"""Inspect actual imported fittings and source support contacts, without a behavior test."""
import bpy, json, math, pathlib, sys, hashlib
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from bpy_extras.object_utils import world_to_camera_view
r=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(r/'thetazine-thruster-v01.glb'))
s=bpy.context.scene;contacts=[]
for name,sign in [('fuel',-1),('oxidizer',1)]:
 o=bpy.data.objects['socket_'+name];flange=bpy.data.objects[name+' socket flange']
 pts=[flange.matrix_world@v.co for v in flange.data.vertices];bounds=[[min(v[i] for v in pts) for i in range(3)],[max(v[i] for v in pts) for i in range(3)]]
 point=o.matrix_world.translation;normal=(o.matrix_world.to_3x3()@Vector((0,0,1))).normalized()
 expected=Vector((sign*2.5,1,.36));assert (point-expected).length<1e-6
 assert (normal-Vector((sign,0,0))).length<1e-6
 assert abs(bounds[0 if sign<0 else 1][0]-point.x)<1e-6
 assert abs((bounds[0][1]+bounds[1][1])/2-point.y)<1e-6 and abs((bounds[0][2]+bounds[1][2])/2-point.z)<1e-6
 contacts.append({'name':name,'position':list(point),'normal':list(normal),'flange_bounds':bounds})
feet=[]
for o in s.objects:
 if o.type=='MESH' and o.name.startswith('Platform saddle foot '):
  low=min((o.matrix_world@v.co).z for v in o.data.vertices);assert abs(low)<1e-6;feet.append({'name':o.name,'lowest_z':low})
assert len(feet)==2
bpy.ops.wm.open_mainfile(filepath=str(r/'thetazine-thruster-v01.blend'));s=bpy.context.scene;s.frame_set(0);bpy.context.view_layer.update()
scale=32/(768/11.25);errors=[];shifts=[];projected=[]
for item in contacts:
 v=world_to_camera_view(s,s.camera,Vector(item['position']));pixel=[v.x*512,(1-v.y)*768]
 target=[-80 if item['name']=='fuel' else 80,-34]
 shifts.append([(target[i]-(pixel[i]-[256,384][i])*scale)/32 for i in range(2)])
 projected.append({'name':item['name'],'source_pixel':pixel,'native_visual_target_pixel':target})
assert math.dist(*shifts)<1e-6
shift=[sum(p[i] for p in shifts)/2 for i in range(2)]
for item in projected:
 pred=[(item['source_pixel'][i]-[256,384][i])*scale+shift[i]*32 for i in range(2)]
 errors.append(math.dist(pred,item['native_visual_target_pixel']))
dg=bpy.context.evaluated_depsgraph_get();cache={}
def tree(o):
 if o.name not in cache:
  e=o.evaluated_get(dg);m=e.to_mesh();cache[o.name]=BVHTree.FromPolygons([o.matrix_world@v.co for v in m.vertices],[list(p.vertices) for p in m.polygons]);e.to_mesh_clear()
 return cache[o.name]
groups={'Regulator rim stud':'Recessed regulator rim','Saddle fastener':'Crossbeam saddle','Deck foot bolt':'Platform saddle foot','Shoulder pivot pin':'Shoulder pivot','Feed receiver screw':'Feed upper manifold','Clevis fixed pin':'Actuator support clevis','Pressure flange stud':'Pressure chamber retaining band','Beam face rivet':'Upper mounting beam'}
hardware=[]
for prefix,support in groups.items():
 supports=[o for o in s.objects if o.type=='MESH' and o.name.startswith(support)]
 for o in s.objects:
  if o.type!='MESH' or not o.name.startswith(prefix):continue
  samples=[o.matrix_world@v.co for v in o.data.vertices[:6]];samples.append(sum(samples,Vector())/6)
  distance=min(tree(v).find_nearest(p)[3] for v in supports for p in samples);assert distance<2e-5,(o.name,distance)
  hardware.append({'name':o.name,'support':support,'nearest_distance':distance})
assert len(hardware)==82
report={'status':'PASS_MODEL_FITTINGS_FEET_AND_LISTED_SUPPORT_CONTACTS_NATIVE_VISUAL_REVIEW_PENDING','native_sha256':sha(r/'thetazine-thruster-v01.blend'),'glb_sha256':sha(r/'thetazine-thruster-v01.glb'),'imported_fittings':contacts,'feet':feet,'mounting_heads_checked':len(hardware),'max_head_support_distance':max(v['nearest_distance'] for v in hardware),'hardware':hardware,'proposed_draw_registration':{'scale':scale,'shift':shift,'render_cell':[512,768],'orthographic_scale':11.25,'scope':'Analytical camera fit to +/-2.5,-1 native mating planes at two-pixel pipe-lip height. Requires native visible pipe-mouth/cap proof before installation.'},'projection':projected,'max_predicted_pixel_error':max(errors),'behavior_tests':'not run'}
(r/'interface-validation.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('THETAZINE_INTERFACES_PASS',len(hardware),max(errors))
