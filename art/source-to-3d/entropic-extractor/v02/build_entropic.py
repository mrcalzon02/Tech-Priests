"""Enclosed blackstone fragment burner-generator reliquary."""
import bpy,bmesh,json,math,hashlib,sys,tempfile
from pathlib import Path
from mathutils import Vector
O=Path(__file__).resolve().parent
def locate_repo():
 for parent in (O,*O.parents):
  for candidate in (parent,parent/'model-production'):
   if (candidate/'tools/fmpl/FMPL.json').is_file():return candidate
 raise FileNotFoundError('Canonical FMPL source checkout required')
REPO=locate_repo();sys.path.insert(0,str(O));sys.path.insert(0,str(REPO/'art/source-to-3d/shared-parts/industrial-asset-library'));sys.path.insert(0,str(REPO/'tools/fmpl'))
from mesh_util import box,cylinder,tube,mesh
from fmpl_uv import cylinder_uv,sweep_uv,panel_uv
from import_materials import import_materials
from blender_camera_guard import install_canonical_camera,assert_clean,temporary_inspection_camera
(O/'export-temp').mkdir(exist_ok=True);tempfile.tempdir=str(O/'export-temp')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
bpy.ops.wm.read_factory_settings(use_empty=True);s=bpy.context.scene
col=bpy.data.collections.new('ENTROPIC | enclosed manufacturing cathedral');s.collection.children.link(col);root=bpy.data.objects.new('EXPORT | Entropic Extractor',None);col.objects.link(root)
ids=['ferrocrete_dark','gunmetal_dark','machine_steel','brass','martian_red','glass','insulator','machined_bright','indicator_green','dark_recess','iron']
catalog=json.loads((REPO/'art/source-to-3d/shared-parts/industrial-asset-library/catalog.json').read_text());provenance={}
for rec in catalog['materials']:
 if rec['material_id']not in ids:continue
 maps={}
 for kind,entry in rec['maps'].items():
  p=REPO/entry['source_path'];data=p.read_bytes();blob=hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest();assert blob==entry['git_blob_sha']
  maps[kind]={'source_path':entry['source_path'],'git_blob_sha':blob,'sha256':sha(p),'color_space':'sRGB'if kind=='albedo'else'Non-Color'}
 provenance[rec['material_id']]={'family':rec['family'],'source_commit':catalog['source_commit'],'maps':maps}
base=import_materials(REPO,ids,pack=True);mats={};roles=[]
for mid in ids:
 m=base[mid].copy();m.name='ENTROPIC FMPL | '+mid;m['entropic_surface_role']=mid;m['fmpl_model_specific_placement']='Closed power reliquary: dressed stone footing, forged mantle, supported copper windings, ceramic cores, blind green panes, thermal fins and cooling fan; physical UV1.25/tile.';mats[mid]=m
 roles.append({'role':mid,'fmpl_material_id':mid,'model_specific_instance':m.name,'original_maps':provenance[mid]['maps'],'texture_repeat_per_tile':1.25})
iron=mats['gunmetal_dark'];steel=mats['machine_steel'];bronze=mats['brass'];red=mats['martian_red'];glass=mats['glass'];dark=mats['dark_recess']
def B(n,p,d,m=iron,parent=root,bevel=.02):return box('ENTROPIC | '+n,p,d,m,col,parent,bevel)
def C(n,p,r,d,m=bronze,axis='Z',parent=root,seg=48):return cylinder('ENTROPIC | '+n,p,r,d,m,col,parent,axis,seg)
def E(n,p=(0,0,0),parent=root):
 o=bpy.data.objects.new('ENTROPIC | '+n,None);col.objects.link(o);o.parent=parent;o.location=p;return o
def bolt(n,p,axis='Z',r=.035,parent=root):return C(n,p,r,.035,bronze,axis,parent,6)
def beam(n,a,b,w=.08,d=.08,m=steel,parent=root):
 a,b=Vector(a),Vector(b);o=B(n,(a+b)/2,(w,d,(b-a).length),m,parent);o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o
def route(n,points,r,m=bronze,bore=0,parent=root,seg=24):
 pts=list(map(Vector,points));ts=[(pts[min(i+1,len(pts)-1)]-pts[max(i-1,0)]).normalized()for i in range(len(pts))]
 if bore:return tube('ENTROPIC | '+n,[(p,t,r,bore)for p,t in zip(pts,ts)],m,col,parent,seg)
 vv=[]
 for p,t in zip(pts,ts):
  trial=Vector((1,0,0))if abs(t.x)<.9 else Vector((0,1,0));a=(trial-t*trial.dot(t)).normalized();b=t.cross(a)
  vv.extend(tuple(p+r*(math.cos(j*math.tau/seg)*a+math.sin(j*math.tau/seg)*b))for j in range(seg))
 ff=[(i*seg+j,i*seg+(j+1)%seg,(i+1)*seg+(j+1)%seg,(i+1)*seg+j)for i in range(len(pts)-1)for j in range(seg)];ff.extend([tuple(reversed(range(seg))),tuple((len(pts)-1)*seg+j for j in range(seg))]);return mesh('ENTROPIC | '+n,vv,ff,m,col,parent)
