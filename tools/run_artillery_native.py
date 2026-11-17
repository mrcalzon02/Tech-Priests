"""Test the real-art native artillery prototype in an isolated mod directory."""
import argparse,json,shutil,subprocess,time
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1];p=argparse.ArgumentParser();p.add_argument('--graphics',action='store_true');p.add_argument('--gui-test',action='store_true');p.add_argument('--reload',action='store_true');p.add_argument('--server-save',action='store_true');args=p.parse_args()
out=ROOT/'build/artillery-native/physics';mods=out/'mods';mod=mods/'tech-priests-artillery-probe'
for folder in ('prototypes','scripts','graphics/entity'):(mod/folder).mkdir(parents=True,exist_ok=True)
(mod/'locale/en').mkdir(parents=True,exist_ok=True)
shutil.copy2(ROOT/'tech-priests_src/locale/en/bunker-artillery.cfg',mod/'locale/en/bunker-artillery.cfg')
for name in ('bunker_autocannon.lua','bunker_autocannon_graphics.lua','bunker_artillery.lua'):shutil.copy2(ROOT/'tech-priests_src/prototypes'/name,mod/'prototypes'/name)
for name in ('artillery_barrage_controller.lua',):shutil.copy2(ROOT/'tech-priests_src/scripts'/name,mod/'scripts'/name)
for name in ('artillery_barrage_geometry.lua','artillery_barrage_visuals.lua'):shutil.copy2(ROOT/'build/artillery-native/animated-art-v19'/name,mod/'scripts'/name)
shutil.copytree(ROOT/'tech-priests_src/graphics/entity/bunker-autocannon',mod/'graphics/entity/bunker-autocannon',dirs_exist_ok=True)
shutil.copytree(ROOT/'build/artillery-native/animated-art-v19',mod/'graphics/entity/bunker-artillery',dirs_exist_ok=True)
fixture=ROOT/'tests/scenarios/artillery-native';shutil.copy2(fixture/'data.lua',mod/'data.lua')
(mod/'data-final-fixes.lua').write_text("require('prototypes.bunker_autocannon').finalize()\n")
(mod/'control.lua').write_text('local GRAPHICAL='+('true' if args.graphics or args.gui_test else 'false')+'\n'+(fixture/'control.lua').read_text())
(mod/'info.json').write_text(json.dumps({'name':'tech-priests-artillery-probe','version':'0.0.1','factorio_version':'2.1','title':'Real bunker artillery mechanics pilot','author':'Tech Priests','dependencies':['base >= 2.1.0']}))
(mods/'mod-list.json').write_text(json.dumps({'mods':[{'name':'base','enabled':True},{'name':'tech-priests-artillery-probe','enabled':True}]}))
user=out/'user-data';user.mkdir(exist_ok=True);exe=Path('C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/Factorio.exe')
config=out/'config.ini';config.write_text('[path]\nread-data='+str(exe.parents[2]/'data')+'\nwrite-data='+str(user)+'\n[other]\ncheck-updates=false\n[graphics]\nfull-screen=false\nmax-threads=4\n')
(out/'steam_appid.txt').write_text('427520');base=[str(exe),'--config',str(config),'--mod-directory',str(mods),'--disable-migration-window']
proof=user/'script-output/artillery-native'/('graphical.json' if args.graphics or args.gui_test else 'result.json');proof.unlink(missing_ok=True)
save=user/'saves/_autosave-artillery-native-mid-reload.zip' if args.reload else out/'native-artillery.zip'
steps=[] if args.reload else [('create',['--create',str(save)])]
if args.server_save:
    assert not args.reload and not args.graphics
    with (out/'create.log').open('w') as log:subprocess.run(base+steps[0][1],cwd=out,stdout=log,stderr=subprocess.STDOUT,check=True)
    checkpoint=user/'saves/_autosave-artillery-native-mid-reload.zip';checkpoint.unlink(missing_ok=True)
    settings=out/'server-settings.json';settings.write_text(json.dumps({'name':'Isolated artillery save test','description':'Local acceptance only',
        'visibility':{'public':False,'lan':False},'auto_pause':False,'require_user_verification':False}))
    with (out/'save-server.log').open('w') as log:
        proc=subprocess.Popen(base+['--start-server',str(save),'--server-settings',str(settings),'--bind','127.0.0.1','--port','34298'],cwd=out,stdout=log,stderr=subprocess.STDOUT)
        try:
            deadline=time.monotonic()+45
            while time.monotonic()<deadline and proc.poll() is None:
                if checkpoint.exists() and 'Saving finished' in (out/'save-server.log').read_text(errors='replace'):break
                time.sleep(.2)
            assert checkpoint.exists(),'Native artillery save was not written; inspect save-server.log'
        finally:
            if proc.poll() is None:proc.terminate()
            proc.wait(timeout=10)
    print('ARTILLERY_NATIVE_MID_RELOAD_SAVED',checkpoint);raise SystemExit(0)
steps.append(('graphics' if args.graphics else ('reload' if args.reload else 'physics'),(['--load-game',str(save),'--window-size','1600x1000'] if args.graphics else ['--test-save',str(save),'--test-ticks','3610'] if args.gui_test else ['--benchmark',str(save),'--benchmark-ticks','3610','--benchmark-runs','1'])))
for phase,command in steps:
    with (out/(phase+'.log')).open('w') as log:
        if not args.graphics:r=subprocess.run(base+command,cwd=out,stdout=log,stderr=subprocess.STDOUT)
        else:
            r=subprocess.Popen(base+command,cwd=out,stdout=log,stderr=subprocess.STDOUT)
            deadline=time.monotonic()+150
            while r.poll() is None and not proof.exists() and time.monotonic()<deadline:
                if 'non-recoverable error' in (out/(phase+'.log')).read_text(errors='replace'):break
                time.sleep(.2)
            if r.poll() is None:r.terminate();r.wait(timeout=10)
            if proof.exists():r.returncode=0
    if r.returncode:raise RuntimeError((out/(phase+'.log')).read_text(errors='replace')[-6500:])
r=json.loads(proof.read_text());assert r['status']=='PASS' and r['actual_art'] and r['recipe_outputs']==1 and r['visual_checks']>1000 and len(r['visual_phases'])==5
if args.reload:assert r['resume']['tick']==r['resume']['saved_tick']+1 and r['resume']['owners']>0
shutil.copy2(proof,proof.parent/('save-reload.json' if args.reload else ('graphics-verified.json' if args.graphics else 'fresh.json')))
print('ARTILLERY_NATIVE_PILOT_PASS',len(r['sites']))
