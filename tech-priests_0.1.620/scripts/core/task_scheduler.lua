-- scripts/core/task_scheduler.lua
-- Tech Priests 0.1.321 canonical scheduler / action pipeline spine.
--
-- This module is intentionally preservation-first.  It gives the mod one named
-- scheduler vocabulary, one ordered action pipeline, and one wrapping point for
-- tick_pair, but it leaves the historical behavior stack underneath unless the
-- experimental 0.1.318 pipeline is explicitly enabled by command.

local Scheduler = {}
local SupplyResolver = require("scripts.core.supply_resolver")

Scheduler.version = "0.1.445"
Scheduler.storage_key = "tech_priests_pipeline_0318"

Scheduler.priorities = {
  validate = 1000,
  combat = 900,
  repair = 800,
  consecration = 700,
  supply = 600,
  emergency = 500,
  idle = 100,
  legacy = 0
}

Scheduler.pipeline = {
  { key = "combat",       kind = "combat",        phase = "threat-response",      visual = "defending",              priority = Scheduler.priorities.combat },
  { key = "repair",       kind = "repair",        phase = "repair-service",       visual = "repairing",              priority = Scheduler.priorities.repair },
  { key = "consecration", kind = "consecration",  phase = "sanctification",       visual = "consecrating",           priority = Scheduler.priorities.consecration },
  { key = "cram",         kind = "supply",        phase = "station-cram",         visual = "cramming-supplies",      priority = Scheduler.priorities.supply },
  { key = "scavenge",     kind = "supply",        phase = "scavenge",             visual = "scavenging-supplies",    priority = Scheduler.priorities.supply - 10 },
  { key = "logistics",    kind = "supply",        phase = "logistics-request",    visual = "missing-supplies",       priority = Scheduler.priorities.supply - 20 },
  { key = "emergency",    kind = "emergency",     phase = "emergency-operation",  visual = "emergency-operation",    priority = Scheduler.priorities.emergency },
  { key = "idle",         kind = "idle",          phase = "idle",                 visual = "idle",                   priority = Scheduler.priorities.idle }
}

local function g(name)
  return rawget(_G, name)
end

local function callable(name)
  local fn = g(name)
  if type(fn) == "function" then return fn end
  return nil
end

local function safe_call(name, ...)
  local fn = callable(name)
  if not fn then return false, nil end
  local ok, result = pcall(fn, ...)
  return ok, result
end

local function now()
  return game and game.tick or 0
end

local function valid_entity(entity)
  return entity and entity.valid
end

function Scheduler.ensure_root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[Scheduler.storage_key] = storage.tech_priests[Scheduler.storage_key] or {
    version = Scheduler.version,
    enabled = false,
    dry_run = true,
    created_tick = now(),
    wrapped = true,
    stats = {}
  }
  local root = storage.tech_priests[Scheduler.storage_key]
  root.version = Scheduler.version
  root.stats = root.stats or {}
  return root
end

function Scheduler.is_enabled()
  local root = Scheduler.ensure_root()
  return root.enabled == true
end

function Scheduler.set_enabled(value)
  local root = Scheduler.ensure_root()
  root.enabled = value == true
  root.dry_run = not root.enabled
  root.changed_tick = now()
  return root.enabled
end

local function pair_shape_ok(pair)
  -- LuaEntity/userdata subjects can leak in through older wrapper signatures.
  -- Never index them as station/priest pair tables; Factorio raises hard errors
  -- such as "LuaEntity doesn't contain key priest" on missing userdata fields.
  return type(pair) == "table"
end

local function legacy_shape_drift_error(err)
  local text = tostring(err or "")
  return text:find("LuaEntity doesn't contain key priest", 1, true)
      or text:find("LuaEntity doesn't contain key station", 1, true)
      or text:find("LuaEntity doesn't contain key scheduler_0318", 1, true)
end

