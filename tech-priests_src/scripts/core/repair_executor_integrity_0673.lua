-- Tech Priests 0.1.661 repair executor integrity hardener.
-- Keeps repair_executor_0516 as the sole repair state machine while enforcing
-- truthful movement, reservation release, timer cleanup, physical repair-pack
-- accounting across station steward inventories, verified task submission,
-- bounded diagnostics history, and immediate order handoff.

local M = {
  version = "0.1.661",
  storage_key = "repair_executor_integrity_0673",
  noisy_history_window = 60,
}

local previous_service
local previous_submit
local previous_active
local previous_install
local previous_station_has_pack
local previous_consume_pack

local function now()
  return game and game.tick or 0
end

local function valid(entity)
  return entity and entity.valid
end

local function lower(value)
  return string.lower(tostring(value or ""))
end

local function safe(value)
  if value == nil then return "nil" end
  local ok, text = pcall(tostring, value)
  return ok and text or "?"
end

local function valid_pair(pair)
  return type(pair) == "table" and valid(pair.station) and valid(pair.priest)
end

local function station_unit(pair)
  return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number) or "nil") or "nil"
end

local function dist_sq(a, b)
  if not (a and b) then return nil end
  local dx = (a.x or a[1] or 0) - (b.x or b[1] or 0)
  local dy = (a.y or a[2] or 0) - (b.y or b[2] or 0)
  return dx * dx + dy * dy
end

local function load_module(name, global_name)
  local ok, module = pcall(require, name)
  if ok then return module end
  return rawget(_G, global_name)
end

local function Repair()
  return load_module("scripts.core.repair_executor_0516", "TechPriestsRepairExecutor0516")
end

local function Reservations()
  return load_module("scripts.core.work_reservations", "TechPriestsWorkReservations0601")
end

local function OrderQueue()
  return load_module("scripts.core.order_queue_0469", "TECH_PRIESTS_ORDER_QUEUE_0469")
end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local root = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    stats = {},
    recent = {},
  }
  storage.tech_priests[M.storage_key] = root
  root.version = M.version
  if root.enabled == nil then root.enabled = true end
  root.stats = root.stats or {}
  root.recent = root.recent or {}
  return root
end

local function stat(name, amount)
  local root = M.root()
  root.stats[name] = (root.stats[name] or 0) + (amount or 1)
end

local function record(pair, action, detail)
  local root = M.root()
  stat(action)
  root.recent[#root.recent + 1] = {
    tick = now(),
    station = station_unit(pair),
    action = tostring(action or "event"),
    detail = tostring(detail or ""),
  }
  while #root.recent > 120 do
    table.remove(root.recent, 1)
  end
end

local function order_kind(order)
  return lower(order and (order.kind or order.type or order.key or order.source) or "")
end

local function is_repair_order(order)
  local kind = order_kind(order)
  return kind == "repair" or kind:find("repair", 1, true) ~= nil
end

local function current_order(pair)
  local queue = pair and pair.order_queue_0469
  return pair and ((queue and queue.current) or pair.active_order_0469) or nil
end

local function target_from(value, seen)
  if valid(value) then return value end
  if type(value) ~= "table" then return nil end
  seen = seen or {}
  if seen[value] then return nil end
  seen[value] = true
  for _, key in ipairs({ "target", "entity", "machine", "source", "selected", "current", "task" }) do
    local target = target_from(value[key], seen)
    if target then return target end
  end
  return nil
end

local function candidate_target(pair, forced)
  if valid(forced) then return forced end
  local state = pair and pair.repair_0516
  if state and valid(state.target) then return state.target end
  local order = current_order(pair)
  if is_repair_order(order) then
    local target = target_from(order)
    if target then return target end
  end
  for _, field in ipairs({ "active_task", "active_task_0285" }) do
    local task = pair and pair[field]
    if type(task) == "table" and is_repair_order(task) then
      local target = target_from(task)
      if target then return target end
    end
  end
  return nil
end

local function target_keys(entity, state)
  if valid(entity) then
    if entity.unit_number then
      return tostring(entity.unit_number), "unit:" .. tostring(entity.unit_number)
    end
    local position = entity.position or { x = 0, y = 0 }
    local position_key = string.format("%.1f,%.1f", position.x or 0, position.y or 0)
    return tostring(entity.name) .. "@" .. position_key,
      "entity:" .. tostring(entity.name) .. ":" .. position_key
  end
  local unit = state and state.target_unit
  if unit then
    return tostring(unit), "unit:" .. tostring(unit)
  end
  return nil, nil
