"""Authored static rubble cache: real masonry shell, stitched cover and supported ties."""
import bpy,bmesh,json,math,random,sys,importlib.util,hashlib
from pathlib import Path
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/martian-stone-cache/v01';T=O/'textures';rng=random.Random(534)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);s=bpy.context.scene;s.render.engine='CYCLES';s.render.film_transparent=True;s.cycles.samples=48;s.cycles.use_denoising=True
root=bpy.data.objects.new('Martian Stone Cache | ground origin',None);s.collection.objects.link(root);mats={};contacts=[];supports=[];records=[]
for role in ('stone','ground-stone','hide','hemp','clay')+ (('dressed-stone',) if (T/'dressed-stone-albedo.png').exists() else ()):
 mat=bpy.data.materials.new('Martian cache | '+role);mat.use_nodes=True;nt=mat.node_tree;bs=nt.nodes.get('Principled BSDF')
 for channel in ('albedo','orm','normal'):
  n=nt.nodes.new('ShaderNodeTexImage');n.name='Cache '+role+' '+channel;n.image=bpy.data.images.load(str(T/(role+'-'+channel+'.png')))
  if channel=='albedo':nt.links.new(n.outputs['Color'],bs.inputs['Base Color'])
  else:
   n.image.colorspace_settings.name='Non-Color'
   if channel=='orm':
    sep=nt.nodes.new('ShaderNodeSeparateColor');nt.links.new(n.outputs['Color'],sep.inputs[0]);nt.links.new(sep.outputs['Green'],bs.inputs['Roughness']);nt.links.new(sep.outputs['Blue'],bs.inputs['Metallic'])
   else:
    normal=nt.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.12 if role=='dressed-stone' else .35 if role in ('stone','ground-stone') else .22;nt.links.new(n.outputs['Color'],normal.inputs['Color']);nt.links.new(normal.outputs[0],bs.inputs['Normal'])
 mats[role]=mat
def uv(ob,kind='stone'):
 layer=ob.data.uv_layers.new(name='CacheSurfaceUV')
 for face in ob.data.polygons:
  axis=max(range(3),key=lambda j:abs(face.normal[j]));axes=[j for j in range(3) if j!=axis]
  for li in face.loop_indices:
   p=ob.matrix_world@ob.data.vertices[ob.data.loops[li].vertex_index].co
   if kind=='hide':value=(p.x/1.6+.5,p.y/1.6+.5)
   elif kind=='ground-stone' and axis!=2:value=(p[axes[0]]*1.7,p.z/.24)
   else:value=(p[axes[0]]*1.7,p[axes[1]]*1.7)
   layer.data[li].uv=value
def mesh(name,verts,faces,role='stone',bevel=0):
 me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update();bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free();ob=bpy.data.objects.new(name,me);s.collection.objects.link(ob);ob.parent=root;ob.data.materials.append(mats[role]);uv(ob,role)
 if bevel:
  mod=ob.modifiers.new('Broken dressed edges','BEVEL');mod.width=bevel;mod.segments=2;bpy.context.view_layer.objects.active=ob;bpy.ops.object.modifier_apply(modifier=mod.name)
 return ob
def joint(a,b,reason):contacts.append(dict(a=a.name if hasattr(a,'name') else a,b=b.name if hasattr(b,'name') else b,why=reason))
def box(name,center,size,role='stone',bevel=.012):
 p=Vector(center);a,b,c=[v*.5 for v in size];verts=[p+Vector((x*a,y*b,z*c)) for x,y,z in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
 return mesh(name,verts,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],role,bevel)
def annulus(name,inner,outer,z0,z1,n=96,role='clay'):
 v=[(r*math.cos(math.tau*j/n),r*math.sin(math.tau*j/n),z) for z,r in ((z0,outer),(z0,inner),(z1,outer),(z1,inner)) for j in range(n)];f=[]
 for j in range(n):
  k=(j+1)%n;f.extend(((j,k,n+k,n+j),(2*n+j,3*n+j,3*n+k,2*n+k),(j,2*n+j,2*n+k,k),(n+j,n+k,3*n+k,3*n+j)))
 return mesh(name,v,f,role)
