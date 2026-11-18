"""Actual ten filter contracts and restrained stock-material PBR surfaces."""
from pathlib import Path
import json,hashlib,shutil,math
import numpy as np
from PIL import Image
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/filtered-stone-caches/v01';T=O/'textures';T.mkdir(parents=True,exist_ok=True);h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();dump=R/'build/fluid-vault-v01-native/user-data/script-output/data-raw-dump.json';raw=json.loads(dump.read_text());keys=['coal','copper-ore','copper-plate','copper-cable','iron-gear-wheel','iron-ore','iron-plate','iron-stick','stone','wood'];rows=[]
for key in keys:
 ID='tech-priests-stone-cache-'+key;p=O/key;p.mkdir(exist_ok=True)
 for src,dst in [(R/'tech-priests_src/graphics/entity/stone-cache'/(ID+'.png'),'original-reference.png'),(R/'tech-priests_src/graphics/entity/stone-cache'/(ID+'-shadow.png'),'original-shadow.png'),(R/'tech-priests_src/graphics/icons/stone-cache'/(ID+'.png'),'original-icon.png')]:
  if not (p/dst).exists():shutil.copy2(src,p/dst)
 shutil.copy2(R/'art/source-to-3d/martian-stone-cache/v01/capture-profile.json',p/'capture-profile.json');shutil.copy2(R/'art/source-to-3d/martian-stone-cache/v01/ATTRIBUTION.txt',p/'ATTRIBUTION.txt')
 contract=dict(id=ID,key=key,prototype=raw['container'][ID],item=raw['item'][ID],recipe=raw['recipe'][ID],recipe_unlocks=[n for n,t in raw['technology'].items() if any(e.get('recipe')==ID for e in t.get('effects',[]))],filter_item=key,filter_behavior='Existing runtime steward, not hard per-slot filters: allowed items stay; wrong items reroute physically through actual storage authority when a valid priest/station pair and destination exist. Without a pair, or with blocked destinations, wrong items remain safely rather than being voided.',footprint='2x2, collision +/-0.9, selection +/-1, fixed north, no fluid/electric power',directions='Static general container with existing circuits; other captures are review views only',visual='User requested simple shared stone wall, centered tablet and distinct inner stock filling. Fill is a static type identifier, not animated inventory quantity.',original_source='Original PNG body/shadow/icon recovered. No original editable source found; authored shared wall and independently modeled stock.',baseline_dump_sha256=h(dump),steward_sha256=h(R/'tech-priests_src/scripts/core/stone_cache_filter_0534.lua'),owner_approval='Requested simplified rapid batch; no final visual approval inferred')
 (p/'contract.json').write_text(json.dumps(contract,indent=2)+'\n');rows.append(dict(key=key,id=ID,path=p.relative_to(R).as_posix(),stem='filtered-cache-'+key+'-v01'))
(O/'catalog.json').write_text(json.dumps(dict(rows=rows,shared_source='art/source-to-3d/martian-stone-cache/v01/martian-stone-cache-v01.blend',shared_sha256=h(R/'art/source-to-3d/martian-stone-cache/v01/martian-stone-cache-v01.blend'),instruction='Keep stone wall and centered tablet identical; vary only the interior stock filling.',baseline_dump_sha256=h(dump)),indent=2)+'\n')
N=1024;rng=np.random.default_rng(1020);y,x=np.mgrid[0:N,0:N]/N
def noise(n):return np.asarray(Image.fromarray(np.uint8(rng.uniform(0,255,(n,n)))).resize((N,N),Image.Resampling.BICUBIC),dtype=float)/255-.5
broad=noise(16);grain=noise(140);fine=noise(1024);maps={}
roles=[('coal',(.055,.057,.061),0,.66),('copper-ore',(.25,.14,.065),.15,.86),('copper',(.45,.235,.09),.85,.59),('iron',(.29,.31,.32),.80,.64),('iron-ore',(.25,.21,.19),.06,.90),('stone',(.46,.43,.35),0,.92),('wood',(.24,.135,.058),0,.91),('wood-end',(.48,.32,.15),0,.91)]
for role,color,metal,rough in roles:
 value=1+.22*broad+.06*grain;rgb=np.stack([value*c for c in color],axis=2);metallic=np.full_like(x,metal);height=.015*grain+.002*fine
 if role=='coal':height=.009*grain+.001*fine
 if role=='copper-ore':
  fleck=np.clip((grain+broad*.6-.07)*3,0,1);rgb+=fleck[...,None]*np.array([.16,.16,.045]);metallic+=fleck*.5
 if role=='copper':rgb+=np.maximum(0,-broad-.12)[...,None]*np.array([-.1,.22,.11])
 if role=='iron-ore':rgb+=np.maximum(0,broad)[...,None]*np.array([.14,.025,-.025])
 if role=='wood':
  grooves=.09*np.sin(x*210+np.sin(y*8)*1.8)+.06*np.sin(x*610+y*3);rgb*=np.clip(1+grooves,.6,1.4)[...,None];height+=grooves*.07
 if role=='wood-end':
  r=np.sqrt((x-.48)**2+(y-.52)**2);rings=np.sin(r*170+broad*2);rgb*=np.clip(.88+.10*rings,.6,1.2)[...,None];height+=rings*.002
 gy,gx=np.gradient(height);nx=-gx*25;ny=-gy*25;nz=np.ones_like(x);length=np.sqrt(nx*nx+ny*ny+nz*nz);normal=np.stack([nx/length*.5+.5,ny/length*.5+.5,nz/length*.5+.5],axis=2);orm=np.stack([np.ones_like(x),np.clip(rough+.08*grain,0,1),np.clip(metallic,0,1)],axis=2)
 for kind,a in [('albedo',rgb),('orm',orm),('normal',normal)]:Image.fromarray(np.uint8(np.clip(a*255,0,255))).save(T/(role+'-'+kind+'.png'))
 maps[role]={k:dict(path=(T/(role+'-'+k+'.png')).relative_to(R).as_posix(),sha256=h(T/(role+'-'+k+'.png'))) for k in ('albedo','orm','normal')}
(O/'surface-plan.json').write_text(json.dumps(dict(regions={'coal':'Black nonmetallic fractured lumps with restrained cleavage sheen','ores':'Angular mineral lumps with copper exposures or iron oxide, distinct from coal and stone','metals':'Actual stacked plate, coiled wire, bored gear and rod geometry; copper oxidation and subdued iron highlights','stone':'Warm coarse rubble stock distinct from shared dressed ring wall','wood':'Longitudinal bark grain and actual circular cross-cut end-grain UV; no invented mechanisms'},maps=maps),indent=2)+'\n');print('TEN_FILTER_CONTRACTS_AND_FILL_SURFACES_READY')
