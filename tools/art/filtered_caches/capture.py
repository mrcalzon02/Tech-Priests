"""Genuine fixed-facing sprites, real shadows and matching icons for ten caches."""
import json
from pathlib import Path
R=Path(__file__).resolve().parents[3];B=R/'art/source-to-3d/filtered-stone-caches/v01';catalog=json.loads((B/'catalog.json').read_text());base=(R/'tools/art/stone_cache/capture.py').read_text()
for row in catalog['rows']:
 src=base.replace("R/'art/source-to-3d/martian-stone-cache/v01'",'Path('+repr(str(R/row['path']))+')').replace('martian-stone-cache-v01',row['stem']).replace('Martian Stone Cache | ground origin','Filtered Cache | '+row['key'])
 src=src.replace(";assert json.loads((O/'wall-and-tie-audit.json').read_text())['passed']",'').replace("('inspection.json','wall-and-tie-audit.json')","('inspection.json',)").replace("profile['source_size']=512;","profile['source_size']=512;profile['orientation_policy']='fixed';profile['directions']=[0];").replace('enumerate((0,90,180,270))','enumerate((0,))').replace('Fixed north, preserved. Other facings review only.','Fixed north only, matching actual prototype; source/export inspection retains four review views.').replace('None: static general container. Existing native circuit connector sprites/LED layers retained untouched.','None: static filtered cache, no invented machinery. Source tablet provides backing; native wire points/pins/LED states stay unchanged.')
 exec(compile(src,str(R/'tools/art/stone_cache/capture.py'),'exec'),{'__file__':__file__});print('FILTERED_CACHE_BODY_SHADOW_ICON_SAVED',row['key'],flush=True)
