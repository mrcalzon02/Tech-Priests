"""Compare compositor devices on identical actual shadow poses before changing jobs."""
from pathlib import Path
import time,json
helper=Path(__file__).with_name('capture_rocket_reload_shadows.py')
kit=helper.read_text().split('began=time.monotonic()')[0]
exec(compile(kit,str(helper),'exec'),globals())
report={'cycles_device':S.cycles.device,'compositor_default':S.render.compositor_device,
        'source_sha256':identity['source_sha256'],'modes':{}}
for device in ('CPU','GPU'):
    S.render.compositor_device=device;times=[]
    for frame in (112,114):
        pose(0,frame);S.render.filepath=str(out/(device.lower()+'-'+str(frame)+'.png'))
        began=time.monotonic();bpy.ops.render.render(write_still=True);times.append(time.monotonic()-began)
    report['modes'][device]=times
(out/'benchmark.json').write_text(json.dumps(report,indent=2)+'\n')
print('SHADOW_DEVICE_BENCHMARK',json.dumps(report),flush=True)
