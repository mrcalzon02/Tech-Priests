"""Sterling reference reconstruction: actual chemical boiler, no invented engine."""
import bpy,bmesh,json,math,sys,hashlib,tempfile
import numpy as np
from pathlib import Path
from mathutils import Vector
O=Path(__file__).resolve().parent;R=next((p for p in O.parents if (p/'tech-priests_src').is_dir()),O.parents[2]);TP=R if (R/'tech-priests_src').is_dir() else R.parent/'model-production'
(O/'export-temp').mkdir(exist_ok=True);tempfile.tempdir=str(O/'export-temp')
sys.path.insert(0,str(R/'models/island-survival/primitive-steam-powered-pump/v3'))
sys.path.insert(0,str(O/'helpers'))
from mesh_util import box,cylinder,tube,lathe
import surfaces
sys.path.insert(0,str(TP/'tools/fmpl'))
from blender_camera_guard import install_canonical_camera,assert_clean,temporary_inspection_camera
bpy.ops.wm.read_factory_settings(use_empty=True);s=bpy.context.scene
col=bpy.data.collections.new('STERLING | supported heated vessel');s.collection.children.link(col)
root=bpy.data.objects.new('EXPORT | Sterling actual boiler',None);col.objects.link(root)
tex=O/'textures';tex.mkdir(exist_ok=True);rng=np.random.default_rng(171126);shape=(256,256)
broad=surfaces.field(rng,shape,.018);fine=surfaces.field(rng,shape,.16);u,v=np.meshgrid(np.linspace(0,1,256),np.linspace(0,1,256))
mats={}
for role,color,metal,rough in [('pressure-shell',(.14,.125,.095),.78,.62),('bronze-flanges',(.34,.24,.11),.82,.40),('cast-chassis',(.065,.072,.07),.73,.66),('martian-service-enamel',(.26,.035,.022),.55,.48),('gauge-ceramic',(.63,.57,.40),0,.70),('control-phosphor',(.018,.24,.035),.05,.34),('water-inlet-steel',(.11,.15,.17),.78,.49),('refractory-liner',(.21,.12,.075),0,.86),('burner-fire',(.8,.22,.015),0,.5)]:
 noise=.012*broad+.006*fine
 # Enamel chips expose metal; vessel oxidation is sparse, not striping.
 rgb=np.stack([np.full(shape,c)+noise for c in color],axis=-1)
 if role=='martian-service-enamel':
  chip=np.clip((fine-1.5)*.45,0,.6);rgb=rgb*(1-chip[:,:,None])+np.array([.16,.14,.10])*chip[:,:,None]
 if role=='control-phosphor':rgb*= (.65+.35*(np.sin(v*360)>0))[:,:,None]
 mat=surfaces.material('sterling-'+role,rgb,np.full(shape,rough)+.025*fine,.5+.018*broad+.007*fine,metal,tex)
 mat.name='STERLING | '+role;mat['surface_authorship']='Sterling role-specific image PBR; pressure casting, machined bronze, serviced Martian enamel, instrument ceramic and phosphor receive distinct maps and physical UV placement.'
 if role in ('control-phosphor','burner-fire'):
  bs=mat.node_tree.nodes['Principled BSDF'];bs.inputs['Emission Color'].default_value=(*color,1);bs.inputs['Emission Strength'].default_value=1.8 if role=='control-phosphor' else 4
 mats[role]=mat
iron=mats['cast-chassis'];bronze=mats['bronze-flanges'];body=mats['pressure-shell'];red=mats['martian-service-enamel']
def B(n,p,d,m=iron,parent=root):return box('STERLING | '+n,p,d,m,col,parent,.015)
def C(n,p,r,d,m=bronze,axis='Z',parent=root,seg=48):return cylinder('STERLING | '+n,p,r,d,m,col,parent,axis,seg)
def route(n,points,r,m=bronze,bore=0):
 pts=[Vector(p) for p in points];o=tube('STERLING | '+n,[(p,(pts[min(i+1,len(pts)-1)]-pts[max(0,i-1)]).normalized(),r,bore) for i,p in enumerate(pts)],m,col,root,24);return o
