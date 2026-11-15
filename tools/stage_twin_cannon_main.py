"""Overlay verified bunker assets onto an isolated exact GitHub-main mod tree."""
import argparse,json,subprocess,tarfile,shutil,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--base',required=True);p.add_argument('--refresh-base',action='store_true');a=p.parse_args()
out=ROOT/'build/twin-cannon/main-integration';out.mkdir(parents=True,exist_ok=True)
base_archive=out/'main-source.tar'
if a.refresh_base or not base_archive.exists():
    with base_archive.open('wb') as stream:subprocess.run(['git','archive','--format=tar',a.base,'tech-priests_src'],cwd=ROOT,stdout=stream,check=True)
mod=out/'mods/tech-priests';mod.mkdir(parents=True,exist_ok=True)
with tarfile.open(base_archive) as tar:
    for member in tar:
        if not member.isfile():continue
        relative=Path(member.name).relative_to('tech-priests_src');target=mod/relative
        assert target.resolve().is_relative_to(mod.resolve())
        target.parent.mkdir(parents=True,exist_ok=True)
        with tar.extractfile(member) as source,target.open('wb') as dest:shutil.copyfileobj(source,dest)
paths=[Path(p) for p in ('data.lua','data-final-fixes.lua','control.lua')]
for folder,pattern in [('prototypes','bunker*.lua'),('scripts','bunker*.lua'),('scripts','bullet_turret_controller.lua'),('scripts','twin_cannon_controller.lua'),('scripts','rocket_salvo*.lua'),('locale/en','bunker*.cfg')]:
    paths.extend(path.relative_to(ROOT/'tech-priests_src') for path in (ROOT/'tech-priests_src'/folder).glob(pattern))
for suffix in ('autocannon','lobber','energy-dish','chicago-piano','twin-minigun','twin-cannon'):
    paths.extend(path.relative_to(ROOT/'tech-priests_src') for path in (ROOT/'tech-priests_src/graphics/entity'/('bunker-'+suffix)).rglob('*') if path.is_file())
for relative in paths:
    target=mod/relative;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/'tech-priests_src'/relative,target)
report={'status':'MAIN_SOURCE_STAGED','base_commit':a.base,'mod_name':'tech-priests','version':json.loads((mod/'info.json').read_text())['version'],
        'production_files':{str(relative).replace('\\','/'):hashlib.sha256((mod/relative).read_bytes()).hexdigest() for relative in sorted(set(paths))}}
(out/'production-overlay.json').write_text(json.dumps(report,indent=2)+'\n')
print('MAIN_MOD_STAGED',len(report['production_files']))
