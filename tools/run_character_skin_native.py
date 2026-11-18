"""Isolated Factorio 2.1 engine validation of the actual feature modules."""
from pathlib import Path
import argparse
import json
import os
import shutil
import subprocess
import time

ROOT=Path(__file__).resolve().parents[1]

def main():
 p=argparse.ArgumentParser()
 p.add_argument('--case',choices=['default','restricted','disabled'],default='default')
 p.add_argument('--full',action='store_true',help='Load the complete source mod rather than the isolated prototype fixture')
 p.add_argument('--output-root',type=Path,default=ROOT/'build/character-skins-native')
 p.add_argument('--headless-only',action='store_true',help='Validate data and native player behavior without graphical capture/reload')
 p.add_argument('--factorio',type=Path,default=Path(r'C:\Program Files (x86)\Steam\steamapps\common\Factorio\bin\x64\factorio.exe'))
 a=p.parse_args()
 out=a.output_root/('full-'+a.case if a.full else a.case)
 mod=out/'mods/tech-priests'
 mod.mkdir(parents=True,exist_ok=True)
 source=ROOT/'tech-priests_src'
 if a.full:
  for path in source.rglob('*'):
   if path.is_file():
    dest=mod/path.relative_to(source);dest.parent.mkdir(parents=True,exist_ok=True)
    if path.suffix.lower() in ('.png','.ogg','.wav'):
     if not dest.exists():
      try:os.link(path,dest)
      except PermissionError:shutil.copy2(path,dest)
    else:shutil.copy2(path,dest)
 files=['shared/character_skin_catalog.lua','shared/combat_roster_catalog.lua','prototypes/character_skins.lua','prototypes/character_skin_settings.lua',
        'scripts/core/character_visuals.lua','scripts/core/character_skin_picker.lua',
        'scripts/core/character_skin_transfer.lua','scripts/core/runtime_event_registry.lua',
        'locale/en/character-skins.cfg','THIRD-PARTY-NOTICES-GLADIUS.txt']
 for relative in files:
  dest=mod/relative;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source/relative,dest)
 for relative in ('graphics/entity/gladius-donors','graphics/icons/character-skins'):
  for path in (source/relative).rglob('*'):
   if path.is_file():
    dest=mod/path.relative_to(source);dest.parent.mkdir(parents=True,exist_ok=True)
    if not dest.exists():
     try:os.link(path,dest)
     except PermissionError:shutil.copy2(path,dest)
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
 mods=out/'mods'
 (mods/'mod-list.json').write_text(json.dumps({'mods':[{'name':'base','enabled':True},{'name':'tech-priests','enabled':True}]+
   [{'name':name,'enabled':a.full} for name in ('space-age','quality','elevated-rails','recycler')]}))
 user=out/'user-data';user.mkdir(exist_ok=True)
 config=out/'config.ini'
 config.write_text('[path]\nread-data='+str(a.factorio.parents[2]/'data').replace('\\','/')+'\nwrite-data='+str(user.resolve()).replace('\\','/')+'\n[other]\ncheck-updates=false\n')
 save=out/'test.zip'
 common=[str(a.factorio),'--config',str(config.resolve()),'--mod-directory',str(mods.resolve())]
 for label,arguments in [('create',['--create',str(save.resolve())]),('native-player',['--test-save',str(save.resolve()),'--test-ticks','180'])]:
  log=out/(label+'.log')
  with log.open('w') as handle:
   result=subprocess.run(common+arguments,stdout=handle,stderr=subprocess.STDOUT,timeout=180)
  print(label,result.returncode,str(log),flush=True)
  if result.returncode or 'isolated handler failure' in log.read_text(errors='replace'):
   print(log.read_text(errors='replace')[-6500:]);return 1
 text=(out/'native-player.log').read_text(errors='replace')
 if '[TP-SKINS-TEST] PASS ' not in text or 'isolated handler failure' in text:
  print(text[-8000:]);return 1
 print('PASS isolated native character-skin case='+a.case)
 if a.headless_only:return 0
 saved=user/'saves/_autosave-character-skins.zip'
 # --test-save deliberately suppresses autosaves and graphical screenshots.
 # A separate hidden native client produces both from the same fixture.
 saved.unlink(missing_ok=True)
 screenshot=user/'script-output/character-skins/native-picker.png'
 screenshot.unlink(missing_ok=True)
 fixture=mod/'fixture.lua'
 fixture.write_text(fixture.read_text().replace('local graphical_run=false','local graphical_run=true'))
 startup=subprocess.STARTUPINFO();startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=0
 with (out/'graphical.log').open('w') as handle:
  environment=os.environ.copy();environment['SteamAppId']='427520';environment['SteamGameId']='427520'
  process=subprocess.Popen(common+['--load-game',str(save.resolve()),'--disable-audio'],stdout=handle,stderr=subprocess.STDOUT,startupinfo=startup,env=environment)
  try:
   deadline=time.monotonic()+150
   while time.monotonic()<deadline and process.poll() is None:
    if 'isolated handler failure' in (out/'graphical.log').read_text(errors='replace'):break
    if saved.exists() and screenshot.exists():
     time.sleep(2);break
    time.sleep(.5)
  finally:
   if process.poll() is None:process.terminate();process.wait(timeout=15)
 graphical=(out/'graphical.log').read_text(errors='replace')
 if not saved.exists() or not screenshot.exists() or 'isolated handler failure' in graphical:
  print(graphical[-8000:]);return 1
 print('PASS native graphical render and autosave')
 with (out/'reload.log').open('w') as handle:
  result=subprocess.run(common+['--test-save',str(saved.resolve()),'--test-ticks','60'],stdout=handle,stderr=subprocess.STDOUT,timeout=180)
 reload=(out/'reload.log').read_text(errors='replace')
 if result.returncode or 'isolated handler failure' in reload or '[TP-SKINS-TEST] RELOAD_PASS ' not in reload:
  print(reload[-6500:]);return 1
 print('PASS separate-process native save/reload')
 return 0

if __name__=='__main__':raise SystemExit(main())
