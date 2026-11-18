"""Independent V06 motion/export and declared-change checker. Run in Blender.

No source is saved, no capture or native client is launched. The checker pins
all inputs, evaluates all 66 poses, preserves exact undeclared V05 source data,
and compares actual physical GLB geometry to source. Targeted clearance uses
actual triangles and closed-solid containment after an AABB broad phase.

Declarations are explicit JSON files, supplied with repeatable --changes:
 {"allowed_source_changes": {"exact object name": {
       "allow_fields": ["transform", "object_animation"], "reason": "..."}},
  "new_names": ["exact new object name"],
  "source_only_names": ["exact render-only volume name"],
  "fixed_names": ["exact immutable interface name"],
  "loop_groups": [{"names": ["name"], "frames": [1,65], "tolerance": 0}],
  "clearance": {"participants": ["name"], "participant_roots": ["core"],
     "minimum_clearance": 0.0005,
     "bounded_contacts": [{"object":"small fitting", "host":"receiving host",
       "point_host_local":[0,0,0], "normal_host_local":[0,0,1],
       "region_radius":0.1, "max_insertion_depth":0.002, "reason":"..."}]}}

Aliases match the root/side-stage manifests. All local source geometry, UV,
material bindings, original PBR and keyframes stay exact except named fields.
Physical cache files are uncompressed arrays in the requested output folder;
this bounds RAM while retaining full world vertices rather than samples.
"""
import argparse
import collections
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import sys
sys.dont_write_bytecode=True

import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.geometry import intersect_ray_tri

ROOT=Path(__file__).resolve().parents[3]
BASE=ROOT/'art/source-to-3d/space-platform-engines/thetazine-thruster/v05-mechanical-detail'
BASE_SOURCE=BASE/'thetazine-v05-mechanical-detail.blend'
BASE_GLB=BASE/'thetazine-v05-mechanical-detail.glb'
BASE_PIN='f02f30ad740636d6fa7906a01c6b86af45d90cf1eb940a7c7fc627ed065a2f34'
BASE_GLB_PIN='f1bd3b2936ce616900fc9acf40fe25e3a0d15bcdebc7f5f90f3494a27ba76d27'
TOL=1e-5
POSES=list(range(66))
HELPER=ROOT/'tools/art/thetazine_v05/validate_detail.py'
spec=importlib.util.spec_from_file_location('independent_v05_geometry_primitives',HELPER)
helper=importlib.util.module_from_spec(spec);spec.loader.exec_module(helper)


def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def read(path):return json.loads(Path(path).read_text(encoding='utf-8-sig'))
def dump(path,data):
    Path(path).write_text(json.dumps(data,indent=2,default=helper.json_default)+'\n',encoding='utf-8')
def objects():return {o.name:o for o in bpy.context.scene.objects if o.type in {'MESH','EMPTY','ARMATURE','CURVE'}}
def prefix(path,allowed):return any(path==a or path.startswith(a+'.') for a in allowed)


ALIASES={
 'basis_vertices':['mesh.coordinates'],
 'shape_keys':['mesh.shape_keys'],
 'shape_key_animation':['mesh.shape_animation'],
 'object_animation':['animation'],
 'transform':['matrix_basis','matrix_parent_inverse'],
 'parent':['parent','parent_type','parent_bone'],
 'geometry':['mesh.coordinates','mesh.loops','mesh.polygons','mesh.custom_normals'],
 'uv':['mesh.uv','mesh.uv_active'],
 'mesh_geometry':['mesh.coordinates','mesh.loops','mesh.polygons','mesh.uv','mesh.uv_active','mesh.custom_normals'],
 'custom_properties':[],
}


def merge_declarations(paths):
    result={'allowed_source_changes':{},'new_names':[],'source_only_names':[],
            'fixed_names':[],'loop_groups':[],
            'clearance':{'participants':[],'participant_roots':[],
                         'bounded_contacts':[],'minimum_clearance':.0005}}
    records=[]
    for path in paths:
        item=read(path);records.append({'path':str(path),'sha256':sha(path)})
        for name,row in item.get('allowed_source_changes',{}).items():
            assert row.get('reason') and row.get('allow_fields'),('Unreasoned or empty change declaration',name,path)
            target=result['allowed_source_changes'].setdefault(name,{'allow_fields':[],'reason':[]})
            target['allow_fields']=sorted(set(target['allow_fields'])|set(row['allow_fields']))
            target['reason'].append(row['reason'])
        # Side assembly declares exact new rod names as new_meshes.
        for key in ('new_names','source_only_names','fixed_names'):
            result[key]=sorted(set(result[key])|set(item.get(key,[])))
        result['new_names']=sorted(set(result['new_names'])|set(item.get('new_meshes',[])))
        result['loop_groups']+=item.get('loop_groups',[])
        clear=item.get('clearance',{})
        for key in ('participants','participant_roots'):
            result['clearance'][key]=sorted(set(result['clearance'][key])|set(clear.get(key,[])))
        result['clearance']['bounded_contacts']+=clear.get('bounded_contacts',[])
        if 'minimum_clearance' in clear:
            value=float(clear['minimum_clearance']);assert value>=0
            result['clearance']['minimum_clearance']=max(result['clearance']['minimum_clearance'],value)
    return result,records


def leaf_differences(a,b,path=''):
    if isinstance(a,dict) and isinstance(b,dict):
        for key in sorted(set(a)|set(b)):
            child=path+'.'+key if path else key
            if key not in a or key not in b:yield child,a.get(key),b.get(key)
            else:yield from leaf_differences(a[key],b[key],child)
    elif a!=b:yield path,a,b


def source_preservation(old,new,declarations,check):
    old_names=set(old['objects']);new_names=set(new['objects'])
    declared_new=set(declarations['new_names'])
    check(not old_names-new_names,'BASE_OBJECT_REMOVED',sorted(old_names-new_names))
    check(new_names-old_names==declared_new,'EXACT_NEW_OBJECT_SET',
          {'actual':sorted(new_names-old_names),'declared':sorted(declared_new)})
    changes=declarations['allowed_source_changes'];diffs=[];permitted=[]
    check(set(changes)<=old_names,'CHANGE_DECLARATION_UNKNOWN_BASE_OBJECT',sorted(set(changes)-old_names))
    for name in sorted(old_names&new_names):
        allowed=[]
        for field in changes.get(name,{}).get('allow_fields',[]):allowed+=ALIASES.get(field,[field])
        for path,a,b in leaf_differences(old['objects'][name],new['objects'][name]):
            row={'object':name,'field':path,'before_sha256':helper.digest(a),'after_sha256':helper.digest(b)}
            if prefix(path,allowed):permitted.append(row)
            else:diffs.append(row);check(False,'UNDECLARED_SOURCE_FIELD_CHANGE',row)
    for name,data in old['materials'].items():
        check(name in new['materials'],'ORIGINAL_PBR_MATERIAL_MISSING',name)
        if name in new['materials']:
            check(data==new['materials'][name],'ORIGINAL_PBR_OR_IMAGE_OR_SHADER_KEYFRAMES_CHANGED',name)
    for key in ('fps','fps_base','frame_start','frame_end'):
        check(old[key]==new[key],'ORIGINAL_TIMELINE_SETTING_CHANGED',{'setting':key,'old':old[key],'new':new[key]})
    return {'original_object_count':len(old_names),'original_material_count':len(old['materials']),
            'exact_new_names':sorted(declared_new),'permitted_field_differences':permitted,
            'undeclared_field_differences':diffs,
            'policy':'Object metadata/custom properties are not physical geometry; original mesh materials, UVs, PBR images and animation are compared. Field exemptions apply only to exact named objects.'}


class PoseCache:
    """Full world vertices, triangle topology and matrices; no point sampling."""
    def __init__(self,path,names=None):
        self.path=Path(path);self.path.mkdir(parents=True,exist_ok=True)
        meta=read(self.path/'index.json') if names is None else None
        self.names=sorted(names) if names is not None else meta['names']
        self.index={name:i for i,name in enumerate(self.names)}
        self.counts=None;self.faces={};self.polygon_connectivity={};self.matrix_names=[]
        if meta is not None:
            self.counts=meta['vertex_counts'];self.matrix_names=meta['matrix_names']
            self.polygon_connectivity=meta.get('raw_polygon_connectivity_sha256',{})
            with np.load(self.path/'topology.npz',allow_pickle=False) as topology:
                self.faces={name:topology['m'+str(i)] for i,name in enumerate(self.names)}
    def write(self,frame,obs,check):
        dg=bpy.context.evaluated_depsgraph_get();chunks=[];counts=[];triangle_overrides={}
        for name in self.names:
            ob=obs[name];ev=ob.evaluated_get(dg);mesh=ev.to_mesh();mesh.calc_loop_triangles()
            local=np.asarray([v.co[:] for v in mesh.vertices],dtype=np.float64)
            matrix=np.asarray(ev.matrix_world,dtype=np.float64)
            points=local@matrix[:3,:3].T+matrix[:3,3]
            faces=np.asarray([tuple(t.vertices) for t in mesh.loop_triangles],dtype=np.int32)
            polygon_connectivity=helper.digest({'loops':[int(l.vertex_index) for l in mesh.loops],
                'polygons':[(int(p.loop_start),int(p.loop_total)) for p in mesh.polygons]})
            check(np.isfinite(points).all() and np.isfinite(matrix).all(),'FINITE_EVALUATED_GEOMETRY_AND_MATRIX',{'frame':frame,'object':name})
            chunks.append(points);counts.append(len(points))
            if frame==0:
                self.faces[name]=faces;self.polygon_connectivity[name]=polygon_connectivity
            else:
                check(polygon_connectivity==self.polygon_connectivity[name],
                      'EVALUATED_RAW_VERTEX_LOOP_POLYGON_TOPOLOGY_CHANGED',{'frame':frame,'object':name})
                # Blender may change the tessellating diagonal of a deformed
                # quad/ngon while its real vertex/loop/polygon topology stays
                # exact. Preserve that pose's actual triangles for BVH work.
                if not np.array_equal(faces,self.faces[name]):triangle_overrides['tri_m'+str(self.index[name])]=faces
            ev.to_mesh_clear()
        offsets=np.cumsum([0]+counts,dtype=np.int64)
        if self.counts is None:self.counts=counts
        check(counts==self.counts,'EVALUATED_VERTEX_COUNTS_CHANGE_WITH_POSE',frame)
        matrix_names=sorted(obs);matrices=[]
        for name in matrix_names:
            matrix=np.asarray(obs[name].evaluated_get(dg).matrix_world,dtype=np.float64)
            check(np.isfinite(matrix).all(),'FINITE_OBJECT_MATRIX',{'frame':frame,'object':name})
            matrices.append(matrix)
        self.matrix_names=matrix_names
        np.savez(self.path/f'pose-{frame:02d}.npz',points=np.concatenate(chunks) if chunks else np.zeros((0,3)),
                 offsets=offsets,matrices=np.asarray(matrices),**triangle_overrides)
        if frame==0:
            dump(self.path/'index.json',{'names':self.names,'matrix_names':matrix_names,'vertex_counts':counts,
                                        'raw_polygon_connectivity_sha256':self.polygon_connectivity})
            np.savez(self.path/'topology.npz',**{'m'+str(i):self.faces[n] for i,n in enumerate(self.names)})
    def read(self,frame):
        result=np.load(self.path/f'pose-{frame:02d}.npz',allow_pickle=False)
        meta=read(self.path/'index.json')
        return CachedPose(result,meta)


class CachedPose:
    def __init__(self,data,meta):
        self.data=data;self.names=meta['names'];self.index={n:i for i,n in enumerate(self.names)}
        self.matrix_index={n:i for i,n in enumerate(meta['matrix_names'])}
        self.points_array=data['points'];self.offsets=data['offsets'];self.matrices=data['matrices']
    def points(self,name):
        i=self.index[name];a,b=self.offsets[i:i+2];return self.points_array[a:b]
    def matrix(self,name):return self.matrices[self.matrix_index[name]]
    def faces(self,cache,name):
        key='tri_m'+str(self.index[name])
        return self.data[key] if key in self.data.files else cache.faces[name]
    def close(self):self.data.close()


def relative_points(points,matrix):
    inverse=np.linalg.inv(matrix);return points@inverse[:3,:3].T+inverse[:3,3]


def physical_centroid(points):
    # GLB splits the same physical vertices at UV/normal seams. Weld only those
    # coincident positions before taking the same geometric-vertex centroid.
    _,indices=np.unique(np.round(points/1e-7).astype(np.int64),axis=0,return_index=True)
    return points[np.sort(indices)].mean(axis=0)


def cached_tree(cache,pose,name):
    return helper.BVHTree.FromPolygons([Vector(p) for p in pose.points(name)],
                                     pose.faces(cache,name).tolist(),all_triangles=True)


class CachedShape:
    def __init__(self,cache,pose,name):
        self.points=pose.points(name);self.faces=pose.faces(cache,name)
        self.triangles=self.points[self.faces];self.tree=cached_tree(cache,pose,name)
        self.closed=helper.Shape.manifold_edges(self.points,self.faces)==0


