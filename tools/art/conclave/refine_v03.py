"""Authored housing/construction refinement; preserve supplied skull anatomy."""
import bpy,bmesh,json,math,sys,hashlib,shutil,importlib.util
from pathlib import Path
from mathutils import Vector,Matrix
R=Path(__file__).resolve().parents[3];OLD=R/'art/source-to-3d/conclave-center/v02-supplied-skull';O=OLD.parent/'v03-authored-housings';O.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(OLD/'conclave-center-v02.blend'));s=bpy.context.scene;root=bpy.data.objects['Conclave Center | ground origin'];contacts=json.loads((OLD/'contacts.json').read_text());changes=[]
def skull_signatures():
 return {o.name:hashlib.sha256(json.dumps(dict(vertices=[list(v.co) for v in o.data.vertices],uvs=[[list(d.uv) for d in layer.data] for layer in o.data.uv_layers],matrix=[list(row) for row in o.matrix_world]),sort_keys=True).encode()).hexdigest() for o in s.objects if o.name.startswith('Supplied DGordillo low-poly skull')}
original_skull_signatures=skull_signatures()
mats={k:bpy.data.materials['Conclave | '+k] for k in ['cast-frame','console-panels','edge-trim','control-keys','floor-tread','cable-jacket']}
# Complete side desks face the central operator recess. Transform every retained
# key, lid, hinge and screen consistently before replacing the large castings.
stations=[(0,.18,0,.60),(-.62,-.17,math.pi/4,.49),(.62,-.17,-math.pi/4,.49)]
previous=[(0,.18,0),(-.57,-.06,-.36),(.57,-.06,.36)]
for i,((cx,cy,yaw,w),(ox,oy,oa)) in enumerate(zip(stations,previous)):
 before=Matrix.Translation((ox,oy,0))@Matrix.Rotation(oa,4,'Z');after=Matrix.Translation((cx,cy,0))@Matrix.Rotation(yaw,4,'Z');delta=after@before.inverted()
 for obj in s.objects:
  if obj.name.startswith('Console %d | '%i) or obj.name.startswith('Console %d captive bezel screw'%i) or obj.name.startswith('Console %d selector knob'%i):obj.matrix_world=delta@obj.matrix_world
def uv(o):
 layer=o.data.uv_layers.new(name='AuthoredMemberUV');bounds=[[min(v.co[k] for v in o.data.vertices),max(v.co[k] for v in o.data.vertices)] for k in range(3)]
 for f in o.data.polygons:
  a=max(range(3),key=lambda j:abs(f.normal[j]));axes=[j for j in range(3) if j!=a]
  for li in f.loop_indices:
   v=o.data.vertices[o.data.loops[li].vertex_index].co;layer.data[li].uv=[.025+.95*(v[j]-bounds[j][0])/max(bounds[j][1]-bounds[j][0],1e-5) for j in axes]
def mesh(name,verts,faces,mat='cast-frame',matrix=None,bevel=.004):
 me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update();bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(me);bm.free();o=bpy.data.objects.new(name,me);s.collection.objects.link(o);o.parent=root
 if matrix:o.matrix_world=matrix
 o.data.materials.append(mats[mat]);uv(o)
 if bevel:
  mod=o.modifiers.new('Foundry edge radii','BEVEL');mod.width=min(bevel,.22*min(max(v.co[j] for v in me.vertices)-min(v.co[j] for v in me.vertices) for j in range(3)));mod.segments=3;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
 return o
def box(name,p,size,mat='cast-frame',matrix=None,bevel=.005):
 x,y,z=[v/2 for v in size];v=[(p[0]+a*x,p[1]+b*y,p[2]+c*z) for a,b,c in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
 return mesh(name,v,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],mat,matrix,bevel)
def replace(old,new):
 oldob=bpy.data.objects[old];bpy.data.objects.remove(oldob,do_unlink=True);new.name=old;changes.append(old)
