-- Tech Priests 0.1.674-dev artillery readiness doctrine.
--
-- Fixed artillery turrets and artillery wagons have dedicated ammunition
-- inventories and are not ordinary ammo turrets. This module is read-only.
-- Fixed turrets can become manual-service candidates when no connected loader or
-- inserter owns them. Wagons can become candidates only while their train is
-- stationary and explicitly in manual mode. The doctrine never changes train
-- speed, state, schedule, manual mode, targeting, firing, or ammunition.

local M = {
  version = "0.1.674-dev",
  storage_key = "artillery_readiness_0712",
  scan_interval = 60 * 5,
  entity_cache_ticks = 60 * 3,
  service_radius_floor = 28,
  service_radius_cap = 96,
  max_scan_entities = 96,
  fallback_target_ammo = 5,
}

local ARTILLERY_TYPES = { "artillery-turret", "artillery-wagon" }

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
    or (tostring(entity.surface and entity.surface.index or "?") .. ":"
      .. tostring(entity.name) .. ":"
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

local function inventory(entity)
  if not (valid(entity) and defines and defines.inventory) then return nil end
  local id = entity.type == "artillery-wagon"
    and defines.inventory.artillery_wagon_ammo
    or defines.inventory.artillery_turret_ammo
  if not id then return nil end
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

local function is_ammo(name)
  local prototype = prototypes and prototypes.item and prototypes.item[name]
  if not prototype then return false end
  local typ
  pcall(function() typ = prototype.type end)
  if typ == "ammo" then return true end
  local category
  pcall(function() category = prototype.ammo_category end)
  return category ~= nil
end

local function can_insert(inv, name)
  if not (inv and inv.valid and name) then return false end
  local ok, yes = pcall(function() return inv.can_insert({ name = name, count = 1 }) end)
  return ok and yes == true
end

local function compatible_ammo(inv)
  local out = {}
  for name in pairs(prototypes and prototypes.item or {}) do
    if is_ammo(name) and can_insert(inv, name) then out[#out + 1] = name end
  end
  table.sort(out)
  return out
end

local function target_count(entity)
  local automated, stack_limit
  pcall(function() automated = tonumber(entity.prototype.automated_ammo_count) end)
  pcall(function() stack_limit = tonumber(entity.prototype.ammo_stack_limit) end)
  local target = automated or M.fallback_target_ammo
  if stack_limit and stack_limit > 0 then target = math.min(target, stack_limit) end
  return math.max(1, math.floor(target or M.fallback_target_ammo))
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

local function train_state_name(state)
  if not (defines and defines.train_state) then return safe(state) end
  for name, value in pairs(defines.train_state) do if value == state then return name end end
  return safe(state)
end

local function train_report(entity)
  if entity.type ~= "artillery-wagon" then return nil end
  local train
  pcall(function() train = entity.train end)
  if not (train and train.valid) then
    return {
      train = nil,
      valid = false,
      stationary = true,
      manual_mode = true,
      safe_for_manual_service = true,
      state_name = "detached-wagon",
      speed = 0,
    }
  end
  local speed, state, manual, station, schedule
  pcall(function() speed = tonumber(train.speed) or 0 end)
  pcall(function() state = train.state end)
  pcall(function() manual = train.manual_mode == true end)
  pcall(function() station = train.station end)
  pcall(function() schedule = train.schedule end)
  local stationary = math.abs(speed or 0) < 0.001
  return {
    train = train,
    valid = true,
    speed = speed or 0,
    stationary = stationary,
    manual_mode = manual == true,
    state = state,
    state_name = train_state_name(state),
    station = station,
    station_name = valid(station) and station.backer_name or nil,
    has_schedule = schedule ~= nil,
    safe_for_manual_service = stationary and manual == true,
  }
end

local function runtime_status(entity)
  local status, target, orientation, damage
  pcall(function() status = entity.status end)
  pcall(function() target = entity.shooting_target end)
  pcall(function() orientation = entity.turret_orientation end)
  pcall(function() damage = tonumber(entity.damage_dealt) or 0 end)
  return {
    status = status,
    shooting_target = target,
    shooting = valid(target),
    turret_orientation = orientation,
    damage_dealt = damage or 0,
  }
end

function M.inspect_entity(pair, entity, force)
  if not (valid_pair(pair) and valid(entity)
    and (entity.type == "artillery-turret" or entity.type == "artillery-wagon"))
  then
    return nil, "invalid"
  end
  local key = entity_key(entity)
  local r = root()
  if not force and key and (r.entity_due[key] or 0) > now() then return r.reports[key], "cached" end
  if key then r.entity_due[key] = now() + M.entity_cache_ticks end

  local inv = inventory(entity)
  local ammo = contents(inv)
  local count = total_count(inv)
  local accepted = compatible_ammo(inv)
  local target = target_count(entity)
  local automated, automation_reasons = connected_automation(entity)
  local train = train_report(entity)
  local runtime = runtime_status(entity)

  local state, severity
  if not inv then
    state, severity = "ammo-inventory-unavailable", "blocked"
  elseif #accepted == 0 then
    state, severity = "no-compatible-artillery-ammo", "blocked"
  elseif entity.type == "artillery-wagon" and train and not train.stationary then
    state, severity = "moving-train-monitor", "monitor"
  elseif entity.type == "artillery-wagon" and train and not train.manual_mode then
    state, severity = "automatic-train-owned", "monitor"
  elseif automated then
    state, severity = "external-item-automation-owned", "monitor"
  elseif count >= target then
    state, severity = "ammo-sufficient", "ready"
  else
    state, severity = "manual-ammo-service-eligible", "eligible"
  end

  local report = {
    version = M.version,
    tick = now(),
    read_only = true,
    entity = entity,
    entity_name = entity.name,
    entity_unit = entity.unit_number,
    entity_type = entity.type,
    station_unit = station_unit(pair),
    state = state,
    severity = severity,
    ammo_inventory = inv,
    ammo_contents = ammo,
    ammo_count = count,
    target_ammo_count = target,
    missing_ammo_count = math.max(0, target - count),
    compatible_ammo = accepted,
    connected_item_automation = automated,
    automation_reasons = automation_reasons,
    train = train,
    runtime = runtime,
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
    type = ARTILLERY_TYPES,
    limit = M.max_scan_entities,
  }, "artillery-readiness", "artillery-readiness:"
      .. tostring(pair.station.surface.index) .. ":"
      .. tostring(pair.station.force.index) .. ":" .. key, 60 * 4)

  local reports = {}
  local eligible, moving, automatic = 0, 0, 0
  for _, entity in pairs(entities) do
    local report = M.inspect_entity(pair, entity, false)
    if report then
      reports[#reports + 1] = report
      if report.state == "manual-ammo-service-eligible" then eligible = eligible + 1 end
      if report.state == "moving-train-monitor" then moving = moving + 1 end
      if report.state == "automatic-train-owned" then automatic = automatic + 1 end
    end
  end
  pair.artillery_reports_0712 = reports
  pair.artillery_summary_0712 = {
    version = M.version,
    tick = now(),
    inspected = #reports,
    eligible = eligible,
    moving_wagons = moving,
    automatic_wagons = automatic,
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
    or diagnostics.artillery_readiness_0712_wrapped
  then
    return false
  end
  diagnostics.artillery_readiness_0712_wrapped = true
  local previous = diagnostics.pair_dump_lines
  diagnostics.pair_dump_lines = function(...)
    local lines = previous(...)
    lines = type(lines) == "table" and lines or {}
    local r = root()
    lines[#lines + 1] = "PAIR-DUMP-0468 ARTILLERY-READINESS-0712 enabled="
      .. safe(r.enabled)
      .. " read_only=true ammo_mutations=0 train_mutations=0"
      .. " inspected=" .. safe(r.stats["entities-inspected"] or 0)
      .. " eligible=" .. safe(r.stats["state-manual-ammo-service-eligible"] or 0)
      .. " sufficient=" .. safe(r.stats["state-ammo-sufficient"] or 0)
      .. " moving=" .. safe(r.stats["state-moving-train-monitor"] or 0)
      .. " automatic=" .. safe(r.stats["state-automatic-train-owned"] or 0)
      .. " external_owned=" .. safe(r.stats["state-external-item-automation-owned"] or 0)
    for _, pair in pairs(pair_map()) do
      if valid_pair(pair) then
        local summary = pair.artillery_summary_0712 or {}
        lines[#lines + 1] = "PAIR-DUMP-0468 artillery-readiness[" .. safe(station_unit(pair)) .. "]"
          .. " inspected=" .. safe(summary.inspected or 0)
          .. " eligible=" .. safe(summary.eligible or 0)
          .. " moving_wagons=" .. safe(summary.moving_wagons or 0)
          .. " automatic_wagons=" .. safe(summary.automatic_wagons or 0)
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
      name = "artillery_readiness_0712",
      category = "machine-logistics",
      interval = 211,
      priority = 77,
      budget = 6,
      note = "read-only fixed artillery and manual stationary wagon readiness",
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
  _G.TechPriestsArtilleryReadiness0712 = M
  _G.tech_priests_artillery_inspect_0712 = M.inspect_entity
  if log then log("[Tech-Priests 0.1.674-dev] read-only artillery turret and wagon readiness armed") end
  return true
end

return M
