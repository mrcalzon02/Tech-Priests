"""Actual source/export convex-brace and opaque-core behavior witnesses."""
import bpy,bmesh,pathlib,sys,json,math,hashlib
from mathutils import Vector
from mathutils.bvhtree import BVHTree
O=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve();c=json.loads((O/'source-contract.json').read_text());sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();blend=next(O.glob('void-fusion-v*.blend'));glb=blend.with_suffix('.glb');HERE=pathlib.Path(__file__).resolve().parent;ROOT=HERE.parents[2];sys.path.insert(0,str(ROOT/'tools/art/thruster_resumption/animation'));from electric_arcs import geometry_digest
pan=[n for n in c['functional_detail_v10']['engine_pan_objects']if'floor'in n]
def bounds(o):
    vv=[o.matrix_world@v.co for v in o.data.vertices];return [[min(v[i]for v in vv)for i in range(3)],[max(v[i]for v in vv)for i in range(3)]]
def aggregate(objects):
    vv=[];ff=[]
    for o in objects:
        o.data.calc_loop_triangles();start=len(vv);vv.extend(o.matrix_world@v.co for v in o.data.vertices);ff.extend(tuple(i+start for i in t.vertices)for t in o.data.loop_triangles)
    return BVHTree.FromPolygons(vv,ff,all_triangles=True)
def repaired_solids():
    result=[]
    for record in c['primary_geometry_guard']['intentional_structural_repairs']:
        o=bpy.data.objects[record['object']];bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7);assert all(len(e.link_faces)==2 for e in bm.edges),(o.name,'Open/nonmanifold brace')
        assert len(bm.verts)==8,(o.name,len(bm.verts));points=[v.co.copy()for v in bm.verts];error=0
        for f in bm.faces:
            for p in points:error=max(error,(p-f.verts[0].co).dot(f.normal))
        assert error<2e-6,(o.name,'Nonconvex/selfcrossing brace',error);volume=bm.calc_volume(signed=True);assert volume>1e-6,(o.name,volume);bm.free();result.append({'object':o.name,'closed_manifold':True,'vertices_after_UV_weld':8,'convex_halfspace_error':error,'actual_signed_volume':volume,'bounds':bounds(o)})
    assert len(result)==8;return result
bpy.ops.wm.open_mainfile(filepath=str(blend));source=[o for o in bpy.context.scene.objects if o.type=='MESH'];unchanged=[bpy.data.objects[n]for n in c['primary_geometry_guard']['unchanged_mesh_names']];assert geometry_digest(unchanged)==c['primary_geometry_guard']['unchanged_geometry_digest_before_after'];source_solids=repaired_solids();source_tree=aggregate(source);baseline=aggregate([bpy.data.objects[n]for n in c['primary_geometry_guard']['all_original_mesh_names']]);lo=min(bounds(bpy.data.objects[n])[0][1]for n in pan);hi=max(bounds(bpy.data.objects[n])[1][1]for n in pan)
targets=[]
for h in c['interstone_housings']:
    for dy in (-.04,0,.04):
        for j in range(13):targets.append(Vector((-.22+j*.44/12,h['center_y']+dy,.08)))
for i in range(51):
    y=lo+.10+(hi-lo-.55)*i/50
    for j in range(9):targets.append(Vector((-.22+j*.44/8,y,.08)))
direction=Vector((0,1,-1)).normalized()
def ray(tree,target):return tree.ray_cast(target-direction*2,direction,5)[0]
source_hits=[ray(source_tree,p)is not None for p in targets];baseline_hits=[ray(baseline,p)is not None for p in targets];assert all(source_hits),('Source protected core see-through',sum(source_hits),len(targets),[list(p)for p,h in zip(targets,source_hits)if not h][:12])
side_targets=[(Vector((0,h['center_y']+dy,z)),Vector((side,0,0)))for h in c['interstone_housings']for dy in(-.12,-.09,0,.09,.12)for z in(-.26,-.13,-.10)for side in(-1,1)]
def side_hits(tree):return [tree.ray_cast(p-d*1.2,d,2.4)[0]is not None for p,d in side_targets]
source_sides=side_hits(source_tree);baseline_sides=side_hits(baseline);assert all(source_sides),('Source backingpan side windows remain see-through',sum(source_sides),len(source_sides))
for o in list(bpy.context.scene.objects):
    if o.type in('MESH','EMPTY'):bpy.data.objects.remove(o,do_unlink=True)
