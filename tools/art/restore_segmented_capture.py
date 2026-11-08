"""Restore a tracked segmented Blender capture and its exact Git-byte pipeline.

Keeps operational copies outside source folders and preserves original render
identity, including source-code line endings, for existing-frame cache reuse.
"""
import argparse,hashlib,json,pathlib,subprocess
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--repo',type=pathlib.Path,required=True);p.add_argument('--capture',required=True);p.add_argument('--out',type=pathlib.Path,required=True);a=p.parse_args();repo=a.repo.resolve();out=a.out.resolve();prefix=a.capture.strip('/')+'/'
if prefix.startswith('../') or '/..' in prefix or pathlib.PurePosixPath(prefix).is_absolute():raise ValueError('Capture must be repository-relative')
paths=subprocess.check_output(['git','-C',str(repo),'ls-files','-z',prefix],encoding='utf-8').split('\0')
for path in filter(None,paths):
    dest=(out/path[len(prefix):]).resolve()
    if not dest.is_relative_to(out):raise ValueError('Capture path escapes output')
    data=subprocess.check_output(['git','-C',str(repo),'show','HEAD:'+path])
    if dest.exists() and dest.read_bytes()!=data:raise ValueError('Existing operational pipeline differs: '+str(dest))
    dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(data)
manifest=json.loads((out/'source_manifest.json').read_text());combined=hashlib.sha256();blocks=[]
for part in manifest['parts']:
    path=(out/part['path']).resolve()
    if not path.is_relative_to(out):raise ValueError('Source fragment path escape')
    data=path.read_bytes();assert len(data)==part['size_bytes'] and hashlib.sha256(data).hexdigest()==part['sha256'];combined.update(data);blocks.append(data)
assert combined.hexdigest()==manifest['sha256'] and sum(map(len,blocks))==manifest['size_bytes']
target=(out/manifest['filename']).resolve()
if not target.is_relative_to(out):raise ValueError('Native output path escape')
if target.exists():assert hashlib.sha256(target.read_bytes()).hexdigest()==manifest['sha256']
else:
    temp=target.with_suffix('.restore-partial');temp.write_bytes(b''.join(blocks));temp.replace(target)
identity={'source_sha256':manifest['sha256']}
if (out/'capture_config.json').exists():identity['config_sha256']=hashlib.sha256((out/'capture_config.json').read_bytes()).hexdigest()
if (out/'render_capture.py').exists() and (out/'capture_common.py').exists():identity['renderer_sha256']=hashlib.sha256((out/'render_capture.py').read_bytes()+(out/'capture_common.py').read_bytes()).hexdigest()
pilot=out/'LOCAL_PILOT.json'
if pilot.exists():
    reference=json.loads(pilot.read_text()).get('source_identity')
    if reference:assert identity==reference,'Restored pixel identity differs from recorded original pilot'
report={'status':'verified_segmented_source_restored','native':str(target),'source_manifest':prefix+'source_manifest.json','source_identity':identity,'fragment_count':len(blocks),'native_bytes':sum(map(len,blocks)),'base_commit':subprocess.check_output(['git','-C',str(repo),'rev-parse','HEAD'],text=True).strip()}
(out/'source-restore-checkpoint.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
