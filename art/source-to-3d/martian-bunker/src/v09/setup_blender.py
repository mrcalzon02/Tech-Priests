"""Native Blender reconstruction of the Red Tech Priests heavy bunker.

Critical repair versus v02: do NOT import the intermediate trimesh GLB as if it
were native glTF Y-up geometry or assume material vertex colors shade in Cycles.
Build original Z-up source mesh arrays in Blender itself, explicitly assign
PBR materials, and export a real Blender-origin GLB using its glTF exporter.

This script is a production diagnostic, NOT sprite/game acceptance.
"""
from pathlib import Path
import gzip
import json
import math
import sys
import os

import bpy
from mathutils import Matrix, Vector

OUT = Path(__file__).resolve().parent
payload = json.loads(gzip.decompress((OUT / 'original_z_up_mesh_payload_v09.json.gz').read_bytes()))
assert payload['axes'] == '+Z up, -Y gun forward, +X right'
assert len(payload['parts']) >= 160

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for c in list(bpy.data.collections):
    if c.name != 'Collection' and c.users == 0:
        bpy.data.collections.remove(c)

static = bpy.data.collections.new('RT-P | STATIONARY FERROCRETE + SERVICES')
rotating = bpy.data.collections.new('RT-P | ROTATING TURRET + ANTENNA')
bpy.context.scene.collection.children.link(static)
bpy.context.scene.collection.children.link(rotating)

materials = {}

def rgb_from_hex(s):
    # Hex palette is sRGB; Blender Principled BSDF base color expects LINEAR.
    # Directly assigning /255 makes gray concrete bleach white and deep red pink.
    s=s.lstrip('#')
    srgb=[int(s[i:i+2],16)/255.0 for i in (0,2,4)]
    return tuple(v/12.92 if v<=0.04045 else ((v+0.055)/1.055)**2.4 for v in srgb)

for key, hx in payload['materials'].items():
    rgb=rgb_from_hex(hx)
    mat=bpy.data.materials.new('RT-P | ' + key.upper())
    mat.use_nodes=True
    bsdf=mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value=(*rgb,1.0)
    metal=(key in ('iron','machine_steel','brass','grease'))
    bsdf.inputs['Metallic'].default_value=(.7 if metal else 0.04)
    bsdf.inputs['Roughness'].default_value=(.72 if key.startswith('ferrocrete') else (.42 if key in ('martian_red','red_highlight','red_dark') else (.56 if metal else .26)))
    mat.diffuse_color=(*rgb,1.0)
    if key in ('indicator_green','alert'):
        emissive = bsdf.inputs.get('Emission Color') or bsdf.inputs.get('Emission')
        strength = bsdf.inputs.get('Emission Strength')
        if emissive: emissive.default_value=(*rgb,1.0)
        if strength: strength.default_value=1.8 if key=='indicator_green' else 1.0
    materials[key]=mat

# Original deterministic PBR image maps; delivered both in editable .blend and GLB.
# Explicitly distinguish flat source-shape from textured candidate while never
# overwriting any approved Factorio production sprites.
TEXTURE_MODE=os.environ.get('BUNKER_TEXTURE_MODE','TEXTURED').upper()
assert TEXTURE_MODE in ('TEXTURED','FLAT'),TEXTURE_MODE
if TEXTURE_MODE=='TEXTURED':
    tex_manifest=json.loads((OUT/'textures/texture_manifest.json').read_text())
    assert set(tex_manifest['materials'])==set(materials)
    for key,mat in materials.items():
        desc=tex_manifest['materials'][key]
        nt=mat.node_tree; nodes=nt.nodes; links=nt.links
        shader=nodes.get('Principled BSDF')
        imgs={}
        for k in ('albedo','orm','normal'):
            img=bpy.data.images.load(str(OUT/desc['texture_files'][k]),check_existing=True)
            img.pack()
            if k!='albedo': img.colorspace_settings.name='Non-Color'
            tex=nodes.new('ShaderNodeTexImage')
            tex.name=f'ORIGINAL_PBR_{key.upper()}'
            tex.image=img
            tex.interpolation='Linear'
            tex.extension='REPEAT'
            imgs[k]=tex
        links.new(imgs['albedo'].outputs['Color'],shader.inputs['Base Color'])
        channel=nodes.new('ShaderNodeSeparateColor')
        channel.mode='RGB'
        links.new(imgs['orm'].outputs['Color'],channel.inputs['Color'])
        links.new(channel.outputs['Green'],shader.inputs['Roughness'])
        links.new(channel.outputs['Blue'],shader.inputs['Metallic'])
        normal=nodes.new('ShaderNodeNormalMap')
        normal.inputs['Strength'].default_value=.45 if key.startswith('ferrocrete') else .28
        links.new(imgs['normal'].outputs['Color'],normal.inputs['Color'])
        links.new(normal.outputs['Normal'],shader.inputs['Normal'])
        mat['texture_source']='original generated maps / make_textures.py'
        mat['source_family']=desc['family']

