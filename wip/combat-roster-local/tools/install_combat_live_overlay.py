"""Install only a previously prepared and natively validated combat overlay.

Checks every live and candidate file against the reviewed preparation. A full
backup precedes any live write; concurrent edits cause refusal, never overwrite.
"""
from pathlib import Path
import argparse, datetime, hashlib, json, shutil
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/combat-roster/live-overlay'
def hashes(folder):
 return {str(p.relative_to(folder)).replace('\\','/'):hashlib.sha256(p.read_bytes()).hexdigest()
         for p in folder.rglob('*') if p.is_file()}
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--apply',action='store_true');args=parser.parse_args()
 report=json.loads((OUT/'preparation.json').read_text())
 live=Path(report['installed_root']);stage=Path(report['candidate_root'])
 assert not report['unresolved_conflicts']
 assert live.name=='tech-priests_0.1.681' and live.parent.name=='mods'
 assert stage.resolve()==(OUT/'tech-priests_0.1.681').resolve()
 assert hashes(live)==report['installed_before_sha256'],'Live profile changed; reconcile and validate again.'
 assert hashes(stage)==report['candidate_sha256'],'Candidate changed; validate again.'
 # These are the actual full installed-pack runs, including current physical
 # supply selection and the merged installed rail/colony implementation.
 for scenario,run in [('deployment','merged-quality-final'),('deployment','merged-ordinary-final')]:
  base=ROOT/'build/combat-roster'/scenario/run
  result=json.loads((base/'user-data/script-output/combat-roster/deployment.json').read_text())
  assert result['passed'] and result['units']==30
  loaded=base/'mods/tech-priests'
  for name in report['candidate_sha256']:
   if name in ['control.lua','data-final-fixes.lua']:continue # Only harness additions differ.
   assert hashlib.sha256((loaded/name).read_bytes()).hexdigest()==report['candidate_sha256'][name],name
  assert (loaded/'control.lua').read_text(encoding='utf-8').startswith((stage/'control.lua').read_text(encoding='utf-8'))
  assert (loaded/'data-final-fixes.lua').read_text(encoding='utf-8').startswith((stage/'data-final-fixes.lua').read_text(encoding='utf-8'))
  assert 'isolated handler failure' not in (base/'behavior.log').read_text(errors='replace')
 for name in ['custody-save','custody-resume','reload']:
  log=(ROOT/'build/combat-roster/deployment/merged-quality-final'/(name+'.log')).read_text(errors='replace')
  assert 'isolated handler failure' not in log
 assert 'RELOAD_PASS' in log
 if not args.apply:
  print('Verified candidate and unchanged live profile; --apply performs a full backup and installation.');return
 stamp=datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
 backup=OUT/('installed-before-combat-'+stamp)
 assert not backup.exists()
 shutil.copytree(live,backup)
 assert hashes(backup)==report['installed_before_sha256'],'Backup verification failed.'
 # Repeat immediately before mutation after the potentially long backup.
 assert hashes(live)==report['installed_before_sha256'],'Live changed during backup; stopped safely.'
 shutil.copytree(stage,live,dirs_exist_ok=True)
 assert hashes(live)==report['candidate_sha256'],'Installed verification failed; restore the full backup.'
 receipt={'installed':True,'timestamp_local':stamp,'live_root':str(live),'backup_root':str(backup),
  'installed_sha256':report['candidate_sha256'],'preserved_three_way_merges':report['three_way_merges'],
  'validation_runs':['merged-quality-final','merged-ordinary-final','merged-live-research-fixed'],
  'restart_required':True,'publication':False}
 target=ROOT/'tests/scenarios/combat-roster/evidence/live-installation'
 target.mkdir(parents=True,exist_ok=True)
 (target/'installation.json').write_text(json.dumps(receipt,indent=2)+'\n')
 print(json.dumps({'installed':str(live),'verified':True,'backup':str(backup),'restart_required':True},indent=2))
if __name__=='__main__':main()
