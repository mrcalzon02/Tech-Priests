import bpy
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(R/'condenser_v21/tech_priests_water_condenser_v21.blend'))
s=bpy.context.scene
for name in ['REFERENCE_ADJACENT_PIPES','REFERENCE_TILE_GRID']:bpy.data.collections[name].hide_render=True
cam=bpy.data.objects['PIPE_FIT_GAME_CAMERA_45_DEGREES'];cam.location=(0,-6,6.37);cam.rotation_euler=(Vector((0,0,.37))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=2.65;s.camera=cam;s['model_review_status']='V21 accepted by user; proceeding to boiler';s['export_view_elevation_degrees']=45
bpy.ops.wm.save_as_mainfile(filepath=str(R/'condenser_v21/tech_priests_water_condenser_v21.blend'),compress=True)
