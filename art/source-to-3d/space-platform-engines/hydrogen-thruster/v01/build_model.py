"""Hydrogen engine candidate authored from the existing Tech-Priests sprite."""
import argparse,bpy,math,json,pathlib,hashlib,sys
from mathutils import Vector
parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--out',type=pathlib.Path,required=True);parser.add_argument('--textures',type=pathlib.Path,required=True);parser.add_argument('--reference-idle',type=pathlib.Path,required=True);parser.add_argument('--reference-run',type=pathlib.Path,required=True);parser.add_argument('--pilot',action='store_true');args=parser.parse_args(sys.argv[sys.argv.index('--')+1:]);ROOT=pathlib.Path(__file__).resolve().parent;OUT=args.out.resolve();OUT.mkdir(parents=True,exist_ok=False)
assert hashlib.sha256(args.reference_idle.read_bytes()).hexdigest()=='5b7daa6196aac7f232cfa4dfa7bf833b318451b05d2f49aa3201dc55213aa3c2'
assert hashlib.sha256(args.reference_run.read_bytes()).hexdigest()=='d62a7eb04bdd7dec8076909ad02ae8d423a77865f5d64456c80fb9b892fa95a3'
bpy.ops.wm.read_factory_settings(use_empty=True);S=bpy.context.scene
A=Vector((0,-math.cos(math.radians(25)),-math.sin(math.radians(25))));B=Vector((0,A.z,-A.y));O=Vector((0,.35,.2));X=Vector((1,0,0))
assert abs(A.dot(B))<1e-6
def p(s,x=0,z=0):return O+A*s+X*x+B*z
M={}
for name in ['cast','tank','brass','steel','bell','dark']:
 m=bpy.data.materials.new('Hydrogen '+name);m.use_nodes=True;nt=m.node_tree;bs=nt.nodes.get('Principled BSDF')
 for kind,socket in [('basecolor','Base Color'),('metalrough',None),('normal',None)]:
  tex=nt.nodes.new('ShaderNodeTexImage');tex.name='Hydrogen '+name+' '+kind;tex.image=bpy.data.images.load(str(args.textures.resolve()/(name+'-'+kind+'.png')),check_existing=True);tex.image.pack()
  if kind=='basecolor':nt.links.new(tex.outputs['Color'],bs.inputs[socket])
  elif kind=='metalrough':
   tex.image.colorspace_settings.name='Non-Color';sep=nt.nodes.new('ShaderNodeSeparateColor');nt.links.new(tex.outputs['Color'],sep.inputs['Color']);nt.links.new(sep.outputs['Green'],bs.inputs['Roughness']);nt.links.new(sep.outputs['Blue'],bs.inputs['Metallic'])
  else:
   tex.image.colorspace_settings.name='Non-Color';normal=nt.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.18;nt.links.new(tex.outputs['Color'],normal.inputs['Color']);nt.links.new(normal.outputs['Normal'],bs.inputs['Normal'])
 M[name]=m
glow=M['dark'].copy();glow.name='Hydrogen inner bell thermal blue';M['glow']=glow;bs=glow.node_tree.nodes.get('Principled BSDF');bs.inputs['Emission Color'].default_value=(.012,.10,.7,1)
for f,strength in list(enumerate([0,.02,.08,0,.1,0,0]))+[(16+i,v) for i,v in enumerate([1.1,1.4,.9,1.6,1.2,1.8,1.1])]+[(23,1.1)]:bs.inputs['Emission Strength'].default_value=strength;bs.inputs['Emission Strength'].keyframe_insert('default_value',frame=f)
registry=[]
def reg(o,name,mat):
 o.name=name;o.data.materials.append(M[mat]);registry.append(o);return o
def mesh(name,verts,faces,mat,uvs=None,smooth=False):
 me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update();o=bpy.data.objects.new(name,me);S.collection.objects.link(o);reg(o,name,mat)
 for face in me.polygons:face.use_smooth=smooth
 if uvs:
  uv=me.uv_layers.new(name='Construction UV')
  for poly,vals in zip(me.polygons,uvs):
   for li,value in zip(poly.loop_indices,vals):uv.data[li].uv=value
 return o
