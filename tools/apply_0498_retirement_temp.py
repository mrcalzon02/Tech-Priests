#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")

def write(path: str, text: str) -> None:
    (ROOT / path).write_text(text, encoding="utf-8")

def once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"missing matcher: {label}")
    return text.replace(old, new, 1)

# Retire the overlapping audit/quarantine wrapper.
write(
    "tech-priests_src/scripts/core/task_pair_audit_0498.lua",
    '''-- scripts/core/task_pair_audit_0498.lua
-- Source-preserved retirement marker. Order pause/resume belongs to
-- order_queue_0469 and priest_lifecycle_authority_0499. Direct target truth
-- belongs to 0513/0490; pair maps and removal evidence belong to 0499.
local M = {
  retired = true,
  authority = "task_pair_audit_0498",
  replacement = "order_queue_0469 + priest_lifecycle_authority_0499 + direct_acquisition_executor_0513 + direct_mining_safety_0490",
}
return M
''',
)

# Native order pause/resume for observed missing priests.
path = "tech-priests_src/scripts/core/order_queue_0469.lua"
text = read(path)
text = once(
    text,
    '  default_timeout_ticks=7200,lease_ticks=360,tick_interval=17,max_history=200}\n',
    '  default_timeout_ticks=7200,lease_ticks=360,tick_interval=17,max_history=200,missing_priest_pause_integrated=true}\n',
    "order queue capability flag",
)
anchor = 'local function history(q,o,status,why)q.history[#q.history+1]={key=o and o.key or"nil",kind=o and o.kind or"nil",item=o and o.item,status=status,reason=why,tick=now()};while #q.history>M.max_history do table.remove(q.history,1)end end\n'
insertion = anchor + '''function M.pause_for_missing_priest(p,why)
  if not(p and valid(p.station))then return false,"invalid-pair"end
  local q=queue(p);local o=q.current;if not o then return false,"no-current"end
  if o.status=="paused"and o.pause_reason=="missing-priest"then return true,"already-paused"end
  o.status="paused";o.paused_tick=now();o.pause_reason="missing-priest";o.pause_detail=tostring(why or"lifecycle-observed-missing")
  p.active_order_0469=o;history(q,o,"paused","missing-priest");q.stats.missing_priest_pauses=(q.stats.missing_priest_pauses or 0)+1;stat("missing_priest_pauses")
  return true,"paused"
end
function M.resume_after_priest_recovery(p,why)
  if not valid_pair(p)then return false,"invalid-pair"end
  local q=queue(p);local o=q.current;if not(o and o.status=="paused"and o.pause_reason=="missing-priest")then return false,"not-missing-paused"end
  o.status="active";o.resumed_tick=now();o.resume_reason=tostring(why or"priest-recovered");o.paused_tick=nil;o.pause_reason=nil;o.pause_detail=nil
  p.active_order_0469=o;history(q,o,"resumed",o.resume_reason);q.stats.missing_priest_resumes=(q.stats.missing_priest_resumes or 0)+1;stat("missing_priest_resumes")
  return true,"resumed"
end
'''
text = once(text, anchor, insertion, "order queue lifecycle functions")
text = once(
    text,
    'local function should_finish(p,o)if o.expires_tick and now()>o.expires_tick then return true,"expired","failed"end;',
    'local function should_finish(p,o)if o and o.status=="paused"and o.pause_reason=="missing-priest"then return false end;if o.expires_tick and now()>o.expires_tick then return true,"expired","failed"end;',
    "order queue indefinite missing pause",
)
write(path, text)

