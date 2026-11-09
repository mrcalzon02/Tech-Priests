"""V03: platform gantry, pressure sight pipes, resisting rams, heat and separate thrust FX."""
import argparse,bpy,math,json,pathlib,hashlib,sys
from mathutils import Vector,Matrix,Quaternion
from mathutils.bvhtree import BVHTree
from bpy_extras.object_utils import world_to_camera_view
p=argparse.ArgumentParser();p.add_argument('--source',type=pathlib.Path,required=True);p.add_argument('--textures',type=pathlib.Path,required=True);p.add_argument('--out',type=pathlib.Path,required=True);a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();assert sha(a.source)=='61f419d9c9c37dc74f02ecf5fb824461bb3bae11a52c8f9005575b4d4c8b4e74'
a.source=a.source.resolve();a.textures=a.textures.resolve()
bpy.ops.wm.open_mainfile(filepath=str(a.source));s=bpy.context.scene;s.frame_set(1);bpy.context.view_layer.update()
A=Vector((0,-math.cos(math.radians(25)),-math.sin(math.radians(25))));B=Vector((0,A.z,-A.y));X=Vector((1,0,0));O=Vector((0,.35,.2));F=1.25
def q(z,x=0,b=0):return (O+A*z+X*x+B*b)*F
def radial(t):return X*math.cos(t)+B*math.sin(t)
def point(z,r,t):return q(z)+radial(t)*r*F
old_static={o.name:[list(row) for row in o.matrix_world] for o in s.objects if o.type=='MESH' and not o.animation_data and not o.parent}
for o in s.objects:
 if o.animation_data:o.animation_data_clear()
removed=[]
for o in list(s.objects):
 if o.name.startswith(('Articulated actuator rod','Actuator fixed shoulder','Petal thermal liner')):removed.append(o.name);bpy.data.objects.remove(o,do_unlink=True)
body=bpy.data.collections.new('V03_RAISED_MACHINERY');s.collection.children.link(body);fx=bpy.data.collections.new('EXHAUST_FX_SEPARATE');s.collection.children.link(fx)
new=[];contacts=[];M={k:bpy.data.materials['Hydrogen '+k] for k in ['cast','tank','brass','steel','bell','dark']}
def basic(name,color,metal,rough,alpha=1,transmission=0,emission=0):
 m=bpy.data.materials.new(name);m.use_nodes=True;bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Metallic'].default_value=metal;bs.inputs['Roughness'].default_value=rough;bs.inputs['Alpha'].default_value=alpha;bs.inputs['Transmission Weight'].default_value=transmission;bs.inputs['IOR'].default_value=1.46;bs.inputs['Emission Color'].default_value=(*color,1);bs.inputs['Emission Strength'].default_value=emission
 if alpha<1 or transmission:m.surface_render_method='BLENDED'
 return m
M['chrome']=basic('V03 polished hydraulic shafts',(.48,.53,.55),1,.26)
M['seal']=basic('V03 pressure gland graphite seals',(.025,.027,.025),.10,.82)
M['glass']=basic('V03 hollow pressure sight glass',(.86,.96,1),0,.075,.26,.96)
M['fuel']=basic('V03 native Thetazine pressurized fuel',(.65,.04,.70),.05,.22,.82,.15,.24)
M['fuelpulse']=basic('V03 compressed fuel density fronts',(1,.25,.95),.05,.20,.88,.1,.7)
M['water']=basic('V03 water-side visible charge',(.04,.33,.52),0,.23,.62,.3,.12)
M['waterpulse']=basic('V03 water pressure fronts',(.22,.72,1),0,.22,.7,.15,.3)
def texture_mat(name,family):
 m=basic(name,(.2,.2,.2),.7,.5);nt=m.node_tree;bs=nt.nodes.get('Principled BSDF')
 for kind in ['basecolor','metalrough','normal','emission']:
  tex=nt.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(a.textures/(family+'-'+kind+'.png')),check_existing=True);tex.image.pack()
  if kind=='basecolor':nt.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
  elif kind=='metalrough':
   tex.image.colorspace_settings.name='Non-Color';sep=nt.nodes.new('ShaderNodeSeparateColor');nt.links.new(tex.outputs['Color'],sep.inputs['Color']);nt.links.new(sep.outputs['Green'],bs.inputs['Roughness']);nt.links.new(sep.outputs['Blue'],bs.inputs['Metallic'])
  elif kind=='normal':
   tex.image.colorspace_settings.name='Non-Color';n=nt.nodes.new('ShaderNodeNormalMap');n.inputs['Strength'].default_value=.35;nt.links.new(tex.outputs['Color'],n.inputs['Color']);nt.links.new(n.outputs['Normal'],bs.inputs['Normal'])
  else:nt.links.new(tex.outputs['Color'],bs.inputs['Emission Color'])
 return m
