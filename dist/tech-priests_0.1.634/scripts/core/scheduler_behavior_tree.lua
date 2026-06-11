-- scripts/core/scheduler_behavior_tree.lua
-- Tech Priests 0.1.361 scheduler behavior tree / ownership map.
--
-- Purpose:
--   This module does not take over gameplay execution yet.  It folds the
--   current scheduler, station-bound inventory doctrine, construction,
--   acquisition, emergency facility, consecration, catalog, chatter, and
--   arterial planning modules into one visible behavior-tree map so future
--   cleanup can move behavior by explicit ownership instead of by guesswork.
--
-- Standards:
--   * No large control.lua bodies.
--   * No new main-chunk locals in control.lua.
--   * Diagnostics first; mutation only through existing owning modules.
--   * Chatter/visuals remain non-mutating.

local M = {}
M.version = "0.1.361"
M.storage_key = "scheduler_behavior_tree_0361"

local function valid(entity)
  return entity and entity.valid
end

local function now()
  return game and game.tick or 0
end

local function pair_map()
  return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
end

local function safe_tostring(value)
  local ok, result = pcall(function() return tostring(value) end)
  if ok then return result end
  return "?"
end

local function station_unit(pair)
  if not pair then return nil end
  return pair.station_unit or (valid(pair.station) and pair.station.unit_number) or nil
end

local function entity_label(entity)
  if not valid(entity) then return "invalid" end
  return safe_tostring(entity.backer_name or entity.name or entity.unit_number or "entity") .. "#" .. safe_tostring(entity.unit_number or "?")
end

local function station_label(pair)
  if not pair then return "no pair" end
  if valid(pair.station) then return entity_label(pair.station) end
  return "station#" .. safe_tostring(pair.station_unit or "?")
end

local function priest_label(pair)
  if not pair then return "no pair" end
  if valid(pair.priest) then return entity_label(pair.priest) end
  return "priest#" .. safe_tostring(pair.priest_unit or "?")
end

local function safe_require(name)
  local ok, mod = pcall(require, name)
  if ok then return mod end
  return nil
end

local function scheduler_root()
  local Scheduler = safe_require("scripts.core.task_scheduler")
  if Scheduler and Scheduler.ensure_root then
    local ok, root = pcall(Scheduler.ensure_root)
    if ok then return Scheduler, root end
  end
  return Scheduler, nil
end

local function relation_summary(pair)
  local out = { superior = nil, juniors = 0, peers = 0 }
  if not (pair and valid(pair.station)) then return out end
  local rank = tonumber(pair.rank or pair.station_rank) or 1
  local radius = tonumber(pair.radius or 36) or 36
  if _G.get_station_operating_radius then
    local ok, r = pcall(_G.get_station_operating_radius, pair.station)
    if ok and tonumber(r) then radius = tonumber(r) end
  end
  local best_superior_rank = -1
  for _, other in pairs(pair_map()) do
    if other ~= pair and other and valid(other.station) and other.station.surface == pair.station.surface then
      local dx = (other.station.position.x or 0) - (pair.station.position.x or 0)
      local dy = (other.station.position.y or 0) - (pair.station.position.y or 0)
      local d = dx * dx + dy * dy
      if d <= radius * radius * 4 then
        local orank = tonumber(other.rank or other.station_rank) or 1
        if orank > rank and orank > best_superior_rank then
          out.superior = other
          best_superior_rank = orank
        elseif orank < rank then
          out.juniors = out.juniors + 1
        elseif orank == rank then
          out.peers = out.peers + 1
        end
      end
    end
  end
  return out
end

