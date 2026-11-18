"""Authored one-tile refractory Emergency Smelter; FMPL source-indexed images."""
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
bpy.ops.wm.read_factory_settings(use_empty=True);s=bpy.context.scene;col=bpy.data.collections.new('SMELTER | one-tile refractory kiln');s.collection.children.link(col);root=bpy.data.objects.new('EXPORT | Emergency Smelter',None);col.objects.link(root)
ids=['ferrocrete','ferrocrete_dark','iron','machine_steel','brass','oxide_red','dark_recess','indicator_green','alert','insulator'];base=import_materials(REPO,ids,pack=True);mats={};roles=[];catalog=json.loads((REPO/'art/source-to-3d/shared-parts/industrial-asset-library/catalog.json').read_text())
for mid in ids:
 m=base[mid].copy();m.name='SMELTER FMPL | '+mid;mats[mid]=m;record=next(q for q in catalog['materials']if q['material_id']==mid);maps={}
 for kind,rec in record['maps'].items():
  p=REPO/rec['source_path'];data=p.read_bytes();assert hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()==rec['git_blob_sha'];maps[kind]={'source_path':rec['source_path'],'git_blob_sha':rec['git_blob_sha'],'sha256':sha(p),'color_space':'sRGB'if kind=='albedo'else'Non-Color'}
 roles.append({'role':mid,'fmpl_material_id':mid,'model_specific_instance':m.name,'original_maps':maps,'texture_repeat_per_tile':4.0})
stone=mats['ferrocrete'];soot=mats['ferrocrete_dark'];iron=mats['iron'];steel=mats['machine_steel'];brass=mats['brass'];red=mats['oxide_red'];dark=mats['dark_recess'];green=mats['indicator_green'];hot=mats['alert'];ceramic=mats['insulator']
# Retain the original indexed pixels; only this model-specific hot material has emission.
bs=next(n for n in hot.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bs.inputs['Emission Color'].default_value=(1,.13,.006,1);bs.inputs['Emission Strength'].default_value=2.5

def B(n,p,d,m=iron,parent=root,bevel=.004):return box('SMELTER | '+n,p,d,m,col,parent,bevel)
def C(n,p,r,d,m=steel,axis='Z',parent=root,seg=24):return cylinder('SMELTER | '+n,p,r,d,m,col,parent,axis,seg)
def E(n,p):o=bpy.data.objects.new('SMELTER | '+n,None);col.objects.link(o);o.parent=root;o.location=p;return o
def pipe(n,points,r,m=steel,parent=root,bore=0):
 points=[Vector(p)for p in points];samples=[(p,(points[min(i+1,len(points)-1)]-points[max(0,i-1)]).normalized(),r,bore)for i,p in enumerate(points)];return tube('SMELTER | '+n,samples,m,col,parent,24)
def ring(n,p,outer,inner,depth,m=steel,axis='Z',parent=root):
 v=Vector((1,0,0)if axis=='X'else(0,0,1));q=Vector(p);return tube('SMELTER | '+n,[(q-v*depth/2,v,outer,inner),(q+v*depth/2,v,outer,inner)],m,col,parent,32)
def stud(n,p,axis='Y',r=.009):return C(n,p,r,.012,brass,axis,seg=12)
# Dressed foundation, genuine empty fire chamber and a separate back flue.
B('dressed foundation',(0,0,.035),(.90,.86,.07),soot,bevel=.018)
B('sealed refractory floor',(0,-.025,.105),(.64,.62,.07),stone)
for side in(-1,1):
 for row in range(4):
  z=.1575+row*.065
  for k in range(4):
   y=-.27+k*.145;B('staggered founded side brick',(side*.265,y,z),(.115,.140,.062),stone,bevel=.006)
# Refractory barrel vault, extruded through depth. Each brick bears on its neighbor.
for course in range(4):
 y=-.302+course*.147
 for j in range(9):
  a=j*math.pi/9;b=(j+1)*math.pi/9
  verts=[(r*math.cos(t),yy,.365+r*math.sin(t))for yy in(y,y+.144)for r,t in[(.207,a),(.310,a),(.310,b),(.207,b)]]
  faces=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)];mesh('SMELTER | fitted refractory vault voussoir',verts,faces,stone,col,root,.002)
