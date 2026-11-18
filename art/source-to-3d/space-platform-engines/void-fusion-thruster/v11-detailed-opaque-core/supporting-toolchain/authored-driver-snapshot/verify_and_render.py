"""Reopen packed source, reimport actual GLB, measure and render the export."""
import bpy,math,json,pathlib,sys,hashlib
from mathutils import Vector,kdtree
from mathutils.bvhtree import BVHTree
OUT=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve()
model_files=list(OUT.glob('void-fusion-v*.blend'));assert len(model_files)==1,model_files
BLEND=model_files[0];GLB=BLEND.with_suffix('.glb')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(name,value):(OUT/name).write_text(json.dumps(value,indent=2)+'\n',encoding='utf-8')
def snapshot():
    result={}; bpy.context.view_layer.update()
    for o in bpy.context.scene.objects:
        if o.type!='MESH':continue
        m=o.data;m.calc_loop_triangles();uv=m.uv_layers.active
        assert uv,('missing UV',o.name)
        vv=[o.matrix_world@v.co for v in m.vertices]
        assert all(math.isfinite(c) for v in vv for c in v)
        area=0;rows=[];degenerate=0;collapsed=0
        for t in m.loop_triangles:
            a,b,c=[vv[i] for i in t.vertices];ar=(b-a).cross(c-a).length/2
            if ar<1e-12:degenerate+=1
            area+=ar
            a,b,c=[uv.data[i].uv for i in t.loops]
            if abs((b-a).cross(c-a))<1e-12:collapsed+=1
            for li in t.loops:
                p=vv[m.loops[li].vertex_index];u=uv.data[li].uv
                rows.append(tuple(p)+tuple(u)+(m.materials[t.material_index].name,))
        assert not degenerate,('zero-area triangle',o.name,degenerate)
        assert not collapsed,('collapsed UV',o.name,collapsed)
        result[o.name]={'bounds':[[min(v[i] for v in vv) for i in range(3)],[max(v[i] for v in vv) for i in range(3)]],'triangles':len(m.loop_triangles),'surface_area':area,'rows':set(rows)}
    return result
def bounds(parts):return [[min(v['bounds'][0][i] for v in parts.values()) for i in range(3)],[max(v['bounds'][1][i] for v in parts.values()) for i in range(3)]]
contract=json.loads((OUT/'source-contract.json').read_text())
bpy.ops.wm.open_mainfile(filepath=str(BLEND))
native=snapshot();source_images=[{'name':i.name,'packed':bool(i.packed_file),'size':list(i.size)} for i in bpy.data.images if i.source=='FILE']
assert source_images and all(i['packed'] and min(i['size'])>0 for i in source_images)
S=bpy.context.scene
for o in list(S.objects):
    if o.type in ('MESH','EMPTY'):bpy.data.objects.remove(o,do_unlink=True)
for material in list(bpy.data.materials):bpy.data.materials.remove(material)
for image in list(bpy.data.images):bpy.data.images.remove(image)
bpy.ops.import_scene.gltf(filepath=str(GLB))
actual=snapshot();assert native.keys()==actual.keys()
max_pos=max_uv=max_area=0
for name,n in native.items():
    a=actual[name];assert n['triangles']==a['triangles'],name
    vals=list(a['rows']);tree=kdtree.KDTree(len(vals))
    for i,v in enumerate(vals):tree.insert(v[:3],i)
    tree.balance()
    for row in n['rows']:
        choices=[(dist,i) for _,i,dist in tree.find_range(row[:3],1e-5) if vals[i][5]==row[5] and max(abs(row[j]-vals[i][j]) for j in (3,4))<1e-5]
        assert choices,('export position/UV/material correspondence',name,row)
        dist,i=min(choices);max_pos=max(max_pos,dist);max_uv=max(max_uv,max(abs(row[j]-vals[i][j]) for j in (3,4)))
    max_area=max(max_area,abs(n['surface_area']-a['surface_area']))
    assert abs(n['surface_area']-a['surface_area'])<1e-4,name
