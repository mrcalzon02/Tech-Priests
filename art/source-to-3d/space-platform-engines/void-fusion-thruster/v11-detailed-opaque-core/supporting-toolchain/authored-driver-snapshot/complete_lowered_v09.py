"""Bounded mandatory construction completion: lowered bay, six rock receivers,
actual Pipette continuous electrical routes and measured ring-lug fixtures.
No runtime install or animation. Shared Pipette modules remain untouched.
"""
import pathlib,sys
HERE=pathlib.Path(__file__).resolve().parent
# Reuse the reviewed lowered mount builder, stopping before its one-housing pilot.
exec(compile((HERE/'lowered_housing_pilot_v09.py').read_text().split('# ONE inter-bay housing')[0],str(HERE/'lowered_housing_pilot_v09.py'),'exec'))
sys.path.insert(0,str(HERE))
from pipette_power_terminal import build_power_terminal
module_root=ROOT/'tools/fmpl/pipette';snapshot=OUT/'pipette-source-snapshot';snapshot.mkdir(exist_ok=True)
module_hash={}
for name in ('core.py','blender_adapter.py','README.md','PIPETTE_STANDARD.md','library_fittings.py','library_geometry.py','architecture_catalog.v1.json'):
    module_hash[name]=sha(module_root/name);shutil.copy2(module_root/name,snapshot/name);assert sha(snapshot/name)==module_hash[name]
spec=importlib.util.spec_from_file_location('narrow_v09_pipette_adapter',snapshot/'blender_adapter.py');adapter=importlib.util.module_from_spec(spec);spec.loader.exec_module(adapter)
exec(compile((HERE/'lowered_housing_pilot_v09.py').read_text().split('def route_uv(o):')[1].split('REQUESTS=[]')[0].join(['def route_uv(o):','']),str(HERE/'lowered_housing_pilot_v09.py'),'exec'))
def vertices(o):return [o.matrix_world@v.co for v in o.data.vertices]
def patch(name,inside,outside,role):
    vv=[tuple(p) for p in inside+outside];ff=[]
    for a in (0,1,3,4):ff.extend([(a,a+1,a+4,a+3),(9+a,12+a,13+a,10+a)])
    edge=[0,1,2,5,8,7,6,3]
    for a,b in zip(edge,edge[1:]+edge[:1]):ff.append((a,b,b+9,a+9))
    return mesh(name,vv,ff,role)
def section(name,outline,ya,yb,role):
    n=len(outline);vv=[(x,y,z) for y in (ya,yb) for x,z in outline];ff=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    ff += [(j,(j+1)%n,(j+1)%n+n,j+n) for j in range(n)]
    return mesh(name,vv,ff,role)
