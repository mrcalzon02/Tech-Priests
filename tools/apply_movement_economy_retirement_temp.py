#!/usr/bin/env python3
from pathlib import Path
import re


def read(path: str) -> str:
    return Path(path).read_text(encoding="utf-8")


def write(path: str, text: str) -> None:
    Path(path).write_text(text, encoding="utf-8")


# Integrate the useful low-priority path budget at the exact engine-command boundary.
path = "tech-priests_src/scripts/core/movement_controller.lua"
text = read(path)
text = text.replace('M.corridor_planner_integrated = true', 'M.corridor_planner_integrated = true\nM.request_budget_integrated = true', 1)
anchor = 'local function metric(k,n) local fn=rawget(_G,"tech_priests_runtime_metric_0606"); if type(fn)=="function" then pcall(fn,k,n or 1) end end\n'
helper = anchor + '''local function budget_take(bucket, amount)
  local fn = rawget(_G, "tech_priests_0576_budget_take")
  if type(fn) == "function" then
    local ok, allowed = pcall(fn, bucket, amount or 1)
    if ok then return allowed ~= false end
  end
  return true
end
local function budget_exempt(reason, owner, priority)
  if (tonumber(priority) or 0) >= 900 then return true end
  local value = lower(reason) .. " " .. lower(owner)
  return value:find("combat",1,true) ~= nil
    or value:find("retreat",1,true) ~= nil
    or value:find("hostile",1,true) ~= nil
    or value:find("manual",1,true) ~= nil
    or value:find("player",1,true) ~= nil
    or value:find("death",1,true) ~= nil
    or value:find("respawn",1,true) ~= nil
    or value:find("vanish",1,true) ~= nil
    or value:find("recovery",1,true) ~= nil
end
local function movement_command_budget_allowed(req)
  if budget_exempt(req and req.reason, req and req.owner, req and req.priority) then return true end
  return budget_take("path_corrections_per_tick", 1)
end
'''
if anchor not in text:
    raise SystemExit('movement metric anchor missing')
text = text.replace(anchor, helper, 1)
old_apply = '''  if now() - (req.last_command_tick or 0) >= M.command_refresh_ticks then
    local ok = direct_go_to(priest, req, radius, req.distraction)
    if ok then'''
new_apply = '''  if now() - (req.last_command_tick or 0) >= M.command_refresh_ticks then
    if not movement_command_budget_allowed(req) then
      pair.movement_controller_state_0418 = "movement-budget-deferred-0577"
      local root = ensure_root()
      root.stats.movement_budget_deferred_0577 = (root.stats.movement_budget_deferred_0577 or 0) + 1
      metric("movement_budget_deferred_0577", 1)
      return false
    end
    local ok = direct_go_to(priest, req, radius, req.distraction)
    if ok then'''
if old_apply not in text:
    raise SystemExit('movement apply_request budget anchor missing')
text = text.replace(old_apply, new_apply, 1)
text = text.replace(
    '      " corridor_planner_integrated=true" ..',
    '      " corridor_planner_integrated=true" ..\n      " request_budget_integrated=true" ..\n      " budget_deferred=" .. tostring((root.stats or {}).movement_budget_deferred_0577 or 0) ..',
    1,
)
write(path, text)

# Retire both economy wrappers.
write(
    "tech-priests_src/scripts/core/efficiency_economy_0572.lua",
    '''-- scripts/core/efficiency_economy_0572.lua
-- Source-preserved retirement marker. Ground priests may not teleport merely
-- because players are not observing them; all ground transit remains physical.
local M = {
  retired = true,
  authority = "efficiency_economy_0572",
  replacement = "physical movement_controller transit",
  retirement_reason = "unobserved ground teleport violates physical honesty",
}
return M
''',
)
write(
    "tech-priests_src/scripts/core/efficiency_economy_0577.lua",
    '''-- scripts/core/efficiency_economy_0577.lua
-- Source-preserved retirement marker. Executor budgets belong to broker service
-- budgets; low-priority engine-command budgeting is native to movement_controller.
local M = {
  retired = true,
  authority = "efficiency_economy_0577",
  replacement = "runtime_tick_broker + scripts.core.movement_controller",
}
return M
''',
)

# Remove both loaders from control.lua.
path = "tech-priests_src/control.lua"
text = read(path)
for version, module, local_name in (
    ('572', 'efficiency_economy_0572', 'Economy0572'),
    ('577', 'efficiency_economy_0577', 'Economy0577'),
):
    pattern = rf'-- 0\.1\.{version}:.*?\ndo\n  local ok, err = pcall\(function\(\)\n    local {local_name} = require\("scripts\.core\.{module}"\)\n    if {local_name} and {local_name}\.install then {local_name}\.install\(\) end\n  end\)\n  if not ok and log then log\("\[Tech-Priests 0\.1\.{version}\] {module} failed to install: " \.\. tostring\(err\)\) end\nend\n\n'
    replacement = f'-- Historical {version} movement-economy wrapper is retired and not loaded.\n\n'
    text, count = re.subn(pattern, replacement, text, count=1, flags=re.DOTALL)
    if count != 1:
        raise SystemExit(f'control {module} loader removal count={count}')
