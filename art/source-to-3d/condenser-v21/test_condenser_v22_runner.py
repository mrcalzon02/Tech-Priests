"""Runner source-provenance tests (synthetic bytes never passed to Blender)."""
import hashlib
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

from run_condenser_v22_review import (
    APPROVED_NAME, SourceBlocked, approved_zip_member, candidates,
    file_hash, find_approved, resolve_source,
)


class ExactSourceGateTest(unittest.TestCase):
    def test_wrong_source_bytes_are_hard_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            wrong = root / APPROVED_NAME
            wrong.write_bytes(b'not the approved condenser blend')
            with self.assertRaisesRegex(SourceBlocked, 'SHA-256 mismatch'):
                resolve_source(wrong, root / 'new-output')
            self.assertFalse((root / 'new-output').exists())

    def test_starter_archive_does_not_accept_names_alone(self):
        with tempfile.TemporaryDirectory() as temp:
            archive = Path(temp) / 'condenser-v21-starter.zip'
            with zipfile.ZipFile(archive, 'w') as writer:
                writer.writestr('nested/' + APPROVED_NAME, b'wrong model')
                writer.writestr('unrelated.txt', b'ignore me')
            with self.assertRaisesRegex(SourceBlocked, 'No SHA-matching'):
                approved_zip_member(archive)

    def test_exact_archive_entry_extracts_only_that_file_after_hash(self):
        # A deliberately synthetic hash is substituted ONLY for this unit test.
        # The production module's accepted SHA constant is not modified on disk.
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            archive = root / 'condenser-v21-starter.zip'
            payload = b'synthetic unit-test fixture, not an actual Blender file'
            with zipfile.ZipFile(archive, 'w') as writer:
                writer.writestr('nested/' + APPROVED_NAME, payload)
                writer.writestr('unrelated.txt', b'never extract this')
            import run_condenser_v22_review as module
            with patch.object(module, 'APPROVED_SHA', hashlib.sha256(payload).hexdigest()):
                source = resolve_source(archive, root / 'fresh-output')
                self.assertEqual(source.read_bytes(), payload)
                self.assertFalse((root / 'fresh-output/unrelated.txt').exists())
                self.assertEqual(file_hash(source), module.APPROVED_SHA)

    def test_discovery_uses_only_explicit_bounded_root(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            wrong = root / APPROVED_NAME
            wrong.write_bytes(b'wrong')
            self.assertEqual(list(candidates(root)), [wrong])
            with self.assertRaisesRegex(SourceBlocked, 'No exact SHA-verified'):
                find_approved(root)


if __name__ == '__main__':
    unittest.main()
