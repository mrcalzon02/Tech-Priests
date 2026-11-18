"""Second inspected repair: unique black mineral, cast dish webs and retained hub."""
import bpy,math,json,pathlib,sys,hashlib,runpy,shutil
from mathutils import Vector
ROOT=pathlib.Path(__file__).resolve().parents[3]
OUT=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve();OUT.mkdir(parents=True,exist_ok=True)
assert not (OUT/'void-fusion-v07.blend').exists()
PASS1=ROOT/'build/thruster-resume-20261117/void-fusion-v06b'
assert (PASS1/'render-receipt.json').exists(),'Inspect first export before this second repair'
helper=pathlib.Path(__file__).with_name('refine_authored_v06.py');saved_args=sys.argv[:]
sys.argv=[str(helper),'--',str(OUT/'body-construction'),'--pass2'];ctx=runpy.run_path(str(helper));sys.argv=saved_args
S=bpy.context.scene;M=ctx['M'];mesh=ctx['mesh'];rod=ctx['rod'];seat=ctx['seat'];tree=ctx['tree'];replace=ctx['replace'];surface=ctx['surface'];contacts=ctx['contacts'];sha=ctx['sha']
M['green']=bpy.data.materials['Noctilith energized fracture Necron green'];M['fracture']=bpy.data.materials['V06 recessed energized noctilith cleavage']
contract=json.loads((OUT/'body-construction/source-contract.json').read_text())
removed=[]
for o in list(S.objects):
    if o.name.startswith('V05 tier') and ('radial brace' in o.name or 'green field trace' in o.name) or o.name.startswith(('V05 central projecting','V05 field tip energized','V05 central green focal')):
        removed.append(o.name);bpy.data.objects.remove(o,do_unlink=True)
surface[:]=[c for c in surface if c['a'] not in removed and c['b'] not in removed]
contacts[:]=[c for c in contacts if c['a'] not in removed and c['b'] not in removed]

# Deliberately mitred, closed beam heels terminate into the actual head carrier.
# Retain all exact flat crown contact planes used by the supported cage roots.
for side in (-1,1):
    old=bpy.data.objects['Continuous structural keel '+str(side)]
    pp=[(.25,.09),(.35,.09),(.35,.18),(.25,.18),(.25,.1593),(.326,.1593),(.326,.1107),(.25,.1107)]
    if side<0:pp=[(-x,z) for x,z in pp]
    vv=[(x,-3.74+1.4*(z-.09),z) for x,z in pp]+[(x,4.15,z) for x,z in pp];n=len(pp)
    ff=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(j,(j+1)%n,(j+1)%n+n,j+n) for j in range(n)]
    replace(old,mesh('new mitred heel',vv,ff,'rail'))
    # Solid closing cap around the fore channel end, not an exposed raw cutoff.
    x=side*.30;vv=[(x+dx,y,z) for y in (4.145,4.18) for dx,z in ((-.05,.09),(.05,.09),(.05,.18),(-.05,.18))]
    mesh('V07 fore channel closed forged termination '+str(side),vv,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],'hull')
    old=bpy.data.objects['V05 grounded dish stack support '+str(side)]
    # Cast, flared root gusset replaces the simple cylindrical support rod.
    vv=[]
    for y in (-3.615,-3.545):vv.extend([(side*.255,y,.18),(side*.345,y,.18),(side*.252,y,.78),(side*.193,y,.78),(side*.215,y,.68),(side*.276,y,.25)])
    ff=[tuple(reversed(range(6))),tuple(range(6,12))]+[(j,(j+1)%6,(j+1)%6+6,j+6) for j in range(6)]
    replace(old,mesh('new cast head support',vv,ff,'rail'))

# Replace rectangular fore foundation blocks with shaped tapered cast clamp shoes.
for old in [o for o in S.objects if o.name.startswith('V02 mount') and 'ground sole' in o.name]:
    y=old.location.y;top=[(-.38,-.135),(.38,-.135),(.43,-.085),(.43,.085),(.38,.135),(-.38,.135),(-.43,.085),(-.43,-.085)]
    vv=[(x*.94,y+yy*.94,0) for x,yy in top]+[(x,y+yy,.09) for x,yy in top]
    ff=[tuple(reversed(range(8))),tuple(range(8,16))]+[(j,(j+1)%8,(j+1)%8+8,j+8) for j in range(8)]
    replace(old,mesh('new fore deck shoe',vv,ff,'rail'))

