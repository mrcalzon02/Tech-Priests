from pathlib import Path
if (Path(__file__).resolve().parent/'OWNER_DIRECTED_MOVE_ON.json').exists():raise SystemExit('OWNER_DIRECTED_MOVE_ON: no more capture attempts')
from pathlib import Path
import subprocess,json,shutil,time,struct,zlib,hashlib
R=Path(__file__).resolve().parent;M=R.parent/'tp-sterling-contract-main01/mods';OUT=R/'native-client';OUT.mkdir(exist_ok=True);runtime=R/'client-runtime';runtime.mkdir(exist_ok=True);config=R/'client-config.ini';config.write_text('[path]\nread-data=C:/Program Files (x86)/Steam/steamapps/common/Factorio/data\nwrite-data='+str(runtime)+'\n[graphics]\nfull-screen=false\n')
d=M/'entropic-capture_0.0.1';d.mkdir(exist_ok=True);(d/'info.json').write_text(json.dumps({'name':'entropic-capture','version':'0.0.1','title':'Entropic native capture','author':'local','factorio_version':'2.1','dependencies':['base','space-age','tech-priests','entropic-contract']}));(d/'control.lua').write_text("script.on_init(function()remote.call('entropic_capture','enable')end)\n")
p=M/'mod-list.json';mods=json.loads(p.read_text());mods['mods']=[x for x in mods['mods']if x['name']!='entropic-capture'];mods['mods'].append({'name':'entropic-capture','enabled':True});p.write_text(json.dumps(mods))
B='C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe';args=[B,'--config',str(config),'--mod-directory',str(M)];save=OUT/'entropic-client-fresh.zip'
with (OUT/'create.log').open('w')as f:r=subprocess.run(args+['--create',str(save)],stdout=f,stderr=subprocess.STDOUT,cwd=R)
assert r.returncode==0
names=[]
for d in(0,4,8,12):
 names+=[f'd{d}-{s}.png'for s in('empty-a','empty-b','working','stopped-a','stopped-b','restarted','blocked-a','blocked-b','output-released','completed')]
 names+=[f'd{d}-motion-{k:02d}{suffix}.png'for k in range(32)for suffix in('','-fan')]
files=[runtime/'script-output/entropic-native'/n for n in names]
def valid(p):
 if not p.is_file()or p.stat().st_mtime<run_started:return False
 b=p.read_bytes();i=8
 if b[:8]!=b'\x89PNG\r\n\x1a\n':return False
 while i+12<=len(b):
  n=struct.unpack_from('>I',b,i)[0];e=i+12+n
  if e>len(b)or zlib.crc32(b[i+4:i+8+n])!=struct.unpack_from('>I',b,i+8+n)[0]:return False
  if b[i+4:i+8]==b'IEND':return e==len(b)
  i=e
 return False
run_started=time.time()
with (OUT/'client.log').open('w')as f:
 p=subprocess.Popen(args+['--load-game',str(save),'--disable-audio','--disable-migration-window','--graphics-quality','medium','--video-memory-usage','low'],stdout=f,stderr=subprocess.STDOUT,cwd=R)
 try:
  deadline=time.monotonic()+180
  while time.monotonic()<deadline:
   log=(OUT/'client.log').read_text(errors='replace')
   if all(valid(x)for x in files)and'ENTROPIC_NATIVE_OPERATIONAL_PASS'in log:break
   if p.poll()is not None or'non-recoverable error'in log:break
   time.sleep(.5)
  passed=all(valid(x)for x in files)and'ENTROPIC_NATIVE_OPERATIONAL_PASS'in log
 finally:
  if p.poll()is None:p.terminate();p.wait(timeout=15)
receipt={'genuine_client_capture':passed,'expected':len(files),'screenshots':[],'owner_visual_approved':False,'engine_graphics_quality':'medium','full_resolution_delivery_sprites_changed':False}
for p in files:
 if valid(p):shutil.copy2(p,OUT/p.name);receipt['screenshots'].append({'file':p.name,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
for src in(runtime/'script-output/entropic-operation').glob('*.json'):shutil.copy2(src,OUT/('client-'+src.name))
(OUT/'capture-receipt.json').write_text(json.dumps(receipt,indent=2));print('ENTROPIC_NATIVE_CLIENT_CAPTURE',passed,len(receipt['screenshots']),flush=True);assert passed
