-- Tech Priests 0.1.260
-- Cogitator Station defensive perimeter planning.
--
-- Stations may build priest-managed wall rings at the edge of station coverage.
-- If station coverage changes, obsolete priest-managed walls are recovered and
-- new walls are planned at the new edge.  If one of those tracked walls is lost,
-- the local priest attempts to place a defensive turret near the breach and then
-- manually service turret ammunition from the station inventory/logistics bridge.

TECH_PRIESTS_DEFENSE_PERIMETER_VERSION_0259 = "0.1.260"
TECH_PRIESTS_DEFENSE_WALL_ITEM_0259 = "stone-wall"
TECH_PRIESTS_DEFENSE_WALL_ENTITY_0259 = "stone-wall"
TECH_PRIESTS_DEFENSE_SCAN_INTERVAL_0259 = 180
TECH_PRIESTS_DEFENSE_REPATH_TICKS_0259 = 90
TECH_PRIESTS_DEFENSE_BUILD_REACH_SQ_0259 = 3.0 * 3.0
TECH_PRIESTS_DEFENSE_BUILD_TICKS_0259 = 60
TECH_PRIESTS_DEFENSE_WALL_SPACING_0259 = 3.0
TECH_PRIESTS_DEFENSE_WALL_RING_TOLERANCE_0259 = 1.75
TECH_PRIESTS_DEFENSE_MAX_WALLS_PER_STATION_0259 = 96
TECH_PRIESTS_DEFENSE_MAX_BREACH_QUEUE_0259 = 12
TECH_PRIESTS_DEFENSE_TURRET_SEARCH_RADIUS_0259 = 6
TECH_PRIESTS_DEFENSE_AMMO_BATCH_0259 = 20
TECH_PRIESTS_DEFENSE_SUPPORT_SEARCH_RADIUS_0260 = 8
TECH_PRIESTS_DEFENSE_PIPE_SUPPORT_ITEM_0260 = "pipe"
TECH_PRIESTS_DEFENSE_POWER_SUPPORT_ITEMS_0260 = { "small-electric-pole", "medium-electric-pole", "big-electric-pole", "substation" }

function tech_priests_0259_diag(message)
  if tech_priests_0246_diag_line then
    tech_priests_0246_diag_line("0.1.259 " .. tostring(message))
  elseif log then
    log("[Tech Priests 0.1.259] " .. tostring(message))
  end
end

local function tech_priests_0259_valid_pair(pair)
  if tech_priests_0248_valid_pair then return tech_priests_0248_valid_pair(pair) end
  return pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid
end

local function tech_priests_0259_distance_sq(a, b)
  if tech_priests_distance_sq_0186 then return tech_priests_distance_sq_0186(a, b) end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end

local function tech_priests_0259_radius(pair)
  local ok, radius = pcall(function()
    if refresh_pair_radius then return refresh_pair_radius(pair) end
    return pair.radius or pair.base_radius or 20
  end)
  if ok and radius then return radius end
  return 20
end

local function tech_priests_0259_station_inventory(pair)
  if get_station_inventory and pair and pair.station and pair.station.valid then return get_station_inventory(pair.station) end
  if pair and pair.station and pair.station.valid then return pair.station.get_inventory(defines.inventory.chest) end
  return nil
end

local function tech_priests_0259_item_count(pair, item_name)
  local inv = tech_priests_0259_station_inventory(pair)
  if inv and inv.valid and item_name then return inv.get_item_count(item_name) end
  return 0
end

local function tech_priests_0259_force_has_item(pair, item_name)
  if tech_priests_0259_item_count(pair, item_name) > 0 then return true end
  if not (pair and pair.station and pair.station.valid and item_name) then return false end
  if transfer_cache_inventory_to_station then pcall(function() transfer_cache_inventory_to_station(pair) end) end
  if tech_priests_0259_item_count(pair, item_name) > 0 then return true end
  local network = get_station_logistic_network and get_station_logistic_network(pair.station) or nil
  if network and logistic_network_item_count then
    local ok, count = pcall(function() return logistic_network_item_count(network, { name = item_name, count = 1 }) end)
    if ok and count and count > 0 then return true end
  end
  return false
end

local function tech_priests_0259_request_item(pair, item_name, count, kind)
  if not (pair and item_name and issue_station_logistic_request) then return false end
  local request = {
    kind = kind or "defense",
    candidates = {
      { name = item_name, count = count or 1, score = 100 }
    }
  }
  local ok, result = pcall(function() return issue_station_logistic_request(pair, request) end)
  return ok and result or false
end

local function tech_priests_0259_take_item(pair, item_name, count)
  local inv = tech_priests_0259_station_inventory(pair)
  if not (inv and inv.valid and item_name) then return 0 end
  return inv.remove({ name = item_name, count = count or 1 }) or 0
