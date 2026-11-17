"""Partition the unchanged capture algorithm by heading; never share PNG writers."""
import sys,json,hashlib,time
from pathlib import Path
arguments=sys.argv[sys.argv.index('--')+1:];kind,index,count=arguments[:3];index,count=int(index),int(count)
source,out,capture=arguments[3:6]
script=Path(__file__).with_name('capture_artillery_animation.py'if kind=='body'else 'capture_artillery_shadows.py')
cache=arguments[6]if len(arguments)>6 else None
sys.argv=[str(script),'--',source,out,capture]if kind=='shadow'else [str(script),'--',source,out,capture]
if kind=='shadow'and cache:sys.argv.append(cache)
code=script.read_text();order="[0,16,32,48]+[d for d in range(64) if d not in (0,16,32,48)]"
if kind=='shadow':order="[0,16,32,48]+[d for d in range(64)if d not in (0,16,32,48)]"
assert order in code
code=code.replace(order,'[d for d in '+order+' if d % '+str(count)+' == '+str(index)+']')
if kind=='body':
 marker='for d in directions:\n    restore()'
 replacement="""for d in directions:
    if all((out/f'd{d:02}-{layer}-{i:03}.png').exists() for layer in ('body','shell0','shell1','shell2') for i in range(len(ticks))):
        completed.append(d);receipt('PILOT_READY');continue
    restore()"""
 assert marker in code;code=code.replace(marker,replacement)
receipt=f'capture-worker-{kind}-{index}.json';code=code.replace("'capture.json'",repr(receipt)).replace("'capture.next.json'",repr(receipt+'.next'))
code=code.replace("receipt('COMPLETE')","receipt('WORKER_COMPLETE')").replace('ARTILLERY_ANIMATION_ALL_64_COMPLETE','ARTILLERY_ANIMATION_WORKER_COMPLETE')
code=code.replace("temp.replace(out/"+repr(receipt)+")","safe_replace(temp,out/"+repr(receipt)+")")
def safe_replace(temp,target):
 for attempt in range(100):
  try:temp.replace(target);return
  except PermissionError:
   if attempt==99:raise
   time.sleep(.05)
driver_hash=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
namespace={'__name__':'__main__','__file__':str(script),'safe_replace':safe_replace};exec(compile(code,str(script),'exec'),namespace)
path=Path(out)/receipt;r=json.loads(path.read_text());r.update(status='WORKER_COMPLETE',worker_index=index,worker_count=count,
 worker_driver_sha256=driver_hash,canonical_algorithm_sha256=hashlib.sha256(script.read_bytes()).hexdigest())
path.write_text(json.dumps(r,indent=2)+'\n')
