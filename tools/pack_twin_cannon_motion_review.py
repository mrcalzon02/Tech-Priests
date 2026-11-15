"""Create a real-time GIF and contact sheet from the rendered recoil clip."""
import json,argparse
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('frames',type=Path);a=p.parse_args()
record=json.loads((a.frames/'review.json').read_text());assert record['status']=='COMPLETE'
ticks=record['ticks'];base=Image.open(ROOT/'tech-priests_src/graphics/entity/bunker-autocannon/base-north.png').convert('RGBA')
flexible=max(ticks)>225
zoom=512/(6.199999809265137*32);anchor=(384,410);shift=-1.110906519093*32*zoom
size=round(base.width*.315463840961*zoom);base=base.resize((size,size),Image.Resampling.LANCZOS)
frames=[];snapshots={}
for tick in ticks:
    canvas=Image.new('RGBA',(768,680),(72,78,82,255))
    canvas.alpha_composite(base,(round(anchor[0]-size/2),round(anchor[1]+shift-size/2)))
    with Image.open(a.frames/f'tick-{tick:03}.png') as body:
        canvas.alpha_composite(body.convert('RGBA'),(anchor[0]-256,round(anchor[1]+shift-256)))
    image=canvas.convert('RGB');draw=ImageDraw.Draw(image)
    draw.text((24,18),'Twin cannon: recoil and traverse-driven flexible aerials' if flexible else 'Twin cannon: deep alternating recoil / slow return to battery',fill='white')
    draw.text((24,648),'Blender motion review with native cannon-effect artwork. Fixed bunker shown for scale.',fill='white')
    frames.append(image);snapshots[tick]=image
durations=[]
for i,tick in enumerate(ticks):
    next_tick=ticks[i+1] if i+1<len(ticks) else tick+30
    durations.append(max(10,round(next_tick*1000/60/10)*10-round(tick*1000/60/10)*10))
frames[0].save(a.frames/'twin-cannon-deep-recoil.gif',save_all=True,append_images=frames[1:],duration=durations,loop=0,optimize=False,disposal=2)
sheet=Image.new('RGB',(1152,1080),(40,45,48));draw=ImageDraw.Draw(sheet)
for i,tick in enumerate((0,5,15,45,50,245,275,335,480) if flexible else (0,3,15,45,48,80,90,135,215)):
    image=snapshots[tick].resize((384,340),Image.Resampling.LANCZOS);sheet.paste(image,((i%3)*384,(i//3)*360+20))
    draw.text(((i%3)*384+10,(i//3)*360+4),f'Tick {tick}',fill='white')
sheet.save(a.frames/'motion-contact-sheet.png')
print(a.frames/'twin-cannon-deep-recoil.gif')
