#!/usr/bin/env python3
"""Validate physical ground transit and canonical movement command budgeting."""
from __future__ import annotations
import pathlib
import sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
FILES={
 "movement":ROOT/"tech-priests_src/scripts/core/movement_controller.lua",
 "teleport":ROOT/"tech-priests_src/scripts/core/efficiency_economy_0572.lua",
 "budget":ROOT/"tech-priests_src/scripts/core/efficiency_economy_0577.lua",
 "control":ROOT/"tech-priests_src/control.lua",
 "cleanup":ROOT/"tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua",
 "planning":ROOT/"tech-priests_src/scripts/core/planning_constraints_0646.lua",
 "workflow":ROOT/".github/workflows/source-validation.yml",
}
REQUIRED={
 "movement":('M.request_budget_integrated = true','local function movement_command_budget_allowed','budget_take("path_corrections_per_tick", 1)','movement-budget-deferred-0577','movement_budget_deferred_0577'),
 "teleport":('retired = true','authority = "efficiency_economy_0572"','physical movement_controller transit','physical honesty','return M'),
 "budget":('retired = true','authority = "efficiency_economy_0577"','runtime_tick_broker + scripts.core.movement_controller','return M'),
 "control":('Historical 572 movement-economy wrapper is retired','Historical 577 movement-economy wrapper is retired'),
 "cleanup":('["tp-efficiency-economy-0572"] = true','["tp-efficiency-economy-0577"] = true'),
 "planning":('retired_authority_count=37','["scripts.core.efficiency_economy_0572"]','["scripts.core.efficiency_economy_0577"]'),
 "workflow":('Audit retired movement economy wrappers','check_movement_economy_boundary_0767.py'),
}
FORBIDDEN={
 "teleport":('function M.install','tech_priests_request_movement_0418','teleport(','commands.add_command','pair.movement_request_0418','set_command'),
 "budget":('function M.install','tech_priests_request_movement_0418','wrap_service_pair','service_pair = function','deferred_moves','on_nth_tick','commands.add_command'),
 "control":('require("scripts.core.efficiency_economy_0572")','require("scripts.core.efficiency_economy_0577")'),
}
def main():
 errors=[];texts={name:path.read_text(encoding='utf-8',errors='replace') for name,path in FILES.items()}
 for name,parts in REQUIRED.items():
  for part in parts:
   if part not in texts[name]:errors.append(f'{FILES[name].relative_to(ROOT)} missing contract: {part}')
 for name,parts in FORBIDDEN.items():
  for part in parts:
   if part in texts[name]:errors.append(f'{FILES[name].relative_to(ROOT)} contains forbidden regression: {part}')
 if errors:
  print('Movement economy boundary audit failed:',file=sys.stderr)
  for error in errors:print('  - '+error,file=sys.stderr)
  return 1
 print('Movement economy boundary audit passed: ground transit stays physical; executor budgets are broker-owned; low-priority path commands are budgeted in movement_controller.')
 return 0
if __name__=='__main__':raise SystemExit(main())
