"""Validate real main-mod event integration using the established cannon cases."""
import argparse,json,subprocess,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];out=ROOT/'build/twin-cannon/main-integration';mod=out/'mods/tech-priests'
p=argparse.ArgumentParser();p.add_argument('--graphical',action='store_true');p.add_argument('--reload-save',type=Path);a=p.parse_args()
production=(ROOT/'tech-priests_src/control.lua').read_text()
fixture=(ROOT/'tests/scenarios/twin-cannon-acceptance/control.lua').read_text()
fixture=fixture.replace('integration.install()',"local registry=require('scripts.core.runtime_event_registry')")
fixture=fixture.replace('script.on_init(function()', 'registry.on_init(function()',1)
fixture=fixture.replace('  integration.init()\n', '''  integration.init()
  check(script.mod_name=='tech-priests','must run inside the real main mod')
  check(integration.main_ownership and integration.main_ownership.preserved,'original event owners preserved')
  check(integration.main_ownership.preexisting_routes>20,'full priest runtime remains installed')
''',1)
fixture=fixture.replace('end)\n-- Preserve',"end,{owner='bunker_acceptance',route='setup',priority=1000000})\n-- Preserve",1)
fixture=fixture.replace('script.on_event(defines.events.on_entity_damaged,','registry.on_event(defines.events.on_entity_damaged,',1)
fixture=fixture.replace('  bullet.hit(e)\n','',1)
fixture=fixture.replace('end)\nscript.on_event(defines.events.on_tick,',"end,nil,{owner='bunker_acceptance',route='damage-observer',priority=1000000})\nregistry.on_event(defines.events.on_tick,",1)
fixture=fixture.replace('  integration.tick(e);local r=','  local r=',1)
assert fixture.rstrip().endswith('end)')
fixture=fixture.rstrip()[:-4]+"end,nil,{owner='bunker_acceptance',route='assertions',priority=1000000})\n"
fixture=fixture.replace('twin-cannon-acceptance','twin-cannon-main')
fixture=fixture.replace("local report={status='PASS',", "local report={status='PASS',main_mod=script.mod_name,event_ownership=integration.main_ownership,",1)
(mod/'scripts/twin_cannon_main_fixture.lua').write_text('local GRAPHICAL='+('true' if a.graphical else 'false')+'\n'+fixture)
(mod/'control.lua').write_text(production+"\n-- Isolated native verification only; not published.\nrequire('scripts.twin_cannon_main_fixture')\n")
data=(ROOT/'tests/scenarios/twin-cannon-acceptance/data-updates.lua').read_text()
updates=mod/'data-updates.lua'
# The base extraction restores this file before each new staging run.
text=updates.read_text() if updates.exists() else ''
marker='-- Isolated twin-cannon verification targets'
text=text.split(marker)[0];updates.write_text(text+'\n'+marker+'\n'+data)
scenario=mod/'scenarios/twin-cannon-main';scenario.mkdir(parents=True,exist_ok=True);(scenario/'control.lua').write_text('-- Assertions registered through the real canonical registry.\n')
mods=out/'mods';(mods/'mod-list.json').write_text(json.dumps({'mods':[{'name':m,'enabled':True} for m in ('base','space-age','quality','elevated-rails','recycler','tech-priests')]}))
exe=Path('C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/Factorio.exe');user=out/'user-data';user.mkdir(exist_ok=True)
config=out/'config.ini';config.write_text('[path]\nread-data='+str(exe.parents[2]/'data')+'\nwrite-data='+str(user)+'\n[other]\ncheck-updates=false\n[graphics]\nfull-screen=false\nmax-threads=4\n')
(out/'steam_appid.txt').write_text('427520');base=[str(exe),'--config',str(config),'--mod-directory',str(mods),'--disable-migration-window']
if a.graphical:
    startup=subprocess.STARTUPINFO();startup.dwFlags=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=0
    with (out/'graphical.log').open('w') as log:proc=subprocess.Popen(base+['--load-scenario','tech-priests/twin-cannon-main','--window-size','1280x800'],cwd=out,stdout=log,stderr=subprocess.STDOUT,startupinfo=startup)
    (out/'graphical-process.json').write_text(json.dumps({'pid':proc.pid}));print('MAIN_MOD_GRAPHICAL_PID',proc.pid)
else:
    save=a.reload_save.resolve() if a.reload_save else out/'main-proof.zip'
    steps=[] if a.reload_save else [('create',['--create',str(save)])]
    steps.append(('reload' if a.reload_save else 'run',['--benchmark',str(save),'--benchmark-ticks','1810','--benchmark-runs','1']))
    for phase,args in steps:
        with (out/(phase+'.log')).open('w') as log:result=subprocess.run(base+args,cwd=out,stdout=log,stderr=subprocess.STDOUT)
        if result.returncode:raise RuntimeError((out/(phase+'.log')).read_text(errors='replace')[-7000:])
    result=user/'script-output/twin-cannon-main/result.json';r=json.loads(result.read_text());assert r['status']=='PASS' and r['main_mod']=='tech-priests'
    if a.reload_save:
        assert 490<=r['resume']['saved_tick']<=510
        (result.parent/'save-reload.json').write_text(json.dumps(r,indent=2)+'\n')
    print('MAIN_MOD_CANNON_PASS',len(r['sites']),len(r['legacy']),len(r['headings']),r['event_ownership'])
