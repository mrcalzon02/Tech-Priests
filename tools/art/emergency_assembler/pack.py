"""Pack actual V07 Cycles frames; bind native registration to source/camera hashes."""
import hashlib,json,math,sys
from pathlib import Path
R=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(R.parent/'local-validation/deps'))
from PIL import Image,ImageDraw,ImageChops
O=R/'art/source-to-3d/emergency-assembler/v07';C=O/'captures';G=R/'tech-priests_src/graphics/entity/emergency-assembler-v07';G.mkdir(parents=True,exist_ok=True)
h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
source=O/'tech_priests_emergency_assembler_v07_animated.blend'
audit=json.loads((O/'motion-audit.json').read_text())
receipt=json.loads((C/'receipt-0-1-2-3.json').read_text())
assert receipt['source_sha256']==h(source)
assert audit['status']=='PASS' and audit['source_sha256']==h(source)
sys.path.insert(0,str(R/'tools/fmpl'));from capture_policy import verify_camera_receipt
verify_camera_receipt(receipt['camera'],receipt['profile'])
size=256;files=[];border_max=[];frames={}
shadow_edge_mask=Image.new('L',(size,size))
shadow_edge_mask.putdata([round(255*min(1,min(x,y,size-1-x,size-1-y)/12)) for y in range(size) for x in range(size)])
def clean(path):
 im=Image.open(path).convert('RGBA');assert im.size==(size,size)
 alpha=im.getchannel('A');edge=max(max(alpha.crop(box).getdata()) for box in [(0,0,size,1),(0,size-1,size,size),(0,0,1,size),(size-1,0,size,size)])
 border_max.append(edge)
 edge_pixels=[]
 for box in [(0,0,size,12),(0,size-12,size,size),(0,0,12,size),(size-12,0,size,size)]:edge_pixels.extend(im.crop(box).getdata())
 assert not any(max(r,g,b)>32 and alpha>16 for r,g,b,alpha in edge_pixels), (path,'Visible machinery enters shadow-only frame margin')
 # Very faint Cycles shadow-catcher sampling noise is not a machine surface.
 # Remove <=8/255 alpha everywhere, keeping the meaningful physical shadow.
 im.putalpha(ImageChops.multiply(alpha.point(lambda x:0 if x<=8 else x),shadow_edge_mask))
 assert im.getchannel('A').getbbox(),path
 return im
for d,name in enumerate(('north','east','south','west')):
 sheet=Image.new('RGBA',(size*12,size*12));frames[d]=[]
 for i,f in enumerate(range(0,288,2)):
  im=clean(C/f'd{d}-f{f:03d}.png');frames[d].append(im);sheet.paste(im,((i%12)*size,(i//12)*size))
 assert len({hashlib.sha256(im.tobytes()).hexdigest() for im in frames[d]})>32, (name,'Working animation is frozen')
 path=G/f'working-{name}.png';sheet.save(path,optimize=True);files.append({'file':path.name,'sha256':h(path),'frames':144})
 path=G/f'idle-{name}.png';frames[d][0].save(path,optimize=True);files.append({'file':path.name,'sha256':h(path),'frames':1})
icon=frames[0][0].copy();alpha=icon.getchannel('A');box=alpha.point(lambda x:255 if x>40 else 0).getbbox();icon=icon.crop(box);icon.thumbnail((116,116),Image.Resampling.LANCZOS)
canvas=Image.new('RGBA',(128,128));canvas.alpha_composite(icon,((128-icon.width)//2,(128-icon.height)//2));canvas.save(G/'icon.png',optimize=True);files.append({'file':'icon.png','sha256':h(G/'icon.png')})
board=Image.new('RGB',(7*256,4*280),(42,45,47));draw=ImageDraw.Draw(board)
for d,name in enumerate(('north','east','south','west')):
 for col,index in enumerate((0,24,42,66,90,120,143)):
  board.paste(Image.alpha_composite(Image.new('RGBA',(256,256),(42,45,47,255)),frames[d][index]),(col*256,d*280))
  draw.text((col*256+8,d*280+259),f'{name}: {index/12:.2f}s',fill=(232,232,232))
board.save(O/'four-direction-cycle-review.png')
preview=[]
for i in range(144):
 frame=Image.new('RGB',(512,512),(42,45,47))
 for d in range(4):frame.paste(Image.alpha_composite(Image.new('RGBA',(256,256),(42,45,47,255)),frames[d][i]),((d%2)*256,(d//2)*256))
 preview.append(frame)
preview[0].save(O/'emergency-assembler-v07-four-directions.gif',save_all=True,append_images=preview[1:],duration=[83,83,84]*48,loop=0,optimize=False)
manifest=dict(status='PASS',source=source.relative_to(R).as_posix(),source_sha256=h(source),source_frames=288,source_fps=24,runtime_frames=144,runtime_fps=12,duration_seconds=12,directions=['north','east','south','west'],capture_receipt=(C/'receipt-0-1-2-3.json').relative_to(R).as_posix(),camera=receipt['camera'],scale=.1875,shift=[0,-.30*math.sqrt(.5)],footprint=[1,1],shadow='Actual per-frame Cycles ground shadow embedded in RGBA body',alpha_noise_cleanup='Alpha <=8/255 removed; outer 12px soft shadow-only margin feathered to transparent to avoid texture-border seams',source_border_alpha_max=max(border_max),files=files)
(O/'atlas-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');print('V07_ATLASES_PACKED',len(files),max(border_max))
