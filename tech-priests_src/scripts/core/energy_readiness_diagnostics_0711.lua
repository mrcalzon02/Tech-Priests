-- Tech Priests 0.1.674-dev energy-readiness diagnostic correction.
-- 0705 records state keys with hyphens. Its original diagnostic line reads
-- underscore variants and can falsely report zero. This wrapper appends the
-- authoritative counters without changing readiness or logistics behavior.

local M = {
  version = "0.1.674-dev",
  storage_key = "energy_readiness_diagnostics_0711",
}

local function safe(value)
  if value == nil then return "nil" end
  local ok, text = pcall(tostring, value)
  return ok and text or "?"
end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or { version = M.version, enabled = true }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  return r
end

local function patch_diagnostics()
  local diagnostics = rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
    or rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diagnostics and type(diagnostics.pair_dump_lines) == "function")
    or diagnostics.energy_readiness_diagnostics_0711_wrapped
  then
    return false
  end
  diagnostics.energy_readiness_diagnostics_0711_wrapped = true
  local previous = diagnostics.pair_dump_lines
  diagnostics.pair_dump_lines = function(...)
    local lines = previous(...)
    lines = type(lines) == "table" and lines or {}
    local readiness = storage and storage.tech_priests
      and storage.tech_priests.energy_family_readiness_0705 or { stats = {} }
    local stats = readiness.stats or {}
    lines[#lines + 1] = "PAIR-DUMP-0468 ENERGY-READINESS-CORRECTED-0711 enabled="
      .. safe(root().enabled)
      .. " eligible=" .. safe(stats["state_fuel-service-eligible"] or 0)
      .. " fuel_sufficient=" .. safe(stats["state_fuel-sufficient"] or 0)
      .. " input_fluid_blocked=" .. safe(stats["state_input-fluid-not-ready"] or 0)
      .. " output_fluid_blocked=" .. safe(stats["state_output-fluid-not-ready"] or 0)
      .. " electric_blocked=" .. safe(stats["state_electric-network-missing"] or 0)
      .. " heat_blocked=" .. safe(stats["state_heat-network-missing"] or 0)
      .. " burnt_blocked=" .. safe(stats["state_burnt-result-blocked"] or 0)
      .. " monitor_only=" .. safe(stats["state_monitor-only"] or 0)
    return lines
  end
  return true
end

function M.install()
  root()
  patch_diagnostics()
  _G.TechPriestsEnergyReadinessDiagnostics0711 = M
  if log then log("[Tech-Priests 0.1.674-dev] corrected hyphenated energy readiness counters armed") end
  return true
end

return M