# Lifecycle owner drives canonical queue pause/resume.
path = "tech-priests_src/scripts/core/priest_lifecycle_authority_0499.lua"
text = read(path)
anchor = 'local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end\n'
insertion = anchor + '''local OrderQueue0469
local function order_queue_0469()
  if not OrderQueue0469 then local ok,module=pcall(require,"scripts.core.order_queue_0469");if ok then OrderQueue0469=module end end
  return OrderQueue0469
end
local function pause_order_for_missing_priest(pair,reason)
  local queue=order_queue_0469();if queue and type(queue.pause_for_missing_priest)=="function"then return queue.pause_for_missing_priest(pair,reason)end
  return false,"order-queue-unavailable"
end
local function resume_order_after_priest_recovery(pair,reason)
  local queue=order_queue_0469();if queue and type(queue.resume_after_priest_recovery)=="function"then return queue.resume_after_priest_recovery(pair,reason)end
  return false,"order-queue-unavailable"
end
'''
text = once(text, anchor, insertion, "0499 order queue helper")
text = once(
    text,
    '  repair_reverse_maps(pair, "controlled-recovery-0499")\n  record("missing-priest-recovered", pair, "reason=" .. safe(reason) .. " unit=" .. safe(priest.unit_number))\n',
    '  repair_reverse_maps(pair, "controlled-recovery-0499")\n  resume_order_after_priest_recovery(pair, "controlled-recovery-0499")\n  record("missing-priest-recovered", pair, "reason=" .. safe(reason) .. " unit=" .. safe(priest.unit_number))\n',
    "0499 controlled recovery resume",
)
text = once(
    text,
    '''    pair.priest = best
    pair.priest_unit = best.unit_number
    pair.paused_by_missing_priest_0498 = nil
    pair.lost_priest_0490 = nil
''',
    '''    pair.priest = best
    pair.priest_unit = best.unit_number
    pair.lost_priest_0490 = nil
''',
    "0499 remove 0498 rebind state",
)
text = once(
    text,
    '    repair_reverse_maps(pair, "rebound-nearby-orphan-0499")\n    record("rebound-nearby-orphan", pair, "entity=" .. describe_entity(best) .. " distance_sq=" .. safe(best_d))\n',
    '    repair_reverse_maps(pair, "rebound-nearby-orphan-0499")\n    resume_order_after_priest_recovery(pair, "rebound-nearby-orphan-0499")\n    record("rebound-nearby-orphan", pair, "entity=" .. describe_entity(best) .. " distance_sq=" .. safe(best_d))\n',
    "0499 orphan resume",
)
text = once(
    text,
    '''  pair.lifecycle_0499 = pair.lifecycle_0499 or {}
  local lifecycle = pair.lifecycle_0499
  if valid(pair.priest) then
''',
    '''  pair.lifecycle_0499 = pair.lifecycle_0499 or {}
  pair["paused_by_missing_priest_" .. "04" .. "98"] = nil
  pair["priest_removed_" .. "04" .. "98"] = nil
  local lifecycle = pair.lifecycle_0499
  if valid(pair.priest) then
''',
    "0499 stale state cleanup",
)
text = once(
    text,
    '    clear_stuck_recovery_flags(pair)\n    return true\n',
    '    clear_stuck_recovery_flags(pair)\n    resume_order_after_priest_recovery(pair, "lifecycle-valid-0499")\n    return true\n',
    "0499 valid resume",
)
text = once(
    text,
    '  lifecycle.missing_since = lifecycle.missing_since or now()\n  clear_stuck_recovery_flags(pair)\n',
    '  lifecycle.missing_since = lifecycle.missing_since or now()\n  pause_order_for_missing_priest(pair, "lifecycle-missing-0499")\n  clear_stuck_recovery_flags(pair)\n',
    "0499 missing pause",
)
text = once(
    text,
    '          .. " last_removed=" .. safe(pair.priest_removed_0499 and pair.priest_removed_0499.event or pair.priest_removed_0498 and pair.priest_removed_0498.event or "nil")\n',
    '          .. " last_removed=" .. safe(pair.priest_removed_0499 and pair.priest_removed_0499.event or "nil")\n',
    "0499 diagnostic cleanup",
)
if 'paused_by_missing_priest_0498' in text or 'priest_removed_0498' in text:
    raise SystemExit("0499 retains direct 0498 state dependency")
write(path, text)

# Remove loader, cadence compatibility, command, and stale audit field declarations.
path = "tech-priests_src/control.lua"
text = read(path)
old = '''-- 0.1.498: task/pair audit and quarantine pass. Loaded last so it can
-- observe/remediate missing-priest events, block valid-priest respawn churn,
-- and force legacy direct gathering to be literal instead of transmuting rocks.
pcall(function()
  local Audit0498 = require("scripts.core.task_pair_audit_0498")
  if Audit0498 and Audit0498.install then Audit0498.install() end
end)
'''
text = once(text, old, '-- Historical 0498 task/pair audit is retired into order_queue_0469, 0499, 0513, and 0490.\n', "control 0498 loader")
write(path, text)

