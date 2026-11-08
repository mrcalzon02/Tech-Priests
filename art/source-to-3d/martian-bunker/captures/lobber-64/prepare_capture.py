"""Prepare an A02 capture copy with the original bunker camera and daylight rig."""
import bpy,json,math,os,hashlib
from pathlib import Path
O=Path(__file__).resolve().parent
source=Path(os.environ['LOBBER_SOURCE']);reference=Path(os.environ['BUNKER_CAPTURE_REFERENCE'])
assert hashlib.sha256(reference.read_bytes()).hexdigest()=='827885c9c42cb752dea9bae1a0d31cb957f144f21d945ad019c507aaa6e2b9a3'
bpy.ops.wm.open_mainfile(filepath=str(reference));S=bpy.context.scene
camera=S.camera.name;world=S.world.name;lights=[o.name for o in S.objects if o.type=='LIGHT' and o.data.type=='AREA']
settings={k:getattr(S.view_settings,k) for k in ['view_transform','look','exposure','gamma']}
reference_camera={k:list(getattr(S.camera,k)) for k in ['location','rotation_euler']};reference_camera['ortho_scale']=S.camera.data.ortho_scale
bpy.ops.wm.open_mainfile(filepath=str(source));S=bpy.context.scene;S.frame_set(1)
for o in list(S.objects):
 if o.type=='CAMERA' or (o.type=='LIGHT' and not o.name.startswith('FLASH_LIGHT_')):bpy.data.objects.remove(o,do_unlink=True)
with bpy.data.libraries.load(str(reference),link=False) as (a,b):b.objects=[camera]+lights;b.worlds=[world]
rig=bpy.data.collections.new('CAPTURE_RIG');S.collection.children.link(rig)
for o in b.objects:rig.objects.link(o)
S.camera=next(o for o in b.objects if o.type=='CAMERA');S.world=b.worlds[0]
for k,v in settings.items():setattr(S.view_settings,k,v)
root=bpy.data.objects['TURRET_TRAVERSE'];assert abs(root.matrix_world.translation.z-1.7)<1e-5
ids=['TOP_R','TOP_L','MID_R','MID_L','BOT_R','BOT_L'];closed={}
def smooth(x):x=max(0,min(1,x));return x*x*(3-2*x)
for i,sid in enumerate(ids):
 h=bpy.data.objects['HATCH_SLIDE_'+sid];p=(-i*80)%480
 depth=smooth((p-1)/2) if p<3 else (1 if p<=98 else 1-smooth((p-98)/2))
 lateral=smooth((p-3)/5) if p<8 else (1 if p<=90 else 1-smooth((p-90)/8))
 sign=1 if sid.endswith('_R') else -1
 closed[sid]=[h.location.x+sign*.21*lateral,h.location.y-.07*depth,h.location.z]
# A separate catcher render uses the same world/pivot. Larger canvas preserves
# the same pixels/unit while allowing the projected ground shadow more room.
bpy.ops.mesh.primitive_plane_add(size=80,location=(0,0,0));plane=bpy.context.object;plane.name='CAPTURE_SHADOW_RECEIVER';plane.is_shadow_catcher=True;plane.hide_render=True
mat=bpy.data.materials.new('Capture neutral shadow receiver');mat.use_nodes=True;mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(1,1,1,1);mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=1;plane.data.materials.append(mat)
S.render.engine='CYCLES';S.cycles.samples=16;S.cycles.use_denoising=True;S.cycles.max_bounces=4;S.cycles.volume_bounces=1
S.render.resolution_x=S.render.resolution_y=640;S.render.resolution_percentage=100;S.render.film_transparent=True;S.render.image_settings.file_format='PNG';S.render.image_settings.color_mode='RGBA';S.render.use_persistent_data=True;S.render.use_sequencer=False
S.view_layers[0].name='TOPPER';S.view_layers[0].use_pass_emit=True
config={'schema':1,'direction_count':64,'direction_step_degrees':5.625,'mapping':'north0_clockwise','fps':24,'master_fps':60,'cycle_ticks':480,'frames_per_direction':192,'chunk_frames':32,'beauty_size':640,'shadow_size':1280,'samples':16,'ortho_scale':S.camera.data.ortho_scale,'mount_world':[0,0,1.7],'closed_hatches':closed,'recoil_rest':{sid:list(bpy.data.objects['RECOIL_'+sid].location) for sid in ids},'chassis_rest_location':list(bpy.data.objects['CHASSIS_FIRING_ROCK'].location),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'reference_sha256':hashlib.sha256(reference.read_bytes()).hexdigest(),'reference_camera':reference_camera,'color_management':settings,'passes':['beauty','emission','shadow'],'shadow_pixel_offset_from_beauty':[-320,-320],'source_animation':'A02 full eight-second cycle; 60 fps linear native keys sampled at 24 fps','entry_frames':15,'settle_frames':15}
# Store tip rest positions with spring offsets removed.
config['antenna_tip_rest']={};config['antenna_tip_rotation_rest']={};config['antenna_tip_displacement_matrix']={};config['antenna_heights']={}
for j in range(2):
 shaft=bpy.data.objects['SHORT_ANTENNA_'+str(j)];tip=bpy.data.objects['ANTENNA_RUBBER_TIP_'+str(j)]
 from mathutils import Vector
 dx=shaft.data.shape_keys.key_blocks['Spring flex X'].value;dy=shaft.data.shape_keys.key_blocks['Spring flex Y'].value
 rest=tip.location-tip.parent.matrix_world.inverted().to_3x3()@Vector((dx,dy,0));config['antenna_tip_rest'][str(j)]=list(rest);config['antenna_tip_displacement_matrix'][str(j)]=[list(row) for row in tip.parent.matrix_world.inverted().to_3x3()]
 zs=[(shaft.matrix_world@v.co).z for v in shaft.data.vertices];height=max(zs)-min(zs);config['antenna_heights'][str(j)]=height;config['antenna_tip_rotation_rest'][str(j)]=[tip.rotation_euler.x+2*dy/height,tip.rotation_euler.y-2*dx/height,tip.rotation_euler.z]
from bpy_extras.object_utils import world_to_camera_view
v=world_to_camera_view(S,S.camera,Vector((0,0,0)));config['shadow_receiver_mask']={'center':[320+v.x*640,320+(1-v.y)*640],'radii':[544,448],'fade_start':.78}
S.frame_set(1);bpy.ops.wm.save_as_mainfile(filepath=str(O/'lobber_capture.blend'),compress=True)
(O/'capture_config.json').write_text(json.dumps(config,indent=2))
print('LOBBER_CAPTURE_PREPARED',flush=True)
