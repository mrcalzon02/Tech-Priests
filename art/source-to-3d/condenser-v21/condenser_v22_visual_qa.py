"""Inspect and assemble REAL Blender Cycles condenser V22 review renders.

This cannot manufacture source renders. It refuses absent PNGs, checks actual
pixels and emits a measured storyboard/GIF from the exact native frames.
It does not replace human approval of the 43.125px/tile Factorio-scale views.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, ImageFont

ANGLES = (0, 90, 180, 270)
STATES = ('idle', 'active')
FRAMES = tuple(range(1, 97, 6))
BG = (27, 30, 34, 255)
FG = (240, 237, 226, 255)
MUTED = (180, 195, 195, 255)


def digest(file: Path) -> str:
    h = hashlib.sha256()
    with file.open('rb') as src:
        for buf in iter(lambda: src.read(1024 * 1024), b''):
            h.update(buf)
    return h.hexdigest()


def rgba(file: Path, size: tuple[int, int]) -> Image.Image:
    if not file.is_file() or file.stat().st_size < 1000:
        raise RuntimeError('Missing/invalid actual Cycles render: ' + str(file))
    with Image.open(file) as raw:
        raw.verify()
    with Image.open(file) as raw:
        if raw.size != size:
            raise RuntimeError('Wrong native-render resolution for %s: %s != %s' %
                               (file, raw.size, size))
        return raw.convert('RGBA')


def on_dark(image: Image.Image) -> Image.Image:
    canvas = Image.new('RGBA', image.size, BG)
    canvas.alpha_composite(image)
    return canvas.convert('RGB')


def diff_count(a: Image.Image, b: Image.Image, floor: int = 10) -> int:
    a, b = on_dark(a), on_dark(b)
    difference = ImageChops.difference(a, b)
    channels = [channel.tobytes() for channel in difference.split()]
    return sum(max(pixel) >= floor for pixel in zip(*channels))


def occupancy(image: Image.Image) -> int:
    return sum(px >= 18 for px in image.getchannel('A').tobytes())


def font(size: int):
    try:
        return ImageFont.truetype('DejaVuSans.ttf', size)
    except OSError:
        return ImageFont.load_default()


def storyboard(out: Path, full: dict, native: dict) -> Path:
    canvas = Image.new('RGBA', (1430, 780), BG)
    draw = ImageDraw.Draw(canvas)
    draw.text((20, 13), 'CONDENSER V22 - ACTUAL BLENDER CYCLES | SOURCE-LOCKED', font=font(22), fill=FG)
    draw.text((20, 49), 'Left: full 256px | Right: true 43.125 px / tile capture on a 138px canvas', font=font(16), fill=MUTED)
    for j, angle in enumerate(ANGLES):
        x = 20 + (j % 2) * 708
        y = 85 + (j // 2) * 334
        draw.text((x, y), f'{angle:03d} deg | Idle / Intake', font=font(17), fill=FG)
        for k, state in enumerate(STATES):
            source = full[(angle, state)]
            canvas.alpha_composite(source, (x + k*258, y+36))
            small = native[(angle, state)]
            canvas.alpha_composite(small, (x+528, y+36+k*144))
    dest = out / 'Condenser_V22_Real_Blender_4_Directions_Proof.png'
    canvas.convert('RGB').save(dest)
    return dest


def animation(out: Path) -> Path:
    frames = []
    for frame in FRAMES:
        rendered = rgba(out / ('frame_%03d.png' % frame), (256, 256))
        panel = Image.new('RGB', (296, 304), BG[:3])
        panel.paste(on_dark(rendered), (20, 36))
        drawer = ImageDraw.Draw(panel)
        drawer.text((12, 8), f'ACTUAL Blender frame {frame:03d} / 096', font=font(15), fill=FG)
        frames.append(panel)
    dest = out / 'Condenser_V22_Real_Blender_Sequential_Intake.gif'
    frames[0].save(dest, save_all=True, append_images=frames[1:], duration=375,
                   loop=0, optimize=True)
    return dest


def inspect(out: Path) -> dict:
    full = {}
    native = {}
    metrics = {}
    for angle in ANGLES:
        for state in STATES:
            key = (angle, state)
            full[key] = rgba(out / ('direction_%03d_%s.png' % key), (256, 256))
            native[key] = rgba(out / ('game_scale_%03d_%s.png' % key), (138, 138))
        big_idle, big_active = full[(angle, 'idle')], full[(angle, 'active')]
        small_idle, small_active = native[(angle, 'idle')], native[(angle, 'active')]
        count_big = diff_count(big_idle, big_active)
        count_native = diff_count(small_idle, small_active)
        alpha_big = occupancy(big_idle)
        alpha_native = occupancy(small_idle)
        if alpha_big < 200 or alpha_native < 25:
            raise RuntimeError(f'No meaningful visible model at {angle} degrees')
        if count_big < 12:
            raise RuntimeError(f'No visible native Cycles active/idle motion at {angle} degrees')
        metrics[str(angle)] = {
            '256px_changed_pixels_10_of_255': count_big,
            '138px_changed_pixels_10_of_255': count_native,
            '256px_opaque_pixels': alpha_big,
            '138px_opaque_pixels': alpha_native,
            '138px_active_difference_detected': count_native > 4,
        }
    storyboard_file = storyboard(out, full, native)
    animation_file = animation(out)
    result = {
        'status': 'REAL_BLENDER_PIXEL_CHECK_COMPLETE',
        'human_visual_approval': 'PENDING',
        'full_size': 256, 'native_canvas_size': 138, 'pixels_per_tile': 138/3.20,
        'nominal_footprint_tiles': [2, 2],
        'native_capture_caveat': '138px ortho viewport samples 43.125 pixels/tile at 3.20 tile coverage. Nominal 2x2 footprint is 86.25px within canvas, but sprite crop/shift and prototype alignment still require review',
        'directions': metrics,
        'proofs': {p.name: digest(p) for p in [storyboard_file, animation_file]},
    }
    (out / 'condenser_v22_visual_qa.json').write_text(json.dumps(result, indent=2)+'\n')
    print('CONDENSER_V22_PIXEL_QA_COMPLETE', json.dumps(metrics), flush=True)
    return result


if __name__ == '__main__':
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument('--out', type=Path, required=True)
    args = cli.parse_args()
    inspect(args.out.resolve())
