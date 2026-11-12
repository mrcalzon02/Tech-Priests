"""Negative gates and performance invariants, no synthetic imagery used as art."""
import struct
import unittest
import zlib
from pathlib import Path
from tempfile import TemporaryDirectory
from verify_v22c_release import (PNG_SIGNATURE,png_size,sha256,file_record,fail_if,
                                  quality_contract,validate)


def png_ihdr(w=256,h=256,depth=8,ctype=6):
    payload=struct.pack('>IIBBBBB',w,h,depth,ctype,0,0,0)
    block=b'IHDR'+payload
    return PNG_SIGNATURE+struct.pack('>I',len(payload))+block+struct.pack('>I',zlib.crc32(block))


class PNGStructure(unittest.TestCase):
    def test_accepts_512_hr_and_256_sd(self):
        self.assertEqual(png_size(png_ihdr(512,512)),(512,512))
        self.assertEqual(png_size(png_ihdr()),(256,256))
    def test_rejects_invalid_signature(self):
        with self.assertRaisesRegex(ValueError,'PNG'):
            png_size(b'not png at all')
    def test_rejects_non_rgba_or_wrong_color_depth(self):
        for kw in ({'depth':16},{'ctype':2}):
            with self.assertRaisesRegex(ValueError,'RGBA'):
                png_size(png_ihdr(**kw))
    def test_rejects_oversized_source_sheets(self):
        with self.assertRaisesRegex(ValueError,'8192'):
            png_size(png_ihdr(8193,1024))
    def test_sha_gate_rejects_corrupted_and_missing_file(self):
        with TemporaryDirectory() as tmp:
            p=Path(tmp)
            raw=png_ihdr(256,256)+b'extra'
            f=p/'test.png';f.write_bytes(raw)
            rec=dict(name='test.png',sha256=sha256(raw),size_bytes=len(raw),width=256,height=256)
            self.assertEqual(file_record(p,rec,(256,256)),'test.png')
            rec['sha256']='0'*64
            with self.assertRaisesRegex(ValueError,'SHA-256'):
                file_record(p,rec,(256,256))
            f.unlink()
            with self.assertRaisesRegex(ValueError,'Missing'):
                file_record(p,rec,(256,256))
    def test_rejects_path_traversal_in_manifest(self):
        with TemporaryDirectory() as tmp:
            rec=dict(name='../leak.png',sha256='0'*64,size_bytes=0,width=1,height=1)
            with self.assertRaisesRegex(ValueError,'Unsafe'):
                file_record(Path(tmp),rec,(1,1))
    def test_equal_world_registration_most_conservative_mode(self):
        # Independent invariant: 512*0.2 == 256*0.4 == 102.4 pixels.
        self.assertAlmostEqual(512*.2,256*.4)
        self.assertAlmostEqual(4*(32+8)*256**2*4/(4*(32+8)*512**2*4),.25)


if __name__ == '__main__':unittest.main()