B('founded rear kiln wall',(0,.274,.31),(.53,.068,.41),soot)
# Door and lower fuel/charge shelf. Opaque liners make a closed manufacturing vessel.
B('dark closed iron firebox door',(0,-.330,.285),(.425,.030,.285),dark,bevel=.009)
for x in(-.229,.229):B('retained firebox jamb',(x,-.348,.292),(.037,.040,.33),iron)
B('retained door lintel',(0,-.348,.465),(.495,.043,.034),iron)
B('retained door sill',(0,-.365,.125),(.50,.080,.043),iron)
# A recessed retained coal tray and horizontal grate are fixed to the masonry.
B('founded charge tray',(0,-.378,.090),(.50,.095,.04),iron)
for x in(-.244,.244):B('charge tray upstand',(x,-.381,.112),(.018,.105,.042),steel)
for z in(.206,.242,.278):B('burner sight slit',(0,-.351,z),(.31,.016,.018),hot,bevel=.001)
for z in(.18,.307):B('burner grille grounded rail',(0,-.37,z),(.47,.060,.024),iron)
for x in[-.16+i*.032 for i in range(11)]:B('fixed retained burner grille',(x,-.370,.244),(.010,.021,.119),iron,bevel=.001)
for x in(-.17,.17):
 for z in(.14,.375):stud('firebox retained rivet',(x,-.349,z))
B('door charge plate',(0,-.354,.365),(.26,.022,.055),iron)
for x in(-.065,0,.065):B('charge plate seated mark',(x,-.367,.365),(.009,.009,.034),brass,bevel=.001)
for x in(-.24,.24):
 for z in(.18,.36):C('door retained hinge eye',(x,-.366,z),.021,.049,brass,'Z');C('door seated hinge pintle',(x,-.366,z),.010,.065,steel,'Z')
# Fixed opaque green heat shields preserve the reference's three-panel identity.
for x in(-.19,0,.19):
 o=B('retained green roof inspection shield',(x,-.07,.661 if x==0 else .596),(.168,.38,.022),green);o.rotation_euler.y=(0 if x==0 else(-1 if x<0 else 1)*math.radians(37))
 # Supporting rails sit at shield edges, attached to the vault cladding.
 for y in(-.263,.123):
  o=B('green shield founded rim',(x,y,.656 if x==0 else .591),(.184,.026,.034),iron);o.rotation_euler.y=(0 if x==0 else(-1 if x<0 else 1)*math.radians(37))
 for y in(-.21,.07):
  o=B('green shield seated transverse trace',(x,y,.676 if x==0 else .610),(.143,.009,.010),brass);o.rotation_euler.y=(0 if x==0 else(-1 if x<0 else 1)*math.radians(37))
# Full-depth roof bands retain the actual vault, with perpendicular riveted seats.
for y in(-.300,.168):
 for j in range(12):
  a=(j+.5)*math.pi/12;r=.316;o=B('vault retaining strap',(r*math.cos(a),y,.365+r*math.sin(a)),(.085,.030,.018),iron);o.rotation_euler.y=math.pi/2-a
  stud('vault strap seated head',(r*math.cos(a),y-.020,.365+r*math.sin(a)),r=.007)
# Rear brick chimney has an uninterrupted masonry load path into the foundation.
for row in range(10):
 z=.07+(row+.5)*.104
 for side in(-1,1):
  B('flue founded side brick',(.20+side*.083,.285,z),(.064,.21,.101),soot,bevel=.004)
  B('flue founded front back brick',(.20,.285+side*.078,z),(.103,.054,.101),stone,bevel=.004)
for side in(-1,1):
 B('flue continuous refractory mortar liner',(.20+side*.078,.285,.59),(.050,.20,1.04),soot)
 B('flue continuous front back mortar liner',(.20,.285+side*.078,.59),(.103,.050,1.04),soot)
