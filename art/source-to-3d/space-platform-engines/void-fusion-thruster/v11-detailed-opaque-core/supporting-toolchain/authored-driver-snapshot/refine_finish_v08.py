"""Focused third inspection repair: orphan audit, chipped mineral and UV bakes."""
import bpy,bmesh,math,json,pathlib,sys,hashlib,shutil,itertools
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
ROOT=pathlib.Path(__file__).resolve().parents[3];OLD=ROOT/'build/thruster-resume-20261117/void-fusion-v07'
OUT=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve();OUT.mkdir(parents=True,exist_ok=True)
assert not (OUT/'void-fusion-v08.blend').exists()
bpy.ops.wm.open_mainfile(filepath=str(OLD/'void-fusion-v07.blend'));S=bpy.context.scene;S.render.threads_mode='FIXED';S.render.threads=2
c=json.loads((OLD/'source-contract.json').read_text());sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
removed=[o.name for o in S.objects if o.name.startswith('Hoop ') and 'radial keeper' in o.name]
assert len(removed)==42,removed
for name in removed:bpy.data.objects.remove(bpy.data.objects[name],do_unlink=True)
surface=c['surface_contacts'];contacts=c['contacts'];M={k:bpy.data.materials[n] for k,n in [('pad','V06 dark compressed ceramic contact pads'),('hull','Spine blackened cast iron'),('rail','Satin iron load rails')]}
def mesh(name,vv,ff,mat):
    me=bpy.data.meshes.new(name);me.from_pydata(vv,[],ff);me.update();o=bpy.data.objects.new(name,me);S.collection.objects.link(o);me.materials.append(M[mat]);bm=bmesh.new();bm.from_mesh(me);bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free();uv=me.uv_layers.new(name='PhysicalRegionUV')
    for p in me.polygons:
        a,b,cc=[me.vertices[i].co for i in p.vertices];u=max((b-a,cc-a,cc-b),key=lambda q:q.length).normalized();v=(b-a).cross(cc-a).normalized().cross(u)
        for li in p.loop_indices:q=me.vertices[me.loops[li].vertex_index].co;uv.data[li].uv=(q.dot(u)*2,q.dot(v)*2)
    return o
def replace(old,new):name=old.name;bpy.data.objects.remove(old,do_unlink=True);new.name=name;return new
def tree(o):
    bpy.context.view_layer.update();m=o.data;m.calc_loop_triangles();return BVHTree.FromPolygons([o.matrix_world@v.co for v in m.vertices],[list(t.vertices) for t in m.loop_triangles],all_triangles=True)
def seat(a,b,p,n,why):surface.append({'a':a.name,'b':b.name,'point':list(p),'normal':list(n),'tolerance':2e-5,'reason':why})

# Weld each intentional stone fragment's coincident construction vertices, then
# pull fragments outward from their common fault intersection. This preserves
# true recessed cleavage faces while producing uneven negative gaps and steps.
MINERAL=[];rocks=[]
for index,record in enumerate(c['rock_bays']):
    o=bpy.data.objects[record['object']];rocks.append(o);bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=7e-7);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    groups=[];todo=set(bm.verts)
    while todo:
        seed=todo.pop();group={seed};queue=[seed]
        while queue:
            v=queue.pop()
            for e in v.link_edges:
                q=e.other_vert(v)
                if q in todo:todo.remove(q);group.add(q);queue.append(q)
        groups.append(group)
    ns=[Vector((.91,.18,-.42)).normalized(),Vector((.16,.94,.47)).normalized(),Vector((-.22,.33,.94)).normalized()]
    ds=[.013,-.031,.021];rot=Matrix.Rotation(.31*math.sin(index*1.7+1),3,'Y')@Matrix.Rotation(.22*math.cos(index*1.2+.5),3,'Z')
    ns=[(rot@n).normalized() for n in ns];ds=[d+.022*math.sin(index*1.9+j) for j,d in enumerate(ds)]
    center=Vector((0,record['center_y'],.55));intersection=Matrix(ns).inverted()@Vector(ds)+center;transforms=[]
    for group in groups:
        centroid=sum((v.co for v in group),Vector())/len(group);delta=(centroid-intersection)*.09
        if delta.length>.024:delta*=.024/delta.length
        for v in group:v.co+=delta
        transforms.append(list(delta))
    # Modest actual flake facets on selected outer sharp edges. No bevel is
    # applied to emissive recesses; the new facet receives crushed-edge maps.
    chipped=0
    for width,modulo in ((.0022,3),(.0035,5)):
        edges=[e for j,e in enumerate(list(bm.edges)) if e.is_valid and len(e.link_faces)==2 and all(f.material_index==0 and f.calc_area()>.00025 for f in e.link_faces) and all(min(q.calc_length() for q in v.link_edges)>.018 for v in e.verts) and e.calc_length()>.035 and e.calc_face_angle(0)>.60 and j%modulo==0]
        if edges:
            result=bmesh.ops.bevel(bm,geom=edges,offset=width,segments=1,affect='EDGES',clamp_overlap=True)
            for f in result.get('faces',[]):f.material_index=1
            chipped+=len(result.get('faces',[]))
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6);bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-6);bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-6);bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free();o.data.update()
    MINERAL.append({'object':o.name,'welded_closed_fragment_count':len(groups),'fragment_translations':transforms,'actual_added_flake_facets':chipped,'purpose':'Uneven negative gaps, interrupted outer planes and actual chipped edges; recessed inner energized faces retained. No floating luminous rods.'})

