"""Focused recovery regression tests; no network or render jobs are launched."""
import io,hashlib,importlib.util,json,os,subprocess,tarfile,tempfile,unittest,urllib.request,zipfile
from pathlib import Path
from unittest.mock import patch
from PIL import Image
import yaml
O=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('recover',O/'recover_export.py');R=importlib.util.module_from_spec(spec);spec.loader.exec_module(R)
class RecoveryTests(unittest.TestCase):
 def fixture(self):
  jobs=[]
  for d in range(64):
   for c in range(6):jobs.append({'name':f'capture_{"north" if d<32 else "south"}_half ({d}, {c})','status':'queued','conclusion':None})
  return jobs
 def test_only_failed_worker_selected(self):
  j=self.fixture();j[0].update(status='completed',conclusion='success');j[6].update(status='completed',conclusion='failure')
  s=R.select({'status':'queued','head_sha':'d2225b3b440400bc49f68da2b5e1ede0f8cb4a86'},j,[{'name':'lobber-heading-0-chunk-0'}],[])
  self.assertEqual(s['repairs'],[{'direction':1,'chunk':0,'key':'d01-c00'}]);self.assertFalse(s['ready'])
 def test_completed_repair_not_requeued(self):
  j=self.fixture();j[6].update(status='completed',conclusion='failure')
  s=R.select({'status':'queued','head_sha':'d2225b3b440400bc49f68da2b5e1ede0f8cb4a86'},j,[],[{'name':R.REPAIR_PREFIX+'d01-c00'}]);self.assertEqual(s['repairs'],[])
 def test_complete_frames_allow_finalization(self):
  j=self.fixture();old=[]
  for i,x in enumerate(j):x.update(status='completed',conclusion='success');d,c=divmod(i,6);old.append({'name':f'lobber-heading-{d}-chunk-{c}'})
  j[6]['conclusion']='failure';old=[a for a in old if a['name']!='lobber-heading-1-chunk-0']
  s=R.select({'status':'completed','head_sha':'d2225b3b440400bc49f68da2b5e1ede0f8cb4a86'},j,old,[{'name':R.REPAIR_PREFIX+'d01-c00'}]);self.assertTrue(s['ready']);self.assertEqual(s['repairs'],[])
 def test_no_bulk_restart_when_source_is_purged(self):
  with self.assertRaisesRegex(RuntimeError,'complete 384-chunk inventory'):R.select({'status':'completed','head_sha':'d2225b3b440400bc49f68da2b5e1ede0f8cb4a86'},[],[],[])
 def test_partial_artifact_not_counted_complete(self):
  j=self.fixture();j[6].update(status='completed',conclusion='failure')
  s=R.select({'status':'queued','head_sha':'d2225b3b440400bc49f68da2b5e1ede0f8cb4a86'},j,[],[{'name':R.PARTIAL_PREFIX+'d01-c00-1'}]);self.assertEqual(len(s['repairs']),1)
 def test_cancelled_capture_is_batched(self):
  jobs=self.fixture()
  for job in jobs:job.update(status='completed',conclusion='cancelled')
  state=R.select({'status':'completed','head_sha':'source'},jobs,[],[])
  self.assertEqual(len(state['repairs']),8);self.assertEqual(state['pending_chunks'],384)
 def test_continuation_requires_progress_and_has_limit(self):
  state={'source_complete':True,'ready':False,'verified_chunk_artifacts':17,'source_commit':'source'}
  self.assertEqual(R.continuation(state,False,0,9)['next_wave'],1)
  with self.assertRaisesRegex(AssertionError,'No verified progress'):R.continuation(state,False,0,17)
  with self.assertRaisesRegex(AssertionError,'limit'):R.continuation(state,False,63,9)
  self.assertEqual(R.continuation(state,True,0,17)['continue'],'false')
  state['ready']=True
  self.assertEqual(R.continuation(state,False,0,17)['continue'],'false')
 def test_auth_not_forwarded_to_blob_origin(self):
  req=urllib.request.Request('https://api.github.com/example');req.add_unredirected_header('Authorization','Bearer unit-test-token')
  nxt=urllib.request.HTTPRedirectHandler().redirect_request(req,None,302,'Found',{},'https://example.blob.core.windows.net/file')
  self.assertFalse(nxt.has_header('Authorization'))
 def test_transient_api_failure_is_retried(self):
  error=__import__('urllib.error',fromlist=['HTTPError']).HTTPError('https://api.github.com/test',502,'Bad Gateway',{},None)
  result=object()
  with patch.object(R.urllib.request,'urlopen',side_effect=[error,result]) as call,patch.object(R.time,'sleep'):
   self.assertIs(R.request('https://api.github.com/test'),result);self.assertEqual(call.call_count,2)
 def test_real_pilot_import_is_idempotent(self):
  pilot=O.parent/'lobber_pilot_r5'/'d00'
  if not pilot.exists():self.skipTest('Optional actual local pilot frames are not present in this checkout')
  with tempfile.TemporaryDirectory() as temp:
   temp=Path(temp);archive=temp/'pilot.zip'
   with zipfile.ZipFile(archive,'w') as z:
    z.write(pilot/'identity.json','d00/identity.json')
    for pas in ['beauty','emission','shadow']:
     for p in (pilot/pas).glob('*.png'):z.write(p,'d00/'+pas+'/'+p.name)
   dst=temp/'rendered';self.assertEqual(R.import_zip(archive,dst),9);self.assertEqual(R.import_zip(archive,dst),0)
 def test_portable_zip_import_and_identity_guard(self):
  with tempfile.TemporaryDirectory() as tmp:
   tmp=Path(tmp);archive=tmp/'frames.zip';dst=tmp/'rendered'
   with zipfile.ZipFile(archive,'w') as z:
    z.writestr('d00/identity.json',json.dumps(R.expected_identity()))
    for pas,size in [('beauty',640),('emission',640),('shadow',1280)]:
     im=Image.new('RGBA',(size,size));im.putpixel((size//2,size//2),(0,0,0,255));b=io.BytesIO();im.save(b,format='PNG');z.writestr('d00/'+pas+'/cycle_000.png',b.getvalue())
   self.assertEqual(R.import_zip(archive,dst),3);self.assertEqual(R.import_zip(archive,dst),0)
   bad=tmp/'bad.zip'
   with zipfile.ZipFile(bad,'w') as z:z.writestr('d00/identity.json','{}')
   with self.assertRaises(AssertionError):R.import_zip(bad,dst)
 def test_scope_and_concurrency(self):
  paths=[O/'lobber-export-recovery.yml']+[p/'.github/workflows/lobber-export-recovery.yml' for p in O.parents];path=next((p for p in paths if p.exists()),None)
  if path is None:self.skipTest('Workflow file is not part of this source-only package')
  w=yaml.safe_load(path.read_text());self.assertEqual(w['on']['push']['paths'],['.github/workflows/lobber-export-recovery.yml']);self.assertNotIn(w['name'],w['on']['workflow_run']['workflows']);self.assertEqual(w['jobs']['repair']['strategy']['max-parallel'],8)
 def test_installer_fallback_and_cache(self):
  with tempfile.TemporaryDirectory() as tmp:
   tmp=Path(tmp);mock=tmp/'bin';mock.mkdir();data=b'#!/bin/sh\necho "Blender 5.0.1"\n';archive=tmp/'fixture.tar.xz'
   with tarfile.open(archive,'w:xz') as t:
    i=tarfile.TarInfo('blender-5.0.1-linux-x64/blender');i.mode=0o755;i.size=len(data);t.addfile(i,io.BytesIO(data))
   sha=hashlib.sha256(archive.read_bytes()).hexdigest();script=tmp/'install.sh';script.write_text((O/'install_blender.sh').read_text().replace('8019580ee1b7262e505f4196a00237ccf743c88d205b38d34201510676e60b09',sha))
   curl=mock/'curl';curl.write_text('#!/usr/bin/env python3\nimport sys,os,shutil\na=sys.argv[1:]\nif any("mirror.blender.org" in x for x in a):sys.exit(22)\nshutil.copyfile(os.environ["TEST_BLENDER_ARCHIVE"],a[a.index("--output")+1])\n');curl.chmod(0o755)
   env=dict(os.environ,PATH=str(mock)+os.pathsep+os.environ['PATH'],TEST_BLENDER_ARCHIVE=str(archive))
   subprocess.run(['bash',str(script)],cwd=tmp,env=env,check=True,capture_output=True)
   curl.write_text('#!/bin/sh\nexit 22\n');subprocess.run(['bash',str(script)],cwd=tmp,env=env,check=True,capture_output=True)
 def test_installer_rejects_wrong_checksum(self):
  with tempfile.TemporaryDirectory() as tmp:
   tmp=Path(tmp);mock=tmp/'bin';mock.mkdir();curl=mock/'curl';curl.write_text('#!/usr/bin/env python3\nimport sys\na=sys.argv[1:]\nopen(a[a.index("--output")+1],"wb").write(b"wrong binary")\n');curl.chmod(0o755)
   env=dict(os.environ,PATH=str(mock)+os.pathsep+os.environ['PATH']);r=subprocess.run(['bash',str(O/'install_blender.sh')],cwd=tmp,env=env,capture_output=True)
   self.assertNotEqual(r.returncode,0);self.assertFalse((tmp/'.tools/blender-5.0.1-linux-x64/blender').exists())
if __name__=='__main__':unittest.main()
