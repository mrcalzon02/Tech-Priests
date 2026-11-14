"""Non-destructive A02 interchange derivative, sampled from the frozen sprite pose authority."""
import bpy,pathlib,json,hashlib,sys,os,time,shutil
from mathutils import Matrix
W=pathlib.Path(__file__).resolve().parent;P=W/'lobber-a02';O=W/'a02-gltf-20261114';SRC=P/'lobber_capture.blend';EXPECTED='0c9ebf42b16ddd53a8162d836bb88a052c77f16c28f4e7265172300797e372ed'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();assert sha(SRC)==EXPECTED
O.mkdir(exist_ok=True);state_path=O/'CHECKPOINT.json'
resume='--resume-boundaries' in sys.argv
if state_path.exists():
 if not resume:raise RuntimeError('Inspect prior checkpoint/process before resuming; no duplicate or overwrite')
 state=json.loads(state_path.read_text());assert state['status']=='FOUR_LOCAL_EXPORTS_REQUIRE_INDEPENDENT_REIMPORT' and state['source_sha256']==EXPECTED
 for row in state['completed']:assert sha(O/(row['mode']+'.glb'))==row['glb_sha256']
 backup=O/'initial-transition-endpoint-study';backup.mkdir(exist_ok=False)
 for mode in ['entry','settle']:
  for suffix in ['.glb','-derivative.blend','-sampled-source.json']:shutil.copy2(O/(mode+suffix),backup/(mode+suffix))
 state['pid']=os.getpid()
else:
 assert not resume
 state={'status':'STARTED','pid':os.getpid(),'source_sha256':EXPECTED,'source_unchanged':True,'completed':[],'started_unix':time.time()}
def checkpoint(status,**kwargs):
 state.update(status=status,**kwargs);t=O/'CHECKPOINT.tmp';t.write_text(json.dumps(state,indent=2)+'\n',encoding='utf-8',newline='\n');t.replace(state_path)
