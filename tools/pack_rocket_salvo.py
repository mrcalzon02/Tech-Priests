"""Pack final real body/nose/moving-shadow captures with exact cell readback."""
import argparse,json,hashlib
from pathlib import Path
from PIL import Image,ImageChops,ImageFilter
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--body',type=Path,default=ROOT/'build/rocket-salvo/runtime-pilot-v1')
p.add_argument('--shadows',type=Path,default=ROOT/'build/rocket-salvo/runtime-shadows-compact-v1')
p.add_argument('--out',type=Path,default=ROOT/'tech-priests_src/graphics/entity/bunker-rocket-salvo')
p.add_argument('--directions',default=','.join(map(str,range(64))))
p.add_argument('--static-combat-test',action='store_true');a=p.parse_args()
directions=list(map(int,a.directions.split(',')));full=directions==list(range(64))
assert full or a.out.resolve()!= (ROOT/'tech-priests_src/graphics/entity/bunker-rocket-salvo').resolve(),'Partial output stays in staging'
assert not a.static_combat_test or a.out.resolve()!= (ROOT/'tech-priests_src/graphics/entity/bunker-rocket-salvo').resolve(),'Static test art is not final production art'
body_id=json.loads((a.body/'identity.json').read_text());shadow_id=json.loads((a.shadows/'identity.json').read_text())
assert body_id['source_sha256']==shadow_id['source_sha256']
assert body_id['source_sha256']==json.loads((ROOT/'tech-priests_src/scripts/rocket_salvo_geometry.json').read_text())['native_sha256']
if full:
    assert json.loads((a.body/'capture.json').read_text())['status']=='COMPLETE'
    assert json.loads((a.shadows/'capture.json').read_text())['status']==('STATIC_COMBAT_FIXTURE_COMPLETE' if a.static_combat_test else 'COMPLETE')
a.out.mkdir(parents=True,exist_ok=True);records=[]
def load(path):
    with Image.open(path) as image:return image.convert('RGBA')
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def pack(name,cells,columns,size):
    sheet=Image.new('RGBA',(columns*size,((len(cells)+columns-1)//columns)*size))
    assert max(sheet.size)<=16384,'Native atlas dimension limit'
    for i,cell in enumerate(cells):
        assert cell.size==(size,size);sheet.paste(cell,(i%columns*size,i//columns*size))
    target=a.out/name;sheet.save(target)
    with Image.open(target) as read:
        for i,cell in enumerate(cells):
            assert read.crop((i%columns*size,i//columns*size,i%columns*size+size,i//columns*size+size)).tobytes()==cell.tobytes(),name
    records.append({'file':name,'frames':len(cells),'cell':size,'sha256':sha(target)})
for d in directions:
    idle=load(a.body/f'd{d:02}-idle.png');poses=[load(a.body/f'd{d:02}-reload-{f:02}.png') for f in range(95)]
    minimum=idle.getchannel('A')
    for image in [idle]+poses:
        box=image.getchannel('A').getbbox()
        assert box and box[0]>0 and box[1]>0 and box[2]<256 and box[3]<256,('Clipped body',d)
        minimum=ImageChops.darker(minimum,image.getchannel('A'))
    pack(f'idle-body-{d:02}.png',[idle],1,256);pack(f'reload-body-{d:02}.png',poses,8,256)
    core=idle.copy();core.putalpha(minimum.point(lambda value:255 if value==255 else 0).filter(ImageFilter.MinFilter(3)))
    assert core.getchannel('A').getbbox(),'Native preview must retain the static weapon'
    core.save(a.out/f'native-{d:02}.png')
    noses=[]
    for cell in range(6):
        samples=[load(a.body/f'd{d:02}-nose{cell}-p{f:03}.png') for f in body_id['nose_holdout_poses']]
        mask=samples[0].getchannel('A')
        for image in samples[1:]:mask=ImageChops.darker(mask,image.getchannel('A'))
        nose=samples[0].copy();nose.putalpha(mask);noses.append(nose)
    pack(f'noses-{d:02}.png',noses,6,256)
    preview=idle.copy()
    for nose in noses:preview.alpha_composite(nose)
    preview.save(a.out/f'preview-{d:02}.png')
    if a.static_combat_test:
        pack(f'shadow-{d:02}.png',[load(a.shadows/f'd{d:02}-idle.png')],1,shadow_id['cell'])
    else:
        pack(f'idle-shadow-{d:02}.png',[load(a.shadows/f'd{d:02}-idle.png')],1,shadow_id['cell'])
        pack(f'reload-shadow-{d:02}.png',[load(a.shadows/f'd{d:02}-reload-{f:02}.png') for f in range(95)],8,shadow_id['cell'])
    print('ROCKET_PACKED_DIRECTION',d,flush=True)
# Compose this weapon's own icon on the existing fixed foundation.
chosen=24 if 24 in directions else directions[0]
canvas=Image.new('RGBA',(640,640))
for image,scale in [(load(ROOT/'tech-priests_src/graphics/entity/bunker-autocannon/base-north.png'),.315463840961),
                    (load(a.out/f'preview-{chosen:02}.png'),.774999976158)]:
    size=round(image.width*scale*2)
    canvas.alpha_composite(image.resize((size,size),Image.Resampling.LANCZOS),(round(320-size/2),round(400-1.11090652*64-size/2)))
crop=canvas.crop(canvas.getchannel('A').getbbox());crop.thumbnail((120,120),Image.Resampling.LANCZOS)
icon=Image.new('RGBA',(128,128));icon.alpha_composite(crop,((128-crop.width)//2,(128-crop.height)//2));icon.save(a.out/'icon.png')
known={r['file'] for r in records}
for path in a.out.glob('*.png'):
    if path.name not in known:records.append({'file':path.name,'sha256':sha(path)})
(a.out/'assets.json').write_text(json.dumps({'status':'ACTUAL_ART_COMBAT_FIXTURE' if a.static_combat_test else ('PACKED_ALL_DIRECTIONS' if full else 'PARTIAL_STAGE'),
 'directions':directions,'body_identity':body_id,'shadow_identity':shadow_id,'files':records,
 'native_core':'Opaque intersection of every body pose, eroded one pixel',
 'scope':'Exact atlas readback and clipping checks; final native main-mod visual acceptance remains separate'},indent=2)+'\n')
print('ROCKET_PACKING_COMPLETE',len(directions),flush=True)
