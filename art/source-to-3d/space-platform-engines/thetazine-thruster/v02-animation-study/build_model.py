"""Separately editable Thetazine 64-frame articulated-nozzle and underlay study.

Actual measured vanilla body alpha motion drives a new authored mechanical rig.
This is not a claim of pixel parity or final surfacing/native integration.
"""
import argparse,bpy,bmesh,math,pathlib,json,hashlib,sys
from mathutils import Vector,Quaternion,Matrix
p=argparse.ArgumentParser();p.add_argument('--source',type=pathlib.Path,required=True);p.add_argument('--reference-audit',type=pathlib.Path,required=True);p.add_argument('--out',type=pathlib.Path,required=True);a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(a.source)=='f3ecc524e9b484b136914f8bab2ff8588941f53e678a642a8f030d9dbabf91ac'
ref=json.loads(a.reference_audit.read_text(encoding='utf-8'));assert ref['zip_sha256']=='0670bc10c11800e89beb4d39dd692dc32a4d3ea4b967b742559b54a8d7967791'
bpy.ops.wm.open_mainfile(filepath=str(a.source));s=bpy.context.scene;s.frame_set(0)
A=Vector((0,-math.cos(math.radians(25)),-math.sin(math.radians(25))));B=Vector((0,A.z,-A.y));X=Vector((1,0,0));O=Vector((0,.35,.2));factor=1.25
def point(z,r=0,theta=0):return (O+A*z+(X*math.cos(theta)+B*math.sin(theta))*r)*factor
materials={k:bpy.data.materials['Hydrogen '+k] for k in ['cast','tank','brass','steel','bell','dark']};materials['glow']=bpy.data.materials['Hydrogen inner bell thermal blue']
removed=[]
for o in list(s.objects):
 if o.type=='MESH' and o.name.startswith(('Continuous hollow bell','Nozzle external transverse seam','Nozzle longitudinal panel rib','Physical inner thermal liner','Nozzle seam retaining pin')):
  removed.append(o.name);bpy.data.objects.remove(o,do_unlink=True)
new=[];petals=[];links=[]
body_collection=bpy.data.collections.new('BODY_ANIMATED');s.collection.children.link(body_collection)
underlay=bpy.data.collections.new('PLATFORM_UNDERLAY_STATIC');s.collection.children.link(underlay)
def register(o,name,material,collection=body_collection):
 o.name=name;o.data.materials.append(materials[material]);new.append(o)
 for c in list(o.users_collection):c.objects.unlink(o)
 collection.objects.link(o);o['render_component']='underlay' if collection==underlay else 'body';return o
def cylinder(name,start,end,radius,material='steel',collection=body_collection):
 start=Vector(start);end=Vector(end);d=end-start;bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=radius,depth=d.length,location=(start+end)/2)
 o=register(bpy.context.object,name,material,collection);o.rotation_euler=d.to_track_quat('Z','Y').to_euler()
 for poly in o.data.polygons:poly.use_smooth=len(poly.vertices)==4
 return o
def box(name,center,size,material='cast',collection=underlay):
 bpy.ops.mesh.primitive_cube_add(size=1,location=center);o=register(bpy.context.object,name,material,collection);o.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 mod=o.modifiers.new('Machined plate edges','BEVEL');mod.width=.025;mod.segments=2;o.modifiers.new('Supported normals','WEIGHTED_NORMAL');return o
