"""Offline, standard-library-only FMPL external donor checks."""
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location("fmpl_greeble_probe",HERE/"probe_source.py")
module=importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class Tests(unittest.TestCase):
    def test_metadata(self):
        info=json.loads((HERE/"source.json").read_text(encoding="utf-8"))
        self.assertEqual(info["observed_datablocks"]["objects"],322)
        self.assertEqual(info["observed_datablocks"]["meshes"],320)
        self.assertEqual(len(info["sha256"]),64)
        self.assertEqual(info["privacy"],"private; no public binary")

    def test_wrong_source_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/"bad.blend"
            path.write_bytes(b"BLENDER17-01v0500"+b"0"*20)
            with self.assertRaises(ValueError):
                module.probe(path)

    def test_non_destructive_adapter(self):
        code=(HERE/"append.py").read_text(encoding="utf-8")
        self.assertIn("bpy.data.libraries.load",code)
        self.assertIn('obj["fmpl_native_port_verified"]=False',code)
        self.assertIn("Cannot overwrite donor",code)

if __name__=="__main__":
    unittest.main()
