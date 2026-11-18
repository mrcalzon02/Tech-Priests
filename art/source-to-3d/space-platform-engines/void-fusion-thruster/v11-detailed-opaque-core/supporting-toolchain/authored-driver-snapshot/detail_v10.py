"""Narrow functional bulk/detail derivative. Accepted897 primary parts remain
unchanged; no runtime or ship-well source edits. Pilot first, then detail."""
import bpy,bmesh,pathlib,sys,json,math,hashlib,shutil
from mathutils import Vector
from mathutils.bvhtree import BVHTree
HERE=pathlib.Path(__file__).resolve().parent;ROOT=HERE.parents[2];OLD=ROOT/'build/thruster-resume-20261117/void-fusion-v09-complete';OUT=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve();OUT.mkdir(exist_ok=True,parents=True);pilot='--pilot' in sys.argv;sys.path.insert(0,str(HERE))
from pipette_power_terminal import _uv_and_normals
sys.path.insert(0,str(ROOT/'tools/art/thruster_resumption/animation'));from electric_arcs import geometry_digest
sha=lambda p:hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest();assert sha(OLD/'void-fusion-v09.glb')=='dead4344d5857aa28cb9885763ddec257ac0aed02d86a1114b8f146478d3b08e'
bpy.ops.wm.open_mainfile(filepath=str(OLD/'void-fusion-v09.blend'));S=bpy.context.scene;S.render.threads_mode='FIXED';S.render.threads=2;c=json.loads((OLD/'source-contract.json').read_text(encoding='utf-8-sig'));primary=[o for o in S.objects if o.type=='MESH'];primary_names=[o.name for o in primary];all_original_guard=geometry_digest(primary);surface=c['surface_contacts'];new=[]
REPAIRS=[]
for obj in primary:
    if not obj.name.startswith(('V09_mount low diagonal gusset ','V09_mount fore low crossmember brace ')):continue
    points=[v.co.copy()for v in obj.data.vertices];assert len(points)==8;before=geometry_digest([obj]);materials=list(obj.data.materials);me=bpy.data.meshes.new(obj.name+' repaired convex section')
    hull=[0,1,3,2];faces=[tuple(reversed(hull)),tuple(i+4 for i in hull)]+[(a,b,b+4,a+4)for a,b in zip(hull,hull[1:]+hull[:1])];me.from_pydata(points,[],faces);me.update();obj.data=me
    for m in materials:me.materials.append(m)
    _uv_and_normals(obj);bm=bmesh.new();bm.from_mesh(me);assert all(len(e.link_faces)==2 for e in bm.edges);assert abs(bm.calc_volume(signed=True))>1e-6;volume=bm.calc_volume(signed=True);bm.free()
    REPAIRS.append({'object':obj.name,'before_geometry_digest':before,'after_geometry_digest':geometry_digest([obj]),'unchanged_vertex_positions':[list(p)for p in points],'repair':'Same8vertices and envelope; bow-tie cap/side face cycle replaced by convex0,1,3,2 section. Actual bottom-Z and outer-cheek-X/fore-Y mounting seats preserved.','closed_manifold_edges':True,'actual_signed_volume':volume})
assert len(REPAIRS)==8
unchanged=[o for o in primary if o.name not in {r['object']for r in REPAIRS}];guard=geometry_digest(unchanged)
def material(name,color,metal,rough):
    m=bpy.data.materials.new(name);m.use_nodes=True;bs=m.node_tree.nodes['Principled BSDF'];bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Metallic'].default_value=metal;bs.inputs['Roughness'].default_value=rough;return m
CAST=material('V10 deep blackened cast receiver covers',(.035,.043,.039),.65,.66);PAN=material('V10 engine core pan machined dark iron',(.047,.052,.048),.70,.60)
def mesh(name,vv,ff,mat):
    m=bpy.data.meshes.new(name);m.from_pydata(vv,[],ff);m.update();o=bpy.data.objects.new(name,m);S.collection.objects.link(o);m.materials.append(mat);_uv_and_normals(o);new.append(o.name);return o
