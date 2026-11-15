"""Verify source animation/attachments; does not claim native firing behaviour."""
import bpy,sys,json,hashlib,math
from pathlib import Path
from mathutils import Vector
p=Path(sys.argv[sys.argv.index('--')+1]);bpy.ops.wm.open_mainfile(filepath=str(p));s=bpy.context.scene
rounds=[o for o in s.objects if o.name.startswith('LOADED_ROCKET_')]
doors=[o for o in s.objects if o.name.startswith('HINGED_RELOAD_SHUTTER_')]
pods=[o for o in s.objects if o.name.startswith('ELEVATING_LAUNCH_POD_')]
loaders=[o for o in s.objects if o.name.startswith('SLIDING_THREE_ROUND_CASSETTE_')]
muzzles=[o for o in s.objects if o.name.startswith('MUZZLE_')]
assert len(rounds)==6 and len(muzzles)==6 and len(doors)==len(loaders)==len(pods)==2
samples=[]
for frame,expected in ((1,6),(2,5),(12,4),(22,3),(32,2),(42,1),(52,0),(179,0),(180,6),(241,6)):
    s.frame_set(frame);count=sum(o.scale.x>.5 for o in rounds);assert count==expected,(frame,count,expected)
    samples.append({'frame':frame,'loaded_rockets':count})
minimum_height=100
for frame in range(1,242):
    s.frame_set(frame)
    for door in doors:
        assert door.parent in pods and all(math.isfinite(v) for row in door.matrix_world for v in row)
    for loader in loaders:assert loader.parent in pods
    lowest=min((o.matrix_world@Vector(p)).z for o in s.objects if o.type=='MESH' for p in o.bound_box)
    minimum_height=min(minimum_height,lowest)
    assert lowest>=1.699,('Moving geometry extends below the bunker socket',frame,lowest)
s.frame_set(116)
assert all(o.rotation_euler.x>math.radians(100) for o in doors)
s.frame_set(241);assert all(abs(o.rotation_euler.x)<1e-5 for o in doors)
images=[im for im in bpy.data.images if im.users and im.source=='FILE']
assert images and all(im.packed_file for im in images)
report={'status':'PASS_SOURCE_STUDY','native_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),
        'source_samples':samples,'frames_checked':241,'packed_images':len(images),
        'base_included':False,'muzzle_sockets':6,'minimum_geometry_height':minimum_height,'native_runtime_tested':False,
        'scope':'Source departure/reload timing and parent ownership only; not mesh collision or native ammo proof'}
(p.parent/'source-motion-check.json').write_text(json.dumps(report,indent=2)+'\n')
print('ROCKET_SOURCE_STUDY_PASS',len(images))
