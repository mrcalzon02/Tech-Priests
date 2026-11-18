"""Capture actual GLB body/fan and 21 supported hatch poses as separate layers.
Existing Factorio cargo pods and processions remain native; no capsule is baked.
"""
import bpy,bmesh,json,math,hashlib,sys,struct
import numpy as np
from pathlib import Path
from mathutils import Vector
A=Path(__file__).resolve().parent;D=A/'sprites';D.mkdir(exist_ok=True)
def repo():
 for p in(A,*A.parents):
  for r in(p,p/'model-production'):
   if(r/'tools/fmpl/FMPL.json').exists():return r
 raise FileNotFoundError('FMPL checkout')
sys.path.insert(0,str(repo()/'tools/fmpl'));from blender_camera_guard import install_canonical_camera,assert_clean
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();runtime=A/'orbital-v07.glb';ins=json.loads((A/'runtime-inspection.json').read_text());assert ins['technical_checks_passed']and json.loads((A/'fmpl-channel-verification.json').read_text())['passed'];assert sha(runtime)==ins['runtime_sha256']
b=runtime.read_bytes();n=struct.unpack_from('<I',b,12)[0];g=json.loads(b[20:20+n]);first=min(g['accessors'][s['input']]['min'][0]for a in g['animations']for s in a['samplers'])
bpy.ops.wm.read_factory_settings(use_empty=True);s=bpy.context.scene;s.render.fps=48;bpy.ops.import_scene.gltf(filepath=str(runtime));profile=json.loads((A/'capture-profile.json').read_text());install_canonical_camera(s,profile,bpy);s.render.engine='CYCLES';s.cycles.samples=16;s.cycles.use_animated_seed=False;s.render.film_transparent=True;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA'
s.world=bpy.data.worlds.new('Actual GLB layer capture');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.28,.28,.28,1)
for loc,power,size in[((4,-7,9),1800,7),((-6,3,6),1400,6)]:
 l=bpy.data.lights.new('FMPL layer studio','AREA');l.energy=power;l.size=size;o=bpy.data.objects.new(l.name,l);s.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,1.4))-o.location).to_track_quat('-Z','Y').to_euler()
root=bpy.data.objects['EXPORT | Orbital Trader'];projection=bpy.data.objects.new('UNSAVED canonical ground projection',None);s.collection.objects.link(projection);projection.scale.y=math.sqrt(2);root.parent=projection;meshes=[o for o in root.children_recursive if o.type=='MESH'];leaves=[bpy.data.objects['ORBITAL | WORKING cargo wedge hinge '+str(k)]for k in range(4)];leafsets=[set(o.name for o in e.children_recursive if o.type=='MESH')for e in leaves];all_lids=set.union(*leafsets);records=[]
def pose(f):
 t=(first+(f-1)/48)*48;s.frame_set(math.floor(t),subframe=t%1);assert_clean(s,profile,bpy)
def pixels(p):
 im=bpy.data.images.load(str(p),check_existing=False);w,h=im.size;a=np.array(im.pixels[:],dtype=np.float32).reshape(h,w,4);bpy.data.images.remove(im);return a
def save(p,a):
 h,w=a.shape[:2];im=bpy.data.images.new(p.stem,width=w,height=h,alpha=True);im.pixels.foreach_set(a.ravel());im.file_format='PNG';im.filepath_raw=str(p);im.save();bpy.data.images.remove(im);r=pixels(p);assert np.abs(r-a).max()<1/255+.00001;return r
def render(name,f):
 pose(f);p=A/(name+'.png');s.render.filepath=str(p);bpy.ops.render.render(write_still=True);a=pixels(p);records.append({'file':p.name,'source_equivalent_frame':f,'runtime_time_seconds':first+(f-1)/48,'sha256':sha(p)});print('ORBITAL_LAYER_CAPTURE',name,flush=True);return a
# Static native body keeps its real open well; hatch overlays close it at idle.
for o in meshes:o.hide_render=o.name in all_lids
save(D/'body-idle.png',render('body-idle',1));body=np.zeros((2048,4096,4),dtype=np.float32)
for k in range(32):
 a=render(f'body-working-{k:02d}',1+5*k);x=k%8*512;y=k//8*512;body[2048-y-512:2048-y,x:x+512]=a
