"""Advanced: intact accepted Basic module plus adjacent cargo door and large crane."""
import bpy,json,math,sys,hashlib
from pathlib import Path
from mathutils import Vector,Matrix
R=Path(__file__).resolve().parents[3];B=R/'art/source-to-3d/space-cargo-inventories/v01/basic';O=B.parent/'advanced';source=B/'basic-space-cargo-v01.blend';bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene;basic=bpy.data.objects['Basic Cargo | grade origin'];contacts=json.loads((B/'contacts.json').read_text());mats={}
for ob in list(s.objects):
 if ob.type=='MESH' and ob.get('fmpl_render_only'):bpy.data.objects.remove(ob,do_unlink=True)
for ob in s.objects:
 if ob.type!='MESH' or not ob.data.materials:continue
 mat=ob.data.materials[0];role=mat.get('cargo_role')
 if role and role not in mats:mats[role]=mat.copy();mats[role].name='Advanced adjunct | '+role
root=bpy.data.objects.new('Advanced Cargo | grade origin',None);s.collection.objects.link(root);basic.parent=root;basic.scale=(.8,.8,.8);basic.location=(0,-1.468,0);basic.name='Advanced | intact Basic three-window module'
col=bpy.data.collections.new('ADVANCED ADDITIONS | cargo door, subframe and overhanging crane');s.collection.children.link(col)
def joint(a,b,why):contacts.append(dict(a=a.name if hasattr(a,'name') else a,b=b.name if hasattr(b,'name') else b,why=why))
def finish(ob,name,role,bevel=.012,below=False):
 ob.name='Advanced | '+name;ob.parent=root
 for c in list(ob.users_collection):c.objects.unlink(ob)
 col.objects.link(ob);ob.data.materials.clear();ob.data.materials.append(mats[role]);bpy.context.view_layer.objects.active=ob
 if bevel:
  mod=ob.modifiers.new('Formed production edge radius','BEVEL');mod.width=bevel;mod.segments=4;bpy.ops.object.modifier_apply(modifier=mod.name)
 if not ob.data.uv_layers:ob.data.uv_layers.new(name='Advanced physical UV')
 bpy.context.view_layer.update()
 for face in ob.data.polygons:
  axis=max(range(3),key=lambda k:abs(face.normal[k]));axes=[k for k in range(3) if k!=axis]
  for li in face.loop_indices:
   p=ob.matrix_world@ob.data.vertices[ob.data.loops[li].vertex_index].co;ob.data.uv_layers.active.data[li].uv=(p[axes[0]]*1.25+.5,p[axes[1]]*1.25+.5)
 ob['below_grade_geometry']=below;return ob
def box(name,p,size,role='deck-steel',bevel=.015,below=False):
 bpy.ops.mesh.primitive_cube_add(size=1,location=p);ob=bpy.context.object;ob.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return finish(ob,name,role,min(bevel,min(size)*.2),below)
def cyl(name,p,r,depth,role='aged-brass',axis='Z',below=False):
 bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=r,depth=depth,location=p);ob=bpy.context.object
 if axis=='X':ob.rotation_euler.y=math.pi/2
 if axis=='Y':ob.rotation_euler.x=math.pi/2
 bpy.ops.object.transform_apply(location=False,rotation=True,scale=True);ob=finish(ob,name,role,min(.008,depth*.15),below)
 for f in ob.data.polygons:f.use_smooth=len(f.vertices)==4
 return ob
def beam(name,a,b,width=.055,depth=.055,role='structure',below=True):
 a=Vector(a);b=Vector(b);ob=box(name,(a+b)/2,(width,depth,(b-a).length),role,.008,below);ob.rotation_mode='QUATERNION';ob.rotation_quaternion=(b-a).to_track_quat('Z','Y');return ob
def clone(ob,shift,suffix):
 n=ob.copy();n.data=ob.data.copy();col.objects.link(n);n.name='Advanced reuse | '+ob.name+' | '+suffix;n.parent=root;n.matrix_world=Matrix.Translation(Vector(shift))@ob.matrix_world
 if n.data.materials:
  mat=n.data.materials[0];role=mat.get('cargo_role')
  if role in mats:n.data.materials[0]=mats[role]
  if 'packed directional FMPL cedar' in mat.name:n.data.materials[0]=mats['timber']
 return n

