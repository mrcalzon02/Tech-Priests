-- Tech Priests 0.1.674-dev hardener installation audit and regression quarantine.
--
-- Observes the final planning_constraints_0646 installation ledger after control
-- loading or configuration changes. The periodic audit is read-only. Its install
-- pass performs a one-time quarantine of the retired 0.1.674 five-tick
-- ammunition authority and re-arms the repaired development integration audit.

local M = {
  version = "0.1.674-dev",
  storage_key = "hardener_installation_audit_0723",
  interval = 311,
  recent_limit = 80,
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
    recent = {},
    last = {},
    quarantine = {},
  }
  storage.tech_priests[M.storage_key] = state
  state.version = M.version
  if state.enabled == nil then state.enabled = true end
  state.stats = state.stats or {}
  state.recent = state.recent or {}
  state.last = state.last or {}
  state.quarantine = state.quarantine or {}
  return state
end

local function stat(name, amount)
  local state = root()
  state.stats[name] = (state.stats[name] or 0) + (amount or 1)
end

local function disable_broker_service(broker, name)
  local disabled = 0
  for _, service in ipairs((broker and broker.services) or {}) do
    if service and service.name == name and service.enabled ~= false then
      service.enabled = false
      disabled = disabled + 1
    end
  end
  return disabled
end

local function enable_broker_service(broker, name)
  local enabled = 0
  for _, service in ipairs((broker and broker.services) or {}) do
    if service and service.name == name and service.enabled == false then
      service.enabled = true
      enabled = enabled + 1
    end
  end
  return enabled
end

local function restore_ammo_wrappers()
  local restored = 0

  local ok_leaf, leaf = pcall(require, "scripts.core.active_leaf_task_truth_0655")
  if ok_leaf and leaf and type(leaf.TECH_PRIESTS_0740_PRE_TRUTH) == "function" then
    leaf.truth = leaf.TECH_PRIESTS_0740_PRE_TRUTH
    leaf.TECH_PRIESTS_0740_PRE_TRUTH = nil
    leaf.ammo_scavenge_0740_wrapped = nil
    restored = restored + 1
  end

  local ok_direct, direct = pcall(require, "scripts.core.direct_acquisition_executor_0513")
  if ok_direct and direct and type(direct.TECH_PRIESTS_0740_PRE_SERVICE_PAIR) == "function" then
    direct.service_pair = direct.TECH_PRIESTS_0740_PRE_SERVICE_PAIR
    direct.TECH_PRIESTS_0740_PRE_SERVICE_PAIR = nil
    direct.ammo_scavenge_0740_wrapped = nil
    restored = restored + 1
  end

  local previous_combat = rawget(_G, "TECH_PRIESTS_0740_PRE_FORCE_COMBAT_TICK")
  if type(previous_combat) == "function" then
    _G.tech_priests_0293_force_combat_tick = previous_combat
    _G.tech_priests_0292_force_combat_tick = previous_combat
    _G.TECH_PRIESTS_0740_PRE_FORCE_COMBAT_TICK = nil
    restored = restored + 1
  end

  return restored
end

local function quarantine_regressions()
  local state = root()
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  local ammo_services = disable_broker_service(broker, "ammo_scavenge_priority_0740")
  local audit_services = enable_broker_service(broker, "development_integration_audit_0721")
  local wrappers = restore_ammo_wrappers()

  local tp = storage.tech_priests or {}
  if tp.ammo_scavenge_priority_0740 then
    tp.ammo_scavenge_priority_0740.enabled = false
  end
  if tp.development_integration_audit_0721 and tp.development_integration_audit_0721.enabled == false then
    tp.development_integration_audit_0721.enabled = true
    audit_services = audit_services + 1
  end

  state.quarantine = {
    tick = now(),
    ammo_services_disabled = ammo_services,
    development_audit_services_reenabled = audit_services,
    ammo_wrappers_restored = wrappers,
  }
  stat("regression-quarantines")
  stat("ammo-services-disabled", ammo_services)
  stat("development-audit-services-reenabled", audit_services)
  stat("ammo-wrappers-restored", wrappers)

  if log then
    log("[Tech-Priests 0.1.674-dev] regression quarantine applied ammo_services="
      .. safe(ammo_services)
      .. " development_audit_reenabled=" .. safe(audit_services)
      .. " wrappers_restored=" .. safe(wrappers))
  end
  return true
end

local function copy_failures(source)
  local out = {}
  for _, failure in ipairs(source or {}) do
    out[#out + 1] = {
      module = tostring(failure.module or "unknown"),
      label = tostring(failure.label or failure.module or "unknown"),
      reason = tostring(failure.reason or "unknown"),
    }
  end
  return out
