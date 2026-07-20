-- scripts/core/construction_planner.lua
-- Tech Priests 0.1.674-dev recovery.
-- Sole physical construction owner. Broker work is discovery only; the pure action
-- classifier recommends cached work and single_dispatcher_0510 alone executes it.

local M = {
  version = "0.1.674-dev",
  storage_key = "construction_planner",
  discovery_interval = 233,
  max_pairs_per_discovery = 6,
  move_priority = 968,
  move_ttl = 60 * 12,
  reservation_ttl = 60 * 20,
  request_timeout = 60 * 20,
  pickup_reach_sq = 2.56,
  build_reach_sq = 4,
  return_reach_sq = 2.56,
  dispatcher_owned = true,
  discovery_only_broker = true,
  positional_reservation = true,
  exact_item_custody = true,
}

local function now() return game and game.tick or 0 end
local function valid(entity) return entity and entity.valid end
local function safe(value)
  if value == nil then return "nil" end
  local ok, text = pcall(tostring, value)
  return ok and text or "?"
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
local function dist_sq(a, b)
  if not (a and b) then return math.huge end
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
    positional_reservation = true,
    exact_item_custody = true,
    stats = {},
    recent = {},
    cursor = 0,
  }
  storage.tech_priests[M.storage_key] = state
  state.version = M.version
  if state.enabled == nil then state.enabled = true end
  state.dispatcher_owned = true
  state.discovery_only_broker = true
  state.positional_reservation = true
  state.exact_item_custody = true
  state.stats = state.stats or {}
  state.recent = state.recent or {}
  state.cursor = tonumber(state.cursor) or 0
  return state
end
local function stat(name, amount)
  local state = M.root()
  state.stats[name] = (tonumber(state.stats[name]) or 0) + (tonumber(amount) or 1)