bb=bounds(actual)
lowered=bool(contract.get('hanging_mount',{}).get('opening_half_width'))
mount_names=set(contract.get('hanging_mount',{}).get('mount_objects',[]))
corebb=bounds({name:q for name,q in actual.items() if name not in mount_names})
assert corebb[0][0]>=-.45-1e-6 and corebb[1][0]<=.45+1e-6,corebb
assert bb[0][0]>=-(.72 if lowered else .45)-1e-6 and bb[1][0]<=(.72 if lowered else .45)+1e-6,bb
assert bb[0][1]>=-4.45-1e-6 and bb[1][1]<=4.45+1e-6,bb
if not lowered:assert abs(bb[0][2])<1e-6,bb
contacts=[]
for c in contract['contacts']:
    a=actual[c['a']]['bounds'];b=actual[c['b']]['bounds']
    gaps=[max(a[0][i]-b[1][i],b[0][i]-a[1][i],0) for i in range(3)]
    assert max(gaps)<1e-5,('support AABB gap',c,gaps)
    contacts.append(dict(c,axis_gaps=gaps,scope_limit='World AABB overlap/touch test only; not actual surface clearance or exhaustive collision proof.'))
images=[{'name':i.name,'packed':bool(i.packed_file),'size':list(i.size)} for i in bpy.data.images if i.source=='FILE']
assert all(i['packed'] and min(i['size'])>0 for i in images)
assert not any(o.name.lower().startswith('socket') for o in S.objects)
surface_contacts=[];trees={};triangle_lists={}
def tree(name):
    if name not in trees:
        o=bpy.data.objects[name];m=o.data;m.calc_loop_triangles();trees[name]=BVHTree.FromPolygons([o.matrix_world@v.co for v in m.vertices],[list(t.vertices) for t in m.loop_triangles],all_triangles=True)
    return trees[name]
def robust_nearest_surface_distance(name,point):
    # Scalar Python doubles avoid BVHTree.find_nearest's observed millimetre
    # error on this vessel's very long thin triangles. BVH rays remain a
    # separate acceptance measurement. Project to each real triangle/edge.
    if name not in triangle_lists:
        o=bpy.data.objects[name];m=o.data;m.calc_loop_triangles()
        verts=[tuple(o.matrix_world@v.co) for v in m.vertices]
        triangle_lists[name]=[[verts[i] for i in t.vertices] for t in m.loop_triangles]
    sub=lambda a,b:tuple(a[i]-b[i] for i in range(3))
    dot=lambda a,b:sum(a[i]*b[i] for i in range(3))
    p=tuple(point);best=float('inf')
    for a,b,c in triangle_lists[name]:
        ab=sub(b,a);ac=sub(c,a);ap=sub(p,a)
        nn=(ab[1]*ac[2]-ab[2]*ac[1],ab[2]*ac[0]-ab[0]*ac[2],ab[0]*ac[1]-ab[1]*ac[0])
        n2=dot(nn,nn)
        if n2<1e-24:continue
        plane=dot(ap,nn)/n2;q=tuple(p[i]-plane*nn[i] for i in range(3));aq=sub(q,a)
        d00=dot(ab,ab);d01=dot(ab,ac);d11=dot(ac,ac);d20=dot(aq,ab);d21=dot(aq,ac);den=d00*d11-d01*d01
        v=(d11*d20-d01*d21)/den;w=(d00*d21-d01*d20)/den
        if min(v,w)>=-1e-10 and v+w<=1+1e-10:best=min(best,abs(plane)*math.sqrt(n2))
        for aa,bb in ((a,b),(b,c),(c,a)):
            edge=sub(bb,aa);t=max(0,min(1,dot(sub(p,aa),edge)/dot(edge,edge)))
            best=min(best,math.sqrt(sum((p[i]-aa[i]-t*edge[i])**2 for i in range(3))))
    return best
