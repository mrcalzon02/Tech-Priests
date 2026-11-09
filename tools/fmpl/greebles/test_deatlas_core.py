"""No Blender or network required. Validate safe candidate naming and resume rules."""
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("core", HERE / "deatlas_core.py")
core = importlib.util.module_from_spec(spec)
spec.loader.exec_module(core)
SHA = "a" * 64

class Tests(unittest.TestCase):
    def test_name_stability_and_collisions(self):
        self.assertEqual(core.candidate_id(SHA, "Body003"), core.candidate_id(SHA, "Body003"))
        self.assertNotEqual(core.candidate_id(SHA, "Body003"), core.candidate_id(SHA, "Body 003"))
        self.assertTrue(core.candidate_id(SHA, "Part/../12").startswith("gb-part-12-"))

    def test_bounded_batch(self):
        self.assertEqual(core.select_batch(["z", "B", "a"], offset=1, limit=2), ["B", "z"])
        with self.assertRaises(ValueError):
            core.select_batch(["a"], offset=0, limit=100)

    def test_resume_checks_actual_output_bytes(self):
        with tempfile.TemporaryDirectory() as dirname:
            root = Path(dirname)
            part, receipt = root / "part.blend", root / "receipt.json"
            self.assertFalse(core.verified_checkpoint(part, receipt, SHA, "Body003"))
            part.write_bytes(b"example file")
            with self.assertRaises(RuntimeError):
                core.verified_checkpoint(part, receipt, SHA, "Body003")
            core.atomic_json(receipt, {"schema":core.SCHEMA,"source_sha256":SHA,
                      "source_object":"Body003","status":"extracted-candidate",
                      "part_sha256":core.sha256_file(part)})
            self.assertTrue(core.verified_checkpoint(part, receipt, SHA, "Body003"))
            part.write_bytes(b"damaged")
            with self.assertRaises(RuntimeError):
                core.verified_checkpoint(part, receipt, SHA, "Body003")

if __name__ == "__main__":
    unittest.main()