end

local function failure_signature(failures)
  local parts = {}
  for _, failure in ipairs(failures or {}) do
    parts[#parts + 1] = failure.label .. "=" .. failure.reason
  end
  table.sort(parts)
  return table.concat(parts, "|")
end

local function remember_failures(state, snapshot)
  local signature = failure_signature(snapshot.failures)
  if signature == (state.last_failure_signature or "") then return end
  state.last_failure_signature = signature
  for _, failure in ipairs(snapshot.failures) do
    state.recent[#state.recent + 1] = {
      tick = snapshot.tick,
      label = failure.label,
      module = failure.module,
      reason = failure.reason,
    }
  end
  while #state.recent > M.recent_limit do table.remove(state.recent, 1) end
end

function M.inspect()
  local state = root()
  local constraints = rawget(_G, "TechPriestsPlanningConstraints0646")
  local failures = constraints and copy_failures(constraints.install_failures) or {
    {
      module = "scripts.core.planning_constraints_0646",
      label = "planning_constraints_0646",
      reason = "module-global-missing",
    },
  }
  if constraints and constraints.install_complete ~= true and #failures == 0 then
    failures[1] = {
      module = "scripts.core.planning_constraints_0646",
      label = "planning_constraints_0646",
      reason = "installation-incomplete-without-failure-detail",
    }
  end

  local snapshot = {
    tick = now(),
    available = constraints ~= nil,
    complete = constraints and constraints.install_complete == true or false,
    attempted = constraints and tonumber(constraints.install_attempted) or 0,
    passed = constraints and tonumber(constraints.install_passed) or 0,
    failed = #failures,
    failures = failures,
    quarantine = state.quarantine,
  }
  state.last = snapshot
  remember_failures(state, snapshot)
  stat("audits")
  stat("failures-observed", #failures)
  if snapshot.complete then stat("complete-observations") else stat("incomplete-observations") end
  return snapshot
end

local function patch_diagnostics()
  local diagnostics = rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
    or rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diagnostics and type(diagnostics.pair_dump_lines) == "function") then return false end
  if diagnostics.hardener_installation_audit_0723_wrapped then return true end
  diagnostics.hardener_installation_audit_0723_wrapped = true
  local previous = diagnostics.pair_dump_lines
  diagnostics.pair_dump_lines = function(...)
    local lines = previous(...)
    lines = type(lines) == "table" and lines or {}
    local state = root()
    local last = state.last or M.inspect()
    local quarantine = state.quarantine or {}
    lines[#lines + 1] = "PAIR-DUMP-0468 HARDENER-INSTALLATION-0723 enabled="
      .. safe(state.enabled)
      .. " available=" .. safe(last.available)
      .. " complete=" .. safe(last.complete)
      .. " attempted=" .. safe(last.attempted or 0)
      .. " passed=" .. safe(last.passed or 0)
      .. " failed=" .. safe(last.failed or 0)
    lines[#lines + 1] = "PAIR-DUMP-0468 regression-quarantine ammo_services="
      .. safe(quarantine.ammo_services_disabled or 0)
      .. " development_audit_reenabled=" .. safe(quarantine.development_audit_services_reenabled or 0)
      .. " wrappers_restored=" .. safe(quarantine.ammo_wrappers_restored or 0)
    for index = math.max(1, #state.recent - 12), #state.recent do
      local event = state.recent[index]
      if event then
        lines[#lines + 1] = "PAIR-DUMP-0468 hardener-install.recent["
          .. safe(index) .. "] tick=" .. safe(event.tick)
          .. " label=" .. safe(event.label)
          .. " module=" .. safe(event.module)
          .. " reason=" .. safe(event.reason)
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
    name = "hardener_installation_audit_0723",
    category = "diagnostics",
    interval = M.interval,
    priority = 997,
    budget = 1,
    dynamic_budget = false,
    note = "read-only final hardener installation ledger audit",
    fn = function()
      local snapshot = M.inspect()
      return snapshot.failed > 0, "complete=" .. safe(snapshot.complete)
        .. " failed=" .. safe(snapshot.failed)
    end,
  })
  return service ~= nil
end

function M.install()
  root()
  local quarantine_ok = quarantine_regressions()
  local diagnostics_ok = patch_diagnostics()
  local broker_ok = register_service()
  _G.TechPriestsHardenerInstallationAudit0723 = M
  if log then
    log("[Tech-Priests 0.1.674-dev] hardener installation audit armed quarantine="
      .. safe(quarantine_ok)
      .. " diagnostics=" .. safe(diagnostics_ok)
      .. " broker=" .. safe(broker_ok))
  end
  return quarantine_ok and diagnostics_ok and broker_ok
end

return M
