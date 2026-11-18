"""Conclave Center: grounded three-console governance shrine, no invented process."""
import bpy,math,json,sys,importlib.util,hashlib
from pathlib import Path
from mathutils import Vector,Matrix
if '--allow-rejected-study' not in sys.argv:
 raise RuntimeError('Owner rejected the procedural skull source. Use replace_supplied_skull.py with the supplied Low Poly Skull archive. This builder is retained only as a rejected V01 study.')
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/conclave-center/v01'
sys.path.insert(0,str(R/'tools/fmpl'))
from blender_camera_guard import install_canonical_camera,assert_clean
def module(name,path):
 s=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(s);sys.modules[name]=m;s.loader.exec_module(m);return m
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
bpy.ops.wm.read_factory_settings(use_empty=True);scene=bpy.context.scene
imp=module('conclave_fmpl_materials',R/'art/source-to-3d/shared-parts/industrial-asset-library/import_materials.py')
surfaces=json.loads((O/'surface-manifest.json').read_text());lib=imp.import_materials(R,sorted({x['fmpl_material_id'] for x in surfaces.values()}),pack=True);mats={}
for role,record in surfaces.items():
 m=lib[record['fmpl_material_id']].copy();m.name='Conclave | '+role
 for n in m.node_tree.nodes:
  if n.type=='TEX_IMAGE':
   kind='albedo' if n.name.endswith('ALBEDO') else 'orm' if n.name.endswith('ORM') else 'normal'
   im=bpy.data.images.load(str(R/record['maps'][kind]['path']),check_existing=True);im.colorspace_settings.name='sRGB' if kind=='albedo' else 'Non-Color';im.pack();n.image=im
 m['conclave_surface_plan']=record['surface_plan'];mats[role]=m
screen=bpy.data.materials.new('Conclave | phosphor CRT');screen.use_nodes=True;bs=screen.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.29;bs.inputs['Emission Strength'].default_value=.55
n=screen.node_tree.nodes.new('ShaderNodeTexImage');n.image=bpy.data.images.load(str(O/'textures/doctrine-crt-albedo.png'));n.image.pack();screen.node_tree.links.new(n.outputs['Color'],bs.inputs['Base Color']);screen.node_tree.links.new(n.outputs['Color'],bs.inputs['Emission Color']);mats['screen']=screen
root=bpy.data.objects.new('Conclave Center | ground origin',None);scene.collection.objects.link(root)
contacts=[];support_objects=[]
def uv(obj):
 if not obj.data.uv_layers:obj.data.uv_layers.new(name='ConclaveUV')
 lows=[min(v.co[k] for v in obj.data.vertices) for k in range(3)];highs=[max(v.co[k] for v in obj.data.vertices) for k in range(3)]
 for face in obj.data.polygons:
  axis=max(range(3),key=lambda k:abs(face.normal[k]));axes=[k for k in range(3) if k!=axis]
  lo=[lows[k] for k in axes];hi=[highs[k] for k in axes]
  for li in face.loop_indices:
   p=obj.data.vertices[obj.data.loops[li].vertex_index].co
   obj.data.uv_layers.active.data[li].uv=tuple(.025+.95*(p[k]-lo[j])/max(hi[j]-lo[j],1e-5) for j,k in enumerate(axes))
def own(obj,name,mat):
 obj.name=name;obj.parent=root
 obj.data.materials.clear();obj.data.materials.append(mats[mat]);uv(obj);obj['authored_role']=name
 return obj
def box(name,pos,size,mat='cast-frame',bevel=.012):
 bpy.ops.mesh.primitive_cube_add(size=1,location=pos);o=bpy.context.object;o.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bevel:
  mod=o.modifiers.new('Cast edge easing','BEVEL');mod.width=bevel;mod.segments=2;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
 return own(o,name,mat)
def cyl(name,pos,r,depth,mat='edge-trim',axis='Z',verts=32):
 bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=r,depth=depth,location=pos);o=bpy.context.object
 if axis=='Y':o.rotation_euler.x=math.pi/2
 if axis=='X':o.rotation_euler.y=math.pi/2
 return own(o,name,mat)
def beam(name,a,b,r,mat='cast-frame'):
 a,b=Vector(a),Vector(b);o=cyl(name,(a+b)/2,r,(b-a).length,mat);o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o
def joint(a,b,why):contacts.append(dict(a=a.name,b=b.name,why=why))
# Foundation is an equipment sole with a usable front operator recess.
base=box('Octagonal sole casting',(0,0,.065),(1.76,1.72,.13),bevel=.17)
tread=box('Recessed standing tread',(0,-.48,.15),(.68,.72,.04),'floor-tread',.025);joint(tread,base,'standing tread supported on sole')
for x in (-.72,.72):
 for y in (-.66,.66):
  foot=box('Grounded sole pad '+str((x,y)),(x,y,.025),(.30,.30,.05),'cast-frame',.025);support_objects.append(foot.name);joint(foot,base,'ground contact through sole')
  bolt=cyl('Foundation retained anchor '+str((x,y)),(x,y,.146),.035,.04,verts=6);joint(bolt,base,'anchor seated in sole')
