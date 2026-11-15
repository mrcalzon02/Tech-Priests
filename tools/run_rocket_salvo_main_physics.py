"""Exercise rocket physics through the real main-mod event owner.

Use normal production registration and final moving-shadow assets in an
isolated staged full mod. No user mod installation is changed by this fixture.
"""
import argparse,json,subprocess,tarfile,shutil,time
from pathlib import Path
parser=argparse.ArgumentParser();parser.add_argument('--reload',action='store_true');parser.add_argument('--server-save',action='store_true');parser.add_argument('--graphics',action='store_true');args=parser.parse_args()
ROOT=Path(__file__).resolve().parents[1];stage=ROOT/'build/twin-cannon/main-integration'
out=ROOT/'build/rocket-salvo/main-physics';out.mkdir(parents=True,exist_ok=True)
mods=stage/'mods';mod=mods/'tech-priests'
assert (stage/'production-overlay.json').is_file(),'Run stage_twin_cannon_main.py first'
for relative in ('scripts/bunker_cannon_integration.lua','scripts/rocket_salvo_controller.lua','scripts/rocket_salvo_geometry.lua','prototypes/bunker_rocket_salvo.lua'):
    shutil.copy2(ROOT/'tech-priests_src'/relative,mod/relative)
with tarfile.open(stage/'main-source.tar') as tar:
    original_updates=tar.extractfile('tech-priests_src/data-updates.lua').read().decode()
(mod/'data.lua').write_text((ROOT/'tech-priests_src/data.lua').read_text())
art=ROOT/'tech-priests_src/graphics/entity/bunker-rocket-salvo'
art_manifest=json.loads((art/'assets.json').read_text())
assert art_manifest['status']=='PACKED_ALL_DIRECTIONS' and len(art_manifest['directions'])==64
shutil.copytree(art,mod/'graphics/entity/bunker-rocket-salvo',dirs_exist_ok=True)
# Preserve concurrent local infrastructure integration when it is present;
# the rocket checkpoint also works independently of that optional local slice.
if 'require("prototypes.martian_infrastructure")' in (mod/'data.lua').read_text():
    for relative in ('scripts/martian_infrastructure.lua','prototypes/martian_infrastructure.lua'):
        shutil.copy2(ROOT/'tech-priests_src'/relative,mod/relative)
    shutil.copytree(ROOT/'tech-priests_src/graphics/entity/martian-infrastructure',mod/'graphics/entity/martian-infrastructure',dirs_exist_ok=True)