M['hotpetal']=texture_mat('V03 axial temper and charred bell petals','petal');M['refractory']=texture_mat('V03 charred inner refractory heat','refractory')
def image_mat(name,file,emission):
 m=basic(name,(1,1,1),0,.5,.3,0,emission);nt=m.node_tree;bs=nt.nodes.get('Principled BSDF');t=nt.nodes.new('ShaderNodeTexImage');t.image=bpy.data.images.load(str(a.textures/file),check_existing=True);t.image.pack();nt.links.new(t.outputs['Color'],bs.inputs['Base Color']);nt.links.new(t.outputs['Color'],bs.inputs['Emission Color']);nt.links.new(t.outputs['Alpha'],bs.inputs['Alpha']);return m
M['envelope']=image_mat('V03 violet-magenta exhaust envelope','exhaust-envelope.png',1.2);M['core']=image_mat('V03 white-hot cyan thrust core','exhaust-core.png',3)
M['diamond']=basic('V03 luminous pressure diamonds',(.52,.73,1),0,.4,.08,0,2)
M['dial']=image_mat('V03 containment pressure instrument','pressure-gauge.png',0);M['dial'].node_tree.nodes.get('Principled BSDF').inputs['Alpha'].default_value=1
def reg(o,name,mat,collection=body):
 o.name=name
 if mat:o.data.materials.append(M[mat])
 for c in list(o.users_collection):c.objects.unlink(o)
 collection.objects.link(o);o['render_component']='exhaust' if collection==fx else 'body';new.append(o);return o
def empty(name,collection=body):
 o=bpy.data.objects.new(name,None);collection.objects.link(o);return o
def mesh(name,verts,faces,mat,uvs=None,collection=body,smooth=False):
 me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update();o=bpy.data.objects.new(name,me);collection.objects.link(o);reg(o,name,mat,collection)
 for poly in me.polygons:poly.use_smooth=smooth
 if uvs:
  layer=me.uv_layers.new(name='Authored construction UV')
  for face,values in zip(me.polygons,uvs):
   for li,value in zip(face.loop_indices,values):layer.data[li].uv=value
 return o
def box(name,center,size,mat='cast',axis=None,bevel=.025):
 bpy.ops.mesh.primitive_cube_add(size=1,location=center);o=reg(bpy.context.object,name,mat);o.scale=size
 if axis:o.rotation_euler=Vector(axis).to_track_quat('Z','Y').to_euler()
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bevel:
  mod=o.modifiers.new('Machined plate edges','BEVEL');mod.width=bevel;mod.segments=2;o.modifiers.new('Weighted construction normals','WEIGHTED_NORMAL')
 return o
def cyl(name,start,end,r,mat='steel',sides=32):
 start=Vector(start);end=Vector(end);delta=end-start;bpy.ops.mesh.primitive_cylinder_add(vertices=sides,radius=r,depth=delta.length,location=(start+end)/2);o=reg(bpy.context.object,name,mat);o.rotation_mode='QUATERNION';o.rotation_quaternion=delta.to_track_quat('Z','Y')
 for face in o.data.polygons:face.use_smooth=len(face.vertices)==4
 return o
def tube(name,origin,axis,profile,mat='steel',sides=40,collection=body):
 axis=Vector(axis).normalized();u=X if abs(axis.dot(X))<.9 else Vector((0,1,0));u=(u-axis*axis.dot(u)).normalized();v=axis.cross(u);origin=Vector(origin);verts=[origin+axis*z+r*(math.cos(i*math.tau/sides)*u+math.sin(i*math.tau/sides)*v) for z,r in profile for i in range(sides)];faces=[];uv=[]
 for ring in range(len(profile)):
  other=(ring+1)%len(profile)
  for i in range(sides):faces.append((ring*sides+i,ring*sides+(i+1)%sides,other*sides+(i+1)%sides,other*sides+i));uv.append([(i/sides,ring/len(profile)),((i+1)/sides,ring/len(profile)),((i+1)/sides,(ring+1)/len(profile)),(i/sides,(ring+1)/len(profile))])
 return mesh(name,verts,faces,mat,uv,collection,True)
def pipe(name,points,r=.055,mat='brass'):
 cu=bpy.data.curves.new(name,'CURVE');cu.dimensions='3D';cu.resolution_u=10;cu.bevel_depth=r;cu.bevel_resolution=3;cu.use_fill_caps=True;sp=cu.splines.new('BEZIER');sp.bezier_points.add(len(points)-1)
 for point,value in zip(sp.bezier_points,points):point.co=value;point.handle_left_type='AUTO';point.handle_right_type='AUTO'
 o=bpy.data.objects.new(name,cu);body.objects.link(o);reg(o,name,mat);return o
