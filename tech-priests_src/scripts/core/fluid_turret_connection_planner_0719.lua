-- Tech Priests 0.1.674-dev safe fluid-turret connection planner.
--
-- Consumes only 0718 safe proposals. Plans ordinary pipe routes inside Cogitator
-- territory, reserves every new tile, requests physical pipes, and delegates all
-- item removal, movement, placement, and refunds to construction_planner.lua.
-- Routes are built from source toward turret so the turret connects on the final
-- tile. No fluid, filter, targeting, or firing mutation occurs here.

local M = {
  version = "0.1.674-dev",
  storage_key = "fluid_turret_connection_planner_0719",
  pipe_item = "pipe",
  pipe_entity = "pipe",
  max_route_tiles = 48,
  max_search_nodes = 4096,
  reservation_ttl = 60 * 30,
  proposal_max_age = 60 * 20,
  rejection_cooldown = 60 * 10,
  max_retries_per_tile = 3,
  adjacency_radius = 1.15,
}

local previous_build_install
local previous_build_service_pair

local FLUID_ENTITY_TYPES = {
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

local function valid_pair(pair)
  return pair and valid(pair.station) and valid(pair.priest)
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

local function normalized_position(value)
  if not value then return nil end
  local x = tonumber(value.x or value[1])
  local y = tonumber(value.y or value[2])
  if not (x and y) then return nil end
  return { x = math.floor(x + 0.5), y = math.floor(y + 0.5) }
end

local function position_key(position)
  return position and (tostring(position.x) .. "," .. tostring(position.y)) or "nil"
end

local function same_position(a, b)
  return a and b
    and math.abs(a.x - b.x) < 0.1
    and math.abs(a.y - b.y) < 0.1
end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  local state = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    stats = {},
    recent = {},
    plans = {},
  }
  storage.tech_priests[M.storage_key] = state
  state.version = M.version
  if state.enabled == nil then state.enabled = true end
  state.stats = state.stats or {}
  state.recent = state.recent or {}
  state.plans = state.plans or {}
  return state
end

local function stat(name, amount)
  local state = root()
  state.stats[name] = (state.stats[name] or 0) + (amount or 1)
end

local function record(pair, action, detail)
  local state = root()
  stat(action)
  state.recent[#state.recent + 1] = {
    tick = now(),
    action = tostring(action or "event"),
    station = safe(station_unit(pair)),
    detail = tostring(detail or ""),
  }
  while #state.recent > 160 do table.remove(state.recent, 1) end
end

local function planning_constraints()
  return rawget(_G, "TechPriestsPlanningConstraints0646")
    or package.loaded["scripts.core.planning_constraints_0646"]
end

local function reservation_authority()
  return rawget(_G, "TechPriestsWorkReservations0601")
    or package.loaded["scripts.core.work_reservations"]
end

local function readiness_authority()
  return rawget(_G, "TechPriestsFluidTurretReadiness0716")
    or package.loaded["scripts.core.fluid_turret_readiness_0716"]
end

local function fluidbox(entity)
  if not valid(entity) then return nil end
  local ok, box = pcall(function() return entity.fluidbox end)
  return ok and box and box.valid and box or nil
end

local function segment_contents(box, index)
  local contents = {}
  if box and box.valid then
    pcall(function() contents = box.get_fluid_segment_contents(index) or {} end)
  end
  return type(contents) == "table" and contents or {}
end

local function segment_id(box, index)
  local value
  if box and box.valid then pcall(function() value = box.get_fluid_segment_id(index) end) end
  return value
end

local function filter_name(box, index)
  local filter
  pcall(function() filter = box.get_filter(index) end)
  if type(filter) == "table" and filter.name then return filter.name end
  local locked
  pcall(function() locked = box.get_locked_fluid(index) end)
  if type(locked) == "string" and locked ~= "" then return locked end
  return nil
end

local function segment_state(entity, index, fluid)
  local box = fluidbox(entity)
  if not box then return nil, "no-fluidbox" end
  local contents = segment_contents(box, index)
  local same = tonumber(contents[fluid]) or 0
  local wrong
  for name, amount in pairs(contents) do
    if name ~= fluid and (tonumber(amount) or 0) > 0.001 then
      wrong = name
      break
    end
  end
  return {
    box = box,
    same = same,
    wrong = wrong,
    filter = filter_name(box, index),
    segment_id = segment_id(box, index),
  }, "ok"
