"""Construction refinement, preserving accepted placement and Basic module."""
refined=[]
def replace_mesh(ob,verts,faces):
 old=ob.data;me=bpy.data.meshes.new(ob.name+' refined casting');me.from_pydata(verts,[],faces);me.update();ob.data=me
 import bmesh
 bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free()
 role=old.materials[0].get('cargo_role','structure') if old.materials else 'structure'
 mat=old.materials[0] if old.materials else mats['structure'];name=ob.name
 finish(ob,name.removeprefix('Advanced | '),role,.004,False);ob.data.materials[0]=mat;refined.append(name)

def octagon(w,d,c):return [(-w/2+c,-d/2),(w/2-c,-d/2),(w/2,-d/2+c),(w/2,d/2-c),(w/2-c,d/2),(-w/2+c,d/2),(-w/2,d/2-c),(-w/2,-d/2+c)]
def loft(ob,stations):
 verts=[(x,y,z) for z,w,d,c in stations for x,y in octagon(w,d,c)];faces=[tuple(reversed(range(8))),tuple(range(len(verts)-8,len(verts)))]
 for k in range(len(stations)-1):
  for j in range(8):faces.append((k*8+j,k*8+(j+1)%8,(k+1)*8+(j+1)%8,(k+1)*8+j))
 replace_mesh(ob,verts,faces)
# Retain the original webs under the existing mounted longitudinal rails.
for label,a,b,w in [('lower articulated boom',shoulder,elbow,.24),('long overhanging jib',elbow,tip,.22)]:
 ob=bpy.data.objects['Advanced | large crane '+label];L=(b-a).length
 loft(ob,[(-L*.5,w,.22,.035),(-L*.44,w+.08,.22,.045),(-L*.32,w,.22,.035),(-L*.28,w,.28,.035),(L*.40,w,.28,.035),(L*.5,w*.82,.32 if label.startswith('lower') else .25,.032)])
 for tag,p,r in [('heel',a,.22 if label.startswith('lower') else .18)]:
  for side in (-1,1):
   ring=hollow('crane %s %s bearing cheek %d'%(label,tag,side),(p.x,p.y+side*.185,p.z),r*1.12,r*.62,.045,'Y','deck-steel');joint(ring,bpy.data.objects['Advanced | large crane '+('shoulder' if label.startswith('lower') else 'elbow')+' closed journal'],'annular cheek plate seats on the actual boom journal')
# Stepped octagonal foundation, on the same grounded support frame.
ped=bpy.data.objects['Advanced | large crane founded pedestal']
loft(ped,[(-.10,.82,.78,.065),(-.05,.82,.78,.065),(-.01,.69,.65,.055),(.10,.76,.72,.045)])
# Triangular radial gussets connect the pedestal to the slewing column.
for sx in (-1,1):
 for sy in (-1,1):
  a=Vector((1.65+sx*.27,-.08+sy*.24,.275));b=Vector((1.65+sx*.11,-.08+sy*.10,.275));c=Vector((b.x,b.y,.49));normal=(b-a).cross(c-a).normalized()*.022
  vs=[tuple(p+normal*t) for t in (-1,1) for p in (a,b,c)];fs=[(0,2,1),(3,4,5),(0,1,4,3),(1,2,5,4),(2,0,3,5)]
  me=bpy.data.meshes.new('cast foundation gusset');me.from_pydata(vs,[],fs);me.update();ob=bpy.data.objects.new('gusset',me);s.collection.objects.link(ob);finish(ob,'crane cast radial foundation gusset %d %d'%(sx,sy),'structure',.004,False);joint(ob,ped,'cast triangular gusset seated on octagonal pedestal');joint(ob,column,'gusset upper edge receives slewing column')
