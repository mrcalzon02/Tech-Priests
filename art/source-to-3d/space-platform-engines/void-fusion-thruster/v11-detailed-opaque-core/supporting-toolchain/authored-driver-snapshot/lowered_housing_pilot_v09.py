"""Lowered U-bay mount + ONE fitted inter-stone housing/Pipette pilot.

Pilot must be visually inspected before repeating its housing over all six bays.
"""
import bpy,bmesh,math,json,pathlib,sys,hashlib,shutil,importlib.util
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
ROOT=pathlib.Path(__file__).resolve().parents[3];OLD=ROOT/'build/thruster-resume-20261117/void-fusion-v08e'
OUT=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve();OUT.mkdir(parents=True,exist_ok=True)
assert not (OUT/'void-fusion-v09.blend').exists()
bpy.ops.wm.open_mainfile(filepath=str(OLD/'void-fusion-v08.blend'));S=bpy.context.scene;S.render.threads_mode='FIXED';S.render.threads=2
c=json.loads((OLD/'source-contract.json').read_text());sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();DROP=.45
removed=[]
for o in list(S.objects):
    if o.name.startswith('V02 mount') and ('ground sole' in o.name or 'captive sole bolt' in o.name):removed.append(o.name);bpy.data.objects.remove(o,do_unlink=True)
contacts=[q for q in c['contacts'] if q['a'] not in removed and q['b'] not in removed];surface=[q for q in c['surface_contacts'] if q['a'] not in removed and q['b'] not in removed]
for o in S.objects:
    if o.type=='MESH' or o.name=='aft_exhaust_axis':o.matrix_world=Matrix.Translation((0,0,-DROP))@o.matrix_world
for q in surface:q['point'][2]-=DROP
for q in c['embedded_reliefs']:q['support_plane_point'][2]-=DROP
c['carrier_clearances']['axis_z']=.51-DROP
M={k:bpy.data.materials[n] for k,n in [('rail','Satin iron load rails'),('hull','Spine blackened cast iron'),('bronze','Worn bronze retaining bands'),('copper','Enclosed copper induction winding'),('ceramic','Glazed olive insulator'),('pad','V06 dark compressed ceramic contact pads')]}
def mesh(name,vv,ff,role):
    me=bpy.data.meshes.new(name);me.from_pydata(vv,[],ff);me.update();o=bpy.data.objects.new(name,me);S.collection.objects.link(o);me.materials.append(M[role]);bm=bmesh.new();bm.from_mesh(me);bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free();uv=me.uv_layers.new(name='PhysicalRegionUV')
    for p in me.polygons:
        a,b,cc=[me.vertices[i].co for i in p.vertices];u=max((b-a,cc-a,cc-b),key=lambda v:v.length).normalized();v=(b-a).cross(cc-a).normalized().cross(u)
        for li in p.loop_indices:q=me.vertices[me.loops[li].vertex_index].co;uv.data[li].uv=(q.dot(u)*2,q.dot(v)*2)
    return o
def box(name,lo,hi,role):
    vv=[(x,y,z) for z in (lo[2],hi[2]) for y in (lo[1],hi[1]) for x in (lo[0],hi[0])]
    return mesh(name,vv,[(0,2,3,1),(4,5,7,6),(0,1,5,4),(1,3,7,5),(3,2,6,7),(2,0,4,6)],role)
def tree(o):
    bpy.context.view_layer.update();me=o.data;me.calc_loop_triangles();return BVHTree.FromPolygons([o.matrix_world@v.co for v in me.vertices],[list(t.vertices) for t in me.loop_triangles],all_triangles=True)
def seat(a,b,p,n,why):surface.append({'a':a.name,'b':b.name,'point':list(p),'normal':list(n),'tolerance':2e-5,'reason':why})
def cyl(name,p,r,h,role):
    bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=r,depth=h,location=p);o=bpy.context.object;o.name=name;o.data.materials.append(M[role]);return o

