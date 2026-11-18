"""V05: screenshot-directed thick segmented stepped dish emitter, not washers."""
import bpy,json,pathlib,sys,math,hashlib,struct,shutil
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=pathlib.Path(__file__).resolve().parents[3]
OLD=ROOT/'build/thruster-resume-20261117/void-fusion-v04b'
OUT=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve();OUT.mkdir(parents=True,exist_ok=True)
assert not (OUT/'void-fusion-v05.blend').exists(),'Fresh output required'
REF=pathlib.Path(r'C:\Users\Admin\AppData\Local\Temp\codex-clipboard-4c56f180-de0c-4c9c-b642-8fb95cfd6d36.png')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
REF_SHA='51653135eeb298c4cbb6936b0d85faef5ddded231c790752682f80de44470e4f'
CLEAN=ROOT/'tech-priests_src/graphics/entity/void-fusion-thruster/void-fusion-thruster-wide-idle.png'
assert sha(CLEAN)=='3b7b6d743220a516fcfae11162b9ad2e5cff713338f5f7c549664c260a35df16'
if REF.exists():assert sha(REF)==REF_SHA
bpy.ops.wm.open_mainfile(filepath=str(OLD/'void-fusion-v04.blend'));S=bpy.context.scene;S.render.threads_mode='FIXED';S.render.threads=2
contract=json.loads((OLD/'source-contract.json').read_text());removed=[]
for o in list(S.objects):
    if o.name.startswith(('V04 field projector','V04 field stage','V04 projector','V04 extraction')):
        removed.append(o.name);bpy.data.objects.remove(o,do_unlink=True)
surface=[c for c in contract['surface_contacts'] if c['a'] not in removed and c['b'] not in removed]
contacts=[c for c in contract['contacts'] if c['a'] not in removed and c['b'] not in removed]
mats={k:bpy.data.materials[n] for k,n in [('hull','Spine blackened cast iron'),('bands','Worn bronze retaining bands'),('rail','Satin iron load rails'),('ceramic','Glazed olive insulator'),('green','Noctilith energized fracture Necron green')]}
def mesh(name,verts,faces,mat):
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update();o=bpy.data.objects.new(name,me);S.collection.objects.link(o);me.materials.append(mats[mat]);bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.uv.smart_project(island_margin=.02);bpy.ops.object.mode_set(mode='OBJECT');return o
def cyl(name,pos,r,h,mat,axis='Y',n=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=n,radius=r,depth=h,location=pos);o=bpy.context.object;o.name=name
    if axis=='Y':o.rotation_euler.x=math.pi/2
    o.data.materials.append(mats[mat]);return o
def rod(name,a,b,r,mat):
    d=Vector(b)-Vector(a);o=cyl(name,(Vector(a)+Vector(b))/2,r,d.length,mat,'Z',16);o.rotation_euler=d.to_track_quat('Z','Y').to_euler();return o
def tree(o):
    bpy.context.view_layer.update();m=o.data;m.calc_loop_triangles();return BVHTree.FromPolygons([o.matrix_world@v.co for v in m.vertices],[list(t.vertices) for t in m.loop_triangles],all_triangles=True)
def annular_sector(name,r0,r1,y0,y1,a0,a1,mat,n=5):
    vv=[]
    for y in (y0,y1):
        for r in (r0,r1):
            for j in range(n+1):
                a=a0+(a1-a0)*j/n;vv.append((r*math.cos(a),y,.51+r*math.sin(a)))
    w=n+1;ff=[]
    for j in range(n):ff.extend([(j,j+1,w+j+1,w+j),(2*w+j,3*w+j,3*w+j+1,2*w+j+1),(j,2*w+j,2*w+j+1,j+1),(w+j,w+j+1,3*w+j+1,3*w+j)])
    ff.extend([(0,w,3*w,2*w),(w-1,3*w-1,4*w-1,2*w-1)])
    return mesh(name,vv,ff,mat)
