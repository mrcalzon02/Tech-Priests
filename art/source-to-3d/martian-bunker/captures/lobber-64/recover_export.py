"""Recover only missing lobber chunks and assemble the existing capture safely.
One source run; bounded progress-gated batches, no polling or broad push trigger.
"""
import argparse,base64,hashlib,io,json,os,re,shutil,tempfile,urllib.request,urllib.error,zipfile,time
from pathlib import Path,PurePosixPath
from PIL import Image
O=Path(__file__).resolve().parent
SOURCE_RUN=42429529804
REPOSITORY=os.environ.get('GITHUB_REPOSITORY','mrcalzon02/Tech-Priests')
API='https://api.github.com/repos/'+REPOSITORY
CHUNK_RE=re.compile(r'capture_(?:north|south)_half \((\d+),\s*(\d+)\)')
OLD_ARTIFACT_RE=re.compile(r'lobber-heading-(\d+)-chunk-(\d+)')
REPAIR_PREFIX=f'lobber-repair-complete-{SOURCE_RUN}-'
REPAIR_RE=re.compile(re.escape(REPAIR_PREFIX)+r'd(\d{2})-c(\d{2})')
PARTIAL_PREFIX=f'lobber-repair-partial-{SOURCE_RUN}-'
PARTIAL_RE=re.compile(re.escape(PARTIAL_PREFIX)+r'd(\d{2})-c(\d{2})-\d+')
BATCH_SIZE=8
MAX_WAVES=64

def request(url):
 req=urllib.request.Request(url,headers={'Accept':'application/vnd.github+json','User-Agent':'Tech-Priests-lobber-recovery'})
 token=os.environ.get('GH_TOKEN')
 if token:req.add_unredirected_header('Authorization','Bearer '+token)
 for attempt in range(4):
  try:return urllib.request.urlopen(req,timeout=120)
  except urllib.error.HTTPError as error:
   if error.code not in [408,429,500,502,503,504] or attempt==3:raise
   print('RETRY_GET_HTTP',error.code,attempt+1,url.removeprefix(API) if url.startswith(API) else 'artifact-download',flush=True);error.close();time.sleep(min(2**(attempt+1),8))
  except (urllib.error.URLError,TimeoutError):
   if attempt==3:raise
   print('RETRY_GET_CONNECTION',attempt+1,flush=True);time.sleep(min(2**(attempt+1),8))

def api(path):
 with request(API+path) as r:return json.load(r)

def pages(path,key):
 result=[];limit=30 if key=='jobs' else 100
 for page in range(1,101):
  data=api(path+('&' if '?' in path else '?')+f'per_page={limit}&page={page}');items=data.get(key,[]);result.extend(items)
  if len(items)<limit:return result
 raise RuntimeError('API pagination exceeded bounded safety limit')

def expected_identity():
 M=json.loads((O/'source_manifest.json').read_text())
 return {'source_sha256':M['sha256'],'config_sha256':hashlib.sha256((O/'capture_config.json').read_bytes()).hexdigest(),'renderer_sha256':hashlib.sha256((O/'render_capture.py').read_bytes()+(O/'capture_common.py').read_bytes()).hexdigest()}

def inventory():
 run=api(f'/actions/runs/{SOURCE_RUN}')
 # Pin the pixel contract to the source run, even if main has subsequently moved.
 path='art/source-to-3d/martian-bunker/captures/lobber-64/LOCAL_PILOT.json'
 old=api('/contents/'+path+'?ref='+run['head_sha'])
 old_identity=json.loads(base64.b64decode(old['content']))['source_identity']
 assert expected_identity()==old_identity,'Current pixel contract differs from the original capture; do not mix frames'
 jobs=pages(f'/actions/runs/{SOURCE_RUN}/jobs','jobs')
 originals=[a for a in pages(f'/actions/runs/{SOURCE_RUN}/artifacts','artifacts') if not a['expired']]
 repairs=[a for a in pages('/actions/artifacts','artifacts') if not a['expired'] and (a['name'].startswith(REPAIR_PREFIX) or a['name'].startswith(PARTIAL_PREFIX))]
 return run,jobs,originals,repairs

