-- Tech Priests 0.1.664 machine-logistics integrity authority.
--
-- Repairs the 0.1.528 dispatcher wrapper without creating a second free-running
-- machine controller. Supply work is converted into an explicit physical chain:
--   station stock -> priest custody -> target machine -> physical insertion.
-- Machine output remains physically removed from its source and is protected by
-- a custody ledger until it reaches retention/waste storage. New machine work is
-- admitted only when it does not displace another concrete leaf task.

local M = {
  version = "0.1.664",
  storage_key = "machine_logistics_integrity_0682",
  station_reach_sq = 2.56,
  machine_reach_sq = 2.56,
  storage_reach_sq = 2.56,
  move_priority = 976,
  move_ttl = 60 * 10,
  reservation_ttl = 60 * 15,
  fetch_timeout = 60 * 14,
  leaf_ttl = 60 * 10,
}

local previous_machine_install
local previous_machine_service
local previous_leaf_truth

local TERMINAL_PHASES = {
  complete = true,
  completed = true,
  done = true,
  none = true,
  idle = true,
  failed = true,
  aborted = true,
}

local DIRECT_KINDS = {
  ["direct-mine-0273"] = true,
  ["direct-dirt-0273"] = true,
  ["direct-mine-0336"] = true,
  dirt = true,
}

local function now()
  return game and game.tick or 0
end

local function valid(entity)
  return entity and entity.valid
end

local function safe(value)
  if value == nil then return "nil" end
  local ok, text = pcall(tostring, value)
  return ok and text or "?"
end

local function lower(value)
  return string.lower(tostring(value or ""))
end

local function dist_sq(a, b)
  if not (a and b) then return 999999999 end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end

local function valid_pair(pair)
  return pair and valid(pair.station) and valid(pair.priest)
end

local function station_unit(pair)
  return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil
end

local function priest_unit(pair)
  return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil
end

local function pair_map()
  return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    physical_station_pickup = true,
    reserve_machine_targets = true,
    protect_custody = true,
    gate_new_machine_work = true,
    stats = {},
    recent = {},
    last_log = {},
  }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.physical_station_pickup == nil then r.physical_station_pickup = true end
  if r.reserve_machine_targets == nil then r.reserve_machine_targets = true end
  if r.protect_custody == nil then r.protect_custody = true end
  if r.gate_new_machine_work == nil then r.gate_new_machine_work = true end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  r.last_log = r.last_log or {}
  return r
end

local function stat(name, amount)
  local r = root()
  r.stats[name] = (r.stats[name] or 0) + (amount or 1)
end

