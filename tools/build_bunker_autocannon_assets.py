#!/usr/bin/env python3
"""Pack the approved independent bunker/base captures into game sprites.

No new rendering or per-heading recentering: both layers use their recorded
world-origin projection and a common 32 pixels per world unit.
"""
import argparse, hashlib, json, zipfile, io
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--turret-package', required=True, type=Path)
p.add_argument('--base-dir', required=True, type=Path)
p.add_argument('--turret-registration', type=Path, default=ROOT/'docs/prototypes/bunker-autocannon-registration.json')
a = p.parse_args()
out = ROOT/'tech-priests_src/graphics/entity/bunker-autocannon'
out.mkdir(parents=True, exist_ok=True)
cell, base_size = 256, 512
reg = json.loads(a.turret_registration.read_text())
base_reg = json.loads((a.base_dir/'capture_manifest.json').read_text())
assert base_reg['approved_base_transforms_match'] and base_reg['turret_excluded_globally']
assert abs(reg['orthographic_scale']-6.2)<1e-5
ts = reg['orthographic_scale']*32/cell
bs = base_reg['orthographic_scale']*32/base_size
def shift(size, origin, ortho):
    return [(size/2-origin[0])*ortho/size, (size/2-origin[1])*ortho/size]
tshift = shift(640, reg['origin_pixels'], reg['orthographic_scale'])
bshift = shift(2048, base_reg['frames'][0]['origin_pixels'], base_reg['orthographic_scale'])
assert max(abs(x-y) for x,y in zip(tshift,bshift))<1e-5, (tshift,bshift)
idle_frames=[]
with zipfile.ZipFile(a.turret_package) as z:
    manifest=json.loads(z.read('Original_Bunker_Turret/capture_manifest.json'))
    assert manifest['direction_count']==64 and manifest['firing_frames_per_direction']==32
    assert not manifest['base_included']
    for d in range(64):
        src=Image.open(io.BytesIO(z.read(f'Original_Bunker_Turret/firing_d{d:02}.png'))).convert('RGBA')
        assert src.size==(5120,2560)
        sheet=Image.new('RGBA',(cell*32,cell))
        for f in range(32):
            im=src.crop(((f%8)*640,(f//8)*640,(f%8+1)*640,(f//8+1)*640))
            im=im.resize((cell,cell),Image.Resampling.LANCZOS)
            sheet.paste(im,(f*cell,0))
            if f==0:idle_frames.append(im.copy())
        sheet.save(out/f'firing-{d:02}.png')
        print('PACKED_HEADING',d,flush=True)
for page in range(8):
    im=Image.new('RGBA',(cell,cell*8))
    for row in range(8):im.paste(idle_frames[page*8+row],(0,row*cell))
    im.save(out/f'idle-{page:02}.png')
for direction in ['north','east','south','west']:
    for suffix in ['', '_shadow', '_glow']:
        with Image.open(a.base_dir/f'base_{direction}{suffix}.png') as im:
            im.convert('RGBA').resize((base_size,base_size),Image.Resampling.LANCZOS).save(out/f'base-{direction}{suffix.replace("_","-")}.png')
# The item icon is an actual composite of the delivered machine, not donor art.
base=Image.open(out/'base-south.png').convert('RGBA')
canvas=Image.new('RGBA',(640,640))
def composite(image,size,scale,offset):
    im=image.resize((size,size),Image.Resampling.LANCZOS)
    anchor=(320,400)
    pos=(round(anchor[0]+offset[0]*64-size/2),round(anchor[1]+offset[1]*64-size/2))
    canvas.alpha_composite(im,pos)
composite(base,round(base_size*bs*2),bs,bshift)
composite(idle_frames[32],round(cell*ts*2),ts,tshift)
box=canvas.getchannel('A').getbbox();assert box
icon=canvas.crop(box);icon.thumbnail((120,120),Image.Resampling.LANCZOS)
square=Image.new('RGBA',(128,128));square.alpha_composite(icon,((128-icon.width)//2,(128-icon.height)//2))
square.save(out/'icon.png')
graphics=ROOT/'tech-priests_src/prototypes/bunker_autocannon_graphics.lua'
graphics.write_text('-- Generated from approved camera/world-origin records.\nreturn {cell=256, base_size=512, turret_scale=%.12f, base_scale=%.12f,\n turret_shift={%.12f, %.12f}, base_shift={%.12f, %.12f}}\n'%(ts,bs,*tshift,*bshift))
record={'schema':1,'status':'PACKED_APPROVED_CAPTURES','cell_size':cell,'directions':64,'firing_frames':32,'footprint':[3,3],
 'pixels_per_world_unit':32,'turret_scale':ts,'base_scale':bs,'turret_shift':tshift,'base_shift':bshift,
 'turret_package_sha256':hashlib.sha256(a.turret_package.read_bytes()).hexdigest(),
 'source_capture_commit':'e9c4e1d4008378c194feb7281241349a9b2658c9','base_capture_commit':'5382858',
 'sprites':{x.name:{'sha256':hashlib.sha256(x.read_bytes()).hexdigest(),'size':list(Image.open(x).size)} for x in sorted(out.glob('*.png'))}}
doc=ROOT/'docs/prototypes';doc.mkdir(parents=True,exist_ok=True)
(doc/'bunker-autocannon-assets.json').write_text(json.dumps(record,indent=2)+'\n')
print('ASSET_PACK_COMPLETE',len(record['sprites']),flush=True)
