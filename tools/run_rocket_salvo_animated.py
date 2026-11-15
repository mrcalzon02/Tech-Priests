"""Run actual rocket pilot art on the shared foundation, isolated from the main mod."""
import argparse,json,subprocess,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--graphical',action='store_true')
p.add_argument('--moving-shadow-art',type=Path);a=p.parse_args()
moving=bool(a.moving_shadow_art)
cell=json.loads((a.moving_shadow_art/'assets.json').read_text())['shadow_identity']['cell'] if moving else 512
out=ROOT/('build/rocket-salvo/animated-moving-shadow-'+str(cell) if moving else 'build/rocket-salvo/animated-pilot-v1')
mods=out/'mods';name='tech-priests-rocket-animation-pilot';mod=mods/name
for folder in ('prototypes','scripts','graphics/entity','scenarios/rocket-salvo-animated'):(mod/folder).mkdir(parents=True,exist_ok=True)
for file in ('bunker_autocannon.lua','bunker_autocannon_graphics.lua','bunker_rocket_salvo.lua'):shutil.copy2(ROOT/'tech-priests_src/prototypes'/file,mod/'prototypes'/file)
for file in ('rocket_salvo_controller.lua','rocket_salvo_geometry.lua'):shutil.copy2(ROOT/'tech-priests_src/scripts'/file,mod/'scripts'/file)
shutil.copytree(ROOT/'tech-priests_src/graphics/entity/bunker-autocannon',mod/'graphics/entity/bunker-autocannon',dirs_exist_ok=True)
pilot_art=a.moving_shadow_art if moving else ROOT/'build/rocket-salvo/runtime-pilot-art-v1'
if not pilot_art.exists():pilot_art=ROOT/'art/bunker-rocket-salvo/runtime-pilot-v1'
shutil.copytree(pilot_art,mod/'graphics/entity/bunker-rocket-salvo',dirs_exist_ok=True)
fixture=ROOT/'tests/scenarios/rocket-salvo-animated';shutil.copy2(fixture/'data.lua',mod/'data.lua')
control=(fixture/'control.lua').read_text()
if moving:
    data=(fixture/'data.lua').read_text().replace('capture_headings={0,16,32,48},static_shadow_pilot=true','capture_headings={0},shadow_cell='+str(cell))
    (mod/'data.lua').write_text(data)
    control=control.replace('local offsets={{0,-26},{26,0},{0,26},{-26,0}}','local offsets={{0,-26}}')
    control=control.replace('capture_headings={0,16,32,48}','capture_headings={0}')
    control=control.replace('Actual four-heading sprite pilot; static shadows only, full headings and moving shadows remain open',
        'Actual one-heading moving-shadow probe; full-direction final acceptance remains open')
(mod/'control.lua').write_text('local GRAPHICAL='+('true' if a.graphical else 'false')+'\nlocal MOVING_SHADOWS='+('true' if moving else 'false')+'\n'+control)
(mod/'scenarios/rocket-salvo-animated/control.lua').write_text('-- Actual four-heading sprite pilot.\n')
(mod/'info.json').write_text(json.dumps({'name':name,'version':'0.0.1','factorio_version':'2.1','title':'Rocket sprite pilot','author':'Tech Priests','dependencies':['base >= 2.1.0']}))
(mods/'mod-list.json').write_text(json.dumps({'mods':[{'name':'base','enabled':True},{'name':name,'enabled':True}]}))
user=out/'user-data';user.mkdir(exist_ok=True);exe=Path('C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/Factorio.exe')
config=out/'config.ini';config.write_text('[path]\nread-data='+str(exe.parents[2]/'data')+'\nwrite-data='+str(user)+'\n[other]\ncheck-updates=false\n[graphics]\nfull-screen=false\nmax-threads=4\n')
(out/'steam_appid.txt').write_text('427520');base=[str(exe),'--config',str(config),'--mod-directory',str(mods),'--disable-migration-window']
if a.graphical:
    (user/'script-output/rocket-salvo-animated/result-graphical.json').unlink(missing_ok=True)
    startup=subprocess.STARTUPINFO();startup.dwFlags=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=0
    with (out/'graphical.log').open('w') as log:proc=subprocess.Popen(base+['--load-scenario',name+'/rocket-salvo-animated','--window-size','1280x800'],cwd=out,stdout=log,stderr=subprocess.STDOUT,startupinfo=startup)
    (out/'graphical-process.json').write_text(json.dumps({'pid':proc.pid}));print('ROCKET_ANIMATION_PID',proc.pid)
else:
    save=out/'pilot.zip'
    for tag,args in [('create',['--create',str(save)]),('pilot',['--benchmark',str(save),'--benchmark-ticks','810','--benchmark-runs','1'])]:
        with (out/(tag+'.log')).open('w') as log:result=subprocess.run(base+args,cwd=out,stdout=log,stderr=subprocess.STDOUT)
        if result.returncode:raise RuntimeError((out/(tag+'.log')).read_text(errors='replace')[-6000:])
    r=json.loads((user/'script-output/rocket-salvo-animated/result.json').read_text());assert r['status']=='PASS'
    print('ROCKET_ACTUAL_ART_PILOT_PASS',len(r['sites']))
