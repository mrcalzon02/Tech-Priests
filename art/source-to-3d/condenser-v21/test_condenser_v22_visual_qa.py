"""Pixel-QA unit tests using disposable synthetic PNGs, never art proofs."""
import tempfile
from pathlib import Path
import unittest
from PIL import Image, ImageDraw
from condenser_v22_visual_qa import demand_effect, diff_count, inspect, occupancy, rgba


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

    @staticmethod
    def synthetic_controls(root: Path):
        """Unit fixtures only: never a rendered machine, never published as proof."""
        def make(size, *, piston=True, vapor=True):
            image = Image.new('RGBA', (size, size), (0, 0, 0, 0))
            scale = size / 256
            draw = ImageDraw.Draw(image)
            def rect(bounds, color):
                draw.rectangle(tuple(round(v * scale) for v in bounds), fill=color)
            rect((48, 67, 195, 202), (75, 72, 65, 255))
            if piston:
                rect((64, 59, 93, 70), (206, 173, 97, 255))
            if vapor:
                rect((68, 21, 83, 55), (138, 190, 197, 210))
            return image

        def save(path, image):
            image.save(path, compress_level=0)  # >1KB, like actual PNG gate

        for frame in range(1, 97, 3):
            save(root / f'frame_{frame:03d}.png', make(512))
        for a in (0, 90, 180, 270):
            for prefix, size in (('direction', 512), ('game_scale', 138)):
                for label, piston, vapor in (
                    ('idle', False, False), ('active', True, True),
                    ('no_vapor', True, False), ('no_piston', False, True)
                ):
                    save(root / f'{prefix}_{a:03d}_{label}.png',
                         make(size, piston=piston, vapor=vapor))
        save(root / 'direction_000_active_repeat.png', make(512))
        save(root / 'game_scale_000_active_repeat.png', make(138))

    def test_ablation_gate_rejects_missing_real_effect_even_if_idle_active_changes(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            self.synthetic_controls(root)
            # Active and idle still differ in the piston, but there is no
            # vapor-only image difference; this must NOT count as proof.
            (root / 'direction_000_no_vapor.png').write_bytes(
                (root / 'direction_000_active.png').read_bytes())
            with self.assertRaisesRegex(RuntimeError, 'vapor at 256px'):
                inspect(root)

    def test_ablation_gate_checks_both_effects_and_real_time_gif_timing(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            self.synthetic_controls(root)
            result = inspect(root)
            self.assertEqual(result['independent_effect_visibility_gates'], 'PASS')
            self.assertEqual(result['gif_cycle_duration_ms'], 12000)
            self.assertEqual(len(result['directions']), 4)
            self.assertEqual(len(result['proofs']), 3)
            self.assertTrue((root / 'Condenser_V22_Real_Blender_Effect_Isolation.png').is_file())
            self.assertGreater(result['directions']['180']['138px_vapor_only_changed'], 3)

    def test_demand_effect_includes_repeatability_noise(self):
        demand_effect(25, noise=0, minimum=16, label='steam')
        with self.assertRaisesRegex(RuntimeError, 'repeat-render noise'):
            demand_effect(25, noise=10, minimum=16, label='steam')

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
