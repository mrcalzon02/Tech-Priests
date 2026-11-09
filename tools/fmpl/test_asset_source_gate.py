"""Validate third-party import evidence gates without network or Blender."""
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location("gate", ROOT/"asset_source_gate.py")
gate=importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)

class Tests(unittest.TestCase):
    def test_current_registry_unapproved(self):
        report=gate.validate_registry(ROOT/"external_sources.json")
        self.assertEqual(report["approved_imports"],0)
        registry=json.loads((ROOT/"external_sources.json").read_text(encoding="utf-8"))
        source_ids={source["source_id"] for source in registry["sources"]}
        self.assertEqual(report["sources"],len(source_ids))
        self.assertGreaterEqual(report["sources"],9)
        self.assertIn("user-tank-chaffe-3d-model",source_ids)

    def test_private_user_archive_is_intake_only(self):
        entry={
          "source_id":"unlicensed-user-upload",
          "origin":"user-supplied-archive","title":"Unlicensed model donor",
          "source_uri":"conversation-upload:donor.zip",
          "state":"private-source-intake",
          "rights":"third-party-provenance-not-established",
          "license_evidence":None,
          "source_medium":"native-blender-plus-textures"
        }
        gate.validate(entry)
        entry["state"]="approved-import"
        entry["asset_file_or_component_id"]="donor.blend"
        entry["asset_medium"]="3d-blend"
        entry["import_medium"]="3d-blend"
        entry["license_evidence"]={"license_name":"unknown","evidence_uri":"conversation"}
        entry["derivative_use_reviewed"]=True
        entry["redistribution_reviewed"]=True
        entry["reviewer"]="owner"
        with self.assertRaises(ValueError):
            gate.validate(entry)

    def test_2d_cannot_be_claimed_3d(self):
        record={"source_id":"third-party","origin":"third-party-website","title":"Render","source_uri":"https://example.org", "state":"approved-import", "rights":"third-party", "license_evidence":{"license_name":"CC-BY-4.0", "evidence_uri":"https://example.org/LICENSE"}, "source_medium":"finished-png", "asset_file_or_component_id":"example.png", "asset_medium":"2d-render", "import_medium":"3d-blend", "derivative_use_reviewed":True, "redistribution_reviewed":True, "reviewer":"owner"}
        with self.assertRaises(ValueError):gate.validate(record)

    def test_unknown_rights_block(self):
        entry={"source_id":"external", "origin":"third-party-website", "title":"Asset", "source_uri":"https://example.org/asset", "state":"approved-import", "rights":"unknown", "license_evidence":{"license_name":"CC0", "evidence_uri":"https://example.org/LICENSE"}, "derivative_use_reviewed":True, "redistribution_reviewed":True,"reviewer":"human", "source_medium":"render", "asset_file_or_component_id":"file.png", "asset_medium":"2d-render", "import_medium":"2d-render"}
        with self.assertRaises(ValueError):gate.validate(entry)
        entry["rights"]="third-party";gate.validate(entry)
        entry["license_evidence"]=None
        with self.assertRaises(ValueError):gate.validate(entry)

if __name__=="__main__":unittest.main()
