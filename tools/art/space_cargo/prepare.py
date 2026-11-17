from pathlib import Path
import json,hashlib,shutil,math
import numpy as np
from PIL import Image
R=Path(__file__).resolve().parents[3];B=R/'art/source-to-3d/space-cargo-inventories/v01';T=B/'textures';T.mkdir(parents=True,exist_ok=True);raw_path=R/'build/filtered-caches-v01-native/user-data/script-output/data-raw-dump.json';raw=json.loads(raw_path.read_text());h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for key in ('basic','advanced'):
 p=B/key;p.mkdir(exist_ok=True);ID='tech-priests-'+key+'-space-cargo-inventory'
 for src,name in [(R/'tech-priests_src/graphics/entity/stone-cache'/(ID+'.png'),'original-reference.png'),(R/'tech-priests_src/graphics/entity/stone-cache'/(ID+'-shadow.png'),'original-shadow.png'),(R/'tech-priests_src/graphics/icons/stone-cache'/(ID+'.png'),'original-icon.png')]:
  if not (p/name).exists():shutil.copy2(src,p/name)
 contract=dict(id=ID,key=key,prototype=raw['container'][ID],item=raw['item'][ID],recipe=raw['recipe'][ID],recipe_unlocks=[n for n,t in raw['technology'].items() if any(e.get('recipe')==ID for e in t.get('effects',[]))],owner_brief='Mostly flush platform plane; green glass reveals cargo below grade, with surface fittings and occasional raised machinery. Clip all below-grade drawing outside viewport apertures, following and extending Clay Pit approach.',baseline_dump_sha256=h(raw_path),main='2a5eca127a6564d27deb613e432a4b5dd266dad7, separately completed Sterling source/FMPL update; no cargo overlap',source_recovery='Original sprite/shadow/icon recovered; no original editable cargo source found. Reuse supplied original skull relief and authored fittings where valid.',native='Passive platform-restricted container, no new loader behavior, power/fluid port or inventory-quantity animation',model_state='Basic pilot first; Advanced contract read, geometry not started',owner_approval='Clarified below-grade viewport construction; no final source/native approval inferred')
 (p/'contract.json').write_text(json.dumps(contract,indent=2)+'\n')
profile=dict(camera_policy='fmpl.factorio45.v1',capture_kind='entity',orientation_policy='fixed',directions=[0],source_size=768,states={'idle':[1]},camera_override=dict(type='ORTHO',elevation_deg=45,azimuth_deg=0,distance=8*math.sqrt(2),target=[0,0,0],ortho_scale=7,shift_x=0,shift_y=0));(B/'basic/capture-profile.json').write_text(json.dumps(profile,indent=2)+'\n')
N=1024;rng=np.random.default_rng(1220);y,x=np.mgrid[0:N,0:N]/N
def noise(n):return np.asarray(Image.fromarray(np.uint8(rng.uniform(0,255,(n,n)))).resize((N,N),Image.Resampling.BICUBIC),dtype=float)/255-.5
broad=noise(15);grain=noise(130);fine=noise(1024);maps={}
for role,color,metal,rough in [('deck-steel',(.28,.29,.27),.78,.72),('cargo-green',(.32,.36,.24),.58,.78),('aged-brass',(.40,.28,.12),.84,.62),('well-liner',(.14,.16,.13),.68,.82),('timber',(.48,.29,.13),0,.86),('barrel-red',(.43,.15,.08),.62,.74),('tool-steel',(.48,.51,.49),.86,.45),('glass',(.76,.93,.58),0,.045)]:
 v=1+.14*broad+.035*grain;rgb=np.stack([v*c for c in color],axis=2);height=.008*grain+.001*fine
 if role=='glass':
  height=.0001*fine;v=1+.025*broad;rgb=np.stack([v*c for c in color],axis=2)
 gy,gx=np.gradient(height);nx=-gx*28;ny=-gy*28;nz=np.ones_like(x);d=np.sqrt(nx*nx+ny*ny+nz*nz);normal=np.stack([nx/d*.5+.5,ny/d*.5+.5,nz/d*.5+.5],axis=2);orm=np.stack([np.ones_like(x),np.clip(rough+.04*grain,0,1),np.full_like(x,metal)],axis=2)
 for kind,a in [('albedo',rgb),('orm',orm),('normal',normal)]:Image.fromarray(np.uint8(np.clip(a*255,0,255))).save(T/(role+'-'+kind+'.png'))
 maps[role]={k:dict(path=(T/(role+'-'+k+'.png')).relative_to(R).as_posix(),sha256=h(T/(role+'-'+k+'.png'))) for k in ('albedo','orm','normal')}
(B/'surface-plan.json').write_text(json.dumps(dict(regions={'deck':'Worn flush steel surface panels and fasteners; supported lifting eyes and small locking housings above grade','glass':'Actual green transmitting glass with subtle micro-scratches, separate from opaque green cargo cases','cargo':'Reinforced sealed green crates below grade; worn corner hardware and banding','well':'Dark opaque baffles/walls and closed floor below platform; no visible exterior underground silhouette'},maps=maps),indent=2)+'\n');print('CARGO_CONTRACTS_AND_BELOW_GRADE_SURFACES_READY')