write(path, text)

# Remove historical commands on upgrades.
path = "tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua"
text = read(path).replace('  ["tp-path-corridors-0574"] = true,', '  ["tp-path-corridors-0574"] = true,\n  ["tp-efficiency-economy-0572"] = true,\n  ["tp-efficiency-economy-0577"] = true,', 1)
write(path, text)

# Declarative graph: 26 active / 35 retired.
path = "tech-priests_src/scripts/core/planning_constraints_0646.lua"
text = read(path).replace('active_hardener_count=26,retired_authority_count=33', 'active_hardener_count=26,retired_authority_count=35', 1)
anchor = ' ["scripts.core.movement_enforcement_0566"]="ground envelope enforcement and void delegation are native to movement_controller",'
entry = anchor + '\n ["scripts.core.efficiency_economy_0572"]="unobserved ground teleportation is retired as physically dishonest",\n ["scripts.core.efficiency_economy_0577"]="executor budgets belong to broker services and path-command budgeting is native to movement_controller",'
if anchor not in text:
    raise SystemExit('planning 0566 retired anchor missing')
text = text.replace(anchor, entry, 1)
write(path, text)

path = "tools/check_development_integration_0732.py"
text = read(path)
text = text.replace('    "scripts.core.movement_enforcement_0566",', '    "scripts.core.movement_enforcement_0566",\n    "scripts.core.efficiency_economy_0572", "scripts.core.efficiency_economy_0577",', 1)
text = text.replace('"retired_authority_count=33"', '"retired_authority_count=35"', 1)
text = text.replace('"check_corridor_route_planner_boundary_0766.py",', '"check_corridor_route_planner_boundary_0766.py", "check_movement_economy_boundary_0767.py",', 1)
write(path, text)

path = "tools/check_recovery_architecture_0744.py"
text = read(path)
text = text.replace('"scripts.core.movement_bounds_contract_0511", "scripts.core.movement_enforcement_0566",', '"scripts.core.movement_bounds_contract_0511", "scripts.core.movement_enforcement_0566", "scripts.core.efficiency_economy_0572", "scripts.core.efficiency_economy_0577",', 1)
text = text.replace('"retired_authority_count=33"', '"retired_authority_count=35"', 1)
text = text.replace('"33 source-preserved authorities"', '"35 source-preserved authorities"', 1)
text = text.replace('"26 active hardeners and 33 explicitly retired"', '"26 active hardeners and 35 explicitly retired"', 1)
text = text.replace('"Thirty-three files remain"', '"Thirty-five files remain"', 1)
text = text.replace('active=26 retired=33 construction=canonical', 'active=26 retired=35 construction=canonical', 1)
text = text.replace(
    '("Audit observer-only corridor route planner", "check_corridor_route_planner_boundary_0766.py"),',
    '("Audit observer-only corridor route planner", "check_corridor_route_planner_boundary_0766.py"),\n        ("Audit retired movement economy wrappers", "check_movement_economy_boundary_0767.py"),',
    1,
)
write(path, text)

path = "tools/check_governance_prerequisites_0738.py"
text = read(path)
for old, new in (
    ('26-active / 33-retired graph', '26-active / 35-retired graph'),
    ('26 active hardeners and 33 explicitly retired', '26 active hardeners and 35 explicitly retired'),
    ('26 active hardeners and 33 retired source-only authorities', '26 active hardeners and 35 retired source-only authorities'),
    ('33 source-preserved authorities', '35 source-preserved authorities'),
    ('33 retired source-only authorities', '35 retired source-only authorities'),
    ('Thirty-three files remain', 'Thirty-five files remain'),
):
    text = text.replace(old, new)
text = text.replace(
    '"Audit observer-only corridor route planner",\n        "check_corridor_route_planner_boundary_0766.py",',
    '"Audit observer-only corridor route planner",\n        "check_corridor_route_planner_boundary_0766.py",\n        "Audit retired movement economy wrappers",\n        "check_movement_economy_boundary_0767.py",',
    1,
)
write(path, text)

for checker in (
    "tools/check_movement_cadence_boundary_0761.py",
    "tools/check_combat_proxy_boundary_0762.py",
    "tools/check_direct_acquisition_bounds_boundary_0764.py",
    "tools/check_movement_enforcement_void_boundary_0765.py",
):
    write(checker, read(checker).replace('retired_authority_count=33', 'retired_authority_count=35'))

