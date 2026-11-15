"""Package the five playable bunker prototypes without the factory runtime."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import zipfile
ROOT=Path(__file__).resolve().parents[1]
NAME='tech-priests-bunker-family-prototype'
VERSION='0.3.0'
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--out',type=Path,required=True)
p.add_argument('--fixture',action='store_true')
p.add_argument('--scenario',choices=['bunker-family','bullet-turrets'],default='bunker-family')
p.add_argument('--headless-graphics',action='store_true')
a=p.parse_args()
assert not a.headless_graphics or (a.fixture and a.scenario=='bullet-turrets'),'Placeholder graphics are allowed only in the isolated headless behavior fixture'
if not a.fixture:
    assert json.loads((ROOT/'docs/prototypes/bunker-dish-working-assets.json').read_text())['status']=='PACKED'
    assert json.loads((ROOT/'docs/prototypes/bullet-turret-assets.json').read_text())['status']=='PASS'
out=a.out.resolve();out.mkdir(parents=True,exist_ok=True)
mod=out/(NAME+'_'+VERSION);mod.mkdir(exist_ok=True)
for folder in ('prototypes','locale/en'):(mod/folder).mkdir(parents=True,exist_ok=True)
for name in ('bunker_autocannon.lua','bunker_autocannon_graphics.lua','bunker_family.lua','bunker_bullet_weapons.lua'):
    shutil.copy2(ROOT/'tech-priests_src/prototypes'/name,mod/'prototypes'/name)
(mod/'scripts').mkdir(exist_ok=True)
shutil.copy2(ROOT/'tech-priests_src/scripts/bunker_family_visuals.lua',mod/'scripts/bunker_family_visuals.lua')
shutil.copy2(ROOT/'tech-priests_src/scripts/bullet_turret_controller.lua',mod/'scripts/bullet_turret_controller.lua')
shipping_control="local v=require('scripts.bunker_family_visuals');v.install();script.on_init(v.init);script.on_event(defines.events.on_tick,v.tick)\n"
(mod/'control.lua').write_text(shipping_control)
for folder in ('bunker-autocannon','bunker-lobber','bunker-energy-dish','bunker-chicago-piano','bunker-twin-minigun'):
    if a.headless_graphics and folder in ('bunker-chicago-piano','bunker-twin-minigun'):continue
    shutil.copytree(ROOT/'tech-priests_src/graphics/entity'/folder,mod/'graphics/entity'/folder,dirs_exist_ok=True)
for file in ('bunker-autocannon.cfg','bunker-family.cfg'):
    shutil.copy2(ROOT/'tech-priests_src/locale/en'/file,mod/'locale/en'/file)
shutil.copy2(ROOT/'docs/prototypes/bullet-turrets-readme.md',mod/'README.md')
(mod/'info.json').write_text(json.dumps({'name':NAME,'version':VERSION,'factorio_version':'2.1',
    'title':'Tech Priests — Bunker Family Prototypes','author':'Christopher Vardeman',
    'dependencies':['base >= 2.1.0','? tech-priests'],
    'description':'Playable autocannon, six-station grenade lobber, powered energy dish, quad burst gun and twin minigun. Provisional alternate-weapon balance.'},indent=2)+'\n')
(mod/'data.lua').write_text('require("prototypes.bunker_family").register("'+NAME+'")\nrequire("prototypes.bunker_bullet_weapons").register("'+NAME+'")\n')
(mod/'data-final-fixes.lua').write_text('require("prototypes.bunker_autocannon").finalize()\nrequire("prototypes.bunker_family").finalize_grenades()\nrequire("prototypes.bunker_bullet_weapons").finalize()\n')
if a.fixture:
    for file in ('control.lua','data-final-fixes.lua'):
        shutil.copy2(ROOT/'tests/scenarios'/a.scenario/file,mod/file)
    if a.headless_graphics:
        target=mod/'data-final-fixes.lua';target.write_text('local HEADLESS_GRAPHICS=true\n'+target.read_text())
    scenario=mod/'scenarios'/a.scenario;scenario.mkdir(parents=True,exist_ok=True)
    (scenario/'control.lua').write_text('-- Fixture in mod control.\n')
    print(json.dumps({'fixture':str(mod)}));raise SystemExit(0)
assert (mod/'control.lua').read_text()==shipping_control,'Combat test fixture must never ship'
assert not (mod/'scenarios').exists(),'Use a fresh output directory; fixture scenarios must never ship'
archive=out/(NAME+'_'+VERSION+'.zip')
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=1) as z:
    for f in sorted(mod.rglob('*')):
        if f.is_file():z.write(f,f.relative_to(out))
with zipfile.ZipFile(archive) as z:assert z.testzip() is None
print(json.dumps({'archive':str(archive),'bytes':archive.stat().st_size,
                  'sha256':hashlib.sha256(archive.read_bytes()).hexdigest()}))
