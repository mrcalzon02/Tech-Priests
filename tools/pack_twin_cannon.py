"""Pack actual independent-state captures and verify every reconstructed cell."""
import argparse,json,hashlib,shutil
from pathlib import Path
from PIL import Image,ImageChops,ImageFilter
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--body',type=Path,required=True);p.add_argument('--aerials',type=Path,required=True)
p.add_argument('--shadows',type=Path,required=True);p.add_argument('--out',type=Path,required=True)
p.add_argument('--directions',default=','.join(map(str,range(64))));a=p.parse_args();directions=list(map(int,a.directions.split(',')))
full=directions==list(range(64));a.out.mkdir(parents=True,exist_ok=True)
identity=json.loads((a.body/'identity.json').read_text());aerial_identity=json.loads((a.aerials/'identity.json').read_text())
assert identity['source_sha256']==aerial_identity['source_sha256'],'Capture model mismatch'
records=[]
def pack(name,paths,columns):
    size=256;sheet=Image.new('RGBA',(columns*size,((len(paths)+columns-1)//columns)*size))
    for frame,path in enumerate(paths):
        with Image.open(path) as cell:
            assert cell.size==(size,size);sheet.paste(cell,(frame%columns*size,frame//columns*size))
    target=a.out/name;sheet.save(target)
    with Image.open(target) as check:
        for frame,path in enumerate(paths):
            with Image.open(path) as original:
                assert original.tobytes()==check.crop((frame%columns*size,frame//columns*size,(frame%columns+1)*size,(frame//columns+1)*size)).tobytes(),str(path)
    records.append({'file':name,'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'frames':len(paths)})

for d in directions:
    minimum=None
    for mode,count in identity['modes'].items():
        paths=[a.body/f'd{d:02}-{mode}-{f:02}.png' for f in range(count)]
        pack(f'{mode}-body-{d:02}.png',paths,1 if count==1 else (8 if count==40 else 6))
        for path in paths:
            with Image.open(path) as cell:minimum=cell.getchannel('A') if minimum is None else ImageChops.darker(minimum,cell.getchannel('A'))
    with Image.open(a.body/f'd{d:02}-idle-00.png') as idle:
        opaque=minimum.point(lambda v:255 if v==255 else 0).filter(ImageFilter.MinFilter(3));assert opaque.getbbox(),'Missing native cap core'
        core=idle.copy();core.putalpha(opaque);core.save(a.out/f'native-{d:02}.png')
    for bank in (0,1):pack(f'aerial{bank}-{d:02}.png',[a.aerials/f'd{d:02}-aerial{bank}-{f:02}.png' for f in range(25)],5)
    with Image.open(a.shadows/f'shadow-{d:02}.png') as shadow:
        assert shadow.size==(512,512);shadow.save(a.out/f'shadow-{d:02}.png')
    print('CANNON_PACKED_DIRECTION',d,flush=True)
# Full neutral native captures remain useful for native-preview comparison,
# whereas the safe solid core avoids a second stationary gun during recoil.
for d in range(64):shutil.copy2(a.body/f'd{d:02}-preview.png',a.out/f'preview-{d:02}.png')
canvas=Image.new('RGBA',(640,640))
for image,scale in [(Image.open(ROOT/'tech-priests_src/graphics/entity/bunker-autocannon/base-north.png').convert('RGBA'),.315463840961),
                    (Image.open(a.body/'d24-preview.png').convert('RGBA'),.774999976158)]:
    size=round(image.width*scale*2);canvas.alpha_composite(image.resize((size,size),Image.Resampling.LANCZOS),(round(320-size/2),round(400-1.11090652*64-size/2)))
crop=canvas.crop(canvas.getchannel('A').getbbox());crop.thumbnail((120,120),Image.Resampling.LANCZOS)
icon=Image.new('RGBA',(128,128));icon.alpha_composite(crop,((128-crop.width)//2,(128-crop.height)//2));icon.save(a.out/'icon.png')
known={record['file'] for record in records}
for path in sorted(a.out.glob('*.png')):
    if path.name not in known:records.append({'file':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
manifest={'status':'PACKED_ALL_DIRECTIONS' if full else 'PARTIAL_RUNTIME_PILOT','directions':directions,'body_identity':identity,
          'aerial_identity':aerial_identity,'scope':'Real sprites and per-cell exact readback; in-game animated verification still required',
          'files':records,'native_core':'Opaque intersection of all actual body poses, eroded one pixel'}
(a.out/'assets.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(manifest['status'],str(a.out))