def box(name,center,size,mat='cast',basis=None,bevel=.025):
 bpy.ops.mesh.primitive_cube_add(size=1,location=center);o=reg(bpy.context.object,name,mat);o.scale=size
 if basis:o.rotation_euler=basis.to_track_quat('Z','Y').to_euler()
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bevel:
  mod=o.modifiers.new('Supported machined edge','BEVEL');mod.width=bevel;mod.segments=2
  o.modifiers.new('Weighted face normals','WEIGHTED_NORMAL')
 return o
def strut(name,a,b,width,depth,mat='cast'):
 d=Vector(b)-Vector(a);return box(name,(Vector(a)+Vector(b))/2,(width,depth,d.length),mat,d,.018)
def lathe(name,origin,axis,profile,mat='steel',sides=48,cyclic=False):
 axis=Vector(axis).normalized();u=X if abs(axis.dot(X))<.1 else Vector((0,1,0));u=(u-axis*axis.dot(u)).normalized();v=axis.cross(u).normalized();origin=Vector(origin)
 verts=[origin+axis*z+radius*(math.cos(i*2*math.pi/sides)*u+math.sin(i*2*math.pi/sides)*v) for z,radius in profile for i in range(sides)]
 faces=[];uvs=[];lengths=[0]
 for i in range(1,len(profile)):lengths.append(lengths[-1]+math.dist(profile[i-1],profile[i]))
 span=max(lengths[-1],.001)
 for row in range(len(profile)-1):
  for i in range(sides):
   faces.append((row*sides+i,row*sides+(i+1)%sides,(row+1)*sides+(i+1)%sides,(row+1)*sides+i));uvs.append([(i/sides,lengths[row]/span),((i+1)/sides,lengths[row]/span),((i+1)/sides,lengths[row+1]/span),(i/sides,lengths[row+1]/span)])
 if cyclic:
  row=len(profile)-1
  for i in range(sides):faces.append((row*sides+i,row*sides+(i+1)%sides,(i+1)%sides,i));uvs.append([(i/sides,1),((i+1)/sides,1),((i+1)/sides,0),(i/sides,0)])
 return mesh(name,verts,faces,mat,uvs,True)
def cylinder(name,a,b,r,mat='steel',sides=32):
 d=Vector(b)-Vector(a);profile=[(0,r*.001),(0,r),(d.length,r),(d.length,r*.001)];return lathe(name,a,d,profile,mat,sides,True)
def band(name,s,r,width=.085,mat='brass',x=0,z=0):return lathe(name,p(s,x,z),A,[(-width/2,r-.025),(-width/2,r+.014),(width/2,r+.014),(width/2,r-.025)],mat,48,True)
def pipe(name,points,r=.038,mat='brass'):
 cu=bpy.data.curves.new(name,'CURVE');cu.dimensions='3D';cu.resolution_u=10;cu.bevel_depth=r;cu.bevel_resolution=3
 sp=cu.splines.new('BEZIER');sp.bezier_points.add(len(points)-1)
 for v,co in zip(sp.bezier_points,points):v.co=co;v.handle_left_type='AUTO';v.handle_right_type='AUTO'
 o=bpy.data.objects.new(name,cu);S.collection.objects.link(o);o.data.materials.append(M[mat]);registry.append(o);return o
def bolt(name,point,normal=B,r=.034):
 normal=Vector(normal);return lathe(name,point,normal,[(0,r*.90),(0,r),(.035,r),(.035,.001)],'brass',6,True)
def sphere(name,center,scale,mat='cast'):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,location=center);o=reg(bpy.context.object,name,mat);o.rotation_euler=B.to_track_quat('Z','Y').to_euler();o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 for face in o.data.polygons:face.use_smooth=True
 return o
