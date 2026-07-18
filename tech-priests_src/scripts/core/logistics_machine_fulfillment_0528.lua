-- scripts/core/logistics_machine_fulfillment_0528.lua
-- Tech Priests 0.1.674-dev recovery.
-- One machine-logistics authority: broker-budgeted read-only candidate discovery,
-- dispatcher-owned execution, literal movement acceptance, container-only station
-- stock, dedicated target-machine inventories, persistent custody, and atomic return.

local M = {
  version = "0.1.674-dev",
  storage_key = "logistics_machine_fulfillment_0528",
  discovery_interval = 61,
  discovery_budget = 2,
  candidate_ttl = 360,
  service_radius = 28,
  radius_cap = 96,
  max_scan_entities = 96,
  machine_reach_sq = 2.56,
  station_reach_sq = 4,
  move_priority = 740,
  move_ttl = 480,
  max_transfer = 50,
  min_fuel_count = 3,
  no_task_cooldown = 180,
  reservation_ttl = 300,
}

local MACHINE_TYPES = {
  ["assembling-machine"] = true,
  furnace = true,
}
local WASTE_ITEMS = {
  ["mechanical-detritus"] = true,
  scrap = true,
}
local FUEL_CANDIDATES = {
  "coal", "wood", "solid-fuel", "rocket-fuel", "nuclear-fuel",
}
local TERMINAL_PHASES = {
  complete = true,
  failed = true,
  idle = true,
  none = true,
}

local function now() return game and game.tick or 0 end
local function valid(entity) return entity and entity.valid end
local function safe(value)
  if value == nil then return "nil" end
  local ok, text = pcall(tostring, value)
  return ok and text or "?"
end
local function lower(value) return string.lower(tostring(value or "")) end
local function valid_pair(pair)
  return type(pair) == "table" and valid(pair.station) and valid(pair.priest)
end
local function station_unit(pair)
  return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil
end
local function pair_map()
  return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
end
local function dist_sq(a, b)
  if not (a and b) then return 999999999 end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end
local function result(fields)
  fields = fields or {}
  return {
    processed = tonumber(fields.processed) or 1,
    acted = tonumber(fields.acted) or 0,
    blocked = tonumber(fields.blocked) or 0,
    waiting = tonumber(fields.waiting) or 0,
    failed = tonumber(fields.failed) or 0,
    exhausted = fields.exhausted == true,
    detail = safe(fields.detail or ""),
  }
end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local state = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    dispatcher_owned = true,
    connection_aware_automation = true,
    stats = {},
    recent = {},
    cooldowns = {},
    discovery_cursor = 0,
  }
  storage.tech_priests[M.storage_key] = state
  state.version = M.version
  if state.enabled == nil then state.enabled = true end
  if state.dispatcher_owned == nil then state.dispatcher_owned = true end
  if state.connection_aware_automation == nil then
    state.connection_aware_automation = true
  end
  state.stats = state.stats or {}
  state.recent = state.recent or {}
  state.cooldowns = state.cooldowns or {}
  state.discovery_cursor = tonumber(state.discovery_cursor) or 0
  return state
end
local function stat(name, amount)
  local state = M.root()
  state.stats[name] = (tonumber(state.stats[name]) or 0) + (tonumber(amount) or 1)
end
local function record(pair, action, detail)
  local state = M.root()
  stat(action)
  state.recent[#state.recent + 1] = {
    tick = now(),
    station = station_unit(pair),
    action = safe(action),
    detail = safe(detail),
  }
  while #state.recent > 160 do table.remove(state.recent, 1) end
end

local function inventory(entity, inventory_id)
  if not (valid(entity) and inventory_id and entity.get_inventory) then return nil end
  local ok, inv = pcall(function() return entity.get_inventory(inventory_id) end)
  return ok and inv and inv.valid and inv or nil
end
local function count_inventory(inv, item)
  if not (inv and inv.valid and item) then return 0 end
  local ok, count = pcall(function() return inv.get_item_count(item) end)
  return ok and (tonumber(count) or 0) or 0
