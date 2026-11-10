"""Pipette v0.1: stdlib-only typing/route/socket/relative-unit regression tests."""
from __future__ import annotations
import importlib.util
from pathlib import Path
import unittest

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location("pipette_pure_core", HERE/"core.py")
core=importlib.util.module_from_spec(spec)
spec.loader.exec_module(core)


def sock(name, point, norm, role, payload):
    return {
        "id":name, "xyz":point, "normal":norm, "role":role,
        "payloads":[payload], "parent_mesh":name+" housing"
    }


def sample(family="rigid_pipe", payload="fluid", begin=(0,0,0),
           end=(1,0,0), diameter=.08):
    return {
        "id":"reference-path", "family":family, "payload":payload,
        "size":{"outer_diameter":diameter,"wall_fraction":.2 if
                family in {"rigid_pipe","segmented_conduit","flex_hose","conduit"} else 0},
        "material_id":"TP Library | iron",
        "path":{"kind":"straight"},
        "start_socket":sock("A",list(begin),[1,0,0],"source",payload),
        "end_socket":sock("B",list(end),[-1,0,0],"sink",payload),
        "fittings":{"start":"auto","end":"auto"}
    }


class PipetteCoreTests(unittest.TestCase):
    def test_scene_unit_diameter_exact(self):
        req=sample(diameter=.08)
        out=core.plan(req)
        self.assertEqual(out["units"],"Blender scene units only; no real-world conversion")
        self.assertAlmostEqual(out["size"]["outer_diameter"],.08)
        self.assertAlmostEqual(out["size"]["bore_diameter"],.064)
        self.assertFalse(out["approval"]["native_blender_verified"])

    def test_named_visual_gauge_is_relative(self):
        req=sample()
        req["size"]={"visual_gauge":"thin","wall_fraction":.2}
        out=core.plan(req)
        self.assertEqual(out["size"]["outer_diameter"],.025)
        self.assertEqual(out["size"]["visual_gauge"],"thin")

    def test_numeric_size_overrides_visual_gauge(self):
        req=sample(diameter=.101)
        req["size"]["visual_gauge"]="massive"
        self.assertEqual(core.plan(req)["size"]["outer_diameter"],.101)

    def test_every_family_with_valid_payload(self):
        families={
            "rigid_pipe":"fluid","segmented_conduit":"air",
            "flex_hose":"coolant","single_wire":"signal",
            "wire_bundle":"power","conduit":"wires",
            "tension_cable":"mechanical_tension","rebar":"reinforcement"}
        for family,payload in families.items():
            with self.subTest(family=family):
                req=sample(family,payload)
                if family=="wire_bundle":
                    req["size"]["conductor_count"]=8
                if family=="segmented_conduit":
                    req["joint_pitch"]=.18
                result=core.plan(req)
                self.assertEqual(result["family"],family)
                self.assertEqual(result["payload"],payload)
                self.assertGreater(len(result["segments"]),0)

    def test_rigid_pipe_uses_flange(self):
        self.assertEqual(core.plan(sample())["fittings"]["start"],"flange")

    def test_electrical_conduit_uses_cable_glands(self):
        request=sample("conduit","wires")
        self.assertEqual(core.plan(request)["fittings"]["end"],"cable_gland")

    def test_flexible_hose_uses_hose_tail(self):
        request=sample("flex_hose","coolant")
        self.assertEqual(core.plan(request)["fittings"]["start"],"hose_tail")

    def test_tension_cable_uses_eye_fittings(self):
        self.assertEqual(core.plan(sample("tension_cable","mechanical_tension"))["fittings"]["start"],"eye")

    def test_rebar_solid_and_coupled(self):
        out=core.plan(sample("rebar","reinforcement"))
        self.assertIsNone(out["size"]["bore_diameter"])
        self.assertEqual(out["fittings"]["end"],"rebar_coupler")

    def test_segmented_conduit_has_measured_joints(self):
        request=sample("segmented_conduit","fluid")
        request["joint_pitch"]=.18
        plan=core.plan(request)
        self.assertEqual(len(plan["segments"]),6)
        self.assertEqual(len(plan["joint_locations"]),5)
        self.assertAlmostEqual(plan["segments"][0]["length"],1/6)

    def test_wire_bundle_count_eight_no_unseen_cores(self):
        req=sample("wire_bundle","power")
        req["size"]["conductor_count"]=8
        out=core.plan(req)
        self.assertEqual(out["size"]["conductor_count"],8)
        self.assertFalse(out["expose_cores"])
        self.assertTrue(any("not built" in note for note in out["warnings"]))

    def test_exposed_conduit_eight_cores(self):
        req=sample("conduit","wires")
        req["size"]["conductor_count"]=8
        req["expose_cores"]=True
        self.assertTrue(core.plan(req)["expose_cores"])

    def test_hanging_sag_is_scene_unit_geometry(self):
        req=sample("tension_cable","mechanical_tension")
        req["path"]={"kind":"hanging","samples":8,"sag":.15}
        out=core.plan(req)
        self.assertAlmostEqual(out["centerline"][4][2],-.15)
        self.assertEqual(out["centerline"][0],(0.,0.,0.))
        self.assertEqual(out["centerline"][-1],(1.,0.,0.))

    def test_orthogonal_routes_around_protected_box(self):
        req=sample(begin=(0,0,0),end=(1,1,0))
        req["path"]={"kind":"orthogonal"}
        req["keep_outs"]=[{"id":"protected","min":[.22,-.10,-.10],"max":[.80,.10,.10]}]
        out=core.plan(req)
        self.assertTrue(len(out["centerline"])>=3)
        self.assertEqual(out["keep_outs"][0]["id"],"protected")
        self.assertGreater(out["centerline"][1][1],0)

    def test_waypoints_must_seat_on_both_sockets(self):
        req=sample()
        req["path"]={"kind":"waypoints","points":[[.1,0,0],[1,0,0]]}
        with self.assertRaises(core.PipetteError):
            core.plan(req)

    def test_waypoints_cannot_cross_keepout(self):
        req=sample()
        req["path"]={"kind":"waypoints","points":[[0,0,0],[.5,0,0],[1,0,0]]}
        req["keep_outs"]=[{"id":"glass tank","min":[.3,-.1,-.1],"max":[.7,.1,.1]}]
        with self.assertRaisesRegex(core.PipetteError,"glass tank"):
            core.plan(req)

    def test_incompatible_fluid_power_connection_rejected(self):
        req=sample("rigid_pipe","power")
        with self.assertRaises(core.PipetteError):
            core.plan(req)

    def test_fitting_mismatch_rejected(self):
        req=sample("single_wire","signal")
        req["fittings"]["start"]="flange"
        with self.assertRaises(core.PipetteError):
            core.plan(req)

    def test_missing_parent_mesh_rejected(self):
        req=sample()
        req["start_socket"].pop("parent_mesh")
        with self.assertRaises(core.PipetteError):
            core.plan(req)

    def test_missing_socket_compatibility_rejected(self):
        req=sample()
        req["end_socket"]["payloads"]=["power"]
        with self.assertRaises(core.PipetteError):
            core.plan(req)

    def test_socket_normal_cannot_be_zero(self):
        req=sample()
        req["start_socket"]["normal"]=[0,0,0]
        with self.assertRaises(core.PipetteError):
            core.plan(req)

    def test_zero_length_route_rejected(self):
        req=sample(end=(0,0,0))
        with self.assertRaises(core.PipetteError):
            core.plan(req)

    def test_nonfinite_diameter_rejected(self):
        req=sample()
        req["size"]["outer_diameter"]=float("nan")
        with self.assertRaises(core.PipetteError):
            core.plan(req)

    def test_wire_bundle_requires_multiple_cores(self):
        req=sample("wire_bundle","signal")
        with self.assertRaises(core.PipetteError):
            core.plan(req)

    def test_single_wire_never_has_eight_cores(self):
        req=sample("single_wire","signal")
        req["size"]["conductor_count"]=8
        with self.assertRaises(core.PipetteError):
            core.plan(req)

    def test_rebar_cannot_have_hollow_wall(self):
        req=sample("rebar","reinforcement")
        req["size"]["wall_fraction"]=.20
        with self.assertRaises(core.PipetteError):
            core.plan(req)

    def test_segment_pitch_needed_for_segmentation(self):
        req=sample("segmented_conduit","fluid")
        with self.assertRaises(core.PipetteError):
            core.plan(req)

    def test_bounded_total_section_count(self):
        req=sample("segmented_conduit","fluid")
        req["joint_pitch"]=.001
        with self.assertRaises(core.PipetteError):
            core.plan(req)

    def test_unterminated_connection_must_be_explicit(self):
        req=sample()
        req["fittings"]["end"]="none"
        with self.assertRaises(core.PipetteError):
            core.plan(req)
        req["allow_unterminated"]=True
        self.assertEqual(core.plan(req)["fittings"]["end"],"none")

    def test_unknown_material_requires_name(self):
        req=sample()
        req["material_id"]=""
        with self.assertRaises(core.PipetteError):
            core.plan(req)

    def test_conservative_classification_requires_review(self):
        hint=core.infer_family_candidates("feed hose to condenser")
        self.assertIn("flex_hose",hint["family_candidates"])
        self.assertTrue(hint["requires_review"])
        self.assertEqual(hint["confidence"],"name-hint-only")


if __name__=="__main__":
    unittest.main()