def parent(o,root):o.parent=root;o.matrix_parent_inverse=root.matrix_world.inverted()
def pin(name,point,normal,r=.04):return cyl(name,point,Vector(point)+Vector(normal)*.045,r,'brass',6)
# Existing socket/ground frame is the invariant; added mass rises from those pads.
for sign in [-1,1]:
 foot=Vector((sign*1.6875,2.4206,0));box('V03 anchored platform pedestal '+str(sign),foot+Vector((0,0,.08)),(.68,.62,.16),'cast',bevel=.045)
 for dx in [-.24,.24]:
  for dy in [-.20,.20]:pin('V03 deck anchor stud',foot+Vector((dx,dy,.16)),Vector((0,0,1)),.047)
 box('V03 deep gantry upright '+str(sign),foot+Vector((0,0,1.08)),(.31,.40,1.84),'cast',bevel=.045)
 box('V03 raised stanchion crown '+str(sign),foot+Vector((0,0,2.03)),(.55,.55,.20),'steel',bevel=.035)
 for z in [.40,.86,1.33,1.77]:
  box('V03 upright reinforcing collar',foot+Vector((0,0,z)),(.42,.48,.105),'brass',bevel=.012)
  pin('V03 upright side keeper',foot+Vector((0,-.244,z)),Vector((0,-1,0)),.034)
 d0=foot+Vector((-sign*.10,-.22,.18));d1=Vector((sign*.96,2.2,1.95));strut=box('V03 triangulated gantry cheek', (d0+d1)/2,(.12,.20,(d1-d0).length),'steel',d1-d0,.018)
box('V03 overhead three-dimensional service bridge',(0,2.42,2.00),(3.86,.38,.25),'cast',bevel=.045)
box('V03 recessed bridge face',(0,2.205,2.00),(2.6,.08,.14),'dark',bevel=.012)
for x in [-1.5,-.95,-.4,.4,.95,1.5]:pin('V03 bridge face fastening',(x,2.16,2.00),Vector((0,-1,0)),.035)
for x in [-.925,.925]:
 cyl('V03 overhead regulator seat',Vector((x,2.4,2.13)),Vector((x,2.4,2.28)),.18,'brass');tube('V03 overhead regulator cap',(x,2.4,2.28),(0,0,1),[(0,.16),(0,.20),(.12,.20),(.12,.01)],'steel',32)
 pump_head=q(.63,x/F,.55)+B*(.63+.025)-A*.14
 pipe('V03 overhead routed distribution',[(x,2.4,2.22),(x,1.98,2.1),tuple(q(-.35,x/F,1.17)),tuple(pump_head)],.065,'brass')
# Raised injector/pump bridge is supported on the actual retained chamber bands.
bpy.context.view_layer.update();supports=[o for o in s.objects if o.type=='MESH' and o.name.startswith(('Pressure chamber retaining band','Diagonal shoulder','Actuator support clevis','Upper mounting beam'))];trees=[]
for obj in supports:trees.append((obj,BVHTree.FromPolygons([obj.matrix_world@v.co for v in obj.data.vertices],[list(p.vertices) for p in obj.data.polygons])))
assert trees
def saddle(name,target,tip):
 candidates=[(tree.find_nearest(Vector(target)),obj.name) for obj,tree in trees];hit,label=min(candidates,key=lambda item:item[0][3]);contact,normal,_,distance=hit;cyl(name+' actual seated riser',contact,tip,.095,'cast');tube(name+' seated weld collar',contact,normal,[(0,.08),(0,.15),(.05,.15),(.05,.08)],'steel',24);contacts.append({'name':name,'support':label,'surface_point':list(contact),'normal':list(normal),'tip':list(tip)});return contact
for sign in [-1,1]:saddle('V03 injector bridge support '+str(sign),q(2.05,sign*.45,.55),q(1.45,sign*.7,.80))
box('V03 elevated injector distribution plenum',q(1.38,0,.84),(2.12,.28,.22),'cast',B,.035)
for sign in [-1,1]:
 start=q(.45,sign*.74,.50);end=q(1.45,sign*.74,.80);box('V03 raised pump load rail '+str(sign),(start+end)/2,(.15,.15,(end-start).length),'steel',end-start,.018);saddle('V03 pump bed front seat '+str(sign),q(.45,sign*1.0,-.02),start)
