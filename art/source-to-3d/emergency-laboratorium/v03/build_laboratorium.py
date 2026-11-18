"""Authored one-tile refractory Emergency Laboratorium; FMPL source-indexed images."""
import bpy,bmesh,math,json,hashlib,sys,tempfile
from pathlib import Path
from mathutils import Vector
O=Path(__file__).resolve().parent
REPO=next(p/'model-production'for p in O.parents if(p/'model-production/tools/fmpl/FMPL.json').is_file());sys.path[:0]=[str(O),str(REPO/'tools/fmpl'),str(REPO/'art/source-to-3d/shared-parts/industrial-asset-library')]
from mesh_util import box,cylinder,tube,mesh
from fmpl_uv import cylinder_uv,sweep_uv,panel_uv
from import_materials import import_materials
from blender_camera_guard import install_canonical_camera,assert_clean,temporary_inspection_camera
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();(O/'export-temp').mkdir(exist_ok=True);tempfile.tempdir=str(O/'export-temp')
bpy.ops.wm.read_factory_settings(use_empty=True);s=bpy.context.scene;col=bpy.data.collections.new('LABORATORIUM | one-tile closed research cabinet');s.collection.children.link(col);root=bpy.data.objects.new('EXPORT | Emergency Laboratorium',None);col.objects.link(root)
ids=['ferrocrete','ferrocrete_dark','iron','machine_steel','brass','oxide_red','dark_recess','indicator_green','alert','insulator','parchment'];base=import_materials(REPO,ids,pack=True);mats={};roles=[];catalog=json.loads((REPO/'art/source-to-3d/shared-parts/industrial-asset-library/catalog.json').read_text())
for mid in ids:
 m=base[mid].copy();m.name='LABORATORIUM FMPL | '+mid;mats[mid]=m;record=next(q for q in catalog['materials']if q['material_id']==mid);maps={}
 for kind,rec in record['maps'].items():
  p=REPO/rec['source_path'];data=p.read_bytes();assert hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()==rec['git_blob_sha'];maps[kind]={'source_path':rec['source_path'],'git_blob_sha':rec['git_blob_sha'],'sha256':sha(p),'color_space':'sRGB'if kind=='albedo'else'Non-Color'}
 roles.append({'role':mid,'fmpl_material_id':mid,'model_specific_instance':m.name,'original_maps':maps,'texture_repeat_per_tile':4.0})
