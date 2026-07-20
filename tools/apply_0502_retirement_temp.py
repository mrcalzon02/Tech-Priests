#!/usr/bin/env python3
from pathlib import Path


def read(path: str) -> str:
    return Path(path).read_text(encoding="utf-8")


def write(path: str, text: str) -> None:
    Path(path).write_text(text, encoding="utf-8")


# Retire the station-side acquisition/movement quarantine wrapper.
write(
    "tech-priests_src/scripts/core/priest_vanish_guard_0502.lua",
    '''-- scripts/core/priest_vanish_guard_0502.lua
-- Source-preserved retirement marker. Direct acquisition belongs to 0513,
-- movement belongs to movement_controller, and priest recovery remains with the
-- lifecycle/recovery authorities under active consolidation.
local M = {
  retired = true,
  authority = "priest_vanish_guard_0502",
  replacement = "direct_acquisition_executor_0513 + movement_controller + canonical lifecycle authority",
}
return M
''',
)

# Rewrite 0509 as broker-only reverse-map and passive UI/cascade maintenance.
cleanup_source = '''-- scripts/core/behavior_stack_cleanup_0509.lua
-- Tech Priests 0.1.674-dev broker-owned passive behavior-stack maintenance.
-- Direct acquisition and movement execution are not owned here. This module
-- only repairs pair reverse maps and debounces passive order/cascade refreshes.

local M = {
  version = "0.1.674-dev",
  storage_key = "behavior_stack_cleanup_0509",
  service_interval = 53,
  service_budget = 32,
  refresh_debounce_ticks = 90,
  cascade_debounce_ticks = 180,
  broker_required = true,
  direct_acquisition_retired = true,
  movement_ownership_retired = true,
}

local function now() return game and game.tick or 0 end
local function valid(entity) return entity and entity.valid end
local function safe(value) if value == nil then return "nil" end local ok, out = pcall(tostring, value); return ok and out or "?" end
local function lower(value) return string.lower(tostring(value or "")) end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil end
local function valid_pair(pair) return type(pair) == "table" and valid(pair.station) and valid(pair.priest) end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or {
    version = M.version, enabled = true, refresh_debounce = true,
    cascade_debounce = true, stats = {}, recent = {}, last_refresh = {}, last_cascade = {},
  }
  local root = storage.tech_priests[M.storage_key]
  root.version = M.version
  if root.enabled == nil then root.enabled = true end
  if root.refresh_debounce == nil then root.refresh_debounce = true end
  if root.cascade_debounce == nil then root.cascade_debounce = true end
  root.stats = root.stats or {}
  root.recent = root.recent or {}
  root.last_refresh = root.last_refresh or {}
  root.last_cascade = root.last_cascade or {}
  root.decommission_0502_executor = nil
  root.physical_direct = nil
  root.last_travel = nil
  return root
end

local function stat(name, amount)
  local root = M.root()
  root.stats[name] = (root.stats[name] or 0) + (amount or 1)
end

local function record(action, pair, detail)
  local root = M.root()
  stat(action)
  root.recent[#root.recent + 1] = {
    tick = now(), action = tostring(action), station = safe(station_unit(pair)),
    priest = safe(priest_unit(pair)), detail = tostring(detail or ""),
  }
  while #root.recent > 120 do table.remove(root.recent, 1) end
end

local function repair_reverse_maps(pair, reason)
  if not valid_pair(pair) then return false end
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests.pairs_by_station = storage.tech_priests.pairs_by_station or {}
  storage.tech_priests.pairs_by_priest = storage.tech_priests.pairs_by_priest or {}
  local changed = false
  if pair.station.unit_number and storage.tech_priests.pairs_by_station[pair.station.unit_number] ~= pair then
    storage.tech_priests.pairs_by_station[pair.station.unit_number] = pair
    changed = true
  end
  if pair.priest.unit_number and storage.tech_priests.pairs_by_priest[pair.priest.unit_number] ~= pair then
    storage.tech_priests.pairs_by_priest[pair.priest.unit_number] = pair
    changed = true
  end
  pair.station_unit = pair.station.unit_number
  pair.priest_unit = pair.priest.unit_number
  if changed then record("reverse-map-repaired-0509", pair, reason or "repair") end
  return changed
end

local function active_work(pair)
  if not pair then return false end
  local canonical = pair.canonical_action_0744
  if type(canonical) == "table" and canonical.phase and canonical.phase ~= "none" and canonical.phase ~= "complete" and canonical.phase ~= "aborted" then return true end
  local direct = pair.dispatcher_direct_0513
  if type(direct) == "table" and direct.phase and direct.phase ~= "none" and direct.phase ~= "complete" and direct.phase ~= "aborted" then return true end
  local queue = pair.order_queue_0469
  if queue and queue.current and queue.current.status == "active" then return true end
  if pair.emergency_craft and (pair.emergency_craft.station_craft_pending_0337 or pair.emergency_craft.craft_due_tick or pair.emergency_craft.current) then return true end
  local mode = lower(pair.mode)
  return mode:find("moving", 1, true) ~= nil or mode:find("travelling", 1, true) ~= nil or mode:find("craft", 1, true) ~= nil or mode:find("repair", 1, true) ~= nil or mode:find("combat", 1, true) ~= nil
end

local function wrap_order_refresh()
  if type(_G.tech_priests_0270_refresh_orders_for_pair) ~= "function" or rawget(_G, "TECH_PRIESTS_0509_PRE_REFRESH_ORDERS") then return true end
  local previous = _G.tech_priests_0270_refresh_orders_for_pair
  _G.TECH_PRIESTS_0509_PRE_REFRESH_ORDERS = previous
  _G.tech_priests_0270_refresh_orders_for_pair = function(pair, source, ...)
    local root = M.root()
    source = tostring(source or "unknown")
    local passive = source == "mouse-over" or source == "radar-priest-scan" or source == "overview-ui" or source:find("overview", 1, true)
    if root.enabled ~= false and root.refresh_debounce ~= false and passive and valid_pair(pair) and active_work(pair) then
      local key = tostring(station_unit(pair) or "nil") .. ":" .. source
      local last = root.last_refresh[key] or -1000000
      if now() - last < M.refresh_debounce_ticks then
        stat("order-refresh-suppressed-0509")
        return false
      end
      root.last_refresh[key] = now()
    end
    return previous(pair, source, ...)
  end
  return true
end

local function wrap_cascade()
  local ok, cascade = pcall(require, "scripts.core.emergency_cascade")
  if not (ok and cascade and type(cascade.cascade_from) == "function") or cascade.behavior_stack_cleanup_0509_wrapped then return true end
  cascade.behavior_stack_cleanup_0509_wrapped = true
  cascade.TECH_PRIESTS_0509_PRE_CASCADE_FROM = cascade.cascade_from
  cascade.cascade_from = function(leader, reason)
    local root = M.root()
    if root.enabled ~= false and root.cascade_debounce ~= false and leader and valid(leader.station) then
      local key = tostring(station_unit(leader) or "nil") .. ":" .. tostring(reason or "")
      local last = root.last_cascade[key] or -1000000
      if now() - last < M.cascade_debounce_ticks then
        record("cascade-suppressed-0509", leader, "reason=" .. safe(reason))
        return 0
      end
      root.last_cascade[key] = now()
    end
    return cascade.TECH_PRIESTS_0509_PRE_CASCADE_FROM(leader, reason)
  end
  return true
end

local function wrap_pair_dump()
  local diagnostics = rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diagnostics and type(diagnostics.pair_dump_lines) == "function") or diagnostics.behavior_stack_cleanup_0509_wrapped then return true end
  local previous = diagnostics.pair_dump_lines
  diagnostics.behavior_stack_cleanup_0509_wrapped = true
  diagnostics.pair_dump_lines = function()
    local lines = previous()
    local root = M.root()
    lines[#lines + 1] = "PAIR-DUMP-0468 BEHAVIOR-STACK-CLEANUP-0509 enabled=" .. safe(root.enabled)
      .. " reverse_repairs=" .. safe(root.stats["reverse-map-repaired-0509"] or 0)
      .. " refresh_suppressed=" .. safe(root.stats["order-refresh-suppressed-0509"] or 0)
      .. " cascade_suppressed=" .. safe(root.stats["cascade-suppressed-0509"] or 0)
    return lines
  end
  return true
end

local function selected_pair(player)
  if _G.selected_pair_for_player then local ok, pair = pcall(_G.selected_pair_for_player, player); if ok and pair then return pair end end
  local selected = player and player.selected
  local root = storage and storage.tech_priests or nil
  if selected and selected.valid and root then
    if root.pairs_by_station and root.pairs_by_station[selected.unit_number] then return root.pairs_by_station[selected.unit_number] end
    if root.pairs_by_priest and root.pairs_by_priest[selected.unit_number] then return root.pairs_by_priest[selected.unit_number] end
  end
  return nil
end

local function install_command()
  if not (commands and commands.add_command) then return true end
  pcall(function() if commands.remove_command then commands.remove_command("tp-behavior-cleanup-0509") end end)
  commands.add_command("tp-behavior-cleanup-0509", "Tech Priests: inspect passive behavior-stack maintenance.", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local parameter = lower(event and event.parameter or "status")
    local root = M.root()
    if parameter == "on" then root.enabled = true elseif parameter == "off" then root.enabled = false end
    if parameter == "refresh-on" then root.refresh_debounce = true elseif parameter == "refresh-off" then root.refresh_debounce = false end
    if parameter == "cascade-on" then root.cascade_debounce = true elseif parameter == "cascade-off" then root.cascade_debounce = false end
    if parameter == "all" then M.service(nil, M.service_budget) end
    local pair = selected_pair(player)
    local message = "[tp-behavior-cleanup-0509] enabled=" .. safe(root.enabled)
      .. " refresh=" .. safe(root.refresh_debounce) .. " cascade=" .. safe(root.cascade_debounce)
      .. " reverse_repairs=" .. safe(root.stats["reverse-map-repaired-0509"] or 0)
      .. " selected=" .. safe(pair and station_unit(pair) or "nil")
    if player and player.valid then player.print(message) elseif game and game.print then game.print(message) end
  end)
  return true
end

function M.service(_, budget)
  local root = M.root()
  if root.enabled == false then return { processed = 0, acted = 0, detail = "disabled" } end
  local limit = math.max(1, math.min(128, math.floor(tonumber(budget) or M.service_budget)))
  local processed, acted = 0, 0
  for _, pair in pairs(pair_map()) do
    if processed >= limit then break end
    if valid_pair(pair) then
      processed = processed + 1
      if repair_reverse_maps(pair, "broker-service-0509") then acted = acted + 1 end
    end
  end
  root.stats.service_processed = (root.stats.service_processed or 0) + processed
  root.stats.service_acted = (root.stats.service_acted or 0) + acted
  return { processed = processed, acted = acted, exhausted = processed >= limit, detail = "passive-reverse-map-maintenance" }
end

function M.install()
  if M._installed then return true end
  M.root()
  wrap_order_refresh()
  wrap_cascade()
  wrap_pair_dump()
  install_command()
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if not (broker and type(broker.register_service) == "function") then return false end
  local registered = broker.register_service({
    name = "behavior_stack_cleanup_0509", category = "maintenance",
    interval = M.service_interval, priority = 82, budget = M.service_budget,
    fn = M.service, note = "passive reverse-map repair and UI/cascade debounce only",
  })
  if not registered then return false end
  _G.TECH_PRIESTS_BEHAVIOR_STACK_CLEANUP_0509 = M
  M._installed = true
  if log then log("[Tech-Priests 0.1.674-dev] broker-owned passive behavior-stack maintenance installed") end
  return true
end

return M
'''
write("tech-priests_src/scripts/core/behavior_stack_cleanup_0509.lua", cleanup_source)

