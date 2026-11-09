"""Independent four-pass regenerative circuits on all twelve articulated leaves."""
import bpy,bmesh,pathlib,sys,json,hashlib,math,tempfile,numpy as np
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
P=pathlib.Path(sys.argv[sys.argv.index('--')+1]).resolve();R=pathlib.Path(sys.argv[sys.argv.index('--')+2]).resolve();R.mkdir(exist_ok=False);tempfile.tempdir=str(R/'export-temp');pathlib.Path(tempfile.tempdir).mkdir();sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();src=P/'thetazine-v04-regenerative-study.blend';manifest=json.loads((P/'source-manifest.json').read_text());assert sha(src)==manifest['native_sha256'];bpy.ops.wm.open_mainfile(filepath=str(src));s=bpy.context.scene;s.frame_set(0);bpy.context.view_layer.update()
A=Vector((0,-math.cos(math.radians(25)),-math.sin(math.radians(25))));B=Vector((0,A.z,-A.y));X=Vector((1,0,0));O=Vector((0,.35,.2));F=1.25;core=bpy.data.objects['V04 independently suspended engine core'];core_inv=core.matrix_world.inverted();collection=bpy.data.collections.new('V04_PER_LEAF_REGENERATIVE_COOLING');s.collection.children.link(collection);M={k:bpy.data.materials[n] for k,n in [('tube','Hydrogen steel'),('brass','Hydrogen brass'),('seal','V04 pressure gland graphite seals')]};added=[];routes=[];ports=[];circuits=[];flex_jobs=[];anchors=[]
def checkpoint(phase):
 (R/'authoring-checkpoint.json').write_text(json.dumps({'phase':phase,'script_sha256':sha(pathlib.Path(__file__)),'input_native_sha256':sha(src),'meshes_added':len(added)},indent=2)+'\n',encoding='utf-8',newline='\n');print('LEAF_COOLING_PHASE',phase,flush=True)
def q(z):return (O+A*z)*F
ownership_repairs=[]
for o in list(s.objects):
 if o.name.startswith(('V04 fixed ram clevis cheek','V04 restraint ram seated saddle','V04 hydraulic manifold standoff','V04 fixed chrome telescoping throat sleeve')):
  world=o.matrix_world.copy();o.parent=core;o.matrix_parent_inverse=core_inv;o.matrix_world=world;ownership_repairs.append(o.name)
bpy.context.view_layer.update()
def radial(t):return X*math.cos(t)+B*math.sin(t)
def profile(z):
 t=(z-3.16)/2.03;return .40+.64*t+.07*math.sin(math.pi*t)
def point(z,r,t):return q(z)+radial(t)*r*F
def mesh(name,verts,faces,uv,mat,parent=None,leaf=False):
 me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update();me.materials.append(M[mat]);layer=me.uv_layers.new(name='Cooling pipe physical UV')
 for p,values in zip(me.polygons,uv):
  p.use_smooth=len(p.vertices)==4
  for li,value in zip(p.loop_indices,values):layer.data[li].uv=value
 bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free();o=bpy.data.objects.new(name,me);collection.objects.link(o);o['render_component']='body'
 if parent:o.parent=parent;o.matrix_parent_inverse=Matrix.Identity(4) if leaf else core_inv
 added.append(o);return o
def path_data(points,radius,sides=16,corrugated=False):
 points=[Vector(p) for p in points];verts=[];faces=[];uv=[];u=None;arc=0
 for j,p in enumerate(points):
  tangent=(points[min(j+1,len(points)-1)]-points[max(0,j-1)]).normalized();seed=(X if abs(tangent.dot(X))<.9 else B) if u is None else u;u=seed-tangent*seed.dot(tangent)
  if u.length<1e-7:u=B-tangent*B.dot(tangent)
  u.normalize();v=tangent.cross(u)
  if j:arc+=(p-points[j-1]).length
  rr=radius*(1+.08*math.cos(j*math.tau/3)) if corrugated else radius
  for i in range(sides):verts.append(p+(u*math.cos(i*math.tau/sides)+v*math.sin(i*math.tau/sides))*rr)
  if j:
   prev_arc=arc-(p-points[j-1]).length
   for i in range(sides):faces.append(((j-1)*sides+i,(j-1)*sides+(i+1)%sides,j*sides+(i+1)%sides,j*sides+i));uv.append([(i/sides,prev_arc*4),((i+1)/sides,prev_arc*4),((i+1)/sides,arc*4),(i/sides,arc*4)])
 for end,reverse in [(0,True),(len(points)-1,False)]:
  ids=[end*sides+i for i in range(sides)];values=[(.5+.45*math.cos(i*math.tau/sides),.5+.45*math.sin(i*math.tau/sides)) for i in range(sides)]
  if reverse:ids.reverse();values.reverse()
  faces.append(ids);uv.append(values)
 return verts,faces,uv