# Low L-cheeks and diagonal gussets terminate against side ledges and a fore
# crossmember. No old leg/sole extends into the lowered frame installation bay.
foundations=[];platform_contacts=[];mount_objects=[]
for i,y in enumerate((.18984344,1.60295499,2.69258317)):
    for side in (-1,1):
        xa,xb=sorted((side*.49,side*.705));flange=box('V09_mount side ledge flange %02d %s'%(i,side),(xa,y-.10,0),(xb,y+.10,.025),'rail');foundations.append(flange.name);mount_objects.append(flange.name)
        xa,xb=sorted((side*.482,side*.50));cheek=box('V09_mount side lip cheek %02d %s'%(i,side),(xa,y-.065,-.24),(xb,y+.065,.025),'hull');mount_objects.append(cheek.name)
        vv=[]
        for yy in (y-.045,y+.045):vv.extend([(side*.27,yy,-.27),(side*.33,yy,-.27),(side*.482,yy,-.105),(side*.482,yy,-.175)])
        gusset=mesh('V09_mount low diagonal gusset %02d %s'%(i,side),vv,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],'rail');mount_objects.append(gusset.name)
        seat(gusset,bpy.data.objects['Continuous structural keel '+str(side)],(side*.30,y,-.27),(0,0,1),'Lowered cantilever crown to low side-cheek gusset')
        seat(gusset,cheek,(side*.482,y,-.14),(side,0,0),'Gusset outer plane on actual side lip receiving cheek')
        seat(cheek,flange,(side*.495,y,.025),(0,0,1),'L-cheek top and horizontal flange top meet in retained corner')
        bolt=cyl('V09_mount side flange captive bolt %02d %s'%(i,side),(side*.61,y,.035),.022,.020,'bronze');mount_objects.append(bolt.name);seat(bolt,flange,(side*.61,y,.025),(0,0,1),'Actual anchor bolt cap on side flange upper plane')
        platform_contacts += [{'part':flange.name,'receiver':'side_ledge_'+str(side),'point':[side*.61,y,0],'normal':[0,0,1]},{'part':cheek.name,'receiver':'side_ledge_wall_'+str(side),'point':[side*.50,y,-.10],'normal':[side,0,0]}]
for side in (-1,1):
    x=side*.30;flange=box('V09_mount fore crossmember flange '+str(side),(x-.075,4.19,0),(x+.075,4.44,.025),'rail');foundations.append(flange.name);mount_objects.append(flange.name)
    cheek=box('V09_mount fore lip cheek '+str(side),(x-.055,4.182,-.24),(x+.055,4.20,.025),'hull');mount_objects.append(cheek.name)
    vv=[]
    for xx in (x-.045,x+.045):vv.extend([(xx,4.10,-.27),(xx,4.16,-.27),(xx,4.182,-.105),(xx,4.182,-.175)])
    web=mesh('V09_mount fore low crossmember brace '+str(side),vv,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],'rail');mount_objects.append(web.name)
    seat(web,bpy.data.objects['Continuous structural keel '+str(side)],(x,4.14,-.27),(0,0,1),'Fore low brace cap on actual cantilever crown')
    seat(web,cheek,(x,4.182,-.14),(0,1,0),'Fore brace outer receiving plane on fore lip cheek')
    bolt=cyl('V09_mount fore flange captive bolt '+str(side),(x,4.32,.035),.022,.02,'bronze');mount_objects.append(bolt.name);seat(bolt,flange,(x,4.32,.025),(0,0,1),'Fore flange bolt rear cap seats on flange')
    platform_contacts += [{'part':flange.name,'receiver':'fore_crossmember','point':[x,4.32,0],'normal':[0,0,1]},{'part':cheek.name,'receiver':'fore_crossmember_wall','point':[x,4.20,-.10],'normal':[0,1,0]}]

