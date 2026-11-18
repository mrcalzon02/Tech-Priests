from pathlib import Path
import json,shutil,subprocess
R=Path(__file__).resolve().parents[3];B=R/'build/fluid-vault-preflight';M=B/'mods';U=B/'user-data';E=Path('C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe');M.mkdir(parents=True,exist_ok=True);U.mkdir(exist_ok=True)
shutil.copytree(R/'tech-priests_src',M/'tech-priests',dirs_exist_ok=True);A=M/'vault-probe';A.mkdir(exist_ok=True);shutil.copy2(Path(__file__).with_name('probe-control.lua'),A/'control.lua');(A/'info.json').write_text(json.dumps(dict(name='vault-probe',version='0.0.1',title='Private vault preflight',author='local',factorio_version='2.1',dependencies=['base','tech-priests'])));(M/'mod-list.json').write_text(json.dumps(dict(mods=[dict(name=n,enabled=True) for n in ('base','quality','space-age','elevated-rails','tech-priests','vault-probe')])));(B/'config.ini').write_text('[path]\nread-data='+str(E.parents[2]/'data')+'\nwrite-data='+str(U)+'\n');(B/'steam_appid.txt').write_text('427520')
common=[str(E),'--config',str(B/'config.ini'),'--mod-directory',str(M)];startup=subprocess.STARTUPINFO();startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=0
for name,args in [('create',['--create',str(B/'probe.zip')]),('test',['--benchmark',str(B/'probe.zip'),'--benchmark-ticks','4','--benchmark-runs','1'])]:
 with (B/(name+'.log')).open('w') as log:rc=subprocess.run(common+args,cwd=B,stdout=log,stderr=subprocess.STDOUT,startupinfo=startup,timeout=180).returncode
 assert rc==0,(name,(B/(name+'.log')).read_text(errors='replace')[-1500:])
print((U/'script-output/fluid-vault/preflight.json').read_text())
