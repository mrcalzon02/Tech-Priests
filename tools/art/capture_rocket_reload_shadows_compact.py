"""All 64 directions and 95 actual reload poses at reviewed shadow density.

Same world camera/receiver; registered at twice the pixel scale of 512 captures.
Completed higher-resolution frames may be inherited with explicit provenance.
"""
from pathlib import Path
import sys,hashlib,time,json
original=Path(__file__).with_name('capture_rocket_reload_shadows.py')
kit=original.read_text().split('began=time.monotonic()')[0]
start=kit.index("identity={'source_sha256'");end=kit.index('root.animation_data_clear()')
kit=kit[:start]+kit[end:]
exec(compile(kit,str(original),'exec'),globals())
identity={'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
 'script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
 'algorithm_source_sha256':hashlib.sha256(original.read_bytes()).hexdigest(),
 'receiver_source_sha256':hashlib.sha256(Path(__file__).with_name('capture_bullet_turrets.py').read_bytes()).hexdigest(),
 'headings':64,'cell':256,'frames':95,'source_reload_frames':[52,240],
 'scale':1.549999952316,'shift':[0,-1.110906519093],'base_included':False,
 'physical_ortho_scale':12.399999618530274,'quality_reference':'Four cardinal paired renders and native moving-shadow probe'}
if (out/'identity.json').exists():assert json.loads((out/'identity.json').read_text())==identity,'Compact capture inputs changed'
else:
    if any(out.glob('d*-*.png')):
        inherited=json.loads((out/'inherited-capture.json').read_text())
        assert inherited['source_identity']['source_sha256']==identity['source_sha256']
        assert inherited['source_identity']['script_sha256']==identity['algorithm_source_sha256']
    (out/'identity.json').write_text(json.dumps(identity,indent=2)+'\n')
S.render.resolution_x=S.render.resolution_y=256;mask.scale(256,256)
began=time.monotonic()
# The reviewed cardinal headings finish first, followed by the complete set.
directions=[0,16,32,48]+[d for d in range(64) if d not in (0,16,32,48)]
for d in directions:
    pose(d,1);capture(out/f'd{d:02}-idle.png')
    for f in range(95):
        pose(d,52+f*2);capture(out/f'd{d:02}-reload-{f:02}.png')
        if f%20==0:print('ROCKET_COMPACT_SHADOW_PROGRESS',d,f,round(time.monotonic()-began,1),flush=True)
    print('ROCKET_COMPACT_SHADOW_DIRECTION_DONE',d,flush=True)
(out/'capture.json').write_text(json.dumps({'status':'COMPLETE','identity':identity,'directions':64,
 'elapsed_seconds':time.monotonic()-began,'scope':'All actual reload poses; inherited high-resolution frames recorded separately'},indent=2)+'\n')
print('ROCKET_COMPACT_SHADOWS_DONE',flush=True)
