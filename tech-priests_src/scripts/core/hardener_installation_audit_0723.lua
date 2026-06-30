-- Tech Priests 0.1.674-dev final hardener activation and installation audit.
--
-- Observes the final planning_constraints_0646 installation ledger after control
-- loading or configuration changes. The periodic audit is read-only. The install
-- pass also activates the late ammunition scavenge-first authority, which must
-- load after the proxy, logistics, leaf-truth, combat, and movement authorities.

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
    required_authorities = {},
  }
  storage.tech_priests[M.storage_key] = state
  state.version = M.version
  if state.enabled == nil then state.enabled = true end
  state.stats = state.stats or {}
  state.recent = state.recent or {}
  state.last = state.last or {}
  state.required_authorities = state.required_authorities or {}
  return state
end

local function stat(name, amount)
  local state = root()
  state.stats[name] = (state.stats[name] or 0) + (amount or 1)
end

local function activate_required_authorities()
  local state = root()
  local record = {
    module = "scripts.core.ammo_scavenge_priority_0740",
    label = "ammo_scavenge_priority_0740",
    attempted_tick = now(),
    ok = false,
    reason = "not-attempted",
  }
  local ok_require, authority = pcall(require, record.module)
  if not ok_require then
    record.reason = tostring(authority)
  elseif not (authority and type(authority.install) == "function") then
    record.reason = "module-missing-install"
  else
    local ok_install, result = pcall(authority.install)
    record.ok = ok_install and result ~= false
    record.reason = record.ok and "installed" or tostring(result)
  end
  state.required_authorities[record.label] = record
  if record.ok then stat("required-authorities-installed") else stat("required-authority-failures") end
  return record.ok, record
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

  local required = state.required_authorities.ammo_scavenge_priority_0740
  if not (required and required.ok == true and rawget(_G, "TechPriestsAmmoScavengePriority0740")) then
    failures[#failures + 1] = {
      module = "scripts.core.ammo_scavenge_priority_0740",
      label = "ammo_scavenge_priority_0740",
      reason = required and tostring(required.reason or "not-armed") or "not-armed",
    }
  end

  local snapshot = {
    tick = now(),
    available = constraints ~= nil,
    complete = constraints and constraints.install_complete == true and #failures == 0 or false,
    attempted = (constraints and tonumber(constraints.install_attempted) or 0) + 1,
    passed = (constraints and tonumber(constraints.install_passed) or 0) + (#failures == 0 and 1 or 0),
    failed = #failures,
    failures = failures,
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
    lines[#lines + 1] = "PAIR-DUMP-0468 HARDENER-INSTALLATION-0723 enabled="
      .. safe(state.enabled)
      .. " available=" .. safe(last.available)
      .. " complete=" .. safe(last.complete)
      .. " attempted=" .. safe(last.attempted or 0)
      .. " passed=" .. safe(last.passed or 0)
      .. " failed=" .. safe(last.failed or 0)
    local required = state.required_authorities.ammo_scavenge_priority_0740 or {}
    lines[#lines + 1] = "PAIR-DUMP-0468 required-authority[ammo_scavenge_priority_0740] ok="
      .. safe(required.ok) .. " reason=" .. safe(required.reason)
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
  local authority_ok, authority = activate_required_authorities()
  local diagnostics_ok = patch_diagnostics()
  local broker_ok = register_service()
  _G.TechPriestsHardenerInstallationAudit0723 = M
  if log then
    log("[Tech-Priests 0.1.674-dev] hardener installation audit armed authority="
      .. safe(authority_ok) .. " authority_reason=" .. safe(authority and authority.reason)
      .. " diagnostics=" .. safe(diagnostics_ok) .. " broker=" .. safe(broker_ok))
  end
  return authority_ok and diagnostics_ok and broker_ok
end

return M
