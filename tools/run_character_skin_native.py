"""Isolated Factorio 2.1 engine validation of the actual feature modules."""
from pathlib import Path
import argparse
import json
import os
import shutil
import subprocess
import time
import zipfile

ROOT=Path(__file__).resolve().parents[1]

# The reference retains the real native artwork and all native motion metadata.
# The source registration must alter only drawing pixels on the player prototype.
DATA_GUARD = r'''
local skin_module=require("prototypes.character_skins")
local register=skin_module.register
local function unchanged(a,b,in_animation)
  if type(a)~=type(b) then return false end
  if type(a)~="table" then return a==b end
  for key,value in pairs(a) do
    if not (in_animation and (key=="tint" or key=="apply_runtime_tint"))
      and not unchanged(value,b[key],in_animation or key=="animations") then return false end
  end
  for key in pairs(b) do
    if not (in_animation and (key=="tint" or key=="apply_runtime_tint")) and a[key]==nil then return false end
  end
  return true
end
skin_module.register=function(...)
  local before=table.deepcopy(assert(data.raw.character.character))
  local corpse_before=table.deepcopy(assert(data.raw["character-corpse"]["character-corpse"]))
  local reference=table.deepcopy(before)
  reference.name="tp-skin-reference-character"
  reference.hidden=true
  reference.hidden_in_factoriopedia=true
  data:extend{reference}
  local result=register(...)
  assert(unchanged(before,data.raw.character.character,false),"Appearance changed native character gameplay or animation timing")
  assert(unchanged(corpse_before,data.raw["character-corpse"]["character-corpse"],false),"Appearance changed the native visible Engineer corpse")
  log("[TP-SKINS-DATA] PASS exact native gameplay and animation timing, unchanged visible native corpse; only pixel tint may change")
  return result
end
'''


def copy_file(source, destination):
 destination.parent.mkdir(parents=True,exist_ok=True)
 if source.suffix.lower() in ('.png','.ogg','.wav','.zip'):
  if destination.exists():destination.unlink()
  try:os.link(source,destination)
  except OSError:shutil.copy2(source,destination)
 else:shutil.copy2(source,destination)


def stage_dependencies(source, destination):
 names=[]
 if source is None:return names
 if not source.is_dir():raise ValueError('Dependency mod directory is missing: '+str(source))
 for path in sorted(source.iterdir()):
  if path.is_file() and path.suffix.lower()=='.zip':
   with zipfile.ZipFile(path) as archive:
    matches=[name for name in archive.namelist() if name.endswith('/info.json') and name.count('/')==1]
    if len(matches)!=1:raise ValueError('Dependency archive requires one info.json: '+str(path))
    name=json.loads(archive.read(matches[0]))['name']
   if name=='tech-priests':continue
   copy_file(path,destination/path.name);names.append(name)
  elif path.is_dir() and (path/'info.json').is_file():
   name=json.loads((path/'info.json').read_text(encoding='utf-8-sig'))['name']
   if name=='tech-priests':continue
   shutil.copytree(path,destination/path.name,dirs_exist_ok=True);names.append(name)
 return names

