"""Actual shape tests for the Pipette five-form carrier expansion.

These generate vertices and polygon faces, rather than counting catalog IDs.
Native .blend/.glb reopen and Cycles evidence are separate validation gates.
"""
from __future__ import annotations
import math
import unittest
import library_geometry as geom
import library_forms as forms


class PipettePhysicalFormsTests(unittest.TestCase):
    A=(-1.2,0,.65)
    B=(1.2,0,.65)
    FORMS=("tube_retractile_coil","hose_layflat","hose_twin_bonded",
           "housing_ladder_tray","housing_slotted_duct")

    def test_all_five_forms_registered_as_executable_implementations(self):
        catalog=geom.source_json("architecture_catalog.v1.json")
        entries={t["id"] for t in catalog["architecture_types"]}
        self.assertEqual(set(forms.SUPPORTED),set(self.FORMS))
        self.assertTrue(set(self.FORMS).issubset(geom.RECIPES))
        self.assertTrue(set(self.FORMS).issubset(entries))
        self.assertEqual(len(geom.RECIPES),30)

    def test_coiled_tube_contains_real_hollow_helix_not_painted_ridges(self):
        sections=forms.generate(self.A,self.B,"tube_retractile_coil")
        self.assertEqual(len(sections),1)
        part=sections[0]
        self.assertEqual(part["role"],"hollow-helical-retractile-line")
        self.assertEqual(part["helix_turns"],14)
        self.assertEqual(part["profile_kind"],"continuous-axial-coil")
        self.assertTrue(part["true_open_bore"])
        self.assertLessEqual(part["coil_outer_envelope_bu"],.12)
        self.assertEqual(part["centerline_start"],list(self.A))
        self.assertEqual(part["centerline_end"],list(self.B))
        audit=geom.surface_topology(part["faces"])
        self.assertEqual(audit["surface_islands"],1)
        self.assertEqual(audit["naked_boundary_edges"],0)
        self.assertGreater(len(part["vertices"]),1000)

    def test_flattened_hose_has_real_open_thin_height_bore(self):
        parts=forms.generate(self.A,self.B,"hose_layflat")
        self.assertEqual(len(parts),1)
        m=parts[0]
        self.assertEqual(m["role"],"flattened-hollow-hose-wall")
        self.assertEqual(m["profile_kind"],"flattened-elliptical-open-bore")
        self.assertTrue(m["true_open_bore"])
        self.assertLess(m["outer_height_bu"],m["outer_width_bu"]*.4)
        self.assertGreater(m["inner_height_bu"],0)
        self.assertLess(m["inner_height_bu"],m["outer_height_bu"])
        audit=geom.surface_topology(m["faces"])
        self.assertEqual(audit["surface_islands"],1)
        self.assertEqual(audit["naked_boundary_edges"],0)
        self.assertEqual(audit["degenerate_polygons"],0)

    def test_twin_hose_has_two_independent_actual_bores(self):
        parts=forms.generate(self.A,self.B,"hose_twin_bonded")
        self.assertEqual(len(parts),3)
        tubes=[x for x in parts if x["role"]=="separate-hollow-channel"]
        self.assertEqual(len(tubes),2)
        self.assertEqual([x["channel_index"] for x in tubes],[0,1])
        self.assertTrue(all(x["true_open_bore"] for x in tubes))
        self.assertTrue(all(x["no_fluid_interconnection"] for x in tubes))
        self.assertEqual(parts[2]["role"],"external-molded-bridge")
        for x in tubes:
            audit=geom.surface_topology(x["faces"])
            self.assertEqual(audit["surface_islands"],1)
            self.assertEqual(audit["naked_boundary_edges"],0)

    def test_ladder_tray_has_rails_and_genuine_open_crossbars(self):
        parts=forms.generate(self.A,self.B,"housing_ladder_tray")
        rails=[x for x in parts if x["role"]=="open-ladder-longitudinal-rail"]
        rungs=[x for x in parts if x["role"]=="open-ladder-transverse-rung"]
        self.assertEqual(len(rails),2)
        self.assertGreaterEqual(len(rungs),4)
        self.assertTrue(all(x["carrier_has_open_air_gaps"] for x in parts))
        self.assertTrue(all(len(x["faces"])>=6 for x in parts))
        self.assertEqual(len(parts),2+len(rungs))
        self.assertEqual(len(set(x["rung_count"] for x in parts)),1)

    def test_slotted_duct_has_continuous_floor_and_air_gaps(self):
        parts=forms.generate(self.A,self.B,"housing_slotted_duct")
        self.assertEqual(sum(p["role"]=="continuous-duct-floor"
                             for p in parts),1)
        self.assertEqual(sum(p["role"]=="continuous-duct-wall-foot"
                             for p in parts),2)
        slots=[p for p in parts
               if p["role"]=="individual-slotted-wall-finger"]
        count=parts[0]["slot_count_per_side"]
        self.assertEqual(len(slots),count*2)
        self.assertTrue(all(p["carrier_has_open_air_gaps"] for p in parts))
        self.assertTrue(all(p["removable_lid_not_mounted"] for p in parts))
        self.assertGreaterEqual(len({p["slot_index"] for p in slots}),8)

    def test_all_five_preserve_fixed_standard_ports(self):
        a=[]
        for name in self.FORMS:
            demo=geom.build_demo(name,"straight")
            a.append(demo["public_ports"])
            self.assertEqual(demo["branch_junction_status"],"no-branch")
            self.assertFalse(demo["requires_native_csg_manifold"])
            self.assertGreater(len(demo["meshes"]),0)
            for part in demo["meshes"]:
                self.assertEqual(part["public_port_centers_unchanged"],
                                 [list(self.A),list(self.B)])
        self.assertTrue(all(x==a[0] for x in a[1:]))

    def test_no_generic_support_boxes_or_floating_rings(self):
        blocked={"junction-housing-preview","branch-strain-relief-wrap",
                 "unapproved-untyped-end-ring"}
        for name in self.FORMS:
            with self.subTest(architecture=name):
                parts=forms.generate(self.A,self.B,name)
                self.assertTrue(blocked.isdisjoint({p["role"] for p in parts}))

    def test_unsupported_and_degenerate_inputs_fail_closed(self):
        with self.assertRaises(ValueError):
            forms.generate(self.A,self.B,"wire_eight_loose_bundle")
        with self.assertRaises(ValueError):
            forms.generate(self.A,self.A,"hose_layflat")
        with self.assertRaises(ValueError):
            forms.generate(self.A,self.B,"tube_retractile_coil",nominal_od=-.2)


if __name__=="__main__":
    unittest.main()