stone=mats['ferrocrete'];soot=mats['ferrocrete_dark'];iron=mats['iron'];steel=mats['machine_steel'];brass=mats['brass'];red=mats['oxide_red'];dark=mats['dark_recess'];green=mats['indicator_green'];hot=mats['alert'];ceramic=mats['insulator']
parchment=mats['parchment']
# Retain the original indexed pixels; only this model-specific hot material has emission.
bs=next(n for n in hot.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bs.inputs['Emission Color'].default_value=(1,.13,.006,1);bs.inputs['Emission Strength'].default_value=2.5

def B(n,p,d,m=iron,parent=root,bevel=.004):return box('LABORATORIUM | '+n,p,d,m,col,parent,bevel)
def C(n,p,r,d,m=steel,axis='Z',parent=root,seg=24):return cylinder('LABORATORIUM | '+n,p,r,d,m,col,parent,axis,seg)
def E(n,p):o=bpy.data.objects.new('LABORATORIUM | '+n,None);col.objects.link(o);o.parent=root;o.location=p;return o
def pipe(n,points,r,m=steel,parent=root,bore=0):
 points=[Vector(p)for p in points];samples=[(p,(points[min(i+1,len(points)-1)]-points[max(0,i-1)]).normalized(),r,bore)for i,p in enumerate(points)];return tube('LABORATORIUM | '+n,samples,m,col,parent,24)
def ring(n,p,outer,inner,depth,m=steel,axis='Z',parent=root):
 v=Vector((1,0,0)if axis=='X'else(0,1,0)if axis=='Y'else(0,0,1));q=Vector(p);return tube('LABORATORIUM | '+n,[(q-v*depth/2,v,outer,inner),(q+v*depth/2,v,outer,inner)],m,col,parent,32)
def stud(n,p,axis='Y',r=.009):return C(n,p,r,.012,brass,axis,seg=12)

# Continuous founded shell and separated fuel-heated service plinth.
B('dressed foundation',(0,0,.035),(.90,.86,.07),soot,bevel=.018)
B('founded cabinet sill',(.025,.04,.091),(.75,.72,.042),iron)
B('closed research chamber',(.025,.04,.37),(.64,.62,.52),iron,bevel=.018)
# Retained flat/sloped pressure covers keep the actual apparatus enclosed.
B('refractory roof liner',(.025,.04,.637),(.65,.63,.035),soot)
B('retained copper roof cover',(-.06,.04,.666),(.43,.57,.035),brass)
B('roof parchment calibration tablet',(-.075,.03,.688),(.33,.42,.016),parchment)
for y in(-.12,-.04,.04,.12,.20):B('roof tablet seated scale',(-.075,y,.700),(.255,.008,.012),iron,bevel=.001)
for x in(-.214,.064):
 for y in(-.152,.212):C('calibration tablet retained head',(x,y,.700),.012,.016,steel,seg=12)
for x in(-.306,.356):
 for y in(-.25,.33):
  B('cabinet corner band',(x,y,.37),(.028,.036,.54),brass)
  for z in(.14,.32,.50,.62):C('corner seated rivet',(x,y-.024,z),.008,.016,steel,'Y',seg=12)
# Screen is an opaque analysis plate, not a view into factory machinery.
B('analysis plate seated backing',(.025,-.283,.455),(.47,.050,.25),dark)
for x in(-.224,.274):B('analysis plate founded jamb',(x,-.312,.455),(.028,.036,.278),brass)
for z in(.316,.594):B('analysis plate retained sill lintel',(.025,-.312,z),(.526,.036,.028),brass)
B('fixed opaque analysis substrate',(.025,-.313,.455),(.417,.018,.207),dark)
B('working green analysis insert',(.025,-.3223,.455),(.417,.002,.207),green)
for z in(.393,.428,.463,.498,.533):B('analysis plate seated trace',(-.015,-.327,z),(.30,.010,.006),brass,bevel=.001)
# Mechanical key tablets and an attached calibration handwheel.
B('founded control console',(.025,-.335,.235),(.55,.13,.11),iron)
for x in[-.155+i*.055 for i in range(7)]:
 for z in(.215,.252):B('console seated key',(x,-.407,z),(.033,.018,.022),parchment,bevel=.002)
C('control wheel seated shaft',(.234,-.415,.228),.016,.050,steel,'Y')
# Wheel is intentionally fixed manual setting hardware, with a solid retained hub.
C('fixed control wheel',(.234,-.443,.228),.045,.018,brass,'Y',seg=32)
C('fixed wheel retained head',(.234,-.456,.228),.019,.018,steel,'Y')
# Grounded coal/combustion module. All inserts are fixed to an opaque backing.
B('founded burner firebox',(-.31,-.17,.175),(.19,.24,.21),soot)
B('burner retained iron front',(-.31,-.301,.175),(.205,.036,.224),iron)
for z in(.138,.169,.200):B('burner sight slit',(-.31,-.324,z),(.14,.016,.014),hot,bevel=.001)
for x in(-.38,-.345,-.310,-.275,-.240):B('burner fixed grille',(x,-.339,.169),(.008,.020,.108),steel,bevel=.001)
for z in(.109,.229):B('burner grille grounded rail',(-.31,-.329,z),(.205,.050,.020),brass)
B('coal charge tray',(-.31,-.329,.089),(.23,.16,.035),iron)
for x in(-.418,-.202):B('coal tray retained upstand',(x,-.330,.109),(.018,.16,.032),steel)
# Closed side cooling/service covers, supported seams and fitted rivets.
for side in(-1,1):
 x=-.301 if side<0 else .351
 B('side seated blind service cover',(x,.07,.38),(.027,.39,.30),steel)
 for y in(-.13,.27):B('side cover retained border',(x+side*.019,y,.38),(.022,.028,.33),brass)
 for z in(.22,.54):B('side cover retained crosspiece',(x+side*.019,.07,z),(.022,.42,.026),brass)
 for y in(-.07,.0,.07,.14,.21):
  B('service cover seated tablet',(x+side*.022,y,.38),(.018,.046,.18),iron)
  for z in(.33,.37,.41,.45):B('service tablet relief',(x+side*.034,y,z),(.012,.027,.007),brass,bevel=.001)
# Source-reference conduit loop: actual internal glands at BOTH ends; no external fluid mouths.
for z,m in[(.31,brass),(.40,red),(.49,green)]:
 pipe('attached closed service conduit',[(.36,-.12,z),(.405,-.12,z),(.405,.23,z),(.36,.23,z)],.012,m)
 for y in(-.12,.23):
  C('conduit founded closed gland',(.365,y,z),.023,.042,steel,'X')
 for y in(-.05,.04,.13):
  # Each collar is an actual bored sleeve in contact with its line, on a founded saddle.
  # Geometry is vertical Y here; rotate the helper's Z ring to match the line.
  ring('conduit retained collar',(.405,y,z),.020,.012,.020,brass,'Y')
  B('conduit saddle seat',(.376,y,z),(.055,.026,.038),iron)
# Founded closed thermal regulator underneath a captured mechanical calibration rotor.
center=(.115,.09,.785)
C('rotor founded thermal governor',(.115,.09,.704),.060,.12,iron)
C('rotor fixed journal shaft',center,.012,.22,steel)
for z in(.752,.818):ring('rotor fixed axial keeper',(.115,.09,z),.039,.012,.016,brass)
C('fixed shaft retained head',(.115,.09,.902),.025,.025,steel)
rotor=E('WORKING captive calibration rotor',center)
ring('moving calibration bored hub',(0,0,0),.038,.0125,.040,brass,parent=rotor)
ring('moving calibration scale',(0,0,0),.135,.119,.014,brass,parent=rotor)
for j in range(6):
 a=j*math.tau/6;o=B('moving calibration rigid spoke',(.078*math.cos(a),.078*math.sin(a),0),(.10,.012,.012),steel,rotor,.001);o.rotation_euler.z=a
for j in range(18):
 a=j*math.tau/18;o=B('moving calibration retained index',(.128*math.cos(a),.128*math.sin(a),.011),(.015,.008,.010),parchment,rotor,.001);o.rotation_euler.z=a
# Open protective cage is founded through the cabinet roof, outside the complete swept disk.
for x,y in[(.115-.166,.09),(.115+.166,.09),(.115,.09-.166),(.115,.09+.166)]:C('rotor founded cage upright',(x,y,.799),.012,.267,steel)
ring('rotor fixed cage guard',(.115,.09,.937),.180,.160,.022,iron)
for x in(.115-.09,.115,.115+.09):B('cage supported top guard',(x,.09,.949),(.012,.34,.018),brass)
# Native red/green wires terminate on real insulated posts, supported by the rear cabinet.
B('founded circuit terminal block',(-.225,.260,.62),(.18,.15,.14),iron)
for x,m in[(-.27,red),(-.18,green)]:
 C('circuit ceramic seat',(x,.260,.710),.025,.040,ceramic);C('circuit terminal head',(x,.260,.736),.018,.018,m)
# Small grounded reliefs and fasteners break broad plain surfaces without floating ornaments.
for y in(-.355,.355):
 for x in(-.4,.4):B('foundation keeper',(x,y,.080),(.045,.055,.028),iron);C('keeper seated head',(x,y,.100),.014,.015,brass,seg=12)
B('rear blind service hatch',(.025,.364,.39),(.43,.035,.32),steel)
for x in(-.17,.22):
 for z in(.25,.53):stud('rear hatch retained rivet',(x,.386,z))
for z in(.31,.35,.39,.43,.47):B('rear hatch retained relief',(.025,.386,z),(.30,.017,.012),brass)
# An arched retained refractory brow gives the sealed study chamber a small
# cathedral construction, rather than leaving a plain console box.
for j in range(11):
 a=j*math.pi/11;b=(j+1)*math.pi/11;vv=[(.025+r*math.cos(t),y,.455+r*math.sin(t))for y in(-.322,-.296)for r,t in[(.244,a),(.270,a),(.270,b),(.244,b)]]
 mesh('LABORATORIUM | retained arched study brow',vv,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],soot,col,root,.001)
 # Retained metal witness on the front of every fitted brow segment.
 t=(a+b)/2;C('study brow seated witness',(.025+.257*math.cos(t),-.330,.455+.257*math.sin(t)),.006,.018,brass,'Y',seg=12)
