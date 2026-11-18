"""Independent actual GLB endpoint, bore, tangency and route-clearance witness.
No invented electrical rating or exhaustive dynamic collision proof."""
import bpy,pathlib,sys,json,math,hashlib
from mathutils import Vector,kdtree
from mathutils.bvhtree import BVHTree
O=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve();c=json.loads((O/'source-contract.json').read_text());sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();BLEND=next(O.glob('void-fusion-v*.blend'));GLB=BLEND.with_suffix('.glb');bpy.ops.wm.open_mainfile(filepath=str(BLEND))
ring_sources={}
for rec in c['pipette']['builds']:
    o=bpy.data.objects[rec['body']];rings=int(o['pipette_ring_count']);sides=len(o.data.vertices)//rings;assert sides==16,(o.name,rings,len(o.data.vertices))
    ring_sources[o.name]=[[list(o.matrix_world@o.data.vertices[i*sides+j].co) for j in range(sides)] for i in range(rings)]
for o in list(bpy.context.scene.objects):
    if o.type in ('MESH','EMPTY'):bpy.data.objects.remove(o,do_unlink=True)
bpy.ops.import_scene.gltf(filepath=str(GLB));bpy.context.view_layer.update();cache={}
def tree(name):
    if name not in cache:
        o=bpy.data.objects[name];me=o.data;me.calc_loop_triangles();cache[name]=BVHTree.FromPolygons([o.matrix_world@v.co for v in me.vertices],[list(t.vertices) for t in me.loop_triangles],all_triangles=True)
    return cache[name]
centers={};actual_od={};maxmatch=0
for name,rings in ring_sources.items():
    o=bpy.data.objects[name];vv=[o.matrix_world@v.co for v in o.data.vertices];kd=kdtree.KDTree(len(vv))
    for i,v in enumerate(vv):kd.insert(v,i)
    kd.balance();cc=[];rmax=0
    for ring in rings:
        actual=[]
        for p in ring:
            v,i,d=kd.find(p);assert d<1e-5,(name,d);actual.append(v);maxmatch=max(maxmatch,d)
        center=sum(actual,Vector())/16;cc.append(center);rmax=max(rmax,max((v-center).length for v in actual))
    centers[name]=cc;actual_od[name]=rmax*2
fixtures=[]
for f in c['pipette']['fixtures']:
    tr=tree(f['conductor_object']);stop=Vector(f['wire_stop_socket']['xyz']);entry=Vector(f['wire_entry_socket']['xyz']);n=Vector(f['wire_entry_socket']['normal']);errors=[]
    # Recast the full wire cross-section down the actual reimported bore.
    for old in f['source_bore_measurement']['endstop_probes']:
        expected=Vector(old['expected_stop_face_point']);offset=expected-stop;hit=tr.ray_cast(entry+offset+n*.003,-n,(entry-stop).length+.008)
        assert hit[0] is not None,(f['conductor_object'],'Bore missing');error=(hit[0]-expected).length;assert error<2e-5,(f['conductor_object'],'Bore blocked',error);errors.append(error)
    fixtures.append({'object':f['conductor_object'],'actual_GLb_bore_probe_count':len(errors),'maximum_endstop_error':max(errors),'entry_distinct_from_mate':f['source_mating_measurement']['wire_entry_is_distinct_from_mate']})
endpoints=[]
for e in c['pipette']['endpoints']:
    cc=centers[e['body']];start=e['end']=='start';p=cc[0] if start else cc[-1];direction=(cc[1]-cc[0]).normalized() if start else (cc[-2]-cc[-1]).normalized();normal=Vector(e['stop']['normal']);error=(p-Vector(e['stop']['xyz'])).length;tangent=direction.dot(normal)
    assert error<1e-5 and tangent>.985,(e['route'],e['end'],error,tangent)
    endpoints.append({'route':e['route'],'end':e['end'],'actual_cap_center_to_stop':error,'actual_first_or_last_segment_dot_bore_axis':tangent,'fixture':e['fixture']})
