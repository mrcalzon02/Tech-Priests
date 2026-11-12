"""Independent native Blender reopen: source-locked 8-head suction animation.

Run AFTER native builder writes temporal and cardinal review renders:
blender -b OUT/condenser_v22_motion_review.blend --python verify_condenser_v22.py -- --out OUT
"""
from __future__ import annotations
import argparse
import hashlib
import json
import struct
import sys
from pathlib import Path
import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]  # /repo/art/source-to-3d/condenser-v21 -> /repo
# Blender --python does not add this script's directory to sys.path on Windows.
# Make the approved sibling timing module visible without weakening source SHA gates.
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(ROOT / 'tools' / 'fmpl'))
from blender_camera_guard import assert_clean, camera_record
from capture_policy import POLICY_ID
from condenser_v22_timing import CYCLE, FPS, HEADS, PREVIEW_FRAMES, STROKE, head_lift, inward_stream, snake_order

APPROVED_SHA = '1ccd8093e5b153d80b7ac66cb77b364f05e7ee46a5f236efe189498b71dd052b'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def mesh_signatures(scene):
    result = {}
    for obj in sorted((o for o in scene.objects if o.type == 'MESH' and not o.get('FX_ONLY_INWARD_ATMOSPHERIC_INTAKE')), key=lambda o: o.name):
        mesh = obj.data
        digest = hashlib.sha256()
        digest.update(struct.pack('<II', len(mesh.vertices), len(mesh.polygons)))
        for vertex in mesh.vertices:
            digest.update(struct.pack('<fff', *vertex.co))
        for face in mesh.polygons:
            digest.update(struct.pack('<I', len(face.vertices)))
            for index in face.vertices:
                digest.update(struct.pack('<I', index))
        result[obj.name] = digest.hexdigest()
    return result


def center(obj):
    return sum((obj.matrix_world @ v.co for v in obj.data.vertices), Vector((0, 0, 0))) / len(obj.data.vertices)


def assert_near(a, b, eps=1e-6):
    if (a - b).length > eps:
        raise RuntimeError('Source-fixed mesh moved: ' + str((a - b).length))