base_manifest=json.loads((B/'occlusion.json').read_text());manifest=dict(schema=base_manifest['schema'],grade_z=0,model_bounds=[[-2.46,-2.46,-1.20],[2.46,2.46,2.25]],bearing_objects=list(base_manifest['bearing_objects']),apertures=[dict(id=p['id'],xmin=p['xmin']*.8,xmax=p['xmax']*.8,ymin=p['ymin']*.8-1.468,ymax=p['ymax']*.8-1.468) for p in base_manifest['apertures']],environment_half_extent=40,mask_edge_allowance_pixels=1)
# Only the newly added aft platform is generated; Basic mesh topology/UVs remain intact.
frame={}
for name,point,size in [('aft left bearing rail',(-2.23,.816,.05),(.46,2.608,.10)),('aft right bearing rail',(2.23,.816,.05),(.46,2.608,.10)),('aft rear bearing rail',(0,2.29,.05),(4.92,.34,.10)),('module joining bridge',(0,-.393,.045),(4.92,.19,.09))]:
 ob=box(name,point,size);frame[name]=ob;manifest['bearing_objects'].append(ob.name)
joint(frame['module joining bridge'],'Cargo | rear grade-bearing deck rail','new service deck joins the rear edge of the complete Basic module')
for name in ('aft left bearing rail','aft right bearing rail'):joint(frame[name],frame['aft rear bearing rail'],'continuous aft frame carries doorway and crane loads')
for side in (-1,1):
 extension=box('square footprint front-side girder %d'%side,(side*2.406,-1.428,.035),(.108,1.880,.070),'structure',.010);manifest['bearing_objects'].append(extension.name);joint(extension,frame['aft left bearing rail'] if side<0 else frame['aft right bearing rail'],'square outer frame joins aft rails alongside intact Basic module')
frontcap=box('square footprint front perimeter',(0,-2.414,.035),(4.92,.092,.070),'structure',.010);manifest['bearing_objects'].append(frontcap.name)
# Huge closed two-leaf cargo door opens into an actual opaque boxed subframe shaft.
xmin,xmax=-2.00,.88;ymin,ymax=-.19,2.13;cx=(xmin+xmax)/2;cy=(ymin+ymax)/2
manifest['apertures'].append(dict(id='cargo-door-shaft',xmin=xmin,xmax=xmax,ymin=ymin,ymax=ymax))
shaft_floor=box('cargo door sealed shaft floor',(cx,cy,-1.155),(3.08,2.54,.09),'well-liner',.010,True)
for label,y in [('front',ymin-.045),('rear',ymax+.045)]:
 wall=box('cargo shaft '+label+' load wall',(cx,y,-.555),(3.08,.09,1.11),'well-liner',.010,True);joint(wall,shaft_floor,'real below-deck shaft closed by opaque load walls')
for label,x in [('left',xmin-.045),('right',xmax+.045)]:
 wall=box('cargo shaft '+label+' load wall',(x,cy,-.555),(.09,2.54,1.11),'well-liner',.010,True);joint(wall,shaft_floor,'real below-deck shaft side wall carries frame')
for label,p,size,host in [('front',(cx,ymin-.075,.045),(3.18,.15,.09),'module joining bridge'),('rear',(cx,ymax+.075,.045),(3.18,.15,.09),'aft rear bearing rail'),('left',(xmin-.075,cy,.045),(.15,2.32,.09),'aft left bearing rail'),('right',(xmax+.075,cy,.045),(.15,2.32,.09),None)]:
 rim=box('cargo doorway '+label+' receiving frame',p,size,'structure',.012);joint(rim,frame[host] if host else bpy.data.objects['Advanced | cargo shaft right load wall'],'door frame carried by platform/subframe wall')
