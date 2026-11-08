"""Independent native reopen, GLB reimport and matched studio review."""
import bpy,json,sys,pathlib,math,hashlib
from mathutils import Vector
O=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve();source=pathlib.Path(sys.argv[sys.argv.index('--')+2]).resolve()
def stats():
 dg=bpy.context.evaluated_depsgraph_get();out={};points=[];triangles=degenerate=0
 for o in bpy.context.scene.objects:
  if o.type!='MESH':continue
  ev=o.evaluated_get(dg);m=ev.to_mesh();m.calc_loop_triangles();p=[o.matrix_world@v.co for v in m.vertices];points.extend(p)
  assert all(math.isfinite(v) for point in p for v in point),o.name
  assert m.uv_layers and all(math.isfinite(v) for uv in m.uv_layers.active.data for v in uv.uv),o.name
  bad=sum((p[t.vertices[1]]-p[t.vertices[0]]).cross(p[t.vertices[2]]-p[t.vertices[0]]).length<1e-12 for t in m.loop_triangles)
  triangles+=len(m.loop_triangles);degenerate+=bad
  out[o.name]={'vertices':len(m.vertices),'triangles':len(m.loop_triangles),'degenerate':bad,'bounds':[[min(v[i] for v in p) for i in range(3)],[max(v[i] for v in p) for i in range(3)]]}
  ev.to_mesh_clear()
 return {'meshes':len(out),'triangles':triangles,'degenerate':degenerate,'bounds':[[min(v[i] for v in points) for i in range(3)],[max(v[i] for v in points) for i in range(3)]],'parts':out}
def setup():
 S=bpy.context.scene
 for o in list(S.objects):
  if o.type in ('CAMERA','LIGHT'):bpy.data.objects.remove(o,do_unlink=True)
 for name,loc,energy,size in [('Key',(4,-5,7),1100,5),('Fill',(-4,-2,5),650,4),('Rim',(1,5,6),900,3)]:
  data=bpy.data.lights.new(name,'AREA');data.energy=energy;data.shape='DISK';data.size=size;o=bpy.data.objects.new(name,data);S.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,2.6))-o.location).to_track_quat('-Z','Y').to_euler()
 data=bpy.data.cameras.new('Independent review');camera=bpy.data.objects.new(data.name,data);S.collection.objects.link(camera);S.camera=camera;data.type='ORTHO';data.ortho_scale=3.5
 S.world=bpy.data.worlds.new('Matched studio world');S.world.use_nodes=True;S.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.16,.18,.22,1);S.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.4
 S.use_nodes=False;S.render.use_compositing=False;S.render.use_sequencer=False;S.render.engine='CYCLES';S.cycles.device='CPU';S.cycles.samples=16;S.cycles.use_denoising=True
 S.render.resolution_x=S.render.resolution_y=512;S.render.resolution_percentage=100;S.render.film_transparent=True;S.render.image_settings.file_format='PNG';S.render.image_settings.color_mode='RGBA';S.view_settings.view_transform='AgX'
 for layer in S.view_layers:layer.material_override=None;layer.use=True
 return S
def render(S,label,pos,scale=3.5,size=512):
 if '--measure-only' in sys.argv:return
 S.camera.location=pos;S.camera.rotation_euler=(Vector((0,0,2.65))-S.camera.location).to_track_quat('-Z','Y').to_euler();S.camera.data.ortho_scale=scale;S.render.resolution_x=S.render.resolution_y=size
 S.render.filepath=str(O/(label+'.png'));bpy.ops.render.render(write_still=True)
report={'status':'review_in_progress','scope':'model/export/studio renders only; no bunker-base or native game placement claim','files':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in [source,O/'energy_dish_v03.blend',O/'energy_dish_v03.glb']}}
bpy.ops.wm.open_mainfile(filepath=str(source));report['source']=stats();S=setup();render(S,'source-front',(5,-7,5.5));render(S,'source-rear',(-5,7,5.5))
bpy.ops.wm.open_mainfile(filepath=str(O/'energy_dish_v03.blend'));report['native']=stats()
assert report['native']['degenerate']==0
assert all(im.packed_file or im.source in ('GENERATED','VIEWER') for im in bpy.data.images)
for name in ('CONTINUOUS_SIDE_RAIL_-1','CONTINUOUS_SIDE_RAIL_1'):
 m=bpy.data.objects[name].data;adj=[set() for v in m.vertices]
 for e in m.edges:a,b=e.vertices;adj[a].add(b);adj[b].add(a)
 seen={0};pending=[0]
 while pending:
  for v in adj[pending.pop()]-seen:seen.add(v);pending.append(v)
 assert len(seen)==len(m.vertices),name
root=bpy.data.objects['TURRET_TRAVERSE'];pivot=bpy.data.objects['WEAPON_ELEVATION'];assert (root.matrix_world.translation-Vector((0,0,1.7))).length<1e-5;assert (pivot.matrix_world.translation-Vector((0,0,2.34))).length<1e-5
assert all(o.parent in (root,pivot) for o in bpy.context.scene.objects if o.type=='MESH')
S=setup();render(S,'native-front',(5,-7,5.5));render(S,'native-rear',(-5,7,5.5));render(S,'native-256-review',(5,-7,5.5),3.5,256)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(O/'energy_dish_v03.glb'));report['glb']=stats()
(O/'independent-measurements.json').write_text(json.dumps(report,indent=2)+'\n')
assert report['glb']['meshes']==report['native']['meshes'] and report['glb']['triangles']==report['native']['triangles'] and report['glb']['degenerate']==0
delta=max(abs(report['glb']['bounds'][i][j]-report['native']['bounds'][i][j]) for i in range(2) for j in range(3));assert delta<1e-5,delta
assert all(o.name in report['native']['parts'] for o in bpy.context.scene.objects if o.type=='MESH')
report['max_roundtrip_bounds_delta']=delta;report['packed_source_images']=True;report['rail_components_each']=1
S=setup();render(S,'glb-front',(5,-7,5.5));render(S,'glb-rear',(-5,7,5.5))
clay=bpy.data.materials.new('Diagnostic clay');clay.diffuse_color=(.38,.38,.38,1);clay.use_nodes=True;clay.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.38,.38,.38,1);clay.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.8
for layer in S.view_layers:layer.material_override=clay
render(S,'glb-clay',(5,-7,5.5));report['status']='TECHNICAL_PASS_VISUAL_REVIEW_PENDING'
(O/'independent-validation.json').write_text(json.dumps(report,indent=2)+'\n');print('DISH_INDEPENDENT_REVIEW_COMPLETE',flush=True)
