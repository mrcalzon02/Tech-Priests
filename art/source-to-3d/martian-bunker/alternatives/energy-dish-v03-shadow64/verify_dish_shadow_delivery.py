"""Independent archive-to-authoring-to-atlas pixel proof, no original live capture access."""
import pathlib,json,zipfile,hashlib,io
from PIL import Image,ImageChops
R=pathlib.Path('C:/GITS/Tech-Priests');D=R/'docs/art/energy-dish-v03-shadow64';A=R/'art/source-to-3d/martian-bunker/alternatives/energy-dish-v03-shadow64';v=json.loads((D/'shadow64-validation.json').read_text());r=json.loads((D/'source-shadow64-archive.json').read_text());p=R/r['file'];assert hashlib.sha256(p.read_bytes()).hexdigest()==r['sha256'];checked=0
with zipfile.ZipFile(p) as z:
 assert z.testzip() is None
 for sheet in v['sheets']:
  dest=A/pathlib.Path(sheet['file']).name;assert hashlib.sha256(dest.read_bytes()).hexdigest()==sheet['sha256']
  with Image.open(dest) as atlas:
   atlas.load();cell=sheet['cell'];assert atlas.size==(4*cell,4*cell)
   for direction in range(sheet['directions'][0],sheet['directions'][1]+1):
    row=v['records'][direction];rawbytes=z.read(f'raw/shadow-{direction:02}.png');authoredbytes=z.read(f'authored/shadow-{direction:02}.png');assert hashlib.sha256(rawbytes).hexdigest()==row['shadow_sha256'];assert hashlib.sha256(authoredbytes).hexdigest()==row['authored_shadow_sha256']
    raw=Image.open(io.BytesIO(rawbytes)).convert('RGBA');authored=Image.open(io.BytesIO(authoredbytes)).convert('RGBA');expected=Image.new('RGBA',raw.size,(0,0,0,0));expected.putalpha(raw.getchannel('A').point([round(x*177/255) for x in range(256)]));assert ImageChops.difference(authored,expected).getbbox(alpha_only=False) is None
    if cell!=1280:expected=authored.resize((cell,cell),Image.Resampling.LANCZOS)
    i=direction%16;actual=atlas.crop(((i%4)*cell,(i//4)*cell,(i%4+1)*cell,(i//4+1)*cell));assert ImageChops.difference(expected,actual).getbbox(alpha_only=False) is None;checked+=1
assert checked==128;out={'status':'PASS_ARCHIVED_RAW_TO_AUTHORED_AND_ALL_128_ATLAS_CELLS','archive_sha256':r['sha256'],'raw_frames':64,'authored_frames':64,'exact_cells':checked,'source':'Published delivery folders only; no live capture cache read','native_integration':False};(D/'independent-delivery-proof.json').write_text(json.dumps(out,indent=2)+'\n',encoding='utf-8',newline='\n');print(json.dumps(out))
