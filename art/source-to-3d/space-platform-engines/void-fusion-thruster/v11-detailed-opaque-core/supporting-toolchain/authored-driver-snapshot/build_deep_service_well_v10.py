"""Necessary service assembly: opaque fore well under unavoidable foundation.
Preserves the accepted body and rim-only history. No aft floor/whole deck."""
import bpy,pathlib,sys,json,hashlib
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=pathlib.Path(__file__).resolve().parents[3];BODY=ROOT/'build/thruster-resume-20261117/void-fusion-v09-complete';OUT=BODY/'service-well-v10';OUT.mkdir(exist_ok=True);sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();body_sha=sha(BODY/'void-fusion-v09.glb');assert body_sha=='dead4344d5857aa28cb9885763ddec257ac0aed02d86a1114b8f146478d3b08e'
bpy.ops.wm.open_mainfile(filepath=str(BODY/'narrow-service-underlay.blend'));scene=bpy.context.scene
mat=bpy.data.materials.new('Fore well dark rough nonreflecting receiver');mat.use_nodes=True;bs=mat.node_tree.nodes['Principled BSDF'];bs.inputs['Base Color'].default_value=(.012,.015,.013,1);bs.inputs['Metallic'].default_value=.05;bs.inputs['Roughness'].default_value=.92
def box(name,lo,hi):
    vv=[(x,y,z) for z in (lo[2],hi[2]) for y in (lo[1],hi[1]) for x in (lo[0],hi[0])];ff=[(0,2,3,1),(4,5,7,6),(0,1,5,4),(1,3,7,5),(3,2,6,7),(2,0,4,6)];me=bpy.data.meshes.new(name);me.from_pydata(vv,[],ff);me.update();o=bpy.data.objects.new(name,me);scene.collection.objects.link(o);me.materials.append(mat);uv=me.uv_layers.new(name='WellPhysicalUV')
    for p in me.polygons:
        a,b,c=[me.vertices[i].co for i in p.vertices[:3]];u=(b-a).normalized();v=(b-a).cross(c-a).normalized().cross(u)
        for li in p.loop_indices:q=me.vertices[me.loops[li].vertex_index].co-a;uv.data[li].uv=(q.dot(u),q.dot(v))
    return o
box('NARROW_SERVICE_DEEP_FORE_WELL_FLOOR',(-.50,0,-.47),(.50,4.20,-.43))
box('NARROW_SERVICE_DEEP_WEST_WALL',(-.52,0,-.47),(-.50,4.20,-.24));box('NARROW_SERVICE_DEEP_EAST_WALL',(.50,0,-.47),(.52,4.20,-.24));box('NARROW_SERVICE_DEEP_FORE_BACKWALL',(-.74,4.20,-.47),(.74,4.22,-.24))
def snap():
    rows={}
    for o in scene.objects:
        if o.type!='MESH':continue
        vv=[o.matrix_world@v.co for v in o.data.vertices];o.data.calc_loop_triangles();rows[o.name]={'bounds':[[min(p[i] for p in vv) for i in range(3)],[max(p[i] for p in vv) for i in range(3)]],'vertices':len(vv),'triangles':len(o.data.loop_triangles)}
    return rows
source=snap();blend=OUT/'narrow-service-well-v10.blend';glb=blend.with_suffix('.glb');bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=True);bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',export_animations=False)
for o in list(scene.objects):bpy.data.objects.remove(o,do_unlink=True)
bpy.ops.import_scene.gltf(filepath=str(glb));actual=snap()
for name,q in source.items():assert q['triangles']==actual[name]['triangles'] and max(abs(q['bounds'][a][i]-actual[name]['bounds'][a][i]) for a in (0,1) for i in range(3))<1e-6
assert len(actual)==7 and all(q['bounds'][0][1]>=0 for q in actual.values())
def tree(name):
    o=bpy.data.objects[name];m=o.data;m.calc_loop_triangles();return BVHTree.FromPolygons([o.matrix_world@v.co for v in m.vertices],[list(t.vertices) for t in m.loop_triangles],all_triangles=True)
