#!/usr/bin/env python3
"""Validate inert 0506/0508 and canonical movement/lifecycle ownership."""
from __future__ import annotations
import pathlib,sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
FILES={
 'r506':ROOT/'tech-priests_src/scripts/core/mobility_recovery_contract_0506.lua','r508':ROOT/'tech-priests_src/scripts/core/movement_recovery_authority_0508.lua',
 'control':ROOT/'tech-priests_src/control.lua','stack':ROOT/'tech-priests_src/scripts/core/action_stack_contract_0507.lua',
 'e556':ROOT/'tech-priests_src/scripts/core/efficiency_economy_0556.lua','e568':ROOT/'tech-priests_src/scripts/core/efficiency_economy_0568.lua',
 'cleanup':ROOT/'tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua','planning':ROOT/'tech-priests_src/scripts/core/planning_constraints_0646.lua',
 'workflow':ROOT/'.github/workflows/source-validation.yml'}
REQUIRED={
 'r506':('retired = true','authority = "mobility_recovery_contract_0506"','movement_controller + direct_acquisition_executor_0513 + priest_lifecycle_authority_0499 + priest_recovery_safety_0503'),
 'r508':('retired = true','authority = "movement_recovery_authority_0508"','movement_controller + direct_acquisition_executor_0513 + priest_lifecycle_authority_0499 + priest_recovery_safety_0503'),
 'control':('Historical 0506 mobility/recovery wrapper is retired','Historical 0508 movement/recovery wrapper is retired'),
 'stack':('owner = "priest_lifecycle_authority_0499 + priest_recovery_safety_0503"','owner = "movement_controller"','sole visible movement request, stop, return, cadence, and engine-command authority'),
 'cleanup':('["tp-mobility-recovery-0506"] = true','["tp-movement-recovery-0508"] = true'),
 'planning':('retired_authority_count=45','["scripts.core.mobility_recovery_contract_0506"]','["scripts.core.movement_recovery_authority_0508"]'),
 'workflow':('Audit retired 0506 and 0508 recovery wrappers','check_mobility_recovery_0506_0508_boundary_0773.py')}
FORBIDDEN={
 'r506':('function M.install','register_service','on_nth_tick','commands.add_command','tech_priests_request_movement_0418','set_command','ensure_pair_priest =','respawn_pair_priest =','pair.mode','pair.target'),
 'r508':('function M.install','register_service','on_nth_tick','commands.add_command','tech_priests_request_movement_0418','set_command','ensure_pair_priest =','respawn_pair_priest =','pair.mode','pair.target'),
 'control':('require("scripts.core.mobility_recovery_contract_0506")','require("scripts.core.movement_recovery_authority_0508")'),
 'stack':('mobility_recovery_contract_0506','0499/0500/0501/0503/0506'),
 'e556':('movement_recovery_authority_0508','service_skipped_0508'),
 'e568':('movement_recovery_authority_0508','mobility_recovery_contract_0506')}
def main():
 errors=[];texts={n:p.read_text(encoding='utf-8',errors='replace') for n,p in FILES.items()}
 for n,parts in REQUIRED.items():
  for part in parts:
   if part not in texts[n]:errors.append(f'{FILES[n].relative_to(ROOT)} missing contract: {part}')
 for n,parts in FORBIDDEN.items():
  for part in parts:
   if part in texts[n]:errors.append(f'{FILES[n].relative_to(ROOT)} contains forbidden regression: {part}')
 if errors:
  print('0506/0508 boundary audit failed:',file=sys.stderr)
  for e in errors:print('  - '+e,file=sys.stderr)
  return 1
 print('0506/0508 boundary audit passed: both wrappers are inert; movement, acquisition, and lifecycle ownership is canonical.')
 return 0
if __name__=='__main__':raise SystemExit(main())
