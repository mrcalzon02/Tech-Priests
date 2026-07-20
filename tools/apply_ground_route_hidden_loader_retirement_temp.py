#!/usr/bin/env python3
from pathlib import Path
import re


def read(path: str) -> str:
    return Path(path).read_text(encoding="utf-8")


def write(path: str, text: str) -> None:
    Path(path).write_text(text, encoding="utf-8")


# Canonical movement owns visible route chunking, retired-state cleanup, and fixes
# the lexical binding of lower() before budget_exempt() is declared.
path = "tech-priests_src/scripts/core/movement_controller.lua"
text = read(path)
text = text.replace('M.request_budget_integrated = true', 'M.request_budget_integrated = true\nM.ground_route_chunking_integrated = true\nM.visible_ground_segment = 18\nM.visible_ground_probe_radius = 96', 1)
old_order = '''local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function metric(k,n) local fn=rawget(_G,"tech_priests_runtime_metric_0606"); if type(fn)=="function" then pcall(fn,k,n or 1) end end'''
new_order = '''local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function lower(value) return string.lower(tostring(value or "")) end
local function metric(k,n) local fn=rawget(_G,"tech_priests_runtime_metric_0606"); if type(fn)=="function" then pcall(fn,k,n or 1) end end'''
if old_order not in text:
    raise SystemExit('movement helper ordering anchor missing')
text = text.replace(old_order, new_order, 1)
# Remove the later duplicate declaration so every consumer binds to the early local.
late_lower = '\nlocal function lower(value) return string.lower(tostring(value or "")) end\nlocal function tier_key(pair)'
if late_lower not in text:
    raise SystemExit('movement late lower declaration missing')
text = text.replace(late_lower, '\nlocal function tier_key(pair)', 1)
anchor = '''local function return_or_recovery_reason(reason, opts)
  local value = lower(reason) .. " " .. lower(opts and opts.owner or "")
  return value:find("return", 1, true) ~= nil
    or value:find("home", 1, true) ~= nil
    or value:find("overleash", 1, true) ~= nil
    or value:find("station", 1, true) ~= nil
    or value:find("recovery", 1, true) ~= nil
    or value:find("respawn", 1, true) ~= nil
    or value:find("pair%-link", 1, false) ~= nil
end
'''
addition = anchor + '''local function player_near(surface, position, radius)
  if not (surface and position) then return false end
  local probe = rawget(_G, "tech_priests_any_player_near_0568") or rawget(_G, "tech_priests_any_player_near")
  if type(probe) == "function" then
    local ok, result = pcall(probe, surface, position, radius or M.visible_ground_probe_radius)
    if ok then return result == true end
  end
  if not (game and game.connected_players) then return false end
  local maximum = tonumber(radius) or M.visible_ground_probe_radius
  local maximum_sq = maximum * maximum
  for _, player in pairs(game.connected_players) do
    if player and player.valid and player.surface == surface and dist_sq(player.position, position) <= maximum_sq then return true end
  end
  return false
end
local function route_chunk_exempt(reason, opts)
  if opts and (opts.no_ground_waypoint == true or opts.corridor_waypoint == true or opts.bounds_exempt == true) then return true end
  if return_or_recovery_reason(reason, opts) then return true end
  return budget_exempt(reason, opts and opts.owner, opts and opts.priority)
end
local function plan_visible_ground_segment(pair, destination, reason, opts)
  if not (pair and valid(pair.priest) and valid(pair.station) and destination) then return destination, opts end
  if route_chunk_exempt(reason, opts) then return destination, opts end
  local distance_sq = dist_sq(pair.priest.position, destination) or 0
  local maximum = M.visible_ground_segment
  if distance_sq <= maximum * maximum then return destination, opts end
  local visible = player_near(pair.priest.surface, pair.priest.position, M.visible_ground_probe_radius)
    or player_near(pair.priest.surface, destination, M.visible_ground_probe_radius)
    or player_near(pair.priest.surface, pair.station.position, M.visible_ground_probe_radius)
  if not visible then return destination, opts end
  local distance = math.sqrt(distance_sq)
  local ratio = maximum / math.max(distance, 0.001)
  local waypoint = {
    x = pair.priest.position.x + (destination.x - pair.priest.position.x) * ratio,
    y = pair.priest.position.y + (destination.y - pair.priest.position.y) * ratio,
  }
  local merged = {}
  for key, value in pairs(opts or {}) do merged[key] = value end
  merged.ground_route_chunked = true
  merged.ground_route_final_destination = { x = destination.x, y = destination.y }
  merged.ttl = math.max(tonumber(merged.ttl) or 0, 600)
  merged.radius = tonumber(merged.radius) or 0.75
  return waypoint, merged
end
'''
if anchor not in text:
    raise SystemExit('movement return/recovery helper anchor missing')