def actuator_pose(phase,frame,cache,metadata,core_name,check):
    """Actual evaluated pins, rigid members, rod/bore overlap and sleeve fits."""
    rest=cache.read(0);cur=cache.read(frame);rows=[];typed_pairs=set()
    Dcore=cur.matrix(core_name)@np.linalg.inv(rest.matrix(core_name))
    for assembly in metadata['assemblies']:
        fore=assembly['fixed_fore_pin'];aft=assembly['moving_aft_pin']
        expected_fore=np.asarray(assembly['fixed_pin_centroid'],dtype=float)
        q=np.asarray(assembly['rest_aft_pin_centroid'],dtype=float)
        expected_aft=Dcore[:3,:3]@q+Dcore[:3,3]
        actual_fore=physical_centroid(cur.points(fore));actual_aft=physical_centroid(cur.points(aft))
        fore_error=float(np.linalg.norm(actual_fore-expected_fore));aft_error=float(np.linalg.norm(actual_aft-expected_aft))
        axis=(actual_aft-actual_fore);axis/=np.linalg.norm(axis)
        barrel=assembly['fixed_barrel_group'][0]
        rod=next(n for n in assembly['sliding_group'] if n.startswith('V06 giant actuator sliding rod'))
        bp,rp=cur.points(barrel),cur.points(rod);origin=physical_centroid(bp)
        bz=(bp-origin)@axis;rz=(rp-origin)@axis
        br=np.linalg.norm((bp-origin)-bz[:,None]*axis,axis=1)
        rr=np.linalg.norm((rp-origin)-rz[:,None]*axis,axis=1)
        overlap=min(float(bz.max()),float(rz.max()))-max(float(bz.min()),float(rz.min()))
        in_barrel=(rz>=bz.min()-TOL)&(rz<=bz.max()+TOL)
        bore=float(br[br>1e-5].min())
        rod_radius=float(rr[in_barrel].max()) if np.any(in_barrel) else float('inf')
        radial_gap=bore-rod_radius
        shoulder=rz[rr>bore+TOL]
        shoulder_clearance=float(shoulder.min()-bz.max()) if len(shoulder) else None
        rigid=[]
        for name in assembly['fixed_barrel_group']+assembly['sliding_group']:
            aa,bb=rest.points(name),cur.points(name);D=cur.matrix(name)@np.linalg.inv(rest.matrix(name))
            expected=aa@D[:3,:3].T+D[:3,3]
            error=float(np.max(np.linalg.norm(expected-bb,axis=1))) if aa.shape==bb.shape else float('inf')
            metric=float(np.max(np.abs(D[:3,:3].T@D[:3,:3]-np.eye(3))))
            rigid.append({'name':name,'actual_rigid_world_vertex_error':error,'delta_orthonormality_error':metric})
            check(error<TOL and metric<TOL,phase+'_ACTUATOR_MEMBER_RIGIDITY',dict(rigid[-1],frame=frame))
        trees={name:cached_tree(cache,cur,name) for name in [barrel,rod]}
        def outer_hit(tree,origin,direction):
            origin=Vector(origin);direction=Vector(direction);cursor=origin;distances=[]
            for _ in range(8):
                hit,normal,index,distance=tree.ray_cast(cursor,direction,.30)
                if hit is None:break
                total=(hit-origin).dot(direction)
                if total>.30:break
                distances.append(total);cursor=hit+direction*2e-6
            return max(distances) if distances else None
        collars=assembly['fixed_barrel_group'][1:]+[n for n in assembly['sliding_group'] if n.startswith('Outer actuator collar')]
        sleeve_rows=[]
        u=np.array([1.,0.,0.]);u-=axis*(u@axis);u/=np.linalg.norm(u);v=np.cross(axis,u)
        for ci,collar in enumerate(collars):
            host=barrel if ci<2 else rod;tree=cached_tree(cache,cur,collar)
            cp=cur.points(collar);az=(cp-origin)@axis;gaps=[];missed=0
            hostz=bz if host==barrel else rz
            axial_seat_margin=min(float(az.min()-hostz.min()),float(hostz.max()-az.max()))
            for fraction in [.25,.5,.75]:
                center=origin+axis*(az.min()+(az.max()-az.min())*fraction)
                for k in range(24):
                    radial=u*math.cos(math.tau*k/24)+v*math.sin(math.tau*k/24)
                    hp,_,_,hd=tree.ray_cast(Vector(center),Vector(radial),.30)
                    sh=outer_hit(trees[host],center,radial)
                    if hp is None or sh is None:missed+=1
                    else:gaps.append(float(hd-sh))
            maximum=max((abs(x) for x in gaps),default=float('inf'))
            passed=missed==0 and len(gaps)==72 and maximum<TOL and axial_seat_margin>=-TOL
            sleeve_rows.append({'collar':collar,'shaft':host,'actual_ray_samples':len(gaps),'missed_samples':missed,
                'signed_bore_to_shaft_gap_range':[min(gaps),max(gaps)] if gaps else None,
                'maximum_absolute_radial_seating_gap':maximum,'minimum_axial_seat_margin':axial_seat_margin,'pass':passed})
            check(passed,phase+'_ACTUAL_ANNULAR_COLLAR_SEAT',dict(sleeve_rows[-1],frame=frame))
            if passed:typed_pairs.add(frozenset((collar,host)))
        # The inherited fore clevis is an actual closed source box/cradle,
        # not a newly invented drilled bearing. Require finite mesh contact.
        support_rows=[]
        for member,host,label in [(barrel,assembly['fixed_fore_clevis'],'FORE_BARREL_IN_ORIGINAL_CLEVIS'),
                                  (rod,assembly['moving_aft_clevis'],'ROD_END_IN_ORIGINAL_AFT_CLEVIS')]:
            contact=state_of_pair(CachedShape(cache,cur,member),CachedShape(cache,cur,host))
            passed=bool(contact['triangle_intersections'] or contact['closed_solid_containment'] or
                        contact['actual_bidirectional_vertex_surface_gap']<TOL)
            support=dict(contact,member=member,host=host,pass_contact=passed,
                         source_host_form='Original finite closed box/cradle; no drilled bore claim')
            support_rows.append(support);check(passed,phase+'_'+label,dict(support,frame=frame))
            if passed:typed_pairs.add(frozenset((member,host)))
        row={'phase':phase,'frame':frame,'side':assembly['sign'],'actual_fixed_pin_centroid':actual_fore.tolist(),
          'actual_aft_pin_centroid':actual_aft.tolist(),'expected_aft_from_actual_core_world':expected_aft.tolist(),
          'fore_pin_fixed_error':fore_error,'aft_pin_core_target_error':aft_error,
          'actual_barrel_axial_interval':bz[[np.argmin(bz),np.argmax(bz)]].tolist(),
          'actual_rod_axial_interval':rz[[np.argmin(rz),np.argmax(rz)]].tolist(),
          'actual_rod_barrel_overlap':overlap,'actual_barrel_bore_radius':bore,
          'actual_overlapping_rod_radius':rod_radius,'actual_radial_running_gap':radial_gap,
          'actual_shoulder_clearance_past_barrel_end':shoulder_clearance,
          'annular_sleeve_seats':sleeve_rows,'rigid_members':rigid,
          'finite_original_clevis_contacts':support_rows}
        check(fore_error<TOL and aft_error<TOL,phase+'_ACTUAL_PIN_CENTROIDS',row)
        check(overlap>.14 and radial_gap>=.005-TOL and (shoulder_clearance is None or shoulder_clearance>0),
              phase+'_ACTUAL_SLIDING_ROD_BORE_AND_OVERLAP',row)
        rows.append(row)
    rest.close();cur.close();return rows,typed_pairs


def state_of_pair_unbounded_reference(a,b):
    overlap=[(i,j) for i,j in a.tree.overlap(b.tree)
             if helper.triangle_intersects(a.triangles[i],b.triangles[j])]
    containment=False
    if not overlap:
        containment=(b.closed and helper.inside(b,a.points[0])) or (a.closed and helper.inside(a,b.points[0]))
    gap=0. if overlap or containment else helper.nearest_surface_gap(a,b)
    return {'triangle_intersections':len(overlap),'closed_solid_containment':bool(containment),
            'actual_bidirectional_vertex_surface_gap':float(gap)}


def state_of_pair_bounded(a,b,margin=.0005):
    """Same .0005 decision; separated pairs need only a conservative bound.

    Exact triangle crossing and closed-solid containment are unchanged. A BVH
    radius query is performed for every actual vertex in both directions; no
    hit proves the same clearance threshold without finding its far distance.
    Under-margin hits retain the exact minimum from both complete vertex sets.
    """
    overlap=[(i,j)for i,j in a.tree.overlap(b.tree)if helper.triangle_intersects(a.triangles[i],b.triangles[j])]
    containment=False
    if not overlap:containment=(b.closed and helper.inside(b,a.points[0]))or(a.closed and helper.inside(a,b.points[0]))
    if overlap or containment:
        gap=0.;kind='EXACT_CROSSING_OR_CONTAINMENT'
    else:
        gap=float(margin);found=False
        for src,dst in [(a,b),(b,a)]:
            for point in src.points:
                hit=dst.tree.find_nearest(Vector(point),gap)
                if hit[0] is not None:
                    found=True;gap=min(gap,float(hit[3]))
        kind='EXACT_UNDER_MARGIN_VERTEX_SURFACE_MINIMUM'if found else'CONSERVATIVE_VERTEX_SURFACE_LOWER_BOUND_AT_SAME_MARGIN'
    return {'triangle_intersections':len(overlap),'closed_solid_containment':bool(containment),
        'actual_bidirectional_vertex_surface_gap':gap,'surface_gap_measurement':kind,'clearance_margin':margin}


def state_of_pair(a,b):return state_of_pair_bounded(a,b)


