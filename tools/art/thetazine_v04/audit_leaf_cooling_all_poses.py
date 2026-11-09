import pathlib,argparse,json,hashlib,subprocess,concurrent.futures,os
p=argparse.ArgumentParser();p.add_argument('study',type=pathlib.Path);p.add_argument('--blender',type=pathlib.Path,required=True);a=p.parse_args();R=a.study.resolve();W=pathlib.Path(__file__).resolve().parent;sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();native=sha(R/'thetazine-v04-regenerative-study.blend');auditor=sha(W/'audit_leaf_cooling_clearance.py');state={'status':'AUDITING_EVALUATED_COOLING_66_POSES','pid':os.getpid(),'native_sha256':native,'auditor_sha256':auditor,'poses':[]}
def run(f):
 dest=R/f'leaf-cooling-clearance-frame-{f:02}.json'
 if dest.exists():
  old=json.loads(dest.read_text());assert old['native_sha256']==native and old['auditor_sha256']==auditor;return old
 with (R/f'leaf-cooling-clearance-frame-{f:02}.log').open('wb') as log:
  cp=subprocess.run([str(a.blender.resolve()),'--factory-startup','--background','--threads','2','--python-exit-code','12','--python',str(W/'audit_leaf_cooling_clearance.py'),'--',str(R),'--frame',str(f)],stdout=log,stderr=subprocess.STDOUT)
 if not dest.exists():raise RuntimeError(f'Pose{f} failed without audit receipt, returncode{cp.returncode}; inspect its log before any retry.')
 return json.loads(dest.read_text())
rows=[]
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
 for row in pool.map(run,range(66)):
  rows.append(row);state['poses'].append({'frame':row['frame'],'status':row['status'],'violations':len(row['violations']),'ambiguous':len(row['ambiguous_closed_solid_samples']),'receipt_sha256':sha(R/f"leaf-cooling-clearance-frame-{row['frame']:02}.json")});(R/'leaf-cooling-audit-progress.json').write_text(json.dumps(state,indent=2)+'\n',encoding='utf-8',newline='\n')
bad=[v for v in state['poses'] if not v['status'].startswith('PASS')];state.update(status='PASS_EVALUATED_84_FLUID_ROUTES_66_POSES' if not bad else 'FAIL_EVALUATED_COOLING_CLEARANCE',failed_poses=bad,all_fluid_routes=84,new_cooling_routes=38,mesh_pairs_checked=sum(r['mesh_pairs_checked'] for r in rows),scope=rows[0]['scope']);(R/'leaf-cooling-clearance-validation.json').write_text(json.dumps(state,indent=2)+'\n',encoding='utf-8',newline='\n');print(state['status'],len(bad));raise SystemExit(1 if bad else 0)
