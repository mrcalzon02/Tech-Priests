import argparse,bpy,json,pathlib,sys,math,hashlib
from mathutils import Vector,Matrix
from bpy_extras.object_utils import world_to_camera_view
parser=argparse.ArgumentParser();parser.add_argument('directory',type=pathlib.Path);parser.add_argument('--job',type=pathlib.Path,required=True);args=parser.parse_args(sys.argv[sys.argv.index('--')+1:]);out=args.directory.resolve();bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(out/'boiler-v08-cold.glb'))
s=bpy.context.scene;job=json.loads(args.job.read_text(encoding='utf-8'))
objects=[o for o in s.objects if o.type=='MESH'];allpoints=[o.matrix_world@v.co for o in objects for v in o.data.vertices];bounds=[[min(p[i] for p in allpoints) for i in range(3)],[max(p[i] for p in allpoints) for i in range(3)]]
assert abs(bounds[0][2])<1e-6,bounds
contact=[]
for identity,sign in [('water',-1),('steam',1)]:
 o=bpy.data.objects['Water full-size bolted inlet flange' if sign<0 else 'Steam full-size bolted inlet flange'];p=[o.matrix_world@v.co for v in o.data.vertices];bb=[[min(v[i] for v in p) for i in range(3)],[max(v[i] for v in p) for i in range(3)]]
 socket=bpy.data.objects['socket_'+identity];pos=socket.matrix_world.translation;plane=bb[0 if sign<0 else 1][0]
 assert abs(pos.x-plane)<1e-6 and abs(pos.y-(bb[0][1]+bb[1][1])/2)<1e-6 and abs(pos.z-(bb[0][2]+bb[1][2])/2)<1e-6,(identity,bb,list(pos))
 contact.append({'identity':identity,'flange_bounds':bb,'socket_position':list(pos),'plane_error':abs(pos.x-plane)})
wire=bpy.data.objects['socket_circuit_mount'].matrix_world.translation;o=bpy.data.objects['Steam rear cage upright'];p=[o.matrix_world@v.co for v in o.data.vertices];bb=[[min(v[i] for v in p) for i in range(3)],[max(v[i] for v in p) for i in range(3)]]
assert all(bb[0][i]-1e-6<=wire[i]<=bb[1][i]+1e-6 for i in range(3)),(list(wire),bb)
camdata=bpy.data.cameras.new('Registration check');cam=bpy.data.objects.new('Registration check',camdata);s.collection.objects.link(cam);s.camera=cam
cam.location=(0,-6,6.85);cam.rotation_euler=(Vector((0,0,.85))-cam.location).to_track_quat('-Z','Y').to_euler();camdata.type='ORTHO';camdata.ortho_scale=3.35;s.render.resolution_x=s.render.resolution_y=256;s.render.resolution_percentage=100;bpy.context.view_layer.update()
targets={'north':[[-32,-18],[32,-18]],'east':[[16,-32],[16,32]],'south':[[32,14],[-32,14]],'west':[[-16,32],[-16,-32]]};directions=[]
for name,yaw in zip(['north','east','south','west'],[0,270,180,90]):
 rotation=Matrix.Rotation(math.radians(yaw),4,'Z');points={};residual=0;fit=job['directional_registration'][name]
 for i,identity in enumerate(['water','steam','circuit_mount']):
  socket=bpy.data.objects['socket_'+identity];pos=rotation@socket.matrix_world.translation;normal=(rotation.to_3x3()@socket.matrix_world.to_3x3()@Vector((0,0,1))).normalized();v=world_to_camera_view(s,cam,pos);pixel=[v.x*256,(1-v.y)*256];native=[fit['scale']*(pixel[a]-128)+fit['shift'][a]*32 for a in range(2)]
  points[identity]={'rotated_model_position':list(pos),'rotated_outward':list(normal),'source_pixel':pixel,'native_draw_pixel_relative_entity_origin':native}
  if i<2:residual=max(residual,math.dist(native,targets[name][i]))
 assert residual<1e-4,(name,residual)
 directions.append({'native_direction':name,'source_yaw_degrees':yaw,'sockets':points,'max_mouth_draw_residual_px':residual})
report={'status':'PASS_ACTUAL_GLB_BOUNDS_MATING_PLANES_FIXED_MOUNT_AND_DIRECTIONAL_DRAW','glb_sha256':hashlib.sha256((out/'boiler-v08-cold.glb').read_bytes()).hexdigest(),'bounds_blender_model_space':bounds,'ground_z':bounds[0][2],'pipe_flange_contacts':contact,'circuit_mount':{'position':list(wire),'support_bounds':bb},'directions':directions,'mapping_note':'These are source-model sockets and current sprite draw projections. Factorio fluidbox declarations are unchanged; model metres are not claimed to map directly to native grid tiles.'}
(out/'socket-bounds-validation.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8');print('SOCKET_BOUNDS_PASS',bounds,'MAX_DRAW_PX',max(d['max_mouth_draw_residual_px'] for d in directions))
