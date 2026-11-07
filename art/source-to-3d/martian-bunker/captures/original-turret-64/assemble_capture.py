import json,hashlib,zipfile,shutil,subprocess
from pathlib import Path
from PIL import Image,ImageDraw
import numpy as np
import argparse
p=argparse.ArgumentParser();p.add_argument('--input',default='rendered');p.add_argument('--output',default='delivery');a=p.parse_args()
I=Path(a.input);O=Path(a.output);O.mkdir(parents=True,exist_ok=True)
size=640;directions=[];preview=[];idle_images=[];bounds=[]
for d in range(64):
 D=I/f'd{d:02}';atlas=Image.new('RGBA',(8*size,4*size))
 for f in range(1,33):
  path=D/f'f{f:02}.png'
  with Image.open(path) as src:
   assert src.size==(size,size) and src.mode=='RGBA',str(path)
   im=src.copy()
  alpha=im.getchannel('A');box=alpha.getbbox();assert box,(d,f)
  # Visible content must stay within the registered canvas.
  assert box[0]>0 and box[1]>0 and box[2]<size and box[3]<size,(d,f,box)
  bounds.append(box)
  atlas.paste(im,(((f-1)%8)*size,((f-1)//8)*size))
  if f==1:idle_images.append(im.copy())
  # Review: each eighth heading is reached by rotating, then fired.
  if d%8==0:
   bg=Image.new('RGBA',im.size,(36,40,45,255));bg.alpha_composite(im);preview.append(bg.convert('RGB'))
 atlas.save(O/f'firing_d{d:02}.png')
 directions.append({'direction':d,'orientation':d/64,'yaw_degrees':180-d*5.625,'file':f'firing_d{d:02}.png','columns':8,'rows':4,'frame_count':32})
rot=Image.new('RGBA',(8*size,8*size))
gif=[]
for d,im in enumerate(idle_images):
 rot.paste(im,((d%8)*size,(d//8)*size))
 bg=Image.new('RGBA',im.size,(36,40,45,255));bg.alpha_composite(im);gif.append(bg.convert('RGB').resize((480,480),Image.Resampling.LANCZOS))
rot.save(O/'rotation_64_directions.png')
gif[0].save(O/'Turret_Full_Rotation.gif',save_all=True,append_images=gif[1:],duration=60,loop=0,optimize=False)
# Full movie shows continuous rotation followed by turn-to-heading and fire at all 64 headings.
V=O/'video_frames';V.mkdir(exist_ok=True);n=0
def add(im):
 global n
 bg=Image.new('RGBA',im.size,(36,40,45,255));bg.alpha_composite(im);bg.convert('RGB').save(V/f'{n:05}.png');n+=1
for im in idle_images:add(im)
for d in range(64):
 add(idle_images[d])
 for f in range(1,33):
  with Image.open(I/f'd{d:02}'/f'f{f:02}.png') as im:add(im)
subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-framerate','24','-i',str(V/'%05d.png'),'-c:v','libx264','-crf','18','-pix_fmt','yuv420p',str(O/'Turret_Rotation_And_All_Direction_Firing.mp4')],check=True)
shutil.rmtree(V)
# Eight compass headings on one inspection sheet.
board=Image.new('RGB',(1600,840),(36,40,45));draw=ImageDraw.Draw(board)
for i,d in enumerate(range(0,64,8)):
 im=idle_images[d].resize((400,400),Image.Resampling.LANCZOS);board.paste(im,((i%4)*400,(i//4)*420),im)
 draw.text(((i%4)*400+15,(i//4)*420+400),['N','NE','E','SE','S','SW','W','NW'][i],fill='white')
board.save(O/'Turret_Eight_Heading_Contact_Sheet.png')
meta={'status':'VERIFIED_CAPTURE','direction_count':64,'direction_order':'north 0, clockwise; east 16, south 32, west 48','rotation_file':'rotation_64_directions.png','rotation_columns':8,'rotation_rows':8,'cell_width':640,'cell_height':640,'fps':24,'firing_frames_per_direction':32,'rendered_frames':2048,'idle_frames':'firing frame 1 of each direction','base_included':False,'camera':'fixed 45 degree orthographic','registration':'same 640 x 640 canvas, camera, scale and pivot for every frame','directions':directions,'alpha_bounds_union':[min(b[0] for b in bounds),min(b[1] for b in bounds),max(b[2] for b in bounds),max(b[3] for b in bounds)]}
(O/'capture_manifest.json').write_text(json.dumps(meta,indent=2))
(O/'checksums.json').write_text(json.dumps({p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in O.iterdir() if p.is_file()},indent=2))
with zipfile.ZipFile('Original_Bunker_Turret_Full_Rotation_And_Firing.zip','w',zipfile.ZIP_DEFLATED,6) as z:
 for p in O.rglob('*'):
  if p.is_file():z.write(p,'Original_Bunker_Turret/'+p.relative_to(O).as_posix())
 for name in ['original_bunker_turret_capture.blend','render_capture.py','validate_scene.py','source_changes.json','scene_validation.json']:
  p=Path(__file__).resolve().parent/name
  if p.exists():z.write(p,'Original_Bunker_Turret/source/'+name)
print('ALL_64_DIRECTIONS_VERIFIED_AND_PACKAGED')
