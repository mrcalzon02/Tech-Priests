"""Seated functional cover/guide/fastener work on the reviewed V10 bulk.
Pipette compatible protective clips retain existing bare power lines; no new
wire route, game socket, fluid fitting or primary shape is invented."""
import bpy,pathlib,sys,json,math,hashlib,shutil,importlib.util
from mathutils import Vector
from mathutils.bvhtree import BVHTree
HERE=pathlib.Path(__file__).resolve().parent;ROOT=HERE.parents[2];OLD=ROOT/'build/thruster-resume-20261117/void-fusion-v10i-bulk-guarded';OUT=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve();OUT.mkdir(exist_ok=True,parents=True)
INITIAL_MODULE_HASHES={name:hashlib.sha256((ROOT/'tools/fmpl/pipette'/name).read_bytes()).hexdigest()for name in('library_fittings.py','library_geometry.py','architecture_catalog.v1.json','joint_catalog.v1.json')}
sys.path.insert(0,str(HERE));from pipette_power_terminal import _uv_and_normals
sys.path.insert(0,str(ROOT/'tools/fmpl/pipette'));import library_fittings as fit
sha=lambda p:hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest();bpy.ops.wm.open_mainfile(filepath=str(OLD/'void-fusion-v10.blend'));S=bpy.context.scene;S.render.threads_mode='FIXED';S.render.threads=2;c=json.loads((OLD/'source-contract.json').read_text());surface=c['surface_contacts'];new=c['functional_detail_v10']['new_objects'];added=[]
for q in surface:
    if q['reason'].startswith('Thick receiver cover bears'):q['point'][0]=.155
def material(name,color,metal,rough):
    m=bpy.data.materials.new(name);m.use_nodes=True;p=m.node_tree.nodes['Principled BSDF'];p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough;return m
METAL=material('V11 machined satin iron cover hardware',(.095,.105,.10),.78,.55);CAST=material('V11 blackened cast iron guide receivers',(.035,.043,.038),.66,.64);POLY=material('V11 dark protective polymer clip',(.015,.025,.017),0,.77);CERAMIC=material('V11 compressed ceramic bus guide sleeve',(.038,.055,.022),0,.73);GASKET=material('V11 receiver split-cover compressed joint',(.008,.012,.009),0,.88)
def mesh(name,vv,ff,mat):
    me=bpy.data.meshes.new(name);me.from_pydata(vv,[],ff);me.update();o=bpy.data.objects.new(name,me);S.collection.objects.link(o);me.materials.append(mat);_uv_and_normals(o);new.append(name);added.append(name);return o
def box(name,lo,hi,mat=CAST):return mesh(name,[(x,y,z)for z in(lo[2],hi[2])for y in(lo[1],hi[1])for x in(lo[0],hi[0])],[(0,2,3,1),(4,5,7,6),(0,1,5,4),(1,3,7,5),(3,2,6,7),(2,0,4,6)],mat)
def spec_mesh(prefix,spec,mat,origin=None):
    if origin is None:return mesh(prefix+spec['name'],spec['vertices'],spec['faces'],mat)
    origin=Vector(origin);points=[[float(v[i])-float(origin[i])for i in range(3)]for v in spec['vertices']];o=mesh(prefix+spec['name'],points,spec['faces'],mat);o.location=origin;return o
def tree(o):
    bpy.context.view_layer.update();o.data.calc_loop_triangles();return BVHTree.FromPolygons([o.matrix_world@v.co for v in o.data.vertices],[list(t.vertices)for t in o.data.loop_triangles],all_triangles=True)
def seat(a,b,p,n,reason,span=.035):surface.append({'a':a.name,'b':b.name,'point':list(p),'normal':list(n),'tolerance':2e-5,'ray_span':span,'reason':reason})
def beveled(o,width=.001):
    mod=o.modifiers.new('Small real machined cover edge radius','BEVEL');mod.width=width;mod.segments=2;mod.affect='EDGES';bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name);_uv_and_normals(o)