HOUSINGS=[];centers=[];all_deleted=[]
for index in range(6):
    ra=bpy.data.objects[c['rock_bays'][index]['object']];rb=bpy.data.objects[c['rock_bays'][index+1]['object']]
    A=vertices(ra);B=vertices(rb);amax=max(p.y for p in A);bmin=min(p.y for p in B);gap=bmin-amax;assert gap>.035,(index,gap)
    yc=(amax+bmin)/2;centers.append(yc);half=min(.021,gap*.21);pad_t=min(.009,gap*.13);parts=[];pockets=[];prefix='V09 interface %02d '%index
    for rock,direction in ((ra,-1),(rb,1)):
        tr=tree(rock);pts=[]
        # A broad three-by-three pad must land on a real solid end fragment;
        # avoid spanning one of the authored through-fracture gaps.
        for cz in (.10,.055,.15):
            for cx in (-.075,.075,-.12,.12,0):
                probes=[tr.ray_cast(Vector((cx+dx,yc,cz+dz)),Vector((0,direction,0)),1.5)[0] for dz in (-.035,0,.035) for dx in (-.032,0,.032)]
                if all(p is not None for p in probes):pts=probes;break
            if pts:break
        assert len(pts)==9,(rock.name,'No connected actual end-face pocket patch')
        back=[p-Vector((0,direction*pad_t,0)) for p in pts]
        ceramic=patch(prefix+rock.name+' conforming ceramic pocket face',pts,back,'pad')
        center=[Vector((p.x,yc+direction*half,p.z)) for p in pts]
        copper=patch(prefix+rock.name+' shaped copper pocket carrier',back,center,'copper');parts += [ceramic.name,copper.name]
        for j in (0,2,4,6,8):seat(ceramic,rock,pts[j],(0,direction,0),'Actual ray-fitted rock-end receiving pocket; bounded ceramic layer, no guessed overlap')
        for j in (0,4,8):seat(copper,ceramic,back[j],(0,direction,0),'Copper pocket carrier actual fitted ceramic back face')
        pockets.append({'rock':rock.name,'ceramic':ceramic.name,'copper':copper.name,'pad_thickness':pad_t,'contact_points':[list(p) for p in pts]})
    # Chamfered split machine body, shaped shoulders, and actual rail-bearing ends.
    outline=[(-.145,-.055),(-.12,-.085),(.12,-.085),(.145,-.055),(.145,.175),(.12,.198),(-.12,.198),(-.145,.175)]
    body=section(prefix+'cast split receiver body',outline,yc-half,yc+half,'hull');parts.append(body.name)
    floor_top=min(min(p.z for p in A),min(p.z for p in B))-.015
    base=section(prefix+'chamfered load crossmember',[(-.40,-.27),(.40,-.27),(.40,floor_top-.012),(.37,floor_top),(-.37,floor_top),(-.40,floor_top-.012)],yc-.075,yc+.075,'rail');parts.append(base.name)
    stem=section(prefix+'receiver lower load neck',[(-.095,floor_top),(.095,floor_top),(.115,-.085),(-.115,-.085)],yc-half,yc+half,'hull');parts.append(stem.name)
    seat(stem,base,(0,yc,floor_top),(0,0,1),'Receiver neck lower cap bears on actual crossmember top')
    seat(stem,body,(0,yc,-.085),(0,0,1),'Receiver neck upper face meets cast body bottom')
    for side in (-1,1):
        # Shoulders bend OUTSIDE the stone pocket before returning to upper rails.
        poly=[(.235,floor_top),(.285,floor_top),(.285,.245),(.215,.3725),(.165,.3725),(.235,.225)]
        arm=section(prefix+'tapered cage shoulder '+str(side),[(side*x,z) for x,z in poly],yc-.018,yc+.018,'hull');parts.append(arm.name)
        seat(arm,base,(side*.26,yc,floor_top),(0,0,1),'Cast shoulder lower cap on crossmember')
        seat(arm,bpy.data.objects['V04 cage longitudinal crown rail '+str(side)],(side*.19,yc,.3725),(0,0,1),'Shaped upper shoulder bears on actual cage channel underside')
        seat(base,bpy.data.objects['Continuous structural keel '+str(side)],(side*.30,yc,-.27),(0,0,1),'Receiver crossmember underside on continuous cantilever crown')
    HOUSINGS.append({'between_rock_indices':[index,index+1],'center_y':yc,'measured_gap':gap,'objects':parts,'pockets':pockets,'crossmember_top_z':floor_top})

# Remove every disconnected old turn and replace all twelve windings, two axial
# buses and twenty-four field-web electrical traces with actual planned bodies.
relocated={}
for side in (-1,1):
    for i,yc in enumerate(centers):
        core=bpy.data.objects['Insulator %s %02d'%(side,i)];dy=yc-core.location.y
        for o in list(S.objects):
            if o.name.startswith('Winding %s %02d'%(side,i)):
                all_deleted.append(o.name);bpy.data.objects.remove(o,do_unlink=True)
            elif o.name.startswith(('Insulator %s %02d'%(side,i),'Coil collar %s %02d'%(side,i),'Coil support %s %02d'%(side,i))):o.location.y+=dy;relocated[o.name]=dy
for o in list(S.objects):
    if o.name.startswith('Sealed side conductor '):all_deleted.append(o.name);bpy.data.objects.remove(o,do_unlink=True)
surface[:]=[q for q in surface if q['a'] not in all_deleted and q['b'] not in all_deleted]
for q in surface:
    delta=relocated.get(q['a'],relocated.get(q['b'],0));q['point'][1]+=delta