# Remove 0502 loader.
path = "tech-priests_src/control.lua"
text = read(path)
old_loader = '''-- 0.1.502/0.1.504: station-side direct acquisition tether. Loaded after
-- 0.1.501 because the visible native unit still vanished during emergency
-- direct-gather movement. 0.1.504 adds an anti-slam throttle so restored
-- watchdog/recovery callers cannot hammer the quarantine path every tick.
pcall(function()
  local Guard0502 = require("scripts.core.priest_vanish_guard_0502")
  if Guard0502 and Guard0502.install then Guard0502.install() end
end)

'''
if old_loader not in text:
    raise SystemExit("control 0502 loader anchor missing")
text = text.replace(old_loader, '-- Historical 0502 station-side acquisition/movement quarantine is retired and not loaded.\n\n', 1)
write(path, text)

# Remove historical command on upgrade.
path = "tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua"
text = read(path).replace('  ["tp-direct-pulse-0631"] = true,', '  ["tp-direct-pulse-0631"] = true,\n  ["tp-vanish-guard-0502"] = true,', 1)
write(path, text)

# Declarative graph: 26 active / 38 retired.
path = "tech-priests_src/scripts/core/planning_constraints_0646.lua"
text = read(path).replace('active_hardener_count=26,retired_authority_count=37', 'active_hardener_count=26,retired_authority_count=38', 1)
anchor = ' ["scripts.core.ground_route_authority_0633"]="visible route chunking is native to movement_controller and child repair loaders are explicit",'
entry = anchor + '\n ["scripts.core.priest_vanish_guard_0502"]="station-side direct acquisition and movement quarantine are obsolete under canonical 0513 and movement ownership",'
if anchor not in text:
    raise SystemExit("planning 0633 retired anchor missing")