def pipe(name,points,radius,mat,parent=None,leaf=False,record=True):
 verts,faces,uv=path_data(points,radius);o=mesh(name,verts,faces,uv,mat,parent,leaf)
 if record:routes.append({'name':o.name,'radius':radius,'endpoints_local':[list(points[0]),list(points[-1])],'parent':parent.name if parent else None})
 return o
def cylinder(name,start,end,radius,mat,parent=None,leaf=False,sides=16):return pipe(name,[Vector(start),Vector(end)],radius,mat,parent,leaf,False)
def ring(name,center,axis,rin,rout,length,mat,parent,leaf=False,sides=20):
 center=Vector(center);axis=Vector(axis).normalized();seed=X if abs(axis.dot(X))<.9 else B;u=(seed-axis*seed.dot(axis)).normalized();v=axis.cross(u);prof=[(-length/2,rin),(-length/2,rout),(length/2,rout),(length/2,rin)];verts=[center+axis*z+(u*math.cos(i*math.tau/sides)+v*math.sin(i*math.tau/sides))*rr for z,rr in prof for i in range(sides)];faces=[];uv=[]
 for j in range(4):
  for i in range(sides):faces.append((j*sides+i,j*sides+(i+1)%sides,((j+1)%4)*sides+(i+1)%sides,((j+1)%4)*sides+i));uv.append([(i/sides,j/4),((i+1)/sides,j/4),((i+1)/sides,(j+1)/4),(i/sides,(j+1)/4)])
 return mesh(name,verts,faces,uv,mat,parent,leaf)
def manifold(fluid,lo):
 name='V04 leaf cooling warm return collector '+fluid;n=40;angles=[lo+.025+(math.pi-.05)*i/n for i in range(n+1)];prof=[(-.035,.600*F),(-.035,.635*F),(.035,.635*F),(.035,.600*F)];verts=[q(3.04)+A*z+radial(t)*rr for z,rr in prof for t in angles];faces=[];uv=[]
 for j in range(4):
  for i in range(n):faces.append((j*(n+1)+i,j*(n+1)+i+1,((j+1)%4)*(n+1)+i+1,((j+1)%4)*(n+1)+i));uv.append([(i/n,j/4),((i+1)/n,j/4),((i+1)/n,(j+1)/4),(i/n,(j+1)/4)])
 for edge in [0,n]:faces.append(tuple(j*(n+1)+edge for j in range(4)));uv.append([(0,0),(1,0),(1,1),(0,1)])
 return mesh(name,verts,faces,uv,'brass',core)
def core_port(name,fluid,theta,z,r,face_offset,host,radial_takeoff=False):
 center=point(z,r,theta)+A*face_offset;axis=A
 if radial_takeoff:
  obj=bpy.data.objects[host];tree=BVHTree.FromPolygons([obj.matrix_world@v.co for v in obj.data.vertices],[list(p.vertices) for p in obj.data.polygons]);center,axis,_,distance=tree.find_nearest(center);assert distance<.005;axis.normalize()
 stem=ring(name+' seated stem',center+axis*.030,axis,.017,.023,.070,'tube',core);ring(name+' captive union',center+axis*.055,axis,.0165,.028,.030,'brass',core);ring(name+' host flange',center+axis*.005,axis,.017,.021,.014,'brass',core)
 contact=center if radial_takeoff else center+radial(theta)*.020;ports.append({'name':name,'host':host,'contact_world_rest':list(contact),'cap_world_rest':list(center+axis*.064),'axis_world_rest':list(axis),'space':'core-rest-world','socket':stem.name});return center+axis*.064,axis
checkpoint('INPUT_VERIFIED')
for fluid,lo in [('water',-math.pi/2),('fuel',math.pi/2)]:manifold(fluid,lo)
def clamp_theta(theta,lo):
 center=lo+math.pi/2;theta=center+math.atan2(math.sin(theta-center),math.cos(theta-center));return max(lo+.065,min(lo+math.pi-.065,theta))
