"""Independently reopen/import each real cache; preserve the shared wall exactly."""
import json,hashlib,sys
from pathlib import Path
import bpy
R=Path(__file__).resolve().parents[3];B=R/'art/source-to-3d/filtered-stone-caches/v01';catalog=json.loads((B/'catalog.json').read_text());p=R/'tools/art/conclave/inspect.py';base=p.read_text();results=[]
for row in catalog['rows']:
 if '--only' in sys.argv and row['key'] not in sys.argv[sys.argv.index('--only')+1].split(','):
  q=R/row['path'];receipt=json.loads((q/'inspection.json').read_text());assert receipt['source_sha256']==hashlib.sha256((q/(row['stem']+'.blend')).read_bytes()).hexdigest();results.append(dict(key=row['key'],passed=receipt['passed']));continue
 O=R/row['path'];src=base.replace("R/'art/source-to-3d/conclave-center/v01'",'Path('+repr(str(O))+')').replace("STEM='conclave-center-'+O.name.split('-')[0]",'STEM='+repr(row['stem'])).replace('CONCLAVE_INSPECTION','FILTERED_CACHE_INSPECTION').replace("clay.diffuse_color=(.35,.35,.35,1);","clay.use_nodes=True;clay.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.3,.3,.3,1);")
 try:exec(compile(src,str(p),'exec'),{'__file__':__file__});results.append(dict(key=row['key'],passed=True))
 except RuntimeError as exc:results.append(dict(key=row['key'],passed=False,error=str(exc)))
 print('FILTERED_CACHE_INDEPENDENT_RESULT',results[-1],flush=True)
(B/'batch-inspection.json').write_text(json.dumps(dict(passed=all(r['passed'] for r in results),results=results),indent=2)+'\n');assert all(r['passed'] for r in results)