# Frame and door leaves are intentionally stepped; no coincident cover faces.
leaves=[]
for side in (-1,1):
 lx=cx+side*.72;leaf=box('cargo door '+('left' if side<0 else 'right')+' thick leaf',(lx,cy,.058),(1.425,2.30,.070),'structure',.020);leaf['cargo_door_leaf']=True;leaves.append(leaf)
 panel=box('cargo door recessed panel %d'%side,(lx,cy,.102),(1.22,2.06,.028),'cargo-green',.025);joint(panel,leaf,'recessed service panel seated in heavy leaf');panel['cargo_door_leaf']=True
 for y in (cy-1.01,cy+1.01):
  rib=box('cargo door leaf %d forged edge rib %.2f'%(side,y),(lx,y,.124),(1.20,.075,.045),'deck-steel',.012);joint(rib,panel,'load rib seated across leaf panel');rib['cargo_door_leaf']=True
 # Three broad pin hinges on each outer edge; sockets meet the receiving frame.
 hx=xmin+.04 if side<0 else xmax-.04
 for index,y in enumerate((cy-.88,cy,cy+.88)):
  ear=box('cargo hinge %d %d anchored ear'%(side,index),(hx,y,.12),(.20,.18,.08),'structure',.014);joint(ear,leaf,'hinge ear fixed to actual leaf edge')
  pin=cyl('cargo hinge %d %d retained pin'%(side,index),(hx,y,.16),.045,.23,'aged-brass','Y');joint(pin,ear,'pin captured by hinge ear; folded static closed door')
 for y in (cy-.29,cy+.29):
  pad=box('cargo door lock guide %d %.2f'%(side,y),(cx+side*.17,y,.13),(.20,.13,.07),'deck-steel',.012);joint(pad,leaf,'sliding bolt guide fixed to leaf')
  bolt=cyl('cargo door closed locking bolt %d %.2f'%(side,y),(cx+side*.16,y,.17),.026,.31,'aged-brass','X');joint(bolt,pad,'captured closed locking bar joins leaf guides')
 # Captive rivets follow the actual leaf perimeter.
 for xx in (lx-.58,lx+.58):
  for yy in (cy-.91,cy+.91):
   cap=cyl('cargo door captive stud %.2f %.2f'%(xx,yy),(xx,yy,.133),.024,.025);joint(cap,panel,'fastener captured in panel perimeter')
# Additional right-hand service deck carries the crane without replacing Basic.
service=box('crane service deck',(1.515,.911,.05),(.97,2.418,.10),'deck-steel',.02);manifest['bearing_objects'].append(service.name);joint(service,frame['aft right bearing rail'],'crane deck founded on the aft side rail')
foot=box('large crane founded pedestal',(1.65,-.08,.18),(.72,.68,.20),'structure',.04);joint(foot,service,'wide crane pedestal bolted to grounded service deck')
for x in (1.39,1.91):
 for y in (-.31,.15):
  stud=cyl('large crane pedestal captive stud %.2f %.2f'%(x,y),(x,y,.292),.042,.045);joint(stud,foot,'load stud seated in pedestal corner')
column=cyl('large crane slewing journal',(1.65,-.08,.39),.22,.32,'structure');joint(column,foot,'slewing journal seated in founded pedestal')
# One vertical articulation plane through the shoulder and jib tip.
crane_horizontal=Vector((-3.08,1.08,0)).normalized();crane_axis=crane_horizontal.cross(Vector((0,0,1))).normalized()
# Supported shoulder and elbow journals; the crane is deliberately large and overhanging.
shoulder=Vector((1.65,-.08,.61));elbow=Vector((.8492,.2008,1.90));tip=Vector((-1.43,1.00,2.05))
for label,pnt,r in [('shoulder',shoulder,.22),('elbow',elbow,.18),('tip',tip,.13)]:
 hub=cyl('large crane '+label+' closed journal',pnt,r,.36,'structure','Y')
 cap=cyl('large crane '+label+' pin cap',(pnt.x,pnt.y-.20,pnt.z),r*.70,.075,'aged-brass','Y');joint(cap,hub,'journal cap seated over captive transverse pin')
 if label=='shoulder':joint(hub,column,'shoulder carried by slewing column')
for label,a,b,w in [('lower articulated boom',shoulder,elbow,.24),('long overhanging jib',elbow,tip,.22)]:
 ob=beam('large crane '+label,a,b,w,.28,'structure',False)
 for pnt in (a,b):
  name='large crane '+('shoulder' if (pnt-shoulder).length<.01 else 'elbow' if (pnt-elbow).length<.01 else 'tip')+' closed journal';joint(ob,bpy.data.objects['Advanced | '+name],'boom terminates inside a supported journal')
 # Supported wear strip and web stiffeners explain the long rigid section.
 for f in (.25,.50,.75):
  pnt=a.lerp(b,f);collar=box('large crane %s web collar %.2f'%(label,f),pnt,(w+.06,.33,.11),'deck-steel',.018);collar.rotation_mode='QUATERNION';collar.rotation_quaternion=(b-a).to_track_quat('Z','Y');joint(collar,ob,'formed stiffening collar seats around boom web')