# Actual attached chapter seals and scale graduations on otherwise broad covers.
for y in(-.10,.02,.14):
 B('roof calibration chapter tab',(-.168,y,.704),(.040,.052,.016),red)
 for x in(-.173,-.163):B('chapter tab retained glyph',(x,y,.716),(.005,.031,.010),parchment,bevel=.001)
for x in(-.12,-.04,.04,.12):
 B('rear hatch seated index tablet',(x,.398,.390),(.046,.020,.118),dark)
 for z in(.36,.39,.42):B('rear index tablet raised mark',(x,.412,z),(.029,.012,.006),parchment,bevel=.001)

# The only articulated assembly is a rigid rotor on its fixed captured journal.
for f in(1,25,49,73,97):rotor.rotation_euler.z=(f-1)/96*math.tau;rotor.keyframe_insert(data_path='rotation_euler',frame=f)
for slot in rotor.animation_data.action.slots:
 for layer in rotor.animation_data.action.layers:
  for strip in layer.strips:
   for fc in strip.channelbag(slot).fcurves:
    for k in fc.keyframe_points:k.interpolation='LINEAR'

dg=bpy.context.evaluated_depsgraph_get();baked={o:bpy.data.meshes.new_from_object(o.evaluated_get(dg))for o in list(col.objects)if o.type=='MESH'and o.modifiers}
for o,m in baked.items():o.data=m;o.modifiers.clear()