for idx in range(12):
 leaf=bpy.data.objects[f'Nozzle articulated petal {idx:02}'];theta=idx*math.tau/12;pivot=point(3.16,.50,theta);fluid='water' if idx in [0,1,2,9,10,11] else 'fuel';lo=-math.pi/2 if fluid=='water' else math.pi/2
 def lp(z,offset,lift=.045):return point(z,profile(z)+lift,theta+offset)-pivot
 def angle(z,outer):return (.19 if outer else .115)+(.010 if outer else .035)*math.exp(-((z-4.20)/.34)**2)
 points=[]
 for z in np.linspace(3.49,4.98,42):points.append(lp(float(z),-angle(float(z),False)))
 for t in np.linspace(0,math.pi,17)[1:]:
  w=(1-math.cos(t))/2;z=4.98+.055*math.sin(t);points.append(lp(z,-(angle(4.98,False)*(1-w)+angle(4.98,True)*w)))
 for z in np.linspace(4.98,3.43,42)[1:]:points.append(lp(float(z),-angle(float(z),True)))
 for t in np.linspace(0,math.pi,25)[1:]:
  w=(1-math.cos(t))/2;points.append(lp(3.43-.055*math.sin(t),angle(3.43,True)*(-1+2*w),.045+.020*math.sin(t)**2))
 for z in np.linspace(3.43,4.98,42)[1:]:points.append(lp(float(z),angle(float(z),True)))
 for t in np.linspace(0,math.pi,17)[1:]:
  w=(1-math.cos(t))/2;z=4.98+.055*math.sin(t);points.append(lp(z,angle(4.98,True)*(1-w)+angle(4.98,False)*w))
 for z in np.linspace(4.98,3.49,42)[1:]:points.append(lp(float(z),angle(float(z),False)))
 circuit=pipe(f'V04 leaf regenerative four-pass circuit {idx:02}',points,.018,'tube',leaf,True);anchors_for_leaf=[]
 for side in [-1,1]:
  for outer in [False,True]:
   for z in [3.72,4.55,4.86]:
    off=side*angle(z,outer);n=radial(theta+off);surface=lp(z,off,0);center=lp(z,off);tangent=(lp(z+.002,side*angle(z+.002,outer))-lp(z-.002,side*angle(z-.002,outer))).normalized();cross=tangent.cross(n).normalized();normal=n-tangent*n.dot(tangent);normal.normalize();roof=center-normal*.026;base=roof-normal*((roof-surface).dot(normal)+.002);tag=f'V04 leaf cooling saddle {idx:02} {len(anchors_for_leaf):02}';foot=cylinder(tag+' seated foot',base,roof,.030,'tube',leaf,True);ring(tag+' welded collar',center,tangent,.019,.027,.036,'brass',leaf,True)
    for sign in [-1,1]:
     base=surface+cross*(sign*.022);cylinder(tag+' fastener',base+n*.004,base+n*.029,.004,'tube',leaf,True,12);cylinder(tag+' fastener head',base+n*.025,base+n*.035,.0075,'brass',leaf,True,6)
    anchors_for_leaf.append({'foot':foot.name,'leaf_surface_local':list(surface),'pipe_center_local':list(center),'base_embedded_center_local':list(base),'roof_center_local':list(roof),'roof_axis_local':list(normal)})
 for kind,ep in [('inlet',points[0]),('outlet',points[-1])]:
  center=ep-A*.025;stem=ring(f'V04 leaf {kind} pressure socket {idx:02}',center,A,.019,.034,.095,'tube',leaf,True);ring(f'V04 leaf {kind} captive nut {idx:02}',center-A*.020,A,.018,.039,.035,'brass',leaf,True);ring(f'V04 leaf {kind} compression gasket {idx:02}',center+A*.018,A,.0175,.025,.014,'seal',leaf,True);ports.append({'name':stem.name,'host':leaf.name,'cap_local':list(ep),'back_cap_local':list(center-A*.040),'space':'leaf-local','socket':stem.name})
  rel=(center+pivot)/F-O;zz=rel.dot(A);tt=math.atan2(rel.dot(B),rel.dot(X));normal=radial(tt);surface=point(zz,profile(zz),tt)-pivot;cylinder(f'V04 leaf {kind} socket seated foot {idx:02}',surface-normal*.002,surface+normal*.037,.028,'tube',leaf,True)
  th=clamp_theta(theta+(-.13 if kind=='inlet' else .13),lo)
  if kind=='inlet':root,root_axis=core_port(f'V04 leaf supply root union {idx:02}',fluid,clamp_theta(theta+math.pi/12,lo),2.94,.685,0,'V04 stationary regenerative supply half '+fluid,True)
  else:root,root_axis=core_port(f'V04 leaf return root union {idx:02}',fluid,th,3.04,.6175,.035,'V04 leaf cooling warm return collector '+fluid)
  flex_jobs.append({'name':f'V04 leaf regenerative flex {kind} {idx:02}','leaf':leaf.name,'root_rest':root,'root_axis_rest':root_axis,'end_local':center-A*.040,'kind':kind,'leaf_index':idx,'fluid':fluid})
 circuits.append({'index':idx,'leaf':leaf.name,'pipe':circuit.name,'fluid':fluid,'longitudinal_passes':4,'root_ports':2,'saddles':anchors_for_leaf,'clearance_bypass':'Inner/outer lanes spread around central piston lug; root crossover lifted over reinforcing spine.','surface_offset':.045*F,'tube_radius':.018})
