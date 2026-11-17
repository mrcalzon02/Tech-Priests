"""Owner-directed enclosed space manufacturing cathedral; no exposed interior."""
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
col=bpy.data.collections.new('CITADEL | enclosed manufacturing cathedral');s.collection.children.link(col);root=bpy.data.objects.new('EXPORT | Citadel Manufactureo',None);col.objects.link(root)
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
 m=base[mid].copy();m.name='CITADEL FMPL | '+mid;m['citadel_surface_role']=mid;m['fmpl_model_specific_placement']='Enclosed cathedral: cast footing, armored shell, structural ribs, sealed green panes, machined exterior services and recovered console; physicalUV1.25/tile.';mats[mid]=m
 roles.append({'role':mid,'fmpl_material_id':mid,'model_specific_instance':m.name,'original_maps':provenance[mid]['maps'],'texture_repeat_per_tile':1.25})
iron=mats['gunmetal_dark'];steel=mats['machine_steel'];bronze=mats['brass'];red=mats['martian_red'];glass=mats['glass'];dark=mats['dark_recess']
def B(n,p,d,m=iron,parent=root,bevel=.02):return box('CITADEL | '+n,p,d,m,col,parent,bevel)
def C(n,p,r,d,m=bronze,axis='Z',parent=root,seg=48):return cylinder('CITADEL | '+n,p,r,d,m,col,parent,axis,seg)
def E(n,p=(0,0,0),parent=root):
 o=bpy.data.objects.new('CITADEL | '+n,None);col.objects.link(o);o.parent=parent;o.location=p;return o
def bolt(n,p,axis='Z',r=.035,parent=root):return C(n,p,r,.035,bronze,axis,parent,6)
def beam(n,a,b,w=.08,d=.08,m=steel,parent=root):
 a,b=Vector(a),Vector(b);o=B(n,(a+b)/2,(w,d,(b-a).length),m,parent);o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o
def route(n,points,r,m=bronze,bore=0,parent=root,seg=24):
 pts=list(map(Vector,points));ts=[(pts[min(i+1,len(pts)-1)]-pts[max(i-1,0)]).normalized()for i in range(len(pts))]
 if bore:return tube('CITADEL | '+n,[(p,t,r,bore)for p,t in zip(pts,ts)],m,col,parent,seg)
 vv=[]
 for p,t in zip(pts,ts):
  trial=Vector((1,0,0))if abs(t.x)<.9 else Vector((0,1,0));a=(trial-t*trial.dot(t)).normalized();b=t.cross(a)
  vv.extend(tuple(p+r*(math.cos(j*math.tau/seg)*a+math.sin(j*math.tau/seg)*b))for j in range(seg))
 ff=[(i*seg+j,i*seg+(j+1)%seg,(i+1)*seg+(j+1)%seg,(i+1)*seg+j)for i in range(len(pts)-1)for j in range(seg)];ff.extend([tuple(reversed(range(seg))),tuple((len(pts)-1)*seg+j for j in range(seg))]);return mesh('CITADEL | '+n,vv,ff,m,col,parent)
def RY(n,x,y,z,r,bore,d,m=bronze,parent=root):return route(n,[(x,y-d/2,z),(x,y+d/2,z)],r,m,bore,parent,48)
def rounded(points,rr=.14):
 pts=list(map(Vector,points));out=[pts[0]]
 for a,b,c in zip(pts,pts[1:],pts[2:]):
  ab=(b-a).normalized();bc=(c-b).normalized();r=min(rr,(b-a).length*.49,(c-b).length*.49);p=b-ab*r;q=b+bc*r;out.append(p)
  for t in [k/8 for k in range(1,9)]:out.append((1-t)**2*p+2*t*(1-t)*b+t*t*q)
 out.append(pts[-1]);return out
