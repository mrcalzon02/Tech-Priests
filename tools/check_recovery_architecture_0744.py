#!/usr/bin/env python3
"""Validate base-state recovery contracts provable from source.

This checker does not claim Factorio runtime, migration, save/load, behavioral,
or performance success. It validates current recovery source invariants,
documentation connections, workflow wiring, and experimental artifact truth.
"""
from __future__ import annotations
import json, pathlib, re, sys

ROOT=pathlib.Path(__file__).resolve().parents[1]
EMERGENCY=ROOT/'tech-priests_src/scripts/core/emergency_production_executor_0514.lua'
ORDER=ROOT/'tech-priests_src/scripts/core/order_queue_0469.lua'
CONSECRATION=ROOT/'tech-priests_src/scripts/core/consecration_executor_0515.lua'
RECOVERY=ROOT/'RECOVERY_REPAIR_SEQUENCE.md'
MAP=ROOT/'docs/RECOVERY_AUTHORITY_MAP_CURRENT.md'
PLAN=ROOT/'docs/state-of-mod-master-plan.md'
HISTORY=ROOT/'docs/DEVELOPMENT_HISTORY.md'
TESTING=ROOT/'tech-priests_src/docs/CURRENT_TESTING_GOALS.md'
WORKFLOW=ROOT/'.github/workflows/source-validation.yml'
MANIFEST=ROOT/'dist/release-manifest-0.1.674-rc.3.json'
RECEIPT=ROOT/'docs/releases/v0.1.674-rc.3-published.json'
DIGEST=ROOT/'dist/tech-priests_0.1.674.zip.sha256'
ARCHIVE=ROOT/'dist/tech-priests_0.1.674.zip'

def read(path,errors):
 if not path.is_file():errors.append(f'missing required recovery file: {path.relative_to(ROOT)}');return''
 return path.read_text(encoding='utf-8',errors='replace')
def require(path,text,parts,errors):
 for part in parts:
  if part not in text:errors.append(f'{path.relative_to(ROOT)}: missing recovery contract: {part}')
def body(text,name):
 marker=f'local function {name}';start=text.find(marker)
 if start<0:return''
 ends=[x for x in (text.find('\nlocal function ',start+len(marker)),text.find('\nfunction M.',start+len(marker))) if x>=0]
 return text[start:min(ends) if ends else len(text)]

def validate_stage1(emergency,order,consecration,errors):
 require(EMERGENCY,emergency,['version = "0.1.674-dev"','require_strict_fallback_recipe','strict-recipe-required','plan_remove','rollback','emergency_production_custody_0514','phase="return-ingredients"','phase="output-held"','tech_priests_safe_deposit_item','complete_current','collect_facility_output'],errors)
 collect=body(emergency,'collect_facility_output')
 if not collect:errors.append('emergency production collection function is missing')
 if 'assembling_machine_input' in collect:errors.append('emergency production still scans assembling-machine input as output')
 if 'local function finish_order' in emergency and 'if ok and done==true then return end' not in emergency:errors.append('emergency order handoff accepts pcall success without terminal acceptance')

 require(ORDER,order,['version="0.1.674-dev"','"queue-full"','"duplicate-merged"','target_key','key_for','preempt-','"target-invalid","failed"','function M.complete_current','function M.fail_current','function M.cancel_current','promote(p,q,why)','run_callback==false','return n>0,"acted="..n','r.cursor'],errors)
 if re.search(r'return\s+true\s*,\s*["\']queued["\']',order) and 'queue-full' not in order:errors.append('order queue can report queued without explicit full rejection')
 if 'activate(p,q,o,"submit")' in order or 'activate(p,q,o,"preempt")' in order:errors.append('initial order activation may invoke stored callback twice')

 require(CONSECRATION,consecration,['version = "0.1.674-dev"','consecration_refund_custody_0515','release_claim','claim_key','clear_timers','queue_terminal','movement-authority-unavailable','refund-storage-blocked','run_callback','queue-rejected','commands.remove_command,"tp-consecration-executor-0515"'],errors)
 if 'move_priest_to' in consecration or 'set_command' in consecration:errors.append('consecration restored an independent movement fallback')
 if 'inv.insert({name=item.name,count=1})' in consecration:errors.append('consecration restored an unverified raw refund insert')
 cooldown=body(consecration,'service_pair')
 if cooldown and cooldown.find('next_consecration_tick')>cooldown.find('claim(p,target'):errors.append('consecration cooldown is evaluated after target claim')
 if 'pcall(submit' not in consecration or 'accepted~=true' not in consecration:errors.append('consecration admission is not verified')

