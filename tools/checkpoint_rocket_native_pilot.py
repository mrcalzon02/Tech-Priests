"""Retain exact native-pilot results and partial sprite evidence, never a release."""
import json,hashlib,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];out=ROOT/'docs/prototypes/rocket-native-pilot';out.mkdir(exist_ok=True)
physics=ROOT/'build/rocket-salvo/native-physics/user-data/script-output/rocket-salvo-physics'
animated=ROOT/'build/rocket-salvo/animated-pilot-v1/user-data/script-output/rocket-salvo-animated'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for src,dst in [(physics/'fresh.json','physics-fresh.json'),(physics/'save-reload.json','physics-save-reload.json'),
                (animated/'result.json','actual-art-headless.json'),(animated/'result-graphical.json','actual-art-graphical.json')]:
    r=json.loads(src.read_text());assert r['status']=='PASS';shutil.copy2(src,out/dst)
resume=json.loads((out/'physics-save-reload.json').read_text())['resume']
assert resume['tick']==resume['saved_tick']+1 and resume['reload_owners']>0
for name in ('opening.png','feeding.png','closing.png','initial-facing-3.png','native-inventory-preview.png','empty-facing-3.png'):
    shutil.copy2(animated/name,out/name)
shutil.copytree(ROOT/'build/rocket-salvo/runtime-pilot-art-v1',ROOT/'art/bunker-rocket-salvo/runtime-pilot-v1',dirs_exist_ok=True)
staged=ROOT/'build/rocket-salvo/animated-pilot-v1/mods/tech-priests-rocket-animation-pilot'
sources={}
for relative in ('scripts/rocket_salvo_controller.lua','scripts/rocket_salvo_geometry.lua','prototypes/bunker_rocket_salvo.lua'):
    assert sha(ROOT/'tech-priests_src'/relative)==sha(staged/relative),'Source changed after actual-art proof'
    sources[relative]=sha(staged/relative)
(out/'source-proof.json').write_text(json.dumps({'status':'NATIVE_PILOT_VERIFIED','sources':sources,
    'socket_model_sha256':json.loads((ROOT/'tech-priests_src/scripts/rocket_salvo_geometry.json').read_text())['native_sha256'],
    'scope':'23 native physics sites / 8 directions, 8 actual-art sites / 4 directions',
    'main_mod_registered':False,'production_complete':False,
    'remaining':['Full 64 heading capture/pack','Moving reload shadows','Full main-mod registration and regression','Final native preview/effect review and delivery']},indent=2)+'\n')
(out/'README.md').write_text('''# Rocket native pilot

Native targeting/projectiles/ammunition remain engine owned. The controller
chooses successive cells and inserts the agreed reload interruption. Real
projectiles are moved to sockets extracted from the checked candidate-v02.

Fresh and separate-process reload physics pass: 23 sites, two stock ammunition
types, eight directions, 10-tick intra-salvo gaps / 190-tick last-to-next gap,
research-scaled cadence and exact native damage, target loss, partial resupply,
external disable, destruction/rebuild and untouched stock launcher origins.
The saved tick is observed from serialized state; autosave completion can lag
its request. Reload resumes on the actual saved tick plus one.

Eight real-art sites pass with four captured headings, real rendering objects,
empty cells and the corrected cassette/shutter sequence. Native screenshots
were viewed, including the full turret in its inventory preview and coloured
corner stanchions. Source-proof.json binds the exercised production modules.

This remains an isolated pilot, not a main-mod registration or full delivery.
Four directions and settled-only cap shadows are temporary pilot limitations.
Full body capture is continuing; moving shadows and full-mod regression remain.
The previously completed six main-mod weapons are unchanged.

Reproduce with a local Factorio 2.1 installation:
- python tools/run_rocket_salvo_physics.py
- python tools/run_rocket_salvo_physics.py --graphical (generates real mid-reload save)
- python tools/run_rocket_salvo_physics.py --reload
- python tools/run_rocket_salvo_animated.py [--graphical]

Graphical fixtures pause after their PASS report; close only their recorded
fixture PID after observing the result. The animated runner can use the
published partial art under art/bunker-rocket-salvo/runtime-pilot-v1.
''',encoding='utf-8')
print('ROCKET_NATIVE_PILOT_CHECKPOINT_READY')