def stone(name,inner,outer,a0,a1,z0,z1,role='stone'):
 n=4;v=[];bulge=rng.uniform(.005,.020)
 for layer,z in enumerate((z0,(z0+z1)/2,z1)):
  for side,r in enumerate((inner,outer)):
   for j in range(n):
    a=a0+(a1-a0)*j/(n-1);radius=r+(bulge*math.sin(math.pi*j/(n-1)) if side and layer==1 else 0);radius+=rng.uniform(-.006,.006) if j in (1,2) else 0;v.append((radius*math.cos(a),radius*math.sin(a),z))
 f=[]
 for layer in range(2):
  off=layer*2*n
  for j in range(n-1):f.extend(((off+j,off+j+1,off+2*n+j+1,off+2*n+j),(off+n+j,off+3*n+j,off+3*n+j+1,off+n+j+1)))
  f.extend(((off,off+2*n,off+3*n,off+n),(off+n-1,off+2*n-1,off+4*n-1,off+3*n-1)))
 for off,reverse in ((0,True),(4*n,False)):
  for j in range(n-1):
   face=(off+j,off+n+j,off+n+j+1,off+j+1);f.append(tuple(reversed(face)) if reverse else face)
 ob=mesh(name,v,f,role,min(rng.uniform(.018,.030),(a1-a0)*inner*.18))
 # Break factory-brick regularity with a coherent sculpt field. Corner bevel
 # vertices move together; independent vertex noise would make spiky stones.
 phase=rng.uniform(0,6.28)
 for vert in ob.data.vertices:
  p=vert.co;radial=math.hypot(p.x,p.y);height=(p.z-z0)/(z1-z0)
  delta=.008*math.sin(23*p.x+phase)*math.cos(19*p.y-phase)+.004*math.sin(47*p.z+phase)
  if radial>0:
   new_radius=min(.991,radial+delta);p.x*=new_radius/radial;p.y*=new_radius/radial
  p.z+=.014*height*(.6+.4*math.sin(21*p.x+13*p.y+phase))
 ob.data.update()
 # Resolve zero-area bevel corner triangles on the narrow stones at the keystone.
 bm=bmesh.new();bm.from_mesh(ob.data);bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.dissolve_degenerate(bm,dist=1e-7,edges=list(bm.edges));bm.to_mesh(ob.data);bm.free();ob.data.update()
 return ob
def tube(name,points,radius,role='hemp',sides=8):
 ps=[Vector(p) for p in points];v=[]
 for j,p in enumerate(ps):
  axis=(ps[min(j+1,len(ps)-1)]-ps[max(j-1,0)]).normalized();a=axis.cross(Vector((0,0,1)) if abs(axis.z)<.9 else Vector((0,1,0))).normalized();b=axis.cross(a)
  for k in range(sides):v.append(p+radius*(a*math.cos(math.tau*k/sides)+b*math.sin(math.tau*k/sides)))
 f=[tuple(range(sides-1,-1,-1)),tuple((len(ps)-1)*sides+j for j in range(sides))]
 for j in range(len(ps)-1):
  for k in range(sides):q=(k+1)%sides;f.append((j*sides+k,j*sides+q,(j+1)*sides+q,(j+1)*sides+k))
 ob=mesh(name,v,f,role)
 for p in ob.data.polygons:p.use_smooth=True
 return ob
def pebble(name,p,size,role='stone'):
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=p);ob=bpy.context.object;ob.name=name;ob.parent=root
 for v in ob.data.vertices:v.co=Vector((v.co.x*size[0],v.co.y*size[1],v.co.z*size[2]))*(1+rng.uniform(-.12,.12))
 ob.data.materials.append(mats[role]);uv(ob,role);return ob
# Recessed earth floor and a load-bearing, grounded rubble course.
floor=box('Compacted earth cavity floor',(0,0,.027),(1.32,1.32,.054),'clay',.04);supports.append(floor.name)
foot=annulus('Continuous grounded rubble footing',.65,.955,0,.105,role='ground-stone');supports.append(foot.name)
courses=[]
front_angle=-math.pi/2
front_start=front_angle-.50+math.tau
front_end=front_angle+.50+math.tau
for course,(z0,z1,inner,outer) in enumerate(((.055,.25,.70,.935),(.235,.445,.70,.945),(.430,.635,.70,.940),(.620,.755,.665,.965))):
 row=[];N=18
 for i in range(N):
  phase=.5 if course%2 else 0;a0=math.tau*(i+phase)/N+.005;a1=math.tau*(i+phase+1)/N-.005
  segments=[(a0,a1)]
  if a0<front_end and a1>front_start:segments=[(a0,min(a1,front_start-.003)),(max(a0,front_end+.003),a1)]
  for part,(begin,end) in enumerate(segments):
   if end-begin<.015:continue
   ob=stone('Hand-laid course %d stone %02d.%d'%(course,i,part),inner,outer,begin,end,z0,z1,'ground-stone' if course==0 else 'stone');ob['bearing_angle']=(begin+end)/2;row.append(ob)
   parent=foot if course==0 else max(courses[-1],key=lambda lower:math.cos(ob['bearing_angle']-lower['bearing_angle']))
   joint(ob,parent,'staggered bearing course with actual vertical overlap; front ends cut to the full-depth curved keystone');records.append(dict(name=ob.name,course=course,inner_radius=inner,outer_radius=outer,z=[z0,z1],angles=[begin,end]))
 courses.append(row)
