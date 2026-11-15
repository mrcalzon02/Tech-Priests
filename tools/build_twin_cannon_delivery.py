"""Stage/package the complete six-weapon prototype, preserving older archives."""
import argparse,json,hashlib,shutil,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];NAME='tech-priests-bunker-family-prototype';VERSION='0.4.0'
p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);p.add_argument('--stage-only',action='store_true');a=p.parse_args()
out=a.out.resolve();out.mkdir(parents=True,exist_ok=True);mod=out/(NAME+'_'+VERSION)
assert a.stage_only or not (mod/'scenarios').exists(),'Do not ship a fixture staging tree'
assets=ROOT/'tech-priests_src/graphics/entity/bunker-twin-cannon/assets.json'
assert json.loads(assets.read_text())['status']=='PACKED_ALL_DIRECTIONS','Complete cannon art is required'
assert json.loads((ROOT/'docs/prototypes/bunker-team-colour-assets.json').read_text())['status']=='PASS_NATIVE_GAME_RENDER'
if not a.stage_only:
    proof=ROOT/'build/twin-cannon/acceptance-v1/user-data/script-output/twin-cannon-acceptance'
    for name in ('result.json','result-graphical.json','save-reload.json'):
        assert json.loads((proof/name).read_text())['status']=='PASS',name
for folder in ('prototypes','scripts','locale/en'):(mod/folder).mkdir(parents=True,exist_ok=True)
for file in ('bunker_autocannon.lua','bunker_autocannon_graphics.lua','bunker_family.lua','bunker_bullet_weapons.lua','bunker_twin_cannon.lua'):
    shutil.copy2(ROOT/'tech-priests_src/prototypes'/file,mod/'prototypes'/file)
for file in ('bunker_family_visuals.lua','bullet_turret_controller.lua','twin_cannon_controller.lua','bunker_cannon_integration.lua'):
    shutil.copy2(ROOT/'tech-priests_src/scripts'/file,mod/'scripts'/file)
for suffix in ('autocannon','lobber','energy-dish','chicago-piano','twin-minigun','twin-cannon'):
    shutil.copytree(ROOT/'tech-priests_src/graphics/entity'/('bunker-'+suffix),mod/'graphics/entity'/('bunker-'+suffix),dirs_exist_ok=True)
for file in ('bunker-autocannon.cfg','bunker-family.cfg'):shutil.copy2(ROOT/'tech-priests_src/locale/en'/file,mod/'locale/en'/file)
shutil.copy2(ROOT/'docs/prototypes/twin-cannon-readme.md',mod/'README.md')
(mod/'info.json').write_text(json.dumps({'name':NAME,'version':VERSION,'factorio_version':'2.1','title':'Tech Priests — Bunker Family Prototypes',
    'author':'Christopher Vardeman','dependencies':['base >= 2.1.0','? tech-priests'],
    'description':'Six playable original fortified weapons, including the alternating twin siege cannon. Native ammunition and team-coloured stanchions.'},indent=2)+'\n')
(mod/'control.lua').write_text("require('scripts.bunker_cannon_integration').install()\n")
(mod/'data.lua').write_text("require('prototypes.bunker_family').register('"+NAME+"')\nrequire('prototypes.bunker_bullet_weapons').register('"+NAME+"')\nrequire('prototypes.bunker_twin_cannon').register('"+NAME+"')\n")
(mod/'data-final-fixes.lua').write_text("require('prototypes.bunker_autocannon').finalize()\nrequire('prototypes.bunker_family').finalize_grenades()\nrequire('prototypes.bunker_bullet_weapons').finalize()\nrequire('prototypes.bunker_twin_cannon').finalize()\n")
for file in mod.rglob('*'):
    assert file.suffix not in ('.log','.blend','.py','.pyc'),'Development artifact in playable package'
if a.stage_only:print(json.dumps({'stage':str(mod)}));raise SystemExit(0)
archive=out/(NAME+'_'+VERSION+'.zip')
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=1) as z:
    for file in sorted(mod.rglob('*')):
        if file.is_file():z.write(file,file.relative_to(out))
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    assert all(n.startswith(NAME+'_'+VERSION+'/') for n in z.namelist())
print(json.dumps({'archive':str(archive),'sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),'bytes':archive.stat().st_size}))
