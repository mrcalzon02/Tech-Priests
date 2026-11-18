"""Second architectural study after owner rejection of the crude first pass.

Reuses only the original project's export/inspection utilities. New geometry,
regional wear, masonry courses, aperture normals and functional assemblies.
"""
import argparse, importlib.util, json, math, sys, hashlib
from pathlib import Path
import bpy,bmesh
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('factory_util',Path(__file__).with_name('build_faction_factories.py'))
b=importlib.util.module_from_spec(spec);spec.loader.exec_module(b)
OUT=ROOT/'art/source-to-3d/faction-factories-v4/candidates'

def material(name,base,rough=.75,metal=0,scale=12,grain=None):
 m=bpy.data.materials.new(name);m.use_nodes=True;n=m.node_tree.nodes;l=m.node_tree.links;p=n.get('Principled BSDF')
 coord=n.new('ShaderNodeTexCoord');noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=scale;noise.inputs['Detail'].default_value=5;noise.inputs['Roughness'].default_value=.72
 vector=coord.outputs['Object']
 if grain:
  v=n.new('ShaderNodeVectorMath');v.operation='MULTIPLY';v.inputs[1].default_value=grain;l.new(vector,v.inputs[0]);vector=v.outputs[0]
 l.new(vector,noise.inputs['Vector'])
 ramp=n.new('ShaderNodeValToRGB')
 for stop,mul in zip(ramp.color_ramp.elements,[.5,1.35]):stop.color=tuple(min(1,c*mul) for c in base)+(1,)
 l.new(noise.outputs['Fac'],ramp.inputs[0])
 geometry=n.new('ShaderNodeNewGeometry');edge=n.new('ShaderNodeValToRGB');edge.color_ramp.elements[0].position=.48;edge.color_ramp.elements[1].position=.56
 edge.color_ramp.elements[1].color=(.10,.10,.10,1)
 l.new(geometry.outputs['Pointiness'],edge.inputs[0])
 mix=n.new('ShaderNodeMixRGB');mix.blend_type='MIX';l.new(edge.outputs['Color'],mix.inputs[0]);l.new(ramp.outputs['Color'],mix.inputs[1])
 mix.inputs[2].default_value=tuple(min(1,c*.6+.08) for c in base)+(1,)
 if metal>.15:mix.inputs[2].default_value=(.22,.23,.22,1)
 ao=n.new('ShaderNodeAmbientOcclusion');ao.inputs['Distance'].default_value=.26
 darken=n.new('ShaderNodeMixRGB');darken.blend_type='MULTIPLY';darken.inputs[0].default_value=.72;l.new(mix.outputs[0],darken.inputs[1]);l.new(ao.outputs['Color'],darken.inputs[2]);l.new(darken.outputs[0],p.inputs['Base Color'])
 p.inputs['Metallic'].default_value=metal
 rr=n.new('ShaderNodeMapRange');rr.inputs['To Min'].default_value=max(.3,rough-.18);rr.inputs['To Max'].default_value=min(.98,rough+.14);l.new(noise.outputs['Fac'],rr.inputs[0]);l.new(rr.outputs[0],p.inputs['Roughness'])
 bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.35;bump.inputs['Distance'].default_value=.014 if metal else .035;l.new(noise.outputs['Fac'],bump.inputs['Height']);l.new(bump.outputs[0],p.inputs['Normal'])
 return m

b.material=material
oldarch=b.arch
def fixed_arch(*args,**kwargs):
 o=oldarch(*args,**kwargs);bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free();return o
b.arch=fixed_arch

def rivets(a,z,y,xspan,mat,n=8):
 for i in range(n):b.cyl('Seated hex rivet',(a-xspan/2+xspan*i/(n-1),y,z),.022,.022,mat,6,'Y')

def floor(tiles,mat,edge,metal):
 half=tiles/2
 b.box('Cast stepped foundation',(0,0,.09),(tiles-.12,tiles-.12,.18),edge,.06)
 for ix in range(tiles):
  for iy in range(tiles):b.box('Individual inset floor slab',(-half+.5+ix,-half+.5+iy,.2),(.965,.965,.08),mat,.018)
 for x in [-half+.13,half-.13]:b.box('Foundation edge flashing',(x,0,.245),(.07,tiles-.2,.035),metal,.01)

def shutter(x,y,z,w,h,steel,dark,frame):
 b.box('Door shadow recess',(x,y+.16,z+h/2),(w,.08,h),dark,.012)
 for i in range(round(h/.12)):
  b.box('Rolled and interlocking shutter slat',(x,y,z+.06+i*.12),(w,.08,.095),steel,.012)
 for dx in [-w/2-.05,w/2+.05]:b.box('Bolted door slide guide',(x+dx,y-.04,z+h/2),(.09,.15,h+.15),frame,.015)
 b.box('Door lintel track',(x,y-.04,z+h+.09),(w+.25,.23,.16),frame,.025)
 rivets(x,z+h+.095,y-.17,w,steel,8)

def flange(center,radius,axis,steel,bolt):
 verts=[];count=24
 for end in [-.045,.045]:
  for rr in [radius,radius*.61]:
   for i in range(count):
    a=i*math.tau/count;u,v=rr*math.cos(a),rr*math.sin(a)
    q=(u,v,end) if axis=='Z' else (u,end,v) if axis=='Y' else (end,u,v)
    verts.append(tuple(center[j]+q[j] for j in range(3)))
 faces=[]
 for i in range(count):
  k=(i+1)%count
  faces.extend([(i,k,2*count+k,2*count+i),(count+i,3*count+i,3*count+k,count+k),
                (i,count+i,count+k,k),(2*count+i,2*count+k,3*count+k,3*count+i)])
 mesh=bpy.data.meshes.new('Bored flange');mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new('Machined open-bore flange',mesh);bpy.context.collection.objects.link(o);b.finish(o,o.name,steel,.008)
 x,y,z=center
 for i in range(8):
  a=i*math.tau/8
  if axis=='Z':b.cyl('Flange stud',(x+radius*.78*math.cos(a),y+radius*.78*math.sin(a),z+.06),.025,.035,bolt,6)
  elif axis=='Y':b.cyl('Flange stud',(x+radius*.78*math.cos(a),y-.06,z+radius*.78*math.sin(a)),.025,.035,bolt,6,'Y')
  else:b.cyl('Flange stud',(x+.06,y+radius*.78*math.cos(a),z+radius*.78*math.sin(a)),.025,.035,bolt,6,'X')

