"""Render the actual repaired reload sequence from a rear-quarter inspection view."""
import bpy,sys,json,math,hashlib
from pathlib import Path
native,out=map(Path,sys.argv[sys.argv.index('--')+1:]);out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(native));s=bpy.context.scene
root=next(o for o in s.objects if o.name=='TURRET_TRAVERSE');root.rotation_euler.z=3*math.pi/4
s.camera.data.ortho_scale=6.4;s.render.resolution_x=s.render.resolution_y=640
s.render.resolution_percentage=100;s.cycles.samples=12
frames=[1,52,67,82,88,94,100,106,121,140,150,162,174,185,196,211,223,237,241]
for frame in frames:
    s.frame_set(frame);s.render.filepath=str(out/('%03d.png'%frame));bpy.ops.render.render(write_still=True)
(out/'frames.json').write_text(json.dumps({'native_sha256':hashlib.sha256(native.read_bytes()).hexdigest(),
    'frames':frames,'view':'Rear quarter; source study, no native game firing','fps':60},indent=2)+'\n')
print('SHUTTER_REVIEW_RENDERED',len(frames),flush=True)
