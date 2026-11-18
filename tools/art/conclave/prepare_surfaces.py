"""Author dedicated UV panel maps from pinned FMPL materials; never mutate donors."""
from pathlib import Path
import json,hashlib,random,shutil
from PIL import Image,ImageDraw,ImageFilter
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/conclave-center/v01';O.mkdir(parents=True,exist_ok=True)
T=O/'textures';T.mkdir(exist_ok=True)
catalog=json.loads((R/'art/source-to-3d/shared-parts/industrial-asset-library/catalog.json').read_text());records={x['material_id']:x for x in catalog['materials']}
manifest={}
for role,base in [('cast-frame','gunmetal_dark'),('console-panels','martian_red'),('edge-trim','brass'),('control-keys','iron'),('skull-cast','parchment'),('floor-tread','machine_steel'),('cable-jacket','dark_recess')]:
 spec=records[base];paths={}
 for kind,record in spec['maps'].items():
  im=Image.open(R/record['source_path']).convert('RGB').resize((512,512))
  if kind=='albedo':
   d=ImageDraw.Draw(im);rng=random.Random(41)
   # A physical panel map: localized perimeter wear, corner fastener stains,
   # directional machining on tread, warm ivory casting separate from metal.
   if role=='skull-cast':
    im=Image.blend(im,Image.new('RGB',im.size,(167,153,115)),.52);d=ImageDraw.Draw(im)
   if role in ('console-panels','cast-frame','edge-trim'):
    for j in range(125):
     x=rng.randrange(8,504);y=rng.choice([rng.randrange(6,23),rng.randrange(489,506)])
     d.line((x,y,x+rng.randrange(2,14),y),fill=(92,86,69),width=1)
    for x,y in [(30,30),(482,30),(30,482),(482,482)]:d.ellipse((x-10,y-10,x+10,y+10),outline=(27,25,21),width=3)
   if role=='floor-tread':
    for y in range(20,512,44):
     for x in range(12,512,42):d.line((x,y,x+15,y+8),fill=(83,82,69),width=4)
  p=T/(role+'-'+kind+'.png');im.save(p);paths[kind]=dict(path=p.relative_to(R).as_posix(),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),source_sha256=hashlib.sha256((R/record['source_path']).read_bytes()).hexdigest())
 manifest[role]=dict(fmpl_material_id=base,source_commit=catalog['source_commit'],maps=paths,surface_plan={'cast-frame':'dark cast back shell and structural supports; edge wear on exposed rims','console-panels':'oxide red service panels, localized edge chips and corner stains','edge-trim':'dull brass bezels and retaining bands','control-keys':'oiled iron keys with separate physical faces','skull-cast':'warm ivory cast relief, no metal striping','floor-tread':'steel access tread with directional raised pattern','cable-jacket':'dark flexible internal signal service'}[role])
# CRT image carries actual fictional doctrine readouts, no implementation controls.
im=Image.new('RGB',(512,256),(3,19,3));d=ImageDraw.Draw(im)
for y in range(0,256,4):d.line((0,y,512,y),fill=(5,28,4))
d.text((26,25),'CONCLAVE  /  NOOSPHERIC LINK',fill=(122,198,47),stroke_width=1)
for i,width in enumerate([370,294,320,220,350,275,317]):d.line((28,65+i*20,width,65+i*20),fill=(42,110,16),width=4)
im.save(T/'doctrine-crt-albedo.png')
(O/'surface-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
src=R/'art/source-to-3d/cogitator-stations/skull_master.py';shutil.copy2(src,O/'reused_cast_skull.py')
(O/'reuse-provenance.json').write_text(json.dumps(dict(skull=dict(source=src.relative_to(R).as_posix(),sha256=hashlib.sha256(src.read_bytes()).hexdigest(),license='Existing user-authored procedural cast anatomy; no DGordillo mesh imported.'),fmpl='Real import_materials API, dedicated UV derivatives, Pipette core.plan + blender_adapter.build',original_conclave_source='Unlocated; reconstruction from actual emm13 reference, not recovered historical source.'),indent=2)+'\n')
print('CONCLAVE_SURFACES_READY',len(manifest)*3+1)