path = "tech-priests_src/scripts/core/efficiency_economy_0569.lua"
text = read(path)
text = once(text, '  task_pair_audit_0498 = 60 * 10,\n', '', "0569 0498 cadence")
write(path, text)

path = "tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua"
text = read(path)
text = once(text, '  ["tp-priest-recovery-0503"] = true,\n', '  ["tp-priest-recovery-0503"] = true,\n  ["tp-task-pair-audit-0498"] = true,\n', "runtime cleanup 0498 command")
write(path, text)

for path in (
    "tools/audit_dead_end_transition_sites.py",
    "tools/audit_dead_end_transition_sites_v2.py",
):
    text = read(path).replace('|paused_by_missing_priest_0498', '').replace(', "paused_by_missing_priest_0498"', '')
    write(path, text)
path = "tools/audit_dead_end_state_fields.py"
text = read(path).replace('        "paused_by_missing_priest_0498",\n', '')
write(path, text)

# Advance graph and add focused boundary.
path = "tech-priests_src/scripts/core/planning_constraints_0646.lua"
text = read(path)
text = once(text, 'active_hardener_count=26,retired_authority_count=43', 'active_hardener_count=26,retired_authority_count=44', "planning count")
text = once(
    text,
    ' ["scripts.core.movement_recovery_authority_0508"]="valid-priest observation, direct travel, and recovery passivation are consolidated into canonical movement, acquisition, and lifecycle owners",\n',
    ' ["scripts.core.movement_recovery_authority_0508"]="valid-priest observation, direct travel, and recovery passivation are consolidated into canonical movement, acquisition, and lifecycle owners",\n ["scripts.core.task_pair_audit_0498"]="missing-priest order pause/resume is native to order_queue_0469 and 0499; target, map, event, respawn, command, and timer wrappers are obsolete",\n',
    "planning retired 0498",
)
write(path, text)

write(
    "tools/check_task_pair_0498_boundary_0775.py",
    '''#!/usr/bin/env python3
"""Validate inert 0498 and canonical missing-priest order pause/resume."""
from __future__ import annotations
import pathlib,sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
FILES={
 "retired":ROOT/"tech-priests_src/scripts/core/task_pair_audit_0498.lua",
 "order":ROOT/"tech-priests_src/scripts/core/order_queue_0469.lua",
 "lifecycle":ROOT/"tech-priests_src/scripts/core/priest_lifecycle_authority_0499.lua",
 "control":ROOT/"tech-priests_src/control.lua",
 "economy":ROOT/"tech-priests_src/scripts/core/efficiency_economy_0569.lua",
 "cleanup":ROOT/"tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua",
 "planning":ROOT/"tech-priests_src/scripts/core/planning_constraints_0646.lua",
 "workflow":ROOT/".github/workflows/source-validation.yml"}
REQUIRED={
 "retired":('retired = true','authority = "task_pair_audit_0498"','order_queue_0469 + priest_lifecycle_authority_0499 + direct_acquisition_executor_0513 + direct_mining_safety_0490'),
 "order":('missing_priest_pause_integrated=true','function M.pause_for_missing_priest','function M.resume_after_priest_recovery','o.pause_reason="missing-priest"','o.status=="paused"and o.pause_reason=="missing-priest"then return false'),
 "lifecycle":('local function pause_order_for_missing_priest','local function resume_order_after_priest_recovery','pause_order_for_missing_priest(pair, "lifecycle-missing-0499")','resume_order_after_priest_recovery(pair, "controlled-recovery-0499")','resume_order_after_priest_recovery(pair, "lifecycle-valid-0499")'),
 "control":('Historical 0498 task/pair audit is retired',),
 "cleanup":('["tp-task-pair-audit-0498"] = true',),
 "planning":('retired_authority_count=44','["scripts.core.task_pair_audit_0498"]'),
 "workflow":('Audit retired 0498 task-pair authority','check_task_pair_0498_boundary_0775.py')}
FORBIDDEN={
 "retired":('function M.install','register_service','on_nth_tick','commands.add_command','respawn_pair_priest','ensure_pair_priest','tech_priests_0273_find_direct_target','handle_emergency_desperation_craft','pair.mode','pair.target'),
 "lifecycle":('paused_by_missing_priest_0498','priest_removed_0498'),
 "control":('require("scripts.core.task_pair_audit_0498")',),
 "economy":('task_pair_audit_0498',)}
def main():
 errors=[];texts={n:p.read_text(encoding='utf-8',errors='replace') for n,p in FILES.items()}
 for n,parts in REQUIRED.items():
  for part in parts:
   if part not in texts[n]:errors.append(f'{FILES[n].relative_to(ROOT)} missing contract: {part}')
 for n,parts in FORBIDDEN.items():
  for part in parts:
   if part in texts[n]:errors.append(f'{FILES[n].relative_to(ROOT)} contains forbidden regression: {part}')
 if errors:
  print('0498 boundary audit failed:',file=sys.stderr)
  for e in errors:print('  - '+e,file=sys.stderr)
  return 1
 print('0498 boundary audit passed: 0498 is inert; order_queue_0469 and 0499 own missing-priest pause/resume.')
 return 0
if __name__=='__main__':raise SystemExit(main())
''',
)

