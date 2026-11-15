"""Decode real normal-addon clocks; keep all native game/counter pixels private."""
import argparse
import json
from pathlib import Path
from PIL import Image
from run_compressor_native_jig import sha


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--profile',required=True);ap.add_argument('--addon',required=True);args=ap.parse_args();root=Path(args.profile).resolve();addon=Path(args.addon).resolve();receipt=json.loads((addon/'BUILD_RECEIPT.json').read_text())
    if not receipt['diagnostic_frame_counters']:raise RuntimeError('Actual private counter addon required')
    rows=[];shots=root/'user-data/script-output/tp-hydrogen-chain-review';requests=json.loads((shots/'screenshots.json').read_text())['requested']
    for spec in receipt['specs']:
        requested=[r for r in requests if r['path'].startswith('tp-hydrogen-chain-review/clock-'+spec['key']+'-frame')]
        if len(requested)!=65 or not all(r['crafting'] for r in requested) or any(b['tick']-a['tick']!=30 for a,b in zip(requested,requested[1:])):raise RuntimeError('Incomplete or nonuniform actual clock requests '+spec['key'])
        count=spec['frame_count'];ticks=spec['cycle_seconds']*60;cell_ticks=ticks/count;scale=spec['sprite_scale']*3
        point=(round(450+(16-128)*scale),round(450+spec['sprite_shift_y']*96+(16-128)*scale));colors=[(20+13*i,235-11*i,40+9*i) for i in range(count)]+[(240,40,240)];samples=[]
        for index in range(65):
            path=shots/f'clock-{spec["key"]}-frame{index}.png'
            with Image.open(path) as im:color=im.convert('RGB').getpixel(point)
            gains=[sum(a*b for a,b in zip(color,c))/sum(b*b for b in c) for c in colors];errors=[sum((a-g*b)**2 for a,b in zip(color,c)) for c,g in zip(colors,gains)];cell=min(range(len(errors)),key=errors.__getitem__)
            samples.append(dict(index=index,source_cell=cell,rgb=color,gain=gains[cell],distance_squared=errors[cell],sha256=sha(path)))
        cells=[r['source_cell'] for r in samples];wraps=sum(b<a for a,b in zip(cells,cells[1:]));stride=round(cell_ticks/30)
        expected_end=(cells[0]+round(64*30/cell_ticks))%count
        passed=all(r['distance_squared']<80 and r['gain']>.25 for r in samples) and set(cells)==set(range(count)) and wraps>=2 and cells[-1]==expected_end and all((b-a)%count==1 for a,b in zip(cells,cells[stride:]))
        first=next(r['tick'] for r in requests if r['path'].endswith('clock-'+spec['key']+'-frame0.png'))
        rows.append(dict(key=spec['key'],passed=passed,native_cycle_ticks=ticks,source_cell_ticks=cell_ticks,sample_origin_tick=first,actual_wraps=wraps,point=point,cells=cells,samples=samples))
    report=dict(passed=all(r['passed'] for r in rows),machines=rows,actual_rendered_orientation='north',other_directions='same structurally audited native sequences; not independently counter-decoded here',build_receipt_sha256=sha(addon/'BUILD_RECEIPT.json'),scope='Native screenshots of continuous fixture-only clock probes use actual production graphics. They prove cadence, not graphics-to-crafting or sound phase synchronization. Counter sprites remain excluded from production.')
    (root/'clock-readback.json').write_text(json.dumps(report,indent=2)+'\n');print('HYDROGEN_CHAIN_CLOCKS',report['passed'],[(r['key'],r['native_cycle_ticks'],r['actual_wraps'],r['passed']) for r in rows],flush=True)


if __name__=='__main__':main()
