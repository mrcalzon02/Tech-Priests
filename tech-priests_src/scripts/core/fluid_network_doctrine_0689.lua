-- Tech Priests 0.1.666 real fluid-network doctrine.
--
-- This module never inserts, removes, sets, clears, or flushes fluid. Factorio's
-- real fluidbox and pipe-segment simulation remains the only fluid authority.
-- The doctrine inspects recipe fluid requirements, actual fluidbox filters,
-- production direction, pipe connections, segment contents, temperature, and
-- capacity. It blocks fluid prototype names from entering the item logistics
-- pipeline and produces read-only connection proposals for later construction
-- planning without placing pipes or moving priests by itself.

local M = {
  version = "0.1.666",
  storage_key = "fluid_network_doctrine_0689",
  pair_scan_cooldown = 60 * 8,
  machine_scan_cooldown = 60 * 5,
  proposal_ttl = 60 * 20,
  service_radius_floor = 28,
  service_radius_cap = 96,
  max_scan_machines = 96,
  max_scan_sources = 192,
  low_fluid_multiplier = 1.0,
  output_reserve_multiplier = 1.0,
}

local previous_final_activate
local previous_machine_service

local FATAL_STATES = {
  ["input-no-fluidbox"] = true,
  ["input-wrong-fluid"] = true,
  ["input-temperature-invalid"] = true,
  ["output-no-fluidbox"] = true,
  ["output-wrong-fluid"] = true,
  ["output-temperature-invalid"] = true,
}

local CONNECTION_STATES = {
  ["input-unconnected"] = true,
  ["output-unconnected-blocked"] = true,
}

local WAITING_STATES = {
  ["input-connected-empty"] = true,
  ["input-connected-low"] = true,
  ["output-connected-low-capacity"] = true,
  ["output-unconnected-buffer"] = true,
}

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

local function priest_unit(pair)
  return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil
end

local function pair_map()
  return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
end

local function machine_key(machine)
  if not valid(machine) then return nil end
  if machine.unit_number then return "unit:" .. tostring(machine.unit_number) end
  return tostring(machine.surface and machine.surface.index or "?")
    .. ":" .. tostring(machine.name or machine.type)
    .. ":" .. tostring(math.floor((machine.position.x or 0) * 10))
    .. ":" .. tostring(math.floor((machine.position.y or 0) * 10))
