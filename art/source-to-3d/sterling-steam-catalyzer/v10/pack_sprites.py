import bpy,json,hashlib,shutil
import numpy as np
from pathlib import Path
O=Path(__file__).resolve().parent;D=O/'sprites';D.mkdir(exist_ok=True);sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def pixels(p,size=256):
 im=bpy.data.images.load(str(p),check_existing=False);assert tuple(im.size)==(256,256)
 if size!=256:im.scale(size,size)
 data=np.array(im.pixels[:],dtype=np.float32).reshape(size,size,4);bpy.data.images.remove(im);return data
def save(p,data):
 h,w=data.shape[:2];im=bpy.data.images.new(p.stem,width=w,height=h,alpha=True);im.pixels.foreach_set(data.ravel());im.file_format='PNG';im.filepath_raw=str(p);im.save();bpy.data.images.remove(im)
 im=bpy.data.images.load(str(p),check_existing=False);actual=np.array(im.pixels[:],dtype=np.float32).reshape(h,w,4);bpy.data.images.remove(im);assert np.abs(actual-data).max()<1/255+.00001;return actual
c=json.loads((O/'capture-manifest.json').read_text());assert c['genuine_blender_frames']==68;files={};bounds=[];board=np.zeros((512,1024,4),dtype=np.float32);unique={}
for i,facing in enumerate(['north','east','south','west']):
 rows=[r for r in c['images'] if r['facing']==facing];assert len(rows)==17;work=np.zeros((512,2048,4),dtype=np.float32);idle=None;hashes=[]
 for row in rows:
  p=O/row['file'];assert sha(p)==row['sha256'];im=pixels(p);ys,xs=np.nonzero(im[:,:,3]>.01);box=[int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)];assert min(box[:2])>1 and max(box[2:])<255,(row['file'],box);bounds.append({'file':row['file'],'alpha_bounds':box})
  if row['state']=='idle':
   idle=im.copy();retained=O/'retained-native-idle'/(facing+'-idle.png');assert np.array_equal(pixels(retained),idle),'Retained native idle pixels differ from current genuine source capture';shutil.copy2(retained,D/(facing+'-idle.png'))
  else:
   k=row['index'];x=k%8*256;y=k//8*256;work[512-y-256:512-y,x:x+256]=im;hashes.append(sha(p))
   if k==3:board[:256,i*256:(i+1)*256]=im
 assert idle is not None and len(hashes)==16
 reloaded=save(D/(facing+'-working.png'),work);board[256:,i*256:(i+1)*256]=idle;unique[facing]=len(set(hashes))
 for row in rows:
  if row['state']=='working':
   k=row['index'];x=k%8*256;y=k//8*256;assert np.abs(reloaded[512-y-256:512-y,x:x+256]-pixels(O/row['file'])).max()<1/255+.00001
assert unique['north']>=8
save(O/'review-four-directions.png',board);save(D/'icon.png',pixels(O/'north-working-03.png',64))
for p in D.glob('*.png'):
 im=bpy.data.images.load(str(p),check_existing=False);files[p.name]={'sha256':sha(p),'dimensions':list(im.size)};bpy.data.images.remove(im)
(O/'atlas-manifest.json').write_text(json.dumps({'verified':True,'source_sha256':c['source_sha256'],'runtime_sha256':c['runtime_sha256'],'genuine_frames':68,'working_frames_per_direction':16,'idle_frames_per_direction':1,'fps':4,'unique_working_images':unique,'retained_native_idle_rgba_exactly_equals_current_source_capture':True,'all_cells_read_back_with_png_quantization_tolerance':True,'alpha_bounds':bounds,'files':files,'native_verified':False,'owner_visual_approved':False},indent=2)+'\n',encoding='utf-8');print('STERLING_ATLASES_VERIFIED',unique,flush=True)