# The red hide bulges over the stored contents, with its hem under the capstones.
# Four cut panels are editable, with actual wall-thickness returns.
def cover_z(r,theta):return .630+.240*(1-(r/.76)**2)+.008*math.sin(theta*5)*(r/.76)**2+.004*math.sin(theta*23+r*18)*(r/.76)**4
covers=[]
for sector in range(4):
 nr,na=18,20;v=[]
 for j in range(nr+1):
  r=.022+(.76-.022)*j/nr
  for k in range(na+1):
   a=sector*math.pi/2+.003+(math.pi/2-.006)*k/na;z=cover_z(r,a);v.append((r*math.cos(a),r*math.sin(a),z))
 f=[]
 for j in range(nr):
  for k in range(na):a=j*(na+1)+k;f.append((a,a+1,a+na+2,a+na+1))
 ob=mesh('Red stitched hide panel %d'%sector,v,f,'hide');solid=ob.modifiers.new('Real hide thickness','SOLIDIFY');solid.thickness=.006;solid.offset=-1;bpy.context.view_layer.objects.active=ob;bpy.ops.object.modifier_apply(modifier=solid.name)
 for face in ob.data.polygons:face.use_smooth=True
 cap=max(courses[3],key=lambda candidate:math.cos(candidate['bearing_angle']-(sector+.5)*math.pi/2))
 covers.append(ob);joint(ob,cap,'outer hem trapped beneath actual overlapping capstones')
center=pebble('Central seam keeper',(0,0,cover_z(0,0)+.004),(.047,.045,.018),'hide');joint(center,covers[0],'small overlapping hide patch bridges central seam ends on inflated dome')
for seam in range(4):
 angle=seam*math.pi/2;along=Vector((math.cos(angle),math.sin(angle),0));across=Vector((-math.sin(angle),math.cos(angle),0))
 for j in range(17):
  r=.052+j*.035;points=[]
  for k in range(9):
   t=k/8;p=along*(r+.008*math.sin(t*math.pi))+across*((t-.5)*.032);p.z=cover_z(math.hypot(p.x,p.y),math.atan2(p.y,p.x))+.004+.008*math.sin(t*math.pi);points.append(p)
  thread=tube('Hand stitch %d.%02d'%(seam,j),points,.0028);joint(thread,covers[seam],'thread crosses panel seam at actual sagging cover surface')
# Small stone weights sit on the cloth, following its actual sag.
for i,a in enumerate((.22,.92,1.80,2.55,3.25,4.01,4.85,5.55)):
 r=.58;z=cover_z(r,a);weight=pebble('Loose cover weight %02d'%i,(r*math.cos(a),r*math.sin(a),z+.027),(.052,.044,.036));joint(weight,covers[int(a/(math.pi/2))%4],'weight bottom embeds slightly in hide, supported by tensioned cover')
# This is the actual wall section, not a surface-mounted slab: the whole
# radial thickness is stone and all surrounding courses end against it.
profile=[(0,.70,.955),(.10,.70,.945),(.25,.70,.94),(.445,.70,.945),(.635,.70,.94),(.755,.665,.965),(.81,.665,.965)]
def outer_radius(z):
 for (za,ia,ra),(zb,ib,rb) in zip(profile,profile[1:]):
  if z<=zb:return ra+(rb-ra)*(z-za)/(zb-za)
 return profile[-1][2]
def front_surface_y(x,z):return -math.sqrt(outer_radius(z)**2-x*x)
segments=32;v=[]
for z,inner,outer in profile:
 for radius in (inner,outer):
  for j in range(segments+1):
   a=front_start+(front_end-front_start)*j/segments;v.append((radius*math.cos(a),radius*math.sin(a),z))