def extrude(n,profile,front,depth,m=iron,bevel=.01):
 N=len(profile);vv=[(x,front+y,z)for y in (0,depth)for x,z in profile];ff=[tuple(reversed(range(N))),tuple(range(N,2*N))]+[(i,(i+1)%N,(i+1)%N+N,i+N)for i in range(N)];return mesh('CITADEL | '+n,vv,ff,m,col,root,bevel)
def pointed(w,bottom,spring,steps=18):
 left=[]
 for i in range(steps+1):
  x=-w+w*i/steps;left.append((x,spring+math.sqrt(max(0,(2*w)**2-(x-w)**2))))
 return [(-w,bottom)]+left+[(-x,z)for x,z in reversed(left[:-1])]+[(w,bottom)]
def arch(n,x,front,outer,inner,bottom,spring,depth,m=bronze):
 a=pointed(outer,bottom,spring);b=pointed(inner,bottom,spring);N=len(a);vv=[(x+xx,front+y,z)for y in (0,depth)for profile in (a,b)for xx,z in profile];ff=[]
 for i in range(N-1):
  j=i+1;ff.extend([(i,j,N+j,N+i),(2*N+i,3*N+i,3*N+j,2*N+j),(i,2*N+i,2*N+j,j),(N+i,N+j,3*N+j,3*N+i)])
 for i in (0,N-1):ff.append((i,N+i,3*N+i,2*N+i))
 return mesh('CITADEL | '+n,vv,ff,m,col,root,.008)
def window(n,x,front,w,bottom,spring):
 extrude(n+' sealed opaque green pane',[(x+xx,z)for xx,z in pointed(w,bottom,spring)],front,.035,glass)
 arch(n+' load-bearing pointed frame',x,front-.020,w+.075,w+.010,bottom-.025,spring,.080,bronze)
 for dx in (-w*.45,0,w*.45):
  top=spring+math.sqrt(max(0,(2*w)**2-(abs(dx)+w)**2));B(n+' seated vertical muntin',(x+dx,front-.024,(bottom+top)/2),(.023,.035,top-bottom),steel,bevel=.004)
 B(n+' sealed horizontal glazing bar',(x,front-.025,spring),((2*w),.035,.025),steel,bevel=.004)
# An installed footing carries the entire enclosed building, not visible machinery.
B('cast ferrocrete foundation',(0,0,.10),(4.85,4.85,.20),mats['ferrocrete_dark'],bevel=.07)
B('bolted iron perimeter deck',(0,0,.235),(4.70,4.70,.07),iron,bevel=.025)
for x in (-2.18,2.18):
 for y in (-2.12,2.12):
  B('founded corner shoe',(x,y,.32),(.40,.38,.14),steel);bolt('corner shoe anchor',(x,y,.415),r=.065)
