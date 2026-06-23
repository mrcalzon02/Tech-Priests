-- Tech Priests 0.1.667 safe fluid-connection construction planner.
--
-- Consumes read-only input connection proposals from 0689. It plans only
-- ordinary pipe routes from an exact machine input port to an exact unconnected
-- interface on a real compatible source segment. Every new tile is checked for
-- station territory, collision, and incompatible adjacent fluids, then reserved
-- through the shared construction reservation authority. Actual item removal,
-- priest movement, and placement remain owned by construction_planner.lua.
--
-- This module does not mutate fluid, place entities directly, alter recipes,
-- build output networks, or guess routes when no compatible source segment exists.

local M = {
  version = "0.1.667",
  storage_key = "fluid_connection_planner_0691",
  pipe_item = "pipe",
  pipe_entity = "pipe",
  max_route_tiles = 48,
  max_search_nodes = 4096,
  reservation_ttl = 60 * 30,
  proposal_max_age = 60 * 20,
  max_retries_per_tile = 3,
  adjacency_radius = 1.15,
}

local previous_build_install
local previous_build_service_pair

local FLUID_NEIGHBOR_TYPES = {
  "pipe",
  "pipe-to-ground",
  "pump",
  "storage-tank",
  "offshore-pump",
  "assembling-machine",
  "furnace",
  "mining-drill",
  "boiler",
  "generator",
  "reactor",
  "fluid-turret",
  "rocket-silo",
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

local function pos(value)
  if not value then return nil end
  local x = tonumber(value.x or value[1])
  local y = tonumber(value.y or value[2])
  if not (x and y) then return nil end
  return { x = math.floor(x + 0.5), y = math.floor(y + 0.5) }
end

local function pos_key(position)
  return position and (tostring(position.x) .. "," .. tostring(position.y)) or "nil"
end

local function same_pos(a, b)
  return a and b and math.abs(a.x - b.x) < 0.1 and math.abs(a.y - b.y) < 0.1
end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    ordinary_pipe_only = true,
    input_routes_only = true,
    stats = {},
    recent = {},
    plans = {},
  }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.ordinary_pipe_only == nil then r.ordinary_pipe_only = true end
  if r.input_routes_only == nil then r.input_routes_only = true end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  r.plans = r.plans or {}
  return r
end

local function stat(name, amount)
  local r = root()
  r.stats[name] = (r.stats[name] or 0) + (amount or 1)
end

local function record(pair, action, detail)
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
  return event
end

local function planning_constraints()
  return rawget(_G, "TechPriestsPlanningConstraints0646")
    or package.loaded["scripts.core.planning_constraints_0646"]
end

local function reservations()
  local module = rawget(_G, "TechPriestsWorkReservations0601")
  if module then return module end
  local ok, loaded = pcall(require, "scripts.core.work_reservations")
  return ok and loaded or nil
end

local function fluid_doctrine()
  local module = rawget(_G, "TechPriestsFluidNetworkDoctrine0689")
  if module then return module end
  local ok, loaded = pcall(require, "scripts.core.fluid_network_doctrine_0689")
  return ok and loaded or nil
end

local function fluidbox(entity)
  if not valid(entity) then return nil end
  local ok, box = pcall(function() return entity.fluidbox end)
  return ok and box and box.valid and box or nil
end

local function segment_contents(box, index)
  local contents = {}
  if not (box and box.valid and index) then return contents end
  pcall(function() contents = box.get_fluid_segment_contents(index) or {} end)
  return type(contents) == "table" and contents or {}
end

local function segment_compatible(entity, index, fluid_name)
  local box = fluidbox(entity)
  if not box then return true, "no-fluidbox" end
  local contents = segment_contents(box, index)
  for name, amount in pairs(contents) do
    if name ~= fluid_name and (tonumber(amount) or 0) > 0.001 then
      return false, "wrong-fluid:" .. tostring(name)
    end
  end
  local filter
  pcall(function() filter = box.get_filter(index) end)
  if type(filter) == "table" and filter.name and filter.name ~= fluid_name then
    return false, "filter:" .. tostring(filter.name)
  end
  local locked
  pcall(function() locked = box.get_locked_fluid(index) end)
  if locked and locked ~= fluid_name then return false, "locked:" .. tostring(locked) end
  return true, "compatible"
