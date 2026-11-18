"""Read-only ownership/socket survey of all84 existing physical fluid routes."""
import bpy,json,pathlib,hashlib,collections
from mathutils import Vector
ROOT=pathlib.Path.cwd();OUT=ROOT/'build/thruster-resume-20261117/thetazine-v06-motion/inspection';OUT.mkdir(parents=True,exist_ok=True)
SRC=ROOT/'build/thruster-resume-20261117/thetazine-v05-detail/candidate-06b-animation-without-guides/thetazine-v05-mechanical-detail.blend'
META=ROOT/'art/source-to-3d/space-platform-engines/thetazine-thruster/v04-regenerative-study/source-manifest.json';m=json.loads(META.read_text())
bpy.ops.wm.open_mainfile(filepath=str(SRC));s=bpy.context.scene;s.frame_set(1);bpy.context.view_layer.update();core=bpy.data.objects['V04 independently suspended engine core']
def in_core(o):
    while o:
        if o==core:return True
        o=o.parent
    return False
def props(o):
    def p(v):
        if isinstance(v,(str,int,float,bool))or v is None:return v
        try:return [p(x)for x in v]
        except TypeError:return str(v)
    return {k:p(v)for k,v in o.items()if k!='_RNA_UI'}
def object_record(name):
    ob=bpy.data.objects[name];chain=[];p=ob.parent
    while p:chain.append(p.name);p=p.parent
    return {'parent':ob.parent.name if ob.parent else None,'parent_chain':chain,'inside_core':in_core(ob),
      'vertices':len(ob.data.vertices)if ob.type=='MESH'else None,'shape_keys':len(ob.data.shape_keys.key_blocks)if ob.type=='MESH'and ob.data.shape_keys else 0,
      'custom_properties':props(ob)}
def endpoint(name,point=None,normal=None):
    host=bpy.data.objects[name];row={'host':name,'inside_core':in_core(host),'host_parent':host.parent.name if host.parent else None}
    if point is not None:row['reference_world']=list(point);row['host_local']=list(host.matrix_world.inverted()@Vector(point))
    if normal is not None:row['normal_host_local']=list((host.matrix_world.to_3x3().transposed()@Vector(normal)).normalized())
    return row
rows=[]
for route in m['mechanical_refinement']['pipe_routes']:
    name=route['pipe'];ends=sorted([j for j in m['mechanical_refinement']['seated_pipe_end_joints']if j['pipe']==name],key=lambda j:0 if j['side']=='start' else 1)
    assert len(ends)==2
    rows.append({'name':name,'family':'legacy46','object':object_record(name),'ends':[dict(endpoint(j['host'],j['pipe_endpoint_inside_union'],j['socket_axis']),side=j['side'])for j in ends]})
L=m['leaf_regenerative_cooling'];circuits={r['pipe']:r for r in L['circuits']}
for route in L['pipe_routes']:
    name=route['name']
    if name in circuits:
        c=circuits[name];ends=[endpoint(c['leaf'])]*2
    else:
        fluid=name.rsplit(' ',1)[1]
        ports=[next(p for p in L['ports']if p['name']==f'V04 leaf return trunk {kind} {fluid}')for kind in ['collector','receiver']]
        ends=[endpoint(p['host'],p['cap_world_rest'],p.get('axis'))for p in ports]
    rows.append({'name':name,'family':'leaf14','object':object_record(name),'ends':ends})
for job in L['flex_links']:
    root=('V04 stationary regenerative supply half 'if job['kind']=='inlet'else'V04 leaf cooling warm return collector ')+job['fluid']
    rows.append({'name':job['mesh'],'family':'leaf24','object':object_record(job['mesh']),
      'ends':[endpoint(root,job['root_rest']),endpoint(job['leaf'])],'leaf_job':job})
assert len(rows)==84 and len({v['name']for v in rows})==84
for r in rows:
    flags=[e['inside_core']for e in r['ends']]
    r['endpoint_ownership']='FIXED_TO_CORE'if any(flags)and not all(flags)else'BOTH_CORE'or'BOTH_FIXED'
    if not any(flags):r['endpoint_ownership']='BOTH_FIXED'
    r['retarget']='CROSS_BOUNDARY_REBAKE'if r['endpoint_ownership']=='FIXED_TO_CORE'else'FOLLOWS_CORE_PARENT'if all(flags)and r['object']['inside_core']else'WORLD_BAKED_BOTH_CORE'if all(flags)else'FIXED_KEEP_UNCHANGED'
anchored={n:object_record(n)for n in m['mechanical_refinement']['anchored_flex_parts']}
extra={j['name']:dict(j,object=object_record(j['name']))for j in m['core_and_full_light_refinement']['flexible_links']if j['name']not in {r['name']for r in rows}}
volumes={o.name:object_record(o.name)for o in s.objects if o.get('render_only_volume')or o.get('light_map_only')or any(k in o.name.lower()for k in ['plume join','volumetric combustion'])}
report={'status':'READ_ONLY_ALL84_ROUTE_OWNERSHIP_AND_ORIGINAL_BUILD_CONTRACT','source':str(SRC),'source_sha256':hashlib.sha256(SRC.read_bytes()).hexdigest(),'routes':rows,'classification_counts':dict(collections.Counter(r['retarget']for r in rows)),
 'four_anchored_bellows':anchored,'additional_core_flex_supports':extra,'render_only_exhaust':volumes,
 'original_core_flex_builder':r'C:\Users\Admin\Documents\Codex\2026-11-07\referenced-chatgpt-conversation-this-is-an\work\thruster-v04\refine_core_and_full_light.py',
 'original_frame_bellows_builder':r'C:\Users\Admin\Documents\Codex\2026-11-07\referenced-chatgpt-conversation-this-is-an\work\thruster-v04\mechanical_refinement.py',
 'original_flex_recipe':'Core flexible weighting: smoothstep(clamp((dot(co-fixed,mobile-fixed)/lengthSquared-.18)/.64)). Terminal18% regions follow exact fixed/core frames. Bellows:24rings/32sides,10corrugations,inner radius74%, parent structural recoil is identity-motion by owner-fixed-frame correction.'}
(OUT/'route-ownership.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('ALL84_CLASSIFIED',report['classification_counts'])
print('CROSS_BOUNDARY',[r['name']for r in rows if r['retarget']=='CROSS_BOUNDARY_REBAKE'])
print('EXHAUST',[(n,v['parent'],v['inside_core'])for n,v in volumes.items()])

