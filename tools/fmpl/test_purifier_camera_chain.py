"""Offline contract tests for the Water Purifier's native Blender camera chain.

Uses Python stdlib only. Geometry and Blender-native acceptance require a
separate actual Blender run on the authorized runner.
"""
from __future__ import annotations

import math
import sys
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT))
from capture_policy import validate_capture_profile, verify_camera_receipt, CAMERA_NAME
from production_smoke.camera_profile import purifier_profile


class PurifierCameraChain(unittest.TestCase):
    def test_measured_camera_fixture_matches_factorio_grid(self):
        c=purifier_profile(512)
        self.assertEqual(validate_capture_profile(c),"entity")
        self.assertEqual(c["directions"],[0,90,180,270])
        self.assertEqual(c["camera_override"]["elevation_deg"],45)
        self.assertEqual(c["camera_override"]["azimuth_deg"],0)
        self.assertAlmostEqual(c["camera_override"]["distance"],6*math.sqrt(2),places=6)

    def test_rendered_camera_matrix_matches_actual_fixture(self):
        c=purifier_profile(512)
        s=math.sqrt(.5)
        record={
            "name":CAMERA_NAME,"type":"ORTHO","ortho_scale":5.8,
            "shift_x":0,"shift_y":0,"resolution":[512,512],
            "matrix_world":[[1,0,0,0],[0,s,-s,-6],[0,s,s,7.65],[0,0,0,1]]
        }
        self.assertTrue(verify_camera_receipt(record,c))
        record["matrix_world"][0][2]=0.1
        with self.assertRaises(ValueError):
            verify_camera_receipt(record,c)

    def test_three_builders_sanitize_before_saving_derived_blend(self):
        for filename in ("blender_build.py","refine_process.py","super_greeble.py"):
            with self.subTest(filename=filename):
                text=(ROOT/"production_smoke"/filename).read_text(encoding="utf-8")
                self.assertIn("camera_profile",text)
                self.assertIn("clean_scene(",text)
                self.assertIn("audit_scene(",text)
                self.assertLess(text.index("clean_scene("),text.index("save_as_mainfile("))
                self.assertNotIn("bpy.data.cameras.new(",text)
                self.assertIn("FMPL",text)

    def test_native_reopen_verifiers_use_the_same_camera_guard(self):
        for filename in ("verify_build.py","verify_process.py","verify_super_greeble.py"):
            with self.subTest(filename=filename):
                text=(ROOT/"production_smoke"/filename).read_text(encoding="utf-8")
                self.assertIn("from camera_profile import audit_scene",text)
                self.assertIn("audit_scene(scene,bpy,512)",text)
                self.assertIn("camera_cleanup",text)
                self.assertIn("fmpl.factorio45.v1",text)

    def test_temporary_camera_lifetime_is_explicit(self):
        guard=(ROOT/"blender_camera_guard.py").read_text(encoding="utf-8")
        self.assertIn("def temporary_inspection_camera(",guard)
        self.assertIn("finally:",guard)
        self.assertIn("scene.camera = previous",guard)
        self.assertIn("bpy.data.objects.remove(obj, do_unlink=True)",guard)
        self.assertIn("len(cameras) != 1",guard)

    def test_no_unsupported_item_or_diagonal_capture(self):
        c=purifier_profile()
        c["directions"]=[0,45,90,180,270]
        with self.assertRaises(ValueError):
            validate_capture_profile(c)
        c=purifier_profile()
        c["capture_kind"]="item"
        with self.assertRaises(ValueError):
            validate_capture_profile(c)


if __name__=="__main__":
    unittest.main()
