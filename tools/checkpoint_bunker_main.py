"""Create a reviewed main-parent checkpoint without disturbing the active checkout.

The alternate index starts at current remote main and overlays only the verified
bunker production files, authoring sources, tests and evidence. Never force-push.
"""
import argparse, hashlib, json, os, shutil, subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/twin-cannon/main-integration'

def git(*args, env=None):
    return subprocess.check_output(['git', *args], cwd=ROOT, env=env)

def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding='utf-8', errors='surrogateescape')

def main():
    p=argparse.ArgumentParser(); p.add_argument('--base', required=True); a=p.parse_args()
    overlay=json.loads((OUT/'production-overlay.json').read_text())
    if a.base != overlay['base_commit']:
        assert not git('diff','--name-only',overlay['base_commit'],a.base,'--','tech-priests_src').strip(), 'Re-stage and verify changed production source'
    paths={Path('tech-priests_src')/name for name in overlay['production_files']}
    for name, digest in overlay['production_files'].items():
        assert hashlib.sha256((ROOT/'tech-priests_src'/name).read_bytes()).hexdigest()==digest, name
    proof=OUT/'user-data/script-output/twin-cannon-main'
    for name in ('result.json','result-graphical.json','save-reload.json'):
        r=json.loads((proof/name).read_text()); assert r['status']=='PASS' and r['main_mod']=='tech-priests'
        assert r['event_ownership']['preserved'] and r['event_ownership']['preexisting_routes']==180
    evidence=ROOT/'docs/prototypes/twin-cannon-main-evidence';evidence.mkdir(exist_ok=True)
    for name in ('result.json','result-graphical.json','save-reload.json','facing-1.png','facing-5.png','settled-cannon.png'):
        shutil.copy2(proof/name,evidence/name)
    shutil.copy2(OUT/'production-overlay.json',evidence/'production-overlay.json')
    # Model and renders contain no owner's private sketch or reference boards.
    source=ROOT/'build/twin-cannon/flexible-aerials-v3/twin-cannon'
    art=ROOT/'art/bunker-twin-cannon';art.mkdir(exist_ok=True)
    for name in ('twin-cannon.blend','twin-cannon.glb','quarter.png','rear.png','import-quarter.png','import-clay.png',
                 'structure-and-motion-check.json','aerial-geometry-check.json','independent-export-inspection.json'):
        shutil.copy2(source/name,art/name)
    write(art/'README.md', '''# Fortified twin siege cannon

Editable Blender 5.0.1 source with packed textures and independently inspected
static GLB export. The concrete foundation is a separate fixed entity layer.
Both guns have independent deep recoil and slow return; radio whips flex.
Production sprites live in tech-priests_src/graphics/entity/bunker-twin-cannon.
The source and export hashes are recorded in the adjacent inspection reports.
Authoring helpers are in tools/art. Runtime and integration evidence is in
docs/prototypes/twin-cannon-main-evidence. No private reference is included.
''')
    # Merge shared documents from remote main, retaining its unrelated updates.
    history=Path('docs/DEVELOPMENT_HISTORY.md')
    current=(ROOT/history).read_text(encoding='utf-8', errors='surrogateescape')
    pilot=current[current.index('## 2026-11-14 — Bunker stanchion'):].split('## 2026-11-15 — Six bunker weapons')[0].rstrip()+'\n'
    base=git('show',a.base+':'+history.as_posix()).decode('utf-8', errors='surrogateescape')
    if '## 2026-11-14 — Bunker stanchion' not in base:base+='\n\n'+pilot
    completion='''

## 2026-11-15 — Six bunker weapons integrated into Tech Priests main

Registered the lobber, energy dish, Chicago piano, twin minigun and completed
twin siege cannon alongside the existing autocannon in the actual main mod.
Finalization runs before the existing recipe-schema sanitizer. Weapon callbacks
use the canonical runtime event registry; all 180 pre-existing event routes are
preserved. Added the original cannon source/GLB and all runtime atlases, native
preview cores, icons, recipe/technology and shared force-coloured stanchions.

The full 0.1.681 Tech Priests source, based on ab7e878, passed Factorio 2.1.24
headless, graphical and separate-process mid-fire reload tests with official
Space Age/Quality/Elevated Rails/Recycler enabled: 32 cannon sites, four native
shell types, all 64 headings, research, ammo exhaustion and all five older
weapon regressions. Final native flash lead is 0.16 tile with facing-dependent
depth; projectile origins remain unchanged. Main evidence is retained under
docs/prototypes/twin-cannon-main-evidence. The earlier two-heading pilot entry
is historical and superseded by these full-direction results.

This is source integration, not a new full-mod release/version bump or a claim
about unrelated priest logistics gates. Rocket, artillery, radium, grav, plasma
and flamer weapon families remain unbuilt. Publication is verified separately
against the resulting GitHub main commit.
'''
    write(ROOT/history,base+completion);paths.add(history)
    goals=Path('tech-priests_src/docs/CURRENT_TESTING_GOALS.md')
    text=git('show',a.base+':'+goals.as_posix()).decode('utf-8', errors='surrogateescape')
    write(ROOT/goals,text+'''\n\n## 2026-11-15 — Owner-authorized bunker weapon integration

PASS in the real Tech Priests 0.1.681 mod on Factorio 2.1.24 with official
Space Age mods: 32 cannon setups, four existing ammunition types, 64 headings,
five legacy weapons, graphics and separate-process mid-fire save/reload.
All 180 existing event routes survive canonical-registry installation.
Evidence: docs/prototypes/twin-cannon-main-evidence. These focused combat
checks do not close or alter the unrelated logistics/recovery goals above.
Next weapon design backlog: rocket, artillery, radium, grav, plasma and flamer.
''');paths.add(goals)
    write(ROOT/'docs/prototypes/bunker-runtime-map.md','''# Main-mod bunker runtime ownership

```mermaid
flowchart TD
  Data[data.lua] --> Family[bunker_family.register]
  Data --> Bullets[bunker_bullet_weapons.register]
  Data --> Cannon[bunker_twin_cannon.register]
  Final[data-final-fixes.lua] --> Finalizers[Grenade packs / bullets / cannon finalizers]
  Finalizers --> Schema[Existing recipe schema sanitizer]
  Control[control.lua] --> Install[bunker_cannon_integration.install_main]
  Install --> Registry[Existing canonical runtime_event_registry]
  Registry --> Init[Init/configuration: discover existing weapons]
  Registry --> Tick[Tick: family motion and cannon motion]
  Registry --> Shot[Native trigger effects: shot / muzzle callbacks]
  Registry --> Built[Build / revive / clone: register weapon]
  Registry --> Hit[Damage: bullet shot observer]
  Tick --> Render[Separate cap / aerials / shadows; fixed foundation]
  Shot --> Render
  Native[Native turret targeting and ammunition] --> Projectile[Original cannon projectile / native damage]
  Shot --> Muzzle[Move original projectile to alternating active muzzle]
  Muzzle --> Projectile
```

The weapon owner adds named routes; it does not install raw script handlers
over priest services. An installation assertion verifies every previous route
still exists. Full-mod fixtures observed 180 preserved routes. Rendering is
shot-driven; ammunition and damage remain owned by the native engine.
''')
    progress=ROOT/'docs/prototypes/twin-cannon-progress.md'
    write(progress,progress.read_text(encoding='utf-8').split('## Final main integration')[0].rstrip()+'''\n\n## Final main integration — 2026-11-15

All 64 directions are packed, with separate motion, occluded aerials, static
cap shadows and native preview cores. Main-mod headless, graphical and mid-fire
reload checks pass. The five earlier weapons are integrated and regressions
pass. See twin-cannon-main-evidence and bunker-runtime-map.md. The remaining
instructions and pending states above are historical development checkpoints.
Source version remains 0.1.681; this integration does not issue a full release.
''')
    readme=ROOT/'docs/prototypes/twin-cannon-readme.md'
    write(readme,'''# Twin siege cannon in Tech Priests

The six bunker weapons are now registered in the main Tech Priests source:
autocannon, lobber, energy dish, Chicago piano, twin minigun and twin cannon.
Use the main mod alone for these weapons. The separately verified 0.4.0
standalone prototype remains a development comparison package.

Main-mod verification: twin-cannon-main-evidence. Runtime ownership:
bunker-runtime-map.md. Editable cannon source: art/bunker-twin-cannon.
No full-mod release/version bump is included in this source checkpoint.

'''+('# Standalone prototype 0.4.0'+readme.read_text(encoding='utf-8').split('# Standalone prototype 0.4.0',1)[1] if '# Standalone prototype 0.4.0' in readme.read_text(encoding='utf-8') else readme.read_text(encoding='utf-8').replace('# Bunker family prototypes 0.4.0','# Standalone prototype 0.4.0',1)))
    # Cannon is verified locally; publication status is the separate Git receipt.
    backlog=ROOT/'docs/prototypes/bunker-weapon-backlog.md'
    lines=backlog.read_text(encoding='utf-8').splitlines()
    lines=['- [x] Twin siege cannon - full main-mod runtime, graphics and save/reload verified'
           if line.startswith(('- [ ] Twin siege cannon','- [x] Twin siege cannon')) else line for line in lines]
    write(backlog,'\n'.join(lines)+'\n')
    for folder in ('art/bunker-twin-cannon','docs/prototypes/twin-cannon-main-evidence'):
        paths.update(x.relative_to(ROOT) for x in (ROOT/folder).rglob('*') if x.is_file())
    for pattern in ('twin-cannon-*.md','bullet-turret*.json','bullet-turret*.md','bunker-*.json','bunker-weapon-backlog.md','bunker-runtime-map.md'):
        paths.update(x.relative_to(ROOT) for x in (ROOT/'docs/prototypes').glob(pattern))
    for folder in ('bullet-turrets','bunker-family','bunker-team-colour','twin-cannon-acceptance','twin-cannon-animated-pilot','twin-cannon-physics','twin-cannon-role'):
        paths.update(x.relative_to(ROOT) for x in (ROOT/'tests/scenarios'/folder).rglob('*') if x.is_file())
    for pattern in ('*twin_cannon*.py','*bullet_turret*.py','*bunker_family*.py','*bunker_team*.py','*dish*.py','build_lobber_native_core.py','checkpoint_bunker_main.py'):
        for folder in ('tools','tools/art'):
            paths.update(x.relative_to(ROOT) for x in (ROOT/folder).glob(pattern))
    paths.add(Path('tools/art/render_bunker_stanchion_coverage.py'))
    for path in paths:
        assert '.codex-attachments' not in str(path) and (ROOT/path).is_file(),path
        assert (ROOT/path).stat().st_size<100*1024*1024,path
    env=os.environ.copy();env['GIT_INDEX_FILE']=str(OUT/'publication.index')
    git('read-tree',a.base,env=env)
    names=sorted(x.as_posix() for x in paths)
    subprocess.run(['git','--literal-pathspecs','add','--sparse','--pathspec-from-file=-','--pathspec-file-nul'],cwd=ROOT,env=env,
                   input=b'\0'.join(x.encode() for x in names)+b'\0',check=True)
    git('diff','--cached','--check',env=env)
    tree=git('write-tree',env=env).decode().strip()
    commit=subprocess.check_output(['git','commit-tree',tree,'-p',a.base],cwd=ROOT,
        input=b'feat: integrate six fortified bunker weapons and completed twin siege cannon\n\nVerified native main-mod combat, graphics and mid-fire reload; preserve canonical event routes.\n').decode().strip()
    git('update-ref','refs/checkpoints/bunker-main-integration',commit)
    report={'status':'LOCAL_CHECKPOINT','commit':commit,'base':a.base,'tree':tree,'paths':names,
            'bytes':sum((ROOT/x).stat().st_size for x in paths)}
    write(OUT/'publication.json',json.dumps(report,indent=2)+'\n')
    print('CHECKPOINT_READY',commit,len(paths),report['bytes'])

if __name__=='__main__':main()