uvs=[]
for o in col.objects:
 if o.type!='MESH':continue
 mode='cylinder'if cylinder_uv(o)else'sweep'if sweep_uv(o)else'panel'
 if mode=='panel':panel_uv(o)
 # Small1x1 furnace uses four repeats/tile versus Orbital1.25, preserving physical mappings.
 for uv in o.data.uv_layers.active.data:uv.uv*=4/1.25
 o['fmpl_uv_method']=mode;uvs.append({'object':o.name,'method':mode,'material':o.data.materials[0].name})
 bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7);bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-7);bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
for _ in range(3):bpy.data.orphans_purge(do_local_ids=True,do_linked_ids=False,do_recursive=True)
profile={'camera_policy':'fmpl.factorio45.v1','capture_kind':'entity','orientation_policy':'fixed','directions':[0],'native_directions':[0],'states':{'idle':[0],'working':list(range(1,97,4))},'source_size':512,'fps':12,'camera_override':{'type':'ORTHO','elevation_deg':45,'azimuth_deg':0,'distance':8.48528137423857,'ortho_scale':2.4,'target':[0,0,.5]}}
install_canonical_camera(s,profile,bpy);s.render.engine='CYCLES';s.cycles.samples=24;s.render.film_transparent=True;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.render.fps=48;s.frame_start=1;s.frame_end=97
s.world=bpy.data.worlds.new('Smelter neutral studio');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.25,.25,.25,1)
for loc,power,size in[((2,-3,4),240,3),((-3,2,4),180,3)]:
 l=bpy.data.lights.new('Smelter studio','AREA');l.energy=power;l.size=size;o=bpy.data.objects.new(l.name,l);s.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,.5))-o.location).to_track_quat('-Z','Y').to_euler()
s.frame_set(1);assert_clean(s,profile,bpy);bpy.ops.file.pack_all();source=O/'laboratorium-v03.blend';bpy.ops.wm.save_as_mainfile(filepath=str(source),compress=True);bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene;root=bpy.data.objects['EXPORT | Emergency Laboratorium'];bpy.ops.object.select_all(action='DESELECT')
for o in[root,*root.children_recursive]:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(O/'laboratorium-v03.glb'),export_format='GLB',use_selection=True,export_cameras=False,export_lights=False,export_animations=True,export_animation_mode='SCENE',export_anim_scene_split_object=False,export_force_sampling=True,export_frame_range=True,export_anim_slide_to_zero=True,export_apply=True)
(O/'capture-profile.json').write_text(json.dumps(profile,indent=2));(O/'fmpl-surface-manifest.json').write_text(json.dumps({'status':'candidate-not-native-integrated','source_sha256':sha(source),'runtime_sha256':sha(O/'laboratorium-v03.glb'),'role_instances':roles,'uv_assignments':uvs,'native_footprint':[1,1],'native_directions':[0],'all_original_source_maps_git_blob_verified':True,'owner_visual_approved':False},indent=2))
projection=bpy.data.objects.new('UNSAVED square ground',None);s.collection.objects.link(projection);projection.scale.y=math.sqrt(2);root.parent=projection;s.render.resolution_x=s.render.resolution_y=768;s.render.filepath=str(O/'front-review.png');bpy.ops.render.render(write_still=True);projection.scale.y=1
with temporary_inspection_camera(s,bpy,'true proportions')as c:
 c.data.type='ORTHO';c.data.ortho_scale=1.9;c.location=(2,-3,2);c.rotation_euler=(Vector((0,0,.6))-c.location).to_track_quat('-Z','Y').to_euler();s.camera=c;s.render.filepath=str(O/'detail-review.png');bpy.ops.render.render(write_still=True)
print('LABORATORIUM_SOURCE_SAVED',sha(source),flush=True)
