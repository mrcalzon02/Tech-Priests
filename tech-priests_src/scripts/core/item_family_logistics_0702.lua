-- scripts/core/item_family_logistics_0702.lua
-- Tech Priests 0.1.674-dev recovery.
-- Canonical visible item-family logistics owner. Broker work is discovery only;
-- the pure classifier recommends work and single_dispatcher_0510 alone executes it.
-- Hidden proxy ammunition remains exclusively owned by proxy_ammo_hardener_0649.

local M = {
  version = "0.1.674-dev",
  storage_key = "item_family_logistics_0702",
  pickup_reach_sq = 2.56,
  target_reach_sq = 2.56,
  return_reach_sq = 2.56,
  move_priority = 978,
  move_ttl = 60 * 10,
  reservation_ttl = 60 * 15,
  request_timeout = 60 * 14,
  discovery_interval = 181,
  service_radius_floor = 28,
  service_radius_cap = 96,
  max_scan_entities = 160,
  max_pairs_per_discovery = 8,
  turret_target_count = 10,
  lab_cycles = 5,
  max_transfer = 50,
}

local AMMO_ORDER = {
  "uranium-rounds-magazine",
  "piercing-rounds-magazine",
  "firearm-magazine",
}

local TERMINAL = {
  complete = true,
  completed = true,
  done = true,
  aborted = true,
  failed = true,
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
local function priest_unit(pair)
  return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil
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

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local state = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    dispatcher_owned = true,
    discovery_only_broker = true,
    proxy_ammo_excluded = true,
    stats = {},
    recent = {},
    discovery_due = {},
    discovery_cursor = 0,
  }
  storage.tech_priests[M.storage_key] = state
  state.version = M.version
  if state.enabled == nil then state.enabled = true end
  if state.dispatcher_owned == nil then state.dispatcher_owned = true end
  if state.discovery_only_broker == nil then state.discovery_only_broker = true end
  if state.proxy_ammo_excluded == nil then state.proxy_ammo_excluded = true end
  state.stats = state.stats or {}
  state.recent = state.recent or {}
  state.discovery_due = state.discovery_due or {}
  state.discovery_cursor = tonumber(state.discovery_cursor) or 0
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
    action = tostring(action or "event"),
    station = safe(station_unit(pair)),
    priest = safe(priest_unit(pair)),
    detail = tostring(detail or ""),
  }
  state.recent[#state.recent + 1] = event
  while #state.recent > 180 do table.remove(state.recent, 1) end
  if pair then pair.item_family_logistics_last_0702 = event end
  if force_log and log then
    log("[Tech-Priests recovery] item-family " .. event.action
      .. " station=" .. event.station .. " priest=" .. event.priest
      .. " " .. event.detail)
  end
end

local function inventory(entity, inventory_id)
  if not (valid(entity) and inventory_id and entity.get_inventory) then return nil end
  local ok, inv = pcall(function() return entity.get_inventory(inventory_id) end)
  return ok and inv and inv.valid and inv or nil
end
local function inv_count(inv, item)
  if not (inv and inv.valid and item) then return 0 end
  local ok, count = pcall(function() return inv.get_item_count(item) end)
  return ok and (tonumber(count) or 0) or 0
end
local function inv_remove(inv, item, count)
  if not (inv and inv.valid and item and (tonumber(count) or 0) > 0) then return 0 end
  local ok, removed = pcall(function()
    return inv.remove({ name = item, count = count })
  end)
  return ok and (tonumber(removed) or 0) or 0
end
local function inv_insert(inv, item, count)
  if not (inv and inv.valid and item and (tonumber(count) or 0) > 0) then return 0 end
  local ok, inserted = pcall(function()
    return inv.insert({ name = item, count = count })
  end)
  return ok and (tonumber(inserted) or 0) or 0
end
local function inv_can_insert(inv, item, count)
  if not (inv and inv.valid and item and (tonumber(count) or 1) > 0) then return false end
  local ok, accepted = pcall(function()
    return inv.can_insert({ name = item, count = count or 1 })
  end)
  return ok and accepted == true
end

local function service_radius(pair)
  local radius = tonumber(pair and pair.radius) or M.service_radius_floor
  if valid_pair(pair) and type(_G.get_station_operating_radius) == "function" then
    local ok, value = pcall(_G.get_station_operating_radius, pair.station)
    if ok and tonumber(value) then radius = tonumber(value) end
  end
  return math.max(8, math.min(math.max(radius, M.service_radius_floor), M.service_radius_cap))
end

local function home_sources(pair)
  local out, seen = {}, {}
  if not valid_pair(pair) then return out end
  local home = station_unit(pair)
  local radius = service_radius(pair)
  local function add(source)
    local inv = source and source.inv
    local entity = source and source.entity
    if not (inv and inv.valid and valid(entity)) then return end
    if entity.surface ~= pair.station.surface or entity.force ~= pair.station.force then return end
    if source.authority_source_station_0573
      and tostring(source.authority_source_station_0573) ~= tostring(home)
    then
      return
    end
    if dist_sq(entity.position, pair.station.position) > radius * radius then return end
    local key = safe(inv)
    if seen[key] then return end
    seen[key] = true
    out[#out + 1] = {
      inv = inv,
      entity = entity,
      label = source.source or source.inventory_id or "home-source",
    }
  end
  local source_fn = rawget(_G, "tech_priests_inventory_steward_sources_for_pair")
  if type(source_fn) == "function" then
    local ok, sources = pcall(source_fn, pair)
    if ok and type(sources) == "table" then
      for _, source in ipairs(sources) do add(source) end
    end
  end
  local ids = defines and defines.inventory
  if ids then
    local station_inv = inventory(pair.station, ids.chest)
    if station_inv then add({ inv = station_inv, entity = pair.station, source = "station-chest" }) end
  end
  return out
end

local function item_prototype(item)
  return prototypes and prototypes.item and prototypes.item[item] or nil
end
local function is_ammo(item)
  local prototype = item_prototype(item)
  if not prototype then return false end
  local item_type
  pcall(function() item_type = prototype.type end)
  if item_type == "ammo" then return true end
  local category
  pcall(function() category = prototype.ammo_category end)
  return category ~= nil
end

local function contents(inv)
  local result = {}
  if not (inv and inv.valid) then return result end
  local ok, raw = pcall(function() return inv.get_contents() end)
  if not (ok and type(raw) == "table") then return result end
  for key, value in pairs(raw) do
    local name, count
    if type(key) == "string" then
      name = key
      count = type(value) == "table"
        and tonumber(value.count or value.amount or value[2]) or tonumber(value)
    elseif type(value) == "table" then
      name = value.name or value.item or value[1]
      count = tonumber(value.count or value.amount or value[2])
    end
    if type(name) == "string" and (tonumber(count) or 0) > 0 then
      result[#result + 1] = { name = name, count = tonumber(count) or 1 }
    end
  end
  return result
end

local function source_for_item(pair, item, target_inv)
  local best
  for _, source in ipairs(home_sources(pair)) do
    local count = inv_count(source.inv, item)
    if count > 0 and (not target_inv or inv_can_insert(target_inv, item, 1)) then
      local distance = dist_sq(pair.priest.position, source.entity.position)
      if not best or distance < best.distance then
        best = {
          item = item,
          count = count,
          inv = source.inv,
          entity = source.entity,
          label = source.label,
          distance = distance,
        }
      end
    end
  end
  return best
end

local function compatible_ammo(target_inv)
  for _, item in ipairs(AMMO_ORDER) do
    if item_prototype(item) and inv_can_insert(target_inv, item, 1) then return item end
  end
  local names = {}
  for item_name in pairs(prototypes and prototypes.item or {}) do
    if is_ammo(item_name) and inv_can_insert(target_inv, item_name, 1) then
      names[#names + 1] = item_name
    end
  end
  table.sort(names)
  return names[1]
end

local function best_ammo_source(pair, target_inv)
  local best
  for _, source in ipairs(home_sources(pair)) do
    for _, entry in ipairs(contents(source.inv)) do
      if is_ammo(entry.name) and inv_can_insert(target_inv, entry.name, 1) then
        local rank = 100
        for index, name in ipairs(AMMO_ORDER) do
          if entry.name == name then rank = index break end
        end
        local score = rank * 100000
          + dist_sq(pair.priest.position, source.entity.position)
          - math.min(entry.count, 1000)
        if not best or score < best.score then
          best = {
            item = entry.name,
            count = entry.count,
            inv = source.inv,
            entity = source.entity,
            label = source.label,
            score = score,
          }
        end
      end
    end
  end
  return best
end

local function target_inventory(task)
  if not (task and valid(task.target) and defines and defines.inventory) then return nil end
  if task.family == "lab-science" then
    return inventory(task.target, defines.inventory.lab_input)
  end
  if task.family == "turret-ammo" then
    return inventory(task.target, defines.inventory.turret_ammo)
  end
  return nil
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
    if category == "item-family-logistics" then found = true break end
  end
  if not found then
    reservations.categories = reservations.categories or {}
    reservations.categories[#reservations.categories + 1] = "item-family-logistics"
  end
  local state = type(reservations.root) == "function" and reservations.root() or nil
  if state then
    state.reservations = state.reservations or {}
    state.reservations["item-family-logistics"] = state.reservations["item-family-logistics"] or {}
  end
  return reservations
end

local function claim_target(pair, task)
  local reservations = ensure_reservation_category()
  if not (reservations and type(reservations.claim) == "function" and valid(task.target)) then
    return false, "reservation-unavailable"
  end
  local ok, why = reservations.claim(
    "item-family-logistics",
    task.target,
    pair,
    M.reservation_ttl,
    {
      surface_index = pair.station.surface.index,
      force_index = pair.station.force.index,
      family = task.family,
      item = task.item,
      source = "item-family-logistics-0702",
    }
  )
  task.reserved_0702 = ok == true
  return ok == true, why
end

local function release_target(pair, task)
  if not (task and valid(task.target)) then return false end
  local reservations = reservations_module()
  if reservations and type(reservations.release) == "function" then
    local ok, released = pcall(
      reservations.release, "item-family-logistics", task.target, pair)
    return ok and released == true
  end
  return false
end

local function connected_automation(entity)
  if not valid(entity) then return false end
  local box
  pcall(function() box = entity.bounding_box end)
  local position = entity.position
  local padding = 3
  local area = box and {
    { box.left_top.x - padding, box.left_top.y - padding },
    { box.right_bottom.x + padding, box.right_bottom.y + padding },
  } or {
    { position.x - padding, position.y - padding },
    { position.x + padding, position.y + padding },
  }
  local entities = {}
  pcall(function()
    entities = entity.surface.find_entities_filtered({
      area = area,
      force = entity.force,
      type = { "inserter", "loader", "loader-1x1" },
      limit = 64,
    }) or {}
  end)
  for _, candidate in pairs(entities) do
    if candidate.type == "inserter" then
      local pickup, drop
      pcall(function() pickup = candidate.pickup_target end)
      pcall(function() drop = candidate.drop_target end)
      if pickup == entity or drop == entity then return true end
      local pickup_position, drop_position
      pcall(function() pickup_position = candidate.pickup_position end)
      pcall(function() drop_position = candidate.drop_position end)
      if box then
        local function inside(point)
          return point
            and point.x >= box.left_top.x - 0.25
            and point.x <= box.right_bottom.x + 0.25
            and point.y >= box.left_top.y - 0.25
            and point.y <= box.right_bottom.y + 0.25
        end
        if inside(pickup_position) or inside(drop_position) then return true end
      end
    else
      local container
      pcall(function() container = candidate.loader_container end)
      if container == entity or math.sqrt(dist_sq(candidate.position, entity.position)) <= 1.65 then
        return true
      end
    end
  end
  return false
end

local function research_ingredients(force)
  local out = {}
  local technology = force and force.current_research
  if not (technology and technology.valid) then return out, nil end
  local ingredients = {}
  pcall(function() ingredients = technology.research_unit_ingredients or {} end)
  for _, ingredient in pairs(ingredients or {}) do
    local name = ingredient.name or ingredient[1]
    local amount = tonumber(ingredient.amount or ingredient[2]) or 1
    if type(name) == "string" and name ~= "" then
      out[#out + 1] = { name = name, amount = math.max(1, amount) }
    end
  end
  return out, technology
end

local function turret_candidate(pair, entity)
  if not valid(entity) or connected_automation(entity) then return nil end
  local ids = defines and defines.inventory
  local inv = ids and inventory(entity, ids.turret_ammo) or nil
  if not inv then return nil end
  local total = 0
  for _, entry in ipairs(contents(inv)) do
    if is_ammo(entry.name) then total = total + entry.count end
  end
  if total >= M.turret_target_count then return nil end
  local source = best_ammo_source(pair, inv)
  local item = source and source.item or compatible_ammo(inv)
  if not item then return nil end
  return {
    family = "turret-ammo",
    target = entity,
    target_unit = entity.unit_number,
    target_name = entity.name,
    item = item,
    count = math.max(1, M.turret_target_count - total),
    source = source,
    priority = 800 - total * 10,
    label = entity.name,
  }
end

local function lab_candidate(pair, entity)
  if not valid(entity) or connected_automation(entity) then return nil end
  local ids = defines and defines.inventory
  local inv = ids and inventory(entity, ids.lab_input) or nil
  if not inv then return nil end
  local ingredients, technology = research_ingredients(entity.force)
  if #ingredients == 0 then return nil end
  local best
  for _, ingredient in ipairs(ingredients) do
    if inv_can_insert(inv, ingredient.name, 1) or inv_count(inv, ingredient.name) > 0 then
      local have = inv_count(inv, ingredient.name)
      local target_count = math.max(
        ingredient.amount,
        math.min(10, ingredient.amount * M.lab_cycles))
      if have < target_count then
        local source = source_for_item(pair, ingredient.name, inv)
        local missing = target_count - have
        local score = have * 100 + dist_sq(pair.priest.position, entity.position)
        if not best or score < best.score then
          best = {
            family = "lab-science",
            target = entity,
            target_unit = entity.unit_number,
            target_name = entity.name,
            item = ingredient.name,
            count = missing,
            source = source,
            priority = 400 - have * 5,
            label = entity.name,
            research = technology.name,
            score = score,
          }
        end
      end
    end
  end
  return best
end

local function routed_find(surface, filters, category, key, ttl)
  local scanner = rawget(_G, "TechPriestsScanRouting0610")
  if not scanner then
    local ok, module = pcall(require, "scripts.core.scan_routing_0610")
    if ok then scanner = module end
  end
  if scanner and type(scanner.find_entities) == "function" then
    local entities = select(1, scanner.find_entities(surface, filters, {
      category = category,
      negative_key = key,
      negative_ttl = ttl or 60 * 3,
    }))
    return entities or {}
  end
  local ok, entities = pcall(function() return surface.find_entities_filtered(filters) end)
  return ok and entities or {}
end

local function scan_candidate(pair)
  local radius = service_radius(pair)
  local position = pair.station.position
  local key = tostring(station_unit(pair) or "?")
  local entities = routed_find(
    pair.station.surface,
    {
      area = {
        { position.x - radius, position.y - radius },
        { position.x + radius, position.y + radius },
      },
      force = pair.station.force,
      type = { "ammo-turret", "lab" },
      limit = M.max_scan_entities,
    },
    "item-family-logistics",
    "item-family-logistics:" .. tostring(pair.station.surface.index)
      .. ":" .. tostring(pair.station.force.index) .. ":" .. key,
    60 * 3
  )
  local best
  for _, entity in pairs(entities) do
    local candidate = entity.type == "ammo-turret" and turret_candidate(pair, entity)
      or entity.type == "lab" and lab_candidate(pair, entity) or nil
    if candidate then
      candidate.distance = dist_sq(pair.priest.position, entity.position)
      local score = (tonumber(candidate.priority) or 0) * 100000 - candidate.distance
      if not best or score > best.score then
        candidate.score = score
        best = candidate
      end
    end
  end
  return best
end

local function candidate_valid(pair, candidate)
  if not (valid_pair(pair) and type(candidate) == "table" and valid(candidate.target)) then
    return false
  end
  if candidate.target.surface ~= pair.station.surface
    or candidate.target.force ~= pair.station.force
  then
    return false
  end
  local inv = target_inventory(candidate)
  if not inv then return false end
  if candidate.family == "turret-ammo" then
    return is_ammo(candidate.item) and inv_can_insert(inv, candidate.item, 1)
  end
  if candidate.family == "lab-science" then
    local technology = pair.station.force and pair.station.force.current_research
    return technology and technology.valid
      and technology.name == candidate.research
      and inv_can_insert(inv, candidate.item, 1)
  end
  return false
end

local function discover_pair(pair)
  if not valid_pair(pair) then return false, "invalid-pair" end
  if pair.item_family_logistics_0702 or pair.item_family_custody_0702 then
    pair.item_family_candidate_0702 = nil
    return false, "active-task"
  end
  local state = M.root()
  local key = tostring(station_unit(pair) or "?")
  local existing = pair.item_family_candidate_0702
  if candidate_valid(pair, existing) then return false, "candidate-retained" end
  pair.item_family_candidate_0702 = nil
  if (tonumber(state.discovery_due[key]) or 0) > now() then return false, "cooldown" end
  state.discovery_due[key] = now() + M.discovery_interval
  local candidate = scan_candidate(pair)
  if not candidate then
    stat("discovery_empty")
    return false, "no-candidate"
  end
  candidate.version = M.version
  candidate.discovered_tick = now()
  candidate.source_name = candidate.source and candidate.source.entity
    and candidate.source.entity.name or nil
  pair.item_family_candidate_0702 = candidate
  record(pair, "candidate-discovered", candidate.family .. " " .. candidate.item
    .. " -> " .. safe(candidate.target_name))
  return true, "candidate-discovered"
end

local function request_move(pair, target, reason)
  if not (valid_pair(pair) and valid(target)) then return false end
  local request = rawget(_G, "tech_priests_request_movement_0418")
  if type(request) ~= "function" then return false end
  local ok, accepted = pcall(
    request,
    pair,
    target.position,
    reason or "item-family-logistics-0702",
    {
      owner = "item-family-logistics-0702",
      priority = M.move_priority,
      ttl = M.move_ttl,
      radius = 1.2,
      distraction = defines and defines.distraction and defines.distraction.none or nil,
    }
  )
  return ok and accepted == true
end

local function matching_request(request, task)
  return type(request) == "table"
    and request.source == "item-family-logistics-0702"
    and request.item == task.item
    and (not request.target_unit
      or tostring(request.target_unit) == tostring(task.target_unit))
end

local function clear_requests(pair, task)
  for _, field in ipairs({ "active_supply_request", "logistic_requested_item" }) do
    if matching_request(pair[field], task) then pair[field] = nil end
  end
end

local function create_request(pair, task)
  pair.active_supply_request = {
    item = task.item,
    count = task.count,
    source = "item-family-logistics-0702",
    purpose = task.family,
    target_unit = task.target_unit,
    target_name = task.target_name,
    tick = now(),
  }
  pair.logistic_requested_item = {
    item = task.item,
    count = task.count,
    source = "item-family-logistics-0702",
    purpose = task.family,
    target_unit = task.target_unit,
  }
  task.phase = "waiting-source"
  task.request_tick = task.request_tick or now()
  stat("item_requests_created")
end

local function sync_custody(pair, task, reason)
  local carried = task and task.carried
  if carried and carried.item and (tonumber(carried.count) or 0) > 0 then
    pair.item_family_custody_0702 = {
      version = M.version,
      tick = now(),
      family = task.family,
      item = carried.item,
      count = carried.count,
      target = task.target,
      target_unit = task.target_unit,
      target_name = task.target_name,
      source_entity = task.source_entity,
      source_inv = task.source_inv,
      source_label = task.source_label,
      research = task.research,
      reason = reason or task.phase,
    }
    return true
  end
  pair.item_family_custody_0702 = nil
  return false
end

local function finish_task(pair, task, reason)
  release_target(pair, task)
  clear_requests(pair, task)
  pair.item_family_custody_0702 = nil
  task.phase = "complete"
  task.completed_tick = now()
  task.result = reason or "complete"
  pair.item_family_logistics_last_task_0702 = task
  pair.item_family_logistics_0702 = nil
  record(pair, "family-task-finished", safe(task.family) .. " " .. safe(reason))
  return { processed = 1, acted = 1, detail = reason or "complete" }
end

local function abort_without_custody(pair, task, reason)
  release_target(pair, task)
  clear_requests(pair, task)
  task.phase = "aborted"
  task.result = reason
  task.completed_tick = now()
  pair.item_family_logistics_last_task_0702 = task
  pair.item_family_logistics_0702 = nil
  record(pair, "family-task-aborted", safe(task.family) .. " " .. safe(reason))
  return { processed = 1, blocked = 1, detail = reason }
end

local function restore_orphan_custody(pair)
  local custody = pair.item_family_custody_0702
  if not (valid_pair(pair) and type(custody) == "table"
    and custody.item and (tonumber(custody.count) or 0) > 0)
    or pair.item_family_logistics_0702
  then
    return false
  end
  pair.item_family_logistics_0702 = {
    version = M.version,
    family = custody.family or "custody-recovery",
    phase = "return-custody",
    item = custody.item,
    count = custody.count,
    carried = { item = custody.item, count = custody.count },
    target = custody.target,
    target_unit = custody.target_unit,
    target_name = custody.target_name,
    source_entity = custody.source_entity,
    source_inv = custody.source_inv,
    source_label = custody.source_label,
    research = custody.research,
    started_tick = now(),
    custody_recovery = true,
  }
  record(pair, "orphan-custody-restored", custody.item .. " x" .. safe(custody.count), true)
  return true
end

local function source_current(task, pair)
  if task.source_inv and task.source_inv.valid and valid(task.source_entity)
    and inv_count(task.source_inv, task.item) > 0
  then
    return {
      inv = task.source_inv,
      entity = task.source_entity,
      item = task.item,
      count = inv_count(task.source_inv, task.item),
      label = task.source_label,
    }
  end
  return source_for_item(pair, task.item, target_inventory(task))
end

local function deposit_exact(pair, item, count, reason)
  local authority = rawget(_G, "TechPriestsStorageRoleAuthority0686")
  if authority and type(authority.deposit_exact) == "function" then
    return authority.deposit_exact(pair, item, count, reason, {})
  end
  local deposit = rawget(_G, "tech_priests_safe_deposit_item")
  if type(deposit) == "function" then
    local ok, why, inserted = deposit(pair, item, count, reason)
    return ok == true and tonumber(inserted) == count, why, tonumber(inserted) or 0
  end
  return false, "storage-unavailable", 0
end

local function return_custody(pair, task)
  local carried = task.carried
  if not (carried and carried.item and (tonumber(carried.count) or 0) > 0) then
    return finish_task(pair, task, "empty-custody")
  end
  local source = valid(task.source_entity) and task.source_entity or nil
  local destination = source or pair.station
  if dist_sq(pair.priest.position, destination.position) > M.return_reach_sq then
    task.phase = "return-custody"
    sync_custody(pair, task, "returning")
    if not request_move(pair, destination, "item-family-return-custody-0702") then
      return { processed = 1, blocked = 1, detail = "return-movement-blocked" }
    end
    return { processed = 1, waiting = 1, detail = "returning-custody" }
  end

  local inserted = 0
  if source and task.source_inv and task.source_inv.valid then
    inserted = inv_insert(task.source_inv, carried.item, carried.count)
  end
  if inserted > 0 then carried.count = carried.count - inserted end
  if carried.count <= 0 then return finish_task(pair, task, "custody-returned") end

  if source then
    task.source_entity = nil
    task.source_inv = nil
    task.source_label = "station-storage"
    sync_custody(pair, task, "source-return-partial")
    if not request_move(pair, pair.station, "item-family-return-station-0702") then
      return { processed = 1, blocked = 1, detail = "station-return-movement-blocked" }
    end
    return { processed = 1, waiting = 1, detail = "returning-to-station" }
  end

  local deposited, why, exact = deposit_exact(
    pair, carried.item, carried.count, "item-family-custody-return-0702")
  if deposited and exact == carried.count then
    carried.count = 0
    return finish_task(pair, task, "custody-returned-to-storage")
  end
  sync_custody(pair, task, "return-blocked")
  record(pair, "custody-return-blocked", carried.item
    .. " remaining=" .. safe(carried.count) .. " reason=" .. safe(why))
  return { processed = 1, blocked = 1, detail = "custody-return-blocked:" .. safe(why) }
end

local function current_research_name(pair)
  local technology = valid_pair(pair) and pair.station.force.current_research or nil
  return technology and technology.valid and technology.name or nil
end

local function normalize_task(pair, task)
  if task.family == "lab-science" then
    local current = current_research_name(pair)
    if task.research ~= current then
      if task.carried and (tonumber(task.carried.count) or 0) > 0 then
        task.phase = "return-custody"
        sync_custody(pair, task, "research-changed")
        record(pair, "stale-lab-custody-returned",
          safe(task.research) .. " -> " .. safe(current or "none"))
        return false, "research-changed"
      end
      return false, "abort:research-changed"
    end
  elseif task.family == "turret-ammo" then
    local inv = target_inventory(task)
    if not inv then
      if task.carried and (tonumber(task.carried.count) or 0) > 0 then
        task.phase = "return-custody"
        sync_custody(pair, task, "ammo-target-inventory-lost")
        return false, "ammo-target-inventory-lost"
      end
      return false, "abort:ammo-target-inventory-lost"
    end
    if not inv_can_insert(inv, task.item, 1) then
      if task.carried and (tonumber(task.carried.count) or 0) > 0 then
        task.phase = "return-custody"
        sync_custody(pair, task, "incompatible-ammunition")
        record(pair, "incompatible-carried-ammo-returned",
          safe(task.carried.item) .. " target=" .. safe(task.target_name))
        return false, "incompatible-ammunition"
      end
      local replacement = compatible_ammo(inv)
      if not replacement then return false, "abort:no-compatible-ammunition" end
      local old = task.item
      clear_requests(pair, task)
      task.item = replacement
      task.source_inv = nil
      task.source_entity = nil
      task.source_label = nil
      task.phase = "waiting-source"
      task.request_tick = now()
      create_request(pair, task)
      record(pair, "ammunition-request-corrected",
        safe(old) .. " -> " .. safe(replacement)
          .. " target=" .. safe(task.target_name))
    end
  end
  return true, "valid"
end

local function begin_task(pair, candidate, reason)
  local task = {
    version = M.version,
    family = candidate.family,
    phase = "new",
    target = candidate.target,
    target_unit = candidate.target_unit,
    target_name = candidate.target_name,
    item = candidate.item,
    count = math.max(1, math.min(M.max_transfer, tonumber(candidate.count) or 1)),
    source_inv = candidate.source and candidate.source.inv or nil,
    source_entity = candidate.source and candidate.source.entity or nil,
    source_label = candidate.source and candidate.source.label or nil,
    started_tick = now(),
    reason = reason or "candidate",
    research = candidate.research,
  }
  local claimed, why = claim_target(pair, task)
  if not claimed then
    return { processed = 1, blocked = 1, detail = "target-reserved:" .. safe(why) }
  end
  pair.item_family_candidate_0702 = nil
  pair.item_family_logistics_0702 = task
  if not candidate.source then
    create_request(pair, task)
    record(pair, "family-task-waiting-source",
      task.family .. " " .. task.item .. " -> " .. safe(task.target_name))
    return { processed = 1, waiting = 1, detail = "waiting-source" }
  end
  task.phase = "move-to-source"
  if not request_move(pair, task.source_entity, "item-family-source-0702") then
    return { processed = 1, blocked = 1, detail = "source-movement-blocked" }
  end
  record(pair, "family-task-began", task.family .. " " .. task.item
    .. " x" .. safe(task.count) .. " -> " .. safe(task.target_name))
  return { processed = 1, waiting = 1, detail = "moving-to-source" }
end

local function continue_task(pair, task)
  if not valid_pair(pair) then
    return { processed = 0, failed = 1, detail = "invalid-pair" }
  end
  if TERMINAL[lower(task.phase)] then return finish_task(pair, task, task.phase) end

  local normalized, why = normalize_task(pair, task)
  if not normalized and tostring(why):find("abort:", 1, true) == 1 then
    return abort_without_custody(pair, task, tostring(why):sub(7))
  end
  if task.carried and not valid(task.target) then
    task.phase = "return-custody"
    sync_custody(pair, task, "target-invalid")
  elseif not task.carried and not valid(task.target) then
    return abort_without_custody(pair, task, "target-invalid")
  end

  if valid(pair.combat_target) and not task.carried then
    return abort_without_custody(pair, task, "combat-priority")
  elseif valid(pair.combat_target) and task.carried then
    task.phase = "return-custody"
    sync_custody(pair, task, "combat-custody-return")
  end

  if task.phase == "waiting-source" then
    if now() - (tonumber(task.request_tick) or now()) >= M.request_timeout then
      return abort_without_custody(pair, task, "source-timeout")
    end
    local source = source_current(task, pair)
    if not source then
      create_request(pair, task)
      return { processed = 1, waiting = 1, detail = "waiting-source" }
    end
    task.source_inv = source.inv
    task.source_entity = source.entity
    task.source_label = source.label
    task.phase = "move-to-source"
    if not request_move(pair, source.entity, "item-family-source-ready-0702") then
      return { processed = 1, blocked = 1, detail = "source-movement-blocked" }
    end
    return { processed = 1, waiting = 1, detail = "source-ready" }
  end

  if task.phase == "move-to-source" then
    local source = source_current(task, pair)
    if not source then
      task.phase = "waiting-source"
      task.request_tick = now()
      create_request(pair, task)
      return { processed = 1, waiting = 1, detail = "source-lost" }
    end
    task.source_inv = source.inv
    task.source_entity = source.entity
    task.source_label = source.label
    if dist_sq(pair.priest.position, source.entity.position) > M.pickup_reach_sq then
      if not request_move(pair, source.entity, "item-family-source-0702") then
        return { processed = 1, blocked = 1, detail = "source-movement-blocked" }
      end
      return { processed = 1, waiting = 1, detail = "moving-to-source" }
    end
    local want = math.max(1, math.min(task.count, source.count, M.max_transfer))
    local removed = inv_remove(source.inv, task.item, want)
    if removed <= 0 then
      task.phase = "waiting-source"
      task.request_tick = now()
      create_request(pair, task)
      return { processed = 1, blocked = 1, detail = "source-remove-failed" }
    end
    task.carried = { item = task.item, count = removed }
    task.phase = "move-to-target"
    clear_requests(pair, task)
    sync_custody(pair, task, "picked-up")
    if not request_move(pair, task.target, "item-family-delivery-0702") then
      task.phase = "return-custody"
      sync_custody(pair, task, "target-movement-blocked")
      return { processed = 1, blocked = 1, detail = "target-movement-blocked" }
    end
    record(pair, "family-item-picked-up",
      task.item .. " x" .. safe(removed) .. " source=" .. safe(source.label))
    return { processed = 1, acted = 1, waiting = 1, detail = "picked-up" }
  end

  if task.phase == "move-to-target" then
    if not valid(task.target) then
      task.phase = "return-custody"
      return return_custody(pair, task)
    end
    if dist_sq(pair.priest.position, task.target.position) > M.target_reach_sq then
      if not request_move(pair, task.target, "item-family-delivery-0702") then
        task.phase = "return-custody"
        sync_custody(pair, task, "target-movement-blocked")
        return { processed = 1, blocked = 1, detail = "target-movement-blocked" }
      end
      sync_custody(pair, task, "moving-to-target")
      return { processed = 1, waiting = 1, detail = "moving-to-target" }
    end
    local target_inv = target_inventory(task)
    if not target_inv then
      task.phase = "return-custody"
      return return_custody(pair, task)
    end
    local carried = task.carried
    if not (carried and carried.item and (tonumber(carried.count) or 0) > 0) then
      return abort_without_custody(pair, task, "custody-missing")
    end
    local inserted = inv_insert(target_inv, carried.item, carried.count)
    if inserted > 0 then
      carried.count = carried.count - inserted
      stat("family_items_delivered", inserted)
      record(pair, "family-item-delivered", task.family .. " " .. carried.item
        .. " x" .. safe(inserted) .. " -> " .. safe(task.target_name))
    end
    if carried.count <= 0 then return finish_task(pair, task, "delivered") end
    task.phase = "return-custody"
    sync_custody(pair, task, inserted > 0 and "target-partial" or "target-blocked")
    return { processed = 1, acted = inserted > 0 and 1 or 0,
      blocked = inserted > 0 and 0 or 1,
      detail = inserted > 0 and "partial-delivery" or "target-insert-blocked" }
  end

  if task.phase == "return-custody" then return return_custody(pair, task) end
  return { processed = 1, failed = 1, detail = "unknown-phase:" .. safe(task.phase) }
end

function M.abort_pair(pair, reason)
  if not valid_pair(pair) then return false, "invalid-pair" end
  restore_orphan_custody(pair)
  local task = pair.item_family_logistics_0702
  if type(task) ~= "table" then return false, "no-task" end
  if task.carried and (tonumber(task.carried.count) or 0) > 0 then
    task.phase = "return-custody"
    sync_custody(pair, task, reason or "abort")
    local result = return_custody(pair, task)
    return result.acted > 0, result.detail
  end
  local result = abort_without_custody(pair, task, reason or "aborted")
  return false, result.detail
end

function M.service_pair(pair, reason)
  local state = M.root()
  if state.enabled == false or not valid_pair(pair) then
    return { processed = 0, failed = not valid_pair(pair) and 1 or 0,
      detail = "disabled-or-invalid" }
  end
  restore_orphan_custody(pair)
  local task = pair.item_family_logistics_0702
  if type(task) == "table" then return continue_task(pair, task) end
  local candidate = pair.item_family_candidate_0702
  if not candidate_valid(pair, candidate) then
    pair.item_family_candidate_0702 = nil
    return { processed = 1, waiting = 1, detail = "no-item-family-candidate" }
  end
  return begin_task(pair, candidate, reason or "dispatcher")
end

local function action_target(pair, task)
  if task.phase == "move-to-source" and valid(task.source_entity) then
    return task.source_entity, "collect-family-item",
      "Collecting " .. safe(task.item) .. " for " .. safe(task.target_name)
  end
  if task.phase == "move-to-target" and valid(task.target) then
    return task.target, "deliver-family-item",
      "Delivering " .. safe(task.item) .. " to " .. safe(task.target_name)
  end
  if task.phase == "return-custody" then
    local target = valid(task.source_entity) and task.source_entity or pair.station
    return target, "return-family-custody", "Returning unused " .. safe(task.item)
  end
  if task.phase == "waiting-source" and valid(task.target) then
    return task.target, "waiting-family-source",
      "Waiting for " .. safe(task.item) .. " for " .. safe(task.target_name)
  end
  return valid(task.target) and task.target or pair.station,
    task.phase or "item-family", "Item-family logistics"
end

function M.recommend_action(pair)
  if M.root().enabled == false or not valid_pair(pair) then return nil end
  local task = pair.item_family_logistics_0702
  local custody = pair.item_family_custody_0702
  if type(task) == "table" then
    local target, phase, label = action_target(pair, task)
    return {
      kind = "item-family-logistics",
      family = "item-family-logistics",
      active = true,
      target = target,
      position = valid(target) and target.position or nil,
      item = task.item,
      phase = phase,
      label = label,
      reason = task.reason or task.phase,
      source = "item_family_logistics_0702",
    }
  end
  if type(custody) == "table" and custody.item and (tonumber(custody.count) or 0) > 0 then
    local target = valid(custody.source_entity) and custody.source_entity or pair.station
    return {
      kind = "item-family-logistics",
      family = "item-family-logistics",
      active = true,
      target = target,
      position = target.position,
      item = custody.item,
      phase = "return-family-custody",
      label = "Returning item-family custody",
      reason = custody.reason or "orphan-custody",
      source = "item_family_logistics_0702",
    }
  end
  local candidate = pair.item_family_candidate_0702
  if not candidate_valid(pair, candidate) then return nil end
  return {
    kind = "item-family-logistics",
    family = "item-family-logistics",
    active = false,
    target = candidate.target,
    position = candidate.target.position,
    item = candidate.item,
    phase = "candidate",
    label = candidate.family == "lab-science" and "Laboratory supply"
      or "Turret ammunition supply",
    reason = "broker-discovered-candidate",
    source = "item_family_logistics_0702",
  }
end

local function discover_pairs(budget)
  local state = M.root()
  if state.enabled == false then
    return { processed = 0, acted = 0, detail = "disabled" }
  end
  local list = {}
  for key, pair in pairs(pair_map()) do
    if valid_pair(pair) then list[#list + 1] = { key = tostring(key), pair = pair } end
  end
  table.sort(list, function(a, b) return a.key < b.key end)
  if #list == 0 then return { processed = 0, acted = 0, detail = "no-pairs" } end
  local limit = math.max(1, math.min(#list,
    math.floor(tonumber(budget) or M.max_pairs_per_discovery)))
  local start = state.discovery_cursor % #list + 1
  local processed, discovered, failed = 0, 0, 0
  for index = 0, limit - 1 do
    local pair = list[((start + index - 1) % #list) + 1].pair
    processed = processed + 1
    local ok, changed = pcall(discover_pair, pair)
    if ok and changed == true then discovered = discovered + 1
    elseif not ok then
      failed = failed + 1
      record(pair, "discovery-error", changed, true)
    end
  end
  state.discovery_cursor = (start + limit - 2) % #list + 1
  return {
    processed = processed,
    acted = discovered,
    failed = failed,
    exhausted = #list > limit,
    detail = "discovered=" .. discovered .. " failed=" .. failed,
  }
end

local function patch_diagnostics()
  local diagnostics = rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
    or rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diagnostics and type(diagnostics.pair_dump_lines) == "function") then
    return false
  end
  if diagnostics.item_family_logistics_0702_wrapped then return true end
  diagnostics.item_family_logistics_0702_wrapped = true
  local previous = diagnostics.pair_dump_lines
  diagnostics.pair_dump_lines = function(...)
    local lines = previous(...)
    lines = type(lines) == "table" and lines or {}
    local state = M.root()
    lines[#lines + 1] = "PAIR-DUMP-0468 ITEM-FAMILY-LOGISTICS-0702"
      .. " version=" .. M.version
      .. " dispatcher_owned=" .. safe(state.dispatcher_owned)
      .. " proxy_ammo_excluded=" .. safe(state.proxy_ammo_excluded)
      .. " requests=" .. safe(state.stats.item_requests_created or 0)
      .. " picked_up=" .. safe(state.stats["family-item-picked-up"] or 0)
      .. " delivered=" .. safe(state.stats.family_items_delivered or 0)
      .. " custody_restored=" .. safe(state.stats["orphan-custody-restored"] or 0)
      .. " direct_timing=0 leaf_authority=0 loose_movement_success=0"
    for _, pair in pairs(pair_map()) do
      if valid_pair(pair) then
        local task = pair.item_family_logistics_0702 or {}
        local custody = pair.item_family_custody_0702 or {}
        local candidate = pair.item_family_candidate_0702 or {}
        lines[#lines + 1] = "PAIR-DUMP-0468 item-family["
          .. safe(station_unit(pair)) .. "] family=" .. safe(task.family or candidate.family or "none")
          .. " phase=" .. safe(task.phase or "none")
          .. " item=" .. safe(task.item or custody.item or candidate.item or "none")
          .. " target=" .. safe(task.target_name or custody.target_name
            or candidate.target_name or "none")
          .. " custody=" .. safe(custody.count or 0)
      end
    end
    return lines
  end
  return true
end

function M.install()
  M.root()
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if not (broker and type(broker.register_service) == "function") then return false end
  local service = broker.register_service({
    name = "item_family_discovery_0702",
    category = "discovery",
    interval = M.discovery_interval,
    priority = 58,
    budget = M.max_pairs_per_discovery,
    note = "discovery only for visible turret ammunition and laboratory science logistics",
    fn = function(_, budget) return discover_pairs(budget) end,
  })
  if not service then return false end
  patch_diagnostics()
  _G.TechPriestsItemFamilyLogistics0702 = M
  if commands and commands.remove_command then
    pcall(commands.remove_command, "tp-proxy-ammo-0649")
  end
  if log then
    log("[Tech-Priests recovery] dispatcher-owned visible item-family logistics installed; proxy ammunition remains with 0649")
  end
  return true
end

return M