end

local function missing_health(entity)
  if not valid(entity) then return 0 end
  local helper = rawget(_G, "get_repair_pack_useful_missing_health")
  if type(helper) == "function" then
    local ok, value = pcall(helper, entity)
    if ok and tonumber(value) then
      return math.max(0, tonumber(value))
    end
  end
  if not (entity.health and entity.max_health) then return 0 end
  return math.max(0, (tonumber(entity.max_health) or 0) - (tonumber(entity.health) or 0))
end

local function pair_for_station(station)
  if not (valid(station) and station.unit_number and storage and storage.tech_priests) then
    return nil
  end
  local pairs = storage.tech_priests.pairs_by_station
  return pairs and pairs[station.unit_number] or nil
end

local function inventory_sources(pair)
  local sources = {}
  local seen = {}

  local function append(inventory, label)
    if inventory and inventory.valid and not seen[inventory] then
      seen[inventory] = true
      sources[#sources + 1] = {
        inv = inventory,
        label = label or "station",
      }
    end
  end

  local steward = rawget(_G, "tech_priests_inventory_steward_sources_for_pair")
  if type(steward) == "function" and valid_pair(pair) then
    local ok, listed = pcall(steward, pair)
    if ok and type(listed) == "table" then
      for _, source in ipairs(listed) do
        if source then
          append(source.inv or source.inventory, source.label or source.kind or source.source)
        end
      end
    end
  end

  local get_station_inventory = rawget(_G, "get_station_inventory")
  if type(get_station_inventory) == "function" and valid_pair(pair) then
    local ok, inventory = pcall(get_station_inventory, pair.station)
    if ok then append(inventory, "legacy-station-inventory") end
  end

  return sources
end

local function inventory_count(inventory, item_name)
  if not (inventory and inventory.valid and item_name) then return 0 end
  local ok, count = pcall(function()
    return inventory.get_item_count(item_name)
  end)
  return ok and (tonumber(count) or 0) or 0
end

local function pack_count(pair)
  local count = 0
  for _, source in ipairs(inventory_sources(pair)) do
    count = count + inventory_count(source.inv, "repair-pack")
  end
  return count
end

local function remove_pack_from_sources(pair)
  for _, source in ipairs(inventory_sources(pair)) do
    if inventory_count(source.inv, "repair-pack") > 0 then
      local ok, removed = pcall(function()
        return source.inv.remove({ name = "repair-pack", count = 1 })
      end)
      if ok and (tonumber(removed) or 0) > 0 then
        stat("steward_pack_removed")
        return true, source.label
      end
    end
  end
  return false, "no-pack-source"
end

local function insert_pack_into_sources(pair)
  local remaining = 1
  for _, source in ipairs(inventory_sources(pair)) do
    local ok, inserted = pcall(function()
      return source.inv.insert({ name = "repair-pack", count = remaining })
    end)
    if ok then
      remaining = remaining - (tonumber(inserted) or 0)
      if remaining <= 0 then
        stat("steward_pack_refunded")
        return true
      end
    end
  end

  if remaining > 0 and valid_pair(pair) and pair.station.surface and pair.station.surface.spill_item_stack then
    local ok = pcall(function()
      pair.station.surface.spill_item_stack({
        position = pair.station.position,
        stack = { name = "repair-pack", count = remaining },
        enable_looted = true,
        force = pair.station.force,
        allow_belts = false,
      })
    end)
    if ok then
      stat("repair_pack_refund_spilled")
      return true
    end
  end
  return false
end

