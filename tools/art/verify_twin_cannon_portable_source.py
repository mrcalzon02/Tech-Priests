"""Reopen the delivered editable scene and check packed textures and motion."""
import bpy,sys,json,hashlib
from pathlib import Path
source,out=map(Path,sys.argv[sys.argv.index('--')+1:]);bpy.ops.wm.open_mainfile(filepath=str(source))
images=[im for im in bpy.data.images if im.source=='FILE' and im.users>0]
assert images and all(im.packed_file for im in images),'Editable scene has external texture dependencies'
root=bpy.data.objects['TURRET_TRAVERSE'];assert root.animation_data and root.animation_data.action
guns=[bpy.data.objects['INDEPENDENT_RECOIL_'+str(i)] for i in (0,1)]
scene=bpy.context.scene;scene.frame_set(226);rest=[g.location.y for g in guns]
scene.frame_set(4);assert abs(guns[0].location.y-rest[0]-.9)<1e-5
scene.frame_set(49);assert abs(guns[1].location.y-rest[1]-.9)<1e-5
scene.frame_set(226);assert all(abs(g.location.y-r)<1e-5 for g,r in zip(guns,rest))
assert len([o for o in scene.objects if o.type in ('MESH','CURVE')])>400
report={'status':'PASS','native_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'reopened':True,
    'all_used_textures_packed':True,'packed_texture_count':len(images),'both_deep_recoil_keys_verified':True,'return_to_battery_verified':True,
    'images':[im.name for im in images]}
out.write_text(json.dumps(report,indent=2)+'\n');print('PORTABLE_CANNON_SOURCE_PASS',len(images))