pumps=[];needles=[];sights=[]
for sign,fluid in [(-1,'fuel'),(1,'water')]:
 base=q(.63,sign*.74,.55);head=base+B*.63;cyl('V03 vertical pressure intensifier '+str(sign),base,head,.17,'cast')
 for depth in [0,.12,.48,.63]:tube('V03 intensifier bolted head',base+B*depth,B,[(-.025,.15),(-.025,.215),(.025,.215),(.025,.15)],'brass',32)
 for xoff in [-.13,.13]:cyl('V03 intensifier tie rod',base+X*xoff,head+X*xoff,.023,'steel',20)
 plunger=cyl('V03 animated pump plunger '+str(sign),head-B*.08,head+B*.20,.071,'chrome');pumps.append((plunger,plunger.location.copy(),sign))
 box('V03 pump support pedestal',base-B*.07,(.40,.38,.15),'steel',B,.02)
 pipe('V03 pump injector outlet',[tuple(base+B*.10),tuple(q(.93,sign*.60,.98)),tuple(q(1.36,sign*.52,.925))],.055,'brass')
 a0=q(.02,sign*1.28,.94);a1=q(1.02,sign*1.28,.94);axis=(a1-a0).normalized();length=(a1-a0).length
 glass=tube('V03 transparent '+fluid+' pressure sight',a0,axis,[(0,.106),(length,.106),(length,.083),(0,.083)],'glass',48)
 core=cyl('V03 visible pressurized '+fluid,a0+axis*.045,a1-axis*.045,.073,fluid)
 for end in [a0,a1]:
  tube('V03 sight bolted metal collar',end,axis,[(-.07,.081),(-.07,.16),(.07,.16),(.07,.081)],'steel',40)
  for i in range(6):
   t=i*math.tau/6;offset=X*math.cos(t)+B*math.sin(t);offset=(offset-axis*offset.dot(axis)).normalized()*.135;pin('V03 sight collar fastener',end+offset+axis*.07,axis,.024)
 for offset in [-.10,.10]:cyl('V03 sight protective stay',a0+X*offset+B*.055,a1+X*offset+B*.055,.018,'steel',20)
 inlet=Vector((sign*1.92,1,.36));pipe('V03 sight supply branch '+fluid,[tuple(inlet),(sign*2.03,.63,.60),tuple(q(-.10,sign*1.30,.80)),tuple(a0)],.072,'tank')
 pipe('V03 sight injector return '+fluid,[tuple(a1),tuple(q(1.18,sign*1.25,1.05)),tuple(q(1.38,sign*.70,.925))],.072,'brass')
 for i in range(5):
  pulse=tube(f'V03 {fluid} pressure front {i}',a0,axis,[(-.027,.045),(-.027,.075),(.027,.075),(.027,.045)],fluid+'pulse',24);pulse.data.transform(Matrix.Translation(-a0));pulse.location=a0;sights.append((pulse,a0,axis,length,i,sign))
 # Gauge disk faces the inspection camera and has its own painted dial UVs.
 center=head-A*.32+B*.10
 cyl('V03 side-mounted pressure instrument case',center-B*.10,center+B*.005,.17,'steel')
 pipe('V03 seated gauge takeoff',[tuple(head-A*.08),tuple(head-A*.29),tuple(center-B*.08)],.055,'brass')
 verts=[center]+[center+(X*math.cos(i*math.tau/48)-A*math.sin(i*math.tau/48))*.15 for i in range(48)];faces=[];uvs=[]
 for i in range(48):faces.append((0,i+1,(i+1)%48+1));uvs.append([(.5,.5),(.5+math.cos(i*math.tau/48)*.5,.5+math.sin(i*math.tau/48)*.5),(.5+math.cos((i+1)*math.tau/48)*.5,.5+math.sin((i+1)*math.tau/48)*.5)])
 mesh('V03 pressure dial face '+str(sign),verts,faces,'dial',uvs);tube('V03 instrument bronze bezel',center-B*.025,B,[(0,.145),(0,.19),(.045,.19),(.045,.145)],'brass',48)
 needle=box('V03 moving containment gauge needle '+str(sign),center+X*.054+B*.012,(.112,.012,.012),'brass',None,.003);world=needle.matrix_world.copy();needle.location=center;needle.data.transform(Matrix.Translation(-center)@world);needle.rotation_mode='QUATERNION';needles.append((needle,sign))
 cyl('V03 gauge spindle',center,center+B*.045,.035,'steel',24)
