import bpy,sys
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parent;D=R/'boiler_tubing_audit';D.mkdir(exist_ok=True)
args=sys.argv[sys.argv.index('--')+1:];variant=args[0]
path=R/('upload/tech_priests_emergency_boiler_v07b.blend' if variant=='source' else 'boiler_v08/tech_priests_emergency_boiler_v08_animated.blend')
bpy.ops.wm.open_mainfile(filepath=str(path))
if bpy.context.object and bpy.context.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
s=bpy.context.scene;s.frame_set(1 if variant!='animated_motion' else 25)
for c in bpy.data.collections:
 if 'REFERENCE_ADJACENT' in c.name or c.name=='V08 ANIMATED STEAM':c.hide_render=True
cam=bpy.data.objects['BOILER_FACTORIO_EXPORT_45'];cam.location=(0,-6,6.60);cam.rotation_euler=(Vector((0,0,.6))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=2.65;s.camera=cam
s.render.engine='CYCLES';s.cycles.device='CPU';s.cycles.samples=16;s.cycles.use_denoising=True;s.render.resolution_x=900;s.render.resolution_y=900;s.render.resolution_percentage=100;s.render.film_transparent=False;s.render.filepath=str(D/(variant+'_Cycles.png'));bpy.ops.render.render(write_still=True)
