"""Archive actual passed native combat observations with tested source hashes."""
import argparse, hashlib, json, shutil, subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--scenario',choices=['battle','deployment','negative','progression','duels'],default='battle')
 parser.add_argument('--run-id',default='');parser.add_argument('--persistence',action='store_true')
 parser.add_argument('--evidence-name',default='');parser.add_argument('--visuals',action='store_true');a=parser.parse_args()
 run=ROOT/'build/combat-roster'/('native' if a.scenario=='battle' else a.scenario)
 if a.run_id:
  assert a.run_id.replace('-','').isalnum();run=run/a.run_id
 proof=run/'user-data/script-output/combat-roster'/f'{a.scenario}.json'
 result=json.loads(proof.read_text());assert result['passed']
 if a.scenario=='negative':assert result['cases']==10 and all(x['original']==x['returned'] for x in result['results'])
 elif a.scenario=='progression':assert result['units']==15
 else:assert result['units']==result['types']*result['forces']
 logs=[run/'create.log',run/'behavior.log']
 if a.visuals:
  logs.append(run/'visual.log')
  assert 'VISUAL_PASS' in (run/'visual.log').read_text(errors='replace')
 if a.persistence:
  logs += [run/name for name in ['custody-save.log','custody-resume.log','reload.log']]
  assert 'CUSTODY_RELOAD_PASS' in (run/'custody-resume.log').read_text(errors='replace')
  assert 'RELOAD_PASS' in (run/'reload.log').read_text(errors='replace')
 for log in logs: assert 'isolated handler failure' not in log.read_text(errors='replace')
 name=a.evidence_name or a.scenario;assert name.replace('-','').isalnum()
 out=ROOT/'tests/scenarios/combat-roster/evidence'/name;out.mkdir(parents=True,exist_ok=True)
 (out/f'{a.scenario}.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
 for log in logs:
  (out/log.name).write_text('\n'.join(x.rstrip() for x in log.read_text(errors='replace').splitlines())+'\n',encoding='utf-8')
 snapshot=run/'mods/tech-priests'
 source={str(p.relative_to(snapshot)).replace('\\','/'):sha(p) for p in snapshot.rglob('*')
         if p.is_file() and p.suffix in ('.lua','.cfg','.json')}
 report={'passed':True,'scope':a.scenario,'engine':'Factorio 2.1.24 build 87808',
         'dependencies':result.get('mods',{'aai-programmable-vehicles':'0.9.2','aai-signals':'0.8.0','informatron':'0.5.0'}),
         'baseline_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
         'tested_snapshot_raw_text_sha256':source,'raw_log_sha256':{p.name:sha(p) for p in logs},
         'source_boundary':'Hashes identify the actual isolated loaded snapshot, including harness; baseline is not a claim of a clean tested checkout.',
         'excluded_claims':['publication','live-profile installation','owner art acceptance','multiplayer','UPS/performance acceptance']}
 report['custody_and_final_reload_passed']=a.persistence
 if a.persistence or a.visuals:
  control=(snapshot/'control.lua').read_text(encoding='utf-8')
  suffix='\nTP_COMBAT_PERSISTENCE=true\n' if a.persistence else '\nTP_COMBAT_VISUALS=true\n'
  assert control.endswith(suffix)
  report['headless_control_utf8_sha256']=hashlib.sha256(control.removesuffix(suffix).encode('utf-8')).hexdigest()
  report['harness_phase_change']=f'Only {suffix.strip()} was appended after the headless pass to enable graphical test assertions. Snapshot hashes identify that graphical/reload phase.'
 report['tested_donor_sprite_sha256']={str(p.relative_to(snapshot)).replace('\\','/'):sha(p)
  for p in (snapshot/'graphics/entity/gladius-donors').rglob('*.png')}
 (out/'validation.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
 screenshot=run/'user-data/script-output/combat-roster/native-muster.png'
 if screenshot.exists():shutil.copy2(screenshot,out/'native-muster.png')
 if a.visuals:
  visual=run/'user-data/script-output/combat-roster/visual';assert len(list(visual.glob('*.png')))==60
  shutil.copytree(visual,out/'visual',dirs_exist_ok=True)
 print(f'Preserved {a.scenario}: {result.get("units",result.get("cases"))} native observations.')
if __name__=='__main__': main()
