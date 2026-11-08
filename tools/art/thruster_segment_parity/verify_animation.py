import bpy,bmesh,hashlib,json,pathlib,sys
from mathutils import Vector
r=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve();sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def capture(frame,source):
 s=bpy.context.scene;s.frame_set(frame);bpy.context.view_layer.update();rows={}
 for o in s.objects:
  if o.type=='MESH' and (o.name.startswith('Nozzle articulated petal') or o.name.startswith('Articulated actuator rod')):
   pts=[o.matrix_world@v.co for v in o.data.vertices];rows[o.name]=[[min(v[i] for v in pts) for i in range(3)],[max(v[i] for v in pts) for i in range(3)]]
 sockets={name:list(bpy.data.objects['socket_'+name].matrix_world.translation) for name in ['fuel','oxidizer']}
 assert (Vector(sockets['fuel'])-Vector((-2.5,1,.36))).length<1e-6 and (Vector(sockets['oxidizer'])-Vector((2.5,1,.36))).length<1e-6
 return {'parts':rows,'sockets':sockets}
bpy.ops.wm.open_mainfile(filepath=str(r/'thetazine-animation-study.blend'));s=bpy.context.scene
topology=[]
for o in s.objects:
 if o.type=='MESH' and o.name.startswith('Nozzle articulated petal'):
  bm=bmesh.new();bm.from_mesh(o.data);boundary=sum(not e.is_manifold for e in bm.edges);bm.free();assert boundary==0,(o.name,boundary);topology.append({'name':o.name,'nonmanifold_edges':boundary})
assert len(topology)==12
native=[capture(i+1,True) for i in range(65)]
assert native[0]==native[64],'Native wrap must be exact'
for record in native:
 for name,part in record['parts'].items():assert all(abs(v)<50 for row in part for v in row),name
motion=max(abs(native[i]['parts'][name][axis][k]-native[0]['parts'][name][axis][k]) for i in range(64) for name in native[0]['parts'] if name.startswith('Nozzle articulated petal') for axis in range(2) for k in range(3));assert motion>.01,motion
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.scene.render.fps=30;bpy.ops.import_scene.gltf(filepath=str(r/'thetazine-animation-study.glb'))
imported=[capture(i+1,False) for i in range(65)];error=0
for i in range(65):
 assert imported[i]['parts'].keys()==native[i]['parts'].keys()
 for name,part in native[i]['parts'].items():
  delta=max(abs(part[j][k]-imported[i]['parts'][name][j][k]) for j in range(2) for k in range(3));assert delta<2e-5,(i,name,delta);error=max(error,delta)
result={'status':'PASS_ACTUAL_GLB_64_FRAME_MECHANICAL_REIMPORT_FIXED_SOCKETS_AND_CLOSED_PETALS','native_sha256':sha(r/'thetazine-animation-study.blend'),'glb_sha256':sha(r/'thetazine-animation-study.glb'),'sampled_cycle_frames':64,'wrap_frame':65,'source_fps':30,'source_frames':'1..65','imported_frames':'1..65; clip retains source time 1/30..65/30 seconds','animated_parts_checked_each_pose':len(native[0]['parts']),'max_world_bounds_delta':error,'max_petal_bbox_motion_units':motion,'closed_petal_topology':topology,'socket_frames_checked_each_source':65,'native_wrap_exact':True,'scope':'Mechanical clip and socket inspection only. Emission material animation is authored in Blender and rendered separately; not claimed as a glTF material animation or native working-clock acceptance.'}
(r/'animation-validation.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n');print('ANIMATION_REIMPORT_PASS',motion,error)