text = text.replace(anchor, addition, 1)
old_request_point = '''  if is_space_pair(pair) and not opts.force_ground_controller then
    if corridor_rejected then return false, "void-corridor-not-authorized" end
    local backend = void_backend()
    if backend and type(backend.request) == "function" then return backend.request(pair, destination, reason, opts) end
    return false, "void-movement-backend-unavailable"
  end
  local root = ensure_root()
'''
new_request_point = '''  if is_space_pair(pair) and not opts.force_ground_controller then
    if corridor_rejected then return false, "void-corridor-not-authorized" end
    local backend = void_backend()
    if backend and type(backend.request) == "function" then return backend.request(pair, destination, reason, opts) end
    return false, "void-movement-backend-unavailable"
  end
  if opts.ground_route_chunked ~= true then
    local planned_destination, planned_opts = plan_visible_ground_segment(pair, destination, reason, opts)
    if planned_destination then destination = planned_destination end
    if planned_opts then opts = planned_opts; reason = "ground-route-waypoint-0633" end
  end
  local root = ensure_root()
'''
if old_request_point not in text:
    raise SystemExit('movement ground route insertion anchor missing')
text = text.replace(old_request_point, new_request_point, 1)
old_request_meta = '''    corridor_station_unit = opts.corridor_station_unit,
    corridor_final_destination = opts.corridor_final_destination
  }'''
new_request_meta = '''    corridor_station_unit = opts.corridor_station_unit,
    corridor_final_destination = opts.corridor_final_destination,
    ground_route_chunked = opts.ground_route_chunked == true,
    ground_route_final_destination = opts.ground_route_final_destination
  }'''
if old_request_meta not in text:
    raise SystemExit('movement request metadata anchor missing')
text = text.replace(old_request_meta, new_request_meta, 1)
old_install_start = '''function M.install()
  install_wrappers()
  local root = ensure_root()
'''
new_install_start = '''function M.cleanup_retired_pair_state()
  local root = ensure_root()
  local cleared = 0
  for _, pair in pairs(pairs_by_station()) do
    if type(pair) == "table" then
      if pair.ground_route_lease_0633 ~= nil then pair.ground_route_lease_0633 = nil; cleared = cleared + 1 end
      if pair.ground_route_status_0633 ~= nil then pair.ground_route_status_0633 = nil; cleared = cleared + 1 end
      if pair.movement_rejected_0566 ~= nil then pair.movement_rejected_0566 = nil; cleared = cleared + 1 end
      local state = pair.dispatcher_direct_0513
      if type(state) == "table" and state.phase == "paused-by-movement-enforcement" then
        state.phase = "none"
        state.detail = "retired-0632-recall-state-cleared"
        state.tick = now()
        cleared = cleared + 1
      end
    end
  end
  root.stats.retired_state_cleared_0632_0633 = (root.stats.retired_state_cleared_0632_0633 or 0) + cleared
  return cleared
end

function M.install()
  install_wrappers()
  local root = ensure_root()
  M.cleanup_retired_pair_state()
'''
if old_install_start not in text:
    raise SystemExit('movement install start anchor missing')
text = text.replace(old_install_start, new_install_start, 1)
text = text.replace(
    '      " request_budget_integrated=true" ..',
    '      " request_budget_integrated=true" ..\n      " ground_route_chunking_integrated=true" ..\n      " retired_route_state_cleared=" .. tostring((root.stats or {}).retired_state_cleared_0632_0633 or 0) ..',
    1,
)
write(path, text)