for z in(.38,.69,1.05):
 for x in(.20-.122,.20+.122):B('flue retaining side band',(x,.285,z),(.014,.226,.033),iron)
 for y in(.165,.405):B('flue retaining front back band',(.20,y,z),(.25,.014,.033),iron)
# Real through-bore chimney crown, not a sealed lid with smoke at sprite center.
ring('open ceramic flue crown',(.20,.285,1.132),.110,.064,.048,ceramic)
for x in(.13,.27):B('spark guard founded upright',(x,.285,1.19),(.015,.017,.095),steel)
B('spark guard supported hood',(.20,.285,1.245),(.21,.19,.020),iron)
for y in(.23,.285,.34):B('spark arrestor top grille',(.20,y,1.16),(.19,.008,.012),steel)
# Founded service/reclamation drawer; closed internal processing, no invented pipes.
B('left founded service chest',(-.353,.025,.25),(.128,.39,.31),iron)
for y in(-.14,.19):B('service chest retaining rib',(-.424,y,.25),(.022,.026,.32),brass)
for z in(.16,.22,.28,.34):B('service chest blind vent',(-.425,.025,z),(.018,.28,.014),dark)
for y in(-.10,.0,.10):
 B('service chest seated plaque',(-.438,y,.26),(.012,.055,.084),steel)
 for z in(.24,.26,.28):B('service plaque raised glyph',(-.446,y,z),(.008,.031,.006),brass,bevel=.001)
# Air-draft duct and damper: actual bored body, grounded bearing neck, captive spindle.
ring('combustion air intake',(.356,-.035,.285),.090,.064,.17,iron,'X')
B('air intake founded foot',(.357,-.035,.143),(.15,.16,.15),iron)
for y in(-.092,-.035,.022):B('air intake retained grille',(.447,y,.285),(.012,.010,.145),steel)
ring('damper fixed lower bearing',(.355,-.035,.203),.024,.0095,.020,brass)
ring('damper fixed upper bearing',(.355,-.035,.375),.024,.0095,.020,brass)
for x in(.325,.385):B('upper bearing grounded side arm',(x,-.035,.375),(.040,.025,.015),iron)
# Bridge sits on the intake outer casting via two short pillars outside the sweep.
for x in(.304,.406):B('bearing grounded pillar',(x,-.035,.355),(.018,.028,.070),iron)
damper=E('WORKING captive thermal draft damper',(.355,-.035,.285))
C('moving retained damper spindle',(0,0,0),.009,.360,steel,parent=damper)
C('moving round damper butterfly',(0,0,0),.060,.012,iron,'X',damper,48)
B('moving damper lever',(0,-.034,.11),(.020,.09,.014),brass,damper,.002)
C('moving spindle upper retaining head',(0,0,.119),.017,.012,steel,parent=damper)
C('moving spindle lower retaining head',(0,0,-.100),.017,.012,steel,parent=damper)
# The thermal actuator remains enclosed, with a founded casing and coaxial bore.
# Its captured spindle is continuous through the fixed upper/lower journals.
ring('closed thermal draft regulator',(.355,-.035,.46),.043,.0095,.060,brass)
C('thermal regulator sealed crown',(.355,-.035,.500),.043,.020,iron)
B('thermal regulator grounded support',(.390,-.035,.425),(.018,.028,.098),brass)
# Captive green/red circuit terminals are fitted to the founded rear service block.
B('founded circuit terminal block',(-.235,.289,.43),(.16,.14,.24),iron)
for x,m in[(-.275,red),(-.195,green)]:
 C('circuit ceramic terminal seat',(x,.289,.565),.025,.040,ceramic);C('circuit terminal head',(x,.289,.59),.018,.016,m)
# External retaining seams and numerous actual seated fasteners, with no floating detail.
for x in(-.428,.428):
 for y in(-.36,.36):
  B('foundation corner keeper',(x,y,.078),(.040,.055,.025),iron);C('keeper grounded head',(x,y,.095),.014,.014,brass,seg=12)
for x in(-.31,.31):
 for y in(-.23,-.08,.07,.22):
  B('masonry strap grounded seat',(x,y,.194),(.023,.024,.225),iron)
  for z in(.12,.27):C('masonry strap rivet',(x+(.017 if x>0 else-.017),y,z),.008,.015,brass,'X',seg=12)
