"""Bind all ten sources to inspected sprites and the actual installed filter proof."""
from pathlib import Path
import json,hashlib,shutil,copy
R=Path(__file__).resolve().parents[3];B=R/'art/source-to-3d/filtered-stone-caches/v01';P=R/'build/filtered-caches-v01-native';N=B/'native-evidence';N.mkdir(exist_ok=True);cat=json.loads((B/'catalog.json').read_text());h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();binding=json.loads((P/'source-binding.json').read_text());raw=json.loads((P/'user-data/script-output/data-raw-dump.json').read_text())
for name in ('prototypes/martian_stone_cache.lua','scripts/core/stone_cache_filter_0534.lua','scripts/core/storage_role_authority_0686.lua'):assert binding[name]==h(R/'tech-priests_src'/name),name
prod=(R/'tech-priests_src/control.lua').read_bytes();bridge=Path(__file__).with_name('filter-proof-bridge.lua').read_bytes();assert (P/'mods/tech-priests/control.lua').read_bytes()==prod+b'\n-- BEGIN PRIVATE FILTER PROOF BRIDGE\n'+bridge
for p in (R/'tech-priests_src/graphics/entity/filtered-stone-caches-v01').glob('*.png'):assert binding[p.relative_to(R/'tech-priests_src').as_posix()]==h(p)
proof_dir=P/'user-data/script-output/filtered-caches';native=json.loads((proof_dir/'native-results.json').read_text());reload=json.loads((proof_dir/'reload-results.json').read_text());assert native['passed'] and reload['reload_preserved']
def diff(a,b,path=''):
 if type(a)!=type(b):return [path]
 if isinstance(a,dict):return [p for k in a.keys()|b.keys() for p in ([path+'/'+k] if k not in a or k not in b else diff(a[k],b[k],path+'/'+k))]
 if isinstance(a,list):return [path] if len(a)!=len(b) else [p for i,(x,y) in enumerate(zip(a,b)) for p in diff(x,y,path+'/'+str(i))]
 return [] if a==b else [path]
def allowed(p):return p=='/icon' or p.startswith('/picture/') or (p.startswith('/circuit_connector/') and any('/sprites/'+k+'/' in p or p.endswith('/sprites/'+k) for k in ('connector_main','connector_shadow')))
ids={row['id']:row['key'] for row in cat['rows']};basepath=R/'build/fluid-vault-v01-native/user-data/script-output/data-raw-dump.json';assert h(basepath)==cat['baseline_dump_sha256'];baseline=json.loads(basepath.read_text());unchanged=[]
for kind in ('container','accumulator','storage-tank','item','recipe'):
 for name,definition in baseline.get(kind,{}).items():
  if name in ids:continue
  if name.startswith('tech-priests-stone-cache-') or name in ('tech-priests-martian-stone-cache','tech-priests-basic-space-cargo-inventory','tech-priests-advanced-space-cargo-inventory'):
   origin=name.removesuffix('-recycling')
   if kind=='recipe' and name.endswith('-recycling') and origin in ids:
    expected=copy.deepcopy(definition);expected['icons'][1]['icon']='__tech-priests__/graphics/entity/filtered-stone-caches-v01/'+ids[origin]+'-icon.png';assert raw[kind][name]==expected;continue
   assert raw[kind][name]==definition,(kind,name);unchanged.append(kind+'/'+name)
for name in ('native-results.json','reload-results.json','native-gallery.png'):shutil.copy2(proof_dir/name,N/name)
shutil.copy2(P/'source-binding.json',N/'source-binding.json');shutil.copy2(P/'private-control-binding.json',N/'private-control-binding.json')
records=[]
for row in cat['rows']:
 O=R/row['path'];cfg=json.loads((O/'contract.json').read_text());source=h(O/(row['stem']+'.blend'));changes={}
 for name in ('inspection.json','integration.json','captures/capture.json'):assert json.loads((O/name).read_text())['source_sha256']==source
 for label,kind in [('prototype','container'),('item','item'),('recipe','recipe')]:
  paths=diff(cfg[label],raw[kind][row['id']]);assert all(allowed(p) for p in paths),paths;changes[label]=paths
 assert native['rows'][row['key']]['passed'];dest=O/'native-evidence';dest.mkdir(exist_ok=True);shutil.copy2(proof_dir/('native-'+row['key']+'.png'),dest/'native.png')
 rec=dict(passed=True,key=row['key'],source_sha256=source,export_sha256=h(O/(row['stem']+'.glb')),native=native['rows'][row['key']],reload=reload,prototype_changes=changes,proof='Actual installed production steward invoked in its own mod context using real cache/station/priest/sink entities and inventory operations; no replacement filter or mock deposit. Private remote bridge is appended only in isolated proof copy, never production.',filter_semantics=cfg['filter_behavior'],owner_approval='User requested simplified rapid batch; final native visuals remain separately reviewable')
 (dest/'review.json').write_text(json.dumps(rec,indent=2)+'\n');records.append(dict(key=row['key'],source_sha256=source,passed=True))
(N/'review.json').write_text(json.dumps(dict(passed=True,rows=records,unchanged_other_family_definitions=unchanged,private_instrumentation='Production control is exact original prefix plus private bridge; actual filter and storage authority files hash-match production; diagnostic remote interface does not ship.',scope='Each six-slot cache: four ordinary inserter in/out sides, capacity block/recovery, both circuit colors/reach, mining and reload. Each existing filter: no-pair safe retention, blocked safe restoration, paired exact reroute, allowed preservation, no spill/custody loss.',owner_approval='Pending final visuals'),indent=2)+'\n');print('TEN_FILTERED_CACHES_CURRENT_NATIVE_EVIDENCE_PASS')
