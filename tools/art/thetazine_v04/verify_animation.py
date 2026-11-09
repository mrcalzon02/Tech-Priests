"""Compare every moving mesh and morph bounds against the actual imported GLB."""
import bpy,bmesh,hashlib,json,pathlib,sys,math
from mathutils import Vector,Matrix
r=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve();sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def capture(frame):
 s=bpy.context.scene;s.frame_set(frame);bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();rows={}
 for o in s.objects:
  if o.type!='MESH' or o.get('render_only_volume'):continue
  ev=o.evaluated_get(dg);m=ev.to_mesh();pts=[o.matrix_world@v.co for v in m.vertices]
  rows[o.name]=[[min(v[i] for v in pts) for i in range(3)],[max(v[i] for v in pts) for i in range(3)]];ev.to_mesh_clear()
 sockets={name:list(bpy.data.objects['socket_'+name].matrix_world.translation) for name in ['fuel','oxidizer']}
 assert (Vector(sockets['fuel'])-Vector((-2.5,1,.36))).length<1e-6 and (Vector(sockets['oxidizer'])-Vector((2.5,1,.36))).length<1e-6
 for i in range(12):
  pin=bpy.data.objects[f'V04 exposed hinge through-pin {i:02}'];petal=bpy.data.objects[f'Nozzle articulated petal {i:02}']
  assert (pin.matrix_world.translation-petal.matrix_world.translation).length<2e-5,(frame,i,'hinge pin misses actual petal pivot')
 # Measure the actual transformed shaft tips against their pin centers,
 # rather than trusting the builder's recorded target lengths.
 for i in range(12):
  root=bpy.data.objects['V04 gimballed ram housing '+str(i)];shaft=bpy.data.objects['V04 telescoping chrome piston shaft '+str(i)];pin=bpy.data.objects['V04 moving restraint pin '+str(i)];gland=bpy.data.objects['V04 forward gland '+str(i)]
  origin=root.matrix_world.translation;axis=(root.matrix_world.to_3x3()@Vector((0,0,1))).normalized();target=pin.matrix_world.translation;length=(target-origin).length
  assert (target-origin-axis*length).length<2e-5,(frame,i,'ram misses pin')
  projected=[(shaft.matrix_world@v.co-origin).dot(axis) for v in shaft.data.vertices];gland_end=max((gland.matrix_world@v.co-origin).dot(axis) for v in gland.data.vertices)
  assert abs(min(projected)-.90)<2e-5 and abs(max(projected)-(length-.08))<2e-5,(frame,i,'shaft endpoints')
  assert abs((gland_end-min(projected))-.22)<2e-5,(frame,i,'gland overlap')
 root=bpy.data.objects.get('V04 independently suspended engine core') or bpy.data.objects['V04 engine structural recoil frame'];pivot=Vector(root['rest_pivot']);undo=Matrix.Translation(pivot)@root.matrix_world.inverted();local={}
 for o in s.objects:
  if o.type=='MESH' and o.name.startswith('V04 stationary'):
   pts=[undo@o.matrix_world@v.co for v in o.data.vertices];local[o.name]=[[min(v[i] for v in pts) for i in range(3)],[max(v[i] for v in pts) for i in range(3)]]
 return {'parts':rows,'sockets':sockets,'regenerative_local':local}
bpy.ops.wm.open_mainfile(filepath=str(r/'thetazine-v04-regenerative-study.blend'));s=bpy.context.scene
topology=[]
for o in s.objects:
 if o.type=='MESH' and o.name.startswith(('Nozzle articulated petal','V04 interleaved containment seal')):
  bm=bmesh.new();bm.from_mesh(o.data);boundary=sum(not e.is_manifold for e in bm.edges);bm.free();assert boundary==0,(o.name,boundary);assert o.rotation_mode=='QUATERNION';topology.append({'name':o.name,'nonmanifold_edges':boundary})
assert len(topology)==24
native=[capture(i+1) for i in range(65)];assert native[0]==native[64],'Native wrap must be exact'
fixed_names=[name for name in native[0]['parts'] if name.startswith(('fuel socket flange','fuel flange fastener','oxidizer socket flange','oxidizer flange fastener','Platform saddle foot','V04 anchored platform pedestal','V04 fixed external'))]
assert len(fixed_names)>=20
for row in native:
 for name in fixed_names:assert row['parts'][name]==native[0]['parts'][name],('fixed attachment moved',name)
stationary_names=[name for name in native[0]['parts'] if name.startswith('V04 stationary')]
assert len(stationary_names)==16
for row in native:
 for name in stationary_names:assert max(abs(row['regenerative_local'][name][a][k]-native[0]['regenerative_local'][name][a][k]) for a in range(2) for k in range(3))<2e-5,('regenerative circuit must be stationary relative to engine',name)
for record in native:
 for name,part in record['parts'].items():assert all(math.isfinite(v) and abs(v)<50 for row in part for v in row),name
motion={prefix:max(abs(native[i]['parts'][name][axis][k]-native[0]['parts'][name][axis][k]) for i in range(64) for name in native[0]['parts'] if name.startswith(prefix) for axis in range(2) for k in range(3)) for prefix in ['Nozzle articulated petal','V04 interleaved containment seal','V04 telescoping chrome piston shaft','V04 animated pump plunger','V04 moving containment gauge needle','V04 Archimedes helical flight','V04 flexible socket bellows','V04 overhead three-dimensional service bridge']}
fixed_families={'V04 flexible socket bellows','V04 overhead three-dimensional service bridge'}
assert all(v==0 if n in fixed_families else v>.001 for n,v in motion.items()),motion
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.scene.render.fps=30;bpy.ops.import_scene.gltf(filepath=str(r/'thetazine-v04-regenerative-study.glb'))
error=0;worst=None
for i in range(65):
 imported=capture(i+1);assert imported['parts'].keys()==native[i]['parts'].keys()
 for name,part in native[i]['parts'].items():
  delta=max(abs(part[j][k]-imported['parts'][name][j][k]) for j in range(2) for k in range(3))
  if delta>error:error=delta;worst=[i+1,name]
  assert delta<4e-5,(i+1,name,delta)
result={'status':'PASS_ACTUAL_GLB_ALL_MESHES_64_POSES_MORPHS_FIXED_SOCKETS_CLOSED_LEAVES','native_sha256':sha(r/'thetazine-v04-regenerative-study.blend'),'glb_sha256':sha(r/'thetazine-v04-regenerative-study.glb'),'sampled_cycle_frames':64,'wrap_frame':65,'source_fps':30,'all_meshes_each_pose':len(native[0]['parts']),'max_world_bounds_delta':error,'worst':worst,'motion_by_family':motion,'closed_petal_topology':topology,'native_wrap_exact':True,'stationary_regenerative_parts':stationary_names,'actual_shaft_tip_and_pin_measurement':'12 shafts x65 poses x2 artifacts; .08 pin-center inset and .22 gland overlap, tolerance2e-5','scope':'Local Blender mechanical/morph interchange only. Cold frame 0 and material heat-strength animation remain native Blender source states; no game import or behavior acceptance.'}
(r/'animation-validation.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n');print('V04_ANIMATION_REIMPORT_PASS',error,motion)
