#!/usr/bin/env python3
"""Validate source-provable Tech Priests recovery contracts without runtime claims."""
from __future__ import annotations
import hashlib,json,pathlib,re,sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
CORE=ROOT/'tech-priests_src/scripts/core'
P={
'emergency':CORE/'emergency_production_executor_0514.lua','order':CORE/'order_queue_0469.lua','direct':CORE/'direct_acquisition_executor_0513.lua','consecration':CORE/'consecration_executor_0515.lua','repair':CORE/'repair_executor_0516.lua','combat_repair':CORE/'combat_repair_doctrine_0517.lua','registry':CORE/'runtime_event_registry.lua','broker':CORE/'runtime_tick_broker.lua','broker_audit':CORE/'broker_registry_integrity_0725.lua','constraints':CORE/'planning_constraints_0646.lua','hardener':CORE/'hardener_installation_audit_0723.lua','proxy':CORE/'proxy_ammo_hardener_0649.lua','visual':CORE/'visual_intent_line_authority_0657.lua','arbiter':CORE/'action_state_arbiter_0488.lua','dispatcher':CORE/'single_dispatcher_0510.lua','ups':ROOT/'tools/audit_ups_hotspots_0743.py','map':ROOT/'docs/RECOVERY_AUTHORITY_MAP_CURRENT.md','recovery':ROOT/'RECOVERY_REPAIR_SEQUENCE.md','history':ROOT/'docs/DEVELOPMENT_HISTORY.md','plan':ROOT/'docs/state-of-mod-master-plan.md','testing':ROOT/'tech-priests_src/docs/CURRENT_TESTING_GOALS.md','workflow':ROOT/'.github/workflows/source-validation.yml','manifest':ROOT/'dist/release-manifest-0.1.674-rc.3.json','receipt':ROOT/'docs/releases/v0.1.674-rc.3-published.json','digest':ROOT/'dist/tech-priests_0.1.674.zip.sha256','archive':ROOT/'dist/tech-priests_0.1.674.zip'}
HARDENER_RE=re.compile(r'\{module="(scripts\.core\.[^"]+)",label="([^"]+)"\}')
RETIRED_RE=re.compile(r'\["(scripts\.core\.[^"]+)"\]="([^"]+)"')
EXPECTED_RETIRED={
'scripts.core.direct_acquisition_movement_lock_0650','scripts.core.movement_vector_enforcer_0651','scripts.core.movement_target_reconciler_0652','scripts.core.movement_intent_authority_0654','scripts.core.active_leaf_task_truth_0655','scripts.core.construction_placement_authority_0656','scripts.core.logistics_mineable_source_bridge_0657','scripts.core.repair_executor_integrity_0673','scripts.core.combat_repair_integrity_0676','scripts.core.combat_repair_terminal_cleanup_0677'}

def read(name,errors):
 path=P[name]
 if not path.is_file():errors.append(f'missing required file: {path.relative_to(ROOT)}');return''
 return path.read_text(encoding='utf-8',errors='replace')
def require(name,text,parts,errors):
 for part in parts:
  if part not in text:errors.append(f'{P[name].relative_to(ROOT)} missing contract: {part}')
def forbid(name,text,parts,errors):
 for part in parts:
  if part in text:errors.append(f'{P[name].relative_to(ROOT)} contains forbidden regression: {part}')
def json_obj(name,errors):
 try:value=json.loads(read(name,errors))
 except json.JSONDecodeError as exc:errors.append(f'{P[name].relative_to(ROOT)} invalid JSON: {exc}');return{}
 return value if isinstance(value,dict)else{}

def authority_boundary(text,errors):
 active=[m.group(1) for m in HARDENER_RE.finditer(text)];retired={m.group(1):m.group(2) for m in RETIRED_RE.finditer(text)}
 if len(active)!=45:errors.append(f'expected 45 active hardeners, found {len(active)}')
 if set(retired)!=EXPECTED_RETIRED:errors.append(f'retired authority mismatch missing={sorted(EXPECTED_RETIRED-set(retired))} unexpected={sorted(set(retired)-EXPECTED_RETIRED)}')
 if len(active)!=len(set(active)):errors.append('duplicate active hardener module')
 if set(active)&set(retired):errors.append(f'authorities both active and retired: {sorted(set(active)&set(retired))}')
 for name,reason in retired.items():
  if not reason.strip():errors.append(f'retired authority lacks reason: {name}')
 require('constraints',text,('local HARDENERS={','local RETIRED={','for _,spec in ipairs(HARDENERS)do','retired=RETIRED'),errors)

