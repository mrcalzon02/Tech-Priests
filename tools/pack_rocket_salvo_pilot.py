"""Pack exact pilot body cells and conservatively occluded nose overlays."""
import json,hashlib
from pathlib import Path
from PIL import Image,ImageChops,ImageFilter
ROOT=Path(__file__).resolve().parents[1];body=ROOT/'build/rocket-salvo/runtime-pilot-v1'
shadows=ROOT/'build/rocket-salvo/runtime-shadow-pilot-v1';out=ROOT/'build/rocket-salvo/runtime-pilot-art-v1';out.mkdir(exist_ok=True)
identity=json.loads((body/'identity.json').read_text());dirs=json.loads((body/'pilot.json').read_text())['directions']
assert identity['source_sha256']==json.loads((shadows/'capture.json').read_text())['source_sha256']
records=[]
def pack(name,cells,columns):
    cell=256;sheet=Image.new('RGBA',(columns*cell,((len(cells)+columns-1)//columns)*cell))
    for i,im in enumerate(cells):sheet.paste(im,(i%columns*cell,i//columns*cell))
    path=out/name;sheet.save(path)
    with Image.open(path) as read:
        for i,im in enumerate(cells):
            assert read.crop((i%columns*cell,i//columns*cell,i%columns*cell+cell,i//columns*cell+cell)).tobytes()==im.tobytes()
    records.append({'file':name,'frames':len(cells),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
def load(p):
    with Image.open(p) as im:return im.convert('RGBA')
for d in dirs:
    idle=load(body/f'd{d:02}-idle.png');cells=[load(body/f'd{d:02}-reload-{f:02}.png') for f in range(95)]
    for im in [idle]+cells:
        box=im.getchannel('A').getbbox();assert box and box[0]>0 and box[1]>0 and box[2]<256 and box[3]<256,'Clipped body cell'
    pack(f'idle-body-{d:02}.png',[idle],1);pack(f'reload-body-{d:02}.png',cells,8)
    minimum=idle.getchannel('A')
    for im in cells:minimum=ImageChops.darker(minimum,im.getchannel('A'))
    core=idle.copy();core.putalpha(minimum.point(lambda v:255 if v==255 else 0).filter(ImageFilter.MinFilter(3)));core.save(out/f'native-{d:02}.png')
    noses=[]
    for i in range(6):
        poses=[load(body/f'd{d:02}-nose{i}-p{f:03}.png') for f in identity['nose_holdout_poses']]
        mask=poses[0].getchannel('A')
        for pose in poses[1:]:mask=ImageChops.darker(mask,pose.getchannel('A'))
        cell=poses[0].copy();cell.putalpha(mask);noses.append(cell)
    pack(f'noses-{d:02}.png',noses,6)
    load(shadows/f'shadow-{d:02}.png').save(out/f'shadow-{d:02}.png')
    preview=idle.copy()
    for nose in noses:preview.alpha_composite(nose)
    preview.save(out/f'preview-{d:02}.png')
icon=Image.new('RGBA',(128,128));preview=load(out/'preview-32.png');preview.thumbnail((120,120),Image.Resampling.LANCZOS)
icon.alpha_composite(preview,((128-preview.width)//2,(128-preview.height)//2));icon.save(out/'icon.png')
(out/'assets.json').write_text(json.dumps({'status':'PARTIAL_RUNTIME_PILOT','directions':dirs,'identity':identity,
 'files':records,'shadows':'Settled cap only; moving reload shadow remains open',
 'nose_occlusion':'Minimum alpha across five actual holdout poses; in-engine visual check remains required'},indent=2)+'\n')
print('ROCKET_PILOT_PACKED',len(dirs),'headings')
