"""Correct outward orientation of closed bell shells without changing their surfaces."""
import bpy,bmesh,pathlib,sys,json,hashlib,tempfile,collections,struct
P=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve();R=pathlib.Path(sys.argv[sys.argv.index('--')+2]).resolve();R.mkdir(exist_ok=False);tempfile.tempdir=str(R/'export-temp');pathlib.Path(tempfile.tempdir).mkdir();sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();src=P/'thetazine-v04-regenerative-study.blend';m=json.loads((P/'source-manifest.json').read_text());assert sha(src)==m['native_sha256'];bpy.ops.wm.open_mainfile(filepath=str(src));s=bpy.context.scene;s.frame_set(0);bpy.context.view_layer.update();records=[]
def surface(me):
 uv=me.uv_layers.active;return collections.Counter((p.material_index,tuple(sorted(tuple(me.vertices[me.loops[li].vertex_index].co)+tuple(uv.data[li].uv) for li in p.loop_indices))) for p in me.polygons)
def topology(me):
 edges=collections.defaultdict(list)
 for p in me.polygons:
  for i in range(len(p.vertices)):
   a,b=p.vertices[i],p.vertices[(i+1)%len(p.vertices)];edges[tuple(sorted((a,b)))].append((a,b))
 return {'non_two_use_edges':sum(len(v)!=2 for v in edges.values()),'inconsistent_edges':sum(len(v)==2 and v[0]==v[1] for v in edges.values())}
for o in s.objects:
 if o.type!='MESH' or not o.name.startswith(('Nozzle articulated petal','V04 interleaved containment seal')):continue
 me=o.data;before=surface(me);coords=[tuple(v.co) for v in me.vertices];old=topology(me);assert old['non_two_use_edges']==0
 bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
 if bm.calc_volume(signed=True)<0:bmesh.ops.reverse_faces(bm,faces=list(bm.faces))
 volume=bm.calc_volume(signed=True);assert volume>0;bm.to_mesh(me);bm.free();me.update();after=topology(me);assert after=={'non_two_use_edges':0,'inconsistent_edges':0};assert before==surface(me),(o.name,'UV/material/surface changed');assert coords==[tuple(v.co) for v in me.vertices],(o.name,'vertices changed');records.append({'mesh':o.name,'before':old,'after':after,'positive_local_volume':volume,'vertices':len(coords),'faces':len(me.polygons)})
assert len(records)==24
s.frame_set(1);bpy.context.view_layer.update();bpy.ops.wm.save_as_mainfile(filepath=str(R/src.name),compress=True)
for o in s.objects:o.select_set(o.type in ['MESH','EMPTY'] and not o.get('render_only_volume'))
bpy.ops.export_scene.gltf(filepath=str(R/'thetazine-v04-regenerative-study.glb'),use_selection=True,export_format='GLB',export_apply=True,export_current_frame=True,export_animations=True,export_animation_mode='SCENE',export_anim_scene_split_object=False,export_frame_range=True,export_force_sampling=True,export_morph=True,export_morph_animation=True,export_extras=True)
m['native_sha256']=sha(R/src.name);m['glb_sha256']=sha(R/'thetazine-v04-regenerative-study.glb');m['closed_shell_winding_repair']={'status':'PASS_24_OUTWARD_CLOSED_SHELLS_EXACT_POSITIONS_UV_MATERIALS','script_sha256':sha(pathlib.Path(__file__)),'input_native_sha256':sha(src),'parts':records};(R/'source-manifest.json').write_text(json.dumps(m,indent=2)+'\n',encoding='utf-8',newline='\n');(R/'shell-winding-repair.json').write_text(json.dumps(m['closed_shell_winding_repair'],indent=2)+'\n',encoding='utf-8',newline='\n');print('BELL_SHELL_ORIENTATION_REPAIRED',len(records),m['native_sha256'])
