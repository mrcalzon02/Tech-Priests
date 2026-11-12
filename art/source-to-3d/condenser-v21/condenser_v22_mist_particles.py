"""V22C Blender procedural atmospheric mist particles (NOT glowing lines).

The first V22B Volume Principled GPU/CPU smoke shader provoked a native
Windows Blender 5.2.3 Cycles C++ crash on the approved runner. This replaces
it with a robust procedural UV-opacity cloud material on camera-facing
particle planes. All pixels are still rendered by real Blender Cycles.
Particle centers travel in actual 3D from outer air into each intake seat.
No old steam curve, image-generated texture, or replacement machine meshes.
"""
from __future__ import annotations
import math
import bpy
from mathutils import Vector

PUFFS_PER_HEAD = 5
REVIEW_RESOLUTION = 512


def mist_material():
    mat = bpy.data.materials.new('FX ONLY | V22C procedural drifting atmospheric mist')
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    nodes.clear()
    output = nodes.new('ShaderNodeOutputMaterial')
    coord = nodes.new('ShaderNodeTexCoord')
    noise = nodes.new('ShaderNodeTexNoise')
    noise.noise_dimensions = '3D'
    noise.inputs['Scale'].default_value = 8.5
    noise.inputs['Detail'].default_value = 3.0
    noise.inputs['Roughness'].default_value = .61
    links.new(coord.outputs['UV'], noise.inputs['Vector'])

    dist = nodes.new('ShaderNodeVectorMath')
    dist.operation = 'DISTANCE'
    dist.inputs[1].default_value = (.5, .5, 0)
    links.new(coord.outputs['UV'], dist.inputs[0])
    falloff = nodes.new('ShaderNodeMapRange')
    falloff.clamp = True
    falloff.interpolation_type = 'SMOOTHERSTEP'
    falloff.inputs['From Min'].default_value = .07
    falloff.inputs['From Max'].default_value = .495
    falloff.inputs['To Min'].default_value = .84
    falloff.inputs['To Max'].default_value = 0.0
    links.new(dist.outputs['Value'], falloff.inputs['Value'])

    fleck = nodes.new('ShaderNodeMapRange')
    fleck.clamp = True
    fleck.inputs['From Min'].default_value = .28
    fleck.inputs['From Max'].default_value = .70
    fleck.inputs['To Min'].default_value = .30
    fleck.inputs['To Max'].default_value = 1.0
    links.new(noise.outputs['Fac'], fleck.inputs['Value'])
    density = nodes.new('ShaderNodeMath')
    density.operation = 'MULTIPLY'
    links.new(falloff.outputs['Result'], density.inputs[0])
    links.new(fleck.outputs['Result'], density.inputs[1])

    transparent = nodes.new('ShaderNodeBsdfTransparent')
    pale = nodes.new('ShaderNodeEmission')
    pale.inputs['Color'].default_value = (.66, .81, .83, 1)
    pale.inputs['Strength'].default_value = .88
    mixed = nodes.new('ShaderNodeMixShader')
    links.new(density.outputs[0], mixed.inputs[0])
    links.new(transparent.outputs['BSDF'], mixed.inputs[1])
    links.new(pale.outputs['Emission'], mixed.inputs[2])
    links.new(mixed.outputs[0], output.inputs['Surface'])
    mat['FX_ONLY_NOT_MACHINE_HARDWARE'] = True
    mat['PROCEDURAL_ALPHA_MIST_NOT_BEVEL_CURVE'] = True
    return mat


def average_center(obj):
    return sum((obj.matrix_world @ v.co for v in obj.data.vertices),
               Vector((0, 0, 0))) / len(obj.data.vertices)


def create_puff(name, cap, seat, index, collection, material):
    box = [cap.matrix_world @ Vector(p) for p in cap.bound_box]
    seat_box = [seat.matrix_world @ Vector(p) for p in seat.bound_box]
    center = average_center(cap)
    width = max(max(p.x for p in box) - min(p.x for p in box),
                max(p.y for p in box) - min(p.y for p in box))
    radius = max(.105, min(.17, width * .5))
    angle = math.tau * index / PUFFS_PER_HEAD + .39
    radial = Vector((math.cos(angle), math.sin(angle), 0))
    outside = center + radial * (radius + .22) + Vector((0, 0, .18))
    inlet = Vector((center.x, center.y, max(p.z for p in seat_box) + .045))
    inlet += radial * .02

    # A noise-softened particle plane, continually facing the actual FMPL
    # capture camera regardless of the machine's cardinal export rotation.
    bpy.ops.mesh.primitive_plane_add(size=2)
    obj = bpy.context.object
    obj.name = name
    for previous in list(obj.users_collection):
        previous.objects.unlink(obj)
    collection.objects.link(obj)
    obj.data.materials.append(material)
    camera = bpy.context.scene.camera
    if camera is None or camera.data.type != 'ORTHO':
        raise RuntimeError('Canonical orthographic camera required for mist particle')
    constraint = obj.constraints.new('TRACK_TO')
    constraint.target = camera
    constraint.track_axis = 'TRACK_Z'
    constraint.up_axis = 'UP_Y'
    obj.location = outside
    obj.scale = (.00001, .00001, .00001)
    obj['FX_ONLY_INWARD_ATMOSPHERIC_INTAKE'] = True
    obj['FX_PROCEDURAL_MIST_PARTICLE'] = True
    obj['fx_origin'] = list(outside)
    obj['fx_destination'] = list(inlet)
    obj['mist_puff_index'] = index
    return obj


def pose(frame, head, obj, cycle=96):
    outside = Vector(obj['fx_origin'])
    inside = Vector(obj['fx_destination'])
    stage = (frame - 1) % cycle
    active_head = stage // 12
    phase = (stage % 12) / 12
    if active_head != head or phase <= .11 or phase >= .91:
        return outside, Vector((.00001, .00001, .00001))
    k = int(obj['mist_puff_index'])
    progress = (phase - .11) / .80
    progress = (progress - k * .10) / (1.0 - k * .10)
    if not 0 < progress < 1:
        return outside, Vector((.00001, .00001, .00001))
    eased = progress * progress * (3 - 2 * progress)
    fade = math.sin(math.pi * progress) ** .65
    loc = outside.lerp(inside, eased)
    loc.z += .046 * math.sin(math.pi * progress)
    width = (.14 + .025 * math.cos(k * 2.4)) * fade
    return loc, Vector((width, width * .85, width))
