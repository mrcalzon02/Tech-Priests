"""Dense, mechanically seated Advanced cargo detail; executed in build globals."""
detail_start=len([o for o in s.objects if o.type=='MESH']);detail_roles=[]
def detail_joint(ob,host,why):joint(ob,host,why);detail_roles.append(dict(object=ob.name,host=host.name if hasattr(host,'name') else host,purpose=why))
def hollow(name,p,outer,inner,length,axis='Z',role='structure'):
 verts=[];faces=[];n=48
 for z,r in [(-length/2,outer),(length/2,outer),(-length/2,inner),(length/2,inner)]:
  for k in range(n):
   a=k*math.tau/n;x=r*math.cos(a);y=r*math.sin(a);verts.append((z,x,y) if axis=='X' else (y,z,x) if axis=='Y' else (x,y,z))
 for k in range(n):
  j=(k+1)%n;faces.extend([(k,j,n+j,n+k),(2*n+k,3*n+k,3*n+j,2*n+j),(n+k,n+j,3*n+j,3*n+k),(k,2*n+k,2*n+j,j)])
 me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update();ob=bpy.data.objects.new(name,me);s.collection.objects.link(ob);ob.location=p;return finish(ob,'detail '+name,role,0,False)
def drill(ob,p,radius,length=.18):
 bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=radius,depth=length,location=p,rotation=(0,math.pi/2,0));cut=bpy.context.object;bpy.context.view_layer.objects.active=ob;mod=ob.modifiers.new('Actual service port bore','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cut;bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cut,do_unlink=True)
# Raised retaining lips and closely spaced studs belong to each door leaf.
for side in (-1,1):
 lx=cx+side*.72;panel=bpy.data.objects['Advanced | cargo door recessed panel %d'%side]
 for sign in (-1,1):
  lip=box('detail door %d raised vertical lip %d'%(side,sign),(lx+sign*.59,cy,.134),(.045,2.02,.038),'structure',.008);detail_joint(lip,panel,'raised protective edge carried by actual cargo door panel')
 for yy in (cy-.91,cy+.91):
  pad=box('detail door %d recessed inspection plate %.2f'%(side,yy),(lx,yy,.137),(.27,.13,.035),'structure',.012);detail_joint(pad,panel,'removable leaf inspection plate')
  for xx in (lx-.10,lx+.10):
   stud=cyl('detail inspection captive stud %.2f %.2f'%(xx,yy),(xx,yy,.165),.013,.024);detail_joint(stud,pad,'captive fastener mounted on inspection plate')
 # Triangular-web-looking paired small buttresses back each hinge ear.
 for yy in (cy-.88,cy,cy+.88):
  xx=xmin+.12 if side<0 else xmax-.12
  for dy in (-.11,.11):
   brace=beam('detail hinge load gusset %d %.2f %.2f'%(side,yy,dy),(xx,yy+dy,.102),(xx+side*.09,yy,.18),.035,.045,'structure',False);detail_joint(brace,panel,'hinge root load gusset carried by leaf panel')
# Structural ribs and bolted corner shoes on the solid joining bridge.
bridge=frame['module joining bridge']
for x in (-2.1,-1.5,-.9,-.3,.3,.9,1.5,2.1):
 rib=box('detail joining bridge raised rib %.2f'%x,(x,-.393,.112),(.09,.17,.045),'structure',.009);detail_joint(rib,bridge,'raised structural bridge rib seated on deck member')
 stud=cyl('detail joining rib bolt %.2f'%x,(x,-.393,.145),.018,.025);detail_joint(stud,rib,'structural rib captive bolt')
for x in (-2.23,2.23):
 for y in (-.25,1.98):
  shoe=box('detail aft corner reinforcement %.2f %.2f'%(x,y),(x,y,.155),(.31,.24,.045),'structure',.016);detail_joint(shoe,bpy.data.objects['Advanced | aft '+('left' if x<0 else 'right')+' bolted cap rail'],'reinforcement shoe overlies grounded frame cap')
  for dx in (-.09,.09):
   stud=cyl('detail corner stud %.2f %.2f'%(x+dx,y),(x+dx,y,.188),.021,.025);detail_joint(stud,shoe,'corner shoe fastening')
# True louver gaps over a dark vent recess, on the right solid frame.
ventbase=box('detail vent housing base',(2.23,.62,.155),(.20,.50,.040),'structure',.012);detail_joint(ventbase,bpy.data.objects['Advanced | aft right bolted cap rail'],'vent housing seated on solid right-frame cap')
for dx in (-.091,.091):
 wall=box('detail vent side wall %.3f'%dx,(2.23+dx,.62,.218),(.018,.50,.09),'structure',.004);detail_joint(wall,ventbase,'vent wall rises from housing floor')
for n in range(8):
 ob=box('detail inclined vent louver %d'%n,(2.23,.415+n*.058,.250),(.18,.040,.015),'deck-steel',.004);ob.rotation_euler.x=.40;detail_joint(ob,bpy.data.objects['Advanced | detail vent side wall -0.091'],'louver blade carried by vent side walls, actual air gaps between blades')
# Sealed local hydraulic reservoir and paired pump/filter stacks for crane service.
rfloor=box('detail pump reservoir floor',(1.80,1.24,.115),(.42,1.14,.030),'structure',.006);detail_joint(rfloor,service,'pump reservoir founded on service deck')
for label,x in [('left',1.602),('right',1.998)]:
 wall=box('detail reservoir '+label+' shell',(x,1.24,.235),(.024,1.14,.210),'structure',.004);detail_joint(wall,rfloor,'hollow reservoir side meets real floor')
for label,y in [('front',.682),('rear',1.798)]:
 wall=box('detail reservoir '+label+' shell',(1.80,y,.235),(.42,.024,.210),'structure',.004);detail_joint(wall,rfloor,'closed reservoir end wall')
lid=box('detail reservoir removable lid',(1.80,1.24,.355),(.44,1.16,.030),'deck-steel',.009);detail_joint(lid,bpy.data.objects['Advanced | detail reservoir left shell'],'reservoir lid seats on actual shell')
fluid_routes=[]
for index,yy in enumerate((.93,1.55)):
 body=hollow('pump stack %d bored shell'%index,(1.80,yy,.59),.125,.095,.44);detail_joint(body,lid,'hollow pump/filter body carried by reservoir lid')
 for z,r in [(.40,.150),(.54,.148),(.61,.148),(.80,.155)]:
  collar=hollow('pump %d ribbed collar %.2f'%(index,z),(1.80,yy,z),r,.125,.030,'Z','deck-steel');detail_joint(collar,body,'formed collar seats on pump shell')
 cap=cyl('detail pump %d bolted end cap'%index,(1.80,yy,.835),.15,.05,'structure');detail_joint(cap,body,'closed pump cap seated on shell mouth')
 for k in range(6):
  a=k*math.tau/6;stud=cyl('detail pump %d cap stud %d'%(index,k),(1.80+.115*math.cos(a),yy+.115*math.sin(a),.875),.014,.03);detail_joint(stud,cap,'retained pump end-cap fastening')
 # Both visible supply and return tubes have real bores in the shell and reservoir wall.
 for port,(zr,zp,reach) in enumerate(((.19,.46,2.20),(.29,.72,2.36))):
  reservoirwall=bpy.data.objects['Advanced | detail reservoir right shell'];drill(reservoirwall,(1.998,yy,zr),.022)
  drill(body,(1.925,yy,zp),.022)
  a=hollow('pump %d reservoir receiver %d'%(index,port),(2.025,yy,zr),.044,.022,.060,'X','aged-brass');detail_joint(a,reservoirwall,'bored receiving socket enters actual reservoir shell opening')
  b=hollow('pump %d body receiver %d'%(index,port),(1.945,yy,zp),.044,.022,.060,'X','aged-brass');detail_joint(b,body,'bored receiver meets real side opening into hollow pump body')
  controls=[Vector(p) for p in [(2.055,yy,zr),(reach,yy,zr),(reach,yy,zp),(1.975,yy,zp)]];route=[]
  for k in range(65):
   t=k/64;pt=controls[0]*(1-t)**3+controls[1]*3*(1-t)**2*t+controls[2]*3*(1-t)*t*t+controls[3]*t**3
   if port==1 and 1<k<63:pt.y+=.16*math.sin(math.pi*t)**2
   route.append(pt)
  if port==1:
   off=.16;start=(2.055,yy,zr);end=(1.975,yy,zp)
   curves=[[start,(2.15,yy,zr),(2.14,yy+off,zr+.09),(2.18,yy+off,zr+.09)],[(2.18,yy+off,zr+.09),(2.42,yy+off,zr+.09),(2.42,yy+off,zp),(2.22,yy+off,zp)],[(2.22,yy+off,zp),(2.12,yy+off,zp),(2.10,yy,zp),end]];route=[]
   for c in curves:
    c=[Vector(q) for q in c];part=[]
    for n in range(25):
     t=n/24;part.append(c[0]*(1-t)**3+c[1]*3*(1-t)**2*t+c[2]*3*(1-t)*t*t+c[3]*t**3)
    route+=part if not route else part[1:]
   route[1].y=yy;route[1].z=zr;route[-2].y=yy;route[-2].z=zp
  request=dict(id='advanced-pump-%d-%d'%(index,port),family='rigid_pipe',payload='fluid',material_id=mats['structure'].name,size=dict(outer_diameter=.035,wall_fraction=.16),path=dict(kind='waypoints',points=[list(p) for p in route]),start_socket=dict(id='reservoir',xyz=list(route[0]),normal=[1,0,0],role='source',payloads=['fluid'],parent_mesh=a.name),end_socket=dict(id='pump',xyz=list(route[-1]),normal=[1,0,0],role='sink',payloads=['fluid'],parent_mesh=b.name),fittings=dict(start='compression',end='compression'),supports=dict(binding='Short broad bends between bored hollow bodies; all equipment founded on service deck'),behavior=dict(static_closed_crane_service_loop=True,no_new_native_fluid_port=True),keep_outs=[])
  plan=adapter.core.plan(request);_,objects=adapter.build(plan,mats['structure'],mats['aged-brass'])
  for ob in objects:ob.parent=root;ob['below_grade_geometry']=False
  fluid_routes.append(dict(request=request,objects=[o.name for o in objects],reservoir_body=reservoirwall.name,pump_body=body.name))
# More mounted crane web ribs and side service covers, leaving all pin axes clear.
for label,a,b in [('lower articulated boom',shoulder,elbow),('long overhanging jib',elbow,tip)]:
 host=bpy.data.objects['Advanced | large crane '+label]
 for k in range(1,10):
  pt=a.lerp(b,k/10);rib=box('detail crane %s transverse web %d'%(label,k),pt,(.28,.035,.060),'structure',.008);rib.rotation_mode='QUATERNION';rib.rotation_quaternion=(b-a).to_track_quat('Z','Y');detail_joint(rib,host,'small stiffening web wraps actual boom section')
 for f in (.23,.53,.77):
  p=a.lerp(b,f)+Vector((0,.155,0));cover=box('detail crane %s rear access tab %.2f'%(label,f),p,(.11,.035,.13),'deck-steel',.008);detail_joint(cover,host,'small rear access cover seated on boom housing')
# Segmented center seam armor leaves the real lock-bar guide zones accessible.
for side in (-1,1):
 panel=bpy.data.objects['Advanced | cargo door recessed panel %d'%side]
 for index,(y0,y1) in enumerate([(-.07,.51),(.84,1.10),(1.44,1.99)]):
  y=(y0+y1)/2;plate=box('detail door seam armor %d %d'%(side,index),(cx+side*.10,y,.142),(.10,y1-y0,.045),'structure',.010);detail_joint(plate,panel,'raised seam armor carried by the leaf, with locking-bar access retained')
  for yy in (y0+.06,y1-.06):
   stud=cyl('detail seam armor captive stud %d %d %.2f'%(side,index,yy),(cx+side*.10,yy,.176),.014,.026);detail_joint(stud,plate,'captive seam armor stud')
# Long raised boom-face edging is attached in each boom's true local frame.
for label,a,b,w in [('lower articulated boom',shoulder,elbow,.24),('long overhanging jib',elbow,tip,.22)]:
 host=bpy.data.objects['Advanced | large crane '+label];L=(b-a).length
 for side in (-1,1):
  rail=box('detail crane %s longitudinal edging %d'%(label,side),(0,0,0),(.045,.040,L*.82),'deck-steel',.008);rail.matrix_world=host.matrix_world@Matrix.Translation(Vector((-w/2-.008,side*.10,0)));detail_joint(rail,host,'longitudinal raised edge seated on the actual boom face')
  for n in range(6):
   z=(-.35+n*.14)*L;stud=cyl('detail crane %s edge fastener %d %d'%(label,side,n),(0,0,0),.014,.032,'aged-brass','X');stud.matrix_world=host.matrix_world@Matrix.Translation(Vector((-w/2-.035,side*.10,z)));detail_joint(stud,rail,'retained fastener seated on raised boom edge')
# Two additional gland-ended control leads rise from the sealed cabinet to pump heads.
signal_routes=[];black_wire=wire.copy();black_wire.name='Advanced | dark insulated pump signal';nt=black_wire.node_tree;bs=nt.nodes.get('Principled BSDF')
for link in list(bs.inputs['Base Color'].links):nt.links.remove(link)
bs.inputs['Base Color'].default_value=(.025,.031,.027,1)
for index,(yy,xstart,material) in enumerate([(.93,1.44,black_wire),(1.55,1.66,wire)]):
 startboss=cyl('detail pump signal cabinet gland %d'%index,(xstart,2.13,.350),.029,.060,'aged-brass');detail_joint(startboss,bpy.data.objects['Advanced | service cabinet removable top'],'signal receiving gland seated in cabinet lid')
 endboss=cyl('detail pump head signal gland %d'%index,(1.80,yy,.880),.027,.050,'aged-brass');detail_joint(endboss,bpy.data.objects['Advanced | detail pump %d bolted end cap'%index],'signal receiver seated in closed pump head')
 controls=[Vector(q) for q in [(xstart,2.13,.380),(xstart,2.13,.650),(1.80,yy,1.10),(1.80,yy,.905)]];pts=[]
 for k in range(65):
  t=k/64;pts.append(controls[0]*(1-t)**3+controls[1]*3*(1-t)**2*t+controls[2]*3*(1-t)*t*t+controls[3]*t**3)
 pts[1].x=xstart;pts[1].y=2.13;pts[-2].x=1.80;pts[-2].y=yy
 request=dict(id='advanced-pump-signal-%d'%index,family='single_wire',payload='signal',material_id=material.name,size=dict(outer_diameter=.018,wall_fraction=0),path=dict(kind='waypoints',points=[list(q) for q in pts]),start_socket=dict(id='cabinet-roof',xyz=list(pts[0]),normal=[0,0,1],role='source',payloads=['signal'],parent_mesh=startboss.name),end_socket=dict(id='pump-head',xyz=list(pts[-1]),normal=[0,0,1],role='sink',payloads=['signal'],parent_mesh=endboss.name),fittings=dict(start='cable_gland',end='cable_gland'),supports=dict(binding='Short flexible service arch between two actual receiving glands; no unsupported hard elbow'),behavior=dict(static_local_signal_lead=True,no_new_gameplay_port=True),keep_outs=[])
 plan=adapter.core.plan(request);_,objects=adapter.build(plan,material,mats['aged-brass'])
 for ob in objects:ob.parent=root;ob['below_grade_geometry']=False
 signal_routes.append(dict(request=request,objects=[o.name for o in objects]))
(O/'dense-detail-manifest.json').write_text(json.dumps(dict(source_stage='Owner requested dense structural/service detail',added_meshes=len([o for o in s.objects if o.type=='MESH'])-detail_start,roles=detail_roles,hydraulic_routes=fluid_routes,signal_routes=signal_routes,scope='Static crane service equipment only. No new native fluid/electrical port, production recipe or operating animation. Original Basic mesh data and5x5 footprint retained.'),indent=2)+'\n')
