"""Overlay verified bunker assets onto an isolated exact GitHub-main mod tree."""
import argparse,json,subprocess,tarfile,shutil,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--base',required=True);p.add_argument('--refresh-base',action='store_true');a=p.parse_args()
out=ROOT/'build/twin-cannon/main-integration';out.mkdir(parents=True,exist_ok=True)
base_archive=out/'main-source.tar'
archive_receipt=out/'main-source-base.json'
source_tree=subprocess.check_output(['git','rev-parse',a.base+':tech-priests_src'],cwd=ROOT,text=True).strip()
cached=json.loads(archive_receipt.read_text())if archive_receipt.exists()else {}
if a.refresh_base or not base_archive.exists()or cached.get('source_tree')!=source_tree:
    pending=out/'main-source.next.tar'
    with pending.open('wb') as stream:subprocess.run(['git','archive','--format=tar',a.base,'tech-priests_src'],cwd=ROOT,stdout=stream,check=True)
    pending.replace(base_archive)
    archive_receipt.write_text(json.dumps({'base_commit':a.base,'source_tree':source_tree},indent=2)+'\n')
mod=out/'mods/tech-priests';mod.mkdir(parents=True,exist_ok=True)
with tarfile.open(base_archive) as tar:
    for member in tar:
        if not member.isfile():continue
        relative=Path(member.name).relative_to('tech-priests_src');target=mod/relative
        assert target.resolve().is_relative_to(mod.resolve())
        target.parent.mkdir(parents=True,exist_ok=True)
        with tar.extractfile(member) as source,target.open('wb') as dest:shutil.copyfileobj(source,dest)
paths=[Path(p) for p in ('data.lua','data-final-fixes.lua','control.lua','info.json')]
for folder,pattern in [('prototypes','bunker*.lua'),('scripts','bunker*.lua'),('scripts','bullet_turret_controller.lua'),('scripts','twin_cannon_controller.lua'),('scripts','rocket_salvo*.lua'),('scripts','artillery_barrage*.lua'),('locale/en','bunker*.cfg')]:
    paths.extend(path.relative_to(ROOT/'tech-priests_src') for path in (ROOT/'tech-priests_src'/folder).glob(pattern))
for suffix in ('autocannon','lobber','energy-dish','chicago-piano','twin-minigun','twin-cannon','rocket-salvo','artillery'):
    paths.extend(path.relative_to(ROOT/'tech-priests_src') for path in (ROOT/'tech-priests_src/graphics/entity'/('bunker-'+suffix)).rglob('*') if path.is_file())
if (ROOT/'tech-priests_src/prototypes/martian_infrastructure.lua').exists():
    for name in ('scripts/martian_infrastructure.lua','prototypes/martian_infrastructure.lua'):
        paths.append(Path(name))
    paths.extend(path.relative_to(ROOT/'tech-priests_src')for path in (ROOT/'tech-priests_src/graphics/entity/martian-infrastructure').rglob('*')if path.is_file())
for relative in paths:
    target=mod/relative;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/'tech-priests_src'/relative,target)
report={'status':'MAIN_SOURCE_STAGED','base_commit':a.base,'mod_name':'tech-priests','version':json.loads((mod/'info.json').read_text())['version'],
        'production_files':{str(relative).replace('\\','/'):hashlib.sha256((mod/relative).read_bytes()).hexdigest() for relative in sorted(set(paths))}}
(out/'production-overlay.json').write_text(json.dumps(report,indent=2)+'\n')
print('MAIN_MOD_STAGED',len(report['production_files']))