function Scheduler.valid_pair(pair)
  if not pair then return false, "nil-pair" end
  if not pair_shape_ok(pair) then return false, "bad-pair-shape:" .. tostring(pair) end
  if not valid_entity(pair.station) then return false, "invalid-station" end
  if not valid_entity(pair.priest) then return false, "invalid-priest" end
  return true, nil
end

function Scheduler.pair_label(pair)
  if not pair then return "nil-pair" end
  local station = pair.station
  local unit = pair.station_unit or (station and station.valid and station.unit_number) or "?"
  local name = pair.station_display_name or pair.display_name or pair.priest_display_name or "unnamed"
  return tostring(name) .. "#" .. tostring(unit)
end

function Scheduler.ensure_pair_state(pair)
  if not pair_shape_ok(pair) then return nil end
  pair.scheduler_0318 = pair.scheduler_0318 or {}
  local state = pair.scheduler_0318
  state.version = Scheduler.version
  state.last_seen_tick = now()
  state.pipeline = state.pipeline or {}
  return state
end

function Scheduler.get_active_task(pair)
  if not pair then return nil end
  return pair.active_task or pair.active_task_0285 or nil
end

function Scheduler.set_visual(pair, task, reason)
  if not (pair and task) then return end
  local kind = task.kind or task.type or "idle"
  local phase = task.phase or task.key or kind
  local visual = task.visual or task.mode or phase
  local target = task.target
  local owner = task.owner_system or reason or "scheduler-0318"

  local setter = callable("tech_priests_set_pair_task_0276")
  if setter then
    pcall(setter, pair, kind, phase, visual, target, owner)
  else
    pair.task_kind_0276 = kind
    pair.task_phase_0276 = phase
    pair.visual_state_0276 = visual
    pair.task_owner_0276 = owner
    if target ~= nil then pair.target = target end
    pair.mode = visual
  end
end

function Scheduler.assign_task(pair, task, reason)
  if not (pair and task) then return false end
  task.type = task.type or task.kind or "idle"
  task.kind = task.kind or task.type
  task.phase = task.phase or task.key or task.type
  task.priority = task.priority or Scheduler.priorities[task.type] or task.priority or 0
  task.owner_system = task.owner_system or reason or "scheduler-0318"
  task.updated_tick = now()
  task.started_tick = task.started_tick or task.updated_tick

  local assign = callable("tech_priests_0285_assign_task")
  if assign and task.type ~= "idle" then
    local ok, result = pcall(assign, pair, task, reason or "scheduler-0318")
    if ok and result then return true end
  end

  pair.active_task = task.type ~= "idle" and task or nil
  pair.active_task_0285 = pair.active_task
  Scheduler.set_visual(pair, task, reason)
  local gov = rawget(_G, "TECH_PRIESTS_TASK_TRANSITION_GOVERNOR_0445")
  if gov and gov.observe then pcall(gov.observe, pair, "scheduler-assign-task") end
  return true
end

function Scheduler.cancel_task(pair, reason)
  if not pair then return false end
  local cancel = callable("tech_priests_0285_cancel_task")
  if cancel then
    local ok, result = pcall(cancel, pair, reason or "scheduler-0318-cancel")
    if ok then return result end
  end
  pair.previous_task_0318 = pair.active_task or pair.active_task_0285
  pair.active_task = nil
  pair.active_task_0285 = nil
  pair.last_task_cancel_reason_0318 = reason
  pair.last_task_cancel_tick_0318 = now()
  return true
end

