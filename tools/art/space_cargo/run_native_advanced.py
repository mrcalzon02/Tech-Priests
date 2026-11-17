"""Private genuine-space-platform proof of the Advanced cargo prototype."""
from pathlib import Path
import subprocess,sys,shutil,json,hashlib,time
R=Path(__file__).resolve().parents[3];B=R/'build/advanced-cargo-v01-native';M=B/'mods';U=B/'user-data';E=Path('C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe');mode=sys.argv[1];h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
if mode=='prepare':
 M.mkdir(parents=True,exist_ok=True);U.mkdir(exist_ok=True);shutil.copytree(R/'tech-priests_src',M/'tech-priests',dirs_exist_ok=True)
 A=M/'advanced-cargo-proof';A.mkdir(exist_ok=True);shutil.copy2(Path(__file__).with_name('native-advanced.lua'),A/'control.lua');(A/'data.lua').write_text("local p=table.deepcopy(data.raw['electric-energy-interface']['electric-energy-interface']);p.name='cargo-proof-power';p.energy_source={type='electric',buffer_capacity='10MJ',usage_priority='primary-output',output_flow_limit='10MW'};p.energy_production='10MW';p.energy_usage='0W';p.minable=nil;data:extend{p}\n");(A/'info.json').write_text(json.dumps(dict(name='advanced-cargo-proof',version='0.0.1',title='Private Advanced cargo proof',author='local',factorio_version='2.1',dependencies=['base','tech-priests'])));(M/'mod-list.json').write_text(json.dumps(dict(mods=[dict(name=n,enabled=True) for n in ('base','quality','space-age','elevated-rails','tech-priests','advanced-cargo-proof')])));(B/'config.ini').write_text('[path]\nread-data='+str(E.parents[2]/'data')+'\nwrite-data='+str(U)+'\n[graphics]\nfull-screen=false\n');(B/'map-gen.json').write_text(json.dumps(dict(seed=114477,peaceful_mode=True,water=0,autoplace_controls={'enemy-base':dict(frequency='none',size='none',richness='none')})));(B/'steam_appid.txt').write_text('427520');(B/'source-binding.json').write_text(json.dumps({p.relative_to(M/'tech-priests').as_posix():h(p) for p in (M/'tech-priests').rglob('*') if p.is_file()},indent=2));print('ADVANCED_CARGO_EXACT_ART_PROFILE_READY');sys.exit()
common=[str(E),'--config',str(B/'config.ini'),'--mod-directory',str(M)]
if mode=='create':tail=['--create',str(B/'proof.zip'),'--map-gen-settings',str(B/'map-gen.json')]
elif mode=='test':tail=['--benchmark',str(B/'proof.zip'),'--benchmark-ticks','1231','--benchmark-runs','1']
elif mode=='dump':tail=['--dump-data']
elif mode=='reload':tail=['--benchmark',str(next((U/'saves').glob('*advanced-cargo-complete*.zip'))),'--benchmark-ticks','51','--benchmark-runs','1']
elif mode=='capture-final':tail=['--load-game',str(next((U/'saves').glob('*advanced-cargo-complete*.zip'))),'--disable-audio','--disable-migration-window']
elif mode=='capture':tail=['--load-game',str(B/'proof.zip'),'--disable-audio','--disable-migration-window']
else:raise ValueError(mode)
startup=subprocess.STARTUPINFO();startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=0;log=B/(mode+'.log')
with log.open('w') as f:
 if mode in ('capture','capture-final'):
  outputs=[U/'script-output/advanced-cargo'/n for n in ('native-platform.png','native-circuits.png','native-rotations.png','native-direction-0.png','native-direction-4.png','native-direction-8.png','native-direction-12.png')]
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
print('ADVANCED_CARGO_NATIVE',mode,rc)
if rc:print(log.read_text(errors='replace')[-2500:]);sys.exit(rc)