# Solid closed nave. No modeled processing interior and no transparent cutaway.
extrude('opaque vaulted manufacturing nave',[(-1.35,.27),(-1.35,2.85),(0,4.10),(1.35,2.85),(1.35,.27)],-1.90,3.95,iron,.025)
for sign in (-1,1):
 x=sign*1.85
 B('closed front service tower',(x,-.80,1.75),(1.04,2.15,3.0),iron,bevel=.10)
 B('front tower founded cast boot',(x,-.80,.42),(1.13,2.24,.30),steel,bevel=.045)
 B('front tower upper load cornice',(x,-.80,3.23),(1.12,2.23,.12),bronze,bevel=.02)
 # Four sloping crown faces on a supported, sealed tower roof.
 vv=[(x-.56,-1.92,3.29),(x+.56,-1.92,3.29),(x+.56,.32,3.29),(x-.56,.32,3.29),(x,-1.40,3.85),(x,-.20,3.85)]
 mesh('CITADEL | supported tower crown',vv,[(0,1,4),(1,2,5,4),(2,3,5),(3,0,4,5),(3,2,1,0)],steel,col,root,.025)
 beam('tower crown seated ridge',(x,-1.43,3.87),(x,-.17,3.87),.10,.10,bronze)
 for yy in (-1.75,.15):
  for xx in (x-.44,x+.44):B('tower corner load rib',(xx,yy,1.77),(.105,.13,2.93),steel,bevel=.012)
 # Rear towers remain closed; their lower crowns carry roof/service loads.
 B('closed rear service tower',(x,1.35,1.45),(.99,1.35,2.36),iron,bevel=.08)
 B('rear tower cast boot',(x,1.35,.40),(1.10,1.46,.26),steel)
 B('rear tower supported head',(x,1.35,2.66),(1.08,1.44,.14),bronze)
 for yy in (.76,1.94):B('rear tower load rib',(x+sign*.45,yy,1.50),(.11,.12,2.25),steel)
 # The two wings are tied to the nave by genuine founded diagonal buttresses.
 B('buttress founded shoe',(sign*2.25,.38,.35),(.38,.38,.17),steel)
 beam('external flying load buttress',(sign*2.25,.38,.40),(sign*1.36,.38,2.63),.20,.22,steel)
 B('buttress seated nave plate',(sign*1.36,.38,2.60),(.15,.38,.35),bronze)
 bolt('buttress shoe retention',(sign*2.25,.38,.46),r=.046)
 window('front tower green clerestory',x,-1.965,.255,1.30,1.60)
 # Blind material-transfer hatches, not invented fluid sockets.
 B('sealed side cargo hatch',(sign*2.385,-.55,.82),(.055,.78,.70),red)
 for yy in (-.84,-.26):bolt('cargo hatch fastener',(sign*2.426,yy,.82),'X',.028)
 for z in (.65,.99):B('cargo hatch captured hinge',(sign*2.424,-.84,z),(.065,.08,.17),bronze)
# Coherent ribbed roof and closed structural facade; original cathedral identity.
for y in (-1.72,-.90,0,.90,1.80):
 beam('nave left roof load rib',(-1.39,y,2.87),(0,y,4.16),.075,.10,bronze)
 beam('nave right roof load rib',(0,y,4.16),(1.39,y,2.87),.075,.10,bronze)
 for x in (-1.38,1.38):bolt('roof rib seated eave bolt',(x,y,2.91),r=.028)
B('ridge seam bearing cap',(0,.075,4.15),(.16,4.12,.075),steel,bevel=.018)
arch('heavy main door pressure arch',0,-2.00,.95,.78,.29,1.10,.18,bronze)
for sign in (-1,1):
 w=.755;bottom=.31;spring=1.10
 half=[(-w,bottom)]+[(x,spring+math.sqrt(max(0,(2*w)**2-(x-w)**2)))for x in [-w+(w-.012)*i/20 for i in range(21)]]+[(-.012,bottom)]
 profile=half if sign<0 else[(-x,z)for x,z in reversed(half)]
 extrude('closed armored manufactureo door',profile,-2.13,.075,iron,.012)
 for x in [sign*.17,sign*.53]:B('door vertical load band',(x,-2.18,1.13),(.075,.065,1.52),steel)
 for z in (.66,1.25):
  C('door grounded hinge pin',(sign*.795,-2.18,z),.045,.25,bronze)
  B('door hinge wall leaf',(sign*.81,-2.13,z),(.15,.10,.18),steel)
  B('door hinge panel leaf',(sign*.70,-2.15,z),(.18,.08,.15),steel)
  for x in (sign*.70,sign*.84):bolt('door hinge leaf bolt',(x,-2.208,z),'Y',.024)
 for z in (.52,1.60):bolt('door strap retainer',(sign*.53,-2.222,z),'Y',.029)
window('main nave opaque green window',0,-1.965,.36,2.83,3.02)
C('main door lock shaft',(0,-2.19,1.24),.050,.22,steel,'Y')
RY('door lock mounted gland',0,-2.15,1.24,.10,.051,.09)
RY('door lock handwheel rim',0,-2.33,1.24,.235,.190,.050)
C('door lock retained hub',(0,-2.33,1.24),.065,.085,steel,'Y')
for k in range(6):
 a=math.tau*k/6;beam('door lock wheel spoke',(.055*math.cos(a),-2.33,1.24+.055*math.sin(a)),(.198*math.cos(a),-2.33,1.24+.198*math.sin(a)),.027,.027,bronze)