function Scheduler.infer_legacy_task(pair)
  if not pair then return nil end

  local infer = callable("tech_priests_0286_infer_legacy_task")
  if infer then
    local ok, result = pcall(infer, pair)
    if ok and result then return result end
  end

  if pair.scavenge then
    return { type = "supply", kind = "supply", phase = "scavenge", key = "scavenge", item = pair.scavenge.item_name, target = pair.scavenge.source, visual = pair.mode or "scavenging-supplies", priority = Scheduler.priorities.supply - 10, owner_system = "legacy-surface-0318" }
  end
  if pair.cram then
    return { type = "supply", kind = "supply", phase = "station-cram", key = "cram", visual = pair.mode or "cramming-supplies", priority = Scheduler.priorities.supply, owner_system = "legacy-surface-0318" }
  end
  if pair.emergency_craft then
    return { type = "emergency", kind = "emergency", phase = "emergency-craft", key = "emergency", item = pair.emergency_craft.item_name or pair.emergency_craft.output_item, visual = pair.mode or "emergency-operation", priority = Scheduler.priorities.emergency, owner_system = "legacy-surface-0318" }
  end
  if pair.logistic_requested_item then
    return { type = "supply", kind = "supply", phase = "logistics-request", key = "logistics", item = pair.logistic_requested_item, count = pair.logistic_requested_count or 1, visual = pair.mode or "missing-supplies", priority = Scheduler.priorities.supply - 20, owner_system = "legacy-surface-0318" }
  end
  if pair.task_kind_0276 and pair.task_kind_0276 ~= "idle" then
    return { type = pair.task_kind_0276, kind = pair.task_kind_0276, phase = pair.task_phase_0276 or pair.mode, key = pair.task_kind_0276, target = pair.target, visual = pair.visual_state_0276 or pair.mode, priority = Scheduler.priorities[pair.task_kind_0276] or 0, owner_system = pair.task_owner_0276 or "legacy-task-0276" }
  end

  return nil
end

function Scheduler.reconcile(pair, stage)
  local ok, reason = Scheduler.valid_pair(pair)
  if not ok then return false, reason end
  local state = Scheduler.ensure_pair_state(pair)
  state.last_reconcile_stage = stage or "unspecified"
  state.last_reconcile_tick = now()

  local task = Scheduler.get_active_task(pair)
  if not task then
    local legacy = Scheduler.infer_legacy_task(pair)
    if legacy then
      pair.active_task = legacy
      pair.active_task_0285 = legacy
      state.adopted_legacy_count = (state.adopted_legacy_count or 0) + 1
      state.last_adopted_legacy_tick = now()
    end
  else
    task.type = task.type or task.kind or "unknown"
    task.kind = task.kind or task.type
    task.phase = task.phase or task.key or task.type
    task.updated_tick = now()
  end

  return true, nil
end

function Scheduler.try_combat(pair)
  local handle = callable("handle_combat")
  if not handle then return false end
  local ok, handled = pcall(handle, pair)
  if ok and handled then
    Scheduler.assign_task(pair, { type = "combat", kind = "combat", phase = "threat-response", key = "combat", visual = pair.mode or "defending", target = pair.target, priority = Scheduler.priorities.combat }, "pipeline-0318-combat")
    return true
  end
  return false
end

function Scheduler.try_repair(pair)
  local find = callable("find_damaged_target")
  local repair = callable("repair_target")
  local has_pack = callable("station_has_repair_pack")
  if not (find and repair and has_pack) then return false end
  local has_ok, has = pcall(has_pack, pair.station)
  if not (has_ok and has) then return false end
  local target = pair.target
  if not (target and target.valid and target.health and target.max_health and target.health < target.max_health) then
    local radius = pair.radius or 0
    local ok_find, found = pcall(find, pair.station, radius, pair.priest)
    if ok_find then target = found end
  end
  if not (target and target.valid) then return false end
  local ok_repair, handled = pcall(repair, pair, target)
  if ok_repair and handled ~= false then
    Scheduler.assign_task(pair, { type = "repair", kind = "repair", phase = "repair-service", key = "repair", visual = pair.mode or "repairing", target = target, priority = Scheduler.priorities.repair }, "pipeline-0318-repair")
    return true
  end
  return false
end