# Thick founded masonry and fitted armored deck; the power core remains enclosed.
stone=mats['ferrocrete_dark'];ceramic=mats['insulator'];green=mats['indicator_green']
B('quarried founded slab',(0,0,.105),(2.86,2.86,.21),stone,bevel=.065)
for x in (-1.0,0,1.0):
 for y in (-1.,0,1.):B('dressed plinth block',(x*.94,y*.94,.27),(.927,.927,.12),stone,bevel=.017)
B('retained armored deck',(0,0,.365),(2.76,2.76,.07),iron,bevel=.025)
for x in (-1.28,1.28):
 for y in (-1.28,1.28):B('deck corner bracket',(x,y,.42),(.16,.16,.04),steel);bolt('deck foundation anchor',(x,y,.457),r=.039)
C('core founded shoe',(0,0,.455),.94,.11,steel,seg=64)
C('closed blackstone conversion mantle',(0,0,1.32),.765,1.72,iron,seg=96)
C('sealed roof casting',(0,0,2.22),.86,.12,steel,seg=96)
# Hollow bands and physically seated radial ribs.
def ring(n,z,outer,inner,depth,m=bronze,xy=(0,0),parent=root):
 return tube('ENTROPIC | '+n,[((xy[0],xy[1],z-depth/2),(0,0,1),outer,inner),((xy[0],xy[1],z+depth/2),(0,0,1),outer,inner)],m,col,parent,64)
def radial_box(n,a,r,z,d,m=iron,bevel=.008):
 o=B(n,(r*math.sin(a),-r*math.cos(a),z),d,m,bevel=bevel);o.rotation_euler.z=a;return o
def facebolt(n,a,r,z):
 o=C(n,(r*math.sin(a),-r*math.cos(a),z),.023,.026,bronze,'Y',seg=6);o.rotation_euler=(Vector((math.sin(a),-math.cos(a),0))).to_track_quat('Z','Y').to_euler();return o
for z in (.55,1.12,1.96,2.14):ring('mantle seated retaining band',z,.838,.757,.075)
for k in range(8):
 a=(k+.5)*math.tau/8;radial_box('founded structural rib',a,.796,1.34,(.065,.105,1.67),steel)
 for z in (.58,1.12,1.96,2.11):facebolt('rib retained band stud',a,.86,z)
for k in range(8):
 a=k*math.tau/8
 radial_box('sealed surface cassette',a,.768,1.55,(.405,.055,.66),steel)
 radial_box('opaque blind green core window',a,.801,1.55,(.337,.018,.53),glass)
 for dx in (-.182,.182):
  o=radial_box('seated window jamb',a,.817,1.55,(.032,.036,.60),bronze);o.location+=Vector((math.cos(a),math.sin(a),0))*dx
 for z in (1.27,1.83):radial_box('sealed window sill',a,.817,z,(.39,.036,.042),bronze)
 for dx in (-.085,0,.085):
  o=radial_box('green pane retained tracery',a,.817,1.55,(.018,.028,.51),iron);o.location+=Vector((math.cos(a),math.sin(a),0))*dx
 for z in (1.41,1.68):radial_box('seated blind glazing crossbar',a,.817,z,(.34,.029,.018),bronze)
 # Recessed access tablets below each window; no open interior.
 radial_box('closed lower service tablet',a,.793,.845,(.37,.05,.32),red)
 for z in (.73,.96):radial_box('tablet raised retaining edge',a,.825,z,(.37,.022,.025),bronze)
 for j in range(5):radial_box('tablet embossed runic rib',a,.825,.765+j*.04,(.17+(j%2)*.06,.024,.012),steel)