def joint(a,b,why):contacts.append(dict(a=a.name if hasattr(a,'name') else a,b=b.name if hasattr(b,'name') else b,why=why))
def octrect(w,h,c):return [(-w/2+c,-h/2),(w/2-c,-h/2),(w/2,-h/2+c),(w/2,h/2-c),(w/2-c,h/2),(-w/2+c,h/2),(-w/2,h/2-c),(-w/2,-h/2+c)]
def ring_xz(name,outer,inner,yfront,yback,centerz,mat,matrix):
 verts=[(x,y,z+centerz) for poly,y in [(outer,yfront),(inner,yfront),(outer,yback),(inner,yback)] for x,z in poly];n=len(outer);faces=[]
 for i in range(n):
  j=(i+1)%n;faces += [(i,j,n+j,n+i),(2*n+i,3*n+i,3*n+j,2*n+j),(i,2*n+i,2*n+j,j),(n+i,n+j,3*n+j,3*n+i)]
 return mesh(name,verts,faces,mat,matrix,.003)
def cylinder(name,a,b,r,mat='edge-trim',n=32):
 a,b=Vector(a),Vector(b);q=(b-a).to_track_quat('Z','Y');v=[]
 for z in (-.5,.5):
  for i in range(n):v.append(tuple((a+b)/2+q@Vector((r*math.cos(i*math.tau/n),r*math.sin(i*math.tau/n),(b-a).length*z))))
 faces=[tuple(range(n-1,-1,-1)),tuple(n+i for i in range(n))]+[(i,(i+1)%n,n+(i+1)%n,n+i) for i in range(n)]
 return mesh(name,v,faces,mat,bevel=0)
# True octagonal sole and layered perimeter rim, retaining the ground contacts.
outline=octrect(1.76,1.72,.19);v=[(x,y,z) for z in (0,.13) for x,y in outline];faces=[tuple(range(7,-1,-1)),tuple(8+i for i in range(8))]+[(i,(i+1)%8,8+(i+1)%8,8+i) for i in range(8)]
replace('Octagonal sole casting',mesh('new sole',v,faces,'cast-frame',bevel=.009))
# Tread becomes a serviceable slatted grate with recessed undertray.
replace('Recessed standing tread',box('tread undertray',(0,-.48,.143),(.65,.69,.026),'cast-frame',bevel=.025))
for i in range(13):
 o=box('Removable tread transverse bar %02d'%i,(0,-.79+i*.052,.165),(.61,.028,.028),'floor-tread',bevel=.006);joint(o,'Recessed standing tread','grate bars seated on undertray')
for x in (-.32,.32):
 o=box('Tread retained side rail '+str(x),(x,-.48,.168),(.035,.72,.035),'edge-trim',bevel=.006);joint(o,'Recessed standing tread','rail retains removable grate')
# Replace plain rectangular back with a shouldered foundry silhouette.
outline=[(-.79,.105),(.79,.105),(.79,1.32),(.73,1.49),(.55,1.61),(.26,1.665),(-.26,1.665),(-.55,1.61),(-.73,1.49),(-.79,1.32)]
n=len(outline);v=[(x,y,z) for y in (.41,.65) for x,z in outline];f=[tuple(range(n-1,-1,-1)),tuple(n+i for i in range(n))]+[(i,(i+1)%n,n+(i+1)%n,n+i) for i in range(n)]
replace('Back shrine structural casting',mesh('shouldered back',v,f,'cast-frame',bevel=.012))
for x in (-.69,.69):
 rib=box('Back casting structural flute '+str(x),(x,.672,.83),(.115,.07,1.17),'cast-frame',bevel=.035);joint(rib,'Back shrine structural casting','rear vertical flute intersects casting')
 for z in (.32,.73,1.13):
  clamp=box('Rear flute strap '+str((x,z)),(x,.717,z),(.14,.035,.055),'edge-trim');joint(clamp,rib,'strap seated on flute')
