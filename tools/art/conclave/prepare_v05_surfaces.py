"""Panel-local wear and mounting stains, derived from existing FMPL image maps."""
from pathlib import Path
import json,hashlib
from PIL import Image,ImageDraw,ImageFilter,ImageOps
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/conclave-center/v05-panels-and-buttresses';T=O/'textures';T.mkdir(parents=True,exist_ok=True);catalog=json.loads((R/'art/source-to-3d/shared-parts/industrial-asset-library/catalog.json').read_text());records={x['material_id']:x for x in catalog['materials']};manifest={};h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for role,base,points in [('roof-panel','machine_steel',[(.09,.13),(.91,.13),(.09,.87),(.91,.87)]),('rear-hatch','brass',[(.13,.14),(.87,.14),(.13,.86),(.87,.86),(.412,.55),(.588,.55)])]:
 spec=records[base];p=R/spec['maps']['albedo']['source_path'];original=Image.open(p).convert('RGB').resize((512,512));gray=Image.blend(ImageOps.grayscale(original),Image.new('L',(512,512),128),.55)
 im=ImageOps.colorize(gray,(37,38,35),(157,156,143)) if role=='roof-panel' else ImageOps.colorize(gray,(30,24,16),(143,116,65))
 grime=Image.new('L',(512,512));d=ImageDraw.Draw(grime);d.rectangle((13,13,499,499),outline=80,width=6)
 for x,y in points:
  x,y=x*512,y*512;d.ellipse((x-13,y-13,x+13,y+13),fill=165);d.ellipse((x-6,y-6,x+6,y+6),fill=70)
 if role=='rear-hatch':
  for x in (.18,.82):d.line((x*512,55,x*512,457),fill=100,width=9)
 grime=grime.filter(ImageFilter.GaussianBlur(3));im=Image.composite(Image.new('RGB',im.size,(34,27,16)),im,grime)
 # Sparse bright scuffs only on exposed panel rims, not bands over the whole model.
 d=ImageDraw.Draw(im)
 for a,b in [((35,16),(128,16)),((344,496),(449,496)),((16,82),(16,121)),((496,320),(496,393))]:d.line((a,b),fill=(122,112,87),width=2)
 out=T/(role+'-albedo.png');im.save(out)
 srcorm=R/spec['maps']['orm']['source_path'];orm=Image.open(srcorm).convert('RGB').resize((512,512));ao,rough,metal=orm.split();rough=Image.blend(rough,Image.new('L',rough.size,185),.55);rough=Image.composite(Image.new('L',rough.size,226),rough,grime);metal=Image.composite(Image.new('L',metal.size,80),metal,grime);Image.merge('RGB',(ao,rough,metal)).save(T/(role+'-orm.png'))
 srcnormal=R/spec['maps']['normal']['source_path'];normal=T/(role+'-normal.png');Image.open(srcnormal).convert('RGB').resize((512,512)).save(normal)
 manifest[role]=dict(fmpl_material_id=base,source_commit=catalog['source_commit'],surface_plan='Panel-local contact staining at measured captive-stud/handle/rib roots; exposed-rim scuffs; restrained directional base metal, increased local roughness and reduced metallic response under grime.',maps={'albedo':dict(path=out.relative_to(R).as_posix(),sha256=h(out),source_sha256=h(p)),'orm':dict(path=(T/(role+'-orm.png')).relative_to(R).as_posix(),sha256=h(T/(role+'-orm.png')),source_sha256=h(srcorm)),'normal':dict(path=normal.relative_to(R).as_posix(),sha256=h(normal),source_sha256=h(srcnormal))})
(O/'panel-surfaces.json').write_text(json.dumps(manifest,indent=2)+'\n');print('V05_PANEL_LOCAL_SURFACES_READY')
