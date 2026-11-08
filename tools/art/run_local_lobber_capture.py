"""Bounded local A02 capture controller. No network, Actions, or gameplay work.

One worker per heading protects the established renderer's per-heading temp files.
Every process exit is inspected; partial valid poses resume through the renderer.
"""
import argparse,hashlib,json,os,pathlib,subprocess,sys,time
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--pipeline',type=pathlib.Path,required=True);p.add_argument('--cache',type=pathlib.Path,required=True);p.add_argument('--blender',type=pathlib.Path,required=True);p.add_argument('--workers',type=int,default=4);p.add_argument('--seed-ready',type=pathlib.Path,required=True);p.add_argument('--optix-setup',type=pathlib.Path);a=p.parse_args()
assert 1<=a.workers<=4
P=a.pipeline.resolve();R=a.cache.resolve();R.mkdir(parents=True,exist_ok=True);logs=R/'worker-logs';logs.mkdir(exist_ok=True);sys.path.insert(0,str(P));import recover_export as recovery
identity=recovery.expected_identity();assert hashlib.sha256((P/'lobber_capture.blend').read_bytes()).hexdigest()==identity['source_sha256']
config=json.loads((P/'capture_config.json').read_text());assert (config['direction_count'],config['frames_per_direction'],config['chunk_frames'],config['entry_frames'],config['settle_frames'])==(64,192,32,15,15),'Different capture contract: audit before queueing'
priority=[16,48,24,40,8,56,0,32]+[d for d in range(64) if d not in [16,48,24,40,8,56,0,32]]
pending=[(d,c) for c in range(6) for d in priority];live={};completed={};failures={};started=time.time();seeded=False;prior_files={}
profile={'backend':'CPU','new_frame_setup_sha256':None}
if a.optix_setup:profile={'backend':'OPTIX','compositor':'CPU','new_frame_setup_sha256':hashlib.sha256(a.optix_setup.read_bytes()).hexdigest(),'new_frames_only':True}
def complete(d,c):
    ip=R/f'd{d:02}'/'identity.json'
    if not ip.exists():return False
    assert json.loads(ip.read_text())==identity,'Capture identity mismatch'
    for pas,name in recovery.chunk_paths(d,c):
        f=R/name
        try:
            if not f.exists() or not recovery.valid(f.read_bytes(),pas):return False
        except Exception:return False
    return True
def checkpoint(status):
    state={'schema':3,'status':status,'manager_pid':os.getpid(),'started_unix':started,'source_identity':identity,'execution_profile_for_new_frames':profile,'target':{'headings':64,'chunks_per_heading':6,'three_pass_poses':14272,'png_images':42816},'seed_ready':a.seed_ready.exists(),'artifact_import_pause':(R/'artifact-import.lock').exists(),'completed_chunks':sorted(completed),'completed_count':len(completed),'pending_count':len(pending),'live_jobs':[{'direction':d,'chunk':c,'pid':v[0].pid,'started_unix':v[2],'log':str(v[3])} for (d,c),v in live.items()],'terminal_failures':failures}
    temp=R/'local-capture-state.tmp';temp.write_text(json.dumps(state,indent=2)+'\n');temp.replace(R/'local-capture-state.json')
while pending or live:
    if a.seed_ready.exists() and not seeded:
        # Import is finished. Only now scan imported headings for reusable chunks.
        for d,c in list(pending):
            if complete(d,c):completed[f'd{d:02}-c{c:02}']='verified seeded frames';pending.remove((d,c))
        seeded=True
    for key,(process,handle,when,log) in list(live.items()):
        rc=process.poll()
        if rc is None:continue
        handle.close();del live[key];d,c=key
        if rc==0 and complete(d,c):
            files=[]
            for _,name in recovery.chunk_paths(d,c):
                digest=hashlib.sha256((R/name).read_bytes()).hexdigest();files.append({'path':name,'sha256':digest,'retained_preexisting_bytes':prior_files.get(key,{}).get(name)==digest})
            (R/f'd{d:02}'/f'local-verified-chunk-{c:02}.json').write_text(json.dumps({'identity':identity,'execution_profile_for_new_frames':profile,'direction':d,'chunk':c,'files':files},indent=2)+'\n');completed[f'd{d:02}-c{c:02}']='verified local capture';print('CHUNK_COMPLETE',d,c,flush=True)
        else:
            tag=f'd{d:02}-c{c:02}';failures[tag]={'attempts':failures.get(tag,{}).get('attempts',0)+1,'exit_code':rc,'log':str(log)}
            if failures[tag]['attempts']<3:pending.append(key)
            else:checkpoint('failed_checkpoint_preserved');raise RuntimeError('Three terminal failures: '+tag)
    active={d for d,c in live}
    for key in list(pending):
        if len(live)>=a.workers:break
        d,c=key
        lock=R/'artifact-import.lock'
        if lock.exists():
            try:held=set(json.loads(lock.read_text())['held_headings'])
            except (ValueError,KeyError,TypeError):break
            if d in held:continue
        if d in active:continue
        # Only these headings have no original full-chunk artifacts. Avoid import
        # races until all existing artifacts have been verified and seeded.
        if not seeded and (d not in [16,48,24,40] or c!=0):continue
        if complete(d,c):completed[f'd{d:02}-c{c:02}']='verified existing frames';pending.remove(key);continue
        ip=R/f'd{d:02}';ip.mkdir(exist_ok=True);log=logs/f'd{d:02}-c{c:02}-attempt{failures.get(f"d{d:02}-c{c:02}",{}).get("attempts",0)+1}.log';handle=log.open('wb')
        prior_files[key]={name:hashlib.sha256((R/name).read_bytes()).hexdigest() for _,name in recovery.chunk_paths(d,c) if (R/name).exists()}
        command=[str(a.blender.resolve()),'--factory-startup','-b',str(P/'lobber_capture.blend'),'-t','4','--python-exit-code','12']
        if a.optix_setup:command+=['--python',str(a.optix_setup.resolve())]
        command+=['--python',str(P/'render_capture.py'),'--','--direction',str(d),'--chunk',str(c),'--out',str(R)]
        process=subprocess.Popen(command,stdout=handle,stderr=subprocess.STDOUT);live[key]=(process,handle,time.time(),log);active.add(d);pending.remove(key);print('LOCAL_WORKER_STARTED',d,c,process.pid,flush=True)
    checkpoint('rendering' if live else 'waiting_for_verified_seed')
    if pending or live:time.sleep(10)
checkpoint('all_384_chunks_complete');print('ALL_LOCAL_A02_CHUNKS_COMPLETE',flush=True)