end

local function free_targets(entity, index)
  local out = {}
  local box = fluidbox(entity)
  if not box then return out end
  local connections = {}
  pcall(function() connections = box.get_pipe_connections(index) or {} end)
  for _, connection in pairs(connections) do
    if type(connection) == "table" then
      local owner
      if connection.target then pcall(function() owner = connection.target.owner end) end
      local target = connection.target_position or connection.position
      if connection.target == nil and not valid(owner) and target then
        out[#out + 1] = { x = target.x, y = target.y }
      end
    end
  end
  return out
end

local function turret_is_safe(pair, plan)
  local authority = readiness_authority()
  if not (authority and type(authority.inspect_entity) == "function" and valid(plan.turret)) then
    return false, "readiness-unavailable"
  end
  local report = authority.inspect_entity(pair, plan.turret, true)
  if not (report and report.accepted_lookup and report.accepted_lookup[plan.fluid]) then
    return false, "fluid-no-longer-accepted"
  end
  if #((report.pipeline and report.pipeline.wrong_fluids) or {}) > 0
    or #((report.buffer and report.buffer.wrong_fluids) or {}) > 0
  then
    return false, "turret-contaminated"
  end
  if report.state ~= "input-pipeline-unconnected" then
    return false, "turret-no-longer-unconnected:" .. safe(report.state)
  end
  return true, "safe", report
end

local function source_is_safe(plan, require_interface)
  if not (plan.source and valid(plan.source.entity)) then return false, "source-invalid" end
  local state = segment_state(plan.source.entity, plan.source.fluidbox_index, plan.fluid)
  if not state then return false, "source-invalid" end
  if state.wrong then return false, "source-contaminated:" .. state.wrong end
  if state.filter and state.filter ~= plan.fluid then return false, "source-filter-changed" end
  if state.same <= 0.001
    and not (state.segment_id and state.segment_id == plan.source_segment_id)
  then
    return false, "source-identity-lost"
  end
  if require_interface and #free_targets(plan.source.entity, plan.source.fluidbox_index) == 0 then
    return false, "source-interface-unavailable"
  end
  return true, "safe", state
end

local function inside_territory(pair, position)
  local constraints = planning_constraints()
  if constraints and type(constraints.interior_position_allowed) == "function" then
    local ok, allowed = pcall(constraints.interior_position_allowed, pair, position, 2.5)
    return ok and allowed == true
  end
  local radius = tonumber(pair.radius) or 28
  return dist_sq(pair.station.position, position) <= math.max(8, radius - 2.5) ^ 2
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

local function existing_compatible_pipe(pair, position, plan)
  for _, entity in pairs(entities_at(pair.station.surface, position)) do
    if valid(entity)
      and entity.force == pair.station.force
      and (entity.type == "pipe" or entity.type == "pipe-to-ground")
    then
      local box = fluidbox(entity)
      if box then
        for index = 1, #box do
          local state = segment_state(entity, index, plan.fluid)
          if state and not state.wrong then
            local accepted = state.same > 0.001
              or state.filter == plan.fluid
              or (state.segment_id and (
                state.segment_id == plan.source_segment_id
                or state.segment_id == plan.turret_segment_id
              ))
            if accepted then return entity end
          end
        end
      end
    end
  end
  return nil
end

local function adjacent_is_safe(pair, position, plan)
  local radius = M.adjacency_radius
  local entities = {}
  pcall(function()
    entities = pair.station.surface.find_entities_filtered({
      area = {
        { position.x - radius, position.y - radius },
        { position.x + radius, position.y + radius },
      },
      force = pair.station.force,
      type = FLUID_ENTITY_TYPES,
      limit = 48,
    }) or {}
  end)
  for _, entity in pairs(entities) do
    local box = fluidbox(entity)
    if box then
      for index = 1, #box do
        local state = segment_state(entity, index, plan.fluid)
        if state then
          if state.wrong then return false, "adjacent-wrong-fluid:" .. state.wrong end
          local endpoint = entity == plan.turret or entity == plan.source.entity
          local known = state.same > 0.001
            or state.filter == plan.fluid
            or (state.segment_id and (
              state.segment_id == plan.source_segment_id
              or state.segment_id == plan.turret_segment_id
            ))
          if not (endpoint or known) then
            return false, "adjacent-ambiguous-fluidbox:" .. safe(entity.name)
          end
        end
      end
    end
  end
  return true, "safe"
end

local function tile_is_available(pair, position, plan)
  if not inside_territory(pair, position) then return false, "outside-station-interior" end
  if existing_compatible_pipe(pair, position, plan) then return true, "existing" end
  local adjacent_ok, why = adjacent_is_safe(pair, position, plan)
  if not adjacent_ok then return false, why end
  local ok, allowed = pcall(function()
    return pair.station.surface.can_place_entity({
      name = M.pipe_entity,
      position = position,
      force = pair.station.force,
      build_check_type = defines and defines.build_check_type
        and defines.build_check_type.manual or nil,
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
  return ok and allowed == true, ok and (allowed and "placeable" or "blocked") or "can-place-error"
end

local function reconstruct(came_from, current, positions)
  local reverse = {}
  while current do
    reverse[#reverse + 1] = positions[current]
    current = came_from[current]
  end
  local route = {}
  for index = #reverse, 1, -1 do route[#route + 1] = reverse[index] end
  return route
end

local function route_between(pair, start_position, goal_position, plan)
  local start = normalized_position(start_position)
  local goal = normalized_position(goal_position)
  if not (start and goal) then return nil, "invalid-endpoint" end

  local queue = { start }
  local head = 1
  local start_key = position_key(start)
  local goal_key = position_key(goal)
  local visited = { [start_key] = true }
  local came_from = {}
  local positions = { [start_key] = start }
  local nodes = 0
  local directions = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

  while head <= #queue and nodes < M.max_search_nodes do
    local current = queue[head]
    head = head + 1
    nodes = nodes + 1
    local current_key = position_key(current)
    if current_key == goal_key then
      local route = reconstruct(came_from, current_key, positions)
      if #route > M.max_route_tiles then return nil, "route-too-long" end
      return route, "found"
    end
    for _, direction in ipairs(directions) do
      local next_position = {
        x = current.x + direction[1],
        y = current.y + direction[2],
      }
      local key = position_key(next_position)
      if not visited[key] then
        local allowed = tile_is_available(pair, next_position, plan)
        if allowed then
          visited[key] = true
          came_from[key] = current_key
          positions[key] = next_position
          queue[#queue + 1] = next_position
        end
      end
    end
  end
  return nil, nodes >= M.max_search_nodes and "search-budget-exhausted" or "no-route"
end

local function shortest_route(pair, proposal, plan)
  local best, best_reason
  for _, turret_target in ipairs(proposal.connection_targets or {}) do
    for _, source_target in ipairs(proposal.source.interfaces or {}) do
      local route, why = route_between(pair, turret_target, source_target, plan)
      if route and (not best or #route < #best) then
        best, best_reason = route, why
      end
    end
  end
  return best, best_reason or "no-route"
end

local function new_tiles(pair, route, plan)
  local tiles = {}
  for _, position in ipairs(route or {}) do
    if not existing_compatible_pipe(pair, position, plan) then
      tiles[#tiles + 1] = { x = position.x, y = position.y }
    end
  end
  -- route is turret -> source; reverse construction so source is built first.
  local source_first = {}
  for index = #tiles, 1, -1 do source_first[#source_first + 1] = tiles[index] end
  return source_first
end

local function claim_route(pair, plan)
  local reservations = reservation_authority()
  if not (reservations and type(reservations.claim) == "function") then
    return false, "reservation-unavailable"
  end
  local claimed = {}
  for _, position in ipairs(plan.tiles or {}) do
    local target = {
      surface_index = pair.station.surface.index,
      position = { x = position.x, y = position.y },
    }
    local ok, why = reservations.claim("construction", target, pair, M.reservation_ttl, {
      surface_index = pair.station.surface.index,
      force_index = pair.station.force.index,
      fluid = plan.fluid,
      plan_id = plan.id,
      source = "fluid-turret-connection-planner-0719",
    })
    if not ok then
      for _, old in ipairs(claimed) do
        pcall(reservations.release, "construction", old, pair)
      end
      return false, why or "reservation-denied"
    end
    claimed[#claimed + 1] = target
  end
  plan.reservation_targets = claimed
  stat("tiles-reserved", #claimed)
  return true, "reserved"
end

local function release_route(pair, plan)
  local reservations = reservation_authority()
  if reservations and type(reservations.release) == "function" then
    for _, target in ipairs(plan and plan.reservation_targets or {}) do
      pcall(reservations.release, "construction", target, pair)
    end
  end
  if plan then plan.reservation_targets = {} end
end

local function station_pipe_count(pair)
  if type(_G.tech_priests_0358_station_item_count) == "function" then
    local ok, count = pcall(_G.tech_priests_0358_station_item_count, pair, M.pipe_item)
    if ok then return tonumber(count) or 0 end
  end
  local total = 0
  if type(_G.tech_priests_inventory_steward_sources_for_pair) == "function" then
    local ok, sources = pcall(_G.tech_priests_inventory_steward_sources_for_pair, pair)
    if ok and type(sources) == "table" then
      for _, source in ipairs(sources) do
        local inv = source and source.inv
        if inv and inv.valid then
          local ok_count, count = pcall(function() return inv.get_item_count(M.pipe_item) end)
          if ok_count then total = total + (tonumber(count) or 0) end
        end
      end
    end
  end
  return total
end

local function request_pipes(pair, plan)
  local remaining = math.max(1,
    #(plan.tiles or {}) - (tonumber(plan.current_index) or 1) + 1)
  pair.active_supply_request = {
    item = M.pipe_item,
    count = remaining,
    source = "fluid-turret-connection-planner-0719",
    purpose = "construction-fluid-turret-pipe",
    fluid = plan.fluid,
    plan_id = plan.id,
    tick = now(),
  }
  pair.logistic_requested_item = {
    item = M.pipe_item,
    count = remaining,
    source = "fluid-turret-connection-planner-0719",
    purpose = "construction-fluid-turret-pipe",
    plan_id = plan.id,
  }
  plan.state = "waiting-pipe-items"
  stat("pipe-requests")
end

local function clear_requests(pair, plan)
  for _, field in ipairs({ "active_supply_request", "logistic_requested_item" }) do
    local request = pair[field]
    if type(request) == "table"
      and request.source == "fluid-turret-connection-planner-0719"
      and (not plan or request.plan_id == plan.id)
    then
      pair[field] = nil
    end
  end
end

local function standard_fluid_route_is_busy(pair)
  if pair.fluid_pipe_plan_0691 or pair.fluid_output_pipe_plan_0696 then return true end
  for _, proposal in ipairs(pair.fluid_connection_proposals_0689 or {}) do
    if proposal.state == "source-network-found" then return true end
  end
  for _, proposal in ipairs(pair.fluid_output_sink_proposals_0694 or {}) do
    if proposal.state == "compatible-sink-found" then return true end
  end
  return false
end

local function blocker(pair)
  if standard_fluid_route_is_busy(pair) then return "standard-fluid-route" end
  if pair.construction_task_0338 then return "construction" end
  if valid(pair.combat_target) then return "combat" end
  if pair.roboport_repair_logistics_0715
    or pair.artillery_logistics_0713
    or pair.rocket_silo_logistics_0710
    or pair.energy_family_logistics_0707
    or pair.item_family_logistics_0702
    or pair.machine_logistics_0528
  then
    return "other-logistics"
  end
  if pair.direct_acquisition_target_lock_0650 then return "direct-acquisition" end
  for _, field in ipairs({ "repair_0516", "combat_repair_0517", "consecration_0515" }) do
    local state = pair[field]
    local phase = lower(type(state) == "table" and state.phase or "")
    if phase ~= "" and phase ~= "complete" and phase ~= "completed" and phase ~= "done" then
      return field
    end
  end
  return nil
end

local function current_proposal(pair)
  for _, proposal in ipairs(pair.fluid_turret_safe_proposals_0718 or {}) do
    if proposal.state == "source-network-found"
      and valid(proposal.turret)
      and proposal.source
      and valid(proposal.source.entity)
      and now() - (tonumber(proposal.tick) or -1000000) <= M.proposal_max_age
    then
      return proposal
    end
  end
  return nil
end

local function create_plan(pair, proposal)
  local plan = {
    version = M.version,
    id = tostring(station_unit(pair) or "?")
      .. ":turret:" .. tostring(proposal.turret_unit or proposal.turret_name)
      .. ":" .. tostring(now()),
    state = "planning",
    turret = proposal.turret,
    turret_name = proposal.turret_name,
    turret_unit = proposal.turret_unit,
    turret_fluidbox_index = proposal.fluidbox_index,
    fluid = proposal.fluid,
    source = proposal.source,
    source_segment_id = proposal.source.segment_id,
    turret_segment_id = segment_id(fluidbox(proposal.turret), proposal.fluidbox_index),
    current_index = 1,
    retries = {},
  }

  local source_ok, why, source_state = source_is_safe(plan, true)
  if not source_ok then return nil, why end
  plan.source_segment_id = source_state.segment_id

  local turret_ok, turret_why = turret_is_safe(pair, plan)
  if not turret_ok then return nil, turret_why end

  local route, route_why = shortest_route(pair, proposal, plan)
  if not route then
    record(pair, "route-rejected", route_why)
    return nil, route_why
  end
  local tiles = new_tiles(pair, route, plan)
  if #tiles == 0 then return nil, "already-connected" end
  plan.route = route
  plan.tiles = tiles
  plan.state = "planned"

  local claimed, claim_why = claim_route(pair, plan)
  if not claimed then return nil, claim_why end
  root().plans[plan.id] = plan
  pair.fluid_turret_pipe_plan_0719 = plan
  pair.fluid_turret_pipe_reject_until_0719 = nil
  stat("plans-created")
  stat("tiles-planned", #tiles)
  record(pair, "plan-created",
    plan.fluid .. " tiles=" .. tostring(#tiles)
      .. " turret=" .. safe(plan.turret_name))
  return plan, "created"
end

local function ensure_plan(pair)
  local plan = pair.fluid_turret_pipe_plan_0719
  if type(plan) == "table" and plan.state ~= "complete" and plan.state ~= "aborted" then
    return plan, "existing"
  end
  if (tonumber(pair.fluid_turret_pipe_reject_until_0719) or 0) > now() then
    return nil, "cooldown"
  end
  local blocked = blocker(pair)
  if blocked then return nil, "blocked:" .. blocked end
  local proposal = current_proposal(pair)
  if not proposal then return nil, "no-proposal" end
  return create_plan(pair, proposal)
end

local function current_tile(plan)
  return plan and plan.tiles and plan.tiles[tonumber(plan.current_index) or 1] or nil
end

local function validate_plan(pair, plan)
  if not (valid(plan.turret) and plan.source and valid(plan.source.entity)) then
    return false, "endpoint-invalid"
  end
  local source_ok, source_why, source_state = source_is_safe(plan, false)
  if not source_ok then return false, source_why end
  plan.source_segment_id = source_state.segment_id

  local turret_ok, turret_why, report = turret_is_safe(pair, plan)
  if not turret_ok then return false, turret_why end
  plan.turret_segment_id = segment_id(fluidbox(plan.turret), plan.turret_fluidbox_index)

  local tile = current_tile(plan)
  if tile then
    local allowed, why = tile_is_available(pair, tile, plan)
    if not allowed then return false, why end
  end
  return true, "valid", report
end

local function seed_task(pair, plan)
  if pair.construction_task_0338 then return true end
  local tile = current_tile(plan)
  if not tile then return false end
  if existing_compatible_pipe(pair, tile, plan) then
    plan.current_index = (tonumber(plan.current_index) or 1) + 1
    stat("tiles-adopted")
    return seed_task(pair, plan)
  end
  if station_pipe_count(pair) <= 0 then
    request_pipes(pair, plan)
    return false
  end
  clear_requests(pair, plan)
  plan.state = "building"
  pair.construction_task_0338 = {
    item_name = M.pipe_item,
    entity_name = M.pipe_entity,
    entity_type = "pipe",
    category = "deferred-network",
    target_position = { x = tile.x, y = tile.y },
    plan_reason = "fluid-turret-connection-plan-0719",
    phase = "planned",
    created_tick = now(),
    source = "fluid-turret-connection-planner-0719",
    fluid_turret_pipe_plan_0719 = true,
    fluid_turret_pipe_plan_id_0719 = plan.id,
    fluid_turret_pipe_index_0719 = plan.current_index,
    fluid_name_0719 = plan.fluid,
  }
  stat("tasks-seeded")
  return true
end

local function complete_plan(pair, plan)
  release_route(pair, plan)
  clear_requests(pair, plan)
  plan.state = "complete"
  plan.completed_tick = now()
  pair.fluid_turret_pipe_plan_last_0719 = plan
  pair.fluid_turret_pipe_plan_0719 = nil
  stat("plans-completed")
  record(pair, "plan-completed",
    plan.fluid .. " tiles=" .. tostring(#(plan.tiles or {})))
end

local function abort_plan(pair, plan, reason)
  release_route(pair, plan)
  clear_requests(pair, plan)
  if pair.construction_task_0338
    and pair.construction_task_0338.fluid_turret_pipe_plan_id_0719 == plan.id
  then
    pair.construction_task_0338 = nil
  end
  plan.state = "aborted"
  plan.result = reason
  plan.aborted_tick = now()
  pair.fluid_turret_pipe_plan_last_0719 = plan
  pair.fluid_turret_pipe_plan_0719 = nil
  pair.fluid_turret_pipe_reject_until_0719 = now() + M.rejection_cooldown
  stat("plans-aborted")
  record(pair, "plan-aborted", reason)
end

local function task_succeeded(pair, task)
  local success = pair.last_construction_success_0338
  return task and success
    and (tonumber(success.tick) or -1) >= (tonumber(task.created_tick) or now())
    and success.entity == M.pipe_entity
    and same_position({ x = success.x, y = success.y }, task.target_position)
end

local function after_construction_service(pair, plan, task, acted, why)
  if not (plan and task and task.fluid_turret_pipe_plan_id_0719 == plan.id) then
    return acted, why
  end
  local index = tonumber(task.fluid_turret_pipe_index_0719)
    or tonumber(plan.current_index) or 1
  if task_succeeded(pair, task)
    or existing_compatible_pipe(pair, task.target_position, plan)
  then
    plan.current_index = index + 1
    plan.retries[index] = nil
    stat("tiles-completed")
    if not current_tile(plan) then
      complete_plan(pair, plan)
      return true, "fluid-turret-pipe-complete"
    end
    seed_task(pair, plan)
    return true, "fluid-turret-pipe-tile-complete"
  end
  if why == "missing-item" then
    request_pipes(pair, plan)
    return false, "waiting-pipes"
  end
  if why == "blocked" or why == "create-failed" or why == "remove-failed" then
    plan.retries[index] = (tonumber(plan.retries[index]) or 0) + 1
    if plan.retries[index] >= M.max_retries_per_tile then
      abort_plan(pair, plan,
        "tile-failed:" .. safe(why) .. ":" .. position_key(task.target_position))
      return false, "aborted"
    end
  end
  return acted, why
end

local function patched_service_pair(pair, reason, ...)
  if root().enabled == false or not valid_pair(pair) then
    return previous_build_service_pair(pair, reason, ...)
  end
  local plan = pair.fluid_turret_pipe_plan_0719
  if not plan then plan = select(1, ensure_plan(pair)) end
  if plan then
    local ok, why = validate_plan(pair, plan)
    if not ok then
      abort_plan(pair, plan, why)
      return false, "fluid-turret-plan-invalid:" .. safe(why)
    end
    if plan.state == "waiting-pipe-items"
      and not pair.construction_task_0338
      and station_pipe_count(pair) <= 0
    then
      request_pipes(pair, plan)
      return false, "waiting-pipes"
    end
    seed_task(pair, plan)
  end

  local hidden_inputs, hidden_outputs, hidden_turrets
  if plan then
    hidden_inputs = pair.fluid_connection_proposals_0689
    hidden_outputs = pair.fluid_output_sink_proposals_0694
    hidden_turrets = pair.fluid_turret_safe_proposals_0718
    pair.fluid_connection_proposals_0689 = nil
    pair.fluid_output_sink_proposals_0694 = nil
    pair.fluid_turret_safe_proposals_0718 = nil
  end
  local task = pair.construction_task_0338
  local acted, why = previous_build_service_pair(pair, reason, ...)
  if plan then
    pair.fluid_connection_proposals_0689 = hidden_inputs
    pair.fluid_output_sink_proposals_0694 = hidden_outputs
    pair.fluid_turret_safe_proposals_0718 = hidden_turrets
  end
  return after_construction_service(pair, plan, task, acted, why)
end

local function patch_build(build)
  if not (build and type(build.service_pair) == "function")
    or build.fluid_turret_connection_planner_0719_active
  then
    return false
  end
  build.fluid_turret_connection_planner_0719_active = true
  previous_build_service_pair = build.service_pair
  build.service_pair = patched_service_pair
  return true
end

local function patch_diagnostics()
  local diagnostics = rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
    or rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diagnostics and type(diagnostics.pair_dump_lines) == "function")
    or diagnostics.fluid_turret_connection_planner_0719_wrapped
  then
    return false
  end
  diagnostics.fluid_turret_connection_planner_0719_wrapped = true
  local previous = diagnostics.pair_dump_lines
  diagnostics.pair_dump_lines = function(...)
    local lines = previous(...)
    lines = type(lines) == "table" and lines or {}
    local state = root()
    lines[#lines + 1] = "PAIR-DUMP-0468 FLUID-TURRET-CONNECTION-0719 enabled="
      .. safe(state.enabled)
      .. " ordinary_pipe_only=true fluid_mutations=0 cyclic_storage_refs=0"
      .. " plans=" .. safe(state.stats["plans-created"] or 0)
      .. " completed=" .. safe(state.stats["plans-completed"] or 0)
      .. " aborted=" .. safe(state.stats["plans-aborted"] or 0)
      .. " tiles=" .. safe(state.stats["tiles-completed"] or 0)
      .. " requests=" .. safe(state.stats["pipe-requests"] or 0)
    for _, pair in pairs(pair_map()) do
      if valid_pair(pair) then
        local plan = pair.fluid_turret_pipe_plan_0719 or {}
        local tile = current_tile(plan)
        lines[#lines + 1] = "PAIR-DUMP-0468 fluid-turret-pipe["
          .. safe(station_unit(pair)) .. "]"
          .. " state=" .. safe(plan.state or "none")
          .. " fluid=" .. safe(plan.fluid or "none")
          .. " index=" .. safe(plan.current_index or 0)
          .. "/" .. safe(plan.tiles and #plan.tiles or 0)
          .. " tile=" .. safe(tile and position_key(tile) or "none")
          .. " turret=" .. safe(plan.turret_name or "none")
      end
    end
    return lines
  end
  return true
end

function M.activate(build)
  patch_build(build)
  patch_diagnostics()
  _G.TechPriestsFluidTurretConnectionPlanner0719 = M
  return true
end

function M.install()
  root()
  local ok, build = pcall(require, "scripts.core.construction_planner")
  if not (ok and build) then return false end
  if not build.fluid_turret_connection_planner_0719_install_wrapped then
    build.fluid_turret_connection_planner_0719_install_wrapped = true
    previous_build_install = build.install
    build.install = function(...)
      local result = type(previous_build_install) == "function"
        and previous_build_install(...) or true
      M.activate(build)
      return result
    end
  end
  if rawget(_G, "TECH_PRIESTS_CONSTRUCTION_PLANNER_0338") then M.activate(build) end
  patch_diagnostics()
  _G.TechPriestsFluidTurretConnectionPlanner0719 = M
  if log then
    log("[Tech-Priests 0.1.674-dev] acyclic reserved source-to-turret ordinary-pipe planner armed")
  end
  return true
end

return M