fixture_data=(ROOT/'tests/scenarios/rocket-salvo-physics/data.lua').read_text().replace('tech-priests-rocket-probe','tech-priests')
fixture_data=fixture_data[fixture_data.index("local actual=data.raw"):]
(mod/'data-updates.lua').write_text(original_updates+'\n-- Isolated rocket combat targets.\n'+fixture_data)
(mod/'data-final-fixes.lua').write_text((ROOT/'tech-priests_src/data-final-fixes.lua').read_text())
fixture=(ROOT/'tests/scenarios/rocket-salvo-physics/control.lua').read_text()
prefix="""local registry=require('scripts.core.runtime_event_registry')
local integration=require('scripts.bunker_cannon_integration')
local function on_init(fn)registry.on_init(fn,{owner='rocket_main_acceptance',route='setup',priority=1000000})end
local function event(id,fn)registry.on_event(id,fn,nil,{owner='rocket_main_acceptance',route=tostring(id),priority=1000000})end
"""
fixture=fixture.replace('script.on_init(', 'on_init(').replace('script.on_event(', 'event(')
fixture=fixture.replace('  rocket.effect(e)\n','')
assert '  rocket.tick(e)\n' in fixture
fixture=fixture.replace('  rocket.tick(e)\n','')
marker='  local site=before and t.origins[key(projectile.surface,e.tick,before)]\n'
assert marker in fixture
fixture=fixture.replace(marker,marker+"""  -- The canonical owner has already moved our projectile. Correlate its
  -- actual launch with the recorded original origin, rather than moving twice.
  if before and not site then
    for _,candidate in ipairs(t.sites) do
      local gun=candidate.gun
      local entry=gun.valid and storage.rocket_salvo.guns[gun.unit_number]
      local launch=entry and entry.last_launch
      if launch and launch.tick==e.tick and math.abs(before.x-launch.actual.x)<.004 and math.abs(before.y-launch.actual.y)<.004 then
        site=candidate;before=launch.before;break
      end
    end
  end
""")
fixture=fixture.replace('if rocket.muzzle_created(e) then',"if e.source and e.source.valid and e.source.name==NAME and e.entity and e.entity.valid and e.entity.name=='explosion-hit' then")
fixture=fixture.replace("  storage.probe={sites=", "  check(script.mod_name=='tech-priests','must execute in actual main mod')\n  check(integration.main_ownership and integration.main_ownership.preserved,'existing event owners preserved')\n  storage.probe={sites=",1)
fixture=fixture.replace("{status='PASS',\n      scope=", "{status='PASS',main_mod=script.mod_name,event_ownership=integration.main_ownership,\n      scope=",1)
fixture=fixture.replace('rocket-salvo-physics/','rocket-salvo-main/')
(mod/'scripts/rocket_salvo_main_fixture.lua').write_text('local GRAPHICAL='+('true' if args.graphics else 'false')+'\n'+prefix+'\n'+fixture)
(mod/'control.lua').write_text((ROOT/'tech-priests_src/control.lua').read_text()+"\n-- Isolated acceptance only; not published.\nrequire('scripts.rocket_salvo_main_fixture')\n")
user=out/'user-data';user.mkdir(exist_ok=True);exe=Path('C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/Factorio.exe')
config=out/'config.ini';config.write_text('[path]\nread-data='+str(exe.parents[2]/'data')+'\nwrite-data='+str(user)+'\n[other]\ncheck-updates=false\n')
(out/'steam_appid.txt').write_text('427520');base=[str(exe),'--config',str(config),'--mod-directory',str(mods),'--disable-migration-window']
proof=user/'script-output/rocket-salvo-main'/('result-graphical.json' if args.graphics else 'result.json');proof.unlink(missing_ok=True)
save=user/'saves/_autosave-rocket-salvo-actual-art-mid-reload.zip' if args.reload else out/'main-rocket.zip'
steps=[] if args.reload else [('create',['--create',str(save)])]
if args.server_save:
    assert not args.reload
    with (out/'create.log').open('w') as log:
        subprocess.run(base+steps[0][1],cwd=out,stdout=log,stderr=subprocess.STDOUT,check=True)
    checkpoint=user/'saves/_autosave-rocket-salvo-actual-art-mid-reload.zip'
    checkpoint.unlink(missing_ok=True)
    settings=out/'server-settings.json'
    settings.write_text(json.dumps({'name':'Isolated rocket save test','description':'Local acceptance only',
        'visibility':{'public':False,'lan':False},'auto_pause':False,'require_user_verification':False}))
    with (out/'save-server.log').open('w') as log:
        proc=subprocess.Popen(base+['--start-server',str(save),'--server-settings',str(settings),'--bind','127.0.0.1','--port','34297'],cwd=out,stdout=log,stderr=subprocess.STDOUT)
        try:
            deadline=time.monotonic()+45
            while time.monotonic()<deadline and proc.poll() is None:
                if checkpoint.exists() and 'Saving finished' in (out/'save-server.log').read_text(errors='replace'):break
                time.sleep(.2)
            assert checkpoint.exists(),'Headless server did not write mid-reload save; inspect save-server.log'
        finally:
            if proc.poll() is None:proc.terminate()
            proc.wait(timeout=10)
    print('ROCKET_MAIN_MID_RELOAD_SAVED',checkpoint)
    raise SystemExit(0)
steps.append(('reload' if args.reload else 'physics',['--benchmark-graphics' if args.graphics else '--benchmark',str(save),'--benchmark-ticks','1710','--benchmark-runs','1','--benchmark-ignore-paused']))
for tag,command in steps:
    with (out/(tag+'.log')).open('w') as log:r=subprocess.run(base+command,cwd=out,stdout=log,stderr=subprocess.STDOUT)
    if r.returncode:raise RuntimeError((out/(tag+'.log')).read_text(errors='replace')[-6500:])
log=(out/('reload.log' if args.reload else 'physics.log')).read_text(errors='replace')
assert 'isolated handler failure owner=rocket_main_acceptance' not in log,'Main registry isolated a failed fixture'
assert 'isolated handler failure owner=bunker_weapons' not in log,'Main registry isolated a failed weapon callback'
r=json.loads(proof.read_text());assert r['recipe_outputs']==1
assert r['status']=='PASS' and r['main_mod']=='tech-priests' and r['event_ownership']['preserved']
if args.reload:
    assert 320<=r['resume']['saved_tick']<=350 and r['resume']['tick']==r['resume']['saved_tick']+1
shutil.copy2(proof,proof.parent/('graphical.json' if args.graphics else ('save-reload.json' if args.reload else 'fresh.json')))
print('ROCKET_MAIN_PHYSICS_PASS',len(r['sites']),r['headings'],r['event_ownership'])
