"""Exercise the actual Tech Priests mod and its canonical event ownership."""
from pathlib import Path
import json,shutil,subprocess,argparse,hashlib,time,importlib.util,sys
ROOT=Path(__file__).resolve().parent;REPO=ROOT.parents[2]
p=argparse.ArgumentParser();p.add_argument('--packaged',type=Path);p.add_argument('--source',type=Path,default=REPO/'tech-priests_src');p.add_argument('--output',type=Path,default=REPO/'build/martian-infrastructure-native');a=p.parse_args();SOURCE=a.source.resolve();OUT=a.output.resolve()/('packaged' if a.packaged else 'source');MODS=OUT/'mods';MODS.mkdir(parents=True,exist_ok=True)
if a.packaged:shutil.copy2(a.packaged,MODS/a.packaged.name)
else:shutil.copytree(SOURCE,MODS/'tech-priests',dirs_exist_ok=True)
if a.packaged:
 import zipfile
 with zipfile.ZipFile(a.packaged) as archive: binding={name:hashlib.sha256(archive.read(name)).hexdigest() for name in sorted(archive.namelist()) if not name.endswith('/')}
else: binding={p.relative_to(MODS/'tech-priests').as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((MODS/'tech-priests').rglob('*')) if p.is_file()}
(OUT/'source-binding.json').write_text(json.dumps(binding,indent=2)+'\n')
DRIVER=MODS/'martian-main-proof_0.0.1';DRIVER.mkdir(exist_ok=True);(DRIVER/'scenarios/proof').mkdir(parents=True,exist_ok=True)
(DRIVER/'info.json').write_text(json.dumps({'name':'martian-main-proof','version':'0.0.1','title':'Tech Priests infrastructure native proof','author':'Tech Priests','factorio_version':'2.1','dependencies':['base','tech-priests']}))
def names(s):return s.replace('martian-power-','tech-priests-martian-power-').replace('martian-comms-','tech-priests-martian-comms-')
fixture=names((ROOT/'native_fixture.lua').read_text()).replace("'martian-'..family","'tech-priests-martian-'..family");balance=json.loads((ROOT/'balance.json').read_text())
def lua(v):
 if isinstance(v,str):return json.dumps(v)
 if isinstance(v,(int,float)):return str(v)
 if isinstance(v,list):return '{'+','.join(map(lua,v))+'}'
 return '{'+','.join('['+lua(k)+']='+lua(x) for k,x in v.items())+'}'
checks='''
  local balance='''+lua(balance)+'''
  local force=game.create_force('martian-unlock-proof')
  for stem,entry in pairs(balance) do
    local name='tech-priests-martian-'..stem
    local recipe=assert(force.recipes[name],name)
    assert(not recipe.enabled,'Recipe starts unlocked: '..name)
    local technology=assert(force.technologies[entry.technology],entry.technology)
    technology.researched=true
    assert(recipe.enabled,'Appropriate technology did not unlock '..name)
    local ingredients={};for _,ingredient in pairs(recipe.ingredients) do ingredients[ingredient.name]=ingredient.amount end
    for _,ingredient in ipairs(entry.ingredients) do assert(ingredients[ingredient[1]]==ingredient[2],'Wrong ingredient count '..name..' '..ingredient[1]) end
    assert(math.abs(recipe.energy-entry.seconds)<.001,'Craft time mismatch '..name)
  end
  for n,site in ipairs(storage.review.sites) do
    assert(site.pole.max_health==balance['power-'..n].health,'Pylon HP mismatch')
    assert(site.array.max_health==balance['comms-'..n].health,'Array HP mismatch')
  end
  storage.review.checks.hitpoints_recipes_unlocks=true
'''
needle="  local surface=game.surfaces[1];surface.request_to_generate_chunks"
assert needle in fixture;fixture=fixture.replace(needle,checks+'\n'+needle,1)
fixture=fixture.replace("local report={status='PASS',","local report={status='PASS',main_mod='tech-priests',main_version=script.active_mods['tech-priests'],",1)
(DRIVER/'native_fixture.lua').write_text(fixture,encoding='utf-8')
data=(ROOT/'proof-data.lua').read_text()
(DRIVER/'data.lua').write_text(data,encoding='utf-8')
(DRIVER/'control.lua').write_text("GRAPHICAL=false\nlocal test=require('native_fixture')\nscript.on_init(test.initialize)\nscript.on_load(test.loaded)\nscript.on_event(defines.events.on_tick,test.tick)\n")
(DRIVER/'scenarios/proof/control.lua').write_text('-- Production Tech Priests controller owns all infrastructure events.\n')
(MODS/'mod-list.json').write_text(json.dumps({'mods':[{'name':n,'enabled':True} for n in ['base','space-age','quality','elevated-rails','recycler','tech-priests','martian-main-proof']]}))
EXE=Path('C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/Factorio.exe');USER=OUT/'user-data';USER.mkdir(exist_ok=True)
config=OUT/'config.ini';config.write_text('[path]\nread-data='+str(EXE.parents[2]/'data')+'\nwrite-data='+str(USER)+'\n[other]\ncheck-updates=false\n[graphics]\nmax-threads=4\nfull-screen=false\n')
(OUT/'steam_appid.txt').write_text('427520');base=[str(EXE),'--config',str(config),'--mod-directory',str(MODS),'--disable-migration-window']
def run(label,args):
 with (OUT/f'{label}.log').open('w') as log:r=subprocess.run(base+args,cwd=OUT,stdout=log,stderr=subprocess.STDOUT)
 if r.returncode:raise RuntimeError((OUT/f'{label}.log').read_text(errors='replace')[-7000:])
 text=(OUT/f'{label}.log').read_text(errors='replace')
 assert not ('owner=martian_infrastructure' in text and 'isolated handler failure owner=martian_infrastructure' in text),'Main controller handler failure'
run('behavior',['--test-scenario','martian-main-proof/proof'])
result=USER/'script-output/martian-pylons/result.json';report=json.loads(result.read_text());assert report['status']=='PASS' and report['main_mod']=='tech-priests' and report['main_version'];assert report['checks']['hitpoints_recipes_unlocks'];shutil.copy2(result,OUT/'new-save-proof.json')
run('create',['--create',str(OUT/'serialized.zip')]);run('reload',['--test-save',str(OUT/'serialized.zip')])
report=json.loads(result.read_text());assert report['status']=='PASS' and report['reloaded'];shutil.copy2(result,OUT/'reload-proof.json')
print('TECH_PRIESTS_MAIN_INTEGRATION_PASS',report['main_version'],'packaged='+str(bool(a.packaged)))