# Refit every affected compression pad and jaw to current chipped fragments.
surface[:]=[q for q in surface if not ('fitted ceramic contact' in q['a'] or 'fitted ceramic contact' in q['b'])]
def fitted(name,inner,outer,role):
    vv=[tuple(p) for p in inner+outer];ff=[]
    for a in (0,1,3,4):ff.extend([(a,a+1,a+4,a+3),(9+a,12+a,13+a,10+a)])
    edge=[0,1,2,5,8,7,6,3]
    for a,b in zip(edge,edge[1:]+edge[:1]):ff.append((a,b,b+9,a+9))
    return mesh(name,vv,ff,role)
for i,rock in enumerate(rocks):
    yc=c['rock_bays'][i]['center_y'];tr=tree(rock)
    for side in (-1,1):
        coords=[]
        for z in (.485,.55,.615):
            for y in (yc-.055,yc,yc+.055):
                hit=None
                for delta in (0,.004,-.004,.009,-.009):
                    hit=tr.ray_cast(Vector((side*.5,y+delta,z)),Vector((-side,0,0)),1)[0]
                    if hit is not None:break
                assert hit is not None,(i,side,y,z);coords.append(hit)
        outer=[p+Vector((side*.014,0,0)) for p in coords]
        pad=replace(bpy.data.objects['V06 rock%02d fitted ceramic contact %s'%(i,side)],fitted('new pad',coords,outer,'pad'))
        back=[Vector((side*.318,p.y,p.z)) for p in coords]
        jaw=replace(bpy.data.objects['V06 rock%02d shaped compression jaw %s'%(i,side)],fitted('new jaw',outer,back,'hull'))
        for j in (0,2,4,6,8):seat(pad,rock,coords[j],(side,0,0),'Current chipped/translated mineral and refitted actual ceramic shoe')
        for j in (2,4,6):seat(jaw,pad,outer[j],(side,0,0),'Current refitted ceramic outer surface and receiving cast jaw')

# All 24 old coarse-only coil boxes become actual concave receiving cradles.
COILS=[]
for collar in [o for o in S.objects if o.name.startswith('Coil collar ')]:
    suffix=collar.name[len('Coil collar '):];old=bpy.data.objects['Coil support '+suffix];side=-1 if suffix.startswith('-1 ') else 1;y=collar.location.y;tr=tree(collar);xs=[side*(.275+j*.09/8) for j in range(9)];top=[]
    for x in xs:
        hit=tr.ray_cast(Vector((x,y,.10)),Vector((0,0,1)),.6)[0];assert hit is not None;top.append(hit.z)
    vv=[]
    for yy in (y-.030,y+.030):
        for above in (False,True):vv.extend([(x,yy,top[j] if above else .18) for j,x in enumerate(xs)])
    N=len(xs);ff=[]
    for j in range(N-1):ff.extend([(j,j+1,N+j+1,N+j),(2*N+j,3*N+j,3*N+j+1,2*N+j+1),(j,2*N+j,2*N+j+1,j+1),(N+j,N+j+1,3*N+j+1,3*N+j)])
    ff.extend([(0,N,3*N,2*N),(N-1,3*N-1,4*N-1,2*N-1)])
    cradle=replace(old,mesh('new concave coil cradle',vv,ff,'hull'))
    for j in (0,2,4,6,8):seat(cradle,collar,(xs[j],y,top[j]),(0,0,1),'Actual concave cradle crown ray-fitted to current coil collar lower triangles; old .059 box penetration removed')
    seat(cradle,bpy.data.objects['Continuous structural keel '+str(side)],(side*.30,y,.18),(0,0,1),'Actual cradle lower plane seats on cantilever channel crown')
    COILS.append({'collar':collar.name,'receiver':cradle.name,'fit':'Ray-fitted actual polygonal lower circumference, five tight samples plus channel-root seat'})