def physical_contracts(t,e):
 require('emergency',t['emergency'],('version = "0.1.674-dev"','emergency_production_custody_0514','plan_remove','rollback','phase="return-ingredients"','phase="output-held"','output-deposited','order-completion-blocked-0514','tech_priests_safe_deposit_item','function finish_order','return ok and a==true'),e)
 forbid('emergency',t['emergency'],('assembling_machine_input','o.status="complete"','q.current=nil','return ok and a~=false'),e)
 require('order',t['order'],('version="0.1.674-dev"','"queue-full"','"duplicate-merged"','target_key','function M.complete_current','function M.fail_current','function M.cancel_current','function M.transition_current','promote(p,q,why)','r.cursor'),e)
 forbid('order',t['order'],('activate(p,q,o,"submit")','activate(p,q,o,"preempt")'),e)
 require('direct',t['direct'],('version="0.1.674-dev"','direct_acquisition_custody_0513','physical-custody-acquired-0513','custody-deposited-0513','atomic_deposit','transition_current','return false,"movement-failed"','return false,"return-movement-failed"'),e)
 forbid('direct',t['direct'],('or"stone"','or "stone"','station_inventory.insert','return true,"movement-failed"','return ok and d~=false'),e)
 require('consecration',t['consecration'],('version = "0.1.674-dev"','consecration_refund_custody_0515','release_claim','clear_timers','queue_terminal','refund-storage-blocked','queue-rejected','return ok and v==true'),e)
 forbid('consecration',t['consecration'],('set_command','inv.insert({name=item.name,count=1})','return ok and v~=false'),e)
 require('repair',t['repair'],('version="0.1.674-dev"','repair_pack_custody_0516','function M.abort_pair','tech_priests_safe_deposit_item','complete_current','fail_current','return ok and v==true','abort_after_refund','function M.service_repair_bucket','sole physical repair authority'),e)
 forbid('repair',t['repair'],('script.on_nth_tick','register_service','set_command','spill_item_stack','q.current=nil','order.status=','return ok and v~=false'),e)
 require('combat_repair',t['combat_repair'],('version = "0.1.674-dev"','Dispatcher-owned tactical selector','function M.find_combat_repair_target','function M.recommend_action','function M.abort_pair','repair.abort_pair','repair.service_pair','canonical_action_0744','cluster_reservations','tactical selection separated from physical repair'),e)
 forbid('combat_repair',t['combat_repair'],('submit_or_assign_repair_task','tech_priests_request_movement_0418','script.on_nth_tick','register_service','set_command','spill_item_stack'),e)

def runtime_contracts(t,e):
 require('registry',t['registry'],('version="0.1.674-dev"','id=owner..":"..route','p=="last"or p=="final"','local function upsert','local function remove','Registry.on_event','Registry.on_nth_tick','Registry.on_init','Registry.on_configuration_changed','isolated handler failure'),e)
 forbid('registry',t['registry'],('Registry.event_routes[key] = nil','Registry.nth_tick_routes[key] = nil','error("[Tech Priests event registry] handler failure'),e)
 require('broker',t['broker'],('version = "0.1.674-dev"','function M.normalize_result','processed = 0, acted = 0, blocked = 0, waiting = 0, failed = 0','function M.installation_summary','runtime_tick_broker_0600:central-pulse','canonical-event-registry-unavailable','isolated service failure'),e)
 forbid('broker',t['broker'],('script.on_nth_tick','direct-fallback','if acted == false then'),e)
 require('broker_audit',t['broker_audit'],('central_route_id = "runtime_tick_broker_0600:central-pulse"','central_route_count','central_route_complete','route_count == 1'),e)
 require('constraints',t['constraints'],('ensure_broker("prearm")','ensure_broker("post-loader")','runtime_tick_broker_0600:central-pulse','install must return literal true','result~=true','recovery_installation_0744'),e)
 forbid('constraints',t['constraints'],('result ~= false','result~=false'),e)
 authority_boundary(t['constraints'],e)
 require('hardener',t['hardener'],('constraints.finalize_installation','previous_result==true and finalized','final_result==true'),e)
 forbid('hardener',t['hardener'],('previous_result~=false','final_result~=false'),e)
 require('arbiter',t['arbiter'],('Pure action classifier','M.classify = M.action','function M.tick_all() return 0 end','no scheduler or movement ownership'),e)
 forbid('arbiter',t['arbiter'],('tech_priests_request_movement_0418','fail_current','register_service','.on_nth_tick','pair.mode =','pair.target ='),e)
 require('dispatcher',t['dispatcher'],('canonical_action_0744','owner = "single_dispatcher_0510"','function M.service_pair','function M.service_all','name = "single_dispatcher_0510"','return M.service_all'),e)
 require('proxy',t['proxy'],('version="0.1.674-dev"','proxy_ammo_refund_custody_0649','atomic_return','return M.service_all("broker",budget)'),e)
 forbid('proxy',t['proxy'],('script.on_nth_tick','TechPriestsRuntimeEventRegistry','M.service_all("broker"); return true'),e)
 require('visual',t['visual'],('version="0.1.674-dev"','canonical_action_0744','canonical-intent-line-0657','return M.refresh_pair_links()'),e)
 forbid('visual',t['visual'],('active_leaf_task_0655','script.on_nth_tick','pair.mode=','pair.target='),e)

