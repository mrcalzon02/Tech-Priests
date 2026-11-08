import bpy,json,math,pathlib,sys
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from bpy_extras.object_utils import world_to_camera_view
r=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve();bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(r/'hydrogen-thruster-v01.glb'));s=bpy.context.scene
contacts=[]
for name,sign in [('fuel',-1),('oxidizer',1)]:
 socket=bpy.data.objects['socket_'+name];flange=bpy.data.objects[name+' socket flange'];pts=[flange.matrix_world@v.co for v in flange.data.vertices];bb=[[min(v[i] for v in pts) for i in range(3)],[max(v[i] for v in pts) for i in range(3)]];position=socket.matrix_world.translation;normal=(socket.matrix_world.to_3x3()@Vector((0,0,1))).normalized()
 assert abs(position.x-bb[0 if sign<0 else 1][0])<1e-6 and abs(position.y-(bb[0][1]+bb[1][1])/2)<1e-6 and abs(position.z-(bb[0][2]+bb[1][2])/2)<1e-6
 assert (normal-Vector((sign,0,0))).length<1e-6
 contacts.append({'name':name,'position':list(position),'normal':list(normal),'actual_flange_bounds':bb})
feet=[]
for o in s.objects:
 if o.type=='MESH' and o.name.startswith('Platform saddle foot '):
  pts=[o.matrix_world@v.co for v in o.data.vertices];low=min(v.z for v in pts);assert abs(low)<1e-6;feet.append({'name':o.name,'min_z':low})
assert len(feet)==2
reg=json.loads((r/'draw-registration.json').read_text(encoding='utf-8'));cam=bpy.data.objects.new('Independent fixed-camera projection',bpy.data.cameras.new('Projection'));s.collection.objects.link(cam);target=Vector((0,-1.3,-.5));cam.location=target+Vector((0,-12,12));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=9;s.camera=cam;s.render.resolution_x=512;s.render.resolution_y=768;bpy.context.view_layer.update();errors=[]
for point in contacts:
 v=world_to_camera_view(s,cam,Vector(point['position']));pixel=[v.x*512,(1-v.y)*768];predicted=[(pixel[i]-[256,384][i])*reg['scale']+reg['shift'][i]*32 for i in range(2)];expected=[-64 if point['name']=='fuel' else 64,-18];error=math.dist(predicted,expected);assert error<1e-4;errors.append(error);point['native_pixel_prediction']=predicted;point['native_pixel_target']=expected
# Independently inspect the corrected mounting head contact on the reopened native.
bpy.ops.wm.open_mainfile(filepath=str(r/'hydrogen-thruster-v01.blend'));s=bpy.context.scene;s.frame_set(0);bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();cache={}
groups={'Regulator rim stud':'Recessed regulator rim','Saddle fastener':'Crossbeam saddle','Deck foot bolt':'Platform saddle foot','Shoulder pivot pin':'Shoulder pivot','Feed receiver screw':'Feed upper manifold','Clevis fixed pin':'Actuator support clevis','Pressure flange stud':'Pressure chamber retaining band','Beam face rivet':'Upper mounting beam'}
def tree(o):
 if o.name not in cache:
  e=o.evaluated_get(dg);m=e.to_mesh();cache[o.name]=BVHTree.FromPolygons([o.matrix_world@v.co for v in m.vertices],[list(p.vertices) for p in m.polygons]);e.to_mesh_clear()
 return cache[o.name]
hardware=[]
for prefix,support_prefix in groups.items():
 supports=[o for o in s.objects if o.type=='MESH' and o.name.startswith(support_prefix)]
 for o in s.objects:
  if o.type!='MESH' or not o.name.startswith(prefix):continue
  # Hex-head construction preserves its six back-ring vertices through baking.
  samples=[o.matrix_world@v.co for v in o.data.vertices[:6]];samples.append(sum(samples,Vector())/6)
  distance=min(tree(support).find_nearest(point)[3] for support in supports for point in samples);assert distance<2e-5,(o.name,distance)
  hardware.append({'name':o.name,'support_group':support_prefix,'nearest_back_face_support_distance':distance})
out={'status':'PASS_IMPORTED_MATING_PLANES_FOOT_CONTACT_FIXED_CAMERA_AND_MOUNTING_HEAD_CONTACT','contacts':contacts,'feet':feet,'max_native_mouth_pixel_error':max(errors),'mounting_heads_checked':len(hardware),'max_checked_head_support_distance':max(v['nearest_back_face_support_distance'] for v in hardware),'hardware':hardware,'scope':'One fixed native north-facing body. Imported model sockets and plane centers, two feet at the platform plane, and listed mounting-head groups only; this is not a claim about every geometric intersection or gameplay connectivity.'}
(r/'interface-validation.json').write_text(json.dumps(out,indent=2)+'\n',encoding='utf-8');print('INTERFACES_PASS',len(hardware),out['max_checked_head_support_distance'],max(errors))
