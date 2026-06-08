-- Tech Priests 0.1.258
-- Magos placement contamination safety and machine-detritus jam clearing.
--
-- This late-loaded layer adds two guardrails to the standard-industry/Magos
-- construction planner:
--   * pipes are not placed adjacent to pipe/fluid runs with a different known
--     or planned fluid;
--   * belts are treated as single-item arteries, so known belt arteries with
--     different item plans do not get cross-connected.
-- It also adds a sweep-fed maintenance task that clears Mechanical Detritus from
-- jammed machines and moves it to a nearby container or smelter.

TECH_PRIESTS_PLACEMENT_SAFETY_VERSION_0258 = "0.1.258"
TECH_PRIESTS_DETRITUS_ITEM_0258 = MECHANICAL_DETRITUS_NAME or "mechanical-detritus"
TECH_PRIESTS_JAM_CLEAR_REACH_SQ_0258 = 3.0 * 3.0
TECH_PRIESTS_JAM_DISPOSE_REACH_SQ_0258 = 3.0 * 3.0
TECH_PRIESTS_JAM_TASK_TIMEOUT_TICKS_0258 = 60 * 30

function tech_priests_0258_diag(message)
  if tech_priests_0246_diag_line then
    tech_priests_0246_diag_line("0.1.258 " .. tostring(message))
  elseif log then
    log("[Tech Priests 0.1.258] " .. tostring(message))
  end
end

local function tech_priests_0258_ensure_storage()
  if ensure_storage then pcall(ensure_storage) end
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests.placement_safety_0258 = storage.tech_priests.placement_safety_0258 or { fluid_runs = {}, belt_arteries = {} }
  return storage.tech_priests.placement_safety_0258
end

local function tech_priests_0258_surface_key(surface)
  return tostring(surface and surface.index or "?")
end

local function tech_priests_0258_tile_key(position)
  if not position then return "?" end
  return tostring(math.floor(position.x or 0)) .. ":" .. tostring(math.floor(position.y or 0))
end

local function tech_priests_0258_entity_type(name)
  local proto = tech_priests_get_entity_prototype_0440 and tech_priests_get_entity_prototype_0440(name) or nil
  if not proto then return nil end
  local ok, typ = pcall(function() return proto.type end)
  if ok then return typ end
  return nil
end

local function tech_priests_0258_is_pipe_entity_name(name)
  local typ = tech_priests_0258_entity_type(name)
  if typ == "pipe" or typ == "pipe-to-ground" then return true end
  if name == "pipe" or name == "pipe-to-ground" then return true end
  return false
end

local function tech_priests_0258_is_belt_entity_name(name)
  local typ = tech_priests_0258_entity_type(name)
  return typ == "transport-belt" or typ == "underground-belt" or typ == "splitter" or name == "transport-belt"
end