# Re-surface the existing closed petals with physical axial UVs and heat maps.
petals=[];carrier=empty('V03 sliding bell containment carrier');carrier.location=(0,0,0);bpy.context.view_layer.update()
# Interleaved inner sealing leaves cover the openings between the primary
# rigid petals throughout expansion; they remain independent closed shells.
primaries=[obj for obj in s.objects if obj.name.startswith('Nozzle articulated petal')]
for original in primaries:
 index=int(original.name.rsplit(' ',1)[1]);theta=(index+.5)*math.tau/12;rotation=Quaternion(A,math.pi/12);axis_origin=q(3.16);pivot=point(3.16,.375,theta);data=original.data.copy()
 for v in data.vertices:
  world=axis_origin+rotation@(original.matrix_world@v.co-axis_origin);rel=world/F-O;rad=rel-A*rel.dot(A)
  if rad.length>1e-6:world-=rad.normalized()*.047
  v.co=world-pivot
 data.update();leaf=bpy.data.objects.new(f'V03 interleaved containment seal {index:02}',data);body.objects.link(leaf);leaf.location=pivot;leaf['sealing_leaf_theta']=theta;leaf['render_component']='body';new.append(leaf)
bpy.context.view_layer.update()
for obj in s.objects:
 if obj.name.startswith(('Nozzle articulated petal','V03 interleaved containment seal')):
  if obj not in new:new.append(obj)
  obj.rotation_mode='QUATERNION';obj.data.materials.clear();obj.data.materials.append(M['hotpetal']);obj.data.materials.append(M['refractory']);obj.data.materials.append(M['steel']);uv=obj.data.uv_layers.active
  index=int(obj.name.rsplit(' ',1)[1]);theta=obj.get('sealing_leaf_theta',index*math.tau/12);pivot=obj.location.copy();tangent=-X*math.sin(theta)+B*math.cos(theta)
  if 'sealing_leaf_theta' in obj:obj.data.materials[0]=M['refractory']
  for poly in obj.data.polygons:
   if abs((obj.matrix_world.to_3x3()@poly.normal).dot(tangent))>.98:poly.material_index=2
   for li in poly.loop_indices:
    world=obj.matrix_world@obj.data.vertices[obj.data.loops[li].vertex_index].co;v=world/F-O;z=v.dot(A);angle=math.atan2(v.dot(B),v.dot(X));u=angle/math.tau
    while u-index/12>.5:u-=1
    while u-index/12<-.5:u+=1
    uv.data[li].uv=(u,(z-3.16)/(5.22-3.16))
  parent(obj,carrier);petals.append((obj,pivot,tangent,theta))
bpy.context.view_layer.update()
aperture_points=[(obj,obj.matrix_world.inverted()@point(5.22,1.0,theta)) for obj,pivot,tangent,theta in petals if obj.name.startswith('Nozzle articulated petal')]
for obj in list(s.objects):
 if obj.name.startswith(('Petal throat hinge','Hinge keeper')):parent(obj,carrier)
tube('V03 fixed chrome telescoping throat sleeve',q(3.02),A,[(0,.40*F),(0,.53*F),(.92,.53*F),(.92,.40*F)],'chrome',64)
collar=tube('V03 floating containment carrier collar',q(3.16),A,[(-.10,.52*F),(-.10,.67*F),(.10,.67*F),(.10,.52*F)],'steel',64);parent(collar,carrier)
tube('V03 supported hydraulic distribution ring',q(2.38),A,[(-.05,.80*F),(-.05,.87*F),(.05,.87*F),(.05,.80*F)],'brass',64)
rams=[]
for index in range(6):
 theta=index*math.tau/6;rad=radial(theta);tan=-X*math.sin(theta)+B*math.cos(theta);petal=next(v[0] for v in petals if abs(v[3]-theta)<1e-5)
 fixed=saddle('V03 restraint ram seated saddle '+str(index),point(2.55,.64,theta),point(2.55,.82,theta));fixed=point(2.55,.82,theta)
 lug=point(4.20,.81,theta);skin=point(4.20,.675,theta);boss=cyl('V03 petal restraint lug neck '+str(index),skin,lug,.10,'cast');parent(boss,petal)
 eye=tube('V03 moving ram clevis eye '+str(index),lug-tan*.065,tan,[(0,.055),(0,.15),(.13,.15),(.13,.055)],'steel',40);parent(eye,petal)
 keeper=cyl('V03 moving restraint pin '+str(index),lug-tan*.105,lug+tan*.105,.052,'brass',24);parent(keeper,petal)
 for off in [-.13,.13]:box('V03 fixed ram clevis cheek',fixed+tan*off,(.16,.20,.28),'cast',A,.025)
 cyl('V03 fixed spherical restraint pin',fixed-tan*.22,fixed+tan*.22,.07,'steel',24)
 root=empty('V03 gimballed ram housing '+str(index));root.location=fixed;root.rotation_mode='QUATERNION';bpy.context.view_layer.update()
 # Geometry is authored in root-local +Z; the pose drives the housing axis.
 for name,z0,z1,radius,mat in [('pressure barrel',.10,1.00,.165,'cast'),('rear pressure cap',.02,.16,.205,'steel'),('forward gland',.98,1.12,.195,'steel'),('gland seal',1.11,1.15,.106,'seal'),('rear reinforcement',.24,.31,.195,'brass'),('front reinforcement',.84,.91,.195,'brass')]:
  part=cyl('V03 '+name+' '+str(index),fixed+Vector((0,0,z0)),fixed+Vector((0,0,z1)),radius,mat);parent(part,root)
 shaft=cyl('V03 telescoping chrome piston shaft '+str(index),fixed+Vector((0,0,.90)),fixed+Vector((0,0,2.1)),.071,'chrome');parent(shaft,root)
 # Side-feed enters the fixed swivel, not a floating barrel port.
 saddle('V03 hydraulic manifold standoff '+str(index),point(2.55,.64,theta),point(2.38,.81,theta))
 pipe('V03 restraint hydraulic feed '+str(index),[tuple(point(2.38,.84,theta)),tuple(point(2.47,.94,theta)),tuple(fixed+rad*.18),tuple(fixed)],.037,'brass')
 rams.append((index,root,shaft,fixed,petal,petal.matrix_world.inverted()@lug))
