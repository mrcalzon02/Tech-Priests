"""Independent Blender reimport check for released GLB axis, colors and attachment."""
from pathlib import Path
import json
import bpy
from mathutils import Vector

folder=Path(__file__).resolve().parent
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(folder/'martian_heavy_weapon_bunker_v03_blender_export.glb'))
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
assert len(meshes)==131, len(meshes)
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
assert red[0]>red[1]*2 and red[0]>red[2]*2,red
print('BLENDER_GLB_REIMPORT_IS_UPRIGHT_COLORED_AND_ASSEMBLED',len(meshes),tuple(red))