text = text.replace(anchor, entry, 1)
write(path, text)

path = "tools/check_development_integration_0732.py"
text = read(path)
text = text.replace('    "scripts.core.direct_acquisition_recall_guard_0632", "scripts.core.ground_route_authority_0633",', '    "scripts.core.direct_acquisition_recall_guard_0632", "scripts.core.ground_route_authority_0633",\n    "scripts.core.priest_vanish_guard_0502",', 1)
text = text.replace('"retired_authority_count=37"', '"retired_authority_count=38"', 1)
text = text.replace('"check_ground_route_loader_boundary_0768.py",', '"check_ground_route_loader_boundary_0768.py", "check_priest_vanish_0502_boundary_0769.py",', 1)
text = text.replace('"movement_controller_enforcement_0566", "void_movement_authority_0630",', '"movement_controller_enforcement_0566", "void_movement_authority_0630",\n    "behavior_stack_cleanup_0509",', 1)
write(path, text)

path = "tools/check_recovery_architecture_0744.py"
text = read(path)
text = text.replace('"scripts.core.efficiency_economy_0572", "scripts.core.efficiency_economy_0577", "scripts.core.direct_acquisition_recall_guard_0632", "scripts.core.ground_route_authority_0633",', '"scripts.core.efficiency_economy_0572", "scripts.core.efficiency_economy_0577", "scripts.core.direct_acquisition_recall_guard_0632", "scripts.core.ground_route_authority_0633", "scripts.core.priest_vanish_guard_0502",', 1)
text = text.replace('"retired_authority_count=37"', '"retired_authority_count=38"', 1)
text = text.replace('"37 source-preserved authorities"', '"38 source-preserved authorities"', 1)
text = text.replace('"26 active hardeners and 37 explicitly retired"', '"26 active hardeners and 38 explicitly retired"', 1)
text = text.replace('"Thirty-seven files remain"', '"Thirty-eight files remain"', 1)
text = text.replace('active=26 retired=37 construction=canonical', 'active=26 retired=38 construction=canonical', 1)
text = text.replace(
    '("Audit retired ground route and explicit child loaders", "check_ground_route_loader_boundary_0768.py"),',
    '("Audit retired ground route and explicit child loaders", "check_ground_route_loader_boundary_0768.py"),\n        ("Audit retired 0502 vanish quarantine", "check_priest_vanish_0502_boundary_0769.py"),',
    1,
)
write(path, text)