# ONE inter-bay housing, between the two central fore rocks, measured before any
# repetition. Both neighbors receive real conforming ceramic/copper pocket seats.
index=3;ra=bpy.data.objects[c['rock_bays'][index]['object']];rb=bpy.data.objects[c['rock_bays'][index+1]['object']]
def vertices(o):return [o.matrix_world@v.co for v in o.data.vertices]
A=vertices(ra);B=vertices(rb);amax=max(p.y for p in A);bmin=min(p.y for p in B);gap=bmin-amax;assert gap>.035,gap
yc=(amax+bmin)/2;half=min(.025,gap*.25);pad_t=min(.010,gap*.15);housing=[];pockets=[]
def patch(name,inside,outside,role):
    vv=[tuple(p) for p in inside+outside];ff=[]
    for a in (0,1,3,4):ff.extend([(a,a+1,a+4,a+3),(9+a,12+a,13+a,10+a)])
    edge=[0,1,2,5,8,7,6,3]
    for a,b in zip(edge,edge[1:]+edge[:1]):ff.append((a,b,b+9,a+9))
    o=mesh(name,vv,ff,role);housing.append(o.name);return o
for rock,direction in ((ra,-1),(rb,1)):
    tr=tree(rock);pts=[]
    for z in (.025,.10,.175):
        for x in (-.12,0,.12):
            hit=tr.ray_cast(Vector((x,yc,z)),Vector((0,direction,0)),1.5)[0];assert hit is not None,(rock.name,x,z);pts.append(hit)
    back=[p-Vector((0,direction*pad_t,0)) for p in pts]
    ceramic=patch('V09 housing pilot '+rock.name+' fitted ceramic end seat',pts,back,'pad')
    center=[Vector((p.x,yc+direction*half,p.z)) for p in pts]
    copper=patch('V09 housing pilot '+rock.name+' shaped copper pocket',back,center,'copper')
    for j in (0,2,4,6,8):seat(ceramic,rock,pts[j],(0,direction,0),'Measured actual adjacent rock end face and housing ceramic pocket seat')
    for j in (0,4,8):seat(copper,ceramic,back[j],(0,direction,0),'Actual copper carrier receives fitted ceramic rear surface')
    pockets.append({'rock':rock.name,'ceramic':ceramic.name,'copper':copper.name,'bounded_pad_thickness':pad_t,'contact_points':[list(p) for p in pts]})
core=box('V09 housing pilot inter-bay machine core',(-.145,yc-half,.02),(.145,yc+half,.18),'hull');housing.append(core.name)
floor_top=min(min(p.z for p in A),min(p.z for p in B))-.015
base=box('V09 housing pilot cast lower machine crossmember',(-.40,yc-.075,-.27),(.40,yc+.075,floor_top),'rail');housing.append(base.name)
for side in (-1,1):
    lo,hi=sorted((side*.29,side*.435));case=box('V09 housing pilot copper side machine case '+str(side),(lo,yc-.07,floor_top),(hi,yc+.07,-.055),'bronze');housing.append(case.name)
    lo,hi=sorted((side*.165,side*.215));arch=box('V09 housing pilot retained cage shoulder '+str(side),(lo,yc-.020,floor_top),(hi,yc+.020,.3725),'hull');housing.append(arch.name)
    seat(arch,bpy.data.objects['V04 cage longitudinal crown rail '+str(side)],(side*.19,yc,.3725),(0,0,1),'Inter-bay machine shoulder seats into actual upper cage channel')
    seat(base,bpy.data.objects['Continuous structural keel '+str(side)],(side*.30,yc,-.27),(0,0,1),'Machine housing lower crossmember on actual cantilever channels')

# Move the matching visible coil hardware to the new housing pilot. Replace its
# six loose turns per side with one continuous typed Pipette conductor each.
old_coil_y=.68;coil_index=3;dy=yc-old_coil_y;relocated=[];deleted_turns=[]
for side in (-1,1):
    for o in list(S.objects):
        if o.name.startswith('Winding %s %02d'%(side,coil_index)):
            deleted_turns.append(o.name);bpy.data.objects.remove(o,do_unlink=True)
        elif o.name.startswith(('Insulator %s %02d'%(side,coil_index),'Coil collar %s %02d'%(side,coil_index),'Coil support %s %02d'%(side,coil_index))):o.location.y+=dy;relocated.append(o.name)