REQUESTS=[];PLANS=[];BUILDS=[];FIXTURES=[];ENDPOINTS=[]
def terminal(parent,p,n,t,diam,prefix):
    f=build_power_terminal(parent,p,n,t,M['copper'],M['ceramic'],wire_diameter=diam,prefix=prefix)
    surface.extend(f['surface_contacts']);FIXTURES.append(f);return f
def socket(f,end,role):
    s=dict(f['wire_stop_socket']);s['role']=role;return s
def route(name,points,fa,fb,diam,keepouts,kind):
    # Real conductor extends inside the open fixture bore to the measured stop;
    # wire entry and mount backface deliberately remain separate datums.
    req={'id':name,'family':'single_wire','payload':'power','size':{'outer_diameter':diam,'wall_fraction':0},'material_id':M['copper'].name,'path':{'kind':'waypoints','points':[list(p) for p in points]},'start_socket':socket(fa,'start','source'),'end_socket':socket(fb,'end','sink'),'fittings':{'start':'none','end':'none'},'keep_outs':keepouts}
    # Prototype adapter delegates the actual, separately built compatible lug
    # fixtures. Its explicit flag suppresses duplicate generic toroidal eyes;
    # this is NOT an assertion that these visibly terminated lines are open.
    req['allow_unterminated']=True
    req['asset_external_fixtures']=[fa['conductor_object'],fb['conductor_object']]
    plan=adapter.core.plan(req);col,objects=adapter.build(plan,M['copper'],M['bronze'])
    for o in objects:route_uv(o)
    body=next(o for o in objects if o.get('pipette_geometry_role')=='continuous-route')
    for end,f in (('start',fa),('end',fb)):
        s=f['wire_stop_socket'];seat(body,bpy.data.objects[f['conductor_object']],s['xyz'],s['normal'],'Actual conductor end cap seats on ring-lug bore insertion stop')
        ENDPOINTS.append({'route':name,'end':end,'body':body.name,'fixture':f['conductor_object'],'stop':s,'entry':f['wire_entry_socket'],'wire_diameter':diam})
    REQUESTS.append(req);PLANS.append(plan);BUILDS.append({'route':name,'body':body.name,'objects':[o.name for o in objects],'kind':kind,'actual_builder':'Pinned Pipette core.plan + blender_adapter.build; separately actual compatible library_fittings ring_lug','uv':'Physical arc-length/circumferential route UV; actual planar fitting UV'})
    print('PIPETTE_ROUTE_BUILT',len(REQUESTS),name,flush=True)
def bezier(a,b,cc,d,n=10):return [a*(1-t)**3+b*3*(1-t)**2*t+cc*3*(1-t)*t*t+d*t**3 for t in (i/n for i in range(n+1))]
def lead_from_fixture(f,target,tangent):
    stop=Vector(f['wire_stop_socket']['xyz']);entry=Vector(f['wire_entry_socket']['xyz']);t=Vector(f['wire_entry_socket']['normal']);out=entry+t*.012
    return [stop,entry,out]+bezier(out,out+t*.025,target-tangent*.025,target)[1:]
def curved_pad(parent,p,n,span,prefix):
    n=Vector(n).normalized();u=Vector((1,0,0)) if abs(n.x)<.8 else Vector((0,1,0));u=(u-n*u.dot(n)).normalized();v=n.cross(u);tr=tree(parent);inside=[]
    for j in (-1,0,1):
        for i in (-1,0,1):
            q=Vector(p)+u*i*span+v*j*span;hit=tr.ray_cast(q+n*.15,-n,.30)[0];assert hit is not None,(prefix,i,j);inside.append(hit)
    offset=max((q-Vector(p)).dot(n) for q in inside)+.008
    outside=[Vector(p)+u*((q-Vector(p)).dot(u))+v*((q-Vector(p)).dot(v))+n*offset for q in inside]
    pad=patch(prefix+' fitted terminal receiving pad',inside,outside,'bronze')
    for j in (0,2,4,6,8):seat(pad,parent,inside[j],n,'Actual ray-fitted electrical mounting pad underside on named parent surface')
    return pad,Vector(p)+n*offset

