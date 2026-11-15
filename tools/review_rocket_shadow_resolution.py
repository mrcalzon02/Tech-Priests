"""Compare registered alpha coverage on the actual paired shadow renders."""
import json
from pathlib import Path
from PIL import Image,ImageChops,ImageStat,ImageDraw
ROOT=Path(__file__).resolve().parents[1];out=ROOT/'build/rocket-salvo/shadow-resolution-review'
record=json.loads((out/'review.json').read_text());rows=[];board=Image.new('RGB',(1024,550*len(record['references'])),(180,182,185))
for row,ref in enumerate(record['references']):
    d,f=ref['direction'],ref['source_frame']
    hi=Image.open(out/f'd{d:02}-f{f:03}-512.png').convert('RGBA')
    lo=Image.open(out/f'd{d:02}-f{f:03}-256.png').convert('RGBA')
    a=hi.getchannel('A').resize((256,256),Image.Resampling.LANCZOS);b=lo.getchannel('A')
    box=ImageChops.lighter(a,b).point(lambda p:255 if p>16 else 0).getbbox();assert box
    diff=ImageChops.difference(a,b).crop(box);stat=ImageStat.Stat(diff)
    abox=a.point(lambda p:255 if p>16 else 0).getbbox();bbox=b.point(lambda p:255 if p>16 else 0).getbbox()
    drift=max(abs(x-y) for x,y in zip(abox,bbox))
    rows.append({'direction':d,'source_frame':f,'alpha_rms_255':stat.rms[0],
       'alpha_mean_abs_255':stat.mean[0],'bounds_drift_pixels':drift,
       'passed':stat.rms[0]<=3 and drift<=2,'seconds':ref['seconds']})
    y=row*550;draw=ImageDraw.Draw(board)
    draw.text((16,y+10),f'512 reference / heading {d} / frame {f}',fill='black')
    draw.text((528,y+10),'256 candidate / same physical scale',fill='black')
    board.paste(hi,(0,y+38),hi);up=lo.resize((512,512),Image.Resampling.BILINEAR);board.paste(up,(512,y+38),up)
    name=f'd{d:02}-idle.png' if f==1 else f'd{d:02}-reload-{(f-52)//2:02}.png'
    body=Image.open(ROOT/'build/rocket-salvo/runtime-pilot-v1'/name).convert('RGBA')
    board.paste(body,(128,y+166),body);board.paste(body,(640,y+166),body)
report={'status':'PASS_NUMERIC_COMPARISON' if all(r['passed'] for r in rows) else 'FAIL',
 'source_sha256':record['source_sha256'],'comparisons':rows,
 'criteria':'RMS alpha <=3/255 and coverage bounds drift <=2 pixels in the nontrivial shadow region',
 'visual_review':'Required before adopting resolution; full direction/pose counts remain unchanged'}
(out/'comparison.json').write_text(json.dumps(report,indent=2)+'\n');board.save(out/'comparison.png')
print(report['status'],rows)
