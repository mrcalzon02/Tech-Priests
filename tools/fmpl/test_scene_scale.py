"""FMPL explicit tile-to-Blender scene reference tests, no Blender required."""
from __future__ import annotations
import importlib.util
import json
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location("fmpl_scene_scale_test",ROOT/"scene_scale.py")
m=importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
REGISTRY=json.loads((ROOT/"scene_scale_registry.json").read_text(encoding="utf-8"))


def scope(which="factorio-3x3-v1",scale=None):
    result=dict(REGISTRY["presets"][which])
    result["footprint_tiles"]=list(result["footprint_tiles"])
    result["origin_bu"]=list(result["origin_bu"])
    if scale is not None:
        result["scene_units_per_tile"]=scale
    return m.resolve_scope(result)


class ScaleTests(unittest.TestCase):
    def test_registry_is_blender_scale_not_realworld(self):
        self.assertFalse(REGISTRY["units"]["real_world_conversion"])
        self.assertEqual(REGISTRY["units"]["scene"],"Blender scene units")

    def test_two_by_two_bounds(self):
        s=scope("factorio-2x2-v1")
        self.assertEqual(s["XY_min_bu"],(-1.,-1.))
        self.assertEqual(s["XY_max_bu"],(1.,1.))

    def test_three_by_three_bounds(self):
        s=scope("factorio-3x3-v1")
        self.assertEqual(s["XY_min_bu"],(-1.5,-1.5))
        self.assertEqual(s["XY_max_bu"],(1.5,1.5))

    def test_two_bu_per_tile_scales_boundaries(self):
        s=scope("factorio-2x2-v1",2.0)
        self.assertEqual(s["XY_min_bu"],(-2.,-2.))
        self.assertEqual(s["XY_max_bu"],(2.,2.))
        self.assertAlmostEqual(m.to_blender_units(.57,s),1.14)
        self.assertAlmostEqual(m.to_tile_fraction(1.14,s),.57)

    def test_pipe_dimensions_exact_and_independent_from_footprint(self):
        a=m.standard_pipe(scope("factorio-2x2-v1"))
        b=m.standard_pipe(scope("factorio-3x3-v1"))
        self.assertEqual(a["barrel_outer_diameter_bu"],.57)
        self.assertEqual(a["open_bore_diameter_bu"],.49)
        self.assertEqual(a["mounting_collar_outer_diameter_bu"],.68)
        self.assertEqual(a["mounting_collar_axial_thickness_bu"],.075)
        for field in ("barrel_outer_diameter_bu","open_bore_diameter_bu",
                      "mounting_collar_outer_diameter_bu","mounting_collar_axial_thickness_bu"):
            self.assertEqual(a[field],b[field])

    def test_two_by_two_centered_faces(self):
        s=scope("factorio-2x2-v1")
        self.assertEqual(m.port_center(s,"west",0,.36),(-1.,0.,.36))
        self.assertEqual(m.port_center(s,"east",0,.36),(1.,0.,.36))

    def test_three_by_three_centered_faces(self):
        s=scope()
        self.assertEqual(m.port_center(s,"west",0,.36),(-1.5,0.,.36))
        self.assertEqual(m.port_center(s,"east",0,.36),(1.5,0.,.36))

    def test_scaled_port_with_origin(self):
        req=dict(REGISTRY["presets"]["factorio-3x3-v1"])
        req["origin_bu"]=[10,20,2]
        req["scene_units_per_tile"]=.5
        s=m.resolve_scope(req)
        self.assertEqual(m.port_center(s,"north",.25,.36),(10.125,20.75,2.18))

    def test_nominal_native_position_and_normal(self):
        s=scope()
        result=m.verify_port(
            {"xyz":[-1.5,0,.36],"normal":[-1,0,0]},
            {"standard_id":m.PIPE_STANDARD_ID,"face":"west",
             "transverse_offset_tiles":0,"elevation_tiles":.36},
            s)
        self.assertTrue(result["model_port_verified"])
        self.assertFalse(result["native_factorio_fluidbox_verified"])

    def test_wrong_port_center_rejected(self):
        s=scope()
        with self.assertRaises(m.SceneScaleError):
            m.verify_port(
                {"xyz":[-1.0,0,.36],"normal":[-1,0,0]},
                {"standard_id":m.PIPE_STANDARD_ID,"face":"west",
                 "transverse_offset_tiles":0,"elevation_tiles":.36},
                s)

    def test_wrong_face_normal_rejected(self):
        s=scope()
        with self.assertRaises(m.SceneScaleError):
            m.verify_port(
                {"xyz":[-1.5,0,.36],"normal":[1,0,0]},
                {"standard_id":m.PIPE_STANDARD_ID,"face":"west",
                 "transverse_offset_tiles":0,"elevation_tiles":.36},
                s)

    def test_implicit_offset_rejected(self):
        with self.assertRaises(m.SceneScaleError):
            m.verify_port(
                {"xyz":[-1.5,0,.36],"normal":[-1,0,0]},
                {"standard_id":m.PIPE_STANDARD_ID,"face":"west",
                 "elevation_tiles":.36},scope())

    def test_transverse_offset_outside_footprint_rejected(self):
        with self.assertRaises(m.SceneScaleError):
            m.port_center(scope(),"west",3.0,.36)

    def test_invalid_units_per_tile_rejected(self):
        with self.assertRaises(m.SceneScaleError):
            scope(scale=0)
        with self.assertRaises(m.SceneScaleError):
            scope(scale=float("nan"))

    def test_arbitrary_origin_does_not_modify_pipe_geometry(self):
        a=scope()
        req=dict(REGISTRY["presets"]["factorio-3x3-v1"])
        req["origin_bu"]=[45,-17,0]
        b=m.resolve_scope(req)
        self.assertEqual(m.standard_pipe(a),m.standard_pipe(b))

    def test_native_game_cell_is_never_claimed(self):
        for name in REGISTRY["presets"]:
            self.assertFalse(m.standard_pipe(scope(name))["installed_factorio_fluidbox_proven"])


if __name__=="__main__":
    unittest.main()
