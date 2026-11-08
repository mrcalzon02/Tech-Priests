#!/usr/bin/env python3
"""Render a labelled preview from the same sprites/scales used by the prototype."""
import argparse,json,subprocess,shutil
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
R=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);a=p.parse_args();O=a.out;O.mkdir(parents=True,exist_ok=True)
G=R/'tech-priests_src/graphics/entity/bunker-autocannon'
m=json.loads((R/'docs/prototypes/bunker-autocannon-assets.json').read_text())
font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',14)
idle=[]
for page in range(8):
 with Image.open(G/f'idle-{page:02}.png') as im:
  for row in range(8):idle.append(im.crop((0,row*256,256,(row+1)*256)).convert('RGBA'))
with Image.open(G/'firing-16.png') as im:fire=[im.crop((f*256,0,(f+1)*256,256)).convert('RGBA') for f in range(32)]
bg=Image.new('RGBA',(480,480),(37,42,45,255));draw=ImageDraw.Draw(bg)
for x in range(16,480,64):draw.line((x,66,x,430),fill=(49,55,58),width=1)
for y in range(54,431,64):draw.line((16,y,464,y),fill=(49,55,58),width=1)
draw.rectangle((144,214,336,406),outline=(157,123,67),width=2)
draw.text((16,14),'BUNKER AUTOCANNON · 3×3',font=font,fill=(238,222,190))
draw.text((16,36),'Sprite assembly preview — not an in-game screenshot',font=font,fill=(176,186,192))
draw.text((16,438),'320 rounds/min · 552.5 physical damage/round',font=font,fill=(225,231,233))
draw.text((16,458),'20 rounds: 16 iron · exactly 2× rifle resources/round',font=font,fill=(203,212,219))
def put(canvas,im,scale,shift):
 size=round(im.width*scale*2)
 im=im.resize((size,size),Image.Resampling.LANCZOS)
 pos=(round(240+shift[0]*64-size/2),round(310+shift[1]*64-size/2))
 canvas.alpha_composite(im,pos)
for suffix in ['-shadow','','-glow']:
 with Image.open(G/f'base-north{suffix}.png') as im:put(bg,im.convert('RGBA'),m['base_scale'],m['base_shift'])
def frame(top):
 im=bg.copy();put(im,top,m['turret_scale'],m['turret_shift']);return im.convert('RGB')
frame(fire[3]).save(O/'Bunker_Autocannon_Prototype.png')
V=O/'frames';V.mkdir(exist_ok=True);gif=[]
for tick in range(850):
 if tick<200:top=idle[int(tick*.005*64)%64]
 elif tick<250:top=idle[int((tick-200)*.005*64)%64]
 elif tick<700:
  phase=(tick-250)%225
  f=int((phase%11)*32/11) if phase<220 else 31
  top=fire[f]
 else:top=idle[(16+int((tick-700)*.005*64))%64]
 im=frame(top);im.save(V/f'{tick:04}.png')
 if tick%2==0:gif.append(im)
durations=[(round((i+1)*100/30)-round(i*100/30))*10 for i in range(len(gif))]
gif[0].save(O/'Bunker_Autocannon_Prototype.gif',save_all=True,append_images=gif[1:],duration=durations,loop=0,optimize=False)
subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-framerate','60','-i',str(V/'%04d.png'),'-c:v','libx264','-crf','18','-pix_fmt','yuv420p',str(O/'Bunker_Autocannon_Prototype.mp4')],check=True)
shutil.rmtree(V)
print('PROTOTYPE_SPRITE_PREVIEW_COMPLETE')
