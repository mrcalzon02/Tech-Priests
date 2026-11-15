"""Checkpoint the measured shutter repair without replacing the rejected study."""
import json,hashlib,shutil
from pathlib import Path
root=Path(__file__).resolve().parents[1]
source=root/'build/rocket-salvo/shutter-repair-v1/rocket-salvo'
review=root/'build/rocket-salvo/shutter-repair-v1/shutter-review'
out=root/'art/bunker-rocket-salvo/candidate-v02'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
motion=json.loads((source/'source-motion-check.json').read_text())
sweep=json.loads((source/'shutter-sweep-check.json').read_text())
export=json.loads((source/'independent-export-inspection.json').read_text())
before=json.loads((root/'build/rocket-salvo/model-v4/rocket-salvo/shutter-sweep-check.json').read_text())
assert sweep['collision_count']==0 and sweep['samples']==481
assert before['status']=='FAIL' and before['collision_count']>0
assert motion['status']=='PASS_SOURCE_STUDY' and export['status']=='PASS' and export['degenerate_triangles']==0
assert sha(source/'rocket-salvo.blend')==motion['native_sha256']==sweep['native_sha256']==export['native_sha256']
assert sha(source/'rocket-salvo.glb')==export['glb_sha256']
assert not out.exists(),'Preserve earlier checkpoint'
out.mkdir(parents=True)
for p in source.iterdir():
    if p.suffix in ('.blend','.glb','.png','.json'):shutil.copy2(p,out/p.name)
shutil.copy2(before_path:=root/'build/rocket-salvo/model-v4/rocket-salvo/shutter-sweep-check.json',out/'rejected-v01-shutter-sweep.json')
shutil.copy2(review/'shutter-clearance.gif',out/'shutter-clearance.gif')
for frame in (82,94,140,174,196,237):shutil.copy2(review/('%03d.png'%frame),out/('clearance-%03d.png'%frame))
shutil.copy2(review/'frames.json',out/'rendered-frames.json')
(out/'README.md').write_text('''# Rocket candidate 02 - shutter clearance repair

Repairs the owner-reported flap collision in candidate-v01. The cassette now
withdraws before opening, feeds while fully raised, withdraws before closing,
and parks behind the closed shutter. The panel clears the guide rails and the
loading ram is outboard. Actual source-rendered animation: shutter-clearance.gif.

Evaluated bevelled meshes were tested at 481 half-frame positions. The original
study produces 2,048 frame/part intersections; this revision produces zero.
Only the two intended hinge-pin contacts are exempt. This is sampled triangle
intersection evidence, not a continuous collision solver or acceptance of all
other moving parts. Original failure data is retained alongside the new report.

Editable source, static GLB and independent front/rear/clay inspections are
included. No rocket native firing implementation is present in this checkpoint.
The original candidate is superseded; its limited source checks did not prove
collision clearance. Owner visual approval remains pending.
''',encoding='utf-8')
report={'status':'SHUTTER_REPAIR_VERIFIED','owner_visual_approval':False,'native_runtime_implemented':False,
    'native_sha256':sha(source/'rocket-salvo.blend'),'glb_sha256':sha(source/'rocket-salvo.glb'),
    'original_frame_part_collisions':before['collision_count'],'repaired_collisions':0,
    'samples':481,'step_frames':.5,'views_reviewed':['clearance-094.png','clearance-140.png','clearance-196.png'],
    'next_gate':'Native firing pilot; continue general mechanical and gameplay review'}
(out/'review.json').write_text(json.dumps(report,indent=2)+'\n')
(out/'SHA256.json').write_text(json.dumps({p.name:sha(p) for p in out.iterdir() if p.is_file()},indent=2)+'\n')
(root/'art/bunker-rocket-salvo/candidate-v01/SUPERSEDED.md').write_text('''# Superseded by candidate-v02

The owner correctly identified shutter/structure penetration. Actual swept-mesh
checks confirm it, including closed panel/rail/ram intersections. The original
timing/height checks did not cover collisions. Retain this candidate only as a
rejected historical study; do not integrate it. Repaired source, failure evidence
and the checked replacement sequence are in ../candidate-v02.
''')
print('SHUTTER_REPAIR_CHECKPOINT_READY',str(out))
