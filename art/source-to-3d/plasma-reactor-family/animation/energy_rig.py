"""Rig the approved reactor meshes in place. All playback data is native to Blender."""
from math import atan2, exp, floor, tau

import bmesh
import bpy
from mathutils import Matrix, Vector


PORT_COUNTS = (10, 12, 16)
DARK_GLASS = (0.0045, 0.012, 0.017)
HOT_LENS = (0.60, 0.95, 1.00)


def port_pulse(frame, index, count, period=96):
    """Clockwise viewed from the inspection face. Its head has a distinct trailing edge."""
    at = (index + 0.5) / count
    head = 0.25 - (frame - 1) / period
    behind = (at - head + 0.5) % 1.0 - 0.5
    width = 0.120 if behind >= 0 else 0.043
    return exp(-(behind / width) ** 2)


def _property_driver(target, path, index, scene, expression, pulse_material=None):
    fc = target.driver_add(path, index) if index is not None else target.driver_add(path)
    driver = fc.driver
    variables = [('p', 'SCENE', scene, '["reactor_power"]')]
    if pulse_material:
        variables.append(('a', 'MATERIAL', pulse_material, '["fmpl_pulse"]'))
    for name, kind, source, data_path in variables:
        variable = driver.variables.new()
        variable.name = name
        variable.targets[0].id_type = kind
        variable.targets[0].id = source
        variable.targets[0].data_path = data_path
    driver.expression = expression
    return fc


def _energize_material(mat, scene, chase=False):
    """Switch both luminous output and the albedo of the cold inspection glass."""
    shader = mat.node_tree.nodes.get('Principled BSDF')
    if shader is None:
        raise ValueError(f'{mat.name} has no Principled material')
    base = shader.inputs['Base Color']
    strength = shader.inputs['Emission Strength']
    emission = shader.inputs['Emission Color']
    original = tuple(base.default_value)[:3]
    value = strength.default_value
    mat['fmpl_lit_color'] = list(original)
    mat['fmpl_lit_strength'] = value
    mat['fmpl_powered'] = True
    variable = mat if chase else None
    for i, (dark, on) in enumerate(zip(DARK_GLASS, original)):
        extra = f'+{HOT_LENS[i] - on:.8f}*a' if chase else ''
        expr = f'{dark:.8f}+p*({on-dark:.8f}{extra})'
        _property_driver(base, 'default_value', i, scene, expr, variable)
        _property_driver(mat, 'diffuse_color', i, scene, expr, variable)
        if chase:
            _property_driver(emission, 'default_value', i, scene,
                             f'{on:.8f}{extra}', variable)
    extra = '+4.6*a' if chase else ''
    _property_driver(strength, 'default_value', None, scene, f'p*({value:.8f}{extra})', variable)


def _port_material(name, original, index, count, period, scene):
    mat = original.copy()
    mat.name = f'{name} | port {index + 1:02}'
    # Only the backing of this specific cut-through slot uses this pulse action.
    mat['fmpl_port_index'] = index
    mat['fmpl_port_count'] = count
    mat['fmpl_pulse'] = 0.0
    mat.id_properties_ui('fmpl_pulse').update(min=0.0, max=1.0,
                                              description='Passage of the clockwise induction pulse')
    for frame in range(1, period + 2):
        mat['fmpl_pulse'] = port_pulse(frame, index, count, period)
        mat.keyframe_insert(data_path='["fmpl_pulse"]', frame=frame, group='Induction pulse')
    action = mat.animation_data.action
    action.name = f'{name} | clockwise pulse · port {index + 1:02}'
    curves = action.fcurves if hasattr(action, 'fcurves') else action.layers[0].strips[0].channelbag(mat.animation_data.action_slot).fcurves
    curve = next(fc for fc in curves if fc.data_path == '["fmpl_pulse"]')
    for point in curve.keyframe_points:
        point.interpolation = 'LINEAR'
    curve.modifiers.new('CYCLES')
    _energize_material(mat, scene, chase=True)
    return mat


def _assembly(collection, label):
    return next(ob for ob in collection.objects if ob.get('assembly') == label)


