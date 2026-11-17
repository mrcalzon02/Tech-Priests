"""Seal current square Advanced source, exported renders and actual native proof."""
from pathlib import Path
import json,hashlib,shutil,math
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/space-cargo-inventories/v01/advanced';B=O.parent/'basic';P=R/'build/advanced-cargo-v01-native';N=O/'native-evidence';N.mkdir(exist_ok=True);ID='tech-priests-advanced-space-cargo-inventory';h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();sha=h(O/'advanced-space-cargo-v01.blend');exportsha=h(O/'advanced-space-cargo-v01.glb')
for name in ('inspection.json','basic-reuse-audit.json','square-footprint.json','integration.json','captures/capture.json','pump-bore-audit.json','pipe-pair-clearance.json'):
 d=json.loads((O/name).read_text());assert d['source_sha256']==sha,name
 if 'passed' in d:assert d['passed'],name
raw=json.loads((P/'user-data/script-output/data-raw-dump.json').read_text());cfg=json.loads((O/'contract.json').read_text());binding=json.loads((P/'source-binding.json').read_text());art=R/'tech-priests_src/graphics/entity/advanced-space-cargo-v01'
for p in [R/'tech-priests_src/prototypes/martian_stone_cache.lua',*art.glob('*.png')]:assert binding[p.relative_to(R/'tech-priests_src').as_posix()]==h(p),p
assert (P/'mods/tech-priests/control.lua').read_bytes()==(R/'tech-priests_src/control.lua').read_bytes(),'Native control snapshot differs from current production'
proof=P/'user-data/script-output/advanced-cargo';native=json.loads((proof/'native-results.json').read_text());reload=json.loads((proof/'reload-results.json').read_text());assert native['passed'] and native['tile_width']==5 and native['tile_height']==5 and reload['passed'] and reload['four_directions_preserved'];assert all(r['passed'] for r in native['rotations'])
for name in ('native-results.json','reload-results.json','native-platform.png','native-circuits.png','native-rotations.png','native-direction-0.png','native-direction-4.png','native-direction-8.png','native-direction-12.png'):shutil.copy2(proof/name,N/name)
def diff(a,b,p=''):
 if type(a)!=type(b):return [p]
 if isinstance(a,dict):return [v for k in a.keys()|b.keys() for v in ([p+'/'+k] if k not in a or k not in b else diff(a[k],b[k],p+'/'+k))]
 if isinstance(a,list):return [p] if len(a)!=len(b) else [v for i,(x,y) in enumerate(zip(a,b)) for v in diff(x,y,p+'/'+str(i))]
 return [] if a==b else [p]
changes={}
for label,kind in [('prototype','container'),('item','item'),('recipe','recipe')]:
 paths=diff(cfg[label],raw[kind][ID]);assert all(p in ('/icon','/direction_count','/circuit_connector') or any(p.startswith(s) for s in ('/picture/','/circuit_connector/','/selection_box/','/collision_box/')) for p in paths),paths;changes[label]=paths
assert raw['container'][ID]['collision_box']==[[-2.2,-2.2],[2.2,2.2]] and raw['container'][ID]['selection_box']==[[-2.5,-2.5],[2.5,2.5]]
assert raw['container'][ID]['inventory_size']==50
baseline=json.loads((R/'build/basic-cargo-v01-native/user-data/script-output/data-raw-dump.json').read_text());unchanged=[]
for kind in ('container','accumulator','storage-tank','item','recipe'):
 for name,v in baseline.get(kind,{}).items():
  if name.startswith('tech-priests-stone-cache-') or name in ('tech-priests-martian-stone-cache','tech-priests-basic-space-cargo-inventory'):
   assert raw[kind][name]==v,(kind,name);unchanged.append(kind+'/'+name)
