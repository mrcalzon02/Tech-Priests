from pathlib import Path
import subprocess,json,shutil,ctypes,time,struct,zlib,hashlib,os
R=Path(__file__).resolve().parent;B='C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe';M=R.parent/'tp-sterling-contract-main01/mods';OUT=R/'client-fmpl-v02';OUT.mkdir(exist_ok=True)
session=ctypes.c_ulong();ctypes.windll.kernel32.ProcessIdToSessionId(os.getpid(),ctypes.byref(session));assert session.value!=0
d=M/'void-v1-capture_0.0.1';d.mkdir(exist_ok=True);(d/'info.json').write_text(json.dumps({'name':'void-v1-capture','version':'0.0.1','title':'Isolated actual Void client capture','author':'local','factorio_version':'2.1','dependencies':['base','space-age','tech-priests','void-v1-proof']}),encoding='utf-8');shutil.copy2(R/'void-gui-control.lua',d/'control.lua');p=M/'mod-list.json';a=json.loads(p.read_text());a['mods']=[x for x in a['mods'] if x['name']!='void-v1-capture'];a['mods'].append({'name':'void-v1-capture','enabled':True});p.write_text(json.dumps(a))
config=R/'client-config-v02.ini';runtime=R/'client-runtime-v02';runtime.mkdir(exist_ok=True);config.write_text('[path]\nread-data=C:/Program Files (x86)/Steam/steamapps/common/Factorio/data\nwrite-data='+str(runtime)+'\n[graphics]\nfull-screen=false\n',encoding='utf-8');common=[B,'--config',str(config),'--mod-directory',str(M)];save=OUT/'void-fresh-proof.zip'
if not save.is_file():
 with (OUT/'create.log').open('w') as f:p=subprocess.run(common+['--create',str(save)],cwd=R,stdout=f,stderr=subprocess.STDOUT,timeout=120)
 assert p.returncode==0 and save.is_file(),(OUT/'create.log').read_text(errors='replace')[-2500:]
names=[]
for facing in ['north','east']:
 names += [facing+'-'+state for state in ['empty-a','empty-b','working','pipe','exhaust','console','stopped-a','stopped-b','restarted','full-a','full-b','load-recovery','starved-a','starved-b','resupplied','cold-steam-a','cold-steam-b','hot-recovered']]
 names += [f'{facing}-motion-{i:02d}' for i in range(32)]
expected=[runtime/'script-output/void-v1'/(n+'.png') for n in names]

def valid_png(p):
 if not p.is_file():return False
 data=p.read_bytes()
 if not data.startswith(b'\x89PNG\r\n\x1a\n'):return False
 i=8
 while i+12<=len(data):
  n=struct.unpack_from('>I',data,i)[0];end=i+12+n
  if end>len(data) or zlib.crc32(data[i+4:i+8+n])!=struct.unpack_from('>I',data,i+8+n)[0]:return False
  if data[i+4:i+8]==b'IEND':return end==len(data)
  i=end
 return False
startup=subprocess.STARTUPINFO();startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=0
log=OUT/'client.log';print('VOID_CLIENT_STARTING expected='+str(len(expected)),flush=True)
with log.open('w') as f:
 p=subprocess.Popen(common+['--load-game',str(save),'--disable-audio','--disable-migration-window'],cwd=R,stdout=f,stderr=subprocess.STDOUT,startupinfo=startup)
 try:
  deadline=time.monotonic()+360
  while time.monotonic()<deadline:
   current=log.read_text(errors='replace');saves=list((runtime/'saves').glob('*void-v1-operated*.zip'))
   if all(valid_png(x) for x in expected) and saves and 'Saving finished' in current:break
   if p.poll() is not None or 'non-recoverable error' in current:break
   time.sleep(.25)
  success=all(valid_png(x) for x in expected) and bool(list((runtime/'saves').glob('*void-v1-operated*.zip')))
 finally:
  if p.poll() is None:
   p.terminate()
   try:p.wait(timeout=10)
   except subprocess.TimeoutExpired:p.kill();p.wait(timeout=10)
receipt={'genuine_client_capture':success,'expected_screenshots':len(expected),'screenshots':[],'owner_visual_approved':False,'native_visual_review_pending':True}
if success:
 for p in expected:shutil.copy2(p,OUT/p.name);receipt['screenshots'].append({'file':p.name,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
 saves=sorted((runtime/'saves').glob('*void-v1-operated*.zip'),key=lambda p:p.stat().st_mtime);shutil.copy2(saves[-1],OUT/'void-v1-operated.zip');receipt['operated_save_sha256']=hashlib.sha256((OUT/'void-v1-operated.zip').read_bytes()).hexdigest()
(OUT/'capture-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8');print('VOID_CLIENT_CAPTURE_RESULT',success,len(receipt['screenshots']),flush=True)
if not success:print(log.read_text(errors='replace')[-4000:]);raise SystemExit(1)
