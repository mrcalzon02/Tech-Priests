"""Test current production source separately from the authored candidate evidence."""
from pathlib import Path
import sys,subprocess,json,os,signal,time
P=Path(__file__).resolve().parent;R=P.parents[2];B=R/'build/conclave-approved-integration';mode=sys.argv[1]
control=(P/'native-v08-control.lua').read_text();control+='\n'+(P/'approved-observer.lua').read_text();(P/'approved-control.lua').write_text(control)
if mode=='physical':
 folder=B/'user-data/script-output/conclave-center'
 for pattern in ('layout-*.png','layout-*.json','physical-*.png','physical-*.json'):
  for old in folder.glob(pattern):
   assert old.resolve().parent==folder.resolve();old.unlink()
 exe=Path('C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe');startup=subprocess.STARTUPINFO();startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=0
 with (B/'physical.log').open('w') as log:
  window_size=sys.argv[sys.argv.index('--window-size')+1] if '--window-size' in sys.argv else '1280x800'
  proc=subprocess.Popen([str(exe),'--config',str(B/'config.ini'),'--mod-directory',str(B/'mods'),'--load-game',str(B/'conclave-proof.zip'),'--disable-audio','--disable-migration-window','--window-size',window_size],stdout=log,stderr=subprocess.STDOUT,cwd=B,startupinfo=startup)
 (B/'physical-process.json').write_text(json.dumps(dict(pid=proc.pid,executable=str(exe),profile=str(B)),indent=2));print('ISOLATED_PHYSICAL_TEST_CLIENT_STARTED',proc.pid,flush=True)
 # Keep the launching job alive while the UI test uses the owned child.
 until=time.monotonic()+600
 try:
  while proc.poll() is None and time.monotonic()<until:time.sleep(.3)
 finally:
  if proc.poll() is None:proc.terminate();proc.wait(timeout=10)
 sys.exit()
if mode=='stop-physical':
 r=json.loads((B/'physical-process.json').read_text());assert Path(r['profile']).resolve()==B.resolve();os.kill(r['pid'],signal.SIGTERM);print('OWNED_TEST_CLIENT_STOPPED');sys.exit()
src=(P/'run_native.py').read_text().replace('build/conclave-native-v01','build/conclave-approved-integration').replace("'native-control.lua'","'approved-control.lua'")
src=src.replace("['native-close.png','native-gameplay.png']","['native-close.png','native-gameplay.png','native-motion-035.png','native-night.png','native-ghost.png']")
if mode=='capture':
 folder=B/'user-data/script-output/conclave-center'
 for screenshot in folder.glob('native-*.png'):
  assert screenshot.resolve().parent==folder.resolve();screenshot.unlink()
exec(compile(src,str(P/'run_native.py'),'exec'))