M.behavior_tree = {
  {
    key = "validate-pair",
    priority = 1000,
    trigger = "Every scheduler pulse / pair tick.",
    decision_owner = "control.lua lifecycle spine + task_scheduler.lua",
    executor_owner = "pair spawning / respawn / reimprint legacy functions",
    fallback = "Respawn/reimprint priest or skip invalid pair safely.",
    mutates = true,
  },
  {
    key = "combat-defense",
    priority = 900,
    trigger = "Hostile target inside station or station-network range.",
    decision_owner = "combat_safety.lua + legacy combat scanner",
    executor_owner = "combat/proxy attack legacy executor",
    fallback = "Reject same-force/allied/neutral targets and resume previous work.",
    mutates = true,
  },
  {
    key = "repair-service",
    priority = 800,
    trigger = "Friendly machine/station/priest damage and repair supplies available.",
    decision_owner = "legacy repair target finder, scheduled by task_scheduler.lua",
    executor_owner = "legacy repair executor / priest movement layer",
    fallback = "If no repair pack or no path, report missing repair supply and resume.",
    mutates = true,
  },
  {
    key = "active-work-continuation",
    priority = 760,
    trigger = "Pair already has active task/request/direct acquisition/build/craft phase.",
    decision_owner = "task_scheduler.lua reconciliation + executor-specific task records",
    executor_owner = "acquisition_executor.lua, crafting_executor.lua, construction_planner.lua",
    fallback = "Replan stale phase or surface blocker in scheduler audit.",
    mutates = true,
  },
  {
    key = "station-bound-inventory-cleanup",
    priority = 740,
    trigger = "Priest has accidental cargo, output needs storage, or station storage is full.",
    decision_owner = "station_work_inventory.lua + inventory_steward.lua",
    executor_owner = "inventory_steward.lua",
    fallback = "Station/stash/friendly storage -> craft chest -> remembered floor cram only at desperation tier.",
    mutates = true,
  },
  {
    key = "emergency-facility-doctrine",
    priority = 720,
    trigger = "Station lacks primitive capability: ore, plates, fuel, power, smelting, crafting, research.",
    decision_owner = "emergency_facility_doctrine.lua",
    executor_owner = "construction_planner.lua + facility feed/use handlers",
    fallback = "Request missing Martian equipment; fall back to primitive acquisition if equipment unavailable.",
    mutates = true,
  },
  {
    key = "acquisition-doctrine",
    priority = 700,
    trigger = "Station request requires item not available in station/stash/facility inventory.",
    decision_owner = "resource_doctrine.lua + acquisition_repair.lua + acquisition_unstick.lua",
    executor_owner = "acquisition_executor.lua",
    fallback = "Known catalog -> mineable source -> recipe dependency -> primitive fallback -> true desperation.",
    mutates = true,
  },
  {
    key = "construction-placement",
    priority = 680,
    trigger = "Station-bound inventory contains placeable item or arterial planner emits build/ghost need.",
    decision_owner = "construction_planner.lua + construction_site_planner.lua",
    executor_owner = "construction_planner.lua",
    fallback = "Report no build site/no path/deferred network item; do not use priest inventory as stock.",
    mutates = true,
  },
  {
    key = "consecration-service",
    priority = 650,
    trigger = "Machine sanctity below service threshold or player uses oil/litany/appeasement.",
    decision_owner = "consecration module family + priest service scanner",
    executor_owner = "scripts/core/consecration/*.lua + priest service wrapper",
    fallback = "Report no consecration item or unsupported target; incense remains cloud-based.",
    mutates = true,
  },
  {
    key = "arterial-planning",
    priority = 500,
    trigger = "Planetary Magos / superior station planning request, science demand, or player station GUI request.",
    decision_owner = "arterial_planner.lua + future material planner",
    executor_owner = "arterial_planner.lua for ghosts; construction_planner.lua for physical placement",
    fallback = "Plan one machine/belt/pole at a time; defer rails/drones/roboports/pipes until routed submodules exist.",
    mutates = true,
  },
  {
    key = "station-catalog-refresh",
    priority = 300,
    trigger = "Radar sweep cadence or explicit station catalog refresh.",
    decision_owner = "station_catalog.lua",
    executor_owner = "station_catalog.lua",
    fallback = "Remove stale claims; never catalog belt contents except true desperation sampling elsewhere.",
    mutates = true,
  },
  {
    key = "background-chatter",
    priority = 120,
    trigger = "Background interval or direct player tap on priest.",
    decision_owner = "chatter.lua",
    executor_owner = "chatter.lua",
    fallback = "Busy rejection bubble; never interrupts work state.",
    mutates = false,
  },
  {
    key = "idle-flavor",
    priority = 100,
    trigger = "No higher-priority work claimed.",
    decision_owner = "legacy idle behavior + chatter.lua",
    executor_owner = "idle/conversation modules",
    fallback = "Wait at station; do not mask a blocked higher-priority task.",
    mutates = false,
  },
}

local key_lookup = nil
local function by_key()
  if key_lookup then return key_lookup end
  key_lookup = {}
  for _, row in ipairs(M.behavior_tree) do key_lookup[row.key] = row end
  return key_lookup
end