# Source-derived upper crossbeam with three saddles and a lower load bar.
box('Upper mounting beam',p(-1.75,0,.02),(4.0,.34,.25),'cast',B,.035)
box('Lower mounting crossmember',p(-.68,0,-.10),(3.95,.24,.20),'cast',B,.025)
strut('Central regulator spine',p(-1.95,0,.02),p(.38,0,.02),.17,.15,'cast')
for ss in [-1.44,-.28]:
 cylinder('Central regulator seat',p(ss,0,.10),p(ss,0,.23),.13,'cast')
 lathe('Recessed regulator rim',p(ss,0,.23),B,[(0,.09),(0,.14),(.045,.14),(.045,.09)],'brass',32,True)
 for i in range(6):
  angle=i*math.tau/6;bolt('Regulator rim stud',p(ss+math.sin(angle)*.105,math.cos(angle)*.105,.275),B,.018)
for x in [-1.35,0,1.35]:
 box('Crossbeam saddle '+str(x),p(-1.75,x,.17),(.34,.46,.12),'steel',B,.018)
 for side in [-1,1]:bolt('Saddle fastener',p(-1.75+side*.14,x,.23))
for x in [-1.35,1.35]:
 top=p(-1.75,x,.02);foot=Vector((x,top.y,0))
 box('Platform saddle foot '+str(x),foot+Vector((0,0,.055)),(.42,.42,.11),'cast',None,.02)
 for side in [-1,1]:
  a=foot+Vector((side*.12,0,.11));b=Vector((a.x,top.y,top.z-.08));strut('Supported saddle cheek',a,b,.10,.22,'cast')
  bolt('Deck foot bolt',foot+Vector((side*.145,-.13,.11)),Vector((0,0,1)),.035)
for x in [-1.85,-1.65,-1.0,-.7,-.4,.4,.7,1.0,1.65,1.85]:bolt('Beam face rivet',p(-1.75,x,.145),B,.024)
# Diagonal shoulder links are actual open-frame load paths, no deck/base slab.
for sign in [-1,1]:
 strut('Diagonal shoulder '+str(sign),p(-.62,sign*1.72,-.02),p(.53,sign*.92,-.02),.19,.16,'cast')
 strut('Shoulder raised rib '+str(sign),p(-.58,sign*1.72,.10),p(.50,sign*.96,.10),.055,.045,'steel')
 for ss,xx in [(-.62,1.72),(.53,.92)]:
  cylinder('Shoulder pivot',p(ss,sign*xx,-.10),p(ss,sign*xx,.16),.13,'steel');bolt('Shoulder pivot pin',p(ss,sign*xx,.16),B,.065)
# Paired longitudinal canisters, their rolled seams and routed header feeds.
for sign in [-1,1]:
 x=sign*.46;origin=p(-1.15,x,.02)
 prof=[(-.08,.18),(0,.26),(.10,.30),(.28,.31),(1.16,.31),(1.30,.27),(1.38,.18),(1.38,.015),(-.08,.015)]
 lathe('Paired canister '+str(sign),origin,A,prof,'tank',48,True)
 for s0 in [-.98,-.55,-.1,.17]:band('Canister rolled restraint',s0,.315,.045,'steel',x,.02)
 cylinder('Canister lower attachment',p(.19,x,.02),p(.51,x,.02),.16,'dark')
 for s0 in [-1.0,.12]:box('Canister saddle',p(s0,x,-.24),(.7,.16,.13),'cast',B,.018)
 pipe('Canister header feed '+str(sign),[p(-1.67,sign*.88,.20),p(-1.35,sign*.86,.20),p(-1.12,x,.32)],.045,'brass')
 pipe('Outer pressure return '+str(sign),[p(-1.5,sign*1.35,.19),p(-1.05,sign*1.25,.20),p(-.80,sign*.88,.32),p(.36,sign*.84,.21)],.035,'steel')
# Six feed columns and their receiving blocks, as visible in the sprite.
for i,x in enumerate([-.65,-.39,-.13,.13,.39,.65]):
 cylinder('Feed column '+str(i),p(.55,x,.0),p(1.77,x,.0),.054,'steel',24)
 for ss in [.57,.91,1.42,1.72]:band('Feed collar',ss,.074,.055,'brass',x,0)
 box('Feed upper manifold',p(.45,x,.02),(.19,.25,.18),'cast',B,.012);bolt('Feed receiver screw',p(.45,x,.11),B,.033)
