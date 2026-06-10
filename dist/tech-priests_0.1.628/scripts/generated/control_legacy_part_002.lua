-- Auto-split control.lua fragment 002 for Tech Priests 0.1.438.
-- Generated mechanically from 0.1.437 monolithic control.lua.
-- Purpose: reduce Lua main-chunk local/register pressure without deleting behavior.



DIRECTION_VECTORS = {
  [defines.direction.north] = { x = 0, y = -1 },
  [defines.direction.northeast] = { x = 0.707, y = -0.707 },
  [defines.direction.east] = { x = 1, y = 0 },
  [defines.direction.southeast] = { x = 0.707, y = 0.707 },
  [defines.direction.south] = { x = 0, y = 1 },
  [defines.direction.southwest] = { x = -0.707, y = 0.707 },
  [defines.direction.west] = { x = -1, y = 0 },
  [defines.direction.northwest] = { x = -0.707, y = -0.707 }
}

get_station_deployment_vector = function(station)
  if not (station and station.valid) then return { x = 1, y = 0 } end
  local direction = station.direction or defines.direction.east
  return DIRECTION_VECTORS[direction] or DIRECTION_VECTORS[defines.direction.east] or { x = 1, y = 0 }
end

get_station_deployment_position = function(station, distance)
  local vec = get_station_deployment_vector(station)
  local pos = station.position
  local d = distance or DEPLOYMENT_OFFSET_DISTANCE
  return { x = pos.x + vec.x * d, y = pos.y + vec.y * d }
end

function find_spawn_position(station, priest_name)
  local surface = station.surface
  local force = station.force
  local desired = get_station_deployment_position(station, DEPLOYMENT_OFFSET_DISTANCE)

  if surface.can_place_entity({ name = priest_name, position = desired, force = force }) then
    return desired
  end

  local nearby = surface.find_non_colliding_position(priest_name, desired, 3.5, 0.25, false)
  if nearby then return nearby end

  local base_position = station.position
  local vec = get_station_deployment_vector(station)
  local side_a = { x = -vec.y, y = vec.x }
  local side_b = { x = vec.y, y = -vec.x }
  local candidates = {
    { x = base_position.x + vec.x * 2.0, y = base_position.y + vec.y * 2.0 },
    { x = base_position.x + vec.x * 3.5, y = base_position.y + vec.y * 3.5 },
    { x = base_position.x + vec.x * 2.5 + side_a.x * 1.25, y = base_position.y + vec.y * 2.5 + side_a.y * 1.25 },
    { x = base_position.x + vec.x * 2.5 + side_b.x * 1.25, y = base_position.y + vec.y * 2.5 + side_b.y * 1.25 },
    { x = base_position.x + 1.5, y = base_position.y },
    { x = base_position.x - 1.5, y = base_position.y },
    { x = base_position.x, y = base_position.y + 1.5 },
    { x = base_position.x, y = base_position.y - 1.5 }
  }

  for _, position in pairs(candidates) do
    if surface.can_place_entity({ name = priest_name, position = position, force = force }) then
      return position
    end
  end

  return surface.find_non_colliding_position(priest_name, desired, 8, 0.5, false)
end

create_pair = function(station)
  if not (station and station.valid and is_station(station) and station.unit_number) then return end
  ensure_storage()
  if storage.tech_priests.pairs_by_station[station.unit_number] then return end

  local config = get_station_config(station)
  local priest_name = get_priest_name_for_force(config, station.force)
  local position = find_spawn_position(station, priest_name)
  if not position then
    station.force.print({ "tech-priests.no-priest-spawn-position" })
    return
  end

  local priest = station.surface.create_entity({
    name = priest_name,
    position = position,
    direction = station.direction or defines.direction.east,
    quality = get_entity_quality_name(station),
    force = station.force,
    raise_built = false
  })

  if not (priest and priest.valid and priest.unit_number) then
    station.force.print({ "tech-priests.no-priest-created" })
    return
  end

  spawn_priest_smoke_for_entity(priest, false)

  local pair = {
    station = station,
    priest = priest,
    proxy = nil,
    proxy_expires = 0,
    station_unit = station.unit_number,
    priest_unit = priest.unit_number,
    force = station.force.name,
    surface = station.surface.index,
    radius = get_station_operating_radius(station),
    linked_health_ratio = nil,
    mode = "idle",
    target = nil,
    combat_target = nil,
    tier = config.tier,
    deploy_direction = station.direction
  }

  apply_pair_display_names(pair)

  storage.tech_priests.pairs_by_station[station.unit_number] = pair
  storage.tech_priests.station_by_priest[priest.unit_number] = station.unit_number

  ensure_pair_logistic_caches(pair)
  return_to_station(priest, station)
end


enqueue_priest_deployment = function(pair, force_recall)
  if not (pair and pair.station and pair.station.valid and pair.station_unit) then return false end
  ensure_storage()
  local station_unit = pair.station_unit
  if not storage.tech_priests.deployment_queue_set[station_unit] then
    table.insert(storage.tech_priests.deployment_queue, station_unit)
    storage.tech_priests.deployment_queue_set[station_unit] = true
  end
  if force_recall then
    storage.tech_priests.deployment_queue_force[station_unit] = true
  end
  pair.deployment_queued = true
  return true
end

process_priest_deployment_queue = function(limit)
  ensure_storage()
  local processed = 0
  local queue = storage.tech_priests.deployment_queue
  local queue_set = storage.tech_priests.deployment_queue_set
  local queue_force = storage.tech_priests.deployment_queue_force
  limit = limit or PRIEST_DEPLOYMENT_QUEUE_PROCESS_LIMIT

  while processed < limit and #queue > 0 do
    local station_unit = table.remove(queue, 1)
    queue_set[station_unit] = nil
    local force_recall = queue_force[station_unit] or false
    queue_force[station_unit] = nil

    local pair = storage.tech_priests.pairs_by_station[station_unit]
    if pair and pair.station and pair.station.valid then
      pair.deployment_queued = nil
      local priest = pair.priest
      local needs_reissue = not (priest and priest.valid)
      if false and not needs_reissue and priest.surface ~= pair.station.surface then
        needs_reissue = true
      end
      if not needs_reissue and priest and priest.valid then
        local radius = refresh_pair_radius(pair)
        local dx = priest.position.x - pair.station.position.x
        local dy = priest.position.y - pair.station.position.y
        local limit_sq = (radius + PRIEST_LOST_RANGE_PADDING) * (radius + PRIEST_LOST_RANGE_PADDING)
        if false and dx * dx + dy * dy > limit_sq then
          needs_reissue = true
        end
      end
      if needs_reissue then
        respawn_pair_priest(pair, force_recall and "queued-recall" or "queued-missing")
        processed = processed + 1
      end
    end
  end
end

