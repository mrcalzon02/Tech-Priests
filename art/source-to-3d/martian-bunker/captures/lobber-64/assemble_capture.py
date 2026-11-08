"""Validate the complete directional capture and package bounded sprite sheets."""
import argparse,json,hashlib,zipfile,subprocess,shutil
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
Image.MAX_IMAGE_PIXELS=200_000_000
O=Path(__file__).resolve().parent;C=json.loads((O/'capture_config.json').read_text())
def image(path,size,required=True):
 with Image.open(path) as src:
  assert src.mode=='RGBA' and src.size==(size,size),(str(path),src.mode,src.size)
  src.load();im=src.copy()
 box=im.getchannel('A').getbbox()
 if required:assert box,('empty alpha',str(path))
 if box:assert box[0]>0 and box[1]>0 and box[2]<size and box[3]<size,('clipped alpha',str(path),box)
 return im

def assemble(I,D):
 D.mkdir(parents=True,exist_ok=True);identities=[json.loads((I/f'd{d:02}'/'identity.json').read_text()) for d in range(64)];assert all(x==identities[0] for x in identities),'Mixed capture sources/settings'
 expected_identity={'source_sha256':json.loads((O/'source_manifest.json').read_text())['sha256'],'config_sha256':hashlib.sha256((O/'capture_config.json').read_bytes()).hexdigest(),'renderer_sha256':hashlib.sha256((O/'render_capture.py').read_bytes()+(O/'capture_common.py').read_bytes()).hexdigest()}
 assert identities[0]==expected_identity,'Capture identity does not match restored source and renderer'
 missing=[]
 for d in range(64):
  for pas in C['passes']:
   for mode,count in [('idle',1),('cycle',192),('entry',C['entry_frames']),('settle',C['settle_frames'])]:
    missing.extend(str(I/f'd{d:02}'/pas/f'{mode}_{f:03}.png') for f in range(count) if not (I/f'd{d:02}'/pas/f'{mode}_{f:03}.png').is_file())
 assert not missing,('Missing capture frames',missing[:12],len(missing))
 # Rotation preview and eight-heading inspection sheet use clean idle states.
 frames=[];board=Image.new('RGB',(1600,840),(36,40,45));draw=ImageDraw.Draw(board)
 for d in range(64):
  im=image(I/f'd{d:02}'/'beauty'/'idle_000.png',640);bg=Image.new('RGBA',im.size,(36,40,45,255));bg.alpha_composite(im);rgb=bg.convert('RGB');frames.append(rgb.resize((480,480),Image.Resampling.LANCZOS))
  if d%8==0:
   j=d//8;board.paste(rgb.resize((400,400),Image.Resampling.LANCZOS),((j%4)*400,(j//4)*420));draw.text(((j%4)*400+12,(j//4)*420+402),['N','NE','E','SE','S','SW','W','NW'][j],fill='white')
 frames[0].save(D/'Lobber_Full_Rotation.gif',save_all=True,append_images=frames[1:],duration=60,loop=0,optimize=False);board.save(D/'Lobber_Eight_Heading_Contact_Sheet.png')
 movie=D/'Lobber_Rotation_And_All_Heading_Firing.mp4'
 encoder=subprocess.Popen(['ffmpeg','-y','-loglevel','error','-f','rawvideo','-pix_fmt','rgb24','-s','640x640','-r','24','-i','pipe:0','-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(movie)],stdin=subprocess.PIPE)
 index=0
 def add(path):
  nonlocal index
  im=image(path,640);bg=Image.new('RGBA',im.size,(36,40,45,255));bg.alpha_composite(im);encoder.stdin.write(bg.convert('RGB').tobytes());index+=1
 for d in range(64):add(I/f'd{d:02}'/'beauty'/'idle_000.png')
 for d in range(64):
  src=I/f'd{d:02}'/'beauty';add(src/'idle_000.png')
  # Entry replaces the overlapping seam at startup, then joins steady playback.
  for f in range(C['entry_frames']):add(src/f'entry_{f:03}.png')
  for f in range(C['entry_frames'],192):add(src/f'cycle_{f:03}.png')
  for f in range(C['settle_frames']):add(src/f'settle_{f:03}.png')
 encoder.stdin.close();assert encoder.wait()==0,'Review video encoding failed'
 directions=[{'direction':d,'orientation':d/64,'yaw_degrees':180-d*5.625,'passes':{}} for d in range(64)];raw=0
 for pas in C['passes']:
  size=C['shadow_size'] if pas=='shadow' else C['beauty_size'];columns=4 if pas=='shadow' else 8;capacity=columns*4;rotation_side=4 if pas=='shadow' else 8;rotation_capacity=rotation_side**2;P=D/pas;P.mkdir(exist_ok=True);rot=None
  for d in range(64):
   src=I/f'd{d:02}'/pas
   if d%rotation_capacity==0:rot=Image.new('RGBA',(rotation_side*size,rotation_side*size))
   idle=image(src/'idle_000.png',size,pas!='emission');raw+=1;cell=d%rotation_capacity;rot.paste(idle,((cell%rotation_side)*size,(cell//rotation_side)*size));idle.close()
   for mode,count in [('cycle',192),('entry',C['entry_frames']),('settle',C['settle_frames'])]:
    for start in range(0,count,capacity):
     sheet=Image.new('RGBA',(columns*size,4*size));n=min(capacity,count-start)
     for j in range(n):
      im=image(src/f'{mode}_{start+j:03}.png',size,pas!='emission');raw+=1;sheet.paste(im,((j%columns)*size,(j//columns)*size));im.close()
     assert max(sheet.size)<=8192
     sheet.save(P/f'd{d:02}_{mode}_{start//capacity:02}.png');sheet.close()
   # Per-heading raw frames remain in the capture job artifacts. Remove
   # assembly working copies once their registered sheets are written.
   for raw_path in src.glob('*.png'):raw_path.unlink()
   rotation_file='rotation_64.png' if rotation_capacity==64 else f'rotation_{d//rotation_capacity:02}.png'
   directions[d]['passes'][pas]={'cycle':[f'{pas}/d{d:02}_cycle_{j:02}.png' for j in range(192//capacity)],'entry':f'{pas}/d{d:02}_entry_00.png','settle':f'{pas}/d{d:02}_settle_00.png','idle_sheet':f'{pas}/{rotation_file}','idle_cell':[cell%rotation_side,cell//rotation_side],'cell_size':[size,size],'columns':columns,'rows':4,'sheet_capacity':capacity}
   if cell==rotation_capacity-1 or d==63:
    assert max(rot.size)<=8192
    rot.save(P/rotation_file);rot.close();rot=None

 expected=64*(1+192+C['entry_frames']+C['settle_frames'])*3;assert raw==expected
 meta={'status':'VERIFIED_CAPTURE','source_identity':identities[0],'direction_count':64,'direction_mapping':'north0_clockwise','fps':24,'frame_index_base':0,'shot_events':[{'station':sid,'cycle_frame':i*32,'seconds':i*4/3} for i,sid in enumerate(['TOP_R','TOP_L','MID_R','MID_L','BOT_R','BOT_L'])],'cycle_frames_per_heading':192,'entry_frames_per_heading':C['entry_frames'],'settle_frames_per_heading':C['settle_frames'],'rendered_images':raw,'passes':C['passes'],'sheet_layouts':{'beauty':{'columns':8,'rows':4,'capacity':32},'emission':{'columns':8,'rows':4,'capacity':32},'shadow':{'columns':4,'rows':4,'capacity':16}},'maximum_sheet_dimension':5120,'idle_rotation_layouts':{'beauty':[8,8,1],'emission':[8,8,1],'shadow':[4,4,4]},'beauty_emission_cell':[640,640],'shadow_cell':[1280,1280],'shadow_offset_pixels':C['shadow_pixel_offset_from_beauty'],'pixels_per_world_unit':640/C['ortho_scale'],'registration':json.loads((O/'scene_validation.json').read_text()),'directions':directions,'base_included':False}
 (D/'capture_manifest.json').write_text(json.dumps(meta,indent=2))
 # Keep individual release archives below a conservative file-size budget.
 files=sorted(p for p in D.rglob('*') if p.is_file());(D/'checksums.json').write_text(json.dumps({str(p.relative_to(D)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files},indent=2))
 archives=[]
 for pas in C['passes']:
  batch=[];weight=0;part=0
  def write_batch(batch,part):
   out=D/f'Lobber_{pas}_{part:02}.zip'
   with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED,6) as z:
    for path in batch:z.write(path,path.relative_to(D))
    for name in ['capture_manifest.json','checksums.json']:z.write(D/name,name)
   with zipfile.ZipFile(out) as check:assert check.testzip() is None,out.name
   for path in batch:path.unlink()
   return out
  for path in sorted((D/pas).glob('*.png')):
   if batch and weight+path.stat().st_size>350*1024*1024:archives.append(write_batch(batch,part));batch=[];weight=0;part+=1
   batch.append(path);weight+=path.stat().st_size
  if batch:archives.append(write_batch(batch,part))
 source=D/'Lobber_Editable_Source_And_Metadata.zip'
 with zipfile.ZipFile(source,'w',zipfile.ZIP_DEFLATED,6) as z:
  for path in O.iterdir():
   if path.suffix in ['.blend','.py','.json','.md','.sh']:z.write(path,'source/'+path.name)
 archives.append(source)
 for p in archives:
  with zipfile.ZipFile(p) as z:assert z.testzip() is None,p.name
 (D/'delivery_manifest.json').write_text(json.dumps({'status':'VERIFIED_CAPTURE','images':raw,'archives':[{'filename':p.name,'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in archives]},indent=2));print('LOBBER_ALL_64_HEADINGS_VERIFIED',raw,flush=True)

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--input',default='rendered');p.add_argument('--output',default='delivery');a=p.parse_args();assemble(Path(a.input),Path(a.output))
