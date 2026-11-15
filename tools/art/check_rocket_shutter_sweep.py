"""Check evaluated shutter meshes against the actual launcher throughout reload.

Blender --background --python THIS -- MODEL.blend
World-space evaluated triangles include bevels. Only the intended hinge pin
contact is exempt. Half-frame samples catch transient crossing, not just poses.
"""
import bpy,sys,json,hashlib
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
p=Path(sys.argv[sys.argv.index('--')+1]);bpy.ops.wm.open_mainfile(filepath=str(p))
s=bpy.context.scene;s.frame_set(1);deps=bpy.context.evaluated_depsgraph_get()
doors=[o for o in s.objects if o.name.startswith('HINGED_RELOAD_SHUTTER_')]
def under(o,parent):
    while o.parent:
        if o.parent==parent:return True
        o=o.parent
    return False
moving=[o for o in s.objects if o.type=='MESH' and any(under(o,d) for d in doors)]
obstacles=[o for o in s.objects if o.type in ('MESH','CURVE') and o not in moving
           and not o.name.startswith('Breech shutter hinge')]
geometry={};cache={}
for o in moving+obstacles:
    evaluated=o.evaluated_get(deps);mesh=evaluated.to_mesh();mesh.calc_loop_triangles()
    geometry[o.name]=([v.co.copy() for v in mesh.vertices],[tuple(t.vertices) for t in mesh.loop_triangles])
    evaluated.to_mesh_clear()
def world(o):
    mw=o.matrix_world
    if abs(mw.determinant())<1e-10:return None
    key=tuple(v for row in mw for v in row)
    if o.name in cache and cache[o.name][0]==key:return cache[o.name][1]
    local,faces=geometry[o.name];points=[mw@v for v in local]
    bounds=tuple((min(v[i] for v in points),max(v[i] for v in points)) for i in range(3))
    result=(bounds,BVHTree.FromPolygons(points,faces,all_triangles=True))
    cache[o.name]=(key,result);return result
collisions=[];sample_count=0;tested_pairs=0
for half in range(2,483):
    frame=half/2;s.frame_set(int(frame),subframe=frame%1);sample_count+=1
    fixed=[(o,world(o)) for o in obstacles]
    for a in moving:
        av=world(a)
        if not av:continue
        for b,bv in fixed:
            if not bv:continue
            if any(av[0][i][1]<bv[0][i][0] or bv[0][i][1]<av[0][i][0] for i in range(3)):continue
            tested_pairs+=1
            hits=av[1].overlap(bv[1])
            if hits:collisions.append({'frame':frame,'shutter_part':a.name,'structure':b.name,'triangle_pairs':len(hits)})
    if half%80==0:print('SHUTTER_SWEEP',frame,'collisions',len(collisions),flush=True)
report={'status':'FAIL' if collisions else 'PASS_SAMPLED_MESH_SWEEP','native_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),
        'samples':sample_count,'step_frames':.5,'moving_meshes':len(moving),'obstacle_meshes':len(obstacles),
        'narrow_phase_pairs':tested_pairs,'collision_count':len(collisions),'collisions':collisions,
        'exempt_contact':'Only the two intended transverse hinge pins',
        'scope':'Evaluated triangle intersections at every half-frame; not a continuous collision solver or a native game test'}
(p.parent/'shutter-sweep-check.json').write_text(json.dumps(report,indent=2)+'\n')
print('SHUTTER_SWEEP_RESULT',report['status'],len(collisions),flush=True)
