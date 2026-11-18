"""Snapshot real production mod; native behavior, dump and graphical proof."""
import json,hashlib,subprocess,shutil,sys,time,os
from pathlib import Path
R=Path(__file__).resolve().parents[3];E=Path('C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe');O=R/'build/conclave-native-v01';O.mkdir(parents=True,exist_ok=True);M=O/'mods';M.mkdir(exist_ok=True);U=O/'user-data';U.mkdir(exist_ok=True)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
mode=sys.argv[1] if len(sys.argv)>1 else 'prepare'
if mode=='prepare':
 dest=M/'tech-priests';shutil.copytree(R/'tech-priests_src',dest,dirs_exist_ok=True)
 addon=M/'conclave-proof';addon.mkdir(exist_ok=True);shutil.copy2(Path(__file__).with_name('native-control.lua'),addon/'control.lua')
 (addon/'info.json').write_text(json.dumps(dict(name='conclave-proof',version='0.0.1',title='Private Conclave validation',author='local proof',factorio_version='2.1',dependencies=['base','tech-priests'])))
 (M/'mod-list.json').write_text(json.dumps(dict(mods=[dict(name=n,enabled=True) for n in ['base','quality','space-age','elevated-rails','tech-priests','conclave-proof']])))
 (O/'config.ini').write_text('[path]\nread-data='+str(E.parents[2]/'data')+'\nwrite-data='+str(U)+'\n[graphics]\nfull-screen=false\n')
 (O/'steam_appid.txt').write_text('427520')
 (O/'map-gen.json').write_text(json.dumps(dict(seed=114477,peaceful_mode=True,water=0,autoplace_controls={'enemy-base':dict(frequency='none',size='none',richness='none')})))
 (O/'source-snapshot.json').write_text(json.dumps({p.relative_to(dest).as_posix():sha(p) for p in dest.rglob('*') if p.is_file()},indent=2))
 print('NATIVE_SNAPSHOT_READY');sys.exit()
common=[str(E),'--config',str(O/'config.ini'),'--mod-directory',str(M)]
if mode=='create':tail=['--create',str(O/'conclave-proof.zip'),'--map-gen-settings',str(O/'map-gen.json')]
elif mode=='test':tail=['--benchmark',str(O/'conclave-proof.zip'),'--benchmark-ticks','1201','--benchmark-runs','1']
elif mode=='dump':tail=['--dump-data']
elif mode=='reload':tail=['--benchmark',str(next((U/'saves').glob('*conclave-complete*.zip'))),'--benchmark-ticks','51','--benchmark-runs','1']
elif mode in ('gui','capture'):tail=['--load-game',str(O/'conclave-proof.zip'),'--disable-audio','--disable-migration-window']
else:raise ValueError(mode)
log=O/(mode+'.log');startup=subprocess.STARTUPINFO();startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=0
with log.open('w') as f:
 if mode in ('gui','capture'):
  p=subprocess.Popen(common+tail,stdout=f,stderr=subprocess.STDOUT,cwd=O,startupinfo=startup)
  try:
   until=time.monotonic()+180
   while time.monotonic()<until:
    files=[U/'script-output/conclave-center'/n for n in ['native-close.png','native-gameplay.png']]
    report=U/'script-output/conclave-center/graphical-governance.json'
    if all(x.exists() and x.read_bytes().endswith(b'IEND\xaeB`\x82') for x in files) and (mode=='capture' or (report.exists() and json.loads(report.read_text()).get('physical_gui_observed'))):break
    if p.poll() is not None:break
    if 'non-recoverable error' in log.read_text(errors='replace'):break
    time.sleep(.3)
  finally:
   if p.poll() is None:p.terminate();p.wait(timeout=10)
  rc=0 if all(x.exists() and x.read_bytes().endswith(b'IEND\xaeB`\x82') for x in files) else 1
 else:rc=subprocess.run(common+tail,stdout=f,stderr=subprocess.STDOUT,cwd=O,startupinfo=startup,timeout=180).returncode
print('CONCLAVE_NATIVE',mode,rc)
if rc:print(log.read_text(errors='replace')[-4500:]);sys.exit(rc)
