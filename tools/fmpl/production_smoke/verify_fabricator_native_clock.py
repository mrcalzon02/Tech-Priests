"""Decode private half-second cell counters across two native twelve-second loops."""
import argparse
import json
from pathlib import Path
from PIL import Image
from run_compressor_native_jig import sha


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--profile',required=True);args=ap.parse_args();root=Path(args.profile).resolve()
    receipt=json.loads((root/'native-jig-receipt.json').read_text());spec=json.loads((root/'spec.json').read_text())
    if not receipt['diagnostic_frame_counters']:raise RuntimeError('Private counter profile required')
    shots=root/'user-data/script-output/tp-mh7-fabricator-review';scale=spec['sprite_scale']*3
    point=(round(450+(16-128)*scale),round(450+spec['sprite_shift_y']*96+(16-128)*scale))
    colors=[(20+18*i,235-15*i,40+13*i) for i in range(12)]+[(240,40,240)];rows=[]
    for direction in ('north','east','south','west'):
        samples=[]
        for index in range(49):
            path=shots/f'{direction}-case1-frame{index}.png'
            with Image.open(path) as image:color=image.convert('RGB').getpixel(point)
            gains=[sum(a*b for a,b in zip(color,c))/sum(b*b for b in c) for c in colors]
            errors=[sum((a-g*b)**2 for a,b in zip(color,c)) for c,g in zip(colors,gains)]
            cell=min(range(len(errors)),key=errors.__getitem__)
            samples.append(dict(index=index,source_cell=cell,rgb=color,brightness_gain=gains[cell],distance_squared=errors[cell],sha256=sha(path)))
        cells=[s['source_cell'] for s in samples];wraps=sum(b<a for a,b in zip(cells,cells[1:]))
        passed=all(s['distance_squared']<80 and s['brightness_gain']>.25 for s in samples) and set(cells)==set(range(12)) and all((b-a)%12 in (0,1) for a,b in zip(cells,cells[1:])) and all((b-a)%12==1 for a,b in zip(cells,cells[2:])) and cells[-1]==cells[0] and wraps>=2
        rows.append(dict(direction=direction,passed=passed,cells=cells,actual_wraps=wraps,samples=samples))
    report=dict(passed=all(r['passed'] for r in rows),sample_interval_ticks=30,source_cell_period_ticks=60,native_cycle_ticks=720,full_loop_boundary_observed=all(r['actual_wraps']>=2 for r in rows),point=point,rows=rows,
                fixture_hashes=receipt['fixture_hashes'],source_graphic_hashes=receipt['graphic_hashes'],scope='Actual native screenshots at half-second intervals show all twelve working source cells at one cell per second and two wraps in each direction. Private counters are excluded from final art. Sound phase synchronization is not asserted.')
    (root/'native-clock-readback.json').write_text(json.dumps(report,indent=2)+'\n');print('FABRICATOR_NATIVE_CLOCK',report['passed'],[(r['direction'],r['cells']) for r in rows],flush=True)


if __name__=='__main__':main()