seats=[]
for side,label in ((-1,'WEST'),(1,'EAST')):
    seats += [('NARROW_SERVICE_DEEP_'+label+'_WALL','NARROW_SERVICE_'+label+'_WELL_RIM',(side*.51,2.1,-.24),(0,0,1)),('NARROW_SERVICE_DEEP_FORE_WELL_FLOOR','NARROW_SERVICE_DEEP_'+label+'_WALL',(side*.50,2.1,-.45),(side,0,0))]
seats += [('NARROW_SERVICE_DEEP_FORE_BACKWALL','NARROW_SERVICE_FORE_RIM_BACKWALL',(0,4.21,-.24),(0,0,1)),('NARROW_SERVICE_DEEP_FORE_WELL_FLOOR','NARROW_SERVICE_DEEP_FORE_BACKWALL',(0,4.20,-.45),(0,1,0))]
records=[]
for a,b,p,n in seats:
    p=Vector(p);n=Vector(n);errors={}
    for name in (a,b):
        tr=tree(name);hits=[tr.ray_cast(p+n*sign*.01,-n*sign,.021)[0] for sign in (-1,1)];distances=[(q-p).length for q in hits if q is not None];assert distances and min(distances)<2e-5,(name,p,distances);errors[name]=min(distances)
    records.append({'a':a,'b':b,'point':list(p),'normal':list(n),'actual_interface_ray_errors':errors})
bpy.ops.import_scene.gltf(filepath=str(BODY/'void-fusion-v09.glb'));mounts=set(json.loads((BODY/'source-contract.json').read_text(encoding='utf-8-sig'))['hanging_mount']['mount_objects']);core=[o for o in scene.objects if o.type=='MESH' and o.name not in actual and o.name not in mounts];fore=[o.matrix_world@v.co for o in core for v in o.data.vertices if (o.matrix_world@v.co).y>=0];minimum_z=min(p.z for p in fore);floor_top=actual['NARROW_SERVICE_DEEP_FORE_WELL_FLOOR']['bounds'][1][2];gap=minimum_z-floor_top;assert gap>.06,gap
below=[p for p in fore if p.z<-.24];side_gap=.50-max(abs(p.x) for p in below);fore_gap=4.20-max(p.y for p in below);assert min(side_gap,fore_gap)>.019
old=json.loads((BODY/'service-underlay-receipt.json').read_text());result={'status':'PASS_ACTUAL_GLb_DEEP_FORE_SERVICE_WELL_SOURCE_EXPORT_SEATS_AND_BODY_CLEARANCE','body_glb_sha256':body_sha,'underlay_glb_sha256':sha(glb),'underlay_blend_sha256':sha(blend),'previous_rim_only_glb_sha256':old['underlay_glb_sha256'],'underlay_glb':str(glb),'parts':actual,'actual_rim_floor_wall_seats':records,'floor_top_z':floor_top,'minimum_actual_fore_core_z':minimum_z,'conservative_floor_to_body_clearance':gap,'minimum_lower_side_wall_gap':side_gap,'minimum_lower_fore_wall_gap':fore_gap,'source_deck_edge_y':0,'deck_top_z':0,'central_fore_well_xy':[[-.50,0],[.50,0],[.50,4.20],[-.50,4.20]],'receiver_xy_polygons':old['receiver_xy_polygons'],'no_aft_floor_or_foundation':True,'reason':'Native origin foundation cannot be removed. Opaque bounded deep service well covers that unavoidable floor beneath the lowered fore installation; original rim-only source preserved. No body changes or whole-deck/donor art.','limits':'Static actual exported surface/bounds witnesses; final camera registration, projected native assembly/underlay occlusion and dynamic runtime art fit require real capture/native review.'}
(OUT/'service-well-receipt.json').write_text(json.dumps(result,indent=2)+'\n');assert sha(BODY/'void-fusion-v09.glb')==body_sha;print('DEEP_FORE_SERVICE_WELL_PASS',sha(glb),gap)