local function tech_priests_0258_entity_fluid_names(entity)
  local result = {}
  if not (entity and entity.valid) then return result end
  local ok_fb, fb = pcall(function() return entity.fluidbox end)
  if not (ok_fb and fb) then return result end
  local ok_len, len = pcall(function() return #fb end)
  if not ok_len then len = 0 end
  for i = 1, len do
    local ok_fluid, fluid = pcall(function() return fb[i] end)
    if ok_fluid and fluid and fluid.name then result[fluid.name] = true end
  end
  return result
end

local function tech_priests_0258_single_key(t)
  local found = nil
  local count = 0
  for k, v in pairs(t or {}) do
    if v then found = k; count = count + 1 end
  end
  if count == 1 then return found end
  return nil
end

local function tech_priests_0258_planned_fluid(pair, entity_name, position)
  local op = pair and (pair.independent_emergency_operation_0184 or (tech_priests_get_emergency_operation_0184 and tech_priests_get_emergency_operation_0184(pair))) or nil
  if op then
    if op.magos_pipe_fluid_0258 then return op.magos_pipe_fluid_0258 end
    if op.construction and op.construction.planned_fluid_0258 then return op.construction.planned_fluid_0258 end
    if op.magos_ratio_plan_0257 and op.magos_ratio_plan_0257.fluids then
      local one = tech_priests_0258_single_key(op.magos_ratio_plan_0257.fluids)
      if one then return one end
    end
  end
  return nil
end

local function tech_priests_0258_planned_belt_item(pair, entity_name, position)
  local op = pair and (pair.independent_emergency_operation_0184 or (tech_priests_get_emergency_operation_0184 and tech_priests_get_emergency_operation_0184(pair))) or nil
  if op then
    if op.magos_belt_item_0258 then return op.magos_belt_item_0258 end
    if op.construction and op.construction.planned_item_0258 then return op.construction.planned_item_0258 end
    if op.magos_ratio_item_0257 and op.magos_ratio_item_0257 ~= entity_name then return op.magos_ratio_item_0257 end
    if op.magos_ratio_plan_0257 and op.magos_ratio_plan_0257.objective then return op.magos_ratio_plan_0257.objective end
    if op.science_item then return op.science_item end
  end
  return nil
end

local function tech_priests_0258_adjacent_entities(surface, position)
  if not (surface and position) then return {} end
  local area = {{position.x - 1.25, position.y - 1.25}, {position.x + 1.25, position.y + 1.25}}
  local ok, entities = pcall(function() return surface.find_entities_filtered({ area = area }) end)
  if ok and entities then return entities end
  return {}
end

local function tech_priests_0258_stored_fluid_for_entity(entity)
  if not (entity and entity.valid and entity.surface) then return nil end
  local store = tech_priests_0258_ensure_storage()
  local sk = tech_priests_0258_surface_key(entity.surface)
  local by_surface = store.fluid_runs[sk] or {}
  local rec = by_surface[tech_priests_0258_tile_key(entity.position)]
  return rec and rec.fluid or nil
end

local function tech_priests_0258_stored_belt_item_for_entity(entity)
  if not (entity and entity.valid and entity.surface) then return nil end
  local store = tech_priests_0258_ensure_storage()
  local sk = tech_priests_0258_surface_key(entity.surface)
  local by_surface = store.belt_arteries[sk] or {}
  local rec = by_surface[tech_priests_0258_tile_key(entity.position)]
  return rec and rec.item or nil
end

local function tech_priests_0258_belt_contents_item(entity)
  if not (entity and entity.valid) then return nil, false end
  local seen = {}
  for line_index = 1, 2 do
    local ok_line, line = pcall(function()
      if entity.get_transport_line then return entity.get_transport_line(line_index) end
      return nil
    end)
    if ok_line and line then
      local ok_contents, contents = pcall(function() return line.get_contents() end)
      if ok_contents and contents then
        for name, count in pairs(contents) do if count and count > 0 then seen[name] = true end end
      end
    end
  end
  local one = tech_priests_0258_single_key(seen)
  local multi = false
  local c = 0
  for _, v in pairs(seen) do if v then c = c + 1 end end
  if c > 1 then multi = true end
  return one, multi
end

function tech_priests_0258_pipe_position_safe(pair, entity_name, position)
  if not (pair and pair.station and pair.station.valid and position) then return true end
  if not tech_priests_0258_is_pipe_entity_name(entity_name) then return true end
  local planned = tech_priests_0258_planned_fluid(pair, entity_name, position)
  local conflicts = {}
  for _, entity in pairs(tech_priests_0258_adjacent_entities(pair.station.surface, position)) do
    if entity and entity.valid and entity.force == pair.station.force and tech_priests_0258_is_pipe_entity_name(entity.name) then
      local known = tech_priests_0258_stored_fluid_for_entity(entity)
      local fluids = tech_priests_0258_entity_fluid_names(entity)
      if not known then known = tech_priests_0258_single_key(fluids) end
      if planned and known and planned ~= known then conflicts[#conflicts + 1] = entity.name .. "=" .. known end
      if not planned then
        local fluid_count = 0
        for _ in pairs(fluids) do fluid_count = fluid_count + 1 end
        if fluid_count > 1 then conflicts[#conflicts + 1] = entity.name .. "=mixed" end
      end
    end
  end
  if #conflicts > 0 then
    local op = pair.independent_emergency_operation_0184
    if op then op.placement_block_reason_0258 = "pipe-fluid-conflict " .. table.concat(conflicts, ",") end
    return false
  end
  return true
end

function tech_priests_0258_belt_position_safe(pair, entity_name, position)
  if not (pair and pair.station and pair.station.valid and position) then return true end
  if not tech_priests_0258_is_belt_entity_name(entity_name) then return true end
  local planned = tech_priests_0258_planned_belt_item(pair, entity_name, position)
  local conflicts = {}
  for _, entity in pairs(tech_priests_0258_adjacent_entities(pair.station.surface, position)) do
    if entity and entity.valid and entity.force == pair.station.force and tech_priests_0258_is_belt_entity_name(entity.name) then
      local known = tech_priests_0258_stored_belt_item_for_entity(entity)
      local content_item, mixed = tech_priests_0258_belt_contents_item(entity)
      if not known then known = content_item end
      if mixed then conflicts[#conflicts + 1] = entity.name .. "=mixed-live-belt" end
      if planned and known and planned ~= known then conflicts[#conflicts + 1] = entity.name .. "=" .. known end
    end
  end
  if #conflicts > 0 then
    local op = pair.independent_emergency_operation_0184
    if op then op.placement_block_reason_0258 = "belt-artery-conflict " .. table.concat(conflicts, ",") end
    return false
  end
  return true
end

function tech_priests_0258_register_constructed_artery(pair, entity, task)
  if not (pair and entity and entity.valid and entity.surface) then return end
  local store = tech_priests_0258_ensure_storage()
  local sk = tech_priests_0258_surface_key(entity.surface)
  if tech_priests_0258_is_pipe_entity_name(entity.name) then
    local fluid = (task and task.planned_fluid_0258) or tech_priests_0258_planned_fluid(pair, entity.name, entity.position)
    if fluid then
      store.fluid_runs[sk] = store.fluid_runs[sk] or {}
      store.fluid_runs[sk][tech_priests_0258_tile_key(entity.position)] = { fluid = fluid, unit = entity.unit_number, tick = game.tick }
    end
  elseif tech_priests_0258_is_belt_entity_name(entity.name) then
    local item = (task and task.planned_item_0258) or tech_priests_0258_planned_belt_item(pair, entity.name, entity.position)
    if item then
      store.belt_arteries[sk] = store.belt_arteries[sk] or {}
      store.belt_arteries[sk][tech_priests_0258_tile_key(entity.position)] = { item = item, unit = entity.unit_number, tick = game.tick }
    end
  end
end

if tech_priests_can_place_emergency_entity_at_0186 then
  TECH_PRIESTS_CAN_PLACE_EMERGENCY_ENTITY_AT_BEFORE_0258 = tech_priests_can_place_emergency_entity_at_0186
  function tech_priests_can_place_emergency_entity_at_0186(pair, entity_name, position)
    if not TECH_PRIESTS_CAN_PLACE_EMERGENCY_ENTITY_AT_BEFORE_0258(pair, entity_name, position) then return false end
    if not tech_priests_0258_pipe_position_safe(pair, entity_name, position) then return false end
    if not tech_priests_0258_belt_position_safe(pair, entity_name, position) then return false end
    return true
  end
end

if tech_priests_begin_emergency_construction_0186 then
  TECH_PRIESTS_BEGIN_EMERGENCY_CONSTRUCTION_BEFORE_0258 = tech_priests_begin_emergency_construction_0186
  function tech_priests_begin_emergency_construction_0186(pair, item_name, op)
    local ok = TECH_PRIESTS_BEGIN_EMERGENCY_CONSTRUCTION_BEFORE_0258(pair, item_name, op)
    if ok and op and op.construction then
      local entity_name = op.construction.entity_name
      if tech_priests_0258_is_pipe_entity_name(entity_name) then op.construction.planned_fluid_0258 = tech_priests_0258_planned_fluid(pair, entity_name, op.construction.position) end
      if tech_priests_0258_is_belt_entity_name(entity_name) then op.construction.planned_item_0258 = tech_priests_0258_planned_belt_item(pair, entity_name, op.construction.position) end
    end
    return ok
  end
end

if tech_priests_complete_emergency_construction_0186 then
  TECH_PRIESTS_COMPLETE_EMERGENCY_CONSTRUCTION_BEFORE_0258 = tech_priests_complete_emergency_construction_0186
  function tech_priests_complete_emergency_construction_0186(pair, op, task)
    local before_unit = task and task.position and pair and pair.station and pair.station.valid and task.entity_name and tech_priests_entity_exists_near_position_0186 and tech_priests_entity_exists_near_position_0186(pair, task.entity_name, task.position) or nil
    local result = TECH_PRIESTS_COMPLETE_EMERGENCY_CONSTRUCTION_BEFORE_0258(pair, op, task)
    if result and task and pair and pair.station and pair.station.valid then
      local entity = before_unit
      if not (entity and entity.valid) and tech_priests_entity_exists_near_position_0186 then entity = tech_priests_entity_exists_near_position_0186(pair, task.entity_name, task.position) end
      if entity and entity.valid then tech_priests_0258_register_constructed_artery(pair, entity, task) end
    end
    return result
  end
end

local function tech_priests_0258_inventory_detritus_count(inv)
  if not (inv and inv.valid) then return 0 end
  local ok, count = pcall(function() return inv.get_item_count(TECH_PRIESTS_DETRITUS_ITEM_0258) end)
  if ok and count then return count end
  return 0
end

local function tech_priests_0258_entity_detritus_count(entity)
  if not (entity and entity.valid) then return 0 end
  local total = 0
  if defines and defines.inventory then
    for _, inv_id in pairs(defines.inventory) do
      local ok, inv = pcall(function() return entity.get_inventory(inv_id) end)
      if ok and inv and inv.valid then total = total + tech_priests_0258_inventory_detritus_count(inv) end
    end
  end
  return total
end

local function tech_priests_0258_remove_detritus_from_entity(entity, max_count)
  if not (entity and entity.valid) then return 0 end
  local remaining = max_count or 1000000
  local removed_total = 0
  if defines and defines.inventory then
    for _, inv_id in pairs(defines.inventory) do
      if remaining <= 0 then break end
      local ok, inv = pcall(function() return entity.get_inventory(inv_id) end)
      if ok and inv and inv.valid then
        local count = tech_priests_0258_inventory_detritus_count(inv)
        if count > 0 then
          local take = math.min(count, remaining)
          local removed = inv.remove({ name = TECH_PRIESTS_DETRITUS_ITEM_0258, count = take }) or 0
          removed_total = removed_total + removed
          remaining = remaining - removed
        end
      end
    end
  end
  return removed_total
end

local function tech_priests_0258_can_dispose_into(entity)
  if not (entity and entity.valid) then return false end
  local typ = tech_priests_0258_entity_type(entity.name)
  return typ == "container" or typ == "logistic-container" or typ == "infinity-container" or typ == "furnace"
end

local function tech_priests_0258_find_disposal_entity(pair)
  if not (pair and pair.station and pair.station.valid) then return nil end
  local station = pair.station
  local radius = refresh_pair_radius and refresh_pair_radius(pair) or pair.radius or 25
  local candidates = station.surface.find_entities_filtered({ force = station.force, position = station.position, radius = radius }) or {}
  local best, best_score = nil, nil
  for _, entity in pairs(candidates) do
    if tech_priests_0258_can_dispose_into(entity) then
      local inv = nil
      if tech_priests_0258_entity_type(entity.name) == "furnace" then
        pcall(function() inv = entity.get_inventory(defines.inventory.furnace_source) end)
      else
        pcall(function() inv = entity.get_inventory(defines.inventory.chest) end)
      end
      if inv and inv.valid and inv.can_insert and inv.can_insert({ name = TECH_PRIESTS_DETRITUS_ITEM_0258, count = 1 }) then
        local score = tech_priests_distance_sq_0186 and tech_priests_distance_sq_0186(entity.position, station.position) or 0
        if not best_score or score < best_score then best, best_score = entity, score end
      end
    end
  end
  return best
end

local function tech_priests_0258_insert_detritus_into(entity, count)
  if not (entity and entity.valid and count and count > 0) then return 0 end
  local inv = nil
  if tech_priests_0258_entity_type(entity.name) == "furnace" then
    pcall(function() inv = entity.get_inventory(defines.inventory.furnace_source) end)
  else
    pcall(function() inv = entity.get_inventory(defines.inventory.chest) end)
  end
  if inv and inv.valid then return inv.insert({ name = TECH_PRIESTS_DETRITUS_ITEM_0258, count = count }) or 0 end
  return 0
end

local function tech_priests_0258_is_maintenance_machine(entity)
  if not (entity and entity.valid) then return false end
  local typ = tech_priests_0258_entity_type(entity.name)
  return typ == "assembling-machine" or typ == "furnace" or typ == "mining-drill" or typ == "lab" or typ == "rocket-silo" or typ == "generator" or typ == "boiler" or typ == "reactor"
end

function tech_priests_0258_consider_jam_target(pair, entity)
  if not (pair and entity and entity.valid and tech_priests_0258_is_maintenance_machine(entity)) then return end
  local count = tech_priests_0258_entity_detritus_count(entity)
  if count <= 0 then return end
  pair.sweep_0248 = pair.sweep_0248 or {}
  pair.sweep_0248.jam_targets_0258 = pair.sweep_0248.jam_targets_0258 or {}
  if tech_priests_0248_insert_candidate and pair.station and pair.station.valid then
    local score = tech_priests_0248_entity_score and tech_priests_0248_entity_score(entity, pair.station, pair.priest) or 0
    tech_priests_0248_insert_candidate(pair.sweep_0248.jam_targets_0258, entity, score)
  else
    pair.sweep_0248.jam_targets_0258[#pair.sweep_0248.jam_targets_0258 + 1] = { entity = entity, score = count, tick = game.tick }
  end
end

if tech_priests_0248_update_station_sweep then
  TECH_PRIESTS_UPDATE_STATION_SWEEP_BEFORE_0258 = tech_priests_0248_update_station_sweep
  function tech_priests_0248_update_station_sweep(pair)
    local sweep = TECH_PRIESTS_UPDATE_STATION_SWEEP_BEFORE_0258(pair)
    if not (pair and pair.station and pair.station.valid and sweep) then return sweep end
    sweep.jam_targets_0258 = tech_priests_0248_prune_cache_list and tech_priests_0248_prune_cache_list(sweep.jam_targets_0258) or (sweep.jam_targets_0258 or {})
    local radius = sweep.radius or (refresh_pair_radius and refresh_pair_radius(pair)) or pair.radius or 25
    local center = pair.station.position
    local angle = sweep.angle or 0
    local endpoint = { x = center.x + math.cos(angle) * radius, y = center.y + math.sin(angle) * radius }
    local minx, maxx = math.min(center.x, endpoint.x) - TECH_PRIESTS_SWEEP_WIDTH_0248, math.max(center.x, endpoint.x) + TECH_PRIESTS_SWEEP_WIDTH_0248
    local miny, maxy = math.min(center.y, endpoint.y) - TECH_PRIESTS_SWEEP_WIDTH_0248, math.max(center.y, endpoint.y) + TECH_PRIESTS_SWEEP_WIDTH_0248
    local ok, entities = pcall(function() return pair.station.surface.find_entities_filtered({ area = {{minx, miny}, {maxx, maxy}}, force = pair.station.force }) end)
    if ok and entities then
      for _, entity in pairs(entities) do
        if entity and entity.valid then tech_priests_0258_consider_jam_target(pair, entity) end
      end
    end
    return sweep
  end
end

function tech_priests_0258_first_jam_target(pair)
  if not (pair and pair.sweep_0248 and pair.sweep_0248.jam_targets_0258) then return nil end
  if tech_priests_0248_first_valid_from_cache then
    return tech_priests_0248_first_valid_from_cache(pair, "jam_targets_0258", function(entity)
      return tech_priests_0258_entity_detritus_count(entity) > 0
    end)
  end
  for _, rec in pairs(pair.sweep_0248.jam_targets_0258) do
    if rec and rec.entity and rec.entity.valid and tech_priests_0258_entity_detritus_count(rec.entity) > 0 then return rec.entity end
  end
  return nil
end

function tech_priests_0258_start_detritus_clear_task(pair, entity)
  if not (pair and entity and entity.valid and pair.priest and pair.priest.valid) then return false end
  pair.detritus_clear_0258 = { phase = "approach-source", source = entity, started_tick = game.tick, next_repath_tick = 0, carried = 0 }
  pair.mode = "clearing-machine-detritus"
  pair.target = entity
  if tech_priests_draw_emergency_operation_status_0184 then tech_priests_draw_emergency_operation_status_0184(pair, "[item=" .. TECH_PRIESTS_DETRITUS_ITEM_0258 .. "] machine jam clearing") end
  return true
end

function tech_priests_0258_handle_detritus_clear_task(pair)
  local task = pair and pair.detritus_clear_0258 or nil
  if not task then return false end
  if not (pair.station and pair.station.valid and pair.priest and pair.priest.valid) then pair.detritus_clear_0258 = nil; return false end
  if game.tick - (task.started_tick or game.tick) > TECH_PRIESTS_JAM_TASK_TIMEOUT_TICKS_0258 then pair.detritus_clear_0258 = nil; return false end

  if task.phase == "approach-source" then
    local source = task.source
    if not (source and source.valid) or tech_priests_0258_entity_detritus_count(source) <= 0 then pair.detritus_clear_0258 = nil; return false end
    local dist = tech_priests_distance_sq_0186 and tech_priests_distance_sq_0186(pair.priest.position, source.position) or 999999
    if dist > TECH_PRIESTS_JAM_CLEAR_REACH_SQ_0258 then
      if game.tick >= (task.next_repath_tick or 0) and issue_priest_command then
        issue_priest_command(pair.priest, { type = defines.command.go_to_location, destination = source.position, radius = 2, distraction = defines.distraction.by_enemy })
        task.next_repath_tick = game.tick + 90
      end
      pair.mode = "clearing-machine-detritus"
      return true
    end
    local removed = tech_priests_0258_remove_detritus_from_entity(source, 100)
    task.carried = (task.carried or 0) + removed
    task.disposal = tech_priests_0258_find_disposal_entity(pair)
    task.phase = "approach-disposal"
    task.next_repath_tick = 0
    if removed <= 0 then pair.detritus_clear_0258 = nil; return false end
    if tech_priests_draw_emergency_operation_status_0184 then tech_priests_draw_emergency_operation_status_0184(pair, "[item=" .. TECH_PRIESTS_DETRITUS_ITEM_0258 .. "] removed jam x" .. tostring(removed)) end
    return true
  end

  if task.phase == "approach-disposal" then
    local disposal = task.disposal
    if not (disposal and disposal.valid) then disposal = tech_priests_0258_find_disposal_entity(pair); task.disposal = disposal end
    if not (disposal and disposal.valid) then
      local inv = get_station_inventory and get_station_inventory(pair.station) or nil
      if inv and inv.valid then
        local inserted = inv.insert({ name = TECH_PRIESTS_DETRITUS_ITEM_0258, count = task.carried or 0 }) or 0
        task.carried = (task.carried or 0) - inserted
      end
      pair.detritus_clear_0258 = nil
      return true
    end
    local dist = tech_priests_distance_sq_0186 and tech_priests_distance_sq_0186(pair.priest.position, disposal.position) or 999999
    if dist > TECH_PRIESTS_JAM_DISPOSE_REACH_SQ_0258 then
      if game.tick >= (task.next_repath_tick or 0) and issue_priest_command then
        issue_priest_command(pair.priest, { type = defines.command.go_to_location, destination = disposal.position, radius = 2, distraction = defines.distraction.by_enemy })
        task.next_repath_tick = game.tick + 90
      end
      pair.mode = "disposing-machine-detritus"
      return true
    end
    local inserted = tech_priests_0258_insert_detritus_into(disposal, task.carried or 0)
    task.carried = (task.carried or 0) - inserted
    if task.carried and task.carried > 0 then
      local inv = get_station_inventory and get_station_inventory(pair.station) or nil
      if inv and inv.valid then task.carried = task.carried - (inv.insert({ name = TECH_PRIESTS_DETRITUS_ITEM_0258, count = task.carried }) or 0) end
    end
    pair.detritus_clear_0258 = nil
    if tech_priests_draw_emergency_operation_status_0184 then tech_priests_draw_emergency_operation_status_0184(pair, "[item=" .. TECH_PRIESTS_DETRITUS_ITEM_0258 .. "] jam cleared") end
    return true
  end

  pair.detritus_clear_0258 = nil
  return false
end

if tick_pair then
  TECH_PRIESTS_TICK_PAIR_BEFORE_0258 = tick_pair
  function tick_pair(pair)
    if pair and pair.detritus_clear_0258 then
      if tech_priests_0258_handle_detritus_clear_task(pair) then return true end
    end
    if pair and tech_priests_0248_valid_pair and tech_priests_0248_valid_pair(pair) then
      local probe = tech_priests_0248_higher_priority_probe and tech_priests_0248_higher_priority_probe(pair) or { priority = "idle" }
      if probe.priority == "idle" then
        local target = tech_priests_0258_first_jam_target(pair)
        if target and tech_priests_0258_start_detritus_clear_task(pair, target) then
          return tech_priests_0258_handle_detritus_clear_task(pair) or true
        end
      end
    end
    return TECH_PRIESTS_TICK_PAIR_BEFORE_0258(pair)
  end
end

if commands and commands.add_command then
  pcall(function()
    commands.add_command("tp-placement-safety-debug", "Tech Priests: report Magos pipe/belt placement safety state for the selected station.", function(event)
      local player = game.get_player(event.player_index)
      if not player then return end
      local pair = nil
      if tech_priests_find_pair_for_player_selection_0184 then pair = tech_priests_find_pair_for_player_selection_0184(player) end
      if not pair and player.selected and player.selected.valid and get_pair_by_station then pair = get_pair_by_station(player.selected) end
      if not pair then player.print("[Tech Priests] Select a Cogitator Station or priest first."); return end
      local store = tech_priests_0258_ensure_storage()
      local sk = tech_priests_0258_surface_key(pair.station.surface)
      local fluids, belts = 0, 0
      for _ in pairs(store.fluid_runs[sk] or {}) do fluids = fluids + 1 end
      for _ in pairs(store.belt_arteries[sk] or {}) do belts = belts + 1 end
      local op = pair.independent_emergency_operation_0184
      player.print("[Tech Priests] placement safety diagnostics:")
      player.print("  station=" .. tostring(pair.station.name) .. " unit=" .. tostring(pair.station.unit_number))
      player.print("  planned_fluid=" .. tostring(tech_priests_0258_planned_fluid(pair, "pipe", pair.station.position) or "unknown"))
      player.print("  planned_belt_item=" .. tostring(tech_priests_0258_planned_belt_item(pair, "transport-belt", pair.station.position) or "unknown"))
      player.print("  tracked_fluid_tiles=" .. tostring(fluids) .. " tracked_belt_tiles=" .. tostring(belts))
      player.print("  last_block_reason=" .. tostring(op and op.placement_block_reason_0258 or "none"))
    end)
  end)
  pcall(function()
    commands.add_command("tp-jam-debug", "Tech Priests: report machine-detritus jam targets for the selected station.", function(event)
      local player = game.get_player(event.player_index)
      if not player then return end
      local pair = nil
      if tech_priests_find_pair_for_player_selection_0184 then pair = tech_priests_find_pair_for_player_selection_0184(player) end
      if not pair and player.selected and player.selected.valid and get_pair_by_station then pair = get_pair_by_station(player.selected) end
      if not pair then player.print("[Tech Priests] Select a Cogitator Station or priest first."); return end
      if tech_priests_0248_update_station_sweep then tech_priests_0248_update_station_sweep(pair) end
      local n = 0
      for _, rec in pairs((pair.sweep_0248 and pair.sweep_0248.jam_targets_0258) or {}) do
        if rec and rec.entity and rec.entity.valid and tech_priests_0258_entity_detritus_count(rec.entity) > 0 then n = n + 1 end
      end
      player.print("[Tech Priests] jam diagnostics: targets=" .. tostring(n) .. " active_task=" .. tostring(pair.detritus_clear_0258 and pair.detritus_clear_0258.phase or "none"))
      local shown = 0
      for _, rec in pairs((pair.sweep_0248 and pair.sweep_0248.jam_targets_0258) or {}) do
        if rec and rec.entity and rec.entity.valid and shown < 8 then
          local count = tech_priests_0258_entity_detritus_count(rec.entity)
          if count > 0 then
            shown = shown + 1
            player.print("  " .. rec.entity.name .. " unit=" .. tostring(rec.entity.unit_number) .. " detritus=" .. tostring(count))
          end
        end
      end
    end)
  end)
end

tech_priests_0258_diag("placement contamination safety + machine detritus jam clearing loaded")
