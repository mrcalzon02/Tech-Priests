"""Stage and run the isolated native Factorio bunker-family combat fixture."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--exe',type=Path,default=Path('C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/Factorio.exe'))
p.add_argument('--out',type=Path,required=True)
p.add_argument('--graphical',action='store_true')
p.add_argument('--preview-only',action='store_true',help='Pause a windowed client on a working weapon inventory panel')
p.add_argument('--scenario',choices=['bunker-family','bullet-turrets'],default='bunker-family')
p.add_argument('--headless-graphics',action='store_true')
p.add_argument('--reload-save',type=Path,help='Benchmark a graphical fixture autosave and require its continued-firing proof')
a=p.parse_args();out=a.out.resolve();out.mkdir(parents=True,exist_ok=True)
mods=out/'mods';mods.mkdir(exist_ok=True)
assert not a.headless_graphics or not a.graphical,'Placeholder graphics cannot be used for graphical verification'
build=[sys.executable,str(ROOT/'tools/build_bunker_family_prototype.py'),'--out',str(mods),'--fixture','--scenario',a.scenario]
if a.headless_graphics:build+=['--headless-graphics']
subprocess.run(build,check=True)
name='tech-priests-bunker-family-prototype'
if a.preview_only:
    staged=[f for f in mods.glob(name+'_*/control.lua')]
    assert len(staged)==1,'Use a fresh output for a preview-only session'
    preview_gun='storage.bullet_proof.sites[5].gun' if a.scenario=='bullet-turrets' else 'storage.family.sites[9].gun'
    with staged[0].open('a') as control:
        control.write("\nscript.on_nth_tick(500,function() if game.tick<500 then return end; local p=game.get_player(1); if p then local gun="+preview_gun+"; p.teleport({gun.position.x-3,gun.position.y},gun.surface); p.opened=gun; game.tick_paused=true; log('[BUNKER-FAMILY] WORKING_PREVIEW_PAUSED') end end)\n")
(mods/'mod-list.json').write_text(json.dumps({'mods':[{'name':m,'enabled':m=='base'} for m in
    ('base','space-age','quality','elevated-rails','recycler')]+[{'name':name,'enabled':True}]}))
user=out/'user-data';user.mkdir(exist_ok=True)
config=out/'config.ini'
config.write_text('[path]\nread-data='+str(a.exe.parents[2]/'data')+'\nwrite-data='+str(user)+'\n[other]\ncheck-updates=false\n[graphics]\nmax-threads=4\n')
if a.graphical:
    with config.open('a') as stream:stream.write('full-screen=false\nwindow-width=1280\nwindow-height=800\n')
base=[str(a.exe),'--config',str(config),'--mod-directory',str(mods),'--disable-migration-window']
(out/'steam_appid.txt').write_text('427520')
if a.graphical:
    command=base+['--load-scenario',name+'/'+a.scenario]
    command+=['--window-size','1280x800']
    with (out/'graphical-client.log').open('w') as log:
        process=subprocess.Popen(command,cwd=out,stdout=log,stderr=subprocess.STDOUT,
            creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
    print(json.dumps({'pid':process.pid,'output':str(out),'command':command}));raise SystemExit(0)
save=a.reload_save.resolve() if a.reload_save else out/'family.zip'
if a.reload_save:assert a.scenario=='bullet-turrets' and save.is_file(),'Reload requires a real bullet fixture autosave'
commands=[] if a.reload_save else [('create',base+['--create',str(save),'--map-gen-seed','49285'])]
commands.append(('reload' if a.reload_save else 'combat',base+['--benchmark',str(save),'--benchmark-ticks','950' if a.reload_save else ('3950' if a.scenario=='bullet-turrets' else '3600'),'--benchmark-runs','1']))
for label,command in commands:
    with (out/(label+'.log')).open('w') as log:
        result=subprocess.run(command,cwd=out,stdout=log,stderr=subprocess.STDOUT)
    if result.returncode:
        print((out/(label+'.log')).read_text(errors='replace')[-10000:]);raise SystemExit(result.returncode)
result=user/('script-output/'+a.scenario+('/continued.json' if a.reload_save else '/result.json'))
assert result.is_file(),'Native fixture did not report results; inspect combat.log'
report=json.loads(result.read_text());assert report['status']=='PASS'
if a.reload_save:
    assert '[BULLET-TURRETS] CONTINUED_FIRING_PASS' in (out/'reload.log').read_text(errors='replace'),'Reload must execute a fresh continued-firing check'
if a.scenario=='bullet-turrets':
    assert '[BULLET-TURRETS] INSERTER_FEED_PASS' in (out/('reload.log' if a.reload_save else 'combat.log')).read_text(errors='replace'),'Must execute the physical inserter feed check'
print(json.dumps({'status':'PASS','phase':'save-reload' if a.reload_save else 'combat','engine':report.get('engine'),'sites':report['sites'] if a.reload_save else len(report['sites']),'result':str(result)}))
