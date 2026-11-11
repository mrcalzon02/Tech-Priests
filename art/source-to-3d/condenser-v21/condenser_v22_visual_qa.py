"""Inspect and assemble REAL native Blender Cycles condenser V22 proof.

Require actual full/idle, 43.125 px/tile and effect-isolation renders.
No generated or fabricated images enter this path. Source geometry and shader
pixels must be independently observed before owner visual approval.
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
    # 16 evenly sampled frames represent the original 12 s / 96-frame cycle.
    # They are sparse hold samples, NOT a 2x-speed animation.
    frames[0].save(dest, save_all=True, append_images=frames[1:], duration=750,
                   loop=0, optimize=True)
    return dest



def isolation_sheet(out: Path, groups: dict) -> Path:
    """Show full-resolution and sprite-scale actual Blender effect controls."""
    canvas = Image.new('RGBA', (1260, 1450), BG)
    draw = ImageDraw.Draw(canvas)
    draw.text((18, 15), 'CONDENSER V22 | TRUE BLENDER A/B EFFECT ISOLATION', font=font(23), fill=FG)
    draw.text((18, 48), 'Each row: operating / no inward vapor / no piston lift', font=font(16), fill=MUTED)
    for index, angle in enumerate(ANGLES):
        y = 90 + index * 340
        draw.text((18, y), f'{angle:03d} degrees | full 256px (top), game-scale 138px (bottom)',
                  font=font(16), fill=FG)
        for i, mode in enumerate(('active', 'no_vapor', 'no_piston')):
            x = 18 + i * 413
            draw.text((x, y + 27), mode.replace('_', ' ').upper(), font=font(13), fill=MUTED)
            canvas.alpha_composite(groups[(angle, mode, 'direction')], (x, y + 45))
            canvas.alpha_composite(groups[(angle, mode, 'game_scale')], (x + 258, y + 45))
    dest = out / 'Condenser_V22_Real_Blender_Effect_Isolation.png'
    canvas.convert('RGB').save(dest)
    return dest


def demand_effect(count: int, noise: int, minimum: int, label: str) -> None:
    """Fail closed on effects that do not change actual pixels beyond noise."""
    threshold = max(minimum, 3 * noise + minimum)
    if count < threshold:
        raise RuntimeError(f'{label}: only {count} changed pixels, minimum {threshold} '
                           f'(repeat-render noise count {noise}); revise real Blender effect')


def inspect(out: Path) -> dict:
    full = {}
    native = {}
    controls = {}
    metrics = {}
    for angle in ANGLES:
        for state in STATES:
            key = (angle, state)
            full[key] = rgba(out / ('direction_%03d_%s.png' % key), (256, 256))
            native[key] = rgba(out / ('game_scale_%03d_%s.png' % key), (138, 138))
        controls[(angle, 'active', 'direction')] = full[(angle, 'active')]
        controls[(angle, 'active', 'game_scale')] = native[(angle, 'active')]
        for mode in ('no_vapor', 'no_piston'):
            for capture, size in (('direction', (256, 256)), ('game_scale', (138, 138))):
                path = out / ('%s_%03d_%s.png' % (capture, angle, mode))
                controls[(angle, mode, capture)] = rgba(path, size)

    # Under the fixed Cycles seed, rendering the identical 0-degree frame
    # twice must not create significant false differences from noise.
    repeated_full = rgba(out / 'direction_000_active_repeat.png', (256, 256))
    repeated_native = rgba(out / 'game_scale_000_active_repeat.png', (138, 138))
    repeat_full_noise = diff_count(full[(0, 'active')], repeated_full)
    repeat_native_noise = diff_count(native[(0, 'active')], repeated_native)
    if repeat_full_noise > 8 or repeat_native_noise > 3:
        raise RuntimeError('Non-repeatable native Blender render; cannot attribute pixel '
                           'changes to suction or pistons. Full/native changed pixel counts: '
                           f'{repeat_full_noise}/{repeat_native_noise}')

    for angle in ANGLES:
        big_idle, big_active = full[(angle, 'idle')], full[(angle, 'active')]
        small_idle, small_active = native[(angle, 'idle')], native[(angle, 'active')]
        count_big = diff_count(big_idle, big_active)
        count_native = diff_count(small_idle, small_active)
        alpha_big = occupancy(big_idle)
        alpha_native = occupancy(small_idle)
        if alpha_big < 200 or alpha_native < 25:
            raise RuntimeError(f'No meaningful visible machine at {angle} degrees')
        if count_big < 12:
            raise RuntimeError(f'No visible native Cycles idle/active motion at {angle} degrees')
        no_vapor_big = controls[(angle, 'no_vapor', 'direction')]
        no_vapor_small = controls[(angle, 'no_vapor', 'game_scale')]
        no_piston_big = controls[(angle, 'no_piston', 'direction')]
        no_piston_small = controls[(angle, 'no_piston', 'game_scale')]
        vapor_big = diff_count(big_active, no_vapor_big)
        vapor_small = diff_count(small_active, no_vapor_small)
        piston_big = diff_count(big_active, no_piston_big)
        piston_small = diff_count(small_active, no_piston_small)
        demand_effect(vapor_big, repeat_full_noise, 16, f'{angle}° vapor at 256px')
        demand_effect(piston_big, repeat_full_noise, 12, f'{angle}° piston at 256px')
        demand_effect(vapor_small, repeat_native_noise, 3, f'{angle}° vapor at 43px/tile')
        demand_effect(piston_small, repeat_native_noise, 3, f'{angle}° piston at 43px/tile')
        metrics[str(angle)] = {
            '256px_active_idle_changed': count_big,
            '138px_active_idle_changed': count_native,
            '256px_vapor_only_changed': vapor_big,
            '138px_vapor_only_changed': vapor_small,
            '256px_piston_only_changed': piston_big,
            '138px_piston_only_changed': piston_small,
            '256px_opaque_pixels': alpha_big,
            '138px_opaque_pixels': alpha_native,
        }
    storyboard_file = storyboard(out, full, native)
    isolation_file = isolation_sheet(out, controls)
    animation_file = animation(out)
    result = {
        'status': 'REAL_BLENDER_PIXEL_CHECK_COMPLETE',
        'human_visual_approval': 'PENDING',
        'full_size': 256, 'native_canvas_size': 138,
        'pixels_per_tile': 138 / 3.20,
        'nominal_footprint_tiles': [2, 2],
        'native_capture_caveat': '138px ortho viewport samples 43.125 pixels/tile over '
                                 '3.20 scene units, before actual sprite crop/shift and prototype alignment',
        'repeatability_control_changed_pixels': {
            '256px': repeat_full_noise, '138px': repeat_native_noise,
        },
        'independent_effect_visibility_gates': 'PASS',
        'gif_cycle_duration_ms': len(FRAMES) * 750,
        'gif_is_sampled_frames_not_full_native_96_frame_video': True,
        'directions': metrics,
        'proofs': {p.name: digest(p) for p in
                   [storyboard_file, isolation_file, animation_file]},
    }
    (out / 'condenser_v22_visual_qa.json').write_text(json.dumps(result, indent=2) + '\n')
    print('CONDENSER_V22_ABLATION_PIXEL_QA_PASS', json.dumps(metrics), flush=True)
    return result


if __name__ == '__main__':
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument('--out', type=Path, required=True)
    args = cli.parse_args()
    inspect(args.out.resolve())
