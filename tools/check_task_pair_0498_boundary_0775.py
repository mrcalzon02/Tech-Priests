#!/usr/bin/env python3
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
 "lifecycle":('local function pause_order_for_missing_priest','local function resume_order_after_priest_recovery','pause_order_for_missing_priest(pair, "lifecycle-missing-0499")','resume_order_after_priest_recovery(pair, reimprint and "reimprint-recovery-0499" or "controlled-recovery-0499")','resume_order_after_priest_recovery(pair, "lifecycle-valid-0499")'),
 "control":('Historical 0498 task/pair audit is retired',),
 "cleanup":('["tp-task-pair-audit-0498"] = true',),
 "planning":('retired_authority_count=47','["scripts.core.task_pair_audit_0498"]'),
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
 print('0498 boundary audit passed: 0498 is inert; order_queue_0469 and 0499 own ordinary-missing and re-imprint pause/resume.')
 return 0
if __name__=='__main__':raise SystemExit(main())