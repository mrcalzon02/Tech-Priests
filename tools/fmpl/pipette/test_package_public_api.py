"""Pipette remains a safe package API, without requiring Blender on import."""
from pathlib import Path
import importlib
import sys
import unittest

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0,str(ROOT))


class PipettePackageApiTests(unittest.TestCase):
    def test_import_without_blender(self):
        original=sys.modules.get("bpy")
        pipette=importlib.import_module("tools.fmpl.pipette")
        self.assertTrue(callable(pipette.build_demo))
        self.assertTrue(callable(pipette.build_fitting))
        self.assertEqual(len(pipette.RECIPES),25)
        self.assertEqual(len(pipette.FITTING_RECIPES),25)
        self.assertIs(sys.modules.get("bpy"),original)

    def test_public_entrypoints_return_actual_editable_meshes(self):
        pipette=importlib.import_module("tools.fmpl.pipette")
        model=pipette.build_demo("conduit_ent_corrugated","straight")
        self.assertGreater(len(model["meshes"][0]["vertices"]),100)
        port=model["public_ports"][0]
        parts=pipette.build_fitting("conduit_ent_corrugated","snap_conduit",port)
        self.assertGreater(len(parts),1)
        self.assertTrue(all(p["public_socket_xyz_bu"]==port["xyz_bu"]
                            for p in parts))


if __name__=="__main__":
    unittest.main()
