"""Bind actual native results and prototype comparison to this cache revision."""
from pathlib import Path
import json,hashlib,shutil,copy
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/martian-stone-cache/v01';B=R/'build/martian-cache-v01-native';N=O/'native-evidence';N.mkdir(exist_ok=True);ID='tech-priests-martian-stone-cache'
h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
before=json.loads((O/'contract.json').read_text());after=json.loads((B/'user-data/script-output/data-raw-dump.json').read_text());changes={}
def diff(a,b,path=''):
 if type(a)!=type(b):return [path]
 if isinstance(a,dict):return [p for k in a.keys()|b.keys() for p in ([path+'/'+k] if k not in a or k not in b else diff(a[k],b[k],path+'/'+k))]
 if isinstance(a,list):return [path] if len(a)!=len(b) else [p for i,(x,y) in enumerate(zip(a,b)) for p in diff(x,y,path+'/'+str(i))]
 return [] if a==b else [path]
for label,kind in [('prototype','container'),('item','item'),('recipe','recipe')]:
 paths=diff(before[label],after[kind][ID]);changes[label]=paths
 allowed=lambda p:p in ('/icon','/icon_size') or p.startswith('/picture/') or (p.startswith('/circuit_connector/') and any('/sprites/'+field+'/' in p for field in ('connector_main','connector_shadow')))
 assert all(allowed(p) for p in paths),paths
native_dir=B/'user-data/script-output/martian-cache'
for name in ('native-results.json','reload-results.json','native-plain.png','native-wired.png','native-ghost.png'):shutil.copy2(native_dir/name,N/name)
native=json.loads((N/'native-results.json').read_text());reload=json.loads((N/'reload-results.json').read_text());assert native['passed'] and reload['reload_preserved']
shutil.copy2(B/'source-binding.json',N/'source-binding.json')
receipt=dict(passed=True,source_sha256=h(O/'martian-stone-cache-v01.blend'),export_sha256=h(O/'martian-stone-cache-v01.glb'),prototype_changes=changes,native=native,reload=reload,art_hashes={p.name:h(p) for p in (R/'tech-priests_src/graphics/entity/martian-stone-cache-v01').glob('*.png')},owner_approval='Pending materials and revised model review; technical pass is not owner acceptance')
(N/'review.json').write_text(json.dumps(receipt,indent=2)+'\n');print('CURRENT_CACHE_NATIVE_EVIDENCE_SAVED')
