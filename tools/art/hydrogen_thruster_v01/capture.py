import bpy,json,pathlib,sys,hashlib,math
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
root=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve();bpy.ops.wm.open_mainfile(filepath=str(root/'hydrogen-thruster-v01.blend'));s=bpy.context.scene;captures=root/'captures';captures.mkdir(exist_ok=True)
native=hashlib.sha256((root/'hydrogen-thruster-v01.blend').read_bytes()).hexdigest();s.view_layers[0].use_pass_emit=True;nt=bpy.data.node_groups.new('Hydrogen actual beauty and emission passes','CompositorNodeTree');s.compositing_node_group=nt;nt.interface.new_socket(name='Image',in_out='OUTPUT',socket_type='NodeSocketColor');rl=nt.nodes.new('CompositorNodeRLayers');output=nt.nodes.new('NodeGroupOutput');nt.links.new(rl.outputs['Image'],output.inputs['Image']);s.render.use_compositing=True
alpha=nt.nodes.new('CompositorNodeSetAlpha');nt.links.new(rl.outputs['Emission'],alpha.inputs['Image']);nt.links.new(rl.outputs['Alpha'],alpha.inputs['Alpha']);fo=nt.nodes.new('CompositorNodeOutputFile');fo.directory=str(captures);fo.format.media_type='IMAGE';fo.format.file_format='PNG';fo.format.color_mode='RGBA';fo.format.color_depth='8';fo.save_as_render=True;fo.file_output_items.new('RGBA','emission');nt.links.new(alpha.outputs['Image'],fo.inputs['emission'])
records=[];receipt=root/'capture-receipt.json'
if receipt.exists():
 old=json.loads(receipt.read_text(encoding='utf-8'));assert old['source_sha256']==native
 for entry in old['files']:
  assert hashlib.sha256((captures/entry['file']).read_bytes()).hexdigest()==entry['sha256'];records.append(entry)
def save_receipt():
 (root/'capture-receipt.json').write_text(json.dumps({'source_sha256':native,'status':'CAPTURED_REQUIRES_REVIEW' if len(records)==28 else 'PARTIAL','files':records,'states':{'idle':list(range(7)),'run':list(range(16,23))},'scope':'Fixed 45-degree camera, 512x768, 16 CPU samples, two threads. No mesh motion invented; 7+7 source emission poses.'},indent=2)+'\n',encoding='utf-8')
for state,frames in [('idle',range(7)),('run',range(16,23))]:
 for index,frame in enumerate(frames):
  if len([v for v in records if v['state']==state and v['index']==index])==2:continue
  if '--pilot' in sys.argv and records:continue
  prefix=state+'-'+str(index).zfill(2);fo.file_name=prefix+'-pass-';before=set(captures.glob('*.png'));s.frame_set(frame);s.render.filepath=str(captures/(prefix+'-beauty.png'));bpy.ops.render.render(write_still=True);dest=pathlib.Path(s.render.filepath)
  generated=[p for p in set(captures.glob('*.png'))-before if p!=dest];assert len(generated)==1,[p.name for p in generated];emission=captures/(prefix+'-emission.png');generated[0].rename(emission)
  records=[v for v in records if not(v['state']==state and v['index']==index)]
  for pass_name,path in [('beauty',dest),('emission',emission)]:records.append({'state':state,'index':index,'source_frame':frame,'pass':pass_name,'file':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
  save_receipt()
# Save the source camera's measured fixed registration, independently of the old sprite shift.
s.frame_set(0);bpy.context.view_layer.update();points={};scale=.375
for name,target in [('fuel',[-64,-18]),('oxidizer',[64,-18])]:
 o=bpy.data.objects['socket_'+name];q=world_to_camera_view(s,s.camera,o.matrix_world.translation);pixel=[q.x*512,(1-q.y)*768];shift=[(target[0]-scale*(pixel[0]-256))/32,(target[1]-scale*(pixel[1]-384))/32];points[name]={'model_position':list(o.matrix_world.translation),'pixel':pixel,'target_native_pixel':target,'fit_shift':shift}
assert max(abs(points['fuel']['fit_shift'][i]-points['oxidizer']['fit_shift'][i]) for i in range(2))<1e-5
(root/'draw-registration.json').write_text(json.dumps({'status':'MEASURED_REQUIRES_NATIVE_CAP_VISUAL_REVIEW','scale':scale,'shift':points['fuel']['fit_shift'],'cell':[512,768],'points':points,'native_fluidbox_fields_unchanged':True},indent=2)+'\n',encoding='utf-8')
print('BEAUTY_CAPTURED',len(records),flush=True)