local function task_snapshot(pair)
  if not pair then return "none", nil end
  local candidates = {
    { "active_task", pair.active_task },
    { "active_task_0285", pair.active_task_0285 },
    { "direct_acquisition_task_0336", pair.direct_acquisition_task_0336 },
    { "station_crafting_task_0337", pair.station_crafting_task_0337 },
    { "construction_task_0338/0359", pair.construction_task_0338 or pair.construction_task_0359 },
    { "emergency_operation", pair.emergency_operation or pair.independent_emergency_operation },
    { "scavenge", pair.scavenge },
    { "cram", pair.cram },
    { "logistic_requested_item", pair.logistic_requested_item },
  }
  for _, rec in ipairs(candidates) do
    if rec[2] then return rec[1], rec[2] end
  end
  return "none", nil
end

local function infer_behavior_key(pair)
  if not pair then return "validate-pair", "no pair" end
  if not valid(pair.station) or not valid(pair.priest) then return "validate-pair", "invalid station/priest" end
  if pair.direct_acquisition_task_0336 or pair.scavenge or pair.logistic_requested_item then return "acquisition-doctrine", "active acquisition/supply request" end
  if pair.construction_task_0338 or pair.construction_task_0359 or pair.construction_task then return "construction-placement", "active construction task" end
  if pair.station_crafting_task_0337 or pair.emergency_craft then return "emergency-facility-doctrine", "craft/facility work" end
  if pair.build_preempts_acquisition_until_0342 and pair.build_preempts_acquisition_until_0342 > now() then return "construction-placement", "construction preempted acquisition" end
  if pair.mode == "defending" or pair.mode == "combat" or pair.mode == "moving-to-combat" then return "combat-defense", "combat-like mode" end
  if pair.mode == "consecrating" or pair.task_kind_0276 == "consecration" then return "consecration-service", "consecration visual/task" end
  if pair.mode == "repairing" or pair.task_kind_0276 == "repair" then return "repair-service", "repair visual/task" end
  if pair.active_task or pair.active_task_0285 then return "active-work-continuation", "generic active task" end
  return "idle-flavor", "no active task visible"
end

local function summarize_blocker(pair, key, task_name, task)
  if not pair then return "no pair" end
  if not valid(pair.station) then return "station invalid/missing" end
  if not valid(pair.priest) then return "priest invalid/missing" end
  if key == "construction-placement" then
    if not (task or pair.construction_task_0338 or pair.construction_task_0359) then return "no construction task record; station may not have detected buildable stock" end
  end
  if key == "acquisition-doctrine" then
    if pair.logistic_requested_item then return "requesting " .. safe_tostring(pair.logistic_requested_item) .. "; check station sources/catalog/executor phase" end
    if pair.scavenge and pair.scavenge.item_name then return "scavenging " .. safe_tostring(pair.scavenge.item_name) end
  end
  if task_name ~= "none" then return "none reported by audit; executor owns next phase" end
  return "none; idle or awaiting scheduler claim"
end

function M.current_behavior(pair)
  local key, reason = infer_behavior_key(pair)
  local row = by_key()[key] or by_key()["idle-flavor"]
  local task_name, task = task_snapshot(pair)
  return {
    key = key,
    reason = reason,
    row = row,
    task_name = task_name,
    task = task,
    blocker = summarize_blocker(pair, key, task_name, task),
  }
end

