"""Establish the base-cache contract and author stone/hide/hemp image surfaces."""
from pathlib import Path
import json,hashlib,shutil,math
import numpy as np
from PIL import Image,ImageFilter,ImageDraw
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/martian-stone-cache/v01';T=O/'textures';T.mkdir(parents=True,exist_ok=True);ID='tech-priests-martian-stone-cache';h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
dump=R/'build/conclave-approved-integration/user-data/script-output/data-raw-dump.json';raw=json.loads(dump.read_text());entity=raw['container'][ID];recipe=raw['recipe'][ID];item=raw['item'][ID]
for src,name in [(R/'tech-priests_src/graphics/entity/stone-cache'/f'{ID}.png','original-reference.png'),(R/'tech-priests_src/graphics/entity/stone-cache'/f'{ID}-shadow.png','original-shadow.png'),(R/'tech-priests_src/graphics/icons/stone-cache'/f'{ID}.png','original-icon.png'),(R/'tech-priests_src/prototypes/martian_stone_cache.lua','original-prototype.lua')]:
 if not (O/name).exists():shutil.copy2(src,O/name)
contract=dict(id=ID,scope='Base cache only; no variants started',prototype=entity,item=item,recipe=recipe,recipe_unlocks=[name for name,tech in raw['technology'].items() if any(e.get('recipe')==ID for e in tech.get('effects',[]))],behavior=dict(storage='Four-slot general emergency station stash; no base-cache item filter',runtime_authorities=['scripts/core/storage_role_authority_0686.lua','scripts/core/master_infrastructure_plan_0644.lua'],filtered_cache_steward_applies=False,fluids=False,electric_power=False,circuit='Inherited steel chest connectors, read-contents control and wire reach9 preserved exactly',directions='Native fixed north; four source rotations for review, no new rotatable behavior',animation='Static cloth-covered container; no native open/working animation and none invented',access='Ordinary Factorio inserters on normal player grid; no precision alignment'),source_recovery=dict(result='Original body/shadow/icon recovered; no editable cache source found in model ledger, shared inventory or workspace source searches',limitation='Independent reconstruction guided by actual original sprite; not claimed recovered Blender source',protected='Tanks source/assets, emergency steam engine, accepted Conclave, hydrogen/reactors and shared in-flight FMPL adapter unchanged'),baseline=dict(native_dump_sha256=h(dump),prototype_sha256=h(O/'original-prototype.lua'),reference_sha256=h(O/'original-reference.png'),main_verified='8c8ddbd5a4f5937190fd6cc801328ef1648f0f37; latest diff registers Tanks Shaler, no cache change',local_checkpoint='991d558ea52ef34d75c29103b232e929f351ded4'))
(O/'contract.json').write_text(json.dumps(contract,indent=2)+'\n')
profile=dict(camera_policy='fmpl.factorio45.v1',capture_kind='entity',orientation_policy='rotatable',directions=[0,90,180,270],source_size=640,states={'idle':[1]},camera_override=dict(type='ORTHO',elevation_deg=45,azimuth_deg=0,distance=8*math.sqrt(2),target=[0,0,.30],ortho_scale=3.0,shift_x=0,shift_y=0));(O/'capture-profile.json').write_text(json.dumps(profile,indent=2))
N=1024;rng=np.random.default_rng(5401);y,x=np.mgrid[0:N,0:N]/N
def noise(size):
 a=np.uint8(rng.uniform(0,255,(size,size)));return np.asarray(Image.fromarray(a).resize((N,N),Image.Resampling.BICUBIC),dtype=float)/255-.5