def vault(name,width,length,eave,rise,mat,y=0):
 # Curved, closed pressed-metal roof shells, with real sheet joints.
 n=12
 for j in range(5):
  y0=y-length/2+j*length/5+.008;y1=y-length/2+(j+1)*length/5-.008
  verts=[]
  for dz in [0,-.09]:
   for yy in [y0,y1]:
    for i in range(n+1):
     t=-math.pi/2+i*math.pi/n;verts.append((width/2*math.sin(t),yy,eave+rise*math.cos(t)+dz))
  row=n+1;faces=[]
  for i in range(n):
   faces.extend([(i,i+1,row+i+1,row+i),(2*row+i,3*row+i,3*row+i+1,2*row+i+1),
                 (i,2*row+i,2*row+i+1,i+1),(row+i,row+i+1,3*row+i+1,3*row+i)])
  faces.extend([(0,row,3*row,2*row),(n,2*row+n,3*row+n,row+n)])
  mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new(name+' sheet '+str(j),mesh);bpy.context.collection.objects.link(o);b.finish(o,o.name,mat,.01)

def hose(name,points,r,mat,collar):
 b.path(name,points,r,mat)
 for i,p in enumerate(points[1:-1]):b.torus(name+' elbow retaining bead',p,r*1.08,r*.2,collar)

def hazard(x,y,w,metal,paint):
 b.box('Hazard sill backing',(x,y,.30),(w,.3,.07),metal,.012)
 for i in range(round(w/.16)):
  o=b.box('Painted loading sill stripe',(x-w/2+.08+i*.16,y,.343),(.07,.27,.012),paint,.003);o.rotation_euler.z=-.35

