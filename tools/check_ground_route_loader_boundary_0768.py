#!/usr/bin/env python3
"""Validate native visible ground routing, retired 0632/0633, and explicit child loaders."""
from __future__ import annotations
import pathlib
import sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
FILES={
 "movement":ROOT/"tech-priests_src/scripts/core/movement_controller.lua",
 "pulse":ROOT/"tech-priests_src/scripts/core/direct_acquisition_pulse_0631.lua",
 "recall":ROOT/"tech-priests_src/scripts/core/direct_acquisition_recall_guard_0632.lua",
 "route":ROOT/"tech-priests_src/scripts/core/ground_route_authority_0633.lua",
 "economy":ROOT/"tech-priests_src/scripts/core/efficiency_economy_0575.lua",
 "control":ROOT/"tech-priests_src/control.lua",
 "cleanup":ROOT/"tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua",
 "planning":ROOT/"tech-priests_src/scripts/core/planning_constraints_0646.lua",
 "workflow":ROOT/".github/workflows/source-validation.yml",
}
REQUIRED={
 "movement":('M.ground_route_chunking_integrated = true','local function plan_visible_ground_segment','ground-route-waypoint-0633','ground_route_final_destination = opts.ground_route_final_destination','function M.cleanup_retired_pair_state','retired_state_cleared_0632_0633'),
 "pulse":('M.version = "0.1.674-dev"','M.broker_required = true','M.recall_guard_retired = true','name="direct_acquisition_pulse_0631"','broker.register_service'),
 "recall":('retired = true','authority = "direct_acquisition_recall_guard_0632"','return M'),
 "route":('retired = true','authority = "ground_route_authority_0633"','explicit child loaders','return M'),
 "control":('Explicit 0634-0643 repair loaders formerly hidden behind retired 0633','require("scripts.core.station_area_change_invalidator_0634")','require("scripts.core.gui_nested_frame_repair_0635")','require("scripts.core.inventory_deposit_safety_0638")','require("scripts.core.station_supply_satisfaction_0639")','require("scripts.core.infrastructure_first_governor_0640")','require("scripts.core.emergency_facility_placement_bridge_0643")','require("scripts.core.behavior_tree_monitor_0642")','require("scripts.core.bootstrap_resource_governor_0637")'),
 "cleanup":('["tp-direct-recall-0632"] = true','["tp-ground-route-0633"] = true','["tp-direct-pulse-0631"] = true'),
 "planning":('retired_authority_count=40','["scripts.core.direct_acquisition_recall_guard_0632"]','["scripts.core.ground_route_authority_0633"]'),
 "workflow":('Audit retired ground route and explicit child loaders','check_ground_route_loader_boundary_0768.py'),
}
FORBIDDEN={
 "pulse":('install_recall_guard','direct_acquisition_recall_guard_0632','commands.add_command','TechPriestsRuntimeEventRegistry','on_nth_tick','script.on_nth_tick'),
 "recall":('function M.install','wrap_direct_executor','service_pair = function','commands.add_command','movement_rejected_0566','pair.mode'),
 "route":('function M.install','tech_priests_request_movement_0418','set_command','commands.add_command','ground_route_lease_0633','install_followup_repairs'),
 "economy":('ground_route_authority_0633','install_ground_route_authority'),
}
def main():
 errors=[];texts={name:path.read_text(encoding='utf-8',errors='replace') for name,path in FILES.items()}
 for name,parts in REQUIRED.items():
  for part in parts:
   if part not in texts[name]:errors.append(f'{FILES[name].relative_to(ROOT)} missing contract: {part}')
 for name,parts in FORBIDDEN.items():
  for part in parts:
   if part in texts[name]:errors.append(f'{FILES[name].relative_to(ROOT)} contains forbidden regression: {part}')
 movement=texts['movement']
 if movement.find('local function lower') > movement.find('local function budget_exempt'):
  errors.append('movement_controller lower() must be declared before budget_exempt() to preserve local lexical binding')
 if errors:
  print('Ground route/loader boundary audit failed:',file=sys.stderr)
  for error in errors:print('  - '+error,file=sys.stderr)
  return 1
 print('Ground route/loader boundary audit passed: controller owns visible chunks and cleanup; 0631 is broker-only; 0632/0633 are inert; child repairs load explicitly.')
 return 0
if __name__=='__main__':raise SystemExit(main())
