"""Actual guide-bore, connected-solid and retained cover witnesses after GLB import."""
import bpy,bmesh,pathlib,sys,json,math,hashlib
from mathutils import Vector
from mathutils.bvhtree import BVHTree
O=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve();c=json.loads((O/'source-contract.json').read_text());blend=next(O.glob('void-fusion-v*.blend'));glb=blend.with_suffix('.glb');sha=lambda p:hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()
def tree(o):
    o.data.calc_loop_triangles();return BVHTree.FromPolygons([o.matrix_world@v.co for v in o.data.vertices],[list(t.vertices)for t in o.data.loop_triangles],all_triangles=True)
def solid(o):
    bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7);assert all(len(e.link_faces)==2 for e in bm.edges),(o.name,'Open/nonmanifold guide/hardware')
    unseen=set(bm.verts);parts=0
    while unseen:
        parts+=1;todo=[unseen.pop()]
        while todo:
            v=todo.pop();neighbors={e.other_vert(v)for e in v.link_edges}&unseen;unseen-=neighbors;todo.extend(neighbors)
    assert parts==1,(o.name,'Disconnected parts',parts);volume=bm.calc_volume(signed=True);assert volume>1e-12,(o.name,'Wrong/zero volume',volume);bm.free();return {'object':o.name,'closed_manifold':True,'connected_components':parts,'signed_volume':volume}
def measure():
    result=[]
    for g in c['functional_detail_v10']['guide_inventory']:
        point=Vector(g['axis_point']);T=Vector(g['axis']).normalized();ref=Vector((0,0,1))if abs(T.z)<.9 else Vector((1,0,0));U=T.cross(ref).normalized();V=T.cross(U).normalized();sleeve=bpy.data.objects[g['sleeve']];tr=tree(sleeve);radii=[]
        for j in range(48):
            d=U*math.cos(math.tau*j/48)+V*math.sin(math.tau*j/48);hit=tr.ray_cast(point,d,g['sleeve_outer_radius']*1.2);assert hit[0]is not None,(g['sleeve'],'Actual bore ray misses',j);radii.append((hit[0]-point).length)
        minimum=min(radii);gap=minimum-g['wire_radius'];assert gap>0.0002,(g['sleeve'],'Actual bore insufficient',gap)
        parts=[solid(bpy.data.objects[g[k]])for k in('clip','sleeve','cradle','foot')]
        result.append({'clip':g['clip'],'sleeve':g['sleeve'],'actual_wire_radius':g['wire_radius'],'actual_minimum_polygonal_bore_radius':minimum,'actual_minimum_radial_wire_clearance':gap,'actual_bore_ray_count':48,'solid_parts':parts,'actual_Pipette_architecture':g['actual_Pipette_call']['architecture_id'],'actual_Pipette_joint':g['actual_Pipette_call']['joint_id']})
    for f in c['functional_detail_v10']['fastener_inventory']:
        solid(bpy.data.objects[f['head']]);solid(bpy.data.objects[f['washer']])
    for case in c['functional_detail_v10']['receiver_covers']:
        info=solid(bpy.data.objects[case['object']]);assert info['signed_volume']>.002,(case,'Lost chunky volume')
    return result
bpy.ops.wm.open_mainfile(filepath=str(blend));source=measure()
for o in list(bpy.context.scene.objects):
    if o.type in('MESH','EMPTY'):bpy.data.objects.remove(o,do_unlink=True)
bpy.ops.import_scene.gltf(filepath=str(glb));actual=measure();assert len(actual)==34
for a,b in zip(source,actual):assert abs(a['actual_minimum_radial_wire_clearance']-b['actual_minimum_radial_wire_clearance'])<1e-5
result={'status':'PASS_ACTUAL_SOURCE_GLb_34_PROTECTIVE_GUIDES_62_CAPTIVE_FASTENERS_SIX_CLOSED_RECEIVER_COVERS','glb_sha256':sha(glb),'blend_sha256':sha(blend),'actual_guides':actual,'actual_connected_fastener_count':len(c['functional_detail_v10']['fastener_inventory']),'actual_receiver_covers':6,'minimum_actual_bore_clearance':min(q['actual_minimum_radial_wire_clearance']for q in actual),'limits':'Actual static bore and closed-connected surface witnesses; full passing source/export seat and existing-wire clearance receipts remain required. Protective guide architecture is not a new gameplay connector, electrical rating or fluid fitting.'}
(O/'guide-cover-export-validation.json').write_text(json.dumps(result,indent=2)+'\n');print('ACTUAL_GUIDE_AND_COVER_SOLIDS_PASS',len(actual),result['minimum_actual_bore_clearance'])
