import bpy,math,pathlib,json,argparse,sys
from mathutils import Vector
p=argparse.ArgumentParser();p.add_argument('--source',required=True);p.add_argument('--out',required=True);p.add_argument('--refresh-impacts',action='store_true');a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);R=pathlib.Path(a.out).resolve();R.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(pathlib.Path(a.source).resolve()))
s=bpy.context.scene;ground=bpy.data.objects['Preview ground - excluded from asset'];ground.is_shadow_catcher=True
s.render.film_transparent=True;s.render.image_settings.color_mode='RGBA';s.render.resolution_x=s.render.resolution_y=128;s.cycles.samples=16;s.cycles.use_denoising=False;s.render.use_persistent_data=True
s.camera.data.ortho_scale=2
root=bpy.data.objects.new('EXPORT_CARDINAL_ORIENTATION',None);s.collection.objects.link(root);bpy.context.view_layer.update()
for o in list(s.objects):
 if o!=root and o!=ground and o.type not in {'CAMERA','LIGHT'} and o.parent is None:
  m=o.matrix_world.copy();o.parent=root;o.matrix_world=m
bpy.ops.wm.save_as_mainfile(filepath=str(R/'workbench_game_export.blend'))
for d,name in enumerate(['north','east','south','west']):
 root.rotation_euler.z=-d*math.pi/2
 folder=R/'frames'/name;folder.mkdir(parents=True,exist_ok=True)
 for f in ([33,49,65,81,97,113,191] if a.refresh_impacts else range(1,193,2)):
  dest=folder/f'{f:04d}.png'
  if dest.exists() and not a.refresh_impacts:continue
  s.frame_set(f-1 if f-1 in [32,48,64,80,96,112] else (192 if f==191 else f));s.render.filepath=str(dest);bpy.ops.render.render(write_still=True)
 print('DIRECTION_COMPLETE',name,flush=True)
(R/'registration.json').write_text(json.dumps({'width':128,'height':128,'scale':.5,'shift':[0,-.63/math.sqrt(2)],'fps':12,'frames':96,'columns':12,'rows':8,'seconds':8,'directions':['north','east','south','west'],'source':'0251d186d82b5027dcaf81880237be35d4c980a2','camera_elevation_degrees':45,'shadow':'transparent Cycles shadow catcher integrated into RGBA'},indent=2))