WEB_RECORD=[]
for i,stage in enumerate(contract['stacked_dish_reference']['actual_tiers']):
    dish=bpy.data.objects[stage['object']];tr=tree(dish);R=stage['outer_radius'];ri=stage['inner_radius'];center=stage['center_y']
    for j in range(8):
        a=j*math.tau/8;radial=Vector((math.cos(a),0,math.sin(a)));tangent=Vector((-math.sin(a),0,math.cos(a)))
        vv=[];bases=[];N=5
        for k in range(N):
            t=k/(N-1);r=ri+.015+(R*.84-ri-.015)*t;w=.020*(1-t)+.010*t;h=.030*(1-t)+.015*t
            p=Vector((0,0,.51))+radial*r;ends=[]
            for sign in (-1,1):
                q=p+tangent*w*sign;hit=tr.ray_cast(Vector((q.x,center-.30,q.z)),Vector((0,1,0)),.6)[0];assert hit is not None
                ends.append(hit)
            L,RR=ends;ym=(L.y+RR.y)/2-h
            # Actual receiving face, flared cast upper section and recessed
            # energy channel with integral dark walls, not neon on a cylinder.
            at=lambda off,yy:tuple(Vector((p.x,yy,p.z))+tangent*off)
            vv.extend([tuple(L),tuple(RR),(RR.x,RR.y-h,RR.z),at(w*.28,ym),at(w*.28,ym+.003),at(-w*.28,ym+.003),at(-w*.28,ym),(L.x,L.y-h,L.z)])
            bases.append((L,RR))
        ff=[];mi=[]
        for k in range(N-1):
            for q in range(8):ff.append((k*8+q,k*8+(q+1)%8,(k+1)*8+(q+1)%8,(k+1)*8+q));mi.append(1 if q==4 else 0)
        ff.extend([tuple(reversed(range(8))),tuple(range((N-1)*8,N*8))]);mi.extend((0,0))
        web=mesh('V07 tier%02d flared cast radial web%02d'%(i,j),vv,ff,'bands',[M['bands'],M['green']],mi)
        for k in (0,2,4):
            for p in bases[k]:seat(web,dish,p,(0,1,0),'Actual flared web receiving face ray-fitted to current dished plate triangles')
        WEB_RECORD.append({'web':web.name,'dish':dish.name,'flared_root_width':.040,'outer_width':.020,'root_height':.030,'outer_height':.015,'recessed_field_channel_depth':.003})

# A real retained ceramic carrier/socket shoulder surrounds the projection.
# Closed curved rear flange mates the final dish, with four distinct fingers.
last=contract['stacked_dish_reference']['actual_tiers'][-1];dish=bpy.data.objects[last['object']];tr=tree(dish);N=48;radii=(.062,.082,.108);vv=[];rear_points=[]
for front in (False,True):
    for r in radii:
        for j in range(N):
            a=j*math.tau/N;x=r*math.cos(a);z=.51+r*math.sin(a);hit=tr.ray_cast(Vector((x,-4.5,z)),Vector((0,1,0)),.6)[0];assert hit is not None
            rear_points.append(hit) if not front else None
            vv.append((x,hit.y-(.026 if front else 0),z))
layer=3*N;ff=[]
for side in (0,1):
    for k in range(2):
        for j in range(N):a=side*layer+k*N+j;b=side*layer+k*N+(j+1)%N;ff.append((a,b,b+N,a+N))
for k in (0,2):
    for j in range(N):a=k*N+j;b=k*N+(j+1)%N;ff.append((a,a+layer,b+layer,b))
flange=mesh('V07 retained electrode curved root flange',vv,ff,'hull')
for j in range(0,len(rear_points),12):seat(flange,dish,rear_points[j],(0,1,0),'Actual retained carrier flange receiving face conforms to final dish front')
def sector(name,r0,r1,y0,y1,a0,a1,mat,n=6):
    vv=[]
    for y in (y0,y1):
        for r in (r0,r1):
            for j in range(n+1):a=a0+(a1-a0)*j/n;vv.append((r*math.cos(a),y,.51+r*math.sin(a)))
    w=n+1;ff=[]
    for j in range(n):ff.extend([(j,j+1,w+j+1,w+j),(2*w+j,3*w+j,3*w+j+1,2*w+j+1),(j,2*w+j,2*w+j+1,j+1),(w+j,w+j+1,3*w+j+1,3*w+j)])
    ff.extend([(0,w,3*w,2*w),(w-1,3*w-1,4*w-1,2*w-1)])
    return mesh(name,vv,ff,mat)
