"""Assemble the actual rendered shutter study; no synthetic motion frames."""
import argparse,json
from pathlib import Path
from PIL import Image,ImageDraw
p=argparse.ArgumentParser();p.add_argument('frames',type=Path);a=p.parse_args()
meta=json.loads((a.frames/'frames.json').read_text());frames=[];durations=[]
def stage(f):
    if f<=82:return 'Cassette withdraws clear of flap'
    if f<=106:return 'Flap opens after cassette clears'
    if f<=150:return 'Cassette feeds under raised flap'
    if f<=174:return 'Cassette withdraws before closure'
    if f<=211:return 'Flap closes with cassette clear'
    return 'Cassette returns behind closed flap'
for i,f in enumerate(meta['frames']):
    raw=Image.open(a.frames/('%03d.png'%f)).convert('RGBA')
    frame=Image.new('RGB',(640,690),(49,51,55));frame.paste(raw,(0,25),raw)
    d=ImageDraw.Draw(frame);d.text((16,9),'ROCKET RELOAD - SOURCE ANIMATION CLEARANCE STUDY',fill='white')
    d.text((16,665),'Frame %03d | '%f+stage(f),fill='white')
    frames.append(frame.quantize(colors=160))
    gap=meta['frames'][i+1]-f if i<len(meta['frames'])-1 else 15
    durations.append(max(130,min(650,round(gap*1000/30))))
frames[0].save(a.frames/'shutter-clearance.gif',save_all=True,append_images=frames[1:],
    duration=durations,loop=0,disposal=2,optimize=False)
print('SHUTTER_GIF_READY',len(frames))
