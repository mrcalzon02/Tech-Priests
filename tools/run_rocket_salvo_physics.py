"""Isolated engine proof for the six-cell rocket salvo, including mid-reload load."""
import argparse,json,subprocess,shutil,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--reload',action='store_true');p.add_argument('--graphical',action='store_true');a=p.parse_args()
out=ROOT/'build/rocket-salvo/native-physics';mods=out/'mods';mod=mods/'tech-priests-rocket-probe_0.0.1';mod.mkdir(parents=True,exist_ok=True)
art=ROOT/'build/rocket-salvo/combat-actual-art-v1'
if not (art/'assets.json').exists():subprocess.run([sys.executable,str(ROOT/'tools/prepare_rocket_combat_art.py')],check=True)
(mod/'info.json').write_text(json.dumps({'name':'tech-priests-rocket-probe','version':'0.0.1','factorio_version':'2.1',
    'title':'Tech Priests actual bunker combat test','author':'Tech Priests','dependencies':['base >= 2.1.0']}))
for name in ('data.lua','control.lua'):shutil.copy2(ROOT/'tests/scenarios/rocket-salvo-physics'/name,mod/name)
(mod/'control.lua').write_text('local GRAPHICAL='+('true' if a.graphical else 'false')+'\n'+(ROOT/'tests/scenarios/rocket-salvo-physics/control.lua').read_text())
for folder,names in {'prototypes':['bunker_rocket_salvo.lua','bunker_autocannon.lua','bunker_autocannon_graphics.lua'],'scripts':['rocket_salvo_controller.lua','rocket_salvo_geometry.lua']}.items():
    (mod/folder).mkdir(exist_ok=True)
    for name in names:shutil.copy2(ROOT/'tech-priests_src'/folder/name,mod/folder/name)
shutil.copytree(ROOT/'tech-priests_src/graphics/entity/bunker-autocannon',mod/'graphics/entity/bunker-autocannon',dirs_exist_ok=True)
shutil.copytree(art,mod/'graphics/entity/bunker-rocket-salvo',dirs_exist_ok=True)
(mods/'mod-list.json').write_text(json.dumps({'mods':[{'name':name,'enabled':name=='base'} for name in ('base','space-age','quality','elevated-rails','recycler')]+[{'name':'tech-priests-rocket-probe','enabled':True}]}))
exe=Path('C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/Factorio.exe');user=out/'user-data';user.mkdir(exist_ok=True)
config=out/'config.ini';config.write_text('[path]\nread-data='+str(exe.parents[2]/'data')+'\nwrite-data='+str(user)+'\n[other]\ncheck-updates=false\n')
(out/'steam_appid.txt').write_text('427520')
base=[str(exe),'--config',str(config),'--mod-directory',str(mods),'--disable-migration-window']
if a.graphical:
    (user/'script-output/rocket-salvo-physics/result-graphical.json').unlink(missing_ok=True)
    scenario=mod/'scenarios/rocket-salvo-physics';scenario.mkdir(parents=True,exist_ok=True);(scenario/'control.lua').write_text('-- Native physics fixture; no final-art claim.\n')
    startup=subprocess.STARTUPINFO();startup.dwFlags=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=0
    with (out/'graphical.log').open('w') as log:proc=subprocess.Popen(base+['--load-scenario','tech-priests-rocket-probe/rocket-salvo-physics','--window-size','1280x800'],cwd=out,stdout=log,stderr=subprocess.STDOUT,startupinfo=startup)
    (out/'graphical-process.json').write_text(json.dumps({'pid':proc.pid}));print('ROCKET_PHYSICS_SAVE_PROCESS',proc.pid)
    raise SystemExit(0)
save=user/'saves/_autosave-rocket-salvo-actual-art-mid-reload.zip' if a.reload else out/'physics.zip'
proof=user/'script-output/rocket-salvo-physics/result.json';proof.unlink(missing_ok=True)
steps=[] if a.reload else [('create',['--create',str(save),'--map-gen-seed','49285'])]
steps.append(('reload' if a.reload else 'physics',['--benchmark',str(save),'--benchmark-ticks','1710','--benchmark-runs','1']))
for tag,args in steps:
    with (out/(tag+'.log')).open('w') as log:result=subprocess.run(base+args,cwd=out,stdout=log,stderr=subprocess.STDOUT)
    if result.returncode:raise RuntimeError((out/(tag+'.log')).read_text(errors='replace')[-6000:])
r=json.loads(proof.read_text());assert r['status']=='PASS' and r['recipe_outputs']==1 and r['actual_art']
if a.reload:
    assert 320<=r['resume']['saved_tick']<=350 and r['resume']['tick']==r['resume']['saved_tick']+1
    shutil.copy2(proof,proof.parent/'save-reload.json')
else:shutil.copy2(proof,proof.parent/'fresh.json')
print('ROCKET_NATIVE_PHYSICS_PASS',len(r['sites']),r['headings'],r['resume'] if a.reload else 'fresh')