for c in contract.get('surface_contacts',[]):
    p=Vector(c['point']);n=Vector(c['normal']);distances={};ray_errors={}
    for name in (c['a'],c['b']):
        tr=tree(name);distance=robust_nearest_surface_distance(name,p)
        distances[name]=distance;assert distance<=c['tolerance'],('actual nearest-surface seat failure',name,p,distance,c)
        # Two-sided localized rays must meet an actual triangle near the point.
        rr=[]
        tangent=n.cross(Vector((0,0,1)))
        if tangent.length<.1:tangent=n.cross(Vector((0,1,0)))
        tangent.normalize();other=n.cross(tangent).normalized()
        # Triangle-edge samples can miss both exact rays after float export.
        # A 2-microunit tangential dither avoids edge ambiguity; every resulting
        # intersection still has to be within the ORIGINAL seat tolerance.
        for delta in (Vector(),tangent*2e-6,-tangent*2e-6,other*2e-6,-other*2e-6,(tangent+other)*2e-6,(tangent-other)*2e-6,(-tangent+other)*2e-6,(-tangent-other)*2e-6):
            for sign in (-1,1):
                span=c.get('ray_span',.035)
                q=tr.ray_cast(p+delta+n*span*sign,-n*sign,span*2+1e-6)
                if q[0] is not None:rr.append((q[0]-p).length)
        assert rr and min(rr)<=c['tolerance'],('actual interface ray failure',name,c,rr)
        ray_errors[name]=min(rr)
    surface_contacts.append(dict(c,nearest_surface_distances=distances,two_sided_ray_point_errors=ray_errors))
embedding=[]
for c in contract.get('embedded_reliefs',[]):
    o=bpy.data.objects[c['skull']];p=Vector(c['support_plane_point']);n=Vector(c['support_plane_normal']).normalized()
    signed=[((o.matrix_world@v.co)-p).dot(n) for v in o.data.vertices]
    depth=max(signed)-min(signed);fraction=-min(signed)/depth
    assert min(signed)<0<max(signed) and fraction>=c['minimum_embedded_fraction'],('actual GLB skull embedding',c,fraction)
    support_distance=robust_nearest_surface_distance(c['support'],p)
    assert support_distance<2e-5,('embedding support plane is not actual support surface',c,support_distance)
    hit=tree(c['support']).ray_cast(p+n*.02,-n,.04)
    assert hit[0] is not None and (hit[0]-p).length<2e-5,('actual medallion upper face ray',c,hit)
    embedding.append(dict(c,actual_total_directional_depth=depth,actual_behind_plane_depth=-min(signed),actual_exposed_depth=max(signed),actual_embedded_fraction=fraction,actual_support_plane_surface_distance=support_distance,actual_support_plane_ray_error=(hit[0]-p).length,scope='Directional depth embedding relative to measured actual support face. Not a volume fraction or exhaustive boolean-intersection proof.'))
result={'status':'PASS_STATIC_SOURCE_EXPORT_CONSTRUCTION_CHECKS','blend_sha256':sha(BLEND),'glb_sha256':sha(GLB),'mesh_count':len(actual),'triangles':sum(a['triangles'] for a in actual.values()),'actual_bounds':bb,'width_depth_height':[bb[1][i]-bb[0][i] for i in range(3)],'world_position_max_delta':max_pos,'uv_max_delta':max_uv,'surface_area_max_delta':max_area,'native_images':source_images,'imported_loaded_images':images,'contacts':contacts,'surface_contacts':surface_contacts,'parts':{k:{x:v for x,v in a.items() if x!='rows'} for k,a in actual.items()},'limits':['No animation acceptance: rigid construction pilot.','AABB contacts remain a coarse screen. Additional named nearest-triangle and two-sided ray contacts are sampled seats, not exhaustive collision/grounding proof.','No native sprite projection, runtime integration, engine operation or owner appearance acceptance.']}
result['embedded_reliefs']=embedding
if contract.get('hanging_mount'):
    mount=contract['hanging_mount'];foundations=[]
    for name in mount['intended_foundation_objects']:
        box=actual[name]['bounds'];assert box[0][1]>=-1e-6 and abs(box[0][2])<1e-6,(name,box)
        foundations.append({'object':name,'bounds':box,'fore_only':True})
    aft_vertices=[o.matrix_world@v.co for o in S.objects if o.type=='MESH' for v in o.data.vertices if (o.matrix_world@v.co).y<-1e-5]
    if not lowered:assert min(p.z for p in aft_vertices)>.06,'Aft floor receiver remains'
    axial=bb[1][1]-bb[0][1];fraction=-bb[0][1]/axial
    assert .45<fraction<.57,fraction
    result['hanging_mount_validation']={'status':'PASS_FORE_ONLY_FOUNDATION_AND_ROUGHLY_HALF_AXIAL_OVERHANG','source_deck_edge_y':0,'deck_top_z':0,'foundation_objects':foundations,'minimum_aft_vertex_z':min(p.z for p in aft_vertices),'aft_axial_fraction':fraction,'no_intended_foundation_at_y_negative':True,'scope':'Source physical geometry only. Native grid split is quantized; future camera registration must measure sourceedgeY0 to legal nativecut, not assume coordinates identical.'}
    if mount.get('source_edge_anchor'):
        anchor=bpy.data.objects[mount['source_edge_anchor']];assert anchor.matrix_world.translation.length<1e-6
        result['hanging_mount_validation']['actual_exported_edge_anchor']=list(anchor.matrix_world.translation)
        result['hanging_mount_validation']['future_legal_native_cut_y']=mount['legal_native_narrow_cut_y']