local function patch_pack_helpers()
  if not previous_station_has_pack then
    previous_station_has_pack = rawget(_G, "station_has_repair_pack")
    _G.station_has_repair_pack = function(station)
      if M.root().enabled == false then
        if type(previous_station_has_pack) == "function" then
          local ok, result = pcall(previous_station_has_pack, station)
          return ok and result == true
        end
        return false
      end

      if type(previous_station_has_pack) == "function" then
        local ok, result = pcall(previous_station_has_pack, station)
        if ok and result == true then return true end
      end
      return pack_count(pair_for_station(station)) > 0
    end
  end

  if not previous_consume_pack then
    previous_consume_pack = rawget(_G, "consume_repair_pack")
    _G.consume_repair_pack = function(station)
      if M.root().enabled == false then
        if type(previous_consume_pack) == "function" then
          local ok, result = pcall(previous_consume_pack, station)
          return ok and result == true
        end
        return false
      end

      local pair = pair_for_station(station)
      local before = pack_count(pair)
      if type(previous_consume_pack) == "function" then
        local ok, result = pcall(previous_consume_pack, station)
        local after = pack_count(pair)
        if (ok and result == true) or after < before then
          return true
        end
      end
      return remove_pack_from_sources(pair)
    end
  end
end

local function release(pair, target, state)
  local local_key, shared_key = target_keys(target, state)
  local reservations = Reservations()

  if reservations and type(reservations.release) == "function" and valid(target) then
    pcall(reservations.release, "repair", target, pair)
  elseif reservations and type(reservations.root) == "function" and shared_key then
    local ok, root = pcall(reservations.root)
    local bucket = ok and root and root.reservations and root.reservations.repair
    if bucket then
      local reservation = bucket[shared_key]
      local pair_id = reservations.pair_id and reservations.pair_id(pair) or station_unit(pair)
      if not reservation or safe(reservation.pair_id) == safe(pair_id) then
        bucket[shared_key] = nil
      end
    end
  end

  local executor = Repair()
  if executor and type(executor.root) == "function" and local_key then
    local ok, root = pcall(executor.root)
    if ok and root and root.reservations then
      root.reservations[local_key] = nil
    end
  end
end

local function clear_tasks(pair, target)
  for _, field in ipairs({ "active_task", "active_task_0285" }) do
    local task = pair[field]
    if type(task) == "table" and is_repair_order(task) then
      local task_target = target_from(task)
      if not target or not task_target or task_target == target then
        pair[field] = nil
      end
    end
  end
end

local function clear_state(pair, phase, blocker, release_first)
  local state = pair.repair_0516 or {}
  local old_target = valid(state.target) and state.target or nil
  if release_first then
    release(pair, old_target, state)
  end
  if pair.target == old_target or (pair.target and not valid(pair.target)) then
    pair.target = nil
  end
  for _, field in ipairs({
    "target", "target_unit", "target_name", "target_source",
    "started_tick", "due_tick", "packs_used", "distance",
    "missing", "max_health", "last_restore", "integrity_target_key_0673",
  }) do
    state[field] = nil
  end
  if phase then state.phase = phase end
  if blocker ~= nil then state.last_blocker = blocker end
  pair.repair_0516 = state
end

local function append_order_history(pair, order, status, why)
  local queue = pair.order_queue_0469
  if not (queue and order) or order.integrity_history_0673 then return end
  queue.history = queue.history or {}
  queue.history[#queue.history + 1] = {
    tick = now(),
    key = order.key,
    kind = order.kind,
    item = order.item,
    status = status,
    why = why,
    source = "repair-integrity-0673",
  }
  while #queue.history > 200 do
    table.remove(queue.history, 1)
  end
  order.integrity_history_0673 = true
end

local function promote(pair, reason)
  local queue = OrderQueue()
  if queue and type(queue.tick_pair) == "function" then
    pcall(queue.tick_pair, pair, reason or "repair-integrity-promote-0673")
    stat("order_promote_attempted")
  end
end

local function finish(pair, target, reason, set_target_cooldown)
  local executor = Repair()
  local state = pair.repair_0516 or {}
  local root = executor and type(executor.root) == "function" and executor.root() or {}
  local local_key = target_keys(target, state)

  if set_target_cooldown and local_key then
    root.cooldowns = root.cooldowns or {}
    root.cooldowns[local_key] = now() + (tonumber(executor and executor.target_cooldown_ticks) or 120)
  end

  release(pair, target, state)
  pair.next_repair_tick_0516 = now() + (tonumber(executor and executor.pair_cooldown_ticks) or 20)
  pair.target = nil
  pair.mode = "idle"
  clear_tasks(pair, target)
  clear_state(pair, "complete", nil, false)

  local order = current_order(pair)
  if is_repair_order(order) then
    order.status = "complete"
    order.finished_tick = now()
    order.finish_reason = reason or "repair-complete-0673"
    append_order_history(pair, order, "complete", order.finish_reason)
    local queue = pair.order_queue_0469
    if queue and queue.current == order then queue.current = nil end
    if pair.active_order_0469 == order then pair.active_order_0469 = nil end
  end
  promote(pair, reason)