def servo_arm(iron,copper,paint,chrome,black):
 """Static industrial manipulator with mechanically readable linked assemblies."""
 A=Vector((.65,-1.23,1.98));B=Vector((.32,-1.23,1.59));C=Vector((.05,-1.23,1.32))
 def pin(name,point,r,depth,mat):
  return b.cyl(name,point,r,depth,mat,24,'Y')
 def fasteners(point,r,depth,mat,count=8):
  for i in range(count):
   t=i*math.tau/count;pin('Servo gearbox cover screw',(point.x+r*math.cos(t),point.y-depth/2-.015,point.z+r*math.sin(t)),.016,.027,mat)
 def channel(name,start,end,wa,wb):
  axis=(end-start).normalized();across=axis.cross(Vector((0,1,0))).normalized();normal=across.cross(axis).normalized()
  for side in [-1,1]:
   outline=[(0,-wa),(.12,-wa),(.85,-wb),(1,-wb),(1,wb),(.85,wb),(.12,wa),(0,wa)]
   verts=[]
   for d in [side*.10-.023,side*.10+.023]:
    for t,u in outline:verts.append(tuple(start+(end-start)*t+across*u+normal*d))
   n=len(outline);faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
   mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new(name+' fork side '+str(side),mesh);bpy.context.collection.objects.link(o);b.finish(o,o.name,paint,.012)
   bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
   # Real inspection/lightening hole through each cheek, with a machined rim.
   hole=start+(end-start)*.48+normal*side*.10
   cutter=b.cyl('Servo plate drill',hole,min(wa,wb)*.46,.14,black,16)
   cutter.rotation_euler=normal.to_track_quat('Z','Y').to_euler()
   bpy.context.view_layer.objects.active=o;mod=o.modifiers.new('Lightening and access bore','BOOLEAN');mod.operation='DIFFERENCE';mod.object=cutter;bpy.ops.object.modifier_apply(modifier=mod.name);b.PARTS.remove(cutter);bpy.data.objects.remove(cutter,do_unlink=True)
  for t in [.18,.72]:
   q=start+(end-start)*t
   rib=b.box(name+' internal cross-web',q,(.13,.20,.07),iron,.012);rib.rotation_euler=axis.to_track_quat('Z','Y').to_euler()
  # Visible bright flange along the lower edge makes the C-channel legible.
  b.beam(name+' exposed machined edge',start-across*wa,end-across*wb,.014,chrome,8)
 # Rail, bolted saddle, rack drive and bearing-supported carriage.
 for xx in [-.87,.87]:
  b.box('Gantry rail end bracket',(xx,-1.15,2.10),(.17,.27,.25),iron,.025)
 b.box('Gantry I-beam web',(0,-1.16,2.12),(1.8,.12,.13),iron,.015)
 for zz in [2.04,2.20]:b.box('Gantry machined rail flange',(0,-1.16,zz),(1.85,.3,.045),chrome,.008)
 for i in range(19):b.box('Gantry drive rack tooth',(-.81+i*.09,-1.34,2.14),(.042,.045,.08),iron,.004)
 b.box('Servo carriage saddle',(.65,-1.17,2.04),(.38,.40,.18),paint,.04)
 for xx in [.5,.8]:
  for yy in [-1.32,-1.02]:b.cyl('Carriage hold-down bolt',(xx,yy,2.15),.024,.035,chrome,6)
 # Shoulder motor has its own cast housing, cooling fins and a pinned drive hub.
 pin('Shoulder reduction gearbox',A,.19,.32,iron)
 pin('Shoulder removable bronze cover',(A.x,A.y-.18,A.z),.164,.055,copper)
 fasteners(A,.137,.38,chrome)
 pin('Shoulder output shaft',(A.x,A.y-.225,A.z),.07,.08,chrome)
 for z in [1.88+i*.045 for i in range(5)]:b.box('Motor cooling fin',(.79,-1.05,z),(.18,.22,.022),iron,.006)
 b.box('Motor terminal housing',(.83,-1.18,1.99),(.15,.15,.13),black,.02)
 channel('Upper servo link',A,B,.13,.105)
 pin('Elbow bearing housing',B,.15,.34,iron)
 pin('Elbow service cover',(B.x,B.y-.19,B.z),.128,.05,copper)
 fasteners(B,.103,.4,chrome,6)
 pin('Elbow axle end',(B.x,B.y-.23,B.z),.05,.055,chrome)
 channel('Forearm servo link',B,C,.105,.075)
 # Offset actuator with a separate barrel, bright piston rod and pinned clevis.
 D=A+Vector((.12,-.04,-.04));E=B+Vector((.18,-.04,-.04));axis=(E-D).normalized();mid=D+(E-D)*.63
 b.beam('Actuator pressure barrel',D,mid,.052,iron,20)
 b.beam('Exposed polished actuator piston',mid-axis*.08,E,.023,chrome,16)
 for q in [D,E]:
  for offset in [-.045,.045]:b.box('Actuator clevis ear',(q.x,q.y+offset,q.z),(.09,.035,.11),paint,.012)
  pin('Actuator clevis cross-pin',q,.026,.16,chrome)
 # Wrist yaw drive, tool-changing flange, drive screws and gripper slide block.
 pin('Wrist pitch bearing',C,.095,.25,iron)
 pin('Wrist bearing cap',(C.x,C.y-.15,C.z),.073,.045,copper)
 fasteners(C,.058,.31,chrome,6)
 b.box('Wrist yaw motor housing',(C.x,C.y,C.z-.08),(.20,.18,.15),paint,.025)
 b.cyl('Wrist rotary coupling',(C.x,C.y,C.z-.17),.10,.07,iron,24)
 for i in range(6):
  t=i*math.tau/6;b.cyl('Tool flange captive screw',(C.x+.072*math.cos(t),C.y+.072*math.sin(t),C.z-.205),.012,.022,chrome,6)
 b.box('Parallel gripper lead-screw slide',(C.x,-1.08,1.08),(.38,.23,.12),iron,.018)
 b.beam('Gripper lead screw',(-.17,-1.21,1.08),(.27,-1.21,1.08),.022,chrome,16)
 for side in [-1,1]:
  b.box('Gripper sliding carriage',(side*.205,-1.08,1.065),(.09,.22,.12),copper,.012)
  b.box('Gripper structural jaw',(side*.245,-1.04,.98),(.075,.20,.24),iron,.012)
  b.box('Replaceable gripping pad',(side*.205,-1.015,.955),(.025,.14,.14),black,.005)
  for z in [.91,.96,1.01]:b.box('Gripper pad tooth',(side*.189,-1.02,z),(.018,.13,.014),chrome,.003)
 # Continuous flexible conduits terminate at real motor boxes and wrist glands.
 def cable(name,points,r,mat):
  curve=bpy.data.curves.new(name,'CURVE');curve.dimensions='3D';curve.resolution_u=12;curve.bevel_depth=r;curve.bevel_resolution=3
  spline=curve.splines.new('BEZIER');spline.bezier_points.add(len(points)-1)
  for p,q in zip(spline.bezier_points,points):p.co=q;p.handle_left_type=p.handle_right_type='AUTO'
  obj=bpy.data.objects.new(name,curve);bpy.context.collection.objects.link(obj);b.finish(obj,name,mat)
 cable('Servo power conduit',[(.83,-1.20,2.00),(.68,-1.57,1.97),(.42,-1.67,1.79),(.16,-1.62,1.52),(.05,-1.37,1.32)],.022,black)
 cable('Servo sensor line',[(.78,-1.22,1.99),(.61,-1.51,1.92),(.35,-1.59,1.73),(.1,-1.52,1.46),(.04,-1.36,1.26)],.011,copper)
 for q in [(.83,-1.20,2.00),(.05,-1.37,1.32)]:pin('Cable gland',Vector(q),.036,.08,chrome)
 bpy.context.scene['servo_joint_frames']=json.dumps({'shoulder':list(A),'elbow':list(B),'wrist':list(C),'actuator_base':list(D),'actuator_end':list(E),
  'construction':'paired cheek plates, physical bores, cross-webs, bearing caps, actuator barrel/rod/clevis, wrist reducer and lead-screw gripper',
  'state':'static posed source, not an animated or load-rated industrial robot'})
 bpy.context.scene['preserve_components']=True