def box(name,lo,hi,mat=PAN):return mesh(name,[(x,y,z)for z in (lo[2],hi[2])for y in (lo[1],hi[1])for x in (lo[0],hi[0])],[(0,2,3,1),(4,5,7,6),(0,1,5,4),(1,3,7,5),(3,2,6,7),(2,0,4,6)],mat)
def section(name,outline,ya,yb,mat=CAST):
    n=len(outline);return mesh(name,[(x,y,z)for y in (ya,yb)for x,z in outline],[tuple(reversed(range(n))),tuple(range(n,n*2))]+[(i,(i+1)%n,(i+1)%n+n,i+n)for i in range(n)],mat)
def seat(a,b,p,n,why):surface.append({'a':a.name,'b':b.name,'point':list(p),'normal':list(n),'tolerance':2e-5,'reason':why})
def vv(o):return [o.matrix_world@v.co for v in o.data.vertices]
def subtract(o,other):
    a,b=bounds(o),bounds(other)
    # Nonintersecting or merely touching solids have no difference volume.
    # Avoid unnecessary coplanar exact-solver operations on distant thin pans.
    if any(a[0][i]>=b[1][i]-1e-7 or b[0][i]>=a[1][i]-1e-7 for i in range(3)):return
    mod=o.modifiers.new('Actual fitted hardware/stone pocket','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=other;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
    assert len(o.data.vertices)>0,('Actual Boolean emptied intended structural part',o.name,other.name)
    bm=bmesh.new();bm.from_mesh(o.data);volume=abs(bm.calc_volume(signed=True));bm.free()
    assert volume>1e-5,('Actual Boolean collapsed structural volume',o.name,other.name,volume,len(o.data.vertices))
def bounds(o):
    p=vv(o);return [Vector([min(v[i]for v in p)for i in range(3)]),Vector([max(v[i]for v in p)for i in range(3)])]
def notch_mount(o):
    # Original low-gusset sections are not safe CSG solids. Actual bounded
    # clearance boxes give explicit notches without modifying accepted parts.
    ob=bounds(o)
    for name in c['hanging_mount']['mount_objects']:
        if not('gusset'in name or 'brace'in name):continue
        a,b=bounds(bpy.data.objects[name]);a-=Vector((.002,.002,.002));b+=Vector((.002,.002,.002))
        if any(a[i]>=ob[1][i]or b[i]<=ob[0][i]for i in range(3)):continue
        cut=box('TEMP actual mount clearance box',a,b);subtract(o,cut);new.remove(cut.name);bpy.data.objects.remove(cut,do_unlink=True)

# A solid retained machinery pan sits on the actual engine channels. It is NOT
# a foundation receiver or aft ship floor. Crossmember intervals already have
# solid body metal; pan pieces terminate on those actual planes without overlap.
rocks=[bpy.data.objects[r['object']]for r in c['rock_bays']];rpoints=[p for o in rocks for p in vv(o)];lo=max(-3.60,min(p.y for p in rpoints)-.025);hi=min(4.14,max(p.y for p in rpoints)+.025)
intervals=[(h['center_y']-.075,h['center_y']+.075,h)for h in c['interstone_housings']];cursor=lo;PANPARTS=[]
for i,(a,b,h)in enumerate(intervals+[(hi,hi,None)]):
    if a>cursor+.001:
        floor=box('V10 retained core pan floor %02d'%i,(-.34,cursor,-.27),(.34,a,-.245));PANPARTS.append(floor.name)
        notch_mount(floor);_uv_and_normals(floor)
        for side in (-1,1):
            candidates=[cursor+(a-cursor)*t for t in (.5,.25,.75,.12,.88)];valid=[]
            for y in candidates:
                point=Vector((side*.30,y,-.27));blocked=False
                for name in c['hanging_mount']['mount_objects']:
                    if 'gusset'in name or 'brace'in name:
                        q,r=bounds(bpy.data.objects[name]);blocked=blocked or(q.x-.002<point.x<r.x+.002 and q.y-.002<point.y<r.y+.002)
                if not blocked:valid.append(y)
            assert valid;seat(floor,bpy.data.objects['Continuous structural keel '+str(side)],(side*.30,valid[0],-.27),(0,0,1),'Internal engine backing pan on actual continuous keel crown; not external foundation')
        if h:
            base=bpy.data.objects[next(n for n in h['objects']if 'chamfered load crossmember'in n)];seat(floor,base,(0,a,-.258),(0,1,0),'Pan aft edge meets real housing crossmember side, solid backing continues through original crossmember')
        if i>0:
            previous=c['interstone_housings'][i-1];base=bpy.data.objects[next(n for n in previous['objects']if 'chamfered load crossmember'in n)];seat(floor,base,(0,cursor,-.258),(0,1,0),'Pan fore edge retained on preceding real crossmember side')
    cursor=max(cursor,b)
# Side returns close diagonal views behind the exposed rock; retain mechanical
# cage openness above. Fitted cutouts keep the fore mount gussets untouched.
for side in (-1,1):
    xa,xb=sorted((side*.265,side*.34));wall=box('V10 core pan raised side return '+str(side),(xa,lo,-.245),(xb,hi,-.075))
    for h in c['interstone_housings']:
        for name in h['objects']:
            if 'chamfered load crossmember'in name or 'tapered cage shoulder'in name:subtract(wall,bpy.data.objects[name])
    notch_mount(wall)
    _uv_and_normals(wall);PANPARTS.append(wall.name)
    # Seats on actual floor pieces away from crossmember/mount cutouts.
    first=bpy.data.objects[PANPARTS[0]];point=(side*.30,(lo+intervals[0][0])/2,-.245);seat(wall,first,point,(0,0,1),'Raised engine pan return lower plane bears on retained pan floor')

CASES=[]
for index in ([3]if pilot else range(6)):
    h=c['interstone_housings'][index];yc=h['center_y'];case=section('V10 substantial split receiver cover %02d'%index,[(-.23,-.22),(-.205,-.245),(.205,-.245),(.23,-.22),(.23,.225),(.205,.25),(-.205,.25),(-.23,.225)],yc-.14,yc+.14)
    # Positive real rock pockets use slightly expanded actual source fragments,
    # preserving exposed mineral/old seats and bounded mechanical clearance.
    cutters=[]
    for ri in h['between_rock_indices']:
        rock=rocks[ri];copy=rock.copy();copy.data=rock.data.copy();S.collection.objects.link(copy);copy.name='TEMP V10 actual rock pocket clearance cutter';pts=vv(copy);center=sum(pts,Vector())/len(pts)
        for v in copy.data.vertices:
            world=copy.matrix_world@v.co;v.co=copy.matrix_world.inverted()@(center+(world-center)*1.012)
        subtract(case,copy);bpy.data.objects.remove(copy,do_unlink=True)
    cut_order=sorted(h['objects'],key=lambda n:0 if'cast split receiver body'in n else 1 if'crossmember'in n or'load neck'in n else 2 if'cage shoulder'in n else 3)
    for name in cut_order:
        target=bpy.data.objects[name]
        if'conforming ceramic pocket face'in name or'shaped copper pocket carrier'in name:
            a,b=bounds(target);a-=Vector((.00035,.00035,.00035));b+=Vector((.00035,.00035,.00035));cut=box('TEMP measured machined pocket relief',a,b);subtract(case,cut);new.remove(cut.name);bpy.data.objects.remove(cut,do_unlink=True)
        else:subtract(case,target)
    for name in PANPARTS:subtract(case,bpy.data.objects[name])
    _uv_and_normals(case)
    bm=bmesh.new();bm.from_mesh(case.data);remaining=abs(bm.calc_volume(signed=True));bad=[e for e in bm.edges if len(e.link_faces)!=2];assert not bad,('New receiver cover not closed',index,len(bad));bm.free();bb=bounds(case);assert remaining>.002 and bb[1].z-bb[0].z>.40 and bb[1].y-bb[0].y>.15,('Chunky receiver lost meaningful volume/envelope',index,remaining,bb)
    tr=BVHTree.FromPolygons(vv(case),[p.vertices[:]for p in case.data.polygons],all_triangles=True)
    for x in(-.11,0,.11):
        hit=tr.ray_cast(Vector((x,yc,.6)),Vector((0,0,-1)),1)[0];assert hit is not None and abs(hit.z-.25)<2e-5,('Actual flat cover footprint missing',index,x,hit)
    base=bpy.data.objects[next(n for n in h['objects']if 'chamfered load crossmember'in n)];seat(case,base,(.20,yc,h['crossmember_top_z']),(0,0,1),'Thick receiver cover bears on original actual crossmember crown outside preserved central pocket core')
    core=bpy.data.objects[next(n for n in h['objects']if 'cast split receiver body'in n)];seat(case,core,(.145,yc,.10),(1,0,0),'New retained cover actually fits original receiver-body side; original pocket/hardware geometry unchanged')
    CASES.append({'index':index,'object':case.name,'actual_rock_clearance_cutters':'Both neighboring actual rock fragments uniformly expanded1.012 about actual bounds center for pocket relief; old exact ceramic/copper seats retained','axial_cover_depth':.28,'maximum_width':.46})
assert geometry_digest(unchanged)==guard,'Detail builder changed non-exempt accepted primary geometry'
c.update({'revision':'V10 INTERMEDIATE one chunkier actual-pocket receiver and retained core backing pan'if pilot else'V10 functional receiver/backpan/fastener/guide detail derivative','surface_contacts':surface,'primary_geometry_guard':{'accepted_v09_glb_sha256':sha(OLD/'void-fusion-v09.glb'),'all_original_mesh_names':primary_names,'all_original_digest':all_original_guard,'unchanged_mesh_names':[o.name for o in unchanged],'unchanged_geometry_digest_before_after':guard,'intentional_structural_repairs':REPAIRS,'policy':'Eight explicitly authorized crossed-section side/fore braces repaired with same vertices/bounds/seat planes; other889 accepted primary meshes/transforms unchanged; functional hardware added.'},'functional_detail_v10':{'stage':'INTERMEDIATE_BULK_PILOT_GUIDES_FASTENERS_PENDING','new_objects':new,'engine_pan_objects':PANPARTS,'receiver_covers':CASES,'no_new_external_mount_or_game_ports':True,'ship_service_well':'UnchangedV10fore-onlydeepwell; bodybackingpan is retained engine machinery, including hanging aft portion.'}})
for im in bpy.data.images:
    if im.source=='FILE'and not im.packed_file:im.pack()
bpy.ops.object.select_all(action='DESELECT')
for o in S.objects:
    if o.type in('MESH','EMPTY'):o.select_set(True)
blend=OUT/'void-fusion-v10.blend';glb=blend.with_suffix('.glb');bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=True);bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_extras=True);c.update({'blend_sha256':sha(blend),'glb_sha256':sha(glb)});(OUT/'source-contract.json').write_text(json.dumps(c,indent=2)+'\n')
for name in('stacked-dish-reference.json','reference-feature-mapping.json','supplied-skull-reuse.json','ATTRIBUTION.txt','orphan-diagnosis.json','noctilith-reference.json'):shutil.copy2(OLD/name,OUT/name)
# Actual export pilot image: remove all source physical meshes before import.
for o in list(S.objects):
    if o.type in('MESH','EMPTY'):bpy.data.objects.remove(o,do_unlink=True)
bpy.ops.import_scene.gltf(filepath=str(glb));S.cycles.samples=16;S.camera.location=(1.55,1.75,1.10);target=Vector((0,c['interstone_housings'][3]['center_y'],.03));S.camera.rotation_euler=(target-S.camera.location).to_track_quat('-Z','Y').to_euler();S.camera.data.ortho_scale=1.55;S.render.resolution_x=S.render.resolution_y=850;S.render.filepath=str(OUT/'actual-housing-backpan-pilot.png');bpy.ops.render.render(write_still=True)
(OUT/'intermediate-render-receipt.json').write_text(json.dumps({'glb_sha256':sha(glb),'actual_import_only':True,'stage':'INTERMEDIATE_BULK_CONCEPT_NOT_FINAL_DETAIL_OR_VALIDATION','file':'actual-housing-backpan-pilot.png','sha256':sha(OUT/'actual-housing-backpan-pilot.png')},indent=2)+'\n');print('V10_BULK_PILOT_ACTUAL_EXPORT_SAVED',glb,flush=True)