# Only external service mechanisms move. Opaque backed fan chambers hide the
# manufacturing interior, and rotors clear both their housings and front grilles.
fans=[]
for sign in (-1,1):
 x=sign*1.85;z=2.67
 C('sealed exterior fan mounting back',(x,-1.92,z),.355,.10,steel,'Y')
 C('opaque fan chamber backplate',(x,-1.98,z),.302,.025,dark,'Y')
 RY('fan protective annular housing',x,-2.045,z,.342,.300,.20,bronze)
 C('fixed exterior fan bearing shaft',(x,-2.025,z),.035,.155,steel,'Y')
 rig=E(('left'if sign<0 else'right')+' external cooling rotor',(x,-2.04,z));fans.append((sign,rig))
 RY('fan rotating bored hub',0,0,0,.076,.041,.040,steel,rig)
 for k in range(5):
  a=math.tau*k/5;beam('fan retained blade root',(.066*math.cos(a),0,.066*math.sin(a)),(.240*math.cos(a),0,.240*math.sin(a)),.045,.028,steel,rig)
  blade=B('fan outer vane',(.225*math.cos(a),0,.225*math.sin(a)),(.075,.026,.105),bronze,rig,bevel=.008);blade.rotation_euler.y=math.pi/2-a
 C('fan shaft front retainer',(x,-2.09,z),.045,.018,bronze,'Y')
 RY('fan front thrust washer',x,-2.0715,z,.062,.036,.015,steel)
 RY('fan rear thrust washer',x,-2.010,z,.062,.036,.015,steel)
 for dx in (-.18,-.06,.06,.18):
  length=2*math.sqrt(.330**2-dx**2);B('fan seated protective grille',(x+dx,-2.145,z),(.020,.025,length),iron,bevel=.004)
 for k in range(8):
  a=math.tau*k/8;bolt('fan housing captured bolt',(x+.323*math.cos(a),-2.161,z+.323*math.sin(a)),'Y',.020)
# Rear service doors/power housing are closed and grounded to the base.
B('rear sealed service hatch',(0,2.085,1.05),(1.25,.10,1.42),red)
for x in (-.50,.50):
 for z in (.48,1.62):bolt('rear service cover fastener',(x,2.16,z),'Y',.036)
B('rear grounded power cabinet',(0,2.17,.56),(1.05,.30,.57),iron)
for x in (-.35,.35):B('power cabinet founded foot',(x,2.15,.30),(.16,.25,.14),steel)
for sign in (-1,1):
 route('terminated armored roof service bus',rounded([(sign*1.40,1.75,2.65),(sign*1.48,1.75,2.55),(sign*1.48,.72,2.55),(sign*1.78,.72,2.55),(sign*1.78,.02,2.55),(sign*1.48,.02,2.55),(sign*1.48,-.50,2.55)],.12),.065,bronze)
 for y in(.55,1.3):
  xx=sign*(1.78 if y==.55 else 1.48)
  route('service bus closed clamp',[(xx,y-.035,2.55),(xx,y+.035,2.55)],.080,steel,.066)
  if y==.55:B('service bus founded bypass saddle',(xx,.414,2.55),(.10,.278,.07),steel)
  else:B('service bus wall standoff',(sign*1.405,y,2.55),(.060,.07,.06),steel)
 for y in(.275,.675):RY('closed bus tower entry collar',sign*1.78,y,2.55,.115,.066,.07,bronze)
 route('rear power cabinet founded conduit',rounded([(0,2.25,.48),(sign*.8,2.25,.48),(sign*.8,2.25,2.00),(sign*.80,1.99,2.00)],.13),.045,iron)