local function record(pair, action, detail, force_log)
  local r = root()
  stat(action)
  local event = {
    tick = now(),
    action = tostring(action or "event"),
    station = safe(station_unit(pair)),
    priest = safe(priest_unit(pair)),
    detail = tostring(detail or ""),
  }
  r.recent[#r.recent + 1] = event
  while #r.recent > 180 do table.remove(r.recent, 1) end
  if pair then pair.machine_logistics_integrity_last_0682 = event end

  local key = event.action .. ":" .. event.station
  local last = tonumber(r.last_log[key] or -1000000) or -1000000
  if force_log or now() - last >= 600 then
    r.last_log[key] = now()
    if log then
      log("[Tech-Priests 0.1.664] " .. event.action
        .. " station=" .. event.station
        .. " priest=" .. event.priest
        .. " " .. safe(detail))
    end
  end
  return event
end

local function machine_module()
  local ok, module = pcall(require, "scripts.core.logistics_machine_fulfillment_0528")
  return ok and module or nil
end

local function reservations_module()
  local reservations = rawget(_G, "TechPriestsWorkReservations0601")
  if reservations then return reservations end
  local ok, module = pcall(require, "scripts.core.work_reservations")
  return ok and module or nil
end

local function ensure_reservation_category()
  local reservations = reservations_module()
  if not reservations then return nil end
  local found = false
  for _, category in ipairs(reservations.categories or {}) do
    if category == "machine-logistics" then found = true break end
  end
  if not found then
    reservations.categories = reservations.categories or {}
    reservations.categories[#reservations.categories + 1] = "machine-logistics"
  end
  local r = type(reservations.root) == "function" and reservations.root() or nil
  if r then
    r.reservations = r.reservations or {}
    r.reservations["machine-logistics"] = r.reservations["machine-logistics"] or {}
  end
  return reservations
end

local function reservation_target(state)
  if state and valid(state.machine) then return state.machine end
  if state and state.machine_unit then return { unit_number = state.machine_unit } end
  return nil
end

local function claim_machine(pair, state)
  if root().reserve_machine_targets == false then return true, "disabled" end
  local reservations = ensure_reservation_category()
  local target = reservation_target(state)
  if not (reservations and target and type(reservations.claim) == "function") then
    return false, "reservation-unavailable"
  end
  local ok, why = reservations.claim(
    "machine-logistics",
    target,
    pair,
    M.reservation_ttl,
    {
      surface_index = valid(pair.station) and pair.station.surface.index or nil,
      force_index = valid(pair.station) and pair.station.force.index or nil,
      item = state and state.item,
      action = state and state.action,
    }
  )
  if ok then
    state.machine_reservation_0682 = true
    state.machine_reservation_tick_0682 = now()
    stat("machine_reservation_claimed")
  else
    stat("machine_reservation_denied")
  end
  return ok, why
end

local function release_machine(pair, state)
  local reservations = reservations_module()
  local target = reservation_target(state)
  if reservations and target and type(reservations.release) == "function" then
    local ok = reservations.release("machine-logistics", target, pair)
    if ok then stat("machine_reservation_released") end
    return ok
  end
  return false
end

local function inventory(entity, inventory_id)
  if not (valid(entity) and inventory_id and entity.get_inventory) then return nil end
  local ok, inv = pcall(function() return entity.get_inventory(inventory_id) end)
  return ok and inv and inv.valid and inv or nil
end

local function add_inventory(out, seen, inv)
  if not (inv and inv.valid) then return end
  local key = safe(inv)
  if seen[key] then return end
  seen[key] = true
  out[#out + 1] = inv
end

local function station_inventories(pair)
  local out, seen = {}, {}
  if not valid_pair(pair) then return out end

  if type(_G.get_station_inventory) == "function" then
    local ok, inv = pcall(_G.get_station_inventory, pair.station)
    if ok then add_inventory(out, seen, inv) end
  end

  local ids = {}
  local d = defines and defines.inventory or nil
  local function add_id(value) if value then ids[#ids + 1] = value end end
  if d then
    add_id(d.chest)
    add_id(d.assembling_machine_input)
    add_id(d.assembling_machine_output)
    add_id(d.furnace_source)
    add_id(d.furnace_result)
  end
  for _, inventory_id in ipairs(ids) do
    add_inventory(out, seen, inventory(pair.station, inventory_id))
  end
  return out
end

local function inventory_count(inv, item)
  if not (inv and inv.valid and item) then return 0 end
  local ok, count = pcall(function() return inv.get_item_count(item) end)
  return ok and (tonumber(count) or 0) or 0
end

local function station_count(pair, item)
  if not (valid_pair(pair) and item) then return 0 end
  local total = 0
  for _, inv in ipairs(station_inventories(pair)) do
    total = total + inventory_count(inv, item)
  end
  return total
end

local function remove_from_station(pair, item, requested)
  local remaining = math.max(1, tonumber(requested) or 1)
  local removed = 0
  for _, inv in ipairs(station_inventories(pair)) do
    if remaining <= 0 then break end
    local ok, amount = pcall(function()
      return inv.remove({ name = item, count = remaining })
    end)
    amount = ok and (tonumber(amount) or 0) or 0
    removed = removed + amount
    remaining = remaining - amount
  end
  return removed
end

local function insert_into_station(pair, item, requested)
  local remaining = math.max(0, tonumber(requested) or 0)
  local inserted = 0
  for _, inv in ipairs(station_inventories(pair)) do
    if remaining <= 0 then break end
    local ok, amount = pcall(function()
      return inv.insert({ name = item, count = remaining })
    end)
    amount = ok and (tonumber(amount) or 0) or 0
    inserted = inserted + amount
    remaining = remaining - amount
  end
  return inserted
end

local function machine_input_inventory(machine)
  local d = defines and defines.inventory
  if not d then return nil end
  return inventory(machine, d.assembling_machine_input)
    or inventory(machine, d.furnace_source)
end

local function machine_fuel_inventory(machine)
  local d = defines and defines.inventory
  return d and inventory(machine, d.fuel) or nil
end

local function container_inventory(entity)
  local d = defines and defines.inventory
  if not d then return nil end
  return inventory(entity, d.chest)
    or inventory(entity, d.car_trunk)
    or inventory(entity, d.spider_trunk)
end

local function insert_inventory(inv, item, count)
  if not (inv and inv.valid and item and (tonumber(count) or 0) > 0) then return 0 end
  local ok, inserted = pcall(function()
    return inv.insert({ name = item, count = count })
  end)
  return ok and (tonumber(inserted) or 0) or 0
end

local function machine_label(machine)
  if not valid(machine) then return "invalid machine" end
  return tostring(machine.name) .. "#" .. tostring(machine.unit_number or "?")
end

local function item_from(value)
  if type(value) == "string" then return value end
  if type(value) ~= "table" then return nil end
  local current = value.current or value.request or value.task or value
  return current.item or current.item_name or current.output_item
    or current.requested_item or current.wanted_item or current.target_item
end

local function matching_machine_request(request, state)
  if type(request) ~= "table" or type(state) ~= "table" then return false end
  if tostring(request.source or "") ~= "machine-logistics-0528" then return false end
  local request_item = item_from(request)
  if request_item and state.item and request_item ~= state.item then return false end
  if request.machine_unit and state.machine_unit
    and tostring(request.machine_unit) ~= tostring(state.machine_unit)
  then
    return false
  end
  return true
end

local function clear_matching_requests(pair, state)
  if not pair then return end
  if matching_machine_request(pair.active_supply_request, state) then
    pair.active_supply_request = nil
    stat("active_supply_request_cleared")
  end
  if matching_machine_request(pair.logistic_requested_item, state) then
    pair.logistic_requested_item = nil
    stat("logistic_requested_item_cleared")
  end
end

local function movement_request_owner(pair)
  local request = pair and pair.movement_request_0418
  return lower(request and request.owner or pair and pair.movement_controller_owner_0418 or "")
end

local function current_direct_task(pair)
  if not pair then return nil end
  for _, key in ipairs({ "emergency_craft", "direct_acquisition_task_0336", "active_acquisition_0333" }) do
    local task = pair[key]
    local current = type(task) == "table" and (task.current or task) or nil
    if current and DIRECT_KINDS[tostring(current.kind or "")] then return current end
  end
  return nil
end

local function active_phase(state)
  if type(state) ~= "table" then return false end
  local phase = lower(state.phase)
  return phase ~= "" and not TERMINAL_PHASES[phase]
end

local function active_non_machine_leaf(pair, machine_state)
  local leaf = pair and pair.active_leaf_task_0655
  if type(leaf) ~= "table" then return false, nil end
  local age = now() - (tonumber(leaf.tick) or -1000000)
  if age > M.leaf_ttl then return false, nil end
  local phase = lower(leaf.phase)
  if TERMINAL_PHASES[phase] then return false, nil end
  local source = lower(leaf.source)
  if source:find("machine%-logistics", 1, false) then return false, nil end

  -- The canonical 0527 fetch leaf is allowed only when it is fulfilling this
  -- exact machine task. It remains the physical source leg beneath 0528.
  if source:find("logistics_fetch_0527", 1, true)
    and machine_state
    and lower(machine_state.phase) == "waiting-known-source-fetch"
    and (not leaf.item or not machine_state.item or leaf.item == machine_state.item)
  then
    return false, nil
  end
  return true, "leaf:" .. safe(leaf.family) .. ":" .. safe(leaf.phase)
end

local function concrete_blocker(pair)
  if not valid_pair(pair) then return "invalid-pair" end
  if valid(pair.combat_target) then return "combat-target" end

  local blocked, reason = active_non_machine_leaf(pair, pair.machine_logistics_0528)
  if blocked then return reason end

  for _, field in ipairs({ "repair_0516", "combat_repair_0517", "consecration_0515" }) do
    if active_phase(pair[field]) then return field .. ":" .. safe(pair[field].phase) end
  end

  if current_direct_task(pair) then return "direct-acquisition" end

  for _, field in ipairs({
    "construction_task_0519",
    "construction_task",
    "active_construction_task",
    "construction_planner_task",
    "construction_site_task",
    "bootstrap_construction_task_0645",
  }) do
    if active_phase(pair[field]) then return field .. ":" .. safe(pair[field].phase) end
  end

  local mode = lower(pair.mode)
  if mode ~= "" and not mode:find("machine%-logistics", 1, false) then
    for _, needle in ipairs({ "combat", "repair", "consecr", "construct", "direct%-acquisition" }) do
      if mode:find(needle, 1, false) then return "mode:" .. mode end
    end
  end

  local owner = movement_request_owner(pair)
  local request = pair.movement_request_0418
  if request and tonumber(request.priority or 0) >= M.move_priority
    and owner ~= ""
    and not owner:find("machine%-logistics", 1, false)
    and not owner:find("logistics%-fetch", 1, false)
  then
    return "movement-owner:" .. owner
  end
  return nil
end

local function publish_leaf(pair, state, phase, target, label)
  if not (valid_pair(pair) and valid(target)) then return end
  pair.active_leaf_task_0655 = {
    version = M.version,
    tick = now(),
    family = "logistics",
    phase = phase,
    item = state and state.item,
    parent_item = nil,
    label = label,
    target_name = target.name,
    target_unit = target.unit_number,
    x = target.position.x,
    y = target.position.y,
    source = "machine_logistics_integrity_0682",
  }
  pair.actual_task_status_0655 = pair.active_leaf_task_0655
  pair.current_work_target_0655 = target
  pair.target = target
end

local function request_move(pair, target, reason, radius)
  if not (valid_pair(pair) and valid(target)) then return false end
  pair.target = target
  local ok, result = false, nil
  if type(_G.tech_priests_request_movement_0418) == "function" then
    ok, result = pcall(
      _G.tech_priests_request_movement_0418,
      pair,
      target.position,
      reason or "machine-logistics-integrity-0682",
      {
        owner = "machine-logistics-integrity-0682",
        priority = M.move_priority,
        ttl = M.move_ttl,
        radius = radius or 1.2,
        distraction = defines and defines.distraction and defines.distraction.none or nil,
      }
    )
  end
  if ok and result ~= false then
    stat("movement_requested")
    return true
  end
  stat("movement_request_failed")
  return false
end

local function sync_custody(pair, state, reason)
  local carried = state and state.carried
  if type(carried) == "table"
    and carried.item
    and (tonumber(carried.count) or 0) > 0
  then
    pair.machine_logistics_custody_0682 = {
      version = M.version,
      tick = now(),
      item = carried.item,
      count = tonumber(carried.count) or 0,
      kind = carried.kind or "retention",
      source_machine_unit = state.machine_unit,
      source_machine_name = state.machine_name,
      storage_unit = valid(state.storage) and state.storage.unit_number or state.storage_unit,
      reason = tostring(reason or state.phase or "custody"),
    }
    return true
  end
  pair.machine_logistics_custody_0682 = nil
  return false
end

local function restore_orphaned_custody(pair)
  local custody = pair and pair.machine_logistics_custody_0682
  if not (valid_pair(pair)
    and type(custody) == "table"
    and custody.item
    and (tonumber(custody.count) or 0) > 0)
  then
    return false
  end
  if type(pair.machine_logistics_0528) == "table" then return false end

  pair.machine_logistics_0528 = {
    phase = "return-custody-to-station",
    action = "custody-recovery",
    item = custody.item,
    count = custody.count,
    kind = custody.kind,
    carried = {
      item = custody.item,
      count = custody.count,
      kind = custody.kind,
    },
    machine_unit = custody.source_machine_unit,
    machine_name = custody.source_machine_name,
    started_tick = now(),
    custody_recovery_0682 = true,
  }
  pair.mode = "machine-logistics-custody-recovery"
  record(pair, "orphaned-custody-restored", custody.item .. " x" .. safe(custody.count), true)
  return true
end

local function clear_leaf_if_owned(pair)
  local leaf = pair and pair.active_leaf_task_0655
  if type(leaf) == "table" and leaf.source == "machine_logistics_integrity_0682" then
    pair.active_leaf_task_0655 = nil
    pair.actual_task_status_0655 = nil
    pair.current_work_target_0655 = nil
  end
end

local function finish_task(pair, state, reason)
  release_machine(pair, state)
  clear_matching_requests(pair, state)
  pair.machine_logistics_custody_0682 = nil
  pair.machine_logistics_integrity_last_task_0682 = {
    tick = now(),
    action = state and state.action,
    item = state and state.item,
    machine_unit = state and state.machine_unit,
    reason = tostring(reason or "complete"),
  }
  pair.machine_logistics_0528 = nil
  clear_leaf_if_owned(pair)
  if lower(pair.mode):find("machine%-logistics", 1, false) then pair.mode = "idle" end
  record(pair, "machine-task-finished", tostring(reason or "complete"))
  return true, reason or "machine-task-finished"
end

local function prepare_station_pickup(pair, state, reason)
  if not (valid_pair(pair) and type(state) == "table" and valid(state.machine)) then
    return false, "invalid-supply-task"
  end
  state.phase = "move-to-station-for-supply"
  state.integrity_physical_supply_0682 = true
  state.pickup_started_tick_0682 = state.pickup_started_tick_0682 or now()
  state.tick = now()
  pair.mode = "machine-logistics-collecting-supply"
  publish_leaf(
    pair,
    state,
    "collect-station-supply",
    pair.station,
    "Collecting " .. safe(state.item) .. " from Cogitator for " .. machine_label(state.machine)
  )
  local moved = request_move(pair, pair.station, "machine-supply-station-pickup-0682", 1.2)
  record(pair, "supply-routed-through-station", safe(state.item) .. " -> " .. machine_label(state.machine) .. " reason=" .. safe(reason))
  return moved or dist_sq(pair.priest.position, pair.station.position) <= M.station_reach_sq,
    moved and "moving-to-station-for-supply" or "station-pickup-adjacent"
end

local function custody_target(pair, state)
  if state and valid(state.storage) then return state.storage, "recorded-storage" end
  return pair and pair.station or nil, "station-recovery"
end

local function service_custody_return(pair, state)
  local carried = state and state.carried
  if not (type(carried) == "table" and carried.item and (tonumber(carried.count) or 0) > 0) then
    return finish_task(pair, state, "empty-custody")
  end

  local target, target_kind = custody_target(pair, state)
  if not valid(target) then return true, "custody-target-unavailable" end
  if dist_sq(pair.priest.position, target.position) > M.storage_reach_sq then
    state.phase = target == pair.station and "return-custody-to-station" or "move-to-storage"
    pair.mode = "machine-logistics-returning-custody"
    publish_leaf(
      pair,
      state,
      "return-custody",
      target,
      "Returning " .. safe(carried.item) .. " to " .. safe(target.name)
    )
    request_move(pair, target, "machine-custody-return-0682", 1.2)
    sync_custody(pair, state, target_kind)
    return true, "returning-custody"
  end

  local inserted = 0
  if target == pair.station then
    inserted = insert_into_station(pair, carried.item, carried.count)
  else
    inserted = insert_inventory(container_inventory(target), carried.item, carried.count)
  end
  if inserted > 0 then
    carried.count = carried.count - inserted
    record(pair, "custody-deposited", carried.item .. " x" .. safe(inserted) .. " -> " .. safe(target.name))
  end
  if carried.count <= 0 then
    return finish_task(pair, state, "custody-deposited")
  end

  state.phase = "custody-deposit-blocked"
  pair.mode = "machine-logistics-custody-blocked"
  sync_custody(pair, state, "deposit-blocked")
  record(pair, "custody-deposit-blocked", carried.item .. " remaining=" .. safe(carried.count) .. " target=" .. safe(target.name))
  return true, "custody-deposit-blocked"
end

local function service_physical_supply(pair, state)
  if not valid(state.machine) then
    if sync_custody(pair, state, "machine-invalid") then
      state.phase = "return-custody-to-station"
      return service_custody_return(pair, state)
    end
    return finish_task(pair, state, "machine-invalid")
  end

  local claimed, why = claim_machine(pair, state)
  if not claimed then
    if sync_custody(pair, state, "reservation-lost") then
      state.phase = "return-custody-to-station"
      return service_custody_return(pair, state)
    end
    clear_matching_requests(pair, state)
    pair.machine_logistics_0528 = nil
    record(pair, "machine-reservation-blocked", machine_label(state.machine) .. " reason=" .. safe(why))
    return false, "machine-reservation-blocked"
  end

  local phase = lower(state.phase)
  if phase == "move-to-machine" and not state.integrity_physical_supply_0682 then
    return prepare_station_pickup(pair, state, "legacy-state-conversion")
  end

  if phase == "move-to-station-for-supply" or phase == "collect-station-supply" then
    if dist_sq(pair.priest.position, pair.station.position) > M.station_reach_sq then
      pair.mode = "machine-logistics-collecting-supply"
      publish_leaf(
        pair,
        state,
        "collect-station-supply",
        pair.station,
        "Collecting " .. safe(state.item) .. " from Cogitator for " .. machine_label(state.machine)
      )
      request_move(pair, pair.station, "machine-supply-station-pickup-0682", 1.2)
      return true, "moving-to-station-for-supply"
    end

    local available = station_count(pair, state.item)
    local requested = math.max(1, tonumber(state.count) or 1)
    local take = math.min(requested, available)
    if take <= 0 then
      state.phase = "waiting-known-source-fetch"
      state.tick = now()
      state.integrity_physical_supply_0682 = nil
      record(pair, "station-supply-missing", safe(state.item) .. " for " .. machine_label(state.machine))
      return false, "station-supply-missing"
    end

    local removed = remove_from_station(pair, state.item, take)
    if removed <= 0 then
      state.phase = "waiting-known-source-fetch"
      state.tick = now()
      state.integrity_physical_supply_0682 = nil
      record(pair, "station-pickup-failed", safe(state.item) .. " for " .. machine_label(state.machine))
      return false, "station-pickup-failed"
    end

    state.carried = {
      item = state.item,
      count = removed,
      kind = "machine-supply",
    }
    state.phase = "move-to-machine"
    state.integrity_physical_supply_0682 = true
    state.station_pickup_tick_0682 = now()
    clear_matching_requests(pair, state)
    sync_custody(pair, state, "station-picked-up")
    pair.mode = "machine-logistics-delivering-supply"
    publish_leaf(
      pair,
      state,
      "deliver-machine-supply",
      state.machine,
      "Delivering " .. safe(state.item) .. " to " .. machine_label(state.machine)
    )
    request_move(pair, state.machine, "machine-supply-delivery-0682", 1.2)
    record(pair, "station-supply-picked-up", state.item .. " x" .. safe(removed) .. " -> " .. machine_label(state.machine))
    return true, "station-supply-picked-up"
  end

  if phase == "move-to-machine" then
    local carried = state.carried
    if not (type(carried) == "table" and carried.item and (tonumber(carried.count) or 0) > 0) then
      return prepare_station_pickup(pair, state, "missing-custody")
    end

    if dist_sq(pair.priest.position, state.machine.position) > M.machine_reach_sq then
      pair.mode = "machine-logistics-delivering-supply"
      publish_leaf(
        pair,
        state,
        "deliver-machine-supply",
        state.machine,
        "Delivering " .. safe(carried.item) .. " to " .. machine_label(state.machine)
      )
      request_move(pair, state.machine, "machine-supply-delivery-0682", 1.2)
      sync_custody(pair, state, "moving-to-machine")
      return true, "moving-to-machine-with-supply"
    end

    local target_inventory
    if state.action == "supply-fuel" then
      target_inventory = machine_fuel_inventory(state.machine)
    else
      target_inventory = machine_input_inventory(state.machine)
    end
    if not (target_inventory and target_inventory.valid) then
      state.phase = "return-custody-to-station"
      record(pair, "machine-target-inventory-missing", machine_label(state.machine) .. " action=" .. safe(state.action))
      return service_custody_return(pair, state)
    end

    local inserted = insert_inventory(target_inventory, carried.item, carried.count)
    if inserted > 0 then
      carried.count = carried.count - inserted
      state.delivered_count_0682 = (tonumber(state.delivered_count_0682) or 0) + inserted
      record(pair, "machine-supply-inserted", carried.item .. " x" .. safe(inserted) .. " -> " .. machine_label(state.machine))
    end

    if carried.count <= 0 then
      return finish_task(pair, state, "machine-supply-complete")
    end

    state.phase = "return-custody-to-station"
    pair.mode = "machine-logistics-returning-leftover"
    sync_custody(pair, state, "machine-partial-insert")
    publish_leaf(
      pair,
      state,
      "return-supply-leftover",
      pair.station,
      "Returning unused " .. safe(carried.item) .. " to Cogitator"
    )
    request_move(pair, pair.station, "machine-supply-leftover-return-0682", 1.2)
    return true, inserted > 0 and "partial-machine-insert" or "machine-insert-blocked"
  end

  if phase == "return-custody-to-station"
    or phase == "custody-deposit-blocked"
  then
    state.storage = nil
    return service_custody_return(pair, state)
  end

  return false, "unhandled-physical-supply-phase:" .. safe(state.phase)
end

local function service_waiting_fetch(pair, state)
  local claimed, why = claim_machine(pair, state)
  if not claimed then
    clear_matching_requests(pair, state)
    pair.machine_logistics_0528 = nil
    record(pair, "waiting-machine-reservation-denied", safe(state.item) .. " reason=" .. safe(why))
    return false, "machine-reservation-blocked"
  end

  local waited = now() - (tonumber(state.tick or state.started_tick) or now())
  if waited >= M.fetch_timeout then
    clear_matching_requests(pair, state)
    return finish_task(pair, state, "known-source-fetch-timeout-0682")
  end

  local needed = math.max(1, tonumber(state.count) or 1)
  if station_count(pair, state.item) >= needed then
    state.action = state.fulfill_action or (state.action == "request-fuel" and "supply-fuel" or "supply-ingredient")
    return prepare_station_pickup(pair, state, "fetch-now-stocked")
  end

  -- Returning false is intentional. The outer 0528 dispatcher wrapper then
  -- falls through to 0527 and finally to raw acquisition/crafting if no known
  -- physical inventory contains the exact requested item.
  return false, "waiting-known-source-fetch"
end

local function is_supply_state(state)
  if type(state) ~= "table" then return false end
  local action = lower(state.action)
  local fulfill = lower(state.fulfill_action)
  return action == "supply-fuel"
    or action == "supply-ingredient"
    or action == "request-fuel"
    or action == "request-ingredient"
    or fulfill == "supply-fuel"
    or fulfill == "supply-ingredient"
    or state.integrity_physical_supply_0682 == true
end

local function postprocess_original_result(pair, acted, why)
  local state = pair and pair.machine_logistics_0528
  if type(state) ~= "table" then
    if pair and pair.machine_logistics_custody_0682 then restore_orphaned_custody(pair) end
    return acted, why
  end

  if lower(state.phase) == "complete" then
    return finish_task(pair, state, why or "legacy-complete")
  end

  if state.carried then sync_custody(pair, state, why or state.phase) end

  if lower(state.phase) == "waiting-known-source-fetch" then
    return service_waiting_fetch(pair, state)
  end

  if is_supply_state(state) and lower(state.phase) == "move-to-machine"
    and not state.integrity_physical_supply_0682
  then
    return prepare_station_pickup(pair, state, "new-task-conversion")
  end

  local claimed, claim_why = claim_machine(pair, state)
  if not claimed then
    if state.carried then
      state.phase = "return-custody-to-station"
      return service_custody_return(pair, state)
    end
    clear_matching_requests(pair, state)
    pair.machine_logistics_0528 = nil
    record(pair, "new-machine-task-reservation-denied", safe(claim_why))
    return false, "machine-reservation-blocked"
  end

  -- A nonterminal machine task owns this dispatcher pulse even when its current
  -- movement/deposit action could not advance. Do not let another family begin
  -- behind a still-live machine custody chain.
  if active_phase(state) then return true, why or "machine-task-held" end
  return acted, why
end

local function patched_service_pair(pair, reason, ...)
  local r = root()
  if r.enabled == false or not valid_pair(pair) then
    return previous_machine_service(pair, reason, ...)
  end

  restore_orphaned_custody(pair)
  local state = pair.machine_logistics_0528

  if type(state) == "table" then
    local phase = lower(state.phase)
    if TERMINAL_PHASES[phase] then
      return finish_task(pair, state, phase)
    end

    if valid(pair.combat_target) then
      sync_custody(pair, state, "combat-suspended")
      record(pair, "machine-task-suspended-for-combat", safe(state.action) .. ":" .. safe(state.item))
      return false, "combat-priority-machine-suspended"
    end

    if phase == "waiting-known-source-fetch" then
      return service_waiting_fetch(pair, state)
    end

    if is_supply_state(state) then
      return service_physical_supply(pair, state)
    end

    if state.carried and not valid(state.machine) then
      state.phase = valid(state.storage) and "move-to-storage" or "return-custody-to-station"
      return service_custody_return(pair, state)
    end

    local acted, why = previous_machine_service(pair, reason, ...)
    return postprocess_original_result(pair, acted, why)
  end

  if r.gate_new_machine_work ~= false then
    local blocker = concrete_blocker(pair)
    if blocker then
      stat("new_machine_task_blocked")
      pair.machine_logistics_admission_block_0682 = {
        tick = now(),
        reason = blocker,
      }
      return false, "machine-logistics-admission-blocked:" .. blocker
    end
  end

  pair.machine_logistics_admission_block_0682 = nil
  local acted, why = previous_machine_service(pair, reason, ...)
  return postprocess_original_result(pair, acted, why)
end

local function machine_truth(pair)
  if not valid_pair(pair) or valid(pair.combat_target) then return nil end
  local state = pair.machine_logistics_0528
  if type(state) ~= "table" then return nil end
  local phase = lower(state.phase)
  if TERMINAL_PHASES[phase] or phase == "waiting-known-source-fetch" then return nil end

  local target, label, truth_phase
  if phase == "move-to-station-for-supply" or phase == "collect-station-supply" then
    target = pair.station
    truth_phase = "collect-station-supply"
    label = "Collecting " .. safe(state.item) .. " from Cogitator"
  elseif phase == "move-to-machine" then
    target = state.machine
    if state.carried then
      truth_phase = "deliver-machine-supply"
      label = "Delivering " .. safe(state.item) .. " to " .. machine_label(state.machine)
    else
      truth_phase = "collect-machine-output"
      label = "Servicing " .. machine_label(state.machine)
    end
  elseif phase == "move-to-storage" then
    target = state.storage
    truth_phase = "deposit-machine-output"
    label = "Depositing " .. safe(state.item or (state.carried and state.carried.item)) .. " into storage"
  elseif phase == "return-custody-to-station" or phase == "custody-deposit-blocked" then
    target = pair.station
    truth_phase = "return-custody"
    label = "Returning " .. safe(state.item or (state.carried and state.carried.item)) .. " to Cogitator"
  end

  if not valid(target) then return nil end
  return {
    family = "logistics",
    phase = truth_phase or phase,
    entity = target,
    position = { x = target.position.x, y = target.position.y },
    item = state.item or (state.carried and state.carried.item),
    parent_item = nil,
    label = label or "Machine logistics",
    owner = "machine-logistics-integrity-0682",
    priority = M.move_priority,
    radius = 1.2,
    color = { r = 1.0, g = 0.68, b = 0.18, a = 0.95 },
    can_move = true,
    source = "machine_logistics_integrity_0682",
  }
end

local function patch_leaf_truth()
  local ok, truth = pcall(require, "scripts.core.active_leaf_task_truth_0655")
  if not (ok and truth and type(truth.truth) == "function")
    or truth.machine_logistics_integrity_0682_wrapped
  then
    return false
  end

  truth.machine_logistics_integrity_0682_wrapped = true
  previous_leaf_truth = truth.truth
  truth.truth = function(pair)
    local existing = previous_leaf_truth(pair)
    if existing then return existing end
    return machine_truth(pair)
  end
  return true
end

local function remove_command()
  if commands and commands.remove_command then
    pcall(commands.remove_command, "tp-machine-logistics-0528")
  end
end

local function patch_diagnostics()
  local diagnostics = rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
    or rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diagnostics and type(diagnostics.pair_dump_lines) == "function")
    or diagnostics.machine_logistics_integrity_0682_wrapped
  then
    return false
  end

  diagnostics.machine_logistics_integrity_0682_wrapped = true
  local previous = diagnostics.pair_dump_lines
  diagnostics.pair_dump_lines = function(...)
    local lines = previous(...)
    lines = type(lines) == "table" and lines or {}
    local r = root()
    lines[#lines + 1] = "PAIR-DUMP-0468 MACHINE-LOGISTICS-INTEGRITY-0682 BEGIN enabled="
      .. safe(r.enabled)
      .. " station_pickup=" .. safe(r.physical_station_pickup)
      .. " reservations=" .. safe(r.reserve_machine_targets)
      .. " custody=" .. safe(r.protect_custody)
      .. " admission_gate=" .. safe(r.gate_new_machine_work)
      .. " routed=" .. safe(r.stats.supply_routed_through_station or 0)
      .. " picked_up=" .. safe(r.stats.station_supply_picked_up or 0)
      .. " inserted=" .. safe(r.stats.machine_supply_inserted or 0)
      .. " custody_recovered=" .. safe(r.stats.orphaned_custody_restored or 0)
      .. " admission_blocked=" .. safe(r.stats.new_machine_task_blocked or 0)
      .. " reservations_denied=" .. safe(r.stats.machine_reservation_denied or 0)

    for _, pair in pairs(pair_map()) do
      if valid_pair(pair) then
        local state = pair.machine_logistics_0528 or {}
        local custody = pair.machine_logistics_custody_0682 or {}
        local block = pair.machine_logistics_admission_block_0682 or {}
        lines[#lines + 1] = "PAIR-DUMP-0468 machine-integrity[" .. safe(station_unit(pair)) .. "]"
          .. " phase=" .. safe(state.phase or "none")
          .. " action=" .. safe(state.action or "none")
          .. " item=" .. safe(state.item or "none")
          .. " machine=" .. safe(state.machine_name or (valid(state.machine) and state.machine.name) or "none")
          .. " custody=" .. safe(custody.item or "none") .. "x" .. safe(custody.count or 0)
          .. " block=" .. safe(block.reason or "none")
      end
    end

    for index = math.max(1, #r.recent - 10), #r.recent do
      local event = r.recent[index]
      if event then
        lines[#lines + 1] = "PAIR-DUMP-0468 machine-integrity.recent[" .. safe(index) .. "]"
          .. " tick=" .. safe(event.tick)
          .. " action=" .. safe(event.action)
          .. " station=" .. safe(event.station)
          .. " priest=" .. safe(event.priest)
          .. " " .. safe(event.detail)
      end
    end
    lines[#lines + 1] = "PAIR-DUMP-0468 MACHINE-LOGISTICS-INTEGRITY-0682 END"
    return lines
  end
  return true
end

function M.activate(machine)
  machine = machine or machine_module()
  if not (machine and type(machine.service_pair) == "function") then return false end
  if machine.machine_logistics_integrity_0682_active then return true end

  machine.machine_logistics_integrity_0682_active = true
  previous_machine_service = machine.service_pair
  machine.service_pair = patched_service_pair
  patch_leaf_truth()
  patch_diagnostics()
  ensure_reservation_category()
  remove_command()
  _G.TechPriestsMachineLogisticsIntegrity0682 = M
  record(nil, "machine-logistics-integrity-activated", "physical station pickup and custody arbitration active", true)
  return true
end

function M.install()
  root()
  local machine = machine_module()
  if not machine then return false end

  if not machine.machine_logistics_integrity_0682_install_wrapped then
    machine.machine_logistics_integrity_0682_install_wrapped = true
    previous_machine_install = machine.install
    machine.install = function(...)
      local result = true
      if type(previous_machine_install) == "function" then result = previous_machine_install(...) end
      M.activate(machine)
      return result
    end
  end

  -- Existing saves or unusual loader order may already have installed 0528.
  if rawget(_G, "TECH_PRIESTS_MACHINE_LOGISTICS_FULFILLMENT_0528") then
    M.activate(machine)
  end
  _G.TechPriestsMachineLogisticsIntegrity0682 = M
  return true
end

return M
