"""Pack all 1024 depth-rendered direction/phase cells without pixel changes."""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('capture',type=Path);a=p.parse_args()
record=json.loads((a.capture/'capture.json').read_text())
assert record['status']=='COMPLETE' and len(record['headings'])==64 and len(record['phases'])==16
assert not record['base_included'] and record['mesh_occluders']==33
out=ROOT/'tech-priests_src/graphics/entity/bunker-energy-dish'
files=[]
for heading in range(64):
    sheet=Image.new('RGBA',(1024,1024))
    for phase in range(16):
        with Image.open(a.capture/f'fx-{heading:02}-{phase:02}.png') as cell:
            assert cell.size==(256,256)
            sheet.paste(cell,(phase%4*256,phase//4*256))
    path=out/f'electrical-{heading:02}.png';sheet.save(path)
    with Image.open(path) as check:
        for phase in range(16):
            with Image.open(a.capture/f'fx-{heading:02}-{phase:02}.png') as source:
                assert source.tobytes()==check.crop((phase%4*256,phase//4*256,(phase%4+1)*256,(phase//4+1)*256)).tobytes()
    files.append({'name':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
(ROOT/'docs/prototypes/bunker-dish-electrical-fx.json').write_text(json.dumps({
    'status':'EXACT_CELL_PACK_PASS','direction_count':64,'phases':16,'base_included':False,
    'occlusion':'Actual 33-mesh dish depth at each heading; no screen-space filaments',
    'source_capture':record,'files':files},indent=2)+'\n')
