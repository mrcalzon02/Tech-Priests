"""Coordinate disjoint heading workers and publish only complete capture receipts."""
import subprocess,json,time,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];base=ROOT/'build/artillery-native';source=ROOT/'art/bunker-artillery/candidate-v19/rolling-artillery.blend'
blender=Path('C:/Users/Admin/Documents/Codex/2026-11-07/referenced-chatgpt-conversation-this-is-an/work/blender-5.0.1/blender-5.0.1-windows-x64/blender.exe')
worker=ROOT/'tools/art/artillery_render_worker.py';jobs=[];began=time.monotonic()
def replace_receipt(temp,target):
 for attempt in range(100):
  try:temp.replace(target);return
  except PermissionError:
   if attempt==99:raise
   time.sleep(.05)
for kind,count in (('body',1),('shadow',1)):
 out=base/('animation-v19'if kind=='body'else 'shadows-v19');out.mkdir(parents=True,exist_ok=True)
 old=out/'capture.json'
 if old.exists()and not(out/'capture-monolithic.json').exists():(out/'capture-monolithic.json').write_bytes(old.read_bytes())
 for index in range(count):
  log=(base/f'final-{kind}-{index}.log').open('w');command=[str(blender),'--factory-startup','-b','-t','4','--python-exit-code','12','--python',str(worker),'--',kind,str(index),str(count),str(source),str(out),str(base/('animation-v17'if kind=='body'else 'animation-v19'))]
  if kind=='shadow':command.append(str(base/'shadows-v17'))
  proc=subprocess.Popen(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT);jobs.append((kind,index,out,proc,log))
(base/'final-render-processes.json').write_text(json.dumps({'coordinator_started':time.time(),'workers':[{'kind':kind,'index':index,'pid':proc.pid}for kind,index,out,proc,log in jobs]},indent=2)+'\n')
last=None
try:
 while True:
  counts={};finished=True
  for kind in ('body','shadow'):
   members=[job for job in jobs if job[0]==kind];complete=set();receipts=[]
   for _,index,out,proc,log in members:
    if proc.poll()is None:finished=False
    elif proc.returncode:raise RuntimeError(f'{kind} worker {index} failed; inspect its final worker log')
    path=out/f'capture-worker-{kind}-{index}.json'
    if path.exists():
     try:r=json.loads(path.read_text())
     except json.JSONDecodeError:continue
     complete.update(r['completed_headings']);receipts.append(r)
   if receipts:
    identity=receipts[0]['identity'];assert all(r['identity']==identity for r in receipts)
    result={'status':'COMPLETE'if len(complete)==64 else 'RUNNING','identity':identity,'completed_headings':sorted(complete),
      'elapsed_seconds':time.monotonic()-began,'workers':len(members),'worker_driver_sha256':hashlib.sha256(worker.read_bytes()).hexdigest()}
    temp=out/'capture.coordinator.json';temp.write_text(json.dumps(result,indent=2)+'\n');replace_receipt(temp,out/'capture.json')
   counts[kind]=len(complete)
  if counts!=last:print('ARTILLERY_FINAL_RENDER',counts,round(time.monotonic()-began),flush=True);last=counts
  if finished:assert counts=={'body':64,'shadow':64};break
  time.sleep(2)
finally:
 for _,_,_,proc,log in jobs:
  if proc.poll()is None:proc.terminate()
  proc.wait(timeout=15);log.close()
print('ARTILLERY_FINAL_ALL_64_BODY_AND_SHADOW_COMPLETE',flush=True)
