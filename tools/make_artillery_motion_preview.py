"""Package completed source-model review frames; never claim in-game footage."""
import argparse,json,hashlib,shutil
from pathlib import Path
from PIL import Image,ImageDraw

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--capture',type=Path,required=True);parser.add_argument('--candidate',type=Path,required=True);args=parser.parse_args()
capture=args.capture.resolve();candidate=args.candidate.resolve()
record=json.loads((capture/'review.json').read_text())
assert record['status']=='COMPLETE'
assert record['identity']['source_sha256']==hashlib.sha256((candidate/'rolling-artillery.blend').read_bytes()).hexdigest()
ticks=record['ticks'];frames=[];durations=[]
for i,tick in enumerate(ticks):
    with Image.open(capture/f'tick-{tick:03}.png') as source:
        box=source.getchannel('A').getbbox()
        assert box and box[0]>0 and box[1]>0 and box[2]<source.width and box[3]<source.height,('Clipped motion frame',tick,box)
        frame=Image.new('RGBA',(384,416),(28,30,33,255));frame.alpha_composite(source.convert('RGBA'),(0,32))
    label='Elevated firing / recoil' if tick<250 or tick>=550 else 'Lowering for reload' if tick<315 else 'Level reload'
    ImageDraw.Draw(frame).text((10,8),f'SOURCE ANIMATION | {tick/60:.1f}s | {label}',fill='white')
    frames.append(frame.convert('RGB').quantize(colors=128))
    durations.append(max(20,round((ticks[i+1]-tick)*1000/60)) if i+1<len(ticks) else 1000)
target=candidate/'motion-preview.gif'
frames[0].save(target,save_all=True,append_images=frames[1:],duration=durations,loop=0,disposal=2)
shutil.copy2(capture/'mount-detail.png',candidate/'mount-detail.png')
(candidate/'motion-preview.json').write_text(json.dumps({'status':'PACKED_SOURCE_PREVIEW','source_sha256':record['identity']['source_sha256'],
 'gif_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'frames':len(ticks),'source_fps':60,
 'scope':'Source geometry/animation only; no native-gameplay or owner visual acceptance claim.'},indent=2)+'\n')
print('ARTILLERY_MOTION_PREVIEW_PACKED',len(frames))