def governance(t,e):
 require('ups',t['ups'],('BASELINE = {','"periodic_route_count": 510','"active_frequent_route_count_le_30": 17','"risky_scan_count": 68','"rewrite_site_count": 916','--check-baseline','Clean-world profiler and high-count scenarios remain mandatory'),e)
 require('workflow',t['workflow'],('Parse every Lua source file','Audit recovery architecture','Audit development integration graph','Self-test complete recovery evidence validator','Self-test bound release authorization','Prove verified release remains blocked'),e)
 require('recovery',t['recovery'],('## Stage 0 — Establish Repository and Architecture Truth','## Stage 1 — Protect Physical State and Scheduler Truth','## Stage 2 — Repair the Shared Runtime Spine','## Stage 3 — Consolidate Behavioral Authority','## Stage 4 — Reduce Runtime Pressure and Diagnostic Self-Cost'),e)
 require('map',t['map'],('## Current Loader and Hardener Shape','## Retired Parallel Authorities','## Canonical Recovery Target','## Stage 5 — Evidence and Release Boundary'),e)
 require('testing',t['testing'],('Emergency-production transaction integrity','Order-queue truthful acceptance','Consecration lifecycle integrity','Direct-acquisition','Performance consolidation'),e)
 m=json_obj('manifest',e);r=json_obj('receipt',e)
 expected={'release':'v0.1.674-rc.3','version':'0.1.674','package':'tech-priests_0.1.674.zip','package_root':'tech-priests_0.1.674','prerelease':True,'runtime_validation_complete':False}
 for key,value in expected.items():
  if m.get(key)!=value:e.append(f'manifest {key} expected {value!r}, found {m.get(key)!r}')
 for key in ('release','source_commit','sha256'):
  if r.get(key)!=m.get(key):e.append(f'manifest/receipt mismatch for {key}')
 if m.get('sha256') not in read('digest',e):e.append('SHA256 sidecar does not match manifest')
 if P['archive'].is_file() and m.get('sha256') and hashlib.sha256(P['archive'].read_bytes()).hexdigest()!=m['sha256']:e.append('committed experimental archive digest does not match manifest')
 require('plan',t['plan'],('v0.1.674-rc.3','experimental prerelease','not a verified release candidate'),e)
 require('history',t['history'],('Experimental `0.1.674` prerelease artifacts exist',),e)

def observations():
 files=list((ROOT/'tech-priests_src').rglob('*.lua'));joined='\n'.join(p.read_text(encoding='utf-8',errors='replace') for p in files)
 return {'lua_files':len(files),'core_modules':len(list(CORE.glob('*.lua'))),'direct_script_routes':len(re.findall(r'\bscript\.on_(?:event|nth_tick|init|configuration_changed|load)\s*\(',joined)),'pair_mode_writes':len(re.findall(r'\bpair\.mode\s*=',joined)),'pair_target_writes':len(re.findall(r'\bpair\.target\s*=',joined))}

def main():
 errors=[];names=('emergency','order','direct','consecration','repair','combat_repair','registry','broker','broker_audit','constraints','hardener','proxy','visual','arbiter','dispatcher','ups','map','recovery','history','plan','testing','workflow');t={n:read(n,errors) for n in names}
 physical_contracts(t,errors);runtime_contracts(t,errors);governance(t,errors)
 print('Recovery architecture observations: '+' '.join(f'{k}={v}' for k,v in sorted(observations().items())))
 if errors:
  print('Recovery architecture audit failed:',file=sys.stderr)
  for error in errors:print('  - '+error,file=sys.stderr)
  return 1
 print('Recovery architecture source audit passed.');return 0
if __name__=='__main__':raise SystemExit(main())
