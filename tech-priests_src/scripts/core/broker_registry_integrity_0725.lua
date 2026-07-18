-- Tech Priests 0.1.674-dev broker and registry integrity audit.
-- Confirms one installed central broker route and one well-formed registration for
-- every critical development service. This module is read-only after installation.

local M = {
  version = "0.1.674-dev",
  storage_key = "broker_registry_integrity_0725",
  interval = 313,
  central_route_id = "runtime_tick_broker_0600:central-pulse",
}

local CRITICAL_SERVICES = {
  "energy_family_readiness_0705",
  "energy_family_logistics_0707",
  "rocket_silo_readiness_0709",
  "rocket_silo_logistics_0710",
  "artillery_readiness_0712",
  "artillery_logistics_0713",
  "roboport_readiness_0714",
  "roboport_repair_pack_logistics_0715",
  "fluid_turret_readiness_0716",
  "fluid_turret_connection_proposals_0717",
  "fluid_turret_proposal_integrity_0718",
  "runtime_command_cleanup_0720",
  "development_integration_audit_0721",
  "hardener_installation_audit_0723",
  "broker_registry_integrity_0725",
  "fluid_turret_planner_integrity_0730",
  "development_lifecycle_checkpoint_0733",
}

local function now() return game and game.tick or 0 end
local function safe(value)
  if value == nil then return "nil" end
  local ok, text = pcall(tostring, value)
  return ok and text or "?"
end
local function root()
  storage.tech_priests = storage.tech_priests or {}
  local state = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    stats = {},
    last = {},
    recent = {},
  }
  storage.tech_priests[M.storage_key] = state
  state.version = M.version
  if state.enabled == nil then state.enabled = true end
  state.stats = state.stats or {}
  state.last = state.last or {}
  state.recent = state.recent or {}
  return state
end
local function stat(name, amount)
  local state = root()
  state.stats[name] = (state.stats[name] or 0) + (amount or 1)
end

local function broker_module()
  return rawget(_G, "TechPriestsRuntimeTickBroker0600")
    or package.loaded["scripts.core.runtime_tick_broker"]
end
local function registry_module()
  return rawget(_G, "TechPriestsRuntimeEventRegistry")
    or package.loaded["scripts.core.runtime_event_registry"]
end
local function installation_snapshot(broker)
  if broker and type(broker.installation_summary) == "function" then
    local ok, snapshot = pcall(broker.installation_summary)
    if ok and type(snapshot) == "table" then return snapshot end
  end
  return {
    complete = false,
    installed = broker and broker.installed == true or false,
    registry_available = false,
    route_registered = false,
    route_id = nil,
    reason = "installation-summary-unavailable",
  }
end
local function central_routes(registry, interval)
  local route_map
  if registry and type(registry.get_nth_tick_routes) == "function" then
    local ok, value = pcall(registry.get_nth_tick_routes)
    if ok then route_map = value end
  end
  route_map = route_map or (registry and registry.nth_tick_routes) or {}
  local routes = route_map[tostring(interval)] or route_map[interval] or {}
  local count, malformed = 0, {}
  for index, entry in ipairs(routes) do
    if type(entry) == "table" and entry.id == M.central_route_id then
      count = count + 1
      if entry.owner ~= "runtime_tick_broker_0600"
        or entry.route ~= "central-pulse"
        or type(entry.handler) ~= "function"
      then
        malformed[#malformed + 1] = {
          index = index,
          owner = safe(entry.owner),
          route = safe(entry.route),
          has_function = type(entry.handler) == "function",
        }
      end
    end
  end
  return count, malformed
end

