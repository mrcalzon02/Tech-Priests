"""Load the actual playable ZIP in native headless and graphical Factorio."""
import json,subprocess,os,shutil,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];out=ROOT/'build/twin-cannon/packaged-load-v1';mods=out/'mods';mods.mkdir(parents=True,exist_ok=True)
name='tech-priests-bunker-family-prototype';archive=ROOT/'build/twin-cannon/delivery-0.4.0'/(name+'_0.4.0.zip');target=mods/archive.name
if not target.exists():
    try:os.link(archive,target)
    except OSError:shutil.copy2(archive,target)
assert hashlib.sha256(target.read_bytes()).digest()==hashlib.sha256(archive.read_bytes()).digest()
(mods/'mod-list.json').write_text(json.dumps({'mods':[{'name':m,'enabled':m=='base'} for m in ('base','space-age','quality','elevated-rails','recycler')]+[{'name':name,'enabled':True}]}))
exe=Path('C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/Factorio.exe');user=out/'user-data';user.mkdir(exist_ok=True)
config=out/'config.ini';config.write_text('[path]\nread-data='+str(exe.parents[2]/'data')+'\nwrite-data='+str(user)+'\n[other]\ncheck-updates=false\n[graphics]\nfull-screen=false\nmax-threads=4\n')
(out/'steam_appid.txt').write_text('427520');base=[str(exe),'--config',str(config),'--mod-directory',str(mods),'--disable-migration-window']
save=out/'packaged.zip';records=[]
for phase,args in [('create',['--create',str(save)]),('headless',['--benchmark',str(save),'--benchmark-ticks','60','--benchmark-runs','1']),
                   ('graphical',['--benchmark-graphics',str(save),'--benchmark-ticks','10','--benchmark-runs','1'])]:
    startup=None
    if phase=='graphical' and os.name=='nt':
        startup=subprocess.STARTUPINFO();startup.dwFlags=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=0
    with (out/(phase+'.log')).open('w') as log:result=subprocess.run(base+args,cwd=out,stdout=log,stderr=subprocess.STDOUT,startupinfo=startup)
    log=(out/(phase+'.log')).read_text(errors='replace')
    assert result.returncode==0,(phase,log[-5000:])
    assert 'non-recoverable error' not in log and 'Error while running' not in log,phase
    if phase=='graphical':assert 'Created an atlas bitmap' in log,'Must initialize actual GPU sprite atlases'
    records.append({'phase':phase,'exit_code':result.returncode,'log_sha256':hashlib.sha256((out/(phase+'.log')).read_bytes()).hexdigest()})
report={'status':'PASS','archive':str(archive.relative_to(ROOT)),'archive_sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),'phases':records,
        'scope':'Unmodified playable ZIP, no fixture mod or scenario, fresh map, headless reload and actual graphical benchmark'}
(out/'result.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