for index,(cx,cy,yaw,w) in enumerate(stations):
 M=Matrix.Translation((cx,cy,0))@Matrix.Rotation(yaw,4,'Z');pre='Console %d | '%index
 # Cast monitor shell: real aperture and taper in depth; no solid box behind screen.
 front=octrect(w,.57,.048);rear=octrect(w*.88,.49,.05);inner=octrect(w*.805,.34,.026)
 verts=[(x,y,z+1.10) for poly,y in [(front,-.113),(rear,.224),(inner,-.113),(inner,.125)] for x,z in poly];faces=[]
 for i in range(8):
  j=(i+1)%8;faces += [(i,j,8+j,8+i),(i,16+i,16+j,j),(16+i,24+i,24+j,16+j),(8+i,8+j,24+j,24+i)]
 replace(pre+'deep monitor cabinet',mesh('cast monitor shell',verts,faces,'cast-frame',M,.006))
 bezel=ring_xz('stepped inset bronze bezel',octrect(w*.94,.455,.03),octrect(w*.805,.34,.026),-.133,-.104,1.12,'edge-trim',M);replace(pre+'brass monitor rim',bezel)
 gasket=ring_xz(pre+'screen seated gasket',octrect(w*.84,.365,.028),octrect(w*.77,.30,.022),-.108,-.078,1.12,'cable-jacket',M);joint(gasket,pre+'brass monitor rim','continuous gasket seats in bezel recess')
 for row in contacts:
  if row['a']==pre+'recessed green doctrine CRT':row['b']=gasket.name;row['why']='glass edge seated inside continuous gasket'
 # Tiny rail lips explain screen retention without obscuring active glass.
 for z in (.938,1.302):
  rail=box(pre+'screen retaining lip '+str(z),(0,-.139,z),(w*.83,.018,.022),'control-keys',M,.003);joint(rail,pre+'brass monitor rim','screen retained by continuous metal lip')
 # Chamfered sloped deck replaces the flat rectangular red slab.
 poly=octrect(w+.045,.55,.055);verts=[(x,y-.13,.75+y*math.tan(.12)+dz) for dz in (-.055,.055) for x,y in poly]
 faces=[tuple(range(7,-1,-1)),tuple(8+i for i in range(8))]+[(i,(i+1)%8,8+(i+1)%8,8+i) for i in range(8)]
 replace(pre+'sloped control deck',mesh('sloped cast desk',verts,faces,'console-panels',M,.006))
 # Rolled front bead is continuous across the load-bearing desk front edge.
 a=M@Vector((-w*.42,-.407,.717));b=M@Vector((w*.42,-.407,.717));lip=cylinder(pre+'rolled front edge',a,b,.017);joint(lip,pre+'sloped control deck','front edge rolled onto deck casting')
 # Key tray inset follows desk inclination. Existing actual keycaps are preserved.
 tray=box(pre+'recessed keyboard tray',(0,-.258,.781),(w*.76,.212,.013),'cable-jacket',M,.006);tray.rotation_euler.x=.12;joint(tray,pre+'sloped control deck','keyboard tray inset into sloped top')
 # Control dial and switch banks have mounted sockets and real face geometry.
 for side in (-1,1):
  cheek=box(pre+'tapered pedestal side cheek '+str(side),(side*w*.35,-.005,.42),(.045,.36,.56),'cast-frame',M,.012);joint(cheek,pre+'grounded pedestal','cheek carries deck into sole')
  collar=box(pre+'recessed service lid surround '+str(side),(side*w*.28,-.216,.43),(.035,.028,.38),'edge-trim',M,.006);joint(collar,pre+'grounded pedestal','service opening surround seated into pedestal')
  # Three-point cast haunch under the desk wing, rather than an unsupported slab.
  x=side*w*.38;profile=[(-.17,.39),(-.17,.68),(.12,.73),(.12,.65)];vs=[(x+dx,y,z) for dx in (-.018,.018) for y,z in profile];haunch=mesh(pre+'desk load rib '+str(side),vs,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],'cast-frame',M,.004);joint(haunch,pre+'grounded pedestal','haunch root enters pedestal');joint(haunch,pre+'sloped control deck','haunch carries desk wing')
 # Rear connector plate and ventilation bank, spaced from the central service cover.
 rearplate=box(pre+'rear connector backplate',(0,.230,1.10),(w*.75,.022,.36),'console-panels',M,.016);joint(rearplate,pre+'deep monitor cabinet','removable rear connector cover seats into shell')
 for j in range(6):
  vent=box(pre+'recessed ventilation fin %d'%j,(0,.248,.985+j*.032),(w*.56,.022,.012),'cast-frame',M,.003);joint(vent,rearplate,'louver root enters removable cover')
 # Lateral restrained control detail fits beside keys, rather than floating hardware.
 badge=box(pre+'engraved control legend',(0,-.375,.781),(w*.20,.025,.012),'edge-trim',M,.004);joint(badge,pre+'sloped control deck','legend plate retained on front desk lip')
 mark=box(pre+'legend engraved rule',(0,-.375,.788),(w*.15,.006,.005),'cast-frame',M,0);joint(mark,badge,'engraved dark rule in legend face')
 for j in range(3):
  knob=bpy.data.objects.get('Console %d selector knob %d'%(index,j))
  if knob:knob.location=M@Vector(((j-1)*w*.25,-.14,.824))
 for side in (-1,1):
  p=M@Vector((side*w*.43,-.25,.792));q=M@Vector((side*w*.43,-.25,.823));dial=cylinder(pre+'mounted side control dial '+str(side),p,q,w*.055,'edge-trim',24);joint(dial,pre+'sloped control deck','dial socket retained in desk casting')