# Round guide barrels with real bores and captive polished rods.
for dy in (-.17,.17):
 a=Vector((1.65,-.08,.52))+crane_axis*dy;b=shoulder.lerp(elbow,.80)+crane_axis*dy;q=(b-a).to_track_quat('Z','Y')
 for kind,f0,f1,r,inner,role in [('sleeve',0,.65,.065,.037,'deck-steel'),('captive rod',.60,1,.0325,0,'tool-steel')]:
  old=bpy.data.objects['Advanced | crane load strut '+kind+' %.2f'%dy];p=a.lerp(b,f0);end=a.lerp(b,f1);length=(end-p).length
  if inner:temp=hollow('temporary barrel',tuple((p+end)/2),r,inner,length,'Z',role)
  else:temp=cyl('temporary rod',tuple((p+end)/2),r,length,role)
  old.data=temp.data.copy();old.location=(p+end)/2;old.rotation_mode='QUATERNION';old.rotation_quaternion=q;bpy.data.objects.remove(temp,do_unlink=True);refined.append(old.name)
 sleeve=bpy.data.objects['Advanced | crane load strut sleeve %.2f'%dy]
 gland=hollow('crane guide gland %.2f'%dy,a.lerp(b,.65),.078,.037,.035,'Z','aged-brass');gland.rotation_mode='QUATERNION';gland.rotation_quaternion=q;joint(gland,sleeve,'bored retaining gland seats around guide barrel with radial rod clearance')
 cap=cyl('crane strut closed heel %.2f'%dy,a.lerp(b,.025),.074,.045,'structure');cap.rotation_mode='QUATERNION';cap.rotation_quaternion=q;joint(cap,sleeve,'closed cylinder heel seated inside load barrel')
# Tapered forged load hook: thick root and belly, fine curved tip.
ob=bpy.data.objects['Advanced | large crane rounded load hook'];verts=[];faces=[];steps=64;sides=16
# Vertices expressed in world frame; replace original curve object's frame explicitly.
ob.matrix_world=Matrix.Identity(4);ob.parent=root
for i in range(steps+1):
 t=i/steps;angle=math.radians(100-265*t);center=Vector((tip.x,tip.y+.12*math.cos(angle),.81+.12*math.sin(angle)));rad=.044*(1-t)+.014*t
 normal=Vector((0,math.cos(angle),math.sin(angle)))
 for j in range(sides):
  phi=j*math.tau/sides;verts.append(tuple(center+Vector((1,0,0))*math.cos(phi)*rad*.80+normal*math.sin(phi)*rad))
for i in range(steps):
 for j in range(sides):faces.append((i*sides+j,i*sides+(j+1)%sides,(i+1)*sides+(j+1)%sides,(i+1)*sides+j))
faces.extend([tuple(reversed(range(sides))),tuple(range(steps*sides,(steps+1)*sides))]);replace_mesh(ob,verts,faces)
for face in ob.data.polygons:face.use_smooth=len(face.vertices)==4
swivel=cyl('crane hook swivel collar',(tip.x,tip.y,1.065),.055,.07,'structure');joint(swivel,bpy.data.objects['Advanced | large crane hook shank'],'hook swivel mechanically captures chain and shank')
gate=beam('crane hook spring safety latch',(tip.x,tip.y-.024,.910),(tip.x,tip.y-.112,.787),.012,.020,'tool-steel',False);joint(gate,ob,'safety latch closes the hook throat')
pivot=cyl('crane hook latch pivot',(tip.x,tip.y-.024,.910),.023,.054,'aged-brass','X');joint(pivot,ob,'safety latch pivot seated in forged hook root')
bpy.context.view_layer.update()
(O/'crane-refinement.json').write_text(json.dumps(dict(scope='Shaped box girders, annular journal cheeks, stepped octagonal foundation, triangular load gussets, bored round strut guides and tapered forged hook with safety latch',modified=refined,placement_preserved=True,basic_module_untouched=True,native_function='Parked static cargo crane; no invented loader behavior',rod_radius=.0325,guide_bore_radius=.037,radial_running_clearance=.0045),indent=2)+'\n')
