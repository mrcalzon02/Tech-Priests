-- Tech Priests 0.1.674-dev rocket-silo readiness doctrine.
--
-- Rocket silos are not ordinary assemblers. This module inspects their crafting
-- inputs, fluid prerequisites, rocket-part progress, launch-state machine,
-- payload/cargo inventories, trash, logistics ownership, and connected inserter
-- or loader automation. It is strictly read-only and creates no delivery,
-- launch, cargo, recipe, movement, or reservation task.

local M = {
  version = "0.1.674-dev",
  storage_key = "rocket_silo_readiness_0709",
  scan_interval = 60 * 5,
  machine_cache_ticks = 60 * 3,
  service_radius_floor = 28,
  service_radius_cap = 96,
  max_scan_entities = 64,
  ingredient_cycles = 2,
}

local function now() return game and game.tick or 0 end
local function valid(entity) return entity and entity.valid end
local function safe(value)
  if value == nil then return "nil" end
  local ok, text = pcall(tostring, value)
  return ok and text or "?"
end
local function valid_pair(pair) return pair and valid(pair.station) and valid(pair.priest) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function dist_sq(a, b)
  if not (a and b) then return 999999999 end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end

local function entity_key(entity)
  if not valid(entity) then return nil end
  if entity.unit_number then return "unit:" .. tostring(entity.unit_number) end
  return tostring(entity.surface and entity.surface.index or "?") .. ":"
    .. tostring(entity.name or "rocket-silo") .. ":"
    .. tostring(math.floor((entity.position.x or 0) * 10)) .. ":"
    .. tostring(math.floor((entity.position.y or 0) * 10))
end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    read_only = true,
    stats = {},
    recent = {},
    scan_due = {},
    machine_due = {},
    reports = {},
  }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.read_only == nil then r.read_only = true end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  r.scan_due = r.scan_due or {}
  r.machine_due = r.machine_due or {}
  r.reports = r.reports or {}
  return r
end

local function stat(name, amount)
  local r = root()
  r.stats[name] = (r.stats[name] or 0) + (amount or 1)
end

local function record(pair, action, detail)
  local r = root()
  stat(action)
  r.recent[#r.recent + 1] = {
    tick = now(),
    action = tostring(action or "event"),
    station = safe(station_unit(pair)),
    detail = tostring(detail or ""),
  }
  while #r.recent > 140 do table.remove(r.recent, 1) end
end

local function inventory(entity, id)
  if not (valid(entity) and id and entity.get_inventory) then return nil end
  local ok, inv = pcall(function() return entity.get_inventory(id) end)
  return ok and inv and inv.valid and inv or nil
end

