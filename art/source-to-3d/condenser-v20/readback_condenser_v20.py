import bpy,json
from pathlib import Path
from mathutils import Vector
D=Path(__file__).resolve().parent/'condenser_v20'
bpy.ops.wm.open_mainfile(filepath=str(D/'tech_priests_water_condenser_v20.blend'))
asset=[o for o in bpy.context.scene.objects if o.type=='MESH' and (o.parent and o.parent.name=='CONDENSER_TILE_CALIBRATION' or o.name.startswith('Water outlet'))]
def bounds(obs):
 pts=[o.matrix_world@Vector(v) for o in obs for v in o.bound_box]
 return [[min(v[i] for v in pts),max(v[i] for v in pts)] for i in range(3)]
before=bounds(asset);count=len(asset)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(D/'tech_priests_water_condenser_v20.glb'))
obs=[o for o in bpy.context.scene.objects if o.type=='MESH'];after=bounds(obs)
error=max(abs(a-b) for x,y in zip(before,after) for a,b in zip(x,y))
check={'native_asset_meshes':count,'glb_meshes':len(obs),'bounds_error_tiles':error,'reference_meshes_exported':any(o.name.startswith(('Reference','Grid')) for o in obs),'pass':len(obs)==count and error<.01}
assert check['pass'],check
p=D/'Condenser_V20_Validation.json';j=json.loads(p.read_text());j['glb_readback']=check;p.write_text(json.dumps(j,indent=2));print(check)
