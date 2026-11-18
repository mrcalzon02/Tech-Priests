"""Isolated full-source AAI roster behavior proof; never alters live saves/mods."""
from pathlib import Path
import argparse, json, os, shutil, subprocess, time

ROOT=Path(__file__).resolve().parents[1]
EXE=Path(r'C:\Program Files (x86)\Steam\steamapps\common\Factorio\bin\x64\factorio.exe')
OUT=ROOT/'build/combat-roster/native'

def main():
 global OUT
 parser=argparse.ArgumentParser();parser.add_argument('--scenario',choices=['battle','deployment','negative','progression','duels'],default='battle')
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
 if args.scenario=='deployment': OUT=ROOT/'build/combat-roster/deployment'
 if args.scenario=='negative': OUT=ROOT/'build/combat-roster/negative'
 if args.scenario=='progression': OUT=ROOT/'build/combat-roster/progression'
 if args.scenario=='duels': OUT=ROOT/'build/combat-roster/duels'
 if args.run_id:
  if not args.run_id.replace('-','').isalnum(): parser.error('run-id must contain letters, numbers or hyphens')
  OUT=OUT/args.run_id
 source=args.source.resolve() if args.source else ROOT/'tech-priests_src'
 assert json.loads((source/'info.json').read_text())['name']=='tech-priests'
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
 fixture={'deployment':'deployment.lua','negative':'negative.lua','battle':'fixture.lua','progression':'progression.lua','duels':'duels.lua'}[args.scenario]
 shutil.copy2(ROOT/'tests/scenarios/combat-roster'/fixture,mod/'combat-fixture.lua')
 (mod/'control.lua').write_text((source/'control.lua').read_text(encoding='utf-8')+f'\nTP_COMBAT_TEST_LIMIT={args.limit}\nTP_COMBAT_GUI_PROOF=true\nTP_COMBAT_ORDINARY_CONSTRUCTION={str(args.ordinary_construction).lower()}\nTP_COMBAT_QUALITY_SUPPLIES={str(args.quality_supplies).lower()}\nTP_COMBAT_OWNERSHIP_OVERLAP={str(args.ownership_overlap).lower()}\nrequire("combat-fixture")\n',encoding='utf-8')
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
 for name,version in [('aai-programmable-vehicles','0.9.2'),('aai-signals','0.8.0'),('informatron','0.5.0')]:
  archive=f'{name}_{version}.zip';shutil.copy2(Path.home()/'AppData/Roaming/Factorio/mods'/archive,OUT/'mods'/archive);names.append(name)
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