end

local function movement_matches(pair, target)
  local request = pair.movement_request_0418
  if not request and storage and storage.tech_priests then
    for _, key in ipairs({ "movement_controller_0418", "movement_controller_0419" }) do
      local root = storage.tech_priests[key]
      if root and root.requests then
        request = root.requests[tostring(station_unit(pair))]
        if request then break end
      end
    end
  end
  if not (request and valid(target)) then return false end

  local position = request.position or request.destination or request.target_position or request.target
  if valid(position) then position = position.position end
  if type(position) ~= "table" then return false end

  local owner = lower(request.owner or request.reason)
  if (dist_sq(position, target.position) or 999) > 4 then return false end
  return owner:find("repair", 1, true) ~= nil or owner:find("leaf", 1, true) ~= nil
end

local function task_installed(pair, target)
  local queue = pair.order_queue_0469
  local order = current_order(pair)
  if is_repair_order(order) then
    local order_target = target_from(order)
    if not target or not order_target or order_target == target then return true end
  end

  for _, pending in ipairs(queue and queue.pending or {}) do
    if is_repair_order(pending) then
      local pending_target = target_from(pending)
      if not target or not pending_target or pending_target == target then return true end
    end
  end

  for _, field in ipairs({ "active_task", "active_task_0285" }) do
    local task = pair[field]
    if type(task) == "table" and is_repair_order(task) then
      local task_target = target_from(task)
      if not target or not task_target or task_target == target then return true end
    end
  end
  return false
end

local function compact_executor_history()
  local executor = Repair()
  if not (executor and type(executor.root) == "function") then return 0 end
  local ok, root = pcall(executor.root)
  if not (ok and root and type(root.recent) == "table") then return 0 end

  local noisy = {
    walk = true,
    ["repair-progress"] = true,
    ["no-target"] = true,
    ["need-item"] = true,
    ["reservation-denied"] = true,
  }
  local newest = {}
  local removed = 0
  for index = #root.recent, 1, -1 do
    local event = root.recent[index]
    local action = event and tostring(event.action or "") or ""
    if noisy[action] then
      local key = action .. ":" .. tostring(event.station or "?")
      local tick = tonumber(event.tick) or 0
      if newest[key] and newest[key] - tick < M.noisy_history_window then
        table.remove(root.recent, index)
        removed = removed + 1
      else
        newest[key] = tick
      end
    end
  end
  if removed > 0 then
    stat("history_entries_compacted", removed)
  end
  return removed
end

local function patch_submit(executor)
  if previous_submit or type(executor.submit_or_assign_repair_task) ~= "function" then return end
  previous_submit = executor.submit_or_assign_repair_task

  executor.submit_or_assign_repair_task = function(pair, target, reason)
    if M.root().enabled == false then
      return previous_submit(pair, target, reason)
    end

    local ok, accepted = pcall(previous_submit, pair, target, reason)
    if not ok then
      record(pair, "submit_error", accepted)
      return false
    end

    local actual_target = valid(target) and target or candidate_target(pair)
    if accepted ~= false and task_installed(pair, actual_target) then
      return true
    end
    if not (valid_pair(pair) and valid(actual_target)) then
      record(pair, "submit_rejected", "no-installed-task")
      return false
    end

    local task = {
      type = "repair",
      kind = "repair",
      phase = "repair-service",
      key = "repair",
      visual = "repairing",
      target = actual_target,
      priority = 800,
      owner_system = "repair-executor-integrity-0673",
    }
    pair.active_task = task
    pair.active_task_0285 = task
    pair.target = actual_target
    pair.mode = "repairing"

    local submit = rawget(_G, "tech_priests_0469_submit_order")
    if type(submit) == "function" then
      local ok_submit, allowed, why = pcall(submit, pair, {
        kind = "repair",
        item = "repair-pack",
        target = actual_target,
        priority = 800,
        source = "repair_executor_integrity_0673",
        task = task,
      })
      if not ok_submit then
        record(pair, "order_submit_error", allowed)
      elseif allowed == false and why ~= "queued" and why ~= "duplicate" then
        record(pair, "order_submit_rejected", why)
      end
    end

    record(pair, "submit_recovered", reason)
    return true
  end
