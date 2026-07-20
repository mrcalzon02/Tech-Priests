#!/usr/bin/env python3
"""Validate observer-only corridor planning and movement-controller execution."""
from __future__ import annotations
import pathlib
import sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
FILES={
 "planner":ROOT/"tech-priests_src/scripts/core/authority_corridor_pathing_0574.lua",
 "movement":ROOT/"tech-priests_src/scripts/core/movement_controller.lua",
 "cleanup":ROOT/"tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua",
 "workflow":ROOT/".github/workflows/source-validation.yml",
}
REQUIRED={
 "planner":('M.version = "0.1.674-dev"','function M.authorization_for_destination','function M.position_allowed','function M.maybe_corridor_waypoint','function M.plan_request','observer-only corridor route planner','_G.tech_priests_0574_plan_request = M.plan_request'),
 "movement":('M.corridor_planner_integrated = true','rawget(_G, "tech_priests_0574_plan_request")','corridor_rejected','corridor_final_destination = opts.corridor_final_destination','reason = "corridor-waypoint-0574"'),
 "cleanup":('["tp-path-corridors-0574"] = true',),
 "workflow":('Audit observer-only corridor route planner','check_corridor_route_planner_boundary_0766.py'),
}
FORBIDDEN={
 "planner":('TECH_PRIESTS_0574_PRE_REQUEST_MOVEMENT_0418','tech_priests_request_movement_0418 =','clear_invalid_movement','return_home','set_command','commands.add_command','TechPriestsRuntimeEventRegistry','registry.on_nth_tick','script.on_nth_tick','pair.movement_request_0418 =','pair.move_target ='),
}
def main():
 errors=[];texts={name:path.read_text(encoding='utf-8',errors='replace') for name,path in FILES.items()}
 for name,parts in REQUIRED.items():
  for part in parts:
   if part not in texts[name]:errors.append(f'{FILES[name].relative_to(ROOT)} missing contract: {part}')
 for name,parts in FORBIDDEN.items():
  for part in parts:
   if part in texts[name]:errors.append(f'{FILES[name].relative_to(ROOT)} contains forbidden ownership regression: {part}')
 if errors:
  print('Corridor route planner audit failed:',file=sys.stderr)
  for error in errors:print('  - '+error,file=sys.stderr)
  return 1
 print('Corridor route planner audit passed: 0574 plans authorization/waypoints; movement_controller alone mutates movement state and issues commands.')
 return 0
if __name__=='__main__':raise SystemExit(main())