# Rounded rear shrine shell, real depth. Uprights retain all three consoles.
back=box('Back shrine structural casting',(0,.53,.865),(1.58,.24,1.52),'cast-frame',.12);joint(back,base,'continuous rear shell reaches sole')
panel=box('Rear access cover',(0,.669,.73),(.86,.035,.79),'console-panels',.028);joint(panel,back,'rear service panel retained on shell')
for x in (-.36,.36):
 for z in (.39,1.07):
  b=cyl('Rear access captive screw '+str((x,z)),(x,.697,z),.024,.018,'edge-trim','Y',6);joint(b,panel,'service cover screw contact')
# Cog crown is a ring, not a solid intersecting disc.
bpy.ops.mesh.primitive_torus_add(major_radius=.54,minor_radius=.065,major_segments=64,minor_segments=10,location=(0,.51,1.37),rotation=(math.pi/2,0,0));crown=own(bpy.context.object,'Crown cog continuous rim','edge-trim');joint(crown,back,'cog rim cast onto backplate')
for i in range(13):
 a=math.pi*i/12;tooth=box('Crown cog tooth %02d'%i,(.615*math.cos(a),.51,1.37+.615*math.sin(a)),(.12,.13,.15),'cast-frame',.009);tooth.rotation_euler.y=-a+math.pi/2;joint(tooth,crown,'cog tooth root enters continuous ring')
skull=module('conclave_cast_anatomy',O/'reused_cast_skull.py')
for i,(x,z,size) in enumerate([(0,1.64,1.0),(-.48,1.48,.61),(.48,1.48,.61)]):
 print('CONCLAVE_SKULL',i,flush=True)
 o=skull.build_cast_skull((x,.39 if i else .355,z),size);own(o,'Retained anatomical skull casting '+str(i),'skull-cast');joint(o,back,'cast skull rear seated on shrine backing')
# Three distinct inward-facing desks. Root transforms let the whole local
# console, keys and mounted fittings remain editable and mechanically aligned.
terminals=[]
for index,(cx,cy,yaw,w) in enumerate([(0,.18,0,.60),(-.57,-.06,-.36,.49),(.57,-.06,.36,.49)]):
 frame=Matrix.Translation(Vector((cx,cy,0))) @ Matrix.Rotation(yaw,4,'Z')
 def pos(x,y,z):return frame @ Vector((x,y,z))
 def localbox(name,p,d,mat='cast-frame',bev=.012):
  o=box('Console %d | '%index+name,pos(*p),d,mat,bev);o.rotation_euler.z=yaw;return o
 leg=localbox('grounded pedestal',(0,0,.405),(w*.70,.39,.60));joint(leg,base,'pedestal on sole; no floating monitor');
 deck=localbox('sloped control deck',(0,-.13,.75),(w+.045,.55,.11),'console-panels');deck.rotation_euler.x=.12;joint(deck,leg,'keyboard deck carried by pedestal')
 housing=localbox('deep monitor cabinet',(0,.085,1.10),(w,.27,.57));joint(housing,deck,'monitor lower edge rests in deck')
 bezel=localbox('brass monitor rim',(0,-.064,1.12),(w*.91,.04,.43),'edge-trim');joint(bezel,housing,'bezel retained on cabinet')
 glass=localbox('recessed green doctrine CRT',(0,-.088,1.12),(w*.79,.012,.32),'screen',.018);joint(glass,bezel,'recessed screen inside retained bezel')
 for row in range(4):
  for col in range(9):
   key=localbox('seated keyboard key %d %d'%(row,col),((col-4)*w*.078,-.33+row*.047,.789+row*.0056),(w*.062,.033,.025),'control-keys',.003);key.rotation_euler.x=.12;joint(key,deck,'key stem embedded in inclined deck')
 for x in (-w*.40,w*.40):
  b=cyl('Console %d captive bezel screw'%index,pos(x,-.092,1.30),.015,.025,'edge-trim','Y',6);b.rotation_euler.z=yaw;joint(b,bezel,'screw fastens visible bezel')
 for j in range(3):
  b=cyl('Console %d selector knob %d'%(index,j),pos((j-1)*w*.25,-.03,.84),.024,.04,'edge-trim',verts=20);joint(b,deck,'rotary control seated in desk')
 terminals.append(dict(index=index,rear=tuple(pos(0,.23,1.08)),housing=housing.name))
 # Pedestal removable front storage/service panel: one-slot container remains native.
 hatch=localbox('service lid',(0,-.207,.43),(w*.53,.022,.32),'console-panels',.015);joint(hatch,leg,'service lid closes pedestal aperture')
 hinge=localbox('service lid retained hinge',(w*.29,-.207,.43),(.035,.03,.24),'edge-trim',.005);joint(hinge,leg,'hinge fixed to pedestal')