function M.describe_pair(pair)
  local Scheduler, root = scheduler_root()
  local current = M.current_behavior(pair)
  local row = current.row or {}
  local rel = relation_summary(pair)
  local lines = {}
  lines[#lines+1] = "Scheduler behavior tree 0.1.361"
  lines[#lines+1] = "Station: " .. station_label(pair)
  lines[#lines+1] = "Priest: " .. priest_label(pair)
  lines[#lines+1] = "Scheduler pipeline: " .. safe_tostring(root and (root.enabled and "enabled" or "observe-only") or "unavailable")
  lines[#lines+1] = "Current behavior: " .. safe_tostring(current.key) .. " (" .. safe_tostring(current.reason) .. ")"
  lines[#lines+1] = "Priority: " .. safe_tostring(row.priority or "?")
  lines[#lines+1] = "Decision owner: " .. safe_tostring(row.decision_owner or "?")
  lines[#lines+1] = "Executor owner: " .. safe_tostring(row.executor_owner or "?")
  lines[#lines+1] = "Task record: " .. safe_tostring(current.task_name)
  lines[#lines+1] = "Current blocker: " .. safe_tostring(current.blocker)
  lines[#lines+1] = "Fallback: " .. safe_tostring(row.fallback or "?")
  lines[#lines+1] = "Superior: " .. (rel.superior and station_label(rel.superior) or "none") .. " | juniors=" .. safe_tostring(rel.juniors) .. " | peers=" .. safe_tostring(rel.peers)
  lines[#lines+1] = "Doctrine: station owns inventory/tasks/facilities; priest is actuator and transient carrier only."
  if Scheduler and Scheduler.pipeline then
    lines[#lines+1] = "Legacy scheduler pipeline stages: " .. safe_tostring(#Scheduler.pipeline)
  end
  return lines
end

function M.ownership_rows()
  local rows = {}
  for _, row in ipairs(M.behavior_tree) do rows[#rows+1] = row end
  table.sort(rows, function(a, b) return (a.priority or 0) > (b.priority or 0) end)
  return rows
end

local function selected_pair(player)
  if not (player and player.valid) then return nil end
  local selected = player.selected
  if selected and selected.valid and _G.find_pair_for_entity then
    local ok, pair = pcall(_G.find_pair_for_entity, selected)
    if ok and pair then return pair end
  end
  for _, pair in pairs(pair_map()) do
    if pair and (pair.station == selected or pair.priest == selected) then return pair end
  end
  return nil
end

function M.print_status(player, pair)
  local lines = M.describe_pair(pair)
  for _, line in ipairs(lines) do
    if player and player.valid then player.print("[tp-scheduler-0361] " .. line) end
  end
end


local function safe_write_file_0462(filename, data, append, for_player)
  if helpers then
    local ok_get, writer = pcall(function() return helpers.write_file end)
    if ok_get and writer then
      local ok_write = pcall(function() writer(filename, data, append or false, for_player) end)
      if ok_write then return true end
    end
  end
  if game then
    local ok_get, writer = pcall(function() return game.write_file end)
    if ok_get and writer then
      local ok_write = pcall(function() writer(filename, data, append or false, for_player) end)
      if ok_write then return true end
    end
  end
  return false
end

function M.write_report(player, pair)
  local lines = {}
  lines[#lines+1] = "Tech Priests 0.1.361 Scheduler Behavior Tree Audit"
  lines[#lines+1] = "Tick: " .. safe_tostring(now())
  lines[#lines+1] = ""
  for _, line in ipairs(M.describe_pair(pair)) do lines[#lines+1] = line end
  lines[#lines+1] = ""
  lines[#lines+1] = "Master ownership rows:"
  for _, row in ipairs(M.ownership_rows()) do
    lines[#lines+1] = "- " .. safe_tostring(row.key) .. " | priority " .. safe_tostring(row.priority) .. " | decision=" .. safe_tostring(row.decision_owner) .. " | executor=" .. safe_tostring(row.executor_owner)
  end
  local ok = safe_write_file_0462("tech-priests-scheduler-behavior-tree-0361.txt", table.concat(lines, "\n"), false)
  if player and player.valid then
    if ok then player.print("[tp-scheduler-0361] wrote script-output/tech-priests-scheduler-behavior-tree-0361.txt")
    else player.print("[tp-scheduler-0361] failed to write script-output/tech-priests-scheduler-behavior-tree-0361.txt; file writer unavailable") end
  end
  return ok
end

function M.install_commands()
  if not (commands and commands.add_command) then return end
  pcall(function() commands.remove_command("tp-scheduler-0361") end)
  commands.add_command("tp-scheduler-0361", "Tech Priests 0.1.361 scheduler behavior tree audit. Usage: /tp-scheduler-0361 status|tree|write", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local parameter = tostring(event and event.parameter or "status")
    local pair = selected_pair(player)
    if not pair and player and player.valid then
      player.print("[tp-scheduler-0361] select a Cogitator Station or Tech-Priest for pair-specific audit.")
    end
    if parameter == "tree" then
      if player and player.valid then
        for _, row in ipairs(M.ownership_rows()) do
          player.print("[tp-scheduler-0361] " .. safe_tostring(row.priority) .. " " .. safe_tostring(row.key) .. " -> " .. safe_tostring(row.decision_owner))
        end
      end
      return
    elseif parameter == "write" then
      M.write_report(player, pair)
      return
    end
    M.print_status(player, pair)
  end)
end

function M.install()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or { version = M.version, installed_tick = now() }
  storage.tech_priests[M.storage_key].version = M.version
  _G.TECH_PRIESTS_SCHEDULER_BEHAVIOR_TREE_0361 = M
  _G.tech_priests_0361_describe_scheduler_state = M.describe_pair
  _G.tech_priests_0361_current_behavior = M.current_behavior
  _G.tech_priests_0361_behavior_tree_rows = M.ownership_rows
  M.install_commands()
  if log then log("[Tech-Priests 0.1.361] scheduler behavior tree / ownership map loaded") end
  return true
end

return M