clearances=[]
rock_names=[r['object'] for r in c['rock_bays']]
hardware_names=['Continuous structural keel -1','Continuous structural keel 1','V04 cage longitudinal crown rail -1','V04 cage longitudinal crown rail 1']+[n for h in c['interstone_housings'] for n in h['objects'] if 'ceramic' not in n and 'pocket carrier' not in n]
hardware_names += [q['web'] for q in c['authored_refinement']['cast_webs']]+[q['object'] for q in c['stacked_dish_reference']['actual_tiers']]+['V07 retained hollow ceramic focusing sleeve','V07 retained stem shoulder and projecting faceted emitter']
hardware_names += c.get('functional_detail_v10',{}).get('new_objects',[])
for rec in c['pipette']['builds']:
    name=rec['body'];cc=centers[name];radius=actual_od[name]/2;samples=cc+[(a+b)/2 for a,b in zip(cc,cc[1:])];minimum=float('inf');nearest_name=None
    for obstacle in rock_names+hardware_names:
        tr=tree(obstacle)
        for p in samples:
            near=tr.find_nearest(p)
            if near[0] is not None and near[3]-radius<minimum:minimum=near[3]-radius;nearest_name=obstacle
    print('ACTUAL_ROUTE_GAP',rec['route'],minimum,nearest_name,flush=True)
    record={'route':rec['route'],'sampled_center_and_chord_midpoint_count':len(samples),'minimum_sampled_rock_and_machine_frame_surface_gap':minimum,'nearest_part':nearest_name}
    if rec['kind']=='continuous-six-turn-power-winding':
        request=next(q for q in c['pipette']['requests'] if q['id']==rec['route']);side_text,index_text=rec['route'].removeprefix('narrow-coil-').rsplit('-',1);side=int(side_text);index=int(index_text);core=bpy.data.objects['Insulator %s %02d'%(side,index)];vv=[core.matrix_world@v.co for v in core.data.vertices];p0=core.matrix_world.translation;outer=max(math.hypot(v.x-p0.x,v.z-p0.z) for v in vv);lo=min(v.y for v in vv);hi=max(v.y for v in vv);gap=min(math.hypot(p.x-p0.x,p.z-p0.z)-radius-outer for p in samples if lo<p.y<hi)
        assert gap>0,(rec['route'],'Winding intersects actual insulating core',gap);record['minimum_conservative_actual_insulator_radial_gap']=gap
    clearances.append(record)
assert len(c['pipette']['builds'])==38 and len(endpoints)==76 and len(fixtures)==76
failed=[q for q in clearances if q['minimum_sampled_rock_and_machine_frame_surface_gap']<=-.00002]
result={'status':'FAIL_ACTUAL_ROUTE_FRAME_CLEARANCE' if failed else 'PASS_38_VISIBLE_ELECTRICAL_ROUTES_76_TERMINATIONS_ACTUAL_EXPORT','failed_clearances':failed,'glb_sha256':sha(GLB),'blend_sha256':sha(BLEND),'script_sha256':sha(pathlib.Path(__file__)),'actual_vertex_correspondence_max_error':maxmatch,'fixture_bores':fixtures,'endpoint_caps_and_tangency':endpoints,'sampled_route_clearances':clearances,'inventory':c['pipette']['visible_line_inventory'],'limits':['Every visible electrical route has typed actual Pipette plan/build and two actual fixtures. This is not a simulation of electrical ampacity.','Actual centerline rings reconstructed from actual reimported mesh vertices; ring and chord midpoint clearance witnesses are sampled static checks, not exhaustive dynamic triangle collision proof.','Separately passing full roundtrip receipt is required for triangle/UV/material, all receiver-seat and skull/bay gates.']}
(O/'pipette-export-validation.json').write_text(json.dumps(result,indent=2)+'\n');assert not failed,failed;print('PIPETTE_ACTUAL_EXPORT_PASS',len(endpoints),min(q['minimum_sampled_rock_and_machine_frame_surface_gap'] for q in clearances))