STAGES=[];receivers=[]
for i,(center,R) in enumerate(((-3.64,.405),(-3.93,.330),(-4.16,.255))):
    ri=R*.22;N=64;rad=[ri+(R-ri)*j/9 for j in range(10)]
    def front(r):return center+.055-.12*(r/R)**1.5
    verts=[]
    # Two real offset curved faces, annular bore and substantial rim thickness.
    for back in (False,True):
        for r in rad:
            for j in range(N):
                a=math.tau*j/N;verts.append((r*math.cos(a),front(r)+(.027 if back else 0),.51+r*math.sin(a)))
    layer=10*N;faces=[]
    for back in (0,1):
        for k in range(9):
            for j in range(N):
                a=back*layer+k*N+j;b=back*layer+k*N+(j+1)%N;faces.append((a,b,b+N,a+N))
    for k in (0,9):
        for j in range(N):
            a=k*N+j;b=k*N+(j+1)%N;faces.append((a,a+layer,b+layer,b))
    dish=mesh('V05 tier%02d thick concave annular dish'%i,verts,faces,'hull')
    band=annular_sector('V05 tier%02d continuous armored rim band'%i,R-.038,R+.005,center-.091,center-.012,0,math.tau,'bands',64)
    # Twelve separated actual armor segments and real aft-face captive bolts.
    for j in range(12):
        a=math.tau*j/12;half=math.radians(13)
        plate=annular_sector('V05 tier%02d segmented rim armor%02d'%(i,j),R-.030,R+.014,center-.099,center-.006,a-half,a+half,'rail')
        r=R-.008;x=r*math.cos(a);z=.51+r*math.sin(a)
        bolt=cyl('V05 tier%02d rim plate captive bolt%02d'%(i,j),(x,center-.107,z),.011,.016,'bands',n=6)
        surface.append({'a':bolt.name,'b':plate.name,'point':[x,center-.099,z],'normal':[0,1,0],'tolerance':2e-5,'reason':'Actual bolt rear cap seated on actual segmented armor front plane'})
    # Source-visible radial braces follow the shallow dished face, not a cone.
    for j in range(8):
        a=j*math.tau/8
        radii=[ri+.012+(R*.83-ri-.012)*q/3 for q in range(4)]
        for k,(r0,r1) in enumerate(zip(radii,radii[1:])):
            aa=(r0*math.cos(a),front(r0)-.011,.51+r0*math.sin(a));bb=(r1*math.cos(a),front(r1)-.011,.51+r1*math.sin(a))
            rod('V05 tier%02d radial brace%02d part%02d'%(i,j,k),aa,bb,.012,'bands')
            aa=(aa[0],aa[1]-.011,aa[2]);bb=(bb[0],bb[1]-.011,bb[2]);rod('V05 tier%02d green field trace%02d part%02d'%(i,j,k),aa,bb,.0035,'green')
    # Four ceramic receivers ray-seated on the ACTUAL dished back face.
    tr=tree(dish);rr=R*.78;stage_receivers=[]
    for j,a in enumerate((math.pi/4,3*math.pi/4,5*math.pi/4,7*math.pi/4)):
        x=rr*math.cos(a);z=.51+rr*math.sin(a)
        hit=tr.ray_cast(Vector((x,center+.25,z)),Vector((0,-1,0)),.5)[0];assert hit is not None
        receiver=cyl('V05 tier%02d actual seated ceramic receiver%02d'%(i,j),(x,hit.y+.035,z),.026,.07,'ceramic')
        surface.append({'a':receiver.name,'b':dish.name,'point':list(hit),'normal':[0,1,0],'tolerance':2e-5,'reason':'Actual receiver lower axial cap ray-seated on concave dish back triangle'})
        stage_receivers.append((receiver,Vector((x,hit.y+.070,z))))
    receivers.append(stage_receivers)
    STAGES.append({'object':dish.name,'center_y':center,'outer_radius':R,'inner_radius':ri,'actual_curved_face_depth':front(ri)-front(R),'wall_thickness':.027,'armored_band_axial_thickness':.079,'rim_armor_segments':12,'radial_braces':8,'stepped_silhouette':'separate substantial dish tier; decreasing radius toward terminal face'})
# Stabilizing rods step inward with the three dish tiers, with actual capped end
# points meeting ceramic receiver upper faces. No equal-width protruding cage.
for j in range(4):
    for i in range(2):
        aa,pa=receivers[i][j];bb,pb=receivers[i+1][j]
        tie=rod('V05 stepped dish stabilizer %02d span%02d'%(j,i),pa,pb,.015,'rail')
        for receiver,p in ((aa,pa),(bb,pb)):
            surface.append({'a':tie.name,'b':receiver.name,'point':list(p),'normal':[0,1,0],'tolerance':2e-5,'reason':'Actual stabilizer end cap meets ceramic receiver upper axial cap'})
for side in (-1,1):
    a=(side*.30,-3.58,.18);b=(side*.22,-3.58,.78)
    brace=rod('V05 grounded dish stack support '+str(side),a,b,.028,'rail')
    surface.append({'a':brace.name,'b':'Continuous structural keel '+str(side),'point':list(a),'normal':[0,0,1],'tolerance':2e-5,'reason':'Actual dish-stack load-brace cap seats on continuous keel crown'})
