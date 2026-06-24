-- Tech Priests 0.1.674-dev roboport readiness doctrine.
--
-- Read-only inspection of fixed roboports: robot inventory, repair-material
-- inventory, electric buffer and network, logistic cell/network membership,
-- charging pressure, stationed/network robot counts, and connected item
-- automation. Only repair-pack replenishment may later become eligible. Robot
-- insertion/removal remains monitor-only because it changes network capacity.

local M = {
  version = "0.1.674-dev",
  storage_key = "roboport_readiness_0714",
  scan_interval = 60 * 5,
  entity_cache_ticks = 60 * 3,
  service_radius_floor = 28,
  service_radius_cap = 96,
  max_scan_entities = 96,
  target_repair_packs = 10,
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
  return entity.unit_number and ("unit:" .. tostring(entity.unit_number))
    or (tostring(entity.surface and entity.surface.index or "?") .. ":roboport:"
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

local function total_count(inv)
  local total = 0
  for _, entry in ipairs(contents(inv)) do total = total + entry.count end
  return total
end

local function item_type(name)
  local prototype = prototypes and prototypes.item and prototypes.item[name]
  if not prototype then return nil end
  local typ
  pcall(function() typ = prototype.type end)
  return typ
end

local function place_result_type(name)
  local prototype = prototypes and prototypes.item and prototypes.item[name]
  if not prototype then return nil end
  local result, typ
  pcall(function() result = prototype.place_result end)
  if result then pcall(function() typ = result.type end) end
  return typ
end

local function repair_tool_names(inv)
  local names = {}
  for name in pairs(prototypes and prototypes.item or {}) do
    if item_type(name) == "repair-tool" then
      local ok, yes = pcall(function() return inv.can_insert({ name = name, count = 1 }) end)
      if ok and yes then names[#names + 1] = name end
    end
  end
  table.sort(names)
  return names
end

local function robot_breakdown(inv)
  local result = {
    logistic = 0,
    construction = 0,
    other = 0,
    entries = contents(inv),
  }
  for _, entry in ipairs(result.entries) do
    local typ = place_result_type(entry.name)
    if typ == "logistic-robot" then
      result.logistic = result.logistic + entry.count
    elseif typ == "construction-robot" then
      result.construction = result.construction + entry.count
    else
      result.other = result.other + entry.count
    end
  end
  return result
end

local function repair_breakdown(inv)
  local result = { repair_packs = 0, other = 0, entries = contents(inv) }
  for _, entry in ipairs(result.entries) do
    if item_type(entry.name) == "repair-tool" then
      result.repair_packs = result.repair_packs + entry.count
    else
      result.other = result.other + entry.count
    end
  end
  return result
end

local function connected_automation(entity)
  if not valid(entity) then return false, {} end
  local reasons = {}
  local box
  pcall(function() box = entity.bounding_box end)
  local p = entity.position
  local area = box and {
    { box.left_top.x - 3, box.left_top.y - 3 },
    { box.right_bottom.x + 3, box.right_bottom.y + 3 },
  } or {
    { p.x - 3, p.y - 3 },
    { p.x + 3, p.y + 3 },
  }
  local nearby = {}
  pcall(function()
    nearby = entity.surface.find_entities_filtered({
      area = area,
      force = entity.force,
      type = { "inserter", "loader", "loader-1x1" },
      limit = 64,
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

local function cell_report(entity)
  local cell
  pcall(function() cell = entity.logistic_cell end)
  if not cell then return { present = false } end
  local network, charging, stationed_logistic, stationed_construction
  pcall(function() network = cell.logistic_network end)
  pcall(function() charging = cell.charging_robots or {} end)
  pcall(function() stationed_logistic = tonumber(cell.stationed_logistic_robot_count) or 0 end)
  pcall(function() stationed_construction = tonumber(cell.stationed_construction_robot_count) or 0 end)
  local charging_count = 0
  if type(charging) == "table" then
    for _, robot in pairs(charging) do if valid(robot) then charging_count = charging_count + 1 end end
  else
    pcall(function() charging_count = tonumber(cell.charging_robot_count) or 0 end)
  end
  return {
    present = true,
    cell = cell,
    logistic_network = network,
    network_present = network ~= nil,
    logistic_radius = cell.logistic_radius,
    construction_radius = cell.construction_radius,
    stationed_logistic = stationed_logistic or 0,
    stationed_construction = stationed_construction or 0,
    charging_count = charging_count,
  }
end

local function network_report(cell_data)
  local network = cell_data and cell_data.logistic_network
  if not network then return { present = false } end
  local network_id, available_logistic, all_logistic, available_construction, all_construction, cells
  pcall(function() network_id = network.network_id end)
  pcall(function() available_logistic = tonumber(network.available_logistic_robots) or 0 end)
  pcall(function() all_logistic = tonumber(network.all_logistic_robots) or 0 end)
  pcall(function() available_construction = tonumber(network.available_construction_robots) or 0 end)
  pcall(function() all_construction = tonumber(network.all_construction_robots) or 0 end)
  pcall(function() cells = network.cells or {} end)
  local cell_count = 0
  for _, cell in pairs(cells or {}) do if cell and cell.valid then cell_count = cell_count + 1 end end
  return {
    present = true,
    network = network,
    network_id = network_id,
    available_logistic = available_logistic or 0,
    all_logistic = all_logistic or 0,
    available_construction = available_construction or 0,
    all_construction = all_construction or 0,
    active_logistic = math.max(0, (all_logistic or 0) - (available_logistic or 0)),
    active_construction = math.max(0, (all_construction or 0) - (available_construction or 0)),
    cell_count = cell_count,
  }
end

local function energy_report(entity)
  local connected = false
  if entity.is_connected_to_electric_network then
    pcall(function() connected = entity.is_connected_to_electric_network() end)
  end
  local network_id, energy, buffer, status
  pcall(function() network_id = entity.electric_network_id end)
  pcall(function() energy = tonumber(entity.energy) or 0 end)
  pcall(function() buffer = tonumber(entity.electric_buffer_size) or 0 end)
  pcall(function() status = entity.status end)
  local recharge_minimum = 0
  pcall(function() recharge_minimum = tonumber(entity.prototype.recharge_minimum) or 0 end)
  return {
    connected = connected == true or network_id ~= nil,
    network_id = network_id,
    energy = energy or 0,
    buffer = buffer or 0,
    ratio = buffer and buffer > 0 and math.max(0, math.min(1, energy / buffer)) or 0,
    recharge_minimum = recharge_minimum or 0,
    status = status,
  }
end

function M.inspect_entity(pair, entity, force)
  if not (valid_pair(pair) and valid(entity) and entity.type == "roboport") then
    return nil, "invalid"
  end
  local key = entity_key(entity)
  local r = root()
  if not force and key and (r.entity_due[key] or 0) > now() then return r.reports[key], "cached" end
  if key then r.entity_due[key] = now() + M.entity_cache_ticks end

  local d = defines and defines.inventory or {}
  local robot_inv = inventory(entity, d.roboport_robot)
  local material_inv = inventory(entity, d.roboport_material)
  local robots = robot_breakdown(robot_inv)
  local materials = repair_breakdown(material_inv)
  local accepted_repairs = material_inv and repair_tool_names(material_inv) or {}
  local automated, automation_reasons = connected_automation(entity)
  local cell = cell_report(entity)
  local network = network_report(cell)
  local energy = energy_report(entity)
  local repair_target = math.max(1, math.min(M.target_repair_packs,
    tonumber(entity.prototype.material_slots_count) and entity.prototype.material_slots_count * 100 or M.target_repair_packs))

  local state, severity
  if not (robot_inv and material_inv) then
    state, severity = "inventory-unavailable", "blocked"
  elseif not cell.present or not network.present then
    state, severity = "logistic-network-missing", "blocked"
  elseif not energy.connected then
    state, severity = "electric-network-missing", "blocked"
  elseif energy.energy < math.max(1, energy.recharge_minimum * 0.25) then
    state, severity = "energy-buffer-low", "blocked"
  elseif automated then
    state, severity = "external-item-automation-owned", "monitor"
  elseif network.all_construction <= 0 then
    state, severity = "no-construction-robots-monitor", "monitor"
  elseif #accepted_repairs <= 0 then
    state, severity = "no-compatible-repair-pack", "blocked"
  elseif materials.repair_packs >= repair_target then
    state, severity = "repair-packs-sufficient", "ready"
  else
    state, severity = "manual-repair-pack-service-eligible", "eligible"
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
    robot_inventory = robot_inv,
    robots = robots,
    material_inventory = material_inv,
    materials = materials,
    compatible_repair_packs = accepted_repairs,
    repair_pack_target = repair_target,
    repair_pack_missing = math.max(0, repair_target - materials.repair_packs),
    connected_item_automation = automated,
    automation_reasons = automation_reasons,
    cell = cell,
    network = network,
    energy = energy,
    robot_population_monitor_only = true,
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
    type = "roboport",
    limit = M.max_scan_entities,
  }, "roboport-readiness", "roboport-readiness:"
      .. tostring(pair.station.surface.index) .. ":"
      .. tostring(pair.station.force.index) .. ":" .. key, 60 * 4)

  local reports = {}
  local eligible, blocked = 0, 0
  for _, entity in pairs(entities) do
    local report = M.inspect_entity(pair, entity, false)
    if report then
      reports[#reports + 1] = report
      if report.state == "manual-repair-pack-service-eligible" then eligible = eligible + 1 end
      if report.severity == "blocked" then blocked = blocked + 1 end
    end
  end
  pair.roboport_reports_0714 = reports
  pair.roboport_summary_0714 = {
    version = M.version,
    tick = now(),
    inspected = #reports,
    eligible = eligible,
    blocked = blocked,
    read_only = true,
  }
  stat("pair-scans")
  stat("eligible-found", eligible)
  return #reports
end

local function patch_diagnostics()
  local diagnostics = rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
    or rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diagnostics and type(diagnostics.pair_dump_lines) == "function")
    or diagnostics.roboport_readiness_0714_wrapped
  then
    return false
  end
  diagnostics.roboport_readiness_0714_wrapped = true
  local previous = diagnostics.pair_dump_lines
  diagnostics.pair_dump_lines = function(...)
    local lines = previous(...)
    lines = type(lines) == "table" and lines or {}
    local r = root()
    lines[#lines + 1] = "PAIR-DUMP-0468 ROBOPORT-READINESS-0714 enabled="
      .. safe(r.enabled)
      .. " read_only=true repair_pack_mutations=0 robot_population_mutations=0"
      .. " inspected=" .. safe(r.stats["entities-inspected"] or 0)
      .. " eligible=" .. safe(r.stats["state-manual-repair-pack-service-eligible"] or 0)
      .. " sufficient=" .. safe(r.stats["state-repair-packs-sufficient"] or 0)
      .. " no_robots=" .. safe(r.stats["state-no-construction-robots-monitor"] or 0)
      .. " no_network=" .. safe(r.stats["state-logistic-network-missing"] or 0)
      .. " low_energy=" .. safe(r.stats["state-energy-buffer-low"] or 0)
      .. " external_owned=" .. safe(r.stats["state-external-item-automation-owned"] or 0)
    for _, pair in pairs(pair_map()) do
      if valid_pair(pair) then
        local summary = pair.roboport_summary_0714 or {}
        lines[#lines + 1] = "PAIR-DUMP-0468 roboport-readiness[" .. safe(station_unit(pair)) .. "]"
          .. " inspected=" .. safe(summary.inspected or 0)
          .. " eligible=" .. safe(summary.eligible or 0)
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
      name = "roboport_readiness_0714",
      category = "machine-logistics",
      interval = 223,
      priority = 78,
      budget = 6,
      note = "read-only roboport energy network robot and repair material readiness",
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
  _G.TechPriestsRoboportReadiness0714 = M
  _G.tech_priests_roboport_inspect_0714 = M.inspect_entity
  if log then log("[Tech-Priests 0.1.674-dev] read-only roboport network and repair-pack readiness armed") end
  return true
end

return M