def bolt(parent,p,n,r,prefix):
    p=Vector(p);n=Vector(n).normalized();u=n.cross(Vector((0,1,0)))
    if u.length<.1:u=n.cross(Vector((0,0,1)))
    u.normalize();h=r*.30;washer=spec_mesh(prefix,fit.annul(tuple(p+n*h/2),tuple(n),r*1.35,r*.52,h,arch='asset_mechanical_retention',label='actual bored captive washer',role='actual-washer',sides=24),METAL,p)
    head=spec_mesh(prefix,fit.rod(tuple(p+n*h),tuple(p+n*(h+r*1.05)),r,arch='asset_mechanical_retention',label='retained hex head',role='actual-captive-head',sides=6),METAL,p)
    shaft=spec_mesh(prefix,fit.rod(tuple(p-n*r*1.4),tuple(p+n*h),r*.46,arch='asset_mechanical_retention',label='bounded threaded insert stud',role='intentional-threaded-insertion',sides=12),METAL,p)
    mod=head.modifiers.new('Actually connected head and captive stud','BOOLEAN');mod.operation='UNION';mod.solver='EXACT';mod.object=shaft;bpy.context.view_layer.objects.active=head;bpy.ops.object.modifier_apply(modifier=mod.name);new.remove(shaft.name);added.remove(shaft.name);bpy.data.objects.remove(shaft,do_unlink=True);_uv_and_normals(head)
    seat(washer,parent,p+u*r*.85,n,'Actual washer rear annulus bears on named cover/guide plate; bore remains open',r*.07)
    seat(head,washer,p+n*h+u*r*.68,n,'Actual hex head lower annular patch seats on bored washer upper face',r*.07)
    return {'head':head.name,'washer':washer.name,'parent':parent.name,'intentional_stud_insertion':r*1.4}

FASTENERS=[];PLATES=[]
for row in c['functional_detail_v10']['receiver_covers']:
    i=row['index'];h=c['interstone_housings'][i];y=h['center_y'];hy=min(.045,h['measured_gap']*.30);case=bpy.data.objects[row['object']];tr=tree(case)
    for x in(-.11,0,.11):
        hit=tr.ray_cast(Vector((x,y,.6)),Vector((0,0,-1)),.5)[0];assert hit is not None and abs(hit.z-.25)<2e-5,('Actual cover cap missing',case.name,x,hit)
    gasket=box('V11 receiver%02d actual split joint'%i,(-.13,y-hy,.25),(.13,y+hy,.253),GASKET);plate=box('V11 receiver%02d retained inspection cover'%i,(-.14,y-hy,.253),(.14,y+hy,.261),METAL);beveled(plate,.0008)
    seat(gasket,case,(0,y,.25),(0,0,1),'Real receiver cover joint lower plane on current cast cap');seat(plate,gasket,(0,y,.253),(0,0,1),'Real cover plate lower plane bears on compressed split joint')
    ys=(y,)if hy<.03 else(y-hy*.45,y+hy*.45)
    for j,yy in enumerate(ys):
        for side in(-1,1):FASTENERS.append(bolt(plate,(side*.105,yy,.261),(0,0,1),.008,'V11 receiver%02d cover%d %s '%(i,j,side)))
    PLATES.append({'case':case.name,'plate':plate.name,'gasket':gasket.name,'actual_edge_radius':.0008})

# Pin actual shared library bytes before/after the new compatible calls.
module=ROOT/'tools/fmpl/pipette';snapshot=OUT/'pipette-detail-source-snapshot';snapshot.mkdir(exist_ok=True);hashes={}
for name in('library_fittings.py','library_geometry.py','architecture_catalog.v1.json','joint_catalog.v1.json'):
    hashes[name]=sha(module/name);assert hashes[name]==INITIAL_MODULE_HASHES[name];shutil.copy2(module/name,snapshot/name)
