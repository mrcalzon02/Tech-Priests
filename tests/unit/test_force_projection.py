import copy
import importlib.util
import json
import pathlib
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import run_force_projection as arena


def observations():
    roster = [{"force": "f"+str(i), "kind": "p" if i in (0, 2) else "b",
               "team": ("left-a", "bugs-a", "left-b", "bugs-b")[i]}
              for i in range(4)]
    rows = [("CONFIG", {"preset": "2p2b", "seed": 42, "active_ticks": 3600,
                        "participants": roster, "side": 2048}),
            ("READY", {"tick": 30000, "participants": 4})]
    for i in (0, 2):
        rows.append(("SUPPLY", {"force": "f"+str(i), "refills": 0,
                               "expansion_stock": {"name":"senior-cogitator-station",
                                   "count":3,"inserted":3,"native_count":3,
                                   "location":"magos-station","deployed":0},
                               "stock": [{"slot": 1, "count": 10}]}))
    for cell in range(64):
        for name in ("iron-ore", "copper-ore", "coal", "stone", "crude-oil", "water"):
            rows.append(("DEPOSIT", {"cell": cell, "name": name,
                                     "entities_or_tiles": 1}))
    for p in roster:
        is_priest = p["kind"] == "p"
        record = {"force": p["force"], "kind": p["kind"], "team": p["team"],
                  "tick": 33600, "elapsed": 3600, "station_alive": is_priest,
                  "priest_alive": is_priest, "build_events": 0, "lost": 0,
                  "research_finished": 0, "damage_dealt": 0,
                  "damage_received": 0, "max_build_distance": 0,
                  "supply_remaining": 0,
                  "ore_production": {"iron-ore": 0, "copper-ore": 0,
                                     "coal": 0, "stone": 0}}
        if is_priest:
            record.update(initial_expansion_kits=3, senior_kits_in_magos=3)
        rows.append(("SAMPLE", record))
    rows.append(("COMPLETE", {"preset": "2p2b", "seed": 42, "tick": 33600,
                              "elapsed": 3600, "participants": 4}))
    return rows


def encode(rows):
    return "\n".join(arena.TAG + kind + " " + json.dumps(data) for kind, data in rows)


class StreamingDiagnostics(unittest.TestCase):
    def test_fragmented_native_markers_preserve_complete_lines(self):
        first = "000 [TP-FORCE-PROJECTION] PAIR_FAI"
        second = 'LURE {"force":"tp-arena-1","pair_record_present":false}\n'
        lines, carry = arena.drain_complete_lines("", first)
        self.assertEqual(lines, [])
        self.assertEqual(carry, first)
        lines, carry = arena.drain_complete_lines(carry, second)
        self.assertEqual(carry, "")
        self.assertEqual(len(lines), 1)
        self.assertIn("PAIR_FAILURE", lines[0])
        self.assertEqual(
            arena.latest_native_receipt(lines[0], "PAIR_FAILURE"),
            {"force": "tp-arena-1", "pair_record_present": False})

    def test_only_complete_native_lines_are_emitted(self):
        lines, carry = arena.drain_complete_lines("", "a\nb\npartial")
        self.assertEqual(lines, ["a", "b"])
        self.assertEqual(carry, "partial")
        lines, carry = arena.drain_complete_lines(carry, "-end\n")
        self.assertEqual(lines, ["partial-end"])
        self.assertEqual(carry, "")

    def test_failure_receipt_does_not_invent_success(self):
        self.assertIsNone(arena.latest_native_receipt("unrelated log", "PAIR_FAILURE"))
        self.assertEqual(
            arena.latest_native_receipt(
                "[TP-FORCE-PROJECTION] PAIR_FAILURE invalid\n",
                "PAIR_FAILURE"),
            {"invalid_native_payload": True})


