"""Verify installed boiler/workbench/bunker image cells and source registration.

This reads committed atlas bytes. It is not a native graphical-client or gameplay test.
"""
import argparse, hashlib, json
from pathlib import Path
from PIL import Image
ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--repo',type=Path,required=True);ap.add_argument('--out',type=Path,required=True);a=ap.parse_args()
root=a.repo;gfx=root/'tech-priests_src/graphics/entity';records=[];cells=0
def sheet(path,size,columns,rows,nonempty=True):
    global cells
    with Image.open(path) as im:
        assert im.mode=='RGBA',(path,'Expected RGBA',im.mode)
        assert im.size==(size*columns,size*rows),(path,im.size)
        for y in range(rows):
            for x in range(columns):
                tile=im.crop((x*size,y*size,(x+1)*size,(y+1)*size))
                if nonempty:assert tile.getchannel('A').getbbox(),(path,x,y,'Empty cell')
                cells+=1
    records.append({'path':path.relative_to(root).as_posix(),'dimensions':[size*columns,size*rows],'cells':columns*rows,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
for size,suffix,columns,rows in [(256,'',12,32),(128,'-128',8,48)]:
    sheet(gfx/f'emergency-boiler-v08-working{suffix}.png',size,columns,rows)
    sheet(gfx/f'emergency-boiler-v08-idle{suffix}.png',size,1,4)
for direction in ('north','east','south','west'):
    sheet(gfx/f'timber-workbench/working-{direction}.png',128,12,8)
    sheet(gfx/f'timber-workbench/idle-{direction}.png',128,1,1)
for n in range(64):sheet(gfx/f'bunker-autocannon/firing-{n:02d}.png',256,32,1)
for n in range(8):sheet(gfx/f'bunker-autocannon/idle-{n:02d}.png',256,1,8)
for direction in ('north','east','south','west'):
    for suffix in ('','-shadow','-glow'):sheet(gfx/f'bunker-autocannon/base-{direction}{suffix}.png',512,1,1,nonempty=suffix!='-glow')
final=(root/'tech-priests_src/data-final-fixes.lua').read_text()
assert 'require("prototypes.workbench_graphics")' in final
assert 'require("prototypes.generated_graphics.emergency-boiler-v08")' in final
boiler=(root/'tech-priests_src/prototypes/generated_graphics/emergency-boiler-v08.lua').read_text()
assert 'frame_count = 96' in boiler and 'animation_speed = 0.4' in boiler
assert 'position={-0.5, -0.5}' in boiler and 'position={0.5, -0.5}' in boiler
wb=(root/'tech-priests_src/prototypes/workbench_graphics.lua').read_text()
assert 'animation_speed = 0.2' in wb and 'scale = 0.5' in wb and 'frame_count = idle and 1 or 96' in wb
report={'status':'PASS','scope':'Installed atlas dimensions, RGBA, nonempty body cells and exact source registration only; no gameplay/native visual acceptance claimed','atlas_files':records,'verified_cells':cells,'graphical_client_review':'not_run','behavior_tests':'not_run'}
a.out.parent.mkdir(parents=True,exist_ok=True);a.out.write_text(json.dumps(report,indent=2)+'\n');print('INSTALLED_ART_INTEGRATION_PASS',len(records),'files',cells,'cells')
