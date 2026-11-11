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
        self.assertTrue(callable(pipette.build_eight_wire_y))
        self.assertTrue(callable(pipette.build_carrier_form))
        self.assertEqual(len(pipette.FORM_RECIPES),5)
        self.assertEqual(len(pipette.RECIPES),30)
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


    def test_public_branch_api_returns_no_cubic_housing(self):
        pipette=importlib.import_module("tools.fmpl.pipette")
        import json
        fixture=json.loads((HERE/"comparison_fixture.v1.json").read_text())
        model=pipette.build_eight_wire_y(
            "wire_eight_loose_bundle", fixture["topologies"]["wye"])
        roles=[part["role"] for part in model["meshes"]]
        self.assertEqual(roles.count("continuous-branched-conductor"),8)
        self.assertNotIn("junction-housing-preview",roles)
        self.assertEqual(model["branch_port_conductor_counts"],
                         {"A":8,"B":4,"C":4})


    def test_new_carrier_public_api_does_not_import_blender(self):
        pipette=importlib.import_module("tools.fmpl.pipette")
        old=sys.modules.get("bpy")
        for name in pipette.FORM_RECIPES:
            parts=pipette.build_carrier_form((-1.2,0,.65),
                      (1.2,0,.65),name)
            self.assertGreater(len(parts),0)
            self.assertTrue(all(p["faces"] and p["vertices"] for p in parts))
        self.assertIs(sys.modules.get("bpy"),old)


if __name__=="__main__":
    unittest.main()
