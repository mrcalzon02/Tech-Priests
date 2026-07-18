-- scripts/core/storage_role_authority_0686.lua
-- Tech Priests 0.1.674-dev recovery.
-- Canonical generic storage authority. Generic station storage is restricted to
-- container/trunk inventories; machine input, output, fuel, lab, and furnace work
-- inventories are reachable only from dedicated machine-family executors.

local M = {
  version = "0.1.674-dev",
  storage_key = "storage_role_authority_0686",
  scan_radius_floor = 28,
  scan_radius_cap = 96,
  role_sweep_interval = 181,
  full_cache_scan_interval = 3600,
  max_role_sweep_entities = 64,
}

local previous_steward_install
local previous_stone_install
local previous_machine_activate
local previous_machine_service
local previous_stone_scan_all

local WASTE_ITEMS = {
  ["mechanical-detritus"] = true,
  scrap = true,
}
local FILTERED_CACHE_ITEMS = {
  ["tech-priests-stone-cache-coal"] = "coal",
  ["tech-priests-stone-cache-stone"] = "stone",
  ["tech-priests-stone-cache-wood"] = "wood",
  ["tech-priests-stone-cache-iron-ore"] = "iron-ore",
  ["tech-priests-stone-cache-copper-ore"] = "copper-ore",
  ["tech-priests-stone-cache-iron-plate"] = "iron-plate",
  ["tech-priests-stone-cache-copper-plate"] = "copper-plate",
  ["tech-priests-stone-cache-copper-cable"] = "copper-cable",
  ["tech-priests-stone-cache-iron-gear-wheel"] = "iron-gear-wheel",
  ["tech-priests-stone-cache-iron-stick"] = "iron-stick",
}
local GENERAL_STASH_NAMES = {
  "tech-priests-martian-stone-cache",
  "wooden-chest",
  "iron-chest",
  "steel-chest",
}
local GENERAL_STASH_COSTS = {
  ["tech-priests-martian-stone-cache"] = { stone = 12 },
  ["wooden-chest"] = { wood = 2 },
}

local function now() return game and game.tick or 0 end
local function valid(entity) return entity and entity.valid end
local function safe(value)
  if value == nil then return "nil" end
  local ok, text = pcall(tostring, value)
  return ok and text or "?"
end
local function lower(value) return string.lower(tostring(value or "")) end
local function dist_sq(a, b)
  if not (a and b) then return 999999999 end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end
local function valid_pair(pair)
  return type(pair) == "table" and valid(pair.station) and valid(pair.priest)
end
local function station_unit(pair)
  return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil
end
local function pair_map()
  return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local state = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    exact_atomic_deposits = true,
    generic_container_only = true,
    no_spill_cache_recovery = true,
    enforce_role_exclusivity = true,
    roles = {},
    roles_by_station = {},
    stats = {},
    recent = {},
    last_log = {},
    last_full_cache_scan = -1000000,
  }
  storage.tech_priests[M.storage_key] = state
  state.version = M.version
  if state.enabled == nil then state.enabled = true end
  if state.exact_atomic_deposits == nil then state.exact_atomic_deposits = true end
  if state.generic_container_only == nil then state.generic_container_only = true end
  if state.no_spill_cache_recovery == nil then state.no_spill_cache_recovery = true end
  if state.enforce_role_exclusivity == nil then state.enforce_role_exclusivity = true end
  state.roles = state.roles or {}
  state.roles_by_station = state.roles_by_station or {}
  state.stats = state.stats or {}
  state.recent = state.recent or {}
  state.last_log = state.last_log or {}
  if state.last_full_cache_scan == nil then state.last_full_cache_scan = -1000000 end
  return state
end
local function stat(name, amount)
  local state = M.root()
  state.stats[name] = (tonumber(state.stats[name]) or 0) + (tonumber(amount) or 1)