# Large paired supporting struts, with aligned clevis bosses and a captive guide sleeve.
for dy in (-.17,.17):
 a=Vector((1.65,-.08,.52))+crane_axis*dy;anchor=shoulder.lerp(elbow,.80);b=anchor+crane_axis*dy;boss=cyl('crane strut upper receiving journal %.2f'%dy,anchor+crane_axis*(dy*.75),.085,.15,'structure','Y');joint(boss,bpy.data.objects['Advanced | large crane lower articulated boom'],'upper strut journal seated through actual boom side');body=beam('crane load strut sleeve %.2f'%dy,a,a.lerp(b,.65),.11,.11,'deck-steel',False);rod=beam('crane load strut captive rod %.2f'%dy,a.lerp(b,.60),b,.065,.065,'tool-steel',False);joint(body,column,'strut lower end received by pedestal clevis');joint(rod,body,'continuous captive rod enters guide sleeve');joint(rod,boss,'strut upper end enters its aligned receiving journal')
# Suspended chain and rounded hook hang over the cargo door, clear of the Basic panes.
previous=bpy.data.objects['Advanced | large crane tip closed journal']
for n in range(15):
 z=1.89-n*.060;bpy.ops.mesh.primitive_torus_add(major_radius=.035,minor_radius=.009,major_segments=28,minor_segments=10,location=(tip.x,tip.y,z),rotation=(math.pi/2,0,n%2*math.pi/2));ob=bpy.context.object;ob=finish(ob,'large crane hanging chain link %d'%n,'structure',0,False);joint(ob,previous,'interlocked chain supported by jib tip');previous=ob
# Rounded open load hook, no impossible disconnected chain end.
shank=beam('large crane hook shank',(tip.x,tip.y,1.08),(tip.x,tip.y,.93),.045,.045,'aged-brass',False);joint(shank,previous,'hook shank retained by last hanging chain link')
curve=bpy.data.curves.new('Large forged load hook','CURVE');curve.dimensions='3D';curve.bevel_depth=.026;curve.bevel_resolution=4;curve.use_fill_caps=True;sp=curve.splines.new('POLY');sp.points.add(48)
for i,point in enumerate(sp.points):
 a=math.radians(100-i*265/48);point.co=(tip.x,tip.y+.12*math.cos(a),.81+.12*math.sin(a),1)
ob=bpy.data.objects.new('Large open hook',curve);s.collection.objects.link(ob);bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob;bpy.ops.object.convert(target='MESH');ob=finish(bpy.context.object,'large crane rounded load hook','aged-brass',0,False);joint(ob,shank,'forged hook neck joins captive shank; suspended above closed cargo door')
# Source-sheet finish: heavy door chevrons, framed covers, rivets and service routes.
for side in (-1,1):
 lx=cx+side*.72;leaf=leaves[0 if side<0 else 1]
 for sign in (-1,1):
  a=(lx+side*.56,cy+sign*.96,.133);b=(cx+side*.18,cy,.133);ob=beam('door leaf %d diagonal armor %d'%(side,sign),a,b,.060,.040,'deck-steel',False);joint(ob,bpy.data.objects['Advanced | cargo door recessed panel %d'%side],'formed diagonal armor rib seated directly on heavy panel')
 for xx in (lx-.58,lx+.58):
  for n in range(6):
   yy=cy-.90+n*.36;stud=cyl('door leaf %d perimeter stud %.2f %.2f'%(side,xx,yy),(xx,yy,.128),.017,.027);joint(stud,bpy.data.objects['Advanced | cargo door recessed panel %d'%side],'captive stud seated in actual panel perimeter')
