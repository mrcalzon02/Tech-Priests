import bpy,sys,json,time
from pathlib import Path
R=Path(__file__).resolve().parent;D=R/'boiler_v08';D.joinpath('preview_frames').mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(D/'tech_priests_emergency_boiler_v08_animated.blend'))
s=bpy.context.scene
s.render.engine='CYCLES';s.cycles.device='CPU';s.cycles.samples=16;s.cycles.use_denoising=True
s.render.resolution_x=720;s.render.resolution_y=720;s.render.resolution_percentage=100
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
frames=[25] if '--test' in args else list(range(1,97,2))
chunk=int(args[args.index('--chunk')+1]) if '--chunk' in args else None
if chunk is not None:frames=frames[chunk::3]
start=time.monotonic()
print('PREVIEW_SETTINGS',s.render.engine,[(n,getattr(s.eevee,n,None)) for n in ['taa_render_samples','volumetric_samples','volumetric_tile_size']] if hasattr(s,'eevee') else [],flush=True)
for f in frames:
 s.frame_set(f);s.render.filepath=str(D/'preview_frames'/('frame_%03d.png'%f));bpy.ops.render.render(write_still=True);print('PREVIEW_FRAME',f,'SECONDS',round(time.monotonic()-start,2),flush=True)
(D/('Preview_Test.json' if '--test' in args else ('Preview_Render_Chunk%d.json'%chunk if chunk is not None else 'Preview_Render.json'))).write_text(json.dumps({'engine':s.render.engine,'frames':frames,'seconds':time.monotonic()-start,'resolution':[720,720],'playback_fps':12,'loop_seconds':4,'native_volume_detail_unchanged':True,'samples':16,'denoised':True},indent=2))
