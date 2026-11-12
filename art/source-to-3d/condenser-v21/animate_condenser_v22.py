"""Source-locked native Blender V22 condenser: sequential pistons and INWARD soft procedural atmospheric mist.

Run from repository checkout with exact owner-accepted V21 .blend. No source
meshes, textures, sockets, base, or native Factorio prototypes are rewritten.
Only existing canister transforms, tiny upper-rack vibration, indicator effects
and inward-moving noisy mist particles are animated in real Blender Cycles. Review stage only.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import struct
import sys
from pathlib import Path

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
if not (ROOT / 'tools' / 'fmpl').is_dir():
    raise RuntimeError('Run in a Tech-Priests checkout with tools/fmpl available')
# Blender --python does not add this script's directory to sys.path on Windows.
# Make the approved sibling timing module visible without weakening source SHA gates.
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(ROOT / 'tools' / 'fmpl'))
from blender_camera_guard import install_canonical_camera, assert_clean, camera_record
from capture_policy import POLICY_ID
from condenser_v22_timing import CYCLE, FPS, HEADS, PREVIEW_FRAMES, STROKE, head_lift, inward_stream, signals, snake_order
from condenser_v22_mist_particles import PUFFS_PER_HEAD, REVIEW_RESOLUTION, mist_material, create_puff, pose as mist_pose

APPROVED_SHA = '1ccd8093e5b153d80b7ac66cb77b364f05e7ee46a5f236efe189498b71dd052b'
CANISTER_PREFIX = 'Condenser capped canister '
SEAT_PREFIX = 'Condenser dark canister seat '
DIRECTIONS = (0, 90, 180, 270)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def mesh_signatures(scene):
    """Hash EVERY original source mesh's local geometry/topology, including references.

    Animation changes transforms and effect-only mist particles only. Using mesh-local hashes
    prevents a moved cap from falsely appearing to mutate its actual geometry.
    """
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


def bbox(obj):
    return [obj.matrix_world @ Vector(p) for p in obj.bound_box]


def parent_preserve(obj, new_parent):
    """Preserve exact world matrix despite the source tile-calibration parent.

    An original Blender source mesh may carry matrix_parent_inverse from the
    former tile-calibration empty. Clear it when reparenting, compute the new
    inverse and preserve the complete evaluated world matrix.
    """
    world = obj.matrix_world.copy()
    obj.parent = new_parent
    obj.matrix_parent_inverse = new_parent.matrix_world.inverted()
    obj.matrix_basis = world
    bpy.context.view_layer.update()
    drift = max(abs(obj.matrix_world[row][col] - world[row][col])
                for row in range(4) for col in range(4))
    if drift > 1e-5:
        raise RuntimeError('Source world matrix shifted when reparenting '
                           + obj.name + ': ' + str(drift))


def new_empty(name, collection, position):
    obj = bpy.data.objects.new(name, None)
    collection.objects.link(obj)
    obj.location = position
    obj.empty_display_size = .025
    return obj


def new_light(name, position, rgb, collection):
    data = bpy.data.lights.new(name, 'POINT')
    data.color = rgb
    data.energy = 0
    data.shadow_soft_size = .045
    obj = bpy.data.objects.new(name, data)
    collection.objects.link(obj)
    obj.location = position + Vector((0, 0, .017))
    obj['FX_ONLY'] = True
    return obj


def indicator_emission(obj, rgb):
    """Overlay emission on a COPY of the existing material: no source changes."""
    if not obj.data.materials:
        raise RuntimeError('Approved indicator cover has no material: ' + obj.name)
    old = obj.data.materials[0]
    mat = old.copy()
    mat.name = 'FX ONLY | blinking ' + obj.name
    obj.data.materials[0] = mat
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    output = next((n for n in nodes if n.type == 'OUTPUT_MATERIAL'), None)
    if output is None or not output.inputs['Surface'].is_linked:
        raise RuntimeError('Existing diode material has no surface shader: ' + old.name)
    original = output.inputs['Surface'].links[0].from_socket
    add = nodes.new('ShaderNodeAddShader')
    emission = nodes.new('ShaderNodeEmission')
    emission.inputs['Color'].default_value = (*rgb, 1)
    emission.inputs['Strength'].default_value = 0
    links.new(original, add.inputs[0])
    links.new(emission.outputs[0], add.inputs[1])
    links.new(add.outputs[0], output.inputs['Surface'])
    return emission.inputs['Strength']


# V22C: no glowing curves or crashing Blender volume shader.
# Soft procedural Cycles mist particles are generated by condenser_v22_mist_particles.py.


def profile():
    return {
        'camera_policy': POLICY_ID, 'capture_kind': 'entity',
        'directions': list(DIRECTIONS),
        'states': {'condenser_v22_preview': list(PREVIEW_FRAMES)},
        'source_size': REVIEW_RESOLUTION,
        'camera_override': {
            'type': 'ORTHO', 'elevation_deg': 45, 'azimuth_deg': 0,
            'distance': 5.5, 'target': [0, 0, .55],
            'ortho_scale': 3.20, 'shift_x': 0, 'shift_y': 0,
        },
    }


def rotate_only_model(scene, fx):
    """Rotate every actual machine root, never the sole canonical 45deg camera.

    Existing parent chains remain intact. Reference pipes/grid and studio
    lights stay in place and are never captured as new machine geometry.
    """
    turntable = new_empty('FX ONLY | entity export turntable', fx, Vector((0, 0, 0)))
    excluded = {'REFERENCE_ADJACENT_PIPES', 'GRID', 'GROUND', 'GROUND_GRID'}
    for obj in list(scene.objects):
        if obj is turntable or obj.parent is not None or obj.type == 'CAMERA':
            continue
        if obj.name.startswith(('Reference pipe', 'Grid ', 'PIPE_FIT_', 'FMPL_CAPTURE_')):
            continue
        # Blender 5.2 bpy_prop_collection.__contains__ takes an object NAME, not an Object.
        if obj.type == 'LIGHT' and obj.name not in fx.objects:
            continue
        if any(c.name in excluded or c.name.startswith('REFERENCE_') for c in obj.users_collection):
            continue
        if obj.type in {'MESH', 'CURVE', 'EMPTY', 'LIGHT'}:
            parent_preserve(obj, turntable)
    return turntable


def run(source, out):
    source = source.resolve()
    if not source.is_file() or sha(source) != APPROVED_SHA:
        raise RuntimeError('Missing/mismatched owner-approved V21 native BLEND; no substitute allowed')
    out.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.open_mainfile(filepath=str(source))
    scene = bpy.context.scene
    scene.frame_set(1)
    bpy.context.view_layer.update()
    original_meshes = mesh_signatures(scene)
    original_world = {o.name: [list(row) for row in o.matrix_world]
                      for o in scene.objects if o.type == 'MESH'}
    caps = [o for o in scene.objects if o.type == 'MESH' and o.name.startswith(CANISTER_PREFIX)]
    seats = [o for o in scene.objects if o.type == 'MESH' and o.name.startswith(SEAT_PREFIX)]
    if len(caps) != HEADS or len(seats) != HEADS:
        raise RuntimeError('Original 8 source canisters/8 seats must be intact')
    for name in ('Condenser continuous central chassis', 'Condenser eight-seat rack body',
                 'Condenser inset display glass', 'Condenser right continuous side cheek',
                 'Condenser shallow tapered foundation', 'Water outlet end flange'):
        if bpy.data.objects.get(name) is None:
            raise RuntimeError('Approved V21 source missing required part ' + name)
    references = bpy.data.collections.get('REFERENCE_ADJACENT_PIPES')
    cam = profile()
    if references:
        references.hide_render = True
        for obj in references.objects:
            obj.hide_render = True
    install_canonical_camera(scene, cam, bpy)
    assert_clean(scene, cam, bpy)
    fx = bpy.data.collections.new('CONDENSER V22 | NON-PRODUCTION INTAKE FX')
    scene.collection.children.link(fx)
    order = snake_order([(o.name, center(o).x, center(o).y) for o in caps])
    ordered_caps = [bpy.data.objects[name] for name in order]
    unused_seats = seats.copy()
    matched = []
    for cap in ordered_caps:
        nearest = min(unused_seats, key=lambda s: (center(s).xy - center(cap).xy).length)
        if (center(nearest).xy - center(cap).xy).length > .30:
            raise RuntimeError('No matching approved seat under canister: ' + cap.name)
        matched.append(nearest)
        unused_seats.remove(nearest)
    rack = bpy.data.objects['Condenser eight-seat rack body']
    root = new_empty('FX ONLY | mild condenser rack rumble', fx, center(rack))
    # Only the removable rack/canister assembly vibrates. Chassis, outlet,
    # water pipe, foundation and external hoses NEVER change transform.
    for obj in [rack] + seats:
        parent_preserve(obj, root)
    pistons = []
    for index, cap in enumerate(ordered_caps):
        piston = new_empty('FX ONLY | piston %02d' % index, fx, center(cap))
        parent_preserve(piston, root)
        parent_preserve(cap, piston)
        pistons.append(piston)
    material = mist_material()
    streams = []
    for index, (cap, seat) in enumerate(zip(ordered_caps, matched)):
        clouds = [create_puff('FX ONLY | inward mist %02d.%d' % (index, j),
                              cap, seat, j, fx, material)
                  for j in range(PUFFS_PER_HEAD)]
        streams.append(clouds)
    lcd = bpy.data.objects['Condenser inset display glass']
    display = new_light('FX ONLY | existing LCD green flux', center(lcd), (.02, 1.0, .10), fx)
    covers = {}
    colors = {'red': (.95, .04, .01), 'amber': (1., .42, .03), 'green': (.08, 1., .04)}
    for label, color in colors.items():
        found = [o for o in scene.objects if o.name.startswith('Condenser ' + label + ' indicator')
                 and 'domed diode cover' in o.name]
        if len(found) != 1:
            raise RuntimeError('Source indicator cover mismatch for ' + label)
        light = new_light('FX ONLY | ' + label + ' existing diode', center(found[0]), color, fx)
        emission = indicator_emission(found[0], color)
        covers[label] = (light, emission)
    turntable = rotate_only_model(scene, fx)
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 48
    # Comparable A/B render probes must use the same per-frame sampling seed.
    # Random seed differences can otherwise look like vapor/piston pixels.
    if hasattr(scene.cycles, 'seed'):
        scene.cycles.seed = 27
    if hasattr(scene.cycles, 'use_animated_seed'):
        scene.cycles.use_animated_seed = False
    for view_layer in scene.view_layers:
        if hasattr(view_layer, 'cycles') and hasattr(view_layer.cycles, 'use_denoising'):
            view_layer.cycles.use_denoising = True
    scene.render.threads_mode = 'FIXED'
    scene.render.threads = 4
    scene.render.film_transparent = True
    scene.render.resolution_x = scene.render.resolution_y = REVIEW_RESOLUTION
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.frame_start, scene.frame_end, scene.render.fps = 1, CYCLE, FPS
    base = root.location.copy()
    piston_bases = [p.location.copy() for p in pistons]
    for frame in range(1, CYCLE + 2):
        wave = 2 * math.pi * ((frame - 1) % CYCLE) / CYCLE
        root.location = base + Vector((.0035 * math.sin(4 * wave),
                                       .0022 * (math.sin(5 * wave + .4) - math.sin(.4)),
                                       .0018 * math.sin(6 * wave)))
        root.rotation_euler.z = math.radians(.08) * math.sin(3 * wave)
        root.keyframe_insert(data_path='location', frame=frame)
        root.keyframe_insert(data_path='rotation_euler', frame=frame)
        for index, piston in enumerate(pistons):
            piston.location = piston_bases[index] + Vector((0, 0, head_lift(frame, index)))
            piston.keyframe_insert(data_path='location', frame=frame)
            for cloud in streams[index]:
                cloud.location, cloud.scale = mist_pose(frame, index, cloud, CYCLE)
                cloud.keyframe_insert(data_path='location', frame=frame)
                cloud.keyframe_insert(data_path='scale', frame=frame)
        led = signals(frame)
        display.data.energy = led['lcd']
        display.data.keyframe_insert(data_path='energy', frame=frame)
        for label, (light, emission) in covers.items():
            light.data.energy = led[label] * .48
            light.data.keyframe_insert(data_path='energy', frame=frame)
            emission.default_value = led[label]
            emission.keyframe_insert(data_path='default_value', frame=frame)
    scene.frame_set(1)
    bpy.context.view_layer.update()
    # Critical: the prior V22C render showed a floated top rack although
    # local mesh geometry hashes were unchanged. Check SOURCE WORLD SPACE,
    # not only mesh vertices, before saving or rendering any new evidence.
    errors = {}
    for name, matrix in original_world.items():
        obj = bpy.data.objects.get(name)
        if obj is None:
            errors[name] = 'missing original source object'
            continue
        delta = max(abs(obj.matrix_world[r][c] - matrix[r][c])
                    for r in range(4) for c in range(4))
        if delta > 1e-4:
            errors[name] = delta
    if errors:
        raise RuntimeError('Original V21 SOURCE WORLD TRANSFORMS MOVED: '
                           + json.dumps(dict(list(errors.items())[:15])))
    scene['source_world_matrices'] = json.dumps(original_world, sort_keys=True)
    scene['source_world_transform_guard'] = 'PASS'
    scene['model'] = 'Atmospheric Water Condenser'
    scene['model_source_revision'] = 'approved V21 unchanged'
    scene['model_source_sha256'] = APPROVED_SHA
    scene['animation_review_revision'] = 'V22 review-only candidate'
    scene['animation_protocol'] = '8 serial canister intake strokes / 12s loop / inward vapor'
    scene['piston_order'] = json.dumps(order)
    scene['procedural_mist_particle_count'] = HEADS * PUFFS_PER_HEAD
    scene['mist_visual_revision'] = 'V22C soft noisy Cycles mist particles, no glowing lines'
    scene['piston_stroke_scene_units'] = STROKE
    scene['native_game_art_modified'] = False
    scene['new_machine_geometry_count'] = 0
    scene['new_render_fx_curve_count'] = 0
    scene['new_render_fx_volume_count'] = 0
    scene['new_render_fx_particle_count'] = HEADS * PUFFS_PER_HEAD
    if mesh_signatures(scene) != original_meshes:
        raise RuntimeError('Existing approved source mesh geometry/topology was modified')
    scene['source_mesh_local_sha256'] = json.dumps(original_meshes, sort_keys=True)
    scene['approved_source_mesh_count'] = len(original_meshes)
    scene['owner_visual_approved'] = False
    blend = out / 'condenser_v22_motion_review.blend'
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    renders = []

    def capture(filename, resolution):
        """Render native Cycles at declared resolution; restore 512px."""
        scene.render.resolution_x = scene.render.resolution_y = resolution
        try:
            destination = out / filename
            scene.render.filepath = str(destination)
            bpy.ops.render.render(write_still=True)
            renders.append(destination)
        finally:
            scene.render.resolution_x = scene.render.resolution_y = REVIEW_RESOLUTION

    for frame in PREVIEW_FRAMES:
        scene.frame_set(frame)
        capture('frame_%03d.png' % frame, REVIEW_RESOLUTION)

    # Independent effect-isolation captures for each production direction:
    # ALL effects; no inward vapor; and cap not lifted (vapor unchanged).
    # Changing delta_location is a non-keyed additive render override and
    # NEVER alters original source vertices, native keyframes or saved model.
    all_strands = [strand for group in streams for strand in group]
    for degrees in DIRECTIONS:
        turntable.rotation_euler.z = math.radians(degrees)
        bpy.context.view_layer.update()
        for frame, state in ((1, 'idle'), (7, 'active')):
            scene.frame_set(frame)
            capture('direction_%03d_%s.png' % (degrees, state), REVIEW_RESOLUTION)
            # 138px canvas / 3.20 tile view = 43.125px per Factorio tile.
            capture('game_scale_%03d_%s.png' % (degrees, state), 138)
        scene.frame_set(7)
        try:
            for strand in all_strands:
                strand.hide_render = True
            bpy.context.view_layer.update()
            capture('direction_%03d_no_vapor.png' % degrees, REVIEW_RESOLUTION)
            capture('game_scale_%03d_no_vapor.png' % degrees, 138)
        finally:
            for strand in all_strands:
                strand.hide_render = False
            bpy.context.view_layer.update()
        try:
            for index, piston in enumerate(pistons):
                piston.delta_location.z = -head_lift(7, index)
            bpy.context.view_layer.update()
            capture('direction_%03d_no_piston.png' % degrees, REVIEW_RESOLUTION)
            capture('game_scale_%03d_no_piston.png' % degrees, 138)
        finally:
            for piston in pistons:
                piston.delta_location.z = 0.0
            bpy.context.view_layer.update()
        if degrees == 0:
            # Duplicate of an unmodified active frame. Detect render-noise
            # artifacts before treating the pixel A/B differences as evidence.
            capture('direction_000_active_repeat.png', REVIEW_RESOLUTION)
            capture('game_scale_000_active_repeat.png', 138)
    turntable.rotation_euler.z = 0
    bpy.context.view_layer.update()
    scene.frame_set(1)
    if any(not p.is_file() or p.stat().st_size < 1000 for p in renders):
        raise RuntimeError('Native Blender Cycles render missing/empty')
    manifest = {
        'model': 'condenser', 'candidate': 'V22 intake stroke study',
        'source_sha256': APPROVED_SHA, 'frame_count': len(PREVIEW_FRAMES),
        'fps': FPS, 'cycle_frames': CYCLE, 'piston_order': order,
        'all_eight_heads_actuated': True, 'procedural_mist_particles': HEADS * PUFFS_PER_HEAD, 'inward_vapor_fx_curves': 0,
        'source_machine_geometry_added': False, 'game_assets_changed': False,
        'directions_reviewed': list(DIRECTIONS), 'ablation_controls': ['no_vapor', 'no_piston'],
        'repeatability_control': 'direction_000_active_repeat.png',
        'game_scale_pixels_per_tile': 138 / 3.20,
        'game_scale_canvas_pixels': 138, 'nominal_2x2_footprint_pixels': 2 * (138 / 3.20),
        'camera': camera_record(scene),
        'render_sha256': {p.name: sha(p) for p in renders},
        'owner_visual_approval': 'PENDING',
    }
    (out / 'condenser_v22_motion_manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print('CONDENSER_V22_NATIVE_INTAKE_STUDY_READY', json.dumps({'renders': len(renders), 'source': APPROVED_SHA}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--source-blend', required=True, type=Path)
    parser.add_argument('--out', required=True, type=Path)
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:])
    run(args.source_blend, args.out)
