import bpy,json,math,hashlib,sys
from pathlib import Path
O=Path(__file__).resolve().parent;R=next((p for p in O.parents if (p/'tech-priests_src').is_dir()),O.parents[2])
sys.path.insert(0,str(R/'tools/fmpl' if (R/'tech-priests_src').is_dir() else R.parent/'model-production/tools/fmpl'))
from blender_camera_guard import assert_clean
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
source=O/'sterling-v10.blend';runtime=O/'sterling-v10.glb';ins=json.loads((O/'runtime-inspection.json').read_text());assert ins['technical_checks_passed'] and sha(source)==ins['source_sha256'] and sha(runtime)==ins['runtime_sha256']
bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene;root=bpy.data.objects['EXPORT | Sterling actual boiler'];profile=json.loads((O/'capture-profile.json').read_text());assert_clean(s,profile,bpy)
projection=bpy.data.objects.new('SPRITE ONLY | square ground projection',None);s.collection.objects.link(projection);projection.scale.y=math.sqrt(2);root.parent=projection;images=[]
for facing,yaw in [('north',0),('east',270),('south',180),('west',90)]:
 root.rotation_euler.z=math.radians(yaw)
 for state,frames in profile['states'].items():
  for index,f in enumerate(frames):
   s.frame_set(f);assert_clean(s,profile,bpy);p=O/f'{facing}-{state}-{index:02d}.png';s.render.filepath=str(p);bpy.ops.render.render(write_still=True);images.append({'file':p.name,'source_frame':f,'state':state,'facing':facing,'index':index,'sha256':sha(p)})
(O/'capture-manifest.json').write_text(json.dumps({'source_sha256':sha(source),'runtime_sha256':sha(runtime),'genuine_blender_frames':len(images),'frame_size':[256,256],'fps':4,'images':images,'projection':{'square_ground_y_scale':math.sqrt(2),'saved_runtime_geometry_changed':False},'native_verified':False,'owner_visual_approved':False},indent=2)+'\n',encoding='utf-8');print('STERLING_GENUINE_CAPTURE_PASS',len(images),flush=True)
