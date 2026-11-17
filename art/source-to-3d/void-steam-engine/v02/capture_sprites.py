"""Genuine 132 actual-GLB captures; only N/E are native generator orientations."""
import bpy,json,math,hashlib,sys,struct
import numpy as np
from pathlib import Path
from mathutils import Vector
O=Path(__file__).resolve().parent;D=O/'sprites';D.mkdir(exist_ok=True)
def locate_repo():
 for parent in (O,*O.parents):
  for candidate in (parent,parent/'model-production'):
   if (candidate/'tools/fmpl/FMPL.json').is_file():return candidate
 raise FileNotFoundError('Pass a source checkout containing tools/fmpl and canonical material maps.')
sys.path.insert(0,str(locate_repo()/'tools/fmpl'))
from blender_camera_guard import install_canonical_camera,assert_clean
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
source=O/'void-steam-v02.blend';runtime=O/'void-steam-v02.glb';ins=json.loads((O/'runtime-inspection.json').read_text())
assert ins['technical_checks_passed'] and sha(source)==ins['source_sha256'] and sha(runtime)==ins['runtime_sha256']
b=runtime.read_bytes();n=struct.unpack_from('<I',b,12)[0];g=json.loads(b[20:20+n]);first=min(g['accessors'][x['input']]['min'][0] for a in g['animations'] for x in a['samplers'])
bpy.ops.wm.read_factory_settings(use_empty=True);s=bpy.context.scene;s.render.fps=48;bpy.ops.import_scene.gltf(filepath=str(runtime))
profile=json.loads((O/'capture-profile.json').read_text());install_canonical_camera(s,profile,bpy)
s.render.engine='CYCLES';s.cycles.samples=24;s.render.film_transparent=True;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA'
s.world=bpy.data.worlds.new('Void actual GLB sprite studio');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.28,.28,.28,1)
for loc,power,size in [((2,-4,6),850,5),((-4,2,4),600,4)]:
 l=bpy.data.lights.new('Actual GLB sprite area','AREA');l.energy=power;l.size=size;o=bpy.data.objects.new(l.name,l);s.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,.9))-o.location).to_track_quat('-Z','Y').to_euler()
root=bpy.data.objects['EXPORT | Void Steam Engine'];projection=bpy.data.objects.new('UNSAVED square ground projection',None);s.collection.objects.link(projection);projection.scale.y=math.sqrt(2)
yaw=bpy.data.objects.new('UNSAVED direction pose',None);s.collection.objects.link(yaw);yaw.parent=projection;root.parent=yaw
def pixels(p,size=256):
 im=bpy.data.images.load(str(p),check_existing=False);assert tuple(im.size)==(256,256)
 if size!=256:im.scale(size,size)
 data=np.array(im.pixels[:],dtype=np.float32).reshape(size,size,4);bpy.data.images.remove(im);return data
def save(p,data):
 h,w=data.shape[:2];im=bpy.data.images.new(p.stem,width=w,height=h,alpha=True);im.pixels.foreach_set(data.ravel());im.file_format='PNG';im.filepath_raw=str(p);im.save();bpy.data.images.remove(im)
 im=bpy.data.images.load(str(p),check_existing=False);actual=np.array(im.pixels[:],dtype=np.float32).reshape(h,w,4);bpy.data.images.remove(im);assert np.abs(actual-data).max()<1/255+.00001;return actual
captures=[];bounds=[];unique={};board=np.zeros((512,1024,4),dtype=np.float32)
for direction,(facing,angle) in enumerate([('north',0),('east',270),('south',180),('west',90)]):
 yaw.rotation_euler.z=math.radians(angle);work=np.zeros((1024,2048,4),dtype=np.float32);hashes=[]
 for state,count in [('idle',1),('working',32)]:
  for k in range(count):
   t=(first+(0 if state=='idle' else k/8))*48;s.frame_set(math.floor(t),subframe=t%1);assert_clean(s,profile,bpy)
   p=O/f'{facing}-{state}-{k:02d}.png';s.render.filepath=str(p);bpy.ops.render.render(write_still=True)
   im=pixels(p);ys,xs=np.nonzero(im[:,:,3]>.01);box=[int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)];assert min(box[:2])>1 and max(box[2:])<255,(p.name,box)
   bounds.append({'file':p.name,'alpha_bounds':box});captures.append({'file':p.name,'facing':facing,'state':state,'index':k,'runtime_time_seconds':t/48,'source_equivalent_frame':1+(t/48-first)*48,'sha256':sha(p),'native_orientation':facing in ('north','east')})
   if state=='idle':save(D/f'{facing}-idle.png',im);board[256:,direction*256:(direction+1)*256]=im
   else:
    x=k%8*256;y=k//8*256;work[1024-y-256:1024-y,x:x+256]=im;hashes.append(sha(p))
    if k==5:board[:256,direction*256:(direction+1)*256]=im
 readback=save(D/f'{facing}-working.png',work)
 for row in captures:
  if row['facing']==facing and row['state']=='working':
   k=row['index'];x=k%8*256;y=k//8*256;assert np.abs(readback[1024-y-256:1024-y,x:x+256]-pixels(O/row['file'])).max()<1/255+.00001
 unique[facing]=len(set(hashes));assert unique[facing]>=16
 print('VOID_CAPTURE_DIRECTION_PASS',facing,unique[facing],flush=True)
save(O/'review-four-directions.png',board);save(D/'icon.png',pixels(O/'north-working-05.png',64))
files={}
for p in D.glob('*.png'):
 im=bpy.data.images.load(str(p),check_existing=False);files[p.name]={'sha256':sha(p),'dimensions':list(im.size)};bpy.data.images.remove(im)
report={'source_sha256':sha(source),'runtime_sha256':sha(runtime),'genuine_blender_frames':len(captures),'rendered_artifact':'Actual independently reimported GLB','frame_size':[256,256],'fps':8,'working_frames_per_direction':32,'idle_frames_per_direction':1,'native_directions':[0,4],'standalone_reference_directions':[0,90,180,270],'unique_working_images':unique,'all_atlas_cells_read_back_with_png_quantization_tolerance':True,'images':captures,'alpha_bounds':bounds,'files':files,'projection':{'square_ground_y_scale':math.sqrt(2),'saved_runtime_geometry_changed':False},'native_verified':False,'owner_visual_approved':False}
assert len(captures)==132
(O/'capture-manifest.json').write_text(json.dumps(report,indent=2)+'\n');(O/'atlas-manifest.json').write_text(json.dumps(report,indent=2)+'\n')
print('VOID_GENUINE_CAPTURE_PASS',len(captures),flush=True)
