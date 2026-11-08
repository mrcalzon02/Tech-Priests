import bpy,json,math
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parent;D=R/'boiler_v05'
bpy.ops.wm.open_mainfile(filepath=str(D/'tech_priests_emergency_boiler_v05.blend'))
obs=[o for o in bpy.context.scene.objects if o.type=='MESH' and (o.parent and o.parent.name=='BOILER_TILE_CALIBRATION' or o.users_collection[0].name=='BOILER_EXTERNAL_FLUID_PORTS')]
def bounds(obs):
 ps=[o.matrix_world@Vector(v) for o in obs for v in o.bound_box];return [[min(v[i] for v in ps),max(v[i] for v in ps)] for i in range(3)]
before=bounds(obs);count=len(obs)
joint_checks=[]
for label,sign in [('Water',-1),('Steam',1)]:
 o=bpy.data.objects[label+' full-size reducing elbow'];points=[o.matrix_world@v.co for v in list(o.data.vertices)[:128]]
 plane_error=max(abs(p.x-sign) for p in points)
 outer=[math.sqrt((p.y-.5)**2+(p.z-.36)**2) for p in points[:64]]
 inner=[math.sqrt((p.y-.5)**2+(p.z-.36)**2) for p in points[64:]]
 check={'fluid':label,'plane_error':plane_error,'outer_radius_error':max(abs(x-.285) for x in outer),'bore_radius_error':max(abs(x-.245) for x in inner)}
 assert max(check[k] for k in ['plane_error','outer_radius_error','bore_radius_error'])<1e-5,check
 joint_checks.append(check)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(D/'tech_priests_emergency_boiler_v05.glb'))
afterobs=[o for o in bpy.context.scene.objects if o.type=='MESH'];after=bounds(afterobs);error=max(abs(a-b) for x,y in zip(before,after) for a,b in zip(x,y))
check={'native_mesh_count':count,'glb_mesh_count':len(afterobs),'bounds_error_tiles':error,'reference_meshes_exported':any('reference' in o.name.lower() for o in afterobs)};assert count==len(afterobs) and error<.01 and not check['reference_meshes_exported'],check
p=D/'Boiler_V05_Validation.json';j=json.loads(p.read_text());j['glb_readback']=check;j['mouth_interface_checks']=joint_checks;p.write_text(json.dumps(j,indent=2));print(check,joint_checks)