pivot=bpy.data.objects.new('TURRET_TRAVERSE_PIVOT_Z_1_70',None)
pivot.empty_display_type='ARROWS'
pivot.empty_display_size=.22
pivot.location=(0,0,1.70)
rotating.objects.link(pivot)
bpy.context.view_layer.update()

by_name={}
for part in payload['parts']:
    mesh=bpy.data.meshes.new(part['name'] + ' | original Z-up geometry')
    mesh.from_pydata(part['vertices'], [], part['faces'])
    mesh.validate(clean_customdata=False)
    mesh.update()
    obj=bpy.data.objects.new(part['name'], mesh)
    (rotating if part['rotating'] else static).objects.link(obj)
    obj.data.materials.append(materials[part['material']])
    # Deterministic per-face box-projected UV coordinates in ORIGINAL world frame;
    # this gives actual image maps on every mesh, including all annular muzzle parts.
    uv=mesh.uv_layers.new(name='RT_P_ORIGINAL_TILE_UV')
    cylindrical = obj.name.startswith((
        '19_machined_barrel_socket','19_socket_flexible_dust_seal',
        '21_cylindrical_gun_jacket','21_jacket_socket_locking_flange',
        '21_jacket_mid_service_collar','22_primary_cannon_barrel',
        '81_mantlet','85_W_rangefinder','85_E_rangefinder',
        '23_muzzle_reinforcement','73_barrel_shroud_front_collar',
        '74_barrel_heat_shield_joint','77_visible_rifled_liner',
        '78_barrel_service_clamp','83_curved_barrel_access_cover'))
    for poly in mesh.polygons:
        normal=poly.normal
        ax=max(range(3),key=lambda k:abs(normal[k]))
        aa,bb=((0,1) if ax==2 else ((1,2) if ax==0 else (0,2)))
        if cylindrical:
            # Per-face seam-safe cylindrical unwrap. This keeps milling lines
            # and battered metal concentric on the gun, not projected as squares.
            loops=list(poly.loop_indices)
            cylindrical_uv=[]
            for loop_i in loops:
                vertex=mesh.vertices[mesh.loops[loop_i].vertex_index].co
                angle=(math.atan2(vertex.z-2.02,vertex.x)/(2*math.pi)+1.0)%1.0
                cylindrical_uv.append([angle,-vertex.y*1.25])
            if max(a[0] for a in cylindrical_uv)-min(a[0] for a in cylindrical_uv)>.5:
                for a in cylindrical_uv:
                    if a[0]<.5:a[0]+=1.0
            for loop_i,(u,v) in zip(loops,cylindrical_uv):
                uv.data[loop_i].uv=(u,v)
        else:
            for loop_i in poly.loop_indices:
                vertex=mesh.vertices[mesh.loops[loop_i].vertex_index].co
                uv.data[loop_i].uv=(vertex[aa]*1.25, vertex[bb]*1.25)

    # True cylindrical gun and lens lathe faces get continuously interpolated normals;
    # keep faceted armor and rectangular plate seams sharp.
    if cylindrical:
        for poly in mesh.polygons:
            poly.use_smooth=True
    if hasattr(obj.data,'use_auto_smooth'):
        obj.data.use_auto_smooth=True
    obj['functional_material']=part['material']
    obj['moves_with_turret']=part['rotating']
    # Source vertices are already in world coordinates. Preserve that exact
    # placement while parenting; the inverse pivot binds rotation about Z=1.70.
    if part['rotating']:
        obj.parent=pivot
        obj.matrix_parent_inverse=pivot.matrix_world.inverted()
    # Narrow edge breaks: use true concrete chamfers from source primitives.
    if obj.name.startswith(('01_','02_','03_','04_','05_','06_','07_')):
        bevel=.022
    elif obj.name.startswith(('16_','17_','18_','19_','21_jacket','26_','29_','63_','68_','69_','71_','73_','74_','78_','81_','82_','83_','85_','86_','87_')):
        bevel=.013
    elif obj.name.startswith(('08_','09_','10_','11_','12_','44_','45_','50_','51_','52_','55_','56_','59_','66_','67_')):
        bevel=.008
    elif obj.name.startswith(('22_','23_','77_','79_','80_')):
        bevel=0.0025 if obj.name.startswith('23_') else 0.0
    else:
        bevel=0.0
    if bevel:
        modifier=obj.modifiers.new('Manufactured edge roll','BEVEL')
        modifier.width=bevel
        modifier.segments=2
        modifier.limit_method='ANGLE'
        if hasattr(modifier, 'affect'):
            modifier.affect='EDGES'
        normal=obj.modifiers.new('Weight main face normals','WEIGHTED_NORMAL')
        normal.keep_sharp=True
    by_name[obj.name]=obj