end

local function tech_priests_0259_return_item(pair, item_name, count)
  local inv = tech_priests_0259_station_inventory(pair)
  if inv and inv.valid and item_name and count and count > 0 then return inv.insert({ name = item_name, count = count }) or 0 end
  return 0
end

local function tech_priests_0259_entity_from_item(item_name)
  if tech_priests_get_entity_prototype_name_from_item_0184 then
    local ok, entity_name = pcall(function() return tech_priests_get_entity_prototype_name_from_item_0184(item_name) end)
    if ok and entity_name then return entity_name end
  end
  local item_proto = tech_priests_get_item_prototype_0440 and tech_priests_get_item_prototype_0440(item_name) or nil
  if item_proto then
    local ok, place = pcall(function() return item_proto.place_result end)
    if ok and place and place.name then return place.name end
  end
  return nil
end

local function tech_priests_0259_item_from_entity(entity_name)
  if not entity_name then return nil end
  for name, proto in pairs((tech_priests_prototype_table_0440 and tech_priests_prototype_table_0440("item")) or {}) do
    local ok, place = pcall(function() return proto.place_result end)
    if ok and place and place.name == entity_name then return name end
  end
  return nil
end

local function tech_priests_0259_entity_type(entity_name)
  local entity_proto = tech_priests_get_entity_prototype_0440 and tech_priests_get_entity_prototype_0440(entity_name) or nil
  if not entity_proto then return nil end
  local ok, typ = pcall(function() return entity_proto.type end)
  if ok then return typ end
  return nil
end

local function tech_priests_0259_is_defensive_entity(entity_name)
  local typ = tech_priests_0259_entity_type(entity_name)
  return typ == "ammo-turret" or typ == "electric-turret" or typ == "fluid-turret" or typ == "turret" or typ == "artillery-turret"
end

