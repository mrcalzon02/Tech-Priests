"""Exact production art, fluid behavior and graphics-only change evidence."""
from pathlib import Path
import json,hashlib,shutil,copy
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/pressurized-fluid-vault/v01';B=R/'build/fluid-vault-v01-native';N=O/'native-evidence';N.mkdir(exist_ok=True);h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();cfg=json.loads((O/'contract.json').read_text());ID=cfg['id'];source=h(O/'pressurized-fluid-vault-v01.blend')
assert json.loads((O/'integration.json').read_text())['source_sha256']==source;binding=json.loads((B/'source-binding.json').read_text())
for p in (R/'tech-priests_src/graphics/entity/pressurized-fluid-vault-v01').glob('*.png'):assert binding[p.relative_to(R/'tech-priests_src').as_posix()]==h(p)
assert binding['prototypes/martian_stone_cache.lua']==h(R/'tech-priests_src/prototypes/martian_stone_cache.lua')
current=json.loads((B/'user-data/script-output/data-raw-dump.json').read_text())
def diff(a,b,path=''):
 if type(a)!=type(b):return [path]
 if isinstance(a,dict):return [p for k in a.keys()|b.keys() for p in ([path+'/'+k] if k not in a or k not in b else diff(a[k],b[k],path+'/'+k))]
 if isinstance(a,list):return [path] if len(a)!=len(b) else [p for i,(x,y) in enumerate(zip(a,b)) for p in diff(x,y,path+'/'+str(i))]
 return [] if a==b else [path]
def allowed(p):
 if p=='/icon' or p.startswith('/pictures/'):return True
 if p.startswith('/circuit_connector/'):
  if '/points/' in p:return True
  return any('/sprites/'+n+'/' in p or p.endswith('/sprites/'+n) for n in ('connector_main','connector_shadow','wire_pins','wire_pins_shadow','led_blue','led_blue_off','led_green','led_red','blue_led_light_offset','red_green_led_light_offset'))
 return False
changes={}
for label,kind in [('prototype','storage-tank'),('item','item'),('recipe','recipe')]:
 paths=diff(cfg[label],current[kind][ID]);assert all(allowed(p) for p in paths),paths;changes[label]=paths
baseline_path=R/'build/battery-bank-v01-native/user-data/script-output/data-raw-dump.json';assert h(baseline_path)==cfg['baseline']['dump_sha256'];baseline=json.loads(baseline_path.read_text());unchanged=[]
for kind in ('container','accumulator','storage-tank','item','recipe'):
 for name,definition in baseline.get(kind,{}).items():
  if name==ID:continue
  if name.startswith('tech-priests-stone-cache-') or name in ('tech-priests-martian-stone-cache','tech-priests-basic-space-cargo-inventory','tech-priests-advanced-space-cargo-inventory'):
   if kind=='recipe' and name==ID+'-recycling':
    expected=copy.deepcopy(definition);expected['icons'][1]['icon']='__tech-priests__/graphics/entity/pressurized-fluid-vault-v01/icon.png';assert current[kind][name]==expected;continue
   assert current[kind][name]==definition,(kind,name);unchanged.append(kind+'/'+name)
native_dir=B/'user-data/script-output/fluid-vault'
for name in ('native-results.json','reload-results.json','native-north.png','native-east.png','native-rotated.png'):shutil.copy2(native_dir/name,N/name)
native=json.loads((N/'native-results.json').read_text());reload=json.loads((N/'reload-results.json').read_text());assert native['passed'] and reload['reload_preserved'];shutil.copy2(B/'source-binding.json',N/'source-binding.json')
r=dict(passed=True,source_sha256=source,export_sha256=h(O/'pressurized-fluid-vault-v01.glb'),prototype_changes=changes,unchanged_family_definitions=unchanged,native=native,reload=reload,art_hashes={p.name:h(p) for p in (R/'tech-priests_src/graphics/entity/pressurized-fluid-vault-v01').glob('*.png')},native_scope='Both actual native directions; ordinary half-tile placement, two pipes per tank, water/steam from either side, conservation, capacity blocking/recovery, amount/temperature circuits, loaded rotation/reconnect, mining and settled fluid-state reload on Nauvis. Aquilo freezing not separately exercised.',circuit_graphics_justification='Inherited large vanilla-tank draw points lie outside the compact stone enclosure. Only graphical contacts/pins/LEDs were registered to actual source posts; wire reach and amount/temperature behavior remain unchanged.',owner_review='Owner said close to done and requested directional capture/integration. Final native visual approval is separate.')
(N/'review.json').write_text(json.dumps(r,indent=2)+'\n');print('FLUID_VAULT_CURRENT_NATIVE_EVIDENCE_PASS')