# Actual supplied skull/bionic/cog meshes are reused as embossed cast door badges.
for side in (-1,1):
 for old in list(s.objects):
  if old.type!='MESH' or not old.name.startswith('Cache centered emblem |'):continue
  ob=old.copy();ob.data=old.data.copy();col.objects.link(ob);ob.parent=root;ob.name='Advanced | cargo door %d cast badge | '%side+old.name
  transform=Matrix.Translation(Vector((cx+side*.72,cy,.131)))@Matrix.Scale(1.45,4)@Matrix.Translation(Vector((0,1.075,-.110)))
  ob.matrix_world=transform@old.matrix_local
  for k,mat in enumerate(ob.data.materials):
   cast=mat.copy();cast.name='Advanced door cast | '+mat.name
   if cast.use_nodes:
    bs=cast.node_tree.nodes.get('Principled BSDF')
    if bs:
     for name in ('Base Color','Metallic','Roughness'):
      for link in list(bs.inputs[name].links):cast.node_tree.links.remove(link)
     bs.inputs['Base Color'].default_value=(.24,.17,.065,1);bs.inputs['Metallic'].default_value=.72;bs.inputs['Roughness'].default_value=.63
   ob.data.materials[k]=mats['structure'] if 'twenty tooth cog' in old.name or 'fitted ' in old.name else mats['barrel-red'] if 'eye lens' in old.name else cast
  if 'twenty tooth cog surround' in old.name:joint(ob,bpy.data.objects['Advanced | cargo door recessed panel %d'%side],'cast badge seated directly on raised cargo-door panel')
# Dark caps and bolted retainers dress the new aft perimeter without changing Basic.
for label,x in [('left',-2.23),('right',2.23)]:
 rail=box('aft '+label+' bolted cap rail',(x,.796,.118),(.22,2.40,.035),'structure',.012);joint(rail,frame['aft '+label+' bearing rail'],'narrow cap strip bolted onto broad grounded flange')
 for y in (-.28,.10,.48,.86,1.24,1.62,2.0):
  cap=cyl('aft '+label+' captive rail bolt %.2f'%y,(x,y,.146),.020,.023);joint(cap,rail,'retainer bolt captured in actual cap rail')
rearcap=box('aft rear bolted cap rail',(0,2.29,.118),(4.48,.19,.035),'structure',.012);joint(rearcap,frame['aft rear bearing rail'],'rear retainer strip follows grounded rear flange')
for x in (-2.1,-1.75,-1.4,-1.05,-.7,-.35,0,.35,.7,1.05,1.4,1.75,2.1):
 cap=cyl('aft rear captive rail bolt %.2f'%x,(x,2.29,.145),.019,.023);joint(cap,rearcap,'captive rear flange fastening')
# Crane carries actual cover plates and pin-retaining bolts around its journals.
for label,pnt,r in [('shoulder',shoulder,.22),('elbow',elbow,.18),('tip',tip,.13)]:
 parent=bpy.data.objects['Advanced | large crane '+label+' pin cap']
 for n in range(6):
  angle=n*math.tau/6;p=(pnt.x+r*.48*math.cos(angle),pnt.y-.245,pnt.z+r*.48*math.sin(angle));stud=cyl('crane %s journal retaining stud %d'%(label,n),p,.022 if label!='tip' else .016,.025,'aged-brass','Y');joint(stud,parent,'retaining stud seated on physical journal cap')
for label,a,b in [('lower articulated boom',shoulder,elbow),('long overhanging jib',elbow,tip)]:
 normal=Vector((0,-.145,0));aa=a.lerp(b,.14)+normal;bb=a.lerp(b,.86)+normal;cover=beam('crane '+label+' bolted side cover',aa,bb,.13,.035,'deck-steel',False);joint(cover,bpy.data.objects['Advanced | large crane '+label],'machined access cover seats on enclosed boom web')
 for f in (.20,.40,.60,.80):
  pt=a.lerp(b,f)+Vector((0,-.172,0));stud=cyl('crane %s cover screw %.2f'%(label,f),pt,.015,.027,'aged-brass','Y');joint(stud,cover,'captive boom cover screw')
for z in (.29,.49):
 ring=cyl('crane slewing thrust collar %.2f'%z,(1.65,-.08,z),.255,.045,'deck-steel');joint(ring,column,'thrust collar seated around founded journal')
# A sealed control housing and restrained Pipette signal/service leads match the sheet.
cabinet=box('sealed crane service control cabinet',(1.55,2.13,.20),(.52,.34,.20),'structure',.028);joint(cabinet,frame['aft rear bearing rail'],'sealed service cabinet mounted to rear flange')
cover=box('service cabinet removable top',(1.55,2.13,.313),(.45,.28,.030),'deck-steel',.018);joint(cover,cabinet,'removable cover seated on sealed cabinet')
for xx in (1.38,1.72):
 for yy in (2.04,2.22):
  stud=cyl('service cabinet captive cover stud %.2f %.2f'%(xx,yy),(xx,yy,.337),.018,.023);joint(stud,cover,'cover screw mounted in retained cabinet lid')