# Direct acquisition pulse remains a broker service but stops installing the obsolete recall wrapper and command/fallback.
path = "tech-priests_src/scripts/core/direct_acquisition_pulse_0631.lua"
text = read(path)
text = text.replace('-- Tech Priests 0.1.631', '-- Tech Priests 0.1.674-dev', 1)
text = text.replace('M.version = "0.1.631"', 'M.version = "0.1.674-dev"\nM.broker_required = true\nM.recall_guard_retired = true', 1)
text, count = re.subn(r'\nlocal function install_command\(\).*?\nend\n\nlocal function install_recall_guard\(\).*?\nend\n', '\n', text, count=1, flags=re.DOTALL)
if count != 1:
    raise SystemExit(f'0631 command/recall installer removal count={count}')
old_install = '''function M.install()
  M.root()
  install_command()
  install_recall_guard()
  _G.TechPriestsDirectAcquisitionPulse0631 = M
  local broker=rawget(_G,"TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service)=="function" then
    broker.register_service({ name="direct_acquisition_pulse_0631", category="direct-acquisition", interval=M.service_interval, priority=46, budget=M.max_pairs_per_pulse, fn=function(event,budget) return M.service(event,budget) end, note="advance direct-acquisition phase machines every tick only while active" })
  else
    local R=rawget(_G,"TechPriestsRuntimeEventRegistry")
    if R and type(R.on_nth_tick)=="function" then R.on_nth_tick(M.service_interval,function(event) M.service(event,M.max_pairs_per_pulse) end,{owner="direct_acquisition_pulse_0631",category="direct-acquisition",priority="early"})
    elseif script and script.on_nth_tick then script.on_nth_tick(M.service_interval,function(event) M.service(event,M.max_pairs_per_pulse) end) end
  end
  if log then log("[Tech-Priests 0.1.631] active-only direct-acquisition pulse installed") end
  return true
end'''
new_install = '''function M.install()
  M.root()
  local broker=rawget(_G,"TechPriestsRuntimeTickBroker0600")
  if not (broker and type(broker.register_service)=="function") then return false end
  local registered=broker.register_service({ name="direct_acquisition_pulse_0631", category="direct-acquisition", interval=M.service_interval, priority=46, budget=M.max_pairs_per_pulse, fn=function(event,budget) return M.service(event,budget) end, note="advance direct-acquisition phase machines every tick only while active" })
  if not registered then return false end
  _G.TechPriestsDirectAcquisitionPulse0631 = M
  if log then log("[Tech-Priests 0.1.674-dev] broker-only active direct-acquisition pulse installed; 0632 recall wrapper retired") end
  return true
end'''
if old_install not in text:
    raise SystemExit('0631 install anchor missing')
text = text.replace(old_install, new_install, 1)
write(path, text)

# 0575 keeps its cache role but stops installing a route owner.
path = "tech-priests_src/scripts/core/efficiency_economy_0575.lua"
text = read(path)
text, count = re.subn(r'\nlocal function install_ground_route_authority\(\).*?\nend\n', '\n', text, count=1, flags=re.DOTALL)
if count != 1:
    raise SystemExit(f'0575 ground route installer removal count={count}')
text = text.replace('  install_ground_route_authority()\n', '', 1)
write(path, text)

# Retire obsolete wrappers.
write(
    "tech-priests_src/scripts/core/direct_acquisition_recall_guard_0632.lua",
    '''-- scripts/core/direct_acquisition_recall_guard_0632.lua
-- Source-preserved retirement marker. Direct acquisition owns native bounds and
-- overleash return; movement_controller owns stale request and return routing.
local M = {
  retired = true,
  authority = "direct_acquisition_recall_guard_0632",
  replacement = "direct_acquisition_executor_0513 + scripts.core.movement_controller",
}
return M
''',
)
write(
    "tech-priests_src/scripts/core/ground_route_authority_0633.lua",
    '''-- scripts/core/ground_route_authority_0633.lua
-- Source-preserved retirement marker. Visible route chunking and request state
-- are native to movement_controller; child repair modules load explicitly.
local M = {
  retired = true,
  authority = "ground_route_authority_0633",
  replacement = "scripts.core.movement_controller + explicit child loaders",
}
return M
''',
)