class Verdict(unittest.TestCase):
    def test_expansion_kits_must_be_one_to_five_real_undeployed_items(self):
        for count in (1,5):
            rows=copy.deepcopy(observations())
            for kind,record in rows:
                if kind=="SUPPLY":
                    for field in ("count","inserted","native_count"):
                        record["expansion_stock"][field]=count
            self.assertTrue(arena.parse_observations(encode(rows),"2p2b",42,3600)["observation_complete"])
        for field,value in (("count",0),("count",6),("inserted",2),
                            ("native_count",2),("deployed",1),("location","chest")):
            rows=copy.deepcopy(observations())
            next(x[1] for x in rows if x[0]=="SUPPLY")["expansion_stock"][field]=value
            with self.assertRaises(ValueError):
                arena.parse_observations(encode(rows),"2p2b",42,3600)

    def test_create_and_loaded_server_have_distinct_native_evidence(self):
        rows = observations()
        initial = encode([x for x in rows if x[0] == "CONFIG"])
        loaded = encode([x for x in rows if x[0] != "CONFIG"])
        self.assertTrue(arena.parse_process_observations(
            initial, loaded, "2p2b", 42, 3600)["observation_complete"])
        for a, b in (("", encode(rows)), (encode(rows), ""),
                     (initial, initial+loaded)):
            with self.assertRaises(ValueError):
                arena.parse_process_observations(a,b,"2p2b",42,3600)

    def test_complete_observation_does_not_imply_combat_or_expansion(self):
        result = arena.parse_observations(encode(observations()), "2p2b", 42, 3600)
        self.assertTrue(result["observation_complete"])
        self.assertFalse(result["combat_observed"])
        self.assertTrue(result["expansion_success_not_assumed"])
        self.assertFalse(result["hostile_contact_observed"])
        self.assertEqual(result["observed_progress"]["native_build_events"], 0)
        self.assertEqual(result["observed_progress"]["native_ore_stat_inputs"], 0)

    def test_native_sample_counters_required_even_for_no_progress(self):
        for field, invalid in (
                ("build_events", -1), ("research_finished", -1),
                ("damage_dealt", -0.5), ("station_alive", None),
                ("priest_alive", "yes"), ("max_build_distance", -1),
                ("tick", 33601), ("team", "wrong")):
            rows = copy.deepcopy(observations())
            sample = next(r for kind, r in rows if kind == "SAMPLE")
            sample[field] = invalid
            with self.assertRaises(ValueError, msg=field):
                arena.parse_observations(encode(rows), "2p2b", 42, 3600)
        rows = copy.deepcopy(observations())
        next(r for kind, r in rows if kind == "SAMPLE")["ore_production"].pop("coal")
        with self.assertRaises(ValueError):
            arena.parse_observations(encode(rows), "2p2b", 42, 3600)

    def test_real_contact_counters_not_a_fabricated_victory(self):
        rows = copy.deepcopy(observations())
        rows.insert(-1, ("CONTACT", {"tick": 30012, "attacker": "f0",
                                     "defender": "f1", "damage": 4}))
        result = arena.parse_observations(encode(rows), "2p2b", 42, 3600)
        self.assertTrue(result["combat_observed"])
        self.assertTrue(result["hostile_contact_observed"])
        self.assertEqual(result["observed_progress"]["cross_force_damage_contacts"], 1)
        self.assertEqual(result["observed_progress"]["native_build_events"], 0)
        for bad in ({"tick": 29999, "attacker": "f0", "defender": "f1", "damage": 4},
                    {"tick": 30012, "attacker": "f0", "defender": "f0", "damage": 4},
                    {"tick": 30012, "attacker": "unknown", "defender": "f1", "damage": 4},
                    {"tick": 30012, "attacker": "f0", "defender": "f1", "damage": 0}):
            invalid = copy.deepcopy(observations())
            invalid.insert(-1, ("CONTACT", bad))
            with self.assertRaises(ValueError):
                arena.parse_observations(encode(invalid), "2p2b", 42, 3600)
        with self.assertRaises(ValueError):
            arena.parse_observations(encode(rows[:-1]+[rows[-2],rows[-1]]),
                                     "2p2b", 42, 3600)

    def test_missing_mismatched_duplicate_and_failed_receipts(self):
        rows = observations()
        variants = [rows[:-1], rows + [rows[-1]], rows[1:],
                    [x for x in rows if x[0] != "SUPPLY"],
                    [x for x in rows if x[0] != "SAMPLE"],
                    [x for x in rows if x[0] != "DEPOSIT"],
                    rows + [("FAIL", {"reason": "broken"})],
                    rows + [("PAIR_FAILURE", {"force": "f0", "station_unit": 12,
                                              "spawn_search_candidate": None})]]
        for variant in variants:
            with self.assertRaises(ValueError):
                arena.parse_observations(encode(variant), "2p2b", 42, 3600)
        for preset, seed, ticks in (("2v2", 42, 3600), ("2p2b", 43, 3600),
                                    ("2p2b", 42, 7200)):
            with self.assertRaises(ValueError):
                arena.parse_observations(encode(rows), preset, seed, ticks)
        for kind in ("SUPPLY", "DEPOSIT"):
            duplicate = next(x for x in rows if x[0] == kind)
            with self.assertRaises(ValueError):
                arena.parse_observations(encode(rows+[duplicate]), "2p2b", 42, 3600)

    def test_empty_deposit_and_refill_refused(self):
        for kind, field in (("DEPOSIT", "entities_or_tiles"), ("SUPPLY", "refills")):
            rows = copy.deepcopy(observations())
            record = next(x[1] for x in rows if x[0] == kind)
            record[field] = 0 if kind == "DEPOSIT" else 1
            with self.assertRaises(ValueError):
                arena.parse_observations(encode(rows), "2p2b", 42, 3600)


if __name__ == "__main__":
    unittest.main()