GUIDES=[]
def guide(parent,center,axis,normal,diam,wire_radius,prefix,base_center=None):
    center=Vector(center);T=Vector(axis).normalized();N=Vector(normal);N=(N-T*N.dot(T)).normalized();U=T.cross(N).normalized();r=diam/2;R=r*1.22;half=r*.58/2;architecture='conduit_split_corrugated_loom';call={'architecture_id':architecture,'joint_id':'split_loom_clip','port':{'id':prefix+'receiving-clip','xyz_bu':list(center),'outward_normal':list(T)},'diameter':diam};raw=fit.build(**call)
    parts=[spec_mesh(prefix,s,POLY,center)for s in raw];clip=parts[0]
    for other in parts[1:]:
        mod=clip.modifiers.new('One connected molded retaining clip','BOOLEAN');mod.operation='UNION';mod.solver='EXACT';mod.object=other;bpy.context.view_layer.objects.active=clip;bpy.ops.object.modifier_apply(modifier=mod.name);new.remove(other.name);added.remove(other.name);bpy.data.objects.remove(other,do_unlink=True)
    _uv_and_normals(clip);sleeve_outer=r*.75;sleeve_inner=wire_radius+(.0012 if wire_radius>.005 else .0004);assert sleeve_inner<sleeve_outer
    sleeve=spec_mesh(prefix,fit.annul(tuple(center),tuple(T),sleeve_outer,sleeve_inner,half*2,arch=architecture,label='actual protective ceramic wire sleeve',role='open-clearance-wire-protector',sides=24),CERAMIC,center)
    cliptr=tree(clip);parenttr=tree(parent);basecenter=Vector(base_center)if base_center is not None else center;foot_half=.045 if wire_radius>.005 else .0065;width=.025 if wire_radius>.005 else .0095;bottom=[];top=[]
    # Parent-facing foot is ray-fitted to the ACTUAL receiving surface.
    for a in(-foot_half,foot_half):
        for u in(-width,width):
            q=basecenter+U*u+T*a;hit=parenttr.ray_cast(q+N*.15,-N,.40)[0];assert hit is not None,(prefix,'Receiver foot misses',q);bottom.append(hit)
    thickness=.020 if wire_radius>.005 else .0018;outer_plane=max((p-center).dot(N)for p in bottom)+thickness;top=[p+N*(outer_plane-(p-center).dot(N))for p in bottom]
    foot=mesh(prefix+'shaped bolted receiving foot',[list(p)for p in bottom+top],[(0,2,3,1),(4,5,7,6),(0,1,5,4),(1,3,7,5),(3,2,6,7),(2,0,4,6)],CAST)
    for j in range(4):seat(foot,parent,bottom[j],N,'Actual guide foot underside ray-fitted to named engine pan/web receiver')
    # Concave upper cradle is fitted to actual outer clip triangles; it spans
    # to the foot as one closed formed section, not a floating eye/ring.
    contours=[]
    for a in(-half*.8,half*.8):
        pp=[]
        for j in range(9):
            u=R*(-.95+1.9*j/8);q=center+U*u+T*a;hit=cliptr.ray_cast(q-N*R*2,N,R*4)[0];assert hit is not None,(prefix,'Clip profile ray misses',j);pp.append(hit)
        # Inboard foot pad provides a diagonal load path for the outboard bus.
        aa=(top[0]+top[1])/2 if a<0 else(top[2]+top[3])/2
        pp += [aa+U*width,aa-U*width];contours.append(pp)
    count=len(contours[0]);verts=[list(p)for row in contours for p in row];faces=[tuple(reversed(range(count))),tuple(range(count,count*2))]+[(j,(j+1)%count,(j+1)%count+count,j+count)for j in range(count)];cradle=mesh(prefix+'actual concave cast clip cradle',verts,faces,CAST)
    for i in(1,3,4,5,7):seat(cradle,clip,contours[0][i],N,'Actual concave cradle profile receives actual Pipette clip outer surface',R*.12)
    # Foot top points must agree with the corresponding cradle lower face.
    for sign in(-1,1):
        q=(top[0]+top[1]+top[2]+top[3])/4+T*(half*.8*sign);seat(cradle,foot,q,N,'Guide cradle actual lower cap on real receiving-foot top')
    outer_points=[sleeve.matrix_world@v.co for v in sleeve.data.vertices if abs(((sleeve.matrix_world@v.co)-center-T*((sleeve.matrix_world@v.co)-center).dot(T)).length-sleeve_outer)<1e-6]
    assert outer_points;delta=outer_points[0]-center;radial=delta-T*delta.dot(T);contact=center+radial
    seat(sleeve,clip,contact,radial.normalized(),'Compatible protective sleeve outer polygon contacts actual retaining clip bore',sleeve_outer*.03)
    bp=(top[0]+top[1]+top[2]+top[3])/4
    if wire_radius>.005:
        for sign in(-1,1):FASTENERS.append(bolt(foot,bp+T*(foot_half*.57*sign),N,.007,prefix+'foot%d '%sign))
    else:FASTENERS.append(bolt(foot,bp+U*.006+T*.003,N,.0018,prefix+'foot '))
    GUIDES.append({'clip':clip.name,'sleeve':sleeve.name,'cradle':cradle.name,'foot':foot.name,'parent':parent.name,'actual_Pipette_call':call,'original_recipe_meshes':raw,'axis_point':list(center),'axis':list(T),'wire_radius':wire_radius,'sleeve_inner_radius':sleeve_inner,'sleeve_outer_radius':sleeve_outer,'minimum_polygonal_wire_clearance':sleeve_inner*math.cos(math.pi/24)-wire_radius,'classification':'Mechanical protective-loom clip/ceramic sleeve guide around existing bare power conductor, not a new conductor/route/game socket/fluid fitting'})

