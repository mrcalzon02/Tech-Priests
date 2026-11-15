"""Actual settled cap shadows for all-direction combat tests, not final reloads."""
from pathlib import Path
import shutil,json,hashlib
original=Path(__file__).with_name('capture_rocket_reload_shadows.py')
kit=original.read_text().split('began=time.monotonic()')[0]
start=kit.index("identity={'source_sha256'");end=kit.index('root.animation_data_clear()');kit=kit[:start]+kit[end:]
exec(compile(kit,str(original),'exec'),globals())
S.render.resolution_x=S.render.resolution_y=256;mask.scale(256,256)
cached=out.parent/'runtime-shadows-compact-v1'
source_hash=hashlib.sha256(source.read_bytes()).hexdigest()
cached_id=json.loads((cached/'identity.json').read_text())
assert cached_id['source_sha256']==source_hash and cached_id['cell']==256
for d in range(64):
    target=out/f'd{d:02}-idle.png';prior=cached/target.name
    if not target.exists() and prior.exists():
        try:
            image=bpy.data.images.load(str(prior));assert tuple(image.size)==(256,256);_ = image.pixels[-1]
            bpy.data.images.remove(image);shutil.copy2(prior,target)
        except Exception:pass
    if not target.exists():pose(d,1);capture(target)
(out/'identity.json').write_text(json.dumps({'source_sha256':source_hash,'cell':256,'frames':1,
 'scale':1.549999952316,'shift':[0,-1.110906519093],'status':'ACTUAL_SETTLED_SHADOWS_FOR_COMBAT_TESTS'},indent=2)+'\n')
(out/'capture.json').write_text(json.dumps({'status':'STATIC_COMBAT_FIXTURE_COMPLETE','directions':64},indent=2)+'\n')
print('ACTUAL_COMBAT_SHADOWS_READY',flush=True)
