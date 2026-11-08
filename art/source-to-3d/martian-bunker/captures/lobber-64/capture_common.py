"""Portable capture states. Native 60 fps keys remain the animation authority."""
import bpy,math,json
from pathlib import Path
C=json.loads((Path(__file__).resolve().parent/'capture_config.json').read_text())
IDS=['TOP_R','TOP_L','MID_R','MID_L','BOT_R','BOT_L']
# A render evaluates the scene again. Temporarily detach native actions after
# sampling so it cannot replace explicit idle/entry/settle overrides.
animated=[]
for datablock in list(bpy.data.objects)+list(bpy.data.shape_keys)+list(bpy.data.lights)+[m.node_tree for m in bpy.data.materials if m.node_tree]:
 ad=getattr(datablock,'animation_data',None)
 if ad and ad.action:animated.append((datablock,ad.action,ad.action_slot))
def restore_actions():
 for ob,action,slot in animated:
  ob.animation_data.action=action;ob.animation_data.action_slot=slot
def freeze_actions():
 for ob,action,slot in animated:ob.animation_data.action=None

def reset_station(sid):
 bpy.data.objects['HATCH_SLIDE_'+sid].location=C['closed_hatches'][sid]
 bpy.data.objects['RECOIL_'+sid].location=C['recoil_rest'][sid]
 bpy.data.objects['WHOLE_PINEAPPLE_'+sid].hide_render=True
 bpy.data.objects['BLAST_'+sid].scale=(.0001,)*3
 bpy.data.objects['FLASH_LIGHT_'+sid].data.energy=0
 for o in bpy.context.scene.objects:
  if o.name.startswith('FLASH_'+sid+'_') or o.name.startswith('MUZZLE_SMOKE_'+sid+'_'):o.hide_render=True
 # Mirrored source-derived track/hose meshes are identified by their controller
 # or the existing source naming, avoiding a second independently authored rig.
 row=IDS.index(sid)//2+1;side='R' if sid.endswith('_R') else 'L'
 hose=bpy.data.objects['BOTTOM_FEED_LEFT_'+str(row)+'_ANIM_'+side]
 hose.data.shape_keys.key_blocks['Recoil compression'].value=0
 track=bpy.data.objects['CONTINUOUS_SEGMENTED_RUBBER_TRACK_LEFT_'+str(row)+'_ANIM_'+side]
 for sk in track.data.shape_keys.key_blocks:
  if sk.name.startswith('Belt travel'):sk.value=1 if sk.name.endswith('00') else 0

def pose(direction,frame=0,mode='cycle'):
 S=bpy.context.scene;restore_actions()
 tick=frame*2.5 if mode!='settle' else 480+frame*2.5
 # The periodic native scene only stores one loop. Settling wraps all stations
 # except the still-finishing last reload; suppress shots from the next loop.
 native=tick%480;S.frame_set(int(native)+1,subframe=native-int(native))
 if mode=='idle':
  for sid in IDS:reset_station(sid)
  w=bpy.data.objects['CHASSIS_FIRING_ROCK'];w.location=C['chassis_rest_location'];w.rotation_euler=(0,0,0)
  for j in range(2):
   sh=bpy.data.objects['SHORT_ANTENNA_'+str(j)]
   for sk in sh.data.shape_keys.key_blocks:
    if sk.name.startswith('Spring flex'):sk.value=0
   tip=bpy.data.objects['ANTENNA_RUBBER_TIP_'+str(j)];tip.location=C['antenna_tip_rest'][str(j)];tip.rotation_euler=C['antenna_tip_rotation_rest'][str(j)]
 elif mode=='entry':
  for i,sid in enumerate(IDS):
   if tick<80*i:reset_station(sid)
 elif mode=='settle':
  for sid in IDS[:-1]:reset_station(sid)
 if mode in ['entry','settle']:
  # Recompute reactions without periodic shots from before startup/after stop.
  from mathutils import Vector,Matrix
  pitch=roll=drop=0
  for i in range(6):
   p=tick-80*i
   if 0<=p<76:
    env=math.exp(-p/17);pitch+=math.radians(1.20)*env*math.sin(p*.235);roll+=math.radians(.42)*(1 if i%2==0 else -1)*env*math.sin(p*.27);drop-=.006*env*math.sin(p*.235)
  w=bpy.data.objects['CHASSIS_FIRING_ROCK'];w.location=Vector(C['chassis_rest_location'])+Vector((0,0,drop));w.rotation_euler=(pitch,roll,0)
  for j in range(2):
   dx=dy=0
   for i in range(6):
    p=tick-80*i-3-j*2
    if 0<=p<110:
     env=math.exp(-p/(24+j*3));dx+=(1 if i%2==0 else -1)*(.036-j*.010)*env*math.sin(p*(.235+j*.025));dy+=(.061-j*.018)*env*math.sin(p*(.205+j*.025))
   shaft=bpy.data.objects['SHORT_ANTENNA_'+str(j)];tip=bpy.data.objects['ANTENNA_RUBBER_TIP_'+str(j)]
   shaft.data.shape_keys.key_blocks['Spring flex X'].value=dx;shaft.data.shape_keys.key_blocks['Spring flex Y'].value=dy
   tip.location=Vector(C['antenna_tip_rest'][str(j)])+Matrix(C['antenna_tip_displacement_matrix'][str(j)])@Vector((dx,dy,0))
   h=C['antenna_heights'][str(j)];r=C['antenna_tip_rotation_rest'][str(j)];tip.rotation_euler=(r[0]-2*dy/h,r[1]+2*dx/h,r[2])
 bpy.data.objects['TURRET_TRAVERSE'].rotation_euler.z=math.radians(180-direction*5.625)
 freeze_actions();bpy.context.view_layer.update()