source_reference=Path('C:/Users/Admin/Downloads/345hd7download.png');reference=dict(owner_sheet_sha256=h(source_reference) if source_reference.exists() else None,retained_original_sha256=h(O/'original-reference.png'))
review=dict(passed=True,source_sha256=sha,export_sha256=exportsha,native=native,reload=reload,prototype_changes=changes,unchanged_other_family_definitions=unchanged,reference=reference,detail_pass='213 mounted additions: raised edges/seam armor, hinge gussets, bridge/corner supports, boom ribs/retainers, louver vent, hollow paired pump stacks and four supply/return tubes with actual bored receivers.400 source/GLB axial bore probes pass.',geometry='Owner-corrected square base; original Basic3pane module plus adjacent massive double cargo door into actual subframe shaft, crane seated next to windows and lofted over doorway.',placement_change='Explicit owner instruction SQUARE: Advanced alone corrected from5x4 to5x5. Selection±2.5/collision±2.2 on both axes.50slots,recipe,health,research,wire reach and platform restrictions unchanged.',projection='Actual model/GLB square4.92x4.92. Sprite-only worldYsqrt2 after facing rotation registers the square deck on square Factorio tiles; source/runtime physical geometry remains undeformed.',private_fixture='Exact production prototype/art plus separate private electric source and ordinary pole/inserter fixtures on a genuine platform; no diagnostic UI or helper ships.',owner_approval='Advanced final model/native visual approval not inferred from Basic acceptance or technical gates.')
(N/'review.json').write_text(json.dumps(review,indent=2)+'\n');shutil.copy2(P/'source-binding.json',N/'source-binding.json')
(O/'surface-plan.json').write_text(json.dumps(dict(basis_source_sha256=json.loads((B/'owner-approval.json').read_text())['source_sha256'],source_sha256=sha,basis='Accepted Basic source retained:242 meshes, exact topology/UV/material binding audit. Uniform0.8 assembly fit only; no component stretching.',environment='Unchanged Boiler V08 workshop lights/world and Standard color transform inherited from accepted Basic.',roles={'basic':'Exact accepted steel/green-glass/cedar/cargo kit','door':'Dark iron/cast frame, machined retaining ribs, bronze captive pins and physically modeled chevrons; source-scale grime and wear','crane':'Dark structural steel with bolted machined covers, actual retained journals, supported struts, chain/hook and sealed service cabinet','cast_badges':'Supplied DGordillo mesh and original sculpt normals; bronze skull, oxide mechanical half and dark cog','services':'Actual Pipette sampled service sweeps, tangent-aligned receiving glands, supported rear conduit and cable saddles. Continuous physical-scale UVs on generated routes.'},glass='Accepted green tint and soft art-directed highlight retained; no hard specular patch reinstated.'),indent=2)+'\n')
(O/'README.md').write_text('''# Advanced Space Cargo Inventory V01

Owner-rescoped construction: keep the original Basic three-window cargo module,
add a huge closed double cargo door into a real subframe shaft and a large
articulated overhanging crane. The pedestal sits close to the cargo windows;
the raised boom and suspended hook reach back over the door. The dense detail pass
adds213mounted parts: panel lips/seam armor, gussets, corner shoes, bolted web
edges, a true louver vent, two hollow pump stacks, and four supply/return tubes
with actually bored receivers.400 source/GLB axial bore probes pass. The rejected
four-bay and rectangular studies remain under `studies/` and are not delivery.

The source is a genuine square:4.92x4.92 units. Owner's explicit SQUARE correction
requires Advanced native placement5x5, selection±2.5/collision±2.2 on both axes.
Capacity50, health420,18s recipe, void-cogitator research, platform-only rules
and wire reach9 are preserved. Square placement permits normal R quarter-turns.

`advanced-space-cargo-v01.blend` is packed editable source; the `.glb` is the actual
independently reimported runtime artifact. `basic-reuse-audit.json` proves all242
Basic meshes/UV/material bindings remain unchanged, with only a uniform0.8 module
fit and translation. Materials and lighting inherit the accepted Basic finish.

`occlusion.json` declares three green windows and the closed cargo-door shaft.
Opaque walls/floors and render-only grade holdouts enforce aperture clipping.
Holdouts are omitted from physical GLB and reconstructed by its renderer.
All four source/export leak and stress passes are inspected. Native sprites use
an explicitly recorded sprite-only worldYsqrt2 projection after facing rotation
to match Factorio's square tiles; physical source and GLB remain undeformed.

Four bodies/shadows and matching64px icon are integrated. Actual platform proof:
5x5 buildability, ground/empty-space rejection,50general slots,mixed items,
all16 ordinary inserter sides, capacity block/recovery, red/green contents/reach,
loaded R quarter-turns, original recipe/research,mining and reload. Test helpers
are isolated and do not ship. Crane/door are static service equipment; no new
powered loader, controller or unsupported working animation is invented.

Original editable Advanced source was unavailable; the supplied sheet and original
PNG are references, and the accepted Basic source is reused. Technical gates and
agent visual review are separate from final owner visual approval.

See `native-evidence/review.json`, `visual-review.json`, `square-footprint.json`,
`service-route.json` and `rear-service-route.json` for exact scope and evidence.
''')
D=R/'docs/art/remaining-structures';p=D/'checklist.json';q=json.loads(p.read_text());row=next(r for r in q['structures'] if r['id']==ID);row.update(state='Rescoped square Basic-plus-door/crane source and four-way integration technically verified; owner review open',source=(O/'advanced-space-cargo-v01.blend').relative_to(R).as_posix(),model='Complete accepted Basic3pane module retained; square4.92x4.92 base, huge braced cargo door/subframe shaft, large window-side crane lofted over door,213new structural/service details, paired bored pump stacks, louver vent and source-sheet hardware. Independent source/GLB/reuse/contact/occlusion checks pass.',sprites='Four native square-tile projected bodies/shadows and matching icon integrated; contacts rotate correctly.',functional='Actual5x5 platform placement,50slots,16ordinary inserter sides,capacity/recovery,circuits/reach,loadedRquarter-turns,research,mining/reload pass. Owner-required square placement is the only gameplay-bound change.',owner_approval='Basic basis accepted. Advanced corrected construction and final native visuals await owner review.',next='Review Advanced final source/native square layout; reconcile Citadel work already on main before new geometry. Finished Cogitators, Sterling and Void Steam Engine remain excluded.',evidence=[(O/n).relative_to(R).as_posix() for n in ('contract.json','construction.json','basic-reuse-audit.json','square-footprint.json','inspection.json','integration.json','dense-detail-manifest.json','pump-bore-audit.json','native-evidence/review.json')]);q.update(active=ID,active_batch=[ID]);p.write_text(json.dumps(q,indent=2)+'\n')
p=D/'CHECKLIST.md';lines=p.read_text().splitlines();lines=['| '+row['name']+' | '+row['model']+' | '+row['sprites']+' | '+row['functional']+' | '+row['next']+' |' if l.startswith('| '+row['name']+' |') else l for l in lines];p.write_text('\n'.join(lines)+'\n')
(D/'CONTINUATION.json').write_text(json.dumps(dict(current='Advanced square Basic-plus-door/crane technical delivery',model_completion=row['model'],sprite_integration=row['sprites'],functional_verification=row['functional'],owner_approval=row['owner_approval'],source_sha256=sha,export_sha256=exportsha,paths=dict(source=row['source'],evidence=(N/'review.json').relative_to(R).as_posix(),gallery=(N/'native-platform.png').relative_to(R).as_posix(),square=(O/'square-footprint.json').relative_to(R).as_posix()),owner_corrections=['Retain Basic module; append door/crane rather than four-bay replacement','Source sheet footprint is SQUARE:5x5 native placement','Crane pedestal close to cargo windows; boom lofted over doorway'],next=row['next'],coordination='Main93ef5cee completed Void Steam Engine elsewhere; Sterling completed elsewhere. Protect Tanks, separate emergency steam engine, accepted Basic and hydrogen/reactors.',queue_complete=False),indent=2)+'\n')
ledger=R/'docs/art/MODEL_COMPLETION_LEDGER.md';s=ledger.read_text(encoding='utf-8');heading='## Advanced cargo square Basic-plus-door/crane — 2026-11-17'
if heading not in s:ledger.write_text(s+'\n\n'+heading+'\n\n[Source and exact evidence](../../art/source-to-3d/space-cargo-inventories/v01/advanced/README.md). Owner-rescoped existing Basic3pane module plus huge closed subframe cargo door and large crane seated near windows/lofted over door. Square4.92x4.92 source and owner-corrected5x5 native placement;50slots/recipe/research preserved.242Basic mesh/UV/material bindings audited unchanged. Packed source/actualGLB, real four-view occlusion/contact inspection and four directional sprites/shadows/icon integrated. Actual platform16inserter sides,circuits/capacity/research/mining and loadedRquarter-turn/reload pass. Dense greeble pass adds213mounted parts and bored pump service loops;400source/GLB receiver probes pass. Source-sheet fit remains owner-reviewable; no final approval inferred. Rejected four-bay/rectangle studies archived.\n',encoding='utf-8')
credit='Low Poly Skull (Craneo) by DGordillo\nhttps://blendswap.com/blend/2499\nCC BY3.0: https://creativecommons.org/licenses/by/3.0/\nAdaptations: resized, aged materials, fitted bionic half-mask and cog, reused as mounted cargo relief/cast door badges. No endorsement implied.\n'
(O/'CREDITS.txt').write_text(credit);(O.parent/'CREDITS.txt').write_text(credit);(R/'tech-priests_src/graphics/entity/space-cargo-credits.txt').write_text(credit)
print('ADVANCED_CURRENT_SOURCE_NATIVE_SQUARE_DELIVERY_SEALED')
