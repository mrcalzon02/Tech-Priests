#!/usr/bin/env python3
"""Validate canonical movement cadence and long-action lease ownership."""
from __future__ import annotations
import pathlib, sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
FILES={
 "movement":ROOT/"tech-priests_src/scripts/core/movement_controller.lua",
 "retired":ROOT/"tech-priests_src/scripts/core/movement_cadence_contract_0518.lua",
 "control":ROOT/"tech-priests_src/control.lua",
 "planning":ROOT/"tech-priests_src/scripts/core/planning_constraints_0646.lua",
 "workflow":ROOT/".github/workflows/source-validation.yml",
}
REQUIRED={
 "movement":('version = "0.1.674-dev"','M.command_refresh_ticks = 45','M.retarget_hold_ticks = 90','M.minimum_retarget_distance_sq = 1.0','M.long_action_lease_ticks = 60 * 8','M.lease_priority_delta = 60','M.cadence_integrated = true','M.broker_required = true','local LONG_ACTION_OWNERS','local function long_action_owner','lease_retargets_held','lease-retarget-held','lease_until = long_action','name = "movement_controller_service_0611"','name = "movement_controller_sample_0611"','if not (broker and type(broker.register_service) == "function") then return false end'),
 "retired":('retired=true','authority="movement_cadence_contract_0518"','replacement="scripts.core.movement_controller"','return M'),
 "control":('historical 0518 wrapper is retired and not loaded',),
 "planning":('retired_authority_count=31','["scripts.core.movement_cadence_contract_0518"]'),
 "workflow":('Audit consolidated movement cadence boundary','check_movement_cadence_boundary_0761.py'),
}
FORBIDDEN={
 "movement":('script.on_nth_tick','registry.on_nth_tick','TechPriestsRuntimeEventRegistry','movement_lease_0518','previous_request','commands.add_command("tp-movement-cadence-0518"'),
 "retired":('function M.install','register_service','on_nth_tick','commands.add_command','tech_priests_request_movement_0418 =','movement_lease_0518'),
 "control":('require("scripts.core.movement_cadence_contract_0518")',),
 "planning":('{module="scripts.core.movement_cadence_contract_0518"',),
}
def main():
 errors=[];texts={}
 for name,path in FILES.items():
  texts[name]=path.read_text(encoding='utf-8',errors='replace') if path.is_file() else ''
  if not path.is_file(): errors.append(f'missing required file: {path.relative_to(ROOT)}')
 for name,parts in REQUIRED.items():
  for part in parts:
   if part not in texts[name]: errors.append(f'{FILES[name].relative_to(ROOT)} missing contract: {part}')
 for name,parts in FORBIDDEN.items():
  for part in parts:
   if part in texts[name]: errors.append(f'{FILES[name].relative_to(ROOT)} contains forbidden regression: {part}')
 if errors:
  print('Movement cadence boundary audit failed:',file=sys.stderr)
  for e in errors: print('  - '+e,file=sys.stderr)
  return 1
 print('Movement cadence boundary audit passed: cadence and long-action leases are canonical movement-controller state; broker ownership is mandatory; 0518 is inert.')
 return 0
if __name__=='__main__': raise SystemExit(main())