def martian(m):
 red,iron,copper,stone,black,glass=m
 warm=material('martian warm hazard enamel',(.57,.35,.055),.78,.05,25)
 pale=material('martian edge chips and old primer',(.32,.28,.22),.82,.1,35)
 floor(4,stone,iron,iron)
 # Roof starts further back: the tall front bay exposes genuine production gear.
 b.box('Rear reinforced shell',(0,1.35,1.27),(2.9,.2,2.04),red,.07)
 for side in [-1,1]:
  x=side*1.35
  b.box('Factory load-bearing flank',(x,.12,1.28),(.19,2.55,2.06),red,.05)
  for y in [-1.05,-.38,.3,.98,1.33]:
   b.box('Cast vertical stanchion',(x+side*.10,y,1.32),(.15,.14,2.16),iron,.02)
   for z in [.4,1.1,1.8,2.25]:b.cyl('Stanchion anchor',(x+side*.13,y,z),.032,.04,copper,6,'X')
  b.box('Side sill rail',(x+side*.11,.12,.43),(.16,2.7,.14),iron,.025)
  for y in [-.7,.2,1.06]:
   b.box('Removable red machine access cover',(x+side*.125,y,1.18),(.05,.5,.95),red,.025)
   b.box('Access cover bottom wear strip',(x+side*.16,y,.75),(.04,.47,.08),pale,.005)
 # Hollow portal: external piers carry a high beam and the bowed iron vault.
 for x in [-1.12,1.12]:
  b.box('Portal footing',(x,-1.18,.52),(.5,.45,.5),iron,.06)
  b.box('Portal pillar',(x,-1.15,1.36),(.32,.35,1.8),iron,.035)
  b.box('Red pillar face',(x,-1.35,1.4),(.21,.05,1.48),red,.02)
 b.box('Production bay crossbeam',(0,-1.16,2.25),(2.75,.43,.25),iron,.045)
 b.box('Production bay wear strip',(0,-1.4,2.3),(2.7,.04,.045),pale,.008)
 rivets(0,2.24,-1.39,2.55,copper,15)
 b.box('Production bay deep floor',(0,-.7,.36),(1.83,1.25,.16),iron,.02)
 b.box('Rear production cell shade',(0,.75,1.25),(2.2,.12,1.8),black)
 # A workstation, turntable and hanging manipulator, all attached to supports.
 b.cyl('Assembly fixture plinth',(0,-1.0,.55),.48,.22,iron)
 b.cyl('Assembly fixture indexing ring',(0,-1.0,.69),.39,.06,copper)
 for i in range(8):
  a=i*math.tau/8;b.cyl('Indexing fixture bolt',(.33*math.cos(a),-1.0+.33*math.sin(a),.74),.025,.035,pale,8)
 b.box('Fixture workpiece',(0,-1.0,.95),(.42,.3,.45),pale,.07)
 servo_arm(iron,copper,red,pale,black)
 vault('Curved armoured manufacture roof',2.98,2.47,2.31,.48,red,.21)
 # Structural arch ribs follow the actual curved roof and end on side stanchions.
 for y in [-1.05,-.4,.27,.94,1.42]:
  pts=[]
  for i in range(13):
   t=-math.pi/2+i*math.pi/12;pts.append((1.51*math.sin(t),y,2.34+.49*math.cos(t)))
  for a,z in zip(pts,pts[1:]):b.beam('Pressed iron vault rib',a,z,.045,iron,8)
 for side in [-1,1]:b.box('Roof gutter',(side*1.53,.2,2.33),(.13,2.65,.11),iron,.025)
 # Off-centre power stacks, with proper caps, flanges and weathered sleeves.
 for x,y,h in [(-.74,.92,3.46),(-.1,1.1,3.23)]:
  b.cyl('Exhaust pier',(x,y,2.68),.25,.18,iron)
  b.cyl('Copper exhaust stack',(x,y,(2.7+h)/2),.15,h-2.7,copper)
  flange((x,y,h-.12),.21,'Z',iron,pale)
  b.cyl('Sooty stack throat',(x,y,h),.12,.035,black)
  b.cyl('Rain cap',(x,y,h+.08),.24,.045,iron)
  for angle in [0,math.pi/2,math.pi,3*math.pi/2]:b.beam('Rain cap leg',(x+.18*math.cos(angle),y+.18*math.sin(angle),h-.06),(x+.18*math.cos(angle),y+.18*math.sin(angle),h+.07),.012,iron)
 # Side extraction fan is bolted to a real air box and connected to rear conduit.
 b.box('Side airbox',(1.58,.55,1.48),(.32,1.02,1.05),iron,.07)
 b.cyl('Side fan dark cavity',(1.78,.55,1.48),.41,.07,black,32,'X')
 for i in range(9):
  a=i*math.tau/9;o=b.box('Extraction fan vane',(1.83,.55+.22*math.cos(a),1.48+.22*math.sin(a)),(.045,.32,.09),pale,.01);o.rotation_euler.x=a+.25
 b.cyl('Fan hub',(1.86,.55,1.48),.09,.07,copper,16,'X')
 flange((1.88,.55,1.48),.45,'X',iron,copper)
 hose('Exterior coolant copper',[(-1.6,-.45,.44),(-1.6,-.45,1.8),(-1.6,.85,1.8),(-1.6,1.12,1.12)],.06,copper,iron)
 for y in [-.2,.7]:b.box('Coolant pipe saddle',(-1.5,y,1.8),(.22,.11,.18),iron)
 # Panelled dispatch console, glass face and separate physical controls.
 b.box('Cogitator console housing',(-1.15,-1.6,.97),(.45,.38,.87),iron,.055)
 screen=b.box('Recessed green display',(-1.15,-1.81,1.13),(.31,.035,.25),glass,.018)
 for x in [-1.25,-1.15,-1.05]:b.cyl('Panel rotary switch',(x,-1.84,.87),.027,.025,copper,10,'Y')
 for z in [1.04,1.12,1.2]:b.box('Display scan line',(-1.17,-1.84,z),(.2,.013,.008),pale,.001)
 lamp=material('martian warm workshop lamp',(.65,.32,.07),.5,0,40)
 principal=lamp.node_tree.nodes.get('Principled BSDF');principal.inputs['Emission Color'].default_value=(1,.46,.1,1);principal.inputs['Emission Strength'].default_value=3
 b.box('Shielded workshop lamp',(0,-1.08,2.10),(.72,.08,.055),lamp,.01)
 ld=bpy.data.lights.new('Workshop task light','POINT');ld.energy=22;ld.color=(1,.58,.24);ld.shadow_soft_size=.15
 lo=bpy.data.objects.new('Workshop task light',ld);bpy.context.scene.collection.objects.link(lo);lo.location=(0,-.7,1.88)
 b.torus('Authored manufacturing cog',(0,-1.42,2.33),.18,.045,copper,'Y')
 for i in range(10):
  a=i*math.tau/10;o=b.box('Cog tooth',(.235*math.cos(a),-1.42,2.33+.235*math.sin(a)),(.09,.08,.08),iron,.01);o.rotation_euler.y=-a
 hazard(0,-1.59,1.72,iron,warm)
 # Individual drainage slots and bolted foundation plates survive all views.
 for x in [-.7+i*.14 for i in range(11)]:b.box('Loading drain slot',(x,-1.84,.255),(.07,.18,.018),black,.006)

