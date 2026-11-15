"""Prepare actual all-direction bunker weapon art for combat tests by default."""
import json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
out=ROOT/'build/rocket-salvo/combat-actual-art-v1'
model=ROOT/'art/bunker-rocket-salvo/candidate-v02/rocket-salvo.blend'
if (out/'assets.json').exists():
    r=json.loads((out/'assets.json').read_text());assert r['status']=='ACTUAL_ART_COMBAT_FIXTURE'
    print('ACTUAL_COMBAT_ART_READY',out);raise SystemExit(0)
blender=Path('C:/Users/Admin/Documents/Codex/2026-11-07/referenced-chatgpt-conversation-this-is-an/work/blender-5.0.1/blender-5.0.1-windows-x64/blender.exe')
python=Path('C:/Users/Admin/Documents/Codex/2026-11-07/referenced-chatgpt-conversation-this-is-an/work/art-venv/Scripts/python.exe')
shadows=ROOT/'build/rocket-salvo/combat-static-shadows-v1'
with (ROOT/'build/rocket-combat-shadow-preparation.log').open('w') as log:
    subprocess.run([str(blender),'--factory-startup','-b','-t','4','--python-exit-code','12',
        '--python',str(ROOT/'tools/art/capture_rocket_combat_test_shadows.py'),'--',str(model),str(shadows)],stdout=log,stderr=subprocess.STDOUT,check=True)
with (ROOT/'build/rocket-combat-art-packing.log').open('w') as log:
    subprocess.run([str(python),str(ROOT/'tools/pack_rocket_salvo.py'),'--shadows',str(shadows),'--out',str(out),'--static-combat-test'],stdout=log,stderr=subprocess.STDOUT,check=True)
print('ACTUAL_COMBAT_ART_READY',out)