# Separately rendered emissive, tinted gas envelope/core with pressure deformation.
exhaust_root=empty('V03 oscillating thrust cone frame',fx);exhaust_root.rotation_mode='QUATERNION';exhaust_meshes=[]
def gas_mesh(name,length,radius,mat):
 rings=32;sides=48;verts=[];faces=[];uv=[]
 for j in range(rings+1):
  t=j/rings;rr=radius*(1-t)**.72*(1+.075*math.cos(t*math.tau*4));rr=max(rr,.006)
  for i in range(sides):angle=i*math.tau/sides;verts.append((rr*math.cos(angle),rr*math.sin(angle),length*t))
 for j in range(rings):
  for i in range(sides):faces.append((j*sides+i,j*sides+(i+1)%sides,(j+1)*sides+(i+1)%sides,(j+1)*sides+i));uv.append([(i/sides,j/rings),((i+1)/sides,j/rings),((i+1)/sides,(j+1)/rings),(i/sides,(j+1)/rings)])
 obj=mesh(name,verts,faces,mat,uv,fx,True);parent(obj,exhaust_root);exhaust_meshes.append((obj,length));return obj
gas_mesh('V03 shaped violet thrust envelope',4.4,1.05,'envelope');gas_mesh('V03 white-hot thrust core',3.9,.44,'core')
for i in range(4):
 z=.48+i*.76;radius=.29*(1-i*.16);diamond=tube('V03 pressure shock diamond '+str(i),(0,0,z),(0,0,1),[(-.35,.008),(0,radius),(.35,.008)],'diamond',40,fx);parent(diamond,exhaust_root)
# Convert authored pipe curves before assigning baked mesh data.
for index,obj in enumerate(list(new)):
 if obj.type=='CURVE':
  bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj;bpy.ops.object.convert(target='MESH');new[index]=bpy.context.object
# Snapshot evaluated geometry before graph mutation; preserve UVs and rig objects.
bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();snap=[]
for obj in new:
 ev=obj.evaluated_get(dg);data=ev.to_mesh(preserve_all_data_layers=True,depsgraph=dg).copy();ev.to_mesh_clear();snap.append((obj,data))
repairs=[]
for obj,data in snap:
 data.calc_loop_triangles();uv=data.uv_layers.active;assert uv is not None,obj.name;verts=[v.co.copy() for v in data.vertices];rows=[];fixed_uv=deleted=0
 for tri in data.loop_triangles:
  pts=[obj.matrix_world@verts[i] for i in tri.vertices];cross=(pts[1]-pts[0]).cross(pts[2]-pts[0])
  if cross.length/2<1e-10:deleted+=1;continue
  values=[tuple(uv.data[i].uv) for i in tri.loops];u=[values[1][k]-values[0][k] for k in range(2)];v=[values[2][k]-values[0][k] for k in range(2)]
  if abs(u[0]*v[1]-u[1]*v[0])/2<1e-8:
   # Thin bevel/end faces need a local planar island: subtract the first
   # corner before storing float32 UVs to avoid loss of tiny face area.
   normal=cross.normalized();omit=max(range(3),key=lambda i:abs(normal[i]));axes=[i for i in range(3) if i!=omit];values=[((p[axes[0]]-pts[0][axes[0]])*4,(p[axes[1]]-pts[0][axes[1]])*4) for p in pts];fixed_uv+=1
  rows.append((tuple(tri.vertices),tri.material_index,tri.use_smooth,values))
 me=bpy.data.meshes.new(obj.name+' evaluated triangles');me.from_pydata(verts,[],[row[0] for row in rows]);me.update()
 for mat in data.materials:me.materials.append(mat)
 layer=me.uv_layers.new(name='Authored UV')
 for face,row in zip(me.polygons,rows):
  face.material_index=row[1];face.use_smooth=row[2]
  for li,value in zip(face.loop_indices,row[3]):layer.data[li].uv=value
 obj.modifiers.clear();obj.data=me;bpy.data.meshes.remove(data);repairs.append({'part':obj.name,'numerical_triangles_removed':deleted,'uv_triangles_repaired':fixed_uv})
