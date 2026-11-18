"""Read-only source/live reconciliation using verified installation receipts.

Differences between source and the preserved installed colony/rail overlay are
reported separately from unexpected changes to the installed files themselves.
No live files, receipts, Git refs, or runtime state are modified.
"""
from pathlib import Path
import argparse, hashlib, json, subprocess
ROOT=Path(__file__).resolve().parents[1]
EVIDENCE=ROOT/'tests/scenarios/combat-roster/evidence'
def hashes(folder):
 return {str(p.relative_to(folder)).replace('\\','/'):hashlib.sha256(p.read_bytes()).hexdigest()
         for p in folder.rglob('*') if p.is_file()}
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--json',action='store_true');args=parser.parse_args()
 baseline=EVIDENCE/'live-installation/installation.json'
 receipt=json.loads(baseline.read_text());live=Path(receipt['live_root'])
 expected=dict(receipt['installed_sha256']);receipts=[str(baseline.relative_to(ROOT))]
 patches=[]
 for path in EVIDENCE.glob('*/patch-installation.json'):
  patch=json.loads(path.read_text())
  if patch.get('installed') and Path(patch['live_root'])==live:patches.append((patch['timestamp_utc'],path,patch))
 for _,path,patch in sorted(patches,key=lambda row:(row[0],str(row[1]))):
  for name,change in patch['changes'].items():
   assert expected.get(name)==change['before'],f'Broken installation receipt chain: {path}: {name}'
   expected[name]=change['after']
  receipts.append(str(path.relative_to(ROOT)))
 actual=hashes(live);source=hashes(ROOT/'tech-priests_src')
 report={'installed_root':str(live),'receipt_chain':receipts,
  'unexpected_changed':[name for name in expected if name in actual and actual[name]!=expected[name]],
  'unexpected_missing':[name for name in expected if name not in actual],
  'unexpected_added':[name for name in actual if name not in expected],
  'source_live_differences':[name for name in source if name in actual and source[name]!=actual[name]],
  'source_only':[name for name in source if name not in actual],
  'source_head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
  'tracked_worktree_changes':subprocess.check_output(['git','status','--short','--untracked-files=no'],cwd=ROOT,text=True).splitlines(),
  'scope':'File provenance only. Does not establish multiplayer synchronization, running-game reload, or equal source/live feature sets.'}
 report['installed_matches_receipts']=not any(report[key] for key in ['unexpected_changed','unexpected_missing','unexpected_added'])
 if args.json:print(json.dumps(report,indent=2))
 else:
  print('PASS installed receipt chain' if report['installed_matches_receipts'] else 'FAIL unexpected installed changes')
  print('Source HEAD:',report['source_head'])
  print('Source/live differing files:',len(report['source_live_differences']),'source-only files:',len(report['source_only']))
  print('Tracked worktree changes:',len(report['tracked_worktree_changes']))
  for key in ['unexpected_changed','unexpected_missing','unexpected_added']:
   if report[key]:print(key+':',', '.join(report[key]))
 if not report['installed_matches_receipts']:raise SystemExit(1)
if __name__=='__main__':main()