local function inspect_services()
  local broker = broker_module()
  local registry = registry_module()
  local installation = installation_snapshot(broker)
  local interval = broker and tonumber(broker.base_interval) or 5
  local route_count, route_malformed = central_routes(registry, interval)

  local counts, malformed, total = {}, {}, 0
  for index, service in ipairs(broker and broker.services or {}) do
    if type(service) == "table" and service.name then
      local name = tostring(service.name)
      counts[name] = (counts[name] or 0) + 1
      total = total + 1
      if type(service.fn) ~= "function"
        or (tonumber(service.interval) or 0) < 1
        or (tonumber(service.budget) or 0) < 1
      then
        malformed[#malformed + 1] = {
          index = index,
          name = name,
          has_function = type(service.fn) == "function",
          interval = tonumber(service.interval),
          budget = tonumber(service.budget),
        }
      end
    else
      malformed[#malformed + 1] = {
        index = index,
        name = "unnamed",
        has_function =
          type(service) == "table" and type(service.fn) == "function" or false,
      }
    end
  end

  local missing, duplicates = {}, {}
  for _, name in ipairs(CRITICAL_SERVICES) do
    if (counts[name] or 0) == 0 then missing[#missing + 1] = name end
  end
  for name, count in pairs(counts) do
    if count > 1 then duplicates[#duplicates + 1] = { name = name, count = count } end
  end
  table.sort(missing)
  table.sort(duplicates, function(a, b) return a.name < b.name end)
  table.sort(malformed, function(a, b)
    if a.name == b.name then return (a.index or 0) < (b.index or 0) end
    return a.name < b.name
  end)

  local route_complete =
    registry ~= nil
    and route_count == 1
    and #route_malformed == 0
    and installation.complete == true
    and installation.installed == true
    and installation.registry_available == true
    and installation.route_registered == true
    and installation.route_id == M.central_route_id

  return {
    tick = now(),
    broker_available = broker ~= nil,
    registry_available = registry ~= nil,
    broker_installation = installation,
    central_interval = interval,
    central_route_id = M.central_route_id,
    central_route_count = route_count,
    central_route_malformed = route_malformed,
    central_route_complete = route_complete,
    total = total,
    critical_expected = #CRITICAL_SERVICES,
    missing = missing,
    duplicates = duplicates,
    malformed = malformed,
    complete =
      broker ~= nil
      and route_complete
      and #missing == 0
      and #duplicates == 0
      and #malformed == 0,
  }
end

local function signature(snapshot)
  local parts = {}
  if not snapshot.central_route_complete then
    parts[#parts + 1] =
      "central-route:" .. safe(snapshot.central_route_count)
      .. ":" .. safe(snapshot.broker_installation and snapshot.broker_installation.reason)
  end
  for _, name in ipairs(snapshot.missing or {}) do
    parts[#parts + 1] = "missing:" .. name
  end
  for _, entry in ipairs(snapshot.duplicates or {}) do
    parts[#parts + 1] =
      "duplicate:" .. entry.name .. "x" .. tostring(entry.count)
  end
  for _, entry in ipairs(snapshot.malformed or {}) do
    parts[#parts + 1] =
      "malformed:" .. entry.name .. "@" .. tostring(entry.index)
  end
  for _, entry in ipairs(snapshot.central_route_malformed or {}) do
    parts[#parts + 1] = "malformed-central-route@" .. tostring(entry.index)
  end
  table.sort(parts)
  return table.concat(parts, "|")
end

function M.audit()
  local state = root()
  local snapshot = inspect_services()
  state.last = snapshot
  stat("audits")
  stat("services-seen", snapshot.total)
  stat("missing-observed", #snapshot.missing)
  stat("duplicates-observed", #snapshot.duplicates)
  stat("malformed-observed", #snapshot.malformed)
  if snapshot.central_route_complete then stat("central-route-complete")
  else stat("central-route-incomplete") end
  if snapshot.complete then stat("complete-observations")
  else stat("incomplete-observations") end

  local current = signature(snapshot)
  if current ~= (state.last_signature or "") then
    state.last_signature = current
    if not snapshot.central_route_complete then
      state.recent[#state.recent + 1] = {
        tick = snapshot.tick,
        code = "central-route-incomplete",
        detail =
          "count=" .. safe(snapshot.central_route_count)
          .. " reason=" .. safe(snapshot.broker_installation.reason),
      }
    end
    for _, name in ipairs(snapshot.missing) do
      state.recent[#state.recent + 1] = {
        tick = snapshot.tick, code = "missing-service", detail = name,
      }
    end
    for _, entry in ipairs(snapshot.duplicates) do
      state.recent[#state.recent + 1] = {
        tick = snapshot.tick,
        code = "duplicate-service",
        detail = entry.name .. " count=" .. tostring(entry.count),
      }
    end
    for _, entry in ipairs(snapshot.malformed) do
      state.recent[#state.recent + 1] = {
        tick = snapshot.tick,
        code = "malformed-service",
        detail = entry.name .. " index=" .. tostring(entry.index),
      }
    end
    while #state.recent > 100 do table.remove(state.recent, 1) end
  end
  return snapshot
end

local function patch_diagnostics()
  local diagnostics =
    rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
    or rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diagnostics and type(diagnostics.pair_dump_lines) == "function") then
    return false
  end
  if diagnostics.broker_registry_integrity_0725_wrapped then return true end
  diagnostics.broker_registry_integrity_0725_wrapped = true
  local previous = diagnostics.pair_dump_lines
  diagnostics.pair_dump_lines = function(...)
    local lines = previous(...)
    lines = type(lines) == "table" and lines or {}
    local state = root()
    local last = state.last
    if not last or last.tick == nil then last = M.audit() end
    lines[#lines + 1] =
      "PAIR-DUMP-0468 BROKER-REGISTRY-0725 enabled=" .. safe(state.enabled)
      .. " broker_available=" .. safe(last.broker_available)
      .. " registry_available=" .. safe(last.registry_available)
      .. " complete=" .. safe(last.complete)
      .. " central_route_complete=" .. safe(last.central_route_complete)
      .. " central_route_count=" .. safe(last.central_route_count)
      .. " central_route_id=" .. safe(last.central_route_id)
      .. " total_services=" .. safe(last.total or 0)
      .. " critical_expected=" .. safe(last.critical_expected or 0)
      .. " missing=" .. safe(#(last.missing or {}))
      .. " duplicates=" .. safe(#(last.duplicates or {}))
      .. " malformed=" .. safe(#(last.malformed or {}))
    for index = math.max(1, #state.recent - 12), #state.recent do
      local event = state.recent[index]
      if event then
        lines[#lines + 1] =
          "PAIR-DUMP-0468 broker-registry.recent[" .. safe(index) .. "]"
          .. " tick=" .. safe(event.tick)
          .. " code=" .. safe(event.code)
          .. " " .. safe(event.detail)
      end
    end
    return lines
  end
  return true
end

local function register_service()
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if not (broker and type(broker.register_service) == "function") then return false end
  local service = broker.register_service({
    name = "broker_registry_integrity_0725",
    category = "diagnostics",
    interval = M.interval,
    priority = 996,
    budget = 1,
    dynamic_budget = false,
    note = "central route plus duplicate missing and malformed broker audit",
    fn = function()
      local snapshot = M.audit()
      return {
        processed = 1,
        acted = 0,
        failed = snapshot.complete and 0 or 1,
        detail =
          "central=" .. safe(snapshot.central_route_complete)
          .. " missing=" .. safe(#snapshot.missing)
          .. " duplicates=" .. safe(#snapshot.duplicates)
          .. " malformed=" .. safe(#snapshot.malformed),
      }
    end,
  })
  return service ~= nil
end

function M.install()
  local diagnostics_ok = patch_diagnostics()
  local broker_ok = register_service()
  _G.TechPriestsBrokerRegistryIntegrity0725 = M
  if log then
    log(
      "[Tech-Priests 0.1.674-dev] broker registry integrity audit armed"
      .. " diagnostics=" .. safe(diagnostics_ok)
      .. " broker=" .. safe(broker_ok)
      .. " control_storage_writes=0"
    )
  end
  return diagnostics_ok == true and broker_ok == true
end

return M