# Flatten the hidden child loader chain into explicit control.lua entries.
path = "tech-priests_src/control.lua"
text = read(path)
anchor = '''do
  local ok, err = pcall(function()
    local Pulse0631 = require("scripts.core.direct_acquisition_pulse_0631")
    if Pulse0631 and Pulse0631.install then Pulse0631.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.631] direct_acquisition_pulse_0631 failed to install: " .. tostring(err)) end
end

'''
children = anchor + '''-- Explicit 0634-0643 repair loaders formerly hidden behind retired 0633.
do
  local ok, err = pcall(function()
    local Invalidate0634 = require("scripts.core.station_area_change_invalidator_0634")
    if Invalidate0634 and Invalidate0634.install then Invalidate0634.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.634] station_area_change_invalidator_0634 failed to install: " .. tostring(err)) end
end
do
  local ok, err = pcall(function()
    local Gui0635 = require("scripts.core.gui_nested_frame_repair_0635")
    if Gui0635 and Gui0635.install then Gui0635.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.635] gui_nested_frame_repair_0635 failed to install: " .. tostring(err)) end
end
do
  local ok, err = pcall(function()
    local Deposit0638 = require("scripts.core.inventory_deposit_safety_0638")
    if Deposit0638 and Deposit0638.install then Deposit0638.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.638] inventory_deposit_safety_0638 failed to install: " .. tostring(err)) end
end
do
  local ok, err = pcall(function()
    local Supply0639 = require("scripts.core.station_supply_satisfaction_0639")
    if Supply0639 and Supply0639.install then Supply0639.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.639] station_supply_satisfaction_0639 failed to install: " .. tostring(err)) end
end
do
  local ok, err = pcall(function()
    local Infra0640 = require("scripts.core.infrastructure_first_governor_0640")
    if Infra0640 and Infra0640.install then Infra0640.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.640] infrastructure_first_governor_0640 failed to install: " .. tostring(err)) end
end
do
  local ok, err = pcall(function()
    local Placement0643 = require("scripts.core.emergency_facility_placement_bridge_0643")
    if Placement0643 and Placement0643.install then Placement0643.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.643] emergency_facility_placement_bridge_0643 failed to install: " .. tostring(err)) end
end
do
  local ok, err = pcall(function()
    local Monitor0642 = require("scripts.core.behavior_tree_monitor_0642")
    if Monitor0642 and Monitor0642.install then Monitor0642.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.642] behavior_tree_monitor_0642 failed to install: " .. tostring(err)) end
end
do
  local ok, err = pcall(function()
    local Bootstrap0637 = require("scripts.core.bootstrap_resource_governor_0637")
    if Bootstrap0637 and Bootstrap0637.install then Bootstrap0637.install() end
  end)
  if not ok and log then log("[Tech-Priests 0.1.637] bootstrap_resource_governor_0637 failed to install: " .. tostring(err)) end
end

'''
if anchor not in text:
    raise SystemExit('control 0631 loader anchor missing')
text = text.replace(anchor, children, 1)
write(path, text)

# Upgrade cleanup removes historical commands.
path = "tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua"
text = read(path).replace('  ["tp-efficiency-economy-0577"] = true,', '  ["tp-efficiency-economy-0577"] = true,\n  ["tp-direct-recall-0632"] = true,\n  ["tp-ground-route-0633"] = true,\n  ["tp-direct-pulse-0631"] = true,', 1)
write(path, text)

# Declarative graph: 26 active / 37 retired.
path = "tech-priests_src/scripts/core/planning_constraints_0646.lua"
text = read(path).replace('active_hardener_count=26,retired_authority_count=35', 'active_hardener_count=26,retired_authority_count=37', 1)
anchor = ' ["scripts.core.efficiency_economy_0577"]="executor budgets belong to broker services and path-command budgeting is native to movement_controller",'
entry = anchor + '\n ["scripts.core.direct_acquisition_recall_guard_0632"]="native direct bounds and movement return ownership replace obsolete 0566 recall compatibility",\n ["scripts.core.ground_route_authority_0633"]="visible route chunking is native to movement_controller and child repair loaders are explicit",'
if anchor not in text:
    raise SystemExit('planning 0577 retired anchor missing')
text = text.replace(anchor, entry, 1)
write(path, text)