end
local function each_inventory_item(inv, callback)
  if not (inv and inv.valid and type(callback) == "function") then return end
  local ok, contents = pcall(function() return inv.get_contents() end)
  if not (ok and type(contents) == "table") then return end
  for key, value in pairs(contents) do
    local name, count
    if type(key) == "string" then
      name = key
      count = type(value) == "table"
        and tonumber(value.count or value.amount or value[2]) or tonumber(value)
    elseif type(value) == "table" then
      name = value.name or value.item or value[1]
      count = tonumber(value.count or value.amount or value[2])
    end
    if type(name) == "string" and name ~= "" and (tonumber(count) or 0) > 0 then
      callback(name, tonumber(count) or 1)
    end
  end
end
local function remove_inventory(inv, item, count)
  if not (inv and inv.valid and item and (tonumber(count) or 0) > 0) then return 0 end
  local ok, removed = pcall(function()
    return inv.remove({ name = item, count = count })
  end)
  return ok and (tonumber(removed) or 0) or 0
end
local function insert_inventory(inv, item, count)
  if not (inv and inv.valid and item and (tonumber(count) or 0) > 0) then return 0 end
  local ok, inserted = pcall(function()
    return inv.insert({ name = item, count = count })
  end)
  return ok and (tonumber(inserted) or 0) or 0
end
local function machine_input(machine)
  local ids = defines and defines.inventory
  return ids and (inventory(machine, ids.assembling_machine_input)
    or inventory(machine, ids.furnace_source)) or nil
end
local function machine_output(machine)
  local ids = defines and defines.inventory
  return ids and (inventory(machine, ids.assembling_machine_output)
    or inventory(machine, ids.furnace_result)) or nil
end
local function machine_fuel(machine)
  local ids = defines and defines.inventory
  return ids and inventory(machine, ids.fuel) or nil
end
local function storage_authority()
  return rawget(_G, "TechPriestsStorageRoleAuthority0686")
    or package.loaded["scripts.core.storage_role_authority_0686"]
end
local function generic_count(pair, item)
  local storage = storage_authority()
  if storage and type(storage.generic_item_count) == "function" then
    local ok, count = pcall(storage.generic_item_count, pair, item)
    if ok then return tonumber(count) or 0 end
  end
  local helper = rawget(_G, "tech_priests_generic_station_item_count_0686")
  if type(helper) == "function" then
    local ok, count = pcall(helper, pair, item)
    if ok then return tonumber(count) or 0 end
  end
  return 0
end
local function remove_generic(pair, item, count)
  local storage = storage_authority()
  if storage and type(storage.remove_generic_item) == "function" then
    local ok, removed = pcall(storage.remove_generic_item, pair, item, count)
    if ok then return tonumber(removed) or 0 end
  end
  local helper = rawget(_G, "tech_priests_generic_station_remove_0686")
  if type(helper) == "function" then
    local ok, removed = pcall(helper, pair, item, count)
    if ok then return tonumber(removed) or 0 end
  end
  return 0
end
local function atomic_deposit(pair, item, count, reason, role)
  local storage = storage_authority()
  if not (storage and type(storage.deposit_exact) == "function") then
    return false, "storage-authority-unavailable"
  end
  local ok, accepted, why, inserted = pcall(
    storage.deposit_exact, pair, item, count, reason, { role = role })
  inserted = tonumber(inserted) or (accepted == true and count or 0)
  return ok and accepted == true and inserted == count, why
end

local function request_move(pair, target, reason)
  local move = rawget(_G, "tech_priests_request_movement_0418")
  if not (valid_pair(pair) and valid(target) and type(move) == "function") then
    return false, "movement-authority-unavailable"
  end
  local ok, accepted = pcall(move, pair, target.position, reason, {
    owner = "logistics_machine_fulfillment_0528",
    priority = M.move_priority,
    ttl = M.move_ttl,
    radius = 1.25,
    distraction = defines and defines.distraction and defines.distraction.none,
  })
  return ok and accepted == true, ok and safe(accepted) or "movement-error:" .. safe(accepted)
