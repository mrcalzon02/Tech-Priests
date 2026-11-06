"""Editable Blender v0.2 scene: imported independently modeled bunker meshes.

Repro: blender -b --factory-startup --python-exit-code 12 setup_blender.py
Optional --render: save diagnostic renders for front and rear of model.
"""
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

D = Path(__file__).resolve().parent
MODEL = D / 'martian_heavy_weapon_bunker_blockout_v02.glb'
M = json.loads((D / 'component_manifest_v02.json').read_text())
assert MODEL.is_file() and M['parts_count'] >= 130
assert M['rear_equipment_clearance_z'] >= 0.10
assert M['base_footprint_unchanged']

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(MODEL))
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
assert len(meshes) >= 130, len(meshes)

static = bpy.data.collections.new('RT-P | Reinforced static casemate and services')
rotating = bpy.data.collections.new('RT-P | Turret group - rotates with antenna')
bpy.context.scene.collection.children.link(static)
bpy.context.scene.collection.children.link(rotating)
prefixes = ('15_ring_rotary_platform', '16_martian_red_turret_armor',
 '17_turret_front_cheek', '18_turret_front_cheek', '19_cannon_mantlet',
 '20_enclosed_breech', '21_gun_tube', '22_primary_cannon',
 '23_muzzle', '24_recoil', '25_recoil', '31_antenna',
 '32_telemetry', '33_telemetry', '34_mast', '35_telemetry',
 '38_primary', '39_primary', '40_coax', '41_rangefinder',
 '42_turret', '43_turret', '47_oil_service', '48_front',
 '63_armored_turret', '64_steel_optic', '65_oil_service')

pivot = bpy.data.objects.new('TURRET_TRAVERSE_PIVOT', None)
pivot.location = (0, 0, 1.70)
rotating.objects.link(pivot)
rotating_count=0
for o in meshes:
    moving = o.name.startswith(prefixes)
    destination = rotating if moving else static
    for c in list(o.users_collection): c.objects.unlink(o)
    destination.objects.link(o)
    if moving:
        mx = o.matrix_world.copy()
        o.parent = pivot
        o.matrix_world = mx
        rotating_count+=1
    # Use restrained physical bevels; the base already has true octagonal chamfers.
    if o.name.startswith(('01_','02_','03_','04_','05_')):
        bevel_width=.025
    elif o.name.startswith(('16_','17_','18_','19_','26_','29_')):
        bevel_width=.018
    elif o.name.startswith(('09_','30_','55_')):
        bevel_width=.012
    else:
        bevel_width=0
    if bevel_width:
        b=o.modifiers.new('Manufactured edge bevel','BEVEL')
        b.width=bevel_width
        b.segments=3
        b.limit_method='ANGLE'
assert rotating_count == M['rotating_mesh_count'], (rotating_count, M['rotating_mesh_count'])
assert any(o.name.startswith('31_antenna') and o.parent == pivot for o in meshes)
assert any(o.name.startswith('32_telemetry') and o.parent == pivot for o in meshes)

cam_data=bpy.data.cameras.new('Factorio orthographic comparison camera')
cam=bpy.data.objects.new('Factorio orthographic comparison camera',cam_data)
bpy.context.scene.collection.objects.link(cam)
look=Vector((0,0,1.35))
cam_data.type='ORTHO'
cam_data.ortho_scale=5.8
bpy.context.scene.camera=cam

def look_from(at):
    cam.location=at
    cam.rotation_euler=(look-cam.location).to_track_quat('-Z','Y').to_euler()

world=bpy.data.worlds.new('Workshop low contrast ambient')
world.use_nodes=True
world.node_tree.nodes['Background'].inputs['Color'].default_value=(.34,.35,.36,1)
world.node_tree.nodes['Background'].inputs['Strength'].default_value=.75
bpy.context.scene.world=world
for name, xyz, energy, size in [('Front diffuse',(-4,-6,8),1550,5),
                                ('Rear rim',(4,5,7),1100,4)]:
    light=bpy.data.lights.new(name,'AREA')
    light.energy=energy
    light.shape='DISK'; light.size=size
    obj=bpy.data.objects.new(name,light)
    bpy.context.scene.collection.objects.link(obj)
    obj.location=xyz
    obj.rotation_euler=(look-obj.location).to_track_quat('-Z','Y').to_euler()

sc=bpy.context.scene
sc.render.engine='CYCLES'
sc.cycles.samples=24
# Ubuntu distro Blender may be compiled without Intel OpenImageDenoise.
# Denoising is optional for this diagnostic; keep renders deterministic on headless CI.
for layer in sc.view_layers:
    if hasattr(layer, 'cycles') and hasattr(layer.cycles, 'use_denoising'):
        layer.cycles.use_denoising = False
sc.render.resolution_x=900
sc.render.resolution_y=900
sc.render.resolution_percentage=100
sc.render.film_transparent=True
sc.render.image_settings.file_format='PNG'
sc.view_settings.view_transform = 'Filmic'

# 360-degree traverse test includes mast because both are parented to the pivot.
for angle in range(0,360,45):
    pivot.rotation_euler.z=math.radians(angle)
    bpy.context.view_layer.update()
    assert abs(pivot.rotation_euler.z-math.radians(angle)) < 1e-6
pivot.rotation_euler.z=0
bpy.context.view_layer.update()
look_from((5,-7,6))
blend=D/'martian_heavy_weapon_bunker_v02.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(blend))
print('MODEL_OK',blend,len(meshes),'rotating',rotating_count)
if '--render' in sys.argv:
    for label,xyz in [('front',(5,-7,6)),('rear',(-5,7,6))]:
        look_from(xyz)
        sc.render.filepath=str(D/f'bunker_blender_{label}_v02.png')
        bpy.ops.render.render(write_still=True)
