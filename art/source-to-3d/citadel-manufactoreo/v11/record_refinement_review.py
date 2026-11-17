"""Bind the actually viewed refinement and focused contact findings to hashes."""
from pathlib import Path
import json,hashlib
O=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
ins=json.loads((O/'runtime-inspection.json').read_text());channels=json.loads((O/'fmpl-channel-verification.json').read_text())
assert ins['technical_checks_passed'] and channels['passed']
checks=[]
for name in('clearance-raw.json','clearance-runtime-raw.json'):
 d=json.loads((O/name).read_text());owners=d['motion_owners'];foreign={k:v for k,v in d['pairs'].items()if v['moving']and len({owners[n]for n in k.split(' <> ')})>1}
 stud_contacts=[k for k in d['pairs']if 'crowned roof service arch' in k and 'crown arch foot retained stud' in k]
 assert not foreign and not stud_contacts,(foreign,stud_contacts)
 checks.append({'report':name,'artifact_sha256':d['sha256'],'sampled_poses':d['sampled_poses'],'raw_contacts':len(d['pairs']),'foreign_moving_contacts':0,'arch_pipe_foot_stud_contacts':0})
ref=O.parents[1]/'tp-sterling-contract-main01/mods/tech-priests_0.1.687/graphics/entity/citadel-manufactoreo/citadel-manufactoreo-idle.png'
ref=ref.resolve();assert ref.is_file(),ref
renders=['actual-glb-front.png','actual-glb-detail.png','actual-glb-rear.png','actual-glb-clay.png']
report={'review_kind':'delegated-refinement-review-not-owner-approval','source_sha256':ins['source_sha256'],'runtime_sha256':ins['runtime_sha256'],'reference':{'path':str(ref),'sha256':sha(ref),'role':'current original enclosed gothic cathedral sprite'},'actually_viewed_render_sha256':{n:sha(O/n)for n in renders},'score_scale':'0 unacceptable, 5 strong','scores':{'enclosed_cathedral_identity':5,'exterior_detail_density':4,'visible_construction_and_support':4,'fmpl_material_identity':4,'fixed_gameplay_camera_readability':4},'observations':['Opaque green blind glazing, thick closed doors and towers preserve the hidden factory premise.','Roof service arches land on actual capped cartridges. Vertical downlegs clear the foot studs in both source and actual GLB contact inventories.','Tangent-aligned loom clamps and seated cantilever saddles replace the earlier nominal-position clips.','Crown traces follow the real hip normals and frame the existing thermal cassettes.','Front/rear service bays and opaque panels preserve an enclosed manufacturing cathedral rather than expose extra processing functions.','Oblique detail/rear/clay views retain true world proportions; only the canonical front uses sprite square-ground calibration.'],'focused_clearance':checks,'fmpl_export_channels_passed':True,'full_fixed_contact_adjudication_pending':True,'sprites_and_native_art_integration_pending':True,'native_states_and_reload_pending':True,'owner_visual_approved':False,'machine_done':False}
(O/'refinement-review.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({'focused_clearance':checks,'review_recorded':True}))