startboss=cyl('cabinet signal gland receiver',(1.40,1.93,.23),.055,.10,'aged-brass','Y');joint(startboss,cabinet,'gland receiver enters real cabinet front face')
endboss=cyl('crane signal gland receiver',(1.42,-.08,.42),.055,.10,'aged-brass','X');joint(endboss,column,'gland receiver enters actual slewing-column side')
import importlib.util
spec=importlib.util.spec_from_file_location('advanced_service_pipette',R/'tools/fmpl/pipette/blender_adapter.py');adapter=importlib.util.module_from_spec(spec);sys.modules[spec.name]=adapter;spec.loader.exec_module(adapter)
wire=mats['barrel-red'].copy();wire.name='Advanced | restrained red insulated service';nt=wire.node_tree;bs=nt.nodes.get('Principled BSDF')
for link in list(bs.inputs['Metallic'].links):nt.links.remove(link)
bs.inputs['Metallic'].default_value=0;bs.inputs['Roughness'].default_value=.72
controls=[Vector(p) for p in [(1.40,1.88,.23),(1.40,1.20,.23),(1.10,-.08,.42),(1.37,-.08,.42)]];points=[]
for n in range(64):
 t=n/63;points.append(controls[0]*(1-t)**3+controls[1]*3*(1-t)**2*t+controls[2]*3*(1-t)*t*t+controls[3]*t**3)
req=dict(id='advanced-crane-service',family='single_wire',payload='signal',material_id=wire.name,size=dict(outer_diameter=.035,wall_fraction=0),path=dict(kind='waypoints',points=[list(p) for p in points]),start_socket=dict(id='cabinet',xyz=list(points[0]),normal=list((points[1]-points[0]).normalized()),role='source',payloads=['signal'],parent_mesh=startboss.name),end_socket=dict(id='crane',xyz=list(points[-1]),normal=list((points[-2]-points[-1]).normalized()),role='sink',payloads=['signal'],parent_mesh=endboss.name),fittings=dict(start='cable_gland',end='cable_gland'),supports=dict(binding='Tangent-aligned glands on sealed cabinet and crane column; broad short service bend'),behavior=dict(static_signal_lead=True,no_new_native_power_or_circuit_port=True),keep_outs=[])
plan=adapter.core.plan(req);collection,objects=adapter.build(plan,wire,mats['aged-brass'])
for ob in objects:ob.parent=root;ob['below_grade_geometry']=False
# Supported intermediate saddles prevent a long floating service-lead span.
for index,k in enumerate((20,40)):
 pnt=points[k];height=pnt.z-.125;post=box('crane service lead support post %d'%index,(pnt.x,pnt.y,.10+height/2),(.040,.045,height),'structure',.006);joint(post,service,'service lead post founded on actual service deck')
 bpy.ops.mesh.primitive_torus_add(major_radius=.027,minor_radius=.006,major_segments=24,minor_segments=8,location=pnt);collar=bpy.context.object;collar.rotation_mode='QUATERNION';collar.rotation_quaternion=(points[k+1]-points[k-1]).to_track_quat('Z','Y');collar=finish(collar,'crane service lead receiving saddle %d'%index,'aged-brass',0,False);joint(collar,post,'open saddle receives cable with finite clearance and rests on support post')
(O/'service-route.json').write_text(json.dumps(dict(request=req,objects=[ob.name for ob in objects],scope='Actual Pipette geometry with fitted tangent-aligned receiving bosses. Static visual service lead; no new gameplay port.'),indent=2)+'\n')
# A continuous curved rear/side conduit follows real flange supports, as on the sheet.
startblock=box('left rear service takeoff',(-2.23,.18,.16),(.14,.14,.12),'structure',.015);joint(startblock,frame['aft left bearing rail'],'service takeoff founded on left aft flange')
junction=box('rear service junction',(1.05,2.29,.18),(.24,.22,.12),'structure',.018);joint(junction,rearcap,'sealed conduit junction mounted over actual raised rear retainer strip')
pts=[Vector((-2.23,.25,.16)),Vector((-2.23,2.09,.16))]
for k in range(1,25):
 a=math.pi-k*(math.pi/2)/24;pts.append(Vector((-2.03+.20*math.cos(a),2.09+.20*math.sin(a),.16)))
