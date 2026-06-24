-- Tech Priests 0.1.674-dev broker registry integrity audit.
--
-- Confirms that critical development services are present exactly once. The
-- runtime broker already replaces registrations by name; this read-only audit
-- makes duplicate or missing service state visible after configuration changes.

local M = {
  version = "0.1.674-dev",
  storage_key = "broker_registry_integrity_0725",
  interval = 313,
}

local CRITICAL_SERVICES = {
  "energy_family_logistics_0707",
  "artillery_readiness_0712",
  "artillery_logistics_0713",
  "roboport_readiness_0714",
  "roboport_repair_pack_logistics_0715",
  "development_integration_audit_0721",
  "hardener_installation_audit_0723",
  "broker_registry_integrity_0725",
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

local function inspect_services()
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
    or package.loaded["scripts.core.runtime_tick_broker"]
  local counts = {}
  local total = 0
  for _, service in ipairs(broker and broker.services or {}) do
    if type(service) == "table" and service.name then
      local name = tostring(service.name)
      counts[name] = (counts[name] or 0) + 1
      total = total + 1
    end
  end

  local missing, duplicates = {}, {}
  for _, name in ipairs(CRITICAL_SERVICES) do
    if (counts[name] or 0) == 0 then missing[#missing + 1] = name end
  end
  for name, count in pairs(counts) do
    if count > 1 then
      duplicates[#duplicates + 1] = { name = name, count = count }
    end
  end
  table.sort(missing)
  table.sort(duplicates, function(a, b) return a.name < b.name end)
  return {
    tick = now(),
    broker_available = broker ~= nil,
    total = total,
    missing = missing,
    duplicates = duplicates,
    complete = broker ~= nil and #missing == 0 and #duplicates == 0,
  }
end

local function signature(snapshot)
  local parts = {}
  for _, name in ipairs(snapshot.missing or {}) do parts[#parts + 1] = "missing:" .. name end
  for _, entry in ipairs(snapshot.duplicates or {}) do
    parts[#parts + 1] = "duplicate:" .. entry.name .. "x" .. tostring(entry.count)
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
  if snapshot.complete then stat("complete-observations") else stat("incomplete-observations") end

  local current = signature(snapshot)
  if current ~= (state.last_signature or "") then
    state.last_signature = current
    for _, name in ipairs(snapshot.missing) do
      state.recent[#state.recent + 1] = {
        tick = snapshot.tick,
        code = "missing-service",
        detail = name,
      }
    end
    for _, entry in ipairs(snapshot.duplicates) do
      state.recent[#state.recent + 1] = {
        tick = snapshot.tick,
        code = "duplicate-service",
        detail = entry.name .. " count=" .. tostring(entry.count),
      }
    end
    while #state.recent > 80 do table.remove(state.recent, 1) end
  end
  return snapshot
end

local function patch_diagnostics()
  local diagnostics = rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
    or rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diagnostics and type(diagnostics.pair_dump_lines) == "function") then return false end
  if diagnostics.broker_registry_integrity_0725_wrapped then return true end
  diagnostics.broker_registry_integrity_0725_wrapped = true
  local previous = diagnostics.pair_dump_lines
  diagnostics.pair_dump_lines = function(...)
    local lines = previous(...)
    lines = type(lines) == "table" and lines or {}
    local state = root()
    local last = state.last or M.audit()
    lines[#lines + 1] = "PAIR-DUMP-0468 BROKER-REGISTRY-0725 enabled="
      .. safe(state.enabled)
      .. " broker_available=" .. safe(last.broker_available)
      .. " complete=" .. safe(last.complete)
      .. " total_services=" .. safe(last.total or 0)
      .. " missing=" .. safe(#(last.missing or {}))
      .. " duplicates=" .. safe(#(last.duplicates or {}))
    for index = math.max(1, #state.recent - 10), #state.recent do
      local event = state.recent[index]
      if event then
        lines[#lines + 1] = "PAIR-DUMP-0468 broker-registry.recent["
          .. safe(index) .. "] tick=" .. safe(event.tick)
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
    note = "read-only duplicate and missing broker service audit",
    fn = function()
      local snapshot = M.audit()
      return not snapshot.complete, "missing=" .. safe(#snapshot.missing)
        .. " duplicates=" .. safe(#snapshot.duplicates)
    end,
  })
  return service ~= nil
end

function M.install()
  root()
  local diagnostics_ok = patch_diagnostics()
  local broker_ok = register_service()
  _G.TechPriestsBrokerRegistryIntegrity0725 = M
  if log then
    log("[Tech-Priests 0.1.674-dev] broker registry integrity audit armed diagnostics="
      .. safe(diagnostics_ok) .. " broker=" .. safe(broker_ok))
  end
  return diagnostics_ok and broker_ok
end

return M
