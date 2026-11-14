"""Independent final-package RGBA cell equality check, resumable by exact sheet/source hashes."""
import argparse,pathlib,json,hashlib,zipfile,io,collections,os,time
from PIL import Image
def sha(b):return hashlib.sha256(b).hexdigest()
def save(p,v):
 temp=p.with_suffix('.tmp');temp.write_text(json.dumps(v,indent=2)+'\n')
 # Windows readers/security scanners can briefly deny replacing an open file.
 # Keep the last valid checkpoint and retry; never discard completed sheet proofs.
 for attempt in range(8):
  try:temp.replace(p);return
  except PermissionError:
   if attempt==7:raise
   time.sleep(min(.1*2**attempt,2))
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--capture',type=pathlib.Path,required=True);p.add_argument('--delivery',type=pathlib.Path,required=True);p.add_argument('--report',type=pathlib.Path,required=True);a=p.parse_args()
 delivery=a.delivery.resolve();capture=a.capture.resolve();a.report.parent.mkdir(parents=True,exist_ok=True)
 meta=json.loads((delivery/'capture_manifest.json').read_text());dm=json.loads((delivery/'delivery_manifest.json').read_text());assert dm['status']=='VERIFIED_CAPTURE' and dm['images']==42816
 assert meta['direction_count']==64 and meta['cycle_frames_per_heading']==192 and meta['entry_frames_per_heading']==meta['settle_frames_per_heading']==15
 proofs={};groups=collections.defaultdict(list)
 for d in range(64):
  receipt=json.loads((capture/f'full-verification/d{d:02}.json').read_text());assert receipt['source_identity']==meta['source_identity'];proofs.update(receipt['files'])
 for d,row in enumerate(meta['directions']):
  assert row['direction']==d and row['orientation']==d/64 and row['yaw_degrees']==180-d*5.625
  for pas,info in row['passes'].items():
   size=info['cell_size'][0];assert info['cell_size']==[size,size]
   groups[info['idle_sheet']].append((f'd{d:02}/{pas}/idle_000.png',info['idle_cell'][0],info['idle_cell'][1],size))
   for mode,count in [('cycle',192),('entry',15),('settle',15)]:
    sheets=info[mode] if mode=='cycle' else [info[mode]]
    for f in range(count):
     col=info['columns'];cap=info['sheet_capacity'];cell=f%cap
     groups[sheets[f//cap]].append((f'd{d:02}/{pas}/{mode}_{f:03}.png',cell%col,cell//col,size))
 assert sum(map(len,groups.values()))==42816 and len(proofs)==42816
 archives=[];index={}
 for entry in dm['archives']:
  path=(delivery/entry['filename']).resolve();assert path.is_relative_to(delivery) and path.stat().st_size==entry['bytes'];assert sha(path.read_bytes())==entry['sha256']
  z=zipfile.ZipFile(path);archives.append(z);assert z.testzip() is None
  for name in z.namelist():
   if name in groups:assert name not in index;index[name]=z
 assert set(index)==set(groups),'Missing/duplicate declared atlas files'
 checkpoint=a.report.parent/(a.report.stem+'-sheets');checkpoint.mkdir(exist_ok=True)
 progress={'status':'VERIFYING_EXACT_RGBA_CELLS','pid':os.getpid(),'source_identity':meta['source_identity'],'delivery_manifest_sha256':sha((delivery/'delivery_manifest.json').read_bytes()),'sheets':[],'cells':0}
 for number,(name,cells) in enumerate(sorted(groups.items())):
  data=index[name].read(name);digest=sha(data);record=checkpoint/(name.replace('/','_')+'.json');old=json.loads(record.read_text()) if record.exists() else None
  sources={path:proofs[path] for path,x,y,size in cells};signature={'sheet':name,'sheet_sha256':digest,'source_sha256':sources,'source_identity':meta['source_identity']}
  # Revalidate current source bytes even when a prior exact-cell proof can be reused.
  source_bytes={path:(capture/path).read_bytes() for path in sources};assert all(sha(b)==sources[path] for path,b in source_bytes.items())
  if not old or old.get('signature')!=signature or old.get('status')!='PASS_EXACT_RGBA_CELLS':
   with Image.open(io.BytesIO(data)) as atlas:
    atlas.load();assert atlas.mode=='RGBA' and max(atlas.size)<=5120
    for path,x,y,size in cells:
     with Image.open(io.BytesIO(source_bytes[path])) as src:
      src.load();assert src.mode=='RGBA' and src.size==(size,size)
      crop=atlas.crop((x*size,y*size,(x+1)*size,(y+1)*size));assert crop.tobytes()==src.tobytes(),(name,path)
   save(record,{'status':'PASS_EXACT_RGBA_CELLS','signature':signature,'cells':len(cells)})
  progress['cells']+=len(cells);progress['sheets'].append({'path':name,'sha256':digest,'cells':len(cells),'receipt_sha256':sha(record.read_bytes())})
  save(a.report,progress)
  if number%32==0:print('EXACT_ATLAS_CELLS',number+1,len(groups),progress['cells'],flush=True)
 assert progress['cells']==42816
 progress.update(status='PASS_ALL_42816_EXACT_SOURCE_TO_ATLAS_RGBA_CELLS',verified_unix=time.time());save(a.report,progress)
 for z in archives:z.close()
 print(progress['status'],len(groups),flush=True)
if __name__=='__main__':main()
