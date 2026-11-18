"""Compare native data dumps of the separated armory and original local roster."""
from pathlib import Path
import json, os, re, shutil, subprocess, sys
import argparse
HERE=Path(__file__).resolve().parents[1]
REPO=HERE
PACKAGE=HERE
EXE=Path(r'C:\Program Files (x86)\Steam\steamapps\common\Factorio\bin\x64\factorio.exe')
def copy(source,target):
 target.parent.mkdir(parents=True,exist_ok=True)
 if target.exists():target.unlink()
 if source.suffix.lower() in ('.png','.ogg','.wav'):
  try:os.link(source,target)
  except OSError:shutil.copy2(source,target)
 else:shutil.copy2(source,target)
def tree(source,target):
 for p in source.rglob('*'):
  if p.is_file():copy(p,target/p.relative_to(source))

parser=argparse.ArgumentParser()
parser.add_argument('--output-root',type=Path,default=HERE/'build/armory-equivalence-native')
parser.add_argument('--reuse',action='store_true')
arguments=parser.parse_args()
OUT=arguments.output_root
OWNERS=['gun','ammo','recipe','beam','projectile','item','item-subgroup','fuel-category','ammo-category','technology','assembling-machine']

def profile(label,original):
 root=OUT/label;mod=root/'mods/tech-priests';mod.mkdir(parents=True,exist_ok=True)
 tree(REPO/'tech-priests_src',mod)
 # These assertions are intentionally only in the test overlay, not publication.
 final=mod/'data-final-fixes.lua'
 text=final.read_text();text=text.split('-- Validation profile only:',1)[0]
 final.write_text(text)
 if original:
  copy(PACKAGE/'wip/combat-roster-local/tech-priests_src/prototypes/combat_roster.lua',mod/'prototypes/combat_roster.lua')
  p=mod/'data.lua';p.write_text(p.read_text().replace('require("prototypes.combat_armory").register()','require("prototypes.combat_roster").register()'))
 # No control code is needed for prototype equality. Preserve actual full data.
 (mod/'control.lua').write_text('')
 (root/'mods/mod-list.json').write_text(json.dumps({'mods':[{'name':n,'enabled':True} for n in ['base','space-age','quality','recycler','elevated-rails','tech-priests']]}))
 user=root/'user-data';user.mkdir(exist_ok=True)
 config=root/'config.ini'
 config.write_text('[path]\nread-data='+str(EXE.parents[2]/'data').replace('\\','/')+'\nwrite-data='+str(user.resolve()).replace('\\','/')+'\n[other]\ncheck-updates=false\n')
 command=[str(EXE),'--config',str(config.resolve()),'--mod-directory',str((root/'mods').resolve()),'--dump-data','--disable-audio']
 log=root/'create.log'
 environment=os.environ.copy();environment['SteamAppId']='427520';environment['SteamGameId']='427520'
 startup=subprocess.STARTUPINFO();startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=0
 with log.open('w') as f:r=subprocess.run(command,stdout=f,stderr=subprocess.STDOUT,timeout=180,env=environment,startupinfo=startup)
 if r.returncode:raise RuntimeError(log.read_text(errors='replace')[-8000:])
 path=user/'script-output/data-raw-dump.json'
 if not path.exists():raise RuntimeError('Native dump missing: '+str(path))
 print('Native data dump',label,path,flush=True)
 return json.loads(path.read_text())

def main():
 if '--reuse' in sys.argv:
  ready=json.loads((OUT/'ready/user-data/script-output/data-raw-dump.json').read_text())
  original=json.loads((OUT/'original-local/user-data/script-output/data-raw-dump.json').read_text())
 else:ready=profile('ready',False);original=profile('original-local',True)
 catalog=(PACKAGE/'tech-priests_src/shared/combat_roster_catalog.lua').read_text()
 weapons=set(re.findall(r'\["weapon"\]="([^"]+)"',catalog))
 ammo=set(re.findall(r'\["name"\]="([^"]+)"',catalog.split('["ammo"]=',1)[1].split('["technologies"]=',1)[0]))
 weapon_names=weapons|ammo
 assert len(weapons)==15 and len(ammo)==10
 compared=[];differences=[]
 # Compare every ready armory/factory prototype to its original local version.
 for kind in OWNERS:
  for name,p in ready.get(kind,{}).items():
   if not name.startswith('tech-priests-'):continue
   include=(kind=='gun' and name in weapons or kind=='ammo' and name in ammo or name.startswith(('tech-priests-combat-','tech-priests-field-supply')) or
    name in ('tech-priests-martian-manufactorum','tech-priests-guard-muster-hall','tech-priests-sororitas-convent'))
   # All local armory recipes and technologies, including those without combat-
   # prefix, are identified by exact gun/ammo item names and native unlocks.
   if kind=='recipe' and name in weapon_names:include=True
   if kind=='technology' and any(e.get('type')=='unlock-recipe' and e.get('recipe') in weapon_names for e in p.get('effects',[])):include=True
   if not include:continue
   q=original.get(kind,{}).get(name)
   if kind=='technology' and q:
    q=dict(q)
    q['effects']=[e for e in q.get('effects',[]) if not (e.get('type')=='unlock-recipe' and e.get('recipe','').startswith('tech-priests-combat-'))]
   if p!=q:differences.append({'type':kind,'name':name,'ready':p,'original_without_actor_unlocks':q})
   compared.append({'type':kind,'name':name})
 assert sum(p['type']=='gun' for p in compared)==15
 assert sum(p['type']=='ammo' for p in compared)==10
 assert not any(n.startswith('tech-priests-combat-') for n in ready.get('car',{}))
 assert sum(n.startswith('tech-priests-combat-') for n in original.get('car',{}))==15
 result={'passed':not differences,'native_engine':'Factorio 2.1.24','compared':compared,
  'differences':differences,'excluded':'15 actor prototypes, their entity items/recipes/reinforcement/AAI adapters and actor-only research unlocks remain unenabled WIP',
  'scope':'Native complete prototype equality for the original implemented armory values, effects, recipes, supply, factories and applicable research; canonical reviewed icons installed identically in both profiles.'}
 (OUT/'result.json').write_text(json.dumps(result,indent=2)+'\n')
 print('Armory equivalence',result['passed'],'prototypes',len(compared),'differences',len(differences),flush=True)
 if differences:raise SystemExit(1)

if __name__=='__main__':main()
