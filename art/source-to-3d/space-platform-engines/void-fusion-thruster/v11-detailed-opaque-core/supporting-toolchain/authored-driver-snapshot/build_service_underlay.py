"""Source-specific narrow U-bay service rim, separate from body/deck review.
No aft foundation, no donor/chemical underlay, and no central bay floor."""
import bpy,pathlib,sys,json,hashlib,math
from mathutils import Vector
O=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve();c=json.loads((O/'source-contract.json').read_text());sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();bpy.ops.wm.read_factory_settings(use_empty=True)
m=bpy.data.materials.new('Narrow U-bay blackened service rim');m.use_nodes=True;bs=m.node_tree.nodes['Principled BSDF'];bs.inputs['Base Color'].default_value=(.07,.085,.08,1);bs.inputs['Metallic'].default_value=.65;bs.inputs['Roughness'].default_value=.65
def part(name,vv,ff):
    me=bpy.data.meshes.new(name);me.from_pydata(vv,[],ff);me.update();o=bpy.data.objects.new(name,me);bpy.context.scene.collection.objects.link(o);me.materials.append(m);uv=me.uv_layers.new(name='ServiceRimUV')
    for p in me.polygons:
        a,b,cc=[me.vertices[i].co for i in p.vertices[:3]];u=(b-a).normalized();v=(b-a).cross(cc-a).normalized().cross(u)
        for li in p.loop_indices:q=me.vertices[me.loops[li].vertex_index].co-a;uv.data[li].uv=(q.dot(u),q.dot(v))
    return o
ff=[(5,4,3,2,1,0),(6,7,8,9,10,11)]+[(i,(i+1)%6,(i+1)%6+6,i+6) for i in range(6)]
for side in (-1,1):
    # Folded rim carries both flange top contacts and lowered side cheek wall.
    profile=[(.50,-.24),(.52,-.24),(.52,-.12),(.74,-.12),(.74,0),(.50,0)]
    part('NARROW_SERVICE_'+('WEST' if side<0 else 'EAST')+'_WELL_RIM',[(side*x,y,z) for y in (0,4.20) for x,z in profile],ff)
profile=[(4.20,-.24),(4.22,-.24),(4.22,-.12),(4.44,-.12),(4.44,0),(4.20,0)]
part('NARROW_SERVICE_FORE_RIM_BACKWALL',[(x,y,z) for x in (-.74,.74) for y,z in profile],ff)
def snap():
    rows={}
    for o in bpy.context.scene.objects:
        if o.type!='MESH':continue
        vv=[o.matrix_world@v.co for v in o.data.vertices];o.data.calc_loop_triangles();rows[o.name]={'bounds':[[min(p[i] for p in vv) for i in range(3)],[max(p[i] for p in vv) for i in range(3)]],'vertices':len(vv),'triangles':len(o.data.loop_triangles)}
    return rows
source=snap();bpy.ops.wm.save_as_mainfile(filepath=str(O/'narrow-service-underlay.blend'),compress=True);bpy.ops.export_scene.gltf(filepath=str(O/'narrow-service-underlay.glb'),export_format='GLB',export_animations=False)
for o in list(bpy.context.scene.objects):bpy.data.objects.remove(o,do_unlink=True)
bpy.ops.import_scene.gltf(filepath=str(O/'narrow-service-underlay.glb'));actual=snap()
for name,q in source.items():
    assert q['triangles']==actual[name]['triangles']
    assert max(abs(q['bounds'][a][i]-actual[name]['bounds'][a][i]) for a in (0,1) for i in range(3))<1e-6