pts.append(Vector((.93,2.29,.16)))
request=dict(id='advanced-rear-service-conduit',family='single_wire',payload='signal',material_id=mats['structure'].name,size=dict(outer_diameter=.035,wall_fraction=0),path=dict(kind='waypoints',points=[list(p) for p in pts]),start_socket=dict(id='left-service',xyz=list(pts[0]),normal=[0,1,0],role='source',payloads=['signal'],parent_mesh=startblock.name),end_socket=dict(id='rear-junction',xyz=list(pts[-1]),normal=[-1,0,0],role='sink',payloads=['signal'],parent_mesh=junction.name),fittings=dict(start='cable_gland',end='cable_gland'),supports=dict(binding='Continuous corner radius, actual flange clamp seats, sealed end receivers'),behavior=dict(static_service_conduit=True,no_new_native_port=True),keep_outs=[])
routeplan=adapter.core.plan(request);_,routeobjects=adapter.build(routeplan,mats['structure'],mats['aged-brass'])
for ob in routeobjects:ob.parent=root;ob['below_grade_geometry']=False
for n,(x,y,side) in enumerate([(-2.23,.55,0),(-2.23,.95,0),(-2.23,1.35,0),(-1.60,2.29,1),(-.80,2.29,1),(0,2.29,1)]):
 for sign in (-1,1):
  foot=box('rear conduit saddle %d foot %d'%(n,sign),(x+(sign*.055 if side==0 else 0),y+(sign*.055 if side==1 else 0),.145),(.035,.035,.028),'aged-brass',.006);joint(foot,bpy.data.objects['Advanced | aft left bolted cap rail'] if side==0 else rearcap,'saddle foot captured on actual raised retainer strip')
 curve=bpy.data.curves.new('Conduit saddle arch %d'%n,'CURVE');curve.dimensions='3D';curve.bevel_depth=.008;curve.bevel_resolution=2;curve.use_fill_caps=True;sp=curve.splines.new('POLY');sp.points.add(20)
 for k,point in enumerate(sp.points):
  a=k*math.pi/20;point.co=(x+(.055*math.cos(a) if side==0 else 0),y+(.055*math.cos(a) if side==1 else 0),.14+.055*math.sin(a),1)
 ob=bpy.data.objects.new('Service conduit saddle',curve);s.collection.objects.link(ob);bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob;bpy.ops.object.convert(target='MESH');finish(bpy.context.object,'rear service conduit saddle %d'%n,'aged-brass',0,False)
