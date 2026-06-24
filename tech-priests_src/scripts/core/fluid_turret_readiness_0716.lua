-- Tech Priests 0.1.674-dev fluid-turret readiness doctrine.
--
-- Fluid turrets use real pipeline supply plus a separate internal fluid-ammunition
-- buffer. This module reads accepted attack fluids, runtime fluid storages,
-- connected segment supply, internal buffer fill, activation threshold, status,
-- and shooting state. It never inserts, removes, clears, or carries fluid and
-- never changes targeting, priorities, firing, filters, or pipe connections.

local M = {
  version = "0.1.674-dev",
  storage_key = "fluid_turret_readiness_0716",
  scan_interval = 60 * 5,
  entity_cache_ticks = 60 * 3,
  service_radius_floor = 28,
  service_radius_cap = 96,
  max_scan_entities = 96,
  minimum_segment_supply = 0.001,
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

local function entity_key(entity)
  if not valid(entity) then return nil end
  return entity.unit_number and ("unit:" .. tostring(entity.unit_number))
    or (tostring(entity.surface and entity.surface.index or "?") .. ":fluid-turret:"
      .. tostring(math.floor(entity.position.x * 10)) .. ":"
      .. tostring(math.floor(entity.position.y * 10)))
end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    read_only = true,
    stats = {},
    scan_due = {},
    entity_due = {},
    reports = {},
  }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.read_only == nil then r.read_only = true end
  r.stats = r.stats or {}
  r.scan_due = r.scan_due or {}
  r.entity_due = r.entity_due or {}
  r.reports = r.reports or {}
  return r
end

local function stat(name, amount)
  local r = root()
  r.stats[name] = (r.stats[name] or 0) + (amount or 1)
end

