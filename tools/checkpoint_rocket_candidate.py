"""Copy verified candidate evidence into an explicitly unfinished authoring lane."""
import hashlib,json,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
source=ROOT/'build/rocket-salvo/model-v4/rocket-salvo'
out=ROOT/'art/bunker-rocket-salvo/candidate-v01';out.mkdir(parents=True,exist_ok=True)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
inspection=json.loads((source/'independent-export-inspection.json').read_text())
motion=json.loads((source/'source-motion-check.json').read_text())
assert inspection['status']=='PASS' and inspection['degenerate_triangles']==0
assert inspection['meshes']==inspection['meshes_with_uv']
assert motion['status']=='PASS_SOURCE_STUDY' and not motion['native_runtime_tested']
assert sha(source/'rocket-salvo.blend')==inspection['native_sha256']==motion['native_sha256']
assert sha(source/'rocket-salvo.glb')==inspection['glb_sha256']
files=['rocket-salvo.blend','rocket-salvo.glb','front.png','rear.png','quarter.png','side.png',
       'reload-study.png','import-front.png','import-rear.png','import-quarter.png','import-clay.png',
       'contract.json','independent-export-inspection.json','source-motion-check.json']
for name in files:shutil.copy2(source/name,out/name)
review={'status':'TECHNICAL_CANDIDATE_OWNER_REVIEW_PENDING','owner_visual_approval':False,
    'native_runtime_implemented':False,'native_sha256':sha(out/'rocket-salvo.blend'),
    'glb_sha256':sha(out/'rocket-salvo.glb'),
    'renders_viewed':['import-quarter.png','import-rear.png','import-clay.png','reload-study.png'],
    'render_sha256':{name:sha(out/name) for name in files if name.endswith('.png')},
    'finish_reference_sha256':sha(ROOT/'art/bunker-twin-cannon/quarter.png'),
    'internal_scores_out_of_5':{'distinct_pod_silhouette':4,'mechanical_readability':3,
       'surface_readability':3,'family_consistency':4},
    'review':'Separate three-cell pods and loaded noses read clearly. Rear triangular cassette retainers, guide rails and hinge axes are visible. Red removable shields, dark launch tubes and steel fittings retain the family finish. Detail is strongest at close range; gameplay-size readability and all moving-part collisions are not yet accepted.',
    'source_checks':{'frames':241,'packed_used_images':motion['packed_images'],
       'triangles':inspection['triangles'],'degenerate_triangles':0,'meshes_with_uv':inspection['meshes_with_uv']},
    'retained_failures':[{'candidate':'model-v1','failure':'96 degenerate louvre triangles; repaired edge break'},
       {'candidate':'model-v3','failure':'Cassette minimum Z 1.655 at frame 116; shorter drop now stays above socket'}],
    'next_gate':'Owner model review, then detailed motion/clearance and native ammo/cadence pilot'}
(out/'review.json').write_text(json.dumps(review,indent=2)+'\n',encoding='utf-8')
(out/'README.md').write_text('''# Rocket salvo candidate 01

Original editable model and static GLB, with packed source textures, a six-shot
source study and visible cassette/shutter reload. This is a model candidate;
it is not installed in the game and has no owner visual approval yet.

Open rocket-salvo.blend at frame 1. Source frames 1-52 demonstrate staggered
departures; frames 57-212 demonstrate the reload. The fixed concrete bunker
is deliberately separate. The GLB is a static independently inspected export.
See review.json, source-motion-check.json and independent-export-inspection.json
for exact scope, hashes and limitations. Full moving-part collision proof and
native targeting, ammo, projectiles, effects and save/reload remain open.

Design and proposed runtime ownership: docs/prototypes/rocket-salvo-design.md.
Authoring: tools/art/build_rocket_salvo_turret.py with the packed family studio
input used by the earlier weapons. Used textures are packed in this final source.
Failed studies remain under build/rocket-salvo locally; they were not promoted.
''',encoding='utf-8')
manifest={name:sha(path) for path in out.iterdir() if path.is_file() and (name:=path.name)!='SHA256.json'}
(out/'SHA256.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('ROCKET_CANDIDATE_CHECKPOINT_READY',len(manifest),'files',sum(p.stat().st_size for p in out.iterdir()))