write(
    "tools/check_movement_economy_boundary_0767.py",
    '''#!/usr/bin/env python3
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
 "planning":('retired_authority_count=35','["scripts.core.efficiency_economy_0572"]','["scripts.core.efficiency_economy_0577"]'),
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
''',
)

# Living records.
write("RECOVERY_REPAIR_SEQUENCE.md", read("RECOVERY_REPAIR_SEQUENCE.md").replace('26-active / 33-retired graph', '26-active / 35-retired graph'))
path = "tech-priests_src/docs/AUTHORITY_REFACTOR_CONTINUITY.md"
text = read(path)
text = text.replace('The `RETIRED` table contains **33 source-preserved authorities**.', 'The `RETIRED` table contains **35 source-preserved authorities**.', 1)
text = text.replace('- `movement_enforcement_0566.lua`;', '- `movement_enforcement_0566.lua`;\n- `efficiency_economy_0572.lua`;\n- `efficiency_economy_0577.lua`;', 1)
section = '''## Movement economy boundary

Ground-priest transit remains physical regardless of player observation. `efficiency_economy_0572.lua` is retired because unseen teleportation violates physical honesty. Executor work is budgeted by named broker services rather than service-pair wrappers. `efficiency_economy_0577.lua` is retired; its useful low-priority path budget is applied inside `movement_controller` immediately before an engine command.

'''
if '## Movement economy boundary' not in text:
    anchor = '## Authority-corridor route planning'
    if anchor not in text: raise SystemExit('continuity corridor anchor missing')
    text = text.replace(anchor, section + anchor, 1)
write(path, text)

path = "tech-priests_src/docs/CURRENT_TESTING_GOALS.md"
text = read(path)
text = text.replace('26 active hardeners and 33 retired source-only authorities', '26 active hardeners and 35 retired source-only authorities', 1)
anchor = '- observer-only corridor authorization and waypoint proposals in `authority_corridor_pathing_0574`, consumed by the sole movement controller before request mutation;\n'
bullet = '- physical ground transit with low-priority path-command budgeting inside `movement_controller`; unseen teleport `0572` and global wrapper budget `0577` are retired;\n'
if bullet not in text:
    if anchor not in text: raise SystemExit('testing corridor anchor missing')
    text = text.replace(anchor, anchor + bullet, 1)
text = text.replace('movement-enforcement/Void-backend and corridor-route-planner audits;', 'movement-enforcement/Void-backend, corridor-route-planner, and movement-economy audits;', 1)
text = text.replace('26 attempted active hardeners and 33 retired source-only authorities', '26 attempted active hardeners and 35 retired source-only authorities', 1)
write(path, text)

path = "docs/RECOVERY_AUTHORITY_MAP_CURRENT.md"
text = read(path)
text = text.replace('**33 retired source-only authorities**', '**35 retired source-only authorities**', 1)
text = text.replace('Planning --> Retired[33 retired authorities]', 'Planning --> Retired[35 retired authorities]', 1)
text = text.replace('Thirty-three files remain source-preserved', 'Thirty-five files remain source-preserved', 1)
anchor = '`authority_corridor_pathing_0574` is a pure planner: it proposes authorization and optional waypoints, while `movement_controller` owns rejection, request state, return movement, and engine commands.'
replacement = anchor + '\n\nGround transit is never replaced with offscreen teleportation. Broker service budgets govern executors; the movement controller consumes the shared path budget only at its engine-command boundary.'
if anchor not in text: raise SystemExit('map corridor paragraph missing')
text = text.replace(anchor, replacement, 1)
write(path, text)

path = "docs/DEVELOPMENT_HISTORY.md"
text = read(path)
section = '''### Retired movement-economy wrappers `0572` and `0577`

`efficiency_economy_0572` replaced visible ground walking with same-surface teleportation whenever no connected player was deemed close enough to observe the priest, destination, or station. That optimization is incompatible with the project’s physical-honesty rules and has been retired without replacement.

`efficiency_economy_0577` wrapped eleven executor `service_pair` methods, the global movement request API, a deferred movement queue, a command, and a periodic route. Canonical executor services already receive broker budgets. Its one distinct useful policy—deferring low-priority path corrections when the shared path budget is exhausted—is now applied inside `movement_controller` immediately before an engine command. Both source files are inert and no longer loaded. The graph is now **26 active hardeners and 35 explicitly retired source-only authorities**.

Complete Source validation and Factorio runtime evidence remain separately required.

'''
if '### Retired movement-economy wrappers `0572` and `0577`' not in text:
    anchor = '## Current Gate State'
    if anchor not in text: raise SystemExit('history gate anchor missing')
    text = text.replace(anchor, section + anchor, 1)
write(path, text)

Path(__file__).unlink()
