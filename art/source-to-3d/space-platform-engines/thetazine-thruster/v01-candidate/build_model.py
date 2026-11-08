"""Fit the shared source-sprite engine construction to Thetazine's own 5x5 frame.

This creates a separately editable candidate, not a runtime sprite replacement.
Keep the input model and references at their recorded exact hashes.
"""
import argparse, bpy, hashlib, json, math, pathlib, sys
from mathutils import Vector, Matrix

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--source', type=pathlib.Path, required=True)
p.add_argument('--reference-idle', type=pathlib.Path, required=True)
p.add_argument('--reference-run', type=pathlib.Path, required=True)
p.add_argument('--contract', type=pathlib.Path, required=True)
p.add_argument('--out', type=pathlib.Path, required=True)
a = p.parse_args(sys.argv[sys.argv.index('--') + 1:])
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
contract = json.loads(a.contract.read_text(encoding='utf-8'))
assert sha(a.source) == '396690cccd81487d1bb2a8e05325a3ccbfc0c52e72332449f10bb8fe567fc27e'
for path, key in [(a.reference_idle, 'idle'), (a.reference_run, 'run')]:
    assert sha(path) == contract['reference_sha256'][key]
assert contract['shared_upper_body_alpha_iou_over_128'] > .9997
out = a.out.resolve(); out.mkdir(parents=True, exist_ok=False)
bpy.ops.wm.open_mainfile(filepath=str(a.source.resolve()))
s = bpy.context.scene; s.frame_set(0)
parts_before = {o.name: len(o.data.polygons) for o in s.objects if o.type == 'MESH'}
old_necks = []; changed = []; factor = 1.25
for o in list(s.objects):
    if o.type != 'MESH':
        continue
    name = o.name
    if name.endswith('routed supply neck'):
        old_necks.append(name); bpy.data.objects.remove(o, do_unlink=True); continue
    socket_group = next((n for n in ['fuel', 'oxidizer'] if name.startswith(n + ' socket flange') or name.startswith(n + ' closed seat') or name.startswith(n + ' flange fastener')), None)
    world = o.matrix_world.copy()
    if socket_group:
        sign = -1 if socket_group == 'fuel' else 1
        shift = Vector((sign * .5, .5, 0))
        o.matrix_world = Matrix.Translation(shift) @ world
        changed.append({'name': name, 'operation': 'translate standard pipe fitting, retain bore and bolt circle', 'delta': list(shift)})
    else:
        o.matrix_world = Matrix.Scale(factor, 4) @ world
assert len(old_necks) == 2
A = Vector((0, -math.cos(math.radians(25)), -math.sin(math.radians(25))))
B = Vector((0, A.z, -A.y)); O = Vector((0, .35, .2))
routes = []
for identity, sign, fluid in [('fuel', -1, 'thetazine-fuel'), ('oxidizer', 1, 'water')]:
    position = Vector((sign * 2.5, 1, .36))
    socket = bpy.data.objects['socket_' + identity]; socket.location = position
    socket['fluid'] = fluid; socket['native_pipe_cell_xy'] = [sign * 2, -1]
    socket['native_mating_xy'] = [sign * 2.5, -1]
    socket['coordinate_frame'] = '+X east, +Y fore/platform, +Z up; visual height .36 pending native jig'
    end = (O + A * -.63 + Vector((sign * .83, 0, 0)) + B * .06) * factor
    points = [position - Vector((sign * .20, 0, 0)), Vector((sign * 1.92, 1, .36)), Vector((sign * 1.47, 1.02, .57)), end]
    curve = bpy.data.curves.new(identity + ' 5x5 routed neck', 'CURVE'); curve.dimensions = '3D'
    curve.resolution_u = 12; curve.bevel_depth = .175; curve.bevel_resolution = 3
    spline = curve.splines.new('BEZIER'); spline.bezier_points.add(len(points) - 1)
    for v, co in zip(spline.bezier_points, points): v.co = co; v.handle_left_type = 'AUTO'; v.handle_right_type = 'AUTO'
    obj = bpy.data.objects.new(curve.name, curve); s.collection.objects.link(obj); obj.data.materials.append(bpy.data.materials['Hydrogen tank'])
    bpy.context.view_layer.objects.active = obj; obj.select_set(True)
    for other in s.objects:
        if other != obj: other.select_set(False)
    bpy.ops.object.convert(target='MESH')
    obj = bpy.context.object; uv = obj.data.uv_layers.active
    assert uv is not None
    # Match the established cylindrical tile density on the larger supply tube.
    for loop in uv.data: loop.uv *= 1.25
    routes.append({'name': obj.name, 'centerline': [list(v) for v in points], 'radius': .175, 'flange_overlap': .04, 'body_end': list(end)})

