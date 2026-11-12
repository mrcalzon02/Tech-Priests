"""Isolated packing tests. Colored synthetic test tiles NEVER used in production."""
from __future__ import annotations
import tempfile
import unittest
from pathlib import Path
from PIL import Image
from pack_condenser_v22_factorio import atlas, build_icon, digest, FRAMES, SCALE_HR, SCALE_STANDARD, FPS

class TestCondenserFactorioAtlas(unittest.TestCase):
    def test_exact_production_frame_cycle_and_scale(self):
        self.assertEqual(len(FRAMES),32)
        self.assertEqual(FRAMES[0],1)
        self.assertEqual(FRAMES[-1],94)
        self.assertAlmostEqual(32/(12*60),FPS/60)
        self.assertAlmostEqual(512*SCALE_HR,256*SCALE_STANDARD)
    def test_sheet_pixel_positions(self):
        colors=[(k*25,210-k*20,120+k,255) for k in range(8)]
        frames=[Image.new('RGBA',(512,512),c) for c in colors]
        image=atlas(frames,512)
        self.assertEqual(image.size,(2048,1024))
        for k,c in enumerate(colors):
            self.assertEqual(image.getpixel(((k%4)*512+250,(k//4)*512+250)),c)
        shrunk=atlas(frames,256)
        self.assertEqual(shrunk.size,(1024,512))
        for k,c in enumerate(colors):
            self.assertEqual(shrunk.getpixel(((k%4)*256+128,(k//4)*256+128)),c)
    def test_reject_wrong_frame_count(self):
        with self.assertRaises(ValueError):
            atlas([Image.new('RGBA',(512,512))]*7)
    def test_real_frame_sha_must_match_manifest(self):
        from pack_condenser_v22_factorio import open_real_frame
        with tempfile.TemporaryDirectory() as td:
            p=Path(td)/'sample.png';Image.new('RGBA',(512,512),(11,22,33,255)).save(p)
            with self.assertRaises(RuntimeError):
                open_real_frame(Path(td),{'path':'sample.png','sha256':'0'*64})
            frame=open_real_frame(Path(td),{'path':'sample.png','sha256':digest(p)})
            self.assertEqual(frame.size,(512,512))
    def test_icon_sized_and_padded(self):
        image=Image.new('RGBA',(512,512),(0,0,0,0))
        for x in range(170,310):
            for y in range(180,320): image.putpixel((x,y),(110,100,70,255))
        icon=build_icon(image)
        self.assertEqual(icon.size,(64,64))
        self.assertTrue(icon.getchannel('A').getbbox())

if __name__=='__main__':unittest.main()