path = "tools/check_governance_prerequisites_0738.py"
text = read(path)
for old, new in (
    ('26-active / 37-retired graph', '26-active / 38-retired graph'),
    ('26 active hardeners and 37 explicitly retired', '26 active hardeners and 38 explicitly retired'),
    ('26 active hardeners and 37 retired source-only authorities', '26 active hardeners and 38 retired source-only authorities'),
    ('37 source-preserved authorities', '38 source-preserved authorities'),
    ('37 retired source-only authorities', '38 retired source-only authorities'),
    ('Thirty-seven files remain', 'Thirty-eight files remain'),
):
    text = text.replace(old, new)
text = text.replace(
    '"Audit retired ground route and explicit child loaders",\n        "check_ground_route_loader_boundary_0768.py",',
    '"Audit retired ground route and explicit child loaders",\n        "check_ground_route_loader_boundary_0768.py",\n        "Audit retired 0502 vanish quarantine",\n        "check_priest_vanish_0502_boundary_0769.py",',
    1,
)
write(path, text)

for checker in (
    "tools/check_movement_cadence_boundary_0761.py",
    "tools/check_combat_proxy_boundary_0762.py",
    "tools/check_direct_acquisition_bounds_boundary_0764.py",
    "tools/check_movement_enforcement_void_boundary_0765.py",
    "tools/check_movement_economy_boundary_0767.py",
    "tools/check_ground_route_loader_boundary_0768.py",
):
    write(checker, read(checker).replace('retired_authority_count=37', 'retired_authority_count=38'))

write(
    "tools/check_priest_vanish_0502_boundary_0769.py",
    '''#!/usr/bin/env python3
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
 "planning":('retired_authority_count=38','["scripts.core.priest_vanish_guard_0502"]'),
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
''',
)

