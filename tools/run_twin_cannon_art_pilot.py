"""Exercise actual captured mechanism/aerial graphics in a disposable mod."""
import argparse,json,shutil,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--graphical',action='store_true');p.add_argument('--reload-save',type=Path);a=p.parse_args()
assert not(a.graphical and a.reload_save)
out=ROOT/'build/twin-cannon/animated-runtime-pilot-v1';mods=out/'mods';name='tech-priests-twin-cannon-pilot';mod=mods/(name+'_0.0.1')
for folder in ('prototypes','scripts','graphics/entity','scenarios/twin-cannon-animated-pilot'):(mod/folder).mkdir(parents=True,exist_ok=True)
for file in ('bunker_autocannon.lua','bunker_autocannon_graphics.lua','bunker_twin_cannon.lua'):shutil.copy2(ROOT/'tech-priests_src/prototypes'/file,mod/'prototypes'/file)
(mod/'locale/en').mkdir(parents=True,exist_ok=True)
for file in ('bunker-family.cfg','bunker-autocannon.cfg'):shutil.copy2(ROOT/'tech-priests_src/locale/en'/file,mod/'locale/en'/file)
shutil.copy2(ROOT/'tech-priests_src/scripts/twin_cannon_controller.lua',mod/'scripts/twin_cannon_controller.lua')
shutil.copytree(ROOT/'tech-priests_src/graphics/entity/bunker-autocannon',mod/'graphics/entity/bunker-autocannon',dirs_exist_ok=True)
art=mod/'graphics/entity/bunker-twin-cannon';art.mkdir(exist_ok=True)
for d in range(64):shutil.copy2(ROOT/f'build/twin-cannon/runtime-capture-v2/d{d:02}-preview.png',art/f'native-{d:02}.png')
shutil.copytree(ROOT/'build/twin-cannon/runtime-pilot-art-v1',art,dirs_exist_ok=True)
fixture=ROOT/'tests/scenarios/twin-cannon-animated-pilot';shutil.copy2(fixture/'data.lua',mod/'data.lua')
(mod/'control.lua').write_text('local GRAPHICAL='+('true' if a.graphical else 'false')+'\n'+(fixture/'control.lua').read_text())
(mod/'scenarios/twin-cannon-animated-pilot/control.lua').write_text('-- Disposable actual-art fixture.\n')
(mod/'info.json').write_text(json.dumps({'name':name,'version':'0.0.1','factorio_version':'2.1','title':'Twin cannon real animation pilot','author':'Tech Priests','dependencies':['base >= 2.1.0']}))
(mods/'mod-list.json').write_text(json.dumps({'mods':[{'name':'base','enabled':True},{'name':name,'enabled':True}]}))
user=out/'user-data';user.mkdir(exist_ok=True);exe=Path('C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/Factorio.exe')
config=out/'config.ini';config.write_text('[path]\nread-data='+str(exe.parents[2]/'data')+'\nwrite-data='+str(user)+'\n[other]\ncheck-updates=false\n[graphics]\nmax-threads=4\nfull-screen=false\n')
(out/'steam_appid.txt').write_text('427520');base=[str(exe),'--config',str(config),'--mod-directory',str(mods),'--disable-migration-window']
if a.graphical:
    with (out/'graphical.log').open('w') as log:proc=subprocess.Popen(base+['--load-scenario',name+'/twin-cannon-animated-pilot','--window-size','1280x800'],cwd=out,stdout=log,stderr=subprocess.STDOUT,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
    (out/'graphical-process.json').write_text(json.dumps({'pid':proc.pid},indent=2));print('GRAPHICAL_PID',proc.pid)
else:
    save=a.reload_save.resolve() if a.reload_save else out/'proof.zip'
    steps=[] if a.reload_save else [('create',['--create',str(save)])]
    steps.append(('reload' if a.reload_save else 'run',['--benchmark',str(save),'--benchmark-ticks','410','--benchmark-runs','1']))
    for label,args in steps:
        with (out/(label+'.log')).open('w') as log:result=subprocess.run(base+args,cwd=out,stdout=log,stderr=subprocess.STDOUT)
        if result.returncode:raise RuntimeError((out/(label+'.log')).read_text(errors='replace')[-5000:])
    report=json.loads((user/'script-output/twin-cannon-animated-pilot/result.json').read_text());assert report['status']=='PASS'
    if a.reload_save:
        resume=report['resume'];assert 90<=resume['saved_tick']<=110 and resume['saved_shots']>0
        assert sum(s['shots'] for s in report['sites'])>resume['saved_shots'],'Must continue actual firing after reload'
        (user/'script-output/twin-cannon-animated-pilot/save-reload.json').write_text(json.dumps(report,indent=2)+'\n')
    print('ACTUAL_CANNON_ANIMATION_PILOT_PASS',len(report['sites']))
