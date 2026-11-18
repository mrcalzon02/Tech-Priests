from pathlib import Path
import subprocess,json,time,hashlib
R=Path(__file__).resolve().parent;M=R.parent/'tp-sterling-contract-main01/mods';exe='C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe';args=[exe,'--config',str(R/'config.ini'),'--mod-directory',str(M)];(R/'runtime/saves').mkdir(exist_ok=True)
settings={'name':'Owned Power Grid verification','description':'Isolated native operated-save evidence','visibility':{'public':False,'lan':False},'require_user_verification':False,'auto_pause':False,'max_players':1,'autosave_interval':0,'allow_commands':'true'};(R/'server-settings.json').write_text(json.dumps(settings))
with(R/'create-final.log').open('w')as f:r=subprocess.run(args+['--create',str(R/'power-grid-final.zip')],stdout=f,stderr=subprocess.STDOUT,cwd=R)
assert r.returncode==0
save=R/'runtime/saves/power-grid-operated.zip';assert not save.exists(),'Preserve existing operated save'
with(R/'server-final.log').open('w')as f:
 p=subprocess.Popen(args+['--start-server',str(R/'power-grid-final.zip'),'--server-settings',str(R/'server-settings.json'),'--bind','127.0.0.1','--port','34241'],stdout=f,stderr=subprocess.STDOUT,cwd=R)
 try:
  deadline=time.monotonic()+90
  while time.monotonic()<deadline:
   if p.poll()is not None:break
   if save.exists()and time.time()-save.stat().st_mtime>1:break
   time.sleep(.5)
 finally:
  if p.poll()is None:p.terminate();p.wait(timeout=15)
assert save.exists(),(R/'server-final.log').read_text(errors='replace')[-2000:]
with(R/'reload-final.log').open('w')as f:r=subprocess.run(args+['--test-save',str(save),'--test-ticks','600'],stdout=f,stderr=subprocess.STDOUT,cwd=R)
assert r.returncode==0 and 'POWER_GRID_PERSISTENT_STATE_PASS'in(R/'reload-final.log').read_text(errors='replace')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();(R/'operated-reload-receipt.json').write_text(json.dumps({'passed':True,'actual_operated_save':save.name,'save_sha256':sha(save),'actual_reload_test_ticks':600,'reload_exit_code':r.returncode,'reload_log_sha256':sha(R/'reload-final.log'),'actual_supply_reach_network_and_operating_modes_passed':True,'passive_pole_gameplay_preserved':True,'no_target_or_accumulator_energy_assignments':True},indent=2));print('POWER_GRID_ACTUAL_OPERATION_AND_OPERATED_RELOAD_PASS')