for obj,length in exhaust_meshes:
 obj.shape_key_add(name='Basis');bulge=obj.shape_key_add(name='Pressure-cell breathing');wobble=obj.shape_key_add(name='Shear-cone oscillation')
 for v0,v1,v2 in zip(obj.data.vertices,bulge.data,wobble.data):
  t=v0.co.z/length;scale=1+.12*math.sin(t*math.tau*4)*math.sin(math.pi*t);v1.co.x*=scale;v1.co.y*=scale;v2.co.x+=.09*math.sin(math.pi*t)*math.sin(t*math.pi*3);v2.co.y+=.06*math.sin(math.pi*t)*math.cos(t*math.pi*4)
states=[];ram_rows=[]
for frame in range(0,66):
 s.frame_set(frame)
 phi=((frame-1)%64)*math.tau/64;running=frame!=0;pressure=(.72+.17*math.sin(phi)+.085*math.sin(3*phi+.6)) if running else 0
 travel=(.25+.085*math.sin(phi-.55)+.025*math.sin(4*phi)) if running else 0;carrier.location=A*travel;carrier.keyframe_insert('location',frame=frame)
 for obj,pivot,tan,theta in petals:
  angle=(.070+.030*math.sin(phi-.15)+.012*math.sin(5*phi+theta*.4)+.007*math.sin(2*phi+theta)) if running else -.052
  obj.rotation_quaternion=Quaternion(tan,angle);obj.keyframe_insert('rotation_quaternion',frame=frame)
 bpy.context.view_layer.update()
 for index,root,shaft,fixed,petal,local_end in rams:
  end=petal.matrix_world@local_end;delta=end-fixed;length=delta.length;assert 1.65<length<2.8,(frame,index,length);root.rotation_quaternion=delta.to_track_quat('Z','Y');root.keyframe_insert('rotation_quaternion',frame=frame)
  rod_length=length-.08-.90;shaft.location=Vector((0,0,.90+rod_length/2));shaft.scale.z=rod_length/1.2;shaft.rotation_quaternion=Quaternion()
  # Parenting uses a fixed inverse translation from authoring in world Z.
  shaft.location+=fixed
  for field in ['location','scale','rotation_quaternion']:shaft.keyframe_insert(field,frame=frame)
  ram_rows.append({'frame':frame,'ram':index,'pin_to_pin':length,'exposed_shaft':length-.08-1.12,'barrel_overlap':.22})
 for obj,base,sign in pumps:obj.location=base+B*(.06*math.sin(2*phi+sign*.5)*pressure);obj.keyframe_insert('location',frame=frame)
 for obj,sign in needles:obj.rotation_quaternion=Quaternion(B,math.radians(-125+235*pressure+8*math.sin(4*phi+sign)));obj.keyframe_insert('rotation_quaternion',frame=frame)
 for obj,start,axis,length,index,sign in sights:
  t=(((frame-1)%64)/64*2+index/5+(0 if sign<0 else .25))%1 if running else index/5;obj.location=start+axis*(t*(length-.16)+.08);obj.keyframe_insert('location',frame=frame);window=min(1,t/.08,(1-t)/.08);obj.scale=(max(.001,window),)*3;obj.keyframe_insert('scale',frame=frame)
 for key in ['hotpetal','refractory']:
  bs=M[key].node_tree.nodes.get('Principled BSDF');bs.inputs['Emission Strength'].default_value=(.10+pressure*(.8 if key=='hotpetal' else 1.5)) if running else 0;bs.inputs['Emission Strength'].keyframe_insert('default_value',frame=frame)
 mouth=sum((obj.matrix_world@local for obj,local in aperture_points),Vector())/len(aperture_points)-A*.20;axis=(A+X*(.025*math.sin(3*phi)) +B*(.018*math.sin(5*phi+.3))).normalized() if running else A
 exhaust_root.location=mouth;exhaust_root.rotation_quaternion=axis.to_track_quat('Z','Y');exhaust_root.scale=(1+.07*math.sin(3*phi),1+.06*math.cos(4*phi),.90+.16*pressure) if running else (.0001,)*3
 for field in ['location','rotation_quaternion','scale']:exhaust_root.keyframe_insert(field,frame=frame)
 for obj,length in exhaust_meshes:
  for name,value in [('Pressure-cell breathing',(.5+.5*math.sin(3*phi))),('Shear-cone oscillation',(.5+.5*math.sin(5*phi+.7)))]:obj.data.shape_keys.key_blocks[name].value=value;obj.data.shape_keys.key_blocks[name].keyframe_insert('value',frame=frame)
 states.append({'frame':frame,'running':running,'pressure_visual':pressure,'carrier_extension':travel})