# Four founded ceramic/copper coil pylons echo the original reliquary silhouette.
for x in (-1.04,1.04):
 for y in (-.91,.91):
  tag=f'pylon {x} {y} '
  B(tag+'founded foot',(x,y,.45),(.40,.40,.10),steel)
  C(tag+'ceramic core',(x,y,1.09),.14,1.18,ceramic,seg=32)
  for z in (.54,1.64):C(tag+'forged end retainer',(x,y,z),.203,.10,bronze,seg=32)
  for k in range(4):
   a=k*math.tau/4;B(tag+'coil support stave',(x+.152*math.cos(a),y+.152*math.sin(a),1.09),(.036,.036,1.04),ceramic,bevel=.006)
  pts=[(x+.185*math.cos(t),y+.185*math.sin(t),.61+1.0*i/320)for i in range(321)for t in [i/320*math.tau*8]]
  route(tag+'continuous supported copper winding',pts,.018,bronze,seg=8)
  C(tag+'sealed terminal crown',(x,y,1.74),.153,.10,steel,seg=32)
  C(tag+'green crown indicator',(x,y,1.805),.105,.03,green,seg=32)
  for dx in (-.15,.15):
   for dy in (-.15,.15):bolt(tag+'foot anchor',(x+dx,y+dy,.5175),r=.025)
# Enclosed side heat-exchanger covers. Fin toes are embedded into their casting.
for sign in (-1,1):
 x=sign*1.13;B('closed thermal side casting',(x,0,.96),(.42,.69,.83),iron,bevel=.05)
 B('thermal casting founded shoe',(x,0,.51),(.48,.75,.12),steel)
 for j in range(9):B('seated external thermal fin',(sign*1.335,0,.63+j*.08),(.11,.63,.032),steel,bevel=.007)
 for y in (-.27,.27):
  B('thermal retaining rail',(sign*1.40,y,.97),(.035,.05,.77),bronze)
 for z in (.65,1.29):
  for y in (-.27,.27):bolt('thermal rail fastener',(sign*1.427,y,z),'X',.026)
# Low closed fuel insertion hatch, guarded retaining hinges and captive latch.
B('fuel vestibule founded casing',(0,-1.025,.69),(.71,.56,.57),steel,bevel=.05)
B('closed fragment fuel hatch',(0,-1.322,.73),(.60,.055,.43),iron,bevel=.025)
for x in (-.27,.27):
 for z in (.58,.88):bolt('fuel door seat fastener',(x*.814814815,-1.367,z),'Y',.025)
for z in (.61,.84):C('fuel hatch captured hinge',(-.30,-1.369,z),.036,.14,bronze,'Z',seg=16)
B('fuel hatch latch seat',(.20,-1.375,.73),(.08,.045,.17),bronze)
B('closed captive latch',(.12,-1.412,.73),(.24,.04,.04),steel)
# Back-mounted closed control panel; no native wire/pipe attachment implied.
B('closed rear regulating casket',(0,1.13,.90),(.63,.34,.72),iron,bevel=.04)
for x in (-.25,.25):
 for z in (.62,1.18):bolt('rear casket retaining screw',(x,1.317,z),'Y',.022)
for x in (-.15,0,.15):
 C('rear blind indicator seat',(x,1.315,.98),.047,.025,bronze,'Y',seg=24)
 C('rear green sealed indicator',(x,1.332,.98),.031,.018,green,'Y',seg=24)
for x in (-.23,.23):
 B('rear casket founded support foot',(x,1.13,.435),(.18,.45,.07),steel)
 B('rear casket load leg',(x,1.13,.51),(.10,.25,.15),steel)
 for y in (.98,1.28):bolt('rear casket foot anchor',(x,y,.488),r=.021)
# Crown relief plates seat on the lid; no plain unsupported block shell.
for k in range(16):
 a=k*math.tau/16;radial_box('radial roof casting relief',a,.65,2.292,(.036,.33,.026),bronze)
 facebolt('upper shell retained stud',a,.853,2.22)
# Mechanically honest roof cooling fan: shaft, bored hub, end stops, housing and grille.
C('fan opaque backplate',(0,0,2.315),.37,.07,iron,seg=64)
ring('stationary fan annular housing',2.45,.405,.35,.20,steel)
C('fixed fan shaft',(0,0,2.435),.025,.22,steel,seg=24)
for z in (2.424,2.466):ring('shaft retained axial washer',z,.053,.025,.008,bronze)
rotor=E('WORKING cooling rotor',(0,0,2.445));ring('bored rotor hub',0,.091,.035,.024,bronze,parent=rotor)
for k in range(6):
 a=k*math.tau/6;o=B('fan rigid blade',(math.cos(a)*.201,math.sin(a)*.201,0),(.25,.061,.018),steel,rotor,.009);o.rotation_euler.z=a
C('shaft top seated retainer',(0,0,2.548),.05,.018,bronze,seg=24)
for i in range(-4,5):
 x=i*.066;length=2*math.sqrt(.35**2-x*x);B('fixed fan guard grille',(x,0,2.568),(.014,length,.016),bronze,bevel=.003)
ring('fan guard grille retained rim',2.568,.405,.344,.025,bronze)
for k in range(8):
 a=k*math.tau/8;bolt('fan housing axial stud',(.378*math.cos(a),.378*math.sin(a),2.599),r=.019)
