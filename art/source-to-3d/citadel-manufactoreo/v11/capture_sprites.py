"""Capture actual inspected GLB: one native fixed-north idle and 32 working frames."""
import bpy,json,math,hashlib,sys,struct
import numpy as np
from pathlib import Path
from mathutils import Vector
O=Path(__file__).resolve().parent;D=O/'sprites';D.mkdir(exist_ok=True)
def locate_repo():
 for parent in(O,*O.parents):
  for candidate in(parent,parent/'model-production'):
   if(candidate/'tools/fmpl/FMPL.json').is_file():return candidate
 raise FileNotFoundError('Canonical FMPL checkout required')
sys.path.insert(0,str(locate_repo()/'tools/fmpl'))
from blender_camera_guard import install_canonical_camera,assert_clean
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
source=O/'citadel-v11.blend';runtime=O/'citadel-v11.glb';ins=json.loads((O/'runtime-inspection.json').read_text())
assert ins['technical_checks_passed']and sha(source)==ins['source_sha256']and sha(runtime)==ins['runtime_sha256']
assert json.loads((O/'fmpl-channel-verification.json').read_text())['passed']
blob=runtime.read_bytes();n=struct.unpack_from('<I',blob,12)[0];g=json.loads(blob[20:20+n]);first=min(g['accessors'][x['input']]['min'][0]for a in g['animations']for x in a['samplers'])
bpy.ops.wm.read_factory_settings(use_empty=True);s=bpy.context.scene;s.render.fps=48;bpy.ops.import_scene.gltf(filepath=str(runtime))
profile=json.loads((O/'capture-profile.json').read_text());install_canonical_camera(s,profile,bpy)
s.render.engine='CYCLES';s.cycles.samples=24;s.render.film_transparent=True;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA'
s.world=bpy.data.worlds.new('Citadel actual GLB sprite studio');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.28,.28,.28,1)
for loc,power,size in[((4,-7,9),1800,7),((-6,3,6),1400,6)]:
 l=bpy.data.lights.new('Actual GLB sprite area','AREA');l.energy=power;l.size=size;o=bpy.data.objects.new(l.name,l);s.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,1.7))-o.location).to_track_quat('-Z','Y').to_euler()
root=bpy.data.objects['EXPORT | Citadel Manufactureo'];projection=bpy.data.objects.new('UNSAVED sprite square ground projection',None);s.collection.objects.link(projection);projection.scale.y=math.sqrt(2);root.parent=projection
def pixels(p,size=512):
 im=bpy.data.images.load(str(p),check_existing=False);assert tuple(im.size)==(512,512)
 if size!=512:im.scale(size,size)
 data=np.array(im.pixels[:],dtype=np.float32).reshape(size,size,4);bpy.data.images.remove(im);return data
def save(p,data):
 h,w=data.shape[:2];im=bpy.data.images.new(p.stem,width=w,height=h,alpha=True);im.pixels.foreach_set(data.ravel());im.file_format='PNG';im.filepath_raw=str(p);im.save();bpy.data.images.remove(im)
 im=bpy.data.images.load(str(p),check_existing=False);actual=np.array(im.pixels[:],dtype=np.float32).reshape(h,w,4);bpy.data.images.remove(im);assert np.abs(actual-data).max()<1/255+.00001;return actual
captures=[];bounds=[];hashes=[];work=np.zeros((2048,4096,4),dtype=np.float32)
for state,count in[('idle',1),('working',32)]:
 for k in range(count):
  t=(first+(0 if state=='idle'else k/8))*48;s.frame_set(math.floor(t),subframe=t%1);assert_clean(s,profile,bpy)
  p=O/f'north-{state}-{k:02d}.png';s.render.filepath=str(p);bpy.ops.render.render(write_still=True)
  im=pixels(p);ys,xs=np.nonzero(im[:,:,3]>.01);box=[int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)];assert min(box[:2])>1 and max(box[2:])<511,(p.name,box)
  bounds.append({'file':p.name,'alpha_bounds':box});captures.append({'file':p.name,'facing':'north','state':state,'index':k,'runtime_time_seconds':t/48,'source_equivalent_frame':1+(t/48-first)*48,'sha256':sha(p),'native_orientation':True})
  if state=='idle':save(D/'north-idle.png',im)
  else:
   x=k%8*512;y=k//8*512;work[2048-y-512:2048-y,x:x+512]=im;hashes.append(sha(p))
  print('CITADEL_CAPTURE',state,k,flush=True)
readback=save(D/'north-working.png',work)
for row in captures:
 if row['state']=='working':
  k=row['index'];x=k%8*512;y=k//8*512;assert np.abs(readback[2048-y-512:2048-y,x:x+512]-pixels(O/row['file'])).max()<1/255+.00001
assert len(set(hashes))>=24
save(D/'icon.png',pixels(O/'north-working-05.png',64));files={}
for p in D.glob('*.png'):
 im=bpy.data.images.load(str(p),check_existing=False);files[p.name]={'sha256':sha(p),'dimensions':list(im.size)};bpy.data.images.remove(im)
report={'source_sha256':sha(source),'runtime_sha256':sha(runtime),'genuine_blender_frames':len(captures),'rendered_artifact':'Actual independently reimported GLB','frame_size':[512,512],'fps':8,'working_frames_per_direction':32,'idle_frames_per_direction':1,'native_directions':[0],'unique_working_images':len(set(hashes)),'all_atlas_cells_read_back_with_png_quantization_tolerance':True,'images':captures,'alpha_bounds':bounds,'files':files,'projection':{'square_ground_y_scale':math.sqrt(2),'saved_runtime_geometry_changed':False},'sprite_scale':.625,'sprite_shift':[0,-1.6/math.sqrt(2)],'native_verified':False,'owner_visual_approved':False}
assert len(captures)==33
(O/'capture-manifest.json').write_text(json.dumps(report,indent=2)+'\n');(O/'atlas-manifest.json').write_text(json.dumps(report,indent=2)+'\n');print('CITADEL_GENUINE_CAPTURE_PASS',len(captures),flush=True)