centers=[h['center_y']for h in c['interstone_housings']];mount_y=(.18984344,1.60295499,2.69258317)
for i,(a,b)in enumerate(zip(centers,centers[1:])):
    options=[a+(b-a)*t for t in(.5,.35,.65,.25,.75)];valid=[y for y in options if all(abs(y-m)>.115 for m in mount_y)];assert valid;y=valid[0]
    for side in(-1,1):guide(bpy.data.objects['V10 core pan raised side return '+str(side)],(side*.345,y,.10),(0,1,0),(0,0,1),.040,.010,'V11 axialbus%02d %s '%(i,side),base_center=(side*.315,y,.10))

# Every existing field approach receives one actual supported midspan guide.
for rec in c['pipette']['builds']:
    if rec['kind']!='dish-field-power-lead':continue
    route=bpy.data.objects[rec['body']];rings=int(route['pipette_ring_count']);sides=len(route.data.vertices)//rings;cc=[sum((route.matrix_world@route.data.vertices[k*sides+j].co for j in range(sides)),Vector())/sides for k in range(rings)];k=rings//2;axis=(cc[k+2]-cc[k-2]).normalized();webname=rec['route'].removeprefix('narrow-field-lead-').replace('-',' ')
    # Original web names have no hyphens; exact recipe route encodes spaces.
    parent=bpy.data.objects[webname];guide(parent,cc[k],axis,(0,-1,0),.012,.002,'V11 fieldguide '+parent.name+' ')
for name,digest in hashes.items():assert sha(module/name)==digest,('Concurrent shared Pipette recipe changed',name)

for name in new:
    o=bpy.data.objects[name]
    if o.type=='MESH':assert o.data.uv_layers and len(o.data.vertices)>0,name
from bake_surface_atlas import bake
large=[bpy.data.objects[n]for n in new if any(w in n for w in('receiver cover','pan floor','pan raised','retained inspection cover'))]
for o in large:
    for mat in o.data.materials:
        if 'V10'in mat.name:mat.name='V11 blackened cast iron '+mat.name
bake_record=bake(large,OUT/'textures','V11 receiver-pan-constructed-surfaces',768,surface,False)
c['functional_detail_v10'].update({'stage':'DETAIL_CONSTRUCTION_COMPLETE_INDEPENDENT_CHECKS_PENDING','new_objects':new,'cover_plates':PLATES,'guide_inventory':GUIDES,'fastener_inventory':FASTENERS,'detail_Pipette_module_hashes_before_after':hashes,'new_large_region_PBR_bake':bake_record,'line_geometry_policy':'All38existingPipetteconductors unchanged; only compatible protective guides/supports added.'});c['revision']='V11 constructed narrow receivers/pan/captive joints/actual protected electrical guides'
for im in bpy.data.images:
    if im.source=='FILE'and not im.packed_file:im.pack()
bpy.ops.object.select_all(action='DESELECT')
for o in S.objects:
    if o.type in('MESH','EMPTY'):o.select_set(True)
blend=OUT/'void-fusion-v11.blend';glb=blend.with_suffix('.glb');bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=True);bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_extras=True);c.update({'blend_sha256':sha(blend),'glb_sha256':sha(glb)});(OUT/'source-contract.json').write_text(json.dumps(c,indent=2)+'\n')
for name in('stacked-dish-reference.json','reference-feature-mapping.json','supplied-skull-reuse.json','ATTRIBUTION.txt','orphan-diagnosis.json','noctilith-reference.json'):shutil.copy2(OLD/name,OUT/name)
print('V11_CONSTRUCTED_DETAIL_SAVED',len(GUIDES),len(FASTENERS),len(surface),glb,flush=True)