def guard(m):
 olive,iron,tan,stone,wood,glass=m
 roofdark=material('guard charcoal roof underlay',(.045,.05,.04),.9,.1,26)
 light=material('guard worn stencilling enamel',(.63,.59,.42),.87,.03,40)
 canvas=material('guard canvas weave',(.22,.25,.12),.96,0,140,(1,8,8))
 floor(5,stone,iron,iron)
 # A longer central hall and lower offset loading annex, instead of one box.
 b.box('Main hall lower masonry',(0,.25,.58),(3.65,3.75,.66),stone,.045)
 hall=b.box('Main hollow hall',(0,.25,1.42),(3.65,3.75,1.4),tan,.04)
 b.cut_arch(hall,(0,-1.62,.32),1.52,1.65,1.0,iron)
 shutter(0,-1.66,.33,1.48,1.45,olive,roofdark,iron)
 for side in [-1,1]:
  x=side*1.85
  for y in [-1.45,-.68,.1,.88,1.65,2.05]:
   b.box('Steel wall upright',(x,y,1.26),(.14,.12,1.77),iron,.018)
   for z in [.5,1.25,2.05]:b.cyl('Frame anchor',(x+side*.08,y,z),.027,.025,light,6,'X')
  for y in [-1.02,-.2,.65,1.48]:
   b.box('Side window rebate',(x,y,1.5),(.12,.58,.6),roofdark,.018)
   b.box('Dusty wireglass',(x+side*.075,y,1.5),(.045,.48,.49),glass,.012)
   for dz in [-.16,.16]:b.box('Side glass transverse brace',(x+side*.11,y,1.5+dz),(.025,.55,.025),iron,.004)
  for z in [.87,1.92]:b.box('Horizontal hall panel rail',(x,.25,z),(.1,3.67,.07),olive,.012)
 for y in [-1.65,2.15]:b.gable('Framed gable',y,3.8,.18,2.1,.8,tan)
 b.roof('Seamed olive roof',0,.25,4.1,4.18,2.12,.83,roofdark)
 for side in [-1,1]:
  for j in range(20):
   yy=-1.76+j*.207
   o=b.box('Individual pressed roof sheet',(side*1.025,yy,2.62),(2.24,.192,.06),olive,.018);o.rotation_euler.y=side*math.atan2(.83,2.05)
   b.beam('Standing steel roof joint',(side*.025,yy,3.02),(side*2.07,yy,2.18),.018,iron,8)
 b.box('Ridge flashing',(0,.25,3.02),(.15,4.25,.09),iron,.02)
 for side in [-1,1]:
  b.box('Rain gutter',(side*2.1,.25,2.14),(.12,4.35,.12),iron,.03)
  hose('Rain downpipe',[(side*2.12,1.92,2.13),(side*2.12,2.14,1.96),(side*2.12,2.14,.4)],.045,iron,olive)
 # Factory ridge monitors, actual slatted louvers and short radio mast.
 for yy in [-.58,1.05]:
  b.box('Roof monitor plinth',(0,yy,3.06),(.85,.8,.12),iron)
  b.box('Ridge air monitor',(0,yy,3.27),(.7,.7,.36),olive,.025)
  for z in [3.16,3.25,3.34]:b.box('Louvre grille',(0,yy-.37,z),(.58,.055,.035),roofdark,.005)
  b.box('Monitor pitched cap',(0,yy,3.5),(.95,.95,.09),iron,.02)
 b.beam('Radio mast',(.1,1.05,3.55),(.1,1.05,3.86),.018,iron)
 for yy in [.8,1.05,1.3]:b.beam('Aerial transverse element',(-.23,yy,3.76),(.43,yy,3.76),.012,iron)
 # Porch, timber-backed notice case, supply dispatch canopy and racks.
 for x in [-.92,.92]:b.box('Entry porch post',(x,-1.98,1.12),(.12,.12,1.7),iron)
 porch=b.box('Supported entrance canopy',(0,-1.97,2.04),(2.0,.68,.09),olive,.03);porch.rotation_euler.x=.1
 for x in [-1.35,1.35]:
  b.box('Front black window rebate',(x,-1.66,1.48),(.52,.1,.58),roofdark)
  b.box('Front window glass',(x,-1.72,1.48),(.41,.025,.46),glass,.012)
  for dx in [-.14,0,.14]:b.box('Front window security bar',(x+dx,-1.75,1.48),(.025,.03,.52),iron,.004)
 b.box('Door transom lintel',(0,-1.75,1.98),(1.8,.1,.14),iron)
 rivets(0,1.99,-1.82,1.6,light,10)
 for side in [-1,1]:b.beam('Military insignia chevron',(0,-1.8,2.62),(side*.32,-1.8,2.36),.055,light,8)
 for j in range(5):
  x=-1.8+j*.21
  b.box('Stacked equipment crate',(x,-2.12,.47),(.2,.35,.42),wood,.025)
  b.box('Crate strap',(x,-2.305,.47),(.045,.025,.43),iron,.004)
 # A separately supported draped canvas lean-to, with tension and seams.
 for x in [-1.9,-.8]:b.beam('Canvas shelter pole',(x,-2.28,.26),(x,-2.28,1.48),.025,iron)
 for k in range(6):
  x=-1.9+k*.22;b.beam('Canvas support rib',(x,-1.83,1.72),(x,-2.32,1.5),.018,iron)
  o=b.box('Draped canvas panel',(x+.08,-2.07,1.61),(.205,.55,.025),canvas,.008);o.rotation_euler.x=.4
 for row in range(2):
  for i in range(3):
   x=.93+i*.43+(row%2)*.09;b.box('Linen sandbag',(x,-2.15,.36+row*.2),(.46,.34,.22),tan,.09)
   b.box('Sandbag stitched seam',(x,-2.33,.38+row*.2),(.34,.014,.014),wood,.004)
 for i in range(8):b.box('Entrance drain slot',(-.56+i*.16,-2.32,.25),(.07,.16,.018),roofdark,.004)
 # Rear equipment access is articulated, avoiding a blank return elevation.
 shutter(.65,2.18,.3,1.25,1.42,olive,roofdark,iron)
 b.box('Rear dispatch awning',(.65,2.25,1.91),(1.6,.35,.08),iron)
 b.box('Power distribution box',(-1.1,2.22,1.08),(.6,.18,.8),olive,.035)
 for x in [-1.22,-1.0]:b.path('Electrical service conduit',[(x,2.33,.38),(x,2.33,.9)],.025,iron)

