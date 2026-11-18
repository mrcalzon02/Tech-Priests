"""Prepare a reviewable combat update while retaining installed colony/rail work.

Never writes the live profile. Three-way merges fail closed into staging; the
candidate must pass native tests before any separately authorised installation.
"""
from pathlib import Path
import hashlib,json,os,re,shutil,subprocess
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'tech-priests_src'
LIVE=Path(os.environ['APPDATA'])/'Factorio/mods/tech-priests_0.1.681'
OUT=ROOT/'build/combat-roster/live-overlay'
STAGE=OUT/'tech-priests_0.1.681'
BASE='d27d1ba'
CORE=['action_state_arbiter_0488','character_visuals','character_skin_picker','character_skin_transfer',
 'combat_item_custody','combat_muster_gui','combat_roster_bridge','combat_roster_orders',
 'construction_planner','efficiency_economy_0569','efficiency_economy_0582',
 'item_family_logistics_0702','priest_recovery_safety_0503','proxy_ammo_hardener_0649','single_dispatcher_0510']
FILES=['scripts/core/'+name+'.lua' for name in CORE]+[
 'shared/character_skin_catalog.lua','shared/combat_roster_catalog.lua',
 'prototypes/character_skins.lua','prototypes/character_skin_settings.lua',
 'prototypes/faction_factories.lua','prototypes/combat_roster.lua',
 'locale/en/character-skins.cfg','locale/en/combat-roster.cfg','locale/en/faction-factories.cfg',
 'THIRD-PARTY-NOTICES-GLADIUS.txt']
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def resolve_known_constructor_handoffs(text):
 pattern=r'^<<<<<<<[^\n]*\n(.*?)^\|\|\|\|\|\|\|[^\n]*\n(.*?)^=======\n(.*?)^>>>>>>>[^\n]*\n'
 resolved=[]
 def combine(match):
  ours,base,theirs=match.groups()
  if not base.strip() and 'local quality' in ours and 'original_remote_drill_supply_0836(pair,item)' in theirs:
   resolved.append('Keep exact remote-drill source first, then combat quality selection')
   return theirs+ours
  debit='  local removed=remove_item(task.source_inv,task.item_name,1)\n'
  if base==debit and 'CombatCustody.pickup' in ours and 'stage_original_wagon_drill_0836(pair,task)' in theirs and theirs.endswith(debit):
   resolved.append('Stage original remote drill before original wagon debit; use native combat-stack debit only for combat items')
   return theirs.removesuffix(debit)+ours
  return match.group(0)
 return re.sub(pattern,combine,text,flags=re.MULTILINE|re.DOTALL),resolved
def append_once(name,line):
 path=STAGE/name;text=path.read_text(encoding='utf-8-sig')
 if line not in text:path.write_text(text+'\n'+line+'\n',encoding='utf-8')
def main():
 assert json.loads((LIVE/'info.json').read_text())['name']=='tech-priests'
 OUT.mkdir(parents=True,exist_ok=True)
 installed={str(p.relative_to(LIVE)).replace('\\','/'):sha(p) for p in LIVE.rglob('*') if p.is_file()}
 shutil.copytree(LIVE,STAGE,dirs_exist_ok=True)
 conflicts=[];merges={}
 merge_dir=OUT/'merge-inputs';merge_dir.mkdir(exist_ok=True)
 for name in FILES:
  source=SOURCE/name;assert source.is_file(),name
  dest=STAGE/name;dest.parent.mkdir(parents=True,exist_ok=True)
  baseline=subprocess.run(['git','show',BASE+':tech-priests_src/'+name],cwd=ROOT,capture_output=True,text=True)
  if (LIVE/name).is_file() and baseline.returncode==0:
   ours=merge_dir/'source.lua';base=merge_dir/'base.lua';theirs=merge_dir/'installed.lua'
   ours.write_text(source.read_text(encoding='utf-8-sig'),encoding='utf-8')
   base.write_text(baseline.stdout,encoding='utf-8');theirs.write_text(dest.read_text(encoding='utf-8-sig'),encoding='utf-8')
   merged=subprocess.run(['git','merge-file','-p','--diff3',str(ours),str(base),str(theirs)],capture_output=True,text=True)
   assert 0<=merged.returncode<128,(merged.returncode,merged.stderr,name)
   text=merged.stdout;resolved=[]
   if name=='scripts/core/construction_planner.lua':text,resolved=resolve_known_constructor_handoffs(text)
   unresolved='<<<<<<<' in text or '>>>>>>>' in text
   dest.write_text(text,encoding='utf-8')
   if unresolved:conflicts.append(name)
   merges[name]={'source_sha256':sha(source),'installed_sha256':installed[name],'merged_sha256':sha(dest),
    'conflict':unresolved,'reviewed_combinations':resolved}
  else:shutil.copy2(source,dest)
 for relative in ['graphics/entity/faction-factories','graphics/entity/gladius-donors','graphics/icons/character-skins']:
  shutil.copytree(SOURCE/relative,STAGE/relative,dirs_exist_ok=True)
 for line in ['require("prototypes.faction_factories").register()','require("prototypes.combat_roster").register()']:append_once('data.lua',line)
 append_once('settings.lua','require("prototypes.character_skin_settings")')
 settings=(STAGE/'settings.lua').read_text(encoding='utf-8')
 if 'name="tech-priests-combat-allow-"' not in settings:
  source=(SOURCE/'settings.lua').read_text(encoding='utf-8')
  start=source.index('for _,faction in ipairs({"mechanicus","astra-militarum","sororitas"}) do')
  end=source.index('\nend',start)+len('\nend')
  (STAGE/'settings.lua').write_text(settings+'\n'+source[start:end]+'\n',encoding='utf-8')
 for name in ['character_skin_picker','combat_roster_bridge','combat_roster_orders','combat_muster_gui']:
  append_once('control.lua',f'assert(require("scripts.core.{name}").install())')
 final=(STAGE/'data-final-fixes.lua').read_text(encoding='utf-8')
 if 'local detritus_furnace_outputs={}' not in final:
  source=(SOURCE/'data-final-fixes.lua').read_text(encoding='utf-8')
  start=source.index('-- Even a probability-zero product reserves an engine output slot.')
  end=source.index('-- Mechanical Detritus furnace reclamation.',start)
  (STAGE/'data-final-fixes.lua').write_text(final+'\n'+source[start:end],encoding='utf-8')
 for line in ['require("prototypes.character_skins").register()','require("prototypes.combat_roster").finalize()']:append_once('data-final-fixes.lua',line)
 info=json.loads((STAGE/'info.json').read_text())
 info['dependencies']=[d for d in info['dependencies'] if 'aai-programmable-vehicles' not in d]+['aai-programmable-vehicles >= 0.9.2']
 (STAGE/'info.json').write_text(json.dumps(info,indent=2)+'\n',encoding='utf-8')
 report={'baseline_commit':BASE,'installed_root':str(LIVE),'candidate_root':str(STAGE),
  'installed_before_sha256':installed,'three_way_merges':merges,'unresolved_conflicts':conflicts,
  'candidate_sha256':{str(p.relative_to(STAGE)).replace('\\','/'):sha(p) for p in STAGE.rglob('*') if p.is_file()},
  'preserved':'Existing installed colony generation, research announcements, railway/custody work, settings and other runtime files remain in the candidate. No live writes.'}
 (OUT/'preparation.json').write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps({'candidate':str(STAGE),'conflicts':conflicts},indent=2))
 if conflicts:raise SystemExit(1)
if __name__=='__main__':main()