for i,yc in enumerate(centers):
    for side in (-1,1):
        axis_x=side*.345;axis_z=.10;ff=[];diam=.014
        for label,sign in (('start',-1),('end',1)):
            collar=min([o for o in S.objects if o.name.startswith('Coil collar %s %02d'%(side,i))],key=lambda o:abs(o.location.y-(yc+sign*.19)))
            pad,p=curved_pad(collar,(axis_x,collar.location.y,axis_z+.08),(0,0,1),.023,'V09 coil %s %02d %s'%(side,i,label))
            ff.append(terminal(pad,p,(0,0,1),(0,-sign,0),diam,'V09 coil %s %02d %s lug'%(side,i,label)))
        N=144;R=.079;turns=6
        helix=[Vector((axis_x+R*math.cos(math.pi/2+math.tau*turns*j/N),yc-.132+.264*j/N,axis_z+R*math.sin(math.pi/2+math.tau*turns*j/N))) for j in range(N+1)]
        tangent=Vector((-R,.264/(math.tau*turns),0)).normalized()
        points=lead_from_fixture(ff[0],helix[0],tangent)[:-1]+helix+list(reversed(lead_from_fixture(ff[1],helix[-1],-tangent)))[1:]
        route('narrow-coil-%s-%02d'%(side,i),points,*ff,diam,[{'id':'protected-mineral-interior','min':[-.20,yc-.60,-.10],'max':[.20,yc+.60,.28]},{'id':'upper-channel','min':[-.23,yc-.50,.36],'max':[.23,yc+.50,.45]}],'continuous-six-turn-power-winding')
        if '--one-route-test' in sys.argv:
            (OUT/'one-route-result.json').write_text(json.dumps({'fixtures':FIXTURES,'routes':BUILDS},indent=2));print('ONE_ROUTE_TEST_PASS');sys.exit(0)

# Two axial power buses terminate in actual retained end-receiver cases. They
# pass through existing insulating cores, rather than ending near free air.
for side in (-1,1):
    x=side*.345;ff=[]
    for label,y,sign in (('aft',-3.32,1),('fore',3.78,-1)):
        parent=box('V09 '+label+' bus receiver '+str(side),(x-.045,y-.065,-.27),(x+.045,y+.065,.13),'hull')
        seat(parent,bpy.data.objects['Continuous structural keel '+str(side)],(side*.30,y,-.27),(0,0,1),'Power bus end receiver actual bottom on keel crown')
        # Vertical pad on receiver end face, mate normal faces along the bus.
        plane=y+sign*.065;p=Vector((x,plane,.10));ff.append(terminal(parent,p,(0,sign,0),(0,0,1),.020,'V09 '+label+' axial bus lug '+str(side)))
    a=Vector(ff[0]['wire_stop_socket']['xyz']);ae=Vector(ff[0]['wire_entry_socket']['xyz']);b=Vector(ff[1]['wire_stop_socket']['xyz']);be=Vector(ff[1]['wire_entry_socket']['xyz'])
    # A routed outer axial bus stays outboard of mineral; explicitly authored
    # receiver tangency elbows bridge to the existing insulator center line.
    pa=Vector((x,ae.y+.24,.10));pb=Vector((x,be.y-.24,.10))
    points=lead_from_fixture(ff[0],pa,Vector((0,1,0)))+list(reversed(lead_from_fixture(ff[1],pb,Vector((0,-1,0)))))
    route('narrow-axial-power-bus-'+str(side),points,*ff,.020,[],'axial-power-bus')

