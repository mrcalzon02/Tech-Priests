"""Fresh native contact, center-flow and source-integrity audit for V16."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import bpy
from mathutils import Vector

sys.path.insert(0,str(Path(__file__).resolve().parent))
from refine_process import hash_original_meshes
from verify_purifier_v14 import gap
from refine_purifier_v14 import tree,bounds
from pipe_bore_clearance import verify_bores
from camera_profile import audit_scene

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--dir',required=True)
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]); out=Path(args.dir).resolve()
    source=out/'water-purifier-v16.blend'; receipt=json.loads((out/'service-fit-receipt.json').read_text())
    bpy.ops.wm.open_mainfile(filepath=str(source)); s=bpy.context.scene; s.frame_set(25)
    meshes=[o for o in s.objects if o.type=='MESH' and not o.hide_render]
    originals=[o for o in s.objects if o.type=='MESH' and o.name.startswith(('MH7_','FMPL_PROCESS |'))]
    errors=[]
    if hash_original_meshes(originals)!=receipt['source_geometry_digest']: errors.append('source mesh integrity')
    camera=audit_scene(s,bpy); bores=verify_bores(s)
    if not bores['passed']: errors.append('external pipe bores')
    contacts=[]
    for row in receipt['endpoint_ledger']:
        if row['receiver'] is None:
            contacts.append(dict(route=row['route'],end=row['end'],status='intentional open gravity outlet',passed=True))
            continue
        names=[row['receiver']] if isinstance(row['receiver'],str) else row['receiver']
        targets=[]
        for name in names:
            ob=bpy.data.objects[name]
            if ob.hide_render:
                derived=[v for v in meshes if v.get('derives_from')==name]
                if len(derived)==1: ob=derived[0]
            targets.append(ob)
        parts=[bpy.data.objects[n] for n in row['fittings']]
        distance=min(gap(a,b) for a in parts for b in targets)
        contacts.append(dict(route=row['route'],end=row['end'],receivers=[v.name for v in targets],
                             gap_tiles=distance,passed=distance<=.015))
    if any(not x['passed'] for x in contacts): errors.append('service fitting contact')
    b= bounds(meshes)
    if min(b[0][:2]) < -1.501 or max(b[1][:2]) >1.501: errors.append('3x3 visual footprint')
    legacy=[o.name for o in meshes if 'FMPL_PROCESS |' in o.name and ' / section ' in o.name]
    expected=('manifold to mounted intake pump','pump to first vertical filter',
              'first filter to second filter','second filter to central treatment inlet',
              'treatment outlet to clean discharge reducer')
    unclassified_legacy=[n for n in legacy if not any(t in n for t in expected)]
    if unclassified_legacy: errors.append('superseded service route still visible')
    # Probe the actual stored swept center line against every visible mesh.
    # Named receiver contacts are allowed within .13 tile of endpoints only;
    # distant crossings through hardware remain failures, never auto-whitelisted.
    cache={o.name:tree(o) for o in meshes}
    blockers=[]; probes=0
    routes=[bpy.data.objects[n] for n in receipt['new_hollow_routes']]
    for route in routes:
        centers=[Vector(p) for p in route.get('flow_path_samples',[])]
        if not centers:
            blockers.append(dict(route=route.name,reason='missing actual sweep samples')); continue
        for a,z in zip(centers,centers[1:]):
            direction=z-a; length=direction.length
            if length<1e-6: continue
            direction.normalize(); probes+=1
            for ob in meshes:
                if ob==route: continue
                # Fluids and steam occupy their process space by design. They
                # are not metal/structural obstructions to the flow centre.
                mats=[m.name.lower() for m in ob.data.materials if m]
                if mats and all(any(t in n for t in ('water','liquid','foam','steam','bubble')) for n in mats): continue
                hit=cache[ob.name].ray_cast(a+direction*.00001,direction,max(length-.00002,0))
                if hit[0] is None: continue
                point=hit[0]
                if min((point-centers[0]).length,(point-centers[-1]).length)<=.13: continue
                blockers.append(dict(route=route.name,obstruction=ob.name,point=list(point)))
    if blockers: errors.append('service flow center obstruction or missing probe')
    report=dict(status='PASS_TARGETED_SERVICES' if not errors else 'FAIL',errors=errors,
        source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),source_integrity='source mesh integrity' not in errors,
        camera=camera,external_bores=bores,bounds=b,service_contacts=contacts,
        centerline_probes=probes,flow_blockers=blockers,visible_legacy_primary_lines=legacy,
        unclassified_legacy_lines=unclassified_legacy,
        pending=['full inner-core clearance and support contact audit','remaining actual socket/fixture classification',
                 'native prototype and graphical pipe jig','owner finish review'])
    (out/'service-independent-readback.json').write_text(json.dumps(report,indent=2)+'\n')
    print('SERVICE_READBACK',report['status'],errors,flush=True)
    if errors: raise RuntimeError('Inspect service-independent-readback.json; do not promote')

if __name__=='__main__': main()