bpy.ops.import_scene.gltf(filepath=str(glb));actual=[o for o in bpy.context.scene.objects if o.type=='MESH'];actual_solids=repaired_solids();actual_tree=aggregate(actual);actual_hits=[ray(actual_tree,p)is not None for p in targets];assert all(actual_hits)and actual_hits==source_hits
actual_sides=side_hits(actual_tree);assert actual_sides==source_sides
result={'status':'PASS_ACTUAL_SOURCE_GLb_EIGHT_CONVEX_REPAIRED_BRACES_AND_OPAQUE_PROTECTED_CORE','glb_sha256':sha(glb),'blend_sha256':sha(blend),'unchanged_primary_mesh_count':len(unchanged),'source_repaired_solids':source_solids,'actual_glb_repaired_solids':actual_solids,'protected_core':{'x_range':[-.22,.22],'source_z_reference':.08,'core_y_range':[lo+.10,hi-.45],'canonical45_ray_direction':list(direction),'source_ray_count':len(targets),'source_blocked':sum(source_hits),'actual_glb_blocked':sum(actual_hits),'accepted_body_subset_without_new_pan_or_cases_blocked':sum(baseline_hits),'newly_blocked_rays':sum(a and not b for a,b in zip(actual_hits,baseline_hits)),'sampling':'Six inter-stone interface windows plus51 axial core stations, inside keels. Outer cage openings, mounting margins and field aperture are intentionally excluded.','limits':'Finite canonical-view geometric ray sample, not a claim that every intentional exterior opening is closed or arbitrary camera projections are opaque.'}}
result['protected_core']['side_and_underside_window_witness']={'source_count':len(side_targets),'source_blocked':sum(source_sides),'actual_glb_blocked':sum(actual_sides),'old_body_subset_blocked':sum(baseline_sides),'newly_blocked':sum(a and not b for a,b in zip(actual_sides,baseline_sides)),'mask':'Both±Xviewdirections, five axial offsets about each of six interfaces, Z-.26/-.13/-.10 inside backing/core zone; aperture/exterioruppercage excluded.'}
(O/'functional-detail-export-validation.json').write_text(json.dumps(result,indent=2)+'\n');print('ACTUAL_DETAIL_SOLID_AND_CORE_RAYS_PASS',len(targets),result['protected_core']['newly_blocked_rays'],result['protected_core']['side_and_underside_window_witness']['newly_blocked'])
# Actual transparent-alpha and3D contrasting-background witnesses; no2D mask.
S=bpy.context.scene;S.cycles.samples=16;S.render.threads_mode='FIXED';S.render.threads=2;S.render.film_transparent=True
for m in bpy.data.materials:
    if m.use_nodes:
        for node in m.node_tree.nodes:
            if node.type=='BSDF_PRINCIPLED':node.inputs['Emission Strength'].default_value=0
target=Vector((0,c['interstone_housings'][3]['center_y'],.02));S.camera.location=target+Vector((0,-3,3));S.camera.rotation_euler=(target-S.camera.location).to_track_quat('-Z','Y').to_euler();S.camera.data.ortho_scale=1.7;S.render.resolution_x=S.render.resolution_y=850;renders=[]
S.render.filepath=str(O/'actual-core-transparent-alpha.png');bpy.ops.render.render(write_still=True);renders.append({'file':'actual-core-transparent-alpha.png','sha256':sha(O/'actual-core-transparent-alpha.png')})
mat=bpy.data.materials.new('REVIEW_ONLY_MAGENTA_3D_BACKGROUND');mat.use_nodes=True;nt=mat.node_tree;nt.nodes.clear();e=nt.nodes.new('ShaderNodeEmission');e.inputs['Color'].default_value=(.7,.003,.3,1);out=nt.nodes.new('ShaderNodeOutputMaterial');nt.links.new(e.outputs[0],out.inputs['Surface']);bpy.ops.mesh.primitive_cube_add(size=1,location=(0,(lo+hi)/2,-.65));board=bpy.context.object;board.name='REVIEW_ONLY_CONTRASTING_3D_BOARD';board.dimensions=(2,hi-lo+2,.02);board.data.materials.append(mat)
S.render.filepath=str(O/'actual-core-magenta-background.png');bpy.ops.render.render(write_still=True);renders.append({'file':'actual-core-magenta-background.png','sha256':sha(O/'actual-core-magenta-background.png')});(O/'core-opacity-render-receipt.json').write_text(json.dumps({'glb_sha256':sha(glb),'actual_glb_import_only':True,'background':'Actual3D magenta board belowengineZ-.65, review-only neverexported; transparent-alpha witness has no board.','renders':renders},indent=2)+'\n')
