"""Revolute joints derived from one physical articulation plane, independent of camera."""
axis=crane_axis;up=Vector((0,0,1));horizontal=crane_horizontal
joint_records=[]
def frame(a,b):
 z=(Vector(b)-Vector(a)).normalized();y=axis;x=y.cross(z).normalized();return Matrix((x,y,z)).transposed().to_4x4()
def orient(ob,p,direction=axis):
 ob.location=p;ob.rotation_mode='QUATERNION';ob.rotation_quaternion=direction.to_track_quat('Z','Y');return ob
def adopt(old,temp):
 bpy.context.view_layer.update();old.data=temp.data.copy();old.matrix_world=temp.matrix_world.copy();bpy.data.objects.remove(temp,do_unlink=True);return old
def ring(name,p,r,inner,depth,role='structure'):
 return orient(hollow(name,p,r,inner,depth,'Z',role),p)
def pin(name,p,r,depth,role='tool-steel'):
 return orient(cyl(name,p,r,depth,role),p)
def bore(ob,p,r,depth):
 cut=pin('TEMP joint clearance cutter',p,r,depth);bpy.context.view_layer.objects.active=ob;mod=ob.modifiers.new('Machined coaxial joint clearance','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cut;bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cut,do_unlink=True)
# Roll every boom member and mounted detail into the common joint frame.
for label,a,b in [('lower articulated boom',shoulder,elbow),('long overhanging jib',elbow,tip)]:
 host=bpy.data.objects['Advanced | large crane '+label];old=host.matrix_world.copy();new=frame(a,b);new.translation=(a+b)/2;delta=new@old.inverted()
 attached=[o for o in s.objects if o.type=='MESH' and label in o.name and 'bearing cheek' not in o.name]
 for ob in attached:ob.matrix_world=delta@ob.matrix_world
 # Service plates are normal to the physical side face, not global Y.
 cover=bpy.data.objects['Advanced | crane '+label+' bolted side cover'];start=.23 if label.startswith('lower') else .14;end=.86;p=a.lerp(b,(start+end)/2)-axis*.1575
 # Replace length too: keep lower cover clear of its shoulder bearing envelope.
 temp=beam('TEMP cover',a.lerp(b,start)-axis*.1575,a.lerp(b,end)-axis*.1575,.13,.035,'deck-steel',False);temp.matrix_world=frame(a,b);temp.location=p;adopt(cover,temp)
 for f in (.20,.40,.60,.80):
  stud=bpy.data.objects['Advanced | crane %s cover screw %.2f'%(label,f)];ff=max(f,.25) if label.startswith('lower') else f;adopt(stud,pin('TEMP screw',a.lerp(b,ff)-axis*.182,.015,.027,'aged-brass'))
 for f in (.23,.53,.77):
  tab=bpy.data.objects['Advanced | detail crane %s rear access tab %.2f'%(label,f)];m=frame(a,b);m.translation=a.lerp(b,f)+axis*.1575;tab.matrix_world=m
# Separate inner rotating hub, fixed cheeks, continuous pin and retained caps.
for label,p,r,bore_r,shaft_r in [('shoulder',shoulder,.22,.058,.050),('elbow',elbow,.18,.048,.040)]:
 hub=bpy.data.objects['Advanced | large crane '+label+' closed journal'];adopt(hub,ring('TEMP bored rotating hub',p,r,bore_r,.24))
 cheeks=[]
 arm_label='lower articulated boom' if label=='shoulder' else 'long overhanging jib'
 for side in (-1,1):
  cheek=bpy.data.objects['Advanced | detail crane %s heel bearing cheek %d'%(arm_label,side)];adopt(cheek,ring('TEMP fixed bearing cheek',p+axis*side*.165,r*1.12,bore_r,.065,'deck-steel'));cheeks.append(cheek)
 cap=bpy.data.objects['Advanced | large crane '+label+' pin cap'];adopt(cap,pin('TEMP retained front cap',p-axis*.2175,r*.70,.040,'aged-brass'))
 rear=pin('crane '+label+' retained rear pin cap',p+axis*.2175,r*.70,.040,'aged-brass');joint(rear,cheeks[1],'rear cap seats on actual fixed cheek face')
 shaft=pin('crane '+label+' continuous transverse pivot pin',p,shaft_r,.445);joint(shaft,hub,'coaxial pin runs through bored rotating hub with radial clearance')
 contacts[:]=[c for c in contacts if not (c['a']==cap.name and c['b']==hub.name) and not (c['a'] in [ch.name for ch in cheeks] and c['b']==hub.name) and not (c['a']==hub.name and c['b']==column.name)]
 joint(cap,cheeks[0],'retaining cap seats on fixed cheek face')
 for n in range(6):
  theta=n*math.tau/6;stud=bpy.data.objects['Advanced | crane %s journal retaining stud %d'%(label,n)];adopt(stud,pin('TEMP retaining stud',p-axis*.248+horizontal*r*.48*math.cos(theta)+up*r*.48*math.sin(theta),.022,.025,'aged-brass'))
 if label=='shoulder':
  # Actual saddle in fixed column, so the rotating hub has a free swept envelope.
  for ob in (column,bpy.data.objects['Advanced | crane slewing thrust collar 0.49']):bore(ob,p,r+.008,.265);bore(ob,p,bore_r,.65)
  for cheek in cheeks:joint(cheek,column,'fixed shoulder fork cheek carried by machined column saddle')
  bore(bpy.data.objects['Advanced | large crane lower articulated boom'],p,bore_r,.65)
 else:
  lower=bpy.data.objects['Advanced | large crane lower articulated boom'];bore(lower,p,r+.008,.265);bore(lower,p,bore_r,.65);bore(bpy.data.objects['Advanced | large crane long overhanging jib'],p,bore_r,.65)
  direction=(elbow-shoulder).normalized()
  for side,cheek in zip((-1,1),cheeks):
   strap=beam('crane elbow fixed fork strap %d'%side,p-direction*.34+axis*side*.165,p-direction*.06+axis*side*.165,.15,.065,'structure',False);m=frame(shoulder,elbow);m.translation=p-direction*.20+axis*side*.165;strap.matrix_world=m;joint(strap,lower,'fork strap welded to incoming lower boom side');joint(cheek,strap,'fixed cheek carried by incoming fork strap')
 joint_records.append(dict(label=label,center=list(p),axis=list(axis),hub=hub.name,cheeks=[c.name for c in cheeks],shaft=shaft.name,hub_depth=.24,cheek_centers=.165,cheek_depth=.065,bore_radius=bore_r,shaft_radius=shaft_r,minimum_axial_clearance=.0125,minimum_radial_clearance=bore_r-shaft_r))
# Tip dead-axle and its fasteners use the same transverse frame.
p=tip;hub=bpy.data.objects['Advanced | large crane tip closed journal'];adopt(hub,pin('TEMP tip axle',p,.13,.36,'structure'));adopt(bpy.data.objects['Advanced | large crane tip pin cap'],pin('TEMP tip cap',p-axis*.20,.091,.075,'aged-brass'))
for n in range(6):
 theta=n*math.tau/6;adopt(bpy.data.objects['Advanced | crane tip journal retaining stud %d'%n],pin('TEMP tip stud',p-axis*.245+horizontal*.13*.48*math.cos(theta)+up*.13*.48*math.sin(theta),.016,.025,'aged-brass'))
# Both guide assemblies lie in offset copies of the same articulation plane.
for side,dy in [(-1,-.17),(1,.17)]:
 a=Vector((shoulder.x,shoulder.y,.35))-horizontal*.17+axis*(side*.23);b=shoulder.lerp(elbow,.80)+axis*(side*.23);direction=(b-a).normalized();length=(b-a).length
 body=bpy.data.objects['Advanced | crane load strut sleeve %.2f'%dy];rod=bpy.data.objects['Advanced | crane load strut captive rod %.2f'%dy]
 start=a+direction*.055;end=a.lerp(b,.65);temp=hollow('TEMP guide barrel',(start+end)/2,.065,.037,(end-start).length,'Z','deck-steel');orient(temp,(start+end)/2,direction);adopt(body,temp)
 start=a.lerp(b,.60);end=b-direction*.055;adopt(rod,orient(cyl('TEMP captive rod',(start+end)/2,.0325,(end-start).length,'tool-steel'),(start+end)/2,direction))
 gland=bpy.data.objects['Advanced | detail crane guide gland %.2f'%dy];adopt(gland,orient(hollow('TEMP gland',a.lerp(b,.65),.078,.037,.035,'Z','aged-brass'),a.lerp(b,.65),direction))
 cap=bpy.data.objects['Advanced | crane strut closed heel %.2f'%dy];adopt(cap,orient(cyl('TEMP barrel heel',a+direction*.075,.074,.045,'structure'),a+direction*.075,direction))
 # Bored rod eyes and double-shear clevises at BOTH ends.
 lower_eye=ring('crane strut lower captive eye %.2f'%dy,a,.065,.024,.055,'deck-steel');upper_eye=ring('crane strut upper captive eye %.2f'%dy,b,.065,.024,.055,'tool-steel');joint(lower_eye,cap,'barrel closed heel bears on lower pivot eye');joint(upper_eye,rod,'rod terminates in eye belly, clear of pivot bore')
 contacts[:]=[c for c in contacts if not (c['a']==body.name and c['b']==column.name) and not (c['a']==rod.name and c['b'].startswith('Advanced | crane strut upper receiving journal')) and not (c['a'].startswith('Advanced | crane strut upper receiving journal') and c['b']=='Advanced | large crane lower articulated boom')]
 for end_name,p,eye in [('lower',a,lower_eye),('upper',b,upper_eye)]:
  shaft=pin('crane strut %s clevis pin %.2f'%(end_name,dy),p,.021,.205 if end_name=='lower' else .19);joint(shaft,eye,'coaxial eye pin with .003 radial clearance')
  for sign in (-1,1):
   cp=p+axis*sign*.065
   if end_name=='upper' and sign==-side:
    old=bpy.data.objects['Advanced | crane strut upper receiving journal %.2f'%dy];cheek=adopt(old,ring('TEMP upper fixed cheek',cp,.085,.024,.035))
   else:cheek=ring('crane strut %s fixed clevis cheek %.2f %d'%(end_name,dy,sign),cp,.085 if end_name=='upper' else .08,.024,.035)
   if end_name=='lower':joint(cheek,ped,'lower clevis cheek foot seated on cast pedestal')
   else:
    # Tail of each upper cheek is supported by a strap beyond the moving eye.
    tail=beam('crane strut upper clevis tail %.2f %d'%(dy,sign),p-direction*.10+axis*sign*.065,shoulder.lerp(elbow,.80)-direction*.10,.045,.045,'structure',False);joint(tail,cheek,'clevis tail joins fixed cheek outside the moving eye envelope');joint(tail,bpy.data.objects['Advanced | large crane lower articulated boom'],'upper clevis strap anchored in boom web')
  for sign in (-1,1):
   retainer=pin('crane strut %s pin retainer %.2f %d'%(end_name,dy,sign),p+axis*sign*.0925,.036,.020,'aged-brass');joint(retainer,shaft,'axial retaining cap seated on clevis pin')
  joint(eye,shaft,'eye captured between spaced fixed cheeks with axial clearance')
 bore(bpy.data.objects['Advanced | large crane lower articulated boom'],shoulder.lerp(elbow,.80),.024,.95)
 joint(body,lower_eye,'closed guide barrel received by lower pivot eye')
# Remove numerical slivers introduced by machining Boolean holes before export.
import bmesh
ob=bpy.data.objects['Advanced | large crane lower articulated boom'];bm=bmesh.new();bm.from_mesh(ob.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7);bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-7);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(ob.data);bm.free()
bpy.context.view_layer.update()
(O/'crane-joint-contract.json').write_text(json.dumps(dict(articulation_plane=dict(shoulder=list(shoulder),elbow=list(elbow),tip=list(tip),horizontal=list(horizontal),normal=list(axis)),joints=joint_records,struts='Two parallel offset articulation planes. Bored rod eyes and double-shear clevises at both ends; cylinder/rod ends stop short of pin bores.',scope='Static parked container crane. Mechanical construction/clearance check only; no new operating animation or loader behavior.'),indent=2)+'\n')
