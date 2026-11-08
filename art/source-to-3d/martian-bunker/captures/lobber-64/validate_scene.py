"""Validate saved capture registration and native animation before rendering."""
import bpy,sys,json,math
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
O=Path(__file__).resolve().parent;sys.path.insert(0,str(O))
from capture_common import C,IDS,pose
S=bpy.context.scene;assert S.camera.data.type=='ORTHO';assert abs(S.camera.rotation_euler.x-math.pi/4)<1e-6
assert all(im.packed_file or im.source in ['GENERATED','VIEWER'] for im in bpy.data.images)
assert not any(o.name.startswith(('BASE_STATIC','BUNKER_WALL','BUNKER_FLOOR')) for o in S.objects)
rig={o.name:o.matrix_world.copy() for o in S.objects if o.type in ['CAMERA','LIGHT'] and o.type!='LIGHT' or (o.type=='LIGHT' and o.data.type=='AREA')}
for d in range(64):
 pose(d,0,'idle')
 assert not any(o.type=='MESH' and o.name.startswith('FLASH_') and not o.hide_render for o in S.objects)
 for sid in IDS:
  assert (bpy.data.objects['HATCH_SLIDE_'+sid].location-Vector(C['closed_hatches'][sid])).length<1e-6
 for name,m in rig.items():assert max(abs(bpy.data.objects[name].matrix_world[i][j]-m[i][j]) for i in range(4) for j in range(4))<1e-6
for i,sid in enumerate(IDS):
 pose(0,32*i,'cycle');active=[o.name for o in S.objects if o.type=='MESH' and o.name.startswith('FLASH_') and not o.hide_render];assert len(active)==2 and all(sid in n for n in active),(sid,active)
pose(0,0,'entry');assert bpy.data.objects['WHOLE_PINEAPPLE_BOT_L'].hide_render
pose(0,14,'entry');a={o.name:o.matrix_world.copy() for o in S.objects if o.type=='MESH'}
pose(0,14,'cycle');assert all(max(abs(bpy.data.objects[n].matrix_world[i][j]-m[i][j]) for i in range(4) for j in range(4))<1e-5 for n,m in a.items())
# Tail ends with the same visible mechanisms as the clean idle rotation pose.
pose(0,14,'settle');a={o.name:o.matrix_world.copy() for o in S.objects if o.type=='MESH' and not o.name.startswith(('MUZZLE_SMOKE','FLASH_','WHOLE_PINEAPPLE'))}
pose(0,0,'idle');assert all(max(abs(bpy.data.objects[n].matrix_world[i][j]-m[i][j]) for i in range(4) for j in range(4))<1e-4 for n,m in a.items())
# Check mesh bounds at the firing extrema in eight compass orientations.
bounds=[]
for d in range(0,64,8):
 for f in [0,2,4,32,64,96,128,160,191]:
  pose(d,f,'cycle')
  for o in S.objects:
   if o.type!='MESH' or o.hide_render or o.name.startswith(('MUZZLE_SMOKE','CAPTURE_SHADOW')):continue
   for corner in o.bound_box:
    p=world_to_camera_view(S,S.camera,o.matrix_world@Vector(corner));assert .015<p.x<.985 and .015<p.y<.985,(d,f,o.name,list(p))
def pixel(point,size=640):
 p=world_to_camera_view(S,S.camera,Vector(point));return [p.x*size,(1-p.y)*size]
pose(0,0,'idle');assert max(abs(a-b) for a,b in zip(C['shadow_receiver_mask']['center'],[x+320 for x in pixel((0,0,0))]))<1e-4
report={'status':'PASS','directions':64,'fps':24,'frames_per_direction':192,'cycle_frames':12288,'idle_frames':64,'entry_frames_per_direction':15,'settle_frames_per_direction':15,'camera':'original bunker 45 degree orthographic','pixels_per_world_unit':640/C['ortho_scale'],'entity_origin_pixel':pixel((0,0,0)),'mount_pixel':pixel((0,0,1.7)),'all_idle_hatches_closed':True,'idle_effects_disabled':True,'six_independent_shots_verified':True,'entry_joins_cycle':True,'tail_returns_to_idle':True,'textures_packed':True,'base_excluded':True,'eight_heading_extreme_bounds_checked':True,'camera_and_area_lights_fixed_at_all_64_headings':True}
(O/'scene_validation.json').write_text(json.dumps(report,indent=2));print('LOBBER_CAPTURE_SCENE_PASS',flush=True)
