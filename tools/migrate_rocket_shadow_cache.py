"""Retain completed physical shadow renders at the reviewed compact resolution."""
import argparse,json,hashlib
from pathlib import Path
from PIL import Image
p=argparse.ArgumentParser();p.add_argument('--source',type=Path,required=True);p.add_argument('--out',type=Path,required=True)
p.add_argument('--directions');p.add_argument('--probe',action='store_true');a=p.parse_args()
identity=json.loads((a.source/'identity.json').read_text());assert identity['cell']==512
a.out.mkdir(parents=True,exist_ok=True);records=[];skipped=[]
selected=set(map(int,a.directions.split(','))) if a.directions else set(range(64))
for source in sorted(a.source.glob('d*-*.png')):
    d=int(source.name[1:3])
    if d not in selected:continue
    target=a.out/source.name
    assert not target.exists(),'Seed once before starting the compact worker'
    try:
        with Image.open(source) as im:
            im.load();assert im.size==(512,512);compact=im.convert('RGBA').resize((256,256),Image.Resampling.LANCZOS)
    except Exception as error:
        skipped.append({'file':source.name,'reason':str(error)});continue
    compact.save(target)
    records.append({'file':source.name,'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
        'sha256':hashlib.sha256(target.read_bytes()).hexdigest()})
report={'status':'RESAMPLED_ACTUAL_CAPTURE_CACHE','source_identity':identity,'target_cell':256,
    'method':'LANCZOS downsample of completed actual 512-pixel shadow poses, same 12.4-tile camera registration',
    'files':records,'skipped_incomplete':skipped}
(a.out/'inherited-capture.json').write_text(json.dumps(report,indent=2)+'\n')
if a.probe:
    (a.out/'identity.json').write_text(json.dumps({'source_sha256':identity['source_sha256'],'cell':256,
       'scale':1.549999952316,'shift':[0,-1.110906519093],'status':'RESAMPLED_REFERENCE_PROBE_ONLY'},indent=2)+'\n')
print('SHADOW_CACHE_RETAINED',len(records),'skipped',len(skipped))
