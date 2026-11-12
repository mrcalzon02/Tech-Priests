"""Offline, native-source recovery and corruption-rejection tests (no Blender required)."""
import hashlib
import json
import tempfile
import unittest
from pathlib import Path
from restore_condenser_v21_source import (APPROVED_SHA, APPROVED_BYTES, APPROVED_FILE, assemble, RestoreError, HERE)


class RecoveryChecks(unittest.TestCase):
    def test_exact_committed_part_names(self):
        manifest=json.loads((HERE/'source-parts/source_manifest.json').read_text())
        self.assertEqual(manifest['approved_source_sha256'], APPROVED_SHA)
        self.assertEqual(manifest['approved_source_size_bytes'], APPROVED_BYTES)
        self.assertEqual(manifest['part_count'], 19)
        self.assertEqual([p['file'] for p in manifest['parts']],
                         [f'condenser_v21.blend.part{i:02d}' for i in range(19)])

    def test_restore_exact_native_bytes(self):
        with tempfile.TemporaryDirectory() as tmp:
            out=Path(tmp)/APPROVED_FILE
            assemble(HERE/'source-parts',out)
            self.assertEqual(out.stat().st_size, APPROVED_BYTES)
            self.assertEqual(hashlib.sha256(out.read_bytes()).hexdigest(),APPROVED_SHA)
            with self.assertRaises(RestoreError):
                assemble(HERE/'source-parts',out)

    def test_tampered_manifest_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder=Path(tmp)/'parts';folder.mkdir()
            manifest=json.loads((HERE/'source-parts/source_manifest.json').read_text())
            manifest['approved_source_sha256']='0'*64
            (folder/'source_manifest.json').write_text(json.dumps(manifest))
            output=Path(tmp)/APPROVED_FILE
            with self.assertRaises(RestoreError):
                assemble(folder,output)
            self.assertFalse(output.exists())

    def test_missing_part_refused_and_partial_removed(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder=Path(tmp)/'parts';folder.mkdir()
            manifest=json.loads((HERE/'source-parts/source_manifest.json').read_text())
            (folder/'source_manifest.json').write_text(json.dumps(manifest))
            out=Path(tmp)/APPROVED_FILE
            with self.assertRaises(RestoreError):
                assemble(folder,out)
            self.assertFalse(out.exists())

if __name__=='__main__': unittest.main()