for q in surface:
    if q['a'] in relocated or q['b'] in relocated:q['point'][1]+=dy

if '--geometry-pilot-only' in sys.argv:
    S['candidate_stage']='INTERMEDIATE_LOWERED_SINGLE_HOUSING_GEOMETRY_REVIEW_PIPETTE_PENDING'
    bpy.ops.object.select_all(action='DESELECT')
    for o in S.objects:
        if o.type in ('MESH','EMPTY'):o.select_set(True)
    blend=OUT/'void-fusion-v09-stage.blend';glb=OUT/'void-fusion-v09-stage.glb'
    bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=True)
    bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_extras=True)
    c.update({'revision':'INTERMEDIATE_LOWERED_SINGLE_HOUSING_REVIEW_ONLY','blend_sha256':sha(blend),'glb_sha256':sha(glb),'validation_status':'UNVERIFIED_CONSTRUCTION_VIEW_NOT_CURRENT_COMPLETION','contacts':contacts,'surface_contacts':surface,'hanging_mount':dict(c['hanging_mount'],intended_foundation_objects=foundations,body_vertical_translation=-DROP,mount_objects=mount_objects,opening_half_width=.50,opening_fore_end_y=4.20,authorized_mount_half_width=.72,platform_contacts=platform_contacts),'housing_pilot':{'index_between_rocks':[index,index+1],'center_y':yc,'measured_gap':gap,'objects':housing,'pockets':pockets},'pipette_status':'Pending; two old toroidal windings removed and receiving cores relocated for actual typed winding build.'})
    (OUT/'source-contract.json').write_text(json.dumps(c,indent=2)+'\n')
    print('LOWERED_GEOMETRY_PILOT_ONLY',yc,glb)
    sys.exit(0)

# Snapshot exactly the concurrently dirty shared library; do not modify it.
module_root=ROOT/'tools/fmpl/pipette';snapshot=OUT/'pipette-source-snapshot';snapshot.mkdir()
module_hash={}
for name in ('core.py','blender_adapter.py','README.md','PIPETTE_STANDARD.md'):
    module_hash[name]=sha(module_root/name);shutil.copy2(module_root/name,snapshot/name);assert sha(snapshot/name)==module_hash[name]