assert all(q['bounds'][0][1]>=0 for q in actual.values())
receipt={'status':'PASS_ACTUAL_REIMPORTED_SOURCE_SPECIFIC_SERVICE_RIM','body_glb_sha256':c['glb_sha256'],'underlay_glb_sha256':sha(O/'narrow-service-underlay.glb'),'underlay_blend_sha256':sha(O/'narrow-service-underlay.blend'),'parts':actual,'datum':{'deck_edge_y':0,'deck_top_z':0,'source_plus_y':'fore/vessel'},'receiver_xy_polygons':[[[-1.3,0],[-.5,0],[-.5,4.8],[-1.3,4.8]],[[.5,0],[1.3,0],[1.3,4.8],[.5,4.8]],[[-.5,4.2],[.5,4.2],[.5,4.8],[-.5,4.8]]],'clear_opening':{'x':[-.50,.50],'y':[0,4.20],'no_central_floor':True},'scope':'Separate formed well/rim/backwall for this lowered fore U-bay installation. It is not the entire foundation deck, a chemical donor overlay, aft foundation, or native installation acceptance.'}
(O/'service-underlay-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print('SOURCE_SPECIFIC_SERVICE_UNDERLAY_PASS')
bpy.ops.import_scene.gltf(filepath=str(O/'void-fusion-v09.glb'))
from mathutils.bvhtree import BVHTree
def tree(name):
    ob=bpy.data.objects[name];me=ob.data;me.calc_loop_triangles();return BVHTree.FromPolygons([ob.matrix_world@v.co for v in me.vertices],[list(t.vertices) for t in me.loop_triangles],all_triangles=True)
seats=[]
for row in c['hanging_mount']['platform_contacts']:
    receiver='NARROW_SERVICE_FORE_RIM_BACKWALL' if row['receiver'].startswith('fore') else 'NARROW_SERVICE_'+('WEST' if row['point'][0]<0 else 'EAST')+'_WELL_RIM';p=Vector(row['point']);n=Vector(row['normal']);errors={}
    assert p.y>=0
    for name in (row['part'],receiver):
        tr=tree(name);hits=[tr.ray_cast(p+n*sgn*.035,-n*sgn,.071)[0] for sgn in (-1,1)];dd=[(q-p).length for q in hits if q is not None];assert dd and min(dd)<2e-5,(row,name,dd);errors[name]=min(dd)
    seats.append(dict(row,actual_receiver_mesh=receiver,actual_body_receiver_ray_errors=errors))
mounts=set(c['hanging_mount']['mount_objects']);body=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.name not in actual and o.name not in mounts]
below=[o.matrix_world@v.co for o in body for v in o.data.vertices if 0<(o.matrix_world@v.co).y and (o.matrix_world@v.co).z<0]
assert all(abs(p.x)<.50-1e-5 and p.y<4.20-1e-5 for p in below),'Body clips actual U-bay wall/rim'
br={'status':'PASS_ACTUAL_EXPORTED_FLANGE_CHEEK_SEATS_AND_OPEN_U_BAY','body_glb_sha256':c['glb_sha256'],'underlay_glb_sha256':receipt['underlay_glb_sha256'],'platform_contacts':seats,'actual_below_deck_core_vertex_count':len(below),'minimum_conservative_side_wall_gap':.50-max(abs(p.x) for p in below),'minimum_fore_wall_gap':4.20-max(p.y for p in below),'no_intended_aft_foundation_contacts':True,'deck_origin':[0,0,0],'limits':'Static actual mesh interface witnesses and conservative open-bay bounds; native sprite registration and placement remain separate.'}
(O/'lowered-bay-export-validation.json').write_text(json.dumps(br,indent=2)+'\n')
name='V05 tier02 thick concave annular dish';dish=bpy.data.objects[name];vv=[dish.matrix_world@v.co for v in dish.data.vertices];axis_z=.06
outer=[p for p in vv if abs(math.hypot(p.x,p.z-axis_z)-.255)<1e-5];front_y=min(p.y for p in outer);ring=[p for p in outer if abs(p.y-front_y)<1e-5];assert len(ring)>=64
actual_center=Vector((sum(float(p.x) for p in ring)/len(ring),front_y,sum(float(p.z) for p in ring)/len(ring)));assert abs(actual_center.x)<1e-6 and abs(actual_center.z-axis_z)<1e-6
inner=[p for p in vv if abs(math.hypot(p.x,p.z-axis_z)-.0561)<1e-5]
tip=bpy.data.objects['V07 retained stem shoulder and projecting faceted emitter'];tv=[tip.matrix_world@v.co for v in tip.data.vertices]
ap={'status':'PASS_ACTUAL_REIMPORTED_FINAL_DISH_RIM_MEASURED','body_glb_sha256':c['glb_sha256'],'projector_mesh':name,'aperture_center_source':list(actual_center),'outward_axis_source':[0,-1,0],'aperture_radius_source':sum(math.hypot(p.x,p.z-axis_z) for p in ring)/len(ring),'measured_rim_vertices':len(ring),'rim_plane_max_error':max(abs(p.y-front_y) for p in ring),'central_bore_radius':.0561,'central_bore_y_extent':[min(p.y for p in inner),max(p.y for p in inner)],'central_projecting_tip_aftmost_y':min(p.y for p in tv),'definition':'Final stacked dish outer forward-facing aperture rim. Central retained stem projects through/forward of the inner bore; FX must respect the central occluder. Not a chemical nozzle.','deck_edge_source':[0,0,0],'source_unit_to_native_pixel':'Candidate calibration is external measured camera/profile input; no recovered physical/native unit identity is claimed.'}
(O/'aperture-measurement.json').write_text(json.dumps(ap,indent=2)+'\n');print('ACTUAL_DISH_APERTURE_PASS',ap['aperture_center_source'],ap['aperture_radius_source'])
