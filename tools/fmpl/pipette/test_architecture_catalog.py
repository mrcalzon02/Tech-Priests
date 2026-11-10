"""Pipette architecture index contracts; no Blender or external dependencies.

These are source-index checks, NOT native mesh, physics, or game-verification tests.
"""
from __future__ import annotations

import importlib.util
import json
import math
from pathlib import Path
import unittest

HERE = Path(__file__).resolve().parent

def load(name: str):
    return json.loads((HERE / name).read_text(encoding="utf-8"))

ARCH = load("architecture_catalog.v1.json")
JOINTS = load("joint_catalog.v1.json")
STIFF = load("stiffness_profiles.v1.json")
RIG = load("comparison_fixture.v1.json")
spec = importlib.util.spec_from_file_location("pipette_catalog_core", HERE / "core.py")
core = importlib.util.module_from_spec(spec)
spec.loader.exec_module(core)


class PipetteArchitectureIndexTests(unittest.TestCase):
    def test_schema_versions(self):
        self.assertEqual(ARCH["schema"], "fmpl.pipette.architecture-catalog.v1")
        self.assertEqual(JOINTS["schema"], "fmpl.pipette.joints.v1")
        self.assertEqual(STIFF["schema"], "fmpl.pipette.stiffness-profiles.v1")
        self.assertEqual(RIG["schema"], "fmpl.pipette.comparison-fixture.v1")

    def test_distinct_type_inventory(self):
        items = ARCH["architecture_types"]
        self.assertEqual(len(items), 140)
        ids = [item["id"] for item in items]
        self.assertEqual(len(ids), len(set(ids)))
        self.assertEqual(len(ARCH["groups"]), 9)
        self.assertGreater(len({item["section_architecture"] for item in items}), 45)

    def test_existing_base_family_compatibility(self):
        for item in ARCH["architecture_types"]:
            with self.subTest(type=item["id"]):
                self.assertIn(item["base_family"], core.FAMILY_PAYLOADS)
                self.assertIn(item["group"], ARCH["groups"])
                self.assertEqual(item["implementation"], "indexed_pending_distinct_native_mesh")
                self.assertTrue(item["visible_architecture"])

    def test_all_referenced_joint_types_exist(self):
        refs = JOINTS["joint_types"]
        used = set()
        for item in ARCH["architecture_types"]:
            self.assertGreaterEqual(len(item["compatible_joint_ids"]), 2)
            for key in item["compatible_joint_ids"]:
                self.assertIn(key, refs, f"{item['id']} references unknown joint {key}")
                used.add(key)
        self.assertGreaterEqual(len(refs), 70)
        self.assertGreaterEqual(len(used), 40)

    def test_cross_domain_review_is_explicit(self):
        reviews = {(x["type"], x["joint"]) for x in
                   ARCH["domain_crossings_for_later_connector_review"]}
        observed = set()
        for item in ARCH["architecture_types"]:
            domain = ARCH["groups"][item["group"]]["domain"]
            for key in item["compatible_joint_ids"]:
                if domain not in JOINTS["joint_types"][key]["domains"]:
                    observed.add((item["id"], key))
        self.assertEqual(reviews, observed)

    def test_stiffness_profiles_typed_and_bounded(self):
        presets = STIFF["presets"]
        self.assertEqual(len(presets), 20)
        for item in ARCH["architecture_types"]:
            self.assertIn(item["stiffness_profile"], presets)
        for name, rule in presets.items():
            with self.subTest(preset=name):
                sag = rule["normalized_sag_fraction_of_span"]
                self.assertTrue(0 <= sag <= .25)
                self.assertIn("shape_rule", rule)
                radius = rule["minimum_bend_radius_in_OD"]
                if radius is not None:
                    self.assertGreaterEqual(radius, 0)

    def test_fixed_port_radius_and_unit_normals(self):
        nominal = RIG["workspace"]["endpoint_radius_bu"]
        self.assertAlmostEqual(nominal, 1.2)
        self.assertAlmostEqual(RIG["workspace"]["nominal_outer_diameter_bu"], .12)
        self.assertEqual(len(RIG["topologies"]), 9)
        for name, topo in RIG["topologies"].items():
            with self.subTest(topology=name):
                ids = [port["id"] for port in topo["ports"]]
                self.assertEqual(len(ids), len(set(ids)))
                known_nodes = set(ids) | {j["id"] for j in topo["junctions"]}
                for port in topo["ports"]:
                    x, y, z = port["xyz_bu"]
                    self.assertAlmostEqual(math.hypot(x, y), nominal, places=7)
                    self.assertAlmostEqual(z, .65)
                    self.assertAlmostEqual(math.sqrt(
                        sum(v * v for v in port["outward_normal"])), 1, places=7)
                for edge in topo["connection_graph"]:
                    self.assertEqual(len(edge), 2)
                    self.assertTrue(set(edge).issubset(known_nodes))

    def test_y_junction_standard_positions(self):
        wye = RIG["topologies"]["wye"]
        ports = {p["id"]: p["xyz_bu"] for p in wye["ports"]}
        self.assertEqual(ports["A"], [-1.2, 0, .65])
        self.assertAlmostEqual(ports["B"][0], .848528137)
        self.assertAlmostEqual(ports["B"][1], .848528137)
        self.assertAlmostEqual(ports["C"][0], .848528137)
        self.assertAlmostEqual(ports["C"][1], -.848528137)
        self.assertEqual(wye["junctions"][0]["xyz_bu"], [0, 0, .65])

    def test_demo_pairs_cannot_override_shared_endpoints(self):
        indexed = {item["id"]: item for item in ARCH["architecture_types"]}
        self.assertGreaterEqual(len(RIG["demo_pairs"]), 4)
        for pair in RIG["demo_pairs"]:
            self.assertIn(pair["left"], indexed)
            self.assertIn(pair["right"], indexed)
            self.assertIn(pair["topology"], RIG["topologies"])
            self.assertNotIn("ports", pair)
            self.assertNotIn("scale", pair)
            self.assertNotIn("endpoint_override", pair)

    def test_historical_lead_and_electrical_y_are_separate_architectures(self):
        profiles = {item["id"]: item for item in ARCH["architecture_types"]}
        lead = profiles["pipe_lead_historical"]
        wire = profiles["wire_single_insulated_solid"]
        self.assertNotEqual(lead["section_architecture"], wire["section_architecture"])
        self.assertIn("lead_wiped_joint", lead["compatible_joint_ids"])
        self.assertIn("crimp_butt", wire["compatible_joint_ids"])
        self.assertIn("wye", lead["comparison_topologies"])
        self.assertIn("wye", wire["comparison_topologies"])

    def test_eight_core_slack_is_nonuniform_but_bounded(self):
        a = RIG["wire_bundle_display_policy"]
        b = STIFF["wire_bundle_variation"]
        self.assertEqual(a["seed"], b["deterministic_seed"])
        for key in ("per_core_sag_multipliers", "per_core_lateral_phase"):
            self.assertEqual(len(a[key]), 8)
        sag = a["per_core_sag_multipliers"]
        self.assertEqual(sag, b["per_core_sag_multiplier"])
        self.assertEqual(len(set(sag)), 8)
        self.assertTrue(all(.5 <= value <= 1.5 for value in sag))
        self.assertLess(max(a["per_core_lateral_phase"]), .5)
        self.assertGreater(min(a["per_core_lateral_phase"]), -.5)

    def test_isolated_cross_is_not_connected_cross(self):
        joined = RIG["topologies"]["cross_connected"]
        isolated = RIG["topologies"]["cross_isolated"]
        self.assertEqual(
            [p["xyz_bu"] for p in joined["ports"]],
            [p["xyz_bu"] for p in isolated["ports"]])
        self.assertTrue(isolated["no_electrical_or_fluid_contact_at_crossing"])
        self.assertNotEqual(joined["connection_graph"], isolated["connection_graph"])

    def test_no_implied_approval_or_global_tile_scaling(self):
        self.assertEqual(ARCH["status"], "INDEX_ONLY_NOT_NATIVE_GENERATOR_OR_GAME_READY")
        self.assertTrue(ARCH["existing_v01_family_compatibility"])
        self.assertIn("Factorio", RIG["invariants"][-1])
        self.assertEqual(JOINTS["status"], "joint_taxonomy_not_generator_approval")


if __name__ == "__main__":
    unittest.main()