# An annular backing makes each unchanged supplied skull's mount explicit.
for i in range(3):
 head=bpy.data.objects['Supplied DGordillo low-poly skull '+str(i)];x,y,z=head.location;radius=.172 if i==0 else .112
 plate=cylinder('Skull retained medallion '+str(i),(x,.406,z),(x,.431,z),radius,'edge-trim',48);joint(plate,'Back shrine structural casting','medallion cast onto shrine backing');joint(head,plate,'supplied skull retained on medallion rear seat')
# Braced candle cups follow the original shrine silhouette; static adornments.
for o in list(s.objects):
 if o.name.startswith('Shrine lamp phosphor lens'):bpy.data.objects.remove(o,do_unlink=True)
contacts=[c for c in contacts if not c['a'].startswith('Shrine lamp phosphor lens')]
wax=bpy.data.materials.new('Conclave V03 | aged ritual wax');wax.diffuse_color=(.43,.33,.15,1);wax.use_nodes=True;wax.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.43,.33,.15,1);wax.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.8;mats['wax']=wax
flame=bpy.data.materials.new('Conclave V03 | static candle flame');flame.use_nodes=True;b=flame.node_tree.nodes.get('Principled BSDF');b.inputs['Base Color'].default_value=(1,.22,.012,1);b.inputs['Emission Color'].default_value=(1,.32,.015,1);b.inputs['Emission Strength'].default_value=2;mats['flame']=flame
for x,y,base in [(-.71,.48,1.66),(.71,.48,1.66),(-.36,.39,1.76),(.36,.39,1.76)]:
 stem=cylinder('Candle cup structural stem '+str(x),(x,y,1.55),(x,y,base),.026);joint(stem,'Back shrine structural casting','ritual cup stem embeds into shrine')
 cup=cylinder('Retained ritual candle cup '+str(x),(x,y,base-.015),(x,y,base+.035),.065);joint(cup,stem,'cup seated on retained stem')
 candle=cylinder('Wax candle '+str(x),(x,y,base+.025),(x,y,base+.18),.033,'wax',24);joint(candle,cup,'candle seated inside metal cup')
 wick=cylinder('Candle wick '+str(x),(x,y,base+.17),(x,y,base+.194),.004,'cable-jacket',8);joint(wick,candle,'wick enters wax body')
 bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=8,radius=1,location=(x,y,base+.215));o=bpy.context.object;o.scale=(.017,.017,.044);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.name='Static candle flame '+str(x);o.parent=root;o.data.materials.append(flame);uv(o);joint(o,wick,'static flame begins at wick')
# Rebuild the internal service paths at the moved console seats. Lower armored
# looms are carried by sole brackets; none is an external gameplay interface.
for obj in list(s.objects):
 if obj.get('pipette_route_id'):bpy.data.objects.remove(obj,do_unlink=True)