def load_json(path,errors):
 text=read(path,errors)
 try:value=json.loads(text)
 except Exception as exc:errors.append(f'{path.relative_to(ROOT)} invalid JSON: {exc}');return{}
 return value if isinstance(value,dict) else {}
def validate_artifacts(plan,history,errors):
 m=load_json(MANIFEST,errors);r=load_json(RECEIPT,errors)
 if not ARCHIVE.is_file():errors.append('committed experimental 0.1.674 archive is missing')
 digest=read(DIGEST,errors)
 for k,v in {'release':'v0.1.674-rc.3','version':'0.1.674','package':'tech-priests_0.1.674.zip','package_root':'tech-priests_0.1.674','prerelease':True,'runtime_validation_complete':False}.items():
  if m.get(k)!=v:errors.append(f'manifest {k!r} mismatch: expected {v!r}, found {m.get(k)!r}')
 for k in ('release','source_commit','sha256'):
  if r.get(k)!=m.get(k):errors.append(f'manifest/receipt mismatch for {k}')
 if r.get('runtime_validation_complete') is not False:errors.append('experimental receipt must remain runtime-unvalidated')
 if m.get('sha256') and m['sha256'] not in digest:errors.append('SHA256 sidecar does not match manifest')
 require(PLAN,plan,['v0.1.674-rc.3','experimental prerelease','runtime validation','not a verified release candidate'],errors)
 require(HISTORY,history,['Experimental `0.1.674` prerelease artifacts exist'],errors)

def observations():
 core=ROOT/'tech-priests_src/scripts/core';files=list((ROOT/'tech-priests_src').rglob('*.lua'));joined='\n'.join(p.read_text(encoding='utf-8',errors='replace') for p in files)
 return {'lua_files':len(files),'core_modules':len(list(core.glob('*.lua'))) if core.is_dir() else 0,'direct_script_routes':len(re.findall(r'\bscript\.on_(?:event|nth_tick|init|configuration_changed|load)\s*\(',joined)),'pair_mode_writes':len(re.findall(r'\bpair\.mode\s*=',joined)),'pair_target_writes':len(re.findall(r'\bpair\.target\s*=',joined)),'movement_requests':joined.count('tech_priests_request_movement_0418')}

def main():
 errors=[]
 emergency=read(EMERGENCY,errors);order=read(ORDER,errors);consecration=read(CONSECRATION,errors);recovery=read(RECOVERY,errors);map_text=read(MAP,errors);plan=read(PLAN,errors);history=read(HISTORY,errors);testing=read(TESTING,errors);workflow=read(WORKFLOW,errors)
 validate_stage1(emergency,order,consecration,errors)
 require(RECOVERY,recovery,['## Stage 0 — Establish Repository and Architecture Truth','## Stage 1 — Protect Physical State and Scheduler Truth'],errors)
 require(MAP,map_text,['## Current Loader and Hardener Shape','## Stage 1 Transaction and Scheduler Repair','### Consecration lifecycle','## Remaining Recovery Defect Fronts'],errors)
 require(TESTING,testing,['Emergency-production transaction integrity','Order-queue truthful acceptance','Consecration lifecycle integrity'],errors)
 require(WORKFLOW,workflow,['check_recovery_architecture_0744.py','Audit recovery architecture'],errors)
 validate_artifacts(plan,history,errors)
 obs=observations();print('Recovery architecture observations: '+' '.join(f'{k}={v}' for k,v in sorted(obs.items())))
 if errors:
  print('Recovery architecture audit failed:',file=sys.stderr)
  for e in errors:print('  - '+e,file=sys.stderr)
  return 1
 print('Recovery architecture source audit passed.')
 return 0
if __name__=='__main__':raise SystemExit(main())
