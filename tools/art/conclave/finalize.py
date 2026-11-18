"""Bind technical/native receipts to exact source, export, sprites and references."""
from pathlib import Path
import json,hashlib,struct,shutil,subprocess,sys
R=Path(__file__).resolve().parents[3];O=Path(sys.argv[sys.argv.index('--asset')+1]).resolve() if '--asset' in sys.argv else R/'art/source-to-3d/conclave-center/v01';D=R/'docs/art/remaining-structures';N=R/'build/conclave-native-v01';F=N/'user-data/script-output/conclave-center'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
inspect=json.loads((O/'inspection.json').read_text());assert inspect['passed']
data=(O/('conclave-center-v02.glb' if O.name.startswith('v02') else 'conclave-center-v01.glb')).read_bytes();length,kind=struct.unpack_from('<II',data,12);g=json.loads(data[20:20+length]);mats=g['materials']
channels=dict(materials=len(mats),images=len(g['images']),normal_mapped=sum('normalTexture' in x for x in mats),base_color_mapped=sum('baseColorTexture' in x.get('pbrMetallicRoughness',{}) for x in mats),rough_metal_mapped=sum('metallicRoughnessTexture' in x.get('pbrMetallicRoughness',{}) for x in mats),embedded_images=all('bufferView' in x for x in g['images']))
assert channels['embedded_images'] and channels['normal_mapped']>=7 and channels['rough_metal_mapped']>=7
raw=json.loads((N/'user-data/script-output/data-raw-dump.json').read_text());e=raw['container']['tech-priests-conclave-center'];item=raw['item']['tech-priests-conclave-center'];recipe=raw['recipe']['tech-priests-conclave-center']
assert e['inventory_size']==1 and e['max_health']==450 and item['stack_size']==10 and recipe['enabled'] is True
assert e['collision_box']==[[-.9,-.9],[.9,.9]] and e['selection_box']==[[-1,-1],[1,1]]
assert {x['name']:x['amount'] for x in recipe['ingredients']}=={'copper-cable':20,'iron-gear-wheel':10,'iron-plate':20}
assert recipe['energy_required']==5 and e['picture']['layers'][0]['filename'].endswith(('conclave-center-v02' if O.name.startswith('v02') else 'conclave-center-v01')+'/body.png')
native=json.loads((F/'native-results.json').read_text());assert native['passed']
reload=json.loads((F/'reload-results.json').read_text());assert reload['reloaded'] and reload['passed']
gui=json.loads((F/'graphical-governance.json').read_text());gui['physical_interaction_gate']='pending; owner stopped Computer Use with Escape; no GUI pass inferred'
evidence=O/'native-evidence';evidence.mkdir(exist_ok=True)
for p in F.iterdir():
 if p.name in ('native-close.png','native-gameplay.png','native-results.json','reload-results.json','graphical-governance.json'):shutil.copy2(p,evidence/p.name)
source_snapshot=json.loads((N/'source-snapshot.json').read_text());snap=N/'mods/tech-priests';
for p in snap.rglob('*'):
 if p.is_file():source_snapshot[p.relative_to(snap).as_posix()]=sha(p)
(evidence/'tested-source-snapshot.json').write_text(json.dumps(source_snapshot,indent=2)+'\n')
for p in ['tech-priests_src/control.lua','tech-priests_src/data.lua','tech-priests_src/data-final-fixes.lua','tech-priests_src/info.json','tools/fmpl/pipette/blender_adapter.py']:
 old=json.loads((D/'reconciliation.json').read_text())['protected_source_hashes'][p]
 # Concurrent chat edits may legitimately advance these paths. We never write them.
 source_snapshot.setdefault('preservation_observations',{})[p]=dict(initial_sha256=old,current_sha256=sha(R/p),written_by_conclave_tools=False)
receipt=dict(schema='tech-priests.conclave-delivery.v1',model=inspect,export_channels=channels,native=native,reload=reload,graphical_gui=gui,prototype_gameplay_preserved=True,fixed_native_direction=True,working_animation='not applicable to static container',owner_approval='V01 procedural skulls rejected; V02 supplied skulls pending owner review',installed_user_mods=False,published=False,source_sha256=sha(O/('conclave-center-v02.blend' if O.name.startswith('v02') else 'conclave-center-v01.blend')),export_sha256=sha(O/('conclave-center-v02.glb' if O.name.startswith('v02') else 'conclave-center-v01.glb')),integration=json.loads((O/'integration.json').read_text()),image_hashes={p.name:sha(p) for p in evidence.glob('*.png')})
(O/'delivery.json').write_text(json.dumps(receipt,indent=2)+'\n')
ledger=json.loads((D/'checklist.json').read_text());row=next(x for x in ledger['structures'] if x['id']=='tech-priests-conclave-center');row.update(state='V02 supplied skull source/export and sprites integrated; native container/reload tests pass; physical GUI and owner review open',source=O.relative_to(R).as_posix()+'/conclave-center-v01.blend',model='reopened source + GLB measured pass; visually inspected candidate',sprites='fixed north body/shadow/icon integrated; four source facings retained',functional='eight inserter transfers, recipe, inventory and real save/reload pass; physical governance GUI check pending',owner_approval='V01 procedural skulls rejected; V02 supplied skulls pending owner review',evidence=[(O/'delivery.json').relative_to(R).as_posix(),(O/'native-evidence/native-close.png').relative_to(R).as_posix()],next='Review supplied-skull V02 and complete physical governance-screen check; then Martian Stone Cache. Preserve separately assigned work.')
(D/'checklist.json').write_text(json.dumps(ledger,indent=2)+'\n')
subprocess.run(['python',str(Path(__file__).with_name('checkpoint.py'))],check=True)
print('CONCLAVE_TECHNICAL_NATIVE_DELIVERY_SAVED')
