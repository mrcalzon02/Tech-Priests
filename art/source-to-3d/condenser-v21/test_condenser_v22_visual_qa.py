"""Pixel-QA unit tests using disposable synthetic PNGs, never art proofs."""
import tempfile
from pathlib import Path
import unittest
from PIL import Image
from condenser_v22_visual_qa import diff_count, occupancy, rgba


class PixelInspectorTest(unittest.TestCase):
    def test_requires_actual_png_and_exact_size(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            with self.assertRaisesRegex(RuntimeError, 'Missing'):
                rgba(root / 'no-render.png', (138, 138))
            img = Image.new('RGBA', (138, 138), (220, 210, 190, 255))
            path = root / 'one.png'
            img.save(path, compress_level=0)
            with self.assertRaisesRegex(RuntimeError, 'resolution'):
                rgba(path, (256, 256))

    def test_real_image_pixel_difference_is_measured_not_assumed(self):
        empty = Image.new('RGBA', (138, 138), (0, 0, 0, 0))
        visible = empty.copy()
        for x in range(30, 50):
            for y in range(40, 60):
                visible.putpixel((x, y), (180, 220, 230, 220))
        self.assertEqual(occupancy(empty), 0)
        self.assertEqual(occupancy(visible), 400)
        self.assertEqual(diff_count(empty, empty), 0)
        self.assertGreater(diff_count(empty, visible), 390)


if __name__ == '__main__':
    unittest.main()
