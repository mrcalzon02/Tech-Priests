"""Synchronize edited Basis meshes with glTF base buffers, preserving evaluated poses."""
import bpy,pathlib,sys,json,hashlib,tempfile
P=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve();R=pathlib.Path(sys.argv[sys.argv.index('--')+2]).resolve();R.mkdir(exist_ok=False);tempfile.tempdir=str(R/'export-temp');pathlib.Path(tempfile.tempdir).mkdir();sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();m=json.loads((P/'source-manifest.json').read_text());bpy.ops.wm.open_mainfile(filepath=str(P/'thetazine-v04-regenerative-study.blend'));s=bpy.context.scene;s.frame_set(0);changes=[]
for o in s.objects:
 if o.type!='MESH' or not o.data.shape_keys:continue
 basis=o.data.shape_keys.key_blocks[0];d=max((v.co-k.co).length for v,k in zip(o.data.vertices,basis.data))
 if d>0:
  changes.append({'mesh':o.name,'maximum_base_buffer_difference':d})
  for v,k in zip(o.data.vertices,basis.data):v.co=k.co
  o.data.update()
s.frame_set(1);bpy.context.view_layer.update();bpy.ops.wm.save_as_mainfile(filepath=str(R/'thetazine-v04-regenerative-study.blend'),compress=True)
for o in s.objects:o.select_set(o.type in ['MESH','EMPTY'] and not o.get('render_only_volume'))
bpy.ops.export_scene.gltf(filepath=str(R/'thetazine-v04-regenerative-study.glb'),use_selection=True,export_format='GLB',export_apply=True,export_current_frame=True,export_animations=True,export_animation_mode='SCENE',export_anim_scene_split_object=False,export_frame_range=True,export_force_sampling=True,export_morph=True,export_morph_animation=True,export_extras=True)
m['native_sha256']=sha(R/'thetazine-v04-regenerative-study.blend');m['glb_sha256']=sha(R/'thetazine-v04-regenerative-study.glb');m['basis_buffer_sync']={'input_native_sha256':sha(P/'thetazine-v04-regenerative-study.blend'),'script_sha256':sha(pathlib.Path(__file__)),'changes':changes};(R/'source-manifest.json').write_text(json.dumps(m,indent=2)+'\n',encoding='utf-8',newline='\n');print('BASIS_BUFFER_SYNC',changes)