# Recover the actual indexed FMPL console, not the unrelated Manufactorum icon.
rec=json.loads((O/'recovered-console.json').read_text());scale=1.04/(rec['bounds']['max'][0]-rec['bounds']['min'][0]);target=Vector((-1.85,-2.01,.83))
for entry in rec['objects']:
 mid=entry['fmpl_material_id']
 if mid not in mats:mid='indicator_green'if'green'in entry['material_name'].lower()else'brass'
 points=[tuple(Vector(v)*scale+target)for v in entry['vertices']]
 mesh('CITADEL | FMPL recovered console '+entry['name'].split(' | ')[-1],points,entry['faces'],mats[mid],col,root)
for x in (-2.18,-1.52):B('console founded support',(x,-1.98,.40),(.10,.20,.26),steel)
route('console protected instrument lead',rounded([(-1.60,-1.89,.65),(-1.60,-1.89,1.12),(-1.60,-1.80,1.12)],.05),.022,iron)
# Externally readable, supported pressure dial. No gameplay fluid port is added.
C('right tower pressure instrument case',(1.85,-1.99,.84),.175,.10,bronze,'Y')
RY('pressure dial bored ceramic face',1.85,-2.051,.84,.148,.020,.016,mats['insulator'])
RY('pressure dial bored needle bearing',1.85,-2.058,.84,.034,.017,.012,steel)
C('pressure needle fixed shaft',(1.85,-2.065,.84),.015,.060,bronze,'Y')
C('pressure needle front retainer',(1.85,-2.094,.84),.024,.012,bronze,'Y')
needle=E('external seated pressure needle',(1.85,-2.080,.84));RY('pressure needle bored retained hub',0,0,0,.030,.017,.010,bronze,needle);B('pressure needle pointer',(0,-.006,.0795),(.012,.008,.103),red,needle,bevel=.002)
for k in range(9):
 a=math.radians(-110+k*27.5);o=B('pressure calibration tick',(1.85+.12*math.sin(a),-2.066,.84+.12*math.cos(a)),(.010,.006,.020),iron,bevel=.001);o.rotation_euler.y=a
route('pressure instrument closed impulse line',rounded([(1.85,-1.96,.98),(2.09,-1.96,.98),(2.09,-1.78,1.15)],.08),.020,bronze)
exec((O/'greeble_skin.py').read_text(),globals())
exec((O/'fit_overlapping_relief.py').read_text(),globals())
# Native working loop: restrained exterior cooling and pressure indication only.
for f in range(0,194):
 phase=math.tau*max(0,f-1)/192
 for sign,rig in fans:rig.rotation_euler.y=sign*phase;rig.keyframe_insert(data_path='rotation_euler',frame=f)
 needle.rotation_euler.y=.25+.12*math.sin(phase*2);needle.keyframe_insert(data_path='rotation_euler',frame=f)
for action in bpy.data.actions:
 for layer in action.layers:
  for strip in layer.strips:
   for bag in strip.channelbags:
    for fc in bag.fcurves:
     for k in fc.keyframe_points:k.interpolation='LINEAR'
uvs=[]
# Bake one stable evaluated snapshot, avoiding repeated global dependency updates.
dg=bpy.context.evaluated_depsgraph_get()
baked={o:bpy.data.meshes.new_from_object(o.evaluated_get(dg))for o in tuple(col.objects)if o.type=='MESH'and o.modifiers}
for o,data in baked.items():o.data=data;o.modifiers.clear()
for o in tuple(col.objects):
 if o.type!='MESH':continue
 bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7);bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-7);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
 if cylinder_uv(o):mode='continuous cylinder wall and planar end caps'
 elif sweep_uv(o):mode='continuous physical centreline/circumference with planar caps'
 else:panel_uv(o);mode='part-local physical panel placement'
 o.data.uv_layers.active.name='FMPL physical UV1.25 per tile';o['fmpl_uv_method']=mode;uvs.append({'object':o.name,'uv_method':mode,'material':o.data.materials[0].name})
