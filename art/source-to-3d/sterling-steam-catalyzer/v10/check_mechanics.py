import bpy,json,math,hashlib,struct
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
O=Path(__file__).resolve().parent;sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();results={};socket_rows={}
for runtime in (False,True):
 artifact=O/('sterling-v10.glb' if runtime else 'sterling-v10.blend')
 if runtime:
  b=artifact.read_bytes();length,_=struct.unpack_from('<II',b,12);g=json.loads(b[20:20+length]);first=min(g['accessors'][x['input']]['min'][0] for a in g['animations'] for x in a['samplers']);bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.scene.render.fps=24;bpy.ops.import_scene.gltf(filepath=str(artifact))
 else:bpy.ops.wm.open_mainfile(filepath=str(artifact));first=0
 s=bpy.context.scene;ob=bpy.data.objects;pin=ob['STERLING | needle retained pivot'];bearing=ob['STERLING | fixed bored pressure needle bearing'];needle=ob['STERLING | visible pressure needle'];coal=ob['STERLING | contained coal bed'];metrics={'minimum_pin_radial_clearance':1.,'minimum_pin_axial_engagement':1.,'minimum_needle_bearing_face_clearance':1.,'maximum_pin_axis_error':0.,'maximum_flame_root_penetration':0.,'maximum_socket_motion':0.}
 def points(o):return [o.matrix_world@v.co for v in o.data.vertices]
 first_sockets={}
 for f in ((1+i/2 for i in range(193)) if runtime else (i/2 for i in range(195))):
  t=(first+(f-1)/24)*24 if runtime else f;s.frame_set(math.floor(t),subframe=t-math.floor(t));bpy.context.view_layer.update();bp=points(bearing);pp=points(pin);np=points(needle);top=max(p.z for p in points(coal));axis=pin.matrix_world.to_quaternion()@Vector((0,0,1));error=min((axis-Vector((0,1,0))).length,(axis-Vector((0,-1,0))).length)
  metrics['maximum_pin_axis_error']=max(metrics['maximum_pin_axis_error'],error)
  br=min(math.hypot(p.x+.67,p.z-1.55) for p in bp);pr=max(math.hypot(p.x+.67,p.z-1.55) for p in pp)
  metrics['minimum_pin_radial_clearance']=min(metrics['minimum_pin_radial_clearance'],br-pr)
  overlap=min(max(p.y for p in bp),max(p.y for p in pp))-max(min(p.y for p in bp),min(p.y for p in pp));metrics['minimum_pin_axial_engagement']=min(metrics['minimum_pin_axial_engagement'],overlap)
  metrics['minimum_needle_bearing_face_clearance']=min(metrics['minimum_needle_bearing_face_clearance'],min(p.y for p in bp)-max(p.y for p in np))
  for o in s.objects:
   if 'coal fire tongue' in o.name:metrics['maximum_flame_root_penetration']=max(metrics['maximum_flame_root_penetration'],top-min(p.z for p in points(o)))
  for role,sign in [('WATER',-1),('STEAM',1)]:
   o=ob['STERLING | '+role+' full bore outer socket'];pts=points(o);edge=(min if sign<0 else max)(p.x for p in pts);face=[p for p in pts if abs(p.x-edge)<1e-5];center=sum(face,Vector())/len(face)
   assert (center-Vector((sign*2,-.5,.36))).length<1e-5
   radii=[math.hypot(p.y-center.y,p.z-center.z) for p in face];assert abs(min(radii)-.245)<1e-5 and abs(max(radii)-.31)<1e-5
   if role not in first_sockets:first_sockets[role]=center.copy()
   metrics['maximum_socket_motion']=max(metrics['maximum_socket_motion'],(center-first_sockets[role]).length)
  if f==0:
   fp=[p for o in s.objects if 'coal fire tongue' in o.name for p in points(o)];metrics['idle_flame_width']=max(p.x for p in fp)-min(p.x for p in fp);metrics['idle_flame_height']=max(p.z for p in fp)-min(p.z for p in fp)
 passed=metrics['minimum_pin_radial_clearance']>.0009 and metrics['minimum_pin_axial_engagement']>.010 and metrics['minimum_needle_bearing_face_clearance']>.0038 and metrics['maximum_pin_axis_error']<1e-5 and metrics['maximum_flame_root_penetration']<1e-4 and metrics['maximum_socket_motion']<1e-6 and (runtime or (metrics['idle_flame_width']<.002 and metrics['idle_flame_height']<.0003))
 results['runtime' if runtime else 'source']={'artifact_sha256':sha(artifact),'poses':193 if runtime else 195,'idle_pose_in_artifact':not runtime,'metrics':metrics,'passed':passed};assert passed,metrics
 if not runtime:
  # Measure the actual sprite camera, using only an unsaved projection parent.
  root=ob['EXPORT | Sterling actual boiler'];proj=bpy.data.objects.new('MEASUREMENT ONLY | square ground projection',None);s.collection.objects.link(proj);proj.scale.y=math.sqrt(2);root.parent=proj;s.frame_set(1);shift=-.8/math.sqrt(2)+.36/math.sqrt(2)-.046875
  for facing,yaw in [('north',0),('east',270),('south',180),('west',90)]:
   root.rotation_euler.z=math.radians(yaw);bpy.context.view_layer.update();rows=[]
   for role,sign in [('WATER',-1),('STEAM',1)]:
    local=Vector((sign*2,-.5,.36));pos=root.matrix_world@local;uv=world_to_camera_view(s,s.camera,pos);actual=Vector(((uv.x-.5)*5.4,(.5-uv.y)*5.4+shift));rot=local.copy();rot.rotate(root.rotation_euler);expected=Vector((rot.x,-rot.y-.046875));error=(actual-expected).length;assert error<1e-5;rows.append({'role':role,'actual_sprite_mouth_position_tiles':list(actual),'native_grid_mouth_position_tiles':list(expected),'projection_error_tiles':error})
   def anchor(p):
    p=Vector(p);p.rotate(root.rotation_euler);return [p.x,-p.y-p.z/math.sqrt(2)+.36/math.sqrt(2)-.046875]
   socket_rows[facing]={'sockets':rows,'smoke_position':anchor((.45,.82,1.69)),'circuit_mount_source_object':'STERLING | armored cogitator console','circuit_main_anchor':anchor((.48,-.70,1.155)),'circuit_shadow_anchor':anchor((.48,-.70,0))}
results.update(passed=all(r['passed'] for r in results.values()),directions=socket_rows,sprite_shift=[0,-.8/math.sqrt(2)+.36/math.sqrt(2)-.046875],native_verified=False,owner_visual_approved=False)
(O/'mechanical-inspection.json').write_text(json.dumps(results,indent=2)+'\n',encoding='utf-8');print('STERLING_MECHANICS_AND_CAMERA_PASS',json.dumps(results),flush=True)
