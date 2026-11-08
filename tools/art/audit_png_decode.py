import argparse,json,hashlib
from pathlib import Path
from PIL import Image
p=argparse.ArgumentParser();p.add_argument('--repo',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();rows=[]
for f in sorted((a.repo/'tech-priests_src/graphics/entity').rglob('*.png')):
    row={'path':f.relative_to(a.repo).as_posix(),'sha256':hashlib.sha256(f.read_bytes()).hexdigest()}
    try:
        with Image.open(f) as im:im.verify()
        with Image.open(f) as im:im.load();row.update(status='PASS',mode=im.mode,size=list(im.size))
    except Exception as e:row.update(status='FAIL',error=str(e))
    rows.append(row)
report={'scope':'Every current entity PNG: full decoder and PNG verification; no visual acceptance implied','files':rows,'passed':sum(r['status']=='PASS' for r in rows),'failed':sum(r['status']=='FAIL' for r in rows)}
a.out.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({'passed':report['passed'],'failed':[r['path'] for r in rows if r['status']=='FAIL']}))