sleeve=sector('V07 retained hollow ceramic focusing sleeve',.0455,.055,-4.278,-4.19,0,math.tau,'ceramic',48)
for j in range(4):
    a=j*math.pi/2+.2;r=.067;hit=tree(flange).ray_cast(Vector((r*math.cos(a),-4.4,.51+r*math.sin(a))),Vector((0,1,0)),.4)[0];assert hit is not None
    finger=sector('V07 carrier cast gripping finger%02d'%j,.054,.083,-4.278,hit.y,a-.30,a+.30,'hull')
    seat(finger,flange,hit,(0,1,0),'Cast carrier finger rear axial face meets actual root flange front')
    p=Vector((.055*math.cos(a),-4.23,.51+.055*math.sin(a)))
    surface.append({'a':finger.name,'b':sleeve.name,'point':list(p),'normal':[math.cos(a),0,math.sin(a)],'tolerance':.00101,'reason':'Explicit .001-unit cast-finger bite into actual ceramic outer cylindrical seat; bounded retaining fit'})
core=rod('V07 ceramic-contained energized focal core',(0,-4.195,.51),(0,-4.275,.51),.039,'green')
# Projecting reference tip is now carried by the ceramic bore, with stem,
# octagonal shoulder and separate faceted point; the root is no longer loose.
verts=[];n=8
for y,r in ((-4.265,.043),(-4.295,.043),(-4.315,.060)):
    for j in range(n):a=j*math.tau/n;verts.append((r*math.cos(a),y,.51+r*math.sin(a)))
verts.append((0,-4.425,.51));faces=[tuple(reversed(range(n)))]
for k in range(2):
    for j in range(n):faces.append((k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j))
for j in range(n):faces.append((2*n+j,2*n+(j+1)%n,3*n))
mesh('V07 retained stem shoulder and projecting faceted emitter',verts,faces,'bands')

for name,pos in [('mount_deck_edge_center',(0,0,0)),('mount_deck_edge_west',(-.45,0,0)),('mount_deck_edge_east',(.45,0,0)),('mount_fore_direction',(0,1,0))]:
    ob=bpy.data.objects.new(name,None);S.collection.objects.link(ob);ob.location=pos;ob.empty_display_size=.12
S['candidate_stage']='V07_SECOND_VISUAL_REPAIR_UNIQUE_MINERAL_CAST_WEBS_RETAINED_CARRIER_HALF_HANGER'
S['native_grid_registration']='Source deckedgeY0 must be camera/shift-fitted to legal narrow native localY+.5 split; no1to1 coordinate claim.'
for im in bpy.data.images:
    if im.source=='FILE' and not im.packed_file:im.pack()
bpy.ops.object.select_all(action='DESELECT')
for o in S.objects:
    if o.type in ('MESH','EMPTY'):o.select_set(True)
blend=OUT/'void-fusion-v07.blend';glb=OUT/'void-fusion-v07.glb'
bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=True)
bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_extras=True)
contract.update({'revision':'V07 second inspected repair: unique rough mineral, cast dish webs, retained ceramic carrier and mitred heels','blend_sha256':sha(blend),'glb_sha256':sha(glb),'contacts':contacts,'surface_contacts':surface,'inspection_input':{'pass1_directory':str(PASS1),'pass1_source_sha256':sha(PASS1/'void-fusion-v06.blend'),'pass1_glb_sha256':sha(PASS1/'void-fusion-v06.glb'),'pass1_render_receipt_sha256':sha(PASS1/'render-receipt.json'),'observed_defects':['Mineral too smooth, gray and repetitive','Dish spokes/simple cone root still primitive','Channel heels abruptly cut off at emitter'],'repairs':['Darker nonmetal high-roughness mineral with unique oblique/chipped roofs and different faults','Cast/tapered dish webs with fitted roots and integral recessed field channels','Actual dish-seated carrier flange, four gripping fingers, hollow ceramic sleeve and shouldered tip stem','Mitred closed channel heels, formed head-load gussets and tapered fore deck shoes']},'authored_refinement':dict(contract['authored_refinement'],pass_number=2,cast_webs=WEB_RECORD),'hanging_mount':dict(contract['hanging_mount'],source_edge_anchor='mount_deck_edge_center',source_edge_span_anchors=['mount_deck_edge_west','mount_deck_edge_east'],legal_native_narrow_cut_y=.5,registration='Fit sourceedgeY0 to native+.5 using measured camera/shift; geometry remains roughly50%hang. Native quantization is not physical source proportion.'),'carrier_clearances':{'ceramic_bore_radius':.0455,'focal_core_radius':.039,'core_radial_clearance':.0065,'tip_root_radius':.043,'tip_root_radial_clearance':.0025,'scope':'Source-designed concentric static radial gap; independently inspect actual GLB geometry and mounting.'}})
(OUT/'source-contract.json').write_text(json.dumps(contract,indent=2)+'\n')
for name in ('stacked-dish-reference.json','reference-feature-mapping.json','supplied-skull-reuse.json','ATTRIBUTION.txt'):shutil.copy2(OUT/'body-construction'/name,OUT/name)
print('V07_SECOND_VISUAL_REPAIR_SAVED',len(surface),blend)
