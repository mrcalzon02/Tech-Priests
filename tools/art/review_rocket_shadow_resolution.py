"""Render high/compact shadow references across cardinal headings and reload phases."""
from pathlib import Path
from array import array
import time,json
helper=Path(__file__).with_name('capture_rocket_reload_shadows.py')
exec(compile(helper.read_text().split('began=time.monotonic()')[0],str(helper),'exec'),globals())
original=array('f',mask.pixels[:]);rows=[]
for d,f in ((0,114),(16,94),(32,140),(48,196)):
    times={}
    for size in (512,256):
        mask.scale(512,512);mask.pixels.foreach_set(original);mask.update()
        if size==256:mask.scale(256,256)
        S.render.resolution_x=S.render.resolution_y=size;pose(d,f)
        S.render.filepath=str(out/f'd{d:02}-f{f:03}-{size}.png')
        start=time.monotonic();bpy.ops.render.render(write_still=True);times[size]=time.monotonic()-start
    rows.append({'direction':d,'source_frame':f,'seconds':times})
(out/'review.json').write_text(json.dumps({'status':'QUALITY_REVIEW_PENDING','source_sha256':identity['source_sha256'],
 'references':rows,'ortho_scale':12.399999618530274},indent=2)+'\n')
print('SHADOW_REFERENCES_READY',len(rows),flush=True)
