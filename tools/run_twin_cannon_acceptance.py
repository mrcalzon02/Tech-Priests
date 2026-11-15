"""Exercise the shipping six-weapon integration with full actual cannon art."""
import argparse,json,subprocess,shutil,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--graphical',action='store_true');p.add_argument('--reload-save',type=Path);a=p.parse_args()
assert not(a.graphical and a.reload_save)
out=ROOT/'build/twin-cannon/acceptance-v1';mods=out/'mods';out.mkdir(parents=True,exist_ok=True)
subprocess.run([sys.executable,str(ROOT/'tools/build_twin_cannon_delivery.py'),'--out',str(mods),'--stage-only'],check=True)
name='tech-priests-bunker-family-prototype';mod=mods/(name+'_0.4.0');fixture=ROOT/'tests/scenarios/twin-cannon-acceptance'
shutil.copy2(fixture/'data-updates.lua',mod/'data-updates.lua')
(mod/'control.lua').write_text('local GRAPHICAL='+('true' if a.graphical else 'false')+'\n'+(fixture/'control.lua').read_text())
scenario=mod/'scenarios/twin-cannon-acceptance';scenario.mkdir(parents=True,exist_ok=True);(scenario/'control.lua').write_text('-- Fixture in mod control.\n')
(mods/'mod-list.json').write_text(json.dumps({'mods':[{'name':m,'enabled':m=='base'} for m in ('base','space-age','quality','elevated-rails','recycler')]+[{'name':name,'enabled':True}]}))
exe=Path('C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/Factorio.exe');user=out/'user-data';user.mkdir(exist_ok=True)
config=out/'config.ini';config.write_text('[path]\nread-data='+str(exe.parents[2]/'data')+'\nwrite-data='+str(user)+'\n[other]\ncheck-updates=false\n[graphics]\nfull-screen=false\nmax-threads=4\n')
(out/'steam_appid.txt').write_text('427520');base=[str(exe),'--config',str(config),'--mod-directory',str(mods),'--disable-migration-window']
if a.graphical:
    startup=None
    if sys.platform=='win32':
        startup=subprocess.STARTUPINFO();startup.dwFlags=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=0
    with (out/'graphical.log').open('w') as log:proc=subprocess.Popen(base+['--load-scenario',name+'/twin-cannon-acceptance','--window-size','1280x800'],cwd=out,stdout=log,stderr=subprocess.STDOUT,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0),startupinfo=startup)
    (out/'graphical-process.json').write_text(json.dumps({'pid':proc.pid},indent=2)+'\n');print('GRAPHICAL_PID',proc.pid)
else:
    save=a.reload_save.resolve() if a.reload_save else out/'proof.zip'
    steps=[] if a.reload_save else [('create',['--create',str(save)])]
    steps.append(('reload' if a.reload_save else 'run',['--benchmark',str(save),'--benchmark-ticks','1810','--benchmark-runs','1']))
    for label,args in steps:
        with (out/(label+'.log')).open('w') as log:result=subprocess.run(base+args,cwd=out,stdout=log,stderr=subprocess.STDOUT)
        if result.returncode:raise RuntimeError((out/(label+'.log')).read_text(errors='replace')[-7000:])
    path=user/'script-output/twin-cannon-acceptance/result.json';report=json.loads(path.read_text());assert report['status']=='PASS'
    if a.reload_save:
        resume=report['resume'];assert 490<=resume['saved_tick']<=510 and resume['saved_shots']>0
        assert sum(s['shots'] for s in report['sites'])>resume['saved_shots'],'continued firing after reload'
        (path.parent/'save-reload.json').write_text(json.dumps(report,indent=2)+'\n')
    print('CANNON_FULL_ACCEPTANCE_PASS',len(report['sites']),len(report['legacy']),len(report['headings']))
