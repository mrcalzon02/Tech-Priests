"""Render the complete elevated rear view without cropping the long barrel."""
import bpy,sys,math
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

source=Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene;s.frame_set(1)
bpy.data.objects['TURRET_TRAVERSE'].rotation_euler.z=math.pi
s.camera.data.ortho_scale=13.5
for _ in range(12):
    bpy.context.view_layer.update()
    projected=[world_to_camera_view(s,s.camera,o.matrix_world@Vector(p)) for o in s.objects if o.type in ('MESH','CURVE') for p in o.bound_box]
    if all(.025<p.x<.975 and .025<p.y<.975 for p in projected):break
    s.camera.data.ortho_scale*=1.12
else:raise AssertionError('Rear review does not fit camera')
s.render.filepath=str(source.parent/'rear.png');bpy.ops.render.render(write_still=True)
print('ARTILLERY_REAR_REVIEW_COMPLETE',s.camera.data.ortho_scale,flush=True)