def _stage_ports(scene, collection, tier, radius, period):
    flange = _assembly(collection, 'Perforated containment flange')
    mesh = flange.data
    source_slot = next(i for i,m in enumerate(mesh.materials) if m.name == 'Plasma')
    original = mesh.materials[source_slot]
    # A clean copy keeps the approved daylight finish available as the reference
    # even after the shared plasma material has acquired the on/off driver.
    template = bpy.data.materials.get('FMPL | Original annular lens')
    if template is None:
        template = original.copy()
        template.name = 'FMPL | Original annular lens'
    count = PORT_COUNTS[tier - 1]
    first = len(mesh.materials)
    for i in range(count):
        mesh.materials.append(_port_material(collection.name, template, i, count, period, scene))
    occupied = set()
    for face in mesh.polygons:
        if face.material_index != source_slot:
            continue
        center = face.center
        angle = atan2(center.z - 1.15 * radius, center.x) % tau
        index = floor(angle / tau * count) % count
        face.material_index = first + index
        occupied.add(index)
    if len(occupied) != count:
        raise ValueError(f'{collection.name} has only {len(occupied)} of {count} port sectors')
    flange['fmpl_port_count'] = count
    flange['fmpl_chase'] = 'Clockwise from the front inspection face'


def _trim_mesh(obj, selected, retain_selected):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    unwanted = [v for v in bm.verts if (v.index in selected) != retain_selected]
    bmesh.ops.delete(bm, geom=unwanted, context='VERTS')
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()


def _driven_rotor(scene, collection, root, assembly, prefixes, name, pivot, axis, period, turns=1.0):
    housing = _assembly(collection, assembly)
    groups = {g.index for g in housing.vertex_groups if g.name.startswith(prefixes)}
    verts = {v.index for v in housing.data.vertices if any(w.group in groups for w in v.groups)}
    if not verts or len(verts) == len(housing.data.vertices):
        raise ValueError(f'{name} needs separate moving and stationary components')
    runner = housing.copy()
    runner.data = housing.data.copy()
    runner.name = f'{collection.name} | {name}'
    runner.data.name = runner.name
    collection.objects.link(runner)
    runner.parent = root
    _trim_mesh(runner, verts, True)
    _trim_mesh(housing, verts, False)
    runner.data.transform(Matrix.Translation(-pivot))
    runner.location = pivot
    runner.rotation_mode = 'AXIS_ANGLE'
    runner.rotation_axis_angle = (0.0, *axis.normalized())
    runner['assembly'] = name
    runner['fmpl_role'] = 'driven_rotor'
    runner['fmpl_axis'] = list(axis.normalized())
    runner['fmpl_pivot'] = list(pivot)
    runner['fmpl_turns_per_loop'] = turns
    _property_driver(runner, 'rotation_axis_angle', 0, scene, f'p*{tau*turns:.12f}*((frame-1)%{period})/{period}')
    return runner


def apply(scene, collection, tier, r, root, period=96):
    """Called once per tier on the approved unrigged scene. The scene master is 0–1."""
    if root.get('fmpl_energy_rig'):
        raise ValueError(f'{root.name} already has an energy rig')
    if 'reactor_power' not in scene:
        scene['reactor_power'] = 1.0
    scene.id_properties_ui('reactor_power').update(min=0, max=1, soft_min=0, soft_max=1,
                                                  description='Reactor family power: 0 idle, 1 online')
    _stage_ports(scene, collection, tier, r, period)
    for m in list(bpy.data.materials):
        if m.name in {'Plasma','Plasma Hot','Plasma Dim','Amber'} and not m.get('fmpl_powered'):
            _energize_material(m, scene)
    impeller = _driven_rotor(scene, collection, root, 'Helical plasma impeller',
                            ('Fluted plasma blades','Recessed impeller shroud'),
                            'Containment impeller', Vector((0,-0.21*r,1.15*r)),
                            Vector((0,1,0)), period, turns=2.0/(8,9,11)[tier-1])
    turbine_radius = (0.275, 0.314, 0.348)[tier - 1]
    turbine = _driven_rotor(scene, collection, root, '06 | Turbine runner, shaft and inlet ring',
                           ('Twisted compressor blade','Blade leading edge','Impeller shaft',
                            'Hub band','Stepped hub','Retaining nut'),
                           'Extraction turbine runner',
                           Vector((1.235*r,-0.452*r,(0.25+turbine_radius)*r)),
                           Vector((0.470,-0.882666200,0)), period)
    for rotor in (impeller,turbine):
        rotor['fmpl_period'] = period
    root['fmpl_energy_rig'] = 'Clockwise annular pulse and independently pivoted shafts'
    return impeller, turbine
