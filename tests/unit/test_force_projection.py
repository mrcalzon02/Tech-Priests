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
    roster = [{"force": "f"+str(i), "kind": "p" if i in (0, 2) else "b"}
              for i in range(4)]
    rows = [("CONFIG", {"preset": "2p2b", "seed": 42, "active_ticks": 3600,
                        "participants": roster, "side": 2048}),
            ("READY", {"tick": 30000, "participants": 4})]
    for i in (0, 2):
        rows.append(("SUPPLY", {"force": "f"+str(i), "refills": 0,
                               "stock": [{"slot": 1, "count": 10}]}))
    for cell in range(64):
        for name in ("iron-ore", "copper-ore", "coal", "stone", "crude-oil", "water"):
            rows.append(("DEPOSIT", {"cell": cell, "name": name,
                                     "entities_or_tiles": 1}))
    for p in roster:
        rows.append(("SAMPLE", {"force": p["force"], "elapsed": 3600}))
    rows.append(("COMPLETE", {"preset": "2p2b", "seed": 42, "tick": 33600,
                              "elapsed": 3600, "participants": 4}))
    return rows


def encode(rows):
    return "\n".join(arena.TAG + kind + " " + json.dumps(data) for kind, data in rows)


class Verdict(unittest.TestCase):
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

    def test_missing_mismatched_duplicate_and_failed_receipts(self):
        rows = observations()
        variants = [rows[:-1], rows + [rows[-1]], rows[1:],
                    [x for x in rows if x[0] != "SUPPLY"],
                    [x for x in rows if x[0] != "SAMPLE"],
                    [x for x in rows if x[0] != "DEPOSIT"],
                    rows + [("FAIL", {"reason": "broken"})]]
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