def stone_courses(name,center,width,height,mat,mortar,axis='Y',skip=None):
 x,y,z=center;stepz=.23;stepx=.42
 for row in range(int(height/stepz)):
  for col in range(math.ceil(width/stepx)):
   u=-width/2+stepx/2+col*stepx+(row%2)*.20
   if u+stepx/2>width/2:continue
   v=.115+row*stepz
   if skip and skip(u,v):continue
   loc=(x+u,y,z+v) if axis=='Y' else (x,y+u,z+v)
   dims=(.399,.045,.207) if axis=='Y' else (.045,.399,.207)
   b.box(name+' individual ashlar',loc,dims,mat,.012)

def sororitas(m):
 stone,dark,roofmat,bronze,glass,red=m
 felt=material('sororitas charcoal roof felt',(.035,.026,.027),.96,0,40)
 pale=material('sororitas pale carved trim',(.59,.53,.42),.86,0,18)
 doorwood=material('sororitas smoked oak portal',(.105,.064,.035),.89,0,18,(10,10,1))
 ruby=material('sororitas ruby glass',(.34,.025,.035),.36,.1,55)
 floor(6,dark,dark,bronze)
 # Nave masonry is built around real apertures, with ashlar facing courses.
 sidewalls=[]
 for x in [-1.52,1.52]:sidewalls.append(b.box('Nave structural side wall',(x,.08,1.75),(.25,4.25,2.7),dark,.015))
 front=b.box('West entrance structural wall',(0,-2.04,1.75),(3.3,.25,2.7),dark,.015)
 rear=b.box('East end structural wall',(0,2.2,1.75),(3.3,.25,2.7),dark,.015)
 b.cut_arch(front,(0,-2.04,.3),1.12,1.83,.8,dark)
 b.arch('Recessed oak arched door',(0,-2.07,.3),1.06,1.77,.07,doorwood)
 for xx in [-.4,-.2,0,.2,.4]:b.box('Oak portal raised plank',(xx,-2.14,.91),(.17,.035,1.10),doorwood,.012)
 for z in [.65,1.18]:b.box('Portal bronze hinge strap',(0,-2.18,z),(1.0,.035,.055),bronze,.008)
 for xx in [-.12,.12]:b.torus('Portal handle',(xx,-2.22,1.02),.055,.013,bronze,'Y')
 b.arch_frame('Inner carved portal',(0,-2.23,.3),1.17,1.9,pale)
 b.arch_frame('Outer carved portal',(0,-2.24,.29),1.42,2.05,stone)
 for x in [-1.52,1.52]:
  wall=sidewalls[0 if x<0 else 1]
  for yy in [-1.08,.25,1.58]:
   cutter=b.arch('Window cutter',(0,0,0),.63,1.52,.7,dark);cutter.rotation_euler.z=math.pi/2;cutter.location=(x,yy,1.0)
   bpy.context.view_layer.objects.active=wall;mod=wall.modifiers.new('Arched void through masonry','BOOLEAN');mod.operation='DIFFERENCE';mod.object=cutter;bpy.ops.object.modifier_apply(modifier=mod.name);b.PARTS.remove(cutter);bpy.data.objects.remove(cutter,do_unlink=True)
   start=len(b.PARTS)
   b.arch('Stained glass',(0,0,0),.59,1.48,.04,glass)
   b.arch_frame('Window carved stone',(0,-.1,0),.65,1.55,pale)
   for zz in [.28,.60,.92]:
    b.box('Glass lead horizontal',(0,-.06,zz),(.56,.025,.022),bronze,.003)
    # Jewel panels inset inside the lead lattice.
    for xx in [-.14,.14]:
     diamond=b.box('Ruby glass diamond',(xx,-.035,zz+.14),(.12,.018,.16),ruby,.004);diamond.rotation_euler.y=.65
   for xx in [-.28,0,.28]:b.box('Lead window mullion',(xx,-.07,.60),(.025,.035,1.19),bronze,.003)
   for o in b.PARTS[start:]:
    p=o.location.copy();o.location=(x-p.y,yy+p.x,1.0+p.z);o.rotation_euler.z+=math.pi/2
  outer=x+math.copysign(.66,x)
  for yy in [-1.87,-.43,.92,2.12]:
   b.box('Buttress stepped pedestal',(outer,yy,.52),(.45,.49,.44),dark,.035)
   b.box('Buttress stone pier',(outer,yy,1.18),(.3,.37,1.0),stone,.025)
   for z in [.78,1.05,1.32,1.6]:b.box('Buttress ashlar joint',(outer,yy,z),(.34,.4,.045),dark,.006)
   b.beam('Supported flying buttress',(outer,yy,1.62),(x,yy,2.73),.14,stone,8)
   b.box('Buttress coping',(outer,yy,1.74),(.43,.49,.14),pale,.025)
   bpy.ops.mesh.primitive_cone_add(vertices=4,radius1=.22,radius2=.025,depth=.35,location=(outer,yy,1.98));b.finish(bpy.context.object,'Buttress gable cap',pale)
  stone_courses('Side nave',(x+math.copysign(.15,x),.12,.39),4.18,2.65,stone,dark,'X',skip=lambda u,v:any(abs(u-y)<.45 and 0.4<v<2.3 for y in [-1.08,.25,1.58]))
 # Front/rear masonry excludes the real portal and central rose window.
 stone_courses('Front nave',(0,-2.185,.4),3.26,2.65,stone,dark,skip=lambda u,v:(abs(u)<.82 and v<1.95) or (abs(u)<.49 and v>1.95))
 stone_courses('Rear nave',(0,2.35,.4),3.26,2.65,stone,dark)
 for y in [-2.04,2.2]:b.gable('Nave stone gable',y,3.3,.25,3.1,.96,stone)
 b.roof('Slate underlay',0,.08,3.78,4.65,3.12,1.03,felt)
 slope=math.atan2(1.03,1.89)
 for side in [-1,1]:
  for row in range(7):
   x=side*(.13+row*.265);zz=4.24-abs(x)*1.03/1.89
   for col in range(14):
    yy=-2.17+col*.332+(row%2)*.08
    tile=b.box('Lapped individual slate',(x,yy,zz),(.294,.31,.047),roofmat,.008);tile.rotation_euler.y=side*slope
 b.box('Nave ridge copper cap',(0,.08,4.24),(.11,4.7,.09),bronze,.02)
 for side in [-1,1]:
  b.box('Moulded stone cornice',(side*1.71,.08,3.08),(.28,4.62,.12),pale,.025)
  b.box('Stone eave shadow course',(side*1.77,.08,2.94),(.22,4.58,.08),dark,.012)
 # Carved front towers have genuine bell openings and coursed stonework.
 for x,h in [(-2.13,3.65),(2.13,4.05)]:
  b.box('Tower stepped lower plinth',(x,-1.75,.53),(1.18,1.25,.48),dark,.04)
  shaft=b.box('Tower masonry core',(x,-1.75,(h+.3)/2),(.94,1.06,h-.3),dark,.02)
  b.cut_arch(shaft,(x,-2.29,h-1.08),.52,.77,.5,dark)
  b.arch('Bell void interior',(x,-2.12,h-1.08),.49,.75,.03,felt)
  for z in [h-.91,h-.74,h-.57]:b.box('Copper bell louvre',(x,-2.34,z),(.43,.1,.055),bronze,.008)
  for yy in [-2.31,-1.19]:stone_courses('Tower front rear',(x,yy,.4),.92,h-.8,stone,dark,skip=lambda u,v,h=h:abs(u)<.3 and v>h-1.55)
  for xx in [x-.49,x+.49]:stone_courses('Tower side',(xx,-1.75,.4),1.04,h-.78,stone,dark,'X')
  for z in [1.05,2.0,h-1.15,h-.08]:
   b.box('Stepped tower string course',(x,-1.75,z),(1.12,1.2,.08),pale,.022)
   b.box('String course shadow',(x,-1.75,z-.06),(1.04,1.14,.04),dark,.01)
  for dx in [-.49,.49]:
   b.box('Tower corner quoin pier',(x+dx,-2.31,1.85),(.14,.13,2.85),pale,.018)
   for z in [.6+i*.29 for i in range(10)]:b.box('Alternating quoin stone',(x+dx,-2.34,z),(.24,.12,.21),stone,.015)
  b.box('Bell cornice',(x,-1.75,h+.04),(1.19,1.31,.16),pale,.025)
  b.box('Bell cornice lower shadow',(x,-1.75,h-.08),(1.12,1.24,.06),dark,.01)
  bpy.ops.mesh.primitive_cone_add(vertices=8,radius1=.77,radius2=.025,depth=1.20,location=(x,-1.75,h+.73));b.finish(bpy.context.object,'Octagonal slate spire',roofmat)
  for j in range(8):
   a=j*math.tau/8;b.beam('Spire copper seam',(x+.76*math.cos(a),-1.75+.76*math.sin(a),h+.13),(x+.03*math.cos(a),-1.75+.03*math.sin(a),h+1.33),.018,bronze,8)
  for j in range(3):
   z=h+.38+j*.25;r=.77*(1-(z-h-.13)/1.2);b.torus('Spire tier band',(x,-1.75,z),r,.016,bronze)
  b.beam('Spire finial',(x,-1.75,h+1.33),(x,-1.75,h+1.62),.025,bronze)
  for side in [-1,1]:b.beam('Finial arm',(x,-1.75,h+1.53),(x+side*.12,-1.75,h+1.53),.018,bronze)
 # A rose, carved corbels, banner suspension and devotional niches.
 b.cyl('Rose window glass',(0,-2.22,2.74),.34,.035,glass,32,'Y')
 b.torus('Rose window carved rim',(0,-2.25,2.74),.38,.07,pale,'Y')
 for i in range(12):
  a=i*math.tau/12;b.beam('Rose tracery',(0,-2.32,2.74),(.32*math.cos(a),-2.32,2.74+.32*math.sin(a)),.015,bronze,8)
 for x in [-.92,.92]:
  b.box('Crimson pennant',(x,-2.32,1.85),(.24,.035,.76),red,.008)
  b.box('Pennant gold hem',(x,-2.35,1.50),(.22,.025,.045),bronze,.005)
  b.beam('Pennant brass suspension',(x-.18,-2.32,2.28),(x+.18,-2.32,2.28),.023,bronze)
 for j in range(3):b.box('Entrance stair',(0,-2.40-j*.12,.32-j*.06),(1.43,.42,.13),stone,.025)
 # Separate rear forge chamber and flued service equipment support manufacture.
 b.box('Rear sacristy workshop',(0,2.47,1.05),(2.65,.5,1.3),dark,.04)
 for x in [-.86,0,.86]:
  shutter(x,2.77,.55,.64,.7,bronze,felt,dark)
  for z in [.72,.94,1.16]:b.box('Rear forge vent',(x,2.85,z),(.45,.035,.045),felt,.005)
 # Real flues rise outside the nave roof, rooted in the rear forge service bay.
 for x in [-.95,.95]:
  b.box('Forge flue masonry footing',(x,2.58,1.65),(.36,.38,.35),dark,.025)
  b.cyl('Rear forge exhaust flue',(x,2.63,2.7),.11,1.8,bronze,20)
  for z in [1.9,2.65,3.52]:flange((x,2.63,z),.15,'Z',dark,bronze)
  b.cyl('Forge flue dark opening',(x,2.63,3.63),.084,.045,felt,20)
  b.cyl('Forge flue rain cap',(x,2.63,3.76),.18,.045,dark,20)
  for side in [-1,1]:b.beam('Flue cap support',(x+side*.13,2.63,3.55),(x+side*.13,2.63,3.76),.012,bronze)