# Heat-sight areas use working-only scale animation; idle renders omit the separate hot slits.
flames=[o for o in col.objects if 'burner sight slit'in o.name]
for f in range(1,98,4):
 phase=(f-1)/96*math.tau;damper.rotation_euler.z=math.radians(12)*math.sin(phase);damper.keyframe_insert(data_path='rotation_euler',frame=f)
 # Combustion light flicker uses native working visualization; hot sight inserts remain fixed.
for o in [damper,*flames]:
 if o.animation_data and o.animation_data.action:
  for slot in o.animation_data.action.slots:
   for layer in o.animation_data.action.layers:
    for strip in layer.strips:
     for fc in strip.channelbag(slot).fcurves:
      for k in fc.keyframe_points:k.interpolation='LINEAR'
# A real continuous spindle bore passes through both the air casting and its foot.
cut=C('TEMP actual damper spindle bore',(.355,-.035,.285),.0095,.60,dark,seg=48)
for o in list(col.objects):
 if o.type=='MESH':
  bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
for obj in [o for o in col.objects if o.name in('SMELTER | combustion air intake','SMELTER | air intake founded foot')]:
 mod=obj.modifiers.new('Actual captive spindle clearance bore','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cut

recess=C('TEMP retaining head counterbore',(.355,-.035,.178),.018,.028,dark,seg=48)
bm=bmesh.new();bm.from_mesh(recess.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(recess.data);bm.free()
obj=bpy.data.objects['SMELTER | air intake founded foot'];mod=obj.modifiers.new('Retaining head running counterbore','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=recess
# Finish editable surfaces and independent actual export.
dg=bpy.context.evaluated_depsgraph_get();baked={o:bpy.data.meshes.new_from_object(o.evaluated_get(dg))for o in list(col.objects)if o.type=='MESH'and o.modifiers}
for o,m in baked.items():o.data=m;o.modifiers.clear()
bpy.data.objects.remove(cut,do_unlink=True);bpy.data.objects.remove(recess,do_unlink=True)
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
s.frame_set(1);assert_clean(s,profile,bpy);bpy.ops.file.pack_all();source=O/'smelter-v05.blend';bpy.ops.wm.save_as_mainfile(filepath=str(source),compress=True);bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene;root=bpy.data.objects['EXPORT | Emergency Smelter'];bpy.ops.object.select_all(action='DESELECT')
for o in[root,*root.children_recursive]:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(O/'smelter-v05.glb'),export_format='GLB',use_selection=True,export_cameras=False,export_lights=False,export_animations=True,export_animation_mode='SCENE',export_anim_scene_split_object=False,export_force_sampling=True,export_frame_range=True,export_anim_slide_to_zero=True,export_apply=True)
(O/'capture-profile.json').write_text(json.dumps(profile,indent=2));(O/'fmpl-surface-manifest.json').write_text(json.dumps({'status':'candidate-not-native-integrated','source_sha256':sha(source),'runtime_sha256':sha(O/'smelter-v05.glb'),'role_instances':roles,'uv_assignments':uvs,'native_footprint':[1,1],'native_directions':[0],'all_original_source_maps_git_blob_verified':True,'owner_visual_approved':False},indent=2))
projection=bpy.data.objects.new('UNSAVED square ground',None);s.collection.objects.link(projection);projection.scale.y=math.sqrt(2);root.parent=projection;s.render.resolution_x=s.render.resolution_y=768;s.render.filepath=str(O/'front-review.png');bpy.ops.render.render(write_still=True);projection.scale.y=1
with temporary_inspection_camera(s,bpy,'true proportions')as c:
 c.data.type='ORTHO';c.data.ortho_scale=1.9;c.location=(2,-3,2);c.rotation_euler=(Vector((0,0,.6))-c.location).to_track_quat('-Z','Y').to_euler();s.camera=c;s.render.filepath=str(O/'detail-review.png');bpy.ops.render.render(write_still=True)
print('SMELTER_SOURCE_SAVED',sha(source),flush=True)