def ringX(n,x,y,z,r,inner,depth,m=bronze):return route(n,[(x-depth/2,y,z),(x+depth/2,y,z)],r,m,inner)
def bolt(n,p,axis='Z',r=.027):return C(n,p,r,.035,bronze,axis,seg=6)
# Broad layered anchoring follows the original sprite; two saddles carry the shell.
B('continuous bolted deck base',(0,0,.085),(3.78,1.78,.17));B('layered armor deck',(0,0,.205),(3.60,1.62,.13),body)
for x in (-1.63,1.63):
 for y in (-.66,.66):
  B('anchor foot',(x,y,.29),(.36,.33,.12));bolt('foundation retained bolt',(x,y,.365),r=.065)
for x in (-.97,.97):
 B('vessel saddle foot',(x,.02,.41),(.24,1.12,.28));B('front saddle upright',(x,-.40,.64),(.20,.20,.46));B('rear saddle upright',(x,.44,.64),(.20,.20,.46))
# Main pressure shell and independent end covers, with seated bands and bolts.
C('horizontal pressure drum',(0,.02,.95),.49,2.64,body,'X',seg=96)
for x in (-1.35,1.35):
 C('dished vessel end cover',(x,.02,.95),.455,.11,body,'X',seg=64)
 ringX('end pressure flange',x,.02,.95,.535,.46,.10)
 for k in range(12):
  a=math.tau*k/12;bolt('end flange captured fastener',(x+math.copysign(.068,x),.02+.50*math.cos(a),.95+.50*math.sin(a)),'X')
for x in (-.91,0,.91):ringX('seated pressure band',x,.02,.95,.512,.49,.082)
# Rear header and front return form a continuous pressure-water circulation jacket.
for y,z in ((.54,1.47),(-.60,.53)):
 route('continuous circulation header',[(-1.60,y,z),(1.60,y,z)],.115)
 for x in (-.85,.85):ringX('header split coupling',x,y,z,.145,.116,.11)
for x in (-1.60,1.60):
 # Broad quarter-circle bends, not sharp elbows through the drum.
 pts=[(x,.54+.22*math.sin(t),1.25+.22*math.cos(t)) for t in np.linspace(0,math.pi/2,13)]+[(x,.76,.75)]+[(x,.54+.22*math.cos(t),.75-.22*math.sin(t)) for t in np.linspace(0,math.pi/2,13)[1:]]+[(x,-.60,.53)]
 route('end jacket return',pts,.115)
 for y,z in ((.54,1.47),(-.60,.53)):C('valve casting',(x,y,z+.11),.17,.20,body)
 C('bolted top access cap',(x,.54,1.73),.21,.07,bronze)
 for k in range(8):
  a=math.tau*k/8;bolt('cap retaining bolt',(x+.17*math.cos(a),.54+.17*math.sin(a),1.775),r=.020)
# Actual player-grid mouths: +/-2 X, -0.5 model Y, fixed Z=.36.
for sign,role,mat in [(-1,'WATER',mats['water-inlet-steel']),(1,'STEAM',bronze)]:
 x=sign*2
 route(role+' full bore outer socket',[(x,-.50,.36),(sign*1.68,-.50,.36)],.31,mat,.245)
 ringX(role+' seating collar',sign*1.90,-.50,.36,.355,.245,.13,mat)
 o=tube('STERLING | '+role+' full-size tapered reducer',[(Vector((sign*1.68,-.50,.36)),Vector((sign,0,0)),.31,.245),(Vector((sign*1.60,-.60,.53)),Vector((sign,0,0)),.115,.080)],mat,col,root,48)
 for k in range(8):
  a=math.tau*k/8;bolt(role+' socket bolt',(sign*1.98,-.50+.317*math.cos(a),.36+.317*math.sin(a)),'X',.022)
 B(role+' connection support',(sign*1.65,-.50,.24),(.24,.42,.18))