def select(run,jobs,originals,repairs):
 states={}
 for j in jobs:
  m=CHUNK_RE.fullmatch(j['name'])
  if m:states[(int(m[1]),int(m[2]))]=j
 old_keys={(int(m[1]),int(m[2])) for a in originals if (m:=OLD_ARTIFACT_RE.fullmatch(a['name']))}
 fixed={(int(m[1]),int(m[2])) for a in repairs if (m:=REPAIR_RE.fullmatch(a['name']))}
 all_keys={(d,c) for d in range(64) for c in range(6)}
 done=fixed|{k for k,j in states.items() if j.get('conclusion')=='success' and k in old_keys}
 complete=run['status']=='completed' or (len(states)==384 and all(j['status']=='completed' for j in states.values()))
 todo=[]
 for key in sorted(all_keys-done):
  j=states.get(key)
  if complete or (j and j['status']=='completed'):todo.append({'direction':key[0],'chunk':key[1],'key':f'd{key[0]:02}-c{key[1]:02}'})
 if complete and len(states)!=384:raise RuntimeError('Source run has no complete 384-chunk inventory; no bulk restart was queued')
 return {'ready':done>=all_keys,'source_complete':complete,'verified_chunk_artifacts':len(done),'pending_chunks':len(all_keys-done),'repairs':todo[:BATCH_SIZE],'repairable_chunks':len(todo),'source_run':SOURCE_RUN,'source_commit':run['head_sha']}

def output(values):
 p=os.environ.get('GITHUB_OUTPUT')
 if p:
  with open(p,'a') as f:
   for key,val in values.items():f.write(key+'='+str(val)+'\n')

def valid(data,pas):
 C=json.loads((O/'capture_config.json').read_text());size=C['shadow_size'] if pas=='shadow' else C['beauty_size']
 try:
  with Image.open(io.BytesIO(data)) as im:im.verify()
  with Image.open(io.BytesIO(data)) as im:
   im.load();assert im.mode=='RGBA' and im.size==(size,size)
   box=im.getchannel('A').getbbox()
   if pas!='emission':assert box
   if box:assert box[0]>0 and box[1]>0 and box[2]<size and box[3]<size
  return True
 except (OSError,ValueError,AssertionError):return False

def import_zip(archive,destination):
 count=0;identity=expected_identity();C=json.loads((O/'capture_config.json').read_text())
 with zipfile.ZipFile(archive) as z:
  identities={}
  for name in z.namelist():
   parts=PurePosixPath(name).parts
   if len(parts)==2 and re.fullmatch(r'd\d{2}',parts[0]) and parts[1]=='identity.json':
    parsed=json.loads(z.read(name));assert parsed==identity,('Artifact identity mismatch',name);identities[parts[0]]=parsed
  for info in z.infolist():
   parts=PurePosixPath(info.filename).parts
   if len(parts)!=3 or parts[0] not in identities or parts[1] not in C['passes']:continue
   m=re.fullmatch(r'(idle|cycle|entry|settle)_(\d{3})\.png',parts[2])
   if not m or not 0<=int(parts[0][1:])<64:continue
   limit={'idle':1,'cycle':192,'entry':C['entry_frames'],'settle':C['settle_frames']}[m[1]]
   if int(m[2])>=limit:continue
   assert info.file_size<20*1024*1024,('Oversized artifact member',info.filename)
   data=z.read(info)
   if not valid(data,parts[1]):
    print('REJECTED_INVALID_FRAME',info.filename,flush=True);continue
   target=destination.joinpath(*parts);target.parent.mkdir(parents=True,exist_ok=True)
   ip=target.parent.parent/'identity.json'
   if ip.exists():assert json.loads(ip.read_text())==identity
   else:ip.write_text(json.dumps(identity,indent=2))
   if target.exists() and valid(target.read_bytes(),parts[1]):continue
   tmp=target.with_suffix('.partial');tmp.write_bytes(data);tmp.replace(target);count+=1
 return count

def download_import(artifact,destination):
 # Authorization is unredirected: it is sent to GitHub API, never to the signed blob origin.
 with tempfile.TemporaryDirectory(prefix='lobber-artifact-') as temp:
  p=Path(temp)/'artifact.zip'
  with request(artifact['archive_download_url']) as r,p.open('wb') as f:shutil.copyfileobj(r,f)
  count=import_zip(p,destination)
 print('IMPORTED',artifact['name'],count,flush=True)

def chunk_paths(direction,chunk):
 modes=[('cycle',range(chunk*32,(chunk+1)*32))]
 if chunk==0:modes += [('idle',range(1)),('entry',range(15))]
 if chunk==5:modes += [('settle',range(15))]
 return [(pas,f'd{direction:02}/{pas}/{mode}_{f:03}.png') for pas in ['beauty','emission','shadow'] for mode,frames in modes for f in frames]

def verify_chunk(directory,direction,chunk,prune=False):
 ip=directory/f'd{direction:02}'/'identity.json'
 if ip.exists():assert json.loads(ip.read_text())==expected_identity(),'Cached pixel identity mismatch'
 bad=[]
 for pas,name in chunk_paths(direction,chunk):
  p=directory/name
  if not p.exists() or not valid(p.read_bytes(),pas):
   bad.append(name)
   if prune and p.exists():p.unlink()
 if bad and not prune:raise RuntimeError('Incomplete/invalid chunk: '+json.dumps(bad[:12]))
 return bad

