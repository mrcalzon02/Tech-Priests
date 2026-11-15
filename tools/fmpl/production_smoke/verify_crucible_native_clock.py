"""Decode temporary per-cell color counters from actual native screenshots."""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image


def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--profile',required=True);args=ap.parse_args();root=Path(args.profile).resolve()
    receipt=json.loads((root/'native-jig-receipt.json').read_text());spec=json.loads((root/'spec.json').read_text())
    if not receipt.get('diagnostic_frame_counters'):raise RuntimeError('Require actual private clock counters')
    shots=root/'user-data/script-output/tp-mh7-crucible-review';scale=spec['sprite_scale']*3
    point=(round(450+(16-128)*scale),round(450+spec['sprite_shift_y']*96+(16-128)*scale))
    colors=[(20+28*i,230-20*i,40+20*i) for i in range(8)];rows=[]
    for direction in ('north','east','south','west'):
        values=[]
        for i in range(9):
            p=shots/(direction+'-working-'+str(i)+'.png')
            with Image.open(p) as im:color=im.convert('RGB').getpixel(point)
            # Native visual opacity/light can attenuate the marker. Decode
            # its hue with one fitted brightness scalar rather than mistaking
            # a dim frame for another cell. Retain fit residual and raw RGB.
            gains=[sum(a*b for a,b in zip(color,c))/sum(b*b for b in c) for c in colors]
            distances=[sum((a-g*b)**2 for a,b in zip(color,c)) for c,g in zip(colors,gains)];index=min(range(8),key=distances.__getitem__)
            values.append(dict(capture_index=i,source_cell=index,rgb=color,brightness_gain=gains[index],distance_squared=distances[index],sha256=sha(p)))
        indices=[r['source_cell'] for r in values]
        passed=all(r['distance_squared']<200 for r in values) and all((b-a)%8==1 for a,b in zip(indices,indices[1:])) and indices[0]==indices[-1]
        rows.append(dict(direction=direction,passed=passed,cells=indices,samples=values))
    advances=all(len(set(r['cells']))>=7 and all(s['distance_squared']<25 for s in r['samples']) for r in rows)
    report=dict(passed=all(r['passed'] for r in rows),native_frames_advance_all_directions=advances,point=point,rows=rows,fixture_hashes=receipt['fixture_hashes'],primary_animation_clock=receipt.get('primary_animation_clock'),
        scope='Temporary counters in real frame cells decoded from native 60-tick screenshot intervals. Diagnostic graphic pixels are never promoted as final artwork.')
    (root/'native-clock-readback.json').write_text(json.dumps(report,indent=2)+'\n');print('NATIVE_CRUCIBLE_CLOCK',report['passed'],[(r['direction'],r['cells']) for r in rows],flush=True)


if __name__=='__main__':main()
