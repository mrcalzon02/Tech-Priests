import bpy,json
from pathlib import Path
R=Path(__file__).resolve().parent;D=R/'boiler_v08'
bpy.ops.wm.open_mainfile(filepath=str(D/'tech_priests_emergency_boiler_v08_animated.blend'))
s=bpy.context.scene;keep=bpy.data.objects['BOILER_FACTORIO_EXPORT_45'];s.camera=keep;removed=[]
for o in list(bpy.data.objects):
 if o.type=='CAMERA' and o!=keep:removed.append(o.name);bpy.data.objects.remove(o,do_unlink=True)
for c in list(bpy.data.cameras):
 if c.users==0:bpy.data.cameras.remove(c)
assert len([o for o in bpy.data.objects if o.type=='CAMERA'])==1
s.frame_set(1);bpy.ops.wm.save_as_mainfile(filepath=str(D/'tech_priests_emergency_boiler_v08_animated.blend'),compress=True)
(D/'Camera_Cleanup.json').write_text(json.dumps({'kept_camera':keep.name,'camera_count':1,'removed_legacy_cameras':removed},indent=2));print('CAMERA_CLEANUP',len(removed),'removed; one export camera retained')
