"""Package existing evaluated USD states; never rerender or touch source caches."""
import pathlib,json,zipfile,hashlib
W=pathlib.Path(__file__).parent; O=W/'a02-evaluated-usd-20261114'; D=W/'a02-usd-delivery-20261114';D.mkdir(exist_ok=True)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
summary=json.loads((O/'independent-data-summary.json').read_text());assert summary['status']=='PASS_ALL_FOUR_EVALUATED_USD_STATES'
rows=[]
for row in summary['modes']:
 mode=row['mode'];src=O/(mode+'.usdc');assert sha(src)==row['usd_sha256'];out=D/(mode+'-evaluated-usd.zip')
 assert not out.exists(),'Inspect existing archive before duplicating packaging'
 members=[src,*sorted((O/'textures').glob('*.png'))]
 with zipfile.ZipFile(out,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
  for p in members:z.write(p,p.relative_to(O).as_posix())
 with zipfile.ZipFile(out) as z:
  assert z.testzip() is None
  for p in members:assert hashlib.sha256(z.read(p.relative_to(O).as_posix())).hexdigest()==sha(p)
 rows.append({'file':out.name,'bytes':out.stat().st_size,'sha256':sha(out),'mode':mode,'usd_sha256':row['usd_sha256'],'archive_crc':'PASS','decompressed_members_sha256':'PASS'})
 (D/'CHECKPOINT.json').write_text(json.dumps({'status':'PACKAGING','archives':rows},indent=2)+'\n',encoding='utf-8',newline='\n')
 print(json.dumps(rows[-1]),flush=True)
source=W/'lobber-a02/lobber_capture.blend';assert sha(source)==summary['source_sha256']
(D/'CHECKPOINT.json').write_text(json.dumps({'status':'FOUR_LOCAL_ARCHIVES_VERIFIED','source_unchanged_sha256':sha(source),'archives':rows,'publication':'LOCAL_ONLY_UNTIL_REMOTE_READBACK'},indent=2)+'\n',encoding='utf-8',newline='\n')