for sign in [-1,1]:
 pipe('Lower feed return '+str(sign),[p(1.58,sign*.39,.1),p(1.85,sign*.39,.16),p(1.91,sign*.20,.29)],.035,'brass')
 cylinder('Outer actuator body '+str(sign),p(1.1,sign*.92,0),p(2.7,sign*.92,0),.085,'steel')
 for ss in [1.15,1.45,1.95,2.6]:band('Outer actuator collar',ss,.11,.065,'brass',sign*.92)
 coil=[]
 for i in range(169):
  t=i/168;theta=t*math.tau*7;coil.append(p(1.76+t*.72,sign*.92)+X*(math.cos(theta)*.125)+B*(math.sin(theta)*.125))
 coil_object=pipe('Source actuator helical thread '+str(sign),coil,.018,'steel');coil_object.data.resolution_u=2
 for ss in [1.1,2.7]:box('Actuator support clevis',p(ss,sign*.92,-.04),(.23,.24,.21),'cast',B,.016);bolt('Clevis fixed pin',p(ss,sign*.92,.065),B,.045)
# Pressure chamber, real stepped shoulders, three rows of bolted retaining bands.
lathe('Main pressure chamber',p(1.75),A,[(0,.48),(.12,.57),(.32,.61),(1.25,.61),(1.45,.47),(1.52,.42)],'cast',64)
for ss in [2.05,2.55,3.03]:
 band('Pressure chamber retaining band',ss,.625,.14,'steel')
 for i in range(12):
  theta=2*math.pi*i/12;n=X*math.cos(theta)+B*math.sin(theta);bolt('Pressure flange stud',p(ss)+n*.639,n,.032)
for i in range(8):
 theta=i*math.tau/8;n=X*math.cos(theta)+B*math.sin(theta);pipe('Pressure casing axial panel seam',[p(ss)+n*.616 for ss in [2.05,2.35,2.65,3.03]],.008,'dark')
# Hollow, axially flared nozzle with thickness, inner refractory and actual ribs.
profile=[(3.16,.40),(3.42,.44),(3.72,.51),(4.03,.61),(4.36,.73),(4.72,.87),(5.12,1.03),(5.19,1.04),(5.22,1.0),(5.16,.975),(4.72,.82),(4.36,.68),(4.03,.56),(3.72,.46),(3.42,.39),(3.16,.35)]
bell=lathe('Continuous hollow bell',O,A,profile,'bell',80,True);bell.data.materials.append(M['dark'])
for poly in bell.data.polygons:
 if poly.index//80 in range(9,15):poly.material_index=1
for ss,rr in [(3.52,.463),(4.18,.668),(4.80,.905),(5.17,1.04)]:band('Nozzle external transverse seam',ss,rr,.035,'steel')
for i in range(12):
 theta=2*math.pi*i/12;n=X*math.cos(theta)+B*math.sin(theta)
 pts=[p(ss)+n*(rr+.012) for ss,rr in profile[:7]];pipe('Nozzle longitudinal panel rib '+str(i),pts,.016,'steel')
 pts=[p(ss)+n*(rr-.016) for ss,rr in profile[9:16]];pipe('Physical inner thermal liner '+str(i),pts,.016,'glow')
 for ss,rr in [(3.52,.463),(4.18,.668),(4.80,.905)]:bolt('Nozzle seam retaining pin',p(ss)+n*(rr+.025),n,.017)
# Cast source emblem: supported wing plates and one hollow-eyed metal skull.
base=p(2.05,0,.70);sphere('Emblem backing boss',base,(.20,.24,.065),'brass')
skull=sphere('Winged skull cranium',p(2.04,0,.775),(.125,.16,.09),'brass')
for sign in [-1,1]:
 eye=sphere('Temporary eye recess cutter',p(2.04,sign*.053,.845),(.043,.049,.065),'dark');bpy.context.view_layer.objects.active=skull;mod=skull.modifiers.new('Actual recessed eye cavity','BOOLEAN');mod.operation='DIFFERENCE';mod.object=eye;bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(eye,do_unlink=True);registry.remove(eye)
 for i in range(4):
  start=p(2.07+i*.045,sign*.12,.76);end=p(2.00+i*.075,sign*(.56-i*.065),.72);strut('Cast wing feather',start,end,.045,.028,'brass')
