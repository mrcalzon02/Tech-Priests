"""Capture the dish candidate's 64 idle azimuths in the existing bunker camera."""
import bpy,pathlib,sys,json,math,hashlib,time
from mathutils import Vector
args=sys.argv[sys.argv.index('--')+1:];dish=pathlib.Path(args[0]).resolve();O=pathlib.Path(args[1]).resolve();O.mkdir(parents=True,exist_ok=True)
S=bpy.context.scene;camera_source=pathlib.Path(bpy.data.filepath);camera_source_sha=hashlib.sha256(camera_source.read_bytes()).hexdigest()
camera=S.camera;camera.animation_data_clear();camera.data.animation_data_clear()
# Preserve the actual calibrated camera/world/studio lights, remove the old cap
# and flash lights. Save world transforms before unlinking any parenting.
keep={o for o in S.objects if o.type in ('CAMERA','LIGHT') and not o.name.startswith('FLASH_LIGHT_')}
world={o:o.matrix_world.copy() for o in keep}
for o in keep:o.parent=None;o.matrix_world=world[o];o.animation_data_clear();o.data.animation_data_clear()
for o in list(S.objects):
 if o not in keep:bpy.data.objects.remove(o,do_unlink=True)
with bpy.data.libraries.load(str(dish),link=False) as (data,loaded):loaded.objects=[name for name in data.objects if name in ('TURRET_TRAVERSE','WEAPON_ELEVATION') or name not in {o.name for o in keep}]
for o in loaded.objects:
 if o and o.type in ('MESH','EMPTY'):S.collection.objects.link(o)
root=bpy.data.objects['TURRET_TRAVERSE'];pivot=bpy.data.objects['WEAPON_ELEVATION']
for o in list(S.objects):
 if o.type not in ('MESH','EMPTY','CAMERA','LIGHT'):bpy.data.objects.remove(o,do_unlink=True)
for col in bpy.data.collections:col.hide_render=False
def enable(lc):
 lc.exclude=False;lc.hide_viewport=False
 for child in lc.children:enable(child)
for layer in list(S.view_layers)[1:]:S.view_layers.remove(layer)
enable(S.view_layers[0].layer_collection);S.view_layers[0].name='Dish idle';S.view_layers[0].use=True
S.use_nodes=False;S.render.use_compositing=False;S.render.use_sequencer=False;S.render.engine='CYCLES';S.cycles.device='CPU';S.cycles.samples=16;S.cycles.use_denoising=True
S.render.resolution_x=S.render.resolution_y=640;S.render.resolution_percentage=100;S.render.image_settings.file_format='PNG';S.render.image_settings.color_mode='RGBA';S.render.image_settings.color_depth='8';S.render.film_transparent=True
assert abs(camera.data.ortho_scale-6.199999809265137)<1e-5
identity={'dish_native_sha256':hashlib.sha256(dish.read_bytes()).hexdigest(),'calibrated_camera_source_sha256':camera_source_sha,'capture_script_sha256':hashlib.sha256(pathlib.Path(__file__).read_bytes()).hexdigest(),'size':640,'samples':16,'backend':'CPU','directions':64,'mapping':'north0_clockwise','yaw_degrees':'180-direction*5.625','camera_world_matrix':[list(r) for r in camera.matrix_world],'ortho_scale':camera.data.ortho_scale,'mount_world':[0,0,1.7],'elevation_pivot':[0,0,2.34],'scope':'Idle beauty only; no firing/emission/shadow or game integration claim'}
ip=O/'identity.json'
if ip.exists():assert json.loads(ip.read_text())==identity,'Capture identity differs; use a new output directory'
else:ip.write_text(json.dumps(identity,indent=2)+'\n')
completed=[]
for direction in range(64):
 path=O/f'idle-{direction:02}.png'
 # Existing files are not blindly trusted or overwritten on resume.
 if path.exists():
  check=bpy.data.images.load(str(path),check_existing=False);assert tuple(check.size)==(640,640);bpy.data.images.remove(check)
 else:
  root.rotation_euler.z=math.radians(180-direction*5.625);bpy.context.view_layer.update();S.render.filepath=str(path);bpy.ops.render.render(write_still=True)
 completed.append({'direction':direction,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
 (O/'capture-checkpoint.json').write_text(json.dumps({'status':'idle64_complete' if len(completed)==64 else 'rendering_idle','completed':completed,'identity':identity},indent=2)+'\n')
 print('DISH_IDLE_CAPTURED',direction,flush=True)
print('DISH_IDLE64_COMPLETE',flush=True)