path = "tools/check_development_integration_0732.py"
text = read(path)
text = text.replace('    "scripts.core.efficiency_economy_0572", "scripts.core.efficiency_economy_0577",', '    "scripts.core.efficiency_economy_0572", "scripts.core.efficiency_economy_0577",\n    "scripts.core.direct_acquisition_recall_guard_0632", "scripts.core.ground_route_authority_0633",', 1)
text = text.replace('"retired_authority_count=35"', '"retired_authority_count=37"', 1)
text = text.replace('"check_movement_economy_boundary_0767.py",', '"check_movement_economy_boundary_0767.py", "check_ground_route_loader_boundary_0768.py",', 1)
write(path, text)

path = "tools/check_recovery_architecture_0744.py"
text = read(path)
text = text.replace('"scripts.core.efficiency_economy_0572", "scripts.core.efficiency_economy_0577",', '"scripts.core.efficiency_economy_0572", "scripts.core.efficiency_economy_0577", "scripts.core.direct_acquisition_recall_guard_0632", "scripts.core.ground_route_authority_0633",', 1)
text = text.replace('"retired_authority_count=35"', '"retired_authority_count=37"', 1)
text = text.replace('"35 source-preserved authorities"', '"37 source-preserved authorities"', 1)
text = text.replace('"26 active hardeners and 35 explicitly retired"', '"26 active hardeners and 37 explicitly retired"', 1)
text = text.replace('"Thirty-five files remain"', '"Thirty-seven files remain"', 1)
text = text.replace('active=26 retired=35 construction=canonical', 'active=26 retired=37 construction=canonical', 1)
text = text.replace(
    '("Audit retired movement economy wrappers", "check_movement_economy_boundary_0767.py"),',
    '("Audit retired movement economy wrappers", "check_movement_economy_boundary_0767.py"),\n        ("Audit retired ground route and explicit child loaders", "check_ground_route_loader_boundary_0768.py"),',
    1,
)
write(path, text)

path = "tools/check_governance_prerequisites_0738.py"
text = read(path)
for old, new in (
    ('26-active / 35-retired graph', '26-active / 37-retired graph'),
    ('26 active hardeners and 35 explicitly retired', '26 active hardeners and 37 explicitly retired'),
    ('26 active hardeners and 35 retired source-only authorities', '26 active hardeners and 37 retired source-only authorities'),
    ('35 source-preserved authorities', '37 source-preserved authorities'),
    ('35 retired source-only authorities', '37 retired source-only authorities'),
    ('Thirty-five files remain', 'Thirty-seven files remain'),
):
    text = text.replace(old, new)
text = text.replace(
    '"Audit retired movement economy wrappers",\n        "check_movement_economy_boundary_0767.py",',
    '"Audit retired movement economy wrappers",\n        "check_movement_economy_boundary_0767.py",\n        "Audit retired ground route and explicit child loaders",\n        "check_ground_route_loader_boundary_0768.py",',
    1,
)
write(path, text)

for checker in (
    "tools/check_movement_cadence_boundary_0761.py",
    "tools/check_combat_proxy_boundary_0762.py",
    "tools/check_direct_acquisition_bounds_boundary_0764.py",
    "tools/check_movement_enforcement_void_boundary_0765.py",
    "tools/check_movement_economy_boundary_0767.py",
):
    write(checker, read(checker).replace('retired_authority_count=35', 'retired_authority_count=37'))

write(
    "tools/check_ground_route_loader_boundary_0768.py",
    '''#!/usr/bin/env python3
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
 "planning":('retired_authority_count=37','["scripts.core.direct_acquisition_recall_guard_0632"]','["scripts.core.ground_route_authority_0633"]'),
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
''',
)