def main():
 p=argparse.ArgumentParser();p.add_argument('--model',choices=list(b.CONTRACTS),required=True);p.add_argument('--samples',type=int,default=48)
 a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);folder=OUT/a.model;folder.mkdir(parents=True,exist_ok=True)
 b.setup_scene();s=bpy.context.scene;s.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.32;s.view_settings.look='AgX - Medium High Contrast';s.view_settings.exposure=.35
 m=b.setup_materials(a.model);globals()[a.model](m)
 # Emissive regions are genuine source-material regions, later isolated from
 # the exported GLB into a native, production-gated flicker overlay.
 for mat in bpy.data.materials:
  if mat.use_nodes and 'glass' in mat.name:
   principled=mat.node_tree.nodes.get('Principled BSDF')
   if 'ruby' in mat.name:colour=(.6,.025,.015,1)
   elif a.model=='martian':colour=(.06,.45,.17,1)
   elif a.model=='guard':colour=(.20,.31,.42,1)
   else:colour=(.08,.25,.45,1)
   principled.inputs['Emission Color'].default_value=colour;principled.inputs['Emission Strength'].default_value=1.1
 if a.model=='guard':
  lamp=material('guard porch lamp',(.65,.42,.14),.45,0,60);p=lamp.node_tree.nodes.get('Principled BSDF');p.inputs['Emission Color'].default_value=(1,.58,.18,1);p.inputs['Emission Strength'].default_value=2
  b.box('Recessed muster porch light',(0,-1.74,1.91),(.48,.07,.055),lamp,.01)
 if a.model=='sororitas':
  heat=material('sororitas forge aperture glow',(.7,.10,.012),.6,0,50);p=heat.node_tree.nodes.get('Principled BSDF');p.inputs['Emission Color'].default_value=(1,.16,.025,1);p.inputs['Emission Strength'].default_value=2
  for x in [-.86,0,.86]:
   for z in [.72,.94,1.16]:b.box('Recessed forge heat slot',(x,2.875,z),(.32,.012,.02),heat,.003)
 parts=len(b.PARTS)
 (folder/'surface-plan.json').write_text(json.dumps({'revision':4,'owner_rejected_previous':True,'contract':b.CONTRACTS[a.model],
  'materials':[mat.name for mat in bpy.data.materials if mat.use_nodes],
  'surface_treatment':'Regional paint/primer and exposed edges; ambient cavity grime; physical joints, roof sheets/slates and ashlar; distinct cloth/stone/timber/metal grains.',
   'texture_maps':'2048 base colour, roughness, tangent normal, metallic and emission; area-based UV packing and actual export readback',
  'construction':'New architectural assembly with supported entrances, roof members, service equipment and aperture cutters with outward normals',
  'icons':'Excluded by owner instruction'},indent=2)+'\n')
 objects=b.bake_export(a.model,folder);bpy.context.view_layer.update();report=b.inspect(objects,a.model)
 b.render_imported(objects,a.model,folder,a.samples)
 report.update(model=a.model,label=b.CONTRACTS[a.model]['label'],revision=4,authored_parts=parts,footprint_tiles=b.CONTRACTS[a.model]['tiles'],
  runtime=dict(size=768,scale=.5,shift=[0,-b.CONTRACTS[a.model]['target']/math.sqrt(2)],camera_elevation=45,sun_ray=[4,6,-8]),
  status='TECHNICAL_PASS_VISUAL_REVIEW_REQUIRED')
 report['sha256']={str(f.relative_to(folder)):hashlib.sha256(f.read_bytes()).hexdigest() for f in folder.rglob('*') if f.is_file() and f.suffix in ['.png','.glb','.blend']}
 (folder/'inspection.json').write_text(json.dumps(report,indent=2)+'\n');print('FACTORY_V2_COMPLETE',a.model,parts,report['triangles'],flush=True)

if __name__=='__main__':main()