# Actual receiver inventory: zero unassigned fasteners remain. Names such as
# gripping-finger are not incorrectly matched merely because they contain pin.
fasteners=[o.name for o in S.objects if o.name.startswith('Coil collar ') or 'captive sole bolt' in o.name or 'rim plate captive bolt' in o.name or 'jaw captive clamp bolt' in o.name or 'actual seated ceramic receiver' in o.name]
AUDIT=[]
for name in fasteners:
    records=[q for q in surface if name in (q['a'],q['b'])];assert records,('unassigned fastener',name)
    AUDIT.append({'object':name,'actual_receivers':sorted(set(q['b'] if q['a']==name else q['a'] for q in records)),'tight_surface_records':len(records)})
assert len(AUDIT)==92,len(AUDIT)

sys.path.insert(0,str(pathlib.Path(__file__).parent));from bake_surface_atlas import bake
BAKES=[]
for i,rock in enumerate(rocks):BAKES.append(bake([rock],OUT/'textures','noctilith-bay-%02d'%i,512,surface,True))
frame=[o for o in S.objects if o.type=='MESH' and (o.name.startswith(('Continuous structural keel','V04 cage longitudinal crown','V06 rock')) and any(s in o.name for s in ('keel','crown','compression jaw','cast jaw-to-keel web')) or o.name.startswith(('Coil support','V05 grounded dish stack','V07 fore channel')))]
head=[o for o in S.objects if o.type=='MESH' and (o.name.startswith('V05 tier') and 'segmented rim armor' in o.name or o.name.startswith('V07 tier') and 'flared cast radial web' in o.name or o.name.startswith(('V07 retained electrode curved','V07 carrier cast gripping')))]
BAKES.append(bake(frame,OUT/'textures','cantilever-frame-authored',768,surface));BAKES.append(bake(head,OUT/'textures','dish-carrier-authored',768,surface))
S['candidate_stage']='V08_ORPHAN_REPAIR_CHIPPED_MINERAL_ACTUAL_UV_BAKES_CONCAVE_COIL_RECEIVERS'
for im in bpy.data.images:
    if im.source=='FILE' and not im.packed_file:im.pack()
bpy.ops.object.select_all(action='DESELECT')
for o in S.objects:
    if o.type in ('MESH','EMPTY'):o.select_set(True)
blend=OUT/'void-fusion-v08.blend';glb=OUT/'void-fusion-v08.glb'
bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=True)
bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_extras=True)
c.update({'revision':'V08 focused actual orphan repair, chipped mineral and model-specific UV surface bake','blend_sha256':sha(blend),'glb_sha256':sha(glb),'previous_blend_sha256':sha(OLD/'void-fusion-v07.blend'),'previous_glb_sha256':sha(OLD/'void-fusion-v07.glb'),'contacts':contacts,'surface_contacts':surface,'finish_repair':{'actual_defect':'Floating Hoop02radialkeeper135 and41siblings survived removal of their V01 receiving vessel hoops; the earlier named seat list did not cover them.','removed_orphan_objects':removed,'remaining_named_fastener_receiver_count':92,'actual_receiver_inventory':AUDIT,'coil_receivers':COILS,'mineral_changes':MINERAL,'uv_bakes':BAKES,'honesty':'Passed earlier sampled seats did not establish absence of unlisted orphan objects. This pass explicitly inventories all remaining named fasteners and replaces coarse coil supports with fitted receivers.'}})
(OUT/'source-contract.json').write_text(json.dumps(c,indent=2)+'\n')
for name in ('stacked-dish-reference.json','reference-feature-mapping.json','supplied-skull-reuse.json','ATTRIBUTION.txt'):shutil.copy2(OLD/name,OUT/name)
shutil.copy2(OLD/'orphan-diagnosis.json',OUT/'orphan-diagnosis.json')
print('V08_UV_BAKED_FINISH_SAVED',len(surface),len(AUDIT),blend)