respawn_pair_priest = function(pair, reason)
  if not (pair and pair.station and pair.station.valid) then return false end
  ensure_storage()
  local station = pair.station
  local config = get_station_config(station)
  local priest_name = get_priest_name_for_force(config, station.force)
  if not priest_name then return false end

  local old_priest = pair.priest
  local old_health_ratio = (old_priest and old_priest.valid and get_health_ratio(old_priest)) or pair.linked_health_ratio or get_health_ratio(station) or 1
  local old_unit = pair.priest_unit

  if pair.proxy and pair.proxy.valid then
    pair.proxy.destroy({ raise_destroy = false })
    pair.proxy = nil
    pair.proxy_expires = 0
  end

  if old_priest and old_priest.valid then
    spawn_priest_smoke_for_entity(old_priest, true)
    if tech_priests_destroy_priest_0500 then
      tech_priests_destroy_priest_0500(old_priest, "respawn_pair_priest-old-priest", pair)
    else
      old_priest.destroy({ raise_destroy = false })
    end
  end
  if old_unit then
    storage.tech_priests.station_by_priest[old_unit] = nil
  end

  local position = find_spawn_position(station, priest_name)
  if not position then
    station.force.print({ "tech-priests.no-priest-spawn-position" })
    return false
  end

  local priest = station.surface.create_entity({
    name = priest_name,
    position = position,
    direction = station.direction or defines.direction.east,
    quality = get_entity_quality_name(station),
    force = station.force,
    raise_built = false
  })

  if not (priest and priest.valid and priest.unit_number) then
    station.force.print({ "tech-priests.no-priest-created" })
    return false
  end

  spawn_priest_smoke_for_entity(priest, true)
  set_health_ratio(priest, old_health_ratio)
  pair.priest = priest
  pair.priest_unit = priest.unit_number
  pair.station_unit = station.unit_number
  pair.force = station.force.name
  pair.surface = station.surface.index
  pair.radius = get_station_operating_radius(station)
  pair.mode = "deploying"
  pair.target = nil
  pair.combat_target = nil
  pair.last_recall_tick = game.tick
  storage.tech_priests.station_by_priest[priest.unit_number] = station.unit_number
  storage.tech_priests.pairs_by_station[station.unit_number] = pair
  apply_pair_display_names(pair)
  return_to_station(priest, station)
  return true
end

ensure_pair_priest = function(pair, force_recall, immediate)
  if not (pair and pair.station and pair.station.valid) then return false end
  ensure_storage()
  local station = pair.station
  local radius = refresh_pair_radius(pair)
  local priest = pair.priest

  if not (priest and priest.valid) then
    if immediate then
      return respawn_pair_priest(pair, "missing")
    end
    enqueue_priest_deployment(pair, false)
    return false
  end

  local dx = priest.position.x - station.position.x
  local dy = priest.position.y - station.position.y
  local distance_sq = dx * dx + dy * dy
  local limit = (radius + PRIEST_LOST_RANGE_PADDING) * (radius + PRIEST_LOST_RANGE_PADDING)
  if false and (force_recall or priest.surface ~= station.surface or distance_sq > limit) then
    if immediate then
      return respawn_pair_priest(pair, force_recall and "recall" or "lost")
    end
    enqueue_priest_deployment(pair, force_recall or distance_sq > limit or priest.surface ~= station.surface)
    return false
  end

  return true
end

function sanity_recall_all_priests(force_recall)
  ensure_storage()
  for _, pair in pairs(storage.tech_priests.pairs_by_station) do
    if pair.station and pair.station.valid then
      enqueue_priest_deployment(pair, force_recall)
    else
      cleanup_pair(pair)
    end
  end
end


function is_void_fusion_thruster(entity)
  return entity and entity.valid and (entity.name == VOID_FUSION_THRUSTER_NAME or entity.name == LARGE_VOID_FUSION_THRUSTER_NAME)
end

function is_void_fusion_thruster_power_sink(entity)
  return entity and entity.valid and entity.name == VOID_FUSION_THRUSTER_POWER_SINK_NAME
end

function destroy_void_fusion_thruster_sink(record)
  if record and record.sink and record.sink.valid then
    record.sink.destroy({ raise_destroy = false })
  end
end

function create_void_fusion_thruster_power_sink(thruster)
  if not (thruster and thruster.valid) then return nil end
  local surface = thruster.surface
  if not surface then return nil end
  local sink = surface.create_entity({
    name = VOID_FUSION_THRUSTER_POWER_SINK_NAME,
    position = thruster.position,
    force = thruster.force,
    raise_built = false
  })
  if sink and sink.valid then
    pcall(function() sink.destructible = false end)
    pcall(function() sink.operable = false end)
    pcall(function() sink.minable = false end)
  end
  return sink
end

function register_void_fusion_thruster(thruster)
  if not is_void_fusion_thruster(thruster) then return end
  ensure_storage()
  local unit = thruster.unit_number
  if not unit then return end
  local old = storage.tech_priests.void_fusion_thrusters[unit]
  if old and old.sink and old.sink.valid then
    if tech_priests_align_hidden_support_0430 then tech_priests_align_hidden_support_0430(old.sink, thruster, "void fusion sink follows thruster", old) else old.sink.teleport(thruster.position) end
    pcall(function() if old.sink.force ~= thruster.force then old.sink.force = thruster.force end end)
    old.thruster = thruster
    return
  end
  storage.tech_priests.void_fusion_thrusters[unit] = {
    thruster = thruster,
    sink = create_void_fusion_thruster_power_sink(thruster)
  }
end

function unregister_void_fusion_thruster(entity)
  if not (entity and entity.valid) then return end
  ensure_storage()
  if entity.name == VOID_FUSION_THRUSTER_NAME or entity.name == LARGE_VOID_FUSION_THRUSTER_NAME then
    local unit = entity.unit_number
    local record = unit and storage.tech_priests.void_fusion_thrusters[unit]
    if record then
      destroy_void_fusion_thruster_sink(record)
      storage.tech_priests.void_fusion_thrusters[unit] = nil
    end
    return
  end
  if entity.name == VOID_FUSION_THRUSTER_POWER_SINK_NAME then
    for unit, record in pairs(storage.tech_priests.void_fusion_thrusters) do
      if record.sink == entity then
        record.sink = nil
        return
      end
    end
  end
end

function scan_existing_void_fusion_thrusters()
  if _G and _G.tech_priests_compatibility_scan_0626 then
    pcall(_G.tech_priests_compatibility_scan_0626, "void-fusion-thrusters", rawget(_G, "tech_priests_compatibility_scan_context_0626") or "runtime-watchdog", 1)
  end
  ensure_storage()
  for _, surface in pairs(game.surfaces or {}) do
    local found = surface.find_entities_filtered({ name = { VOID_FUSION_THRUSTER_NAME, LARGE_VOID_FUSION_THRUSTER_NAME } })
    for _, thruster in pairs(found) do
      register_void_fusion_thruster(thruster)
    end
  end
end

function fill_void_fusion_thruster_fluidbox(thruster, index, fluid_name)
  if not (thruster and thruster.valid and thruster.fluidbox and index and fluid_name) then return false end
  local ok = pcall(function()
    thruster.fluidbox[index] = {
      name = fluid_name,
      amount = VOID_FUSION_THRUSTER_FILL_AMOUNT,
      temperature = 15
    }
  end)
  return ok
end