def run(out):
    blend = out / 'condenser_v22_motion_review.blend'
    if not blend.is_file() or Path(bpy.data.filepath).resolve() != blend.resolve():
        raise RuntimeError('Must independently reopen the actual saved derivative .blend')
    scene = bpy.context.scene
    if (scene.get('model_source_sha256') != APPROVED_SHA or
            scene.get('native_game_art_modified') is not False or
            scene.get('animation_review_revision') != 'V22 review-only candidate' or
            scene.get('new_machine_geometry_count') != 0 or
            scene.get('new_render_fx_curve_count') != 0 or
            scene.get('new_render_fx_volume_count') != 0 or
            scene.get('new_render_fx_particle_count') != 40 or
            scene.get('mist_visual_revision') != 'V22C soft noisy Cycles mist particles, no glowing lines'):
        raise RuntimeError('Owner source / FX-only / game-art staging gate changed')
    locked_meshes = json.loads(scene.get('source_mesh_local_sha256', '{}'))
    if not locked_meshes or mesh_signatures(scene) != locked_meshes:
        raise RuntimeError('Original V21 mesh local geometry/topology not preserved')
    if scene.get('approved_source_mesh_count') != len(locked_meshes):
        raise RuntimeError('Source-geometry mesh count disagrees with source receipt')
    camera = {
        'camera_policy': POLICY_ID, 'capture_kind': 'entity',
        'directions': [0, 90, 180, 270],
        'states': {'condenser_v22_preview': list(PREVIEW_FRAMES)},
        'source_size': 256, 'camera_override': {
            'type': 'ORTHO', 'elevation_deg': 45, 'azimuth_deg': 0,
            'distance': 5.5, 'target': [0, 0, .55],
            'ortho_scale': 3.20, 'shift_x': 0, 'shift_y': 0,
        },
    }
    assert_clean(scene, camera, bpy)
    rack = bpy.data.objects.get('FX ONLY | mild condenser rack rumble')
    base = bpy.data.objects.get('Condenser shallow tapered foundation')
    outlet = bpy.data.objects.get('Water outlet end flange')
    turntable = bpy.data.objects.get('FX ONLY | entity export turntable')
    if not all((rack, base, outlet, turntable)):
        raise RuntimeError('Original foundation/outlet or V22 rack/rotation missing')
    if abs(turntable.rotation_euler.z) > 1e-7:
        raise RuntimeError('Saved native model must be canonical direction 0')
    caps = [o for o in scene.objects if o.type == 'MESH' and o.name.startswith('Condenser capped canister ')]
    seats = [o for o in scene.objects if o.type == 'MESH' and o.name.startswith('Condenser dark canister seat ')]
    vapor = [o for o in scene.objects if o.type == 'MESH' and o.get('FX_PROCEDURAL_MIST_PARTICLE')]
    old_lines = [o for o in scene.objects if o.type == 'CURVE' and o.get('FX_ONLY_INWARD_ATMOSPHERIC_INTAKE')]
    if old_lines:
        raise RuntimeError('Old beveled steam line curves must not survive V22B')
    if not all(any(m.get('PROCEDURAL_ALPHA_MIST_NOT_BEVEL_CURVE') for m in ob.data.materials) for ob in vapor):
        raise RuntimeError('Expected procedural soft mist particle material on every FX cloud')
    if len(caps) != HEADS or len(seats) != HEADS or len(vapor) != HEADS * 5:
        raise RuntimeError('Wrong original cap/seat or 3D mist puff counts')
    order = json.loads(scene['piston_order'])
    if len(order) != HEADS or set(order) != {o.name for o in caps}:
        raise RuntimeError('Not all original canisters have motion assignments')
    pistons = [bpy.data.objects.get('FX ONLY | piston %02d' % i) for i in range(HEADS)]
    if any(p is None for p in pistons):
        raise RuntimeError('Eight separately animated piston controls missing')
    if any(bpy.data.objects[cap].parent != pistons[i] or pistons[i].parent != rack
           for i, cap in enumerate(order)):
        raise RuntimeError('Original caps not parented to their independent piston controls')
    if any(seat.parent != rack for seat in seats):
        raise RuntimeError('Original canister seats are not mounted on rack controller')
    required = [out / ('frame_%03d.png' % f) for f in PREVIEW_FRAMES]
    required += [out / ('direction_%03d_%s.png' % (a, s)) for a in (0, 90, 180, 270)
                 for s in ('idle', 'active')]
    required += [out / ('game_scale_%03d_%s.png' % (a, s)) for a in (0, 90, 180, 270)
                 for s in ('idle', 'active')]
    required += [out / ('%s_%03d_%s.png' % (prefix, a, mode))
                 for a in (0, 90, 180, 270)
                 for mode in ('no_vapor', 'no_piston')
                 for prefix in ('direction', 'game_scale')]
    required += [out / 'direction_000_active_repeat.png',
                 out / 'game_scale_000_active_repeat.png']
    if any(not p.is_file() or p.stat().st_size < 1000 for p in required):
        raise RuntimeError('Missing real native Cycles review render')
    scene.frame_set(1)
    origin = center(base).copy()
    flange = center(outlet).copy()
    caps_at_start = [center(bpy.data.objects[name]).copy() for name in order]
    for i in range(HEADS):
        scene.frame_set(7 + i * 12)
        displacement = [center(bpy.data.objects[name]).z - caps_at_start[j].z
                        for j, name in enumerate(order)]
        if not STROKE * .97 <= displacement[i] <= STROKE * 1.03:
            raise RuntimeError('Individual cylinder did not rise at expected step ' + str(i))
        if any(abs(displacement[j]) > .02 for j in range(HEADS) if j != i):
            raise RuntimeError('Unscheduled canister also lifted')
        assert_near(center(base), origin)
        assert_near(center(outlet), flange)
        group = [o for o in vapor if o.name.startswith('FX ONLY | inward mist %02d.' % i)]
        if len(group) != 5 or sum(max(o.scale) > .01 for o in group) < 2:
            raise RuntimeError('Active head does not draw visible soft mist clouds inward')
        if any(max(o.scale) > .01 for o in vapor if o not in group):
            raise RuntimeError('Inactive head has visible mist')
    scene.frame_set(97)
    for i, name in enumerate(order):
        assert_near(center(bpy.data.objects[name]), caps_at_start[i])
    assert_near(center(base), origin)
    assert_near(center(outlet), flange)
    for obj in vapor:
        if max(obj.scale) > .0001:
            raise RuntimeError('Real mist failed to vanish at loop closure')
    result = {
        'verification': 'PASS', 'source_sha256': APPROVED_SHA,
        'sequential_independent_pistons': HEADS, 'volumetric_mist_puffs': len(vapor), 'beveled_steam_lines': 0,
        'period_frames': CYCLE, 'fps': FPS,
        'fx_ablation_captures': 16, 'repeatability_controls': 2,
        'approved_mesh_count_unmodified': len(locked_meshes),
        'foundation_stationary': True, 'pipe_flange_stationary': True,
        'camera': camera_record(scene),
        'actual_png_sha256': {p.name: sha(p) for p in required},
        'game_art_modified': False, 'owner_visual_approved': False,
    }
    (out / 'condenser_v22_native_readback.json').write_text(json.dumps(result, indent=2) + '\n')
    print('CONDENSER_V22_NATIVE_REOPEN_PASS', json.dumps({'caps': HEADS, 'renders': len(required)}), flush=True)


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--out', type=Path, required=True)
    args = p.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:])
    run(args.out.resolve())