stride=segments+1;f=[]
for layer in range(len(profile)-1):
 off=layer*2*stride
 for j in range(segments):f.extend(((off+j,off+2*stride+j,off+2*stride+j+1,off+j+1),(off+stride+j,off+stride+j+1,off+3*stride+j+1,off+3*stride+j)))
 f.extend(((off,off+stride,off+3*stride,off+2*stride),(off+stride-1,off+3*stride-1,off+4*stride-1,off+2*stride-1)))
for off,reverse in ((0,True),((len(profile)-1)*2*stride,False)):
 for j in range(segments):
  face=(off+j,off+j+1,off+stride+j+1,off+stride+j);f.append(tuple(reversed(face)) if reverse else face)
tablet=mesh('Grounded carved circuit receiving tablet',v,f,'dressed-stone' if 'dressed-stone' in mats else 'stone',.009);joint(tablet,foot,'curved keystone replaces the whole wall section, with full-depth inner and outer faces and ground bearing');supports.append(tablet.name)
# Owner correction: a centered, shallow Martian skull-and-cog relief. Reuse the
# actual supplied skull and accepted augmetic module, never a procedural skull.
donor=R/'art/source-to-3d/conclave-center/v08-martian-central-emblem';donor_path=donor/'conclave-center-v08.blend'
with bpy.data.libraries.load(str(donor_path),link=False) as (available,loaded):loaded.objects=[name for name in available.objects if name=='Supplied DGordillo low-poly skull 0' or name.startswith('Mars emblem |')]
loaded_objects=[ob for ob in loaded.objects if ob and ob.type=='MESH'];name_map={};scale=.80;depth_scale=.032
red=mats['hide'].copy();red.name='Martian cache | weathered red cog enamel';nt=red.node_tree;bs=nt.nodes.get('Principled BSDF')
catalog=json.loads((R/'art/source-to-3d/shared-parts/industrial-asset-library/catalog.json').read_text());paint=next(m for m in catalog['materials'] if m['material_id']=='martian_red')
for node in nt.nodes:
 if node.type=='TEX_IMAGE':
  kind='albedo' if node.name.endswith('albedo') else 'orm' if node.name.endswith('orm') else 'normal';node.image=bpy.data.images.load(str(R/paint['maps'][kind]['source_path']),check_existing=True)
  if kind!='albedo':node.image.colorspace_settings.name='Non-Color'
bs.inputs['Metallic'].default_value=.4
for ob in loaded_objects:
 original=ob.name;matrix=ob.matrix_basis.copy();s.collection.objects.link(ob);ob.parent=root;ob.matrix_world=Matrix.Identity(4);ob.name='Cache centered emblem | '+original;name_map[original]=ob.name
 for vert in ob.data.vertices:
  p=matrix@vert.co;x=p.x*scale;z=.47+(p.z-1.66)*scale;depth=(p.y-.420)*scale*depth_scale+.0018
  if original=='Mars emblem | twenty tooth cog surround':depth-=.003
  vert.co=(x,front_surface_y(x,z)+depth,z)
 ob.data.update()
 if original=='Mars emblem | twenty tooth cog surround':ob.data.materials.clear();ob.data.materials.append(red);[setattr(poly,'material_index',0) for poly in ob.data.polygons]
 if original=='Supplied DGordillo low-poly skull 0':
  bone=ob.data.materials[0].copy();bone.name='Martian cache | aged ivory relief';ob.data.materials[0]=bone
  bone.node_tree.nodes['Actual original UV aged bone'].image=bpy.data.images.load(str(T/'cache-bone-ivory-albedo.png'))
 if original=='Supplied DGordillo low-poly skull 0':joint(ob,tablet,'supplied original skull adapted as shallow curved relief; back embeds in stone')
 if original=='Mars emblem | twenty tooth cog surround':joint(ob,tablet,'red cog back follows outer curve and embeds in wall face')
for record in json.loads((donor/'contacts.json').read_text()):
 if record['a'] in name_map and record['b'] in name_map:contacts.append(dict(a=name_map[record['a']],b=name_map[record['b']],why='Preserved fitted relief relationship: '+record['why']))