end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    forbid_fluid_item_requests = true,
    inspect_real_segments = true,
    produce_connection_proposals = true,
    stats = {},
    recent = {},
    pair_scan_due = {},
    machine_scan_due = {},
    machines = {},
    proposals = {},
  }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.forbid_fluid_item_requests == nil then r.forbid_fluid_item_requests = true end
  if r.inspect_real_segments == nil then r.inspect_real_segments = true end
  if r.produce_connection_proposals == nil then r.produce_connection_proposals = true end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  r.pair_scan_due = r.pair_scan_due or {}
  r.machine_scan_due = r.machine_scan_due or {}
  r.machines = r.machines or {}
  r.proposals = r.proposals or {}
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
    priest = safe(priest_unit(pair)),
    detail = tostring(detail or ""),
  }
  r.recent[#r.recent + 1] = event
  while #r.recent > 180 do table.remove(r.recent, 1) end
  return event
end

local function fluid_exists(name)
  return type(name) == "string"
    and name ~= ""
    and prototypes
    and prototypes.fluid
    and prototypes.fluid[name] ~= nil
end

local function get_recipe(machine)
  if not (valid(machine) and machine.get_recipe) then return nil end
  local ok, recipe = pcall(function() return machine.get_recipe() end)
  return ok and recipe or nil
end

local function normalize_recipe_member(member)
  if type(member) ~= "table" then return nil end
  local name = member.name or member[1]
  local kind = member.type or (member.name and "item")
  local amount = tonumber(member.amount or member.amount_min or member[2]) or 1
  if type(name) ~= "string" or name == "" then return nil end
  return {
    name = name,
    type = kind,
    amount = math.max(0, amount),
    minimum_temperature = tonumber(member.minimum_temperature),
    maximum_temperature = tonumber(member.maximum_temperature),
    temperature = tonumber(member.temperature),
    fluidbox_index = tonumber(member.fluidbox_index),
    probability = tonumber(member.probability) or 1,
  }
end

local function recipe_members(recipe, field)
  local out = {}
  if not recipe then return out end
  local raw
  local ok = pcall(function() raw = recipe[field] end)
  if not (ok and type(raw) == "table") then return out end
  for _, member in pairs(raw) do
    local normalized = normalize_recipe_member(member)
    if normalized then out[#out + 1] = normalized end
  end
  return out
end

local function recipe_fluid_inputs(recipe)
  local out = {}
  for _, ingredient in ipairs(recipe_members(recipe, "ingredients")) do
    if ingredient.type == "fluid" or fluid_exists(ingredient.name) then
      ingredient.type = "fluid"
      out[#out + 1] = ingredient
    end
  end
  return out
end

local function recipe_fluid_outputs(recipe)
  local out = {}
  for _, product in ipairs(recipe_members(recipe, "products")) do
    if product.type == "fluid" or fluid_exists(product.name) then
      product.type = "fluid"
      product.amount = product.amount * product.probability
      out[#out + 1] = product
    end
  end
  return out
end

local function recipe_item_members(recipe)
  local items = {}
  for _, ingredient in ipairs(recipe_members(recipe, "ingredients")) do
    if ingredient.type ~= "fluid" and not fluid_exists(ingredient.name) then
      items[#items + 1] = ingredient.name
    end
  end
  for _, product in ipairs(recipe_members(recipe, "products")) do
    if product.type ~= "fluid" and not fluid_exists(product.name) then
      items[#items + 1] = product.name
    end
  end
  return items
end

local function barrel_mediated(recipe)
  for _, name in ipairs(recipe_item_members(recipe)) do
    local text = lower(name)
    if text == "empty-barrel" or text:find("barrel", 1, true) then return true end
  end
  return false
end

local function fluidbox(machine)
  if not valid(machine) then return nil end
  local ok, box = pcall(function() return machine.fluidbox end)
  if ok and box and box.valid then return box end
  return nil
end

local function prototype_records(box, index)
  local out = {}
  if not (box and box.valid) then return out end
  local ok, value = pcall(function() return box.get_prototype(index) end)
  if not ok or value == nil then return out end
  if type(value) == "table" and value.object_name == nil then
    for _, prototype in pairs(value) do
      if prototype then out[#out + 1] = prototype end
    end
  else
    out[#out + 1] = value
  end
  return out
end

local function production_type(box, index)
  local has_input, has_output = false, false
  for _, prototype in ipairs(prototype_records(box, index)) do
    local production
    pcall(function() production = prototype.production_type end)
    production = lower(production)
    if production == "input" or production == "input-output" then has_input = true end
    if production == "output" or production == "input-output" then has_output = true end
  end
  return has_input, has_output
end

local function filter_record(box, index)
  local filter
  pcall(function() filter = box.get_filter(index) end)
  if type(filter) == "table" and filter.name then return filter end
  local locked
  pcall(function() locked = box.get_locked_fluid(index) end)
  if type(locked) == "string" and locked ~= "" then return { name = locked } end
  for _, prototype in ipairs(prototype_records(box, index)) do
    local fluid
    pcall(function() fluid = prototype.filter end)
    if fluid then
      local name
      pcall(function() name = fluid.name end)
      if type(name) == "string" then return { name = name } end
    end
  end
  return nil
end

local function current_fluid(box, index)
  local fluid
  pcall(function() fluid = box[index] end)
  if type(fluid) == "table" and fluid.name and (tonumber(fluid.amount) or 0) > 0 then
    return {
      name = fluid.name,
      amount = tonumber(fluid.amount) or 0,
      temperature = tonumber(fluid.temperature),
    }
  end
  return nil
end

local function segment_contents(box, index)
  local contents
  pcall(function() contents = box.get_fluid_segment_contents(index) end)
  if type(contents) ~= "table" then return {} end
  local out = {}
  for name, amount in pairs(contents) do
    if type(name) == "string" and (tonumber(amount) or 0) > 0 then
      out[name] = tonumber(amount) or 0
    end
  end
  return out
end

local function segment_capacity(box, index)
  local capacity = 0
  pcall(function() capacity = tonumber(box.get_capacity(index)) or 0 end)
  return capacity
end

local function pipe_connections(box, index)
  local connections = {}
  pcall(function() connections = box.get_pipe_connections(index) or {} end)
  local out = {}
  for connection_index, connection in pairs(connections or {}) do
    if type(connection) == "table" then
      local target_owner
      if connection.target then pcall(function() target_owner = connection.target.owner end) end
      out[#out + 1] = {
        index = connection_index,
        position = connection.position,
        target_position = connection.target_position,
        target = connection.target,
        target_owner = target_owner,
        target_fluidbox_index = connection.target_fluidbox_index,
        flow_direction = connection.flow_direction,
        connection_type = connection.connection_type,
      }
    end
  end
  return out
end

local function connection_count(box, index)
  local count = 0
  local records = pipe_connections(box, index)
  for _, connection in ipairs(records) do
    if connection.target or valid(connection.target_owner) then count = count + 1 end
  end
  if count == 0 then
    local connected = {}
    pcall(function() connected = box.get_connections(index) or {} end)
    for _, other in pairs(connected or {}) do
      if other and other.valid then count = count + 1 end
    end
  end
  return count, records
end

local function temperature_allowed(requirement, fluid)
  if not fluid or fluid.name ~= requirement.name then return true end
  local temperature = tonumber(fluid.temperature)
  if not temperature then return true end
  if requirement.temperature and math.abs(temperature - requirement.temperature) > 0.001 then return false end
  if requirement.minimum_temperature and temperature < requirement.minimum_temperature then return false end
  if requirement.maximum_temperature and temperature > requirement.maximum_temperature then return false end
  return true
end

local function box_matches_requirement(box, index, requirement, direction, used)
  if used[index] then return false end
  if requirement.fluidbox_index and requirement.fluidbox_index ~= index then return false end
  local input, output = production_type(box, index)
  if direction == "input" and not input then return false end
  if direction == "output" and not output then return false end
  local filter = filter_record(box, index)
  if filter and filter.name and filter.name ~= requirement.name then return false end
  return true
end

local function choose_box(box, requirement, direction, used)
  if not (box and box.valid) then return nil end
  local best, best_score
  for index = 1, #box do
    if box_matches_requirement(box, index, requirement, direction, used) then
      local filter = filter_record(box, index)
      local fluid = current_fluid(box, index)
      local score = 0
      if requirement.fluidbox_index == index then score = score + 1000 end
      if filter and filter.name == requirement.name then score = score + 500 end
      if fluid and fluid.name == requirement.name then score = score + 250 end
      if not best_score or score > best_score then best, best_score = index, score end
    end
  end
  if best then used[best] = true end
  return best
end

local function sum_contents(contents)
  local total = 0
  for _, amount in pairs(contents or {}) do total = total + (tonumber(amount) or 0) end
  return total
end

local function unexpected_fluid(contents, expected)
  for name, amount in pairs(contents or {}) do
    if name ~= expected and (tonumber(amount) or 0) > 0.001 then return name, amount end
  end
  return nil, 0
end

local function inspect_input(box, index, requirement)
  if not index then
    return {
      direction = "input",
      requirement = requirement,
      state = "input-no-fluidbox",
      severity = "fatal",
    }
  end
  local fluid = current_fluid(box, index)
  local contents = segment_contents(box, index)
  local wrong, wrong_amount = unexpected_fluid(contents, requirement.name)
  local connections, pipe_records = connection_count(box, index)
  local capacity = segment_capacity(box, index)
  local available = tonumber(contents[requirement.name]) or (fluid and fluid.name == requirement.name and fluid.amount) or 0

  local state, severity
  if wrong then
    state, severity = "input-wrong-fluid", "fatal"
  elseif fluid and fluid.name ~= requirement.name then
    state, severity = "input-wrong-fluid", "fatal"
    wrong, wrong_amount = fluid.name, fluid.amount
  elseif not temperature_allowed(requirement, fluid) then
    state, severity = "input-temperature-invalid", "fatal"
  elseif connections <= 0 then
    state, severity = "input-unconnected", "connection"
  elseif available <= 0.001 then
    state, severity = "input-connected-empty", "waiting"
  elseif available + 0.001 < requirement.amount * M.low_fluid_multiplier then
    state, severity = "input-connected-low", "waiting"
  else
    state, severity = "input-ready", "ready"
  end
  return {
    direction = "input",
    requirement = requirement,
    index = index,
    state = state,
    severity = severity,
    current = fluid,
    segment_contents = contents,
    available = available,
    capacity = capacity,
    connections = connections,
    pipe_connections = pipe_records,
    wrong_fluid = wrong,
    wrong_amount = wrong_amount,
  }
end

local function inspect_output(box, index, requirement)
  if not index then
    return {
      direction = "output",
      requirement = requirement,
      state = "output-no-fluidbox",
      severity = "fatal",
    }
  end
  local fluid = current_fluid(box, index)
  local contents = segment_contents(box, index)
  local wrong, wrong_amount = unexpected_fluid(contents, requirement.name)
  local connections, pipe_records = connection_count(box, index)
  local capacity = segment_capacity(box, index)
  local occupied = sum_contents(contents)
  local free = math.max(0, capacity - occupied)
  local needed = requirement.amount * M.output_reserve_multiplier

  local state, severity
  if wrong then
    state, severity = "output-wrong-fluid", "fatal"
  elseif fluid and fluid.name ~= requirement.name then
    state, severity = "output-wrong-fluid", "fatal"
    wrong, wrong_amount = fluid.name, fluid.amount
  elseif not temperature_allowed(requirement, fluid) then
    state, severity = "output-temperature-invalid", "fatal"
  elseif connections <= 0 and free + 0.001 < needed then
    state, severity = "output-unconnected-blocked", "connection"
  elseif connections <= 0 then
    state, severity = "output-unconnected-buffer", "waiting"
  elseif free + 0.001 < needed then
    state, severity = "output-connected-low-capacity", "waiting"
  else
    state, severity = "output-ready", "ready"
  end
  return {
    direction = "output",
    requirement = requirement,
    index = index,
    state = state,
    severity = severity,
    current = fluid,
    segment_contents = contents,
    occupied = occupied,
    free = free,
    capacity = capacity,
    connections = connections,
    pipe_connections = pipe_records,
    wrong_fluid = wrong,
    wrong_amount = wrong_amount,
  }
end

local function aggregate(records)
  local aggregate_state = "fluid-ready"
  local aggregate_severity = "ready"
  for _, record in ipairs(records) do
    if FATAL_STATES[record.state] then
      return "fluid-fatal", "fatal", record
    end
    if CONNECTION_STATES[record.state] then
      aggregate_state, aggregate_severity = "fluid-connection-required", "connection"
    elseif WAITING_STATES[record.state] and aggregate_severity == "ready" then
      aggregate_state, aggregate_severity = "fluid-network-waiting", "waiting"
    end
  end
  return aggregate_state, aggregate_severity, nil
end

function M.inspect_machine(pair, machine, force)
  if not (valid_pair(pair) and valid(machine)) then return nil, "invalid" end
  local recipe = get_recipe(machine)
  if not recipe then return nil, "no-recipe" end
  local inputs = recipe_fluid_inputs(recipe)
  local outputs = recipe_fluid_outputs(recipe)
  if #inputs == 0 and #outputs == 0 then return nil, "no-fluid-recipe" end

  local key = machine_key(machine)
  local r = root()
  if not force and key and (r.machine_scan_due[key] or 0) > now() then
    return r.machines[key], "cached"
  end
  if key then r.machine_scan_due[key] = now() + M.machine_scan_cooldown end

  local box = fluidbox(machine)
  local used = {}
  local records = {}
  for _, requirement in ipairs(inputs) do
    local index = choose_box(box, requirement, "input", used)
    records[#records + 1] = inspect_input(box, index, requirement)
  end
  for _, requirement in ipairs(outputs) do
    local index = choose_box(box, requirement, "output", used)
    records[#records + 1] = inspect_output(box, index, requirement)
  end

  local state, severity, first_fatal = aggregate(records)
  local report = {
    version = M.version,
    tick = now(),
    machine = machine,
    machine_name = machine.name,
    machine_unit = machine.unit_number,
    station_unit = station_unit(pair),
    recipe_name = recipe.name,
    state = state,
    severity = severity,
    inputs = inputs,
    outputs = outputs,
    records = records,
    barrel_mediated = barrel_mediated(recipe),
    first_fatal = first_fatal and first_fatal.state or nil,
    read_only = true,
  }
  if key then r.machines[key] = report end
  pair.machine_fluid_network_0689 = report
  stat("machines_inspected")
  stat("state_" .. state)
  return report, "inspected"
end

local function service_radius(pair)
  local radius = tonumber(pair and pair.radius) or M.service_radius_floor
  if valid_pair(pair) and type(_G.get_station_operating_radius) == "function" then
    local ok, value = pcall(_G.get_station_operating_radius, pair.station)
    if ok and tonumber(value) then radius = tonumber(value) end
  end
  return math.max(8, math.min(math.max(radius, M.service_radius_floor), M.service_radius_cap))
end

local function routed_find(surface, filters, category, negative_key, ttl)
  local scanner = rawget(_G, "TechPriestsScanRouting0610")
  if not scanner then
    local ok, module = pcall(require, "scripts.core.scan_routing_0610")
    if ok then scanner = module end
  end
  if scanner and type(scanner.find_entities) == "function" then
    local entities = select(1, scanner.find_entities(surface, filters, {
      category = category,
      negative_key = negative_key,
      negative_ttl = ttl or 60 * 4,
    }))
    return entities or {}
  end
  local ok, entities = pcall(function() return surface.find_entities_filtered(filters) end)
  return ok and entities or {}
end

local function entity_fluid_segments(entity, wanted)
  local results = {}
  local box = fluidbox(entity)
  if not box then return results end
  for index = 1, #box do
    local contents = segment_contents(box, index)
    local amount = tonumber(contents[wanted]) or 0
    local fluid = current_fluid(box, index)
    if amount <= 0 and fluid and fluid.name == wanted then amount = fluid.amount end
    if amount > 0.001 then
      local segment_id
      pcall(function() segment_id = box.get_fluid_segment_id(index) end)
      results[#results + 1] = {
        entity = entity,
        fluidbox_index = index,
        segment_id = segment_id,
        amount = amount,
        capacity = segment_capacity(box, index),
      }
    end
  end
  return results
end

local function connection_target_positions(record)
  local out = {}
  for _, connection in ipairs(record.pipe_connections or {}) do
    local position = connection.target_position or connection.position
    if position then out[#out + 1] = { x = position.x, y = position.y } end
  end
  return out
end

local function find_source_candidate(pair, machine, fluid_name, target_positions)
  if not (valid_pair(pair) and valid(machine) and fluid_exists(fluid_name)) then return nil end
  local radius = service_radius(pair)
  local position = pair.station.position
  local entities = routed_find(machine.surface, {
    area = {
      { position.x - radius, position.y - radius },
      { position.x + radius, position.y + radius },
    },
    force = machine.force,
    type = FLUID_ENTITY_TYPES,
    limit = M.max_scan_sources,
  }, "fluid-network-source", "fluid-network-source:"
      .. tostring(machine.surface.index) .. ":"
      .. tostring(machine.force.index) .. ":"
      .. tostring(fluid_name), 60 * 5)

  local best, best_score
  for _, entity in pairs(entities) do
    if valid(entity) and entity ~= machine then
      for _, segment in ipairs(entity_fluid_segments(entity, fluid_name)) do
        local nearest = dist_sq(entity.position, machine.position)
        for _, target in ipairs(target_positions or {}) do
          nearest = math.min(nearest, dist_sq(entity.position, target))
        end
        local score = nearest - math.min(segment.amount, 100000) * 0.001
        if not best_score or score < best_score then
          best, best_score = {
            entity = entity,
            entity_name = entity.name,
            entity_unit = entity.unit_number,
            position = { x = entity.position.x, y = entity.position.y },
            fluidbox_index = segment.fluidbox_index,
            segment_id = segment.segment_id,
            amount = segment.amount,
            capacity = segment.capacity,
            distance_sq = nearest,
          }, score
        end
      end
    end
  end
  return best
end

local function build_connection_proposals(pair, report)
  if not (valid_pair(pair) and report and valid(report.machine)) then return {} end
  local proposals = {}
  for _, record in ipairs(report.records or {}) do
    if record.state == "input-unconnected" or record.state == "input-connected-empty" then
      local targets = connection_target_positions(record)
      local source = find_source_candidate(pair, report.machine, record.requirement.name, targets)
      local proposal = {
        version = M.version,
        tick = now(),
        expires_tick = now() + M.proposal_ttl,
        read_only = true,
        action = "connect-fluid-input",
        machine = report.machine,
        machine_name = report.machine_name,
        machine_unit = report.machine_unit,
        fluid = record.requirement.name,
        amount_per_craft = record.requirement.amount,
        fluidbox_index = record.index,
        connection_targets = targets,
        source = source,
        state = source and "source-network-found" or "no-source-network-found",
      }
      proposals[#proposals + 1] = proposal
    elseif record.state == "output-unconnected-buffer"
      or record.state == "output-unconnected-blocked"
    then
      proposals[#proposals + 1] = {
        version = M.version,
        tick = now(),
        expires_tick = now() + M.proposal_ttl,
        read_only = true,
        action = "connect-fluid-output",
        machine = report.machine,
        machine_name = report.machine_name,
        machine_unit = report.machine_unit,
        fluid = record.requirement.name,
        amount_per_craft = record.requirement.amount,
        fluidbox_index = record.index,
        connection_targets = connection_target_positions(record),
        source = nil,
        state = "output-network-required",
      }
    end
  end

  local key = machine_key(report.machine)
  if key then root().proposals[key] = proposals end
  pair.fluid_connection_proposals_0689 = proposals
  if #proposals > 0 then stat("connection_proposals_created", #proposals) end
  return proposals
end

local function clear_illegal_request(pair, field)
  local request = pair and pair[field]
  if type(request) ~= "table" then return false end
  local item = request.item or request.item_name or request.requested_item
  if not fluid_exists(item) then return false end
  local source = lower(request.source)
  if source ~= "" and not source:find("machine%-logistics", 1, false)
    and not source:find("fluid", 1, true)
  then
    return false
  end
  pair[field] = nil
  record(pair, "fluid-item-request-rejected", field .. " fluid=" .. safe(item))
  return true
end

local function release_machine_reservation(pair, state)
  local reservations = rawget(_G, "TechPriestsWorkReservations0601")
  if not reservations then
    local ok, module = pcall(require, "scripts.core.work_reservations")
    if ok then reservations = module end
  end
  if reservations and type(reservations.release) == "function" and state and valid(state.machine) then
    pcall(reservations.release, "machine-logistics", state.machine, pair)
  end
end

local function sanitize_fluid_as_item_state(pair)
  local changed = false
  changed = clear_illegal_request(pair, "active_supply_request") or changed
  changed = clear_illegal_request(pair, "logistic_requested_item") or changed
  changed = clear_illegal_request(pair, "supply_request") or changed
  local state = pair and pair.machine_logistics_0528
  if type(state) == "table" and fluid_exists(state.item) then
    release_machine_reservation(pair, state)
    record(pair, "fluid-machine-state-rejected", safe(state.action) .. " fluid=" .. safe(state.item))
    pair.machine_logistics_0528 = nil
    changed = true
  end
  if changed then stat("fluid_item_pipeline_blocks") end
  return changed
end

local function inspect_active_state(pair)
  local state = pair and pair.machine_logistics_0528
  if not (type(state) == "table" and valid(state.machine)) then return nil end
  local report = M.inspect_machine(pair, state.machine, false)
  if report then
    state.fluid_network_state_0689 = report.state
    state.fluid_network_severity_0689 = report.severity
    state.fluid_network_tick_0689 = report.tick
    build_connection_proposals(pair, report)
  end
  return report
end

local function scan_pair(pair, force)
  if not valid_pair(pair) then return 0 end
  local key = tostring(station_unit(pair) or "?")
  local r = root()
  if not force and (r.pair_scan_due[key] or 0) > now() then return 0 end
  r.pair_scan_due[key] = now() + M.pair_scan_cooldown

  local radius = service_radius(pair)
  local position = pair.station.position
  local machines = routed_find(pair.station.surface, {
    area = {
      { position.x - radius, position.y - radius },
      { position.x + radius, position.y + radius },
    },
    force = pair.station.force,
    type = { "assembling-machine", "furnace", "rocket-silo" },
    limit = M.max_scan_machines,
  }, "fluid-network-machine", "fluid-network-machine:"
      .. tostring(pair.station.surface.index) .. ":"
      .. tostring(pair.station.force.index) .. ":"
      .. key, 60 * 4)

  local inspected = 0
  local worst
  for _, machine in pairs(machines) do
    local report = M.inspect_machine(pair, machine, false)
    if report then
      inspected = inspected + 1
      build_connection_proposals(pair, report)
      if not worst
        or report.severity == "fatal"
        or (report.severity == "connection" and worst.severity ~= "fatal")
        or (report.severity == "waiting" and worst.severity == "ready")
      then
        worst = report
      end
    end
  end
  pair.fluid_network_summary_0689 = {
    version = M.version,
    tick = now(),
    inspected = inspected,
    worst_state = worst and worst.state or "none",
    worst_machine = worst and worst.machine_name or nil,
    worst_machine_unit = worst and worst.machine_unit or nil,
    read_only = true,
  }
  stat("pair_scans")
  stat("pair_machines_inspected", inspected)
  return inspected
end

local function patched_machine_service(pair, reason, ...)
  if root().enabled == false or not valid_pair(pair) then
    return previous_machine_service(pair, reason, ...)
  end
  sanitize_fluid_as_item_state(pair)
  inspect_active_state(pair)
  local acted, why = previous_machine_service(pair, reason, ...)
  sanitize_fluid_as_item_state(pair)
  local report = inspect_active_state(pair)
  if not report and (why == "no-machine-task" or why == "cooldown") then scan_pair(pair, false) end
  return acted, why
end

local function patch_machine(machine)
  if not (machine and type(machine.service_pair) == "function")
    or machine.fluid_network_doctrine_0689_active
  then
    return false
  end
  machine.fluid_network_doctrine_0689_active = true
  previous_machine_service = machine.service_pair
  machine.service_pair = patched_machine_service
  return true
end

local function patch_diagnostics()
  local diagnostics = rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
    or rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diagnostics and type(diagnostics.pair_dump_lines) == "function")
    or diagnostics.fluid_network_doctrine_0689_wrapped
  then
    return false
  end
  diagnostics.fluid_network_doctrine_0689_wrapped = true
  local previous = diagnostics.pair_dump_lines
  diagnostics.pair_dump_lines = function(...)
    local lines = previous(...)
    lines = type(lines) == "table" and lines or {}
    local r = root()
    lines[#lines + 1] = "PAIR-DUMP-0468 FLUID-NETWORK-0689 enabled="
      .. safe(r.enabled)
      .. " read_only=true"
      .. " fluid_mutations=0"
      .. " inspected=" .. safe(r.stats.machines_inspected or 0)
      .. " ready=" .. safe(r.stats.state_fluid_ready or 0)
      .. " waiting=" .. safe(r.stats.state_fluid_network_waiting or 0)
      .. " connection_required=" .. safe(r.stats.state_fluid_connection_required or 0)
      .. " fatal=" .. safe(r.stats.state_fluid_fatal or 0)
      .. " item_pipeline_blocks=" .. safe(r.stats.fluid_item_pipeline_blocks or 0)
      .. " proposals=" .. safe(r.stats.connection_proposals_created or 0)
    for _, pair in pairs(pair_map()) do
      if valid_pair(pair) then
        local summary = pair.fluid_network_summary_0689 or {}
        local active = pair.machine_fluid_network_0689 or {}
        local proposals = pair.fluid_connection_proposals_0689 or {}
        lines[#lines + 1] = "PAIR-DUMP-0468 fluid-network[" .. safe(station_unit(pair)) .. "]"
          .. " active_state=" .. safe(active.state or "none")
          .. " active_machine=" .. safe(active.machine_name or "none")
          .. " recipe=" .. safe(active.recipe_name or "none")
          .. " barrel_mediated=" .. safe(active.barrel_mediated or false)
          .. " inspected=" .. safe(summary.inspected or 0)
          .. " worst=" .. safe(summary.worst_state or "none")
          .. " proposals=" .. safe(#proposals)
      end
    end
    for index = math.max(1, #r.recent - 10), #r.recent do
      local event = r.recent[index]
      if event then
        lines[#lines + 1] = "PAIR-DUMP-0468 fluid-network.recent[" .. safe(index) .. "]"
          .. " tick=" .. safe(event.tick)
          .. " action=" .. safe(event.action)
          .. " station=" .. safe(event.station)
          .. " priest=" .. safe(event.priest)
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
      name = "fluid_network_doctrine_0689_scan",
      category = "machine-logistics",
      interval = 173,
      priority = 72,
      budget = 8,
      note = "read-only real fluidbox and pipe-segment inspection",
      fn = function(_, budget)
        local count = 0
        for _, pair in pairs(pair_map()) do
          if valid_pair(pair) then
            scan_pair(pair, false)
            count = count + 1
            if count >= (tonumber(budget) or 8) then break end
          end
        end
        return count > 0, "pairs=" .. safe(count)
      end,
    })
  end
end

function M.activate(machine)
  patch_machine(machine)
  patch_diagnostics()
  _G.TechPriestsFluidNetworkDoctrine0689 = M
  _G.tech_priests_fluid_network_inspect_0689 = M.inspect_machine
  return true
end

function M.install()
  root()
  local ok, final = pcall(require, "scripts.core.machine_logistics_final_authority_0684")
  if ok and final and type(final.activate) == "function" then
    if not final.fluid_network_doctrine_0689_activate_wrapped then
      final.fluid_network_doctrine_0689_activate_wrapped = true
      previous_final_activate = final.activate
      final.activate = function(machine, ...)
        local result = previous_final_activate(machine, ...)
        M.activate(machine)
        return result
      end
    end
    local machine = rawget(_G, "TECH_PRIESTS_MACHINE_LOGISTICS_FULFILLMENT_0528")
    if machine then M.activate(machine) end
  end
  register_service()
  patch_diagnostics()
  _G.TechPriestsFluidNetworkDoctrine0689 = M
  _G.tech_priests_fluid_network_inspect_0689 = M.inspect_machine
  if log then
    log("[Tech-Priests 0.1.666] real fluid-network doctrine armed; read-only segment inspection active and fluid-to-item logistics is forbidden")
  end
  return true
end

return M
