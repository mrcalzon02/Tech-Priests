"""Run pinned fusion capture with fresh renderer processes per lane.

Cycles/static-energy and Eevee/volume never share a rendered Blender process.
Existing matching receipts resume; changed inputs still require a new output.
"""
import argparse,datetime,hashlib,json,pathlib,shutil,subprocess,sys,time
HERE=pathlib.Path(__file__).resolve().parent
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--profile',type=pathlib.Path,required=True);p.add_argument('--out',type=pathlib.Path,required=True);p.add_argument('--blender',type=pathlib.Path,default=pathlib.Path('C:/Program Files/Blender Foundation/Blender 5.0/blender.exe'));p.add_argument('--frames',default='all');p.add_argument('--lanes',default='static,energy,field');p.add_argument('--timeout',type=int,default=1800);a=p.parse_args();R=a.out.resolve();R.mkdir(parents=True,exist_ok=True)
sha=lambda f:hashlib.sha256(pathlib.Path(f).read_bytes()).hexdigest();stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ');logdir=R/'runner-logs'/stamp;logdir.mkdir(parents=True);snapshot=logdir/'tooling';snapshot.mkdir();copies={}
for name in('capture.py','package.py','particle_plume.py','electric_arcs.py','emitter_energy.py','run_capture.py'):
 shutil.copy2(HERE/name,snapshot/name);copies[name]=sha(HERE/name)
startup=None
if sys.platform=='win32':
 startup=subprocess.STARTUPINFO();startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=0
render_threads=int(json.loads(a.profile.read_text()).get('render_threads',2));assert 1<=render_threads<=32
base=[str(a.blender.resolve()),'--factory-startup','--background','--threads',str(render_threads),'--python-exit-code','12','--python',str(HERE/'capture.py'),'--']
commands=[('prepare',base+['prepare','--profile',str(a.profile.resolve()),'--out',str(R)])]
lanes=set(a.lanes.split(','));assert lanes.issubset({'static','energy','field'})
for lane,layers in [('static','cold_body,cold_light,shadow,underlay'),('energy','working_light'),('field','field')]:
 if lane in lanes:commands.append((lane,base+['capture','--profile',str(a.profile.resolve()),'--out',str(R),'--frames',a.frames,'--layers',layers]))
commands.append(('package',[sys.executable,str(HERE/'package.py'),str(R)]+(['--allow-partial']if a.frames!='all'else[])))
receipt={'profile':str(a.profile.resolve()),'profile_sha256':sha(a.profile),'tooling':copies,'fresh_process_per_lane':True,'steps':[],'status':'RUNNING'}
for phase,cmd in commands:
 log=logdir/(phase+'.log');start=time.monotonic();print('CAPTURE_STAGE',phase,flush=True)
 with log.open('w',encoding='utf-8')as output:result=subprocess.run(cmd,stdout=output,stderr=subprocess.STDOUT,startupinfo=startup,timeout=a.timeout)
 row={'phase':phase,'argv':cmd,'exit_code':result.returncode,'elapsed_seconds':time.monotonic()-start,'log':log.relative_to(R).as_posix(),'log_sha256':sha(log)};receipt['steps'].append(row)
 if result.returncode:
  receipt['status']='FAILED_'+phase.upper();(logdir/'runner-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print(log.read_text(errors='replace')[-2400:]);raise SystemExit(result.returncode)
receipt['status']='COMPLETED_SELECTED_PILOT_STAGES_REQUIRES_REVIEW'if a.frames!='all'else'COMPLETED_CAPTURE_PACKAGE_REQUIRES_NATIVE_REVIEW';(logdir/'runner-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print(receipt['status'],flush=True)
