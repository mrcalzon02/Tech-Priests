"""Rebind existing hose sweeps to their actual fixed/core socket frames.

Pipette validates the typed socket/centerline contract for every authored pose.
Existing tube topology, diameters, UVs, materials and captive unions are retained;
this is an animation rebind, not a second set of connector hardware.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector

p=argparse.ArgumentParser()
for name in ('source','motion','audit','base_manifest','out'):
    p.add_argument('--'+name.replace('_','-'),type=Path,required=True)
a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
for k,v in vars(a).items():setattr(a,k,v.resolve())
sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
repo=Path(__file__).resolve().parents[3]
module=repo/'tools/fmpl/pipette'
module_pins={n:sha(module/n)for n in ('core.py','PIPETTE_STANDARD.md','type_registry.json')}
spec=importlib.util.spec_from_file_location('v06_pipette_core',module/'core.py')
pipette=importlib.util.module_from_spec(spec);spec.loader.exec_module(pipette)
audit=json.loads(a.audit.read_text(encoding='utf-8'))
motion=json.loads(a.motion.read_text(encoding='utf-8'))
base=json.loads(a.base_manifest.read_text(encoding='utf-8'))
a.out.mkdir(parents=True,exist_ok=False)
bpy.ops.wm.open_mainfile(filepath=str(a.source))
s=bpy.context.scene;s.frame_set(0);bpy.context.view_layer.update()
core=bpy.data.objects[motion['moving_root']]
rest_core=core.matrix_world.copy()
routes=[r for r in audit['routes']if r['retarget']=='CROSS_BOUNDARY_REBAKE']
assert len(routes)==8


def world_basis(o):
    key=o.data.shape_keys.key_blocks[0] if o.data.shape_keys else None
    return [o.matrix_world@v.co for v in (key.data if key else o.data.vertices)]


def linear_keys(data):
    if not data.animation_data or not data.animation_data.action:return
    action=data.animation_data.action
    try:curves=list(action.fcurves)
    except AttributeError:
        curves=[fc for layer in action.layers for strip in layer.strips
                for bag in strip.channelbags for fc in bag.fcurves]
    for fc in curves:
        for key in fc.keyframe_points:key.interpolation='LINEAR'


def bake(o,poses):
    inv=o.matrix_world.inverted()
    if o.data.shape_keys:o.shape_key_clear()
    o.data.vertices.foreach_set('co',np.asarray([inv@v for v in poses[0]],dtype=np.float32).reshape(-1))
    o.shape_key_add(name='Basis')
    keys=[]
    for f in range(1,65):
        key=o.shape_key_add(name=f'V06 interface pose {f:02}')
        key.data.foreach_set('co',np.asarray([inv@v for v in poses[f]],dtype=np.float32).reshape(-1))
        keys.append(key)
    for f in range(66):
        for i,key in enumerate(keys,1):
            key.value=float(i==((f-1)%64)+1)if f else 0
            key.keyframe_insert('value',frame=f)
    linear_keys(o.data.shape_keys);o.data.update()


stored={};route_setup={};support_setup={}
for r in routes:
    o=bpy.data.objects[r['name']];coords=world_basis(o)
    # Converted original bevel curves have43 complete10-sided section rings.
    assert len(coords)==430,(o.name,len(coords))
    raw_rings=[coords[k:k+10]for k in range(0,len(coords),10)]
    # Blender's converted/triangulated curve stores its two cap rings first.
    # Recover longitudinal order from actual triangle adjacency, never index order.
    graph={k:set()for k in range(len(raw_rings))}
    for face in o.data.polygons:
        groups=set(v//10 for v in face.vertices)
        assert len(groups)<=2,(o.name,groups)
        if len(groups)==2:
            u,v=groups;graph[u].add(v);graph[v].add(u)
    cap_ids=[k for k,v in graph.items()if not v]
    terminal=[k for k,v in graph.items()if len(v)==1]
    assert len(terminal)==len(cap_ids)==2 and all(len(v)in(0,1,2)for v in graph.values()),o.name
    order=[terminal[0]]
    while len(order)<len(raw_rings)-len(cap_ids):
        nxt=graph[order[-1]]-set(order)
        assert len(nxt)==1,(o.name,order,nxt)
        order.append(nxt.pop())
    rings=[raw_rings[k]for k in order]
    centers=[sum(row,Vector())/10 for row in rings]
    ends=r['ends']
    start=Vector(ends[0]['reference_world']);end=Vector(ends[1]['reference_world'])
    err_forward=(centers[0]-start).length+(centers[-1]-end).length
    err_reverse=(centers[-1]-start).length+(centers[0]-end).length
    assert min(err_forward,err_reverse)<2e-5,(o.name,err_forward,err_reverse)
    reverse=err_reverse<err_forward
    if reverse:rings.reverse();centers.reverse();order.reverse()
    distances=[0.]
    for u,v in zip(centers,centers[1:]):distances.append(distances[-1]+(v-u).length)
    weights=[]
    for d in distances:
        t=max(0.,min(1.,(d/distances[-1]-.18)/.64));weights.append(t*t*(3-2*t))
    host_frames=[]
    for e in ends:
        host=bpy.data.objects[e['host']]
        host_frames.append({'host':host,'point':host.matrix_world.inverted()@Vector(e['reference_world']),
                            'normal':Vector(e['normal_host_local'])})
    caps=[]
    for idx in cap_ids:
        ring=raw_rings[idx];c=sum(ring,Vector())/10
        endpoint=0 if(c-centers[0]).length<(c-centers[-1]).length else 1
        assert(c-centers[0 if endpoint==0 else -1]).length<1e-6
        caps.append((idx,ring,endpoint))
    route_setup[o.name]=(o,rings,centers,weights,order,host_frames,caps)

contacts={r['name']:r for r in base['seated_support_contacts']}
for name,r in audit['additional_core_flex_supports'].items():
    if not name.startswith(('V04 injector bridge support','V04 pump bed front seat')):continue
    o=bpy.data.objects[name];coords=world_basis(o)
    label=name.removesuffix(' actual seated riser').removesuffix(' seated weld collar')
    contact=contacts[label];host=bpy.data.objects[contact['support']]
    ancestor=host;moving=False
    while ancestor:
        moving|=ancestor==core;ancestor=ancestor.parent
    fixed=Vector(r['fixed_end']);mobile=Vector(r['moving_end']);axis=mobile-fixed
    weights=[]
    for co in coords:
        t=max(0.,min(1.,((co-fixed).dot(axis)/axis.length_squared-.18)/.64))
        weights.append(t*t*(3-2*t)if moving else 0.)
    assert moving==name.startswith('V04 injector bridge support'),(name,host.name,moving)
    support_setup[name]=(o,coords,weights,host,moving)

poses={n:{}for n in [*route_setup,*support_setup]}
checks=[];plans=[]
for f in range(66):
    s.frame_set(f);bpy.context.view_layer.update()
    D=core.matrix_world@rest_core.inverted();rotation=D.to_quaternion()
    for name,(o,rings,centers,weights,order,hosts,caps)in route_setup.items():
        new_rings=[]
        for ring,c,w in zip(rings,centers,weights):
            nc=c.lerp(D@c,w);rot=Quaternion().slerp(rotation,w)
            new_rings.append([nc+rot@(v-c)for v in ring])
        new_centers=[sum(ring,Vector())/10 for ring in new_rings]
        sockets=[]
        for i,h in enumerate(hosts):
            host=h['host'];point=host.matrix_world@h['point']
            normal=(host.matrix_world.to_3x3()@h['normal']).normalized()
            sockets.append({'id':host.name+':'+str(i),'xyz':list(point),'normal':list(normal),
                            'role':'source'if i==0 else'sink','payloads':['fluid'],'parent_mesh':host.name})
        errors=[(new_centers[i]-Vector(sockets[j]['xyz'])).length for i,j in((0,0),(-1,1))]
        assert max(errors)<2e-5,('Hose left its actual captive union',name,f,errors)
        radius=sum((v-centers[0]).length for v in rings[0])/10
        request={'id':name+f':pose-{f:02}','family':'flex_hose','payload':'fluid',
                 'size':{'outer_diameter':radius*2,'wall_fraction':.22},
                 'material_id':o.data.materials[0].name,
                 'path':{'kind':'waypoints','points':[list(c)for c in new_centers]},
                 'start_socket':sockets[0],'end_socket':sockets[1],
                 'fittings':{'start':'hose_tail','end':'hose_tail'},
                 'behavior':{'binding':'V06 existing captive union, source animation only'}}
        plan=pipette.plan(request)
        # Finite discretization of old Bezier at the sockets is retained exactly.
        alignment=[]
        for idx,other,j in((0,1,0),(-1,-2,1)):
            tangent=(new_centers[other]-new_centers[idx]).normalized()
            alignment.append(tangent.dot(Vector(sockets[j]['normal'])))
        assert min(alignment)>.90,('Socket tangent changed',name,f,alignment)
        plans.append({'frame':f,'route':name,'request':request,'plan':plan})
        checks.append({'frame':f,'route':name,'actual_socket_gaps':errors,'terminal_axis_dot':alignment})
        original_order=[None]*(len(new_rings)+len(caps))
        for group,ring in zip(order,new_rings):original_order[group]=ring
        for group,ring,endpoint in caps:
            original_order[group]=[D@v for v in ring]if endpoint else ring
        poses[name][f]=[v for ring in original_order for v in ring]
    for name,(o,coords,weights,host,moving)in support_setup.items():
        poses[name][f]=[co.lerp(D@co,w)for co,w in zip(coords,weights)]

records=[]
for name,(o,*_)in route_setup.items():
    bake(o,poses[name]);o['v06_motion_ownership']='Pipette typed endpoint contract; existing sweep ring frames follow fixed/core unions'
    records.append({'mesh':name,'method':'Existing41x10 sweep plus two10-vertex cap rings retained. Arc-length smooth weighting, rigid ring rotations; end18percent rigid to actual socket frame.','poses':66})
for name,(o,coords,weights,host,moving)in support_setup.items():
    if moving:bake(o,poses[name])
    else:
        o.shape_key_clear();inv=o.matrix_world.inverted()
        o.data.vertices.foreach_set('co',np.asarray([inv@v for v in coords],dtype=np.float32).reshape(-1));o.data.update()
    o['v06_motion_ownership']='Actual seated host: '+host.name
    records.append({'mesh':name,'actual_host':host.name,'host_follows_core':moving,
                    'method':'Original seated support weighting retargeted to actual moving host'if moving else'Incorrect inherited core deformation removed; both support contacts are fixed'})

s.frame_set(1);bpy.context.view_layer.update()
target=a.out/'thetazine-v06-seated-interfaces.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(target),compress=True)
assert module_pins=={n:sha(module/n)for n in module_pins}
report={'status':'EIGHT_HOSE_AND_EIGHT_SUPPORT_INTERFACES_REBOUND_REQUIRES_INDEPENDENT_REOPEN',
        'input_source':{'path':str(a.source),'sha256':sha(a.source)},'script_sha256':sha(Path(__file__)),
        'native':{'path':str(target),'sha256':sha(target)},'pipette_module_hashes':module_pins,
        'pipette_scope':'Typed route/socket planner actually invoked528times; existing sweep topology/UV/materials/unions preserved. No new connector build or game-flow claim.',
        'maximum_socket_gap':max(max(r['actual_socket_gaps'])for r in checks),
        'minimum_terminal_axis_dot':min(min(r['terminal_axis_dot'])for r in checks),
        'changed_objects':records,'measurements':checks}
(a.out/'interface-retarget.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
(a.out/'pipette-pose-plans.json').write_text(json.dumps(plans,indent=2)+'\n',encoding='utf-8')
print('V06_INTERFACES_REBOUND',len(records),report['maximum_socket_gap'],report['minimum_terminal_axis_dot'],flush=True)