profile=[(3.16,.40),(3.42,.44),(3.72,.51),(4.03,.61),(4.36,.73),(4.72,.87),(5.12,1.03),(5.19,1.04),(5.22,1.0),(5.16,.975),(4.72,.82),(4.36,.68),(4.03,.56),(3.72,.46),(3.42,.39),(3.16,.35)]
for index in range(12):
 theta=index*math.tau/12;radial=X*math.cos(theta)+B*math.sin(theta);tangent=-X*math.sin(theta)+B*math.cos(theta);pivot=point(3.16,.375,theta);span=math.tau/12+.013;segments=8
 angles=[theta-span/2+span*j/segments for j in range(segments+1)];verts=[point(z,r,t)-pivot for z,r in profile for t in angles];faces=[];uvs=[]
 for ring in range(len(profile)):
  nxt=(ring+1)%len(profile)
  for j in range(segments):
   faces.append((ring*9+j,ring*9+j+1,nxt*9+j+1,nxt*9+j));uvs.append([(angles[j]/math.tau,ring/16),(angles[j+1]/math.tau,ring/16),(angles[j+1]/math.tau,(ring+1)/16),(angles[j]/math.tau,(ring+1)/16)])
 for edge in [0,8]:
  ids=[k*9+edge for k in range(16)]
  if edge==0:ids.reverse()
  faces.append(ids);uvs.append([(profile[k//9][0],profile[k//9][1]) for k in ids])
 mesh=bpy.data.meshes.new('Closed articulated petal geometry');mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new(f'Nozzle articulated petal {index:02}',mesh);body_collection.objects.link(o);o.location=pivot;register(o,o.name,'bell');o.data.materials.append(materials['dark']);uv=mesh.uv_layers.new(name='Circumference and axial petal UV')
 for poly,values in zip(mesh.polygons,uvs):
  poly.use_smooth=poly.index<16*8
  if poly.index//8 in range(9,16):poly.material_index=1
  for li,value in zip(poly.loop_indices,values):uv.data[li].uv=value
 o.rotation_mode='QUATERNION';petals.append((o,tangent,pivot,theta));o['mechanism']='Rigid overlapping petal, tangential throat hinge; closed mesh with side caps'
 hinge=cylinder(f'Petal throat hinge {index:02}',pivot-tangent*.09,pivot+tangent*.09,.055,'steel')
 for sign in [-1,1]:cylinder(f'Hinge keeper {index:02} {sign}',pivot+tangent*(sign*.085),pivot+tangent*(sign*.105),.072,'brass')
 # Each retaining rail is parented to its own rigid petal.
 for j,((z0,r0),(z1,r1)) in enumerate(zip(profile[:6],profile[1:7])):
  rib=cylinder(f'Petal supported seam {index:02} {j}',point(z0,r0+.015,theta),point(z1,r1+.015,theta),.018,'steel');rib.parent=o;rib.matrix_parent_inverse=Matrix.Translation(-pivot)
 liner=cylinder(f'Petal thermal liner {index:02}',point(4.05,.535,theta),point(5.16,.955,theta),.019,'glow');liner.parent=o;liner.matrix_parent_inverse=Matrix.Translation(-pivot)
 fixed=point(3.05,.56,theta);end=point(4.02,.66,theta)
 cylinder(f'Actuator fixed shoulder {index:02}',point(3.05,.45,theta),fixed,.065,'cast')
 rod=cylinder(f'Articulated actuator rod {index:02}',fixed,end,.028,'steel');rod.rotation_mode='QUATERNION';links.append((rod,fixed,end,o,pivot))
# Source-authored U-shaped under-deck machinery, kept in a separate render collection.
box('Underlay fore crossmember',(0,2.25,-.18),(4.85,.34,.24))
for sign in [-1,1]:
 box('Underlay continuous side bearer '+str(sign),(sign*2.15,-.95,-.20),(.22,6.6,.26))
 for j,y in enumerate([2.1,.7,-.7,-2.1,-3.5]):
  box(f'Underlay side bearing block {sign} {j}',(sign*2.15,y,-.16),(.46,.36,.32),'steel')
  cylinder(f'Underlay exposed pipe {sign} {j}',(sign*2.38,y+.2,-.13),(sign*2.38,y-.7,-.13),.085,'brass',underlay)
  for dx in [-.13,.13]:cylinder(f'Underlay block fastener {sign} {j} {dx}',(sign*2.15+dx,y,-.01),(sign*2.15+dx,y,.045),.034,'brass',underlay)
 for j,y in enumerate([.15,-2.65]):
  box(f'Underlay valve casing {sign} {j}',(sign*2.09,y,-.09),(.44,.48,.32),'cast')
  cylinder(f'Underlay valve barrel {sign} {j}',(sign*2.09,y,.07),(sign*2.09,y,.20),.13,'steel',underlay)
  cylinder(f'Underlay valve spindle {sign} {j}',(sign*2.09-.14,y,.215),(sign*2.09+.14,y,.215),.028,'brass',underlay)
 # Actual new side cradle meets the fore platform foot/crossmember plane.
 cylinder('Underlay foot riser '+str(sign),(sign*1.6875,2.42,-.18),(sign*1.6875,2.42,0),.115,'steel',underlay)
# Bake modifiers and triangulate only new authored geometry, preserving object rig frames.
dg=bpy.context.evaluated_depsgraph_get();bpy.context.view_layer.update();snap=[]
for o in new:
 ev=o.evaluated_get(dg);m=ev.to_mesh(preserve_all_data_layers=True,depsgraph=dg).copy();ev.to_mesh_clear();snap.append((o,m))
repairs=[]
for o,m in snap:
 m.calc_loop_triangles();uv=m.uv_layers.active;assert uv is not None,o.name;verts=[v.co.copy() for v in m.vertices];rows=[];fixed=removed_count=0
 for tri in m.loop_triangles:
  pts=[o.matrix_world@verts[i] for i in tri.vertices];cross=(pts[1]-pts[0]).cross(pts[2]-pts[0])
  if cross.length/2<1e-10:removed_count+=1;continue
  values=[tuple(uv.data[i].uv) for i in tri.loops];u=[values[1][k]-values[0][k] for k in range(2)];v=[values[2][k]-values[0][k] for k in range(2)]
  if abs(u[0]*v[1]-u[1]*v[0])/2<1e-10:
   n=cross.normalized();omit=max(range(3),key=lambda i:abs(n[i]));axes=[i for i in range(3) if i!=omit];values=[(p[axes[0]],p[axes[1]]) for p in pts];fixed+=1
  rows.append((tuple(tri.vertices),tri.material_index,tri.use_smooth,values))
 me=bpy.data.meshes.new(o.name+' triangles');me.from_pydata(verts,[],[row[0] for row in rows]);me.update()
 for mat in m.materials:me.materials.append(mat)
 layer=me.uv_layers.new(name='Authored UV')
 for face,row in zip(me.polygons,rows):
  face.material_index=row[1];face.use_smooth=row[2]
  for li,value in zip(face.loop_indices,row[3]):layer.data[li].uv=value
 o.modifiers.clear();o.data=me;bpy.data.meshes.remove(m);repairs.append({'part':o.name,'numerical_faces_removed':removed_count,'uv_faces_repaired':fixed})
widths=[v['lower_lip_width_px'] for v in ref['body_motion']]
# Remove integer alpha-bound jitter using six measured periodic harmonics.
# This remains a one-degree-of-freedom authored kinematic interpretation.
mean=sum(widths)/64;harmonics=[]
for k in range(1,7):harmonics.append((2/64*sum(v*math.cos(k*i*math.tau/64) for i,v in enumerate(widths)),2/64*sum(v*math.sin(k*i*math.tau/64) for i,v in enumerate(widths))))
def smooth_width(i):return mean+sum(c*math.cos(k*i*math.tau/64)+d*math.sin(k*i*math.tau/64) for k,(c,d) in enumerate(harmonics,1))
width0=smooth_width(0);samples=[]
for frame in range(1,66):
 source=(frame-1)%64;width=ref['body_motion'][source]['lower_lip_width_px'];delta=(smooth_width(source)/width0-1)*1.30;angle=math.atan2(delta,2.45)
 for o,tangent,pivot,theta in petals:o.rotation_quaternion=Quaternion(tangent,angle);o.keyframe_insert('rotation_quaternion',frame=frame)
 for rod,fixed,end,petal,pivot in links:
  endpoint=pivot+petal.rotation_quaternion@(end-pivot);d=endpoint-fixed;rod.location=(fixed+endpoint)/2;rod.rotation_quaternion=d.to_track_quat('Z','Y');rod.scale.z=d.length/(end-fixed).length
  for path in ['location','rotation_quaternion','scale']:rod.keyframe_insert(path,frame=frame)
 samples.append({'frame':frame,'source_body_frame':source,'measured_lip_width_px':width,'six_harmonic_smoothed_width_px':smooth_width(source),'petal_angle_radians':angle})
glow=materials['glow'];glow.node_tree.animation_data_clear();bs=glow.node_tree.nodes.get('Principled BSDF')
for frame in range(0,66):
 bs.inputs['Emission Strength'].default_value=.25 if frame==0 else 1.1+.35*math.sin((frame-1)*math.tau/64)**2;bs.inputs['Emission Strength'].keyframe_insert('default_value',frame=frame)
s.frame_start=1;s.frame_end=65;s.render.fps=30;s.frame_set(1);s.render.threads_mode='FIXED';s.render.threads=2;s.cycles.device='CPU';s.cycles.samples=16
s['animation_scope']='64 unique mechanical timeline samples + wrapped frame65; source-lip-width kinematic study, not exact recovered vanilla geometry or approved final movement';s['component_graph']='BODY_ANIMATED, PLATFORM_UNDERLAY_STATIC, glow material, fixed fuel/water sockets; native cap/flame/plume layers remain separate integration work'
bpy.ops.wm.save_as_mainfile(filepath=str(out/'thetazine-animation-study.blend'),compress=True)
for o in s.objects:o.select_set(o.type=='MESH' or o.name.startswith('socket_'))
bpy.ops.export_scene.gltf(filepath=str(out/'thetazine-animation-study.glb'),use_selection=True,export_format='GLB',export_apply=True,export_animations=True,export_animation_mode='SCENE',export_anim_scene_split_object=False,export_frame_range=True,export_force_sampling=True)
report={'status':'AUTHORED_64_FRAME_MECHANICAL_STUDY_REQUIRES_EXPORT_AND_RENDER_REVIEW','source_sha256':sha(a.source),'reference_zip_sha256':ref['zip_sha256'],'reference_audit_sha256':sha(a.reference_audit),'builder_sha256':sha(pathlib.Path(__file__)),'native_sha256':sha(out/'thetazine-animation-study.blend'),'glb_sha256':sha(out/'thetazine-animation-study.glb'),'mechanism':'12 rigid overlapping closed petal meshes, tangential throat hinges, attached seam rails/inner thermal liners, 12 articulated actuator rods; main structure/sockets remain static. New authored mechanism driven by measured reference body-alpha lip width; not exact vanilla-part identity.','render_components':['body beauty','body emission','static source-authored underlay','body shadow pending','native gated caps preserved separately','flame/plume native integration pending'],'fps':30,'cycle_frames':64,'wrap_frame':65,'source_body_parts_removed':removed,'mesh_count':sum(o.type=='MESH' for o in s.objects),'new_geometry_repairs':repairs,'samples':samples,'native_graphics_installed':False,'final_surface_or_animation_approval':False}
(out/'source-manifest.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n');print('ANIMATION_STUDY_BUILT',report['mesh_count'])
