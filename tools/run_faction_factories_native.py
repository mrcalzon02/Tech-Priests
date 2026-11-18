"""Isolated full-source Factorio building placement/crafting/art/reload proof."""
from pathlib import Path
import argparse,json,os,shutil,subprocess,time

ROOT=Path(__file__).resolve().parents[1]
EXE=Path(r'C:\Program Files (x86)\Steam\steamapps\common\Factorio\bin\x64\factorio.exe')
OUT=ROOT/'build/faction-factories-native'

def main():
 global OUT
 p=argparse.ArgumentParser()
 p.add_argument('--output-root',type=Path,default=OUT)
 OUT=p.parse_args().output_root
 source=ROOT/'tech-priests_src';mod=OUT/'mods/tech-priests';mod.mkdir(parents=True,exist_ok=True)
 for path in source.rglob('*'):
  if not path.is_file():continue
  dest=mod/path.relative_to(source);dest.parent.mkdir(parents=True,exist_ok=True)
  if path.suffix.lower() in ('.png','.ogg','.wav'):
   if not dest.exists():
    try:os.link(path,dest)
    except PermissionError:shutil.copy2(path,dest)
  else:shutil.copy2(path,dest)
 fixture=ROOT/'tests/scenarios/faction-factories/fixture.lua';shutil.copy2(fixture,mod/'factory-fixture.lua')
 (mod/'control.lua').write_text((source/'control.lua').read_text(encoding='utf-8')+'\nrequire("factory-fixture")\n',encoding='utf-8')
 data='''
local factories=require("prototypes.faction_factories").definitions
for _,def in ipairs(factories) do
 data:extend{{type="recipe",name="tech-priests-factory-proof-"..def.id,
  categories={def.category},enabled=true,energy_required=.25,
  ingredients={{type="item",name="iron-plate",amount=2}},
  results={{type="item",name="iron-stick",amount=4}},hidden=true}}
 data:extend{{type="recipe",name="tech-priests-factory-animation-proof-"..def.id,
  categories={def.category},enabled=true,energy_required=8,
  ingredients={{type="item",name="iron-plate",amount=1}},
  results={{type="item",name="iron-stick",amount=1}},hidden=true}}
 data:extend{{type="recipe",name="tech-priests-factory-fluid-proof-"..def.id,
  categories={def.category},enabled=true,energy_required=.25,
  ingredients={{type="item",name="iron-plate",amount=2},{type="fluid",name="water",amount=1}},
  results={{type="item",name="iron-stick",amount=4}},hidden=true}}
end
'''
 (mod/'data-final-fixes.lua').write_text((source/'data-final-fixes.lua').read_text(encoding='utf-8')+data,encoding='utf-8')
 mods=OUT/'mods';(mods/'mod-list.json').write_text(json.dumps({'mods':[{'name':n,'enabled':True} for n in ['base','space-age','quality','recycler','elevated-rails','tech-priests']]}))
 user=OUT/'user-data';user.mkdir(exist_ok=True)
 config=OUT/'config.ini';config.write_text('[path]\nread-data='+str(EXE.parents[2]/'data').replace('\\','/')+'\nwrite-data='+str(user.resolve()).replace('\\','/')+'\n[other]\ncheck-updates=false\n')
 common=[str(EXE),'--config',str(config.resolve()),'--mod-directory',str(mods.resolve())];save=OUT/'test.zip'
 def run(label,args,marker=None):
  path=OUT/(label+'.log')
  with path.open('w') as handle:r=subprocess.run(common+args,stdout=handle,stderr=subprocess.STDOUT,timeout=180)
  text=path.read_text(errors='replace');print(label,r.returncode,flush=True)
  if r.returncode or 'isolated handler failure' in text or marker and marker not in text:
   print(text[-9000:]);raise RuntimeError(label+' failed')
 run('create',['--create',str(save.resolve())])
 run('native',['--test-save',str(save.resolve()),'--test-ticks','480'],'[TP-FACTORIES-TEST] PASS ')
 screenshot=user/'script-output/faction-factories/native-overview.png';screenshot.unlink(missing_ok=True)
 animation=user/'script-output/faction-factories/animation-proof.json';animation.unlink(missing_ok=True)
 saved=user/'saves/_autosave-faction-factories.zip';saved.unlink(missing_ok=True)
 startup=subprocess.STARTUPINFO();startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=0
 env=os.environ.copy();env['SteamAppId']='427520';env['SteamGameId']='427520'
 with (OUT/'graphical.log').open('w') as handle:
  process=subprocess.Popen(common+['--load-game',str(save.resolve()),'--disable-audio'],stdout=handle,stderr=subprocess.STDOUT,startupinfo=startup,env=env)
  try:
   deadline=time.monotonic()+150
   while process.poll() is None and time.monotonic()<deadline:
    if 'isolated handler failure' in (OUT/'graphical.log').read_text(errors='replace'):break
    if screenshot.exists() and saved.exists() and animation.exists():time.sleep(2);break
    time.sleep(.5)
  finally:
   if process.poll() is None:process.terminate();process.wait(timeout=15)
 text=(OUT/'graphical.log').read_text(errors='replace')
 if not screenshot.exists() or not saved.exists() or not animation.exists() or 'isolated handler failure' in text:
  print(text[-9000:]);raise RuntimeError('Graphical proof failed')
 print('native graphical captures PASS',flush=True)
 run('reload',['--test-save',str(saved.resolve()),'--test-ticks','60'],'[TP-FACTORIES-TEST] RELOAD_PASS ')
 print('PASS full-source faction factories: 12 directional placements; native research, power, crafting and separate-process reload')

if __name__=='__main__':main()