# Actual field-web lead inventory. Existing recessed tracks become dark cast
# channels and receive small continuous typed conductors with retained ends.
for record in c['authored_refinement']['cast_webs']:
    web=bpy.data.objects[record['web']];vv=vertices(web);angle=math.atan2(sum(p.z-.06 for p in vv),sum(p.x for p in vv));rad=Vector((math.cos(angle),0,math.sin(angle)));tan=Vector((-rad.z,0,rad.x));rr=[(p-Vector((0,0,.06))).dot(rad) for p in vv];r0=min(rr)+.023;r1=max(rr)-.023;assert r1-r0>.025,(web.name,r0,r1)
    y0=min(p.y for p in vv);ff=[]
    for label,r,sgn in (('root',r0,1),('rim',r1,-1)):
        p=Vector((rad.x*r,y0,.06+rad.z*r));pad,p=curved_pad(web,p,(0,-1,0),.0056,'V09 '+web.name+' '+label)
        ff.append(terminal(pad,p,(0,-1,0),rad*sgn,.004,'V09 '+web.name+' '+label+' lug'))
    a=Vector(ff[0]['wire_stop_socket']['xyz']);ae=Vector(ff[0]['wire_entry_socket']['xyz']);b=Vector(ff[1]['wire_stop_socket']['xyz']);be=Vector(ff[1]['wire_entry_socket']['xyz']);points=[a,ae,ae+rad*.007]
    for j in range(1,6):
        r=r0+(r1-r0)*j/6;q=Vector((rad.x*r,y0-1,.06+rad.z*r));hit=tree(web).ray_cast(q,Vector((0,1,0)),2)[0];assert hit is not None;points.append(hit+Vector((0,-.016,0)))
    points += [be-rad*.007,be,b]
    route('narrow-field-lead-'+web.name.replace(' ','-'),points,*ff,.004,[],'dish-field-power-lead')
    if len(web.data.materials)>1:web.data.materials[1]=M['hull']

for name,digest in module_hash.items():assert sha(module_root/name)==digest,('Shared Pipette source changed during actual calls',name)
inventory=[e for e in c['finish_repair']['actual_receiver_inventory'] if e['object'] not in removed]
for name in mount_objects:
    if 'captive bolt' in name:
        rows=[q for q in surface if q['a']==name];inventory.append({'object':name,'actual_receivers':[q['b'] for q in rows],'tight_surface_records':len(rows)})
c['finish_repair']['actual_receiver_inventory']=inventory;c['finish_repair']['remaining_named_fastener_receiver_count']=len(inventory)
c.update({'revision':'V09 lowered U-bay, six fitted inter-stone machine housings and complete typed Pipette electrical-line construction','contacts':[q for q in contacts if q['a'] not in all_deleted and q['b'] not in all_deleted],'surface_contacts':surface,'hanging_mount':dict(c['hanging_mount'],intended_foundation_objects=foundations,removed_old_plinths=removed,body_vertical_translation=-DROP,mount_objects=mount_objects,opening_half_width=.50,opening_fore_end_y=4.20,authorized_mount_half_width=.72,platform_contacts=platform_contacts,source_edge_anchor='mount_deck_edge_center'),'interstone_housings':HOUSINGS,'pipette':{'module_source':str(module_root),'snapshot':str(snapshot),'module_sha256_before_after':module_hash,'requests':REQUESTS,'plans':PLANS,'builds':BUILDS,'fixtures':FIXTURES,'endpoints':ENDPOINTS,'removed_old_line_objects':all_deleted,'no_auto_bvh_route_claim':'All helix/Bezier/field anchors and keep-outs explicitly authored; actual-mesh validation is separate. No P2 automatic routing claim.','visible_line_inventory':{'continuous_windings':12,'axial_power_buses':2,'field_power_leads':24,'structural_ties':'Mechanical members, not wires','rock_fractures':'Recessed mineral faces, not wires'},'technical_status':'Construction complete; independent source/export/seat/route validation pending'}})
S['candidate_stage']='V09_MANDATORY_CONSTRUCTION_COMPLETE_INDEPENDENT_VALIDATION_PENDING'
for im in bpy.data.images:
    if im.source=='FILE' and not im.packed_file:im.pack()
bpy.ops.object.select_all(action='DESELECT')
for o in S.objects:
    if o.type in ('MESH','EMPTY'):o.select_set(True)
blend=OUT/'void-fusion-v09.blend';glb=OUT/'void-fusion-v09.glb';bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=True);bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_extras=True)
c.update({'blend_sha256':sha(blend),'glb_sha256':sha(glb)})
(OUT/'source-contract.json').write_text(json.dumps(c,indent=2)+'\n')
for name in ('stacked-dish-reference.json','reference-feature-mapping.json','supplied-skull-reuse.json','ATTRIBUTION.txt','orphan-diagnosis.json'):shutil.copy2(OLD/name,OUT/name)
print('NARROW_V09_CONSTRUCTION_SAVED',len(REQUESTS),len(FIXTURES),len(surface),glb,flush=True)