def continuation(state,already,wave,before):
 more=state['source_complete'] and not state['ready'] and not already
 if more:
  assert state['verified_chunk_artifacts']>before,'No verified progress: refusing to dispatch a duplicate batch'
  assert wave+1<MAX_WAVES,'Continuation limit reached'
 return {'ready':str(state['ready'] and not already).lower(),'source_commit':state['source_commit'],'continue':str(more).lower(),'next_wave':wave+1}

def main():
 p=argparse.ArgumentParser();p.add_argument('mode',choices=['plan','ready','seed','verify','collect','record']);p.add_argument('--direction',type=int);p.add_argument('--chunk',type=int);p.add_argument('--directory',type=Path,default=Path('rendered'));p.add_argument('--prune',action='store_true');a=p.parse_args()
 if a.mode=='record':
  report={'status':'VERIFIED_CAPTURE_PUBLISHED','capture_source_run':SOURCE_RUN,'source_commit':os.environ['SOURCE_COMMIT'],'assembly_commit':os.environ['ASSEMBLY_COMMIT'],'native_source_sha256':expected_identity()['source_sha256'],'release_tag':f'lobber-export-{SOURCE_RUN}-recovered','release_url':'https://github.com/'+REPOSITORY+f'/releases/tag/lobber-export-{SOURCE_RUN}-recovered','recovery_run_url':os.environ['RECOVERY_RUN_URL'],'delivery':json.loads(Path('delivery/delivery_manifest.json').read_text())}
  (O/'DELIVERY.json').write_text(json.dumps(report,indent=2));return
 if a.mode=='verify':
  bad=verify_chunk(a.directory,a.direction,a.chunk,a.prune);print('CHUNK_VALIDATION',len(bad),'missing/invalid' if a.prune else 'PASS');return
 run,jobs,originals,repairs=inventory();state=select(run,jobs,originals,repairs)
 wave=int(os.environ.get('RECOVERY_WAVE','0'));assert 0<=wave<MAX_WAVES,'Recovery wave limit reached';state['wave']=wave
 Path('recovery_state.json').write_text(json.dumps(state,indent=2));print(json.dumps(state),flush=True)
 if a.mode=='plan':
  matrix={'include':state['repairs'] or [{'direction':0,'chunk':0,'key':'d00-c00'}]};output({'matrix':json.dumps(matrix,separators=(',',':')),'has_repairs':str(bool(state['repairs'])).lower(),'verified_before':state['verified_chunk_artifacts']});return
 if a.mode=='ready':
  # A prior verified delivery makes concurrent completion events idempotent.
  try:
   saved=api('/contents/art/source-to-3d/martian-bunker/captures/lobber-64/DELIVERY.json?ref=main');published=json.loads(base64.b64decode(saved['content']));already=published.get('status')=='VERIFIED_CAPTURE_PUBLISHED' and published.get('capture_source_run')==SOURCE_RUN and published.get('native_source_sha256')==expected_identity()['source_sha256']
  except urllib.error.HTTPError as e:
   if e.code!=404:raise
   already=False
  output(continuation(state,already,wave,int(os.environ['VERIFIED_BEFORE'])));return
 if a.mode=='seed':
  key=(a.direction,a.chunk);wanted=[]
  for artifact in originals:
   m=OLD_ARTIFACT_RE.fullmatch(artifact['name'])
   if m and (int(m[1]),int(m[2]))==key:wanted.append(artifact)
  for artifact in repairs:
   m=PARTIAL_RE.fullmatch(artifact['name'])
   if m and (int(m[1]),int(m[2]))==key:wanted.append(artifact)
  for artifact in wanted:download_import(artifact,a.directory)
  verify_chunk(a.directory,a.direction,a.chunk,True);return
 if a.mode=='collect':
  assert state['ready'],'Original workers or targeted repairs are not finished'
  for artifact in originals:
   if OLD_ARTIFACT_RE.fullmatch(artifact['name']):download_import(artifact,a.directory)
  newest={}
  for artifact in repairs:
   if REPAIR_RE.fullmatch(artifact['name']):newest.setdefault(artifact['name'],artifact)
  for artifact in newest.values():download_import(artifact,a.directory)
  for direction in range(64):
   for chunk in range(6):verify_chunk(a.directory,direction,chunk)
  print('ALL_384_CHUNKS_IMPORTED_AND_VERIFIED',flush=True)
if __name__=='__main__':main()
