"""Render a lower-resolution shadow at the same physical camera registration."""
from pathlib import Path
import time,json
helper=Path(__file__).with_name('capture_rocket_reload_shadows.py')
exec(compile(helper.read_text().split('began=time.monotonic()')[0],str(helper),'exec'),globals())
S.render.resolution_x=S.render.resolution_y=256;mask.scale(256,256)
times=[]
for frame in (112,114):
    pose(0,frame);S.render.filepath=str(out/('shadow-256-'+str(frame)+'.png'))
    began=time.monotonic();bpy.ops.render.render(write_still=True);times.append(time.monotonic()-began)
(out/'resolution-benchmark.json').write_text(json.dumps({'status':'QUALITY_CANDIDATE_ONLY','source_sha256':identity['source_sha256'],
 'cell':256,'physical_ortho_scale':12.399999618530274,'runtime_scale':1.549999952316,
 'seconds':times,'scope':'Same actual geometry/pose/receiver; must compare quality before replacing capture'},indent=2)+'\n')
print('SHADOW_RESOLUTION_BENCHMARK',times,flush=True)
