import bpy,json,time
from pathlib import Path
R=Path(__file__).resolve().parent;D=R/'boiler_tubing_audit'
bpy.ops.wm.open_mainfile(filepath=str(R/'boiler_v08/tech_priests_emergency_boiler_v08_animated.blend'))
s=bpy.context.scene;s.frame_set(25);s.render.engine='CYCLES';s.cycles.device='CPU';s.cycles.samples=16;s.cycles.use_denoising=True;s.render.resolution_x=900;s.render.resolution_y=900;s.render.resolution_percentage=100
assert s.camera.name=='BOILER_FACTORIO_EXPORT_45'
assert not bpy.data.collections['V08 ANIMATED STEAM'].hide_render
s.render.filepath=str(D/'Boiler_V08_Correct_Cycles_View.png');start=time.monotonic();bpy.ops.render.render(write_still=True)
(D/'Correct_Cycles_Settings.json').write_text(json.dumps({'engine':s.render.engine,'frame':25,'resolution':[900,900],'samples':16,'steam_visible':True,'camera':s.camera.name,'camera_orthographic_scale':s.camera.data.ortho_scale,'lighting':'Unchanged from supplied V07b','seconds':time.monotonic()-start},indent=2))
