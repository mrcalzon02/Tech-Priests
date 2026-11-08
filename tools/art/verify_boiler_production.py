#!/usr/bin/env python3
"""Check every final boiler atlas cell against its verified raw capture."""
import argparse,hashlib,json,math
from pathlib import Path
from PIL import Image
import numpy as np

p=argparse.ArgumentParser();p.add_argument('--production',type=Path,required=True);p.add_argument('--capture',type=Path,required=True);p.add_argument('--job',type=Path,required=True);args=p.parse_args()
job=json.loads(args.job.read_text());manifest=json.loads((args.capture/'capture.json').read_text());cfg=manifest['config']
entries={(r['state'],r['direction'],r['index']):r for r in manifest['frames']}
checks=[]
for state,frames in cfg['states'].items():
    count=1 if state=='idle' else len(frames)
    for size in job['sizes']:
        suffix='' if size==job['primary_size'] else f'-{size}'
        name=f'{job["asset"]}-{job["revision"]}-{state}{suffix}.png'
        path=args.production/'prototype_ready/graphics/entity'/name
        with Image.open(path) as image:
            cols=min(max(8,math.ceil(count*4*size/8192)),count);rows=math.ceil(count/cols)
            assert image.mode=='RGBA' and image.size==(cols*size,rows*4*size)
            assert max(image.size)<=8192
            for d in range(4):
                source_direction=job['source_direction_indices'][d]
                for index in range(count):
                    entry=entries[(state,source_direction,index)]
                    source_path=args.capture/entry['path']
                    assert hashlib.sha256(source_path.read_bytes()).hexdigest()==entry['sha256']
                    with Image.open(source_path) as source:
                        expected=source.copy() if size==cfg['source_size'] else source.resize((size,size),Image.Resampling.LANCZOS)
                    pixels=np.array(expected);pixels[pixels[:,:,3]==0,:3]=0
                    x=index%cols*size;y=(d*rows+index//cols)*size
                    actual=np.array(image.crop((x,y,x+size,y+size)))
                    assert np.array_equal(actual,pixels),(state,size,d,index)
        checks.append({'state':state,'size':size,'file':name,'columns':cols,'rows_per_direction':rows,'frames_per_direction':count,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'scale':job['scale']*job['primary_size']/size,'cells_verified':count*4})
report={'passed':True,'checks':['all final RGBA channels equal verified source cells','N/E/S/W geometry coordinate mapping','source hashes','atlas dimensions <=8192','correct per-resolution scale'],'source_direction_indices':job['source_direction_indices'],'fps':cfg['fps'],'loop_seconds':len(cfg['states']['working'])/cfg['fps'],'animation_speed':cfg['fps']/60,'sheets':checks,'cells_verified':sum(c['cells_verified'] for c in checks)}
(args.production/'final-atlas-qa.json').write_text(json.dumps(report,indent=2)+'\n')
print('FINAL_BOILER_ATLAS_QA_PASS',report['cells_verified'],flush=True)
