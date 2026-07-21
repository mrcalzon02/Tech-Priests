#!/usr/bin/env python3
"""Validate inert 0502 retirement and broker-only passive 0509 maintenance."""
from __future__ import annotations
import pathlib
import sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
FILES={
 "retired":ROOT/"tech-priests_src/scripts/core/priest_vanish_guard_0502.lua",
 "cleanup":ROOT/"tech-priests_src/scripts/core/behavior_stack_cleanup_0509.lua",
 "control":ROOT/"tech-priests_src/control.lua",
 "runtime_cleanup":ROOT/"tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua",
 "planning":ROOT/"tech-priests_src/scripts/core/planning_constraints_0646.lua",
 "workflow":ROOT/".github/workflows/source-validation.yml",
}
REQUIRED={
 "retired":('retired = true','authority = "priest_vanish_guard_0502"','direct_acquisition_executor_0513 + movement_controller + canonical lifecycle authority','return M'),
 "cleanup":('version = "0.1.674-dev"','broker_required = true','direct_acquisition_retired = true','movement_ownership_retired = true','local function repair_reverse_maps','local function wrap_order_refresh','local function wrap_cascade','function M.service','name = "behavior_stack_cleanup_0509"','broker.register_service'),
 "control":('Historical 0502 station-side acquisition/movement quarantine is retired',),
 "runtime_cleanup":('["tp-vanish-guard-0502"] = true',),
 "planning":('retired_authority_count=39','["scripts.core.priest_vanish_guard_0502"]'),
 "workflow":('Audit retired 0502 vanish quarantine','check_priest_vanish_0502_boundary_0769.py'),
}
FORBIDDEN={
 "retired":('function M.install','tech_priests_request_movement_0418','set_command','on_nth_tick','commands.add_command','station_direct_acquisition_0502','pair.mode','pair.target'),
 "cleanup":('0502','station_direct_acquisition_0502','tech_priests_request_movement_0418','acquisition_executor','hold_or_route_direct','wrap_direct_globals','wrap_acquisition_executor','set_command','TechPriestsRuntimeEventRegistry','registry.on_nth_tick','script.on_nth_tick'),
 "control":('require("scripts.core.priest_vanish_guard_0502")',),
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
  print('0502 lifecycle boundary audit failed:',file=sys.stderr)
  for error in errors:print('  - '+error,file=sys.stderr)
  return 1
 print('0502 lifecycle boundary audit passed: station-side acquisition/movement quarantine is inert; 0509 is passive and broker-only.')
 return 0
if __name__=='__main__':raise SystemExit(main())
