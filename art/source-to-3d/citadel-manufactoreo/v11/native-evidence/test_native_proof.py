from pathlib import Path
import subprocess,shutil,sys
R=Path(__file__).resolve().parent;M=R.parent/'tp-sterling-contract-main01/mods';B='C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe'
tag=sys.argv[1];save=R/f'citadel-proof-{tag}.zip';assert not save.exists(),'Never overwrite an existing proof save'
shutil.copy2(R/'citadel-proof-control.lua',M/'citadel-v1-proof_0.0.1/control.lua')
common=[B,'--config',str(R/'config.ini'),'--mod-directory',str(M)]
for phase,args in [('create',['--create',str(save)]),('test',['--test-save',str(save),'--test-ticks','34000'])]:
 log=R/f'{phase}-proof-{tag}.log'
 with log.open('w')as f:p=subprocess.run(common+args,cwd=R,stdout=f,stderr=subprocess.STDOUT,timeout=180)
 text=log.read_text(errors='replace');print(phase,p.returncode,text[-1600:],flush=True)
 assert p.returncode==0 and (phase!='create'or save.is_file())
 if phase=='test':assert 'CITADEL_NATIVE_OPERATIONAL_PASS'in text
print('CITADEL_NATIVE_HEADLESS_PASS',tag,flush=True)
