"""Bind real-grid behavior and graphics-only prototype changes to this bank."""
from pathlib import Path
import json,hashlib,shutil,copy
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/primitive-battery-bank/v01';B=R/'build/battery-bank-v01-native';N=O/'native-evidence';N.mkdir(exist_ok=True);ID='tech-priests-stone-cache-primitive-acclimator-battery-bank';h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert json.loads((O/'integration.json').read_text())['source_sha256']==h(O/'primitive-battery-bank-v01.blend')
binding=json.loads((B/'source-binding.json').read_text())
for p in (R/'tech-priests_src/graphics/entity/primitive-battery-bank-v01').glob('*.png'):assert binding[p.relative_to(R/'tech-priests_src').as_posix()]==h(p)
assert binding['prototypes/martian_stone_cache.lua']==h(R/'tech-priests_src/prototypes/martian_stone_cache.lua')
contract=json.loads((O/'contract.json').read_text());current=json.loads((B/'user-data/script-output/data-raw-dump.json').read_text())
def diff(a,b,path=''):
 if type(a)!=type(b):return [path]
 if isinstance(a,dict):return [p for k in a.keys()|b.keys() for p in ([path+'/'+k] if k not in a or k not in b else diff(a[k],b[k],path+'/'+k))]
 if isinstance(a,list):return [path] if len(a)!=len(b) else [p for i,(x,y) in enumerate(zip(a,b)) for p in diff(x,y,path+'/'+str(i))]
 return [] if a==b else [path]
def allowed(path):
 if path=='/icon':return True
 if any(path.startswith('/chargable_graphics/'+p+'/') for p in ('picture','charge_animation','discharge_animation')):return True
 if any(path.startswith('/circuit_connector/sprites/'+p+'/') for p in ('connector_main','connector_shadow')):return True
 if any(path.startswith('/circuit_connector/sprites/'+p+'/shift/') for p in ('led_blue','led_blue_off','led_green','led_red')):return True
 return any(path.startswith('/circuit_connector/sprites/'+p+'/') for p in ('blue_led_light_offset','red_green_led_light_offset'))
changes={}
for label,kind in [('prototype','accumulator'),('item','item'),('recipe','recipe')]:
 paths=diff(contract[label],current[kind][ID]);assert all(allowed(p) for p in paths),paths;changes[label]=paths
baseline_path=R/'build/item-vault-v01-native/user-data/script-output/data-raw-dump.json';assert h(baseline_path)==contract['baseline']['dump_sha256'];baseline=json.loads(baseline_path.read_text());family=[]
for kind in ('container','accumulator','storage-tank','item','recipe'):
 for name,definition in baseline.get(kind,{}).items():
  if name==ID:continue
  if name.startswith('tech-priests-stone-cache-') or name in ('tech-priests-martian-stone-cache','tech-priests-basic-space-cargo-inventory','tech-priests-advanced-space-cargo-inventory'):
   if kind=='recipe' and name==ID+'-recycling':
    expected=copy.deepcopy(definition);expected['icons'][1]['icon']='__tech-priests__/graphics/entity/primitive-battery-bank-v01/icon.png';assert current[kind][name]==expected;continue
   assert current[kind][name]==definition,(kind,name);family.append(kind+'/'+name)
native_dir=B/'user-data/script-output/battery-bank'
for name in ('native-results.json','reload-results.json','native-plain.png','native-charge.png','native-discharge.png'):shutil.copy2(native_dir/name,N/name)
native=json.loads((N/'native-results.json').read_text());reload=json.loads((N/'reload-results.json').read_text());assert native['passed'] and reload['reload_preserved'];shutil.copy2(B/'source-binding.json',N/'source-binding.json')
result=dict(passed=True,source_sha256=h(O/'primitive-battery-bank-v01.blend'),export_sha256=h(O/'primitive-battery-bank-v01.glb'),prototype_changes=changes,unchanged_family_definitions=family,native=native,reload=reload,art_hashes={p.name:h(p) for p in (R/'tech-priests_src/graphics/entity/primitive-battery-bank-v01').glob('*.png')},native_applicability='Actual accumulator; ordinary electrical pole coverage and native signal-A are tested. Inserter/physical-item storage tests do not apply.',owner_approval='Pending owner model and shared finish review; no approval inferred from next instruction')
(N/'review.json').write_text(json.dumps(result,indent=2)+'\n');print('BATTERY_BANK_CURRENT_NATIVE_EVIDENCE_PASS')
