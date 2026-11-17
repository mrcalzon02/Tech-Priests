"""Wait for complete captures, promote artillery, then run the final mod checks.

Publication and installation follow review of the resulting evidence; this tool
does not commit, push, touch user saves, or alter the user's mod installation.
"""
import hashlib,json,shutil,subprocess,time,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];out=ROOT/'build/artillery-native';state_path=out/'finalization.json'
python=Path('C:/Users/Admin/Documents/Codex/2026-11-07/referenced-chatgpt-conversation-this-is-an/work/art-venv/Scripts/python.exe')
previous=json.loads(state_path.read_text())if state_path.exists()else {}
state={'status':'WAITING_FOR_COMPLETE_RENDER','phases':[]}
def write():
 temp=state_path.with_suffix('.next.json');temp.write_text(json.dumps(state,indent=2)+'\n')
 for attempt in range(100):
  try:temp.replace(state_path);return
  except PermissionError:
   if attempt==99:raise
   time.sleep(.05)
def run(phase,command):
 state.update(status='RUNNING',phase=phase);write();print('ARTILLERY_FINALIZATION_START',phase,flush=True)
 with (out/('final-'+phase+'.log')).open('w')as log:
  result=subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
 assert result.returncode==0,f'{phase} failed; inspect its final phase log'
 state['phases'].append({'phase':phase,'status':'PASS'});write();print('ARTILLERY_FINALIZATION_PASS',phase,flush=True)
write()
try:
 while True:
  ready=True
  for folder in ('animation-v19','shadows-v19'):
   try:r=json.loads((out/folder/'capture.json').read_text())
   except(FileNotFoundError,json.JSONDecodeError):ready=False;continue
   if r['status']!='COMPLETE'or len(r['completed_headings'])!=64:ready=False
  if ready:break
  time.sleep(5)
 run('pack',[str(python),'tools/pack_artillery_animation.py','--shadows',str(out/'shadows-v19')])
 art=out/'animated-art-v19';manifest=json.loads((art/'assets.json').read_text());assert manifest['status']=='PACKED_ALL_DIRECTIONS'
 source=ROOT/'art/bunker-artillery/candidate-v19/rolling-artillery.blend'
 assert manifest['source_sha256']==hashlib.sha256(source.read_bytes()).hexdigest()
 motion=json.loads(source.with_name('source-motion-check.json').read_text());assert motion['status']=='PASS_SOURCE_INTERFACES'and motion['source_sha256']==manifest['source_sha256']
 target=ROOT/'tech-priests_src/graphics/entity/bunker-artillery';target.mkdir(parents=True,exist_ok=True)
 for filename,expected in manifest['files'].items():
  assert hashlib.sha256((art/filename).read_bytes()).hexdigest()==expected,filename
  shutil.copy2(art/filename,target/filename)
 shutil.copy2(art/'assets.json',target/'assets.json')
 for filename in ('artillery_barrage_visuals.lua','artillery_barrage_geometry.lua','artillery_barrage_geometry.json'):
  shutil.copy2(art/filename,ROOT/'tech-priests_src/scripts'/filename)
 data=ROOT/'tech-priests_src/data.lua';text=data.read_text();line='require("prototypes.bunker_artillery").register("tech-priests")'
 if line not in text:
  marker='require("prototypes.bunker_rocket_salvo").register("tech-priests")';assert marker in text;text=text.replace(marker,marker+'\n'+line);data.write_text(text)
 info=ROOT/'tech-priests_src/info.json';metadata=json.loads(info.read_text())
 if previous.get('source_sha256')==manifest['source_sha256']and previous.get('version')==metadata['version']:
  state['version']=metadata['version']
 else:
  parts=metadata['version'].split('.');parts[-1]=str(int(parts[-1])+1);metadata['version']='.'.join(parts);state['version']=metadata['version']
 state['source_sha256']=manifest['source_sha256'];write();info.write_text(json.dumps(metadata,indent=2)+'\n')
 head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
 run('stage',['python','tools/stage_twin_cannon_main.py','--base',head])
 stage=ROOT/'build/twin-cannon/main-integration'
 scoped=out/'scoped-shared-source';scoped.mkdir(exist_ok=True)
 # Compose only artillery changes onto published main. Concurrent local
 # infrastructure edits remain untouched in the shared working source.
 with tarfile.open(stage/'main-source.tar')as archive:
  shared={name:archive.extractfile('tech-priests_src/'+name).read()for name in ('control.lua','data.lua','data-final-fixes.lua','info.json')}
 marker=b'require("prototypes.bunker_rocket_salvo").register("tech-priests")'
 shared['data.lua']=shared['data.lua'].replace(marker,marker+b'\nrequire("prototypes.bunker_artillery").register("tech-priests")')
 marker=b'require("prototypes.bunker_rocket_salvo").finalize()'
 shared['data-final-fixes.lua']=shared['data-final-fixes.lua'].replace(marker,marker+b'\nrequire("prototypes.bunker_artillery").finalize()')
 scoped_info=json.loads(shared['info.json']);scoped_info['version']=state['version'];shared['info.json']=(json.dumps(scoped_info,indent=2)+'\n').encode()
 for name,content in shared.items():
  (scoped/name).write_bytes(content);(stage/'mods/tech-priests'/name).write_bytes(content)
 state['base_commit']=head;state['scoped_shared_files']={name:hashlib.sha256(content).hexdigest()for name,content in shared.items()};write()
 command=['python','tools/run_artillery_main.py','--production-control',str(scoped/'control.lua')]
 run('main-physics',command)
 run('main-save',command+['--server-save'])
 run('main-reload',command+['--reload'])
 run('main-graphics',command+['--graphics'])
 with tarfile.open(stage/'main-source.tar')as archive:updates=archive.extractfile('tech-priests_src/data-updates.lua').read()
 (stage/'mods/tech-priests/data-updates.lua').write_bytes(updates)
 run('cannon-family-regression',['python','tools/run_twin_cannon_main.py'])
 run('rocket-regression',['python','tools/run_rocket_salvo_main_physics.py'])
 state.update(status='READY_FOR_FINAL_REVIEW',phase='review');write();print('ARTILLERY_READY_FOR_FINAL_REVIEW',state['version'],flush=True)
except Exception as error:
 state.update(status='FAILED',error=str(error));write();raise
