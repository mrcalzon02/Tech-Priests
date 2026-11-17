"""Seal actual Basic evidence and keep remaining work explicit."""
from pathlib import Path
import json,hashlib,shutil
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/space-cargo-inventories/v01/basic';P=R/'build/basic-cargo-v01-native';N=O/'native-evidence';N.mkdir(exist_ok=True);h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();ID='tech-priests-basic-space-cargo-inventory';cfg=json.loads((O/'contract.json').read_text());raw=json.loads((P/'user-data/script-output/data-raw-dump.json').read_text());binding=json.loads((P/'source-binding.json').read_text())
for p in [R/'tech-priests_src/prototypes/martian_stone_cache.lua',R/'tech-priests_src/control.lua',*(R/'tech-priests_src/graphics/entity/basic-space-cargo-v01').glob('*.png')]:assert binding[p.relative_to(R/'tech-priests_src').as_posix()]==h(p),p
assert (P/'mods/tech-priests/control.lua').read_bytes()==(R/'tech-priests_src/control.lua').read_bytes()
proof=P/'user-data/script-output/basic-cargo';native=json.loads((proof/'native-results.json').read_text());reload=json.loads((proof/'reload-results.json').read_text());assert native['passed'] and reload['passed']
sha=h(O/'basic-space-cargo-v01.blend')
for n in ('inspection.json','integration.json','captures/capture.json'):assert json.loads((O/n).read_text())['source_sha256']==sha
def diff(a,b,p=''):
 if type(a)!=type(b):return [p]
 if isinstance(a,dict):return [x for k in a.keys()|b.keys() for x in ([p+'/'+k] if k not in a or k not in b else diff(a[k],b[k],p+'/'+k))]
 if isinstance(a,list):return [p] if len(a)!=len(b) else [x for i,(v,w) in enumerate(zip(a,b)) for x in diff(v,w,p+'/'+str(i))]
 return [] if a==b else [p]
changes={}
for label,kind in [('prototype','container'),('item','item'),('recipe','recipe')]:
 paths=diff(cfg[label],raw[kind][ID]);assert all(p in ('/icon','/direction_count','/circuit_connector') or p.startswith('/picture/') or p.startswith('/circuit_connector/') for p in paths),paths;changes[label]=paths
base=json.loads((R/'build/filtered-caches-v01-native/user-data/script-output/data-raw-dump.json').read_text());unchanged=[]
for kind in ('container','accumulator','storage-tank','item','recipe'):
 for name,v in base.get(kind,{}).items():
  if not (name.startswith('tech-priests-stone-cache-') or name in ('tech-priests-martian-stone-cache','tech-priests-advanced-space-cargo-inventory')):continue
  assert raw[kind][name]==v,(kind,name);unchanged.append(kind+'/'+name)