(O/'rear-service-route.json').write_text(json.dumps(dict(request=request,objects=[ob.name for ob in routeobjects]),indent=2)+'\n')
exec(compile((R/'tools/art/space_cargo/detail_advanced.py').read_text(encoding='utf-8'),str(R/'tools/art/space_cargo/detail_advanced.py'),'exec'))
exec(compile((R/'tools/art/space_cargo/refine_crane.py').read_text(encoding='utf-8'),str(R/'tools/art/space_cargo/refine_crane.py'),'exec'))
exec(compile((R/'tools/art/space_cargo/align_crane.py').read_text(encoding='utf-8'),str(R/'tools/art/space_cargo/align_crane.py'),'exec'))
# Give generated Pipette sweeps real continuous physical-scale UVs locally;
# keep the shared adapter and accepted Basic UVs untouched.
for ob in s.objects:
 if ob.type!='MESH' or not ob.get('pipette_geometry_role'):continue
 me=ob.data;uv=me.uv_layers.new(name='Advanced continuous service UV') if not me.uv_layers else me.uv_layers.active;role=ob.get('pipette_geometry_role');coords={}
 if role in ('terminal-band','terminal-stop'):
  center=sum((v.co for v in me.vertices),Vector())/len(me.vertices);radius=sum((v.co-center).length for v in me.vertices)/len(me.vertices)
  for v in me.vertices:coords[v.index]=((v.index//8)/24*math.tau*radius*1.25,(v.index%8)/8*math.tau*.005*1.25)
 else:
  n=16;stride=32 if ob.get('pipette_true_hollow_mesh') else 16;centers=[sum((me.vertices[k+j].co for j in range(n)),Vector())/n for k in range(0,len(me.vertices),stride)];distance=0
  for k,center in enumerate(centers):
   if k:distance+=(center-centers[k-1]).length
   radius=sum((me.vertices[k*stride+j].co-center).length for j in range(n))/n
   for j in range(n):coords[k*stride+j]=(distance*1.25,j/n*math.tau*radius*1.25)
   if stride==32:
    for j in range(n):coords[k*stride+n+j]=(distance*1.25,j/n*math.tau*ob.get('pipette_bore_diameter_bu',.02)/2*1.25)
 for face in me.polygons:
  if len(face.vertices)>4:
   axis=max(range(3),key=lambda k:abs(face.normal[k]));axes=[k for k in range(3) if k!=axis]
   for li in face.loop_indices:
    v=me.vertices[me.loops[li].vertex_index].co;uv.data[li].uv=(v[axes[0]]*1.25,v[axes[1]]*1.25)
  else:
   for li in face.loop_indices:uv.data[li].uv=coords[me.loops[li].vertex_index]
# Closed manually parked equipment: no new native power/fluid/loading function or animation.
terminals={k:[p[0]*.8,p[1]*.8-1.468,p[2]*.8] for k,p in json.loads((B/'construction.json').read_text())['terminals'].items()};p=json.loads((B/'construction.json').read_text())['status_led'];led=[p[0]*.8,p[1]*.8-1.468,p[2]*.8]
sys.path.insert(0,str(R/'tools/fmpl'));from below_grade_occlusion import add_grade_holdouts;add_grade_holdouts(s,bpy,manifest,parent=root)
profile=json.loads((B/'capture-profile.json').read_text());profile['source_size']=1024;profile['camera_override'].update(ortho_scale=6.5,target=[0,0,.30]);from blender_camera_guard import install_canonical_camera;install_canonical_camera(s,profile,bpy);s.cycles.samples=96;s.cycles.use_denoising=True;s.render.film_transparent=True
for n,d in [('capture-profile.json',profile),('occlusion.json',manifest),('contacts.json',contacts),('construction.json',dict(grade=0,underground_floor=-1.20,glass_top=-.004,terminals=terminals,status_led=led,registration=[0,-.30/math.sqrt(2)],native='Existing Advanced5x5/50slot passive platform container,420health,18s recipe,void-cogitator unlock,wire reach9 preserved. Four native placement directions as requested for the family.',owner_rescope='Preserve the Basic three-window assembly and add adjacent huge cargo door/subframe and a large overhanging crane; four-bay replacement rejected.',basis='Complete accepted Basic module retained with unchanged meshes/UVs/materials; uniform0.8 fit into owner-corrected Advanced5x5 square contract, located atY-1.468. No component stretching or window-layout replacement.',crane_position='Owner refinement: pedestal seated atY-.08 close to the lower cargo windows; raised elbowZ1.90 and jib tipZ2.05 reach over the central cargo doorway. Struts, cable and chain follow the moved journals.',geometry='Aft steel platform, heavy two-leaf cargo door into an opaque underframe shaft, large founded overhanging articulated crane with actual journals/struts/chain/rounded hook',animation='None: static closed cargo door and parked crane; actual prototype remains ordinary passive storage, not a new automatic loader',basis_source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),source_sheet='Owner345hd7download.png: heavy closed double cargo door, large overhanging crane, perimeter retainers, cast skull reliefs, dark steel/cast brass services; within owner-corrected5x5 square footprint',source_recovery='Original Advanced editable source unavailable; referencePNG retained; accepted Basic source reused without editing its mesh data'))]:
 (O/n).write_text(json.dumps(d,indent=2)+'\n')
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(O/'advanced-space-cargo-v01.blend'),compress=True);bpy.ops.object.select_all(action='DESELECT')
for ob in s.objects:
 if ob.type=='MESH' and not ob.get('fmpl_render_only'):ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(O/'advanced-space-cargo-v01.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_lights=False,export_cameras=False,export_extras=True)
s.render.filepath=str(O/'source-front.png');bpy.ops.render.render(write_still=True);print('ADVANCED_BASIC_PLUS_DOOR_AND_CRANE_SOURCE_CONSTRUCTED')