grain=noise(128);coarse=noise(16);fine=noise(1024);stone=.56+.24*coarse+.17*grain+.035*fine
radius=np.sqrt(((x-.5)*2)**2+((y-.5)*2)**2)
manifest={}
for role in ('stone','ground-stone','hide','hemp','clay'):
 if role in ('stone','ground-stone'):
  value=stone.copy();rgb=np.stack([value*165,value*148,value*113],axis=2)
  if role=='ground-stone':rgb*=np.clip(.56+y*.72,.56,1)[...,None]
  height=coarse*.13+grain*.18+fine*.055;rough=np.clip(.83+grain*.11,0,1);metal=0
 elif role=='hide':
  seams=np.maximum(np.exp(-((x-.5)/.007)**2),np.exp(-((y-.5)/.007)**2));hem=np.clip((radius-.66)*2.5,0,1)
  # Region scars follow the cover rather than a square panel border. Fine
  # hide creases and dark stitch punctures accompany the actual sewn seams.
  scars=np.exp(-(np.sin(x*71+coarse*4+np.sin(y*19)*.5)/.075)**2)*.035
  holes=np.maximum(np.exp(-((x-.5-.010)/.002)**2),np.exp(-((y-.5+.010)/.002)**2))*(np.sin((x+y)*290)>.65)
  value=.76+.25*coarse+.17*grain+.04*fine-.25*hem-.24*seams-scars-.19*holes;rgb=np.stack([value*137,value*48,value*24],axis=2)
  height=grain*.10+fine*.035-scars*.4+.006*np.sin(x*1250)*np.sin(y*1250);rough=np.clip(.82+.10*hem+.07*grain,0,1);metal=0
 elif role=='hemp':
  value=.73+.12*grain+.06*np.sin((x+y*.4)*1500);rgb=np.stack([value*178,value*144,value*88],axis=2);height=grain*.10+.025*np.sin((x+y*.4)*1500);rough=np.full((N,N),.92);metal=0
 else:
  value=.65+.2*coarse+.09*grain;rgb=np.stack([value*72,value*55,value*35],axis=2);height=grain*.12;rough=np.full((N,N),.96);metal=0
 Image.fromarray(np.uint8(np.clip(rgb,0,255))).save(T/(role+'-albedo.png'))
 gy,gx=np.gradient(height);nx=-gx*75;ny=-gy*75;nz=np.ones_like(nx);length=np.sqrt(nx*nx+ny*ny+nz*nz);normal=np.stack([nx/length*.5+.5,ny/length*.5+.5,nz/length*.5+.5],axis=2);Image.fromarray(np.uint8(np.clip(normal*255,0,255))).save(T/(role+'-normal.png'))
 orm=np.stack([np.ones_like(rough),rough,np.full_like(rough,metal)],axis=2);Image.fromarray(np.uint8(orm*255)).save(T/(role+'-orm.png'))
 manifest[role]={kind:dict(path=(T/(role+'-'+kind+'.png')).relative_to(R).as_posix(),sha256=h(T/(role+'-'+kind+'.png'))) for kind in ('albedo','normal','orm')}
(O/'surface-plan.json').write_text(json.dumps(dict(regions={'stone':'Quarried warm rubble, finite chipped geometry, isotropic pitting; lower course receives actual ground-height-aligned dirt gradient.','hide':'Red patchwork hide, radial hem dust and grime on the actual X/Y cross-seams; stitches and folded panel thickness modeled.','hemp':'Dry hemp thread and tie cords, no metallic channels or pretend fluid pipes.','clay':'Dark earth/mud in recessed joints and on cavity floor.'},maps=manifest,uv='Stone at shared physical texel scale; hide UVs registered to whole-cover XY so seam dirt follows actual seams; dense parts do not receive a full wall atlas allocation.',reference='Original stone ring, red stitched cover and front carved tablet retained as identity.'),indent=2))
# Preserve the donor's actual original-UV cavity aging while making the raised
# bone read as warm ivory against the red cog, rather than brown stone.
bone=Image.open(R/'art/source-to-3d/conclave-center/v07-aged-and-ambient/textures/aged-original-skull-albedo.png').convert('RGB');a=np.asarray(bone,dtype=float);a=a*np.array([1.16,1.20,1.35])+np.array([8,18,19]);Image.fromarray(np.uint8(np.clip(a,0,255))).save(T/'cache-bone-ivory-albedo.png')
print('MARTIAN_CACHE_CONTRACT_AND_AUTHORED_MAPS_READY')