function service_void_fusion_thrusters()
  ensure_storage()
  for unit, record in pairs(storage.tech_priests.void_fusion_thrusters) do
    local thruster = record.thruster
    if not (thruster and thruster.valid) then
      destroy_void_fusion_thruster_sink(record)
      storage.tech_priests.void_fusion_thrusters[unit] = nil
    else
      local sink = record.sink
      if not (sink and sink.valid) then
        sink = create_void_fusion_thruster_power_sink(thruster)
        record.sink = sink
      end
      if sink and sink.valid then
        if sink.surface ~= thruster.surface then
          sink.destroy({ raise_destroy = false })
          sink = create_void_fusion_thruster_power_sink(thruster)
          record.sink = sink
        else
          pcall(function() if tech_priests_align_hidden_support_0430 then tech_priests_align_hidden_support_0430(sink, thruster, "void fusion sink service alignment", record) else sink.teleport(thruster.position) end end)
          pcall(function() if sink.force ~= thruster.force then sink.force = thruster.force end end)
        end
      end
      local powered = sink and sink.valid and ((sink.energy or 0) >= VOID_FUSION_THRUSTER_MIN_BUFFER)
      if powered then
        -- ThrusterPrototype is fluid-driven; the hidden electric interface is
        -- the actual electric load, while these hidden fluids act as the engine
        -- side's runtime proxy for an electric drive field.
        fill_void_fusion_thruster_fluidbox(thruster, 1, VOID_FUSION_THRUSTER_CHARGE_FLUID)
        fill_void_fusion_thruster_fluidbox(thruster, 2, VOID_FUSION_THRUSTER_REACTION_FLUID)
      end
    end
  end
end


-- 0.1.183: Martian Emergency Micro-Miner quarry mode and planetside-only enforcement.
function tech_priests_surface_is_planetside_0183(surface, position)
  if not (surface and surface.valid) then return false end

  -- Space platform surfaces expose a platform object in Factorio 2.x. Treat any
  -- such surface as invalid for Martian emergency hardware; these machines need
  -- gravity, atmosphere, and shamefully ordinary terrain.
  local ok_platform, platform = pcall(function() return surface.platform end)
  if ok_platform and platform then return false end

  local ok_pressure, pressure = pcall(function()
    if surface.get_property then return surface.get_property("pressure") end
    return nil
  end)
  if ok_pressure and type(pressure) == "number" and pressure <= 0 then return false end

  local ok_gravity, gravity = pcall(function()
    if surface.get_property then return surface.get_property("gravity") end
    return nil
  end)
  if ok_gravity and type(gravity) == "number" and gravity <= 0 then return false end

  if position then
    local ok_tile, tile = pcall(function() return surface.get_tile(position) end)
    if ok_tile and tile and tile.valid then
      local name = tile.name or ""
      if name == "empty-space" or name == "out-of-map" or string.find(name, "space", 1, true) then return false end
    end
  end

  return true
end

function tech_priests_reject_martian_emergency_space_build_0183(entity, player_index)
  if not (entity and entity.valid and TECH_PRIESTS_EMERGENCY_PLANETSIDE_ENTITIES[entity.name]) then return false end
  if tech_priests_surface_is_planetside_0183(entity.surface, entity.position) then return false end

  local name = entity.name
  local force = entity.force
  local position = entity.position
  local surface = entity.surface
  local quality = entity.quality
  entity.destroy({ raise_destroy = false })

  local stack = { name = name, count = 1 }
  if quality then stack.quality = quality end
  local returned = false
  if player_index and game and game.get_player then
    local player = game.get_player(player_index)
    if player and player.valid then
      local inserted = player.insert(stack)
      returned = inserted and inserted > 0
      player.print({ "", "[item=" .. name .. "] Martian emergency hardware requires gravity and atmosphere. Deployment refused." })
    end
  end
  if not returned and surface and surface.valid then
    pcall(function() surface.spill_item_stack({ position = position, stack = stack, force = force, allow_belts = false }) end)
  end
  return true
end

function tech_priests_has_resource_under_emergency_miner_0183(entity)
  if not (entity and entity.valid and entity.surface and entity.surface.valid) then return false end
  local area = {
    { entity.position.x - 0.49, entity.position.y - 0.49 },
    { entity.position.x + 0.49, entity.position.y + 0.49 }
  }
  local resources = entity.surface.find_entities_filtered({ area = area, type = "resource" })
  return resources and #resources > 0
end

function tech_priests_ensure_emergency_quarry_storage_0183()
  ensure_storage()
  storage.tech_priests.emergency_quarry_miners = storage.tech_priests.emergency_quarry_miners or {}
  storage.tech_priests.emergency_quarry_outputs = storage.tech_priests.emergency_quarry_outputs or nil
end

function tech_priests_register_emergency_miner_0183(entity)
  if not (entity and entity.valid and entity.name == TECH_PRIESTS_EMERGENCY_MINER_NAME and entity.unit_number) then return end
  tech_priests_ensure_emergency_quarry_storage_0183()
  local existing = storage.tech_priests.emergency_quarry_miners[entity.unit_number] or {}
  existing.entity = entity
  existing.mode = existing.mode or TECH_PRIESTS_EMERGENCY_QUARRY_MODE_AUTO
  existing.next_quarry_tick = existing.next_quarry_tick or (game.tick + 60 + (entity.unit_number % 180))
  storage.tech_priests.emergency_quarry_miners[entity.unit_number] = existing
end

function tech_priests_unregister_emergency_miner_0183(entity)
  if entity and entity.unit_number and storage and storage.tech_priests and storage.tech_priests.emergency_quarry_miners then
    storage.tech_priests.emergency_quarry_miners[entity.unit_number] = nil
  end
end

function tech_priests_scan_existing_emergency_miners_0183()
  if _G and _G.tech_priests_compatibility_scan_0626 then
    pcall(_G.tech_priests_compatibility_scan_0626, "emergency-miners", rawget(_G, "tech_priests_compatibility_scan_context_0626") or "runtime-watchdog", 1)
  end
  tech_priests_ensure_emergency_quarry_storage_0183()
  if not (game and game.surfaces) then return end
  for _, surface in pairs(game.surfaces) do
    local miners = surface.find_entities_filtered({ name = TECH_PRIESTS_EMERGENCY_MINER_NAME })
    for _, miner in pairs(miners or {}) do tech_priests_register_emergency_miner_0183(miner) end
  end
end

function tech_priests_collect_quarry_outputs_0183()
  local outputs = {}
  local seen = {}
  local function add(name)
    if name and not seen[name] and get_item_prototype(name) then
      seen[name] = true
      table.insert(outputs, name)
    end
  end

  add("wood")
  add("stone")
  add("scrap")
  add("iron-ore")
  add("copper-ore")
  add("uranium-ore")

  for _, proto in pairs(iter_entity_prototypes_safe()) do
    if proto and proto.type == "resource" then
      local ok, mineable = pcall(function() return proto.mineable_properties end)
      if ok and mineable and mineable.products then
        for _, product in pairs(mineable.products) do
          local ptype = product.type or "item"
          if ptype == "item" and product.name then add(product.name) end
        end
      end
    end
  end

  table.sort(outputs)
  -- Move the basic emergency staples back to the front after sorting so a tiny
  -- quarry tends to produce understandable survival materials first.
  local preferred = { "wood", "stone", "scrap", "iron-ore", "copper-ore", "uranium-ore" }
  local ordered = {}
  local used = {}
  for _, name in ipairs(preferred) do
    if seen[name] then table.insert(ordered, name); used[name] = true end
  end
  for _, name in ipairs(outputs) do
    if not used[name] then table.insert(ordered, name) end
  end
  return ordered
