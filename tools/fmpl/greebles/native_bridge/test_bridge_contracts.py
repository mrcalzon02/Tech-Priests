"""Pure-Python static contracts for the native geometry bridge."""
from pathlib import Path
import re
import unittest

ROOT=Path(__file__).resolve().parent

class SourceBridgeTests(unittest.TestCase):
    def test_source_pins(self):
        source=(ROOT/'blend5_geometry_reader.py').read_text()
        self.assertIn('BLENDER17-01v0500',source)
        self.assertIn('d46d896a146792eadad0a8822a3fc7eb311c6557bd154652ce1dfe7523ebcdc1',source)
    def test_no_claim_of_blender_reopen(self):
        docs=(ROOT/'README.md').read_text()
        self.assertIn('not run in the internal workspace',docs)
        self.assertIn('No new GitHub workflow',docs)
    def test_emits_glb_and_obj(self):
        extract=(ROOT/'extract_native_geometry.py').read_text()
        self.assertIn("save_glb(glb,local,loaded['faces'])",extract)
        self.assertIn('save_obj(obj,local,loaded)',extract)

if __name__=='__main__':unittest.main()