end

local function patch_active(executor)
  if previous_active or type(executor.active) ~= "function" then return end
  previous_active = executor.active

  executor.active = function(pair)
    if M.root().enabled == false then
      return previous_active(pair)
    end
    if not pair then return false end

    local phase = lower((pair.repair_0516 or {}).phase)
    if phase == "walk-to-target" or phase == "repair-target" then return true end
    if is_repair_order(current_order(pair)) then return true end
    if phase == "none"
      or phase == "complete"
      or phase == "cooldown"
      or phase == "no-target"
      or phase == "need-item"
      or phase == "target-invalid"
      or phase == "target-reserved"
      or phase == "movement-request-failed"
      or phase == "health-write-failed"
      or phase == "executor-error"
    then
      return false
    end
    return lower(pair.mode):find("repair", 1, true) ~= nil
  end
end

local function patch_service(executor)
  if previous_service or type(executor.service_pair) ~= "function" then return end
  previous_service = executor.service_pair

  executor.service_pair = function(pair, reason, forced_target)
    if M.root().enabled == false then
      return previous_service(pair, reason, forced_target)
    end
    if not valid_pair(pair) then return false, "invalid-pair" end

    local executor_root = type(executor.root) == "function" and executor.root() or {}
    if executor_root.dispatcher_owned == false and lower(reason):find("dispatcher", 1, true) then
      return false, "dispatcher-ownership-disabled"
    end

    local state = pair.repair_0516 or { phase = "none" }
    pair.repair_0516 = state
    local before_order = current_order(pair)
    local before_target = candidate_target(pair, forced_target)
    local before_health = valid(before_target) and tonumber(before_target.health)
    local before_count = pack_count(pair)
    local before_used = tonumber(state.packs_used) or 0

    if tonumber(pair.next_repair_tick_0516 or 0) > now() then
      release(pair, before_target, state)
      clear_state(pair, "cooldown", nil, false)
      pair.target = nil
      pair.mode = "repair-cooldown"
      compact_executor_history()
      return true, "cooldown"
    end

    if valid(before_target) then
      local local_key = target_keys(before_target, state)
      local cooldown_active = local_key
        and executor_root.cooldowns
        and (tonumber(executor_root.cooldowns[local_key]) or 0) > now()

      if missing_health(before_target) <= 0.01 or cooldown_active then
        finish(
          pair,
          before_target,
          cooldown_active and "repair-target-cooldown-0673" or "repair-already-full-0673",
          false
        )
        record(pair, "stale_target_completed", before_target.name)
        compact_executor_history()
        return true, "complete"
      end

      if state.integrity_target_key_0673 ~= local_key then
        state.started_tick = nil
        state.due_tick = nil
        state.packs_used = nil
        state.integrity_target_key_0673 = local_key
      end
    elseif state.target or state.target_unit then
      release(pair, nil, state)
      clear_state(pair, "target-invalid", "invalid-stale-target", false)
    end

    local ok, acted, why = pcall(previous_service, pair, reason, forced_target)
    compact_executor_history()

    if not ok then
      release(pair, candidate_target(pair, forced_target), pair.repair_0516)
      clear_state(pair, "executor-error", safe(acted), false)
      pair.mode = "repair-executor-error"
      record(pair, "service_error", acted)
      return false, "repair-executor-error"
    end

    state = pair.repair_0516 or state
    local after_target = valid(state.target) and state.target or before_target
    if valid(after_target) and not state.integrity_target_key_0673 then
      state.integrity_target_key_0673 = target_keys(after_target, state)
    end
    local result = tostring(why or "")

    if result == "walk-to-target" and valid(after_target) and not movement_matches(pair, after_target) then
      release(pair, after_target, state)
      clear_state(pair, "movement-request-failed", "missing-repair-movement-request-0673", false)
      pair.mode = "repair-movement-failed"
      record(pair, "false_movement_rejected", after_target.name)
      return false, "movement-request-failed"
    end

    if result == "no-repair-pack"
      or result == "consume-failed"
      or result == "movement-request-failed"
      or result == "target-reserved"
      or result == "no-eligible-target"
      or result == "target-invalid"
    then
      release(pair, after_target, state)
      clear_state(pair, state.phase, state.last_blocker or result, false)
      pair.target = nil
      if result == "no-repair-pack" or result == "consume-failed" then
        pair.mode = "missing-repair-supplies"
      end
      record(pair, "blocked_state_released", result)
      return acted, why
    end

    local charged = (tonumber(state.packs_used) or 0) > before_used or pack_count(pair) < before_count
    if charged and valid(after_target) and before_health then
      local after_health = tonumber(after_target.health) or before_health
      if after_health <= before_health + 0.001 then
        insert_pack_into_sources(pair)
        release(pair, after_target, state)
        clear_state(pair, "health-write-failed", "repair-pack-refunded-0673", false)
        pair.mode = "repair-health-write-failed"
        record(pair, "health_write_failed", after_target.name)
        return false, "health-write-failed"
      end
      state.last_restore = after_health - before_health
    end

    if executor_root.full_repair == false
      and result == "repair-pack-applied"
      and valid(after_target)
    then
      finish(pair, after_target, "repair-single-pack-complete-0673", true)
      record(pair, "single_pack_complete", after_target.name)
      return true, "complete"
    end

    if result == "complete" or state.phase == "complete" then
      local completed_target = valid(after_target) and after_target or before_target
      local completed_order = before_order or current_order(pair)
      if is_repair_order(completed_order) then
        completed_order.status = "complete"
        completed_order.finished_tick = completed_order.finished_tick or now()
        completed_order.finish_reason = completed_order.finish_reason or "repair-complete-0673"
        append_order_history(pair, completed_order, "complete", completed_order.finish_reason)
      end
      release(pair, completed_target, state)
      clear_tasks(pair, completed_target)
      clear_state(pair, "complete", nil, false)
      pair.target = nil
      pair.mode = "idle"
      promote(pair, "repair-complete-promote-0673")
      record(pair, "completion_hardened", completed_target and completed_target.name)
      return true, "complete"
    end

    return acted, why
  end
