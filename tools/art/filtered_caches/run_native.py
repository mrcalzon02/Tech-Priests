"""One private profile verifies all ten actual filtered-cache prototypes."""
from pathlib import Path
import subprocess,sys,shutil,json,hashlib,time
R=Path(__file__).resolve().parents[3];B=R/'build/filtered-caches-v01-native';M=B/'mods';U=B/'user-data';E=Path('C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe');mode=sys.argv[1];h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();keys=['coal','copper-ore','copper-plate','copper-cable','iron-gear-wheel','iron-ore','iron-plate','iron-stick','stone','wood']
if mode=='prepare':
 M.mkdir(parents=True,exist_ok=True);U.mkdir(exist_ok=True);shutil.copytree(R/'tech-priests_src',M/'tech-priests',dirs_exist_ok=True);control=M/'tech-priests/control.lua';bridge=Path(__file__).with_name('filter-proof-bridge.lua');original=control.read_bytes();control.write_bytes(original+b'\n-- BEGIN PRIVATE FILTER PROOF BRIDGE\n'+bridge.read_bytes());(B/'private-control-binding.json').write_text(json.dumps(dict(original_sha256=h(R/'tech-priests_src/control.lua'),bridge_sha256=h(bridge),private_sha256=h(control),note='Production control bytes preserved as exact prefix; private remote bridge only invokes installed steward with real fixtures, never ships'),indent=2))
 A=M/'filtered-caches-proof';A.mkdir(exist_ok=True);shutil.copy2(Path(__file__).with_name('native-control.lua'),A/'control.lua');(A/'info.json').write_text(json.dumps(dict(name='filtered-caches-proof',version='0.0.1',title='Private filtered-cache proof',author='local',factorio_version='2.1',dependencies=['base','tech-priests'])));(M/'mod-list.json').write_text(json.dumps(dict(mods=[dict(name=n,enabled=True) for n in ('base','quality','space-age','elevated-rails','tech-priests','filtered-caches-proof')])));(B/'config.ini').write_text('[path]\nread-data='+str(E.parents[2]/'data')+'\nwrite-data='+str(U)+'\n[graphics]\nfull-screen=false\n');(B/'map-gen.json').write_text(json.dumps(dict(seed=114477,peaceful_mode=True,water=0,autoplace_controls={'enemy-base':dict(frequency='none',size='none',richness='none')})));(B/'steam_appid.txt').write_text('427520');(B/'source-binding.json').write_text(json.dumps({p.relative_to(M/'tech-priests').as_posix():h(p) for p in (M/'tech-priests').rglob('*') if p.is_file()},indent=2));print('TEN_CACHE_EXACT_ART_PROFILE_READY');sys.exit()
common=[str(E),'--config',str(B/'config.ini'),'--mod-directory',str(M)]
if mode=='create':tail=['--create',str(B/'proof.zip'),'--map-gen-settings',str(B/'map-gen.json')]
elif mode=='test':tail=['--benchmark',str(B/'proof.zip'),'--benchmark-ticks','1251','--benchmark-runs','1']
elif mode=='dump':tail=['--dump-data']
elif mode=='reload':tail=['--benchmark',str(next((U/'saves').glob('*filtered-caches-complete*.zip'))),'--benchmark-ticks','51','--benchmark-runs','1']
elif mode=='capture':tail=['--load-game',str(B/'proof.zip'),'--disable-audio','--disable-migration-window']
else:raise ValueError(mode)
startup=subprocess.STARTUPINFO();startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=0;log=B/(mode+'.log')
with log.open('w') as f:
 if mode=='capture':
  outputs=[U/'script-output/filtered-caches'/('native-'+k+'.png') for k in keys+['gallery']]
  for p in outputs:
   if p.exists():p.unlink()
  process=subprocess.Popen(common+tail,cwd=B,stdout=f,stderr=subprocess.STDOUT,startupinfo=startup);until=time.monotonic()+180
  try:
   while time.monotonic()<until and process.poll() is None:
    if all(p.exists() and p.read_bytes().endswith(b'IEND\xaeB`\x82') for p in outputs):break
    if 'non-recoverable error' in log.read_text(errors='replace'):break
    time.sleep(.3)
  finally:
   if process.poll() is None:process.terminate();process.wait(timeout=10)
  rc=0 if all(p.exists() and p.read_bytes().endswith(b'IEND\xaeB`\x82') for p in outputs) else 1
 else:rc=subprocess.run(common+tail,cwd=B,stdout=f,stderr=subprocess.STDOUT,startupinfo=startup,timeout=180).returncode
print('FILTERED_CACHES_NATIVE',mode,rc)
if rc:print(log.read_text(errors='replace')[-2500:]);sys.exit(rc)