def main():
 p=argparse.ArgumentParser()
 p.add_argument('--case',choices=['default','restricted','disabled','legacy'],default='default')
 p.add_argument('--full',action='store_true',help='Load the complete source mod rather than the isolated prototype fixture')
 p.add_argument('--output-root',type=Path,default=ROOT/'build/character-skins-native')
 p.add_argument('--source',type=Path,default=ROOT/'tech-priests_src',help='Exact staged source and graphics to validate')
 p.add_argument('--dependency-mods',type=Path,help='Directory of required official dependency ZIPs or unpacked mods for --full')
 p.add_argument('--headless-only',action='store_true',help='Validate data and native player behavior without graphical capture/reload')
 p.add_argument('--configuration-reload',action='store_true',help='Also verify configuration migration in a separate native process')
 p.add_argument('--factorio',type=Path,default=Path(r'C:\Program Files (x86)\Steam\steamapps\common\Factorio\bin\x64\factorio.exe'))
 a=p.parse_args()
 a.factorio=a.factorio.resolve()
 out=(a.output_root/('full-'+a.case if a.full else a.case)).resolve()
 mod=out/'mods/tech-priests'
 mod.mkdir(parents=True,exist_ok=True)
 source=a.source.resolve()
 if not (source/'info.json').is_file():raise ValueError('Source mod info.json is missing: '+str(source))
 if source==mod or source in mod.parents:raise ValueError('Test output must be outside the source mod directory')
 if a.full:
  for path in source.rglob('*'):
   if path.is_file():
    copy_file(path,mod/path.relative_to(source))
 files=['shared/character_skin_catalog.lua','shared/combat_roster_catalog.lua','prototypes/character_skins.lua','prototypes/character_skin_settings.lua','prototypes/engineer_visuals.lua',
        'scripts/core/runtime_tick_broker.lua','scripts/core/broker_pressure_cache_1502.lua','scripts/core/character_visuals.lua','scripts/core/character_skin_picker.lua',
        'scripts/core/character_skin_transfer.lua','scripts/core/runtime_event_registry.lua','scripts/core/engineer_visuals.lua',
        'locale/en/character-skins.cfg','THIRD-PARTY-NOTICES-GLADIUS.txt']
 for relative in files:
  dest=mod/relative;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source/relative,dest)
 for relative in ('graphics/entity/gladius-donors','graphics/icons/character-skins'):
  for path in (source/relative).rglob('*'):
   if path.is_file():
    if not a.full:copy_file(path,mod/path.relative_to(source))
 info=json.loads((source/'info.json').read_text())
 info['dependencies']=['base >= 2.1.0'];info['title']='Tech Priests isolated character appearance test'
 (mod/'info.json').write_text(json.dumps(info))
 (mod/'settings.lua').write_text('require("prototypes.character_skin_settings")\n')
 overrides=''
 if a.case=='restricted':overrides='data.raw["bool-setting"]["tech-priests-skin-allow-canoness"].default_value=false\n'
 if a.case=='disabled':overrides='data.raw["bool-setting"]["tech-priests-character-picker-enabled"].default_value=false\n'
 (mod/'settings-final-fixes.lua').write_text(overrides)
 (mod/'data.lua').write_text('''local catalog=require("shared.character_skin_catalog")
local definitions={}
local health={junior=150,intermediate=300,senior=600,["planetary-magos"]=850,void=850}
for rank in pairs(catalog.ranks) do
 for _,suffix in ipairs({"","-belt-immune"}) do
  local unit=table.deepcopy(data.raw.unit["small-biter"])
  unit.name=rank.."-tech-priest"..suffix
  unit.max_health=health[rank]
  unit.corpse=rank.."-tech-priest-corpse"
  definitions[#definitions+1]=unit
 end
 local corpse=table.deepcopy(data.raw.corpse["small-biter-corpse"])
 corpse.name=rank.."-tech-priest-corpse"
 definitions[#definitions+1]=corpse
end
data:extend(definitions)
''')
 (mod/'data-final-fixes.lua').write_text('require("prototypes.character_skins").register()\n')
 shutil.copy2(ROOT/'tests/scenarios/character-skins/fixture.lua',mod/'fixture.lua')
 if a.case=='legacy':
  fixture=mod/'fixture.lua';fixture.write_text(fixture.read_text().replace('local legacy_case=false','local legacy_case=true'))
 (mod/'control.lua').write_text('assert(require("scripts.core.character_skin_picker").install())\nrequire("fixture")\n')
 if a.full:
  # Full integration retains actual settings, prototypes and runtime owners.
  for name in ('info.json','settings.lua','data.lua','data-final-fixes.lua'):
   shutil.copy2(source/name,mod/name)
  (mod/'control.lua').write_text((source/'control.lua').read_text(encoding='utf-8')+'\nrequire("fixture")\n',encoding='utf-8')
  fixture=(mod/'fixture.lua').read_text()
  fixture=fixture.replace('tp.pairs_by_station[station.unit_number]=pair;tp.pairs_by_priest[priest.unit_number]=pair',
                          'Visuals.track(priest,model) -- actual prototypes; no synthetic gameplay pairs')
  (mod/'fixture.lua').write_text(fixture)
 data_final=mod/'data-final-fixes.lua'
 data_final.write_text(DATA_GUARD+'\n'+data_final.read_text(encoding='utf-8'),encoding='utf-8')
 mods=out/'mods'
 dependencies=stage_dependencies(a.dependency_mods,mods) if a.full else []
 enabled={'base':True,'tech-priests':True}
 enabled.update({name:a.full for name in ('space-age','quality','elevated-rails','recycler')})
 enabled.update({name:True for name in dependencies})
 (mods/'mod-list.json').write_text(json.dumps({'mods':[{'name':name,'enabled':value} for name,value in enabled.items()]}))
 user=out/'user-data';user.mkdir(exist_ok=True)
 config=out/'config.ini'
 config.write_text('[path]\nread-data='+str(a.factorio.parents[2]/'data').replace('\\','/')+'\nwrite-data='+str(user.resolve()).replace('\\','/')+'\n[other]\ncheck-updates=false\n')
 save=out/'test.zip'
 common=[str(a.factorio),'--config',str(config.resolve()),'--mod-directory',str(mods.resolve())]
 for label,arguments in [('create',['--create',str(save.resolve())]),('native-player',['--test-save',str(save.resolve()),'--test-ticks','1200'])]:
  log=out/(label+'.log')
  with log.open('w') as handle:
   result=subprocess.run(common+arguments,stdout=handle,stderr=subprocess.STDOUT,timeout=180)
  print(label,result.returncode,str(log),flush=True)
  if result.returncode or 'isolated handler failure' in log.read_text(errors='replace'):
   print(log.read_text(errors='replace')[-6500:]);return 1
 text=(out/'native-player.log').read_text(errors='replace')
 if '[TP-SKINS-TEST] PASS ' not in text or '[TP-SKINS-DATA] PASS ' not in text or 'isolated handler failure' in text:
  print(text[-8000:]);return 1
 print('PASS native character-skin case='+a.case+' full='+str(a.full),flush=True)
 evidence=user/'script-output/character-skins/result.json'
 if not evidence.is_file() or not json.loads(evidence.read_text()).get('passed'):
  print('Missing successful native movement receipt');return 1
 print(evidence.read_text(),flush=True)
 if a.headless_only:return 0
 saved=user/'saves/_autosave-character-skins.zip'
 # --test-save deliberately suppresses autosaves and graphical screenshots.
 # A separate headed native client produces both from the same fixture.
 saved.unlink(missing_ok=True)
 screenshot=user/'script-output/character-skins/native-picker.png'
 screenshot.unlink(missing_ok=True)
 fixture=mod/'fixture.lua'
 fixture.write_text(fixture.read_text().replace('local graphical_run=false','local graphical_run=true'))
 startup=None
 if os.name=='nt':
  startup=subprocess.STARTUPINFO();startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=1
 required_screenshots=[screenshot,user/'script-output/character-skins/engineer-walking.png']
 if a.case!='disabled':required_screenshots.append(user/'script-output/character-skins/enginseer-walking.png')
 for path in required_screenshots:path.unlink(missing_ok=True)
 with (out/'graphical.log').open('w') as handle:
  environment=os.environ.copy();environment['SteamAppId']='427520';environment['SteamGameId']='427520'
  process=subprocess.Popen(common+['--load-game',str(save.resolve()),'--disable-audio'],stdout=handle,stderr=subprocess.STDOUT,startupinfo=startup,env=environment)
  try:
   deadline=time.monotonic()+150
   while time.monotonic()<deadline and process.poll() is None:
    if 'isolated handler failure' in (out/'graphical.log').read_text(errors='replace'):break
    if saved.exists() and all(path.exists() for path in required_screenshots):
     time.sleep(2);break
    time.sleep(.5)
  finally:
   if process.poll() is None:process.terminate();process.wait(timeout=15)
 graphical=(out/'graphical.log').read_text(errors='replace')
 if not saved.exists() or not all(path.exists() for path in required_screenshots) or 'isolated handler failure' in graphical:
  print(graphical[-8000:]);return 1
 print('PASS native graphical render and autosave')
 with (out/'reload.log').open('w') as handle:
  result=subprocess.run(common+['--test-save',str(saved.resolve()),'--test-ticks','60'],stdout=handle,stderr=subprocess.STDOUT,timeout=180)
 reload=(out/'reload.log').read_text(errors='replace')
 if result.returncode or 'isolated handler failure' in reload or '[TP-SKINS-TEST] RELOAD_PASS ' not in reload:
  print(reload[-6500:]);return 1
 print('PASS separate-process native save/reload')
 if a.configuration_reload:
  metadata=mod/'info.json';info=json.loads(metadata.read_text());version=info['version'].split('.');version[-1]=str(int(version[-1])+1);info['version']='.'.join(version);metadata.write_text(json.dumps(info))
  with (out/'configuration-reload.log').open('w') as handle:
   result=subprocess.run(common+['--test-save',str(saved.resolve()),'--test-ticks','60'],stdout=handle,stderr=subprocess.STDOUT,timeout=180)
  text=(out/'configuration-reload.log').read_text(errors='replace')
  if result.returncode or 'isolated handler failure' in text or '[TP-SKIN-BROKER] CONFIG_PASS ' not in text:
   print(text[-8000:]);return 1
  print('PASS separate-process configuration reload and stable broker service count')
 return 0

if __name__=='__main__':raise SystemExit(main())