(O/'emblem-reuse.json').write_text(json.dumps(dict(source=str(donor_path.relative_to(R)),source_sha256=hashlib.sha256(donor_path.read_bytes()).hexdigest(),original_skull='User-supplied DGordillo Craneo mesh, 1192 vertices /2380 triangles, original UV and sculpt normal retained',adaptation='Near-flush curved bas-relief, X/Z scale0.8, fore-aft scale0.0256, back embedded in stone; source anatomy reused, not claimed geometrically unchanged',center=[0,.47],front_angle=front_angle,red_cog_material_source=paint['maps'],objects=name_map,native_circuits='Wire points/reach preserved; base connector artwork suppressed so it cannot obscure the centered insignia; wire pins and native LED states retained.'),indent=2))
import shutil
shutil.copy2(donor/'ATTRIBUTION.txt',O/'ATTRIBUTION.txt')
with (O/'ATTRIBUTION.txt').open('a') as credit:credit.write('\nMartian Stone Cache adaptation: centered shallow curved skull relief over a red cog, using the original donor anatomy, UV and sculpt normal.\n')
# Native wire points stay fixed. Small reclaimed contact studs follow the real
# receiving face; native wire-pin/LED sprites remain responsible for live state.
metal=next(mat for mat in bpy.data.materials if 'worn augmetic steel' in mat.name);mats['circuit-metal']=metal;terminal_records=[]
tablet_tree=BVHTree.FromPolygons([tablet.matrix_world@v.co for v in tablet.data.vertices],[list(p.vertices) for p in tablet.data.polygons])
for wire,x,screen_y in [('red',.34375,.203125),('green',.40625,.421875)]:
 z=.4
 for step in range(30):y=front_surface_y(x,z)-.013;z=-(screen_y-.125)*math.sqrt(2)-y
 mouth=Vector((x,y,z));seat,normal,face,d=tablet_tree.find_nearest(mouth);stud=tube('Native '+wire+' circuit contact seat',[seat-normal*.002,mouth],.012,'circuit-metal',16);joint(stud,tablet,'contact stud root seats on actual curved wall normal; cap projects to unchanged native wire point');terminal_records.append(dict(wire=wire,native=[x,screen_y],mouth=list(mouth),seat=list(seat),surface_normal=list(normal),object=stud.name))
# Pipette mechanical-tension routes are hemp ties, not invented fluid/electric
# services. Their plain ends are trapped under visible weight stones.
spec=importlib.util.spec_from_file_location('cache_pipette',R/'tools/fmpl/pipette/blender_adapter.py');adapter=importlib.util.module_from_spec(spec);sys.modules[spec.name]=adapter;spec.loader.exec_module(adapter);routes=[];tie_records=[]
for i,theta in enumerate((.57,2.15,3.72,5.28)):
 a=Vector((.60*math.cos(theta),.60*math.sin(theta),cover_z(.60,theta)+.002));host=covers[int(theta/(math.pi/2))];target=Vector((.81*math.cos(theta),.81*math.sin(theta),.755));options=[]
 for candidate in courses[3]+[tablet]:
  tree=BVHTree.FromPolygons([candidate.matrix_world@v.co for v in candidate.data.vertices],[list(p.vertices) for p in candidate.data.polygons]);point,normal,face,distance=tree.find_nearest(target);options.append((distance,candidate,point,normal))
 d,cap,b,no=min(options,key=lambda row:row[0]);b=b+no*.001
 path=[]
 for j in range(25):t=j/24;p=a.lerp(b,t);p.z+=.022*math.sin(math.pi*t);path.append(list(p))
 req=dict(id='cache-hemp-retainer-%d'%i,family='tension_cable',payload='mechanical_tension',material_id=mats['hemp'].name,size=dict(outer_diameter=.009,wall_fraction=0),path=dict(kind='waypoints',points=path),start_socket=dict(id='cover-%d'%i,xyz=list(a),normal=list((Vector(path[1])-a).normalized()),role='source',payloads=['mechanical_tension'],parent_mesh=host.name),end_socket=dict(id='cap-%d'%i,xyz=list(b),normal=list((Vector(path[-2])-b).normalized()),role='sink',payloads=['mechanical_tension'],parent_mesh=cap.name),fittings=dict(start='none',end='none'),allow_unterminated=True,supports=dict(binding='actual hide and capstone endpoints, weighted rather than metal-terminated'),behavior=dict(static_mechanical_retainer=True,no_native_external_port=True),keep_outs=[])
 plan=adapter.core.plan(req);col,objects=adapter.build(plan,mats['hemp'],mats['hemp'])
 for ob in objects:ob.parent=root;uv(ob,'hemp');joint(ob,host,'tie begins on actual hide panel');joint(ob,cap,'tie end seated against actual capstone ray surface')
 weight=pebble('Retainer capstone keeper %d'%i,b+Vector((0,0,.026)),(.052,.045,.032));joint(weight,cap,'keeper holds hemp end on actual capstone face');routes.append(req);tie_records.append(dict(id=req['id'],start=list(a),end=list(b),start_parent=host.name,end_parent=cap.name,objects=[ob.name for ob in objects]))
