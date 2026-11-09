"""FMPL stdlib-only tests. No network, Blender, GitHub token or runner."""
import importlib.util
import hashlib
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("fmpl_entry", ROOT / "fmpl.py")
fmpl = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fmpl)


class FmplTests(unittest.TestCase):
    def test_module_consistency(self):
        doc = fmpl.validate()
        self.assertEqual(doc["inventory"]["materials"], 23)
        self.assertEqual(doc["inventory"]["bunker_component_candidates"], 21)
        self.assertEqual(doc["inventory"]["component_candidates_total"], 39)
        self.assertEqual(doc["inventory"]["emergency_component_candidates"], 18)
        self.assertEqual(len(doc["models"]), 9)
        self.assertEqual(len(doc["programs"]), 19)
        self.assertEqual(len(doc["pipelines"]), 5)
        self.assertEqual(doc["inventory"]["verified_shared_components"], 0)
        self.assertTrue(doc["process_machinery_standard"]["input_process_output_visible_required"])
        self.assertTrue(doc["policy"]["concrete_foundation_language"])

    def test_candidate_event_and_optimistic_conflict(self):
        with tempfile.TemporaryDirectory() as d:
            temp = Path(d) / "checkpoints.json"
            temp.write_text('{"schema":"fmpl.checkpoints.v1","events":[]}\n')
            event = {
                "event_id":"pilot:1:v01","asset_id":"pilot","asset_kind":"model",
                "revision":"v01","state":"candidate","source_sha256":"a"*64,
                "evidence":{"note":"native preview unapproved"}
            }
            with patch.object(fmpl, "EVENTS", temp):
                expected = fmpl.digest()
                new = fmpl.add_event(event, expected)
                self.assertNotEqual(expected, new)
                with self.assertRaises(RuntimeError):
                    fmpl.add_event(dict(event, event_id="pilot:2:v02"), expected)
                with self.assertRaises(RuntimeError):
                    fmpl.add_event(event, new)
                self.assertEqual(len(json.loads(temp.read_text())["events"]),1)

    def test_promotion_requires_real_evidence(self):
        candidate = {"event_id":"a","asset_id":"b","asset_kind":"part","revision":"v1",
                     "state":"installed","source_sha256":"b"*64,"evidence":{}}
        with self.assertRaises(ValueError):
            fmpl.validate_event(candidate)
        candidate["evidence"] = {"source_artifact_sha256":"b"*64,"native_reopen_verified":True}
        with self.assertRaises(ValueError):
            fmpl.validate_event(candidate)
        candidate["evidence"]["owner_visual_approval"] = True
        with self.assertRaises(ValueError):
            fmpl.validate_event(candidate)
        candidate["evidence"]["factorio_runtime_verified"] = True
        fmpl.validate_event(candidate)


if __name__ == "__main__":
    unittest.main()
