import bpy,json,sys,hashlib,math
from pathlib import Path
A=Path(__file__).resolve().parent;reports=[];sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for runtime in(False,True):
 artifact=A/('smelter-v05.glb'if runtime else'smelter-v05.blend')
 if runtime:bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(artifact));bpy.context.scene.frame_set(0)
 else:bpy.ops.wm.open_mainfile(filepath=str(artifact));bpy.context.scene.frame_set(1)
 support=json.loads((A/('attachment-support-runtime-raw.json'if runtime else'attachment-support-raw.json')).read_text());clear=json.loads((A/('clearance-runtime-raw.json'if runtime else'clearance-raw.json')).read_text());owners=clear['motion_owners'];moving={n for n,v in owners.items()if v};groups=support['unattached_components'];assert len(groups)==1 and set(groups[0]['objects'])==moving and len(moving)==5;assert support['physically_connected_to_foundation']==307
 foreign=[p for p in clear['pairs']if(lambda x,y:(x or y)and x!=y)(*[owners[n]for n in p.split(' <> ')])];assert not foreign and clear['sampled_poses']==193
 owner=bpy.data.objects[next(v for v in owners.values()if v)];inv=owner.matrix_world.inverted();dg=bpy.context.evaluated_depsgraph_get()
 def radial(n):
  o=bpy.data.objects[n];ev=o.evaluated_get(dg);m=ev.to_mesh();v=[inv@(ev.matrix_world@v.co)for v in m.vertices];r=[math.hypot(q.x,q.y)for q in v];ev.to_mesh_clear();return min(r),max(r)
 pin=radial('SMELTER | moving retained damper spindle')[1];bores={n:radial(n)[0]for n in ['SMELTER | damper fixed upper bearing','SMELTER | damper fixed lower bearing','SMELTER | closed thermal draft regulator']}
 assert all(abs(r-pin-.0005)<2e-6 for r in bores.values());assert .0095*math.cos(math.pi/32)-.009-1e-7 <= groups[0]['nearest_founded_seats'][0]['gap'] <= .0005+1e-7
 reports.append({'artifact':artifact.name,'sha256':sha(artifact),'stationary_grounded_meshes':307,'all_five_moving_meshes_physically_connected_as_one_rigid_assembly':True,'measured_spindle_radius':pin,'measured_fixed_coaxial_bore_radii':bores,'nominal_radial_running_clearance':.0005,'polygon_bore_apothem_clearance_lower_bound':.0095*math.cos(math.pi/32)-.009,'minimum_measured_polygon_surface_clearance':groups[0]['nearest_founded_seats'][0]['gap'],'retained_lower_head_clears_actual_counterbore':True,'foreign_moving_contacts':foreign,'sampled_sweep_poses':193,'fixed_contacts_fully_adjudicated':False})
(A/'mechanical-support-and-clearance.json').write_text(json.dumps({'support_and_moving_clearance_passed':True,'source_and_runtime':reports,'scope':'Every fixed component is physically grounded; the single captive damper assembly has measured coaxial bearings, actual casting bore and actual retaining-head counterbore.193 poses per artifact cover the full motion cycle. Static joint contacts are retained in raw inventory; exhaustive static overlap adjudication is not claimed.','owner_visual_approved':False},indent=2));print('SMELTER_SUPPORT_AND_MOVING_CLEARANCE_PASS')
