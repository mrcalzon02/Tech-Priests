import bpy,json,math
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parent;D=R/'boiler_v07'
bpy.ops.wm.open_mainfile(filepath=str(D/'tech_priests_emergency_boiler_v07.blend'))
obs=[o for o in bpy.context.scene.objects if o.type=='MESH' and (o.parent and o.parent.name=='BOILER_TILE_CALIBRATION' or any(c.name=='BOILER_REAR_INTERFACE_MANIFOLDS' for c in o.users_collection))]
def bounds(obs):
 ps=[o.matrix_world@Vector(v) for o in obs for v in o.bound_box];return [[min(v[i] for v in ps),max(v[i] for v in ps)] for i in range(3)]
before=bounds(obs);count=len(obs);interfaces=[]
for label,sign in [('Water',-1),('Steam',1)]:
 o=bpy.data.objects[label+' full-size bolted inlet flange'];points=[o.matrix_world@v.co for v in o.data.vertices if abs((o.matrix_world@v.co).x-sign)<1e-5];assert len(points)>=128
 errors=[min(abs(math.hypot(p.y-.5,p.z-.36)-r) for r in [.34,.245]) for p in points];assert max(errors)<1e-5
 interfaces.append({'fluid':label,'matching_interface_vertices':len(points),'max_radius_error':max(errors)})
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(D/'tech_priests_emergency_boiler_v07.glb'))
afterobs=[o for o in bpy.context.scene.objects if o.type=='MESH'];after=bounds(afterobs);error=max(abs(a-b) for x,y in zip(before,after) for a,b in zip(x,y))
check={'native_mesh_count':count,'glb_mesh_count':len(afterobs),'bounds_error_tiles':error,'reference_meshes_exported':any('reference' in o.name.lower() for o in afterobs)};assert count==len(afterobs) and error<.01 and not check['reference_meshes_exported'],check
p=D/'Boiler_V07_Validation.json';j=json.loads(p.read_text());j['glb_readback']=check;j['mouth_interface_checks']=interfaces;j['flange_throat_join']='Manifold neck ends at flange inner face X=+/-0.925; flange carries bore onward to X=+/-1, avoiding duplicate bore walls and coplanar visible mouth caps';p.write_text(json.dumps(j,indent=2));print(check,interfaces)
