-- Tech Priests 0.1.665 role-aware station storage authority.
--
-- One authority now defines where station-bound items may be stored:
--   * station inventory: general home inventory;
--   * filtered stone cache: exactly its declared item;
--   * waste box: mechanical detritus and scrap only;
--   * retention box: non-waste production output only;
--   * general stash: ordinary overflow only.
--
-- Deposits remain all-or-nothing for compatibility with callers that generate an
-- output only after a true return value. Capacity is planned before mutation;
-- partial insertion is rolled back. Wrong filtered-cache items are conserved and
-- rerouted, never spilled. Machine-logistics box memory is sanitized so one chest
-- cannot be both waste and retention storage.

local M = {
  version = "0.1.665",
  storage_key = "storage_role_authority_0686",
  scan_radius_floor = 28,
  scan_radius_cap = 96,
  role_sweep_interval = 181,
  full_cache_scan_interval = 60 * 60,
  max_role_sweep_entities = 64,
}

local previous_steward_install
local previous_stone_install
local previous_machine_activate
local previous_machine_service
local previous_stone_sweep
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

local function pair_map()
  return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    exact_atomic_deposits = true,
    no_spill_cache_recovery = true,
    enforce_role_exclusivity = true,
    roles = {},
    roles_by_station = {},
    stats = {},
    recent = {},
    last_log = {},
    last_full_cache_scan = -1000000,
  }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.exact_atomic_deposits == nil then r.exact_atomic_deposits = true end
  if r.no_spill_cache_recovery == nil then r.no_spill_cache_recovery = true end
  if r.enforce_role_exclusivity == nil then r.enforce_role_exclusivity = true end
  r.roles = r.roles or {}
  r.roles_by_station = r.roles_by_station or {}
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  r.last_log = r.last_log or {}
  if r.last_full_cache_scan == nil then r.last_full_cache_scan = -1000000 end
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
    detail = tostring(detail or ""),
  }
  r.recent[#r.recent + 1] = event
  while #r.recent > 180 do table.remove(r.recent, 1) end
  local key = event.action .. ":" .. event.station
  local last = tonumber(r.last_log[key] or -1000000) or -1000000
  if force_log or now() - last >= 600 then
    r.last_log[key] = now()
    if log then
      log("[Tech-Priests 0.1.665] " .. event.action
        .. " station=" .. event.station .. " " .. safe(detail))
    end
  end
  return event
end

local function entity_key(entity)
  if not valid(entity) then return nil end
  if entity.unit_number then return "unit:" .. tostring(entity.unit_number) end
  local position = entity.position or { x = 0, y = 0 }
  return tostring(entity.surface and entity.surface.index or "?")
    .. ":" .. tostring(entity.name or entity.type)
    .. ":" .. tostring(math.floor((position.x or 0) * 10))
    .. ":" .. tostring(math.floor((position.y or 0) * 10))
end

local function inventory(entity, inventory_id)
  if not (valid(entity) and inventory_id and entity.get_inventory) then return nil end
  local ok, inv = pcall(function() return entity.get_inventory(inventory_id) end)
  return ok and inv and inv.valid and inv or nil
end

local function container_inventory(entity)
  local d = defines and defines.inventory
  if not d then return nil end
  return inventory(entity, d.chest)
    or inventory(entity, d.car_trunk)
    or inventory(entity, d.spider_trunk)
end

local function station_inventories(pair)
  local out, seen = {}, {}
  if not valid_pair(pair) then return out end
  local function add(inv)
    if not (inv and inv.valid) then return end
    local key = safe(inv)
    if seen[key] then return end
    seen[key] = true
    out[#out + 1] = inv
  end
  if type(_G.get_station_inventory) == "function" then
    local ok, inv = pcall(_G.get_station_inventory, pair.station)
    if ok then add(inv) end
  end
  local d = defines and defines.inventory
  local ids = {}
  local function add_id(value) if value then ids[#ids + 1] = value end end
  if d then
    add_id(d.chest)
    add_id(d.assembling_machine_input)
    add_id(d.assembling_machine_output)
    add_id(d.furnace_source)
    add_id(d.furnace_result)
  end
  for _, inventory_id in ipairs(ids) do add(inventory(pair.station, inventory_id)) end
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
    local mid = math.floor((low + high + 1) / 2)
    local ok, can = pcall(function()
      return inv.can_insert({ name = item, count = mid })
    end)
    if ok and can then low = mid else high = mid - 1 end
  end
  return low
end

local function item_exists(name)
  return type(name) == "string"
    and name ~= ""
    and prototypes
    and prototypes.item
    and prototypes.item[name] ~= nil
end

local function entity_exists(name)
  return type(name) == "string"
    and name ~= ""
    and prototypes
    and prototypes.entity
    and prototypes.entity[name] ~= nil
end

local function fixed_filtered_role(entity)
  local item = valid(entity) and FILTERED_CACHE_ITEMS[entity.name] or nil
  return item and ("filtered:" .. item) or nil, item
end

local function role_for(entity)
  if not valid(entity) then return nil end
  local fixed = fixed_filtered_role(entity)
  if fixed then return fixed end
  if entity == nil then return nil end
  local key = entity_key(entity)
  local rec = key and root().roles[key] or nil
  return rec and rec.role or nil
end

local function remember_role(pair, entity, role, reason)
  if not (valid(entity) and role) then return false, "invalid" end
  local fixed = fixed_filtered_role(entity)
  if fixed and fixed ~= role then return false, "fixed-filtered-role" end
  local key = entity_key(entity)
  if not key then return false, "no-key" end
  local r = root()
  local existing = r.roles[key]
  if existing and existing.role and existing.role ~= role then
    if existing.role ~= "general" and role ~= "general" then
      stat("role_conflict_denied")
      return false, "role-conflict:" .. tostring(existing.role)
    end
    if existing.role ~= "general" and role == "general" then
      stat("role_conflict_denied")
      return false, "specialized-role:" .. tostring(existing.role)
    end
  end
  local unit = station_unit(pair)
  r.roles[key] = {
    role = role,
    entity = entity,
    entity_name = entity.name,
    entity_unit = entity.unit_number,
    station_unit = unit,
    tick = now(),
    reason = tostring(reason or "assigned"),
  }
  if unit then
    local bucket = r.roles_by_station[tostring(unit)] or {}
    r.roles_by_station[tostring(unit)] = bucket
    bucket[key] = true
  end
  stat(existing and "role_renewed" or "role_assigned")
  return true, role
end

local function release_invalid_roles()
  local r = root()
  for key, rec in pairs(r.roles) do
    if not (rec and valid(rec.entity)) then
      r.roles[key] = nil
      for _, bucket in pairs(r.roles_by_station) do bucket[key] = nil end
      stat("invalid_role_released")
    end
  end
end

local function item_role(item, reason)
  if WASTE_ITEMS[item] then return "waste" end
  local text = lower(reason)
  if text:find("waste", 1, true)
    or text:find("detritus", 1, true)
    or text:find("scrap", 1, true)
  then
    return "waste"
  end
  if text:find("retention", 1, true)
    or text:find("machine%-output", 1, false)
    or text:find("production%-output", 1, false)
  then
    return "retention"
  end
  return "general"
end

local function role_accepts(entity, item, requested_role)
  if not (valid(entity) and item) then return false, "invalid" end
  local fixed, filtered_item = fixed_filtered_role(entity)
  if fixed then
    return item == filtered_item, item == filtered_item and "matching-filter" or "filtered-mismatch"
  end

  local role = role_for(entity)
  if role == "waste" then
    return WASTE_ITEMS[item] == true, WASTE_ITEMS[item] and "waste" or "waste-reject"
  end
  if role == "retention" then
    return not WASTE_ITEMS[item], WASTE_ITEMS[item] and "retention-reject-waste" or "retention"
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

local function pair_for_entity(entity)
  if not valid(entity) then return nil end
  local catalog = storage and storage.tech_priests
    and (storage.tech_priests.station_catalog_0327 or storage.tech_priests.station_catalog_0326)
  local owner = catalog and catalog.owned_resources
    and catalog.owned_resources[(entity.unit_number and "u:" .. tostring(entity.unit_number)) or ""]
  if owner then
    local map = pair_map()
    local pair = map[owner] or map[tostring(owner)]
    if valid_pair(pair) then return pair end
  end

  local best, best_distance
  for _, pair in pairs(pair_map()) do
    if valid_pair(pair)
      and pair.station.surface == entity.surface
      and pair.station.force == entity.force
    then
      local distance = dist_sq(pair.station.position, entity.position)
      if not best_distance or distance < best_distance then
        best, best_distance = pair, distance
      end
    end
  end
  return best
end

local function steward_root()
  return storage and storage.tech_priests
    and (storage.tech_priests.inventory_steward_0357 or storage.tech_priests.inventory_steward_0356)
    or nil
end

local function remember_general_stash(pair, entity)
  local sroot = steward_root()
  local unit = station_unit(pair)
  if not (sroot and unit and valid(entity)) then return end
  sroot.stashes_by_station = sroot.stashes_by_station or {}
  local bucket = sroot.stashes_by_station[unit] or sroot.stashes_by_station[tostring(unit)] or {}
  sroot.stashes_by_station[unit] = bucket
  bucket[entity.unit_number or entity_key(entity)] = {
    entity = entity,
    unit = entity.unit_number,
    name = entity.name,
    tick = now(),
    x = entity.position.x,
    y = entity.position.y,
  }
end

local function nearby_container_candidates(pair)
  local out, seen = {}, {}
  if not valid_pair(pair) then return out end
  local function add(entity, source)
    if not valid(entity) or entity == pair.station then return end
    local key = entity_key(entity)
    if not key or seen[key] then return end
    local inv = container_inventory(entity)
    if not inv then return end
    seen[key] = true
    out[#out + 1] = {
      entity = entity,
      inv = inv,
      source = source,
      distance = dist_sq(pair.station.position, entity.position),
    }
  end

  local sroot = steward_root()
  local unit = station_unit(pair)
  local bucket = sroot and sroot.stashes_by_station
    and (sroot.stashes_by_station[unit] or sroot.stashes_by_station[tostring(unit)])
  for key, rec in pairs(bucket or {}) do
    if rec and valid(rec.entity) then add(rec.entity, "remembered") else bucket[key] = nil end
  end

  local radius = tonumber(pair.radius) or M.scan_radius_floor
  if type(_G.get_station_operating_radius) == "function" then
    local ok, value = pcall(_G.get_station_operating_radius, pair.station)
    if ok and tonumber(value) then radius = tonumber(value) end
  end
  radius = math.max(8, math.min(math.max(radius, M.scan_radius_floor), M.scan_radius_cap))
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

local function station_item_count(pair, item)
  local total = 0
  for _, inv in ipairs(station_inventories(pair)) do total = total + inv_count(inv, item) end
  return total
end

local function remove_station_item(pair, item, count)
  local remaining = math.max(0, tonumber(count) or 0)
  local removed = 0
  for _, inv in ipairs(station_inventories(pair)) do
    if remaining <= 0 then break end
    local amount = inv_remove(inv, item, remaining)
    removed = removed + amount
    remaining = remaining - amount
  end
  return removed
end

local function insert_station_item(pair, item, count)
  local remaining = math.max(0, tonumber(count) or 0)
  local inserted = 0
  for _, inv in ipairs(station_inventories(pair)) do
    if remaining <= 0 then break end
    local amount = inv_insert(inv, item, remaining)
    inserted = inserted + amount
    remaining = remaining - amount
  end
  return inserted
end

local function stash_position(pair, entity_name)
  if not valid_pair(pair) then return nil end
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
      return pair.station.surface.find_non_colliding_position(entity_name, desired, 4, 0.25, false)
    end)
    if ok and position then return position end
  end
  return nil
end

local function refund_materials(pair, materials)
  local failed = {}
  for item, count in pairs(materials or {}) do
    local inserted = insert_station_item(pair, item, count)
    if inserted < count then failed[item] = count - inserted end
  end
  return failed
end

local function safe_create_stash(pair, role)
  if not valid_pair(pair) then return nil, "invalid-pair" end
  local chosen, materials, position

  for _, entity_name in ipairs(GENERAL_STASH_NAMES) do
    if entity_exists(entity_name) and item_exists(entity_name)
      and station_item_count(pair, entity_name) > 0
    then
      local candidate_position = stash_position(pair, entity_name)
      if candidate_position then
        chosen = entity_name
        materials = { [entity_name] = 1 }
        position = candidate_position
        break
      end
    end
  end

  if not chosen then
    for _, entity_name in ipairs(GENERAL_STASH_NAMES) do
      local cost = GENERAL_STASH_COSTS[entity_name]
      if entity_exists(entity_name) and cost then
        local enough = true
        for item, count in pairs(cost) do
          if station_item_count(pair, item) < count then enough = false break end
        end
        if enough then
          local candidate_position = stash_position(pair, entity_name)
          if candidate_position then
            chosen = entity_name
            materials = cost
            position = candidate_position
            break
          end
        end
      end
    end
  end

  if not (chosen and materials and position) then return nil, "no-safe-stash-plan" end

  local removed = {}
  for item, count in pairs(materials) do
    local got = remove_station_item(pair, item, count)
    removed[item] = got
    if got < count then
      refund_materials(pair, removed)
      record(pair, "stash-material-removal-failed", item .. " got=" .. safe(got) .. " need=" .. safe(count), true)
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
    local failed = refund_materials(pair, removed)
    record(pair, "stash-create-failed-refunded", chosen .. " refund_failures=" .. safe(next(failed) ~= nil), true)
    return nil, "create-failed"
  end

  remember_general_stash(pair, entity)
  local assigned, why = remember_role(pair, entity, role or "general", "created-for-storage-role")
  if not assigned then
    record(pair, "stash-role-assignment-failed", safe(why), true)
  end
  stat("safe_stash_created")
  return entity, "created"
end

local function candidate_priority(entity, item, requested_role)
  if entity == nil then return 999999 end
  local fixed, filtered_item = fixed_filtered_role(entity)
  if fixed and filtered_item == item then return requested_role == "general" and 10 or 18 end
  local role = role_for(entity)
  if role == requested_role then return 5 end
  if role == "general" then return requested_role == "general" and 12 or 20 end
  if role == nil then return requested_role == "general" and 15 or 24 end
  return 1000
end

local function collect_destinations(pair, item, requested_role, exclude_entity)
  local out = {}
  for index, inv in ipairs(station_inventories(pair)) do
    out[#out + 1] = {
      entity = pair.station,
      inv = inv,
      role = "station",
      priority = requested_role == "waste" and 30 or 1,
      distance = index * 0.001,
    }
  end

  for _, candidate in ipairs(nearby_container_candidates(pair)) do
    if candidate.entity ~= exclude_entity then
      local accepts, why = role_accepts(candidate.entity, item, requested_role)
      if accepts then
        candidate.role = role_for(candidate.entity)
        candidate.claim_role = why and why:find("claimable:", 1, true)
          and requested_role or nil
        candidate.priority = candidate_priority(candidate.entity, item, requested_role)
        out[#out + 1] = candidate
      end
    end
  end

  table.sort(out, function(a, b)
    if a.priority ~= b.priority then return a.priority < b.priority end
    return (a.distance or 999999999) < (b.distance or 999999999)
  end)
  return out
end

local function build_deposit_plan(pair, item, count, requested_role, exclude_entity)
  local remaining = count
  local plan = {}
  for _, destination in ipairs(collect_destinations(pair, item, requested_role, exclude_entity)) do
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

local function rollback_plan(item, completed)
  local rolled_back = 0
  for index = #completed, 1, -1 do
    local entry = completed[index]
    rolled_back = rolled_back + inv_remove(entry.inv, item, entry.inserted)
  end
  return rolled_back
end

local function execute_deposit_plan(pair, item, count, requested_role, plan, reason)
  local completed = {}
  local inserted_total = 0
  for _, entry in ipairs(plan) do
    if entry.claim_role and entry.entity ~= pair.station then
      local claimed, why = remember_role(pair, entry.entity, entry.claim_role, "deposit-plan:" .. safe(reason))
      if not claimed then
        local rolled = rollback_plan(item, completed)
        record(pair, "deposit-role-claim-failed", safe(why) .. " rolled=" .. safe(rolled), true)
        return false, "role-claim-failed", 0
      end
    end
    local inserted = inv_insert(entry.inv, item, entry.count)
    if inserted ~= entry.count then
      if inserted > 0 then completed[#completed + 1] = { inv = entry.inv, inserted = inserted } end
      local rolled = rollback_plan(item, completed)
      record(pair, "atomic-deposit-rollback", item .. " expected=" .. safe(entry.count) .. " inserted=" .. safe(inserted) .. " rolled=" .. safe(rolled), true)
      return false, "atomic-insert-failed", 0
    end
    completed[#completed + 1] = { inv = entry.inv, inserted = inserted }
    inserted_total = inserted_total + inserted
  end
  if inserted_total ~= count then
    local rolled = rollback_plan(item, completed)
    record(pair, "atomic-deposit-count-mismatch", item .. " expected=" .. safe(count) .. " inserted=" .. safe(inserted_total) .. " rolled=" .. safe(rolled), true)
    return false, "count-mismatch", 0
  end
  stat("exact_items_deposited", inserted_total)
  stat("exact_deposit_transactions")
  return true, requested_role, inserted_total
end

function M.deposit_exact(pair, item, count, reason, options)
  local r = root()
  if r.enabled == false then return false, "disabled", 0 end
  if not (valid_pair(pair) and item_exists(item)) then return false, "invalid", 0 end
  count = math.max(1, math.floor(tonumber(count) or 1))
  options = options or {}
  local requested_role = options.role or item_role(item, reason)
  local plan, remaining = build_deposit_plan(pair, item, count, requested_role, options.exclude_entity)

  if remaining > 0 and options.allow_create ~= false then
    local stash, why = safe_create_stash(pair, requested_role == "general" and "general" or requested_role)
    if stash then
      plan, remaining = build_deposit_plan(pair, item, count, requested_role, options.exclude_entity)
    else
      record(pair, "deposit-stash-unavailable", item .. " x" .. safe(count) .. " reason=" .. safe(why))
    end
  end

  if remaining > 0 then
    stat("exact_deposit_blocked")
    return false, "no-role-capacity", 0
  end
  return execute_deposit_plan(pair, item, count, requested_role, plan, reason)
end

local function filter_steward_sources(previous, pair)
  local ok, list = pcall(previous, pair)
  if not (ok and type(list) == "table") then return {} end
  local out = {}
  for _, source in ipairs(list) do
    local entity = source and source.entity
    local role = role_for(entity)
    if role ~= "waste" then out[#out + 1] = source else stat("waste_source_hidden") end
  end
  return out
end

local function patch_steward(steward)
  if not steward or steward.storage_role_authority_0686_active then return false end
  steward.storage_role_authority_0686_active = true

  steward.safe_deposit_item = function(pair, item, count, reason)
    return M.deposit_exact(pair, item, count, reason, {})
  end
  _G.tech_priests_safe_deposit_item = steward.safe_deposit_item

  steward.create_stash = function(pair)
    return safe_create_stash(pair, "general")
  end
  _G.tech_priests_inventory_steward_create_stash = steward.create_stash

  if type(steward.sources_for_pair) == "function" then
    local previous_sources = steward.sources_for_pair
    steward.sources_for_pair = function(pair)
      return filter_steward_sources(previous_sources, pair)
    end
    _G.tech_priests_inventory_steward_sources_for_pair = steward.sources_for_pair
  end

  if commands and commands.remove_command then
    pcall(commands.remove_command, "tp-inventory-steward-0356")
    pcall(commands.remove_command, "tp-inventory-steward-0357")
  end
  return true
end

local function sync_machine_buckets(machine, pair)
  if not (machine and type(machine.root) == "function" and valid_pair(pair)) then return end
  local ok, mroot = pcall(machine.root)
  if not (ok and mroot) then return end
  local unit = tostring(station_unit(pair) or "?")
  for bucket_name, role in pairs({ waste_boxes = "waste", retention_boxes = "retention" }) do
    local all = mroot[bucket_name] or {}
    mroot[bucket_name] = all
    local bucket = all[unit] or {}
    all[unit] = bucket
    for key, rec in pairs(bucket) do
      local entity = rec and rec.entity
      if not valid(entity) then
        bucket[key] = nil
      else
        local current = role_for(entity)
        if current and current ~= "general" and current ~= role then
          bucket[key] = nil
          stat("machine_bucket_conflict_removed")
        else
          local assigned = remember_role(pair, entity, role, "machine-bucket-sync")
          if not assigned then bucket[key] = nil end
        end
      end
    end
  end
end

local function role_box_capacity(entity, item, count, role)
  local accepts = role_accepts(entity, item, role)
  local inv = container_inventory(entity)
  return accepts and inv and insertable_count(inv, item, count) >= count, inv
end

local function find_or_create_role_box(pair, item, count, role)
  for _, candidate in ipairs(nearby_container_candidates(pair)) do
    if candidate.entity ~= pair.station then
      local current = role_for(candidate.entity)
      if current == role or current == nil or current == "general" then
        local enough, inv = role_box_capacity(candidate.entity, item, count, role)
        if enough then
          local claimed = remember_role(pair, candidate.entity, role, "machine-destination")
          if claimed then return candidate.entity, inv, "existing-role-box" end
        end
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

local function prime_machine_destination(machine, pair, state)
  local carried = state and state.carried
  if not (valid_pair(pair) and type(carried) == "table"
    and carried.item and (tonumber(carried.count) or 0) > 0)
  then
    return true
  end
  local phase = lower(state.phase)
  if phase ~= "move-to-storage" and phase ~= "custody-deposit-blocked" then return true end
  local role = (carried.kind == "waste" or WASTE_ITEMS[carried.item]) and "waste" or "retention"
  sync_machine_buckets(machine, pair)
  local box, _, why = find_or_create_role_box(pair, carried.item, carried.count, role)
  if not box then
    state.storage = nil
    state.storage_unit = nil
    state.storage_kind = nil
    state.phase = "return-custody-to-station"
    record(pair, "machine-role-box-unavailable", role .. " item=" .. carried.item .. " reason=" .. safe(why))
    return false
  end

  local ok, mroot = pcall(machine.root)
  if ok and mroot then
    local unit = tostring(station_unit(pair) or "?")
    local bucket_root = role == "waste" and mroot.waste_boxes or mroot.retention_boxes
    bucket_root[unit] = bucket_root[unit] or {}
    bucket_root[unit][entity_key(box)] = {
      entity = box,
      unit = box.unit_number,
      name = box.name,
      x = box.position.x,
      y = box.position.y,
      tick = now(),
      reason = "storage-role-authority-0686",
    }
    local other_root = role == "waste" and mroot.retention_boxes or mroot.waste_boxes
    if other_root and other_root[unit] then other_root[unit][entity_key(box)] = nil end
  end
  state.storage = box
  state.storage_unit = box.unit_number
  state.storage_kind = role
  stat("machine_role_destination_primed")
  return true
end

local function patch_machine(machine)
  if not (machine and type(machine.service_pair) == "function")
    or machine.storage_role_authority_0686_active
  then
    return false
  end
  machine.storage_role_authority_0686_active = true
  previous_machine_service = machine.service_pair
  machine.service_pair = function(pair, reason, ...)
    local state = pair and pair.machine_logistics_0528
    if type(state) == "table" then prime_machine_destination(machine, pair, state) end
    local acted, why = previous_machine_service(pair, reason, ...)
    sync_machine_buckets(machine, pair)
    local after = pair and pair.machine_logistics_0528
    if type(after) == "table" then prime_machine_destination(machine, pair, after) end
    return acted, why
  end
  return true
end

local function reroute_wrong_stack(entity, stack, allowed_item)
  if not (valid(entity) and stack and stack.valid_for_read and stack.name ~= allowed_item) then return false end
  local pair = pair_for_entity(entity)
  if not valid_pair(pair) then
    stat("filtered_cache_no_owner")
    return false
  end

  local item, count = stack.name, stack.count
  local inv = container_inventory(entity)
  if not inv then return false end
  local removed = inv_remove(inv, item, count)
  if removed <= 0 then return false end

  local role = item_role(item, "filtered-cache-recovery")
  local ok, why, inserted = M.deposit_exact(pair, item, removed, "filtered-cache-recovery", {
    exclude_entity = entity,
    role = role,
  })
  if ok and inserted == removed then
    record(pair, "filtered-cache-item-rerouted", item .. " x" .. safe(removed) .. " from " .. safe(entity.name))
    return true
  end

  local restored = inv_insert(inv, item, removed)
  record(pair, "filtered-cache-reroute-blocked", item .. " x" .. safe(removed) .. " restored=" .. safe(restored) .. " reason=" .. safe(why), true)
  return false
end

local function patch_stone_cache(stone)
  if not stone or stone.storage_role_authority_0686_active then return false end
  stone.storage_role_authority_0686_active = true
  previous_stone_sweep = stone.sweep_entity
  previous_stone_scan_all = stone.scan_all_surfaces

  stone.sweep_entity = function(entity)
    if not valid(entity) then return false end
    local allowed = FILTERED_CACHE_ITEMS[entity.name]
    if not allowed then return false end
    remember_role(pair_for_entity(entity), entity, "filtered:" .. allowed, "filtered-cache-prototype")
    local inv = container_inventory(entity)
    if not inv then return false end
    local changed = false
    for index = 1, #inv do
      local stack = inv[index]
      if stack and stack.valid_for_read and stack.name ~= allowed then
        changed = reroute_wrong_stack(entity, stack, allowed) or changed
      end
    end
    stat("filtered_cache_swept")
    return changed
  end

  stone.scan_all_surfaces = function(force)
    local r = root()
    if force ~= true and now() - (tonumber(r.last_full_cache_scan) or -1000000) < M.full_cache_scan_interval then
      stat("filtered_cache_full_scan_skipped")
      return 0
    end
    r.last_full_cache_scan = now()
    local count = type(previous_stone_scan_all) == "function" and previous_stone_scan_all() or 0
    stat("filtered_cache_full_scans")
    return count
  end

  if commands and commands.remove_command then
    pcall(commands.remove_command, "tp-cache-filters-0534")
  end
  return true
end

local function sweep_role_containers()
  release_invalid_roles()
  local r = root()
  local checked = 0
  for _, rec in pairs(r.roles) do
    if checked >= M.max_role_sweep_entities then break end
    local entity = rec and rec.entity
    local role = rec and rec.role
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
                local target_role = item_role(item, "role-container-correction")
                local ok, why, inserted = M.deposit_exact(pair, item, removed, "role-container-correction", {
                  exclude_entity = entity,
                  role = target_role,
                })
                if not ok or inserted ~= removed then
                  local restored = inv_insert(inv, item, removed)
                  record(pair, "role-container-correction-blocked", item .. " restored=" .. safe(restored) .. " reason=" .. safe(why), true)
                else
                  record(pair, "role-container-item-rerouted", item .. " x" .. safe(removed) .. " from=" .. role)
                end
              end
            end
          end
        end
      end
    end
  end
  r.stats.last_role_sweep_checked = checked
  return checked
end

local function patch_diagnostics()
  local diagnostics = rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
    or rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diagnostics and type(diagnostics.pair_dump_lines) == "function")
    or diagnostics.storage_role_authority_0686_wrapped
  then
    return false
  end
  diagnostics.storage_role_authority_0686_wrapped = true
  local previous = diagnostics.pair_dump_lines
  diagnostics.pair_dump_lines = function(...)
    local lines = previous(...)
    lines = type(lines) == "table" and lines or {}
    local r = root()
    local role_counts = { general = 0, waste = 0, retention = 0, filtered = 0 }
    for _, rec in pairs(r.roles) do
      local role = rec and rec.role or ""
      if role:find("filtered:", 1, true) == 1 then
        role_counts.filtered = role_counts.filtered + 1
      elseif role_counts[role] ~= nil then
        role_counts[role] = role_counts[role] + 1
      end
    end
    lines[#lines + 1] = "PAIR-DUMP-0468 STORAGE-ROLES-0686 enabled="
      .. safe(r.enabled)
      .. " exact_transactions=" .. safe(r.stats.exact_deposit_transactions or 0)
      .. " exact_items=" .. safe(r.stats.exact_items_deposited or 0)
      .. " blocked=" .. safe(r.stats.exact_deposit_blocked or 0)
      .. " rollbacks=" .. safe(r.stats["atomic-deposit-rollback"] or 0)
      .. " general=" .. safe(role_counts.general)
      .. " waste=" .. safe(role_counts.waste)
      .. " retention=" .. safe(role_counts.retention)
      .. " filtered=" .. safe(role_counts.filtered)
      .. " role_conflicts=" .. safe(r.stats.role_conflict_denied or 0)
      .. " cache_rerouted=" .. safe(r.stats["filtered-cache-item-rerouted"] or 0)
      .. " cache_blocked=" .. safe(r.stats["filtered-cache-reroute-blocked"] or 0)
      .. " spill_calls=0"
      .. " sweep_checked=" .. safe(r.stats.last_role_sweep_checked or 0)
    for index = math.max(1, #r.recent - 10), #r.recent do
      local event = r.recent[index]
      if event then
        lines[#lines + 1] = "PAIR-DUMP-0468 storage-role.recent[" .. safe(index) .. "]"
          .. " tick=" .. safe(event.tick)
          .. " action=" .. safe(event.action)
          .. " station=" .. safe(event.station)
          .. " " .. safe(event.detail)
      end
    end
    return lines
  end
  return true
end

local function register_service()
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service) == "function" then
    broker.register_service({
      name = "storage_role_authority_0686_sweep",
      category = "inventory",
      interval = M.role_sweep_interval,
      priority = 68,
      budget = M.max_role_sweep_entities,
      note = "enforces filtered/waste/retention/general storage exclusivity without spills",
      fn = function()
        local checked = sweep_role_containers()
        return checked > 0, "checked=" .. safe(checked)
      end,
    })
  end
end

local function activate_steward(steward)
  patch_steward(steward)
  patch_diagnostics()
  _G.TechPriestsStorageRoleAuthority0686 = M
end

function M.install()
  root()

  local ok_steward, steward = pcall(require, "scripts.core.inventory_steward")
  if ok_steward and steward then
    if not steward.storage_role_authority_0686_install_wrapped then
      steward.storage_role_authority_0686_install_wrapped = true
      previous_steward_install = steward.install
      steward.install = function(...)
        local result = type(previous_steward_install) == "function" and previous_steward_install(...) or true
        activate_steward(steward)
        return result
      end
    end
    if rawget(_G, "TECH_PRIESTS_STATION_BOUND_INVENTORY_0357") then activate_steward(steward) end
  end

  local ok_stone, stone = pcall(require, "scripts.core.stone_cache_filter_0534")
  if ok_stone and stone then
    if not stone.storage_role_authority_0686_install_wrapped then
      stone.storage_role_authority_0686_install_wrapped = true
      previous_stone_install = stone.install
      stone.install = function(...)
        local result = type(previous_stone_install) == "function" and previous_stone_install(...) or true
        patch_stone_cache(stone)
        return result
      end
    end
    if rawget(_G, "tech_priests_stone_cache_filter_0534") then patch_stone_cache(stone) end
  end

  local ok_final, final = pcall(require, "scripts.core.machine_logistics_final_authority_0684")
  if ok_final and final and type(final.activate) == "function" then
    if not final.storage_role_authority_0686_activate_wrapped then
      final.storage_role_authority_0686_activate_wrapped = true
      previous_machine_activate = final.activate
      final.activate = function(machine, ...)
        local result = previous_machine_activate(machine, ...)
        patch_machine(machine)
        return result
      end
    end
    local machine = rawget(_G, "TECH_PRIESTS_MACHINE_LOGISTICS_FULFILLMENT_0528")
    if machine then patch_machine(machine) end
  end

  register_service()
  patch_diagnostics()
  _G.TechPriestsStorageRoleAuthority0686 = M
  _G.tech_priests_storage_deposit_exact_0686 = M.deposit_exact
  if log then
    log("[Tech-Priests 0.1.665] exact role-aware storage authority armed; filtered caches no longer spill and waste/retention roles are exclusive")
  end
  return true
end

return M
