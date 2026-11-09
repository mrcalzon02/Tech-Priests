"""FMPL camera contract tests; Python stdlib, no Blender or network."""
import importlib.util
import math
import unittest
from pathlib import Path

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location("fmpl_capture_policy",HERE/"capture_policy.py")
p=importlib.util.module_from_spec(spec)
spec.loader.exec_module(p)


def cfg(kind="entity"):
    return {"capture_kind":kind,"camera_policy":p.POLICY_ID,
       "directions":[0,90,180,270] if kind=="entity" else [0],
       "states":{"idle":[0],"working":[1,2]} if kind=="entity" else {"icon":[0]},
       "source_size":256,"camera_override":{"type":"ORTHO",
         "elevation_deg":45,"azimuth_deg":0,"distance":8,
         "target":[0,0,0.5],"ortho_scale":3.5}}


def receipt():
    s=math.sqrt(.5)
    return {"name":p.CAMERA_NAME,"type":"ORTHO","ortho_scale":3.5,
       "shift_x":0,"shift_y":0,"resolution":[256,256],
       "matrix_world":[[1,0,0,0],[0,s,-s,-8*s],
                       [0,s,s,.5+8*s],[0,0,0,1]]}


class CameraPolicyTests(unittest.TestCase):
    def test_entity_and_item(self):
        for kind in ("entity","item"):
            c=cfg(kind)
            self.assertEqual(p.validate_capture_profile(c),kind)
            self.assertTrue(p.verify_camera_receipt(receipt(),c))

    def test_reject_wrong_or_extra_directions(self):
        for angles in ([0,45,90,180],[0,90,180],
                       [0,90,180,270,360],[90,0,180,270]):
            c=cfg();c["directions"]=angles
            with self.subTest(angles=angles),self.assertRaises(ValueError):
                p.validate_capture_profile(c)

    def test_item_requires_one_icon(self):
        for states in ({"icon":[0,1]},{"idle":[0]},
                       {"icon":[0],"preview":[0]}):
            c=cfg("item");c["states"]=states
            with self.subTest(states=states),self.assertRaises(ValueError):
                p.validate_capture_profile(c)

    def test_reject_off_grid_perspective_and_shift(self):
        for key,value in (("elevation_deg",35),("elevation_deg",46),
                          ("azimuth_deg",45),("type","PERSP"),
                          ("distance",0),("ortho_scale",0),("shift_x",.4)):
            c=cfg();c["camera_override"][key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):
                p.validate_capture_profile(c)

    def test_real_render_receipt_must_match(self):
        for field,value in (("name","closeup"),("type","PERSP"),
                            ("shift_x",.1),("resolution",[256,192])):
            rec=receipt();rec[field]=value
            with self.subTest(field=field),self.assertRaises(ValueError):
                p.verify_camera_receipt(rec,cfg())
        for row,col,value in ((0,2,.4),(0,1,.4),(1,3,200)):
            rec=receipt();rec["matrix_world"][row][col]=value
            with self.subTest(row=row,col=col),self.assertRaises(ValueError):
                p.verify_camera_receipt(rec,cfg())

    def test_temporary_camera_scope_and_original_preservation(self):
        text=(HERE/"blender_camera_guard.py").read_text(encoding="utf-8")
        self.assertIn("bpy.data.objects.remove(camera, do_unlink=True)",text)
        self.assertIn("finally:",text)
        self.assertIn("scene.camera = previous",text)
        clean=(HERE/"camera_cleanup_scene.py").read_text(encoding="utf-8")
        self.assertIn("output==original",clean)
        self.assertIn("if output.exists()",clean)


if __name__=="__main__":
    unittest.main()
