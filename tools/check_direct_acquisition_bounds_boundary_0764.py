#!/usr/bin/env python3
"""Validate native direct-acquisition bounds and inert 0511 retirement."""
from __future__ import annotations
import pathlib
import sys

ROOT=pathlib.Path(__file__).resolve().parents[1]
FILES={
 "direct":ROOT/"tech-priests_src/scripts/core/direct_acquisition_executor_0513.lua",
 "cleanup":ROOT/"tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua",
 "retired":ROOT/"tech-priests_src/scripts/core/movement_bounds_contract_0511.lua",
 "control":ROOT/"tech-priests_src/control.lua",
 "planning":ROOT/"tech-priests_src/scripts/core/planning_constraints_0646.lua",
 "workflow":ROOT/".github/workflows/source-validation.yml",
}
REQUIRED={
 "direct":('bounds_integrated=true','function M.direct_radius','function M.hard_leash','function M.target_within_bounds','local function recover_overleash','direct-acquisition-overleash-return-0513','_G.tech_priests_direct_target_within_bounds_0513'),
 "cleanup":('legacy_direct_route_cleanup_integrated = true','["tp-movement-bounds-0511"] = true','function M.remove_legacy_direct_route','control_legacy_part_016.lua','registry.nth_tick_routes["61"] = kept'),
 "retired":('retired=true','authority="movement_bounds_contract_0511"','replacement="direct_acquisition_executor_0513 + runtime_command_cleanup_0720"','return M'),
 "control":('Historical 0511 bounds wrapper is retired',),
 "planning":('retired_authority_count=43','["scripts.core.movement_bounds_contract_0511"]'),
 "workflow":('Audit canonical direct acquisition bounds','check_direct_acquisition_bounds_boundary_0764.py'),
}
FORBIDDEN={
 "direct":('TechPriestsMovementBounds0511','bounds-authority-unavailable'),
 "retired":('function M.install','register_service','on_nth_tick','commands.add_command','tech_priests_request_movement_0418','pair.mode','pair.target'),
 "control":('require("scripts.core.movement_bounds_contract_0511")',),
}
def main():
 errors=[];texts={name:path.read_text(encoding='utf-8',errors='replace')for name,path in FILES.items()}
 for name,parts in REQUIRED.items():
  for part in parts:
   if part not in texts[name]:errors.append(f'{FILES[name].relative_to(ROOT)} missing contract: {part}')
 for name,parts in FORBIDDEN.items():
  for part in parts:
   if part in texts[name]:errors.append(f'{FILES[name].relative_to(ROOT)} contains forbidden regression: {part}')
 if errors:
  print('Direct acquisition bounds audit failed:',file=sys.stderr)
  for error in errors:print('  - '+error,file=sys.stderr)
  return 1
 print('Direct acquisition bounds audit passed: 0513 owns bounds/overleash recovery; 0720 removes the obsolete route/command; 0511 is inert.')
 return 0
if __name__=='__main__':raise SystemExit(main())