# Preserve the shared cast/tank/bell PBR finish; do not relabel it as newly authored maps.
# The source sheets have two idle and two run rectangles, with changing light/plume.
glow = bpy.data.materials['Hydrogen inner bell thermal blue']
glow.node_tree.animation_data_clear()
bs = glow.node_tree.nodes.get('Principled BSDF')
for frame, strength in [(0, 1.1), (1, 1.25), (16, 2.4), (17, 3.1)]:
    bs.inputs['Emission Strength'].default_value = strength
    bs.inputs['Emission Strength'].keyframe_insert('default_value', frame=frame)
s['asset'] = 'Thetazine V01 separately editable 5x5 model candidate'
s['runtime_status'] = 'Not installed; native visual jig, full source-state capture, plume/glow/shadow export and integration remain open'
s['surface_plan'] = 'Shared source construction: same cast beam, steel canisters, brass fittings and heat-worn bell maps. Existing UV regions preserve grain and circumferential/axial seam direction. New supply necks use cylindrical UVs. Common fabrication is intentional; no map renaming or recolor uniqueness claim.'
target = Vector((0, -1.625, -.625)); s.camera.location = target + Vector((0, -15, 15))
s.camera.rotation_euler = (target - s.camera.location).to_track_quat('-Z', 'Y').to_euler()
s.camera.data.ortho_scale = 11.25
s.render.resolution_x = 512; s.render.resolution_y = 768
s.render.threads_mode = 'FIXED'; s.render.threads = 2; s.cycles.device = 'CPU'; s.cycles.samples = 16
s.frame_start = 0; s.frame_end = 17; s.frame_set(0)
for light in [o for o in s.objects if o.type == 'LIGHT']:
    light.location *= factor; light.data.energy *= factor * factor; light.data.size *= factor
bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=str(out / 'thetazine-thruster-v01.blend'), compress=True)
for o in s.objects: o.select_set(o.type == 'MESH' or o.name.startswith('socket_'))
bpy.ops.export_scene.gltf(filepath=str(out / 'thetazine-thruster-v01.glb'), use_selection=True, export_format='GLB', export_apply=True, export_animations=False, export_extras=True)
report = {'status': 'MODELED_CANDIDATE_NATIVE_INTEGRATION_OPEN', 'builder_sha256': sha(pathlib.Path(__file__)), 'input_model_sha256': sha(a.source), 'reference_sha256': contract['reference_sha256'], 'source_contract_sha256': sha(a.contract), 'mesh_count': len([o for o in s.objects if o.type == 'MESH']), 'triangles': sum(len(o.data.polygons) if all(len(p.vertices)==3 for p in o.data.polygons) else sum(len(p.vertices)-2 for p in o.data.polygons) for o in s.objects if o.type == 'MESH'), 'retained_body_scale': factor, 'standard_fitting_changes': changed, 'new_supply_routes': routes, 'source_states': {'idle': [0,1], 'run': [16,17]}, 'states_scope': 'Source emission controls only; no mechanical deformation or plume animation acceptance. Static cold/hot GLB snapshot exports current frame only.', 'native_sha256': sha(out / 'thetazine-thruster-v01.blend'), 'glb_sha256': sha(out / 'thetazine-thruster-v01.glb'), 'shared_surface_plan': s['surface_plan'], 'prior_meshes': len(parts_before)}
(out / 'source-manifest.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8',newline='\n')
print('THETAZINE_MODELED', report['mesh_count'], report['triangles'], flush=True)