sphere('Skull jaw',p(2.18,0,.78),(.085,.07,.06),'brass')
for i in range(5):box('Cast skull tooth',p(2.21,(i-2)*.025,.84),(.018,.044,.025),'steel',B,.003)
# The explicit new interface detail fits the already fixed native port contract.
for identity,sign in [('fuel',-1),('oxidizer',1)]:
 origin=Vector((sign*2,.5,.36));axis=Vector((sign,0,0))
 lathe(identity+' socket flange',origin,axis,[(-.24,.20),(-.10,.26),(-.04,.285),(0,.285),(0,.18),(-.24,.16)],'steel',48,True)
 cylinder(identity+' closed seat',origin-axis*.015,origin-axis*.005,.175,'dark',40)
 pipe(identity+' routed supply neck',[(sign*1.8,.5,.36),(sign*1.55,.5,.36),(sign*1.26,.63,.43),tuple(p(-.63,sign*.83,.06))],.14,'tank')
 for i in range(6):
  a=i*math.tau/6;normal=axis;point=origin+Vector((0,math.cos(a)*.247,math.sin(a)*.247));bolt(identity+' flange fastener',point,normal,.027)
 empty=bpy.data.objects.new('socket_'+identity,None);S.collection.objects.link(empty);empty.location=origin;empty.rotation_euler=axis.to_track_quat('Z','Y').to_euler();empty['fluid']='liquid-hydrogen' if sign<0 else 'liquid-oxygen';empty['coordinate_frame']='Blender X right, Y platform/fore, Z up; candidate height .36 requires native visual jig'
# Bake only evaluated geometry, with a numeric guard on UVs and microscopic faces.
S.frame_set(0);bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();snap=[]
for o in list(S.objects):
 if o.type not in ['MESH','CURVE']:continue
 ev=o.evaluated_get(dg);m=ev.to_mesh(preserve_all_data_layers=True,depsgraph=dg).copy();ev.to_mesh_clear();snap.append((o,m,o.matrix_world.copy()))
repairs=[]
for o,m,world in snap:
 m.calc_loop_triangles();verts=[v.co.copy() for v in m.vertices];coords=[world@v for v in verts];uv=m.uv_layers.active;normals=[tuple(n.vector) for n in m.corner_normals];rows=[];removed=uvfix=0
 for tri in m.loop_triangles:
  pts=[coords[i] for i in tri.vertices];area=(pts[1]-pts[0]).cross(pts[2]-pts[0]).length/2
  if area<1e-10 or min((pts[i]-pts[(i+1)%3]).length for i in range(3))<1e-6:removed+=1;continue
  vals=[tuple(uv.data[l].uv) for l in tri.loops] if uv else [(0,0)]*3;a=[vals[1][k]-vals[0][k] for k in range(2)];b=[vals[2][k]-vals[0][k] for k in range(2)]
  if abs(a[0]*b[1]-a[1]*b[0])/2<1e-10 or min(math.dist(vals[i],vals[(i+1)%3]) for i in range(3))<1e-6:
   n=(pts[1]-pts[0]).cross(pts[2]-pts[0]).normalized();omit=max(range(3),key=lambda i:abs(n[i]));axes=[i for i in range(3) if i!=omit];vals=[(v[axes[0]]*2+.5,v[axes[1]]*2+.5) for v in pts];uvfix+=1
  rows.append((tuple(tri.vertices),tri.material_index,tri.use_smooth,vals,[normals[l] for l in tri.loops]))
 me=bpy.data.meshes.new(o.name+' authored triangles');me.from_pydata(verts,[],[t[0] for t in rows]);me.update()
 for mat in m.materials:me.materials.append(mat)
 layer=me.uv_layers.new(name='Construction UV')
 for face,row in zip(me.polygons,rows):
  face.material_index=row[1];face.use_smooth=row[2]
  for li,val in zip(face.loop_indices,row[3]):layer.data[li].uv=val
 me.normals_split_custom_set([n for row in rows for n in row[4]])
 name=o.name;bpy.data.objects.remove(o,do_unlink=True);new=bpy.data.objects.new(name,me);S.collection.objects.link(new);new.matrix_world=world;bpy.data.meshes.remove(m);repairs.append({'name':name,'triangles':len(rows),'numerical_faces_removed':removed,'uv_faces_repaired':uvfix})