s.frame_start=1;s.frame_end=65;s.render.fps=30;s.frame_set(1);s.render.resolution_x=512;s.render.resolution_y=1280;s.camera.data.ortho_scale=18.75
target=Vector((0,-1.625,-.625))-Vector((0,1,1)).normalized()*1.4;s.camera.location=target+Vector((0,-15,15));s.camera.rotation_euler=(target-s.camera.location).to_track_quat('-Z','Y').to_euler()
s.cycles.device='CPU';s.cycles.samples=24;s.cycles.use_denoising=True;s.cycles.transmission_bounces=10;s.cycles.transparent_max_bounces=12;s.render.threads_mode='FIXED';s.render.threads=2;s.render.use_compositing=False
bpy.context.view_layer.update();registration=[]
for name,expected in [('fuel',[-80,-34]),('oxidizer',[80,-34])]:
 pt=bpy.data.objects['socket_'+name].matrix_world.translation;v=world_to_camera_view(s,s.camera,pt);pixel=[v.x*512,(1-v.y)*1280];scale=.46875;shift=[(expected[i]-(pixel[i]-[256,640][i])*scale)/32 for i in range(2)];registration.append({'name':name,'position':list(pt),'pixel':pixel,'shift':shift})
assert math.dist(registration[0]['shift'],registration[1]['shift'])<1e-5
s['V03_design']='Owner-requested raised platform gantry, layered pressure machinery, transparent pressurized Thetazine fuel, hot/charred restrained bell and separate large oscillating tinted thrust cone.'
bpy.ops.wm.save_as_mainfile(filepath=str(out/'thetazine-v03-pressure-study.blend'),compress=True)
for obj in s.objects:obj.select_set(obj.type=='MESH' or obj.type=='EMPTY')
bpy.ops.export_scene.gltf(filepath=str(out/'thetazine-v03-pressure-study.glb'),use_selection=True,export_format='GLB',export_apply=True,export_current_frame=True,export_animations=True,export_animation_mode='SCENE',export_anim_scene_split_object=False,export_frame_range=True,export_force_sampling=True,export_morph=True,export_morph_animation=True,export_extras=True)
manifest={'status':'V03_PRESSURE_AND_CONTAINMENT_CANDIDATE_REQUIRES_INDEPENDENT_EXPORT_AND_RENDER_REVIEW','input_native_sha256':sha(a.source),'builder_sha256':sha(pathlib.Path(__file__)),'native_sha256':sha(out/'thetazine-v03-pressure-study.blend'),'glb_sha256':sha(out/'thetazine-v03-pressure-study.glb'),'source_model_units':'Blender X east, +Y fore, +Z up; unchanged actual native pipe and ground frame','requested_features':['raised three-dimensional platform gantry and anchored pedestals','vertically layered pumps, manifolds and moving pressure gauges','hollow transparent pressure sight pipes with native magenta fuel and moving density fronts','six heavy telescoping containment rams with glands, shafts, clevises and pins','closed cold bell; extended/open oscillating bell under load','axial temper, persistent lip char, dynamic heated refractory','large separate violet/white thrust cone with animated shape keys and shock diamonds'],'mesh_count':sum(o.type=='MESH' for o in s.objects),'new_source_geometry':repairs,'removed_placeholder_parts':removed,'seated_support_contacts':contacts,'ram_pose_rows':ram_rows,'visual_states':states,'frame_contract':{'idle':0,'working':'1..64','wrap':65,'fps':30},'draw_registration':{'scale':.46875,'shift':registration[0]['shift'],'cell':[512,1280],'points':registration},'runtime_interfaces_changed':False,'native_game_integrated':False,'material_animation_scope':'Heat emission strengths authored for source renders; GLB transform/morph animation and packed PBR inspect independently.','exhaust_component':'EXHAUST_FX_SEPARATE collection; gas surfaces/morphs are an authored visual effect, not a fluid/thrust simulation.'}
(out/'source-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8',newline='\n');print('V03_BUILT',manifest['mesh_count'],flush=True)