end

local function pipe_connections(entity, index)
  local out = {}
  local box = fluidbox(entity)
  if not box or not index then return out end
  local connections = {}
  pcall(function() connections = box.get_pipe_connections(index) or {} end)
  for _, connection in pairs(connections or {}) do
    if type(connection) == "table" then
      local owner
      if connection.target then pcall(function() owner = connection.target.owner end) end
      out[#out + 1] = {
        target_position = pos(connection.target_position or connection.position),
        connected = connection.target ~= nil or valid(owner),
        target_owner = owner,
      }
    end
  end
  return out
end

local function source_port_positions(source, fluid_name)
  if not (source and valid(source.entity) and source.fluidbox_index) then return {} end
  local compatible = segment_compatible(source.entity, source.fluidbox_index, fluid_name)
  if not compatible then return {} end
  local out = {}
  for _, connection in ipairs(pipe_connections(source.entity, source.fluidbox_index)) do
    if not connection.connected and connection.target_position then
      out[#out + 1] = connection.target_position
    end
  end
  return out
end

local function territory_allowed(pair, position)
  local constraints = planning_constraints()
  if constraints and type(constraints.interior_position_allowed) == "function" then
    local ok, allowed = pcall(constraints.interior_position_allowed, pair, position, 2.5)
    return ok and allowed == true
  end
  local radius = tonumber(pair and pair.radius) or 28
  return valid_pair(pair) and dist_sq(pair.station.position, position) <= math.max(8, radius - 2.5) ^ 2
end

local function entities_at(surface, position)
  local entities = {}
  pcall(function()
    entities = surface.find_entities_filtered({
      area = {
        { position.x - 0.35, position.y - 0.35 },
        { position.x + 0.35, position.y + 0.35 },
      },
    }) or {}
  end)
  return entities
end

local function existing_compatible_pipe(pair, position, fluid_name)
  for _, entity in pairs(entities_at(pair.station.surface, position)) do
    if valid(entity) and entity.force == pair.station.force
      and (entity.type == "pipe" or entity.type == "pipe-to-ground")
    then
      local box = fluidbox(entity)
      if box then
        for index = 1, #box do
          local compatible = segment_compatible(entity, index, fluid_name)
          if compatible then return entity end
        end
      else
        return entity
      end
    end
  end
  return nil
end

local function incompatible_adjacent_segment(pair, position, fluid_name)
  local entities = {}
  local radius = M.adjacency_radius
  pcall(function()
    entities = pair.station.surface.find_entities_filtered({
      area = {
        { position.x - radius, position.y - radius },
        { position.x + radius, position.y + radius },
      },
      force = pair.station.force,
      type = FLUID_NEIGHBOR_TYPES,
      limit = 48,
    }) or {}
  end)
  for _, entity in pairs(entities) do
    local box = fluidbox(entity)
    if box then
      for index = 1, #box do
        local compatible, why = segment_compatible(entity, index, fluid_name)
        if not compatible then return true, entity, why end
      end
    end
  end
  return false, nil, nil
end

local function can_place_pipe(pair, position, fluid_name)
  if not territory_allowed(pair, position) then return false, "outside-station-interior" end
  local existing = existing_compatible_pipe(pair, position, fluid_name)
  if existing then return true, "existing-compatible-pipe", existing end
  local incompatible, entity, why = incompatible_adjacent_segment(pair, position, fluid_name)
  if incompatible then return false, "adjacent-incompatible:" .. safe(why) .. ":" .. safe(entity and entity.name) end
  local ok, allowed = pcall(function()
    return pair.station.surface.can_place_entity({
      name = M.pipe_entity,
      position = position,
      force = pair.station.force,
      build_check_type = defines and defines.build_check_type and defines.build_check_type.manual or nil,
    })
  end)
  if not ok then
    ok, allowed = pcall(function()
      return pair.station.surface.can_place_entity({
        name = M.pipe_entity,
        position = position,
        force = pair.station.force,
      })
    end)
  end
  return ok and allowed == true, ok and "placeable" or "can-place-error"
end

local function reconstruct(came_from, current_key, positions)
  local route = {}
  while current_key do
    route[#route + 1] = positions[current_key]
    current_key = came_from[current_key]
  end
  local out = {}
  for index = #route, 1, -1 do out[#out + 1] = route[index] end
  return out
end

local function bfs_route(pair, start_position, goal_position, fluid_name)
  local start = pos(start_position)
  local goal = pos(goal_position)
  if not (start and goal) then return nil, "invalid-endpoint" end

  local queue = { start }
  local head = 1
  local start_key = pos_key(start)
  local goal_key = pos_key(goal)
  local visited = { [start_key] = true }
  local came_from = {}
  local positions = { [start_key] = start }
  local nodes = 0
  local directions = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

  while head <= #queue and nodes < M.max_search_nodes do
    local current = queue[head]
    head = head + 1
    nodes = nodes + 1
    local current_key = pos_key(current)
    if current_key == goal_key then
      local route = reconstruct(came_from, current_key, positions)
      if #route > M.max_route_tiles then return nil, "route-too-long:" .. tostring(#route) end
      stat("route_nodes_visited", nodes)
      return route, "route-found"
    end

    for _, direction in ipairs(directions) do
      local next_position = { x = current.x + direction[1], y = current.y + direction[2] }
      local key = pos_key(next_position)
      if not visited[key] then
        local allowed = can_place_pipe(pair, next_position, fluid_name)
        if allowed then
          visited[key] = true
          came_from[key] = current_key
          positions[key] = next_position
          queue[#queue + 1] = next_position
        end
      end
    end
  end
  stat("route_search_exhausted")
  return nil, nodes >= M.max_search_nodes and "search-budget-exhausted" or "no-route"
end

local function best_route(pair, proposal)
  if not (valid_pair(pair) and proposal and valid(proposal.machine)
    and proposal.source and valid(proposal.source.entity))
  then
    return nil, "invalid-proposal"
  end
  local starts = proposal.connection_targets or {}
  local goals = source_port_positions(proposal.source, proposal.fluid)
  if #starts == 0 then return nil, "machine-has-no-unconnected-target" end
  if #goals == 0 then return nil, "source-has-no-unconnected-interface" end

  local best, best_reason
  for _, start_position in ipairs(starts) do
    for _, goal_position in ipairs(goals) do
      local route, why = bfs_route(pair, start_position, goal_position, proposal.fluid)
      if route and (not best or #route < #best) then
        best, best_reason = route, why
      end
    end
  end
  return best, best_reason or "no-compatible-route"
end

local function new_tiles(pair, route, fluid_name)
  local tiles = {}
  for _, position in ipairs(route or {}) do
    if not existing_compatible_pipe(pair, position, fluid_name) then
      tiles[#tiles + 1] = { x = position.x, y = position.y }
    end
  end
  -- Build from the source interface toward the machine. The machine is connected
  -- only by the final placement, after the rest of the route already exists.
  local reversed = {}
  for index = #tiles, 1, -1 do reversed[#reversed + 1] = tiles[index] end
  return reversed
end

local function claim_route(pair, plan)
  local module = reservations()
  if not (module and type(module.claim) == "function") then return false, "reservation-authority-unavailable" end
  local claimed = {}
  for _, position in ipairs(plan.tiles or {}) do
    local target = { position = { x = position.x, y = position.y } }
    local ok, why = module.claim("construction", target, pair, M.reservation_ttl, {
      surface_index = pair.station.surface.index,
      force_index = pair.station.force.index,
      fluid = plan.fluid,
      plan_id = plan.id,
      source = "fluid-connection-planner-0691",
    })
    if not ok then
      for _, old in ipairs(claimed) do pcall(module.release, "construction", old, pair) end
      stat("route_reservation_denied")
      return false, why or "reservation-denied"
    end
    claimed[#claimed + 1] = target
  end
  plan.reservation_targets = claimed
  stat("route_tiles_reserved", #claimed)
  return true, "reserved"
end

local function release_route(pair, plan)
  local module = reservations()
  if module and type(module.release) == "function" then
    for _, target in ipairs(plan and plan.reservation_targets or {}) do
      pcall(module.release, "construction", target, pair)
    end
  end
  if plan then plan.reservation_targets = {} end
end

local function station_item_count(pair, item)
  if type(_G.tech_priests_0358_station_item_count) == "function" then
    local ok, count = pcall(_G.tech_priests_0358_station_item_count, pair, item)
    if ok then return tonumber(count) or 0 end
  end
  local total = 0
  local sources
  if type(_G.tech_priests_inventory_steward_sources_for_pair) == "function" then
    local ok, value = pcall(_G.tech_priests_inventory_steward_sources_for_pair, pair)
    if ok then sources = value end
  end
  for _, source in ipairs(type(sources) == "table" and sources or {}) do
    local inv = source and source.inv
    if inv and inv.valid then
      local ok, count = pcall(function() return inv.get_item_count(item) end)
      if ok then total = total + (tonumber(count) or 0) end
    end
  end
  return total
end

local function pipe_unlocked(pair)
  local constraints = planning_constraints()
  if constraints and type(constraints.item_unlocked) == "function" then
    local ok, unlocked, why = pcall(constraints.item_unlocked, pair.station.force, M.pipe_item)
    if ok then return unlocked == true, why end
  end
  return true, "unknown-assumed-unlocked"
end

local function request_pipe_items(pair, plan)
  local remaining = math.max(1, #(plan.tiles or {}) - (tonumber(plan.current_index) or 1) + 1)
  pair.active_supply_request = {
    item = M.pipe_item,
    count = remaining,
    source = "fluid-connection-planner-0691",
    purpose = "construction-pipe",
    fluid = plan.fluid,
    plan_id = plan.id,
    tick = now(),
  }
  pair.logistic_requested_item = {
    item = M.pipe_item,
    count = remaining,
    source = "fluid-connection-planner-0691",
    purpose = "construction-pipe",
    plan_id = plan.id,
  }
  plan.state = "waiting-pipe-items"
  stat("pipe_item_requests")
end

local function clear_pipe_request(pair, plan)
  for _, field in ipairs({ "active_supply_request", "logistic_requested_item" }) do
    local request = pair and pair[field]
    if type(request) == "table"
      and request.source == "fluid-connection-planner-0691"
      and (not plan or request.plan_id == plan.id)
    then
      pair[field] = nil
    end
  end
end

local function blocker(pair)
  if not valid_pair(pair) then return "invalid-pair" end
  if valid(pair.combat_target) then return "combat" end
  if pair.machine_logistics_custody_0682 then return "machine-custody" end
  for _, field in ipairs({ "repair_0516", "combat_repair_0517", "consecration_0515" }) do
    local state = pair[field]
    local phase = lower(type(state) == "table" and state.phase or "")
    if phase ~= "" and phase ~= "complete" and phase ~= "completed" and phase ~= "done" then
      return field
    end
  end
  if pair.direct_acquisition_target_lock_0650 then return "direct-acquisition" end
  return nil
end

local function proposal_candidate(pair)
  local proposals = pair and pair.fluid_connection_proposals_0689
  if type(proposals) ~= "table" then return nil end
  for _, proposal in ipairs(proposals) do
    if type(proposal) == "table"
      and proposal.action == "connect-fluid-input"
      and proposal.state == "source-network-found"
      and proposal.source
      and valid(proposal.source.entity)
      and valid(proposal.machine)
      and now() - (tonumber(proposal.tick) or -1000000) <= M.proposal_max_age
    then
      return proposal
    end
  end
  return nil
end

local function create_plan(pair, proposal)
  local unlocked, why = pipe_unlocked(pair)
  if not unlocked then
    record(pair, "pipe-plan-technology-locked", safe(why))
    return nil, "pipe-locked"
  end
  local route, route_why = best_route(pair, proposal)
  if not route then
    record(pair, "pipe-route-rejected", safe(route_why))
    return nil, route_why
  end
  local tiles = new_tiles(pair, route, proposal.fluid)
  if #tiles == 0 then
    local doctrine = fluid_doctrine()
    if doctrine and type(doctrine.inspect_machine) == "function" then
      pcall(doctrine.inspect_machine, pair, proposal.machine, true)
    end
    record(pair, "pipe-route-already-present", proposal.fluid .. " machine=" .. safe(proposal.machine_name))
    return nil, "already-connected-or-existing-route"
  end
  if #tiles > M.max_route_tiles then return nil, "too-many-new-tiles" end

  local id = tostring(station_unit(pair) or "?") .. ":"
    .. tostring(proposal.machine_unit or proposal.machine_name) .. ":"
    .. tostring(now())
  local plan = {
    version = M.version,
    id = id,
    state = "planned",
    created_tick = now(),
    fluid = proposal.fluid,
    machine = proposal.machine,
    machine_name = proposal.machine_name,
    machine_unit = proposal.machine_unit,
    source = proposal.source,
    route = route,
    tiles = tiles,
    current_index = 1,
    retries = {},
    proposal_tick = proposal.tick,
    ordinary_pipe_only = true,
  }
  local claimed, claim_why = claim_route(pair, plan)
  if not claimed then return nil, claim_why end
  root().plans[id] = plan
  pair.fluid_pipe_plan_0691 = plan
  stat("pipe_plans_created")
  stat("pipe_tiles_planned", #tiles)
  record(pair, "pipe-plan-created", proposal.fluid .. " tiles=" .. tostring(#tiles)
    .. " machine=" .. safe(proposal.machine_name)
    .. " source=" .. safe(proposal.source.entity_name))
  return plan, "created"
end

local function ensure_plan(pair)
  local r = root()
  if r.enabled == false or not valid_pair(pair) then return nil, "disabled-or-invalid" end
  local plan = pair.fluid_pipe_plan_0691
  if type(plan) == "table" and plan.state ~= "complete" and plan.state ~= "aborted" then return plan, "existing" end
  if pair.construction_task_0338 then return nil, "construction-busy" end
  local blocked = blocker(pair)
  if blocked then return nil, "blocked:" .. blocked end
  local proposal = proposal_candidate(pair)
  if not proposal then return nil, "no-input-proposal" end
  return create_plan(pair, proposal)
end

local function current_tile(plan)
  return plan and plan.tiles and plan.tiles[tonumber(plan.current_index) or 1] or nil
end

local function pipe_exists(pair, position, fluid_name)
  return existing_compatible_pipe(pair, position, fluid_name) ~= nil
end

local function seed_task(pair, plan)
  if not (valid_pair(pair) and plan and plan.state ~= "aborted" and plan.state ~= "complete") then return false end
  if pair.construction_task_0338 then return true end
  local tile = current_tile(plan)
  if not tile then return false end

  if pipe_exists(pair, tile, plan.fluid) then
    plan.current_index = (tonumber(plan.current_index) or 1) + 1
    stat("pipe_tiles_adopted_existing")
    return seed_task(pair, plan)
  end

  if station_item_count(pair, M.pipe_item) <= 0 then
    request_pipe_items(pair, plan)
    return false
  end
  clear_pipe_request(pair, plan)
  plan.state = "building"
  pair.construction_task_0338 = {
    item_name = M.pipe_item,
    entity_name = M.pipe_entity,
    entity_type = "pipe",
    category = "deferred-network",
    target_position = { x = tile.x, y = tile.y },
    plan_reason = "fluid-connection-plan-0691",
    phase = "planned",
    created_tick = now(),
    source = "fluid-connection-planner-0691",
    fluid_pipe_plan_0691 = true,
    fluid_pipe_plan_id_0691 = plan.id,
    fluid_pipe_index_0691 = plan.current_index,
    fluid_name_0691 = plan.fluid,
  }
  plan.active_task_tick = now()
  plan.active_tile = { x = tile.x, y = tile.y }
  stat("pipe_tasks_seeded")
  return true
end

local function complete_plan(pair, plan, reason)
  release_route(pair, plan)
  clear_pipe_request(pair, plan)
  plan.state = "complete"
  plan.completed_tick = now()
  plan.result = reason or "complete"
  pair.fluid_pipe_plan_last_0691 = plan
  pair.fluid_pipe_plan_0691 = nil
  local doctrine = fluid_doctrine()
  if doctrine and type(doctrine.inspect_machine) == "function" and valid(plan.machine) then
    pcall(doctrine.inspect_machine, pair, plan.machine, true)
  end
  stat("pipe_plans_completed")
  record(pair, "pipe-plan-completed", plan.fluid .. " tiles=" .. tostring(#(plan.tiles or {})))
end

local function abort_plan(pair, plan, reason)
  release_route(pair, plan)
  clear_pipe_request(pair, plan)
  if pair.construction_task_0338 and pair.construction_task_0338.fluid_pipe_plan_id_0691 == plan.id then
    pair.construction_task_0338 = nil
  end
  plan.state = "aborted"
  plan.aborted_tick = now()
  plan.result = tostring(reason or "aborted")
  pair.fluid_pipe_plan_last_0691 = plan
  pair.fluid_pipe_plan_0691 = nil
  stat("pipe_plans_aborted")
  record(pair, "pipe-plan-aborted", safe(reason))
end

local function validate_plan(pair, plan)
  if not (plan and valid(plan.machine) and plan.source and valid(plan.source.entity)) then
    return false, "endpoint-invalid"
  end
  local source_ok = segment_compatible(plan.source.entity, plan.source.fluidbox_index, plan.fluid)
  if not source_ok then return false, "source-segment-incompatible" end
  local tile = current_tile(plan)
  if tile then
    local allowed, why = can_place_pipe(pair, tile, plan.fluid)
    if not allowed then return false, why end
  end
  return true, "valid"
end

local function task_succeeded(pair, task)
  local success = pair and pair.last_construction_success_0338
  return task and success
    and (tonumber(success.tick) or -1) >= (tonumber(task.created_tick) or now())
    and success.entity == M.pipe_entity
    and same_pos({ x = success.x, y = success.y }, task.target_position)
end

local function after_build_service(pair, plan, task, acted, why)
  if not plan then return acted, why end
  if task and task.fluid_pipe_plan_id_0691 == plan.id then
    local index = tonumber(task.fluid_pipe_index_0691) or tonumber(plan.current_index) or 1
    if task_succeeded(pair, task) or pipe_exists(pair, task.target_position, plan.fluid) then
      plan.current_index = index + 1
      plan.retries[index] = nil
      plan.active_tile = nil
      stat("pipe_tiles_completed")
      if not current_tile(plan) then
        complete_plan(pair, plan, "route-built")
        return true, "fluid-pipe-plan-complete"
      end
      seed_task(pair, plan)
      return true, "fluid-pipe-tile-complete"
    end

    if why == "missing-item" then
      request_pipe_items(pair, plan)
      return false, "waiting-pipe-items"
    end
    if why == "blocked" or why == "create-failed" or why == "remove-failed" then
      plan.retries[index] = (tonumber(plan.retries[index]) or 0) + 1
      stat("pipe_tile_retries")
      if plan.retries[index] >= M.max_retries_per_tile then
        abort_plan(pair, plan, "tile-failed:" .. safe(why) .. ":" .. pos_key(task.target_position))
        return false, "fluid-pipe-plan-aborted"
      end
      return acted, "fluid-pipe-tile-retry:" .. safe(why)
    end
  end
  return acted, why
end

local function patched_build_service_pair(pair, reason, ...)
  if root().enabled == false or not valid_pair(pair) then
    return previous_build_service_pair(pair, reason, ...)
  end
  local plan = pair.fluid_pipe_plan_0691
  if not plan then plan = select(1, ensure_plan(pair)) end
  if plan then
    local valid_plan, why = validate_plan(pair, plan)
    if not valid_plan then
      abort_plan(pair, plan, why)
      return false, "fluid-pipe-plan-invalid:" .. safe(why)
    end
    seed_task(pair, plan)
  end

  local task = pair.construction_task_0338
  local acted, why = previous_build_service_pair(pair, reason, ...)
  return after_build_service(pair, plan, task, acted, why)
end

local function patch_build(build)
  if not (build and type(build.service_pair) == "function")
    or build.fluid_connection_planner_0691_active
  then
    return false
  end
  build.fluid_connection_planner_0691_active = true
  previous_build_service_pair = build.service_pair
  build.service_pair = patched_build_service_pair
  return true
end

local function patch_diagnostics()
  local diagnostics = rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
    or rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diagnostics and type(diagnostics.pair_dump_lines) == "function")
    or diagnostics.fluid_connection_planner_0691_wrapped
  then
    return false
  end
  diagnostics.fluid_connection_planner_0691_wrapped = true
  local previous = diagnostics.pair_dump_lines
  diagnostics.pair_dump_lines = function(...)
    local lines = previous(...)
    lines = type(lines) == "table" and lines or {}
    local r = root()
    lines[#lines + 1] = "PAIR-DUMP-0468 FLUID-CONNECTION-0691 enabled="
      .. safe(r.enabled)
      .. " ordinary_pipe_only=true"
      .. " input_routes_only=true"
      .. " direct_placements=0"
      .. " fluid_mutations=0"
      .. " plans=" .. safe(r.stats.pipe_plans_created or 0)
      .. " completed=" .. safe(r.stats.pipe_plans_completed or 0)
      .. " aborted=" .. safe(r.stats.pipe_plans_aborted or 0)
      .. " tiles_planned=" .. safe(r.stats.pipe_tiles_planned or 0)
      .. " tiles_reserved=" .. safe(r.stats.route_tiles_reserved or 0)
      .. " tiles_completed=" .. safe(r.stats.pipe_tiles_completed or 0)
      .. " item_requests=" .. safe(r.stats.pipe_item_requests or 0)
      .. " reservation_denied=" .. safe(r.stats.route_reservation_denied or 0)
    for _, pair in pairs(pair_map()) do
      if valid_pair(pair) then
        local plan = pair.fluid_pipe_plan_0691 or {}
        local tile = current_tile(plan)
        lines[#lines + 1] = "PAIR-DUMP-0468 fluid-pipe[" .. safe(station_unit(pair)) .. "]"
          .. " state=" .. safe(plan.state or "none")
          .. " fluid=" .. safe(plan.fluid or "none")
          .. " index=" .. safe(plan.current_index or 0)
          .. "/" .. safe(plan.tiles and #plan.tiles or 0)
          .. " tile=" .. safe(tile and pos_key(tile) or "none")
          .. " machine=" .. safe(plan.machine_name or "none")
          .. " source=" .. safe(plan.source and plan.source.entity_name or "none")
      end
    end
    for index = math.max(1, #r.recent - 10), #r.recent do
      local event = r.recent[index]
      if event then
        lines[#lines + 1] = "PAIR-DUMP-0468 fluid-pipe.recent[" .. safe(index) .. "]"
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

function M.activate(build)
  patch_build(build)
  patch_diagnostics()
  _G.TechPriestsFluidConnectionPlanner0691 = M
  return true
end

function M.install()
  root()
  local ok, build = pcall(require, "scripts.core.construction_planner")
  if not (ok and build) then return false end
  if not build.fluid_connection_planner_0691_install_wrapped then
    build.fluid_connection_planner_0691_install_wrapped = true
    previous_build_install = build.install
    build.install = function(...)
      local result = type(previous_build_install) == "function" and previous_build_install(...) or true
      M.activate(build)
      return result
    end
  end
  if rawget(_G, "TECH_PRIESTS_CONSTRUCTION_PLANNER_0338") then M.activate(build) end
  patch_diagnostics()
  _G.TechPriestsFluidConnectionPlanner0691 = M
  if log then
    log("[Tech-Priests 0.1.667] reserved ordinary-pipe input connection planner armed; construction executor remains sole placement authority")
  end
  return true
end

return M