end
local function record(pair, action, detail)
  local state = M.root()
  local event = {
    tick = now(),
    station = safe(station_unit(pair)),
    action = tostring(action or "event"),
    detail = tostring(detail or ""),
  }
  state.recent[#state.recent + 1] = event
  while #state.recent > 160 do table.remove(state.recent, 1) end
  if pair then pair.construction_last_event_0338 = event end
end

local function site_planner()
  return rawget(_G, "TECH_PRIESTS_CONSTRUCTION_SITE_PLANNER_0359")
    or package.loaded["scripts.core.construction_site_planner"]
end
local function storage_authority()
  return rawget(_G, "TechPriestsStorageRoleAuthority0686")
    or package.loaded["scripts.core.storage_role_authority_0686"]
end
local function reservations_module()
  local module = rawget(_G, "TechPriestsWorkReservations0601")
    or package.loaded["scripts.core.work_reservations"]
  if not module then
    local ok, loaded = pcall(require, "scripts.core.work_reservations")
    if ok then module = loaded end
  end
  return module
end
local function ensure_reservation_category()
  local reservations = reservations_module()
  if not reservations then return nil end
  local category = "construction-placement"
  local found = false
  for _, value in ipairs(reservations.categories or {}) do
    if value == category then found = true break end
  end
  if not found then
    reservations.categories = reservations.categories or {}
    reservations.categories[#reservations.categories + 1] = category
  end
  local state = type(reservations.root) == "function" and reservations.root() or nil
  if state then
    state.reservations = state.reservations or {}
    state.reservations[category] = state.reservations[category] or {}
  end
  return reservations
end
local function position_target(pair, position)
  return {
    position = { x = position.x, y = position.y },
    surface_index = pair.station.surface.index,
    force_index = pair.station.force.index,
  }
end
local function claim_site(pair, task)
  local reservations = ensure_reservation_category()
  if not (reservations and type(reservations.claim) == "function" and task.position) then
    return false, "reservation-unavailable"
  end
  task.reservation_target = position_target(pair, task.position)
  local ok, reason = reservations.claim(
    "construction-placement",
    task.reservation_target,
    pair,
    M.reservation_ttl,
    {
      surface_index = pair.station.surface.index,
      force_index = pair.station.force.index,
      family = "construction",
      entity_name = task.entity_name,
      item = task.item_name,
      source = "construction-planner-0338",
    }
  )
  task.reserved_0338 = ok == true
  return ok == true, reason
end
local function release_site(pair, task)
  if not (task and task.reservation_target) then return false end
  local reservations = reservations_module()
  if reservations and type(reservations.release) == "function" then
    local ok, released = pcall(
      reservations.release,
      "construction-placement",
      task.reservation_target,
      pair
    )
    return ok and released == true
  end
  return false
end
local function request_move(pair, target, reason)
  if not (valid_pair(pair) and valid(target)) then return false end
  local request = rawget(_G, "tech_priests_request_movement_0418")
  if type(request) ~= "function" then return false end
  local ok, accepted = pcall(request, pair, target.position, reason, {
    owner = "construction-planner-0338",
    priority = M.move_priority,
    ttl = M.move_ttl,
    radius = 1.5,
    distraction = defines and defines.distraction and defines.distraction.none or nil,
  })
  return ok and accepted == true
end
local function request_move_position(pair, position, reason)
  if not (valid_pair(pair) and position) then return false end
  local request = rawget(_G, "tech_priests_request_movement_0418")
  if type(request) ~= "function" then return false end
  local ok, accepted = pcall(request, pair, position, reason, {
    owner = "construction-planner-0338",
    priority = M.move_priority,
    ttl = M.move_ttl,
    radius = 1.75,
    distraction = defines and defines.distraction and defines.distraction.none or nil,
  })
  return ok and accepted == true
end
local function item_count(inventory, item_name)
  if not (inventory and inventory.valid and item_name) then return 0 end
  local ok, count = pcall(inventory.get_item_count, inventory, item_name)
  return ok and (tonumber(count) or 0) or 0
end
local function remove_item(inventory, item_name, count)
  if not (inventory and inventory.valid and item_name and (tonumber(count) or 0) > 0) then return 0 end
  local ok, removed = pcall(inventory.remove, inventory, { name = item_name, count = count })
  return ok and (tonumber(removed) or 0) or 0
end
local function insert_item(inventory, item_name, count)
  if not (inventory and inventory.valid and item_name and (tonumber(count) or 0) > 0) then return 0 end
  local ok, inserted = pcall(inventory.insert, inventory, { name = item_name, count = count })
  return ok and (tonumber(inserted) or 0) or 0
end
local function generic_source_allowed(pair, source)
  local entity = source and source.entity
  local inventory = source and source.inv
  if not (inventory and inventory.valid and valid(entity)) then return false end
  if entity.surface ~= pair.station.surface or entity.force ~= pair.station.force then return false end
  if entity == pair.station then return true end
  return entity.type == "container" or entity.type == "logistic-container"
    or entity.type == "car" or entity.type == "spider-vehicle"
end
local function home_sources(pair)
  local out, seen = {}, {}
  local function add(source)
    if not generic_source_allowed(pair, source) then return end
    local key = safe(source.inv)
    if seen[key] then return end
    seen[key] = true
    out[#out + 1] = {
      inv = source.inv,
      entity = source.entity,
      label = source.source or source.inventory_id or "generic-home-source",
    }
  end
  local authority = storage_authority()
  if authority and type(authority.generic_station_inventories) == "function" then
    local ok, sources = pcall(authority.generic_station_inventories, pair)
    if ok and type(sources) == "table" then
      for _, source in ipairs(sources) do add(source) end
    end
  end
  local steward = rawget(_G, "tech_priests_inventory_steward_sources_for_pair")
  if type(steward) == "function" then
    local ok, sources = pcall(steward, pair)
    if ok and type(sources) == "table" then
      for _, source in ipairs(sources) do add(source) end
    end
  end
  return out
end
local function source_for_item(pair, item_name)
  local best
  for _, source in ipairs(home_sources(pair)) do
    local count = item_count(source.inv, item_name)
    if count > 0 then
      local score = dist_sq(pair.priest.position, source.entity.position) - math.min(count, 100)
      if not best or score < best.score then
        best = {
          item_name = item_name,
          count = count,
          inv = source.inv,
          entity = source.entity,
          label = source.label,
          score = score,
        }
      end
    end
  end
  return best
end
local function entity_exists(name)
  return type(name) == "string" and name ~= ""
    and prototypes and prototypes.entity and prototypes.entity[name] ~= nil
end
local function item_exists(name)
  return type(name) == "string" and name ~= ""
    and prototypes and prototypes.item and prototypes.item[name] ~= nil
end
local function place_result(item_name)
  local item = item_exists(item_name) and prototypes.item[item_name] or nil
  local result
  if item then pcall(function() result = item.place_result end) end
  return result and result.name or nil
end
local function item_for_entity(entity_name)
  if not entity_exists(entity_name) then return nil end
  local policy = rawget(_G, "TechPriestsPlanningConstraints0646")
    or package.loaded["scripts.core.planning_constraints_0646"]
  if policy and type(policy.item_for_entity) == "function" then
    local ok, item_name = pcall(policy.item_for_entity, entity_name)
    if ok and item_name then return item_name end
  end
  for item_name, item in pairs(prototypes and prototypes.item or {}) do
    local result
    pcall(function() result = item.place_result end)
    if result and result.name == entity_name then return item_name end
  end
  return nil
end
local function entity_type(entity_name)
  local entity = entity_exists(entity_name) and prototypes.entity[entity_name] or nil
  local result
  if entity then pcall(function() result = entity.type end) end
  return result
end
local function category_for(entity_name, requested)
  local typ = entity_type(entity_name)
  if requested and requested ~= "" and requested ~= "generic" then return requested end
  if typ == "mining-drill" then return "miner" end
  if typ == "furnace" then return "furnace" end
  if typ == "assembling-machine" then return "assembler" end
  if typ == "container" or typ == "logistic-container" then return "storage" end
  if typ == "lab" then return "lab" end
  if typ == "electric-pole" then return "emergency-power-pole" end
  if typ == "roboport" then return "defense-roboport" end
  if typ == "wall" or typ == "gate" then return "defense-wall" end
  if typ == "artillery-turret" then return "defense-artillery" end
  if typ == "ammo-turret" or typ == "electric-turret" or typ == "fluid-turret" then
    return "defense-turret"
  end
  if typ == "radar" then return "defense-radar" end
  if typ == "land-mine" then return "defense-mine" end
  return "generic"
end
local function normalize_placeable(value)
  if type(value) == "string" then
    if item_exists(value) then
      local entity_name = place_result(value)
      return entity_name and {
        item_name = value,
        entity_name = entity_name,
        category = category_for(entity_name),
      } or nil
    end
    if entity_exists(value) then
      local item_name = item_for_entity(value)
      return item_name and {
        item_name = item_name,
        entity_name = value,
        category = category_for(value),
      } or nil
    end
    return nil
  end
  if type(value) ~= "table" then return nil end
  local item_name = value.item_name or value.item or value.name
  local entity_name = value.entity_name or value.entity or value.place_result
  if entity_name and type(entity_name) == "table" then entity_name = entity_name.name end
  if not entity_name and item_name then entity_name = place_result(item_name) end
  if not item_name and entity_name then item_name = item_for_entity(entity_name) end
  if not (item_exists(item_name) and entity_exists(entity_name)) then return nil end
  return {
    item_name = item_name,
    entity_name = entity_name,
    category = category_for(entity_name, value.category or value.class),
    source = value.source,
    direction = value.direction,
  }
end
local request_fields = {
  "structure_construction_requested_item",
  "construction_requested_item",
  "construction_request",
  "pending_construction",
  "build_request",
}
local function bootstrap_request(pair)
  local record = pair and pair.construction_bootstrap_ghost_0645
  if type(record) ~= "table" then return nil end
  local ghost = valid(record.ghost) and record.ghost or nil
  if not ghost and record.position and valid_pair(pair) then
    local ok, found = pcall(pair.station.surface.find_entity, pair.station.surface, "entity-ghost", record.position)
    if ok and valid(found) then ghost = found end
  end
  local placeable = normalize_placeable({
    item_name = record.item,
    entity_name = record.entity_name,
    category = record.category or record.class,
    source = "construction-bootstrap-ghost-0645",
  })
  if not placeable or not record.position then return nil end
  return {
    field = "construction_bootstrap_ghost_0645",
    value = record,
    placeable = placeable,
    position = { x = record.position.x, y = record.position.y },
    ghost = ghost,
    site_reason = "bootstrap-ghost",
    effectiveness = record.effectiveness,
  }
end
local function construction_request(pair)
  local bootstrap = bootstrap_request(pair)
  if bootstrap then return bootstrap end
  for _, field in ipairs(request_fields) do
    local value = pair[field]
    if value ~= nil then
      local placeable = normalize_placeable(value)
      if placeable then return { field = field, value = value, placeable = placeable } end
    end
  end
  local legacy = pair.construction_task
  if type(legacy) == "table" and legacy.item_name and legacy.entity_name then
    local placeable = normalize_placeable(legacy)
    if placeable then
      return {
        field = "construction_task",
        value = legacy,
        placeable = placeable,
        position = legacy.site_position,
        site_reason = legacy.site_reason or "legacy-task-recovery",
      }
    end
  end
  return nil
end
local function clear_request(pair, task)
  local field = task and task.request_field
  if not field then return end
  if field == "construction_bootstrap_ghost_0645" then
    if type(pair[field]) == "table" then
      pair[field].status = "built"
      pair[field].completed_tick = now()
    end
    pair[field] = nil
  elseif pair[field] == task.request_value then
    pair[field] = nil
  end
  if field == "construction_task" then pair.construction_task = nil end
end
local function plan_request(pair, request)
  if request.position then
    local planner = site_planner()
    local effectiveness
    if planner and type(planner.placement_effectiveness_report) == "function" then
      local ok, report = pcall(
        planner.placement_effectiveness_report,
        pair,
        request.placeable.entity_name,
        request.position,
        request.placeable.category
      )
      if ok then effectiveness = report end
    end
    return request.position, request.site_reason or "fixed-request-site", effectiveness
  end
  local planner = site_planner()
  if not (planner and type(planner.plan_site) == "function") then
    return nil, "site-planner-unavailable"
  end
  local ok, position, reason, report = pcall(planner.plan_site, pair, request.placeable)
  if not ok then return nil, "site-planner-error:" .. safe(position) end
  return position, reason, report
end
function M.discover_pair(pair, force)
  local state = M.root()
  if state.enabled == false or not valid_pair(pair) then return nil end
  if pair.construction_task_0338 or pair.construction_custody_0338 then
    return pair.construction_candidate_0338
  end
  if not force and now() < (tonumber(pair.construction_cooldown_0338) or 0) then
    return pair.construction_candidate_0338
  end
  local request = construction_request(pair)
  if not request then
    pair.construction_candidate_0338 = nil
    return nil
  end
  local position, reason, effectiveness = plan_request(pair, request)
  if not position then
    pair.construction_candidate_0338 = nil
    pair.construction_blocked_reason_0338 = reason
    pair.construction_cooldown_0338 = now() + 180
    record(pair, "site-blocked", reason)
    return nil
  end
  local candidate = {
    version = M.version,
    tick = now(),
    item_name = request.placeable.item_name,
    entity_name = request.placeable.entity_name,
    category = request.placeable.category,
    position = { x = position.x, y = position.y },
    site_reason = reason,
    effectiveness = effectiveness,
    request_field = request.field,
    request_value = request.value,
    ghost = request.ghost,
    source = "construction-planner-0338",
  }
  pair.construction_candidate_0338 = candidate
  pair.construction_blocked_reason_0338 = nil
  stat("candidates-discovered")
  return candidate
end
function M.recommend_action(pair)
  if not pair then return nil end
  local task = pair.construction_task_0338
  local custody = pair.construction_custody_0338
  local candidate = pair.construction_candidate_0338
  local value = task or custody or candidate
  if not value then return nil end
  return {
    kind = "construction",
    family = "construction",
    target = valid(value.ghost) and value.ghost or nil,
    position = value.position,
    item = value.item_name or value.item,
    phase = value.phase or (task and task.phase) or "candidate",
    source = "construction-planner-0338",
    reason = value.site_reason or value.reason or "construction-request",
    active = task ~= nil or custody ~= nil,
  }
end
local function sync_custody(pair, task, reason)
  local carried = task and task.carried
  if carried and carried.item_name and (tonumber(carried.count) or 0) > 0 then
    pair.construction_custody_0338 = {
      version = M.version,
      tick = now(),
      phase = "removed-not-built",
      item_name = carried.item_name,
      count = carried.count,
      entity_name = task.entity_name,
      category = task.category,
      position = task.position,
      source_entity = task.source_entity,
      source_inv = task.source_inv,
      source_label = task.source_label,
      request_field = task.request_field,
      request_value = task.request_value,
      reason = reason or task.phase,
    }
    return true
  end
  pair.construction_custody_0338 = nil
  return false
end
local function finish(pair, task, built, reason)
  release_site(pair, task)
  if built then clear_request(pair, task) end
  pair.construction_candidate_0338 = nil
  pair.construction_custody_0338 = nil
  pair.construction_task_0338 = nil
  pair.construction_task = nil
  pair.construction_cooldown_0338 = now() + (built and 90 or 180)
  task.phase = built and "complete" or "aborted"
  task.completed_tick = now()
  task.result = reason
  task.built_entity = built
  pair.construction_last_task_0338 = task
  record(pair, built and "built" or "aborted", reason)
  return {
    processed = 1,
    acted = built and 1 or 0,
    blocked = built and 0 or 1,
    detail = reason,
  }
end
local function deposit_exact(pair, item_name, count, reason)
  local authority = storage_authority()
  if authority and type(authority.deposit_exact) == "function" then
    return authority.deposit_exact(pair, item_name, count, reason, {})
  end
  return false, "storage-authority-unavailable", 0
end
local function return_custody(pair, task)
  local carried = task.carried
  if not (carried and carried.item_name and (tonumber(carried.count) or 0) > 0) then
    return finish(pair, task, false, "empty-custody")
  end
  local source = valid(task.source_entity) and task.source_entity or pair.station
  if dist_sq(pair.priest.position, source.position) > M.return_reach_sq then
    task.phase = "return-custody"
    sync_custody(pair, task, "returning-custody")
    if not request_move(pair, source, "construction-custody-return-0338") then
      return { processed = 1, blocked = 1, detail = "return-movement-blocked" }
    end
    return { processed = 1, waiting = 1, detail = "returning-custody" }
  end
  if valid(task.source_entity) and task.source_inv and task.source_inv.valid then
    local inserted = insert_item(task.source_inv, carried.item_name, carried.count)
    carried.count = carried.count - inserted
    if carried.count <= 0 then return finish(pair, task, false, "custody-returned-source") end
    task.source_entity = nil
    task.source_inv = nil
    sync_custody(pair, task, "source-return-partial")
  end
  local accepted, why, inserted = deposit_exact(
    pair,
    carried.item_name,
    carried.count,
    "construction-custody-return-0338"
  )
  inserted = tonumber(inserted) or 0
  carried.count = carried.count - inserted
  if accepted == true and carried.count <= 0 then
    return finish(pair, task, false, "custody-stored")
  end
  sync_custody(pair, task, "storage-blocked")
  return { processed = 1, blocked = 1, detail = "storage-blocked:" .. safe(why) }
end
local function begin_task(pair, candidate)
  local task = {
    version = M.version,
    phase = "waiting-source",
    item_name = candidate.item_name,
    entity_name = candidate.entity_name,
    category = candidate.category,
    position = { x = candidate.position.x, y = candidate.position.y },
    site_reason = candidate.site_reason,
    effectiveness = candidate.effectiveness,
    request_field = candidate.request_field,
    request_value = candidate.request_value,
    ghost = candidate.ghost,
    started_tick = now(),
  }
  local ok, reason = claim_site(pair, task)
  if not ok then return nil, reason end
  pair.construction_task_0338 = task
  return task
end
local function restore_orphan_custody(pair)
  if pair.construction_task_0338 or type(pair.construction_custody_0338) ~= "table" then return false end
  local custody = pair.construction_custody_0338
  if not (custody.item_name and (tonumber(custody.count) or 0) > 0) then return false end
  pair.construction_task_0338 = {
    version = M.version,
    phase = "return-custody",
    item_name = custody.item_name,
    entity_name = custody.entity_name,
    category = custody.category,
    position = custody.position,
    carried = { item_name = custody.item_name, count = custody.count },
    source_entity = custody.source_entity,
    source_inv = custody.source_inv,
    source_label = custody.source_label,
    request_field = custody.request_field,
    request_value = custody.request_value,
    started_tick = now(),
    custody_recovery = true,
  }
  record(pair, "orphan-custody-restored", custody.item_name)
  return true
end
local function site_still_valid(pair, task)
  if valid(task.ghost) then return true, "matching-ghost" end
  local planner = site_planner()
  if planner and type(planner.plan_site) == "function" then
    local ok, position = pcall(planner.plan_site, pair, {
      item_name = task.item_name,
      entity_name = task.entity_name,
      category = task.category,
      source = "construction-revalidation-0338",
    })
    if ok and position
      and math.abs(position.x - task.position.x) < 0.1
      and math.abs(position.y - task.position.y) < 0.1
    then
      return true, "site-revalidated"
    end
  end
  local ok, can_place = pcall(pair.station.surface.can_place_entity, pair.station.surface, {
    name = task.entity_name,
    position = task.position,
    force = pair.station.force,
  })
  return ok and can_place == true, ok and "engine-revalidated" or "engine-check-failed"
end
local function create_entity(pair, task)
  if valid(task.ghost) then
    local ok, revived = pcall(task.ghost.revive, task.ghost, { raise_revive = true })
    if ok and valid(revived) then return revived, "ghost-revived" end
  end
  local ok, entity = pcall(pair.station.surface.create_entity, pair.station.surface, {
    name = task.entity_name,
    position = task.position,
    force = pair.station.force,
    direction = task.direction,
    raise_built = true,
  })
  if ok and valid(entity) then return entity, "entity-created" end
  return nil, ok and "create-refused" or "create-error:" .. safe(entity)
end
function M.abort_pair(pair, reason)
  local task = pair and pair.construction_task_0338
  if not task then return { processed = 0, detail = "no-task" } end
  if sync_custody(pair, task, reason) then
    task.phase = "return-custody"
    return return_custody(pair, task)
  end
  return finish(pair, task, false, reason or "aborted")
end
function M.service_pair(pair, reason)
  local state = M.root()
  if state.enabled == false or not valid_pair(pair) then
    return { processed = 0, failed = not valid_pair(pair) and 1 or 0, detail = "disabled-or-invalid" }
  end
  restore_orphan_custody(pair)
  local task = pair.construction_task_0338
  if not task then
    local candidate = pair.construction_candidate_0338 or M.discover_pair(pair, true)
    if not candidate then return { processed = 1, waiting = 1, detail = "no-candidate" } end
    local why
    task, why = begin_task(pair, candidate)
    if not task then return { processed = 1, blocked = 1, detail = "reservation-blocked:" .. safe(why) } end
  end
  if task.phase == "return-custody" then return return_custody(pair, task) end
  if now() - (tonumber(task.started_tick) or now()) > M.request_timeout then
    return M.abort_pair(pair, "construction-timeout")
  end
  if task.phase == "waiting-source" then
    local source = source_for_item(pair, task.item_name)
    if not source then return { processed = 1, waiting = 1, detail = "waiting-source" } end
    task.source_entity = source.entity
    task.source_inv = source.inv
    task.source_label = source.label
    task.phase = "move-source"
  end
  if task.phase == "move-source" then
    if not valid(task.source_entity) then return M.abort_pair(pair, "source-invalid") end
    if dist_sq(pair.priest.position, task.source_entity.position) > M.pickup_reach_sq then
      if not request_move(pair, task.source_entity, "construction-source-0338") then
        return { processed = 1, blocked = 1, detail = "source-movement-blocked" }
      end
      return { processed = 1, waiting = 1, detail = "moving-source" }
    end
    task.phase = "pickup"
  end
  if task.phase == "pickup" then
    local removed = remove_item(task.source_inv, task.item_name, 1)
    if removed ~= 1 then return M.abort_pair(pair, "source-remove-failed") end
    task.carried = { item_name = task.item_name, count = 1 }
    sync_custody(pair, task, "removed-source")
    task.phase = "move-site"
  end
  if task.phase == "move-site" then
    if dist_sq(pair.priest.position, task.position) > M.build_reach_sq then
      if not request_move_position(pair, task.position, "construction-site-0338") then
        task.phase = "return-custody"
        return return_custody(pair, task)
      end
      return { processed = 1, waiting = 1, detail = "moving-site" }
    end
    task.phase = "build"
  end
  if task.phase == "build" then
    local valid_site, why = site_still_valid(pair, task)
    if not valid_site then
      task.phase = "return-custody"
      sync_custody(pair, task, "site-invalid:" .. safe(why))
      return return_custody(pair, task)
    end
    local built, build_reason = create_entity(pair, task)
    if not built then
      task.phase = "return-custody"
      sync_custody(pair, task, build_reason)
      return return_custody(pair, task)
    end
    task.carried.count = 0
    pair.construction_custody_0338 = nil
    stat("entities-built")
    return finish(pair, task, built, build_reason)
  end
  return { processed = 1, failed = 1, detail = "unknown-phase:" .. safe(task.phase) }
end
function M.service_all(reason, budget)
  local list = {}
  for key, pair in pairs(pair_map()) do
    if valid_pair(pair) then list[#list + 1] = { key = tostring(key), pair = pair } end
  end
  table.sort(list, function(a, b) return a.key < b.key end)
  local state = M.root()
  local limit = math.min(#list, math.max(0, math.floor(tonumber(budget) or M.max_pairs_per_discovery)))
  if limit == 0 then return { processed = 0, acted = 0, detail = "no-pairs" } end
  local start = state.cursor % #list + 1
  local failed = 0
  for offset = 0, limit - 1 do
    local pair = list[((start + offset - 1) % #list) + 1].pair
    local ok = pcall(M.discover_pair, pair, false)
    if not ok then failed = failed + 1 end
  end
  state.cursor = (start + limit - 2) % #list + 1
  return {
    processed = limit,
    acted = 0,
    failed = failed,
    exhausted = #list > limit,
    detail = "pairs=" .. limit .. " failed=" .. failed,
  }
end
function M.describe_pair(pair)
  if not pair then return "No pair." end
  local task = pair.construction_task_0338
  if task then
    return "Construction " .. safe(task.entity_name) .. " phase=" .. safe(task.phase)
      .. " site=" .. safe(task.position and (task.position.x .. "," .. task.position.y))
  end
  local candidate = pair.construction_candidate_0338
  if candidate then
    return "Construction candidate " .. safe(candidate.entity_name)
      .. " reason=" .. safe(candidate.site_reason)
  end
  return "No construction work."
end
local function register_service()
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if not (broker and type(broker.register_service) == "function") then return false end
  local service = broker.register_service({
    name = "construction_discovery_0338",
    category = "construction",
    interval = M.discovery_interval,
    priority = 58,
    budget = M.max_pairs_per_discovery,
    note = "discovery only; dispatcher owns physical construction",
    fn = function(_, budget) return M.service_all("broker-discovery", budget) end,
  })
  return service ~= nil
end
function M.install()
  M.root()
  ensure_reservation_category()
  _G.TECH_PRIESTS_CONSTRUCTION_PLANNER_0338 = M
  _G.TechPriestsConstructionPlanner0338 = M
  if not register_service() then return false end
  if log then
    log("[Tech-Priests recovery] dispatcher-owned construction armed; placement effectiveness remains in construction_site_planner")
  end
  return true
end

return M