for mode,count in ([('entry',16),('settle',16)] if resume else [('idle',1),('cycle',193),('entry',16),('settle',16)]):
 checkpoint('SAMPLING_SOURCE',mode=mode)
 bpy.ops.wm.open_mainfile(filepath=str(SRC));sys.path.insert(0,str(P))
 sys.modules.pop('capture_common',None);import capture_common as authority
 s=bpy.context.scene
 # Volume smoke remains in editable source/sprite passes. Core glTF has no volume shader equivalent.
 excluded=[o for o in s.objects if o.type=='MESH' and (o.name=='CAPTURE_SHADOW_RECEIVER' or o.name.startswith('MUZZLE_SMOKE_'))]
 meshes=[o for o in s.objects if o.type=='MESH' and o not in excluded]
 assert len(meshes)==302 and len(excluded)==19
 objects=set(meshes)
 for o in meshes:
  parent=o.parent
  while parent:objects.add(parent);parent=parent.parent
 objects=sorted(objects,key=lambda o:o.name)
 assert all(o.type in ['MESH','EMPTY'] for o in objects)
 records={o.name:[] for o in objects};shape_records={o.name:[] for o in meshes if o.data.shape_keys};modifier_scope={o.name:[{'name':m.name,'type':m.type} for m in o.modifiers] for o in meshes if len(o.modifiers)}
 for f in range(count):
  authority.pose(0,f,mode)
  for o in objects:
   local=o.parent.matrix_world.inverted_safe()@o.matrix_world if o.parent in objects else o.matrix_world.copy()
   pos,rot,scale=local.decompose();hidden=o.type=='MESH' and o.hide_render
   if hidden:
    assert not o.children,('Visibility scale would affect children',o.name)
    scale*=0
   records[o.name].append({'location':list(pos),'rotation':list(rot),'scale':list(scale),'source_hidden':hidden})
  for o in meshes:
   if o.name in shape_records:shape_records[o.name].append({k.name:k.value for k in o.data.shape_keys.key_blocks if k!=o.data.shape_keys.reference_key})
 sample={'source_sha256':EXPECTED,'mode':mode,'fps':24,'frames':count,'direction':0,'mapping':'north0_clockwise; authoring source retained, glTF Y-up export','objects':records,'shape_keys':shape_records,'modifiers':modifier_scope,'excluded_volume_meshes':[o.name for o in excluded if o.name.startswith('MUZZLE_SMOKE_')],'excluded_capture_receiver':True,'visibility_adapter':'Only leaf hidden-render meshes get zero scale. All source-visible transforms and material/UV data retained.'}
 sample_path=O/(mode+'-sampled-source.json');sample_path.write_text(json.dumps(sample,indent=2)+'\n',encoding='utf-8',newline='\n');checkpoint('SOURCE_SAMPLED',mode=mode,source_sample_sha256=sha(sample_path))
 # Detach source animation only inside this in-memory derivative; original .blend is never saved.
 for o in objects:
  o.animation_data_clear();o.constraints.clear();o.matrix_parent_inverse=Matrix.Identity(4)
  if o.type=='MESH':
   o.hide_render=False;o.hide_viewport=False;o.hide_set(False)
   if o.data.shape_keys:o.data.shape_keys.animation_data_clear()
 for o in objects:
  o.rotation_mode='QUATERNION'
  for f,row in enumerate(records[o.name],1):
   o.location=row['location'];o.rotation_quaternion=row['rotation'];o.scale=row['scale']
   if count>1:
    for prop in ['location','rotation_quaternion','scale']:o.keyframe_insert(prop,frame=f)
  if o.name in shape_records:
   for f,row in enumerate(shape_records[o.name],1):
    for name,value in row.items():
     k=o.data.shape_keys.key_blocks[name];k.value=value
     if count>1:k.keyframe_insert('value',frame=f)
 s.render.fps=24;s.frame_start=1;s.frame_end=count;s.frame_set(1);bpy.context.view_layer.update()
 # Preserve explicit interpolation. Samples are authoritative at integer24fps frames.
 for datablock in list(objects)+[o.data.shape_keys for o in meshes if o.data.shape_keys]:
  ad=datablock.animation_data
  if ad and ad.action:
   for layer in ad.action.layers:
    for strip in layer.strips:
     for bag in strip.channelbags:
      for fc in bag.fcurves:
       for key in fc.keyframe_points:key.interpolation='LINEAR'
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=meshes[0]
 # Keep original modifier stack in derivative; independent roundtrip must assess its actual export.
 derivative=O/(mode+'-derivative.blend');bpy.ops.wm.save_as_mainfile(filepath=str(derivative))
 checkpoint('EXPORTING_GLTF',mode=mode,derivative_sha256=sha(derivative))
 dest=O/(mode+'.glb')
 bpy.ops.export_scene.gltf(filepath=str(dest),export_format='GLB',use_selection=True,export_yup=True,export_animations=count>1,export_animation_mode='SCENE',export_frame_range=True,export_frame_step=1,export_force_sampling=True,export_morph=True,export_morph_animation=True,export_cameras=False,export_lights=False,export_apply=False)
 state['completed']=[row for row in state['completed'] if row['mode']!=mode]
 state['completed'].append({'mode':mode,'frames':count,'glb_sha256':sha(dest),'glb_bytes':dest.stat().st_size,'sample_sha256':sha(sample_path),'native_derivative_sha256':sha(derivative)})
 assert sha(SRC)==EXPECTED
 checkpoint('MODE_EXPORTED_REQUIRES_INDEPENDENT_REIMPORT',mode=mode)
 print('A02_MODE_EXPORTED',mode,dest.stat().st_size,flush=True)
checkpoint('FOUR_LOCAL_EXPORTS_REQUIRE_INDEPENDENT_REIMPORT',source_unchanged=sha(SRC)==EXPECTED)