# Source-visible projecting tip: faceted armored electrode with a focused green
# root. A discrete prismatic point, not a combustion nozzle or flame.
cyl('V05 central green focal electrode',(0,-4.245,.51),.048,.032,'green')
verts=[];N=8
for y,r in ((-4.25,.070),(-4.345,.052)):
    for j in range(N):
        a=j*math.tau/N;verts.append((r*math.cos(a),y,.51+r*math.sin(a)))
verts.append((0,-4.425,.51));faces=[tuple(reversed(range(N)))]
for j in range(N):
    k=(j+1)%N;faces.extend([(j,k,N+k,N+j),(N+j,N+k,2*N)])
mesh('V05 central projecting faceted field tip',verts,faces,'bands')
for j in range(4):
    a=j*math.pi/2
    rod('V05 field tip energized edge '+str(j),(.071*math.cos(a),-4.255,.51+.071*math.sin(a)),(.053*math.cos(a),-4.345,.51+.053*math.sin(a)),.003,'green')

refmapping={'reference_private_path':str(REF),'reference_sha256':REF_SHA,'image_size':[283,230],'durable_clean_reference':{'path':CLEAN.relative_to(ROOT).as_posix(),'sha256':sha(CLEAN),'head_crop_xyxy':[51,280,334,510],'size':[384,512],'mapping':'The supplied screenshot is a wide-head detail; use this clean committed sprite crop to preserve the dish/crown/tip features without faint UI text. The emitter construction is adapted to narrow 1x9, not copied as a texture.','feature_rectangles_xyxy':{'upper_armored_tier_and_reliquary':[96,307,288,391],'three_stepped_segmented_dish_tiers':[106,368,277,461],'radial_bracing_and_central_projecting_tip':[139,423,245,496]}},'privacy':'Screenshot inspected as design reference only. Background text not imported into textures/art or public gallery. Clipboard existence is optional; rebuild requires the hash-checked committed clean reference.','owner_authority':'Recognizable thick segmented armored stacked dish emitter; tiers decrease toward smaller lower face and central projecting tip. Supersedes prior equal-bore thin-ring interpretation.','feature_rectangles_xyxy':{'upper_armored_tier_and_reliquary':[45,27,237,111],'three_stepped_segmented_dish_tiers':[55,88,226,181],'radial_bracing_and_central_projecting_tip':[88,143,194,216]},'original_narrow_first_cell_head_crop_xyxy':[54,386,138,547],'interpretation':'Adapt screenshot construction to narrow 1x9 width; preserve three discrete stepped dishes and plated/braced silhouette, not a continuous cone.','actual_tiers':STAGES}
(OUT/'stacked-dish-reference.json').write_text(json.dumps(refmapping,indent=2)+'\n')
S['candidate_stage']='V05_OWNER_REFERENCE_THICK_STEPPED_ARMORED_DISH_STACK_CANDIDATE'
bpy.ops.object.select_all(action='DESELECT')
for o in S.objects:
    if o.type in ('MESH','EMPTY'):o.select_set(True)
for im in bpy.data.images:
    if im.source=='FILE' and not im.packed_file:im.pack()
blend=OUT/'void-fusion-v05.blend';glb=OUT/'void-fusion-v05.glb'
bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=True)
bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_extras=True)
contract.update({'revision':'V05 exact owner image: thick segmented armored stepped dish emitter','blend_sha256':sha(blend),'glb_sha256':sha(glb),'previous_blend_sha256':sha(OLD/'void-fusion-v04.blend'),'previous_glb_sha256':sha(OLD/'void-fusion-v04.glb'),'contacts':contacts,'surface_contacts':surface,'stacked_dish_reference':refmapping,'design_authority':dict(contract['design_authority'],projector='Owner screenshot supersedes equal-bore ring guidance: three thick segmented concave armored dish tiers decreasing in radius, plated/bolted rim bands, radial braces and central projecting tip; exotic field emission, no continuous chemical cone.'),'geometry_scope':'Rigid V05 emitter revision; V04b Noctilith cage/green and both half-buried skull transforms retained.'})
(OUT/'source-contract.json').write_text(json.dumps(contract,indent=2)+'\n')
for n in ('reference-feature-mapping.json','supplied-skull-reuse.json','ATTRIBUTION.txt'):shutil.copy2(OLD/n,OUT/n)
print('STACKED_DISH_SOURCE_SAVED',len(surface),blend)