spec=importlib.util.spec_from_file_location('conclave_refine_pipette',R/'tools/fmpl/pipette/blender_adapter.py');adapter=importlib.util.module_from_spec(spec);sys.modules[spec.name]=adapter;spec.loader.exec_module(adapter)
requests=[];plans=[]
def service_route(name,points,start_parent,end_parent,family='single_wire',diameter=.035):
 a,b=Vector(points[0]),Vector(points[-1]);request=dict(id=name,family=family,payload='signal',size=dict(outer_diameter=diameter,wall_fraction=.18 if family=='segmented_conduit' else 0),material_id=mats['cable-jacket'].name,path=dict(kind='waypoints',points=points),joint_pitch=.065,start_socket=dict(id=name+'.source',xyz=list(a),normal=list((Vector(points[1])-a).normalized()),role='source',payloads=['signal'],parent_mesh=start_parent),end_socket=dict(id=name+'.sink',xyz=list(b),normal=list((Vector(points[-2])-b).normalized()),role='sink',payloads=['signal'],parent_mesh=end_parent),fittings=dict(start='cable_gland',end='cable_gland'),supports=dict(mechanical_brackets='separately modeled sole saddles'),behavior=dict(internal_visual_service_only=True,live_binding_implemented=False),keep_outs=[])
 if family!='segmented_conduit':request.pop('joint_pitch')
 plan=adapter.core.plan(request);col,objects=adapter.build(plan,mats['cable-jacket'],mats['edge-trim'])
 for obj in objects:obj.parent=root;uv(obj)
 requests.append(request);plans.append(plan)
for i,(cx,cy,yaw,w) in enumerate(stations):
 M=Matrix.Translation((cx,cy,0))@Matrix.Rotation(yaw,4,'Z');a=list(M@Vector((0,.245,1.10)));end=[cx,.416,.91]
 points=[a,[a[0],a[1]+.11,1.1],[cx,.36,1.04],end]
 service_route('conclave-v03-console-service-'+str(i),points,'Console %d | rear connector backplate'%i,'Back shrine structural casting')
for sign,index in [(-1,1),(1,2)]:
 cx,cy,yaw,w=stations[index];M=Matrix.Translation((cx,cy,0))@Matrix.Rotation(yaw,4,'Z')
 pod=box('Lower rear signal junction '+str(sign),(sign*.77,.57,.38),(.10,.13,.13),'cast-frame',bevel=.012);joint(pod,'Back shrine structural casting','junction pod seated against rear shell flank')
 end=list(M@Vector((sign*w*.39,0,.43)));seat=box('Console lower gland seat '+str(sign),(sign*w*.39,0,.43),(.05,.09,.10),'cast-frame',M,.009);joint(seat,'Console %d | grounded pedestal'%index,'gland shoe retained on pedestal outer cheek')
 points=[[sign*.795,.57,.38],[sign*.86,.50,.37],[sign*.88,.35,.35],[sign*.88,-.24,.35],[sign*.85,-.39,.37],end]
 service_route('conclave-v03-armored-return-'+str(sign),points,pod.name,seat.name,'segmented_conduit',.052)
 for j,y in enumerate((.26,-.15)):
  bracket=box('Armored loom grounded saddle '+str((sign,j)),(sign*.85,y,.235),(.125,.07,.21),'cast-frame',bevel=.007);joint(bracket,'Octagonal sole casting','saddle reaches sole top')
  # Strap across the upper jacket with two vertical legs sunk into the saddle.
  strap=box('Armored loom retained strap '+str((sign,j)),(sign*.88,y,.383),(.082,.023,.018),'edge-trim',bevel=.004)
  for side in (-1,1):
   leg=box('Loom strap leg '+str((sign,j,side)),(sign*.88+side*.033,y,.35),(.014,.023,.07),'edge-trim',bevel=.003);joint(leg,bracket,'strap leg fastened into grounded saddle');joint(strap,leg,'strap bends continuously onto retaining leg')