end
local function record(pair, action, detail, force_log)
  local state = M.root()
  stat(action)
  local event = {
    tick = now(),
    station = safe(station_unit(pair)),
    action = safe(action),
    detail = safe(detail),
  }
  state.recent[#state.recent + 1] = event
  while #state.recent > 180 do table.remove(state.recent, 1) end
  local key = event.action .. ":" .. event.station
  local previous = tonumber(state.last_log[key] or -1000000) or -1000000
  if force_log or now() - previous >= 600 then
    state.last_log[key] = now()
    if log then
      log("[Tech-Priests 0.1.674-dev] storage " .. event.action
        .. " station=" .. event.station .. " " .. event.detail)
    end
  end
end

local function entity_key(entity)
  if not valid(entity) then return nil end
  if entity.unit_number then return "unit:" .. tostring(entity.unit_number) end
  local position = entity.position or { x = 0, y = 0 }
  return safe(entity.surface and entity.surface.index) .. ":" .. safe(entity.name)
    .. ":" .. tostring(math.floor((position.x or 0) * 10))
    .. ":" .. tostring(math.floor((position.y or 0) * 10))
end
local function inventory(entity, inventory_id)
  if not (valid(entity) and inventory_id and entity.get_inventory) then return nil end
  local ok, inv = pcall(function() return entity.get_inventory(inventory_id) end)
  return ok and inv and inv.valid and inv or nil
end
local function container_inventory(entity)
  local ids = defines and defines.inventory
  if not ids then return nil end
  return inventory(entity, ids.chest)
    or inventory(entity, ids.car_trunk)
    or inventory(entity, ids.spider_trunk)
end
local function add_inventory(out, seen, inv, entity, source)
  if not (inv and inv.valid) then return end
  local key = safe(inv)
  if seen[key] then return end
  seen[key] = true
  out[#out + 1] = { inv = inv, entity = entity, source = source }
end

function M.generic_station_inventories(pair)
  local out, seen = {}, {}
  if not valid_pair(pair) then return out end
  add_inventory(out, seen, container_inventory(pair.station), pair.station, "station-container")
  return out
end

local function inv_count(inv, item)
  if not (inv and inv.valid and item) then return 0 end
  local ok, count = pcall(function() return inv.get_item_count(item) end)
  return ok and (tonumber(count) or 0) or 0
end
local function inv_insert(inv, item, count)
  if not (inv and inv.valid and item and (tonumber(count) or 0) > 0) then return 0 end
  local ok, inserted = pcall(function()
    return inv.insert({ name = item, count = count })
  end)
  return ok and (tonumber(inserted) or 0) or 0
end
local function inv_remove(inv, item, count)
  if not (inv and inv.valid and item and (tonumber(count) or 0) > 0) then return 0 end
  local ok, removed = pcall(function()
    return inv.remove({ name = item, count = count })
  end)
  return ok and (tonumber(removed) or 0) or 0
end
local function insertable_count(inv, item, maximum)
  if not (inv and inv.valid and item and (tonumber(maximum) or 0) > 0) then return 0 end
  local low, high = 0, math.max(0, math.floor(tonumber(maximum) or 0))
  while low < high do
    local middle = math.floor((low + high + 1) / 2)
    local ok, accepted = pcall(function()
      return inv.can_insert({ name = item, count = middle })
    end)
    if ok and accepted == true then low = middle else high = middle - 1 end
  end
  return low
end
local function item_exists(name)
  return type(name) == "string" and name ~= ""
    and prototypes and prototypes.item and prototypes.item[name] ~= nil
end
local function entity_exists(name)
  return type(name) == "string" and name ~= ""
    and prototypes and prototypes.entity and prototypes.entity[name] ~= nil
end

local function fixed_role(entity)
  local item = valid(entity) and FILTERED_CACHE_ITEMS[entity.name] or nil
  return item and ("filtered:" .. item) or nil, item
end
function M.role_for(entity)
  if not valid(entity) then return nil end
  local fixed = fixed_role(entity)
  if fixed then return fixed end
  local rec = M.root().roles[entity_key(entity)]
  return rec and rec.role or nil
end
function M.remember_role(pair, entity, role, reason)
  if not (valid(entity) and role) then return false, "invalid" end
  local fixed = fixed_role(entity)
  if fixed and fixed ~= role then return false, "fixed-filtered-role" end
  local key = entity_key(entity)
  if not key then return false, "no-key" end
  local state = M.root()
  local existing = state.roles[key]
  if existing and existing.role and existing.role ~= role
    and existing.role ~= "general" and role ~= "general"
  then
    stat("role_conflict_denied")
    return false, "role-conflict:" .. safe(existing.role)
  end
  if existing and existing.role and existing.role ~= "general" and role == "general" then
    stat("role_conflict_denied")
    return false, "specialized-role:" .. safe(existing.role)
  end
  state.roles[key] = {
    entity = entity,
    role = role,
    station_unit = station_unit(pair),
    tick = now(),
    reason = safe(reason or "assigned"),
  }
  local unit = station_unit(pair)
  if unit then
    local bucket = state.roles_by_station[tostring(unit)] or {}
    state.roles_by_station[tostring(unit)] = bucket
    bucket[key] = true
  end
  stat(existing and "role_renewed" or "role_assigned")
  return true, role
end
local function release_invalid_roles()
  local state = M.root()
  for key, rec in pairs(state.roles) do
    if not (rec and valid(rec.entity)) then
      state.roles[key] = nil
      for _, bucket in pairs(state.roles_by_station) do bucket[key] = nil end
      stat("invalid_role_released")
    end
  end
end
local function item_role(item, reason)
  if WASTE_ITEMS[item] then return "waste" end
  local text = lower(reason)
  if text:find("waste", 1, true) or text:find("detritus", 1, true)
    or text:find("scrap", 1, true)
  then
    return "waste"
  end
  if text:find("retention", 1, true) or text:find("machine%-output")
    or text:find("production%-output")
  then
    return "retention"
  end
  return "general"
end
local function role_accepts(entity, item, requested_role)
  if not (valid(entity) and item) then return false, "invalid" end
  local fixed, filtered_item = fixed_role(entity)
  if fixed then
    return item == filtered_item,
      item == filtered_item and "matching-filter" or "filtered-mismatch"
  end
  local role = M.role_for(entity)
  if role == "waste" then
    return WASTE_ITEMS[item] == true, WASTE_ITEMS[item] and "waste" or "waste-reject"
  end
  if role == "retention" then
    return not WASTE_ITEMS[item],
      WASTE_ITEMS[item] and "retention-reject-waste" or "retention"
  end
  if role == "station" then return true, "station" end
  if role == "general" or role == nil then
    if requested_role == "waste" or requested_role == "retention" then
      return true, "claimable:" .. requested_role
    end
    return true, "general"
  end
  return false, "unknown-role:" .. safe(role)
end

local function steward_root()
  return storage and storage.tech_priests
    and (storage.tech_priests.inventory_steward_0357
      or storage.tech_priests.inventory_steward_0356)
    or nil
end
local function remember_general_stash(pair, entity)
  local state = steward_root()
  local unit = station_unit(pair)
  if not (state and unit and valid(entity)) then return end
  state.stashes_by_station = state.stashes_by_station or {}
  local bucket = state.stashes_by_station[unit]
    or state.stashes_by_station[tostring(unit)] or {}
  state.stashes_by_station[unit] = bucket
  bucket[entity.unit_number or entity_key(entity)] = {
    entity = entity,
    unit = entity.unit_number,
    name = entity.name,
    tick = now(),
    x = entity.position.x,
    y = entity.position.y,
  }
end
local function nearby_containers(pair)
  local out, seen = {}, {}
  if not valid_pair(pair) then return out end
  local function add(entity, source)
    if not valid(entity) or entity == pair.station then return end
    local key = entity_key(entity)
    local inv = container_inventory(entity)
    if not (key and inv) or seen[key] then return end
    seen[key] = true
    out[#out + 1] = {
      entity = entity,
      inv = inv,
      source = source,
      distance = dist_sq(pair.station.position, entity.position),
    }
  end
  local steward = steward_root()
  local unit = station_unit(pair)
  local bucket = steward and steward.stashes_by_station
    and (steward.stashes_by_station[unit]
      or steward.stashes_by_station[tostring(unit)])
  for key, rec in pairs(bucket or {}) do
    if rec and valid(rec.entity) then add(rec.entity, "remembered")
    else bucket[key] = nil end
  end
  local radius = math.max(M.scan_radius_floor,
    math.min(M.scan_radius_cap, tonumber(pair.radius) or M.scan_radius_floor))
  local position = pair.station.position
  local ok, entities = pcall(function()
    return pair.station.surface.find_entities_filtered({
      area = {
        { position.x - radius, position.y - radius },
        { position.x + radius, position.y + radius },
      },
      force = pair.station.force,
      type = { "container", "logistic-container", "car", "spider-vehicle" },
      limit = 256,
    })
  end)
  if ok and entities then
    for _, entity in pairs(entities) do add(entity, "nearby") end
  end
  return out
end

function M.generic_item_count(pair, item)
  local total = 0
  for _, source in ipairs(M.generic_station_inventories(pair)) do
    total = total + inv_count(source.inv, item)
  end
  for _, source in ipairs(nearby_containers(pair)) do
    if M.role_for(source.entity) ~= "waste" then
      total = total + inv_count(source.inv, item)
    end
  end
  return total
end
function M.remove_generic_item(pair, item, count)
  local remaining = math.max(0, math.floor(tonumber(count) or 0))
  local removed = 0
  local sources = {}
  for _, source in ipairs(M.generic_station_inventories(pair)) do
    sources[#sources + 1] = source
  end
  for _, source in ipairs(nearby_containers(pair)) do
    if M.role_for(source.entity) ~= "waste" then sources[#sources + 1] = source end
  end
  for _, source in ipairs(sources) do
    if remaining <= 0 then break end
    local amount = inv_remove(source.inv, item, remaining)
    removed = removed + amount
    remaining = remaining - amount
  end
  return removed
end

local function stash_position(pair, entity_name)
  local base = pair.station.position
  local offsets = {
    { 2.5, 0 }, { -2.5, 0 }, { 0, 2.5 }, { 0, -2.5 },
    { 3.5, 2.5 }, { -3.5, 2.5 }, { 3.5, -2.5 }, { -3.5, -2.5 },
    { 5, 0 }, { -5, 0 }, { 0, 5 }, { 0, -5 },
    { 5, 5 }, { -5, 5 }, { 5, -5 }, { -5, -5 },
  }
  for _, offset in ipairs(offsets) do
    local desired = { x = base.x + offset[1], y = base.y + offset[2] }
    local ok, position = pcall(function()
      return pair.station.surface.find_non_colliding_position(
        entity_name, desired, 4, 0.25, false)
    end)
    if ok and position then return position end
  end
  return nil
end
local function restore_materials(pair, removed)
  local failures = {}
  for item, count in pairs(removed or {}) do
    local ok, why, inserted = M.deposit_exact(
      pair, item, count, "stash-material-refund",
      { allow_create = false, role = "general" })
    if not ok or inserted ~= count then
      failures[item] = { count = count, reason = why, inserted = inserted }
    end
  end
  return failures
end
local function safe_create_stash(pair, role)
  if not valid_pair(pair) then return nil, "invalid-pair" end
  local chosen, materials, position
  for _, name in ipairs(GENERAL_STASH_NAMES) do
    if entity_exists(name) and item_exists(name)
      and M.generic_item_count(pair, name) > 0
    then
      local candidate = stash_position(pair, name)
      if candidate then
        chosen, materials, position = name, { [name] = 1 }, candidate
        break
      end
    end
  end
  if not chosen then
    for _, name in ipairs(GENERAL_STASH_NAMES) do
      local cost = GENERAL_STASH_COSTS[name]
      if entity_exists(name) and cost then
        local enough = true
        for item, count in pairs(cost) do
          if M.generic_item_count(pair, item) < count then enough = false break end
        end
        local candidate = enough and stash_position(pair, name) or nil
        if candidate then chosen, materials, position = name, cost, candidate break end
      end
    end
  end
  if not (chosen and materials and position) then return nil, "no-safe-stash-plan" end
  local removed = {}
  for item, count in pairs(materials) do
    local amount = M.remove_generic_item(pair, item, count)
    removed[item] = amount
    if amount ~= count then
      restore_materials(pair, removed)
      return nil, "material-removal-failed"
    end
  end
  local ok, entity = pcall(function()
    return pair.station.surface.create_entity({
      name = chosen,
      position = position,
      force = pair.station.force,
      raise_built = true,
    })
  end)
  if not (ok and valid(entity)) then
    local failures = restore_materials(pair, removed)
    if next(failures) then
      record(pair, "stash-refund-custody-required", safe(failures), true)
    end
    return nil, "create-failed"
  end
  remember_general_stash(pair, entity)
  M.remember_role(pair, entity, role or "general", "created-for-storage-role")
  stat("safe_stash_created")
  return entity, "created"
end

local function priority(entity, item, requested_role)
  if entity == nil then return 999999 end
  local fixed, filtered_item = fixed_role(entity)
  if fixed and filtered_item == item then return requested_role == "general" and 10 or 18 end
  local role = M.role_for(entity)
  if role == requested_role then return 5 end
  if role == "general" then return requested_role == "general" and 12 or 20 end
  if role == nil then return requested_role == "general" and 15 or 24 end
  return 1000
end
local function destinations(pair, item, requested_role, excluded)
  local out = {}
  for index, source in ipairs(M.generic_station_inventories(pair)) do
    out[#out + 1] = {
      entity = pair.station,
      inv = source.inv,
      priority = requested_role == "waste" and 30 or 1,
      distance = index * 0.001,
    }
  end
  for _, source in ipairs(nearby_containers(pair)) do
    if source.entity ~= excluded then
      local accepts, why = role_accepts(source.entity, item, requested_role)
      if accepts then
        source.claim_role = why and why:find("claimable:", 1, true)
          and requested_role or nil
        source.priority = priority(source.entity, item, requested_role)
        out[#out + 1] = source
      end
    end
  end
  table.sort(out, function(a, b)
    if a.priority ~= b.priority then return a.priority < b.priority end
    return (a.distance or 999999999) < (b.distance or 999999999)
  end)
  return out
end
local function deposit_plan(pair, item, count, role, excluded)
  local plan, remaining = {}, count
  for _, destination in ipairs(destinations(pair, item, role, excluded)) do
    if remaining <= 0 then break end
    local capacity = insertable_count(destination.inv, item, remaining)
    if capacity > 0 then
      plan[#plan + 1] = {
        entity = destination.entity,
        inv = destination.inv,
        count = capacity,
        claim_role = destination.claim_role,
      }
      remaining = remaining - capacity
    end
  end
  return plan, remaining
end
local function rollback(item, completed)
  local restored = 0
  for index = #completed, 1, -1 do
    local entry = completed[index]
    restored = restored + inv_remove(entry.inv, item, entry.inserted)
  end
  return restored
end
local function execute_plan(pair, item, count, role, plan, reason)
  local completed, inserted_total = {}, 0
  for _, entry in ipairs(plan) do
    if entry.claim_role and entry.entity ~= pair.station then
      local claimed, why = M.remember_role(
        pair, entry.entity, entry.claim_role, "deposit:" .. safe(reason))
      if not claimed then
        rollback(item, completed)
        return false, "role-claim-failed:" .. safe(why), 0
      end
    end
    local inserted = inv_insert(entry.inv, item, entry.count)
    if inserted ~= entry.count then
      if inserted > 0 then
        completed[#completed + 1] = { inv = entry.inv, inserted = inserted }
      end
      local restored = rollback(item, completed)
      record(pair, "atomic-deposit-rollback",
        item .. " inserted=" .. safe(inserted) .. " restored=" .. safe(restored), true)
      return false, "atomic-insert-failed", 0
    end
    completed[#completed + 1] = { inv = entry.inv, inserted = inserted }
    inserted_total = inserted_total + inserted
  end
  if inserted_total ~= count then
    rollback(item, completed)
    return false, "count-mismatch", 0
  end
  stat("exact_items_deposited", inserted_total)
  stat("exact_deposit_transactions")
  return true, role, inserted_total
end

function M.deposit_exact(pair, item, count, reason, options)
  local state = M.root()
  if state.enabled == false then return false, "disabled", 0 end
  if not (valid_pair(pair) and item_exists(item)) then return false, "invalid", 0 end
  count = math.max(1, math.floor(tonumber(count) or 1))
  options = options or {}
  local role = options.role or item_role(item, reason)
  local plan, remaining = deposit_plan(pair, item, count, role, options.exclude_entity)
  if remaining > 0 and options.allow_create ~= false then
    local stash = safe_create_stash(pair, role)
    if stash then
      plan, remaining = deposit_plan(pair, item, count, role, options.exclude_entity)
    end
  end
  if remaining > 0 then
    stat("exact_deposit_blocked")
    return false, "no-role-capacity", 0
  end
  return execute_plan(pair, item, count, role, plan, reason)
end

local function pair_for_entity(entity)
  if not valid(entity) then return nil end
  local best, best_distance
  for _, pair in pairs(pair_map()) do
    if valid_pair(pair) and pair.station.surface == entity.surface
      and pair.station.force == entity.force
    then
      local distance_value = dist_sq(pair.station.position, entity.position)
      if not best_distance or distance_value < best_distance then
        best, best_distance = pair, distance_value
      end
    end
  end
  return best
end
local function reroute_wrong_stack(entity, stack, allowed_item)
  if not (valid(entity) and stack and stack.valid_for_read
    and stack.name ~= allowed_item)
  then
    return false
  end
  local pair = pair_for_entity(entity)
  local inv = container_inventory(entity)
  if not (valid_pair(pair) and inv) then return false end
  local item, count = stack.name, stack.count
  local removed = inv_remove(inv, item, count)
  if removed <= 0 then return false end
  local ok, why, inserted = M.deposit_exact(
    pair, item, removed, "filtered-cache-recovery",
    { exclude_entity = entity, role = item_role(item, "filtered-cache-recovery") })
  if ok and inserted == removed then
    record(pair, "filtered-cache-item-rerouted", item .. " x" .. safe(removed))
    return true
  end
  local restored = inv_insert(inv, item, removed)
  record(pair, "filtered-cache-reroute-blocked",
    item .. " restored=" .. safe(restored) .. " reason=" .. safe(why), true)
  return false
end

local function patch_stone_cache(stone)
  if not stone or stone.storage_role_authority_0686_active then return true end
  stone.storage_role_authority_0686_active = true
  previous_stone_scan_all = stone.scan_all_surfaces
  stone.sweep_entity = function(entity)
    local allowed = valid(entity) and FILTERED_CACHE_ITEMS[entity.name] or nil
    if not allowed then return false end
    M.remember_role(pair_for_entity(entity), entity,
      "filtered:" .. allowed, "filtered-cache-prototype")
    local inv = container_inventory(entity)
    if not inv then return false end
    local changed = false
    for index = 1, #inv do
      changed = reroute_wrong_stack(entity, inv[index], allowed) or changed
    end
    return changed
  end
  stone.scan_all_surfaces = function(force)
    local state = M.root()
    if force ~= true and now() - state.last_full_cache_scan < M.full_cache_scan_interval then
      return 0
    end
    state.last_full_cache_scan = now()
    return type(previous_stone_scan_all) == "function"
      and (tonumber(previous_stone_scan_all()) or 0) or 0
  end
  return true
end

local function patch_steward(steward)
  if not steward then return false end
  if steward.storage_role_authority_0686_active then return true end
  steward.storage_role_authority_0686_active = true
  steward.safe_deposit_item = function(pair, item, count, reason)
    return M.deposit_exact(pair, item, count, reason, {})
  end
  steward.create_stash = function(pair)
    return safe_create_stash(pair, "general")
  end
  _G.tech_priests_safe_deposit_item = steward.safe_deposit_item
  _G.tech_priests_inventory_steward_create_stash = steward.create_stash
  if commands and commands.remove_command then
    pcall(commands.remove_command, "tp-inventory-steward-0356")
    pcall(commands.remove_command, "tp-inventory-steward-0357")
  end
  return true
end

local function role_box_capacity(entity, item, count, role)
  local accepts = role_accepts(entity, item, role)
  local inv = container_inventory(entity)
  return accepts and inv and insertable_count(inv, item, count) >= count, inv
end
local function find_or_create_role_box(pair, item, count, role)
  for _, source in ipairs(nearby_containers(pair)) do
    local current = M.role_for(source.entity)
    if current == role or current == nil or current == "general" then
      local enough, inv = role_box_capacity(source.entity, item, count, role)
      if enough then
        local claimed = M.remember_role(
          pair, source.entity, role, "machine-destination")
        if claimed then return source.entity, inv, "existing-role-box" end
      end
    end
  end
  local created, why = safe_create_stash(pair, role)
  if created then
    local enough, inv = role_box_capacity(created, item, count, role)
    if enough then return created, inv, "created-role-box" end
  end
  return nil, nil, why or "no-role-box"
end
local function prime_machine_destination(machine, pair, machine_state)
  local carried = machine_state and machine_state.carried
  if not (valid_pair(pair) and type(carried) == "table"
    and carried.item and (tonumber(carried.count) or 0) > 0)
  then
    return true
  end
  local phase = lower(machine_state.phase)
  if phase ~= "move-to-storage" and phase ~= "custody-deposit-blocked" then
    return true
  end
  local role = (carried.kind == "waste" or WASTE_ITEMS[carried.item])
    and "waste" or "retention"
  local box, _, why = find_or_create_role_box(
    pair, carried.item, carried.count, role)
  if not box then
    machine_state.storage = nil
    machine_state.storage_unit = nil
    machine_state.storage_kind = nil
    machine_state.phase = "return-custody-to-station"
    record(pair, "machine-role-box-unavailable",
      role .. " item=" .. safe(carried.item) .. " reason=" .. safe(why))
    return false
  end
  machine_state.storage = box
  machine_state.storage_unit = box.unit_number
  machine_state.storage_kind = role
  stat("machine_role_destination_primed")
  return true
end
local function patch_machine(machine)
  if not (machine and type(machine.service_pair) == "function") then return false end
  if machine.storage_role_authority_0686_active then return true end
  machine.storage_role_authority_0686_active = true
  previous_machine_service = machine.service_pair
  machine.service_pair = function(pair, reason, ...)
    local state = pair and pair.machine_logistics_0528
    if type(state) == "table" then prime_machine_destination(machine, pair, state) end
    local primary, secondary = previous_machine_service(pair, reason, ...)
    local after = pair and pair.machine_logistics_0528
    if type(after) == "table" then prime_machine_destination(machine, pair, after) end
    return primary, secondary
  end
  return true
end

local function sweep_role_containers()
  release_invalid_roles()
  local state = M.root()
  local checked, changed = 0, 0
  for _, rec in pairs(state.roles) do
    if checked >= M.max_role_sweep_entities then break end
    local entity, role = rec and rec.entity, rec and rec.role
    if valid(entity) and (role == "waste" or role == "retention") then
      checked = checked + 1
      local inv = container_inventory(entity)
      local pair = pair_for_entity(entity)
      if inv and valid_pair(pair) then
        for index = 1, #inv do
          local stack = inv[index]
          if stack and stack.valid_for_read then
            local correct = role == "waste" and WASTE_ITEMS[stack.name]
              or role == "retention" and not WASTE_ITEMS[stack.name]
            if not correct then
              local item, count = stack.name, stack.count
              local removed = inv_remove(inv, item, count)
              if removed > 0 then
                local ok, why, inserted = M.deposit_exact(
                  pair, item, removed, "role-container-correction",
                  { exclude_entity = entity, role = item_role(item, "role-correction") })
                if not ok or inserted ~= removed then
                  inv_insert(inv, item, removed)
                  record(pair, "role-container-correction-blocked",
                    item .. " reason=" .. safe(why), true)
                else
                  changed = changed + 1
                end
              end
            end
          end
        end
      end
    end
  end
  state.stats.last_role_sweep_checked = checked
  return {
    processed = checked,
    acted = changed,
    detail = "checked=" .. safe(checked) .. " changed=" .. safe(changed),
  }
end
local function register_service()
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if not (broker and type(broker.register_service) == "function") then
    return false
  end
  local service = broker.register_service({
    name = "storage_role_authority_0686_sweep",
    category = "inventory",
    interval = M.role_sweep_interval,
    priority = 68,
    budget = M.max_role_sweep_entities,
    dynamic_budget = false,
    note = "container-only generic storage role enforcement",
    fn = function() return sweep_role_containers() end,
  })
  return service ~= nil
end
local function patch_diagnostics()
  local diagnostics = rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
    or rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diagnostics and type(diagnostics.pair_dump_lines) == "function") then
    return false
  end
  if diagnostics.storage_role_authority_0686_wrapped then return true end
  diagnostics.storage_role_authority_0686_wrapped = true
  local previous = diagnostics.pair_dump_lines
  diagnostics.pair_dump_lines = function(...)
    local lines = previous(...)
    lines = type(lines) == "table" and lines or {}
    local state = M.root()
    lines[#lines + 1] = "PAIR-DUMP-0468 STORAGE-ROLES-0686 version="
      .. M.version .. " generic_container_only=" .. safe(state.generic_container_only)
      .. " exact_transactions=" .. safe(state.stats.exact_deposit_transactions or 0)
      .. " exact_items=" .. safe(state.stats.exact_items_deposited or 0)
      .. " blocked=" .. safe(state.stats.exact_deposit_blocked or 0)
      .. " machine_work_inventory_access=0 spill_calls=0"
    return lines
  end
  return true
end

function M.install()
  M.root()
  local ok_steward, steward = pcall(require, "scripts.core.inventory_steward")
  if not (ok_steward and steward) then return false end
  if not steward.storage_role_authority_0686_install_wrapped then
    steward.storage_role_authority_0686_install_wrapped = true
    previous_steward_install = steward.install
    steward.install = function(...)
      local previous = type(previous_steward_install) == "function"
        and previous_steward_install(...) or true
      local patched = patch_steward(steward)
      return previous == true and patched == true
    end
  end
  patch_steward(steward)

  local ok_stone, stone = pcall(require, "scripts.core.stone_cache_filter_0534")
  if ok_stone and stone then
    if not stone.storage_role_authority_0686_install_wrapped then
      stone.storage_role_authority_0686_install_wrapped = true
      previous_stone_install = stone.install
      stone.install = function(...)
        local previous = type(previous_stone_install) == "function"
          and previous_stone_install(...) or true
        local patched = patch_stone_cache(stone)
        return previous == true and patched == true
      end
    end
    patch_stone_cache(stone)
  end

  local ok_final, final = pcall(
    require, "scripts.core.machine_logistics_final_authority_0684")
  if ok_final and final and type(final.activate) == "function" then
    if not final.storage_role_authority_0686_activate_wrapped then
      final.storage_role_authority_0686_activate_wrapped = true
      previous_machine_activate = final.activate
      final.activate = function(machine, ...)
        local previous = previous_machine_activate(machine, ...)
        local patched = patch_machine(machine)
        return previous == true and patched == true
      end
    end
    local machine = rawget(_G, "TECH_PRIESTS_MACHINE_LOGISTICS_FULFILLMENT_0528")
    if machine then patch_machine(machine) end
  end

  local broker_ok = register_service()
  patch_diagnostics()
  _G.TechPriestsStorageRoleAuthority0686 = M
  _G.tech_priests_storage_deposit_exact_0686 = M.deposit_exact
  _G.tech_priests_generic_station_inventories_0686 = M.generic_station_inventories
  _G.tech_priests_generic_station_item_count_0686 = M.generic_item_count
  _G.tech_priests_generic_station_remove_0686 = M.remove_generic_item
  if log then
    log("[Tech-Priests 0.1.674-dev] container-only generic storage authority armed")
  end
  return broker_ok == true
end

return M
