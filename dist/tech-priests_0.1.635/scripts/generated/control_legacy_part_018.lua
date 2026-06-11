-- Auto-split control.lua fragment 018 for Tech Priests 0.1.438.
-- Generated mechanically from 0.1.437 monolithic control.lua.
-- Purpose: reduce Lua main-chunk local/register pressure without deleting behavior.

TECH_PRIESTS_0285_TASK_PRIORITY = {
  combat = 100,
  repair = 90,
  consecration = 80,
  logistics = 70,
  assignment = 60,
  emergency_craft = 50,
  scavenge = 40,
  idle = 0
}
TECH_PRIESTS_0286_RECONCILE_INTERVAL = 30
TECH_PRIESTS_0284_MAX_FANOUT_ASSIGNMENTS = 4

function tech_priests_0286_now()
  return game and game.tick or 0
end

function tech_priests_0286_valid_pair(pair)
  return pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid
end

function tech_priests_0286_station_unit(pair)
  return pair and pair.station and pair.station.valid and pair.station.unit_number or nil
end

function tech_priests_0285_task_priority(task)
  if not task then return -1 end
  return task.priority or TECH_PRIESTS_0285_TASK_PRIORITY[task.type or task.kind or "idle"] or 0
end

function tech_priests_0285_task_target_valid(pair, task)
  local target = task and task.target
  if not target then return true end
  if type(target) == "table" and target.valid == false then return false end
  if type(target) == "table" and target.valid and tech_priests_radar_entity_inside_station_0278 then
    return tech_priests_radar_entity_inside_station_0278(pair, target)
  end
  return true
end

function tech_priests_0285_validate_task(pair, task)
  if not tech_priests_0286_valid_pair(pair) then return false, "invalid-pair" end
  if not task then return false, "nil-task" end
  task.type = task.type or task.kind or "idle"
  if task.expires_tick and tech_priests_0286_now() > task.expires_tick then return false, "expired" end
  if not tech_priests_0285_task_target_valid(pair, task) then return false, "target-invalid" end
  if task.type == "repair" and task.target then
    local t = task.target
    if not (t.valid and t.health and t.max_health and t.health > 0 and t.health < t.max_health) then return false, "repair-target-not-damaged" end
  elseif task.type == "consecration" and task.target and tech_priests_radar_target_needs_consecration_0282 then
    if not tech_priests_radar_target_needs_consecration_0282(task.target) then return false, "consecration-target-clean" end
  elseif task.type == "scavenge" and task.source then
    if not (task.source.valid and (not tech_priests_radar_entity_inside_station_0278 or tech_priests_radar_entity_inside_station_0278(pair, task.source))) then return false, "scavenge-source-invalid" end
  elseif task.type == "assignment" and task.assignment then
    if task.assignment.status and task.assignment.status ~= "active" then return false, "assignment-not-active" end
  end
  return true, "ok"
end

function tech_priests_0285_clear_legacy_task_surfaces(pair, reason)
  if not pair then return end
  pair.target = nil
  pair.scavenge = nil
  pair.cram = nil
  pair.inventory_scan = nil
  pair.next_scavenge_search_tick = nil
  pair.last_scheduler_priority_0277 = nil
  pair.task_kind = nil
  pair.task_phase = nil
  pair.task_target = nil
  pair.visual_state = nil
  if pair.emergency_craft then
    pair.emergency_craft.cancel_reason_0285 = reason or "canonical-cancel"
  end
  pair.emergency_craft = nil
  pair.logistic_requested_item = nil
  pair.logistic_requested_count = nil
  pair.last_task_cancel_reason_0285 = reason or "canonical-cancel"
  pair.last_task_cancel_tick_0285 = tech_priests_0286_now()
end

function tech_priests_0285_mirror_task_to_legacy(pair, task)
  if not (pair and task) then return end
  local typ = task.type or task.kind
  pair.mode = task.mode or typ or pair.mode
  pair.task_kind = typ
  pair.task_phase = task.phase or "active"
  pair.task_target = task.target
  if typ == "repair" or typ == "consecration" or typ == "combat" then
    pair.target = task.target
  elseif typ == "scavenge" then
    pair.scavenge = pair.scavenge or {
      item_name = task.item,
      count = task.count or 1,
      source = task.source or task.target,
      started_tick = tech_priests_0286_now()
    }
    pair.target = pair.scavenge and pair.scavenge.source or task.target
  elseif typ == "logistics" then
    pair.logistic_requested_item = task.item
    pair.logistic_requested_count = task.count or 1
  elseif typ == "assignment" then
    pair.assignment_0252 = task.assignment or pair.assignment_0252
    pair.assignment_id_0252 = task.assignment and task.assignment.id or pair.assignment_id_0252
  elseif typ == "emergency_craft" then
    if task.item and tech_priests_start_emergency_operation_craft_item_0184 and not pair.emergency_craft then
      pcall(function() tech_priests_start_emergency_operation_craft_item_0184(pair, task.item) end)
    end
  end
  pair.last_task_mirror_tick_0285 = tech_priests_0286_now()
end

function tech_priests_0285_cancel_task(pair, reason)
  if not pair then return false end
  local old = pair.active_task or pair.active_task_0285
  pair.previous_task_0285 = old
  pair.active_task = nil
  pair.active_task_0285 = nil
  tech_priests_0285_clear_legacy_task_surfaces(pair, reason or "canonical-cancel")
  if tech_priests_0277_clear_task then pcall(function() tech_priests_0277_clear_task(pair, reason or "canonical-cancel") end) end
  pair.mode = "idle"
  return true
end

function tech_priests_0285_assign_task(pair, task, reason)
  if not pair then return false end
  task = task or {}
  task.type = task.type or task.kind or "idle"
  task.priority = task.priority or TECH_PRIESTS_0285_TASK_PRIORITY[task.type] or 0
  task.owner_system = task.owner_system or reason or "canonical-scheduler"
  task.started_tick = task.started_tick or tech_priests_0286_now()
  task.updated_tick = tech_priests_0286_now()
  local ok, why = tech_priests_0285_validate_task(pair, task)
  if not ok then
    pair.last_task_reject_reason_0285 = why
    pair.last_task_reject_tick_0285 = tech_priests_0286_now()
    return false
  end
  local current = pair.active_task or pair.active_task_0285
  if current then
    local cok = tech_priests_0285_validate_task(pair, current)
    if cok and tech_priests_0285_task_priority(current) > tech_priests_0285_task_priority(task) then
      pair.last_task_reject_reason_0285 = "lower-priority-than-active"
      return false
    end
  end
  pair.active_task = task
  pair.active_task_0285 = task
  pair.last_task_assign_reason_0285 = reason or task.owner_system
  pair.last_task_assign_tick_0285 = tech_priests_0286_now()
  tech_priests_0285_mirror_task_to_legacy(pair, task)
  return true
end

function tech_priests_0285_detection_to_task(pair, detection)
  if not detection then return nil end
  local entity = detection.entity or detection.target
  local kind = detection.kind or detection.type
  if kind == "combat" or kind == "enemy" then
    return { type = "combat", target = entity, priority = TECH_PRIESTS_0285_TASK_PRIORITY.combat, owner_system = "radar-detection" }
  elseif kind == "repair" then
    return { type = "repair", target = entity, priority = TECH_PRIESTS_0285_TASK_PRIORITY.repair, owner_system = "radar-detection" }
  elseif kind == "consecration" or kind == "sanctification" then
    return { type = "consecration", target = entity, priority = TECH_PRIESTS_0285_TASK_PRIORITY.consecration, owner_system = "radar-detection" }
  elseif kind == "resource" or kind == "scavenge" then
    return { type = "scavenge", target = entity, source = entity, item = detection.item or (entity and entity.name), count = detection.count or 1, priority = TECH_PRIESTS_0285_TASK_PRIORITY.scavenge, owner_system = "radar-detection" }
  end
  return nil
end

function tech_priests_0285_scheduler_refresh(pair, detection, reason)
  if not tech_priests_0286_valid_pair(pair) then return false end
  local active = pair.active_task or pair.active_task_0285
  if active then
    local ok, why = tech_priests_0285_validate_task(pair, active)
    if not ok then tech_priests_0285_cancel_task(pair, "invalid-active:" .. tostring(why)) end
  end
  local task = tech_priests_0285_detection_to_task(pair, detection)
  if task then return tech_priests_0285_assign_task(pair, task, reason or "scheduler-refresh") end
  return false
end

