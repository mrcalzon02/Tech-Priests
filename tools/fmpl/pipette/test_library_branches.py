"""Geometric regression for compact eight-wire Y/tee connectors.

These tests generate *actual indexed vertices/faces*, not only catalog names.
They check that the eight entering wires remain eight continuous strands;
a generic cubic terminal housing and three duplicated eight-wire legs are
hard failures. Electrical certification remains out of scope.
"""
from __future__ import annotations

import collections
import math
import unittest

import library_branches as branches
import library_geometry as lib


class WireBranchGeometryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture=lib.source_json("comparison_fixture.v1.json")
        cls.wye=cls.fixture["topologies"]["wye"]
        cls.ports={p["id"]:p for p in cls.wye["ports"]}

    def test_real_eight_wire_wye_has_no_cube(self):
        model=lib.build_demo("wire_eight_loose_bundle","wye")
        roles=[part["role"] for part in model["meshes"]]
        self.assertNotIn("junction-housing-preview",roles)
        self.assertNotIn("eight-way-connector-housing",roles)
        self.assertNotIn("junction-cube",roles)
        self.assertEqual(model["branch_junction_status"],
                         "continuous-conductor-breakout-built")
        self.assertFalse(model["requires_native_csg_manifold"])
        self.assertTrue(model["branch_geometry"]["branch_continuity_constructed"])

    def test_exactly_eight_continuous_wires_not_twenty_four(self):
        model=lib.build_demo("wire_eight_loose_bundle","wye")
        wires=[x for x in model["meshes"]
               if x["role"]=="continuous-branched-conductor"]
        self.assertEqual(len(wires),8)
        self.assertEqual({x["conductor_index"] for x in wires},set(range(8)))
        self.assertEqual(model["branch_geometry"]["branch_route_count"],8)
        self.assertTrue(all(x["branch_continuity"] for x in wires))
        self.assertTrue(all(len(x["vertices"])>100 for x in wires))
        self.assertTrue(all(lib.surface_topology(x["faces"])["surface_islands"]==1
                            for x in wires))

    def test_four_to_each_branch_no_cloned_conductors(self):
        model=lib.build_demo("wire_eight_loose_bundle","wye")
        wires=[x for x in model["meshes"]
               if x["role"]=="continuous-branched-conductor"]
        counts=collections.Counter(tuple(x["conductor_port_pair"])
                                   for x in wires)
        self.assertEqual(counts,{("A","B"):4,("A","C"):4})
        self.assertEqual(model["branch_geometry"]["branch_port_conductor_counts"],
                         {"A":8,"B":4,"C":4})

    def test_wires_use_same_original_public_socket_centers(self):
        model=lib.build_demo("wire_eight_loose_bundle","wye")
        self.assertEqual(model["public_ports"],self.wye["ports"])
        for x in model["meshes"]:
            if x["role"]=="continuous-branched-conductor":
                p1,p2=x["conductor_port_pair"]
                self.assertEqual(x["public_port_centers_unchanged"],
                    [self.ports[p1]["xyz_bu"],self.ports[p2]["xyz_bu"]])
                for node,port in ((x["source_endpoint_bu"],p1),
                                  (x["target_endpoint_bu"],p2)):
                    self.assertLess(math.dist(node,
                      self.ports[port]["xyz_bu"]),.12*.5)

    def test_sag_varies_naturally_and_output_is_repeatable(self):
        a=lib.build_demo("wire_eight_loose_bundle","wye")
        b=lib.build_demo("wire_eight_loose_bundle","wye")
        wa=sorted((x for x in a["meshes"] if
                   x["role"]=="continuous-branched-conductor"),
                  key=lambda x:x["conductor_index"])
        wb=sorted((x for x in b["meshes"] if
                   x["role"]=="continuous-branched-conductor"),
                  key=lambda x:x["conductor_index"])
        self.assertEqual(len({tuple(x["sag_blender_units"]) for x in wa}),8)
        self.assertEqual([x["vertices"] for x in wa],
                         [x["vertices"] for x in wb])
        self.assertTrue(all(x["sag_blender_units"][0]>0 and
                            x["sag_blender_units"][1]>0 for x in wa))

    def test_loose_bundle_has_sixteen_end_ferrules_but_no_floating_wrappers(self):
        model=lib.build_demo("wire_eight_loose_bundle","wye")
        hardware=[p for p in model["meshes"] if
                  p["role"]=="individual-conductor-ferrule"]
        sleeves=[p for p in model["meshes"] if
                 p["role"]=="branch-strain-relief-wrap"]
        self.assertEqual(len(hardware),16)
        self.assertEqual(len(sleeves),0)
        self.assertEqual(collections.Counter(
            p["ferrule_terminal_port"] for p in hardware),
            {"A":8,"B":4,"C":4})
        self.assertEqual(model["branch_geometry"]["branch_strain_relief_wraps"],0)
        self.assertEqual(model["branch_geometry"]["branch_hardware_type"],
                         "eight-wire-Y-unbound-loose-split")
        self.assertTrue(all(p["true_open_bore"] for p in hardware+ sleeves))
        self.assertFalse(any(p["role"].endswith("box") for p in model["meshes"]))
        self.assertTrue(all(not p.get("native_socket_seating_verified",False)
                            for p in hardware))

    def test_loose_wire_variant_has_no_unmounted_metal_ring_or_binding(self):
        for topology in ("wye","tee"):
            with self.subTest(topology=topology):
                model=lib.build_demo("wire_eight_loose_bundle",topology)
                unwanted={"branch-strain-relief-wrap",
                          "junction-housing-preview",
                          "terminal-band","terminal-stop"}
                roles={part["role"] for part in model["meshes"]}
                self.assertTrue(roles.isdisjoint(unwanted))
                self.assertEqual(model["branch_geometry"]["branch_strain_relief_wraps"],0)
                self.assertFalse(model["branch_geometry"]["branch_has_mounted_support"])
                self.assertEqual(
                    sum(x["role"]=="continuous-branched-conductor"
                        for x in model["meshes"]),8)

    def test_ferrule_bore_clears_real_insulated_strand(self):
        model=lib.build_demo("wire_eight_loose_bundle","wye")
        strands=[p for p in model["meshes"]
                 if p["role"]=="continuous-branched-conductor"]
        ferrules=[p for p in model["meshes"]
                  if p["role"]=="individual-conductor-ferrule"]
        self.assertEqual(len(strands),8)
        self.assertEqual(len(ferrules),16)
        diameter={p["conductor_index"]:p["outer_diameter_bu"] for p in strands}
        for sleeve in ferrules:
            with self.subTest(core=sleeve["conductor_index"]):
                self.assertGreater(sleeve["bore_diameter_bu"],
                                   diameter[sleeve["conductor_index"]])
                self.assertLess(sleeve["outer_diameter_bu"],.12*.20)

    def test_three_breakout_boots_are_tapered_closed_walls_not_thin_rings(self):
        model=lib.build_demo("wire_eight_laced_loom","wye")
        wraps=[p for p in model["meshes"]
               if p["role"]=="branch-strain-relief-wrap"]
        self.assertEqual(len(wraps),5)
        for wrap in wraps:
            self.assertEqual(wrap["profile_kind"],
                             "tapered-hollow-wire-breakout-boot")
            self.assertGreater(wrap["axial_length_bu"],.12*.8)
            self.assertGreater(wrap["bore_diameter_bu"],.12*.39)
            audit=lib.surface_topology(wrap["faces"])
            self.assertEqual(audit["surface_islands"],1)
            self.assertEqual(audit["naked_boundary_edges"],0)
            self.assertEqual(audit["degenerate_polygons"],0)
            self.assertEqual(audit["overlapping_nonmanifold_edges"],0)

    def test_does_not_extend_ferrules_beyond_canonical_port_face(self):
        model=lib.build_demo("wire_eight_loose_bundle","wye")
        for p in model["meshes"]:
            if p["role"]!="individual-conductor-ferrule":
                continue
            port=self.ports[p["ferrule_terminal_port"]]
            face=port["xyz_bu"]
            outward=port["outward_normal"]
            outward_extents=[lib.dot(lib.sub(v,face),outward)
                             for v in p["vertices"]]
            self.assertLess(max(outward_extents),.12*.52)

    def test_wire_centerlines_do_not_interpenetrate_at_hub(self):
        for topology in ("wye","tee"):
            with self.subTest(topology=topology):
                model=lib.build_demo("wire_eight_loose_bundle",topology)
                info=model["branch_geometry"]
                self.assertTrue(info["cross_section_spacing_checked"])
                self.assertGreater(info["minimum_wire_surface_gap_bu"],0)
                conductor_od=.12*.115
                self.assertGreater(
                    info["minimum_wire_center_spacing_bu"],
                    conductor_od*1.08)

    def test_tied_harness_has_extra_real_lacing_not_a_block(self):
        model=lib.build_demo("wire_eight_laced_loom","wye")
        roles=[p["role"] for p in model["meshes"]]
        self.assertEqual(roles.count("continuous-branched-conductor"),8)
        self.assertEqual(roles.count("branch-strain-relief-wrap"),5)
        self.assertEqual(roles.count("individual-conductor-ferrule"),16)
        self.assertFalse(any("housing-preview" in x for x in roles))

    def test_tee_reuses_same_split_rule_without_invented_hub_xyz(self):
        model=lib.build_demo("wire_eight_loose_bundle","tee")
        expected=self.fixture["topologies"]["tee"]
        self.assertEqual(model["public_ports"],expected["ports"])
        self.assertEqual(model["junctions"],expected["junctions"])
        self.assertEqual(model["branch_junction_status"],
                         "continuous-conductor-breakout-built")

    def test_unimplemented_branches_do_not_insert_fake_cube(self):
        for architecture in ("wire_single_insulated_solid",
                             "wire_coax","conduit_fmc_interlocked"):
            with self.subTest(architecture=architecture):
                model=lib.build_demo(architecture,"wye")
                self.assertEqual(model["branch_junction_status"],
                                 "unresolved-branch-hardware-no-fallback-block")
                self.assertFalse(any(x["role"]=="junction-housing-preview"
                                     for x in model["meshes"]))

    def test_invalid_port_orientation_fails_closed(self):
        bad={k:list(v) if isinstance(v,list) else v for k,v in self.wye.items()}
        bad["ports"]=[dict(p) for p in self.wye["ports"]]
        bad["ports"][0]["outward_normal"]=[1,0,0]
        with self.assertRaisesRegex(ValueError,"facing"):
            branches.build_eight_wire_y("wire_eight_loose_bundle",bad)

    def test_catalog_only_cannot_implicitly_build_unrelated_branches(self):
        with self.assertRaises(ValueError):
            branches.build_eight_wire_y("wire_twisted_pair",self.wye)
        with self.assertRaises(ValueError):
            branches.build_eight_wire_y("wire_eight_loose_bundle",self.wye,-.2)


if __name__=="__main__":
    unittest.main()