# Dedicated patinated console finish, retaining source-indexed map provenance.
T=O/'textures';T.mkdir(exist_ok=True)
for role,mat in list(mats.items()):
 if role not in ('cast-frame','console-panels','edge-trim'):continue
 local=mat.copy();local.name='Conclave V03 | '+role
 for node in local.node_tree.nodes:
  if node.type=='TEX_IMAGE' and node.name.endswith('ALBEDO'):
   path=O/'textures'/(role+'-albedo.png')
   if path.exists():im=bpy.data.images.load(str(path));im.pack();node.image=im
 for o in s.objects:
  if o.type=='MESH':
   for slot in o.material_slots:
    if slot.material==mat:slot.material=local
 mats[role]=local
for name in ['contract.json','capture-profile.json','pipette-requests.json','pipette-plans.json','support-objects.json','original-prototype.lua','supplied-skull-reuse.json','ATTRIBUTION.txt','surface-manifest.json']:
 shutil.copy2(OLD/name,O/name)
(O/'pipette-requests.json').write_text(json.dumps(requests,indent=2)+'\n');(O/'pipette-plans.json').write_text(json.dumps(plans,indent=2)+'\n')
surfaces=json.loads((O/'surface-manifest.json').read_text())
for role in ('cast-frame','console-panels','edge-trim'):
 path=T/(role+'-albedo.png');surfaces[role]['maps']['albedo'].update(path=path.relative_to(R).as_posix(),sha256=hashlib.sha256(path.read_bytes()).hexdigest());surfaces[role]['refinement']='Dedicated subdued patina derivative; compressed color variation avoids giant mottled patches. Physical lips/retainers carry edge highlights.'
(O/'surface-manifest.json').write_text(json.dumps(surfaces,indent=2)+'\n')
assert skull_signatures()==original_skull_signatures,'Supplied skull geometry/UV/frame changed'
orientation=[]
for i,(cx,cy,yaw,w) in enumerate(stations):
 M=Matrix.Translation((cx,cy,0))@Matrix.Rotation(yaw,4,'Z');normal=M.to_3x3()@Vector((0,-1,0));center=M@Vector((0,.085,1.12));aim=Vector((0,-.79,1.12))-center
 orientation.append(dict(console=i,front_normal=list(normal),facing_middle_dot=normal.dot(aim.normalized()),yaw_degrees=math.degrees(yaw),position=[cx,cy,0]))
assert all(x['facing_middle_dot']>.99 for x in orientation),'Console points away from central operator recess'
(O/'orientation-and-skull-preservation.json').write_text(json.dumps(dict(operator_target=[0,-.79,1.12],orientation=orientation,skull_geometry_uv_and_frame_unchanged=original_skull_signatures),indent=2)+'\n')
(O/'contacts.json').write_text(json.dumps(contacts,indent=2)+'\n');(O/'refinement.json').write_text(json.dumps(dict(previous=str(OLD/'conclave-center-v02.blend'),source_skulls_preserved=True,replaced_major_parts=changes,stage='review candidate; not integrated',surface_plan={'console':'bronze patinated sloped casting, retained keyboard tray and real screen aperture','frame':'shouldered cast back, mounted medallions and supporting flutes','ground':'octagonal sole, removable slatted operator grate','services':'retained rear connector covers and louvers; original internal signal looms retained','ritual':'four mounted candle cups, static source-reference adornment; no new operating state'}),indent=2)+'\n')
sys.path.insert(0,str(R/'tools/fmpl'));from blender_camera_guard import assert_clean;assert_clean(s,json.loads((O/'capture-profile.json').read_text()),bpy)
prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='OPTIX';prefs.get_devices()
for d in prefs.devices:d.use=d.type=='OPTIX'
if any(d.use for d in prefs.devices):s.cycles.device='GPU'
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(O/'conclave-center-v03.blend'),compress=True)
bpy.ops.object.select_all(action='DESELECT')
for o in s.objects:
 if o.type=='MESH':o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(O/'conclave-center-v03.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_cameras=False,export_lights=False)
s.render.filepath=str(O/'source-front.png');bpy.ops.render.render(write_still=True);print('CONCLAVE_AUTHORED_REFINEMENT_SAVED',len(changes),len(contacts),flush=True)
