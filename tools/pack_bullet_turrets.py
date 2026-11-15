"""Pack both captured caps, verify exact cells, and derive safe native previews."""
import argparse,json,hashlib
from pathlib import Path
from PIL import Image,ImageChops,ImageFilter
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('captures',type=Path);a=p.parse_args()
all_records=[]
for name in ('chicago-piano','twin-minigun'):
    capture=a.captures/name;metadata=json.loads((capture/'capture.json').read_text());assert metadata['status']=='COMPLETE'
    frames=metadata['identity']['frames'];dest=ROOT/'tech-priests_src/graphics/entity'/('bunker-'+name);dest.mkdir(parents=True,exist_ok=True)
    for d in range(64):
        minimum=None
        for pas,size in [('body',256),('fx',256),('shadow',512)]:
            count=1 if pas=='shadow' else frames
            columns=1 if pas=='shadow' else 6
            sheet=Image.new('RGBA',(columns*size,((count+columns-1)//columns)*size))
            for f in range(count):
                source=capture/(f'd{d:02}-idle-shadow.png' if pas=='shadow' else f'd{d:02}-f{f:02}-{pas}.png')
                with Image.open(source) as cell:
                    assert cell.size==(size,size)
                    sheet.paste(cell,(f%columns*size,f//columns*size))
                    if pas=='body':minimum=cell.getchannel('A') if minimum is None else ImageChops.darker(minimum,cell.getchannel('A'))
            path=dest/f'{pas}-{d:02}.png';sheet.save(path)
            with Image.open(path) as readback:
                for f in range(count):
                    cell_name=f'd{d:02}-idle-shadow.png' if pas=='shadow' else f'd{d:02}-f{f:02}-{pas}.png'
                    with Image.open(capture/cell_name) as cell:
                        assert cell.tobytes()==readback.crop((f%columns*size,f//columns*size,(f%columns+1)*size,(f//columns+1)*size)).tobytes()
            with Image.open(capture/f'd{d:02}-idle-{pas}.png') as idle:idle.save(dest/f'idle-{pas}-{d:02}.png')
        with Image.open(dest/f'idle-body-{d:02}.png') as idle:
            minimum=ImageChops.darker(minimum,idle.getchannel('A'))
            opaque=minimum.point(lambda x:255 if x==255 else 0).filter(ImageFilter.MinFilter(3))
            core=idle.copy();core.putalpha(opaque);core.save(dest/f'native-{d:02}.png')
        assert opaque.getbbox(),'Preview core must contain a cap'
    all_records.append({'name':name,'capture':metadata,'status':'EXACT_CELL_READBACK_PASS',
      'files':[{'name':f.name,'sha256':hashlib.sha256(f.read_bytes()).hexdigest()} for f in sorted(dest.glob('*.png'))]})
(ROOT/'docs/prototypes/bullet-turret-assets.json').write_text(json.dumps({'status':'PASS','weapons':all_records},indent=2)+'\n')