# Studio environment and the one authoritative FMPL camera.
world=bpy.data.worlds.new('Cache neutral studio');world.use_nodes=True;world.node_tree.nodes.get('Background').inputs['Color'].default_value=(.18,.19,.22,1);world.node_tree.nodes.get('Background').inputs['Strength'].default_value=.45;s.world=world
for name,p,power,size in [('key',(-3,-4,6),500,4),('fill',(3,-1,4),260,4),('rim',(0,4,5),380,3)]:
 data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size;ob=bpy.data.objects.new(name,data);s.collection.objects.link(ob);ob.location=p;ob.rotation_euler=(Vector((0,0,.3))-ob.location).to_track_quat('-Z','Y').to_euler()
sys.path.insert(0,str(R/'tools/fmpl'));from blender_camera_guard import install_canonical_camera;install_canonical_camera(s,json.loads((O/'capture-profile.json').read_text()),bpy)
prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='OPTIX';prefs.get_devices()
for device in prefs.devices:device.use=device.type=='OPTIX'
s.cycles.device='GPU'
(O/'contacts.json').write_text(json.dumps(contacts,indent=2));(O/'support-objects.json').write_text(json.dumps(supports,indent=2));(O/'masonry-and-cover.json').write_text(json.dumps(dict(stones=records,cover=dict(panels=[ob.name for ob in covers],hem='r0.76 trapped under capstones',dome='z0.870 at center, z0.630 at hem; seams/weights/ties use the same surface function'),ties=tie_records,front_wall_section=dict(object=tablet.name,angular_bounds=[front_start,front_end],radial_profile=profile,construction='Centered full radial wall thickness, inner-to-outer curved faces, adjacent masonry cut back, relief follows outer curve'),circuit_support=dict(tablet=tablet.name,native_points_unchanged=True,red=[.34375,.203125],green=[.40625,.421875],reach=9,terminals=terminal_records),animation='Static. No native open/working state invented.'),indent=2));(O/'pipette-requests.json').write_text(json.dumps(routes,indent=2))
groups={key:bpy.data.collections.new(name) for key,name in [('stone','CACHE KIT | Stone enclosure'),('emblem','CACHE KIT | Centered Martian relief'),('cover','CACHE VARIANT | Domed hide cover')]}
for group in groups.values():s.collection.children.link(group)
for ob in list(s.objects):
 if ob.type!='MESH':continue
 key='emblem' if ob.name.startswith('Cache centered emblem |') else 'stone' if ob.name.startswith(('Hand-laid','Continuous grounded','Compacted earth','Grounded carved','Native ')) else 'cover'
 for collection in list(ob.users_collection):collection.objects.unlink(ob)
 groups[key].objects.link(ob);ob['cache_component']=key
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(O/'martian-stone-cache-v01.blend'),compress=True);bpy.ops.object.select_all(action='DESELECT')
bpy.data.libraries.write(str(O/'martian-stone-enclosure-kit.blend'),{groups['stone']},fake_user=True,compress=True)
(O/'reusable-components.json').write_text(json.dumps(dict(state='Editable component kit; material/owner review pending before family propagation',stone_library='martian-stone-enclosure-kit.blend',collections={k:g.name for k,g in groups.items()},geometry_scope='Full-depth curved front section and surrounding outer stone wall/foundation; cover and skull emblem remain separately editable',variants='Only the base cache is constructed. Later variants require their own actual prototype, geometry/fittings, captures and native tests.'),indent=2))
for ob in s.objects:
 if ob.type=='MESH':ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(O/'martian-stone-cache-v01.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_cameras=False,export_lights=False)
s.render.filepath=str(O/'source-front.png');bpy.ops.render.render(write_still=True);print('MARTIAN_STONE_CACHE_REAL_SOURCE_EXPORT_SAVED',len(records),len(contacts),flush=True)