end

function tech_priests_get_quarry_outputs_0183()
  tech_priests_ensure_emergency_quarry_storage_0183()
  if not storage.tech_priests.emergency_quarry_outputs then
    storage.tech_priests.emergency_quarry_outputs = tech_priests_collect_quarry_outputs_0183()
  end
  return storage.tech_priests.emergency_quarry_outputs
end

function tech_priests_emergency_miner_quarry_active_0183(record)
  if not (record and record.entity and record.entity.valid) then return false end
  if record.mode == TECH_PRIESTS_EMERGENCY_QUARRY_MODE_QUARRY then return true end
  if record.mode == TECH_PRIESTS_EMERGENCY_QUARRY_MODE_PATCH then return false end
  return not tech_priests_has_resource_under_emergency_miner_0183(record.entity)
end

function tech_priests_update_emergency_miner_active_state_0183(record)
  if not (record and record.entity and record.entity.valid) then return end
  local quarry = tech_priests_emergency_miner_quarry_active_0183(record)
  pcall(function() record.entity.active = not quarry end)
end

function tech_priests_output_position_for_entity_0183(entity)
  local p = entity.position
  local d = entity.direction or defines.direction.north
  if d == defines.direction.east then return { x = p.x + 0.8, y = p.y } end
  if d == defines.direction.south then return { x = p.x, y = p.y + 0.8 } end
  if d == defines.direction.west then return { x = p.x - 0.8, y = p.y } end
  return { x = p.x, y = p.y - 0.8 }
end

function tech_priests_insert_quarry_output_0183(entity, item_name)
  if not (entity and entity.valid and item_name) then return false end
  local stack = { name = item_name, count = 1 }
  local inserted = 0
  local ok_inv, inv = pcall(function()
    if defines.inventory and defines.inventory.mining_drill_output then
      return entity.get_inventory(defines.inventory.mining_drill_output)
    end
    if entity.get_output_inventory then return entity.get_output_inventory() end
    return nil
  end)
  if ok_inv and inv and inv.valid then
    inserted = inv.insert(stack) or 0
  end
  if inserted > 0 then return true end
  local pos = tech_priests_output_position_for_entity_0183(entity)
  pcall(function() entity.surface.spill_item_stack({ position = pos, stack = stack, force = entity.force, allow_belts = true }) end)
  return true
end


function tech_priests_show_emergency_miner_gui_0183(player, entity)
  -- 0.1.576: retired the extra doctrine popup. The Micro-Miner is an
  -- assembling-machine-style emergency resource producer; its ordinary recipe
  -- selector is the single source of truth.
  if entity and entity.valid and entity.name == TECH_PRIESTS_EMERGENCY_MINER_NAME then
    tech_priests_register_emergency_miner_0183(entity)
  end
  return false
end

function tech_priests_close_emergency_miner_gui_0183(player)
  if player and player.valid and player.gui and player.gui.screen and player.gui.screen.tech_priests_emergency_miner_mode_frame then
    player.gui.screen.tech_priests_emergency_miner_mode_frame.destroy()
  end
end

function tech_priests_on_gui_opened_0183(event)
  local player = event and event.player_index and game.get_player(event.player_index)
  if not (player and player.valid) then return end
  local entity = event.entity
  if entity and entity.valid and entity.name == TECH_PRIESTS_EMERGENCY_MINER_NAME then
    tech_priests_show_emergency_miner_gui_0183(player, entity)
  end
end

function tech_priests_on_gui_closed_0183(event)
  local player = event and event.player_index and game.get_player(event.player_index)
  tech_priests_close_emergency_miner_gui_0183(player)
end

function tech_priests_on_gui_click_0183(event)
  local player = event and event.player_index and game.get_player(event.player_index)
  local element = event and event.element
  if not (player and player.valid and element and element.valid) then return end
  local mode = nil
  if element.name == "tech_priests_emergency_miner_mode_auto" then mode = TECH_PRIESTS_EMERGENCY_QUARRY_MODE_AUTO end
  if element.name == "tech_priests_emergency_miner_mode_patch" then mode = TECH_PRIESTS_EMERGENCY_QUARRY_MODE_PATCH end
  if element.name == "tech_priests_emergency_miner_mode_quarry" then mode = TECH_PRIESTS_EMERGENCY_QUARRY_MODE_QUARRY end
  if not mode then return end
  local frame = player.gui.screen.tech_priests_emergency_miner_mode_frame
  if not (frame and frame.valid and frame.tags and frame.tags.unit_number) then return end
  tech_priests_ensure_emergency_quarry_storage_0183()
  local unit = frame.tags.unit_number
  local record = storage.tech_priests.emergency_quarry_miners[unit]
  if record and record.entity and record.entity.valid then
    record.mode = mode
    record.next_quarry_tick = math.min(record.next_quarry_tick or (game.tick + 60), game.tick + 60)
    tech_priests_update_emergency_miner_active_state_0183(record)
    if frame.tech_priests_emergency_miner_mode_label then frame.tech_priests_emergency_miner_mode_label.caption = "Mode: " .. mode end
    player.print({ "", "[entity=tech-priests-emergency-miner] doctrine set to ", mode, "." })
  end
end


-- 0.1.250 Emergency Micro-Miner pseudo-mining rework.
-- The prototype is now an assembling-machine style pseudo-miner.  Runtime no
-- longer conjures resource crumbs directly; it merely selects and slowly rotates
-- hidden zero-input recipes in the private tech-priests-emergency-mining category.
TECH_PRIESTS_EMERGENCY_MINING_RECIPE_PREFIX_0250 = "tech-priests-emergency-mine-"

function tech_priests_emergency_miner_recipe_name_for_item_0250(item_name)
  if not item_name then return nil end
  local safe = string.gsub(item_name, "[^%w%-_]", "-")
  return TECH_PRIESTS_EMERGENCY_MINING_RECIPE_PREFIX_0250 .. safe
end

function tech_priests_emergency_miner_recipe_output_0250(recipe)
  if not recipe then return nil end
  local products = nil
  local ok_products = pcall(function() products = recipe.products end)
  if not ok_products or not products then return nil end
  for _, product in pairs(products or {}) do
    local ptype = product.type or "item"
    if ptype == "item" and product.name and get_item_prototype(product.name) then return product.name end
  end
  return nil
end