function tech_priests_0284_recipe_missing_ingredients(pair, item_name)
  local result = {}
  if not item_name then return result end
  local ingredients = tech_priests_get_recipe_ingredients_for_item_0185 and tech_priests_get_recipe_ingredients_for_item_0185(item_name) or {}
  local inv = pair and pair.station and pair.station.valid and get_station_inventory(pair.station) or nil
  local seen = {}
  for _, ing in pairs(ingredients or {}) do
    local name = ing and ing.name
    local need = math.max(1, ing and ing.count or 1)
    if name and not seen[name] then
      local have = inv and inv.get_item_count(name) or 0
      if have < need then
        result[#result + 1] = { name = name, count = need - have }
        seen[name] = true
      end
    end
  end
  return result
end

function tech_priests_0284_active_assignment_count(pair)
  if not (pair and storage and storage.tech_priests and storage.tech_priests.assignment_by_requester_0252) then return 0 end
  local unit = tech_priests_0286_station_unit(pair)
  local map = unit and storage.tech_priests.assignment_by_requester_0252[unit] or nil
  local n = 0
  for id in pairs(map or {}) do
    local a = storage.tech_priests.assignments_0252 and storage.tech_priests.assignments_0252[id]
    if a and a.status == "active" then n = n + 1 end
  end
  return n
end

function tech_priests_0284_assignment_already_requested(pair, item_name)
  if not (pair and item_name and storage and storage.tech_priests and storage.tech_priests.assignment_by_requester_0252) then return false end
  local unit = tech_priests_0286_station_unit(pair)
  local map = unit and storage.tech_priests.assignment_by_requester_0252[unit] or nil
  for id in pairs(map or {}) do
    local a = storage.tech_priests.assignments_0252 and storage.tech_priests.assignments_0252[id]
    if a and a.status == "active" and a.item_name == item_name then return true end
  end
  return false
end

function tech_priests_0284_recipe_fanout(pair, item_name, op, reason)
  if not (tech_priests_0286_valid_pair(pair) and item_name and tech_priests_0252_create_assignment and tech_priests_0252_find_subordinate_pair) then return false end
  local missing = tech_priests_0284_recipe_missing_ingredients(pair, item_name)
  if #missing == 0 then return false end
  if tech_priests_0252_ensure_assignment_storage then tech_priests_0252_ensure_assignment_storage() end
  op = op or pair.independent_emergency_operation_0184 or pair.assignment_op_0252 or pair.emergency_operation
  if op then op.assignment_requests_0252 = op.assignment_requests_0252 or {} end
  local assigned = 0
  for _, ing in ipairs(missing) do
    if assigned >= TECH_PRIESTS_0284_MAX_FANOUT_ASSIGNMENTS then break end
    if not tech_priests_0284_assignment_already_requested(pair, ing.name) then
      local worker = tech_priests_0252_find_subordinate_pair(pair, ing.name, ing.count, 0)
      if worker then
        local a = tech_priests_0252_create_assignment(pair, worker, ing.name, ing.count, reason or ("recipe-fanout-of-" .. tostring(item_name)), 0, nil)
        if a then
          assigned = assigned + 1
          if op then op.assignment_requests_0252[tostring(ing.name) .. ":fanout"] = a.id end
          tech_priests_0285_assign_task(worker, { type = "assignment", assignment = a, item = ing.name, count = ing.count, priority = TECH_PRIESTS_0285_TASK_PRIORITY.assignment, owner_system = "recipe-fanout" }, "recipe-fanout-worker")
        end
      end
    end
  end
  if assigned > 0 then
    pair.last_recipe_fanout_item_0284 = item_name
    pair.last_recipe_fanout_count_0284 = assigned
    pair.last_recipe_fanout_tick_0284 = tech_priests_0286_now()
    return true
  end
  -- No available subordinate: requester begins one remaining ingredient itself.
  for _, ing in ipairs(missing) do
    if not tech_priests_0284_assignment_already_requested(pair, ing.name) then
      tech_priests_0285_assign_task(pair, { type = "logistics", item = ing.name, count = ing.count, priority = TECH_PRIESTS_0285_TASK_PRIORITY.logistics, owner_system = "recipe-fanout-self" }, "recipe-fanout-self")
      if tech_priests_emergency_operation_acquire_item_0185 and op then pcall(function() tech_priests_emergency_operation_acquire_item_0185(pair, ing.name, op, ing.count, 0) end) end
      pair.last_recipe_fanout_item_0284 = item_name
      pair.last_recipe_fanout_self_item_0284 = ing.name
      pair.last_recipe_fanout_tick_0284 = tech_priests_0286_now()
      return true
    end
  end
  return false
end

TECH_PRIESTS_0284_PRE_ACQUIRE = tech_priests_emergency_operation_acquire_item_0185
function tech_priests_emergency_operation_acquire_item_0185(pair, item_name, op, count, depth)
  if depth == nil or depth == 0 then
    if tech_priests_0284_recipe_fanout(pair, item_name, op, "recipe-fanout-acquire") then
      if op then op.phase = "recipe-fanout-assignment"; op.last_item = item_name; op.next_tick = tech_priests_0286_now() + 120 end
      return true
    end
  end
  if TECH_PRIESTS_0284_PRE_ACQUIRE then return TECH_PRIESTS_0284_PRE_ACQUIRE(pair, item_name, op, count, depth) end
  return false
end

function tech_priests_0286_infer_legacy_task(pair)
  if not pair then return nil end
  if pair.target and pair.task_kind then return { type = pair.task_kind, target = pair.target, priority = TECH_PRIESTS_0285_TASK_PRIORITY[pair.task_kind] or 30, owner_system = "legacy-infer" } end
  if pair.assignment_0252 then return { type = "assignment", assignment = pair.assignment_0252, item = pair.assignment_0252.item_name, count = pair.assignment_0252.count, priority = TECH_PRIESTS_0285_TASK_PRIORITY.assignment, owner_system = "legacy-infer" } end
  if pair.scavenge then return { type = "scavenge", source = pair.scavenge.source, target = pair.scavenge.source, item = pair.scavenge.item_name, count = pair.scavenge.count, priority = TECH_PRIESTS_0285_TASK_PRIORITY.scavenge, owner_system = "legacy-infer" } end
  if pair.emergency_craft then return { type = "emergency_craft", item = pair.emergency_craft.item_name or pair.emergency_craft.output_item, priority = TECH_PRIESTS_0285_TASK_PRIORITY.emergency_craft, owner_system = "legacy-infer" } end
  if pair.logistic_requested_item then return { type = "logistics", item = pair.logistic_requested_item, count = pair.logistic_requested_count or 1, priority = TECH_PRIESTS_0285_TASK_PRIORITY.logistics, owner_system = "legacy-infer" } end
  return nil
end

function tech_priests_0286_reconcile_pair(pair, stage, force)
  if not tech_priests_0286_valid_pair(pair) then return false end
  local now = tech_priests_0286_now()
  if not force and pair.last_reconcile_tick_0286 and now - pair.last_reconcile_tick_0286 < TECH_PRIESTS_0286_RECONCILE_INTERVAL then return false end
  pair.last_reconcile_tick_0286 = now
  pair.last_reconcile_stage_0286 = stage or "periodic"
  local active = pair.active_task or pair.active_task_0285
  if active then
    local ok, why = tech_priests_0285_validate_task(pair, active)
    if not ok then
      tech_priests_0285_cancel_task(pair, "governor-invalid:" .. tostring(why))
      active = nil
    end
  end
  if not active then
    local inferred = tech_priests_0286_infer_legacy_task(pair)
    if inferred then
      tech_priests_0285_assign_task(pair, inferred, "governor-adopt-legacy")
      active = pair.active_task
    end
  else
    -- If a stale lower-priority legacy surface survived, clear it instead of
    -- allowing the old stack to drag the priest back to the obsolete task.
    if active.type ~= "scavenge" and pair.scavenge then pair.scavenge = nil end
    if active.type ~= "emergency_craft" and pair.emergency_craft then pair.emergency_craft = nil end
    if active.type ~= "assignment" and pair.assignment_0252 then
      -- Do not destroy the global assignment record here; only prevent local
      -- state from pretending it owns the priest while a higher task is active.
      pair.assignment_0252 = nil
      pair.assignment_id_0252 = nil
      pair.assignment_op_0252 = nil
    end
    if active.type ~= "combat" and active.type ~= "repair" and active.type ~= "consecration" then
      if pair.target and pair.task_kind and (TECH_PRIESTS_0285_TASK_PRIORITY[pair.task_kind] or 0) < tech_priests_0285_task_priority(active) then pair.target = nil end
    end
    tech_priests_0285_mirror_task_to_legacy(pair, active)
  end
  return true
end

TECH_PRIESTS_0286_PRE_TICK_PAIR = tick_pair
function tick_pair(pair)
  if tech_priests_0286_reconcile_pair then pcall(function() tech_priests_0286_reconcile_pair(pair, "before-tick", false) end) end
  local result = nil
  if TECH_PRIESTS_0286_PRE_TICK_PAIR then result = TECH_PRIESTS_0286_PRE_TICK_PAIR(pair) end
  if tech_priests_0286_reconcile_pair then pcall(function() tech_priests_0286_reconcile_pair(pair, "after-tick", false) end) end
  return result
end

TECH_PRIESTS_0286_PRE_RADAR_REFRESH_DETECTED = tech_priests_radar_refresh_detected_task_0282
function tech_priests_radar_refresh_detected_task_0282(pair, entity, info)
  if info and info.kind then
    tech_priests_0285_scheduler_refresh(pair, { kind = info.kind, entity = entity, target = entity }, "radar-detected-task")
  end
  if TECH_PRIESTS_0286_PRE_RADAR_REFRESH_DETECTED then return TECH_PRIESTS_0286_PRE_RADAR_REFRESH_DETECTED(pair, entity, info) end
  return false
end

TECH_PRIESTS_0286_PRE_RADAR_HARD_REAUDIT = tech_priests_radar_hard_reaudit_pair_0283
function tech_priests_radar_hard_reaudit_pair_0283(pair, reason)
  local r = nil
  if TECH_PRIESTS_0286_PRE_RADAR_HARD_REAUDIT then r = TECH_PRIESTS_0286_PRE_RADAR_HARD_REAUDIT(pair, reason) end
  tech_priests_0286_reconcile_pair(pair, reason or "radar-hard-reaudit", true)
  return r
end

if commands and commands.add_command then
  pcall(function()
    TechPriestsDebugCommandRegistry.add("tp-fanout-0284", "Tech Priests: report recipe fan-out assignment state for selected station.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      if not (player and player.valid) then return end
      local pair = tech_priests_radar_get_hover_pair_0278 and tech_priests_radar_get_hover_pair_0278(player) or nil
      if not pair then player.print("No selected/hovered Tech Priest pair."); return end
      player.print("Fanout 0.1.284 item=" .. tostring(pair.last_recipe_fanout_item_0284 or "none") .. " assigned=" .. tostring(pair.last_recipe_fanout_count_0284 or 0) .. " self=" .. tostring(pair.last_recipe_fanout_self_item_0284 or "none") .. " active_assignments=" .. tostring(tech_priests_0284_active_assignment_count(pair)))
    end)
  end)
  pcall(function()
    TechPriestsDebugCommandRegistry.add("tp-scheduler-0285", "Tech Priests: report canonical active task ledger for selected station.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      if not (player and player.valid) then return end
      local pair = tech_priests_radar_get_hover_pair_0278 and tech_priests_radar_get_hover_pair_0278(player) or nil
      if not pair then player.print("No selected/hovered Tech Priest pair."); return end
      local task = pair.active_task or pair.active_task_0285 or {}
      player.print("Scheduler 0.1.285 task=" .. tostring(task.type or "none") .. " item=" .. tostring(task.item or "none") .. " owner=" .. tostring(task.owner_system or "none") .. " assign_reason=" .. tostring(pair.last_task_assign_reason_0285 or "none") .. " cancel=" .. tostring(pair.last_task_cancel_reason_0285 or "none") .. " reject=" .. tostring(pair.last_task_reject_reason_0285 or "none"))
    end)
  end)
  pcall(function()
    TechPriestsDebugCommandRegistry.add("tp-scheduler-0286", "Tech Priests: report scheduler governor/reconciliation state for selected station.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      if not (player and player.valid) then return end
      local pair = tech_priests_radar_get_hover_pair_0278 and tech_priests_radar_get_hover_pair_0278(player) or nil
      if not pair then player.print("No selected/hovered Tech Priest pair."); return end
      tech_priests_0286_reconcile_pair(pair, "manual-command", true)
      local task = pair.active_task or pair.active_task_0285 or {}
      player.print("Governor 0.1.286 task=" .. tostring(task.type or "none") .. " item=" .. tostring(task.item or "none") .. " mode=" .. tostring(pair.mode or "nil") .. " stage=" .. tostring(pair.last_reconcile_stage_0286 or "none") .. " fanout=" .. tostring(pair.last_recipe_fanout_item_0284 or "none"))
    end)
  end)
end

-- 0.1.425: inert script.on_init marker removed during event switchboard cleanup.

if log then log("[Tech Priests 0.1.286] cumulative recipe fanout + canonical scheduler ledger + governor reconciliation loaded") end


-- ============================================================================
-- 0.1.287: emergency recipe simplification + active acquisition watchdog.
-- ============================================================================
-- The canonical scheduler now has authority, but a priest can still appear idle
-- when the active task is a logistics/resource/crafting task and the older
-- acquisition ladder is merely waiting on a retry tick. This layer treats those
-- task types as motion-required: either the priest is actively crafting, moving
-- to scrounge/mine, or the task is kicked back through the acquisition ladder.

TECH_PRIESTS_PATCH_0287 = "0.1.287-emergency-recipe-pass-active-acquisition-watchdog"
TECH_PRIESTS_0287_KICK_INTERVAL = 30
TECH_PRIESTS_0287_STALE_TICKS = 90
TECH_PRIESTS_0287_MOTION_TASKS = {
  logistics = true,
  assignment = true,
  emergency_craft = true,
  scavenge = true
}

function tech_priests_0287_now()
  return game and game.tick or 0
end

function tech_priests_0287_log(msg)
  if tech_priests_0264_log then
    pcall(function() tech_priests_0264_log("[0.1.287] " .. tostring(msg), true) end)
  elseif log then
    log("[Tech-Priests 0.1.287] " .. tostring(msg))
  end
end

function tech_priests_0287_station_inventory(pair)
  if get_station_inventory and pair and pair.station and pair.station.valid then
    local ok, inv = pcall(function() return get_station_inventory(pair.station) end)
    if ok and inv then return inv end
  end
  if pair and pair.station and pair.station.valid and defines and defines.inventory then
    local ok, inv = pcall(function() return pair.station.get_inventory(defines.inventory.chest) end)
    if ok and inv then return inv end
  end
  return nil
end

function tech_priests_0287_have_item(pair, item, count)
  local inv = tech_priests_0287_station_inventory(pair)
  if not (inv and item) then return false end
  return (inv.get_item_count(item) or 0) >= math.max(1, count or 1)
end

function tech_priests_0287_active_task(pair)
  return pair and (pair.active_task or pair.active_task_0285) or nil
end

function tech_priests_0287_task_item(task, pair)
  if task then
    if task.item then return task.item end
    if task.item_name then return task.item_name end
    if task.output_item then return task.output_item end
    if task.assignment and task.assignment.item_name then return task.assignment.item_name end
  end
  if pair then
    if pair.logistic_requested_item then return pair.logistic_requested_item end
    if pair.assignment_0252 and pair.assignment_0252.item_name then return pair.assignment_0252.item_name end
    if pair.scavenge and pair.scavenge.item_name then return pair.scavenge.item_name end
    if pair.emergency_craft then
      return pair.emergency_craft.item_name or pair.emergency_craft.output_item or pair.emergency_craft.item
    end
  end
  return nil
end

function tech_priests_0287_task_count(task, pair)
  if task then return math.max(1, task.count or task.amount or (task.assignment and task.assignment.count) or 1) end
  if pair then return math.max(1, pair.logistic_requested_count or (pair.scavenge and pair.scavenge.count) or 1) end
  return 1
end

function tech_priests_0287_ensure_op(pair, item)
  if not pair then return nil end
  pair.scheduler_acquisition_op_0287 = pair.scheduler_acquisition_op_0287 or {
    phase = "scheduler-acquisition-watchdog",
    started_tick = tech_priests_0287_now(),
    reason = "active-task-watchdog"
  }
  local op = pair.independent_emergency_operation_0184 or pair.assignment_op_0252 or pair.emergency_operation or pair.scheduler_acquisition_op_0287
  op.phase = op.phase or "scheduler-acquisition-watchdog"
  op.last_item = item or op.last_item
  op.last_action_tick = tech_priests_0287_now()
  return op
end

function tech_priests_0287_priest_near_station(pair)
  if not (pair and pair.priest and pair.priest.valid and pair.station and pair.station.valid) then return false end
  local dx = pair.priest.position.x - pair.station.position.x
  local dy = pair.priest.position.y - pair.station.position.y
  return dx * dx + dy * dy <= 9
end

function tech_priests_0287_task_is_motion_required(pair, task)
  if not (pair and task) then return false end
  local typ = task.type or task.kind
  if TECH_PRIESTS_0287_MOTION_TASKS[typ] then return true end
  if pair.emergency_craft or pair.scavenge or pair.logistic_requested_item or pair.assignment_0252 then return true end
  return false
end

function tech_priests_0287_service_existing_motion(pair)
  if not pair then return false end
  if pair.emergency_craft and handle_emergency_desperation_craft then
    local ok, did = pcall(function() return handle_emergency_desperation_craft(pair) end)
    if ok and did then return true end
  end
  if pair.scavenge and handle_priest_scavenge_task then
    local ok, did = pcall(function() return handle_priest_scavenge_task(pair) end)
    if ok and did then return true end
  end
  return false
end

function tech_priests_0287_kick_active_acquisition(pair, reason, force)
  if not (tech_priests_0286_valid_pair and tech_priests_0286_valid_pair(pair)) then return false end
  local now = tech_priests_0287_now()
  if not force and pair.last_active_acquisition_kick_0287 and now - pair.last_active_acquisition_kick_0287 < TECH_PRIESTS_0287_KICK_INTERVAL then return false end

  local task = tech_priests_0287_active_task(pair)
  if not task then return false end
  if not tech_priests_0287_task_is_motion_required(pair, task) then return false end

  local ok_task = true
  if tech_priests_0285_validate_task then
    local ok = false
    ok = select(1, tech_priests_0285_validate_task(pair, task))
    ok_task = ok
  end
  if not ok_task then
    if tech_priests_0285_cancel_task then tech_priests_0285_cancel_task(pair, "0287-invalid-motion-task") end
    return false
  end

  pair.last_active_acquisition_kick_0287 = now
  pair.last_active_acquisition_reason_0287 = reason or "watchdog"

  if tech_priests_0287_service_existing_motion(pair) then
    pair.last_active_acquisition_result_0287 = "serviced-existing-motion"
    return true
  end

  local item = tech_priests_0287_task_item(task, pair)
  local count = tech_priests_0287_task_count(task, pair)
  if not item then return false end

  if tech_priests_0287_have_item(pair, item, count) then
    pair.last_active_acquisition_result_0287 = "already-have-item"
    if (task.type == "logistics" or task.type == "emergency_craft") and tech_priests_0285_cancel_task then
      tech_priests_0285_cancel_task(pair, "0287-item-now-available")
    end
    return true
  end

  local op = tech_priests_0287_ensure_op(pair, item)
  local did = false
  if tech_priests_emergency_operation_acquire_item_0185 then
    local ok, result = pcall(function() return tech_priests_emergency_operation_acquire_item_0185(pair, item, op, count, 0) end)
    did = ok and result or false
  end

  -- If the acquisition ladder only scheduled a retry and left no movement state,
  -- start the raw emergency craft path immediately so the priest is visibly doing
  -- something instead of praying at the station for several minutes.
  if not pair.emergency_craft and not pair.scavenge and tech_priests_start_emergency_operation_craft_item_0184 then
    local ok, started = pcall(function() return tech_priests_start_emergency_operation_craft_item_0184(pair, item) end)
    if ok and started then
      did = true
      if handle_emergency_desperation_craft then pcall(function() handle_emergency_desperation_craft(pair) end) end
    end
  end

  if pair.emergency_craft and handle_emergency_desperation_craft then
    pcall(function() handle_emergency_desperation_craft(pair) end)
  elseif pair.scavenge and handle_priest_scavenge_task then
    pcall(function() handle_priest_scavenge_task(pair) end)
  end

  if did then
    pair.mode = pair.mode or "emergency-gathering"
    pair.last_active_acquisition_result_0287 = "kicked-acquisition:" .. tostring(item)
    if draw_priest_status_bubble then pcall(function() draw_priest_status_bubble(pair) end) end
    return true
  end

  -- Last nudge: if we still have nothing but the priest is parked at station,
  -- keep the task hot and shorten any retry wait that was going to leave him idle.
  if tech_priests_0287_priest_near_station(pair) and op then
    op.next_tick = now + 30
    op.logistic_due_tick = now
    op.phase = "scheduler-acquisition-retry-soon"
    pair.last_active_acquisition_result_0287 = "retry-shortened:" .. tostring(item)
    return true
  end

  return false
end

TECH_PRIESTS_0287_PRE_TICK_PAIR = tick_pair
function tick_pair(pair)
  if tech_priests_0286_reconcile_pair then pcall(function() tech_priests_0286_reconcile_pair(pair, "0287-before-tick", false) end) end
  if tech_priests_0287_kick_active_acquisition then pcall(function() tech_priests_0287_kick_active_acquisition(pair, "tick-pair", false) end) end
  local result = nil
  if TECH_PRIESTS_0287_PRE_TICK_PAIR then result = TECH_PRIESTS_0287_PRE_TICK_PAIR(pair) end
  if tech_priests_0287_kick_active_acquisition then pcall(function() tech_priests_0287_kick_active_acquisition(pair, "post-tick-pair", false) end) end
  return result
end

TechPriestsRuntimeEventRegistry.on_nth_tick(29, function()
  if not (storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return end
  for _, pair in pairs(storage.tech_priests.pairs_by_station or {}) do
    pcall(function()
      local task = tech_priests_0287_active_task(pair)
      if task and tech_priests_0287_task_is_motion_required(pair, task) then
        local age = tech_priests_0287_now() - (task.updated_tick or task.started_tick or tech_priests_0287_now())
        local force = age >= TECH_PRIESTS_0287_STALE_TICKS or tech_priests_0287_priest_near_station(pair)
        tech_priests_0287_kick_active_acquisition(pair, "nth-tick-watchdog", force)
      end
    end)
  end
end)

if commands and commands.add_command then
  pcall(function()
    TechPriestsDebugCommandRegistry.add("tp-acquire-0287", "Tech Priests: force active logistics/resource/crafting task through the acquisition watchdog.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      if not player then return end
      local pair = tech_priests_get_selected_pair_0247 and tech_priests_get_selected_pair_0247(player) or nil
      if not pair and tech_priests_0264_find_pair_for_player then
        local ok, got = pcall(function() return tech_priests_0264_find_pair_for_player(player) end)
        if ok then pair = got end
      end
      if not pair then player.print("[Tech Priests] Select a Cogitator Station or Tech-Priest."); return end
      if tech_priests_0286_reconcile_pair then pcall(function() tech_priests_0286_reconcile_pair(pair, "manual-0287", true) end) end
      local task = tech_priests_0287_active_task(pair) or {}
      local item = tech_priests_0287_task_item(task, pair)
      local forced = tech_priests_0287_kick_active_acquisition(pair, "manual-command", true)
      player.print("[Tech Priests 0.1.287] task=" .. tostring(task.type or "none") .. " item=" .. tostring(item or "none") .. " mode=" .. tostring(pair.mode or "nil") .. " result=" .. tostring(pair.last_active_acquisition_result_0287 or forced))
    end)
  end)
end

tech_priests_0287_log("0.1.287 emergency recipe pass + active acquisition watchdog loaded")

-- -----------------------------------------------------------------------------
-- 0.1.290 honest 2x2 emergency devices + station-inventory crafting kick
-- -----------------------------------------------------------------------------
-- The 0.1.287 watchdog kept kicking acquisition tasks, but it still treated
-- "the station already contains usable crafting inputs" as a passive wait path.
-- This layer lets the priest actually craft from the Cogitator Station inventory
-- before falling back to scavenge/logistics/raw emergency gathering.

TECH_PRIESTS_PATCH_0290 = "0.1.290-emergency-device-footprint-and-active-station-crafting"
TECH_PRIESTS_0290_DIRECT_CRAFT_TICKS = 90

function tech_priests_0290_now()
  return game and game.tick or 0
end

function tech_priests_0290_log(msg)
  if tech_priests_0264_log then
    pcall(function() tech_priests_0264_log("[0.1.290] " .. tostring(msg), true) end)
  elseif log then
    log("[Tech-Priests 0.1.290] " .. tostring(msg))
  end
end

function tech_priests_0290_station_inventory(pair)
  if get_station_inventory and pair and pair.station and pair.station.valid then
    local ok, inv = pcall(function() return get_station_inventory(pair.station) end)
    if ok and inv then return inv end
  end
  return nil
end

function tech_priests_0290_item_stack_size(name)
  if get_item_stack_size then
    local ok, n = pcall(function() return get_item_stack_size(name) end)
    if ok and n then return n end
  end
  return 50
end

function tech_priests_0290_recipe_ingredients(item_name)
  if tech_priests_get_recipe_ingredients_for_item_0185 then
    local ok, ingredients = pcall(function() return tech_priests_get_recipe_ingredients_for_item_0185(item_name) end)
    if ok and ingredients and #ingredients > 0 then return ingredients, "recipe" end
  end
  local recipe = tech_priests_make_recipe_aware_emergency_recipe_0184 and tech_priests_make_recipe_aware_emergency_recipe_0184(item_name) or nil
  local result = {}
  if recipe and recipe.primary then
    for name, amount in pairs(recipe.primary) do
      result[#result + 1] = { name = name, count = math.max(1, math.ceil(amount or 1)) }
    end
  end
  table.sort(result, function(a, b) return tostring(a.name) < tostring(b.name) end)
  return result, "emergency-primary"
end

function tech_priests_0290_can_insert(inv, item_name, count)
  if not (inv and item_name) then return false end
  local ok, can = pcall(function() return inv.can_insert({ name = item_name, count = math.max(1, count or 1) }) end)
  return ok and can
end

function tech_priests_0290_try_consume_exact_recipe(pair, item_name, count)
  local inv = tech_priests_0290_station_inventory(pair)
  if not (inv and item_name) then return false end
  count = math.max(1, count or 1)
  if inv.get_item_count(item_name) >= count then return false, "already-present" end
  if not tech_priests_0290_can_insert(inv, item_name, count) then return false, "cannot-insert-output" end

  local ingredients, source = tech_priests_0290_recipe_ingredients(item_name)
  if not ingredients or #ingredients == 0 then return false, "no-ingredients" end

  for _, ing in pairs(ingredients) do
    local need = math.max(1, math.ceil((ing.count or ing.amount or 1) * count))
    if inv.get_item_count(ing.name) < need then
      return false, "missing-" .. tostring(ing.name)
    end
  end

  local removed = {}
  for _, ing in pairs(ingredients) do
    local need = math.max(1, math.ceil((ing.count or ing.amount or 1) * count))
    local r = inv.remove({ name = ing.name, count = need })
    removed[#removed + 1] = { name = ing.name, count = r }
    if r < need then
      for _, rr in pairs(removed) do if rr.count and rr.count > 0 then inv.insert({ name = rr.name, count = rr.count }) end end
      return false, "remove-failed-" .. tostring(ing.name)
    end
  end

  local inserted = inv.insert({ name = item_name, count = count })
  if inserted < count then
    if inserted > 0 then inv.remove({ name = item_name, count = inserted }) end
    for _, rr in pairs(removed) do if rr.count and rr.count > 0 then inv.insert({ name = rr.name, count = rr.count }) end end
    return false, "insert-failed"
  end

  pair.last_station_direct_craft_0290 = item_name
  pair.last_station_direct_craft_source_0290 = source
  pair.last_station_direct_craft_tick_0290 = tech_priests_0290_now()
  if tech_priests_draw_emergency_operation_status_0184 then
    pcall(function() tech_priests_draw_emergency_operation_status_0184(pair, "[item=" .. item_name .. "] station inventory craft") end)
  end
  if draw_priest_status_bubble then pcall(function() draw_priest_status_bubble(pair) end) end
  return true, source
end

function tech_priests_0290_task_item(task, pair)
  if tech_priests_0287_task_item then
    local ok, item = pcall(function() return tech_priests_0287_task_item(task, pair) end)
    if ok and item then return item end
  end
  if task then
    return task.item or task.item_name or task.output_item or (task.assignment and task.assignment.item_name)
  end
  if pair then
    if pair.logistic_requested_item then return pair.logistic_requested_item end
    if pair.assignment_0252 and pair.assignment_0252.item_name then return pair.assignment_0252.item_name end
    if pair.emergency_craft then return pair.emergency_craft.item_name or pair.emergency_craft.output_item or pair.emergency_craft.item end
    if pair.scavenge then return pair.scavenge.item_name end
  end
  return nil
end

function tech_priests_0290_task_count(task, pair)
  if tech_priests_0287_task_count then
    local ok, n = pcall(function() return tech_priests_0287_task_count(task, pair) end)
    if ok and n then return math.max(1, n) end
  end
  return math.max(1, (task and (task.count or task.amount or (task.assignment and task.assignment.count))) or 1)
end

function tech_priests_0290_try_station_inventory_craft_for_task(pair, reason)
  if not (pair and pair.station and pair.station.valid) then return false end
  local task = pair.active_task or pair.active_task_0285
  if not task and tech_priests_0286_infer_legacy_task then
    local ok, inferred = pcall(function() return tech_priests_0286_infer_legacy_task(pair) end)
    if ok then task = inferred end
  end
  if not task then return false end
  local typ = task.type or task.kind
  if not (typ == "logistics" or typ == "assignment" or typ == "emergency_craft" or typ == "scavenge") then return false end
  local item = tech_priests_0290_task_item(task, pair)
  if not item then return false end
  local count = math.min(tech_priests_0290_task_count(task, pair), tech_priests_0290_item_stack_size(item))
  local ok, how = tech_priests_0290_try_consume_exact_recipe(pair, item, count)
  if not ok then
    pair.last_station_direct_craft_fail_0290 = how
    pair.last_station_direct_craft_fail_item_0290 = item
    pair.last_station_direct_craft_fail_tick_0290 = tech_priests_0290_now()
    return false
  end

  -- The requested item now exists. Clear stale acquisition surfaces so the next
  -- scheduler pulse can immediately move to delivery/use instead of continuing
  -- to display an old "need X" or "scavenging wrong resource" bubble.
  pair.scavenge = nil
  pair.emergency_craft = nil
  pair.target = nil
  pair.mode = "returning"
  if pair.scheduler_acquisition_op_0287 then pair.scheduler_acquisition_op_0287.acquisition = nil end
  if pair.independent_emergency_operation_0184 then pair.independent_emergency_operation_0184.acquisition = nil; pair.independent_emergency_operation_0184.next_tick = tech_priests_0290_now() + 1 end
  if tech_priests_0285_cancel_task and (typ == "logistics" or typ == "emergency_craft" or typ == "scavenge") then
    pcall(function() tech_priests_0285_cancel_task(pair, "0290-station-direct-crafted-" .. tostring(item)) end)
  end
  if pair.priest and pair.priest.valid and pair.station and pair.station.valid and return_to_station then
    pcall(function() return_to_station(pair.priest, pair.station) end)
  end
  pair.last_station_direct_craft_result_0290 = "crafted-" .. tostring(item) .. " via " .. tostring(how) .. " reason=" .. tostring(reason)
  return true
end

TECH_PRIESTS_0290_PRE_ACQUIRE_0185 = tech_priests_emergency_operation_acquire_item_0185
function tech_priests_emergency_operation_acquire_item_0185(pair, item_name, op, count, depth)
  -- First: if the Cogitator Station already has the ingredients, craft now.
  -- Do not make the priest stare at the shrine muttering "need ammo" while the
  -- steel/plates sit directly inside the shrine inventory.
  if pair and item_name and tech_priests_0290_try_consume_exact_recipe then
    local ok, made = pcall(function() return tech_priests_0290_try_consume_exact_recipe(pair, item_name, math.max(1, count or 1)) end)
    if ok and made then
      if op then op.phase = "station-direct-craft"; op.last_item = item_name; op.next_tick = tech_priests_0290_now() + 1; op.acquisition = nil end
      return true
    end
  end
  if TECH_PRIESTS_0290_PRE_ACQUIRE_0185 then return TECH_PRIESTS_0290_PRE_ACQUIRE_0185(pair, item_name, op, count, depth) end
  return false
end

if tech_priests_0287_kick_active_acquisition then
  TECH_PRIESTS_0290_PRE_KICK_ACTIVE_ACQUISITION = tech_priests_0287_kick_active_acquisition
  function tech_priests_0287_kick_active_acquisition(pair, reason, force)
    if tech_priests_0290_try_station_inventory_craft_for_task(pair, reason or "0287-kick-precraft") then return true end
    return TECH_PRIESTS_0290_PRE_KICK_ACTIVE_ACQUISITION(pair, reason, force)
  end
end

TECH_PRIESTS_0290_PRE_TICK_PAIR = tick_pair
function tick_pair(pair)
  if pair then pcall(function() tech_priests_0290_try_station_inventory_craft_for_task(pair, "tick-pair-pre") end) end
  local result = nil
  if TECH_PRIESTS_0290_PRE_TICK_PAIR then result = TECH_PRIESTS_0290_PRE_TICK_PAIR(pair) end
  if pair then pcall(function() tech_priests_0290_try_station_inventory_craft_for_task(pair, "tick-pair-post") end) end
  return result
end

TechPriestsRuntimeEventRegistry.on_nth_tick(31, function()
  if not (storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return end
  for _, pair in pairs(storage.tech_priests.pairs_by_station or {}) do
    pcall(function() tech_priests_0290_try_station_inventory_craft_for_task(pair, "nth-tick-31") end)
  end
end)

if commands and commands.add_command then
  pcall(function()
    TechPriestsDebugCommandRegistry.add("tp-craft-0290", "Tech Priests: force station-inventory direct craft for selected pair/task.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      if not player then return end
      local pair = nil
      local selected = player.selected
      if selected and storage and storage.tech_priests then
        if storage.tech_priests.pairs_by_station and storage.tech_priests.pairs_by_station[selected.unit_number] then pair = storage.tech_priests.pairs_by_station[selected.unit_number] end
        if not pair and storage.tech_priests.pairs_by_priest and storage.tech_priests.pairs_by_priest[selected.unit_number] then pair = storage.tech_priests.pairs_by_priest[selected.unit_number] end
      end
      if not pair then player.print("[Tech Priests] Select a Cogitator Station or Tech-Priest first."); return end
      local task = pair.active_task or pair.active_task_0285 or (tech_priests_0286_infer_legacy_task and tech_priests_0286_infer_legacy_task(pair)) or {}
      local item = tech_priests_0290_task_item(task, pair)
      local count = tech_priests_0290_task_count(task, pair)
      local did = tech_priests_0290_try_station_inventory_craft_for_task(pair, "command")
      player.print("Craft 0.1.290 item=" .. tostring(item or "none") .. " count=" .. tostring(count) .. " did=" .. tostring(did) .. " last=" .. tostring(pair.last_station_direct_craft_result_0290 or "none") .. " fail=" .. tostring(pair.last_station_direct_craft_fail_0290 or "none"))
    end)
  end)
end

tech_priests_0290_log("0.1.290 emergency device footprint + active station craft layer loaded")

-- -----------------------------------------------------------------------------
-- 0.1.291 local ground-stockpile scavenging + emergency micro visual tune
-- -----------------------------------------------------------------------------
-- Priests should not ignore a pile of exactly-needed supplies lying inside their
-- station radius.  This layer lets the normal supply/scavenge path prefer local
-- item-on-ground stacks before expensive inventory scans or passive waiting.

TECH_PRIESTS_PATCH_0291 = "0.1.291-local-ground-stockpile-scavenging"

function tech_priests_0291_now()
  return game and game.tick or 0
end

function tech_priests_0291_log(msg)
  if tech_priests_0264_log then
    pcall(function() tech_priests_0264_log("[0.1.291] " .. tostring(msg), true) end)
  elseif log then
    log("[Tech-Priests 0.1.291] " .. tostring(msg))
  end
end

function tech_priests_0291_stack_name_and_count(entity)
  if not (entity and entity.valid) then return nil, 0 end
  local ok_type, typ = pcall(function() return entity.type end)
  if not (ok_type and (typ == "item-entity" or typ == "item-on-ground")) then return nil, 0 end
  local ok, stack = pcall(function() return entity.stack end)
  if not (ok and stack and stack.valid_for_read) then return nil, 0 end
  return stack.name, stack.count or 1, stack
end

function tech_priests_0291_request_accepts_item(pair, request, item_name, stack_count)
  if not (pair and pair.station and pair.station.valid and request and item_name) then return nil end
  local station_inventory = get_station_inventory and get_station_inventory(pair.station) or nil
  if not station_inventory then return nil end

  if request.kind == "ammo" then
    if is_ammo_item and is_ammo_item(item_name) then
      local proxy = ensure_proxy and ensure_proxy(pair) or nil
      local proxy_inventory = get_turret_ammo_inventory and get_turret_ammo_inventory(proxy) or nil
      local test_stack = { name = item_name, count = 1 }
      if station_inventory.can_insert(test_stack) and (not proxy_inventory or proxy_inventory.can_insert(test_stack)) then
        local score = get_ammo_preference_score and get_ammo_preference_score(item_name) or 1
        return { name = item_name, count = math.min(get_item_stack_size and get_item_stack_size(item_name) or 50, stack_count or 1), score = score }
      end
    end
    return nil
  end

  if request.item_name and request.item_name == item_name and station_inventory.can_insert({ name = item_name, count = 1 }) then
    return { name = item_name, count = math.min(get_item_stack_size and get_item_stack_size(item_name) or 50, stack_count or 1), score = request.score or 1000 }
  end

  for _, candidate in pairs(request.candidates or {}) do
    if candidate and candidate.name == item_name and station_inventory.can_insert({ name = item_name, count = 1 }) then
      return { name = item_name, count = math.min(get_item_stack_size and get_item_stack_size(item_name) or 50, stack_count or 1), score = candidate.score or 0 }
    end
  end
  return nil
end

function tech_priests_0291_find_ground_stockpile_for_request(pair, request)
  if not (pair and pair.station and pair.station.valid and request) then return nil end
  local station = pair.station
  local priest = pair.priest
  local radius = refresh_pair_radius and refresh_pair_radius(pair) or pair.radius or 30
  local pos = station.position
  local area = {{pos.x - radius, pos.y - radius}, {pos.x + radius, pos.y + radius}}
  local best = nil
  local best_score = nil
  local ok, ground_items = pcall(function()
    return station.surface.find_entities_filtered({ area = area, type = "item-entity" })
  end)
  if not ok then return nil end

  for _, entity in pairs(ground_items or {}) do
    local item_name, stack_count = tech_priests_0291_stack_name_and_count(entity)
    local found = tech_priests_0291_request_accepts_item(pair, request, item_name, stack_count)
    if found then
      local dx = entity.position.x - pos.x
      local dy = entity.position.y - pos.y
      local station_distance_sq = dx * dx + dy * dy
      if station_distance_sq <= radius * radius then
        local score_distance = station_distance_sq
        if priest and priest.valid then
          local pdx = entity.position.x - priest.position.x
          local pdy = entity.position.y - priest.position.y
          score_distance = math.min(score_distance, pdx * pdx + pdy * pdy)
        end
        local score = score_distance - ((found.score or 0) * 0.0001)
        if not best_score or score < best_score then
          best_score = score
          best = {
            source = entity,
            inventory_id = nil,
            item_name = found.name,
            count = found.count or 1,
            kind = request.kind,
            quality = found.quality,
            ground_stockpile_0291 = true
          }
        end
      end
    end
  end
  return best
end

function tech_priests_0291_take_ground_stockpile(pair)
  if not (pair and pair.station and pair.station.valid and pair.scavenge and pair.scavenge.source and pair.scavenge.source.valid and pair.scavenge.ground_stockpile_0291) then return false end
  local source = pair.scavenge.source
  local item_name, stack_count, stack = tech_priests_0291_stack_name_and_count(source)
  if not (item_name and item_name == pair.scavenge.item_name and stack_count and stack_count > 0) then return false end
  local station_inventory = get_station_inventory and get_station_inventory(pair.station) or nil
  if not station_inventory then return false end
  local wanted = math.max(1, pair.scavenge.count or 1)
  local max_stack = get_item_stack_size and get_item_stack_size(item_name) or 50
  local count = math.min(wanted, stack_count, max_stack)
  if get_insertable_item_count then
    count = get_insertable_item_count(station_inventory, item_name, count, pair.scavenge.quality)
  elseif not station_inventory.can_insert({ name = item_name, count = 1 }) then
    count = 0
  end
  if count <= 0 then return false end

  local inserted = station_inventory.insert(make_item_stack_identification and make_item_stack_identification(item_name, count, pair.scavenge.quality) or { name = item_name, count = count })
  if inserted <= 0 then return false end

  if inserted >= stack_count then
    pcall(function() source.destroy({ raise_destroy = false }) end)
  else
    local ok_set = pcall(function() stack.count = stack_count - inserted end)
    if not ok_set then
      -- If this Factorio build refuses partial stack mutation, avoid duplicating
      -- supplies.  Destroy only when the whole visible stack was taken.
      if inserted == stack_count then pcall(function() source.destroy({ raise_destroy = false }) end) end
    end
  end

  pair.mode = "returning"
  pair.target = nil
  pair.scavenge = nil
  if clear_logistic_frustration then pcall(function() clear_logistic_frustration(pair) end) end
  if pair.priest and pair.priest.valid and pair.station and pair.station.valid and return_to_station then
    pcall(function() return_to_station(pair.priest, pair.station) end)
  end
  pair.last_ground_stockpile_pickup_0291 = item_name
  pair.last_ground_stockpile_pickup_count_0291 = inserted
  pair.last_ground_stockpile_pickup_tick_0291 = tech_priests_0291_now()
  if draw_priest_status_bubble then pcall(function() draw_priest_status_bubble(pair) end) end
  return true
end

TECH_PRIESTS_0291_PRE_FIND_SCAVENGE_SOURCE = find_scavenge_source_for_request
function find_scavenge_source_for_request(pair, request)
  local ground = tech_priests_0291_find_ground_stockpile_for_request(pair, request)
  if ground then return ground end
  if TECH_PRIESTS_0291_PRE_FIND_SCAVENGE_SOURCE then return TECH_PRIESTS_0291_PRE_FIND_SCAVENGE_SOURCE(pair, request) end
  return nil
end

TECH_PRIESTS_0291_PRE_TRY_WITHDRAW_SCAVENGE_ITEM = try_withdraw_scavenge_item
function try_withdraw_scavenge_item(pair)
  if pair and pair.scavenge and pair.scavenge.ground_stockpile_0291 then
    return tech_priests_0291_take_ground_stockpile(pair)
  end
  if TECH_PRIESTS_0291_PRE_TRY_WITHDRAW_SCAVENGE_ITEM then return TECH_PRIESTS_0291_PRE_TRY_WITHDRAW_SCAVENGE_ITEM(pair) end
  return false
end

TECH_PRIESTS_0291_PRE_MAYBE_START_SUPPLY_SCAVENGE = maybe_start_supply_scavenge
function maybe_start_supply_scavenge(pair, kind, target)
  if pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid then
    local request = (pair.active_supply_request and pair.active_supply_request.kind == kind) and pair.active_supply_request or (build_supply_request and build_supply_request(pair, kind, target) or nil)
    if request and (not tech_priests_abort_if_supply_request_obsolete or not tech_priests_abort_if_supply_request_obsolete(pair, request)) then
      local ground = tech_priests_0291_find_ground_stockpile_for_request(pair, request)
      if ground then
        pair.active_supply_request = request
        pair.inventory_scan = nil
        pair.scavenge = ground
        pair.target = ground.source
        pair.mode = "scavenging-supplies"
        if draw_priest_status_bubble then pcall(function() draw_priest_status_bubble(pair) end) end
        return handle_priest_scavenge_task and handle_priest_scavenge_task(pair) or true
      end
    end
  end
  if TECH_PRIESTS_0291_PRE_MAYBE_START_SUPPLY_SCAVENGE then return TECH_PRIESTS_0291_PRE_MAYBE_START_SUPPLY_SCAVENGE(pair, kind, target) end
  return false
end

if tech_priests_0287_kick_active_acquisition then
  TECH_PRIESTS_0291_PRE_KICK_ACTIVE_ACQUISITION = tech_priests_0287_kick_active_acquisition
  function tech_priests_0287_kick_active_acquisition(pair, reason, force)
    if pair and pair.active_supply_request then
      local ground = tech_priests_0291_find_ground_stockpile_for_request(pair, pair.active_supply_request)
      if ground then
        pair.inventory_scan = nil
        pair.scavenge = ground
        pair.target = ground.source
        pair.mode = "scavenging-supplies"
        return handle_priest_scavenge_task and handle_priest_scavenge_task(pair) or true
      end
    end
    return TECH_PRIESTS_0291_PRE_KICK_ACTIVE_ACQUISITION(pair, reason, force)
  end
end

if commands and commands.add_command then
  pcall(function()
    TechPriestsDebugCommandRegistry.add("tp-ground-0291", "Tech Priests: force local ground-stockpile scavenging check for selected pair.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      if not player then return end
      local pair = nil
      local selected = player.selected
      if selected and storage and storage.tech_priests then
        if storage.tech_priests.pairs_by_station and storage.tech_priests.pairs_by_station[selected.unit_number] then pair = storage.tech_priests.pairs_by_station[selected.unit_number] end
        if not pair and storage.tech_priests.pairs_by_priest and storage.tech_priests.pairs_by_priest[selected.unit_number] then pair = storage.tech_priests.pairs_by_priest[selected.unit_number] end
      end
      if not pair then player.print("[Tech Priests] Select a Cogitator Station or Tech-Priest first."); return end
      local request = pair.active_supply_request or (build_supply_request and build_supply_request(pair, pair.logistic_frustration_kind or "ammo", pair.target) or nil)
      local found = request and tech_priests_0291_find_ground_stockpile_for_request(pair, request) or nil
      if found then
        pair.scavenge = found
        pair.target = found.source
        pair.mode = "scavenging-supplies"
        if handle_priest_scavenge_task then pcall(function() handle_priest_scavenge_task(pair) end) end
      end
      player.print("[Tech Priests 0.1.291] ground-stockpile request=" .. tostring(request and request.kind or "none") .. " found=" .. tostring(found and found.item_name or "none") .. " mode=" .. tostring(pair.mode or "nil"))
    end)
  end)
end

tech_priests_0291_log("0.1.291 local ground-stockpile scavenging + emergency micro visual tune loaded")


-- -----------------------------------------------------------------------------
-- 0.1.292 combat/proxy-turret scheduler refactor
-- -----------------------------------------------------------------------------
-- Observed failure: Tech-Priests could point at an enemy while valid ammo sat in
-- the Cogitator Station, because older scavenge/cram/acquisition surfaces could
-- still run before combat and because combat state was not always being promoted
-- into the canonical active_task ledger.  This layer makes defense a hard
-- scheduler preemption and directly primes the hidden small-arms proxy turret.

TECH_PRIESTS_PATCH_0292 = "0.1.292-combat-proxy-refactor"
TECH_PRIESTS_0292_COMBAT_RECHECK_TICKS = 15
TECH_PRIESTS_0292_PROXY_DIAG_TICKS = 60

function tech_priests_0292_now()
  return game and game.tick or 0
end

function tech_priests_0292_log(msg)
  if tech_priests_0264_log then
    pcall(function() tech_priests_0264_log("[0.1.292] " .. tostring(msg), true) end)
  elseif log then
    log("[Tech-Priests 0.1.292] " .. tostring(msg))
  end
end

function tech_priests_0292_valid_pair(pair)
  return pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid
end

function tech_priests_0292_proxy_has_ammo(pair)
  if not (pair and pair.proxy and pair.proxy.valid and get_turret_ammo_inventory and turret_inventory_has_ammo) then return false end
  local inv = get_turret_ammo_inventory(pair.proxy)
  return inv and turret_inventory_has_ammo(inv) or false
end

function tech_priests_0292_station_has_ammo(pair)
  if not (pair and pair.station and pair.station.valid) then return false end
  if count_station_ammo_items then
    local ok, n = pcall(function() return count_station_ammo_items(pair.station) end)
    if ok and n and n > 0 then return true end
  end
  local inv = get_station_inventory and get_station_inventory(pair.station) or nil
  if inv and find_ammo_item then
    local ok, ammo = pcall(function() return find_ammo_item(inv) end)
    if ok and ammo then return true end
  end
  return false
end

function tech_priests_0292_select_target(pair)
  if not tech_priests_0292_valid_pair(pair) then return nil end
  local radius = refresh_pair_radius and refresh_pair_radius(pair) or pair.radius or COMBAT_FIRE_RANGE or 15
  if pair.combat_target and enemy_inside_station_radius and enemy_inside_station_radius(pair.station, pair.combat_target, radius) then
    return pair.combat_target
  end
  if find_enemy_target then
    local ok, target = pcall(function() return find_enemy_target(pair.station, radius, pair.priest) end)
    if ok and target and target.valid then
      pair.combat_target = target
      return target
    end
  end
  return nil
end

function tech_priests_0292_clear_lower_priority_surfaces(pair, reason)
  if not pair then return end
  -- Combat is the top of the activity stack.  Preserve the target, but remove
  -- stale acquisition/crafting/scavenge surfaces that otherwise return early
  -- before the proxy turret ever gets a chance to fire.
  pair.scavenge = nil
  pair.cram = nil
  pair.inventory_scan = nil
  pair.emergency_craft = nil
  pair.assignment_op_0252 = nil
  pair.scheduler_acquisition_op_0287 = nil
  pair.last_combat_preempt_reason_0292 = reason or "combat-preempt"
  pair.last_combat_preempt_tick_0292 = tech_priests_0292_now()
end

function tech_priests_0292_assign_combat_task(pair, target, reason)
  if not (pair and target and target.valid) then return false end
  local task = {
    type = "combat",
    target = target,
    priority = TECH_PRIESTS_0285_TASK_PRIORITY and TECH_PRIESTS_0285_TASK_PRIORITY.combat or 100,
    owner_system = "combat-proxy-0292",
    reason = reason or "enemy-pressure",
    updated_tick = tech_priests_0292_now(),
    expires_tick = tech_priests_0292_now() + (PROXY_KEEPALIVE_TICKS or 120)
  }
  if tech_priests_0285_assign_task then
    local ok, did = pcall(function() return tech_priests_0285_assign_task(pair, task, reason or "combat-preempt") end)
    if ok and did then return true end
  end
  pair.active_task = task
  pair.active_task_0285 = task
  pair.task_kind = "combat"
  pair.target = target
  pair.mode = "combat"
  return true
end

function tech_priests_0292_prime_proxy_attack(pair, target, reason)
  if not (tech_priests_0292_valid_pair(pair) and target and target.valid) then return false end
  local station = pair.station
  local priest = pair.priest
  local proxy = ensure_proxy and ensure_proxy(pair) or nil
  if not (proxy and proxy.valid) then
    pair.last_combat_fail_0292 = "no-proxy"
    return false
  end

  if tech_priests_align_proxy_to_priest_0430 then tech_priests_align_proxy_to_priest_0430(pair, proxy, priest, "combat proxy prime attached to visible priest") else pcall(function() proxy.teleport(priest.position) end) end
  pcall(function() proxy.active = true end)
  pcall(function() proxy.operable = false end)
  pcall(function() proxy.destructible = false end)

  if not tech_priests_0292_proxy_has_ammo(pair) then
    if not (load_proxy_from_station and load_proxy_from_station(pair)) then
      pair.mode = "missing-ammo-supplies"
      pair.target = target
      pair.combat_target = target
      pair.last_combat_fail_0292 = "no-compatible-ammo"
      pair.last_combat_fail_tick_0292 = tech_priests_0292_now()
      if maybe_start_supply_scavenge then pcall(function() maybe_start_supply_scavenge(pair, "ammo", target) end) end
      return true
    end
  end

  local dx = priest.position.x - target.position.x
  local dy = priest.position.y - target.position.y
  local dist_sq = dx * dx + dy * dy
  local fire_range = COMBAT_FIRE_RANGE or 15

  pcall(function() proxy.shooting_target = target end)
  pcall(function() proxy.active = true end)
  pair.proxy_expires = tech_priests_0292_now() + (PROXY_KEEPALIVE_TICKS or 120)
  pair.combat_target = target
  pair.target = target
  pair.mode = "defending"
  pair.task_kind = "combat"
  pair.last_proxy_target_0292 = target.name
  pair.last_proxy_prime_reason_0292 = reason or "combat-prime"
  pair.last_proxy_prime_tick_0292 = tech_priests_0292_now()

  if describe_proxy_state and ((tech_priests_0292_now() - (pair.last_proxy_diag_tick_0292 or 0)) >= TECH_PRIESTS_0292_PROXY_DIAG_TICKS) then
    pair.last_proxy_diag_tick_0292 = tech_priests_0292_now()
    pcall(function() describe_proxy_state(pair, proxy, target, "0292 prime") end)
  end

  if dist_sq > fire_range * fire_range then
    if issue_priest_command then
      pcall(function()
        issue_priest_command(priest, {
          type = defines.command.go_to_location,
          destination = target.position,
          radius = COMBAT_APPROACH_RADIUS or math.max(1, fire_range - 2),
          distraction = defines.distraction.by_enemy
        })
      end)
    end
    pair.mode = "moving-to-combat"
  else
    -- Keep the visual behavior of the Tech-Priest pointing/engaging, while the
    -- actual damage path remains the hidden proxy turret using real ammo.
    if issue_priest_command then
      pcall(function()
        issue_priest_command(priest, {
          type = defines.command.attack,
          target = target,
          distraction = defines.distraction.none
        })
      end)
    end
  end
  return true
end

function tech_priests_0292_force_combat_tick(pair, reason, force)
  if not tech_priests_0292_valid_pair(pair) then return false end
  local target = tech_priests_0292_select_target(pair)
  if not (target and target.valid) then return false end

  local has_ammo = tech_priests_0292_station_has_ammo(pair) or tech_priests_0292_proxy_has_ammo(pair)
  local current = pair.active_task or pair.active_task_0285
  local current_priority = tech_priests_0285_task_priority and tech_priests_0285_task_priority(current) or 0
  local combat_priority = TECH_PRIESTS_0285_TASK_PRIORITY and TECH_PRIESTS_0285_TASK_PRIORITY.combat or 100

  -- Interrupt every lower task as soon as enemy pressure exists.  If we lack
  -- ammo, the combat handler starts the ammo requisition path; if we have ammo,
  -- the proxy gets primed immediately and old scavenge/craft returns cannot
  -- starve the gun.
  if force or has_ammo or current_priority < combat_priority then
    tech_priests_0292_clear_lower_priority_surfaces(pair, reason or "enemy-pressure")
    tech_priests_0292_assign_combat_task(pair, target, reason or "enemy-pressure")
  end

  if handle_combat then
    local ok, handled = pcall(function() return handle_combat(pair) end)
    if ok and handled then
      -- Double-prime after legacy combat because some old branches set the
      -- visible priest command without refreshing the turret target afterward.
      tech_priests_0292_prime_proxy_attack(pair, target, reason or "post-handle-combat")
      return true
    elseif not ok then
      pair.last_combat_fail_0292 = "handle-combat-error: " .. tostring(handled)
    end
  end

  return tech_priests_0292_prime_proxy_attack(pair, target, reason or "direct-prime")
end

TECH_PRIESTS_0292_PRE_TICK_PAIR = tick_pair

TechPriestsRuntimeEventRegistry.on_nth_tick(17, function()
  if not (storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return end
  for _, pair in pairs(storage.tech_priests.pairs_by_station or {}) do
    pcall(function() tech_priests_0292_force_combat_tick(pair, "nth-tick-17", false) end)
  end
end)

if commands and commands.add_command then
  pcall(function()
    TechPriestsDebugCommandRegistry.add("tp-combat-0292", "Tech Priests: force combat/proxy-turret reacquisition for selected pair.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      if not player then return end
      local pair = nil
      local selected = player.selected
      if selected and storage and storage.tech_priests then
        if storage.tech_priests.pairs_by_station and storage.tech_priests.pairs_by_station[selected.unit_number] then pair = storage.tech_priests.pairs_by_station[selected.unit_number] end
        if not pair and storage.tech_priests.pairs_by_priest and storage.tech_priests.pairs_by_priest[selected.unit_number] then pair = storage.tech_priests.pairs_by_priest[selected.unit_number] end
      end
      if not pair then player.print("[Tech Priests] Select a Cogitator Station or Tech-Priest first."); return end
      local target = tech_priests_0292_select_target(pair)
      local did = tech_priests_0292_force_combat_tick(pair, "manual-command", true)
      local proxy_ammo = false
      if pair.proxy and pair.proxy.valid and get_turret_ammo_inventory and count_inventory_items then
        local inv = get_turret_ammo_inventory(pair.proxy)
        proxy_ammo = inv and count_inventory_items(inv) or 0
      end
      player.print("[Tech Priests 0.1.292] combat did=" .. tostring(did) .. " target=" .. tostring(target and target.name or "none") .. " station_ammo=" .. tostring(tech_priests_0292_station_has_ammo(pair)) .. " proxy_ammo=" .. tostring(proxy_ammo) .. " mode=" .. tostring(pair.mode or "nil") .. " fail=" .. tostring(pair.last_combat_fail_0292 or "none"))
    end)
  end)
end

tech_priests_0292_log("0.1.292 combat/proxy-turret scheduler refactor loaded")


-- -----------------------------------------------------------------------------
-- 0.1.293 combat hard-lock guard / proxy cadence limiter
-- -----------------------------------------------------------------------------
-- Runtime verification of 0.1.292 confirmed that the hidden proxy turret path can
-- fire, but Factorio hard-locked shortly after enemies died.  The most plausible
-- failure mode is not a Lua exception: it is an over-eager combat loop repeatedly
-- reassigning proxy targets and character attack commands every tick, plus an
-- on_nth_tick(17) global combat pass, while targets are dying/invalidating.
--
-- This layer makes combat edge-triggered and cadence-limited.  It preserves the
-- hidden real-ammo proxy turret, but stops hammering shooting_target and attack
-- commands continuously.

TECH_PRIESTS_PATCH_0293 = "0.1.293-combat-hardlock-guard"
TECH_PRIESTS_0293_COMBAT_PAIR_COOLDOWN = 12
TECH_PRIESTS_0293_COMBAT_COMMAND_COOLDOWN = 45
TECH_PRIESTS_0293_GLOBAL_SCAN_TICKS = 97

function tech_priests_0293_now()
  return game and game.tick or 0
end

function tech_priests_0293_log(msg)
  if tech_priests_0264_log then
    pcall(function() tech_priests_0264_log("[0.1.293] " .. tostring(msg), true) end)
  elseif log then
    log("[Tech-Priests 0.1.293] " .. tostring(msg))
  end
end

function tech_priests_0293_valid_pair(pair)
  return pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid
end

function tech_priests_0293_proxy_has_ammo(pair)
  if not (pair and pair.proxy and pair.proxy.valid and get_turret_ammo_inventory and turret_inventory_has_ammo) then return false end
  local ok, inv = pcall(function() return get_turret_ammo_inventory(pair.proxy) end)
  return ok and inv and turret_inventory_has_ammo(inv) or false
end

function tech_priests_0293_station_has_ammo(pair)
  if not (pair and pair.station and pair.station.valid) then return false end
  if count_station_ammo_items then
    local ok, n = pcall(function() return count_station_ammo_items(pair.station) end)
    if ok and n and n > 0 then return true end
  end
  local inv = get_station_inventory and get_station_inventory(pair.station) or nil
  if inv and find_ammo_item then
    local ok, ammo = pcall(function() return find_ammo_item(inv) end)
    if ok and ammo then return true end
  end
  return false
end

function tech_priests_0293_radius(pair)
  if refresh_pair_radius then
    local ok, r = pcall(function() return refresh_pair_radius(pair) end)
    if ok and r then return r end
  end
  return pair.radius or COMBAT_FIRE_RANGE or 15
end

function tech_priests_0293_clear_dead_combat(pair, reason)
  if not pair then return false end
  if pair.proxy and pair.proxy.valid then pcall(function() pair.proxy.shooting_target = nil end) end
  pair.combat_target = nil
  if pair.active_task and pair.active_task.type == "combat" then pair.active_task = nil end
  if pair.active_task_0285 and pair.active_task_0285.type == "combat" then pair.active_task_0285 = nil end
  if pair.mode == "combat" or pair.mode == "defending" or pair.mode == "moving-to-combat" then pair.mode = "idle" end
  pair.last_combat_clear_0293 = reason or "no-valid-target"
  pair.last_combat_clear_tick_0293 = tech_priests_0293_now()
  return true
end

function tech_priests_0293_select_target(pair)
  if not tech_priests_0293_valid_pair(pair) then return nil end
  local radius = tech_priests_0293_radius(pair)
  local old = pair.combat_target or pair.target
  if old and old.valid and enemy_inside_station_radius and enemy_inside_station_radius(pair.station, old, radius) then
    return old
  end
  pair.combat_target = nil
  if find_enemy_target then
    local ok, target = pcall(function() return find_enemy_target(pair.station, radius, pair.priest) end)
    if ok and target and target.valid then return target end
  end
  return nil
end