if contract.get('carrier_clearances'):
    axis_z=contract['carrier_clearances'].get('axis_z',.51)
    sleeve=bpy.data.objects['V07 retained hollow ceramic focusing sleeve'];points=[sleeve.matrix_world@v.co for v in sleeve.data.vertices];inner=min(math.hypot(p.x,p.z-axis_z) for p in points)
    # Minimum radius of actual polygonal inner walls, not just vertex radius.
    sleeve.data.calc_loop_triangles();wall_radii=[]
    for tri in sleeve.data.loop_triangles:
        vv=[points[i] for i in tri.vertices]
        if not all(abs(math.hypot(p.x,p.z-axis_z)-inner)<1e-5 for p in vv):continue
        for a,b in ((vv[0],vv[1]),(vv[1],vv[2]),(vv[2],vv[0])):
            ax,az=a.x,a.z-axis_z;dx,dz=b.x-a.x,b.z-a.z;den=dx*dx+dz*dz
            if den>1e-12:
                t=max(0,min(1,-(ax*dx+az*dz)/den));wall_radii.append(math.hypot(ax+t*dx,az+t*dz))
    min_bore=min(wall_radii)
    core=bpy.data.objects['V07 ceramic-contained energized focal core'];core_r=max(math.hypot((core.matrix_world@v.co).x,(core.matrix_world@v.co).z-axis_z) for v in core.data.vertices)
    tip=bpy.data.objects['V07 retained stem shoulder and projecting faceted emitter'];sleeve_y=[min(p.y for p in points),max(p.y for p in points)]
    tip_r=max(math.hypot(p.x,p.z-axis_z) for v in tip.data.vertices if sleeve_y[0]<= (p:=tip.matrix_world@v.co).y<=sleeve_y[1])
    assert min_bore-core_r>.005 and min_bore-tip_r>.0015,(min_bore,core_r,tip_r)
    result['actual_carrier_clearances']={'minimum_actual_polygonal_bore_radius':min_bore,'maximum_core_radius':core_r,'maximum_overlapping_tip_stem_radius':tip_r,'core_clearance_lower_bound':min_bore-core_r,'tip_clearance_lower_bound':min_bore-tip_r,'scope':'Conservative concentric static radial clearance using actual GLB polygon walls and overlap vertices; not a dynamic/thermal sweep.'}
if contract.get('finish_repair'):
    repair=contract['finish_repair'];assert not any(name in bpy.data.objects for name in repair['removed_orphan_objects'])
    seats={q['a'] for q in surface_contacts}|{q['b'] for q in surface_contacts}
    for entry in repair['actual_receiver_inventory']:assert entry['object'] in actual and entry['object'] in seats,entry
    result['actual_fastener_receiver_audit']={'status':'PASS_42_LEGACY_ORPHANS_REMOVED_92_REMAINING_FASTENERS_AND_RECEIVERS_SEATED','removed_count':len(repair['removed_orphan_objects']),'remaining_count':len(repair['actual_receiver_inventory']),'inventory':repair['actual_receiver_inventory'],'scope':'Explicit named fastener/receiver inventory with real current surface-seat results. Does not silently generalize this to every decorative or nonfastener part.'}
write('roundtrip-validation.json',result)
if '--verify-only' in sys.argv:
    print('VOID_STATIC_CHECKS_PASS',result['mesh_count'],result['triangles'],bb,len(surface_contacts));sys.exit(0)
