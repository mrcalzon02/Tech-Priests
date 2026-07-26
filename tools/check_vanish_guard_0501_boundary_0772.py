#!/usr/bin/env python3
"""Validate inert 0501, canonical 0513 target safety, and safety-only 0490."""
from __future__ import annotations
import pathlib
import sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
FILES={
 "retired":ROOT/"tech-priests_src/scripts/core/priest_vanish_guard_0501.lua",
 "direct":ROOT/"tech-priests_src/scripts/core/direct_acquisition_executor_0513.lua",
 "legacy":ROOT/"tech-priests_src/scripts/core/direct_mining_safety_0490.lua",
 "audit":ROOT/"tech-priests_src/scripts/core/task_pair_audit_0498.lua",
 "lifecycle":ROOT/"tech-priests_src/scripts/core/priest_lifecycle_authority_0499.lua",
 "recovery":ROOT/"tech-priests_src/scripts/core/priest_recovery_safety_0503.lua",
 "control":ROOT/"tech-priests_src/control.lua",
 "cleanup":ROOT/"tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua",
 "planning":ROOT/"tech-priests_src/scripts/core/planning_constraints_0646.lua",
 "workflow":ROOT/".github/workflows/source-validation.yml",
}
REQUIRED={
 "retired":('retired = true','authority = "priest_vanish_guard_0501"','direct_acquisition_executor_0513 + direct_mining_safety_0490 + priest_lifecycle_authority_0499'),
 "direct":('target_safety_integrated=true','function M.target_is_safe','function M.physical_item','physical-output-mismatch','protected-target','owned-simple-entity'),
 "legacy":('lifecycle_recovery_retired = true','periodic_authority_retired = true','legacy direct-mining safety installed without lifecycle recovery or periodic authority','M.patch_legacy_direct_gather()'),
 "control":('Historical 0501 vanish/recovery wrapper is retired',),
 "cleanup":('["tp-priest-vanish-0501"] = true','["tp-direct-mining-safety-0490"] = true'),
 "planning":('retired_authority_count=48','["scripts.core.priest_vanish_guard_0501"]'),
 "workflow":('Audit retired 0501 vanish guard','check_vanish_guard_0501_boundary_0772.py'),
}
FORBIDDEN={
 "retired":('function M.install','register_service','on_nth_tick','commands.add_command','tech_priests_request_movement_0418','respawn_pair_priest','ensure_pair_priest','pair.target'),
 "legacy":('rescue_missing_priests','R.on_nth_tick','script.on_nth_tick','commands.add_command','function M.handle_removed'),
 "audit":('patch_direct_safety_rescue','rescue_missing_priests','TechPriestsPairLinkHardening0495'),
 "lifecycle":('rescue_missing_priests','direct-safety-rescue-disabled'),
 "recovery":('TechPriestsPriestVanishGuard0501','rescue_missing_priests','patch_quarantine_modules'),
 "control":('require("scripts.core.priest_vanish_guard_0501")',),
}
def main():
 errors=[];texts={n:p.read_text(encoding='utf-8',errors='replace') for n,p in FILES.items()}
 for n,parts in REQUIRED.items():
  for part in parts:
   if part not in texts[n]:errors.append(f'{FILES[n].relative_to(ROOT)} missing contract: {part}')
 for n,parts in FORBIDDEN.items():
  for part in parts:
   if part in texts[n]:errors.append(f'{FILES[n].relative_to(ROOT)} contains forbidden regression: {part}')
 if errors:
  print('0501 boundary audit failed:',file=sys.stderr)
  for error in errors:print('  - '+error,file=sys.stderr)
  return 1
 print('0501 boundary audit passed: 0501 is inert; 0513 owns physical target truth; 0490 is lifecycle-free safety only.')
 return 0
if __name__=='__main__':raise SystemExit(main())