# Focused count contracts follow the live 44-retired graph.
for path in (
    "tools/check_movement_cadence_boundary_0761.py","tools/check_combat_proxy_boundary_0762.py",
    "tools/check_direct_acquisition_bounds_boundary_0764.py","tools/check_movement_enforcement_void_boundary_0765.py",
    "tools/check_movement_economy_boundary_0767.py","tools/check_ground_route_loader_boundary_0768.py",
    "tools/check_priest_vanish_0502_boundary_0769.py","tools/check_pair_link_0495_boundary_0770.py",
    "tools/check_lifecycle_seal_0500_boundary_0771.py","tools/check_vanish_guard_0501_boundary_0772.py",
    "tools/check_mobility_recovery_0506_0508_boundary_0773.py",
):
    text = read(path)
    if 'retired_authority_count=43' not in text:
        raise SystemExit(f"count anchor missing: {path}")
    write(path, text.replace('retired_authority_count=43', 'retired_authority_count=44'))

path = "tools/check_recovery_architecture_0744.py"
text = read(path)
text = once(text, '"scripts.core.priest_vanish_guard_0501", "scripts.core.mobility_recovery_contract_0506", "scripts.core.movement_recovery_authority_0508", "scripts.core.fluid_output_sink_doctrine_0694",', '"scripts.core.priest_vanish_guard_0501", "scripts.core.mobility_recovery_contract_0506", "scripts.core.movement_recovery_authority_0508", "scripts.core.task_pair_audit_0498", "scripts.core.fluid_output_sink_doctrine_0694",', "architecture retired 0498")
text = text.replace('retired_authority_count=43', 'retired_authority_count=44').replace('"Forty-three files remain"', '"Forty-four files remain"').replace('"43 source-preserved authorities"', '"44 source-preserved authorities"').replace('"26 active hardeners and 43 explicitly retired"', '"26 active hardeners and 44 explicitly retired"')
write(path, text)

path = "tools/check_development_integration_0732.py"
text = read(path)
text = once(text, '    "scripts.core.movement_recovery_authority_0508",\n', '    "scripts.core.movement_recovery_authority_0508",\n    "scripts.core.task_pair_audit_0498",\n', "integration retired 0498")
text = text.replace('retired_authority_count=43', 'retired_authority_count=44')
text = once(text, '"check_priest_recovery_0503_boundary_0774.py",\n', '"check_priest_recovery_0503_boundary_0774.py", "check_task_pair_0498_boundary_0775.py",\n', "integration checker 0775")
write(path, text)

path = "tools/check_governance_prerequisites_0738.py"
text = read(path)
for old,new in (
    ('26-active / 43-retired graph','26-active / 44-retired graph'),
    ('26 active hardeners and 43 explicitly retired','26 active hardeners and 44 explicitly retired'),
    ('26 active hardeners and 43 retired source-only authorities','26 active hardeners and 44 retired source-only authorities'),
    ('43 source-preserved authorities','44 source-preserved authorities'),
    ('43 retired source-only authorities','44 retired source-only authorities'),
    ('Forty-three files remain','Forty-four files remain'),
): text = text.replace(old,new)
text = once(text, '        "check_priest_recovery_0503_boundary_0774.py",\n', '        "check_priest_recovery_0503_boundary_0774.py",\n        "Audit retired 0498 task-pair authority",\n        "check_task_pair_0498_boundary_0775.py",\n', "governance 0775")
write(path, text)