checkpoint('TWELVE_LEAF_CIRCUITS_AND_SEATED_SADDLES_CREATED')
collector_supports=[];host=bpy.data.objects['Main pressure chamber'];tree=BVHTree.FromPolygons([host.matrix_world@v.co for v in host.data.vertices],[list(p.vertices) for p in host.data.polygons])
for fluid,lo in [('water',-math.pi/2),('fuel',math.pi/2)]:
 for i in range(6):
  theta=lo+(i+.5)*math.pi/6;target=point(3.04,.615,theta);contact,normal,_,distance=tree.find_nearest(target);assert .005<distance<.12;axis=(target-contact).normalized();tag=f'V04 leaf collector welded support {fluid} {i:02}';cylinder(tag,contact-axis*.003,target+axis*.005,.018,'tube',core);cylinder(tag+' body weld',contact-axis*.002,contact+axis*.007,.026,'brass',core);cylinder(tag+' manifold weld',target-axis*.006,target+axis*.005,.026,'brass',core);collector_supports.append({'support':tag,'body_host':host.name,'collector':'V04 leaf cooling warm return collector '+fluid,'body_surface_point':list(contact),'collector_embedded_point':list(target),'measured_gap_before_support':distance})
# Return collectors join existing separated warm-return manifolds, using a
# route between adjacent ram stations and outside the supply header.
for fluid,theta in [('water',math.pi/12),('fuel',math.pi+math.pi/12)]:
 start=point(3.04,.635,theta);end=point(2.20,.685,theta);normal=radial(theta)
 for name,p,host in [('collector',start,'V04 leaf cooling warm return collector '+fluid),('receiver',end,'V04 stationary regenerative return half '+fluid)]:
  ring('V04 leaf return trunk '+name+' union '+fluid,p+normal*.027,normal,.020,.034,.070,'brass',core);ports.append({'name':'V04 leaf return trunk '+name+' '+fluid,'host':host,'contact_world_rest':list(p),'cap_world_rest':list(p+normal*.045),'space':'core-rest-world'})
 a=start+normal*.045;b=point(3.04,.80,theta);c=point(2.20,.80,theta);d=end+normal*.045;pts=[a*(1-t)**3+b*(3*(1-t)**2*t)+c*(3*(1-t)*t*t)+d*t**3 for t in np.linspace(0,1,49)];pipe('V04 leaf cooling common return trunk '+fluid,pts,.020,'brass',core)
# Bake each flexible link from the actual core and individual plate frames,
# not a blanket whole-engine sway. Both endpoint centers remain exact.
for job in flex_jobs:
 poses=[]
 for frame in range(66):
  s.frame_set(frame);bpy.context.view_layer.update();leaf=bpy.data.objects[job['leaf']];start=core.matrix_world@core_inv@job['root_rest'];end=leaf.matrix_world@job['end_local'];ax0=(core.matrix_world.to_3x3()@job['root_axis_rest']).normalized();ax1=(leaf.matrix_world.to_3x3()@A).normalized();p1=start+ax0*(.12 if job['kind']=='inlet' else .16);p2=end-ax1*.15;centerline=[start*(1-t)**3+p1*(3*(1-t)**2*t)+p2*(3*(1-t)*t*t)+end*t**3 for t in np.linspace(0,1,33)];poses.append(path_data(centerline,.016,12,True))
 verts,faces,uv=poses[0];o=mesh(job['name'],verts,faces,uv,'seal');o.shape_key_add(name='Basis');keys=[]
 for frame in range(1,65):
  key=o.shape_key_add(name=f'Leaf cooling flex pose {frame:02}')
  for v,co in zip(key.data,poses[frame][0]):v.co=co
  keys.append((frame,key))
 for frame in range(66):
  for pose,key in keys:key.value=1 if frame==pose or (frame==65 and pose==1) else 0;key.keyframe_insert('value',frame=frame)
 job['root_rest']=list(job['root_rest']);job['root_axis_rest']=list(job['root_axis_rest']);job['end_local']=list(job['end_local']);job['mesh']=o.name;job['ring_sides']=12;job['rings']=33