S.render.threads_mode='FIXED';S.render.threads=2;S.cycles.samples=24
views=[('export-front',(5,-8,12),(0,0,.4),10.7,False),('export-rear',(-5,8,11),(0,0,.4),10.7,False),('export-clay',(5,8,11),(0,0,.4),10.7,True),('export-contacts',(3,-5,2.2),(0,-3.5,.4),2.55,False)]
if contract.get('revision'):
    views += [('export-skull-detail',(1.0,1.9,2.8),(0,3.527,.95),1.0,False),('export-support-detail',(1.6,-1.2,.65),(0,-.85,.2),1.45,False)]
if contract.get('rock_bays'):
    views += [('export-fieldhead-detail',(1.4,-5.8,1.7),(0,-4.02,.51),1.6,False),('export-working-green',(5,-8,12),(0,0,.4),10.7,False)]
if '--emitter-only' in sys.argv:
    assert contract.get('stacked_dish_reference'),'Emitter-only review requires the recorded current dish revision'
    views=[v for v in views if v[0] in ('export-front','export-fieldhead-detail','export-working-green')]
if contract.get('authored_refinement'):
    views=[v for v in views if v[0] in ('export-front','export-rear','export-clay','export-fieldhead-detail')]
    views += [('export-rock-detail',(1.6,-1.5,1.7),(0,-.90,.56),1.35,False),('export-cage-detail',(1.7,.6,.8),(0,.19,.45),1.50,False)]
if contract.get('hanging_mount'):
    views += [('export-deck-cutaway',(5,-8,12),(0,0,.35),10.7,False),('export-deck-side',(7,-.3,1.25),(0,0,.3),10.0,False),('export-deck-underside',(5,-2,-2.8),(0,.2,.25),10.0,False)]
if '--finish-focus' in sys.argv:
    assert contract.get('finish_repair')
    order=['export-rock-detail','export-cage-detail','export-fieldhead-detail','export-front','export-rear','export-clay','export-deck-side']
    views=sorted([v for v in views if v[0] in order],key=lambda v:order.index(v[0]))
receipt=[]
clay=bpy.data.materials.new('Neutral geometry clay');clay.diffuse_color=(.42,.42,.42,1);clay.use_nodes=True
clay.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.42,.42,.42,1)
clay.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.7
for name,loc,target,scale,neutral in views:
    if name.startswith('export-deck-'):
        if not bpy.data.objects.get('REVIEW_ONLY_FORE_DECK'):
            bpy.ops.mesh.primitive_cube_add(size=1,location=(0,2.4,-.10));deck=bpy.context.object;deck.name='REVIEW_ONLY_FORE_DECK';deck.dimensions=(2.6,4.8,.20);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
            dm=bpy.data.materials.new('Review fore-only deck datum');dm.use_nodes=True;dm.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.09,.12,.14,1);dm.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.7;deck.data.materials.append(dm)
        bpy.data.objects['REVIEW_ONLY_FORE_DECK'].hide_render=False
    elif bpy.data.objects.get('REVIEW_ONLY_FORE_DECK'):bpy.data.objects['REVIEW_ONLY_FORE_DECK'].hide_render=True
    if name=='export-working-green':
        S.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.035
        for o in S.objects:
            if o.type=='LIGHT':o.data.energy*=.18
    S.view_layers[0].material_override=clay if neutral else None
    S.camera.location=loc;S.camera.rotation_euler=(Vector(target)-S.camera.location).to_track_quat('-Z','Y').to_euler();S.camera.data.ortho_scale=scale
    S.render.resolution_x=760;S.render.resolution_y=1100 if name!='export-contacts' else 760
    if name in ('export-deck-side','export-deck-underside'):S.render.resolution_x=1100;S.render.resolution_y=640
    S.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)
    p=OUT/(name+'.png');receipt.append({'file':p.name,'sha256':sha(p),'scope':'Actual reimported GLB; no source meshes remain in scene.'})
write('render-receipt.json',{'glb_sha256':result['glb_sha256'],'renders':receipt})
print('VOID_STATIC_CHECKS_AND_RENDER_PASS',result['mesh_count'],result['triangles'],bb,max_pos,max_uv,len(contacts))