for f,a in ((1,0),(193,math.tau)):
 rotor.rotation_euler.z=a;rotor.keyframe_insert(data_path='rotation_euler',frame=f,group='working cooling rotor')
for act in bpy.data.actions:
 for layer in act.layers:
  for strip in layer.strips:
   for bag in strip.channelbags:
    for fc in bag.fcurves:
     for key in fc.keyframe_points:key.interpolation='LINEAR'
# UVs, original indexed images, editable save/reopen and runtime export.
uvs=[];dg=bpy.context.evaluated_depsgraph_get();baked={o:bpy.data.meshes.new_from_object(o.evaluated_get(dg))for o in tuple(col.objects)if o.type=='MESH'and o.modifiers}
for o,data in baked.items():o.data=data;o.modifiers.clear()
for o in tuple(col.objects):
 if o.type!='MESH':continue
 # Assign cylinder/sweep UVs BEFORE triangulation preserves ring identification.
 mode='cylinder'if cylinder_uv(o)else'sweep'if sweep_uv(o)else'panel'
 if mode=='panel':panel_uv(o)
 o['fmpl_uv_method']=mode;uvs.append({'object':o.name,'method':mode,'material':o.data.materials[0].name})
 bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
for _ in range(3):bpy.data.orphans_purge(do_local_ids=True,do_linked_ids=False,do_recursive=True)
profile={'camera_policy':'fmpl.factorio45.v1','capture_kind':'entity','orientation_policy':'rotatable','directions':[0,90,180,270],'native_directions':[0,4,8,12],'states':{'idle':[0],'working':list(range(1,193,6))},'source_size':512,'fps':8,'camera_override':{'type':'ORTHO','elevation_deg':45,'azimuth_deg':0,'distance':8.48528137423857,'ortho_scale':6.,'target':[0,0,1.]}}
install_canonical_camera(s,profile,bpy);s.render.engine='CYCLES';s.cycles.samples=24;s.render.film_transparent=True;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.render.fps=48;s.frame_start=1;s.frame_end=193
s.world=bpy.data.worlds.new('Entropic neutral studio');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.25,.25,.25,1)
for loc,power,size in [((4,-7,9),1600,7),((-6,3,6),1200,6)]:
 l=bpy.data.lights.new('Entropic authored studio','AREA');l.energy=power;l.size=size;o=bpy.data.objects.new(l.name,l);s.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,1.))-o.location).to_track_quat('-Z','Y').to_euler()
s.frame_set(1);assert_clean(s,profile,bpy);bpy.ops.file.pack_all();source=O/'entropic-v02.blend';bpy.ops.wm.save_as_mainfile(filepath=str(source),compress=True);bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene;root=bpy.data.objects['EXPORT | Entropic Extractor'];bpy.ops.object.select_all(action='DESELECT')
for o in [root,*root.children_recursive]:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(O/'entropic-v02.glb'),export_format='GLB',use_selection=True,export_cameras=False,export_lights=False,export_animations=True,export_animation_mode='SCENE',export_anim_scene_split_object=False,export_force_sampling=True,export_frame_range=True,export_anim_slide_to_zero=True,export_apply=True)
(O/'capture-profile.json').write_text(json.dumps(profile,indent=2))
(O/'fmpl-surface-manifest.json').write_text(json.dumps({'status':'candidate-not-native-integrated','source_sha256':sha(source),'runtime_sha256':sha(O/'entropic-v02.glb'),'native_footprint':[3,3],'native_directions':[0,4,8,12],'purpose':'2MW closed fragment-burning electrical generator','role_instances':roles,'uv_assignments':uvs,'all_original_source_maps_git_blob_verified':True,'packed_images':len([im for im in bpy.data.images if im.users and im.packed_file]),'animation':'exterior roof cooling rotor; closed energy conversion interior','owner_visual_approved':False},indent=2))
projection=bpy.data.objects.new('UNSAVED sprite ground projection',None);s.collection.objects.link(projection);projection.scale.y=math.sqrt(2);root.parent=projection;s.frame_set(25);s.render.resolution_x=s.render.resolution_y=768;s.render.filepath=str(O/'front-review.png');bpy.ops.render.render(write_still=True);projection.scale.y=1
with temporary_inspection_camera(s,bpy,'Entropic true proportions')as camera:
 target=Vector((0,0,1.15));camera.data.type='ORTHO';camera.data.ortho_scale=4.8;camera.location=(5,-7,5);camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();s.camera=camera;s.render.filepath=str(O/'detail-review.png');bpy.ops.render.render(write_still=True)
print('ENTROPIC_SOURCE_EXPORTED',sha(source),flush=True)