bpy.context.view_layer.update()
manifest=json.loads((OUT/'component_manifest_v09.json').read_text())
assert len(by_name)==manifest['parts_count']
assert sum(1 for p in payload['parts'] if p['rotating'])==manifest['rotating_mesh_count']

def center_world(o):
    return o.matrix_world @ (sum((v.co for v in o.data.vertices), Vector((0,0,0))) / len(o.data.vertices))

def world_bounds(o):
    verts=[o.matrix_world @ v.co for v in o.data.vertices]
    return (Vector(tuple(min(v[i] for v in verts) for i in range(3))),
            Vector(tuple(max(v[i] for v in verts) for i in range(3))))

# A coordinate, rig and attachment proof; the v02 job never checked these.
base=world_bounds(by_name['01_foundation_granular_ferrocrete'])
assert abs(base[0].z)<.002 and abs(base[1].z-.26)<.002, base
assert abs(base[0].x+1.5)<.002 and abs(base[1].x-1.5)<.002, base
housing=world_bounds(by_name['16_martian_red_turret_armor'])
assert 1.81<housing[0].z<1.83 and 2.27<housing[1].z<2.29, housing
muzzle=center_world(by_name['23_muzzle_reinforcement'])
assert -2.00 < muzzle.y < -1.85 and 1.99 < muzzle.z < 2.05, muzzle
mast=center_world(by_name['32_telemetry_mast'])
assert mast.z>2.6 and mast.y>0.7, mast
assert by_name['32_telemetry_mast'].parent == pivot
assert by_name['22_primary_cannon_barrel'].parent == pivot
assert by_name['21_cylindrical_gun_jacket'].parent == pivot
assert '21_gun_tube_outer_shroud' not in by_name, 'Old box never removed'
assert 20 <= len(manifest['target_detail_parts']) <= 45
assert all(by_name[n].parent==pivot for n in manifest['target_detail_parts']), 'Target assembly detached from turret'
assert '81_mantlet_heavy_outer_armor' in by_name and '83_curved_barrel_access_cover' in by_name
for n in ('23_muzzle_reinforcement','77_visible_rifled_liner'):
    assert by_name[n].parent == pivot,('barrel accessory detached from turret',n)