save(D/'body-working.png',body)
# Camera-ray holdout preserves actual fixed-part occlusion and original GI.
original={o.name:list(o.data.materials)for o in meshes};holdouts={}
for o in meshes:
 if o.name in all_lids:continue
 for i,m in enumerate(o.data.materials):
  if m.name not in holdouts:
   h=m.copy();h.name='UNSAVED camera holdout | '+m.name;nt=h.node_tree;out=next(n for n in nt.nodes if n.type=='OUTPUT_MATERIAL');old=out.inputs['Surface'].links[0].from_socket;mix=nt.nodes.new('ShaderNodeMixShader');lp=nt.nodes.new('ShaderNodeLightPath');ho=nt.nodes.new('ShaderNodeHoldout');nt.links.new(lp.outputs['Is Camera Ray'],mix.inputs[0]);nt.links.new(old,mix.inputs[1]);nt.links.new(ho.outputs[0],mix.inputs[2]);nt.links.new(mix.outputs[0],out.inputs['Surface']);holdouts[m.name]=h
  o.data.materials[i]=holdouts[m.name]
for layer,visible in[('hatch-back',leafsets[1]),('hatch-front',leafsets[0]|leafsets[2]|leafsets[3])]:
 sheet=np.zeros((1536,3584,4),dtype=np.float32)
 for o in meshes:o.hide_render=o.name in all_lids and o.name not in visible
 for k in range(21):
  a=render(f'{layer}-{k:02d}',25+48*k/20);x=k%7*512;y=k//7*512;sheet[1536-y-512:1536-y,x:x+512]=a
 save(D/(layer+'.png'),sheet)
for o in meshes:
 o.data.materials.clear()
 for m in original[o.name]:o.data.materials.append(m)
 o.hide_render=True
# Native pods use the existing air-object layer. The real front wall/rim mask
# sorts ahead of them; rear walls and the rear leaf stay behind the native pod.
root.parent=None;bpy.context.view_layer.update();mask=[]
keys=('cargo receiver continuous hollow wall','fixed annular cargo lid foundation','cargo lid retained annular frame','cargo chamber continuous load band','cargo chamber founded exterior rib','closed cargo chamber service tablet','cargo tablet seated retaining border','cargo tablet mounted embossed character','front cargo gate','front closed cargo gate','front opaque green sealed gate','gate founded bronze jamb','gate seated arch tie','gate retained vertical tracery','gate closed pane crossbar','front gate founded mounting surround')
for o in meshes:
 if not any(key in o.name for key in keys):continue
 m=o.data.copy();bm=bmesh.new();bm.from_mesh(m);bmesh.ops.transform(bm,matrix=o.matrix_world,verts=list(bm.verts));bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=1e-7,plane_co=(0,-1.,0),plane_no=(0,1,0),clear_outer=True,clear_inner=False);bm.to_mesh(m);bm.free()
 if not m.polygons:continue
 cp=bpy.data.objects.new('UNSAVED front-wall depth mask',m);s.collection.objects.link(cp);cp.parent=projection;mask.append(cp)
root.parent=projection;save(D/'front-wall-mask.png',render('front-wall-mask',1))
for o in mask:o.hide_render=True
for o in meshes:o.hide_render=False
full=render('closed-model-reference',1);save(D/'icon.png',full)
im=bpy.data.images.load(str(D/'icon.png'),check_existing=False);im.scale(128,128);im.filepath_raw=str(D/'icon.png');im.save();bpy.data.images.remove(im)
for name,f in[('hatch-half-open-reference',49),('hatch-open-reference',73)]:render(name,f)
files={p.name:{'sha256':sha(p),'dimensions':list(bpy.data.images.load(str(p),check_existing=False).size)}for p in D.glob('*.png')}
r={'source_sha256':ins['source_sha256'],'runtime_sha256':sha(runtime),'genuine_actual_glb_frames':len(records),'records':records,'files':files,'body_frames':32,'body_fps':9.6,'hatch_frames':21,'hatch_control':'Engine-event-driven existing native cargo pod arrival; open/close frames are used forward/backward.','authored_replacement_cargo_pod_meshes':0,'native_pod_reference':'cargo-pod graphics and native landing procession reused unchanged','sprite_scale':.75,'sprite_shift':[0,-1.15/math.sqrt(2)],'native_directions':[0],'all_atlas_pngs_read_back':True,'layer_isolation':'Actual fixed geometry camera-ray holdout preserves occlusion and original image-material GI.','owner_visual_approved':False};(A/'capture-manifest.json').write_text(json.dumps(r,indent=2));print('ORBITAL_ACTUAL_GLB_LAYER_CAPTURE_PASS',len(records),flush=True)