end
local function reservations()
  return rawget(_G, "TechPriestsWorkReservations0601")
    or package.loaded["scripts.core.work_reservations"]
end
local function claim_machine(pair, machine)
  local authority = reservations()
  if not (authority and type(authority.claim) == "function") then
    return false, "reservation-authority-unavailable"
  end
  local ok, accepted = pcall(
    authority.claim, "machine-logistics", machine, pair, M.reservation_ttl)
  return ok and accepted == true, ok and "claimed" or safe(accepted)
end
local function release_machine(pair, machine)
  local authority = reservations()
  if valid(machine) and authority and type(authority.release) == "function" then
    pcall(authority.release, "machine-logistics", machine, pair)
  end
end

local function item_exists(name)
  return type(name) == "string" and name ~= ""
    and prototypes and prototypes.item and prototypes.item[name] ~= nil
end
local function get_recipe(machine)
  if not (valid(machine) and machine.get_recipe) then return nil end
  local ok, recipe = pcall(function() return machine.get_recipe() end)
  return ok and recipe or nil
end
local function recipe_ingredients(recipe)
  local out = {}
  if not recipe then return out end
  local ingredients
  local ok = pcall(function() ingredients = recipe.ingredients end)
  if not (ok and type(ingredients) == "table") then return out end
  for _, ingredient in pairs(ingredients) do
    local name = ingredient.name or ingredient[1]
    local kind = ingredient.type or (ingredient.name and "item")
    local amount = tonumber(
      ingredient.amount or ingredient.amount_min or ingredient[2]) or 1
    if kind ~= "fluid" and item_exists(name) then
      out[#out + 1] = { name = name, amount = math.max(1, math.ceil(amount)) }
    end
  end
  return out
end
local function is_machine(entity)
  return valid(entity) and MACHINE_TYPES[entity.type] == true
end
local function machine_box(machine)
  if not valid(machine) then return nil end
  local ok, box = pcall(function() return machine.bounding_box end)
  if ok and box then return box end
  ok, box = pcall(function() return machine.selection_box end)
  return ok and box or nil
end
local function position_in_box(position, box, padding)
  if not (position and box and box.left_top and box.right_bottom) then return false end
  padding = tonumber(padding) or 0.25
  return position.x >= box.left_top.x - padding
    and position.x <= box.right_bottom.x + padding
    and position.y >= box.left_top.y - padding
    and position.y <= box.right_bottom.y + padding
end
local function inserter_connected(inserter, machine)
  if not (valid(inserter) and valid(machine) and inserter.type == "inserter") then
    return false
  end
  local pickup, drop
  pcall(function() pickup = inserter.pickup_target end)
  pcall(function() drop = inserter.drop_target end)
  if pickup == machine or drop == machine then return true end
  local pickup_position, drop_position
  pcall(function() pickup_position = inserter.pickup_position end)
  pcall(function() drop_position = inserter.drop_position end)
  local box = machine_box(machine)
  return position_in_box(pickup_position, box)
    or position_in_box(drop_position, box)
end
local function loader_connected(loader, machine)
  if not (valid(loader) and valid(machine)
    and (loader.type == "loader" or loader.type == "loader-1x1"))
  then
    return false
  end
  local container
  pcall(function() container = loader.loader_container end)
  if container == machine then return true end
  return dist_sq(loader.position, machine.position) <= 2.75
end
local function machine_automated(machine)
  if not valid(machine) then return false end
  local box = machine_box(machine)
  local position = machine.position
  local area = box and {
    { box.left_top.x - 3, box.left_top.y - 3 },
    { box.right_bottom.x + 3, box.right_bottom.y + 3 },
  } or {
    { position.x - 3, position.y - 3 },
    { position.x + 3, position.y + 3 },
  }
  local ok, entities = pcall(function()
    return machine.surface.find_entities_filtered({
      area = area,
      force = machine.force,
      type = { "inserter", "loader", "loader-1x1" },
      limit = 64,
    })
  end)
  if not (ok and entities) then return false end
  for _, entity in pairs(entities) do
    if inserter_connected(entity, machine) or loader_connected(entity, machine) then
      return true
    end
  end
  return false
end

local function output_candidate(machine)
  local output = machine_output(machine)
  local best
  if output then
    each_inventory_item(output, function(item, count)
      local candidate = {
        action = "clear-output",
        item = item,
        count = math.min(M.max_transfer, count),
        machine = machine,
        source_inventory = output,
        kind = WASTE_ITEMS[item] and "waste" or "retention",
      }
      if not best or candidate.kind == "waste"
        or candidate.count > best.count
      then
        best = candidate
      end
    end)
  end
  local input = machine_input(machine)
  local detritus = input and count_inventory(input, "mechanical-detritus") or 0
  if detritus > 0 then
    best = {
      action = "clear-output",
      item = "mechanical-detritus",
      count = math.min(M.max_transfer, detritus),
      machine = machine,
      source_inventory = input,
      kind = "waste",
    }
  end
  return best
end
local function fuel_candidate(pair, machine)
  local fuel = machine_fuel(machine)
  if not fuel then return nil end
  local total = 0
  each_inventory_item(fuel, function(_, count) total = total + count end)
  if total >= M.min_fuel_count then return nil end
  for _, item in ipairs(FUEL_CANDIDATES) do
    local available = generic_count(pair, item)
    if item_exists(item) and available > 0 then
      return {
        action = "supply-fuel",
        item = item,
        count = math.min(M.max_transfer, M.min_fuel_count - total, available),
        machine = machine,
      }
    end
  end
  return nil
end
local function ingredient_candidate(pair, machine)
  local input = machine_input(machine)
  local recipe = get_recipe(machine)
  if not (input and recipe) then return nil end
  for _, ingredient in ipairs(recipe_ingredients(recipe)) do
    local missing = ingredient.amount - count_inventory(input, ingredient.name)
    local available = generic_count(pair, ingredient.name)
    if missing > 0 and available > 0 then
      return {
        action = "supply-ingredient",
        item = ingredient.name,
        count = math.min(M.max_transfer, missing, available),
        machine = machine,
      }
    end
  end
  return nil
end
local function task_score(pair, task)
  local base = task.action == "clear-output" and 600
    or task.action == "supply-fuel" and 500 or 420
  if task.kind == "waste" then base = base + 120 end
  return base - math.sqrt(dist_sq(pair.priest.position, task.machine.position))
    - math.sqrt(dist_sq(pair.station.position, task.machine.position)) * 0.15
end
local function discover_candidate(pair)
  if not valid_pair(pair) or valid(pair.combat_target) then return nil end
  local radius = math.max(M.service_radius,
    math.min(M.radius_cap, tonumber(pair.radius) or M.service_radius))
  local position = pair.station.position
  local ok, machines = pcall(function()
    return pair.station.surface.find_entities_filtered({
      area = {
        { position.x - radius, position.y - radius },
        { position.x + radius, position.y + radius },
      },
      force = pair.station.force,
      type = { "assembling-machine", "furnace" },
      limit = M.max_scan_entities,
    })
  end)
  if not (ok and machines) then return nil end
  local best, best_score
  for _, machine in pairs(machines) do
    if is_machine(machine) and machine ~= pair.station and not machine_automated(machine) then
      local task = output_candidate(machine)
        or fuel_candidate(pair, machine)
        or ingredient_candidate(pair, machine)
      if task then
        local score = task_score(pair, task)
        if not best_score or score > best_score then
          best, best_score = task, score
        end
      end
    end
  end
  if best then
    best.score = best_score
    best.discovered_tick = now()
    best.expires_tick = now() + M.candidate_ttl
    best.source = "machine-logistics-discovery-0528"
  end
  return best
end
local function active_state(pair)
  local state = pair and pair.machine_logistics_0528
  return type(state) == "table" and state.phase
    and not TERMINAL_PHASES[lower(state.phase)] and state or nil
end
local function read_root()
  return storage and storage.tech_priests
    and storage.tech_priests[M.storage_key]
    or { enabled = true, cooldowns = {}, discovery_cursor = 0 }
end
function M.recommend_action(pair)
  if not valid_pair(pair) or read_root().enabled == false then return nil end
  local state = active_state(pair)
  if state and valid(state.machine) then
    local target = state.machine
    if state.phase == "move-to-station"
      or state.phase == "return-custody-to-station"
    then
      target = pair.station
    end
    return {
      kind = "machine-logistics",
      target = target,
      item = state.item or (state.custody and state.custody.item),
      reason = state.phase,
      priority = 780,
      source = "logistics_machine_fulfillment_0528",
    }
  end
  local candidate = pair.machine_logistics_candidate_0528
  if type(candidate) ~= "table" or not valid(candidate.machine)
    or (tonumber(candidate.expires_tick) or 0) < now()
  then
    return nil
  end
  return {
    kind = "machine-logistics",
    target = candidate.machine,
    item = candidate.item,
    reason = candidate.action,
    priority = 760,
    source = "machine-logistics-discovery-0528",
  }
end

local function discover_pairs(budget)
  local pairs = {}
  for _, pair in pairs(pair_map()) do
    if valid_pair(pair) then pairs[#pairs + 1] = pair end
  end
  table.sort(pairs, function(a, b)
    return (station_unit(a) or 0) < (station_unit(b) or 0)
  end)
  if #pairs == 0 then return result({ processed = 0, detail = "no-pairs" }) end
  local root = M.root()
  local limit = math.max(1, math.floor(tonumber(budget) or M.discovery_budget))
  local processed, acted = 0, 0
  for offset = 1, math.min(limit, #pairs) do
    local index = ((root.discovery_cursor + offset - 1) % #pairs) + 1
    local pair = pairs[index]
    processed = processed + 1
    if not active_state(pair) then
      local key = tostring(station_unit(pair) or "?")
      if (tonumber(root.cooldowns[key]) or 0) <= now() then
        local candidate = discover_candidate(pair)
        pair.machine_logistics_candidate_0528 = candidate
        if candidate then acted = acted + 1
        else root.cooldowns[key] = now() + M.no_task_cooldown end
      end
    end
  end
  root.discovery_cursor = (root.discovery_cursor + math.min(limit, #pairs)) % #pairs
  return result({
    processed = processed,
    acted = acted,
    exhausted = #pairs > limit,
    detail = "machine-candidates=" .. acted,
  })
end

local function begin_state(pair, candidate)
  local claimed, why = claim_machine(pair, candidate.machine)
  if not claimed then return false, "machine-reserved:" .. safe(why) end
  pair.machine_logistics_0528 = {
    version = M.version,
    phase = candidate.action == "clear-output" and "move-to-machine"
      or "move-to-station",
    action = candidate.action,
    item = candidate.item,
    count = math.max(1, math.min(M.max_transfer, tonumber(candidate.count) or 1)),
    kind = candidate.kind,
    machine = candidate.machine,
    machine_unit = candidate.machine.unit_number,
    machine_name = candidate.machine.name,
    source_inventory = candidate.source_inventory,
    started_tick = now(),
    updated_tick = now(),
  }
  pair.machine_logistics_candidate_0528 = nil
  pair.mode = "machine-logistics"
  record(pair, "task-began", candidate.action .. ":" .. candidate.item)
  return true, "task-began"
end
local function clear_state(pair, phase, why)
  local state = pair.machine_logistics_0528
  local machine = state and state.machine
  release_machine(pair, machine)
  pair.machine_logistics_0528 = {
    version = M.version,
    phase = phase or "complete",
    completed_tick = now(),
    last_blocker = why,
  }
  if pair.target == machine then pair.target = nil end
  pair.mode = valid(pair.combat_target) and "combat" or "idle"
end
local function refund_custody(pair, reason)
  local state = pair.machine_logistics_0528
  local custody = state and state.custody
  if not custody then return true, "no-custody" end
  local role = custody.kind == "waste" and "waste" or "general"
  local ok, why = atomic_deposit(
    pair, custody.item, custody.count, reason or "machine-custody-return-0528", role)
  if not ok then
    state.phase = "return-custody-to-station"
    state.last_blocker = safe(why)
    state.updated_tick = now()
    stat("custody_return_blocked")
    return false, why
  end
  state.custody = nil
  pair.machine_logistics_custody_0528 = nil
  stat("custody_returned")
  return true, "custody-returned"
end
local function acquire_station_custody(pair, state)
  local removed = remove_generic(pair, state.item, state.count)
  if removed <= 0 then return false, "station-stock-unavailable" end
  state.custody = {
    version = M.version,
    item = state.item,
    count = removed,
    kind = "supply",
    source = "generic-container-storage",
    created_tick = now(),
  }
  pair.machine_logistics_custody_0528 = state.custody
  stat("station_items_removed", removed)
  return true, "station-custody-acquired"
end
local function acquire_output_custody(pair, state)
  local inv = state.source_inventory
  if not (inv and inv.valid) then
    inv = machine_output(state.machine) or machine_input(state.machine)
  end
  if not (inv and inv.valid) then return false, "machine-source-inventory-invalid" end
  local available = count_inventory(inv, state.item)
  local wanted = math.min(state.count, available)
  if wanted <= 0 then return false, "machine-output-empty" end
  local removed = remove_inventory(inv, state.item, wanted)
  if removed ~= wanted then
    if removed > 0 then
      local restored = insert_inventory(inv, state.item, removed)
      return false, restored == removed and "short-remove-rolled-back"
        or "short-remove-rollback-failed"
    end
    return false, "machine-output-remove-failed"
  end
  state.custody = {
    version = M.version,
    item = state.item,
    count = removed,
    kind = state.kind == "waste" and "waste" or "retention",
    source = "machine-output",
    machine_unit = state.machine.unit_number,
    created_tick = now(),
  }
  pair.machine_logistics_custody_0528 = state.custody
  stat("machine_output_removed", removed)
  return true, "machine-output-custody-acquired"
end
local function deliver_supply(pair, state)
  local custody = state.custody
  if not custody then return false, "no-supply-custody" end
  local destination = state.action == "supply-fuel"
    and machine_fuel(state.machine) or machine_input(state.machine)
  if not (destination and destination.valid) then
    return false, "machine-destination-invalid"
  end
  local inserted = insert_inventory(destination, custody.item, custody.count)
  if inserted > 0 then
    custody.count = custody.count - inserted
    stat("machine_items_inserted", inserted)
  end
  if custody.count <= 0 then
    state.custody = nil
    pair.machine_logistics_custody_0528 = nil
    clear_state(pair, "complete")
    record(pair, "supply-complete", state.action .. ":" .. state.item)
    return true, "machine-supply-complete"
  end
  state.phase = "return-custody-to-station"
  state.last_blocker = inserted > 0 and "partial-machine-insert" or "machine-insert-blocked"
  return inserted > 0, state.last_blocker
end
local function deposit_output(pair, state)
  local custody = state.custody
  if not custody then return false, "no-output-custody" end
  local role = custody.kind == "waste" and "waste" or "retention"
  local ok, why = atomic_deposit(
    pair, custody.item, custody.count, "machine-output-deposit-0528", role)
  if not ok then
    state.phase = "return-custody-to-station"
    state.last_blocker = safe(why)
    return false, "output-deposit-blocked:" .. safe(why)
  end
  state.custody = nil
  pair.machine_logistics_custody_0528 = nil
  clear_state(pair, "complete")
  record(pair, "output-complete", state.item)
  return true, "machine-output-complete"
end

function M.abort_pair(pair, reason)
  if not valid_pair(pair) then return result({ failed = 1, detail = "invalid-pair" }) end
  local state = pair.machine_logistics_0528
  if type(state) ~= "table" then return result({ processed = 0, detail = "no-state" }) end
  if state.custody then
    state.phase = "return-custody-to-station"
    if dist_sq(pair.priest.position, pair.station.position) > M.station_reach_sq then
      local moved, why = request_move(
        pair, pair.station, "machine-logistics-abort-return-0528")
      if not moved then
        state.last_blocker = why
        return result({ failed = 1, detail = "abort-movement-failed:" .. safe(why) })
      end
      return result({ waiting = 1, detail = "abort-returning-custody" })
    end
    local returned, why = refund_custody(pair, "machine-logistics-abort-0528")
    if not returned then return result({ blocked = 1, detail = why }) end
  end
  clear_state(pair, "failed", reason or "machine-logistics-aborted")
  record(pair, "aborted", reason)
  return result({ acted = 1, detail = reason or "machine-logistics-aborted" })
end

function M.service_pair(pair, reason)
  if M.root().enabled == false then return result({ processed = 0, detail = "disabled" }) end
  if not valid_pair(pair) then return result({ failed = 1, detail = "invalid-pair" }) end
  if valid(pair.combat_target) then
    if active_state(pair) then return M.abort_pair(pair, "combat-priority") end
    return result({ processed = 0, detail = "combat-priority" })
  end
  local state = active_state(pair)
  if not state then
    local candidate = pair.machine_logistics_candidate_0528
    if type(candidate) ~= "table" or not valid(candidate.machine)
      or (tonumber(candidate.expires_tick) or 0) < now()
    then
      return result({ processed = 0, detail = "no-machine-candidate" })
    end
    local began, why = begin_state(pair, candidate)
    if not began then return result({ blocked = 1, detail = why }) end
    state = pair.machine_logistics_0528
  end
  if not valid(state.machine) then return M.abort_pair(pair, "machine-invalid") end
  state.updated_tick = now()
  pair.target = state.machine
  if state.phase == "move-to-station"
    or state.phase == "return-custody-to-station"
  then
    pair.target = pair.station
  end
  pair.mode = "machine-logistics"

  if state.phase == "move-to-station" then
    if dist_sq(pair.priest.position, pair.station.position) > M.station_reach_sq then
      local moved, why = request_move(
        pair, pair.station, "machine-logistics-collect-station-0528")
      if not moved then
        return result({ failed = 1, detail = "movement-failed:" .. safe(why) })
      end
      return result({ waiting = 1, detail = "move-to-station" })
    end
    local acquired, why = acquire_station_custody(pair, state)
    if not acquired then return M.abort_pair(pair, why) end
    state.phase = "move-to-machine"
    return result({ acted = 1, detail = "station-custody-acquired" })
  end

  if state.phase == "move-to-machine" then
    if dist_sq(pair.priest.position, state.machine.position) > M.machine_reach_sq then
      local moved, why = request_move(
        pair, state.machine, "machine-logistics-move-to-machine-0528")
      if not moved then
        return result({ failed = 1, detail = "movement-failed:" .. safe(why) })
      end
      return result({ waiting = 1, detail = "move-to-machine" })
    end
    if state.action == "clear-output" and not state.custody then
      local acquired, why = acquire_output_custody(pair, state)
      if not acquired then return M.abort_pair(pair, why) end
      state.phase = "return-custody-to-station"
      return result({ acted = 1, detail = "machine-output-custody-acquired" })
    end
    local delivered, why = deliver_supply(pair, state)
    if delivered and state.phase == "complete" then
      return result({ acted = 1, detail = why })
    end
    return result({
      acted = delivered and 1 or 0,
      blocked = delivered and 0 or 1,
      detail = why,
    })
  end

  if state.phase == "return-custody-to-station" then
    if dist_sq(pair.priest.position, pair.station.position) > M.station_reach_sq then
      local moved, why = request_move(
        pair, pair.station, "machine-logistics-return-custody-0528")
      if not moved then
        return result({ failed = 1, detail = "movement-failed:" .. safe(why) })
      end
      return result({ waiting = 1, detail = "return-custody-to-station" })
    end
    if state.action == "clear-output" then
      local deposited, why = deposit_output(pair, state)
      return result({
        acted = deposited and 1 or 0,
        blocked = deposited and 0 or 1,
        detail = why,
      })
    end
    local returned, why = refund_custody(pair, "machine-supply-leftover-0528")
    if not returned then return result({ blocked = 1, detail = why }) end
    clear_state(pair, "failed", state.last_blocker or "machine-insert-incomplete")
    return result({ acted = 1, detail = "supply-leftover-returned" })
  end

  return M.abort_pair(pair, "unknown-phase:" .. safe(state.phase))
end

function M.describe_pair(pair)
  if not valid_pair(pair) then return "invalid pair" end
  local state = pair.machine_logistics_0528 or {}
  local candidate = pair.machine_logistics_candidate_0528 or {}
  local custody = state.custody or pair.machine_logistics_custody_0528 or {}
  return "phase=" .. safe(state.phase or "none")
    .. " action=" .. safe(state.action or candidate.action or "none")
    .. " item=" .. safe(state.item or candidate.item or custody.item or "none")
    .. " custody=" .. safe(custody.count or 0)
    .. " machine=" .. safe(state.machine_name
      or (valid(candidate.machine) and candidate.machine.name) or "none")
end

local function register_discovery()
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if not (broker and type(broker.register_service) == "function") then return false end
  local service = broker.register_service({
    name = "machine_logistics_discovery_0528",
    category = "logistics",
    interval = M.discovery_interval,
    priority = 70,
    budget = M.discovery_budget,
    dynamic_budget = true,
    note = "bounded machine candidate discovery only; dispatcher owns execution",
    fn = function(_, budget) return discover_pairs(budget) end,
  })
  return service ~= nil
end
local function patch_diagnostics()
  local diagnostics = rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
    or rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diagnostics and type(diagnostics.pair_dump_lines) == "function") then
    return false
  end
  if diagnostics.machine_logistics_0528_recovery_wrapped then return true end
  diagnostics.machine_logistics_0528_recovery_wrapped = true
  local previous = diagnostics.pair_dump_lines
  diagnostics.pair_dump_lines = function(...)
    local lines = previous(...)
    lines = type(lines) == "table" and lines or {}
    local root = M.root()
    lines[#lines + 1] = "PAIR-DUMP-0468 MACHINE-LOGISTICS-0528 version="
      .. M.version .. " dispatcher_owned=" .. safe(root.dispatcher_owned)
      .. " station_removed=" .. safe(root.stats.station_items_removed or 0)
      .. " output_removed=" .. safe(root.stats.machine_output_removed or 0)
      .. " inserted=" .. safe(root.stats.machine_items_inserted or 0)
      .. " custody_returned=" .. safe(root.stats.custody_returned or 0)
      .. " station_machine_inventory_access=0"
    for _, pair in pairs(pair_map()) do
      if valid_pair(pair) then
        lines[#lines + 1] = "PAIR-DUMP-0468 machine-logistics["
          .. safe(station_unit(pair)) .. "] " .. M.describe_pair(pair)
      end
    end
    return lines
  end
  return true
end

function M.install()
  M.root()
  local discovery_ok = register_discovery()
  patch_diagnostics()
  if commands and commands.remove_command then
    pcall(commands.remove_command, "tp-machine-logistics-0528")
  end
  _G.TECH_PRIESTS_MACHINE_LOGISTICS_FULFILLMENT_0528 = M
  _G.TechPriestsMachineLogisticsFulfillment0528 = M
  if log then
    log("[Tech-Priests 0.1.674-dev] consolidated dispatcher-owned machine logistics installed")
  end
  return discovery_ok == true
end

return M
