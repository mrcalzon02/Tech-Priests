"""Source-locked native Blender V22 condenser: sequential pistons and INWARD vapor.

Run from repository checkout with exact owner-accepted V21 .blend. No source
meshes, textures, sockets, base, or native Factorio prototypes are rewritten.
Only existing canister transforms, tiny upper-rack vibration, indicator effects
and reversible atmospheric inlet vapor curves are animated. Review stage only.
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

APPROVED_SHA = '1ccd8093e5b153d80b7ac66cb77b364f05e7ee46a5f236efe189498b71dd052b'
CANISTER_PREFIX = 'Condenser capped canister '
SEAT_PREFIX = 'Condenser dark canister seat '
DIRECTIONS = (0, 90, 180, 270)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def mesh_signatures(scene):
    """Hash EVERY original source mesh's local geometry/topology, including references.

    Animation changes transforms and FX curves only. Using mesh-local hashes
    prevents a moved cap from falsely appearing to mutate its actual geometry.
    """
    result = {}
    for obj in sorted((o for o in scene.objects if o.type == 'MESH'), key=lambda o: o.name):
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
    """Preserve source world transform, including the existing tile calibration."""
    world = obj.matrix_world.copy()
    obj.parent = new_parent
    obj.matrix_world = world


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


def vapor_material():
    mat = bpy.data.materials.new('FX ONLY | atmospheric vapor sucked toward open canister')
    mat.diffuse_color = (.64, .82, .84, .40)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.clear()
    links = mat.node_tree.links
    out = nodes.new('ShaderNodeOutputMaterial')
    transparent = nodes.new('ShaderNodeBsdfTransparent')
    transparent.inputs['Color'].default_value = (1, 1, 1, 1)
    glow = nodes.new('ShaderNodeEmission')
    glow.inputs['Color'].default_value = (.48, .67, .69, 1)
    glow.inputs['Strength'].default_value = .47
    mix = nodes.new('ShaderNodeMixShader')
    mix.inputs[0].default_value = .46
    links.new(transparent.outputs[0], mix.inputs[1])
    links.new(glow.outputs[0], mix.inputs[2])
    links.new(mix.outputs[0], out.inputs['Surface'])
    return mat


def vapor_curve(name, cap, seat, strand, collection, material):
    """A tapering atmospheric strand from OUTSIDE the head INTO its exposed seat.

    The path points travel from outer air to the seat mouth. Only its bevel
    limits animate, so the visible segment progresses inward (not outward).
    This is render FX, not a new machine pipe, valve, or water source.
    """
    bc = bbox(cap)
    bs = bbox(seat)
    c = center(cap)
    radius = max(.105, min(.175, max(max(p.x for p in bc) - min(p.x for p in bc),
                                   max(p.y for p in bc) - min(p.y for p in bc)) / 2))
    opening_z = max(p.z for p in bs) + .021
    top_z = max(p.z for p in bc)
    theta = 2 * math.pi * (strand / 3.0) + .19
    direction = Vector((math.cos(theta), math.sin(theta), 0))
    side = Vector((-direction.y, direction.x, 0))
    target = Vector((c.x, c.y, opening_z)) + direction * .026
    outer = Vector((c.x, c.y, top_z + .10)) + direction * (radius + .17)
    p1 = outer - direction * .060 + side * .025 + Vector((0, 0, .035))
    p2 = target + direction * (radius * .78) - side * .015 + Vector((0, 0, .085))
    points = (outer, p1, p2, target)
    data = bpy.data.curves.new(name, 'CURVE')
    data.dimensions = '3D'
    data.resolution_u = 18
    data.bevel_depth = .018
    data.bevel_resolution = 3
    data.resolution_u = 16
    data.bevel_factor_start = 0
    data.bevel_factor_end = 0
    data.materials.append(material)
    spline = data.splines.new('BEZIER')
    spline.bezier_points.add(3)
    for pt, pos, taper in zip(spline.bezier_points, points, (1.0, 1.10, .77, .22)):
        pt.co = pos
        pt.handle_left_type = 'AUTO'
        pt.handle_right_type = 'AUTO'
        pt.radius = taper
    obj = bpy.data.objects.new(name, data)
    collection.objects.link(obj)
    obj['FX_ONLY_INWARD_ATMOSPHERIC_INTAKE'] = True
    return obj


def profile():
    return {
        'camera_policy': POLICY_ID, 'capture_kind': 'entity',
        'directions': list(DIRECTIONS),
        'states': {'condenser_v22_preview': list(PREVIEW_FRAMES)},
        'source_size': 256,
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
    original_meshes = mesh_signatures(scene)
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
    material = vapor_material()
    streams = []
    for index, (cap, seat) in enumerate(zip(ordered_caps, matched)):
        strands = [vapor_curve('FX ONLY | inward vapor %02d.%d' % (index, j),
                               cap, seat, j, fx, material) for j in range(3)]
        streams.append(strands)
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
    scene.cycles.samples = 20
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
    scene.render.resolution_x = scene.render.resolution_y = 256
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
            start, end = inward_stream(frame, index)
            for strand in streams[index]:
                strand.data.bevel_factor_start = start
                strand.data.bevel_factor_end = end
                strand.data.keyframe_insert(data_path='bevel_factor_start', frame=frame)
                strand.data.keyframe_insert(data_path='bevel_factor_end', frame=frame)
        led = signals(frame)
        display.data.energy = led['lcd']
        display.data.keyframe_insert(data_path='energy', frame=frame)
        for label, (light, emission) in covers.items():
            light.data.energy = led[label] * .48
            light.data.keyframe_insert(data_path='energy', frame=frame)
            emission.default_value = led[label]
            emission.keyframe_insert(data_path='default_value', frame=frame)
    scene.frame_set(1)
    scene['model'] = 'Atmospheric Water Condenser'
    scene['model_source_revision'] = 'approved V21 unchanged'
    scene['model_source_sha256'] = APPROVED_SHA
    scene['animation_review_revision'] = 'V22 review-only candidate'
    scene['animation_protocol'] = '8 serial canister intake strokes / 12s loop / inward vapor'
    scene['piston_order'] = json.dumps(order)
    scene['vapor_strands'] = HEADS * 3
    scene['piston_stroke_scene_units'] = STROKE
    scene['native_game_art_modified'] = False
    scene['new_machine_geometry_count'] = 0
    scene['new_render_fx_curve_count'] = HEADS * 3
    if mesh_signatures(scene) != original_meshes:
        raise RuntimeError('Existing approved source mesh geometry/topology was modified')
    scene['source_mesh_local_sha256'] = json.dumps(original_meshes, sort_keys=True)
    scene['approved_source_mesh_count'] = len(original_meshes)
    scene['owner_visual_approved'] = False
    blend = out / 'condenser_v22_motion_review.blend'
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    renders = []

    def capture(filename, resolution):
        """Render a native frame at a declared resolution; always restore 256px."""
        scene.render.resolution_x = scene.render.resolution_y = resolution
        try:
            destination = out / filename
            scene.render.filepath = str(destination)
            bpy.ops.render.render(write_still=True)
            renders.append(destination)
        finally:
            scene.render.resolution_x = scene.render.resolution_y = 256

    for frame in PREVIEW_FRAMES:
        scene.frame_set(frame)
        capture('frame_%03d.png' % frame, 256)

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
            capture('direction_%03d_%s.png' % (degrees, state), 256)
            # 138px canvas / 3.20 tile view = 43.125px per Factorio tile.
            capture('game_scale_%03d_%s.png' % (degrees, state), 138)
        scene.frame_set(7)
        try:
            for strand in all_strands:
                strand.hide_render = True
            bpy.context.view_layer.update()
            capture('direction_%03d_no_vapor.png' % degrees, 256)
            capture('game_scale_%03d_no_vapor.png' % degrees, 138)
        finally:
            for strand in all_strands:
                strand.hide_render = False
            bpy.context.view_layer.update()
        try:
            for index, piston in enumerate(pistons):
                piston.delta_location.z = -head_lift(7, index)
            bpy.context.view_layer.update()
            capture('direction_%03d_no_piston.png' % degrees, 256)
            capture('game_scale_%03d_no_piston.png' % degrees, 138)
        finally:
            for piston in pistons:
                piston.delta_location.z = 0.0
            bpy.context.view_layer.update()
        if degrees == 0:
            # Duplicate of an unmodified active frame. Detect render-noise
            # artifacts before treating the pixel A/B differences as evidence.
            capture('direction_000_active_repeat.png', 256)
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
        'all_eight_heads_actuated': True, 'inward_vapor_fx_curves': HEADS * 3,
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
