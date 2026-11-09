"""Resumable sampled source animation, not a full runtime atlas or behavior test."""
import bpy,pathlib,sys,hashlib,json,os
r=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve();source=r/'thetazine-v04-regenerative-study.blend';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene;s.render.engine='BLENDER_EEVEE';s.render.resolution_percentage=100
if hasattr(s.eevee,'taa_render_samples'):s.eevee.taa_render_samples=24
dest=r/'full-preview-frames';dest.mkdir(exist_ok=True);receipt=r/'full-preview-capture.json';state={'status':'CAPTURING','pid':os.getpid(),'native_sha256':sha(source),'renderer_sha256':sha(pathlib.Path(__file__)),'renderer':'Blender5.0.1 Eevee blended-alpha full source','sample_contract':'Cold0 plus every working pose1..64 and exact wrap65 at30fps. Combined body+FX preview captures, not segmented runtime atlases.','frames':[]}
if receipt.exists():
 old=json.loads(receipt.read_text(encoding='utf-8'));assert old['native_sha256']==state['native_sha256'] and old['renderer_sha256']==state['renderer_sha256'];state['frames']=old['frames']
def checkpoint():receipt.write_text(json.dumps(state,indent=2)+'\n',encoding='utf-8',newline='\n')
checkpoint()
for frame in range(66):
 path=dest/f'{frame:02}.png';prior=next((x for x in state['frames'] if x['frame']==frame),None)
 if prior:assert sha(path)==prior['sha256'];continue
 s.frame_set(frame);s.render.filepath=str(path);bpy.ops.render.render(write_still=True);state['frames'].append({'frame':frame,'file':str(path.relative_to(r)).replace('\\','/'),'sha256':sha(path),'size':[512,1280]});checkpoint();print('V04_PREVIEW_FRAME',frame,flush=True)
state['status']='RENDERED_REQUIRES_VIEW';checkpoint();print('V04_PREVIEW_COMPLETE',len(state['frames']))
