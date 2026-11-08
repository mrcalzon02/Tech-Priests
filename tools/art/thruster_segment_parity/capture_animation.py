"""Resumable separate body beauty/emission plus static underlay; no native approval implied."""
import bpy,pathlib,json,hashlib,sys
r=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve();model=r/'thetazine-animation-study.blend';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();native=sha(model);script=sha(pathlib.Path(__file__));captures=r/'captures';captures.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(model));s=bpy.context.scene;s.cycles.device='CPU';s.cycles.samples=16;s.render.threads_mode='FIXED';s.render.threads=2;s.view_layers[0].use_pass_emit=True
for o in s.objects:
 if o.type=='MESH' and o.name.startswith('Underlay'):o.hide_render=True
nt=bpy.data.node_groups.new('Separated body beauty and glow','CompositorNodeTree');s.compositing_node_group=nt;nt.interface.new_socket(name='Image',in_out='OUTPUT',socket_type='NodeSocketColor');rl=nt.nodes.new('CompositorNodeRLayers');output=nt.nodes.new('NodeGroupOutput');nt.links.new(rl.outputs['Image'],output.inputs['Image']);s.render.use_compositing=True
alpha=nt.nodes.new('CompositorNodeSetAlpha');nt.links.new(rl.outputs['Emission'],alpha.inputs['Image']);nt.links.new(rl.outputs['Alpha'],alpha.inputs['Alpha']);fo=nt.nodes.new('CompositorNodeOutputFile');fo.directory=str(captures);fo.format.media_type='IMAGE';fo.format.file_format='PNG';fo.format.color_mode='RGBA';fo.format.color_depth='8';fo.save_as_render=True;fo.file_output_items.new('RGBA','emission');nt.links.new(alpha.outputs['Image'],fo.inputs['emission'])
receipt=r/'capture-receipt.json';records=[]
if receipt.exists():
 old=json.loads(receipt.read_text(encoding='utf-8'));assert old['source_sha256']==native and old['renderer_sha256']==script
 for row in old['files']:assert sha(captures/row['file'])==row['sha256'];records.append(row)
def checkpoint():
 receipt.write_text(json.dumps({'status':'COMPLETE_SOURCE_CAPTURE_REQUIRES_REVIEW' if len(records)==128 else 'RENDERING','source_sha256':native,'renderer_sha256':script,'target_frames':64,'target_pngs':128,'completed_pngs':len(records),'files':records,'scope':'Actual authored mechanical cycle, separate beauty/emission, 512x768, 16 CPU samples, two threads. Native working-clock/atlas/shadow/exhaust gates remain separate.'},indent=2)+'\n',encoding='utf-8',newline='\n')
checkpoint()
for frame in range(1,65):
 if sum(row['source_frame']==frame for row in records)==2:continue
 prefix=f'body-{frame:02}';fo.file_name=prefix+'-pass-';before=set(captures.glob('*.png'));s.frame_set(frame);dest=captures/(prefix+'-beauty.png');s.render.filepath=str(dest);bpy.ops.render.render(write_still=True)
 generated=[p for p in set(captures.glob('*.png'))-before if p!=dest];assert len(generated)==1,[p.name for p in generated];emission=captures/(prefix+'-emission.png');generated[0].rename(emission)
 records=[row for row in records if row['source_frame']!=frame]
 for kind,path in [('beauty',dest),('emission',emission)]:records.append({'source_frame':frame,'pass':kind,'file':path.name,'sha256':sha(path)})
 checkpoint();print('SOURCE_FRAME_CHECKPOINT',frame,flush=True)
s.render.use_compositing=False
for o in s.objects:
 if o.type=='MESH':o.hide_render=not o.name.startswith('Underlay')
s.frame_set(1);s.render.filepath=str(r/'underlay-pilot.png');bpy.ops.render.render(write_still=True)
print('SOURCE_CAPTURE_COMPLETE',len(records),flush=True)