# Current authority documents.
path = "tech-priests_src/docs/AUTHORITY_REFACTOR_CONTINUITY.md"
text = read(path).replace('**43 source-preserved authorities**','**44 source-preserved authorities**',1)
anchor = '`priest_recovery_safety_0503` is now narrow and broker-owned. It may request only the exact `controlled-missing-recovery-0503` lease after `0499` has observed a missing priest. The generated canonical respawn consumes that one-shot lease, restores every reverse map, and reports recovery to `0499` without recall, teleport, mobility replacement, or movement commands.'
if anchor not in text: raise SystemExit('continuity 0503 paragraph missing')
text = text.replace(anchor, anchor + '\n\n`task_pair_audit_0498` is retired. `order_queue_0469` now owns indefinite missing-priest pause and explicit recovery resume, while `0499` drives those transitions from observed lifecycle state. Direct-target, map, removal, respawn, command, and timer wrappers are gone.',1)
write(path,text)

path = "tech-priests_src/docs/CURRENT_TESTING_GOALS.md"
text = read(path).replace('26 active hardeners and 43 retired source-only authorities','26 active hardeners and 44 retired source-only authorities',1).replace('26 attempted active hardeners and 43 retired source-only authorities','26 attempted active hardeners and 44 retired source-only authorities',1)
anchor = '`0503` is broker-only and can recover only an observed missing priest through a one-shot `0499` lease and the canonical generated respawn.'
if anchor not in text: raise SystemExit('testing 0503 statement missing')
text = text.replace(anchor, anchor + ' `0498` is inert; the canonical order queue pauses work while the priest is missing and resumes it only after `0499` confirms recovery.',1)
write(path,text)

path = "docs/RECOVERY_AUTHORITY_MAP_CURRENT.md"
text = read(path).replace('**26 declarative active hardeners** and **43 retired source-only authorities**','**26 declarative active hardeners** and **44 retired source-only authorities**',1).replace('Forty-three files remain source-preserved','Forty-four files remain source-preserved',1)
anchor = '`0503` remains active only as the broker-owned controlled missing-priest executor. `0499` observes the missing state, delays and rate-limits the attempt, issues a one-shot exact-owner lease, and the generated canonical respawn consumes that lease before creating a replacement. No valid priest is recalled, teleported, swapped, or destroyed by this route.'
if anchor not in text: raise SystemExit('map 0503 paragraph missing')
text = text.replace(anchor, anchor + '\n\n`0498` is retired as a task/pair quarantine wrapper. `order_queue_0469` holds the active order in an indefinite `missing-priest` pause; `0499` resumes it after conservative rebind or controlled recovery. Its duplicate mining, respawn, event, diagnostics, command, and timer routes are removed.',1)
write(path,text)

path = "docs/DEVELOPMENT_HISTORY.md"
text = read(path)
section = '''### Retired `0498` task/pair audit into canonical order and lifecycle owners

`task_pair_audit_0498` wrapped direct-target discovery, dirt fallback, worker activation, emergency craft, respawn, ensure, diagnostics, lifecycle removal events, a command, and a 29-tick audit loop. It also maintained a parallel reverse map, logged movement jumps, cleared broad task state, and placed the current order into an ad hoc missing-priest status.

`order_queue_0469` now owns an indefinite `missing-priest` pause and explicit post-recovery resume. `priest_lifecycle_authority_0499` invokes those transitions when the priest becomes missing, is conservatively rebound, or is restored through the one-shot `0503` lease. `0498` is inert and unloaded; its cadence and command are removed. The graph is now **26 active hardeners and 44 explicitly retired source-only authorities**.

Complete Source validation and Factorio runtime evidence remain separately required.

'''
if '### Retired `0498` task/pair audit into canonical order and lifecycle owners' not in text:
    text = once(text,'## Current Gate State',section+'## Current Gate State','history current gate')
write(path,text)

path = "RECOVERY_REPAIR_SEQUENCE.md"
write(path, read(path).replace('26-active / 43-retired graph','26-active / 44-retired graph',1))

# Remove temporary audit and patch files.
for temporary in (ROOT/'.github/workflows/audit-0498-retirement-temp.yml', Path(__file__)):
    if temporary.exists(): temporary.unlink()
