from pathlib import Path
import subprocess,json,time
R=Path(__file__).resolve().parent;M=R.parent/'tp-sterling-contract-main01/mods';exe='C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe';args=[exe,'--config',str(R/'config.ini'),'--mod-directory',str(M)]
settings={'name':'Owned Entropic headless verification','description':'Isolated operational evidence','visibility':{'public':False,'lan':False},'require_user_verification':False,'auto_pause':False,'max_players':1,'autosave_interval':0,'allow_commands':'true'};(R/'server-settings.json').write_text(json.dumps(settings))
with (R/'create-final-art.log').open('w')as f:r=subprocess.run(args+['--create',str(R/'entropic-final-art.zip')],stdout=f,stderr=subprocess.STDOUT)
assert r.returncode==0
save=R/'runtime/saves/entropic-operated.zip';assert not save.exists(),'preserve any prior operated save'
with (R/'server-final-art.log').open('w')as f:
 p=subprocess.Popen(args+['--start-server',str(R/'entropic-final-art.zip'),'--server-settings',str(R/'server-settings.json'),'--port','34237'],stdout=f,stderr=subprocess.STDOUT)
 (R/'owned-headless-server.json').write_text(json.dumps({'pid':p.pid,'purpose':'Entropic final-art operating pass and actual operated save'}));start=time.time()
 while time.time()-start<120:
  if p.poll()is not None:break
  if save.exists()and time.time()-save.stat().st_mtime>2:break
  time.sleep(1)
 if p.poll()is None:p.terminate();p.wait(timeout=20)
assert save.exists(),(R/'server-final-art.log').read_text(errors='replace')[-4000:]
with (R/'reload-final-art.log').open('w')as f:r=subprocess.run(args+['--test-save',str(save),'--test-ticks','360'],stdout=f,stderr=subprocess.STDOUT)
assert r.returncode==0 and 'ENTROPIC_OPERATED_RELOAD_PASS'in(R/'reload-final-art.log').read_text(errors='replace');print('ENTROPIC_FINAL_ART_OPERATION_AND_ACTUAL_RELOAD_PASS')
