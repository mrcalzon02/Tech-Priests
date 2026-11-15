"""Decode private source-cell counters at half-second native intervals."""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image


def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--profile',required=True);args=ap.parse_args();root=Path(args.profile).resolve()
    receipt=json.loads((root/'native-jig-receipt.json').read_text());spec=json.loads((root/'spec.json').read_text())
    if not receipt['diagnostic_frame_counters']:raise RuntimeError('Require private native clock counters')
    shots=root/'user-data/script-output/tp-mh7-forge-review';scale=spec['sprite_scale']*3
    point=(round(450+(16-128)*scale),round(450+spec['sprite_shift_y']*96+(16-128)*scale))
    colors=[(20+28*i,230-20*i,40+20*i) for i in range(8)]+[(220,40,230)];rows=[]
    for direction in ('north','east','south','west'):
        samples=[]
        for i in range(16):
            p=shots/f'{direction}-working-{i}.png'
            with Image.open(p) as im:color=im.convert('RGB').getpixel(point)
            gains=[sum(a*b for a,b in zip(color,c))/sum(b*b for b in c) for c in colors]
            errors=[sum((a-g*b)**2 for a,b in zip(color,c)) for c,g in zip(colors,gains)]
            cell=min(range(len(errors)),key=errors.__getitem__)
            samples.append(dict(capture_index=i,source_cell=cell,rgb=color,brightness_gain=gains[cell],distance_squared=errors[cell],sha256=sha(p)))
        cells=[s['source_cell'] for s in samples]
        passed=all(s['distance_squared']<80 and s['brightness_gain']>.25 for s in samples) and set(cells)==set(range(8)) and all((b-a)%8 in (0,1) for a,b in zip(cells,cells[1:])) and all((b-a)%8==1 for a,b in zip(cells,cells[2:]))
        rows.append(dict(direction=direction,passed=passed,cells=cells,samples=samples))
    report=dict(passed=all(r['passed'] for r in rows),all_eight_source_cells_each_direction=all(set(r['cells'])==set(range(8)) for r in rows),sample_interval_ticks=30,source_frame_period_ticks=60,nominal_cycle_seconds=8,full_loop_boundary_observed=False,
        point=point,rows=rows,fixture_hashes=receipt['fixture_hashes'],scope='Actual native half-second snapshots traverse all eight working cells at one cell per second in each direction. Source/GLB separately prove eight-second loop closure; a stopped single native craft does not establish a continuous-loop boundary. Private counters are excluded from final artwork.')
    (root/'native-clock-readback.json').write_text(json.dumps(report,indent=2)+'\n');print('FORGE_NATIVE_CLOCK',report['passed'],[(r['direction'],r['cells']) for r in rows],flush=True)


if __name__=='__main__':main()
