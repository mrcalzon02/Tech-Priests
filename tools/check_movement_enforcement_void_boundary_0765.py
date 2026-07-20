#!/usr/bin/env python3
"""Validate native ground enforcement and delegated broker-only Void movement."""
from __future__ import annotations
import pathlib
import sys
ROOT = pathlib.Path(__file__).resolve().parents[1]
FILES = {
 "movement": ROOT / "tech-priests_src/scripts/core/movement_controller.lua",
 "void": ROOT / "tech-priests_src/scripts/core/void_movement_authority_0630.lua",
 "retired": ROOT / "tech-priests_src/scripts/core/movement_enforcement_0566.lua",
 "control": ROOT / "tech-priests_src/control.lua",
 "cleanup": ROOT / "tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua",
 "planning": ROOT / "tech-priests_src/scripts/core/planning_constraints_0646.lua",
 "workflow": ROOT / ".github/workflows/source-validation.yml",
}
REQUIRED = {
 "movement": ('M.enforcement_integrated = true','function M.position_allowed','function M.enforce_pair','function M.enforcement_service','name = "movement_controller_enforcement_0566"','local function void_backend','backend.request(pair, destination, reason, opts)','backend.stop(pair, reason)','backend.status(pair, owner)'),
 "void": ('version = "0.1.674-dev"','public_wrapper_retired = true','function M.request','function M.stop','function M.status','name = "void_movement_authority_0630"','broker.register_service','TECH_PRIESTS_VOID_MOVEMENT_AUTHORITY_0630'),
 "retired": ('retired = true','authority = "movement_enforcement_0566"','replacement = "scripts.core.movement_controller"','return M'),
 "control": ('Historical 0566 movement governor is retired','require("scripts.core.void_movement_authority_0630")','require("scripts.core.direct_acquisition_pulse_0631")'),
 "cleanup": ('["tp-movement-enforcement-0566"] = true','["tp-void-movement-0630"] = true'),
 "planning": ('retired_authority_count=33','["scripts.core.movement_enforcement_0566"]'),
 "workflow": ('Audit canonical movement enforcement and void backend','check_movement_enforcement_void_boundary_0765.py'),
}
FORBIDDEN = {
 "void": ('tech_priests_request_movement_0418 =','tech_priests_stop_movement_0418 =','tech_priests_movement_status_0418 =','move_priest_to =','patch_movement_bounds','patch_movement_enforcement','movement_bounds_contract_0511','movement_enforcement_0566','TechPriestsRuntimeEventRegistry','registry.on_nth_tick','script.on_nth_tick','commands.add_command','install_direct_acquisition_pulse'),
 "retired": ('function M.install','register_service','on_nth_tick','commands.add_command','tech_priests_request_movement_0418','set_command','pair.mode','pair.target'),
 "control": ('require("scripts.core.movement_enforcement_0566")',),
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
  print('Movement enforcement/Void boundary audit failed:',file=sys.stderr)
  for error in errors:print('  - '+error,file=sys.stderr)
  return 1
 print('Movement enforcement/Void boundary audit passed: movement_controller owns public routes and ground envelope; 0630 is a broker-only delegated backend; 0566 is inert.')
 return 0
if __name__=='__main__':raise SystemExit(main())
