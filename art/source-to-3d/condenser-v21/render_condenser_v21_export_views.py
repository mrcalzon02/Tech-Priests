import bpy,math,json
from pathlib import Path
from mathutils import Vector,Matrix
R=Path(__file__).resolve().parent;D=R/'condenser_v21_export_views';D.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(R/'condenser_v21/tech_priests_water_condenser_v21.blend'))
s=bpy.context.scene
for name in ['REFERENCE_ADJACENT_PIPES','REFERENCE_TILE_GRID']:bpy.data.collections[name].hide_render=True
cam=bpy.data.objects['PIPE_FIT_GAME_CAMERA_45_DEGREES'];cam.location=(0,-6,6.37);target=Vector((0,0,.37));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=2.65;s.camera=cam
s.cycles.samples=32;s.render.resolution_x=800;s.render.resolution_y=800;s.render.resolution_percentage=100;s.render.film_transparent=True;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA'
asset=[o for o in s.objects if o.type=='MESH' and (o.parent and o.parent.name=='CONDENSER_TILE_CALIBRATION' or o.name.startswith('Water outlet'))]
original={o.name:o.matrix_world.copy() for o in asset}
for heading,degrees in [('North',0),('East',-90),('South',-180),('West',-270)]:
 m=Matrix.Rotation(math.radians(degrees),4,'Z')
 for o in asset:o.matrix_world=m@original[o.name]
 bpy.context.view_layer.update();s.render.filepath=str(D/('Condenser_V21_'+heading+'.png'));bpy.ops.render.render(write_still=True)
 print('DIRECTION_COMPLETE',heading,flush=True)
(D/'Camera_Settings.json').write_text(json.dumps({'projection':'orthographic','downward_elevation_degrees':45,'camera_position':[0,-6,6.37],'camera_target':[0,0,.37],'ortho_scale':2.65,'canvas':[800,800],'model_clockwise_headings_degrees':[0,90,180,270],'reference_pipes_visible':False,'grid_visible':False,'native_model_modified':False,'lighting':'Preserved V21 model lighting'},indent=2))
