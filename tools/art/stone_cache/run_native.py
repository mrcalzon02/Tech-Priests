"""Real production-source cache test in a separate profile, never user saves."""
from pathlib import Path
import subprocess,sys,shutil,json,hashlib,time
R=Path(__file__).resolve().parents[3];B=R/'build/martian-cache-v01-native';M=B/'mods';U=B/'user-data';E=Path('C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe');mode=sys.argv[1]
if mode=='prepare':
 M.mkdir(parents=True,exist_ok=True);U.mkdir(exist_ok=True);shutil.copytree(R/'tech-priests_src',M/'tech-priests',dirs_exist_ok=True);addon=M/'cache-proof';addon.mkdir(exist_ok=True);shutil.copy2(Path(__file__).with_name('native-control.lua'),addon/'control.lua');(addon/'info.json').write_text(json.dumps(dict(name='cache-proof',version='0.0.1',title='Private cache proof',author='local proof',factorio_version='2.1',dependencies=['base','tech-priests'])));(M/'mod-list.json').write_text(json.dumps(dict(mods=[dict(name=n,enabled=True) for n in ('base','quality','space-age','elevated-rails','tech-priests','cache-proof')])));(B/'config.ini').write_text('[path]\nread-data='+str(E.parents[2]/'data')+'\nwrite-data='+str(U)+'\n[graphics]\nfull-screen=false\n');(B/'map-gen.json').write_text(json.dumps(dict(seed=114477,peaceful_mode=True,water=0,autoplace_controls={'enemy-base':dict(frequency='none',size='none',richness='none')})));(B/'steam_appid.txt').write_text('427520');(B/'source-binding.json').write_text(json.dumps({p.relative_to(M/'tech-priests').as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in (M/'tech-priests').rglob('*') if p.is_file()},indent=2));print('CACHE_NATIVE_SOURCE_SNAPSHOT_READY');sys.exit()
common=[str(E),'--config',str(B/'config.ini'),'--mod-directory',str(M)]
if mode=='create':tail=['--create',str(B/'cache-proof.zip'),'--map-gen-settings',str(B/'map-gen.json')]
elif mode=='test':tail=['--benchmark',str(B/'cache-proof.zip'),'--benchmark-ticks','1201','--benchmark-runs','1']
elif mode=='dump':tail=['--dump-data']
elif mode=='reload':tail=['--benchmark',str(next((U/'saves').glob('*martian-cache-complete*.zip'))),'--benchmark-ticks','51','--benchmark-runs','1']
elif mode=='capture':tail=['--load-game',str(B/'cache-proof.zip'),'--disable-audio','--disable-migration-window']
else:raise ValueError(mode)
startup=subprocess.STARTUPINFO();startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=0;log=B/(mode+'.log')
with log.open('w') as f:
 if mode=='capture':
  outputs=[U/'script-output/martian-cache'/name for name in ('native-plain.png','native-wired.png','native-ghost.png')]
  for p in outputs:
   if p.exists():p.unlink()
  p=subprocess.Popen(common+tail,cwd=B,stdout=f,stderr=subprocess.STDOUT,startupinfo=startup);until=time.monotonic()+180
  try:
   while time.monotonic()<until and p.poll() is None:
    if all(q.exists() and q.read_bytes().endswith(b'IEND\xaeB`\x82') for q in outputs):break
    if 'non-recoverable error' in log.read_text(errors='replace'):break
    time.sleep(.3)
  finally:
   if p.poll() is None:p.terminate();p.wait(timeout=10)
  rc=0 if all(q.exists() and q.read_bytes().endswith(b'IEND\xaeB`\x82') for q in outputs) else 1
 else:rc=subprocess.run(common+tail,cwd=B,stdout=f,stderr=subprocess.STDOUT,startupinfo=startup,timeout=180).returncode
print('CACHE_NATIVE',mode,rc)
if rc:print(log.read_text(errors='replace')[-3000:]);sys.exit(rc)