# Living records.
write("RECOVERY_REPAIR_SEQUENCE.md", read("RECOVERY_REPAIR_SEQUENCE.md").replace('26-active / 35-retired graph', '26-active / 37-retired graph'))
path = "tech-priests_src/docs/AUTHORITY_REFACTOR_CONTINUITY.md"
text = read(path)
text = text.replace('The `RETIRED` table contains **35 source-preserved authorities**.', 'The `RETIRED` table contains **37 source-preserved authorities**.', 1)
text = text.replace('- `efficiency_economy_0577.lua`;', '- `efficiency_economy_0577.lua`;\n- `direct_acquisition_recall_guard_0632.lua`;\n- `ground_route_authority_0633.lua`;', 1)
section = '''## Visible ground route and explicit loader authority

`movement_controller.lua` owns visible ground route chunking and clears retired `0632`/`0633` pair state during installation. `direct_acquisition_pulse_0631.lua` is broker-only and does not install a recall wrapper or command. `direct_acquisition_recall_guard_0632.lua` and `ground_route_authority_0633.lua` are retired and inert.

The unrelated `0634`–`0643` repair modules formerly hidden behind `0633` are now loaded explicitly in `control.lua`, preserving behavior while removing the dependency chain.

'''
if '## Visible ground route and explicit loader authority' not in text:
    anchor = '## Movement economy boundary'
    if anchor not in text: raise SystemExit('continuity movement economy anchor missing')
    text = text.replace(anchor, section + anchor, 1)
write(path, text)

path = "tech-priests_src/docs/CURRENT_TESTING_GOALS.md"
text = read(path)
text = text.replace('26 active hardeners and 35 retired source-only authorities', '26 active hardeners and 37 retired source-only authorities', 1)
anchor = '- physical ground transit with low-priority path-command budgeting inside `movement_controller`; unseen teleport `0572` and global wrapper budget `0577` are retired;\n'
bullet = '- native visible route chunking and retired-state cleanup in `movement_controller`, broker-only `0631`, inert `0632`/`0633`, and explicit `0634`–`0643` repair loaders;\n'
if bullet not in text:
    if anchor not in text: raise SystemExit('testing movement economy anchor missing')
    text = text.replace(anchor, anchor + bullet, 1)
text = text.replace('movement-enforcement/Void-backend, corridor-route-planner, and movement-economy audits;', 'movement-enforcement/Void-backend, corridor-route-planner, movement-economy, and ground-route/loader audits;', 1)
text = text.replace('26 attempted active hardeners and 35 retired source-only authorities', '26 attempted active hardeners and 37 retired source-only authorities', 1)
write(path, text)

path = "docs/RECOVERY_AUTHORITY_MAP_CURRENT.md"
text = read(path)
text = text.replace('**35 retired source-only authorities**', '**37 retired source-only authorities**', 1)
text = text.replace('Planning --> Retired[35 retired authorities]', 'Planning --> Retired[37 retired authorities]', 1)
text = text.replace('Thirty-five files remain source-preserved', 'Thirty-seven files remain source-preserved', 1)
anchor = 'Ground transit is never replaced with offscreen teleportation. Broker service budgets govern executors; the movement controller consumes the shared path budget only at its engine-command boundary.'
replacement = anchor + '\n\nVisible long-route chunking is native to the movement controller. `0632` and `0633` are retired, and their formerly hidden child repair modules load explicitly.'
if anchor not in text: raise SystemExit('map movement economy paragraph missing')
text = text.replace(anchor, replacement, 1)
write(path, text)

path = "docs/DEVELOPMENT_HISTORY.md"
text = read(path)
section = '''### Retired `0632`/`0633` and flattened hidden repair loaders

`direct_acquisition_pulse_0631` previously installed `direct_acquisition_recall_guard_0632`, which wrapped the canonical direct executor using obsolete `0566` compatibility state. `efficiency_economy_0575` installed `ground_route_authority_0633`, which wrapped the movement request API and silently installed seven unrelated repair modules.

Visible route chunking and old pair-state cleanup are now native to `movement_controller`. `0631` is broker-only and no longer installs a command, timer fallback, or recall wrapper. `0632` and `0633` are inert. The `0634`, `0635`, `0638`, `0639`, `0640`, `0643`, `0642`, and `0637` repairs are loaded explicitly from `control.lua` in their previous order. The same slice corrected `movement_controller` so its local `lower` helper is declared before `budget_exempt`, preventing an otherwise invisible runtime global lookup.

The declarative graph is now **26 active hardeners and 37 explicitly retired source-only authorities**. Complete Source validation and Factorio runtime evidence remain separately required.

'''
if '### Retired `0632`/`0633` and flattened hidden repair loaders' not in text:
    anchor = '## Current Gate State'
    if anchor not in text: raise SystemExit('history gate anchor missing')
    text = text.replace(anchor, section + anchor, 1)
write(path, text)

Path(__file__).unlink()
