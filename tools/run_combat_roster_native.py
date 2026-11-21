"""Isolated native proof for the integrated, not WIP, AAI combat roster.
Never alters live saves, installed mods or installed actor prototypes.
"""
from pathlib import Path
import argparse, json, os, shutil, subprocess, time

ROOT=Path(__file__).resolve().parents[1]
EXE=Path(r'C:\Program Files (x86)\Steam\steamapps\common\Factorio\bin\x64\factorio.exe')
OUT=ROOT/'build/combat-roster/native'

def main():
 global OUT, EXE
 parser=argparse.ArgumentParser()
 parser.add_argument('--factorio',type=Path,default=EXE,
   help='Exact installed Factorio 2.1 executable; never installed or fetched here')
 parser.add_argument('--output-dir',type=Path,
   help='Fresh isolated test directory; never overwrite installed game data')
 parser.add_argument('--dependency-mods',type=Path,
   help='Local AAI 0.9.2, AAI Signals 0.8.0 and Informatron 0.5.0 ZIP directory')
 parser.add_argument('--scenario',choices=['battle','deployment','negative','progression','duels','batch-visual'],default='battle')
 parser.add_argument('--source-sha',default=None,
   help='Exact 40-hex source revision for visual proof provenance')
 parser.add_argument('--limit',type=int,default=15)
 parser.add_argument('--run-id',default='')
 parser.add_argument('--persistence',action='store_true')
 parser.add_argument('--visuals',action='store_true')
 parser.add_argument('--full-pack',action='store_true')
 parser.add_argument('--ordinary-construction',action='store_true')
 parser.add_argument('--quality-supplies',action='store_true')
 parser.add_argument('--ownership-overlap',action='store_true',help='Reissue an older owned actor while its priest has a new pending muster')
 parser.add_argument('--source',type=Path,help='Read-only prepared mod source to validate instead of the working source')
 parser.add_argument('--faction-off',choices=['mechanicus','astra-militarum','sororitas']);args=parser.parse_args()
 EXE=args.factorio.resolve()
 if not EXE.is_file():parser.error('Installed Factorio executable missing: '+str(EXE))
 if args.scenario=='deployment': OUT=ROOT/'build/combat-roster/deployment'
 if args.scenario=='negative': OUT=ROOT/'build/combat-roster/negative'
 if args.scenario=='progression': OUT=ROOT/'build/combat-roster/progression'
 if args.scenario=='duels': OUT=ROOT/'build/combat-roster/duels'
 if args.run_id:
  if not args.run_id.replace('-','').isalnum(): parser.error('run-id must contain letters, numbers or hyphens')
  OUT=OUT/args.run_id
 if args.output_dir:OUT=args.output_dir.resolve()
 if OUT.exists() and any(OUT.iterdir()):
  parser.error('Refusing to overwrite nonempty test output directory: '+str(OUT))
 source=args.source.resolve() if args.source else ROOT/'tech-priests_src'
 info=json.loads((source/'info.json').read_text())
 assert info['name']=='tech-priests' and info['factorio_version']=='2.1'
 assert any(d.startswith('aai-programmable-vehicles >= 0.9.2') for d in info['dependencies']), 'Integrated units need AAI hard dependency'
 assert (source/'prototypes/combat_roster.lua').is_file(), 'Production actor prototypes unavailable'
 assert (source/'scripts/core/combat_roster_bridge.lua').is_file(), 'Native AAI bridge unavailable'
 mod=OUT/'mods/tech-priests';mod.mkdir(parents=True,exist_ok=True)
 for path in source.rglob('*'):
  if not path.is_file(): continue
  dest=mod/path.relative_to(source);dest.parent.mkdir(parents=True,exist_ok=True)
  if path.suffix.lower() in ('.png','.ogg','.wav'):
   if dest.exists(): continue
   try: os.link(path,dest)
   except OSError: shutil.copy2(path,dest)
  else: shutil.copy2(path,dest)
 if args.faction_off:
  path=mod/'settings-final-fixes.lua'
  path.write_text(path.read_text(encoding='utf-8')+f'\ndata.raw["bool-setting"]["tech-priests-combat-allow-{args.faction_off}"].default_value=false\n',encoding='utf-8')
 fixture={'deployment':'deployment.lua','negative':'negative.lua','battle':'fixture.lua','progression':'progression.lua','duels':'duels.lua','batch-visual':'batch_visual.lua'}[args.scenario]
 shutil.copy2(ROOT/'tests/scenarios/combat-roster'/fixture,mod/'combat-fixture.lua')
 batch_flag='true' if args.scenario=='batch-visual' else 'false'
 (mod/'control.lua').write_text((source/'control.lua').read_text(encoding='utf-8')+f'\nTP_COMBAT_TEST_LIMIT={args.limit}\nTP_COMBAT_GUI_PROOF=true\nTP_COMBAT_ORDINARY_CONSTRUCTION={str(args.ordinary_construction).lower()}\nTP_COMBAT_QUALITY_SUPPLIES={str(args.quality_supplies).lower()}\nTP_COMBAT_OWNERSHIP_OVERLAP={str(args.ownership_overlap).lower()}\nTP_COMBAT_BATCH_VISUALS={batch_flag}\nrequire("combat-fixture")\n',encoding='utf-8')
 (mod/'data-final-fixes.lua').write_text((source/'data-final-fixes.lua').read_text(encoding='utf-8')+'''
local target=table.deepcopy(data.raw.container["wooden-chest"])
target.name="tech-priests-combat-test-target";target.max_health=100000;target.resistances={}
target.minable=nil;target.is_military_target=true;data:extend{target}
''',encoding='utf-8')
 if args.quality_supplies:
  with (mod/'data-final-fixes.lua').open('a',encoding='utf-8') as handle:
   handle.write('''
-- Harness only: same paid recipe bills, deterministic uncommon output.
local catalog=require("shared.combat_roster_catalog")
local names={"tech-priests-field-supply-pack"}
for _,ammo in pairs(catalog.ammo) do names[#names+1]=ammo.name end
for _,name in ipairs(names) do
 local recipe=table.deepcopy(data.raw.recipe[name]);recipe.name=name.."-test-quality";recipe.enabled=true
 for _,result in ipairs(recipe.results) do
  if result.name==name then result.quality_min="uncommon";result.quality_max="uncommon";result.affected_by_quality=false end
 end
 data:extend{recipe}
end
''')
 names=['base','space-age','quality','recycler','elevated-rails','tech-priests']
 dependency_root=args.dependency_mods.resolve() if args.dependency_mods else (
  Path(os.environ.get('APPDATA',str(Path.home()/'AppData/Roaming')))/'Factorio/mods')
 for name,version in [('aai-programmable-vehicles','0.9.2'),('aai-signals','0.8.0'),('informatron','0.5.0')]:
  archive=f'{name}_{version}.zip'
  location=dependency_root/archive
  if not location.is_file():
   raise FileNotFoundError('AAI_NATIVE_DEPENDENCY_MISSING: '+str(location))
  shutil.copy2(location,OUT/'mods'/archive);names.append(name)
 if args.full_pack:
  installed=Path(os.environ['APPDATA'])/'Factorio/mods'
  desired=json.loads((installed/'mod-list.json').read_text())['mods']
  for row in desired:
   name=row['name']
   if not row.get('enabled') or name in names:continue
   candidates=[p for p in installed.iterdir() if p.name.startswith(name+'_') and (p.is_dir() or p.suffix=='.zip')]
   assert candidates,f'Enabled installed dependency unavailable: {name}'
   def version(path):return tuple(int(x) for x in path.name[len(name)+1:].removesuffix('.zip').split('.'))
   current=max(candidates,key=version);dest=OUT/'mods'/current.name
   if current.is_dir():shutil.copytree(current,dest,dirs_exist_ok=True)
   else:shutil.copy2(current,dest)
   names.append(name)
  if (installed/'mod-settings.dat').exists():shutil.copy2(installed/'mod-settings.dat',OUT/'mods/mod-settings.dat')
  print('Testing full installed dependency pack:',', '.join(names),flush=True)
 (OUT/'mods/mod-list.json').write_text(json.dumps({'mods':[{'name':n,'enabled':True} for n in names]}))
 user=OUT/'user-data';user.mkdir(exist_ok=True)
 config=OUT/'config.ini';config.write_text('[path]\nread-data='+str(EXE.parents[2]/'data').replace('\\','/')+'\nwrite-data='+str(user.resolve()).replace('\\','/')+'\n[other]\ncheck-updates=false\n')
 common=[str(EXE),'--config',str(config.resolve()),'--mod-directory',str((OUT/'mods').resolve())]
 save=OUT/'test.zip'
 if args.scenario=='batch-visual':
  import re
  import sys
  if not args.source_sha or not re.fullmatch('[0-9a-f]{40}',args.source_sha):
   parser.error('--source-sha must pin exact integrated commit for genuine visual proof')
  # A headless engine can simulate a combatant; it cannot render a native
  # visual frame. Launch an actual desktop Factorio 2.1 graphical client.
  with config.open('a',encoding='utf-8') as stream:
   stream.write('[graphics]\nfull-screen=false\nwindow-width=1280\nwindow-height=800\n')
  environment=os.environ.copy()
  environment.update(SteamAppId='427520',SteamGameId='427520')
  (OUT/'steam_appid.txt').write_text('427520',encoding='utf-8')
  create_log=OUT/'create.log'
  with create_log.open('w',encoding='utf-8') as log:
   result=subprocess.run(common+['--create',str(save.resolve()),
    '--map-gen-seed','907260'],stdout=log,stderr=subprocess.STDOUT,
    timeout=240,env=environment,cwd=OUT)
  if result.returncode or not save.is_file():
   raise RuntimeError('Native batch save creation failed: '+
      create_log.read_text(errors='replace')[-4500:])
  gui_log=OUT/'graphical-client.log'
  native=OUT/'user-data/script-output/combat-roster/batch-native'
  marker='[TP-COMBAT-BATCH] NATIVE_COMBAT_PASS'
  child=None
  seen=False
  deadline=time.monotonic()+600
  with gui_log.open('w',encoding='utf-8') as log:
   child=subprocess.Popen(common+['--load-game',str(save.resolve()),
    '--disable-audio'],stdout=log,stderr=subprocess.STDOUT,
    env=environment,cwd=OUT)
   try:
    while time.monotonic()<deadline:
     if child.poll() is not None:break
     output=gui_log.read_text(errors='replace')
     if 'isolated handler failure' in output or 'Error Util.cpp' in output:
      break
     if marker in output and (native/'manifest.json').is_file():
      # The final native client may still be finishing queued screenshot
      # writes; require every numbered original source file on disk.
      try:
       receipt=json.loads((native/'manifest.json').read_text(encoding='utf-8-sig'))
       expected=receipt['frames']
       count=sum(len(frames) for frames in expected.values())
       actual=sum(1 for clip_id,frames in expected.items()
         for rec in frames
         if (native/clip_id/('frame-%04d.png'%rec['frame'])).is_file())
       if count>=100 and actual==count:
        seen=True
        break
      except (ValueError,KeyError,StopIteration,TypeError):
       pass
     time.sleep(.8)
   finally:
    if child.poll() is None:
     child.terminate()
     try:child.wait(timeout=20)
     except subprocess.TimeoutExpired:child.kill();child.wait(timeout=15)
  if not seen:
   raise RuntimeError('Native headful frame capture incomplete: '+
     gui_log.read_text(errors='replace')[-7500:])
  proof=OUT/'proof-clips'
  encoder=[sys.executable,str(ROOT/'tools/assemble_native_combat_proofs.py'),
    '--native-root',str(native),'--output-dir',str(proof),
    '--source-sha',args.source_sha]
  result=subprocess.run(encoder,cwd=ROOT,env=environment,timeout=600)
  if result.returncode:
   raise RuntimeError('Native Factorio frames exist but one or more real GIF/MP4 encodes failed; see '+str(proof))
  print(json.dumps({'status':'PASS','native':True,
   'actors_staged':30,'bunkers':14,'biters':48,'source_sha':args.source_sha,
   'manifest':str(proof/'proof-manifest.json'),'proof_dir':str(proof)}),flush=True)
  return
 for label,arguments,marker in [('create',['--create',str(save.resolve())],None),
                            ('behavior',['--test-save',str(save.resolve()),'--test-ticks','24000' if args.scenario=='deployment' else '15000' if args.scenario=='negative' else '18000' if args.scenario=='progression' else '7200' if args.scenario=='duels' else '3600'],
                             {'deployment':'[TP-COMBAT-DEPLOY] PASS','negative':'[TP-COMBAT-NEGATIVE] PASS','battle':'[TP-COMBAT-TEST] PASS','progression':'[TP-COMBAT-PROGRESSION] PASS','duels':'[TP-COMBAT-DUELS] PASS'}[args.scenario])]:
  path=OUT/(label+'.log')
  with path.open('w') as handle:
   process=subprocess.Popen(common+arguments,stdout=handle,stderr=subprocess.STDOUT)
   deadline=time.monotonic()+600
   while process.poll() is None:
    if time.monotonic()>deadline or 'isolated handler failure' in path.read_text(errors='replace'):
     process.terminate();process.wait(timeout=15);break
    time.sleep(.25)
   code=process.wait()
  output=(OUT/(label+'.log')).read_text(errors='replace')
  print(label,code,flush=True)
  if code or 'isolated handler failure' in output or marker and marker not in output:
   failures=[line for line in output.splitlines() if 'isolated handler failure' in line]
   print('\n'.join(failures[:3]) if failures else output[-4000:]);raise SystemExit(1)
 print('PASS actual AAI combat roster',flush=True)
 if args.persistence or args.visuals:
  assert args.scenario==('deployment' if args.persistence else 'battle')
  control=mod/'control.lua'
  flag='TP_COMBAT_PERSISTENCE' if args.persistence else 'TP_COMBAT_VISUALS'
  control.write_text(control.read_text(encoding='utf-8')+f'\n{flag}=true\n',encoding='utf-8')
  custody=user/'saves/_autosave-combat-roster-custody.zip'
  final=user/'saves/_autosave-combat-roster-deployment.zip'
  for path in (custody,final):path.unlink(missing_ok=True)
  environment=os.environ.copy();environment.update(SteamAppId='427520',SteamGameId='427520')
  startup=subprocess.STARTUPINFO();startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=0
  def graphical(label,load,target,marker):
   path=OUT/(label+'.log')
   with path.open('w') as handle:
    child=subprocess.Popen(common+['--load-game',str(load.resolve()),'--disable-audio'],stdout=handle,
      stderr=subprocess.STDOUT,startupinfo=startup,env=environment)
    try:
     deadline=time.monotonic()+600
     while time.monotonic()<deadline and child.poll() is None:
      output=path.read_text(errors='replace')
      if 'isolated handler failure' in output or 'Error Util.cpp' in output:break
      if target.exists() and marker in output and 'Saving finished' in output:break
      time.sleep(.25)
    finally:
     if child.poll() is None:child.terminate();child.wait(timeout=15)
   output=path.read_text(errors='replace')
   assert target.exists() and marker in output and 'isolated handler failure' not in output,output[-5000:]
   print('PASS '+label,flush=True)
  if args.visuals:
   visual_save=user/'saves/_autosave-combat-roster-visual.zip';visual_save.unlink(missing_ok=True)
   graphical('visual',save,visual_save,'[TP-COMBAT-TEST] VISUAL_PASS')
   print('PASS native graphical combat states and force masks',flush=True)
   return
  graphical('custody-save',save,custody,'[TP-COMBAT-DEPLOY] CUSTODY_SAVE')
  graphical('custody-resume',custody,final,'[TP-COMBAT-DEPLOY] PASS')
  assert '[TP-COMBAT-DEPLOY] CUSTODY_RELOAD_PASS' in (OUT/'custody-resume.log').read_text(errors='replace')
  path=OUT/'reload.log'
  with path.open('w') as handle:
   result=subprocess.run(common+['--test-save',str(final.resolve()),'--test-ticks','120'],stdout=handle,stderr=subprocess.STDOUT,timeout=180)
  output=path.read_text(errors='replace')
  assert result.returncode==0 and '[TP-COMBAT-DEPLOY] RELOAD_PASS' in output and 'isolated handler failure' not in output,output[-5000:]
  print('PASS independent-process custody and final roster reload',flush=True)

if __name__=='__main__':main()