local function contents(inv)
  local out = {}
  if not (inv and inv.valid) then return out end
  local ok, raw = pcall(function() return inv.get_contents() end)
  if not (ok and type(raw) == "table") then return out end
  for key, value in pairs(raw) do
    local name, count
    if type(key) == "string" then
      name = key
      count = type(value) == "table" and tonumber(value.count or value.amount or value[2]) or tonumber(value)
    elseif type(value) == "table" then
      name = value.name or value.item or value[1]
      count = tonumber(value.count or value.amount or value[2])
    end
    if type(name) == "string" and (tonumber(count) or 0) > 0 then
      out[#out + 1] = { name = name, count = tonumber(count) or 1 }
    end
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

local function item_count(inv, item)
  if not (inv and inv.valid and item) then return 0 end
  local ok, count = pcall(function() return inv.get_item_count(item) end)
  return ok and (tonumber(count) or 0) or 0
end

local function empty_slots(inv)
  if not (inv and inv.valid) then return 0 end
  local ok, count = pcall(function() return inv.count_empty_stacks() end)
  return ok and (tonumber(count) or 0) or 0
end

local function recipe_of(entity)
  if not valid(entity) then return nil end
  local recipe
  if entity.get_recipe then pcall(function() recipe = entity.get_recipe() end) end
  if not recipe then pcall(function() recipe = entity.recipe end) end
  return recipe
end

local function recipe_members(recipe, field)
  local out = {}
  if not recipe then return out end
  local members
  pcall(function() members = recipe[field] end)
  for _, member in pairs(members or {}) do
    local name, amount, typ
    pcall(function()
      name = member.name or member[1]
      amount = tonumber(member.amount or member[2]) or 1
      typ = member.type or "item"
    end)
    if type(name) == "string" and name ~= "" then
      out[#out + 1] = {
        name = name,
        amount = math.max(0, amount or 0),
        type = typ or "item",
      }
    end
  end
  table.sort(out, function(a, b)
    if a.type ~= b.type then return a.type < b.type end
    return a.name < b.name
  end)
  return out
end

local function status_name(status)
  if not (defines and defines.rocket_silo_status) then return safe(status) end
  for name, value in pairs(defines.rocket_silo_status) do
    if value == status then return name end
  end
  return safe(status)
end

local function entity_status_name(status)
  if not (defines and defines.entity_status) then return safe(status) end
  for name, value in pairs(defines.entity_status) do
    if value == status then return name end
  end
  return safe(status)
end

local function rocket_status(entity)
  local value
  pcall(function() value = entity.rocket_silo_status end)
  return value, status_name(value)
end

local function rocket_parts(entity)
  local value = 0
  pcall(function() value = tonumber(entity.rocket_parts) or 0 end)
  return value
end

local function parts_required(entity)
  local value = 0
  pcall(function() value = tonumber(entity.prototype.rocket_parts_required) or 0 end)
  return value
end

local function connected_automation(entity)
  if not valid(entity) then return false, {} end
  local reasons = {}
  local box
  pcall(function() box = entity.bounding_box end)
  local p = entity.position
  local pad = 3
  local area = box and {
    { box.left_top.x - pad, box.left_top.y - pad },
    { box.right_bottom.x + pad, box.right_bottom.y + pad },
  } or {
    { p.x - pad, p.y - pad },
    { p.x + pad, p.y + pad },
  }
  local nearby = {}
  pcall(function()
    nearby = entity.surface.find_entities_filtered({
      area = area,
      force = entity.force,
      type = { "inserter", "loader", "loader-1x1" },
      limit = 96,
    }) or {}
  end)
  for _, candidate in pairs(nearby) do
    if candidate.type == "inserter" then
      local pickup, drop
      pcall(function() pickup = candidate.pickup_target end)
      pcall(function() drop = candidate.drop_target end)
      if pickup == entity or drop == entity then
        reasons[#reasons + 1] = "connected-inserter:" .. safe(candidate.unit_number)
      end
    else
      local container
      pcall(function() container = candidate.loader_container end)
      if container == entity then
        reasons[#reasons + 1] = "connected-loader:" .. safe(candidate.unit_number)
      end
    end
  end
  return #reasons > 0, reasons
end

local function logistics_state(entity)
  local network, cell, transitional, target, automatic
  pcall(function() network = entity.logistic_network end)
  pcall(function() cell = entity.logistic_cell end)
  pcall(function() transitional = entity.use_transitional_requests == true end)
  pcall(function() target = entity.transitional_request_target end)
  pcall(function() automatic = entity.send_to_orbit_automatically == true end)
  return {
    logistic_network = network,
    logistic_network_present = network ~= nil,
    logistic_cell = cell,
    logistic_cell_present = cell ~= nil,
    use_transitional_requests = transitional == true,
    transitional_request_target = target,
    transitional_request_target_present = target ~= nil,
    send_to_orbit_automatically = automatic == true,
  }
end

local function fluidbox(entity)
  if not valid(entity) then return nil end
  local ok, box = pcall(function() return entity.fluidbox end)
  return ok and box and box.valid and box or nil
end

local function production_type(box, index)
  local input, output = false, false
  local prototypes = {}
  local ok, value = pcall(function() return box.get_prototype(index) end)
  if ok and value then
    if type(value) == "table" and value.object_name == nil then
      for _, prototype in pairs(value) do prototypes[#prototypes + 1] = prototype end
    else
      prototypes[#prototypes + 1] = value
    end
  end
  for _, prototype in ipairs(prototypes) do
    local kind
    pcall(function() kind = prototype.production_type end)
    if kind == "input" or kind == "input-output" then input = true end
    if kind == "output" or kind == "input-output" then output = true end
  end
  return input, output
end

local function segment_contents(box, index)
  local result = {}
  if box and box.valid then pcall(function() result = box.get_fluid_segment_contents(index) or {} end) end
  return type(result) == "table" and result or {}
end

local function local_fluid(box, index)
  local fluid
  if box and box.valid then pcall(function() fluid = box[index] end) end
  if type(fluid) == "table" and fluid.name and (tonumber(fluid.amount) or 0) > 0 then
    return { name = fluid.name, amount = tonumber(fluid.amount) or 0, temperature = tonumber(fluid.temperature) }
  end
  return nil
end

local function connection_count(box, index)
  if not (box and box.valid) then return 0 end
  local total = 0
  local connections = {}
  pcall(function() connections = box.get_pipe_connections(index) or {} end)
  for _, connection in pairs(connections or {}) do
    if type(connection) == "table" then
      local owner
      if connection.target then pcall(function() owner = connection.target.owner end) end
      if connection.target ~= nil or valid(owner) then total = total + 1 end
    end
  end
  if total == 0 then
    local connected = {}
    pcall(function() connected = box.get_connections(index) or {} end)
    for _, other in pairs(connected or {}) do if other and other.valid then total = total + 1 end end
  end
  return total
end

local function fluid_report(entity)
  local box = fluidbox(entity)
  local out = {
    present = box ~= nil,
    input_ready = true,
    output_ready = true,
    records = {},
    blockers = {},
  }
  if not box then return out end
  for index = 1, #box do
    local input, output = production_type(box, index)
    local segment = segment_contents(box, index)
    local local_record = local_fluid(box, index)
    if next(segment) == nil and local_record then segment[local_record.name] = local_record.amount end
    local occupied = 0
    for _, amount in pairs(segment) do occupied = occupied + (tonumber(amount) or 0) end
    local capacity = 0
    pcall(function() capacity = tonumber(box.get_capacity(index)) or 0 end)
    local connections = connection_count(box, index)
    local record_data = {
      index = index,
      input = input,
      output = output,
      contents = segment,
      local_fluid = local_record,
      occupied = occupied,
      capacity = capacity,
      free = math.max(0, capacity - occupied),
      connections = connections,
    }
    out.records[#out.records + 1] = record_data
    if input and (connections <= 0 or occupied <= 0.001) then
      out.input_ready = false
      out.blockers[#out.blockers + 1] = connections <= 0 and ("input-unconnected:" .. index) or ("input-empty:" .. index)
    end
    if output and (connections <= 0 or record_data.free <= 0.001) then
      out.output_ready = false
      out.blockers[#out.blockers + 1] = connections <= 0 and ("output-unconnected:" .. index) or ("output-full:" .. index)
    end
  end
  return out
end

local function item_ingredient_report(recipe, input_inv)
  local missing, sufficient = {}, {}
  for _, ingredient in ipairs(recipe_members(recipe, "ingredients")) do
    if ingredient.type == "item" then
      local have = item_count(input_inv, ingredient.name)
      local target = math.max(1, math.ceil(ingredient.amount * M.ingredient_cycles))
      local record_data = {
        name = ingredient.name,
        amount_per_craft = ingredient.amount,
        have = have,
        target = target,
        missing = math.max(0, target - have),
      }
      if record_data.missing > 0 then missing[#missing + 1] = record_data else sufficient[#sufficient + 1] = record_data end
    end
  end
  return missing, sufficient
end

local function launch_active(status)
  if not (defines and defines.rocket_silo_status) then return false end
  local idle = defines.rocket_silo_status.building_rocket
  return status ~= nil and status ~= idle
end

function M.inspect_silo(pair, silo, force)
  if not (valid_pair(pair) and valid(silo) and silo.type == "rocket-silo") then return nil, "invalid" end
  local key = entity_key(silo)
  local r = root()
  if not force and key and (r.machine_due[key] or 0) > now() then return r.reports[key], "cached" end
  if key then r.machine_due[key] = now() + M.machine_cache_ticks end

  local d = defines and defines.inventory or {}
  local input_inv = inventory(silo, d.crafter_input)
  local output_inv = inventory(silo, d.crafter_output)
  local module_inv = inventory(silo, d.crafter_modules)
  local crafter_trash = inventory(silo, d.crafter_trash)
  local rocket_inv = inventory(silo, d.rocket_silo_rocket)
  local silo_trash = inventory(silo, d.rocket_silo_trash)
  local attached_cargo = inventory(silo, d.rocket_silo_attached_cargo_unit)
  local recipe = recipe_of(silo)
  local missing, sufficient = item_ingredient_report(recipe, input_inv)
  local status_value, status_label = rocket_status(silo)
  local entity_status
  pcall(function() entity_status = silo.status end)
  local parts = rocket_parts(silo)
  local required = parts_required(silo)
  local automated, automation_reasons = connected_automation(silo)
  local logistics = logistics_state(silo)
  local fluids = fluid_report(silo)
  local part_progress = required > 0 and math.min(1, parts / required) or 0
  local payload_count = inventory_count and 0 or 0
  local rocket_contents = contents(rocket_inv)
  local attached_contents = contents(attached_cargo)
  local trash_contents = contents(silo_trash)
  local crafter_trash_contents = contents(crafter_trash)
  for _, entry in ipairs(rocket_contents) do payload_count = payload_count + entry.count end
  for _, entry in ipairs(attached_contents) do payload_count = payload_count + entry.count end

  local automation_owned = automated
    or logistics.use_transitional_requests
    or logistics.transitional_request_target_present
    or (logistics.logistic_network_present and logistics.logistic_cell_present)

  local state, severity
  if launch_active(status_value) then
    state, severity = "launch-sequence-active", "monitor"
  elseif not recipe then
    state, severity = "no-rocket-part-recipe", "blocked"
  elseif not fluids.input_ready then
    state, severity = "fluid-input-not-ready", "blocked"
  elseif not fluids.output_ready then
    state, severity = "fluid-output-not-ready", "blocked"
  elseif output_inv and output_inv.valid and empty_slots(output_inv) <= 0 and #contents(output_inv) > 0 then
    state, severity = "crafter-output-blocked", "blocked"
  elseif #crafter_trash_contents > 0 or #trash_contents > 0 then
    state, severity = "trash-needs-clearing", "blocked"
  elseif automation_owned then
    state, severity = "external-logistics-owned", "monitor"
  elseif required > 0 and parts >= required then
    state, severity = "rocket-ready-monitor", "monitor"
  elseif #missing > 0 then
    state, severity = "manual-input-service-eligible", "eligible"
  else
    state, severity = "building-ready", "ready"
  end

  local report = {
    version = M.version,
    tick = now(),
    read_only = true,
    silo = silo,
    silo_name = silo.name,
    silo_unit = silo.unit_number,
    station_unit = station_unit(pair),
    state = state,
    severity = severity,
    entity_status = entity_status,
    entity_status_name = entity_status_name(entity_status),
    rocket_silo_status = status_value,
    rocket_silo_status_name = status_label,
    launch_sequence_active = launch_active(status_value),
    rocket_parts = parts,
    rocket_parts_required = required,
    rocket_part_progress = part_progress,
    recipe = recipe,
    recipe_name = recipe and recipe.name or nil,
    item_ingredients_missing = missing,
    item_ingredients_sufficient = sufficient,
    fluid = fluids,
    input_inventory = input_inv,
    input_contents = contents(input_inv),
    output_inventory = output_inv,
    output_contents = contents(output_inv),
    module_inventory = module_inv,
    module_contents = contents(module_inv),
    crafter_trash_inventory = crafter_trash,
    crafter_trash_contents = crafter_trash_contents,
    rocket_inventory = rocket_inv,
    rocket_contents = rocket_contents,
    silo_trash_inventory = silo_trash,
    silo_trash_contents = trash_contents,
    attached_cargo_inventory = attached_cargo,
    attached_cargo_contents = attached_contents,
    payload_count = payload_count,
    connected_item_automation = automated,
    automation_reasons = automation_reasons,
    logistics = logistics,
    automation_owned = automation_owned,
  }

  if key then r.reports[key] = report end
  stat("silos-inspected")
  stat("state-" .. state)
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
      negative_ttl = ttl or 60 * 4,
    }))
    return entities or {}
  end
  local ok, entities = pcall(function() return surface.find_entities_filtered(filters) end)
  return ok and entities or {}
end

function M.scan_pair(pair, force)
  if root().enabled == false or not valid_pair(pair) then return 0 end
  local key = tostring(station_unit(pair) or "?")
  local r = root()
  if not force and (r.scan_due[key] or 0) > now() then return 0 end
  r.scan_due[key] = now() + M.scan_interval
  local radius = service_radius(pair)
  local p = pair.station.position
  local silos = routed_find(pair.station.surface, {
    area = { { p.x - radius, p.y - radius }, { p.x + radius, p.y + radius } },
    force = pair.station.force,
    type = "rocket-silo",
    limit = M.max_scan_entities,
  }, "rocket-silo-readiness", "rocket-silo-readiness:"
      .. tostring(pair.station.surface.index) .. ":"
      .. tostring(pair.station.force.index) .. ":" .. key, 60 * 4)

  local reports = {}
  local eligible = 0
  local blocked = 0
  local worst
  for _, silo in pairs(silos) do
    local report = M.inspect_silo(pair, silo, false)
    if report then
      reports[#reports + 1] = report
      if report.state == "manual-input-service-eligible" then eligible = eligible + 1 end
      if report.severity == "blocked" then blocked = blocked + 1 end
      if not worst or report.severity == "blocked" or (report.severity == "eligible" and worst.severity ~= "blocked") then
        worst = report
      end
    end
  end
  pair.rocket_silo_reports_0709 = reports
  pair.rocket_silo_summary_0709 = {
    version = M.version,
    tick = now(),
    inspected = #reports,
    eligible = eligible,
    blocked = blocked,
    worst_state = worst and worst.state or "none",
    worst_silo = worst and worst.silo_name or nil,
    read_only = true,
  }
  stat("pair-scans")
  stat("eligible-found", eligible)
  stat("blocked-found", blocked)
  return #reports
end

local function patch_diagnostics()
  local diagnostics = rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
    or rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diagnostics and type(diagnostics.pair_dump_lines) == "function")
    or diagnostics.rocket_silo_readiness_0709_wrapped
  then
    return false
  end
  diagnostics.rocket_silo_readiness_0709_wrapped = true
  local previous = diagnostics.pair_dump_lines
  diagnostics.pair_dump_lines = function(...)
    local lines = previous(...)
    lines = type(lines) == "table" and lines or {}
    local r = root()
    lines[#lines + 1] = "PAIR-DUMP-0468 ROCKET-SILO-READINESS-0709 enabled="
      .. safe(r.enabled)
      .. " read_only=true inventory_mutations=0 rocket_parts_mutations=0 launch_flag_mutations=0"
      .. " inspected=" .. safe(r.stats["silos-inspected"] or 0)
      .. " eligible=" .. safe(r.stats["state-manual-input-service-eligible"] or 0)
      .. " external_owned=" .. safe(r.stats["state-external-logistics-owned"] or 0)
      .. " launch_active=" .. safe(r.stats["state-launch-sequence-active"] or 0)
      .. " ready_monitor=" .. safe(r.stats["state-rocket-ready-monitor"] or 0)
    for _, pair in pairs(pair_map()) do
      if valid_pair(pair) then
        local summary = pair.rocket_silo_summary_0709 or {}
        lines[#lines + 1] = "PAIR-DUMP-0468 rocket-silo-readiness[" .. safe(station_unit(pair)) .. "]"
          .. " inspected=" .. safe(summary.inspected or 0)
          .. " eligible=" .. safe(summary.eligible or 0)
          .. " blocked=" .. safe(summary.blocked or 0)
          .. " worst=" .. safe(summary.worst_state or "none")
          .. " silo=" .. safe(summary.worst_silo or "none")
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
      name = "rocket_silo_readiness_0709",
      category = "machine-logistics",
      interval = 193,
      priority = 76,
      budget = 6,
      note = "read-only rocket silo crafting launch payload and logistics ownership audit",
      fn = function(_, budget)
        local count = 0
        for _, pair in pairs(pair_map()) do
          if valid_pair(pair) then
            M.scan_pair(pair, false)
            count = count + 1
            if count >= (tonumber(budget) or 6) then break end
          end
        end
        return count > 0, "pairs=" .. safe(count)
      end,
    })
  end
end

function M.install()
  root()
  register_service()
  patch_diagnostics()
  _G.TechPriestsRocketSiloReadiness0709 = M
  _G.tech_priests_rocket_silo_inspect_0709 = M.inspect_silo
  if log then log("[Tech-Priests 0.1.674-dev] read-only rocket-silo readiness doctrine armed") end
  return true
end

return M