# Internal-only signal looms. No external Factorio circuit connection implied.
adapter=module('conclave_pipette',R/'tools/fmpl/pipette/blender_adapter.py');requests=[];plans=[]
for t in terminals:
 i=t['index'];a=list(t['rear']);b=[a[0],.55,.75];points=[a,[a[0],.42,1.08],[a[0],.55,.95],b]
 req=dict(id='conclave-internal-signal-'+str(i),family='single_wire',payload='signal',size=dict(outer_diameter=.035,wall_fraction=0),material_id=mats['cable-jacket'].name,path=dict(kind='waypoints',points=points),start_socket=dict(id='console-'+str(i)+'.gland',xyz=a,normal=[0,1,0],role='source',payloads=['signal'],parent_mesh=t['housing']),end_socket=dict(id='backplane-'+str(i)+'.gland',xyz=b,normal=[0,0,1],role='sink',payloads=['signal'],parent_mesh=back.name),fittings=dict(start='cable_gland',end='cable_gland'),supports={},behavior=dict(internal_visual_service_only=True,live_binding_implemented=False),keep_outs=[])
 plan=adapter.core.plan(req);col,objects=adapter.build(plan,mats['cable-jacket'],mats['edge-trim'])
 for o in objects:o.parent=root;uv(o)
 requests.append(req);plans.append(plan)
# Shrine lamps, seated stems; static supported signal lamps, no invented fire cycle.
for x in (-.71,.71):
 stem=cyl('Shrine lamp mounted stem '+str(x),(x,.48,1.56),.04,.28);joint(stem,back,'lamp stem enters structural rear casting')
 lens=cyl('Shrine lamp phosphor lens '+str(x),(x,.48,1.72),.047,.08,'screen');joint(lens,stem,'lens retained in stem cup')
profile=dict(camera_policy='fmpl.factorio45.v1',capture_kind='entity',orientation_policy='rotatable',directions=[0,90,180,270],source_size=640,states={'idle':[1]},camera_override=dict(type='ORTHO',elevation_deg=45,azimuth_deg=0,distance=8*math.sqrt(2),target=[0,0,.79],ortho_scale=3.15,shift_x=0,shift_y=0))
camera_receipt=install_canonical_camera(scene,profile,bpy)
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True;scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA';scene.view_settings.view_transform='AgX'
scene.world=bpy.data.worlds.new('Neutral world');scene.world.use_nodes=True;scene.world.node_tree.nodes.get('Background').inputs[0].default_value=(.18,.18,.18,1)
for name,loc,power,size in [('key',(-3,-4,6),500,4),('fill',(3,-1,4),260,3),('rim',(0,4,5),380,3)]:
 data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size;o=bpy.data.objects.new(name,data);scene.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,.8))-o.location).to_track_quat('-Z','Y').to_euler()
# The export is mesh-only, includes modifiers; cameras/lights remain source-only.
for o in scene.objects:o.select_set(o.type=='MESH')
bpy.ops.object.select_all(action='DESELECT')
for o in scene.objects:
 if o.type=='MESH':o.select_set(True)
contract=dict(id='tech-priests-conclave-center',type='container',footprint=[2,2],collision_box=[[-.9,-.9],[.9,.9]],selection_box=[[-1,-1],[1,1]],inventory_size=1,max_health=450,ground_z=0,interfaces=dict(fluid=[],electrical=[],circuit=[]),rotation='Native plain container is fixed-facing; four source rotations supplied for inspection only. Do not alter native gameplay to force rotation.',animation='Static governance console; native prototype has no working state.',standard_inserter_access=True,model_reconstruction='emm13.png reference; original Conclave 3D source unlocated',no_owner_approval_inferred=True)
(O/'contract.json').write_text(json.dumps(contract,indent=2)+'\n');(O/'contacts.json').write_text(json.dumps(contacts,indent=2));(O/'pipette-requests.json').write_text(json.dumps(requests,indent=2));(O/'pipette-plans.json').write_text(json.dumps(plans,indent=2));(O/'capture-profile.json').write_text(json.dumps(profile,indent=2));(O/'support-objects.json').write_text(json.dumps(support_objects))
scene['conclave_contract']=json.dumps(contract);scene['fmpl_camera_receipt']=json.dumps(camera_receipt);assert_clean(scene,profile,bpy);bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(O/'conclave-center-v01.blend'),compress=True)
bpy.ops.export_scene.gltf(filepath=str(O/'conclave-center-v01.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_cameras=False,export_lights=False)
scene.render.filepath=str(O/'source-front.png');bpy.ops.render.render(write_still=True)
print('CONCLAVE_CONSTRUCTION_SAVED',len(contacts),'recorded contacts',flush=True)