# Living recovery records.
write("RECOVERY_REPAIR_SEQUENCE.md", read("RECOVERY_REPAIR_SEQUENCE.md").replace('26-active / 37-retired graph', '26-active / 38-retired graph'))
path = "tech-priests_src/docs/AUTHORITY_REFACTOR_CONTINUITY.md"
text = read(path)
text = text.replace('The `RETIRED` table contains **37 source-preserved authorities**.', 'The `RETIRED` table contains **38 source-preserved authorities**.', 1)
text = text.replace('- `ground_route_authority_0633.lua`;', '- `ground_route_authority_0633.lua`;\n- `priest_vanish_guard_0502.lua`;', 1)
section = '''## Retired station-side vanish quarantine

`priest_vanish_guard_0502.lua` is retired. It may not duplicate direct acquisition, wrap movement requests, issue engine commands, own task/mode state, run a watchdog, or install commands. Missing-priest observation and controlled rescue remain with the still-active lifecycle/recovery authorities pending their consolidation.

`behavior_stack_cleanup_0509.lua` is broker-only passive maintenance for pair reverse maps and UI/cascade debounce. It no longer requires, disables, reports, or wraps `0502`, acquisition executors, or movement APIs.

'''
if '## Retired station-side vanish quarantine' not in text:
    anchor = '## Visible ground route and explicit loader authority'
    if anchor not in text: raise SystemExit('continuity route/loader anchor missing')
    text = text.replace(anchor, section + anchor, 1)
write(path, text)

path = "tech-priests_src/docs/CURRENT_TESTING_GOALS.md"
text = read(path)
text = text.replace('26 active hardeners and 37 retired source-only authorities', '26 active hardeners and 38 retired source-only authorities', 1)
anchor = '- native visible route chunking and retired-state cleanup in `movement_controller`, broker-only `0631`, inert `0632`/`0633`, and explicit `0634`–`0643` repair loaders;\n'
bullet = '- retired `priest_vanish_guard_0502` station-side acquisition/movement quarantine and broker-only passive `behavior_stack_cleanup_0509`;\n'
if bullet not in text:
    if anchor not in text: raise SystemExit('testing route/loader anchor missing')
    text = text.replace(anchor, anchor + bullet, 1)
text = text.replace('movement-economy, and ground-route/loader audits;', 'movement-economy, ground-route/loader, and retired-0502 lifecycle audits;', 1)
text = text.replace('26 attempted active hardeners and 37 retired source-only authorities', '26 attempted active hardeners and 38 retired source-only authorities', 1)
write(path, text)

path = "docs/RECOVERY_AUTHORITY_MAP_CURRENT.md"
text = read(path)
text = text.replace('**37 retired source-only authorities**', '**38 retired source-only authorities**', 1)
text = text.replace('Planning --> Retired[37 retired authorities]', 'Planning --> Retired[38 retired authorities]', 1)
text = text.replace('Thirty-seven files remain source-preserved', 'Thirty-eight files remain source-preserved', 1)
anchor = 'Visible long-route chunking is native to the movement controller. `0632` and `0633` are retired, and their formerly hidden child repair modules load explicitly.'
replacement = anchor + '\n\n`0502` is also retired: station-side acquisition, movement quarantine, and anti-slam task mutation are obsolete under the canonical executor and movement controller. `0509` remains only as broker-owned passive reverse-map and UI/cascade maintenance.'
if anchor not in text: raise SystemExit('map route/loader paragraph missing')
text = text.replace(anchor, replacement, 1)
write(path, text)

path = "docs/DEVELOPMENT_HISTORY.md"
text = read(path)
section = '''### Retired `0502` station-side acquisition and movement quarantine

`priest_vanish_guard_0502` was a historical emergency layer that duplicated direct acquisition, movement requests, engine commands, mutable task and mode fields, watchdog recovery, diagnostics, and anti-slam state. Direct acquisition and movement are now owned by `0513` and `movement_controller`; missing-priest detection and controlled rescue remain available through the still-active lifecycle authorities.

`0502` is now inert and no longer loaded. `behavior_stack_cleanup_0509` was rewritten as broker-only passive maintenance for pair reverse maps and UI/cascade debounce, removing all `0502`, direct-acquisition, movement-request, engine-command, registry, and direct-timer ownership. The graph is now **26 active hardeners and 38 explicitly retired source-only authorities**.

Complete Source validation and Factorio runtime evidence remain separately required.

'''
if '### Retired `0502` station-side acquisition and movement quarantine' not in text:
    anchor = '## Current Gate State'
    if anchor not in text: raise SystemExit('history gate anchor missing')
    text = text.replace(anchor, section + anchor, 1)
write(path, text)

Path(__file__).unlink()