function Scheduler.try_consecration(pair)
  local find = callable("find_consecration_target_for_station")
  local sanctify = callable("sanctify_target_with_priest")
  if not (find and sanctify) then return false end
  local target = pair.target
  if not (target and target.valid) then
    local ok_find, found = pcall(find, pair.station, pair.radius or 0, pair.priest)
    if ok_find then target = found end
  end
  if not (target and target.valid) then return false end
  local ok_sanctify, handled = pcall(sanctify, pair, target)
  if ok_sanctify and handled then
    Scheduler.assign_task(pair, { type = "consecration", kind = "consecration", phase = "sanctification", key = "consecration", visual = pair.mode or "consecrating", target = target, priority = Scheduler.priorities.consecration }, "pipeline-0318-consecration")
    return true
  end
  return false
end

function Scheduler.try_supply(pair)
  if SupplyResolver and SupplyResolver.classify then
    pcall(function() SupplyResolver.classify(pair) end)
  end

  if SupplyResolver and SupplyResolver.try_supply then
    local ok, handled, phase = pcall(function()
      return SupplyResolver.try_supply(pair, pair and pair.logistic_frustration_kind or nil, pair and pair.target or nil)
    end)
    if ok and handled then
      Scheduler.assign_task(pair, {
        type = "supply",
        kind = "supply",
        phase = phase or (pair and pair.mode) or "supply",
        key = phase or "supply",
        item = pair and (pair.logistic_requested_item or (pair.scavenge and pair.scavenge.item_name) or (pair.inventory_scan and pair.inventory_scan.item_name)),
        target = pair and (pair.target or (pair.scavenge and pair.scavenge.source)),
        visual = pair and pair.mode or "missing-supplies",
        priority = Scheduler.priorities.supply
      }, "pipeline-0321-supply-resolver")
      return true
    end
  end

  -- Legacy fallback path retained for inactive resolver mode and unexpected module failures.
  if pair.cram then
    local fn = callable("handle_priest_cram_task")
    if fn then
      local ok, handled = pcall(fn, pair)
      if ok and handled then
        Scheduler.assign_task(pair, { type = "supply", kind = "supply", phase = "station-cram", key = "cram", visual = pair.mode or "cramming-supplies", priority = Scheduler.priorities.supply }, "pipeline-0321-cram-fallback")
        return true
      end
    end
  end

  if pair.scavenge then
    local fn = callable("handle_priest_scavenge_task")
    if fn then
      local ok, handled = pcall(fn, pair)
      if ok and handled then
        Scheduler.assign_task(pair, { type = "supply", kind = "supply", phase = "scavenge", key = "scavenge", item = pair.scavenge and pair.scavenge.item_name, target = pair.scavenge and pair.scavenge.source, visual = pair.mode or "scavenging-supplies", priority = Scheduler.priorities.supply - 10 }, "pipeline-0321-scavenge-fallback")
        return true
      end
    end
  end

  if pair.logistic_requested_item then
    local scan = callable("handle_logistic_inventory_scan")
    if scan then
      local ok, handled = pcall(scan, pair)
      if ok and handled then
        Scheduler.assign_task(pair, { type = "supply", kind = "supply", phase = "logistics-request", key = "logistics", item = pair.logistic_requested_item, count = pair.logistic_requested_count or 1, visual = pair.mode or "missing-supplies", priority = Scheduler.priorities.supply - 20 }, "pipeline-0321-logistics-fallback")
        return true
      end
    end
  end

  return false
end

function Scheduler.try_emergency(pair)
  local fn = callable("handle_emergency_desperation_craft")
  if not (fn and pair.emergency_craft) then return false end
  local ok, handled = pcall(fn, pair)
  if ok and handled then
    Scheduler.assign_task(pair, { type = "emergency", kind = "emergency", phase = "emergency-operation", key = "emergency", item = pair.emergency_craft and (pair.emergency_craft.item_name or pair.emergency_craft.output_item), visual = pair.mode or "emergency-operation", priority = Scheduler.priorities.emergency }, "pipeline-0318-emergency")
    return true
  end
  return false
