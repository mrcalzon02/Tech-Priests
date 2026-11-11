"""Pipette typed fitting geometry tests; inspect generated meshes, not catalogs.

The 21 modeled fitting recipes are NOT service/pressure/ampacity certifications.
"""
import unittest

import library_fittings as f
import library_geometry as g


class TypedFittingGeometryTests(unittest.TestCase):
    def setUp(self):
        self.rig=g.source_json("comparison_fixture.v1.json")
        self.port=self.rig["topologies"]["wye"]["ports"][0]

    def model(self,architecture,joint,port=None):
        return f.build(architecture,joint,port or self.port)

    def test_first_construction_slice_is_real_and_indexed(self):
        joints=g.source_json("joint_catalog.v1.json")["joint_types"]
        self.assertEqual(len(f.FITTING_RECIPES),25)
        self.assertTrue(set(f.FITTING_RECIPES).issubset(joints))

    def test_fittings_keep_public_port_xyz_unchanged(self):
        cases=[
            ("pipe_galvanized_threaded","threaded"),
            ("conduit_ent_corrugated","snap_conduit"),
            ("conduit_fmc_interlocked","flex_conduit_connector"),
            ("hose_rubber_coolant","hose_barb_clamp"),
            ("wire_eight_loose_bundle","terminal_block"),
            ("wire_single_insulated_solid","ring_lug"),
            ("rebar_deformed_ribbed","rebar_threaded_coupler"),
            ("cable_turnbuckle_rod","turnbuckle")]
        for arch,joint in cases:
            with self.subTest(arch=arch,joint=joint):
                parts=self.model(arch,joint)
                self.assertGreater(len(parts),0)
                self.assertTrue(all(p["public_socket_id"]==self.port["id"]
                                    for p in parts))
                self.assertTrue(all(p["public_socket_xyz_bu"]==
                                    self.port["xyz_bu"] for p in parts))
                self.assertTrue(all(not p["port_has_been_moved"] for p in parts))
                self.assertTrue(all(p["vertices"] and p["faces"] for p in parts))

    def test_flange_is_open_and_has_six_bolts(self):
        parts=self.model("pipe_cast_iron_flanged","flange")
        self.assertEqual(len(parts),8)
        self.assertTrue(any(p["true_open_bore"] for p in parts))
        self.assertEqual(sum("captive bolt" in p["name"] for p in parts),6)
        self.assertEqual(sum(p["role"]=="concentric-mating-throat"
                             for p in parts),1)

    def test_compression_fitting_has_actual_six_flat_faces(self):
        parts=self.model("pipe_brass_hardline","compression")
        nut=next(p for p in parts if p["role"]=="six-flat-retaining-nut")
        self.assertTrue(nut["hex_six_flats"])
        self.assertTrue(nut["true_open_bore"])
        self.assertGreaterEqual(len(nut["faces"]),48)

    def test_raised_thread_is_helical_strip_not_shader(self):
        parts=self.model("pipe_galvanized_threaded","threaded")
        threads=[p for p in parts if p["role"]=="male-thread-ridge"]
        self.assertEqual(len(threads),1)
        self.assertEqual(threads[0]["profile_kind"],"true-helical-ribbon")
        self.assertGreater(len(threads[0]["vertices"]),100)

    def test_fluid_hose_barb_has_actual_ridges_and_clamp(self):
        parts=self.model("hose_rubber_coolant","hose_barb_clamp")
        self.assertEqual(len(parts),5)
        self.assertEqual(sum(p["role"]=="retaining-barb-or-crimp"
                             for p in parts),3)
        self.assertEqual(sum(p["role"]=="full-width-clamp-band"
                             for p in parts),1)

    def test_fmc_gripper_contains_real_helical_capture(self):
        parts=self.model("conduit_fmc_interlocked","flex_conduit_connector")
        helix=next(p for p in parts if p["role"]=="conduit-helical-retention")
        self.assertEqual(helix["profile_kind"],"true-helical-ribbon")
        self.assertGreater(len(helix["faces"]),100)

    def test_eight_wire_connector_has_eight_separate_contacts(self):
        parts=self.model("wire_eight_loose_bundle","terminal_block")
        self.assertEqual(len(parts),9)
        self.assertEqual(sum(p["role"]=="individual-recessed-contact"
                             for p in parts),8)
        self.assertTrue(any(p["role"]=="eight-way-connector-housing"
                            for p in parts))

    def test_ring_lug_has_metal_eye_and_crimp(self):
        parts=self.model("wire_single_insulated_solid","ring_lug")
        self.assertEqual({p["role"] for p in parts},
                         {"flat-ring-lug","wire-crimp-barrel",
                          "solid-lug-bridge"})
        self.assertEqual(sum(p["true_open_bore"] for p in parts),2)
        self.assertFalse(next(p for p in parts if p["role"]=="solid-lug-bridge")
                         ["true_open_bore"])

    def test_eight_terminal_contacts_are_outside_visible_housing_face(self):
        parts=self.model("wire_eight_loose_bundle","terminal_block")
        contacts=[x for x in parts if x["role"]=="individual-recessed-contact"]
        housing=next(x for x in parts if x["role"]=="eight-way-connector-housing")
        self.assertEqual(len(contacts),8)
        # Port A normal is -X, so the public face is on the negative X side.
        housing_front=min(v[0] for v in housing["vertices"])
        self.assertTrue(all(min(v[0] for v in p["vertices"])<housing_front
                            for p in contacts))

    def test_rebar_coupling_is_not_hollow_fluid_pipe(self):
        parts=self.model("rebar_deformed_ribbed","rebar_threaded_coupler")
        self.assertEqual(len(parts),2)
        self.assertTrue(all("solid-bar" in p["role"] or
                            "mechanical-sleeve" in p["role"] for p in parts))

    def test_junction_selects_correct_type_not_fluid_ring_for_wire(self):
        with self.assertRaisesRegex(ValueError,"incompatible"):
            self.model("wire_single_insulated_solid","flange")
        with self.assertRaisesRegex(ValueError,"incompatible"):
            self.model("hose_rubber_coolant","ring_lug")
        with self.assertRaisesRegex(ValueError,"not yet implemented"):
            self.model("pipe_lead_historical","lead_wiped_joint")

    def test_invalid_ports_fail(self):
        bad=dict(self.port)
        bad["outward_normal"]=[0,0,0]
        with self.assertRaises(ValueError):
            self.model("pipe_galvanized_threaded","threaded",bad)

    def test_every_mesh_is_preview_only(self):
        parts=self.model("wire_eight_loose_bundle","terminal_block")
        self.assertTrue(all(p["preview_only"] for p in parts))
        self.assertTrue(all(p["native_socket_seating_verified"] is False
                            for p in parts))

    def test_twisted_pair_uses_two_contacts_not_eight(self):
        parts=self.model("wire_twisted_pair","terminal_block")
        contacts=[p for p in parts if
                  p["role"]=="individual-recessed-contact"]
        self.assertEqual(len(contacts),2)
        self.assertEqual({p["conductor_index"] for p in contacts},{0,1})
        self.assertEqual(len(parts),3)
        self.assertEqual(sum(p["role"]=="sized-multicore-connector-housing"
                             for p in parts),1)



    def test_flat_ribbon_idc_contacts_align_one_per_conductor(self):
        parts=self.model("wire_flat_ribbon","insulation_displacement")
        self.assertEqual(len(parts),9)
        blades=[p for p in parts if p["role"]=="individual-idc-contact-blade"]
        self.assertEqual(len(blades),8)
        self.assertEqual({p["conductor_index"] for p in blades},set(range(8)))
        self.assertEqual(sum(p["role"]=="ribbon-idc-housing" for p in parts),1)

    def test_coax_has_concentric_shield_dielectric_and_center_pin(self):
        parts=self.model("wire_coax","coax_connector")
        roles={p["role"] for p in parts}
        self.assertEqual(len(parts),5)
        self.assertIn("shielded-coax-outer-shell",roles)
        self.assertIn("coax-insulator-ring",roles)
        self.assertIn("coaxial-inner-pin",roles)
        self.assertEqual(sum(p["role"]=="coax-bayonet-retainer" for p in parts),2)
        self.assertTrue(next(p for p in parts if p["role"]==
                        "shielded-coax-outer-shell")["true_open_bore"])

    def test_expanding_braid_has_two_real_overlapping_protection_rings(self):
        parts=self.model("housing_pet_braided_sleeve","sleeve_overlap")
        self.assertEqual(len(parts),2)
        self.assertEqual({p["role"] for p in parts},
                         {"hollow-receiving-sleeve","real-sleeve-overlap"})
        self.assertTrue(all(p["true_open_bore"] for p in parts))

    def test_metal_bellows_receives_flange_and_six_captive_bolts(self):
        parts=self.model("hose_metal_annular","bellows_flange")
        self.assertEqual(len(parts),8)
        self.assertEqual(sum(p["role"]=="bellows-flange-bolt" for p in parts),6)
        self.assertEqual(sum(p["true_open_bore"] for p in parts),2)



if __name__=="__main__":
    unittest.main()
