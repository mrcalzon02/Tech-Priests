import bpy,json,math,hashlib
from pathlib import Path
A=Path(__file__).resolve().parent;reports=[];sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for runtime in(False,True):
 artifact=A/('laboratorium-v03.glb'if runtime else'laboratorium-v03.blend')
 if runtime:bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(artifact));bpy.context.scene.frame_set(0)
 else:bpy.ops.wm.open_mainfile(filepath=str(artifact));bpy.context.scene.frame_set(1)
 support=json.loads((A/('attachment-support-runtime-raw.json'if runtime else'attachment-support-raw.json')).read_text());clear=json.loads((A/('clearance-runtime-raw.json'if runtime else'clearance-raw.json')).read_text());owners=clear['motion_owners'];moving={n for n,v in owners.items()if v};groups=support['unattached_components'];assert len(groups)==1 and set(groups[0]['objects'])==moving and len(moving)==26;assert support['physically_connected_to_foundation']==250
 foreign=[p for p in clear['pairs']if(lambda x,y:(x or y)and x!=y)(*[owners[n]for n in p.split(' <> ')])];assert not foreign and clear['sampled_poses']==193
 root=bpy.data.objects[next(v for v in owners.values()if v)];inv=root.matrix_world.inverted();dg=bpy.context.evaluated_depsgraph_get()
 def radial(n):
  o=bpy.data.objects[n];ev=o.evaluated_get(dg);m=ev.to_mesh();v=[inv@(ev.matrix_world@v.co)for v in m.vertices];r=[math.hypot(q.x,q.y)for q in v];ev.to_mesh_clear();return min(r),max(r)
 shaft=radial('LABORATORIUM | rotor fixed journal shaft')[1];bore=radial('LABORATORIUM | moving calibration bored hub')[0];assert abs(bore-shaft-.0005)<2e-6
 assert .0125*math.cos(math.pi/32)-.012-1e-7<=groups[0]['nearest_founded_seats'][0]['gap']<=.0005+1e-7
 reports.append({'artifact':artifact.name,'sha256':sha(artifact),'stationary_grounded_meshes':250,'moving_meshes':26,'all_moving_meshes_physically_connected_as_one_rigid_assembly':True,'measured_fixed_shaft_radius':shaft,'measured_moving_bore_radius':bore,'nominal_running_clearance':bore-shaft,'polygon_clearance_lower_bound':.0125*math.cos(math.pi/32)-.012,'measured_nearest_founded_surface':groups[0]['nearest_founded_seats'][0],'foreign_moving_contacts':foreign,'sampled_full_rotation_poses':193,'fixed_contacts_fully_adjudicated':False})
(A/'mechanical-support-and-clearance.json').write_text(json.dumps({'support_and_moving_clearance_passed':True,'source_and_runtime':reports,'scope':'Every fixed component has a measured physical path to the foundation. All26 rotor parts form one measured connected rigid assembly on its captured coaxial shaft.193 source and193 runtime poses cover the complete rotation. Static fitted-seat contacts remain in the raw inventory; exhaustive static overlap adjudication is not claimed.','owner_visual_approved':False},indent=2));print('LABORATORIUM_SUPPORT_AND_MOVING_CLEARANCE_PASS')