# Real coal fire beneath the drum. The front slots expose only the burner chamber.
B('firebox refractory bed',(0,-.24,.39),(1.52,1.25,.08),mats['refractory-liner'])
B('firebox back wall',(0,.38,.53),(1.52,.12,.31));B('firebox left wall',(-.71,-.24,.53),(.12,1.25,.31));B('firebox right wall',(.71,-.24,.53),(.12,1.25,.31))
B('ash drawer',(0,-.89,.32),(1.32,.11,.09));B('firebox front lintel',(0,-.89,.66),(1.40,.10,.06))
for x in np.linspace(-.62,.62,10):B('seated grate bar',(float(x),-.89,.52),(.035,.07,.23))
flame=bpy.data.objects.new('STERLING | actual burner flame rig',None);col.objects.link(flame);flame.parent=root;flame.location=(0,-.85,.46)
for i,x in enumerate(np.linspace(-.55,.55,7)):
 o=lathe('STERLING | coal fire tongue '+str(i),[(0,0),(.037,.015),(.043,.06),(.02,.13),(0,.19)],(float(x),0),mats['burner-fire'],col,flame,24)
# Offset console is mechanically mounted to the front saddle, not floating.
for x in (-.56,.56):B('console bolted pressure-shell support',(x,-.52,.89),(.075,.25,.10))
B('armored cogitator console',(0,-.70,.91),(1.45,.22,.49),body);B('recessed console face',(0,-.825,.91),(1.32,.035,.36),iron)
B('green status display',(-.24,-.85,.94),(.68,.018,.23),mats['control-phosphor'])
for x in (.29,.51):
 for z in (.82,1.02):C('recessed console control',(x,-.865,z),.057,.045,bronze,'Y')
for x in (-.66,.66):
 for z in (.73,1.09):bolt('console panel screw',(x,-.86,z),'Y',.022)
# A pressure dial takes a direct seated impulse line from the hot header.
route('pressure instrument impulse',[(-.67,.54,1.47),(-.67,.25,1.55),(-.67,-.25,1.55)],.026)
C('pressure instrument case',(-.67,-.28,1.55),.145,.09,bronze,'Y');C('pressure ceramic dial',(-.67,-.331,1.55),.123,.015,mats['gauge-ceramic'],'Y')
needle=bpy.data.objects.new('STERLING | seated pressure needle rig',None);col.objects.link(needle);needle.parent=root;needle.location=(-.67,-.344,1.55)
B('visible pressure needle',(0,0,.042),(.012,.010,.085),red,needle);C('needle retained pivot',(0,-.008,0),.019,.014,bronze,'Y',needle)
for k in range(9):
 a=math.radians(-110+k*27.5);o=B('dial calibration mark',(-.67+.099*math.sin(a),-.346,1.55+.099*math.cos(a)),(.009,.008,.018),iron);o.rotation_euler.y=a
# Visible servicing details are physically seated, restrained rather than random boxes.
B('removable Martian red inspection plate',(.58,-.35,1.29),(.45,.10,.24),red)
for x in (.40,.76):bolt('inspection plate bolt',(x,-.414,1.29),'Y',.023)
route('console protected sensor cable',[(.54,-.58,.72),(.74,-.52,.72),(.82,-.48,.80),(.82,-.44,1.10)],.027,iron)
route('rear combustion exhaust',[(.77,.40,.47),(.83,.69,.50),(.86,.70,1.05),(.86,.70,1.69)],.085,iron,.059)
C('stack founded support foot',(.86,.70,.35),.14,.18,iron)
for f in range(0,98):
 phase=math.tau*(f-1)/96
 flame.scale=(1,1,.001 if f==0 else .84+.18*math.sin(phase*5)+.08*math.sin(phase*11));flame.keyframe_insert(data_path='scale',frame=f)
 needle.rotation_euler.y=math.radians(-92 if f==0 else 21+5*math.sin(phase));needle.keyframe_insert(data_path='rotation_euler',frame=f)