for name in ('native-results.json','reload-results.json','native-platform.png','native-circuits.png','native-rotations.png','native-direction-0.png','native-direction-4.png','native-direction-8.png','native-direction-12.png'):shutil.copy2(proof/name,N/name)
review=dict(passed=True,source_sha256=sha,export_sha256=h(O/'basic-space-cargo-v01.glb'),native=native,reload=reload,prototype_changes=changes,unchanged_other_family_definitions=unchanged,private_fixture='Unmodified production mod plus private electric-energy-interface source feeding normal poles and ordinary inserters. Real LuaSpacePlatform, applied starter pack and foundation tiles. No test helper ships.',cargo_revision='Owner requested varied cargo: slatted timber crate, metal case, three chime/hoop/bung barrels, supported tray with two open-jaw spanners, hammer and two screwdrivers; previous repeated-case study retained',rotation_revision='Owner requested wall trusses and alternate rotations: continuous chords/diagonal braces/gussets plus four native pictures and registered contacts. Normal placed R flips180 on original6x3 grid; all four placement grids pass.',visual_review='Native deck registration, bounded three green windows and varied cargo/circuit hardware inspected; clay/open/empty well plus four GLB views inspected separately.',owner_approval='Owner accepted refined steel/green source as Advanced basis; final native screenshot approval not separately inferred')
(N/'review.json').write_text(json.dumps(review,indent=2)+'\n')
doc='''# Basic Space Cargo Inventory V01

Mostly flush steel platform insert over three closed, below-grade cargo wells.
The bays now vary: slatted wooden crate plus sealed case, three rolled-hoop red
barrels with bungs, and a supported tray of spanners, hammer and screwdrivers.
Accepted FMPL steel/gunmetal/brass/red surfaces and baked directional cedar
replace the initial generic-noise study. Rounded plate/tool edges, formed drum
shoulders and smooth barrel normals replace the overly sharp pilot. The exact
Boiler V08 workshop world, lights and Standard transform are preserved.
Green glazing has a soft low-energy highlight; its effective IOR1.08 is an
art-directed thin-window approximation, rather than a laboratory glass value.

Green glazing, receiving ledges, opaque partition walls and a sealed floor are
editable physical geometry. Corner locks and circuit contacts sit above grade.
The centered relief reuses the supplied skull and bionic assembly.

The original editable cargo source was unavailable; original sprite/icon/shadow
references are retained. This is an independently authored replacement.

`basic-space-cargo-v01.blend` contains packed PBR maps and render-only grade
holdouts. `basic-space-cargo-v01.glb` is the actual physical export. Reconstruct
the cutaway environment from `occlusion.json` when rendering GLB: it does not
provide automatic engine clipping. Factorio uses the baked bounded sprite.

Source and export inspection pass: UVs/maps, finite nondegenerate meshes,
grade-bearing rim, recorded contacts, four-view aperture isolation, neutral clay,
open/empty wells and a deliberately protruding underground stress test. All four
views report zero outside-aperture pixels with one-pixel antialias allowance;
the stress object falls from 1531 visible pixels to zero with clipping.

Four directional bodies, aperture-respecting above-grade shadows and 64px icon are
integrated into the actual prototype. This passive container has no invented
working machinery, cargo-quantity animation or player masking controls.

Real Factorio platform tests pass: 6x3 placement, ground and empty-space rejection,
20 general slots, all four ordinary inserter sides, mixed items, full blocking
and recovery, red/green contents and wire reach, research unlock, mining contents
and reload. Gameplay fields and the other family prototypes remain unchanged.

Wall trusses have continuous chords, fitted gussets and diagonal load braces along
long walls, ends and partitions. All four native placement directions have aligned
circuit points and ordinary inserter access. The original mixed-parity 6x3 grid
uses 180-degree R turns when already placed; quarter-turn placement uses the
normal 3x6 tile alignment. No custom relocation or precision-inserter rule added.

Technical gates pass. Owner accepted this refined source as the Advanced basis;
final native screenshot approval is not separately inferred. Advanced has a
read contract and recovered references, but no model yet. Build its distinct
larger compartment and supported fittings using this clipping standard next.
'''
(O/'README.md').write_text(doc)
D=R/'docs/art/remaining-structures';p=D/'checklist.json';q=json.loads(p.read_text());row=next(x for x in q['structures'] if x['id']==ID)
row.update(state='Accepted refined steel/green source exported and four-way production integration verified',source=(O/'basic-space-cargo-v01.blend').relative_to(R).as_posix(),model='Owner-accepted refined FMPL steel/green-glass finish in Boiler V08 workshop rig; rounded deck/tool edges and formed barrel shoulders. Packed editable flush deck, green panes and varied sub-deck cargo: timber crate, sealed case, three barrels, supported tray of spanners/hammer/drivers, and wall trusses with continuous chords/gussets; supplied skull relief reused. Source/export contacts, UVs/maps, four-view occlusion, clay/open/empty/stress checks pass.',sprites='Four native directional cutaway bodies/shadows, rotated circuit graphics and matching icon integrated',functional='Genuine platform6x3/3x6: four placement facings and sixteen ordinary inserter sides pass; rotated circuits/bounds,20slots,blocking/recovery,research,mining/reload pass. Placed R flips180 on native mixed-parity grid.',owner_approval='Owner accepted refined source as Advanced basis; final native screenshot approval not separately inferred',evidence=[(O/n).relative_to(R).as_posix() for n in ('contract.json','inspection.json','occlusion.json','integration.json','native-evidence/review.json')],next='Advanced Space Cargo Inventory: build native5x4 expanded compartment from the accepted Basic materials/softened forms, preserving50slots and platform/recipe/research contract.')
q.update(active=ID,active_batch=[ID],updated_owner_date='2026-11-17');p.write_text(json.dumps(q,indent=2)+'\n')
lines=[]
for line in (D/'CHECKLIST.md').read_text().splitlines():
 if line.startswith('| '+row['name']+' |'):line='| '+row['name']+' | '+row['model']+' | '+row['sprites']+' | '+row['functional']+' | '+row['next']+' |'
 lines.append(line)
(D/'CHECKLIST.md').write_text('\n'.join(lines)+'\n')
(D/'CONTINUATION.json').write_text(json.dumps(dict(current='Basic Space Cargo Inventory wrapped; Advanced next',model_completion=row['model'],sprite_integration=row['sprites'],functional_verification=row['functional'],owner_approval=row['owner_approval'],paths=dict(source=row['source'],evidence=(N/'review.json').relative_to(R).as_posix(),gallery=(N/'native-rotations.png').relative_to(R).as_posix(),standard='docs/art/BELOW_GRADE_VIEWPORT_STANDARD.md'),next=row['next'],advanced='Contract/reference recovery complete; geometry not started. No duplicate pilot.',coordination='Main2a5eca127a6564d27deb613e432a4b5dd266dad7 Sterling source/FMPL work preserved. Tanks, separate steam engine, completed Cogitators, hydrogen/reactors untouched.',queue_complete=False),indent=2)+'\n')
ledger=R/'docs/art/MODEL_COMPLETION_LEDGER.md';s=ledger.read_text(encoding='utf-8');heading='## Basic Space Cargo Inventory V01 below-grade delivery — 2026-11-17'
if heading not in s:ledger.write_text(s+'\n\n'+heading+'\n\n[Source, actual GLB and evidence](../../art/source-to-3d/space-cargo-inventories/v01/basic/README.md). Packed editable flush steel deck, green panes and closed underground wells; supplied skull reused. Independent source/export/contact, four-view zero-leak and protrusion-stress checks pass. Fixed-facing body/shadow/icon integrated; genuine platform placement, ordinary inserters on four sides, capacity/circuits/research/mining and reload pass. Other family definitions unchanged. Owner visual approval separate. Advanced contract read; geometry next.\n',encoding='utf-8')
s=ledger.read_text(encoding='utf-8')
old='Packed editable flush steel deck, green panes and closed underground wells; supplied skull reused.'
new='Packed editable flush steel deck, green panes and closed underground wells; supplied skull reused. Owner cargo-variation revision adds a slatted timber crate, sealed metal case, three hooped barrels with bungs, and a supported tray of open-jaw spanners, hammer and screwdrivers. Prior repeated-case study is retained; new source/export, sprites and native evidence replace it.'
if old in s and 'Owner cargo-variation revision' not in s:ledger.write_text(s.replace(old,new,1),encoding='utf-8')
print('BASIC_CARGO_TECHNICAL_GATES_AND_CONTINUATION_SAVED')