assert by_name['26_rear_armor_magazine'].parent is None
assert by_name['29_rear_control_cabinet'].parent is None
# Turret's base physically meets the rotary platform, and weapon is attached.
platform=world_bounds(by_name['15_ring_rotary_platform'])
assert abs(platform[1].z-housing[0].z)<.02, (platform,housing)
assert by_name['16_martian_red_turret_armor'].data.materials[0] == materials['martian_red']
assert by_name['01_foundation_granular_ferrocrete'].data.materials[0]==materials['ferrocrete_dark']

original_centers={name:center_world(by_name[name]).copy() for name in (['21_cylindrical_gun_jacket','22_primary_cannon_barrel','23_muzzle_reinforcement','77_visible_rifled_liner','32_telemetry_mast','16_martian_red_turret_armor','19_machined_barrel_socket']+(['68_trunnion_bearing_cap_E','68_trunnion_bearing_cap_W'] if manifest['turret_front_refinement_pass']==2 else []))}
for angle in range(0,360,15):
    pivot.rotation_euler.z=math.radians(angle)
    bpy.context.view_layer.update()
    for name, original in original_centers.items():
        expected=Matrix.Rotation(math.radians(angle),4,'Z') @ (original - pivot.location) + pivot.location
        actual=center_world(by_name[name])
        assert (actual-expected).length<0.001,(angle,name,actual,expected)
pivot.rotation_euler.z=0
bpy.context.view_layer.update()
for name, original in original_centers.items():
    assert (center_world(by_name[name])-original).length<0.001, name
# Critically, v0.6 checks attachment conforming in the ACTUAL Blender scene.
assert len(manifest['hull_attachments'])>=22
for panel in manifest['hull_attachments']:
    o=by_name[panel['name']]
    assert o.parent is None,(panel['name'],'static surface unexpectedly rotates')
    if panel['contact_type'] in ('shell','face-mounted equipment'):
        xyz=[o.matrix_world @ v.co for v in o.data.vertices]
        face=panel['face'];ax=0 if face in ('E','W') else 1
        sign=1 if face in ('E','N') else -1
        inner=panel['stand_off']-panel['penetration']
        for z in (panel['z_bottom'],panel['z_top']):
            verts=[v for v in xyz if abs(v.z-z)<.0005]
            shell=(1.375 if ax==0 else 1.355) - .16*(z-.38)/.93
            assert len(verts)>=4 and min(sign*v[ax] for v in verts)<=shell+inner+.002, (panel['name'],z)
for butt in manifest['inward_sloped_buttresses']:
    if not butt['name'].startswith('06_'): continue
    assert all(a>b for a,b in zip(butt['low_center'],butt['high_center'])),butt
print('BLENDER_NATIVE_HULL_CONTACT_AND_SLOPED_BUTTRESS_PASSED',len(manifest['hull_attachments']))
# The actual muzzle bore must remain open when changing geometry and rigging.
assert by_name['22_primary_cannon_barrel'].data.polygons and by_name['23_muzzle_reinforcement'].data.polygons
assert all(o.data.uv_layers for o in by_name.values()),'Textured GLB would have no UV coordinates'
assert world_bounds(by_name['23_muzzle_reinforcement'])[0].y<-2.02
assert by_name['77_visible_rifled_liner'].parent==pivot
print('NATIVE_Z_UP_ORIENTATION_AND_TURRET_ATTACHMENT_OK',len(by_name), 'meshes,', manifest['rotating_mesh_count'], 'rotating')

# Confirm rear clearance with real Blender vertex-space positions.
fixed_rear=['26_rear_armor_magazine','27_protected_breech_feed','28_right_magazine_inspection_panel','29_rear_control_cabinet','30_controller_access_panel']
rear_top=max(world_bounds(by_name[name])[1].z for name in fixed_rear)
assert platform[0].z-rear_top>=0.1, (platform,rear_top)

look=Vector((0,0,1.35))
cam_data=bpy.data.cameras.new('Factorio-style Z-up orthographic camera')
cam=bpy.data.objects.new('Factorio-style Z-up orthographic camera',cam_data)
bpy.context.scene.collection.objects.link(cam)
cam_data.type='ORTHO'
cam_data.ortho_scale=5.45
bpy.context.scene.camera=cam

