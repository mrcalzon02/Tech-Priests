"""Reopen and measure actual hose terminal rings, cross sections and support seats."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import bpy
import numpy as np
from mathutils import Matrix, Vector

p=argparse.ArgumentParser()
for n in ('baseline','source','audit','base_manifest','out'):p.add_argument('--'+n.replace('_','-'),type=Path,required=True)
a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
for k,v in vars(a).items():setattr(a,k,v.resolve())
sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
audit=json.loads(a.audit.read_text(encoding='utf-8'));base=json.loads(a.base_manifest.read_text(encoding='utf-8'))
routes=[r for r in audit['routes']if r['retarget']=='CROSS_BOUNDARY_REBAKE']
supports={n:r for n,r in audit['additional_core_flex_supports'].items()if n.startswith(('V04 injector bridge support','V04 pump bed front seat'))}

def vertices(o):
    ev=o.evaluated_get(bpy.context.evaluated_depsgraph_get());me=ev.to_mesh()
    coords=np.asarray([o.matrix_world@v.co for v in me.vertices],dtype=np.float64);ev.to_mesh_clear();return coords

def uv(o):return np.asarray([v.uv[:]for v in o.data.uv_layers.active.data],dtype=np.float32)
def polys(o):return [tuple(p.vertices)for p in o.data.polygons]

bpy.ops.wm.open_mainfile(filepath=str(a.baseline));bpy.context.scene.frame_set(0);bpy.context.view_layer.update()
original={}
for n in [r['name']for r in routes]+list(supports):
    o=bpy.data.objects[n];original[n]={'coords':vertices(o),'uv':uv(o),'faces':polys(o),'materials':[m.name for m in o.data.materials]}
host_rest={e['host']:bpy.data.objects[e['host']].matrix_world.copy()for r in routes for e in r['ends']}
core_rest=bpy.data.objects['V04 independently suspended engine core'].matrix_world.copy()
fixed_rest=bpy.data.objects['V04 engine structural recoil frame'].matrix_world.copy()
socket_local={(r['name'],e['side']):host_rest[e['host']].inverted()@Vector(e['reference_world'])for r in routes for e in r['ends']}
setup={}
for r in routes:
    n=r['name'];raw=original[n]['coords'].reshape(43,10,3);centers=raw.mean(axis=1)
    # Actual cap rings are disconnected from body rings; both copies must stay seated.
    groups=[]
    for e in r['ends']:
        gap=np.linalg.norm(centers-np.asarray(e['reference_world']),axis=1)
        ids=np.flatnonzero(gap<2e-6).tolist();assert len(ids)==2,(n,e['side'],ids)
        groups.append(ids)
    setup[n]={'groups':groups,'radii':np.linalg.norm(raw-centers[:,None,:],axis=2)}

bpy.ops.wm.open_mainfile(filepath=str(a.source));s=bpy.context.scene
for n,r in original.items():
    o=bpy.data.objects[n]
    assert np.array_equal(uv(o),r['uv'])and polys(o)==r['faces']and [m.name for m in o.data.materials]==r['materials'],('Source sweep changed',n)
rows=[];first={};wrap=0.;support_error=0.
for f in range(66):
    s.frame_set(f);bpy.context.view_layer.update()
    core=bpy.data.objects['V04 independently suspended engine core'];D=core.matrix_world@core_rest.inverted()
    fixed=bpy.data.objects['V04 engine structural recoil frame']
    assert max(abs(fixed.matrix_world[i][j]-fixed_rest[i][j])for i in range(4)for j in range(4))<1e-8
    for r in routes:
        n=r['name'];actual=vertices(bpy.data.objects[n]);rings=actual.reshape(43,10,3);centers=rings.mean(axis=1)
        gaps=[]
        for e,groups in zip(r['ends'],setup[n]['groups']):
            target=np.asarray(bpy.data.objects[e['host']].matrix_world@socket_local[(n,e['side'])])
            gaps.extend(float(np.linalg.norm(centers[k]-target))for k in groups)
        radii=np.linalg.norm(rings-centers[:,None,:],axis=2)
        radius_error=float(np.max(np.abs(radii-setup[n]['radii'])))
        assert max(gaps)<2e-5 and radius_error<2e-6,(f,n,gaps,radius_error)
        rows.append({'frame':f,'mesh':n,'maximum_actual_captive_union_gap':max(gaps),'maximum_radius_change':radius_error})
        if f==1:first[n]=actual
        if f==65:wrap=max(wrap,float(np.max(np.linalg.norm(actual-first[n],axis=1))))
    for n,r in supports.items():
        actual=vertices(bpy.data.objects[n]);old=original[n]['coords'];mobile=n.startswith('V04 injector bridge support')
        if not mobile:error=float(np.max(np.linalg.norm(actual-old,axis=1)))
        else:
            fixed=np.asarray(r['fixed_end']);moving=np.asarray(r['moving_end']);axis=moving-fixed
            t=(old-fixed)@axis/float(axis@axis)
            fixed_ids=np.flatnonzero(t<=.18+1e-6);moving_ids=np.flatnonzero(t>=.82-1e-6)
            assert len(moving_ids),(n,'No moving seat')
            expected=np.asarray([D@Vector(c)for c in old[moving_ids]])
            error=float(np.max(np.linalg.norm(actual[moving_ids]-expected,axis=1)))
            if len(fixed_ids):error=max(error,float(np.max(np.linalg.norm(actual[fixed_ids]-old[fixed_ids],axis=1))))
        assert error<2e-5,('Support seat left host',f,n,error)
        support_error=max(support_error,error)
assert wrap<1e-6
report={'status':'PASS_EIGHT_HOSES_AND_EIGHT_SUPPORT_SEATS_66_REOPENED_SOURCE_POSES',
        'source':{'path':str(a.source),'sha256':sha(a.source)},'baseline_sha256':sha(a.baseline),'script_sha256':sha(Path(__file__)),
        'measured_hose_poses':len(rows),'measured_support_poses':len(supports)*66,
        'max_captive_union_gap':max(r['maximum_actual_captive_union_gap']for r in rows),
        'max_radius_change':max(r['maximum_radius_change']for r in rows),'max_support_seat_error':support_error,
        'working_loop_max_error':wrap,'topology_materials_uvs_unchanged':True,'measurements':rows,
        'scope':'Actual reopened source terminal-ring centers including duplicate caps; invariant tube cross sections; fixed and moving support terminal vertices. Actual GLB and swept collision checks separate.'}
a.out.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8');print(report['status'],report['max_captive_union_gap'],support_error,flush=True)