local function accepted_fluids(entity)
  local out, seen = {}, {}
  local attack
  pcall(function() attack = entity.prototype.attack_parameters end)
  local fluids = attack and attack.fluids or nil
  for _, record_data in pairs(fluids or {}) do
    local name, damage
    pcall(function()
      name = record_data.type or record_data.name or record_data.fluid
      damage = tonumber(record_data.damage_modifier) or 1
    end)
    if type(name) == "string" and name ~= "" and not seen[name] then
      seen[name] = true
      out[#out + 1] = { name = name, damage_modifier = damage or 1 }
    end
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out, seen
end

local function entity_fluid_contents(entity)
  local result = {}
  if valid(entity) and entity.get_fluid_contents then
    pcall(function() result = entity.get_fluid_contents() or {} end)
  end
  return type(result) == "table" and result or {}
end

local function fluid_storages(entity)
  local out = {}
  local count = 0
  pcall(function() count = tonumber(entity.fluids_count) or 0 end)
  for index = 1, count do
    local fluid
    pcall(function() fluid = entity.get_fluid(index) end)
    if type(fluid) == "table" and fluid.name then
      out[#out + 1] = {
        index = index,
        name = fluid.name,
        amount = tonumber(fluid.amount) or 0,
        temperature = tonumber(fluid.temperature),
      }
    else
      out[#out + 1] = { index = index, amount = 0 }
    end
  end
  return out
end

local function fluidbox(entity)
  if not valid(entity) then return nil end
  local ok, box = pcall(function() return entity.fluidbox end)
  return ok and box and box.valid and box or nil
end

local function segment_contents(box, index)
  local contents = {}
  if box and box.valid then pcall(function() contents = box.get_fluid_segment_contents(index) or {} end) end
  return type(contents) == "table" and contents or {}
end

local function connection_records(box, index)
  local out = {}
  if not (box and box.valid) then return out end
  local connections = {}
  pcall(function() connections = box.get_pipe_connections(index) or {} end)
  for _, connection in pairs(connections or {}) do
    if type(connection) == "table" then
      local owner
      if connection.target then pcall(function() owner = connection.target.owner end) end
      local position = connection.target_position or connection.position
      out[#out + 1] = {
        connected = connection.target ~= nil or valid(owner),
        position = position and { x = position.x, y = position.y } or nil,
        target_owner = owner,
      }
    end
  end
  return out
end

local function pipeline_report(entity, accepted)
  local box = fluidbox(entity)
  local result = {
    present = box ~= nil,
    connected = false,
    accepted_amount = 0,
    wrong_fluids = {},
    records = {},
    free_targets = {},
  }
  if not box then return result end
  for index = 1, #box do
    local segment = segment_contents(box, index)
    local connections = connection_records(box, index)
    local connected = false
    for _, connection in ipairs(connections) do
      if connection.connected then connected = true else
        if connection.position then result.free_targets[#result.free_targets + 1] = connection.position end
      end
    end
    if connected then result.connected = true end
    local accepted_amount = 0
    local wrong = {}
    for name, amount in pairs(segment) do
      amount = tonumber(amount) or 0
      if accepted[name] then
        accepted_amount = accepted_amount + amount
        result.accepted_amount = result.accepted_amount + amount
      elseif amount > 0.001 then
        wrong[#wrong + 1] = { name = name, amount = amount }
        result.wrong_fluids[#result.wrong_fluids + 1] = { name = name, amount = amount, index = index }
      end
    end
    result.records[#result.records + 1] = {
      index = index,
      connected = connected,
      connections = connections,
      segment_contents = segment,
      accepted_amount = accepted_amount,
      wrong_fluids = wrong,
    }
  end
  return result
end

local function buffer_report(entity, accepted)
  local contents = entity_fluid_contents(entity)
  local storages = fluid_storages(entity)
  local accepted_amount = 0
  local wrong = {}
  for name, amount in pairs(contents) do
    amount = tonumber(amount) or 0
    if accepted[name] then
      accepted_amount = accepted_amount + amount
    elseif amount > 0.001 then
      wrong[#wrong + 1] = { name = name, amount = amount }
    end
  end
  local size, ratio
  pcall(function() size = tonumber(entity.prototype.fluid_buffer_size) or 0 end)
  pcall(function() ratio = tonumber(entity.prototype.activation_buffer_ratio) or 0 end)
  local threshold = math.max(0, (size or 0) * (ratio or 0))
  return {
    contents = contents,
    storages = storages,
    accepted_amount = accepted_amount,
    wrong_fluids = wrong,
    capacity = size or 0,
    activation_ratio = ratio or 0,
    activation_threshold = threshold,
    above_activation_threshold = accepted_amount + 0.001 >= threshold,
  }
end

local function runtime_report(entity)
  local status, target, orientation, damage, kills
  pcall(function() status = entity.status end)
  pcall(function() target = entity.shooting_target end)
  pcall(function() orientation = entity.turret_orientation end)
  pcall(function() damage = tonumber(entity.damage_dealt) or 0 end)
  pcall(function() kills = tonumber(entity.kills) or 0 end)
  return {
    status = status,
    shooting_target = target,
    shooting = valid(target),
    turret_orientation = orientation,
    damage_dealt = damage or 0,
    kills = kills or 0,
  }
end

function M.inspect_entity(pair, entity, force)
  if not (valid_pair(pair) and valid(entity) and entity.type == "fluid-turret") then
    return nil, "invalid"
  end
  local key = entity_key(entity)
  local r = root()
  if not force and key and (r.entity_due[key] or 0) > now() then return r.reports[key], "cached" end
  if key then r.entity_due[key] = now() + M.entity_cache_ticks end

  local accepted_list, accepted = accepted_fluids(entity)
  local pipeline = pipeline_report(entity, accepted)
  local buffer = buffer_report(entity, accepted)
  local runtime = runtime_report(entity)
  local state, severity
  if #accepted_list == 0 then
    state, severity = "accepted-fluid-unknown", "blocked"
  elseif #pipeline.wrong_fluids > 0 or #buffer.wrong_fluids > 0 then
    state, severity = "wrong-fluid-contamination", "blocked"
  elseif not pipeline.present then
    state, severity = "input-fluidbox-unavailable", "blocked"
  elseif not pipeline.connected then
    state, severity = "input-pipeline-unconnected", "blocked"
  elseif pipeline.accepted_amount < M.minimum_segment_supply and buffer.accepted_amount <= 0.001 then
    state, severity = "connected-pipeline-empty", "waiting"
  elseif not buffer.above_activation_threshold then
    state, severity = "internal-buffer-filling", "waiting"
  else
    state, severity = "fluid-ammunition-ready", "ready"
  end

  local report = {
    version = M.version,
    tick = now(),
    read_only = true,
    entity = entity,
    entity_name = entity.name,
    entity_unit = entity.unit_number,
    station_unit = station_unit(pair),
    state = state,
    severity = severity,
    accepted_fluids = accepted_list,
    accepted_lookup = accepted,
    pipeline = pipeline,
    buffer = buffer,
    runtime = runtime,
    connection_required = state == "input-pipeline-unconnected",
  }
  if key then r.reports[key] = report end
  stat("entities-inspected")
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
    or package.loaded["scripts.core.scan_routing_0610"]
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
  local entities = routed_find(pair.station.surface, {
    area = { { p.x - radius, p.y - radius }, { p.x + radius, p.y + radius } },
    force = pair.station.force,
    type = "fluid-turret",
    limit = M.max_scan_entities,
  }, "fluid-turret-readiness", "fluid-turret-readiness:"
      .. tostring(pair.station.surface.index) .. ":"
      .. tostring(pair.station.force.index) .. ":" .. key, 60 * 4)

  local reports = {}
  local ready, connection_required, blocked = 0, 0, 0
  for _, entity in pairs(entities) do
    local report = M.inspect_entity(pair, entity, false)
    if report then
      reports[#reports + 1] = report
      if report.state == "fluid-ammunition-ready" then ready = ready + 1 end
      if report.connection_required then connection_required = connection_required + 1 end
      if report.severity == "blocked" then blocked = blocked + 1 end
    end
  end
  pair.fluid_turret_reports_0716 = reports
  pair.fluid_turret_summary_0716 = {
    version = M.version,
    tick = now(),
    inspected = #reports,
    ready = ready,
    connection_required = connection_required,
    blocked = blocked,
    read_only = true,
  }
  stat("pair-scans")
  stat("connection-required-found", connection_required)
  return #reports
end

local function patch_diagnostics()
  local diagnostics = rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
    or rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diagnostics and type(diagnostics.pair_dump_lines) == "function")
    or diagnostics.fluid_turret_readiness_0716_wrapped
  then
    return false
  end
  diagnostics.fluid_turret_readiness_0716_wrapped = true
  local previous = diagnostics.pair_dump_lines
  diagnostics.pair_dump_lines = function(...)
    local lines = previous(...)
    lines = type(lines) == "table" and lines or {}
    local r = root()
    lines[#lines + 1] = "PAIR-DUMP-0468 FLUID-TURRET-READINESS-0716 enabled="
      .. safe(r.enabled)
      .. " read_only=true fluid_mutations=0 targeting_mutations=0 firing_mutations=0"
      .. " inspected=" .. safe(r.stats["entities-inspected"] or 0)
      .. " ready=" .. safe(r.stats["state-fluid-ammunition-ready"] or 0)
      .. " unconnected=" .. safe(r.stats["state-input-pipeline-unconnected"] or 0)
      .. " empty=" .. safe(r.stats["state-connected-pipeline-empty"] or 0)
      .. " filling=" .. safe(r.stats["state-internal-buffer-filling"] or 0)
      .. " contaminated=" .. safe(r.stats["state-wrong-fluid-contamination"] or 0)
    for _, pair in pairs(pair_map()) do
      if valid_pair(pair) then
        local summary = pair.fluid_turret_summary_0716 or {}
        lines[#lines + 1] = "PAIR-DUMP-0468 fluid-turret-readiness[" .. safe(station_unit(pair)) .. "]"
          .. " inspected=" .. safe(summary.inspected or 0)
          .. " ready=" .. safe(summary.ready or 0)
          .. " connection_required=" .. safe(summary.connection_required or 0)
          .. " blocked=" .. safe(summary.blocked or 0)
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
      name = "fluid_turret_readiness_0716",
      category = "machine-logistics",
      interval = 227,
      priority = 79,
      budget = 6,
      note = "read-only fluid turret accepted fluid pipeline and internal buffer audit",
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
  _G.TechPriestsFluidTurretReadiness0716 = M
  _G.tech_priests_fluid_turret_inspect_0716 = M.inspect_entity
  if log then log("[Tech-Priests 0.1.674-dev] read-only fluid-turret pipeline and internal buffer readiness armed") end
  return true
end

return M