def look_from(pos,target=None,scale=5.45):
    cam.location=pos
    subject = Vector(target) if target is not None else look
    cam.rotation_euler=(subject-cam.location).to_track_quat('-Z','Y').to_euler()
    cam_data.ortho_scale=scale

world=bpy.data.worlds.new('RT-P | Warm workshop ambient')
world.use_nodes=True
world.node_tree.nodes['Background'].inputs['Color'].default_value=(.31,.31,.30,1.0)
world.node_tree.nodes['Background'].inputs['Strength'].default_value=.8
bpy.context.scene.world=world
for name,xyz,energy,size in [('Warm key',(-4,-6,8),1450,5),('Cold steel fill',(4,5,7),750,4)]:
    lamp=bpy.data.lights.new(name,'AREA')
    lamp.energy=energy
    lamp.shape='DISK';lamp.size=size
    holder=bpy.data.objects.new(name,lamp)
    bpy.context.scene.collection.objects.link(holder)
    holder.location=xyz
    holder.rotation_euler=(look-holder.location).to_track_quat('-Z','Y').to_euler()

sc=bpy.context.scene
sc.render.engine='CYCLES'
sc.cycles.samples=40
for layer in sc.view_layers:
    if hasattr(layer,'cycles') and hasattr(layer.cycles,'use_denoising'):
        layer.cycles.use_denoising=False
sc.render.resolution_x=900
sc.render.resolution_y=900
sc.render.resolution_percentage=100
sc.render.film_transparent=True
sc.render.image_settings.file_format='PNG'
sc.view_settings.view_transform='Standard' # preserve diagnostic material identity

# Export ONLY physical meshes + moving pivot; Blender handles GLB Y-up conversion.
bpy.ops.object.select_all(action='DESELECT')
for o in by_name.values():o.select_set(True)
pivot.select_set(True)
final_glb=OUT/f'martian_heavy_weapon_bunker_v09_{TEXTURE_MODE.lower()}_export.glb'
bpy.ops.export_scene.gltf(filepath=str(final_glb), export_format='GLB', use_selection=True)
assert final_glb.is_file() and final_glb.stat().st_size>30000
bpy.ops.object.select_all(action='DESELECT')

look_from((5,-7,6))
# Pack every image map for a self-contained native .blend.
if TEXTURE_MODE=='TEXTURED': bpy.ops.file.pack_all()
blend=OUT/f'martian_heavy_weapon_bunker_v09_{TEXTURE_MODE.lower()}.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(blend))
assert blend.is_file() and blend.stat().st_size>20000
if '--render' in sys.argv:
    for label,loc in [('front',(5,-7,6)),('rear',(-5,7,6))]:
        look_from(loc)
        sc.render.filepath=str(OUT/f'bunker_v09_{TEXTURE_MODE.lower()}_{label}.png')
        bpy.ops.render.render(write_still=True)
    look_from((3.2,-7,4.25),target=(0,-1.25,2.05),scale=1.90)
    sc.render.filepath=str(OUT/f'barrel_v09_{TEXTURE_MODE.lower()}_three_quarter.png')
    bpy.ops.render.render(write_still=True)
    look_from((0,-8,2.75),target=(0,-1.40,2.02),scale=1.54)
    sc.render.filepath=str(OUT/f'barrel_v09_{TEXTURE_MODE.lower()}_head_on.png')
    bpy.ops.render.render(write_still=True)
    look_from((-7,-3.4,4.0),target=(0,-1.25,2.05),scale=2.22)
    sc.render.filepath=str(OUT/f'barrel_v09_{TEXTURE_MODE.lower()}_side.png')
    bpy.ops.render.render(write_still=True)
print('BUNKER_V09_REAL_NATIVE_BLENDER_REFERENCE_GEOMETRY_AND_PBR',TEXTURE_MODE, len(by_name),blend,final_glb)
