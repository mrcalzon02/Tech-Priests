#!/usr/bin/env python3
"""Build the playable data-only cannon add-on; never repack the protected baseline."""
import argparse, hashlib, json, shutil, zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
NAME='tech-priests-bunker-cannon-prototype'
p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);p.add_argument('--family',choices=['2.0','2.1'],default='2.1');p.add_argument('--fixture',action='store_true');a=p.parse_args()
base=a.out.resolve();base.mkdir(parents=True,exist_ok=True);mod=base/(NAME+'_0.1.0')
if mod.exists():shutil.rmtree(mod)
(mod/'prototypes').mkdir(parents=True);(mod/'locale/en').mkdir(parents=True)
for name in ['bunker_autocannon.lua','bunker_autocannon_graphics.lua']:
    shutil.copy2(ROOT/'tech-priests_src/prototypes'/name,mod/'prototypes'/name)
shutil.copytree(ROOT/'tech-priests_src/graphics/entity/bunker-autocannon',mod/'graphics/entity/bunker-autocannon')
shutil.copy2(ROOT/'tech-priests_src/locale/en/bunker-autocannon.cfg',mod/'locale/en/bunker-autocannon.cfg')
meta={'name':NAME,'version':'0.1.0','factorio_version':a.family,'title':'Tech Priests — Bunker Autocannon Prototype',
 'author':'Christopher Vardeman','dependencies':['base >= '+a.family+'.0','? tech-priests','? space-age >= '+a.family+'.0','? quality >= '+a.family+'.0','? elevated-rails >= '+a.family+'.0'],
 'description':'Original 3x3 bunker autocannon: 64 directions, 32-frame recoil cycle, exact midpoint average firing rate and dedicated ammunition costing 2x rifle resources per round.'}
(mod/'info.json').write_text(json.dumps(meta,indent=2)+'\n')
(mod/'data.lua').write_text('require("prototypes.bunker_autocannon").register("'+NAME+'")\n')
(mod/'data-final-fixes.lua').write_text('require("prototypes.bunker_autocannon").finalize()\n')
(mod/'README.txt').write_text('BUNKER AUTOCANNON PROTOTYPE\n\nInstall this ZIP in the Factorio '+a.family+' mods folder. Works by itself or alongside Tech Priests. Research Fortified autocannon emplacements (military-3 + concrete).\n\n3x3 footprint; 2000 health; range 24; 64 aiming directions; 32 firing frames per direction.\n5 1/3 shots/sec average: 20 shots per 225 simulation ticks, using native 11-tick shots and a 5-tick magazine reload. No combat runtime script.\n552.5 physical damage per round, halfway between normal rifle damage 5 and normal cannon-shell total impact 1100.\n20-round magazine: 16 iron plates. Equivalent 20 rifle rounds: 8 iron plates. Every input resource is exactly doubled per round.\n\nThe protected 0.1.672 Tech Priests release is not modified by this add-on.\n')
if a.fixture:
    for name in ['control.lua','data-final-fixes.lua']:shutil.copy2(ROOT/'tests/scenarios/bunker-autocannon'/name,mod/name)
else:
    assert not (mod/'control.lua').exists(), 'Never ship the combat fixture in the playable mod'
archive=base/(NAME+'_0.1.0.zip')
if a.fixture:
    if archive.exists():archive.unlink()
    print(json.dumps({'fixture_directory':str(mod),'fixture':True}))
    raise SystemExit(0)
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for f in sorted(mod.rglob('*')):
        if f.is_file():z.write(f,f.relative_to(base))
with zipfile.ZipFile(archive) as z:assert z.testzip() is None
print(json.dumps({'archive':str(archive),'size_bytes':archive.stat().st_size,'sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),'fixture':a.fixture}))