end

function Scheduler.try_pipeline(pair)
  local ok, reason = Scheduler.valid_pair(pair)
  if not ok then return false, reason end

  if Scheduler.try_combat(pair) then return true, "combat" end
  if Scheduler.try_repair(pair) then return true, "repair" end
  if Scheduler.try_consecration(pair) then return true, "consecration" end
  if Scheduler.try_supply(pair) then return true, "supply" end
  if Scheduler.try_emergency(pair) then return true, "emergency" end

  return false, "no-claim"
end

function Scheduler.tick_pair(pair, legacy_tick)
  local valid_pair_ok, valid_pair_reason = Scheduler.valid_pair(pair)
  if not valid_pair_ok then
    local root = Scheduler.ensure_root()
    root.stats.bad_pair_shape_skips = (root.stats.bad_pair_shape_skips or 0) + 1
    root.last_bad_pair_shape_reason = tostring(valid_pair_reason)
    root.last_bad_pair_shape_tick = now()
    return false, valid_pair_reason
  end

  local state = Scheduler.ensure_pair_state(pair)
  if state then state.last_tick = now() end

  Scheduler.reconcile(pair, "before-legacy")

  if Scheduler.is_enabled() then
    local claimed, key = Scheduler.try_pipeline(pair)
    if state then
      state.last_pipeline_claim = key
      state.last_pipeline_claim_tick = now()
    end
    if claimed then
      Scheduler.reconcile(pair, "after-pipeline-claim")
      return true
    end
  end

  local result = nil
  if type(legacy_tick) == "function" then
    local ok, legacy_result = pcall(legacy_tick, pair)
    if ok then
      result = legacy_result
    else
      if state then
        state.last_legacy_error = tostring(legacy_result)
        state.last_legacy_error_tick = now()
      end
      if legacy_shape_drift_error(legacy_result) then
        local root = Scheduler.ensure_root()
        root.stats.legacy_shape_drift_quarantined = (root.stats.legacy_shape_drift_quarantined or 0) + 1
        root.last_legacy_shape_drift_error = tostring(legacy_result)
        root.last_legacy_shape_drift_tick = now()
        if log then log("[Tech-Priests 0.1.441] quarantined legacy pair-shape drift in tick_pair: " .. tostring(legacy_result)) end
        return false, "legacy-shape-drift-quarantined"
      end
      error(legacy_result)
    end
  end

  Scheduler.reconcile(pair, "after-legacy")
  return result
end

function Scheduler.behavior_ownership_report(pair)
  local tree = rawget(_G, "TECH_PRIESTS_SCHEDULER_BEHAVIOR_TREE_0361")
  if tree and type(tree.describe_pair) == "function" then
    local ok, lines = pcall(tree.describe_pair, pair)
    if ok and lines then return lines end
  end
  return { "Scheduler behavior tree module not installed." }
end

function Scheduler.command_status(player)
  local root = Scheduler.ensure_root()
  local msg = "[Tech Priests 0.1.321] pipeline=" .. (root.enabled and "enabled" or "observe-only") .. " dry_run=" .. tostring(root.dry_run)
  if player and player.valid and player.print then player.print(msg) elseif game and game.print then game.print(msg) end
end

function Scheduler.register_commands()
  if not (commands and commands.add_command) then return end
  pcall(function()
    commands.add_command("tp-pipeline-0318", "Tech Priests: inspect or enable the unified action pipeline. Usage: /tp-pipeline-0318 status|enable|disable", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      local parameter = event and event.parameter or "status"
      parameter = tostring(parameter or "status")
      if parameter == "enable" then
        Scheduler.set_enabled(true)
      elseif parameter == "disable" then
        Scheduler.set_enabled(false)
      end
      Scheduler.command_status(player)
    end)
  end)
end

return Scheduler
