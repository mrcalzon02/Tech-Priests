#!/usr/bin/env python3
"""Validate Tech Priests recovery governance and artifact truth."""
from __future__ import annotations
import hashlib, json, pathlib, sys

R=pathlib.Path(__file__).resolve().parents[1]
P={
 'readme':R/'README.md','recovery':R/'RECOVERY_REPAIR_SEQUENCE.md','standards':R/'docs/STANDARDS_AND_PRACTICES.md',
 'history':R/'docs/DEVELOPMENT_HISTORY.md','plan':R/'docs/state-of-mod-master-plan.md',
 'source_standards':R/'tech-priests_src/docs/STANDARDS_AND_PRACTICES.md',
 'testing':R/'tech-priests_src/docs/CURRENT_TESTING_GOALS.md','continuity':R/'tech-priests_src/docs/AUTHORITY_REFACTOR_CONTINUITY.md',
 'map':R/'docs/RECOVERY_AUTHORITY_MAP_CURRENT.md','package':R/'tools/package_local.py',
 'workflow':R/'.github/workflows/source-validation.yml','info':R/'tech-priests_src/info.json',
 'manifest':R/'dist/release-manifest-0.1.674-rc.3.json','receipt':R/'docs/releases/v0.1.674-rc.3-published.json',
 'digest':R/'dist/tech-priests_0.1.674.zip.sha256','archive':R/'dist/tech-priests_0.1.674.zip'}

REQ={
 'readme':['RECOVERY_REPAIR_SEQUENCE.md','docs/STANDARDS_AND_PRACTICES.md','docs/DEVELOPMENT_HISTORY.md','docs/RECOVERY_AUTHORITY_MAP_CURRENT.md','tech-priests_src/docs/CURRENT_TESTING_GOALS.md'],
 'recovery':['**Status:** Temporary top-level recovery authority','## Recovery Freeze','## Documentation Authority Graph','## Stage 0 — Establish Repository and Architecture Truth','## Stage 1 — Protect Physical State and Scheduler Truth','## Stage 6 — Establish One Artifact and Release Doctrine'],
 'standards':['**Status:** Authoritative project governance document','**Authoritative branch:** `main`','**Packaged baseline:** `0.1.672`','## Base-State Recovery Exception','RECOVERY_REPAIR_SEQUENCE.md','## Physical Honesty','## Runtime Event and Timing Ownership','## Validation Gates','## Packaging Rules'],
 'history':['**Status:** Canonical narrative development history','**Authoritative branch:** `main`','**Packaged baseline:** `0.1.672`','No accepted Factorio runtime logs have yet been recorded','## Base-State Recovery and Unification Directive','RECOVERY_REPAIR_SEQUENCE.md'],
 'plan':['**Authoritative branch:** `main`','docs/STANDARDS_AND_PRACTICES.md','docs/DEVELOPMENT_HISTORY.md','RECOVERY_REPAIR_SEQUENCE.md','docs/RECOVERY_AUTHORITY_MAP_CURRENT.md','v0.1.674-rc.3','experimental prerelease','not a verified release candidate','No accepted Factorio runtime evidence has yet been recorded.','### Gate 1: governance and build prerequisites'],
 'source_standards':['## Base-state recovery sequence rule','../../RECOVERY_REPAIR_SEQUENCE.md','AUTHORITY_REFACTOR_CONTINUITY.md','../../docs/DEVELOPMENT_HISTORY.md'],
 'testing':['**Top-level work order:** `../../RECOVERY_REPAIR_SEQUENCE.md`','## Recovery Directive','### Active Stage 0 target','Emergency-production transaction integrity','Order-queue truthful acceptance'],
 'continuity':['../../RECOVERY_REPAIR_SEQUENCE.md','## Recovery ownership target','## Recovery migration order','Action classification must become and remain read-only.'],
 'map':['## Current Loader and Hardener Shape','## Canonical Recovery Target','## Stage 1 Transaction and Scheduler Repair','## Remaining Recovery Defect Fronts'],
 'package':['check_governance_prerequisites_0738.py','def run_governance_checker(','run_governance_checker(project_root)','Governance prerequisite checker passed.'],
 'workflow':['check_governance_prerequisites_0738.py','Audit governance prerequisites','check_recovery_architecture_0744.py','Audit recovery architecture']}
FORBID={'plan':['No `0.1.674` package has been compiled.','No `0.1.674` release package has been authorized by the current milestone.']}

def read(k,errors):
 p=P[k]
 if not p.is_file():errors.append(f'missing required file: {p.relative_to(R)}');return ''
 return p.read_text(encoding='utf-8',errors='replace')
def obj(k,errors):
 t=read(k,errors)
 try:v=json.loads(t)
 except Exception as e:errors.append(f'{P[k].relative_to(R)} invalid JSON: {e}');return {}
 if not isinstance(v,dict):errors.append(f'{P[k].relative_to(R)} must be a JSON object');return {}
 return v

def main():
 errors=[];texts={k:read(k,errors) for k in REQ}
 for k,parts in REQ.items():
  for x in parts:
   if x not in texts[k]:errors.append(f'{P[k].relative_to(R)} missing contract: {x}')
 for k,parts in FORBID.items():
  for x in parts:
   if x in texts.get(k,''):errors.append(f'{P[k].relative_to(R)} contains stale claim: {x}')
 try:info=json.loads(read('info',errors))
 except Exception as e:errors.append(f'info.json invalid: {e}');info={}
 if info.get('version')!='0.1.672':errors.append(f"protected source version must remain 0.1.672, found {info.get('version')!r}")

 m=obj('manifest',errors);r=obj('receipt',errors)
 expected={'release':'v0.1.674-rc.3','version':'0.1.674','package':'tech-priests_0.1.674.zip','package_root':'tech-priests_0.1.674','prerelease':True,'runtime_validation_complete':False}
 for k,v in expected.items():
  if m.get(k)!=v:errors.append(f'manifest {k} expected {v!r}, found {m.get(k)!r}')
 for k in ('release','source_commit','sha256'):
  if r.get(k)!=m.get(k):errors.append(f'manifest/receipt mismatch for {k}')
 if r.get('prerelease') is not True or r.get('runtime_validation_complete') is not False:errors.append('publication receipt must remain experimental and runtime-unvalidated')
 if P['archive'].is_file() and m.get('sha256'):
  actual=hashlib.sha256(P['archive'].read_bytes()).hexdigest()
  if actual!=m['sha256']:errors.append('committed RC3 archive digest does not match manifest')
 d=read('digest',errors)
 if m.get('sha256') and m['sha256'] not in d:errors.append('SHA256 sidecar does not match manifest')

 if texts['standards'].count('Authoritative project governance document')!=1:errors.append('standards authority marker must appear exactly once')
 if texts['history'].count('Canonical narrative development history')!=1:errors.append('history authority marker must appear exactly once')
 if errors:
  print('Governance prerequisite audit failed:',file=sys.stderr)
  for e in errors:print('  - '+e,file=sys.stderr)
  return 1
 print('Governance prerequisite audit passed. Protected source=0.1.672; v0.1.674-rc.3=experimental prerelease.')
 return 0
if __name__=='__main__':raise SystemExit(main())
