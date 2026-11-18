"""Recover the actual Item Vault contract and author its hatch surfaces."""
from pathlib import Path
import json,hashlib,shutil
import numpy as np
from PIL import Image
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/item-vault/v01';T=O/'textures';T.mkdir(parents=True,exist_ok=True);ID='tech-priests-stone-cache-item-vault';h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
dump=R/'build/martian-cache-v01-native/user-data/script-output/data-raw-dump.json';raw=json.loads(dump.read_text())
for src,name in [(R/'tech-priests_src/graphics/entity/stone-cache'/f'{ID}.png','original-reference.png'),(R/'tech-priests_src/graphics/entity/stone-cache'/f'{ID}-shadow.png','original-shadow.png'),(R/'tech-priests_src/graphics/icons/stone-cache'/f'{ID}.png','original-icon.png'),(R/'tech-priests_src/prototypes/martian_stone_cache.lua','original-prototype.lua')]:
 if not (O/name).exists():shutil.copy2(src,O/name)
contract=dict(id=ID,prototype=raw['container'][ID],item=raw['item'][ID],recipe=raw['recipe'][ID],recipe_unlocks=[n for n,t in raw['technology'].items() if any(e.get('recipe')==ID for e in t.get('effects',[]))],behavior=dict(storage='Ten general unfiltered slots; ordinary local storage, not logistics or item-specific filtering',footprint='2x2, collision +/-0.9, selection +/-1, ground z0',directions='Fixed north; four review rotations only',circuits='Inherited red/green connector points, reach9, native read-contents controls',fluids=False,electric_power=False,animation='Static container; handwheel/hatch do not gain invented gameplay animation',recipe='Enabled hand crafting, 8s, stone48 iron-plate6 iron-gear-wheel2',access='Normal Factorio inserter grid on all four sides'),source_recovery=dict(result='Original sprite/shadow/icon recovered; no original editable Item Vault model found in workspace or model ledger',approach='Independently author hatch and hardware on the reusable authored cache wall; no Tanks models used'),reconciliation=dict(main='372ee9db56ac05b0bb2134a2c02d0a287d1351a0, latest change registers Tanks Calcifier; no Item Vault conflict',other_chat='Tanks structures chat currently working Thinking Hut in tanks-structure-production; no Item Vault overlap',baseline_dump_sha256=h(dump),prototype_sha256=h(O/'original-prototype.lua'),cache_kit_sha256=h(R/'art/source-to-3d/martian-stone-cache/v01/martian-stone-enclosure-kit.blend'),owner_state='Proceeding on user continue instruction; shared stone finish and model owner approval remain pending, not recorded as approved'))
(O/'contract.json').write_text(json.dumps(contract,indent=2)+'\n');shutil.copy2(R/'art/source-to-3d/martian-stone-cache/v01/capture-profile.json',O/'capture-profile.json')
N=1024;rng=np.random.default_rng(741);y,x=np.mgrid[0:N,0:N]/N;X=(x-.5)*1.4;Y=(y-.5)*1.4
def noise(n):return np.asarray(Image.fromarray(np.uint8(rng.uniform(0,255,(n,n)))).resize((N,N),Image.Resampling.BICUBIC),dtype=float)/255-.5
broad=noise(12);grain=noise(128);fine=noise(1024)
boundary=np.maximum.reduce([np.abs(X)/.50,np.abs(Y)/.45,(np.abs(X)+np.abs(Y))/.87])
edge=np.exp(-((boundary-1)/.018)**2);seam=np.exp(-((boundary-1.06)/.025)**2)
rub=np.exp(-((np.hypot(X-.17,Y+.02)-.20)/.014)**2)
scratches=(np.maximum(0,np.sin(x*947+y*19)-.992))*np.clip(grain+.12,0,1)
maps={}
for role in ('forged-iron','rubbed-iron','gasket'):
 if role=='gasket':
  rgb=np.stack([.080+.025*broad,.066+.020*broad,.047+.018*broad],axis=2);rough=np.full((N,N),.94);metal=np.zeros((N,N));height=.003*grain
 else:
  wear=np.clip(edge*.35+rub*.25,0,1);dark=np.clip(seam*.11+np.maximum(0,-broad)*.10,0,.24)
  base=(.27 if role=='forged-iron' else .37)+.075*broad+.02*grain-dark+wear
  rgb=np.stack([base*1.08,base*1.00,base*.84],axis=2);rough=np.clip(.73+.10*grain-.30*wear-(.13 if role=='rubbed-iron' else 0),.35,.88);metal=np.full((N,N),.82);height=.008*grain+.001*fine-scratches*.5
 gy,gx=np.gradient(height);nx=-gx*30;ny=-gy*30;nz=np.ones_like(nx);length=np.sqrt(nx*nx+ny*ny+nz*nz);normal=np.stack([nx/length*.5+.5,ny/length*.5+.5,nz/length*.5+.5],axis=2);orm=np.stack([np.ones_like(rough),rough,metal],axis=2)
 for kind,array in [('albedo',rgb),('orm',orm),('normal',normal)]:Image.fromarray(np.uint8(np.clip(array*255,0,255))).save(T/(role+'-'+kind+'.png'))
 maps[role]={k:dict(path=(T/(role+'-'+k+'.png')).relative_to(R).as_posix(),sha256=h(T/(role+'-'+k+'.png'))) for k in ('albedo','orm','normal')}
(O/'surface-plan.json').write_text(json.dumps(dict(regions={'wall':'Reused cache quarry surfaces, provisional owner finish state retained','hatch':'Forged iron, seam grime at actual hatch reinforcement and edge wear at rectangular door boundary; wear ring follows handwheel XY placement','hardware':'Rubbed iron at handle, hub, hinges and bolt crowns, subdued bronze oxidation rather than polished chrome','gasket':'Dark fibrous gasket under hatch, high roughness and no metal'},uv='Hatch maps registered in world XY over 1.4 units; hardware uses physical-scale planar/cylindrical UV; original supplied skull UV/sculpt normal retained',maps=maps),indent=2)+'\n')
print('ITEM_VAULT_CONTRACT_AND_SURFACES_READY')
