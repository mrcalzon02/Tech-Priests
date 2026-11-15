"""Fresh-process contact measurements for authored load and electrical paths."""
import argparse
import json
from pathlib import Path
import sys
import bpy

sys.path.insert(0,str(Path(__file__).resolve().parent))
from refine_purifier_v14 import sha
from verify_purifier_v14 import gap


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--dir',required=True)
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);out=Path(args.dir).resolve()
    source=out/'electrolyzer-v01.blend'
    receipt=json.loads((out/'construction-receipt.json').read_text())
    bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene;s.frame_set(25);bpy.context.view_layer.update()
    pairs=list(receipt['contacts']);prefix='TP_ELECTROLYZER_V01 | '
    def add(a,b,label):pairs.append(dict(a=prefix+a,b=prefix+b,label=label))
    for x in (-1.13,1.13):
        for y in (-1.,1.):
            # Original tuple formatting is retained in saved object names.
            def find(token):
                matches=[o for o in s.objects if token in o.name and abs(o.location.x-x)<.001 and abs(o.location.y-y)<.001]
                if len(matches)!=1:raise RuntimeError('Ambiguous support '+str((token,x,y)))
                return matches[0].name
            pairs.append(dict(a=find('red upright web'),b=find('column shoe'),label='column seated in shoe'))
            bridge=next(o.name for o in s.objects if 'overhead transverse web' in o.name and abs(o.location.y-y)<.001)
            pairs.append(dict(a=find('red upright web'),b=bridge,label='column carries service bridge'))
    for i,x in enumerate((-.62,.62),1):
        add('cell bottom pressure closure '+str(i),'cell bearing plinth '+str(i),'cell supported on bearing plinth')
        add('cell bearing plinth '+str(i),'ferrocrete equipment footing','cell plinth on footing')
        add('electrode chamber shell '+str(i),'cell bottom pressure closure '+str(i),'closed chamber seated on base')
        add('electrode chamber shell '+str(i),'top gas collector closure '+str(i),'cell head seated on chamber')
    add('console mounting pedestal','console seated foot','console pedestal grounded')
    add('console seated foot','front rail clear of water mouth 0.4','console foot on front skid')
    case=next(o.name for o in s.objects if 'front service cogitator /' in o.name and 'service interface casting' in o.name)
    pairs.append(dict(a=case,b=prefix+'console mounting pedestal',label='donor console case seated on pedestal'))
    # Validate the actual supported rectifier, with two distinct bearing piers.
    for x in (-.61,.61):
        add('rectifier cast enclosure','rectifier foundation pier '+str(x),'rectifier on foundation pier')
        add('rectifier foundation pier '+str(x),'ferrocrete equipment footing','rectifier pier on foundation')
    results=[]
    for row in pairs:
        a,b=(bpy.data.objects.get(row[k]) for k in ('a','b'))
        distance=gap(a,b) if a and b else None
        results.append(dict(**row,gap_tiles=distance,passed=distance is not None and distance<=.015))
    failed=[r for r in results if not r['passed']]
    report=dict(source_sha256=sha(source),passed=not failed,contact_count=len(results),contacts=results,
                scope='evaluated triangle surface contact/nearest-vertex distance; load-path assembly check, not structural simulation',
                failures=failed)
    (out/'contact-readback.json').write_text(json.dumps(report,indent=2)+'\n')
    print('ELECTROLYZER_CONTACTS',len(results),'failures',json.dumps(failed),flush=True)


if __name__=='__main__':main()