end

local function remove_command()
  if commands and commands.remove_command then
    pcall(commands.remove_command, "tp-repair-executor-0516")
  end
end

local function patch_install(executor)
  if previous_install or type(executor.install) ~= "function" then return end
  previous_install = executor.install
  executor.install = function(...)
    local result = previous_install(...)
    patch_pack_helpers()
    remove_command()
    return result
  end
end

local function patch_diagnostics()
  local diagnostics = rawget(_G, "TechPriestsEmergencyDiagnostics0468")
    or rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
  if not (diagnostics and type(diagnostics.pair_dump_lines) == "function")
    or diagnostics.repair_executor_integrity_0673_wrapped
  then
    return
  end

  local previous = diagnostics.pair_dump_lines
  diagnostics.repair_executor_integrity_0673_wrapped = true
  diagnostics.pair_dump_lines = function()
    local lines = previous()
    local root = M.root()
    lines[#lines + 1] = "PAIR-DUMP-0468 REPAIR-INTEGRITY-0673 enabled="
      .. safe(root.enabled)
      .. " completed=" .. safe(root.stats.completion_hardened or 0)
      .. " released=" .. safe(root.stats.blocked_state_released or 0)
      .. " false_move=" .. safe(root.stats.false_movement_rejected or 0)
      .. " health_fail=" .. safe(root.stats.health_write_failed or 0)
      .. " submit_recovered=" .. safe(root.stats.submit_recovered or 0)
      .. " steward_removed=" .. safe(root.stats.steward_pack_removed or 0)
      .. " steward_refunded=" .. safe(root.stats.steward_pack_refunded or 0)
      .. " history_compacted=" .. safe(root.stats.history_entries_compacted or 0)
    return lines
  end
end

function M.install()
  M.root()
  local executor = Repair()
  if not executor then
    if log then
      log("[Tech-Priests 0.1.661] repair integrity unavailable: repair_executor_0516 missing")
    end
    return false
  end

  patch_pack_helpers()
  patch_submit(executor)
  patch_active(executor)
  patch_service(executor)
  patch_install(executor)
  remove_command()
  patch_diagnostics()
  _G.TechPriestsRepairExecutorIntegrity0673 = M

  if log then
    log("[Tech-Priests 0.1.661] repair integrity installed; steward inventory access, reservation/timer cleanup, movement and health verification, history compaction, submission verification, and order handoff active")
  end
  return true
end

return M
