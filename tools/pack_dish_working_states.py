"""Pack Blender-rendered occluded emitter masks into the native 40-tick pulse."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__);p.add_argument('capture',type=Path)
p.add_argument('--draft',action='store_true',help='Use rejected initial shadows only for parallel headless combat debugging')
a=p.parse_args()
assert json.loads((a.capture/'capture.json').read_text())['status']=='CAPTURE_COMPLETE'
out=ROOT/'tech-priests_src/graphics/entity/bunker-energy-dish'
out.mkdir(parents=True,exist_ok=True)
records=[]
for direction in range(64):
    emission=Image.open(a.capture/f'emission-{direction:02}.png').convert('RGBA')
    assert emission.size==(256,256)
    emission.save(out/f'emission-{direction:02}.png')
    pulse=Image.new('RGBA',(2048,256))
    for frame,level in enumerate((.05,1,.8,.6,.4,.2,.08,0)):
        cell=emission.copy();cell.putalpha(cell.getchannel('A').point(lambda value:round(value*level)))
        pulse.paste(cell,(frame*256,0))
    pulse.save(out/f'pulse-{direction:02}.png')
    shadow='shadow' if a.draft else 'shadow-clean'
    shutil.copy2(a.capture/f'{shadow}-{direction:02}.png',out/f'shadow-{direction:02}.png')
for f in sorted(out.glob('*.png')):
    with Image.open(f) as im:
        records.append({'file':f.name,'size':list(im.size),'sha256':hashlib.sha256(f.read_bytes()).hexdigest()})
(ROOT/'docs/prototypes/bunker-dish-working-assets.json').write_text(json.dumps({
    'status':'DRAFT_COMBAT_DEBUG_ONLY' if a.draft else 'PACKED','pulse_ticks':40,'pulse_frames':8,'directions':64,
    'emitter_masks':'actual Blender geometry with holdout occlusion',
    'shadows':'actual Cycles shadow catcher, fixed calibrated camera, 512px at ortho12.4',
    'files':records},indent=2)+'\n')