def review_authored_feed6_terminal(args,feed_index=6):
    """Resolve the two mirrored terminals using PREEXISTING last Bezier spans."""
    report_path=args.review_terminal_flags.resolve()/'clearance.json';screen=read(report_path)
    assert screen['source_sha256']==args.source_sha256 and screen['glb_binding_sha256']==args.glb_sha256
    cache=PoseCache(args.targeted32_source_cache/'source-physical-cache')
    actual=PoseCache(ROOT/'build/thruster-resume-20261117/thetazine-v06-motion/independent10-export66/actual-glb-physical-cache')
    bpy.ops.wm.open_mainfile(filepath=str(args.baseline));bpy.context.scene.frame_set(0);bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
    assert feed_index in (0,6)
    name=f'V04 restraint hydraulic feed {feed_index}';clevis='Actuator support clevis.001'if feed_index==6 else'Actuator support clevis.003'
    joint_index=77 if feed_index==6 else 65
    joint=read(BASE/'provenance/v04-source-manifest.json')['mechanical_refinement']['seated_pipe_end_joints'][joint_index]
    pin=joint['host']
    oldpipe=helper.Shape(bpy.data.objects[name],dg);oldpin=helper.Shape(bpy.data.objects[pin],dg)
    cold=cache.read(0);coords=cold.points(name);assert len(coords)==330
    assert oldpipe.points.shape==coords.shape and np.linalg.norm(oldpipe.points-coords,axis=1).max()<TOL
    assert np.linalg.norm(oldpin.points-cold.points(pin),axis=1).max()<TOL
    assert joint['pipe']==name and joint['side']=='end'
    rings=coords.reshape(33,10,3);centers=rings.mean(1);graph={i:set()for i in range(33)}
    for face in cache.faces[name]:
        groups={int(i)//10 for i in face};assert len(groups)<=2
        if len(groups)==2:a,b=groups;graph[a].add(b);graph[b].add(a)
    caps=[i for i,g in graph.items()if not g];ends=[i for i,g in graph.items()if len(g)==1]
    assert len(caps)==len(ends)==2
    order=[ends[0]]
    while len(order)<31:
        nxt=graph[order[-1]]-set(order);assert len(nxt)==1;order.append(nxt.pop())
    p3=np.asarray(joint['pipe_endpoint_inside_union'])
    if np.linalg.norm(centers[order[0]]-p3)<np.linalg.norm(centers[order[-1]]-p3):order.reverse()
    # Exact primary constructor: theta6=pi, radial=-X, final span begins
    # fixed+radial*.18. These dimensions precede the observed interference.
    fixed=oldpin.points.mean(0);p0=fixed+np.asarray([-.18 if feed_index==6 else .18,0.,0.])
    start=min(range(31),key=lambda i:np.linalg.norm(centers[order[i]]-p0))
    assert start==20
    t=np.linspace(0,1,11);B=np.stack((3*(1-t)**2*t,3*(1-t)*t*t),axis=1)
    body=centers[order[start:]];Y=body-(1-t)[:,None]**3*p0-t[:,None]**3*p3
    fitted=np.linalg.lstsq(B,Y,rcond=None)[0];pred=(1-t)[:,None]**3*p0+B@fitted+t[:,None]**3*p3
    p2=p3+np.asarray(joint['socket_axis'])*.12
    constructor_error=float(np.linalg.norm(body[0]-p0));fit_error=float(np.linalg.norm(pred-body,axis=1).max());handle_error=float(np.linalg.norm(fitted[1]-p2))
    assert max(constructor_error,fit_error,handle_error)<TOL and np.linalg.norm(body[-1]-p3)<TOL
    oldclevis=helper.Shape(bpy.data.objects[clevis],dg);old_ids=set();old_contacts=[]
    for ob in bpy.context.scene.objects:
        if ob.type!='MESH'or not ob.name.startswith(f'V04 seated union {joint_index:03d} '):continue
        sh=helper.Shape(ob,dg);hits=[(i,j)for i,j in oldclevis.tree.overlap(sh.tree)if helper.triangle_intersects(oldclevis.triangles[i],sh.triangles[j])]
        if hits:
            old_ids.update(int(k)for i,j in hits for k in oldclevis.faces[i]);old_contacts.append({'host':ob.name,'triangle_intersections':len(hits)})
    rows=[]
    for flag in screen['classifier_flags']:
        if flag['classification']!='COLLECTED_CONNECTED_SOURCE_TERMINAL_SUBPART_FLAG':continue
        if frozenset((flag['a'],flag['b']))!=frozenset((name,clevis)):continue
        frame=flag['frame'];source=cache.read(frame);export=actual.read(frame)
        geometry=[]
        for phase,pc,pose in [('SOURCE',cache,source),('ACTUAL_GLB',actual,export)]:
            a,b=CachedShape(pc,pose,clevis),CachedShape(pc,pose,name)
            hits=[(i,j)for i,j in a.tree.overlap(b.tree)if helper.triangle_intersects(a.triangles[i],b.triangles[j])]
            state=state_of_pair(a,b)
            from mathutils.kdtree import KDTree
            def original_ids(mesh,ids,source_name):
                kd=KDTree(len(source.points(source_name)))
                for i,p in enumerate(source.points(source_name)):kd.insert(Vector(p),i)
                kd.balance();mapped=[];error=0.
                for i in ids:
                    _,j,d=kd.find(Vector(mesh.points[i]));mapped.append(j);error=max(error,float(d))
                assert error<TOL;return set(mapped),error
            ai={int(k)for i,j in hits for k in a.faces[i]};bi={int(k)for i,j in hits for k in b.faces[j]}
            if not hits:
                assert state['actual_bidirectional_vertex_surface_gap']<.0005
                for src,dst,own,host in [(a,b,ai,bi),(b,a,bi,ai)]:
                    for i,p in enumerate(src.points):
                        hit=dst.tree.find_nearest(Vector(p),.0005)
                        if hit[0]is not None:own.add(i);host.update(map(int,dst.faces[hit[2]]))
            aid,ae=original_ids(a,ai,clevis);bid,be=original_ids(b,bi,name)
            groups={i//10 for i in bid};positions=[]
            for g in groups:
                position=order.index(g)if g in order else min(range(31),key=lambda i:np.linalg.norm(centers[g]-centers[order[i]]))
                positions.append(position)
            geometry.append({'phase':phase,**state,'source_pipe_body_ring_positions':sorted(set(positions)),
                'all_contacts_on_preexisting_last_span':all(start<=p<=30 for p in positions),
                'all_contact_clevis_vertices_in_old_fouled_union_region':aid<=old_ids,
                'clevis_source_vertex_ids':sorted(aid),'physical_vertex_mapping_error':max(ae,be)})
        assert all(r['all_contacts_on_preexisting_last_span']and r['all_contact_clevis_vertices_in_old_fouled_union_region']for r in geometry)
        rows.append({'frame':frame,'pipe':name,'clevis':clevis,'source_joint_index':joint_index,'actual_source_and_export_contact_regions':geometry,
            'outside_strict_union_envelope':flag['connected_source_terminal_subpart']['maximum_crossing_outside_union_envelope'],
            'classification':'MEASURED_INHERITED_CONNECTED_TERMINAL_SPAN_AND_SAME_OLD_CLEVIS_FACE_REGION'})
        source.close();export.close()
    primary=Path(r'C:\Users\Admin\Documents\Codex\2026-11-07\referenced-chatgpt-conversation-this-is-an\work\thruster-v04')
    result={'status':'PASS_COLLECTED_SOURCE_AND_ACTUAL_GLB_TERMINAL_SPAN_REGIONS','units':'BU','feed_index':feed_index,
        'source_sha256':args.source_sha256,'glb_sha256':args.glb_sha256,'input_screen_sha256':sha(report_path),
        'primary_source_files':[{'path':str(primary/n),'sha256':sha(primary/n)}for n in ['build_model.py','mechanical_refinement.py']],
        'primary_source_references':f'build_model.py244-259: feed{feed_index} last span fixed+rad*.18→fixed,theta=index*tau/12. mechanical_refinement.py61-65: final endpoint inside joint{joint_index}; left handle endpoint+socket_axis*.12.',
        'source_original_pipe_world_error':float(np.linalg.norm(oldpipe.points-coords,axis=1).max()),
        'actual_pin_centroid':fixed,'authored_last_span_start':p0,'matched_body_ring_start':start,'body_ring_order':order,
        'constructor_to_actual_ring_error':constructor_error,'all11rings_cubic_fit_error':fit_error,'constructor_handle_to_fitted_handle_error':handle_error,
        'old_clevis_terminal_union_contacts':old_contacts,'rows':rows,
        'scope':'The source-defined last Bezier span, not an enlarged union or entire pipe/machine, contains the actual new contacts. Records inherited local assembly roughness; does not claim universal CAD clearance or physically separated terminal parts.'}
    dump(args.out/f'terminal-review-feed{feed_index}.json',result);cold.close();print(result['status'],'feed',feed_index,'poses',len(rows),flush=True)
    return result


def review_inherited_finite_containment(args):
    """Replay contained old subparts against actual SOURCE and imported GLB."""
    screen=read(args.review_terminal_flags/'clearance.json')
    cache=PoseCache(args.targeted32_source_cache/'source-physical-cache')
    actual=PoseCache(ROOT/'build/thruster-resume-20261117/thetazine-v06-motion/independent10-export66/actual-glb-physical-cache')
    rows=[]
    for flag in screen['classifier_flags']:
        if flag['classification']!='COLLECTED_LEGACY_SAME_PAIR_LOCAL_REGION_CLASSIFIER_FLAG'or not flag['closed_solid_containment']:continue
        bpy.ops.wm.open_mainfile(filepath=str(args.baseline));bpy.context.scene.frame_set(0);bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
        member,part=flag['a'],flag['b'];oldhost=helper.Shape(bpy.data.objects[member],dg);oldpart=helper.Shape(bpy.data.objects[part],dg)
        old_state=state_of_pair(oldhost,oldpart)
        assert oldhost.closed and old_state['closed_solid_containment']and all(helper.inside(oldhost,q)for q in oldpart.points)
        old_hit=oldhost.tree.find_nearest(Vector(oldpart.points[0]));old_ids=set(map(int,oldhost.faces[old_hit[2]]))
        role=next(r for r in screen['inherited_finite_union_roles']if r['member']==member and part.startswith(r['union_prefix']))
        frame=flag['frame'];source=cache.read(frame);phase_rows=[]
        from mathutils.kdtree import KDTree
        kd=KDTree(len(source.points(member)))
        for i,q in enumerate(source.points(member)):kd.insert(Vector(q),i)
        kd.balance()
        boss=role['union_prefix']+'welded socket boss';M=source.matrix(boss)
        union=np.concatenate([relative_points(source.points(n),M)for n in cache.names if n.startswith(role['union_prefix'])])
        for phase,pc in [('SOURCE',cache),('ACTUAL_GLB',actual)]:
            pose=pc.read(frame);a,b=CachedShape(pc,pose,member),CachedShape(pc,pose,part);state=state_of_pair(a,b)
            assert a.closed and state['closed_solid_containment']and not state['triangle_intersections']and all(helper.inside(a,q)for q in b.points)
            target=source.points(part)[0];witness=min(b.points,key=lambda q:np.linalg.norm(q-target));hit=a.tree.find_nearest(Vector(witness))
            ids={kd.find(Vector(a.points[i]))[1]for i in a.faces[hit[2]]};local=relative_points(witness[None],M)[0]
            inside=bool(np.all(local>=union.min(0)-TOL)and np.all(local<=union.max(0)+TOL));assert inside and ids&old_ids
            phase_rows.append({'phase':phase,'state':state,'all_same_original_part_vertices_inside_same_host':True,
                'old_nearest_host_source_vertices':sorted(old_ids),'current_nearest_host_source_vertices':sorted(ids),
                'finite_source_face_vertex_overlap':len(ids&old_ids),'witness_within_exact_finite_source_union':inside,
                'physical_source_export_witness_error':float(np.linalg.norm(witness-target)),
                'nearest_host_surface_distance':hit[3]});pose.close()
        rows.append({'frame':frame,'a':member,'b':part,'canonical_cold_state':old_state,
            'all_old_part_vertices_inside_old_host':True,'actual_source_and_export_regions':phase_rows,
            'classification':'RETAINED_SAME_WHOLE_FINITE_ORIGINAL_SUBPART_CONTAINMENT_AND_ADJACENT_SOURCE_FACE_REGION'})
        source.close()
    result={'status':'PASS_INHERITED_FINITE_SOURCE_AND_ACTUAL_GLB_CONTAINMENT','source_sha256':args.source_sha256,
        'glb_sha256':args.glb_sha256,'input_screen_sha256':sha(args.review_terminal_flags/'clearance.json'),'rows':rows,
        'scope':'Retains documented containment of the same old finite original subpart in the same old host. This is not a claim of clearance, new drilling, or a redesigned CAD assembly.'}
    dump(args.out/'inherited-containment-review.json',result);return result


def bounded_contact(rule,obs,shapes):
    required=['object','host','point_host_local','normal_host_local','region_radius','max_insertion_depth','reason']
    assert all(k in rule for k in required),('Incomplete bounded-contact rule',rule)
    assert rule['reason'] and float(rule['region_radius'])>0 and float(rule['max_insertion_depth'])>=0
    obj,host=rule['object'],rule['host'];M=obs[host].matrix_world
    point=M@Vector(rule['point_host_local']);normal=(M.to_3x3().inverted().transposed()@Vector(rule['normal_host_local'])).normalized()
    hp,hn,_,gap=shapes[host].tree.find_nearest(point)
    distances=np.linalg.norm(shapes[obj].points-np.asarray(hp),axis=1)
    behind=-(shapes[obj].points-np.asarray(hp))@np.asarray(normal)
    row={'object':obj,'host':host,'reason':rule['reason'],'host_anchor_surface_gap':gap,
      'whole_object_radius_from_actual_host_anchor':float(distances.max()),
      'whole_object_depth_behind_actual_host_tangent':max(0.,float(behind.max())),
      'allowed_region_radius':float(rule['region_radius']),'allowed_max_depth':float(rule['max_insertion_depth'])}
    row['pass']=(gap<=1e-4 and distances.max()<=float(rule['region_radius'])+TOL and
                 behind.max()<=float(rule['max_insertion_depth'])+TOL and hn.dot(normal)>.5)
    return row


def parent_chain(name,snapshot):
    seen=set();result=[]
    while name in snapshot['objects'] and name not in seen:
        seen.add(name);result.append(name);name=snapshot['objects'][name]['parent']
    return result


def clearance_pose(frame,phase,obs,physical,participants,baseline_cache,current_cache,
                   roots,config,snapshot,check):
    """Check only affected/new sweep pairs, preserving old rigid relationships."""
    dg=bpy.context.evaluated_depsgraph_get();margin=float(config['minimum_clearance'])
    old=baseline_cache.read(frame);cur=current_cache.read(frame)
    shapes={};boxes={n:[cur.points(n).min(axis=0),cur.points(n).max(axis=0)] for n in physical}
    preserved_roots={};root_proofs=[]
    for name in physical:
        if name not in old.index:continue
        for root in roots:
            if root not in parent_chain(name,snapshot) or root not in old.matrix_index or root not in cur.matrix_index:continue
            aa=relative_points(old.points(name),old.matrix(root));bb=relative_points(cur.points(name),cur.matrix(root))
            if aa.shape!=bb.shape:continue
            error=float(np.max(np.linalg.norm(aa-bb,axis=1))) if len(aa) else 0.
            if error<TOL:preserved_roots[name]=root;root_proofs.append({'name':name,'root':root,'error':error});break
    rules={frozenset((r['object'],r['host'])):r for r in config.get('bounded_contacts',[])}
    candidates=[];counts=collections.Counter();seen=set();physical_order=sorted(physical)
    box_array=np.asarray([boxes[n] for n in physical_order])
    for name in participants:
        if name not in physical:continue
        counts['broadphase_pairs']+=len(physical_order)-1
        mask=np.all(box_array[:,0]<=boxes[name][1]+margin,axis=1)&np.all(box_array[:,1]>=boxes[name][0]-margin,axis=1)
        counts['aabb_culled']+=int(len(mask)-np.count_nonzero(mask))
        for index in np.flatnonzero(mask):
            other=physical_order[int(index)]
            key=tuple(sorted((name,other)))
            if name==other or key in seen:continue
            seen.add(key)
            if preserved_roots.get(name) is not None and preserved_roots.get(name)==preserved_roots.get(other):
                counts['proved_same_baseline_relative_geometry']+=1;continue
            for n in key:
                if n not in shapes:shapes[n]=helper.Shape(obs[n],dg)
            state=state_of_pair(shapes[name],shapes[other]);counts['exact_pairs']+=1
            if not state['triangle_intersections'] and not state['closed_solid_containment'] and state['actual_bidirectional_vertex_surface_gap']>=margin:
                counts['clear_pairs']+=1;continue
            row=dict(state,frame=frame,phase=phase,a=name,b=other)
            rule=rules.get(frozenset(key))
            if rule:
                bound=bounded_contact(rule,obs,shapes);row['bounded_contact']=bound
                if bound['pass']:row['classification']='DECLARED_SPATIALLY_BOUNDED_CONTACT';counts['bounded_contacts']+=1
                else:row['classification']='BOUNDED_CONTACT_OUTSIDE_ACTUAL_LIMITS';check(False,phase+'_BOUNDED_CONTACT_LIMIT',row)
            else:row['classification']='REQUIRES_BASELINE_PAIR_CLASSIFICATION'
            candidates.append(row)
    old.close();cur.close()
    return candidates,dict(counts),root_proofs


def baseline_classification(rows,cache_source,cache_base,baseline_source,check):
    """A pre-existing pair is not a blanket waiver for changed contact geometry."""
    bpy.ops.wm.open_mainfile(filepath=str(baseline_source));helper.SHAPE_CONTEXT='V05_BASELINE_PAIR_CHECK'
    grouped=collections.defaultdict(list)
    for row in rows:
        if row['classification']=='REQUIRES_BASELINE_PAIR_CLASSIFICATION':grouped[row['frame']].append(row)
    for frame,jobs in grouped.items():
        bpy.context.scene.frame_set(frame);bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();obs=objects();shapes={}
        old=cache_base.read(frame);cur=cache_source.read(frame)
        for row in jobs:
            a,b=row['a'],row['b']
            if a not in old.index or b not in old.index:
                row['classification']='INTRODUCED_NEW_OBJECT_CONTACT';check(False,'INTRODUCED_NEW_OBJECT_CONTACT',row);continue
            for n in (a,b):
                if n not in shapes:shapes[n]=helper.Shape(obs[n],dg)
            baseline=state_of_pair(shapes[a],shapes[b]);row['baseline_pair']=baseline
            old_bad=baseline['triangle_intersections'] or baseline['closed_solid_containment'] or baseline['actual_bidirectional_vertex_surface_gap']<.0005
            if not old_bad:
                row['classification']='INTRODUCED_PREVIOUSLY_CLEAR_PAIR_CONTACT';check(False,'INTRODUCED_PREVIOUSLY_CLEAR_PAIR_CONTACT',row);continue
            da=cur.matrix(a)@np.linalg.inv(old.matrix(a));db=cur.matrix(b)@np.linalg.inv(old.matrix(b))
            same_delta=float(np.max(np.abs(da-db)))<1e-7
            rigid=np.max(np.abs(da[:3,:3].T@da[:3,:3]-np.eye(3)))<1e-6
            errors=[]
            for n in (a,b):
                aa=old.points(n);bb=cur.points(n)
                if aa.shape!=bb.shape:errors.append(float('inf'));continue
                expected=aa@da[:3,:3].T+da[:3,3];errors.append(float(np.max(np.linalg.norm(expected-bb,axis=1))))
            row['shared_rigid_delta_error']=float(np.max(np.abs(da-db)));row['baseline_geometry_under_shared_delta_errors']=errors
            if same_delta and rigid and max(errors)<TOL:row['classification']='PROVED_INHERITED_RIGID_CONTACT'
            else:
                row['classification']='INHERITED_CONTACT_RELATION_CHANGED_REVIEW_REQUIRED'
                check(False,'INHERITED_CONTACT_RELATION_CHANGED_WITHOUT_BOUNDED_RULE',row)
        old.close();cur.close()


def loops_and_correspondence(source_cache,export_cache,config,check,compare_geometry=True):
    maxima=[];loop_rows=[];zero_one=[]
    for frame in (POSES if compare_geometry else []):
        a=source_cache.read(frame);b=export_cache.read(frame)
        check(set(a.names)==set(b.names),'EXACT_PHYSICAL_EXPORT_NAMES',{'frame':frame,'missing':sorted(set(a.names)-set(b.names)),'extra':sorted(set(b.names)-set(a.names))})
        frame_max=0.;worst=None
        for name in sorted(set(a.names)&set(b.names)):
            aa,bb=a.points(name),b.points(name)
            if aa.shape==bb.shape:
                direct=float(np.max(np.linalg.norm(aa-bb,axis=1))) if len(aa) else 0.
            else:direct=float('inf')
            error=direct if direct<TOL else helper.world_correspondence(aa,bb)
            if error>frame_max:frame_max=error;worst=name
            check(error<TOL,'ACTUAL_GLB_WORLD_GEOMETRY_OR_MOTION',{'frame':frame,'name':name,'error':error})
        maxima.append({'frame':frame,'maximum_world_vertex_error':frame_max,'worst_object':worst})
        a.close();b.close();print('SOURCE_GLB_POSE',frame,frame_max,flush=True)
    groups=config or [{'names':source_cache.names,'frames':[1,65],'tolerance':0.,'reason':'Exact working-cycle closure'}]
    for phase,cache in [('SOURCE',source_cache),('ACTUAL_GLB',export_cache)]:
        for group in groups:
            assert group.get('reason') and len(group['frames'])>=2
            if not set(group['frames'])<=set(POSES):
                loop_rows.append({'phase':phase,'status':'NOT_RUN_DIAGNOSTIC_POSE_SUBSET','requested_frames':group['frames']});continue
            tolerance=float(group.get('tolerance',0.));assert tolerance>=0
            first=cache.read(group['frames'][0])
            for frame in group['frames'][1:]:
                other=cache.read(frame)
                for name in group['names']:
                    if name not in first.index or name not in other.index:
                        check(False,'LOOP_DECLARED_NAME_MISSING',{'phase':phase,'name':name});continue
                    aa,bb=first.points(name),other.points(name)
                    error=float(np.max(np.linalg.norm(aa-bb,axis=1))) if aa.shape==bb.shape else float('inf')
                    bit_exact=np.array_equal(aa,bb)
                    passed=bit_exact if tolerance==0 else error<=tolerance
                    row={'phase':phase,'name':name,'frames':[group['frames'][0],frame],
                         'maximum_world_vertex_error':error,'bit_exact':bit_exact,'declared_tolerance':tolerance,'pass':passed}
                    loop_rows.append(row);check(passed,'DECLARED_PHYSICAL_LOOP',row)
                other.close()
            first.close()
        if not {0,1}<=set(POSES):continue
        cold,working=cache.read(0),cache.read(1)
        for name in cache.names:
            aa,bb=cold.points(name),working.points(name)
            error=float(np.max(np.linalg.norm(aa-bb,axis=1))) if aa.shape==bb.shape else float('inf')
            zero_one.append({'phase':phase,'name':name,'cold0_to_working1_error':error,'equal':np.array_equal(aa,bb)})
        cold.close();working.close()
    return maxima,loop_rows,zero_one


def resume_actual_export(args,declarations,manifest_records,actuator_metadata,actuator_pin):
    """Resume a new GLB against already-passed, immutable 66-pose SOURCE data."""
    previous=args.resume_source_cache.resolve();prior=read(previous/'validation.json')
    assert prior['source_sha256']==args.source_sha256 and prior['baseline_source_sha256']==BASE_PIN
    assert prior['frames']==POSES and not prior['failures'],'Prior source evidence is incomplete/failed'
    source_rows=[r for r in prior.get('actuator_rows',[]) if r['phase']=='SOURCE']
    assert len(source_rows)==len(POSES)*2 and {r['frame'] for r in source_rows}==set(POSES)
    assert all(prior['inputs_unchanged_during_run'].values())
    old_assembly=read(prior['actuator_manifest']['path'])['assemblies']
    assert old_assembly==actuator_metadata['assemblies'],'Actuator targets changed since SOURCE proof'
    assert prior['declarations']==manifest_records,'Source change declarations changed since SOURCE proof'
    source_cache=PoseCache(previous/'source-physical-cache')
    assert all((source_cache.path/f'pose-{f:02d}.npz').is_file() for f in POSES)
    failures=[]
    def check(ok,gate,context):
        if not ok:
            failures.append({'gate':gate,'context':context})
            if len(failures)<=20:print('FIRST_FAILURE',gate,json.dumps(context,default=helper.json_default)[:3000],flush=True)
    report={k:v for k,v in prior.items() if k not in {'status','exception','failures','progress','inputs_unchanged_during_run','checker_sha256','glb_sha256'}}
    report.update(status='RUNNING_RESUMED_ACTUAL_GLB',glb_sha256=args.glb_sha256,
        checker_sha256=sha(__file__),source_proof_reused_from={'path':str(previous/'validation.json'),
        'sha256':sha(previous/'validation.json'),'reason':'All66 SOURCE poses passed; prior actual-export phase stopped on a hierarchy lookup. This run binds a new GLB to the identical source without repeating SOURCE66.'},
        failures=failures)
    report['actuator_rows']=source_rows.copy();report['source_glb_world_vertex_errors']=[]
    def checkpoint():dump(args.out/'validation.json',report)
    checkpoint()
    try:
        bpy.ops.wm.open_mainfile(filepath=str(args.source));snapshot=helper.original_snapshot()
        required_empties={n for n,r in snapshot['objects'].items() if r['type']=='EMPTY'}
        source_parents={n:r['parent'] for n,r in snapshot['objects'].items()}
        raw=helper.glb_json(args.glb);nodes=raw.get('nodes',[]);raw_names={n.get('name') for n in nodes}
        parents={nodes[c].get('name'):n.get('name') for n in nodes for c in n.get('children',[])}
        physical_nodes={n.get('name') for n in nodes if 'mesh' in n}
        check(required_empties<=raw_names,'CANONICAL_EMPTY_HIERARCHY_NOT_EXPORTED',sorted(required_empties-raw_names))
        for name in required_empties|set(source_cache.names):
            expected=source_parents[name]
            check(parents.get(name)==expected,'ACTUAL_GLB_CANONICAL_PARENT_EDGE',{'node':name,'expected_parent':expected,'actual_parent':parents.get(name)})
        check(not set(declarations['source_only_names'])&physical_nodes,'SOURCE_ONLY_VOLUME_EXPORTED',None)
        check(bool(raw.get('animations')),'ACTUAL_GLB_HAS_NO_ANIMATION',None)
        check(all('bufferView'in im and 'uri'not in im for im in raw.get('images',[])),'ACTUAL_GLB_IMAGES_NOT_EMBEDDED',None)
        report['canonical_empty_hierarchy']={'required_names':sorted(required_empties),'actual_node_count':len(nodes),
            'expected_physical_mesh_count':len(source_cache.names),'actual_physical_mesh_count':len(physical_nodes)}
        serialized=helper.RawGLB(args.glb);sample_rows=[]
        expected_times=np.asarray(POSES,dtype=float)*snapshot['fps_base']/snapshot['fps']
        for clip in serialized.json.get('animations',[]):
            for channel in clip['channels']:
                target=channel['target'];name=serialized.json['nodes'][target['node']].get('name')
                if name!=args.core_name or target['path'] not in {'translation','rotation'}:continue
                sampler=clip['samplers'][channel['sampler']];times=serialized.accessor(sampler['input']).reshape(-1)
                error=float(np.max(np.abs(times-expected_times))) if len(times)==len(POSES) else None
                row={'clip':clip.get('name'),'node':name,'path':target['path'],'sample_count':len(times),
                     'time_range_seconds':[float(times.min()),float(times.max())],
                     'expected_frames':POSES,'maximum_timestamp_error_seconds':error}
                sample_rows.append(row)
                check(error is not None and error<1e-6,'ACTUAL_GLB_COLD0_WORKING1_TO64_WRAP65_TIMESTAMPS',row)
        check({r['path'] for r in sample_rows}=={'translation','rotation'},'ACTUAL_GLB_CORE_MOTION_CHANNELS_MISSING',sample_rows)
        report['core_serialized66_sample_times']=sample_rows
        if failures:report['status']='FAIL_ACTUAL_GLB_HIERARCHY_OR_PACKAGING';checkpoint();raise SystemExit(1)
        bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.scene.render.fps=snapshot['fps'];bpy.context.scene.render.fps_base=snapshot['fps_base']
        bpy.ops.import_scene.gltf(filepath=str(args.glb));obs=objects();physical={n for n,o in obs.items() if o.type=='MESH'}
        cache=PoseCache(args.out/'actual-glb-physical-cache',physical);helper.SHAPE_CONTEXT='V06_RESUMED_ACTUAL_GLB'
        bpy.context.scene.frame_set(0);bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
        guards=[helper.new_mesh_check(obs[n],dg,{}) for n in declarations['new_names'] if n in physical]
        report['new_actual_glb_mesh_guards']=guards
        for row in guards:check(row['finite'] and row['degenerate_triangles']==0 and row['nonmanifold_geometric_edges']==0 and not row['missing_uv'] and row['collapsed_uv_triangles']==0,'NEW_ACTUAL_GLB_GEOMETRY_UV_PBR',row)
        for frame in POSES:
            bpy.context.scene.frame_set(frame);bpy.context.view_layer.update();cache.write(frame,objects(),check)
            actor,typed_pairs=actuator_pose('ACTUAL_GLB',frame,cache,actuator_metadata,args.core_name,check)
            report['actuator_rows']+=actor;a,b=source_cache.read(frame),cache.read(frame)
            check(set(a.names)==set(b.names),'EXACT_PHYSICAL_EXPORT_NAMES',{'missing':sorted(set(a.names)-set(b.names)),'extra':sorted(set(b.names)-set(a.names))})
            maximum=0.;worst=None
            for name in sorted(set(a.names)&set(b.names)):
                aa,bb=a.points(name),b.points(name)
                direct=float(np.max(np.linalg.norm(aa-bb,axis=1))) if aa.shape==bb.shape and len(aa) else float('inf')
                error=direct if direct<TOL else helper.world_correspondence(aa,bb)
                if error>maximum:maximum=error;worst=name
                check(error<TOL,'ACTUAL_GLB_WORLD_GEOMETRY_OR_MOTION',{'frame':frame,'name':name,'error':error})
            a.close();b.close();report['source_glb_world_vertex_errors'].append({'frame':frame,'maximum_world_vertex_error':maximum,'worst_object':worst})
            report['progress']={'phase':'ACTUAL_GLB','frame':frame};checkpoint()
            print('RESUMED_ACTUAL_GLB_POSE',frame,'max_world_error',maximum,'failures',len(failures),flush=True)
            if failures:report['status']='FAIL_FIRST_RESUMED_ACTUAL_GLB_POSE';checkpoint();raise SystemExit(1)
        _,loops,cold=loops_and_correspondence(source_cache,cache,declarations['loop_groups'],check,compare_geometry=False)
        report['physical_loops']=loops;report['cold0_working1_distinction']=cold
        report['maximum_world_vertex_error']=max(r['maximum_world_vertex_error'] for r in report['source_glb_world_vertex_errors'])
        report['status']='PASS_MOTION_EXPORT_CLEARANCE_DEFERRED' if not failures else 'FAIL_RESUMED_ACTUAL_GLB_MOTION'
    except Exception as error:
        report['status']='ERROR_INCOMPLETE_RESUMED_GLB_VALIDATION';report['exception']={'type':type(error).__name__,'message':str(error)};raise
    finally:
        pins={'source':sha(args.source)==args.source_sha256,'glb':sha(args.glb)==args.glb_sha256,
              'reused_source_report':sha(previous/'validation.json')==report['source_proof_reused_from']['sha256'],
              'declarations':all(sha(x['path'])==x['sha256'] for x in manifest_records),'actuator_manifest':sha(args.actuator_manifest)==actuator_pin}
        report['inputs_unchanged_during_run']=pins
        if not all(pins.values()):report['status']='FAIL_RESUMED_INPUTS_CHANGED'
        checkpoint()
    print(report['status'],'failures',len(failures),'report',args.out/'validation.json',flush=True)
    if not report['status'].startswith('PASS_'):raise SystemExit(1)


def targeted32_source_clearance(args,metadata):
    """Finite final interference screen, reusing SOURCE66 and author roles."""
    source_dir=args.targeted32_source_cache.resolve();proof=read(source_dir/'validation.json')
    assert proof['source_sha256']==args.source_sha256 and not proof['failures']
    assert len([r for r in proof['actuator_rows'] if r['phase']=='SOURCE'])==132
    roles=read(args.mechanical_role_contract)
    assert roles['current_source_sha256']==args.source_sha256 and roles['current_glb_sha256']==args.glb_sha256
    provenance_path=BASE/'provenance/v04-source-manifest.json';provenance=read(provenance_path)
    union_roles=roles.get('inherited_union_assembly_regions',[])
    for r in union_roles:
        assert r['reason'] and r['union_prefix']==f"V04 seated union {r['source_joint_index']:03d} "
        assert r['source_joint_index']<len(provenance['mechanical_refinement']['seated_pipe_end_joints'])
    cache=PoseCache(source_dir/'source-physical-cache');root_changes=read(args.changes[0])
    targets=set();mapping={r['new_name']:r['baseline_name'] for r in roles['functional_replacements']}
    for assembly in metadata['assemblies']:
        targets.update(assembly['fixed_barrel_group']+assembly['sliding_group']+[assembly['aft_load_web']])
        body=assembly['fixed_barrel_group'][0];mapping[body]=body
    for name in root_changes['allowed_source_changes']:
        if name.startswith(('V04 cold bulk radial feed','V04 regenerative turbo supply','V04 injector bridge support')):targets.add(name)
    assert len(targets)==32 and targets<=set(cache.names)
    work=ROOT/'build/thruster-resume-20261117/thetazine-v06-motion'
    gap_proof_path=work/'independent08g-local32-source-clearance/bounded-gap-equivalence.json'
    gap_proof=read(gap_proof_path)
    assert gap_proof['status'].startswith('PASS_') and all(r['equivalent']for r in gap_proof['rows'])
    assert sha(gap_proof_path.with_name('bounded-fastpath-tested-checker.py'))==gap_proof['checker_sha256']
    static_names=set(read(work/'core05-fixedbrackets/static-allowed-changes.json')['new_names'])
    static_report=read(work/'core07-collar-aligned/static-bracket-moving-clearance.json')
    lineage=read(work/'core08-matched-collar-facets/facet-repair-lineage-validation.json')
    assert not static_report['failures'] and not lineage['failures'] and lineage['final_source_sha256']==args.source_sha256
    bpy.ops.wm.open_mainfile(filepath=str(args.baseline));bpy.context.scene.frame_set(0);bpy.context.view_layer.update()
    baseline=objects();cold=cache.read(0);cold_shapes={};cold_matrices={};corridors={};axes={}
    for assembly in metadata['assemblies']:
        body=assembly['fixed_barrel_group'][0]
        axis=np.asarray(assembly['rest_aft_pin_centroid'])-np.asarray(assembly['fixed_pin_centroid']);axis/=np.linalg.norm(axis);axes[body]=axis
        shape=helper.Shape(baseline[body],bpy.context.evaluated_depsgraph_get());cold_shapes[body]=shape
        cold_matrices[body]=np.asarray(baseline[body].matrix_world).copy()
        center=shape.points.mean(axis=0);z=(shape.points-center)@axis
        radius=np.linalg.norm((shape.points-center)-z[:,None]*axis,axis=1)
        corridors[body]={'center':center,'axis':axis,'radius':float(radius.max()),'axial_low':float(z.min()),'axial_high':float(z.max())}
    report={'status':'RUNNING_MAPPED32_SOURCE_CLEARANCE','source_sha256':args.source_sha256,'glb_binding_sha256':args.glb_sha256,
      'checker_sha256':sha(__file__),'source_proof_sha256':sha(source_dir/'validation.json'),
      'mechanical_role_contract_sha256':sha(args.mechanical_role_contract),'units':'Blender units (BU)',
      'canonical_union_provenance_sha256':sha(provenance_path),'inherited_finite_union_roles':union_roles,
      'bounded_gap_fastpath':{'equivalence_report_sha256':sha(gap_proof_path),'margin_unchanged':.0005,
        'policy':'Exact crossing/containment and exact under-margin vertex-surface minima. Separated pairs return an explicitly labelled conservative lower bound at the SAME .0005 margin.'},
      'scope':'32 exact source participants vs near physical nonmates. No core-root general sweep or old petal/ram audit. Reuses 110 static-vs-other-moving receipt through exact07-to08 lineage; four authored shafts remain screened.',
      'participants':sorted(targets),'functional_replacements':mapping,'canonical_shaft_corridors':corridors,
      'axis_clarification':roles['axis_correction_clarification'],
      'replacement_policy':'Actual replacement vertices must remain inside the measured canonical shaft radial/axial corridor after inverse measured rigid motion, AND the exact finite host must already have contacted the original shaft. Changed profiles and current contacts are disclosed; this does not claim unchanged triangle patches or universal CAD collision freedom.',
      'rows':[],'failures':[],'classifier_flags':[],'per_frame':[]}
    def save():dump(args.out/'clearance.json',report)
    def cold_shape(name,frame):
        if name not in cold_shapes:
            bpy.context.scene.frame_set(0);bpy.context.view_layer.update()
            cold_shapes[name]=helper.Shape(baseline[name],bpy.context.evaluated_depsgraph_get())
            cold_matrices[name]=np.asarray(baseline[name].matrix_world).copy()
            bpy.context.scene.frame_set(frame);bpy.context.view_layer.update()
        return cold_shapes[name]
    def patch_ids(a,b):
        ia=set();ib=set()
        for i,j in a.tree.overlap(b.tree):
            if helper.triangle_intersects(a.triangles[i],b.triangles[j]):ia.update(map(int,a.faces[i]));ib.update(map(int,b.faces[j]))
        return ia,ib
    def near_patch_ids(a,b,margin=.0005):
        # The predeclared clearance test treats old under-margin gaps as old
        # contact regions too. Such a region has no intersecting faces; recover
        # its actual finite closest source-face vertices rather than changing
        # the margin or pretending the old surfaces intersected.
        ia=set();ib=set()
        for src,dst,own,host in [(a,b,ia,ib),(b,a,ib,ia)]:
            for i,p in enumerate(src.points):
                hit=dst.tree.find_nearest(Vector(p))
                if hit[0] is not None and hit[3]<margin:
                    own.add(i);host.update(map(int,dst.faces[hit[2]]))
        return ia,ib
    def contained_patch_ids(a,b):
        ia=set();ib=set()
        for src,dst,own,host in [(a,b,ia,ib),(b,a,ib,ia)]:
            if not dst.closed:continue
            for i,p in enumerate(src.points):
                if helper.inside(dst,p):
                    hit=dst.tree.find_nearest(Vector(p))
                    own.add(i);host.update(map(int,dst.faces[hit[2]]))
        return ia,ib
    def crossing_points(a,b):
        result=[]
        for i,j in a.tree.overlap(b.tree):
            ta,tb=a.triangles[i],b.triangles[j]
            if not helper.triangle_intersects(ta,tb):continue
            for edge,face in [(ta,tb),(tb,ta)]:
                for k in range(3):
                    p,q=edge[k],edge[(k+1)%3];d=q-p
                    hit=intersect_ray_tri(*map(Vector,face),Vector(d),Vector(p),True)
                    if hit is not None and np.dot(np.asarray(hit)-p,d)<=np.dot(d,d)+1e-10:result.append(np.asarray(hit))
        return np.asarray(result)
    def under_margin_witnesses(a,b):
        result=[]
        for src,dst in [(a,b),(b,a)]:
            for point in src.points:
                hit=dst.tree.find_nearest(Vector(point),.0005)
                if hit[0]is not None:result.extend((point,np.asarray(hit[0])))
        return np.asarray(result)
    cycle_pairs={}
    def canonical_cycle_contacts(member,host,current_frame):
        key=(member,host)
        if key not in cycle_pairs:
            hits=[]
            for old_frame in range(66):
                bpy.context.scene.frame_set(old_frame);bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
                aa=helper.Shape(baseline[member],dg);bb=helper.Shape(baseline[host],dg);st=state_of_pair(aa,bb)
                if st['triangle_intersections']or st['closed_solid_containment']or st['actual_bidirectional_vertex_surface_gap']<.0005:
                    if st['triangle_intersections']:ia,ib=patch_ids(aa,bb)
                    elif st['closed_solid_containment']:ia,ib=contained_patch_ids(aa,bb)
                    else:ia,ib=near_patch_ids(aa,bb)
                    hits.append({'frame':old_frame,'state':st,'member_ids':ia,'host_ids':ib,
                        'member_points':aa.points,'host_points':bb.points,'host_matrix':np.asarray(baseline[host].matrix_world).copy()})
            cycle_pairs[key]=hits;bpy.context.scene.frame_set(current_frame);bpy.context.view_layer.update()
        return cycle_pairs[key]
    start_frame=0
    if args.resume_targeted_prefix:
        prior_path=args.resume_targeted_prefix.resolve()/'clearance.json';prior=read(prior_path)
        assert prior['source_sha256']==report['source_sha256'] and prior['glb_binding_sha256']==report['glb_binding_sha256']
        assert prior['participants']==report['participants'] and prior['mechanical_role_contract_sha256']==report['mechanical_role_contract_sha256']
        passed=[r for r in prior['per_frame'] if not any(f['frame']==r['frame'] for f in prior['failures'])]
        assert [r['frame']for r in passed]==list(range(len(passed)))
        start_frame=len(passed);report['per_frame']=passed
        report['rows']=[r for r in prior['rows']if r['frame']<start_frame]
        report['classifier_flags']=[r for r in prior.get('classifier_flags',[])if r['frame']<start_frame]
        report['reused_passing_prefix']={'path':str(prior_path),'sha256':sha(prior_path),'frames':list(range(start_frame)),
            'executed_checker_sha256':prior['checker_sha256'],'reason':'Retain immutable completed passing source-pose evidence; resume at the first unresolved pose after checker-only contact classification repair.'}
    interface_report=read(work/'core-03c-seated-interfaces/interface-validation.json')
    interface_manifest=read(work/'core-03c-seated-interfaces/interface-retarget.json')
    assert interface_report['status'].startswith('PASS_') and interface_report['max_support_seat_error']<TOL
    support_mates={frozenset((r['mesh'],r['actual_host']))for r in interface_manifest['changed_objects']if r['mesh'].startswith('V04 injector bridge support')}
    assert len(support_mates)==4
    report['reused_exact_support_seats']={'report_sha256':sha(work/'core-03c-seated-interfaces/interface-validation.json'),
        'lineage_sha256':sha(work/'core08-matched-collar-facets/facet-repair-lineage-validation.json'),
        'pairs':[sorted(p)for p in support_mates],'maximum_actual_seat_error':interface_report['max_support_seat_error']}
    old_mates={};legacy_cold_mates={};save()
    for frame in POSES[start_frame:]:
        pose=cache.read(frame);bpy.context.scene.frame_set(frame);bpy.context.view_layer.update()
        names=cache.names;index={n:i for i,n in enumerate(names)}
        boxes=np.asarray([[pose.points(n).min(axis=0),pose.points(n).max(axis=0)] for n in names])
        shapes={};old_shapes={};seen=set();counts=collections.Counter();envelopes={};typed=set();union_cache={}
        for name,body in mapping.items():
            D=pose.matrix(name)@np.linalg.inv(cold.matrix(name));inverse=np.linalg.inv(D)
            q=pose.points(name)@inverse[:3,:3].T+inverse[:3,3];c=corridors[body];z=(q-c['center'])@c['axis']
            radial=np.linalg.norm((q-c['center'])-z[:,None]*c['axis'],axis=1)
            row={'actual_max_radius':float(radial.max()),'canonical_max_radius':c['radius'],
                 'actual_axial_range':[float(z.min()),float(z.max())],'canonical_axial_range':[c['axial_low'],c['axial_high']]}
            row['pass']=radial.max()<=c['radius']+TOL and z.min()>=c['axial_low']-TOL and z.max()<=c['axial_high']+TOL
            envelopes[name]=row
            if not row['pass']:report['failures'].append(dict(row,frame=frame,a=name,classification='REPLACEMENT_OUTSIDE_CANONICAL_SHAFT_CORRIDOR'))
        for row in proof['actuator_rows']:
            if row['phase']!='SOURCE' or row['frame']!=frame:continue
            for seat in row['annular_sleeve_seats']:
                assert seat['pass'];typed.add(frozenset((seat['collar'],seat['shaft'])))
            for seat in row['finite_original_clevis_contacts']:
                assert seat['pass_contact'];typed.add(frozenset((seat['member'],seat['host'])))
        for name in sorted(targets):
            i=index[name];mask=np.all(boxes[:,0]<=boxes[i,1]+.0005,axis=1)&np.all(boxes[:,1]>=boxes[i,0]-.0005,axis=1)
            counts['broadphase_pairs']+=len(names)-1;counts['aabb_culled']+=len(names)-int(mask.sum())
            for j in np.flatnonzero(mask):
                other=names[int(j)];key=tuple(sorted((name,other)))
                if name==other or key in seen:continue
                seen.add(key)
                if other in static_names and name not in mapping:counts['reused_static_moving_receipt']+=1;continue
                if frozenset(key) in typed:counts['dedicated_actual_fit_mate']+=1;continue
                if frozenset(key) in support_mates:counts['reused_exact_actual_support_seat']+=1;continue
                for n in key:
                    if n not in shapes:shapes[n]=CachedShape(cache,pose,n)
                a,b=shapes[name],shapes[other];state=state_of_pair(a,b);counts['exact_pairs']+=1
                if not state['triangle_intersections'] and not state['closed_solid_containment'] and state['actual_bidirectional_vertex_surface_gap']>=.0005:
                    counts['clear_pairs']+=1;continue
                row=dict(state,frame=frame,a=name,b=other,classification='UNRESOLVED')
                shaft=name if name in mapping else other if other in mapping else None
                host=other if shaft==name else name
                if shaft is not None and host in baseline:
                    body=mapping[shaft];pair=(body,host)
                    if pair not in old_mates:old_mates[pair]=state_of_pair(cold_shape(body,frame),cold_shape(host,frame))
                    old_contact=old_mates[pair];row['canonical_old_role']=body;row['canonical_rest_host_contact']=old_contact;row['replacement_corridor']=envelopes[shaft]
                    if envelopes[shaft]['pass'] and (old_contact['triangle_intersections'] or old_contact['closed_solid_containment']):
                        row['classification']='INHERITED_FUNCTIONAL_REPLACEMENT_WITHIN_OLD_SHAFT_CORRIDOR'
                        row['legacy_near_gap_below_generic_margin']=not (state['triangle_intersections'] or state['closed_solid_containment'])
                    elif envelopes[shaft]['pass']:
                        old_cycle=canonical_cycle_contacts(body,host,frame)
                        current_shaft,current_host=shapes[shaft],shapes[host]
                        _,host_ids=patch_ids(current_shaft,current_host)if state['triangle_intersections']else near_patch_ids(current_shaft,current_host)
                        row['canonical_old_fullcycle_host_contacts']=[{'frame':r['frame'],**r['state'],'host_source_face_vertex_overlap':len(host_ids&r['host_ids'])}for r in old_cycle]
                        if any(host_ids&r['host_ids']for r in old_cycle):
                            row['classification']='INHERITED_FUNCTIONAL_REPLACEMENT_WITHIN_OLD_CORRIDOR_AND_ACTUAL_OLD_CYCLE_HOST_REGION'
                        elif old_cycle:
                            row['classification']='COLLECTED_LEGACY_REPLACEMENT_HOST_REGION_CLASSIFIER_FLAG';report['classifier_flags'].append(row)
                if row['classification']=='UNRESOLVED' and name in baseline and other in baseline:
                    for n in key:
                        if n not in old_shapes:old_shapes[n]=helper.Shape(baseline[n],bpy.context.evaluated_depsgraph_get())
                    aa,bb=old_shapes[name],old_shapes[other];old=state_of_pair(aa,bb);row['baseline_state']=old
                    if old['triangle_intersections'] or old['closed_solid_containment'] or old['actual_bidirectional_vertex_surface_gap']<.0005:
                        D=pose.matrix(name)@np.linalg.inv(np.asarray(baseline[name].matrix_world));errors=[]
                        for n,original in [(name,aa),(other,bb)]:
                            current=pose.points(n);expected=original.points@D[:3,:3].T+D[:3,3]
                            errors.append(float(np.max(np.linalg.norm(expected-current,axis=1))) if expected.shape==current.shape else float('inf'))
                        if max(errors)<TOL and np.max(np.abs(D[:3,:3].T@D[:3,:3]-np.eye(3)))<1e-6:
                            row['classification']='PROVED_INHERITED_SHARED_RIGID_CONTACT';row['actual_geometry_errors']=errors
                        elif state['closed_solid_containment'] and old['closed_solid_containment']:
                            contained=[]
                            for small,large,prior_small,prior_large,label in [(a,b,aa,bb,name),(b,a,bb,aa,other)]:
                                if small.points.shape==prior_small.points.shape and all(helper.inside(large,p) for p in small.points) and all(helper.inside(prior_large,p) for p in prior_small.points):contained.append(label)
                            if contained:row['classification']='INHERITED_SAME_FINITE_CONTAINED_SOURCE_PART';row['actual_contained_parts']=contained
                            else:
                                # Legacy source contains overlapping assembly
                                # representations. Preserve a matching actual
                                # containment witness on the same finite face
                                # region; do not claim whole-part containment.
                                for small,large,prior_small,prior_large,small_name,host_name in [(a,b,aa,bb,name,other),(b,a,bb,aa,other,name)]:
                                    if not (large.closed and prior_large.closed and helper.inside(large,small.points[0]) and helper.inside(prior_large,prior_small.points[0])):continue
                                    old_face=prior_large.tree.find_nearest(Vector(prior_small.points[0]))[2]
                                    new_face=large.tree.find_nearest(Vector(small.points[0]))[2]
                                    old_ids=set(map(int,prior_large.faces[old_face]));new_ids=set(map(int,large.faces[new_face]))
                                    if old_ids&new_ids:
                                        old_local=relative_points(prior_small.points[:1],np.asarray(baseline[host_name].matrix_world))
                                        new_local=relative_points(small.points[:1],pose.matrix(host_name))
                                        row['classification']='INHERITED_SAME_FINITE_CONTAINMENT_WITNESS_REGION'
                                        row['legacy_witness_host_local_drift']=float(np.linalg.norm(old_local-new_local))
                                        row['legacy_witness_part']=small_name;row['legacy_host_face_vertex_overlap']=len(old_ids&new_ids)
                                        break
                        if row['classification']=='UNRESOLVED' and a.points.shape==aa.points.shape and b.points.shape==bb.points.shape and (state['triangle_intersections'] or state['actual_bidirectional_vertex_surface_gap']<.0005) and (old['triangle_intersections'] or old['closed_solid_containment'] or old['actual_bidirectional_vertex_surface_gap']<.0005):
                            ca,cb=patch_ids(a,b) if state['triangle_intersections'] else near_patch_ids(a,b)
                            if old['triangle_intersections']:oa,ob=patch_ids(aa,bb);region='INTERSECTING_SOURCE_FACES'
                            elif old['closed_solid_containment']:oa,ob=contained_patch_ids(aa,bb);region='ACTUAL_CONTAINED_VERTEX_NEAREST_SOURCE_FACES'
                            else:oa,ob=near_patch_ids(aa,bb);region='ACTUAL_UNDER_MARGIN_NEAREST_SOURCE_FACES'
                            row['baseline_contact_region_kind']=region
                            ia=sorted(ca|oa);ib=sorted(cb|ob)
                            oldM=np.asarray(baseline[other].matrix_world);newM=pose.matrix(other)
                            e=max(float(np.max(np.linalg.norm(relative_points(a.points[ia],newM)-relative_points(aa.points[ia],oldM),axis=1))),float(np.max(np.linalg.norm(relative_points(b.points[ib],newM)-relative_points(bb.points[ib],oldM),axis=1))))
                            row['actual_terminal_patch_host_local_error']=e
                            if e<TOL:row['classification']='PROVED_INHERITED_ACTUAL_TERMINAL_PATCH'
                            elif ca&oa and cb&ob:
                                # Explicit final acceptance scope permits
                                # animated roughness on the SAME old parts and
                                # overlapping original local source-face region.
                                # Record drift; this is not pointwise invariance
                                # or a claim of newly perfected CAD seating.
                                row['classification']='ANIMATED_INHERITED_SAME_PART_LOCAL_REGION_ROUGHNESS'
                                row['legacy_contact_vertex_overlap']=[len(ca&oa),len(cb&ob)]
                if row['classification']=='UNRESOLVED' and state['triangle_intersections']:
                    # Only explicitly authorized old finite union assemblies may
                    # classify a newly touched retained bolt/subpart as local
                    # inherited assembly roughness. The exact new subpart pair
                    # remains disclosed, with actual crossing points and drift.
                    for role in union_roles:
                        member=role['member'];prefix=role['union_prefix']
                        if member not in key:continue
                        host=other if name==member else name
                        if not host.startswith(prefix):continue
                        ukey=(member,prefix)
                        if ukey not in union_cache:
                            parts=sorted(n for n in baseline if n.startswith(prefix) and n in pose.index)
                            boss=prefix+'welded socket boss';assert boss in parts
                            original=helper.Shape(baseline[member],bpy.context.evaluated_depsgraph_get())
                            original_ids=set();old_contacts=[];part_points=[];rigid_errors=[]
                            old_boss=np.asarray(baseline[boss].matrix_world);new_boss=pose.matrix(boss);D=new_boss@np.linalg.inv(old_boss)
                            for part in parts:
                                sh=helper.Shape(baseline[part],bpy.context.evaluated_depsgraph_get());st=state_of_pair(original,sh)
                                if st['triangle_intersections']:
                                    ids,_=patch_ids(original,sh);original_ids.update(ids);old_contacts.append(dict(host=part,**st))
                                elif st['closed_solid_containment']:
                                    ids,_=contained_patch_ids(original,sh);original_ids.update(ids);old_contacts.append(dict(host=part,**st))
                                part_points.append(relative_points(sh.points,old_boss))
                                expected=sh.points@D[:3,:3].T+D[:3,3];actual=pose.points(part)
                                rigid_errors.append(float(np.linalg.norm(expected-actual,axis=1).max()) if expected.shape==actual.shape else float('inf'))
                            all_points=np.concatenate(part_points)
                            union_cache[ukey]=(original_ids,old_contacts,all_points.min(0),all_points.max(0),max(rigid_errors),new_boss,original)
                        old_ids,old_contacts,low,high,rigid_error,new_boss,original=union_cache[ukey]
                        current=shapes[member];host_shape=shapes[host];ids,_=patch_ids(current,host_shape)
                        crosses=crossing_points(current,host_shape)
                        local=relative_points(crosses,new_boss) if len(crosses) else np.empty((0,3))
                        within=bool(len(local) and np.all(local>=low-TOL) and np.all(local<=high+TOL))
                        proofrow={'union_prefix':prefix,'source_joint_index':role['source_joint_index'],
                            'source_joint':provenance['mechanical_refinement']['seated_pipe_end_joints'][role['source_joint_index']],
                            'exact_old_contact_parts':old_contacts,'source_face_vertex_overlap':len(ids&old_ids),
                            'actual_crossing_point_count':len(local),'actual_crossing_bounds_boss_local':[local.min(0),local.max(0)] if len(local) else None,
                            'canonical_finite_union_bounds_boss_local':[low,high],'all_union_part_rigid_geometry_error':rigid_error,
                            'all_crossings_within_canonical_finite_union':within,'new_exact_subpart_pair':True}
                        row['inherited_finite_union_assembly']=proofrow
                        if old_contacts and ids&old_ids and within and rigid_error<TOL:
                            row['classification']='NEW_SUBPART_CONTACT_IN_INHERITED_SAME_FINITE_UNION_ASSEMBLY_REGION'
                            inds=sorted(ids);oldlocal=relative_points(original.points[inds],np.asarray(baseline[host].matrix_world));newlocal=relative_points(current.points[inds],pose.matrix(host))
                            row['legacy_assembly_source_patch_host_local_drift']=float(np.linalg.norm(oldlocal-newlocal,axis=1).max())
                        break
                terminal_cases=[('Actuator support clevis.001','V04 restraint hydraulic feed 6',77),('Actuator support clevis.003','V04 restraint hydraulic feed 0',65)]
                terminal_case=next((r for r in terminal_cases if frozenset(key)==frozenset(r[:2])),None)
                if row['classification']=='UNRESOLVED' and terminal_case:
                    # Root's bounded collect-first instruction: this exact
                    # newly touched pipe is connected to an already-fouled
                    # source union077 terminal. Do NOT claim it lies within the
                    # union envelope or approve it here. Retain the measured
                    # finite outside amount and same clevis source-face region
                    # as a post-pass classifier flag, not a generic waiver.
                    member,pipe,joint_index=terminal_case;prefix=f'V04 seated union {joint_index:03d} '
                    assert provenance['mechanical_refinement']['seated_pipe_end_joints'][joint_index]['pipe']==pipe
                    curmember,curpipe=shapes[member],shapes[pipe];ids,_=patch_ids(curmember,curpipe)if state['triangle_intersections']else near_patch_ids(curmember,curpipe)
                    oldmember=cold_shape(member,frame);old_ids=set();old_parts=[]
                    parts=sorted(n for n in baseline if n.startswith(prefix) and n in pose.index)
                    for part in parts:
                        oldpart=cold_shape(part,frame);st=state_of_pair(oldmember,oldpart)
                        if st['triangle_intersections']:
                            pids,_=patch_ids(oldmember,oldpart);old_ids.update(pids);old_parts.append(dict(host=part,**st))
                    if ids&old_ids:
                        boss=prefix+'welded socket boss';M=pose.matrix(boss)
                        all_points=np.concatenate([relative_points(pose.points(n),M)for n in parts]);lo,hi=all_points.min(0),all_points.max(0)
                        cross=crossing_points(curmember,curpipe)if state['triangle_intersections']else under_margin_witnesses(curmember,curpipe);local=relative_points(cross,M)
                        row['connected_source_terminal_subpart']={'source_joint_index':joint_index,
                            'source_joint':provenance['mechanical_refinement']['seated_pipe_end_joints'][joint_index],
                            'old_fouled_source_region_reference_frame':0,
                            'exact_old_contact_parts':old_parts,'same_clevis_source_vertex_overlap':len(ids&old_ids),
                            'actual_crossing_point_count':len(local),'actual_crossing_bounds_boss_local':[local.min(0),local.max(0)],
                            'finite_original_union_bounds_boss_local':[lo,hi],
                            'maximum_crossing_outside_union_envelope':float(np.maximum(np.maximum(lo-local,local-hi),0).max()),
                            'witness_kind':'ACTUAL_TRIANGLE_EDGE_CROSSINGS'if state['triangle_intersections']else'ACTUAL_UNDER_MARGIN_NEAREST_VERTEX_SURFACE_PAIRS',
                            'scope':'COLLECTED FOR POST-PASS REVIEW; pipe is related to this exact old union and clevis face. This does not claim inside the strict union envelope or collision-free geometry.'}
                        row['classification']='COLLECTED_CONNECTED_SOURCE_TERMINAL_SUBPART_FLAG';report['classifier_flags'].append(row)
                if row['classification']=='UNRESOLVED' and name in baseline and other in baseline:
                    # Final scope collects legacy classifier flags rather than
                    # restarting for every animated old seat/coplanar contact.
                    # A host pair already bad in canonical cold0 remains an old
                    # host even when the original animation clears it later.
                    if key not in legacy_cold_mates:
                        legacy_cold_mates[key]=state_of_pair(cold_shape(name,frame),cold_shape(other,frame))
                    old0=legacy_cold_mates[key];old_now=row.get('baseline_state',{})
                    bad=lambda s:bool(s.get('triangle_intersections')or s.get('closed_solid_containment')or s.get('actual_bidirectional_vertex_surface_gap',float('inf'))<.0005)
                    if bad(old0)or bad(old_now):
                        row['canonical_cold_same_pair_state']=old0
                        ca,cb=patch_ids(a,b)if state['triangle_intersections']else near_patch_ids(a,b)
                        aa0,bb0=cold_shape(name,frame),cold_shape(other,frame)
                        if old0['triangle_intersections']:oa,ob=patch_ids(aa0,bb0)
                        elif old0['closed_solid_containment']:oa,ob=contained_patch_ids(aa0,bb0)
                        else:oa,ob=near_patch_ids(aa0,bb0)
                        row['cold_source_face_vertex_overlap']=[len(ca&oa),len(cb&ob)]
                        if a.points.shape==aa0.points.shape and b.points.shape==bb0.points.shape and ca and cb:
                            ia=sorted(ca|oa);ib=sorted(cb|ob);oldM=cold_matrices[other];newM=pose.matrix(other)
                            row['canonical_cold_patch_host_local_drift']=max(float(np.linalg.norm(relative_points(a.points[ia],newM)-relative_points(aa0.points[ia],oldM),axis=1).max()),float(np.linalg.norm(relative_points(b.points[ib],newM)-relative_points(bb0.points[ib],oldM),axis=1).max()))
                        if ca&oa and cb&ob:row['classification']='ANIMATED_INHERITED_COLD_SAME_PART_LOCAL_REGION_ROUGHNESS'
                        else:
                            row['classification']='COLLECTED_LEGACY_SAME_PAIR_LOCAL_REGION_CLASSIFIER_FLAG'
                            report['classifier_flags'].append(row)
                if row['classification']=='UNRESOLVED' and name in baseline and other in baseline:
                    # Original animation may foul a pair only in another old
                    # phase. Cold0 and matching-phase clearance do not make an
                    # already-fouled source pair a genuinely unrelated host.
                    old_cycle=canonical_cycle_contacts(name,other,frame)
                    ca,cb=patch_ids(a,b)if state['triangle_intersections']else near_patch_ids(a,b)
                    row['canonical_old_fullcycle_same_pair_contacts']=[{'frame':r['frame'],**r['state'],
                        'source_face_vertex_overlap':[len(ca&r['member_ids']),len(cb&r['host_ids'])]}for r in old_cycle]
                    matches=[r for r in old_cycle if ca&r['member_ids']and cb&r['host_ids']]
                    if matches:
                        selected=max(matches,key=lambda r:len(ca&r['member_ids'])+len(cb&r['host_ids']))
                        ia=sorted(ca|selected['member_ids']);ib=sorted(cb|selected['host_ids'])
                        oldM=selected['host_matrix'];newM=pose.matrix(other)
                        if a.points.shape==selected['member_points'].shape and b.points.shape==selected['host_points'].shape:
                            row['old_cycle_patch_host_local_drift']=max(float(np.linalg.norm(relative_points(a.points[ia],newM)-relative_points(selected['member_points'][ia],oldM),axis=1).max()),float(np.linalg.norm(relative_points(b.points[ib],newM)-relative_points(selected['host_points'][ib],oldM),axis=1).max()))
                        row['canonical_old_reference_frame']=selected['frame']
                        row['classification']='ANIMATED_INHERITED_ACTUAL_OLD_CYCLE_SAME_PART_LOCAL_REGION_ROUGHNESS'
                    elif old_cycle:
                        row['classification']='COLLECTED_LEGACY_OLD_CYCLE_LOCAL_REGION_CLASSIFIER_FLAG';report['classifier_flags'].append(row)
                if row['classification']=='UNRESOLVED':
                    row['classification']='NEW_NONMATE_OR_CHANGED_LOCAL_REGION';report['failures'].append(row)
                    print('FIRST_NEW_NONMATE',json.dumps(row,default=helper.json_default)[:3500],flush=True)
                else:counts[row['classification']]+=1
                report['rows'].append(row)
        report['per_frame'].append({'frame':frame,'counts':dict(counts),'replacement_envelopes':envelopes});report['progress_frame']=frame
        pose.close();save();print('MAPPED32_SOURCE_POSE',frame,'exact',counts['exact_pairs'],'failures',len(report['failures']),flush=True)
        if report['failures']:report['status']='FAIL_FIRST_MAPPED32_SOURCE_POSE';save();break
    else:
        report['status']='COMPLETE_MAPPED32_SOURCE66_WITH_LEGACY_CLASSIFIER_FLAGS_FOR_REVIEW'if report['classifier_flags']else'PASS_MAPPED32_SOURCE66_NO_NEW_NONMATE_OUTSIDE_DECLARED_LEGACY_CORRIDORS'
        save()
    report['input_pins_rechecked_after_run']={'source':sha(args.source)==args.source_sha256,'glb':sha(args.glb)==args.glb_sha256,
        'source_proof':sha(source_dir/'validation.json')==report['source_proof_sha256'],
        'role_contract':sha(args.mechanical_role_contract)==report['mechanical_role_contract_sha256'],
        'canonical_provenance':sha(provenance_path)==report['canonical_union_provenance_sha256']}
    if not all(report['input_pins_rechecked_after_run'].values()):report['status']='FAIL_TARGETED_INPUT_PIN_CHANGED'
    save()
    cold.close();print(report['status'],args.out/'clearance.json',flush=True)
    if report['failures']or report['status'].startswith('FAIL_'):raise SystemExit(1)


def main():
    global POSES
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source',type=Path,required=True);p.add_argument('--glb',type=Path,required=True)
    p.add_argument('--source-sha256',required=True);p.add_argument('--glb-sha256',required=True)
    p.add_argument('--changes',type=Path,action='append',required=True)
    p.add_argument('--out',type=Path,required=True)
    p.add_argument('--baseline',type=Path,default=BASE_SOURCE);p.add_argument('--baseline-glb',type=Path,default=BASE_GLB)
    p.add_argument('--actuator-manifest',type=Path,required=True)
    p.add_argument('--core-name',default='V04 independently suspended engine core')
    p.add_argument('--diagnostic-poses',help='Explicit diagnostic subset, e.g.0,1; never a full pass')
    p.add_argument('--motion-only',action='store_true',help='Defer clearance; report never claims clearance pass')
    p.add_argument('--resume-source-cache',type=Path,help='Completed source proof directory; skip SOURCE reevaluation, test new GLB')
    p.add_argument('--targeted32-source-cache',type=Path,help='Completed SOURCE66 cache for the final finite 32-part interference screen')
    p.add_argument('--mechanical-role-contract',type=Path)
    p.add_argument('--resume-targeted-prefix',type=Path,help='Preserved previous targeted report; reuse only its contiguous zero-failure pose prefix with identical input/role pins')
    p.add_argument('--review-terminal-flags',type=Path,help='Read a completed targeted report and independently resolve feed6 flags against actual source-defined last-span geometry and imported GLB')
    args=p.parse_args(sys.argv[sys.argv.index('--')+1:]);args.out=args.out.resolve();args.out.mkdir(parents=True,exist_ok=False)
    # Preserve the exact executed checker beside its report, including failed
    # studies; later repairs must not make an earlier hash irreproducible.
    (args.out/'checker-snapshot.py').write_bytes(Path(__file__).read_bytes())
    if args.diagnostic_poses:
        POSES=sorted(set(int(f) for f in args.diagnostic_poses.split(',')));assert POSES and POSES[0]==0 and set(POSES)<=set(range(66))
    args.source=args.source.resolve();args.glb=args.glb.resolve();args.baseline=args.baseline.resolve();args.baseline_glb=args.baseline_glb.resolve()
    assert sha(args.baseline)==BASE_PIN and sha(args.baseline_glb)==BASE_GLB_PIN,'Canonical V05 pin mismatch'
    assert sha(args.source)==args.source_sha256 and sha(args.glb)==args.glb_sha256,'Candidate input pin mismatch'
    declarations,manifest_records=merge_declarations([x.resolve() for x in args.changes])
    actuator_metadata=read(args.actuator_manifest);actuator_pin=sha(args.actuator_manifest)
    if args.review_terminal_flags:
        assert args.targeted32_source_cache
        cases=[review_authored_feed6_terminal(args,index)for index in (6,0)]
        containment=review_inherited_finite_containment(args)
        screen=read(args.review_terminal_flags/'clearance.json')
        expected={(r['frame'],frozenset((r['a'],r['b'])))for r in screen['classifier_flags']}
        resolved={(r['frame'],frozenset((r['pipe'],r['clevis'])))for case in cases for r in case['rows']}
        resolved|={(r['frame'],frozenset((r['a'],r['b'])))for r in containment['rows']}
        assert expected==resolved,('Unreviewed collected source region flags',expected-resolved)
        dump(args.out/'terminal-review.json',{'status':'PASS_ALL_COLLECTED_LEGACY_REGION_FLAGS_SOURCE_AND_ACTUAL_GLB',
            'source_sha256':args.source_sha256,'glb_sha256':args.glb_sha256,
            'input_screen_sha256':sha(args.review_terminal_flags/'clearance.json'),
            'cases':cases,'rows':[row for case in cases for row in case['rows']],
            'inherited_finite_containment':containment})
        return
    if args.targeted32_source_cache:
        assert args.mechanical_role_contract and POSES==list(range(66))
        return targeted32_source_clearance(args,actuator_metadata)
    if args.resume_source_cache:
        assert args.motion_only and POSES==list(range(66))
        return resume_actual_export(args,declarations,manifest_records,actuator_metadata,actuator_pin)
    failures=[]
    def check(ok,gate,context):
        if not ok:
            failures.append({'gate':gate,'context':context})
            if len(failures)<=20:print('FIRST_FAILURE',gate,json.dumps(context,default=helper.json_default)[:3000],flush=True)
    report={'status':'RUNNING','scope':'All66 physical source/export poses, exact undeclared V05 local data/PBR/keyframes and named fixed interfaces. Targeted changed/new swept checks only; no native clients, captures, old full route/route audit or appearance acceptance.',
            'geometry_units':'Blender units (BU); no real-world length conversion is assumed',
            'baseline_source_sha256':BASE_PIN,'baseline_glb_sha256':BASE_GLB_PIN,
            'source_sha256':args.source_sha256,'glb_sha256':args.glb_sha256,
            'checker_sha256':sha(__file__),'helper_sha256':sha(HELPER),'declarations':manifest_records,
            'actuator_manifest':{'path':str(args.actuator_manifest),'sha256':actuator_pin},
            'frames':POSES,'failures':failures}
    def checkpoint():dump(args.out/'validation.json',report)
    checkpoint()
    try:
        bpy.ops.wm.open_mainfile(filepath=str(args.baseline));base_snapshot=helper.original_snapshot();base_obs=objects()
        exclusions=set(declarations['source_only_names'])
        base_names={n for n,o in base_obs.items() if o.type=='MESH' and n not in exclusions}
        # Motion-only runs need every original matrix, but do not repeat all
        # old evaluated mesh geometry merely to check fixed interfaces.
        baseline_cache=PoseCache(args.out/'baseline-physical-cache',set() if args.motion_only else base_names)
        helper.SHAPE_CONTEXT='V05_MOTION_BASELINE'
        for frame in POSES:
            bpy.context.scene.frame_set(frame);bpy.context.view_layer.update();baseline_cache.write(frame,objects(),check)
        bpy.ops.wm.open_mainfile(filepath=str(args.source));source_snapshot=helper.original_snapshot();obs=objects()
        report['source_preservation']=source_preservation(base_snapshot,source_snapshot,declarations,check)
        check(exclusions=={n for n,o in obs.items() if o.type=='MESH' and o.get('render_only_volume')},
              'EXACT_SOURCE_ONLY_VOLUME_DECLARATION',{'declared':sorted(exclusions),'tagged':[n for n,o in obs.items() if o.type=='MESH' and o.get('render_only_volume')]})
        physical={n for n,o in obs.items() if o.type=='MESH' and n not in exclusions}
        source_cache=PoseCache(args.out/'source-physical-cache',physical)
        changed=set(declarations['allowed_source_changes'])|set(declarations['new_names'])
        roots=set(declarations['clearance']['participant_roots'])
        roots|={n for n in changed if n in obs and obs[n].type=='EMPTY'}
        participants=(changed|set(declarations['clearance']['participants']))&physical
        participants|={n for n in physical if any(r in parent_chain(n,source_snapshot) for r in roots)}
        report['clearance_participants']=sorted(participants);report['clearance_changed_roots']=sorted(roots)
        fixed=set(declarations['fixed_names'])
        check(bool(fixed),'EXPLICIT_FIXED_INTERFACE_NAMES_REQUIRED',None)
        check(fixed<=set(obs),'FIXED_INTERFACE_NAME_MISSING',sorted(fixed-set(obs)))
        fixed_rows=[];clearance_rows=[];clearance_counts=collections.Counter();preserved_root_rows=[];actuator_rows=[]
        bpy.context.scene.frame_set(0);bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
        report['new_source_mesh_guards']=[helper.new_mesh_check(obs[n],dg,{}) for n in declarations['new_names'] if n in physical]
        for row in report['new_source_mesh_guards']:
            check(row['finite'] and row['degenerate_triangles']==0 and row['nonmanifold_geometric_edges']==0 and not row['missing_uv'] and row['collapsed_uv_triangles']==0,'NEW_SOURCE_GEOMETRY_UV_PBR',row)
        if failures:
            report['status']='FAIL_INITIAL_SOURCE_PRESERVATION_OR_NEW_GEOMETRY';checkpoint();raise SystemExit(1)
        helper.SHAPE_CONTEXT='V06_SOURCE_MOTION'
        for frame in POSES:
            bpy.context.scene.frame_set(frame);bpy.context.view_layer.update();obs=objects();source_cache.write(frame,obs,check)
            old,cur=baseline_cache.read(frame),source_cache.read(frame)
            for name in sorted(fixed):
                if name not in old.matrix_index or name not in cur.matrix_index:continue
                error=float(np.max(np.abs(old.matrix(name)-cur.matrix(name))))
                row={'phase':'SOURCE','frame':frame,'name':name,'matrix_max_error':error};fixed_rows.append(row)
                check(error<1e-7,'FIXED_V05_INTERFACE_WORLD_MATRIX',row)
            old.close();cur.close()
            actor,typed_pairs=actuator_pose('SOURCE',frame,source_cache,actuator_metadata,args.core_name,check);actuator_rows+=actor
            rows,counts,proofs=([],{},[]) if args.motion_only else clearance_pose(frame,'SOURCE',obs,physical,participants,baseline_cache,source_cache,
                                             roots,declarations['clearance'],source_snapshot,check)
            clearance_rows+=rows;clearance_counts.update(counts)
            preserved_root_rows.append({'frame':frame,'root_relative_geometry_proofs':proofs})
            print('SOURCE_POSE_CACHED',frame,'clearance_candidates',len(rows),'failures',len(failures),flush=True)
            report['actuator_rows']=actuator_rows;report['progress']={'phase':'SOURCE','frame':frame};checkpoint()
            if failures:
                report['status']='FAIL_FIRST_SOURCE_POSE';checkpoint();raise SystemExit(1)
        if not args.motion_only:baseline_classification(clearance_rows,source_cache,baseline_cache,args.baseline,check)
        report['source_clearance_rows']=clearance_rows;report['source_clearance_counts']=dict(clearance_counts)
        report['preserved_root_relative_geometry']=preserved_root_rows;report['fixed_interface_rows']=fixed_rows
        checkpoint()
        raw=helper.glb_json(args.glb);raw_mesh_names={n.get('name') for n in raw.get('nodes',[]) if 'mesh' in n}
        check(not exclusions&raw_mesh_names,'SOURCE_ONLY_VOLUME_EXPORTED_AS_PHYSICAL_MESH',sorted(exclusions&raw_mesh_names))
        check(bool(raw.get('animations')),'PHYSICAL_GLB_HAS_NO_ANIMATION',None)
        check(all('bufferView' in im and 'uri' not in im for im in raw.get('images',[])),'ACTUAL_GLB_IMAGES_NOT_EMBEDDED',None)
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.context.scene.render.fps=source_snapshot['fps'];bpy.context.scene.render.fps_base=source_snapshot['fps_base']
        bpy.ops.import_scene.gltf(filepath=str(args.glb));export_obs=objects()
        export_names={n for n,o in export_obs.items() if o.type=='MESH'}
        export_cache=PoseCache(args.out/'actual-glb-physical-cache',export_names)
        helper.SHAPE_CONTEXT='V06_ACTUAL_GLB_MOTION'
        for frame in POSES:
            bpy.context.scene.frame_set(frame);bpy.context.view_layer.update();export_cache.write(frame,objects(),check)
            actor,typed_pairs=actuator_pose('ACTUAL_GLB',frame,export_cache,actuator_metadata,args.core_name,check);actuator_rows+=actor
            report['actuator_rows']=actuator_rows;report['progress']={'phase':'ACTUAL_GLB','frame':frame};checkpoint()
            if failures:
                report['status']='FAIL_FIRST_ACTUAL_GLB_POSE';checkpoint();raise SystemExit(1)
        maxima,loop_rows,cold=loops_and_correspondence(source_cache,export_cache,declarations['loop_groups'],check)
        report['source_glb_world_vertex_errors']=maxima;report['maximum_world_vertex_error']=max(r['maximum_world_vertex_error'] for r in maxima)
        report['physical_loops']=loop_rows;report['cold0_working1_distinction']=cold
        # Recheck all source-detected contact cases on the actual interchange.
        exported_contact_rows=[]
        by_frame=collections.defaultdict(list)
        for row in clearance_rows:by_frame[row['frame']].append(row)
        rules={frozenset((r['object'],r['host'])):r for r in declarations['clearance'].get('bounded_contacts',[])}
        for frame,jobs in by_frame.items():
            bpy.context.scene.frame_set(frame);bpy.context.view_layer.update();obs=objects();dg=bpy.context.evaluated_depsgraph_get();shapes={}
            for original in jobs:
                a,b=original['a'],original['b']
                if a not in obs or b not in obs:continue
                for n in (a,b):
                    if n not in shapes:shapes[n]=helper.Shape(obs[n],dg)
                row=dict(state_of_pair(shapes[a],shapes[b]),a=a,b=b,frame=frame,
                         source_classification=original['classification'])
                rule=rules.get(frozenset((a,b)))
                if rule:
                    row['bounded_contact']=bounded_contact(rule,obs,shapes);check(row['bounded_contact']['pass'],'ACTUAL_GLB_BOUNDED_CONTACT',row)
                exported_contact_rows.append(row)
        report['actual_glb_source_contact_rechecks']=exported_contact_rows
        report['clearance_limit']='Exact triangle crossing and closed-solid containment; bidirectional vertex-to-triangle distance supplements those tests. It is not a universal edge/edge closest-distance engineering proof. Inherited contact is accepted only with proved unchanged shared rigid geometry or an explicit measured bounded-contact region.'
        report['status']='PASS_V06_DECLARED_MOTION_SOURCE_AND_ACTUAL_GLB' if not failures else 'FAIL_V06_DECLARED_MOTION_SOURCE_AND_ACTUAL_GLB'
        if not failures and args.motion_only:report['status']='PASS_MOTION_EXPORT_CLEARANCE_DEFERRED'
        if not failures and args.diagnostic_poses:report['status']='PASS_DIAGNOSTIC_POSES_FULL66_NOT_RUN'
    except Exception as error:
        report['status']='ERROR_INCOMPLETE_V06_VALIDATION';report['exception']={'type':type(error).__name__,'message':str(error)}
        raise
    finally:
        final_pins={'baseline_source':sha(args.baseline)==BASE_PIN,'baseline_glb':sha(args.baseline_glb)==BASE_GLB_PIN,
                    'source':sha(args.source)==args.source_sha256,'glb':sha(args.glb)==args.glb_sha256,
                    'declarations':all(sha(row['path'])==row['sha256'] for row in manifest_records)}
        final_pins['actuator_manifest']=sha(args.actuator_manifest)==actuator_pin
        report['inputs_unchanged_during_run']=final_pins
        if not all(final_pins.values()):report['status']='FAIL_INPUTS_CHANGED_DURING_VALIDATION'
        checkpoint()
    print(report['status'],'failures',len(failures),'report',args.out/'validation.json',flush=True)
    if not report['status'].startswith('PASS_'):raise SystemExit(1)


if __name__=='__main__':main()