local function tech_priests_0259_turret_candidates()
  if storage and storage.tech_priests and storage.tech_priests.defense_turret_candidates_0259 then
    return storage.tech_priests.defense_turret_candidates_0259
  end
  if ensure_storage then pcall(ensure_storage) end
  storage.tech_priests = storage.tech_priests or {}
  local preferred = { "gun-turret", "laser-turret", "flamethrower-turret", "artillery-turret" }
  local result, seen = {}, {}
  for _, item_name in pairs(preferred) do
    local entity_name = tech_priests_0259_entity_from_item(item_name)
    if entity_name and tech_priests_0259_is_defensive_entity(entity_name) then
      result[#result + 1] = { item = item_name, entity = entity_name }
      seen[item_name] = true
    end
  end
  do
    for item_name, proto in pairs((tech_priests_prototype_table_0440 and tech_priests_prototype_table_0440("item")) or {}) do
      if not seen[item_name] then
        local ok, place = pcall(function() return proto.place_result end)
        if ok and place and place.name and tech_priests_0259_is_defensive_entity(place.name) then
          result[#result + 1] = { item = item_name, entity = place.name }
        end
      end
    end
  end
  storage.tech_priests.defense_turret_candidates_0259 = result
  return result
end

local function tech_priests_0259_select_turret(pair)
  local fallback = nil
  for _, rec in pairs(tech_priests_0259_turret_candidates()) do
    if tech_priests_0259_item_count(pair, rec.item) > 0 then return rec.item, rec.entity end
    if not fallback and tech_priests_0259_force_has_item(pair, rec.item) then fallback = rec end
  end
  if fallback then return fallback.item, fallback.entity end
  local first = tech_priests_0259_turret_candidates()[1]
  if first then return first.item, first.entity end
  return nil, nil
end

local function tech_priests_0259_defense_state(pair)
  pair.defense_perimeter_0259 = pair.defense_perimeter_0259 or {
    walls = {},
    breaches = {},
    last_radius = nil,
    next_scan_tick = 0,
    built = 0,
    recovered = 0,
    turrets_built = 0,
    last_reason = "initialized"
  }
  return pair.defense_perimeter_0259
end

local function tech_priests_0259_position_key(pos)
  return tostring(math.floor((pos.x or 0) + 0.5)) .. ":" .. tostring(math.floor((pos.y or 0) + 0.5))
end

local function tech_priests_0259_wall_positions(pair, radius)
  local result = {}
  if not (pair and pair.station and pair.station.valid) then return result end
  local center = pair.station.position
  local circumference = math.max(12, 2 * math.pi * math.max(4, radius))
  local count = math.min(TECH_PRIESTS_DEFENSE_MAX_WALLS_PER_STATION_0259, math.max(12, math.floor(circumference / TECH_PRIESTS_DEFENSE_WALL_SPACING_0259)))
  for i = 1, count do
    local angle = (i - 1) * ((math.pi * 2) / count)
    local x = math.floor(center.x + math.cos(angle) * radius + 0.5) + 0.5
    local y = math.floor(center.y + math.sin(angle) * radius + 0.5) + 0.5
    local pos = { x = x, y = y }
    result[tech_priests_0259_position_key(pos)] = pos
  end
  return result
end

local function tech_priests_0259_can_place(pair, entity_name, position)
  if not (pair and pair.station and pair.station.valid and entity_name and position) then return false end
  local surface = pair.station.surface
  local ok, can = pcall(function()
    return surface.can_place_entity({ name = entity_name, position = position, force = pair.station.force })
  end)
  return ok and can or false
end

local function tech_priests_0259_find_near_position(pair, entity_name, center, max_r)
  if tech_priests_0259_can_place(pair, entity_name, center) then return center end
  for r = 1, max_r or 6 do
    for dx = -r, r do
      for dy = -r, r do
        if math.max(math.abs(dx), math.abs(dy)) == r then
          local pos = { x = math.floor(center.x) + dx + 0.5, y = math.floor(center.y) + dy + 0.5 }
          if tech_priests_0259_can_place(pair, entity_name, pos) then return pos end
        end
      end
    end
  end
  return nil
end

local function tech_priests_0259_higher_priority_visible(pair)
  if tech_priests_0248_higher_priority_probe then
    local ok, probe = pcall(function() return tech_priests_0248_higher_priority_probe(pair) end)
    if ok and probe and probe.priority and probe.priority ~= "idle" then return true, probe.priority end
  end
  if tech_priests_pair_has_higher_priority_work_0248 then
    local ok, result = pcall(function() return tech_priests_pair_has_higher_priority_work_0248(pair) end)
    if ok and result then return true, "higher-priority" end
  end
  return false, "idle"
end

local function tech_priests_0259_queue_breach(state, position, reason)
  if not (state and position) then return end
  state.breaches = state.breaches or {}
  if #state.breaches >= TECH_PRIESTS_DEFENSE_MAX_BREACH_QUEUE_0259 then table.remove(state.breaches, 1) end
  state.breaches[#state.breaches + 1] = { position = { x = position.x, y = position.y }, tick = game and game.tick or 0, reason = reason or "wall-lost" }
end

local function tech_priests_0259_validate_tracked_walls(pair, state, desired, radius)
  local obsolete = nil
  for key, rec in pairs(state.walls or {}) do
    local entity = rec.entity
    if not (entity and entity.valid) then
      tech_priests_0259_queue_breach(state, rec.position, "tracked-wall-destroyed")
      state.walls[key] = nil
    else
      local dist = math.sqrt(tech_priests_0259_distance_sq(entity.position, pair.station.position))
      local desired_here = desired[key] ~= nil
      if not desired_here or math.abs(dist - radius) > TECH_PRIESTS_DEFENSE_WALL_RING_TOLERANCE_0259 then
        obsolete = rec
        obsolete.key = key
        break
      end
    end
  end
  return obsolete
end

local function tech_priests_0259_first_missing_wall(pair, state, desired)
  for key, pos in pairs(desired or {}) do
    local rec = state.walls and state.walls[key] or nil
    if not (rec and rec.entity and rec.entity.valid) then
      local near = tech_priests_0259_find_near_position(pair, TECH_PRIESTS_DEFENSE_WALL_ENTITY_0259, pos, 1)
      if near then return key, near end
    end
  end
  return nil, nil
end

local function tech_priests_0259_start_task(pair, task)
  pair.defense_task_0259 = task
  pair.mode = task.mode or "defense-perimeter"
  pair.target = nil
  return true
end

local function tech_priests_0259_start_recover_wall(pair, rec)
  if not (rec and rec.entity and rec.entity.valid) then return false end
  return tech_priests_0259_start_task(pair, {
    type = "recover-wall",
    entity = rec.entity,
    item = rec.item or TECH_PRIESTS_DEFENSE_WALL_ITEM_0259,
    key = rec.key,
    position = { x = rec.entity.position.x, y = rec.entity.position.y },
    next_repath_tick = 0,
    mode = "relocating-defense-wall"
  })
end

local function tech_priests_0259_start_build(pair, task_type, item_name, entity_name, position, key)
  return tech_priests_0259_start_task(pair, {
    type = task_type,
    item = item_name,
    entity_name = entity_name,
    position = { x = position.x, y = position.y },
    key = key,
    phase = "approach",
    next_repath_tick = 0,
    build_due_tick = nil,
    mode = task_type == "build-turret" and "placing-defense-turret" or (task_type == "build-turret-support" and "placing-defense-support" or "placing-defense-wall")
  })
end

local function tech_priests_0259_turret_needs_ammo(entity)
  return entity and entity.valid and tech_priests_0259_entity_type(entity.name) == "ammo-turret"
end

local function tech_priests_0259_find_ammo(pair)
  local inv = tech_priests_0259_station_inventory(pair)
  if not (inv and inv.valid) then return nil end
  local contents = inv.get_contents()
  for name, count in pairs(contents or {}) do
    local proto = tech_priests_get_item_prototype_0440 and tech_priests_get_item_prototype_0440(name) or nil
    if count and count > 0 and proto and proto.type == "ammo" then return name end
  end
  return nil
end

local function tech_priests_0259_start_ammo_service(pair, turret)
  if not (turret and turret.valid and tech_priests_0259_turret_needs_ammo(turret)) then return false end
  local ammo = tech_priests_0259_find_ammo(pair)
  if not ammo then
    tech_priests_0259_request_item(pair, "firearm-magazine", TECH_PRIESTS_DEFENSE_AMMO_BATCH_0259, "defense-ammo")
    return false
  end
  return tech_priests_0259_start_task(pair, {
    type = "ammo-turret",
    turret = turret,
    ammo = ammo,
    position = { x = turret.position.x, y = turret.position.y },
    next_repath_tick = 0,
    mode = "refilling-defense-turret"
  })
end

local function tech_priests_0259_complete_build(pair, task)
  local removed = tech_priests_0259_take_item(pair, task.item, 1)
  if removed <= 0 then
    tech_priests_0259_request_item(pair, task.item, 1, task.type)
    return false
  end
  local ok, entity = pcall(function()
    return pair.station.surface.create_entity({
      name = task.entity_name,
      position = task.position,
      force = pair.station.force,
      create_build_effect_smoke = true,
      raise_built = true
    })
  end)
  if not (ok and entity and entity.valid) then
    tech_priests_0259_return_item(pair, task.item, 1)
    return false
  end
  local state = tech_priests_0259_defense_state(pair)
  if task.type == "build-wall" then
    state.walls[task.key or tech_priests_0259_position_key(task.position)] = {
      entity = entity,
      item = task.item,
      position = { x = entity.position.x, y = entity.position.y },
      radius = state.last_radius,
      built_tick = game.tick
    }
    state.built = (state.built or 0) + 1
  elseif task.type == "build-turret" then
    state.turrets_built = (state.turrets_built or 0) + 1
    state.last_turret = entity
    tech_priests_0259_start_ammo_service(pair, entity)
    return true
  elseif task.type == "build-turret-support" then
    state.supports_built_0260 = (state.supports_built_0260 or 0) + 1
    if task.pending_breach_position_0260 then
      tech_priests_0259_queue_breach(state, task.pending_breach_position_0260, "turret-support-complete")
    end
  end
  if tech_priests_draw_emergency_operation_status_0184 then tech_priests_draw_emergency_operation_status_0184(pair, "[entity=" .. entity.name .. "] defense placement complete") end
  return true
end

local function tech_priests_0259_handle_task(pair)
  local task = pair.defense_task_0259
  if not task then return false end
  if not tech_priests_0259_valid_pair(pair) then pair.defense_task_0259 = nil; return false end
  local priest = pair.priest

  if task.type == "recover-wall" then
    if not (task.entity and task.entity.valid) then pair.defense_task_0259 = nil; return false end
    local dist = tech_priests_0259_distance_sq(priest.position, task.entity.position)
    if dist > TECH_PRIESTS_DEFENSE_BUILD_REACH_SQ_0259 then
      if game.tick >= (task.next_repath_tick or 0) and issue_priest_command then
        issue_priest_command(priest, { type = defines.command.go_to_location, destination = task.entity.position, radius = 2, distraction = defines.distraction.by_enemy })
        task.next_repath_tick = game.tick + TECH_PRIESTS_DEFENSE_REPATH_TICKS_0259
      end
      pair.mode = "relocating-defense-wall"
      return true
    end
    local state = tech_priests_0259_defense_state(pair)
    pcall(function() task.entity.destroy({ raise_destroy = false }) end)
    tech_priests_0259_return_item(pair, task.item, 1)
    if task.key then state.walls[task.key] = nil end
    state.recovered = (state.recovered or 0) + 1
    pair.defense_task_0259 = nil
    return true
  end

  if task.type == "ammo-turret" then
    if not (task.turret and task.turret.valid) then pair.defense_task_0259 = nil; return false end
    local dist = tech_priests_0259_distance_sq(priest.position, task.turret.position)
    if dist > TECH_PRIESTS_DEFENSE_BUILD_REACH_SQ_0259 then
      if game.tick >= (task.next_repath_tick or 0) and issue_priest_command then
        issue_priest_command(priest, { type = defines.command.go_to_location, destination = task.turret.position, radius = 2, distraction = defines.distraction.by_enemy })
        task.next_repath_tick = game.tick + TECH_PRIESTS_DEFENSE_REPATH_TICKS_0259
      end
      pair.mode = "refilling-defense-turret"
      return true
    end
    local ammo = task.ammo or tech_priests_0259_find_ammo(pair)
    if not ammo then pair.defense_task_0259 = nil; return false end
    local removed = tech_priests_0259_take_item(pair, ammo, TECH_PRIESTS_DEFENSE_AMMO_BATCH_0259)
    if removed <= 0 then pair.defense_task_0259 = nil; return false end
    local inv = task.turret.get_inventory(defines.inventory.turret_ammo)
    if inv and inv.valid then
      local inserted = inv.insert({ name = ammo, count = removed }) or 0
      if inserted < removed then tech_priests_0259_return_item(pair, ammo, removed - inserted) end
    else
      tech_priests_0259_return_item(pair, ammo, removed)
    end
    pair.defense_task_0259 = nil
    return true
  end

  if task.type == "build-wall" or task.type == "build-turret" or task.type == "build-turret-support" then
    if not task.position then pair.defense_task_0259 = nil; return false end
    if not tech_priests_0259_can_place(pair, task.entity_name, task.position) then
      local new_pos = tech_priests_0259_find_near_position(pair, task.entity_name, task.position, task.type == "build-turret" and TECH_PRIESTS_DEFENSE_TURRET_SEARCH_RADIUS_0259 or 1)
      if not new_pos then pair.defense_task_0259 = nil; return false end
      task.position = new_pos
    end
    if not tech_priests_0259_force_has_item(pair, task.item) then
      tech_priests_0259_request_item(pair, task.item, 1, task.type)
      pair.defense_task_0259 = nil
      return false
    end
    local dist = tech_priests_0259_distance_sq(priest.position, task.position)
    if dist > TECH_PRIESTS_DEFENSE_BUILD_REACH_SQ_0259 then
      if game.tick >= (task.next_repath_tick or 0) and issue_priest_command then
        issue_priest_command(priest, { type = defines.command.go_to_location, destination = task.position, radius = 2, distraction = defines.distraction.by_enemy })
        task.next_repath_tick = game.tick + TECH_PRIESTS_DEFENSE_REPATH_TICKS_0259
      end
      pair.mode = task.mode or "defense-construction"
      return true
    end
    if not task.build_due_tick then
      task.build_due_tick = game.tick + TECH_PRIESTS_DEFENSE_BUILD_TICKS_0259
      if tech_priests_draw_emergency_operation_status_0184 then tech_priests_draw_emergency_operation_status_0184(pair, "[item=" .. task.item .. "] defense construction rite") end
      return true
    end
    if game.tick < task.build_due_tick then return true end
    local ok = tech_priests_0259_complete_build(pair, task)
    if ok and pair.defense_task_0259 == task then pair.defense_task_0259 = nil end
    return ok
  end

  pair.defense_task_0259 = nil
  return false
end



-- 0.1.260 Defensive turret support validation.
-- Flamethrower/fluid turrets must be placed with a pipe connection available
-- or an adjacent support-pipe build queued first. Laser/electric turrets must be
-- placed inside electrical supply coverage or have a pole requested/queued.
local function tech_priests_0260_entity_kind(entity_name)
  local typ = tech_priests_0259_entity_type(entity_name)
  if typ == "electric-turret" then return "electric" end
  if typ == "fluid-turret" then return "fluid" end
  if entity_name and string.find(entity_name, "laser", 1, true) then return "electric" end
  if entity_name and string.find(entity_name, "flamethrower", 1, true) then return "fluid" end
  return "ordinary"
end

local function tech_priests_0260_position_has_power(pair, position)
  if tech_priests_position_in_electric_supply_0253 then
    local ok, supplied = pcall(function() return tech_priests_position_in_electric_supply_0253(pair, position) end)
    if ok and supplied then return true end
  end
  if not (pair and pair.station and pair.station.valid and position) then return false end
  local surface = pair.station.surface
  local area = {{position.x - 12, position.y - 12}, {position.x + 12, position.y + 12}}
  local ok, poles = pcall(function() return surface.find_entities_filtered({ area = area, type = "electric-pole", force = pair.station.force }) end)
  if not (ok and poles) then return false end
  for _, pole in pairs(poles) do
    if pole and pole.valid then
      local supply = 2.5
      pcall(function() if pole.prototype and pole.prototype.supply_area_distance then supply = pole.prototype.supply_area_distance end end)
      local dx = pole.position.x - position.x
      local dy = pole.position.y - position.y
      if dx * dx + dy * dy <= (supply + 0.35) * (supply + 0.35) then return true end
    end
  end
  return false
end

local function tech_priests_0260_adjacent_support_positions(position)
  return {
    { x = position.x + 1, y = position.y },
    { x = position.x - 1, y = position.y },
    { x = position.x, y = position.y + 1 },
    { x = position.x, y = position.y - 1 }
  }
end

local function tech_priests_0260_position_has_pipe_connection(pair, position)
  if not (pair and pair.station and pair.station.valid and position) then return false end
  local surface = pair.station.surface
  local area = {{position.x - 1.35, position.y - 1.35}, {position.x + 1.35, position.y + 1.35}}
  local ok, entities = pcall(function() return surface.find_entities_filtered({ area = area, force = pair.station.force }) end)
  if not (ok and entities) then return false end
  for _, entity in pairs(entities) do
    if entity and entity.valid then
      local typ = tech_priests_0259_entity_type(entity.name)
      if typ == "pipe" or typ == "pipe-to-ground" or entity.name == "pipe" or entity.name == "pipe-to-ground" then return true end
    end
  end
  return false
end

local function tech_priests_0260_find_powered_turret_position(pair, entity_name, center, max_r)
  max_r = max_r or TECH_PRIESTS_DEFENSE_SUPPORT_SEARCH_RADIUS_0260
  for r = 0, max_r do
    for dx = -r, r do
      for dy = -r, r do
        if math.max(math.abs(dx), math.abs(dy)) == r then
          local pos = { x = math.floor(center.x) + dx + 0.5, y = math.floor(center.y) + dy + 0.5 }
          if tech_priests_0259_can_place(pair, entity_name, pos) and tech_priests_0260_position_has_power(pair, pos) then return pos end
        end
      end
    end
  end
  return nil
end

local function tech_priests_0260_find_pipe_supported_turret_position(pair, entity_name, center, max_r)
  max_r = max_r or TECH_PRIESTS_DEFENSE_SUPPORT_SEARCH_RADIUS_0260
  for r = 0, max_r do
    for dx = -r, r do
      for dy = -r, r do
        if math.max(math.abs(dx), math.abs(dy)) == r then
          local pos = { x = math.floor(center.x) + dx + 0.5, y = math.floor(center.y) + dy + 0.5 }
          if tech_priests_0259_can_place(pair, entity_name, pos) and tech_priests_0260_position_has_pipe_connection(pair, pos) then return pos end
        end
      end
    end
  end
  return nil
end

local function tech_priests_0260_find_pipe_stub_position(pair, turret_position)
  for _, pos in pairs(tech_priests_0260_adjacent_support_positions(turret_position)) do
    if tech_priests_0259_can_place(pair, "pipe", pos) then
      if not tech_priests_0258_pipe_position_safe or tech_priests_0258_pipe_position_safe(pair, "pipe", pos) then return pos end
    end
  end
  return nil
end

local function tech_priests_0260_power_support_item(pair)
  for _, item in pairs(TECH_PRIESTS_DEFENSE_POWER_SUPPORT_ITEMS_0260) do
    local entity = tech_priests_0259_entity_from_item(item)
    if entity and tech_priests_0259_force_has_item(pair, item) then return item, entity end
  end
  for _, item in pairs(TECH_PRIESTS_DEFENSE_POWER_SUPPORT_ITEMS_0260) do
    local entity = tech_priests_0259_entity_from_item(item)
    if entity then return item, entity end
  end
  return nil, nil
end

local function tech_priests_0260_find_power_pole_position(pair, turret_position)
  local item, entity = tech_priests_0260_power_support_item(pair)
  if not (item and entity) then return nil end
  for r = 1, 5 do
    for dx = -r, r do
      for dy = -r, r do
        if math.max(math.abs(dx), math.abs(dy)) == r then
          local pos = { x = math.floor(turret_position.x) + dx + 0.5, y = math.floor(turret_position.y) + dy + 0.5 }
          if tech_priests_0259_can_place(pair, entity, pos) then
            -- Prefer pole placements that will actually supply the desired turret tile.
            local supply = 2.5
            pcall(function()
              local proto = tech_priests_get_entity_prototype_0440 and tech_priests_get_entity_prototype_0440(entity) or nil
              if proto and proto.supply_area_distance then supply = proto.supply_area_distance end
            end)
            local ddx = pos.x - turret_position.x
            local ddy = pos.y - turret_position.y
            if ddx * ddx + ddy * ddy <= (supply + 0.35) * (supply + 0.35) then return item, entity, pos end
          end
        end
      end
    end
  end
  return item, entity, nil
end

local function tech_priests_0260_supported_turret_position(pair, entity_name, breach_position)
  local kind = tech_priests_0260_entity_kind(entity_name)
  if kind == "electric" then
    return tech_priests_0260_find_powered_turret_position(pair, entity_name, breach_position, TECH_PRIESTS_DEFENSE_TURRET_SEARCH_RADIUS_0259), "electric"
  elseif kind == "fluid" then
    return tech_priests_0260_find_pipe_supported_turret_position(pair, entity_name, breach_position, TECH_PRIESTS_DEFENSE_TURRET_SEARCH_RADIUS_0259), "fluid"
  end
  return tech_priests_0259_find_near_position(pair, entity_name, breach_position, TECH_PRIESTS_DEFENSE_TURRET_SEARCH_RADIUS_0259), "ordinary"
end

local function tech_priests_0260_queue_turret_support(pair, turret_entity_name, breach_position, state)
  local kind = tech_priests_0260_entity_kind(turret_entity_name)
  if kind == "electric" then
    local item, entity, pos = tech_priests_0260_find_power_pole_position(pair, breach_position)
    if item and entity and pos then
      if not tech_priests_0259_force_has_item(pair, item) then tech_priests_0259_request_item(pair, item, 1, "defense-power-support") end
      state.last_reason = "placing-power-before-" .. tostring(turret_entity_name)
      local started = tech_priests_0259_start_build(pair, "build-turret-support", item, entity, pos, nil)
      if started and pair.defense_task_0259 then
        pair.defense_task_0259.pending_breach_position_0260 = { x = breach_position.x, y = breach_position.y }
        pair.defense_task_0259.pending_turret_entity_0260 = turret_entity_name
      end
      return started
    elseif item then
      tech_priests_0259_request_item(pair, item, 1, "defense-power-support")
      state.last_reason = "requested-power-before-" .. tostring(turret_entity_name)
      return false
    end
  elseif kind == "fluid" then
    local pos = tech_priests_0260_find_pipe_stub_position(pair, breach_position)
    if pos then
      if not tech_priests_0259_force_has_item(pair, TECH_PRIESTS_DEFENSE_PIPE_SUPPORT_ITEM_0260) then tech_priests_0259_request_item(pair, TECH_PRIESTS_DEFENSE_PIPE_SUPPORT_ITEM_0260, 2, "defense-pipe-support") end
      state.last_reason = "placing-pipe-before-" .. tostring(turret_entity_name)
      local started = tech_priests_0259_start_build(pair, "build-turret-support", TECH_PRIESTS_DEFENSE_PIPE_SUPPORT_ITEM_0260, "pipe", pos, nil)
      if started and pair.defense_task_0259 then
        pair.defense_task_0259.pending_breach_position_0260 = { x = breach_position.x, y = breach_position.y }
        pair.defense_task_0259.pending_turret_entity_0260 = turret_entity_name
      end
      return started
    else
      tech_priests_0259_request_item(pair, TECH_PRIESTS_DEFENSE_PIPE_SUPPORT_ITEM_0260, 2, "defense-pipe-support")
      state.last_reason = "requested-pipe-before-" .. tostring(turret_entity_name)
      return false
    end
  end
  return false
end

local function tech_priests_0259_service_wall_breach(pair, state)
  if not (state.breaches and #state.breaches > 0) then return false end
  local breach = table.remove(state.breaches, 1)
  local fallback_support = nil
  for _, rec in pairs(tech_priests_0259_turret_candidates()) do
    if rec.item and rec.entity and tech_priests_0259_force_has_item(pair, rec.item) then
      local pos, support_kind = tech_priests_0260_supported_turret_position(pair, rec.entity, breach.position)
      if pos then
        state.last_reason = "responding-to-breach-" .. tostring(support_kind or "ordinary")
        return tech_priests_0259_start_build(pair, "build-turret", rec.item, rec.entity, pos, nil)
      end
      if not fallback_support then fallback_support = rec end
    end
  end

  local turret_item, turret_entity = tech_priests_0259_select_turret(pair)
  if not (turret_item and turret_entity) then return false end
  if fallback_support then
    if tech_priests_0260_queue_turret_support(pair, fallback_support.entity, breach.position, state) then return true end
  end
  local pos, support_kind = tech_priests_0260_supported_turret_position(pair, turret_entity, breach.position)
  if not pos then
    if tech_priests_0260_queue_turret_support(pair, turret_entity, breach.position, state) then return true end
    state.last_reason = "breach-turret-site-blocked-or-unsupported"
    return false
  end
  if not tech_priests_0259_force_has_item(pair, turret_item) then
    tech_priests_0259_request_item(pair, turret_item, 1, "defense-turret")
    state.last_reason = "requested-" .. tostring(turret_item)
    return false
  end
  state.last_reason = "responding-to-breach-" .. tostring(support_kind or "ordinary")
  return tech_priests_0259_start_build(pair, "build-turret", turret_item, turret_entity, pos, nil)
end

local function tech_priests_0259_service_perimeter(pair)
  if not tech_priests_0259_valid_pair(pair) then return false end
  local state = tech_priests_0259_defense_state(pair)
  if game.tick < (state.next_scan_tick or 0) then return false end
  state.next_scan_tick = game.tick + TECH_PRIESTS_DEFENSE_SCAN_INTERVAL_0259

  local radius = math.max(8, math.floor(tech_priests_0259_radius(pair) - 1))
  local desired = tech_priests_0259_wall_positions(pair, radius)
  if math.abs((state.last_radius or 0) - radius) > 0.5 then
    state.last_reason = "coverage-changed"
    state.last_radius = radius
  end

  local obsolete = tech_priests_0259_validate_tracked_walls(pair, state, desired, radius)
  if obsolete and tech_priests_0259_start_recover_wall(pair, obsolete) then return true end

  if tech_priests_0259_service_wall_breach(pair, state) then return true end

  if not tech_priests_0259_force_has_item(pair, TECH_PRIESTS_DEFENSE_WALL_ITEM_0259) then
    tech_priests_0259_request_item(pair, TECH_PRIESTS_DEFENSE_WALL_ITEM_0259, 10, "defense-wall")
    state.last_reason = "awaiting-walls"
    return false
  end

  local key, pos = tech_priests_0259_first_missing_wall(pair, state, desired)
  if key and pos then
    state.last_reason = "placing-wall-ring"
    return tech_priests_0259_start_build(pair, "build-wall", TECH_PRIESTS_DEFENSE_WALL_ITEM_0259, TECH_PRIESTS_DEFENSE_WALL_ENTITY_0259, pos, key)
  end

  state.last_reason = "perimeter-satisfied"
  return false
end

if tick_pair then
  TECH_PRIESTS_TICK_PAIR_BEFORE_0259 = tick_pair
  function tick_pair(pair)
    if pair and pair.defense_task_0259 then
      local blocked = tech_priests_0259_higher_priority_visible(pair)
      if not blocked and tech_priests_0259_handle_task(pair) then return true end
    end
    if pair and tech_priests_0259_valid_pair(pair) then
      local blocked = tech_priests_0259_higher_priority_visible(pair)
      if not blocked and tech_priests_0259_service_perimeter(pair) then return true end
    end
    return TECH_PRIESTS_TICK_PAIR_BEFORE_0259(pair)
  end
end

if commands and commands.add_command then
  pcall(function()
    commands.add_command("tp-defense-debug", "Tech Priests: report Cogitator Station defense perimeter state for the selected station.", function(event)
      local player = game.get_player(event.player_index)
      if not player then return end
      local pair = nil
      if tech_priests_find_pair_for_player_selection_0184 then pair = tech_priests_find_pair_for_player_selection_0184(player) end
      if not pair and player.selected and player.selected.valid and get_pair_by_station then pair = get_pair_by_station(player.selected) end
      if not pair then player.print("[Tech Priests] Select a Cogitator Station or priest first."); return end
      local state = tech_priests_0259_defense_state(pair)
      local wall_count, invalid_count = 0, 0
      for _, rec in pairs(state.walls or {}) do
        if rec and rec.entity and rec.entity.valid then wall_count = wall_count + 1 else invalid_count = invalid_count + 1 end
      end
      local turret_item, turret_entity = tech_priests_0259_select_turret(pair)
      player.print("[Tech Priests] defense perimeter diagnostics:")
      player.print("  station=" .. tostring(pair.station and pair.station.valid and pair.station.name or "nil") .. " unit=" .. tostring(pair.station and pair.station.valid and pair.station.unit_number or "nil"))
      player.print("  radius=" .. tostring(state.last_radius or "unknown") .. " walls=" .. tostring(wall_count) .. " invalid_records=" .. tostring(invalid_count))
      player.print("  breaches=" .. tostring(state.breaches and #state.breaches or 0) .. " active_task=" .. tostring(pair.defense_task_0259 and pair.defense_task_0259.type or "none"))
      player.print("  wall_items=" .. tostring(tech_priests_0259_item_count(pair, TECH_PRIESTS_DEFENSE_WALL_ITEM_0259)) .. " last_reason=" .. tostring(state.last_reason or "none"))
      player.print("  preferred_turret=" .. tostring(turret_item or "none") .. " entity=" .. tostring(turret_entity or "none") .. " support_kind=" .. tostring(turret_entity and tech_priests_0260_entity_kind(turret_entity) or "none"))
      player.print("  built_walls=" .. tostring(state.built or 0) .. " recovered_walls=" .. tostring(state.recovered or 0) .. " turrets_built=" .. tostring(state.turrets_built or 0) .. " supports_built=" .. tostring(state.supports_built_0260 or 0))
    end)
  end)
end

tech_priests_0259_diag("defense perimeter planner loaded with 0.1.260 turret support validation")
