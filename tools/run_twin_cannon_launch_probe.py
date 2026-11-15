"""Run the isolated native projectile-origin capability experiment."""
import json,subprocess,shutil,argparse
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--fixture',choices=['twin-cannon-launch-probe','twin-cannon-physics','twin-cannon-role'],default='twin-cannon-launch-probe');a=p.parse_args()
OUT=ROOT/'build/twin-cannon'/a.fixture.removeprefix('twin-cannon-')
OUT.mkdir(parents=True,exist_ok=True);MODS=OUT/'mods';MOD=MODS/'tech-priests-twin-cannon-probe_0.0.1';MOD.mkdir(parents=True,exist_ok=True)
(MOD/'info.json').write_text(json.dumps({'name':'tech-priests-twin-cannon-probe','version':'0.0.1','factorio_version':'2.1','title':'Twin cannon launch probe','author':'Tech Priests','dependencies':['base >= 2.1.0']}))
for file in ('data.lua','control.lua'):shutil.copy2(ROOT/'tests/scenarios'/a.fixture/file,MOD/file)
(MOD/'scripts').mkdir(exist_ok=True)
shutil.copy2(ROOT/'tech-priests_src/scripts/twin_cannon_controller.lua',MOD/'scripts/twin_cannon_controller.lua')
(MOD/'prototypes').mkdir(exist_ok=True)
shutil.copy2(ROOT/'tech-priests_src/prototypes/bunker_twin_cannon.lua',MOD/'prototypes/bunker_twin_cannon.lua')
(MODS/'mod-list.json').write_text(json.dumps({'mods':[{'name':name,'enabled':name=='base'} for name in ('base','space-age','quality','elevated-rails','recycler')]+[{'name':'tech-priests-twin-cannon-probe','enabled':True}]}))
exe=Path('C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/Factorio.exe');USER=OUT/'user-data';USER.mkdir(exist_ok=True)
config=OUT/'config.ini';config.write_text('[path]\nread-data='+str(exe.parents[2]/'data')+'\nwrite-data='+str(USER)+'\n[other]\ncheck-updates=false\n')
(OUT/'steam_appid.txt').write_text('427520')
base=[str(exe),'--config',str(config),'--mod-directory',str(MODS),'--disable-migration-window']
for label,args in [('create',['--create',str(OUT/'probe.zip'),'--map-gen-seed','49285']),('probe',['--benchmark',str(OUT/'probe.zip'),'--benchmark-ticks',{'twin-cannon-physics':'1210','twin-cannon-role':'1910'}.get(a.fixture,'610'),'--benchmark-runs','1'])]:
    with (OUT/(label+'.log')).open('w') as log:result=subprocess.run(base+args,cwd=OUT,stdout=log,stderr=subprocess.STDOUT)
    if result.returncode:raise RuntimeError((OUT/(label+'.log')).read_text(errors='replace')[-5000:])
proof=USER/('script-output/'+a.fixture+'/result.json');assert proof.exists()
report=json.loads(proof.read_text());assert report['status']=='PASS'
print(json.dumps({'status':'PASS','result':str(proof),'sites':len(report.get('sites',[])),'launches':report.get('launches')}))
