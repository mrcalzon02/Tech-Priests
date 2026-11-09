import bpy,pathlib,sys,json,hashlib
r=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve();source=r/'thetazine-v04-regenerative-study.blend';bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene;s.frame_set(0);s.render.engine='CYCLES';s.cycles.device='CPU';s.cycles.samples=16;s.render.threads_mode='FIXED';s.render.threads=2
for o in s.objects:
 if o.type=='MESH':o.hide_render=o.get('render_component')!='underlay' and not o.name.startswith('Underlay')
path=r/'source-package/underlay.png';s.render.filepath=str(path);bpy.ops.render.render(write_still=True)
(r/'underlay-render-receipt.json').write_text(json.dumps({'native_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'file':'underlay.png','sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'cell':[512,1280],'static_source_frame':0,'scope':'Static source-authored under-platform machinery only; same camera/registration as body and heat. Native floor-layer proof remains separate.'},indent=2)+'\n',encoding='utf-8',newline='\n')