spec=importlib.util.spec_from_file_location('narrow_v09_pipette_adapter',snapshot/'blender_adapter.py');adapter=importlib.util.module_from_spec(spec);spec.loader.exec_module(adapter)
def route_uv(o):
    me=o.data
    if me.uv_layers:return
    uv=me.uv_layers.new(name='PipetteArcLengthUV');rings=int(o.get('pipette_ring_count',0))
    if rings:
        sides=len(me.vertices)//rings;centers=[sum((me.vertices[i*sides+j].co for j in range(sides)),Vector())/sides for i in range(rings)];arc=[0]
        for a,b in zip(centers,centers[1:]):arc.append(arc[-1]+(b-a).length)
        period=max(.001,float(o.get('pipette_outer_diameter_bu',.014))*math.pi)
        for p in me.polygons:
            ids=list(p.vertices);js=[j%sides for j in ids]
            if len(p.vertices)>4:
                a,b,cc=[me.vertices[j].co for j in ids[:3]];u=(b-a).normalized();v=(b-a).cross(cc-a).normalized().cross(u)
                for li in p.loop_indices:q=me.vertices[me.loops[li].vertex_index].co;uv.data[li].uv=(q.dot(u)/period,q.dot(v)/period)
            else:
                seam=0 in js and sides-1 in js
                for li in p.loop_indices:j=me.loops[li].vertex_index;uu=j%sides/sides;uu=1 if seam and j%sides==0 else uu;uv.data[li].uv=(uu,arc[j//sides]/period)
    else:
        # Adapter retaining-band torus: true major/minor angular UVs.
        for p in me.polygons:
            ids=list(p.vertices);major=[j//8 for j in ids];minor=[j%8 for j in ids]
            for li in p.loop_indices:
                j=me.loops[li].vertex_index;u=j//8/24;v=j%8/8
                if 0 in major and 23 in major and j//8==0:u=1
                if 0 in minor and 7 in minor and j%8==0:v=1
                uv.data[li].uv=(u,v)

REQUESTS=[];PLANS=[];BUILDS=[];ENDPOINTS=[]
def bezier(a,b,cc,d,n=12):return [a*(1-t)**3+b*3*(1-t)**2*t+cc*3*(1-t)*t*t+d*t**3 for t in (i/n for i in range(n+1))]
for side in (-1,1):
    axis_x=side*.345;axis_z=.10;terminals=[]
    for terminal,sign in (('start',-1),('end',1)):
        collar=min([o for o in S.objects if o.name.startswith('Coil collar %s %02d'%(side,coil_index))],key=lambda o:abs(o.location.y-(yc+sign*.19)));tr=tree(collar);yp=collar.location.y;inside=[]
        for zz in (-.014,0,.014):
            for xx in (-.014,0,.014):
                hit=tr.ray_cast(Vector((axis_x+xx,yp+zz,axis_z+.2)),Vector((0,0,-1)),.4)[0];assert hit is not None;inside.append(hit)
        ztop=max(p.z for p in inside)+.010;outside=[Vector((p.x,p.y,ztop)) for p in inside];pad=patch('V09 housing pilot '+terminal+' flat power gland pad '+str(side),inside,outside,'bronze')
        for j in (0,4,8):seat(pad,collar,inside[j],(0,0,1),'Actual curved collar receives power-terminal pad underside')
        terminals.append((pad,Vector((axis_x,yp,ztop))))
    turns=6;N=144;R=.079;diam=.014
    helix=[Vector((axis_x+R*math.cos(math.pi/2+math.tau*turns*i/N),yc-.132+.264*i/N,axis_z+R*math.sin(math.pi/2+math.tau*turns*i/N))) for i in range(N+1)]
    tangent=Vector((-R,.264/(math.tau*turns),0)).normalized();pa=terminals[0][1];pb=terminals[1][1]
    first=bezier(pa,pa+Vector((0,0,.04)),helix[0]-tangent*.035,helix[0]);last=bezier(helix[-1],helix[-1]+tangent*.035,pb+Vector((0,0,.04)),pb)
    path=first[:-1]+helix+last[1:]
    sock=lambda term,pad,p,role:{'id':'pilot-coil-%s-%s'%(side,term),'xyz':list(p),'normal':[0,0,1],'role':role,'payloads':['power'],'parent_mesh':pad.name}
    request={'id':'narrow-housing-pilot-continuous-power-winding-'+str(side),'family':'single_wire','payload':'power','size':{'outer_diameter':diam,'wall_fraction':0},'material_id':M['copper'].name,'path':{'kind':'waypoints','points':[list(p) for p in path]},'start_socket':sock('start',terminals[0][0],pa,'source'),'end_socket':sock('end',terminals[1][0],pb,'sink'),'fittings':{'start':'cable_gland','end':'cable_gland'},'keep_outs':[{'id':'protected-rock-interior','min':[-.20,yc-.65,-.10],'max':[.20,yc+.65,.28]},{'id':'upper-cage-rail-band','min':[-.23,yc-.5,.36],'max':[.23,yc+.5,.45]}]}
    plan=adapter.core.plan(request);col,objects=adapter.build(plan,M['copper'],M['bronze'])
    for o in objects:route_uv(o)
    REQUESTS.append(request);PLANS.append(plan);BUILDS.append({'route':request['id'],'collection':col.name,'objects':[o.name for o in objects],'actual_builder':'Pinned byte-identical Pipette core.plan + blender_adapter.build','uv':'Arc-length/circumferential route bodies; cylindrical sleeve caps and toroidal fitting coordinates'})
    body=next(o for o in objects if o.get('pipette_geometry_role')=='continuous-route')
    for term,(pad,p) in zip(('start','end'),terminals):
        seat(body,pad,p,(0,0,1),'Actual Pipette continuous conductor terminal cap on declared power receiving pad')
        ENDPOINTS.append({'route':request['id'],'terminal':term,'receiver':pad.name,'point':list(p),'normal':[0,0,1],'wire_diameter':diam,'fitting':'cable_gland','intentional_fitting_insertion':diam*.85/2,'body':body.name})
for name,digest in module_hash.items():assert sha(module_root/name)==digest,('shared Pipette module changed during build',name)

# Refresh hardware inventory after replacing six plinth bolts with eight real
# platform-flange bolts; Pipette endpoint hardware has its own typed inventory.
inventory=[]
for old in c['finish_repair']['actual_receiver_inventory']:
    if old['object'] not in removed:inventory.append(old)
for name in mount_objects:
    if 'captive bolt' in name:
        rows=[q for q in surface if q['a']==name];inventory.append({'object':name,'actual_receivers':[q['b'] for q in rows],'tight_surface_records':len(rows)})
c['finish_repair']['actual_receiver_inventory']=inventory
c['finish_repair']['remaining_named_fastener_receiver_count']=len(inventory)
S['candidate_stage']='V09_LOWERED_U_BAY_SINGLE_INTERSTONE_HOUSING_TWO_PIPETTE_WINDING_PILOT'
for im in bpy.data.images:
    if im.source=='FILE' and not im.packed_file:im.pack()
bpy.ops.object.select_all(action='DESELECT')
for o in S.objects:
    if o.type in ('MESH','EMPTY'):o.select_set(True)
blend=OUT/'void-fusion-v09.blend';glb=OUT/'void-fusion-v09.glb'
bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=True)
bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_extras=True)
c.update({'revision':'V09 lowered edge-bay installation and first fitted interstone machine housing/Pipette pilot','blend_sha256':sha(blend),'glb_sha256':sha(glb),'previous_blend_sha256':sha(OLD/'void-fusion-v08.blend'),'previous_glb_sha256':sha(OLD/'void-fusion-v08.glb'),'contacts':contacts,'surface_contacts':surface,'hanging_mount':dict(c['hanging_mount'],intended_foundation_objects=foundations,removed_old_plinths=removed,body_vertical_translation=-DROP,mount_objects=mount_objects,opening_half_width=.50,opening_fore_end_y=4.20,authorized_mount_half_width=.72,platform_contacts=platform_contacts,source_edge_anchor='mount_deck_edge_center'),'housing_pilot':{'only_one_before_review':True,'index_between_rocks':[index,index+1],'center_y':yc,'measured_gap':gap,'objects':housing,'pockets':pockets,'lower_crossmember_top_z':floor_top,'remaining_housing_interfaces':5},'pipette':{'module_source':str(module_root),'snapshot':str(snapshot),'module_sha256_before_after':module_hash,'requests':REQUESTS,'plans':PLANS,'builds':BUILDS,'endpoints':ENDPOINTS,'no_auto_bvh_route_claim':'All helix/Bezier anchors and keep-outs explicitly authored. Actual-mesh clearance is separately verified; P2 auto-routing is not claimed.','visible_line_inventory':{'converted_continuous_windings':2,'remaining_unconverted_windings':10,'remaining_axial_power_buses':2,'remaining_field_power_leads':24,'structural_ties_and_stabilizers':'Mechanical cast/tie members, not fluid/electrical line carriers','rock_fractures':'Actual recessed energized mineral faces, not wires'},'remaining':'This is a two-route/single-housing inspection pilot, not100%line or housing-family completion.'}})
(OUT/'source-contract.json').write_text(json.dumps(c,indent=2)+'\n')
for name in ('stacked-dish-reference.json','reference-feature-mapping.json','supplied-skull-reuse.json','ATTRIBUTION.txt','orphan-diagnosis.json'):shutil.copy2(OLD/name,OUT/name)
print('LOWERED_SINGLE_HOUSING_PIPETTE_PILOT_SAVED',len(surface),yc,gap,blend)