# Lights/camera are source-authoring aids, not a runtime floor plate.
world=bpy.data.worlds.new('Neutral orbital studio');S.world=world;world.use_nodes=True;world.node_tree.nodes.get('Background').inputs[0].default_value=(.12,.15,.20,1);world.node_tree.nodes.get('Background').inputs[1].default_value=.35
for name,loc,energy,size,color in [('Key',(-4,-2,7),1600,5,(1,.96,.87)),('Fill',(4,1,4),850,4,(.75,.85,1)),('Rim',(0,5,4),1100,3,(.97,.92,.83))]:
 data=bpy.data.lights.new(name,'AREA');data.energy=energy;data.shape='DISK';data.size=size;data.color=color;o=bpy.data.objects.new(name,data);S.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,-1,-.4))-o.location).to_track_quat('-Z','Y').to_euler()
cam=bpy.data.objects.new('factorio_main',bpy.data.cameras.new('factorio_main'));S.collection.objects.link(cam);target=Vector((0,-1.3,-.5));cam.location=target+Vector((0,-12,12));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=9;S.camera=cam
S.render.engine='CYCLES';S.cycles.device='CPU';S.cycles.samples=16;S.cycles.use_denoising=True;S.render.threads_mode='FIXED';S.render.threads=2;S.render.resolution_x=512;S.render.resolution_y=768;S.render.resolution_percentage=100;S.render.film_transparent=True;S.render.image_settings.file_format='PNG';S.render.image_settings.color_mode='RGBA';S.render.use_compositing=False;S.view_settings.view_transform='AgX';S.view_settings.look='AgX - Medium High Contrast';S.render.fps=24;S.frame_start=0;S.frame_end=23
S.frame_set(0);bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'hydrogen-thruster-v01.blend'),compress=True)
for o in S.objects:o.select_set(o.type=='MESH' or o.name.startswith('socket_'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'hydrogen-thruster-v01.glb'),use_selection=True,export_format='GLB',export_apply=True,export_animations=False,export_extras=True)
report={'status':'SOURCE_AUTHORED_CANDIDATE_REQUIRES_VISUAL_AND_NATIVE_REVIEW','source_sprite_sha256':hashlib.sha256(args.reference_idle.read_bytes()).hexdigest(),'source_run_sprite_sha256':hashlib.sha256(args.reference_run.read_bytes()).hexdigest(),'builder_sha256':hashlib.sha256(pathlib.Path(__file__).read_bytes()).hexdigest(),'parts':repairs,'mesh_count':len(repairs),'triangles':sum(p['triangles'] for p in repairs),'axis':list(A),'transverse_up':list(B),'camera_elevation':45,'orthographic_scale':9,'render_cell':[512,768],'states':{'idle':list(range(7)),'run':list(range(16,23))},'fixed_direction':'north; no four-way variants invented','source_reference_features':['crossbeam and saddles','paired canisters','diagonal shoulders','six feed columns','outer actuators','bolted pressure chamber','continuous hollow flared bell','cast winged skull','explicit native socket flanges'],'native_sha256':hashlib.sha256((OUT/'hydrogen-thruster-v01.blend').read_bytes()).hexdigest(),'glb_sha256':hashlib.sha256((OUT/'hydrogen-thruster-v01.glb').read_bytes()).hexdigest()}
(OUT/'source-manifest.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
if args.pilot:
 for frame,name in [(0,'idle-pilot'),(19,'run-pilot')]:S.frame_set(frame);S.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)
print('HYDROGEN_CANDIDATE',report['mesh_count'],report['triangles'],flush=True)
