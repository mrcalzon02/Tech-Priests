"""Stage a disposable six-weapon/four-force native stanchion-mask proof."""
import argparse,subprocess,json,shutil,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--graphical',action='store_true');a=p.parse_args()
out=ROOT/'build/bunker-team-colour/runtime';mods=out/'mods';out.mkdir(parents=True,exist_ok=True)
subprocess.run([sys.executable,str(ROOT/'tools/build_bunker_family_prototype.py'),'--out',str(mods),'--fixture'],check=True)
name='tech-priests-bunker-family-prototype';mod=mods/(name+'_0.3.0')
shutil.copy2(ROOT/'tech-priests_src/prototypes/bunker_twin_cannon.lua',mod/'prototypes/bunker_twin_cannon.lua')
art=mod/'graphics/entity/bunker-twin-cannon';art.mkdir(parents=True,exist_ok=True)
captures=ROOT/'build/twin-cannon/runtime-capture-v2'
assert len(list(captures.glob('d??-preview.png')))==64,'Native preview capture not complete'
for d in range(64):shutil.copy2(captures/f'd{d:02}-preview.png',art/f'native-{d:02}.png')
shutil.copy2(mod/'graphics/entity/bunker-autocannon/icon.png',art/'icon.png')
fixture=ROOT/'tests/scenarios/bunker-team-colour'
shutil.copy2(fixture/'data.lua',mod/'data.lua')
(mod/'data-final-fixes.lua').write_text("require('prototypes.bunker_autocannon').finalize()\nrequire('prototypes.bunker_family').finalize_grenades()\nrequire('prototypes.bunker_bullet_weapons').finalize()\nrequire('prototypes.bunker_twin_cannon').finalize()\n")
(mod/'control.lua').write_text('local GRAPHICAL='+('true' if a.graphical else 'false')+'\n'+(fixture/'control.lua').read_text())
scenario=mod/'scenarios/bunker-team-colour';scenario.mkdir(parents=True,exist_ok=True);(scenario/'control.lua').write_text('-- Test implemented in mod control.\n')
(mods/'mod-list.json').write_text(json.dumps({'mods':[{'name':'base','enabled':True},{'name':name,'enabled':True}]}))
exe=Path('C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/Factorio.exe');user=out/'user-data';user.mkdir(exist_ok=True)
config=out/'config.ini';config.write_text('[path]\nread-data='+str(exe.parents[2]/'data')+'\nwrite-data='+str(user)+'\n[other]\ncheck-updates=false\n[graphics]\nfull-screen=false\nmax-threads=4\n')
(out/'steam_appid.txt').write_text('427520')
base=[str(exe),'--config',str(config),'--mod-directory',str(mods),'--disable-migration-window']
if a.graphical:
    command=base+['--load-scenario',name+'/bunker-team-colour','--window-size','1280x800']
    with (out/'graphical.log').open('w') as log:proc=subprocess.Popen(command,cwd=out,stdout=log,stderr=subprocess.STDOUT,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
    (out/'graphical-process.json').write_text(json.dumps({'pid':proc.pid,'command':command},indent=2)+'\n');print('GRAPHICAL_PID',proc.pid)
else:
    for label,args in [('create',['--create',str(out/'proof.zip')]),('run',['--benchmark',str(out/'proof.zip'),'--benchmark-ticks','25','--benchmark-runs','1'])]:
        with (out/(label+'.log')).open('w') as log:result=subprocess.run(base+args,cwd=out,stdout=log,stderr=subprocess.STDOUT)
        if result.returncode:raise RuntimeError((out/(label+'.log')).read_text(errors='replace')[-5000:])
    report=json.loads((user/'script-output/bunker-team-colour/result.json').read_text());assert report['status']=='PASS' and len(report['sites'])==24
    print('TEAM_MASK_HEADLESS_PASS',len(report['sites']))
