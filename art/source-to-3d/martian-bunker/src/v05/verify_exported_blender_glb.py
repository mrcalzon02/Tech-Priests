"""Independent Blender reimport check for released GLB axis, colors and attachment."""
from pathlib import Path
import json
import bpy
from mathutils import Vector

folder=Path(__file__).resolve().parent
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(folder/'martian_heavy_weapon_bunker_v05_blender_export.glb'))
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
manifest=json.loads((folder/'component_manifest_v05.json').read_text())
assert len(meshes)==manifest['parts_count'], (len(meshes),manifest['parts_count'])
bpy.context.view_layer.update()

def bounds(o):
    verts=[o.matrix_world @ v.co for v in o.data.vertices]
    return [min(v[i] for v in verts) for i in range(3)],[max(v[i] for v in verts) for i in range(3)]

def get(n):
    matches=[o for o in meshes if o.name.startswith(n)]
    assert len(matches)==1,(n,[x.name for x in matches])
    return matches[0]

base=get('01_foundation_granular_ferrocrete')
low,high=bounds(base)
assert abs(low[0]+1.5)<.004 and abs(high[0]-1.5)<.004,(low,high)
assert abs(low[2])<.004 and abs(high[2]-.26)<.004,(low,high)
muzzle=get('23_muzzle_reinforcement')
lo,hi=bounds(muzzle)
assert hi[1] < -1.79 and 1.8 < lo[2]<2.03,(lo,hi)
mast=get('32_telemetry_mast')
lo,hi=bounds(mast)
assert hi[2]>2.98 and lo[2]>2.4,(lo,hi)
turret=get('16_martian_red_turret_armor')
lo,hi=bounds(turret)
assert 1.8 < lo[2] <1.85 and 2.25<hi[2]<2.31,(lo,hi)
assert turret.data.materials, 'Material lost on export'
mat=turret.data.materials[0]
assert mat.use_nodes
bsdf=mat.node_tree.nodes.get('Principled BSDF')
assert bsdf
red=bsdf.inputs['Base Color'].default_value
assert red[0]>red[1]*4 and red[0]>red[2]*4,red
assert 0.20 < red[0] < 0.25 and 0.015 < red[1] < 0.025, ('source sRGB not correctly linearized',red)
# Ensure exported corners stayed tapered; check actual WORLD vertices after import.
for name in ('06_corner_armor_buttress_WS','06_corner_armor_buttress_ES','06_corner_armor_buttress_WN','06_corner_armor_buttress_EN'):
    o=get(name)
    verts=[o.matrix_world @ v.co for v in o.data.vertices]
    lo_z=min(v.z for v in verts); hi_z=max(v.z for v in verts)
    low=[v for v in verts if abs(v.z-lo_z)<.002]
    high=[v for v in verts if abs(v.z-hi_z)<.002]
    def mean_abs(vs,ax): return sum(abs(v[ax]) for v in vs)/len(vs)
    assert mean_abs(high,0)+.08 < mean_abs(low,0),(name,'corner failed to lean inward X')
    assert mean_abs(high,1)+.08 < mean_abs(low,1),(name,'corner failed to lean inward Y')
for a in manifest['hull_attachments']:
    if a['contact_type'] not in ('shell','face-mounted equipment'): continue
    o=get(a['name'])
    verts=[o.matrix_world @ v.co for v in o.data.vertices]
    ax=0 if a['face'] in ('E','W') else 1
    sign=1 if a['face'] in ('E','N') else -1
    center_axis=sum(v[ax]*sign for v in verts)/len(verts)
    assert center_axis>1.10,(a['name'],'unexpected detached or rotated panel',center_axis)
# Turret front is materially assembled after the complete GLB export/import.
face=get('19_machined_barrel_socket')
lo,hi=bounds(face)
assert -1.07<lo[1]<-.90 and -1.04<hi[1]<-.84,(lo,hi)
assert lo[2]<2.02<hi[2],(lo,hi)
for side in ('W','E'):
    cheek=get(f'17_turret_front_cheek_{side}' if side=='W' else '18_turret_front_cheek_E')
    cl,ch=bounds(cheek)
    assert cl[1]<-.85 and ch[1]>-.65,(side,cl,ch)
if manifest['turret_front_refinement_pass']==2:
    for side in ('W','E'):
        cap=get(f'68_trunnion_bearing_cap_{side}')
        cl,ch=bounds(cap)
        assert ch[1]>-.89 and cl[1]<-.92,(side,cl,ch)
    assert len(meshes)>=150, len(meshes)
print('BLENDER_GLB_REIMPORT_IS_UPRIGHT_COLORED_AND_TURRET_FACE_ATTACHED',len(meshes),tuple(red))