checkpoint('TWENTY_FOUR_HOST_FOLLOWING_FLEX_LINKS_BAKED')
# Fine warm edge/lip fringing. Keep the plate centers dark metal and char.
n=1024;y,x=np.mgrid[0:n,0:n]/(n-1);cell=(x*12+.5)%1;d=np.minimum(cell,1-cell);edge=np.exp(-(d/.040)**2);lip=np.exp(-((y-.985)/.018)**2);mask=.32*edge*(.25+.75*y**.8)+.22*lip;rgba=np.ones((n,n,4),np.float32);rgba[:,:,:3]=mask[:,:,None]*np.array([1,.15,.025]);im=bpy.data.images.new('V04 gentle leaf edge heat fringe.png',width=n,height=n,alpha=True);im.pixels.foreach_set(rgba.ravel());im.filepath_raw=str(R/'gentle-leaf-edge-heat-fringe.png');im.file_format='PNG';im.save();im.pack();mat=bpy.data.materials['V04 axial temper and charred bell petals'];bs=mat.node_tree.nodes['Principled BSDF'];tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=im;mat.node_tree.links.new(tex.outputs['Color'],bs.inputs['Emission Color'])
for frame in range(66):
 phi=((frame-1)%64)*math.tau/64;bs.inputs['Emission Strength'].default_value=.65*(1+.06*math.sin(phi)) if frame else 0;bs.inputs['Emission Strength'].keyframe_insert('default_value',frame=frame)
s.frame_set(1);bpy.context.view_layer.update();dst=R/'thetazine-v04-regenerative-study.blend';bpy.ops.wm.save_as_mainfile(filepath=str(dst),compress=True);checkpoint('NATIVE_LEAF_COOLING_SOURCE_SAVED')
for o in s.objects:o.select_set(o.type in ['MESH','EMPTY'] and not o.get('render_only_volume'))
bpy.ops.export_scene.gltf(filepath=str(R/'thetazine-v04-regenerative-study.glb'),use_selection=True,export_format='GLB',export_apply=True,export_current_frame=True,export_animations=True,export_animation_mode='SCENE',export_anim_scene_split_object=False,export_frame_range=True,export_force_sampling=True,export_morph=True,export_morph_animation=True,export_extras=True)
manifest['native_sha256']=sha(dst);manifest['glb_sha256']=sha(R/'thetazine-v04-regenerative-study.glb');manifest['mesh_count']=sum(o.type=='MESH' and not o.get('render_only_volume') for o in s.objects);manifest['leaf_regenerative_cooling']={'script_sha256':sha(pathlib.Path(__file__)),'input_native_sha256':sha(src),'circuits':circuits,'flex_links':flex_jobs,'ports':ports,'pipe_routes':routes,'added_meshes':[o.name for o in added],'collector_supports':collector_supports,'core_ownership_repairs':ownership_repairs,'edge_heat_texture_sha256':sha(R/'gentle-leaf-edge-heat-fringe.png'),'flow':'Existing independent supply half -> radial takeoff between ram stations -> flexible root inlet -> four longitudinal serpentine runs per primary leaf -> flexible return -> matching welded core return collector -> existing separated warm-return half. Six leaves per coolant stream; no mixed circuits.','owner_contract':'Independent pipes on each of twelve external moving primary plates, supported and clear of piston/hinge/neighbouring leaves; gentle warm edge/lip fringing with dark metal centers. Twelve internal overlap seals remain passive.','status':'AUTHORED_CANDIDATE_REQUIRES_NEW_CLEARANCE_AND_POSE_INSPECTION','validation_scope':'Existing46route audits do not cover these38new paths. Actual evaluated-mesh all-pose pipe/ram/hinge/leaf/pipe clearance and all new endpoint seats must be measured before promotion.','repair_basis':'Cold-state overlaps require narrower inset lanes; saddle roofs align with pipe tangent. Radial supply takeoffs avoid retaining band. Clevis cheeks and chamber-mounted standoffs/sleeve now belong to moving core rather than rigid outer frame.'};(R/'source-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8',newline='\n');checkpoint('NATIVE_AND_GLB_EXPORTED_REQUIRES_PILOT_AND_CLEARANCE');print('LEAF_COOLING_BUILT',manifest['mesh_count'],len(routes),len(ports))