for _ in range(3):bpy.data.orphans_purge(do_local_ids=True,do_linked_ids=False,do_recursive=True)
profile={'camera_policy':'fmpl.factorio45.v1','capture_kind':'entity','orientation_policy':'fixed','directions':[0],'native_directions':[0],'states':{'idle':[0],'working':list(range(1,193,6))},'source_size':512,'fps':8,'camera_override':{'type':'ORTHO','elevation_deg':45,'azimuth_deg':0,'distance':8.48528137423857,'ortho_scale':10.0,'target':[0,0,1.6]}}
install_canonical_camera(s,profile,bpy);s.render.engine='CYCLES';s.cycles.samples=32;s.render.film_transparent=True;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.render.fps=48;s.frame_start=1;s.frame_end=193
s.world=bpy.data.worlds.new('Citadel neutral studio');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.25,.25,.25,1)
for loc,power,size in [((4,-7,9),1800,7),((-6,3,6),1400,6)]:
 l=bpy.data.lights.new('Citadel authored studio','AREA');l.energy=power;l.size=size;o=bpy.data.objects.new(l.name,l);s.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,1.7))-o.location).to_track_quat('-Z','Y').to_euler()
s.frame_set(1);assert_clean(s,profile,bpy);bpy.ops.file.pack_all();source=O/'citadel-v11.blend';bpy.ops.wm.save_as_mainfile(filepath=str(source),compress=True);bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene;root=bpy.data.objects['EXPORT | Citadel Manufactureo'];bpy.ops.object.select_all(action='DESELECT')
for o in [root,*root.children_recursive]:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(O/'citadel-v11.glb'),export_format='GLB',use_selection=True,export_cameras=False,export_lights=False,export_animations=True,export_animation_mode='SCENE',export_anim_scene_split_object=False,export_force_sampling=True,export_frame_range=True,export_anim_slide_to_zero=True,export_apply=True)
(O/'capture-profile.json').write_text(json.dumps(profile,indent=2)+'\n')
manifest={'status':'candidate-not-native-integrated-not-owner-approved','owner_enclosed_cathedral_brief':True,'hidden_factory_interior_not_modeled':True,'native_footprint':[5,5],'native_directions':[0],'native_fluid_ports':0,'source_sha256':sha(source),'runtime_sha256':sha(O/'citadel-v11.glb'),'canonical_catalog_source_commit':catalog['source_commit'],'all_original_source_maps_git_blob_verified':True,'canonical_material_ids':ids,'role_instances':roles,'uv_assignments':uvs,'source_maps_not_duplicated_or_modified':True,'packed_images':len([im for im in bpy.data.images if im.users and im.packed_file]),'console_source':{'part_id':rec['part_id'],'source_sha256':rec['source_sha256'],'meshes':20,'uniform_scale':scale},'animation':'Two externally mounted cooling rotors and one pressure needle; closed opaque backed housings. No factory interior or extra native function.','owner_visual_approved':False}
(O/'fmpl-surface-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
# Canonical sprite projection is temporary; oblique inspection stays undistorted.
projection=bpy.data.objects.new('UNSAVED sprite square ground projection',None);s.collection.objects.link(projection);projection.scale.y=math.sqrt(2);root.parent=projection;s.frame_set(25);s.render.resolution_x=s.render.resolution_y=768;s.render.filepath=str(O/'front-review.png');bpy.ops.render.render(write_still=True);projection.scale.y=1
with temporary_inspection_camera(s,bpy,'Citadel true proportions')as camera:
 target=Vector((0,0,2));camera.data.type='ORTHO';camera.data.ortho_scale=8.6;camera.location=(6,-8,6);camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();s.camera=camera;s.render.filepath=str(O/'detail-review.png');bpy.ops.render.render(write_still=True)
print('CITADEL_ENCLOSED_FMPL_CANDIDATE_SAVED',sha(source),flush=True)
