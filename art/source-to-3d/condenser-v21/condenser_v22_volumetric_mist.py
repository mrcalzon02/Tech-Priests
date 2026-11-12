"""V22B genuine noisy 3D *volume* mist; no glowing lines, tube meshes or billboards.

Each approved condenser intake cap pulls multiple soft turbulent volume puffs
from the surrounding atmosphere into its mouth. This module creates FX ONLY
volume boundaries; it never rebuilds or edits a source-machine mesh.
"""
from __future__ import annotations
import math
import bpy
from mathutils import Vector

PUFFS_PER_HEAD = 5
FX_NAME = "FX ONLY | inward volume mist"
REVIEW_RESOLUTION = 512


def mist_material():
    """A heterogeneous Volume Principled shader with spherical feathering."""
    mat = bpy.data.materials.new("FX ONLY | V22B irregular atmospheric mist VOLUME")
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    texture = nodes.new("ShaderNodeTexCoord")
    noise = nodes.new("ShaderNodeTexNoise")
    noise.noise_dimensions = "3D"
    noise.inputs["Scale"].default_value = 5.1
    noise.inputs["Detail"].default_value = 3.2
    noise.inputs["Roughness"].default_value = 0.61
    links.new(texture.outputs["Generated"], noise.inputs["Vector"])

    # Spherical falloff ensures the light-scattering region softens to nothing
    # before hitting the mesh boundary. Noise breaks up featureless spheres.
    radius = nodes.new("ShaderNodeVectorMath")
    radius.operation = "DISTANCE"
    radius.inputs[1].default_value = (.5, .5, .5)
    links.new(texture.outputs["Generated"], radius.inputs[0])
    fade = nodes.new("ShaderNodeMapRange")
    fade.clamp = True
    fade.inputs["From Min"].default_value = .13
    fade.inputs["From Max"].default_value = .51
    fade.inputs["To Min"].default_value = 1.0
    fade.inputs["To Max"].default_value = 0.0
    links.new(radius.outputs["Value"], fade.inputs["Value"])
    turb = nodes.new("ShaderNodeMapRange")
    turb.clamp = True
    turb.inputs["From Min"].default_value = .30
    turb.inputs["From Max"].default_value = .70
    turb.inputs["To Min"].default_value = .15
    turb.inputs["To Max"].default_value = 1.1
    links.new(noise.outputs["Fac"], turb.inputs["Value"])

    product = nodes.new("ShaderNodeMath")
    product.operation = "MULTIPLY"
    links.new(fade.outputs["Result"], product.inputs[0])
    links.new(turb.outputs["Result"], product.inputs[1])
    density = nodes.new("ShaderNodeMath")
    density.operation = "MULTIPLY"
    density.inputs[1].default_value = 8.0
    links.new(product.outputs[0], density.inputs[0])

    volume = nodes.new("ShaderNodeVolumePrincipled")
    volume.inputs["Color"].default_value = (.72, .83, .86, 1.0)
    volume.inputs["Anisotropy"].default_value = .18
    volume.inputs["Emission Color"].default_value = (.62, .78, .82, 1.0)
    volume.inputs["Emission Strength"].default_value = .065
    links.new(density.outputs[0], volume.inputs["Density"])
    links.new(volume.outputs["Volume"], output.inputs["Volume"])
    mat["FX_ONLY_NOT_MACHINE_HARDWARE"] = True
    mat["VOLUME_RENDER_NOT_BEVEL_CURVE"] = True
    return mat


def average_center(obj):
    return sum((obj.matrix_world @ v.co for v in obj.data.vertices),
               Vector((0, 0, 0))) / len(obj.data.vertices)


def create_puff(name, cap, seat, index, collection, material):
    """Build an actual closed mesh volume and two fixed world-space endpoints."""
    cap_box = [cap.matrix_world @ Vector(p) for p in cap.bound_box]
    seat_box = [seat.matrix_world @ Vector(p) for p in seat.bound_box]
    center = average_center(cap)
    horizontal_extent = max(
        max(v.x for v in cap_box) - min(v.x for v in cap_box),
        max(v.y for v in cap_box) - min(v.y for v in cap_box))
    radius = max(.105, min(.17, horizontal_extent * .5))
    angle = math.tau * index / PUFFS_PER_HEAD + .39
    direction = Vector((math.cos(angle), math.sin(angle), 0))
    outside = center + direction * (radius + .22) + Vector((0, 0, .18))
    inlet = Vector((center.x, center.y, max(p.z for p in seat_box) + .045))
    inlet += direction * .02
    # UV spheres are merely closed volume boundaries: shading comes from
    # Blender's shader-volume output, not a solid surface or a shiny wire.
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=1)
    obj = bpy.context.object
    obj.name = name
    for group in list(obj.users_collection):
        group.objects.unlink(obj)
    collection.objects.link(obj)
    obj.data.materials.append(material)
    obj.location = outside
    obj.scale = (.00001, .00001, .00001)
    obj["FX_ONLY_INWARD_ATMOSPHERIC_INTAKE"] = True
    obj["FX_REAL_VOLUME_MIST"] = True
    obj["fx_origin"] = list(outside)
    obj["fx_destination"] = list(inlet)
    obj["mist_puff_index"] = index
    return obj


def pose(frame, head, obj, cycle=96):
    """Draw soft, staggered clouds inward; inactive heads are truly invisible."""
    outside = Vector(obj["fx_origin"])
    inside = Vector(obj["fx_destination"])
    phase_id = (frame - 1) % cycle
    head_id = phase_id // 12
    step = (phase_id % 12) / 12.0
    if head_id != head or step <= .11 or step >= .91:
        return outside, Vector((.00001, .00001, .00001))
    puff_index = int(obj["mist_puff_index"])
    progress = (step - .11) / .80
    progress = (progress - puff_index * .10) / (1.0 - puff_index * .10)
    if not 0 < progress < 1:
        return outside, Vector((.00001, .00001, .00001))
    eased = progress * progress * (3 - 2 * progress)
    fade = math.sin(math.pi * progress) ** .65
    position = outside.lerp(inside, eased)
    position.z += .046 * math.sin(math.pi * progress)
    radius = (.115 + .012 * math.cos(puff_index * 2.4)) * fade
    return position, Vector((radius, radius * .90, radius * 1.20))