# Bake edge treatment before physical UV placement and triangulation.
for o in tuple(col.objects):
 if o.type!='MESH':continue
 if o.modifiers:o.data=bpy.data.meshes.new_from_object(o.evaluated_get(bpy.context.evaluated_depsgraph_get()));o.modifiers.clear()
 surfaces.physical_box_uv(o)
 bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7);bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-7);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
profile={'camera_policy':'fmpl.factorio45.v1','capture_kind':'entity','orientation_policy':'rotatable','directions':[0,90,180,270],'states':{'idle':[0],'working':list(range(1,97,6))},'source_size':256,'fps':4,'camera_override':{'type':'ORTHO','elevation_deg':45,'azimuth_deg':0,'distance':8.48528137423857,'ortho_scale':5.4,'target':[0,0,.8]}}
install_canonical_camera(s,profile,bpy);s.render.engine='CYCLES';s.cycles.samples=32;s.render.film_transparent=True;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.render.fps=24;s.frame_start=0;s.frame_end=97
s.world=bpy.data.worlds.new('Sterling neutral studio');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.28,.28,.28,1)
for loc,power,size in [((2,-4,6),900,5),((-4,2,4),600,4)]:
 l=bpy.data.lights.new('Sterling authored area','AREA');l.energy=power;l.size=size;o=bpy.data.objects.new(l.name,l);s.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,.7))-o.location).to_track_quat('-Z','Y').to_euler()
s.frame_set(1);assert_clean(s,profile,bpy);bpy.ops.file.pack_all();source=O/'sterling-v03.blend';bpy.ops.wm.save_as_mainfile(filepath=str(source),compress=True)
bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene;root=bpy.data.objects['EXPORT | Sterling actual boiler'];bpy.ops.object.select_all(action='DESELECT')
for o in [root,*root.children_recursive]:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(O/'sterling-v03.glb'),export_format='GLB',use_selection=True,export_cameras=False,export_lights=False,export_animations=True,export_animation_mode='SCENE',export_anim_scene_split_object=False,export_force_sampling=True,export_frame_range=True,export_apply=True)
(O/'capture-profile.json').write_text(json.dumps(profile,indent=2)+'\n',encoding='utf-8')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
(O/'construction.json').write_text(json.dumps({'status':'candidate-not-integrated-not-approved','source_sha256':sha(source),'runtime_sha256':sha(O/'sterling-v03.glb'),'contract':'Actual platform-only 4x2 chemical600kW boiler; water2/s -> steam20/s165C; no assembler processing or invented power generation.','source_recovery':'Current committed art/tools named Sterling/Stirling paths contain sprite reference only; no original editable Sterling source located. Existing emergency boiler inspected as construction reference, not substituted.','source_reference':'tech-priests_src/graphics/entity/sterling-steam-catalyzer/sterling-steam-catalyzer.png','fixed_model_sockets':[[-2,-.5,.36],[2,-.5,.36]],'surface_images':27,'owner_visual_approved':False},indent=2)+'\n',encoding='utf-8')
# Genuine source review views, unsaved square-ground projection only.
projection=bpy.data.objects.new('SPRITE ONLY | square ground projection',None);s.collection.objects.link(projection);projection.scale.y=math.sqrt(2);root.parent=projection;s.render.resolution_x=s.render.resolution_y=512;s.render.filepath=str(O/'front-review.png');bpy.ops.render.render(write_still=True)
with temporary_inspection_camera(s,bpy,'Sterling supported shell and fixed sockets') as camera:
 target=Vector((0,0,.8));camera.data.type='ORTHO';camera.data.ortho_scale=5.1;camera.location=(4,-6,4);camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();s.camera=camera;s.render.filepath=str(O/'detail-review.png');bpy.ops.render.render(write_still=True)
print('STERLING_AUTHORED_CANDIDATE_PASS',sha(source),flush=True)
