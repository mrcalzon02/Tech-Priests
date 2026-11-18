"""Run one bounded headless proof stage with its isolated working directory."""
import argparse,pathlib,json,subprocess,shutil,hashlib,time
p=argparse.ArgumentParser();p.add_argument('profile',type=pathlib.Path);p.add_argument('step',choices=('create','test','server','reload'));a=p.parse_args();root=a.profile.resolve();here=pathlib.Path(__file__).resolve().parent;sha=lambda p:hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest();prep=json.loads((root/'preparation.json').read_text());exe=pathlib.Path('C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe');args=[str(exe),'--config',str(root/'config.ini'),'--mod-directory',str(root/'mods')]
if a.step=='create':
 assert not(root/'visual-power-proof.zip').exists(),'Preserve existing initial save'
 if prep.get('optional_animation_assets_present',True):shutil.copy2(here/'control.lua',root/'mods/tp-visual-power-proof/control.lua')
 prep['fixture_control_sha256']=sha(root/'mods/tp-visual-power-proof/control.lua');(root/'preparation.json').write_text(json.dumps(prep,indent=2)+'\n');args += ['--create',str(root/'visual-power-proof.zip'),'--map-gen-settings',str(root/'map-gen.json')]
elif a.step=='server':
 assert(root/'server-settings.json').exists();args += ['--start-server',str(root/'visual-power-proof.zip'),'--server-settings',str(root/'server-settings.json'),'--bind','127.0.0.1','--port','34318']
else:
 save=root/'visual-power-proof.zip' if a.step=='test' else root/'user-data/saves/_autosave-visual-power-coupling.zip';assert save.exists(),save
 args += ['--benchmark',str(save),'--benchmark-ticks','1761' if a.step=='test' else '201','--benchmark-runs','1']
attempt=len(list(root.glob(a.step+'-run-*.json')))+1;prefix=a.step+'-run-%02d'%attempt
with(root/(prefix+'.log')).open('w')as out,(root/(prefix+'-stderr.log')).open('w')as err:
 if a.step=='server':
  dest=root/'user-data/script-output/visual-power-native/continuous-results.json';assert not dest.exists(),'Preserve prior actual server proof'
  proc=subprocess.Popen(args,cwd=root,stdout=out,stderr=err,creationflags=subprocess.CREATE_NO_WINDOW);(root/'actual-server.pid').write_text(str(proc.pid));deadline=time.monotonic()+55
  try:
   while time.monotonic()<deadline and not dest.exists()and proc.poll()is None:time.sleep(.25)
   assert dest.exists(),'Server did not emit actual completed proof'
   assert(root/'user-data/saves/_autosave-visual-power-coupling.zip').exists(),'Actual native save missing'
  finally:
   if proc.poll()is None:proc.terminate();proc.wait(timeout=10)
  result=subprocess.CompletedProcess(args,0)
 else:result=subprocess.run(args,cwd=root,stdout=out,stderr=err,creationflags=subprocess.CREATE_NO_WINDOW,timeout=60)
(root/(prefix+'.json')).write_text(json.dumps({'command':args,'working_directory':str(root),'exit_code':result.returncode,'fixture_control_sha256':prep['fixture_control_sha256'],'stub_scope':'Headless native API/state proof; not pixel appearance'},indent=2)+'\n');print(prefix,'EXIT',result.returncode);assert result.returncode==0,(root/(prefix+'.log')).read_text(errors='replace')[-4000:]
if a.step=='create':assert(root/'visual-power-proof.zip').exists(),'No actual map created'
else:assert(root/('user-data/script-output/visual-power-native/'+('continuous-results.json'if a.step in('test','server')else'reload-results.json'))).exists(),'No actual native evidence emitted'