function tech_priests_collect_quarry_outputs_0183()
  local outputs = {}
  local seen = {}
  local function add(name)
    if name and not seen[name] and get_item_prototype(name) then
      local recipe_name = tech_priests_emergency_miner_recipe_name_for_item_0250(name)
      if get_recipe_prototype_safe(recipe_name) then
        seen[name] = true
        table.insert(outputs, name)
      end
    end
  end

  -- Keep the basic survival order stable and understandable.
  add("wood")
  add("stone")
  add("iron-ore")
  add("copper-ore")
  add("coal")
  add("uranium-ore")

  local recipes = {}
  if prototypes then
    local ok, recipe_protos = pcall(function() return prototypes.recipe end)
    if ok and recipe_protos then recipes = recipe_protos end
  end
  -- Factorio 2.0 exposes prototype collections as LuaCustomTable/userdata in runtime.
  -- Calling next() on those directly crashes (table expected, got userdata), so probe
  -- emptiness with pairs() under pcall instead.
  local function tech_priests_has_any_recipe_proto_0288(collection)
    if not collection then return false end
    local ok, has_any = pcall(function()
      for _, _ in pairs(collection) do return true end
      return false
    end)
    return ok and has_any
  end
  if (not tech_priests_has_any_recipe_proto_0288(recipes)) and tech_priests_prototype_table_0440 then
    recipes = tech_priests_prototype_table_0440("recipe") or {}
  end
  local ok_iter, iter_err = pcall(function()
    for recipe_name, recipe in pairs(recipes or {}) do
      if type(recipe_name) == "string" and string.sub(recipe_name, 1, #TECH_PRIESTS_EMERGENCY_MINING_RECIPE_PREFIX_0250) == TECH_PRIESTS_EMERGENCY_MINING_RECIPE_PREFIX_0250 then
        add(tech_priests_emergency_miner_recipe_output_0250(recipe))
      end
    end
  end)
  if not ok_iter then
    pcall(function() log("[Tech-Priests 0.1.288] quarry recipe prototype scan skipped: " .. tostring(iter_err)) end)
  end
  return outputs
end

-- 0.1.288 crash guard: the old body below used to continue the loop directly.
-- It is intentionally bypassed by the safe pcall loop above.
--[[
  for recipe_name, recipe in pairs(recipes or {}) do
    if type(recipe_name) == "string" and string.sub(recipe_name, 1, #TECH_PRIESTS_EMERGENCY_MINING_RECIPE_PREFIX_0250) == TECH_PRIESTS_EMERGENCY_MINING_RECIPE_PREFIX_0250 then
      add(tech_priests_emergency_miner_recipe_output_0250(recipe))
    end
  end
  return outputs
end
]]

function tech_priests_set_emergency_miner_recipe_0250(entity, item_name)
  if not (entity and entity.valid and item_name) then return false end
  local recipe_name = tech_priests_emergency_miner_recipe_name_for_item_0250(item_name)
  if not get_recipe_prototype_safe(recipe_name) then return false end
  local ok, result = pcall(function()
    if entity.set_recipe then return entity.set_recipe(recipe_name) end
    return false
  end)
  if ok then
    pcall(function() entity.active = true end)
    return true
  end
  return false
end

function tech_priests_get_emergency_miner_current_recipe_0250(entity)
  if not (entity and entity.valid and entity.get_recipe) then return nil end
  local ok, recipe = pcall(function() return entity.get_recipe() end)
  if ok and recipe then
    if type(recipe) == "string" then return recipe end
    return recipe.name
  end
  return nil
end

function tech_priests_register_emergency_miner_0183(entity)
  if not (entity and entity.valid and entity.name == TECH_PRIESTS_EMERGENCY_MINER_NAME and entity.unit_number) then return end
  tech_priests_ensure_emergency_quarry_storage_0183()
  local existing = storage.tech_priests.emergency_quarry_miners[entity.unit_number] or {}
  existing.entity = entity
  existing.mode = existing.mode or TECH_PRIESTS_EMERGENCY_QUARRY_MODE_AUTO
  existing.recipe_index = existing.recipe_index or 0
  existing.next_quarry_tick = existing.next_quarry_tick or (game.tick + 60 + (entity.unit_number % 180))
  storage.tech_priests.emergency_quarry_miners[entity.unit_number] = existing

  local current = tech_priests_get_emergency_miner_current_recipe_0250(entity)
  if not (current and string.sub(current, 1, #TECH_PRIESTS_EMERGENCY_MINING_RECIPE_PREFIX_0250) == TECH_PRIESTS_EMERGENCY_MINING_RECIPE_PREFIX_0250) then
    local outputs = tech_priests_get_quarry_outputs_0183()
    if outputs and #outputs > 0 then
      existing.recipe_index = ((existing.recipe_index or 0) % #outputs) + 1
      tech_priests_set_emergency_miner_recipe_0250(entity, outputs[existing.recipe_index])
    end
  end
end

function tech_priests_update_emergency_miner_active_state_0183(record)
  if not (record and record.entity and record.entity.valid) then return end
  -- The pseudo-miner should remain active whenever it has a valid hidden recipe.
  -- Patch/quarry/auto are now doctrine labels for recipe rotation, not true
  -- drill-vs-quarry physics.
  pcall(function() record.entity.active = true end)
end

function tech_priests_service_emergency_quarry_miners_0183()
  if not (storage and storage.tech_priests and storage.tech_priests.emergency_quarry_miners) then return end
  local outputs = tech_priests_get_quarry_outputs_0183()
  if not outputs or #outputs == 0 then return end
  for unit, record in pairs(storage.tech_priests.emergency_quarry_miners) do
    local entity = record.entity
    if not (entity and entity.valid) then
      storage.tech_priests.emergency_quarry_miners[unit] = nil
    elseif not tech_priests_surface_is_planetside_0183(entity.surface, entity.position) then
      pcall(function() entity.active = false end)
    else
      tech_priests_update_emergency_miner_active_state_0183(record)
      local current = tech_priests_get_emergency_miner_current_recipe_0250(entity)
      local current_is_emergency = current and string.sub(current, 1, #TECH_PRIESTS_EMERGENCY_MINING_RECIPE_PREFIX_0250) == TECH_PRIESTS_EMERGENCY_MINING_RECIPE_PREFIX_0250
      if not current_is_emergency then
        record.recipe_index = ((record.recipe_index or 0) % #outputs) + 1
        tech_priests_set_emergency_miner_recipe_0250(entity, outputs[record.recipe_index])
        record.next_quarry_tick = game.tick + TECH_PRIESTS_EMERGENCY_QUARRY_INTERVAL_TICKS + (unit % 90)
      elseif game.tick >= (record.next_quarry_tick or 0) then
        -- 0.1.567: do not rotate/cycle the Micro-Miner recipe behind the
        -- player's back.  The miner now has a real recipe selector; once a
        -- valid pseudo-mining recipe is set, runtime only keeps the machine
        -- active and records cadence.  A missing/invalid recipe above still
        -- receives one safe default.
        record.next_quarry_tick = game.tick + TECH_PRIESTS_EMERGENCY_QUARRY_INTERVAL_TICKS + (unit % 90)
      end
    end
  end
end

function tech_priests_debug_emergency_miner_0250(player, entity)
  if not (player and player.valid) then return end
  if not (entity and entity.valid and entity.name == TECH_PRIESTS_EMERGENCY_MINER_NAME) then
    player.print("[Tech Priests] Select a Martian Emergency Micro-Miner first.")
    return
  end
  tech_priests_register_emergency_miner_0183(entity)
  local record = storage.tech_priests.emergency_quarry_miners and storage.tech_priests.emergency_quarry_miners[entity.unit_number]
  local outputs = tech_priests_get_quarry_outputs_0183()
  player.print("[Tech Priests] Emergency Micro-Miner pseudo-mining debug:")
  player.print("  unit=" .. tostring(entity.unit_number) .. " mode=" .. tostring(record and record.mode or "nil"))
  player.print("  recipe=" .. tostring(tech_priests_get_emergency_miner_current_recipe_0250(entity)))
  player.print("  recipe outputs available=" .. tostring(outputs and #outputs or 0))
  if outputs and #outputs > 0 then
    local preview = {}
    for i = 1, math.min(#outputs, 12) do preview[#preview + 1] = outputs[i] end
    player.print("  first outputs=" .. table.concat(preview, ", "))
  end
end

function on_built(event)
  local entity = event.entity or event.created_entity or event.destination
  if tech_priests_reject_martian_emergency_space_build_0183(entity, event and event.player_index) then return end
  if is_station(entity) then
    create_pair(entity)
  end
  register_void_fusion_thruster(entity)
  register_consecration_target(entity)
  tech_priests_register_emergency_miner_0183(entity)
end

function on_removed(event)
  local entity = event.entity
  if is_station(entity) or is_priest(entity) then
    remove_pair_for_entity(entity, event)
  end
  unregister_void_fusion_thruster(entity)
  remove_consecration_target(entity)
  tech_priests_unregister_emergency_miner_0183(entity)
end


function is_cogitator_logistic_requisition_enabled(force)
  if not (force and force.valid) then return false end
  local technology = force.technologies and force.technologies[COGITATOR_LOGISTIC_REQUISITION_TECH]
  return technology and technology.researched
end

function get_station_logistic_network(station)
  if not (station and station.valid and station.surface and station.force) then return nil end
  local ok, network = pcall(function()
    return station.surface.find_logistic_network_by_position(station.position, station.force)
  end)
  if ok and network then return network end
  return nil
end

function logistic_network_item_count(network, stack)
  if not network then return 0 end
  local query = make_item_stack_identification(stack.name, 1, stack.quality)
  local ok, count = pcall(function() return network.get_item_count(query) end)
  if ok and type(count) == "number" then return count end
  ok, count = pcall(function() return network.get_item_count(stack.name) end)
  if ok and type(count) == "number" then return count end
  return 0
end

function remove_item_from_logistic_network(network, stack)
  if not network then return 0 end
  local request = make_item_stack_identification(stack.name, stack.count or 1, stack.quality)
  local ok, removed = pcall(function() return network.remove_item(request) end)
  if ok then
    if type(removed) == "number" then return removed end
    if type(removed) == "table" and removed.count then return removed.count end
    return request.count or 1
  end
  return 0
end

function insert_from_logistic_network_into_inventory(network, inventory, stack)
  if not (network and inventory and stack and stack.name and (stack.count or 0) > 0) then return 0 end
  local available = logistic_network_item_count(network, stack)
  if available <= 0 then return 0 end

  local request = make_item_stack_identification(stack.name, math.min(stack.count, available), stack.quality)
  if not inventory.can_insert(request) then return 0 end

  local removed = remove_item_from_logistic_network(network, request)
  if removed <= 0 then return 0 end

  local insert_stack = make_item_stack_identification(stack.name, removed, stack.quality)
  local inserted = inventory.insert(insert_stack)
  if inserted < removed then
    local remainder = make_item_stack_identification(stack.name, removed - inserted, stack.quality)
    pcall(function() network.insert(remainder) end)
  end
  return inserted
end

function count_station_consecration_items(station)
  local inventory = get_station_inventory(station)
  if not inventory then return 0 end
  local count = 0
  for _, option in pairs(get_station_consecration_item_options()) do
    count = count + inventory.get_item_count(option.name)
  end
  return count
end

function count_station_ammo_items(station)
  local inventory = get_station_inventory(station)
  if not inventory then return 0 end
  local count = 0
  for index = 1, #inventory do
    local stack = inventory[index]
    if stack and stack.valid_for_read and is_ammo_item(stack.name) then
      count = count + stack.count
    end
  end
  return count
end

function get_item_order_key(item_name)
  local prototype = get_item_prototype(item_name)
  if not prototype then return "" end
  local subgroup_order = ""
  pcall(function()
    if prototype.subgroup and prototype.subgroup.order then
      subgroup_order = prototype.subgroup.order
    end
  end)
  local order = ""
  pcall(function() order = prototype.order or "" end)
  return subgroup_order .. "/" .. order .. "/" .. item_name
end

function get_ammo_preference_score(item_name)
  local score = 0
  local lower = string.lower(item_name or "")
  if string.find(lower, "uranium", 1, true) then score = score + 300000 end
  if string.find(lower, "piercing", 1, true) then score = score + 200000 end
  if string.find(lower, "firearm", 1, true) then score = score + 100000 end
  -- Preserve broad mod compatibility by using prototype order as a stable
  -- tie-breaker. Vanilla firearm magazine ordering naturally progresses from
  -- basic to piercing to uranium, while modded ammo still gets a deterministic
  -- highest-available choice.
  local key = get_item_order_key(item_name)
  for i = 1, math.min(#key, 40) do
    score = score + string.byte(key, i) / (1000 + i)
  end
  return score
end

function iter_item_prototypes()
  if prototypes then
    local ok, item_prototypes = pcall(function() return prototypes.item end)
    if ok and item_prototypes then return item_prototypes end
  end

  if tech_priests_prototype_table_0440 then
    return tech_priests_prototype_table_0440("item") or {}
  end

  return {}
end

function force_can_reasonably_use_item(force, item_name)
  if not (force and force.valid and item_name) then return false end
  local recipe = force.recipes and force.recipes[item_name]
  if recipe and recipe.enabled then return true end
  -- Items may also arrive through modded loot, trade, or orbital import chains.
  -- If they are already in the logistics network, availability is enough.
  return true
end

function find_best_logistic_ammo_for_station(pair, network, inventory)
  if not (pair and network and inventory) then return nil end
  local proxy = ensure_proxy(pair)
  if not (proxy and proxy.valid) then return nil end
  local proxy_inventory = get_turret_ammo_inventory(proxy)
  if not proxy_inventory then return nil end

  local best = nil
  local best_score = nil
  for item_name, prototype in pairs(iter_item_prototypes()) do
    if prototype and prototype.type == "ammo" and force_can_reasonably_use_item(pair.station.force, item_name) then
      local stack = { name = item_name, count = 1 }
      if logistic_network_item_count(network, stack) > 0 and proxy_inventory.can_insert(stack) and inventory.can_insert(stack) then
        local score = get_ammo_preference_score(item_name)
        if not best_score or score > best_score then
          best = item_name
          best_score = score
        end
      end
    end
  end
  return best
end

function request_repair_supplies_from_logistics(pair, network, inventory)
  local current = inventory.get_item_count("repair-pack")
  if current >= LOGISTIC_REQUISITION_REPAIR_TARGET_STOCK then return 0 end
  return insert_from_logistic_network_into_inventory(network, inventory, {
    name = "repair-pack",
    count = LOGISTIC_REQUISITION_REPAIR_TARGET_STOCK - current
  })
end

function request_consecration_supplies_from_logistics(pair, network, inventory)
  if count_station_consecration_items(pair.station) >= LOGISTIC_REQUISITION_CONSECRATION_TARGET_STOCK then return 0 end
  for _, option in pairs(get_station_consecration_item_options()) do
    if logistic_network_item_count(network, { name = option.name, count = 1 }) > 0 then
      return insert_from_logistic_network_into_inventory(network, inventory, { name = option.name, count = 1 })
    end
  end
  return 0
end

function request_ammo_supplies_from_logistics(pair, network, inventory)
  if count_station_ammo_items(pair.station) >= LOGISTIC_REQUISITION_AMMO_TARGET_STOCK then return 0 end
  local ammo_name = find_best_logistic_ammo_for_station(pair, network, inventory)
  if not ammo_name then return 0 end
  local missing = LOGISTIC_REQUISITION_AMMO_TARGET_STOCK - count_station_ammo_items(pair.station)
  return insert_from_logistic_network_into_inventory(network, inventory, {
    name = ammo_name,
    count = math.min(LOGISTIC_REQUISITION_AMMO_BATCH_SIZE, math.max(1, missing))
  })
end

function station_has_enemy_pressure(pair)
  if not (pair and pair.station and pair.station.valid) then return false end
  local target = pair.combat_target
  if target and enemy_inside_station_radius(pair.station, target, refresh_pair_radius(pair)) then return true end
  local enemy = find_enemy_target(pair.station, refresh_pair_radius(pair), pair.priest)
  return enemy ~= nil
end



function clear_logistic_frustration(pair)
  if not pair then return end
  pair.logistic_frustration_kind = nil
  pair.logistic_frustration_start_tick = nil
  pair.logistic_frustration_due_tick = nil
  pair.logistic_requested_item = nil
  pair.logistic_requested_count = nil
  pair.next_scavenge_search_tick = nil
  pair.logistic_cram_start_tick = nil
  pair.logistic_cram_due_tick = nil
  pair.next_cram_search_tick = nil
  pair.cram_search_started_tick = nil
  pair.cram_dump_due_tick = nil
end

function get_consecration_request_candidates_for_target(station, target)
  local candidates = {}
  local missing = nil
  if target and target.valid then
    local record = get_consecration_record(target)
    if record then
      local maximum = record.max_sanctification or get_base_sanctification_max(target.force)
      local current = record.sanctification or 0
      missing = math.max(0, maximum - current)
    end
  end
  for _, option in pairs(get_station_consecration_item_options()) do
    if not missing or missing <= 0 or option.amount <= missing then
      candidates[#candidates + 1] = { name = option.name, count = 1, score = option.amount or 0 }
    end
  end
  if #candidates == 0 then
    for _, option in pairs(get_station_consecration_item_options()) do
      candidates[#candidates + 1] = { name = option.name, count = 1, score = option.amount or 0 }
    end
  end
  return candidates
end

function build_supply_request(pair, kind, target)
  if not (pair and pair.station and pair.station.valid) then return nil end
  if kind == "repair" then
    return { kind = kind, candidates = { { name = "repair-pack", count = 1, score = 1 } } }
  end
  if kind == "consecration" then
    return { kind = kind, candidates = get_consecration_request_candidates_for_target(pair.station, target or pair.target) }
  end
  if kind == "ammo" then
    return { kind = kind, candidates = nil, count = LOGISTIC_SCAVENGE_ITEM_BATCH_SIZE }
  end
  return nil
end

function is_scavenge_inventory_id_allowed(inventory_id)
  return inventory_id ~= nil
end

function get_scavenge_inventory_ids()
  local ids = {}
  local inv = defines and defines.inventory
  if not inv then return ids end
  local names = {
    "chest",
    "cargo_wagon",
    "car_trunk",
    "spider_trunk",
    "assembling_machine_output",
    "furnace_result",
    "assembling_machine_input",
    "furnace_source",
    "lab_input",
    -- Space Age asteroid collectors keep their caught chunks in dedicated
    -- inventories. Without these, emergency crafting priests can beam the
    -- collector all day and never withdraw the asteroid material they need.
    "asteroid_collector_output",
    "asteroid_collector_arm",
    "hub_main",
    "cargo_landing_pad_main"
  }
  local seen = {}
  for _, name in pairs(names) do
    if inv[name] ~= nil and not seen[inv[name]] then
      ids[#ids + 1] = inv[name]
      seen[inv[name]] = true
    end
  end
  -- Future-proofing for Space Age/minor-version inventory additions: include
  -- any explicitly named asteroid/collector inventory defined by the engine.
  for name, id in pairs(inv) do
    if type(name) == "string" and id ~= nil and not seen[id] then
      local lower = string.lower(name)
      if string.find(lower, "asteroid", 1, true) or string.find(lower, "collector", 1, true) then
        ids[#ids + 1] = id
        seen[id] = true
      end
    end
  end
  return ids
end

function get_entity_inventory_safe(entity, inventory_id)
  if not (entity and entity.valid and inventory_id) then return nil end
  local ok, inventory = pcall(function() return entity.get_inventory(inventory_id) end)
  if ok and inventory and inventory.valid then return inventory end
  return nil
end

function inventory_has_insertable_request_item(pair, inventory, request)
  if not (pair and inventory and request) then return nil end
  local station_inventory = get_station_inventory(pair.station)
  if not station_inventory then return nil end

  if request.kind == "ammo" then
    local proxy = ensure_proxy(pair)
    local proxy_inventory = get_turret_ammo_inventory(proxy)
    if not proxy_inventory then return nil end
    local best = nil
    local best_score = nil
    for index = 1, #inventory do
      local stack = inventory[index]
      if stack and stack.valid_for_read and is_ammo_item(stack.name) then
        local test_stack = { name = stack.name, count = 1 }
        if proxy_inventory.can_insert(test_stack) and station_inventory.can_insert(test_stack) then
          local score = get_ammo_preference_score(stack.name)
          if not best_score or score > best_score then
            best = { name = stack.name, count = math.min(get_item_stack_size(stack.name), stack.count), score = score }
            best_score = score
          end
        end
      end
    end
    return best
  end

  for _, candidate in pairs(request.candidates or {}) do
    local available = inventory.get_item_count(candidate.name)
    if available > 0 and station_inventory.can_insert({ name = candidate.name, count = 1 }) then
      return { name = candidate.name, count = math.min(get_item_stack_size(candidate.name), available), score = candidate.score or 0 }
    end
  end
  return nil
end

function find_scavenge_source_for_request(pair, request)
  if not (pair and pair.station and pair.station.valid and request) then return nil end
  local station = pair.station
  local priest = pair.priest
  local radius = refresh_pair_radius(pair)
  local position = station.position
  local area = {
    { position.x - radius, position.y - radius },
    { position.x + radius, position.y + radius }
  }
  local ids = get_scavenge_inventory_ids()
  local best = nil
  local best_score = nil
  local entities = station.surface.find_entities_filtered({ area = area, force = station.force })

  for _, entity in pairs(entities) do
    if entity.valid and entity ~= station and entity.name ~= PROXY_NAME and not is_priest(entity) then
      local sdx = entity.position.x - position.x
      local sdy = entity.position.y - position.y
      local station_distance_sq = sdx * sdx + sdy * sdy
      if station_distance_sq <= radius * radius then
        for _, inventory_id in pairs(ids) do
          local inventory = get_entity_inventory_safe(entity, inventory_id)
          local found = inventory_has_insertable_request_item(pair, inventory, request)
          if found then
            local score_distance = station_distance_sq
            if priest and priest.valid then
              local pdx = entity.position.x - priest.position.x
              local pdy = entity.position.y - priest.position.y
              score_distance = math.min(score_distance, pdx * pdx + pdy * pdy)
            end
            local item_bonus = (found.score or 0) * 0.0001
            local score = score_distance - item_bonus
            if not best_score or score < best_score then
              best_score = score
              best = { source = entity, inventory_id = inventory_id, item_name = found.name, count = found.count or 1, kind = request.kind }
            end
          end
        end
      end
    end
  end

  return best
end

function try_withdraw_scavenge_item(pair)
  if not (pair and pair.station and pair.station.valid and pair.scavenge and pair.scavenge.source and pair.scavenge.source.valid) then return false end
  local source = pair.scavenge.source
  local inventory = get_entity_inventory_safe(source, pair.scavenge.inventory_id)
  local station_inventory = get_station_inventory(pair.station)
  if not (inventory and station_inventory) then return false end

  local item_name = pair.scavenge.item_name
  local requested = math.max(1, pair.scavenge.count or 1)
  local available = inventory.get_item_count(item_name)
  if available <= 0 then return false end
  local count = math.min(requested, available, get_item_stack_size(item_name))
  count = get_insertable_item_count(station_inventory, item_name, count, pair.scavenge.quality)
  if count <= 0 then return false end

  local removed = inventory.remove(make_item_stack_identification(item_name, count, pair.scavenge.quality))
  if removed <= 0 then return false end
  local inserted = station_inventory.insert(make_item_stack_identification(item_name, removed, pair.scavenge.quality))
  if inserted < removed then
    inventory.insert(make_item_stack_identification(item_name, removed - inserted, pair.scavenge.quality))
  end
  if inserted > 0 then
    pair.mode = "returning"
    pair.target = nil
    pair.scavenge = nil
    clear_logistic_frustration(pair)
    return_to_station(pair.priest, pair.station)
    return true
  end
  return false
end

function handle_priest_scavenge_task(pair)
  if not (pair and pair.priest and pair.priest.valid and pair.station and pair.station.valid and pair.scavenge) then return false end
  local priest = pair.priest
  local source = pair.scavenge.source
  if not (source and source.valid) then
    pair.scavenge = nil
    pair.next_scavenge_search_tick = game.tick + LOGISTIC_SCAVENGE_RETRY_TICKS
    return false
  end

  local dx = priest.position.x - source.position.x
  local dy = priest.position.y - source.position.y
  if dx * dx + dy * dy > LOGISTIC_SCAVENGE_PICKUP_DISTANCE_SQ then
    move_priest_to(priest, source)
    pair.mode = "moving-to-scavenge"
    pair.target = source
    return true
  end

  if try_withdraw_scavenge_item(pair) then
    return true
  end

  pair.scavenge = nil
  pair.next_scavenge_search_tick = game.tick + LOGISTIC_SCAVENGE_RETRY_TICKS
  return false
end



function request_has_station_space(pair, request)
  if not (pair and pair.station and pair.station.valid and request) then return false end
  local inventory = get_station_inventory(pair.station)
  if not inventory then return false end
  if request.kind == "ammo" then
    local stack = choose_logistic_request_stack and choose_logistic_request_stack(pair, request) or nil
    if stack then return inventory.can_insert({ name = stack.name, count = 1 }) end
    return false
  end
  for _, candidate in pairs(request.candidates or {}) do
    if inventory.can_insert({ name = candidate.name, count = 1 }) then return true end
  end
  return false
end

function find_unwanted_station_stack_for_request(pair, request)
  if not (pair and pair.station and pair.station.valid and request) then return nil end
  local inventory = get_station_inventory(pair.station)
  if not inventory then return nil end
  for i = 1, #inventory do
    local stack = inventory[i]
    if stack and stack.valid_for_read and not item_matches_logistic_request(stack.name, request) then
      return { name = stack.name, count = math.min(get_item_stack_size(stack.name), stack.count), quality = get_stack_quality_name(stack) }
    end
  end
  return nil
end

function find_cram_destination_for_item(pair, item)
  if not (pair and pair.station and pair.station.valid and item and item.name) then return nil end
  local station = pair.station
  local radius = refresh_pair_radius(pair)
  local position = station.position
  local area = {{position.x - radius, position.y - radius}, {position.x + radius, position.y + radius}}
  local ids = get_scavenge_inventory_ids()
  local best = nil
  local best_score = nil
  local entities = station.surface.find_entities_filtered({ area = area, force = station.force })
  for _, entity in pairs(entities) do
    if entity.valid and entity ~= station and entity.name ~= PROXY_NAME and entity.name ~= LOGISTIC_REQUESTER_CACHE_NAME and entity.name ~= LOGISTIC_RETURN_CACHE_NAME and not is_priest(entity) then
      local sdx = entity.position.x - position.x
      local sdy = entity.position.y - position.y
      local station_distance_sq = sdx * sdx + sdy * sdy
      if station_distance_sq <= radius * radius then
        for _, inventory_id in pairs(ids) do
          local inventory = get_entity_inventory_safe(entity, inventory_id)
          if inventory and inventory.can_insert(make_item_stack_identification(item.name, 1, item.quality)) then
            local score = station_distance_sq
            if pair.priest and pair.priest.valid then
              local pdx = entity.position.x - pair.priest.position.x
              local pdy = entity.position.y - pair.priest.position.y
              score = math.min(score, pdx * pdx + pdy * pdy)
            end
            if not best_score or score < best_score then
              best_score = score
              best = { destination = entity, inventory_id = inventory_id, item_name = item.name, count = item.count or 1, quality = item.quality }
            end
          end
        end
      end
    end
  end
  return best
end

function try_deposit_cram_item(pair)
  if not (pair and pair.station and pair.station.valid and pair.cram and pair.cram.destination and pair.cram.destination.valid) then return false end
  local station_inventory = get_station_inventory(pair.station)
  local destination_inventory = get_entity_inventory_safe(pair.cram.destination, pair.cram.inventory_id)
  if not (station_inventory and destination_inventory) then return false end
  local item_name = pair.cram.item_name
  local count = math.min(math.max(1, pair.cram.count or 1), get_item_stack_size(item_name))
  count = get_insertable_item_count(destination_inventory, item_name, count, pair.cram.quality)
  if count <= 0 then return false end
  local removed = station_inventory.remove(make_item_stack_identification(item_name, count, pair.cram.quality))
  if removed <= 0 then return false end
  local inserted = destination_inventory.insert(make_item_stack_identification(item_name, removed, pair.cram.quality))
  if inserted < removed then
    station_inventory.insert(make_item_stack_identification(item_name, removed - inserted, pair.cram.quality))
  end
  if inserted > 0 then
    pair.mode = "returning"
    pair.target = nil
    pair.cram = nil
    pair.logistic_cram_start_tick = nil
    pair.logistic_cram_due_tick = nil
    return_to_station(pair.priest, pair.station)
    return true
  end
  return false
end
