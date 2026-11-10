"""Pipette registry must be consistent with executable typing and sizing rules."""
from __future__ import annotations
import importlib.util
import json
from pathlib import Path
import unittest

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location("pipette_core_under_test",HERE/"core.py")
module=importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
REGISTRY=json.loads((HERE/"type_registry.json").read_text(encoding="utf-8"))


class PipetteRegistryTests(unittest.TestCase):
    def test_no_realworld_conversion(self):
        self.assertFalse(REGISTRY["units"]["real_world_conversions"])
        self.assertFalse(REGISTRY["units"]["units_tied_to_realworld"])
        self.assertEqual(REGISTRY["units"]["geometry"],"Blender scene units")

    def test_preset_values_equal_executable(self):
        self.assertEqual(REGISTRY["relative_sizes"],module.SIZE_PRESETS)

    def test_all_family_payloads_in_executable(self):
        self.assertEqual(set(x["id"] for x in REGISTRY["type_categories"]),
                         set(module.FAMILY_PAYLOADS))
        for category in REGISTRY["type_categories"]:
            self.assertEqual(set(category["payloads"]),
                             module.FAMILY_PAYLOADS[category["id"]])

    def test_all_fittings_type_compatible(self):
        self.assertEqual(set(REGISTRY["supported_fittings"]),set(module.FITTINGS))
        for name,meta in REGISTRY["supported_fittings"].items():
            self.assertEqual(set(meta["payloads"]),module.FITTINGS[name])

    def test_every_family_has_visual_questionnaire(self):
        for category in REGISTRY["type_categories"]:
            self.assertGreaterEqual(len(category["ask"]),3)
            self.assertIn("section",category)
            self.assertIn("surface",category)

    def test_no_implicit_simulation(self):
        self.assertFalse(REGISTRY["constraints"]["never_assume_native_factorio_fluidbox"] is False)
        self.assertTrue(REGISTRY["constraints"]["do_not_build_unseen_cores_by_default"])


if __name__=="__main__":
    unittest.main()
