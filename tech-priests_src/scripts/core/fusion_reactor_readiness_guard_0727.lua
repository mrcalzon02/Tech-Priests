-- Tech Priests 0.1.674-dev fusion-reactor readiness correction.
--
-- Fusion reactors use their electrical, item, fluid, and neighbour-connectable
-- contracts. They are not ordinary heat-buffer reactors and must not be blocked
-- merely because LuaEntity.heat_neighbours is empty. This module is a read-only
-- leaf correction beneath energy_family_readiness_0705.

local M = {
  version = "0.1.674-dev",
  storage_key = "fusion_reactor_readiness_guard_0727",
  minimum_fuel_items = 2,
}

local previous_inspect

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
  }
  storage.tech_priests[M.storage_key] = state
  state.version = M.version
  if state.enabled == nil then state.enabled = true end
  state.stats = state.stats or {}
  return state
end

local function stat(name, amount)
  local state = root()
  state.stats[name] = (state.stats[name] or 0) + (amount or 1)
end

local function corrected_state(report)
  if not report.has_item_fuel then return "monitor-only", "monitor" end
  if not report.burnt_ready then return "burnt-result-blocked", "blocked" end
  if not report.electric_ready then return "electric-network-missing", "blocked" end
  local fluid = type(report.fluid) == "table" and report.fluid or {}
  if fluid.input_ready == false then return "input-fluid-not-ready", "blocked" end
  if fluid.output_ready == false then return "output-fluid-not-ready", "blocked" end
  local burner = type(report.burner) == "table" and report.burner or {}
  if (tonumber(report.fuel_count) or 0) >= M.minimum_fuel_items
    or (tonumber(burner.remaining_burning_fuel) or 0) > 0
  then
    return "fuel-sufficient", "ready"
  end
  return "fuel-service-eligible", "eligible"
end

local function correct_report(report)
  if not (type(report) == "table" and report.entity_type == "fusion-reactor") then
    return report
  end
  local previous_state = report.state
  report.heat_ready = true
  report.heat_neighbour_count = 0
  report.fusion_heat_requirement_0727 = false
  report.fusion_readiness_basis_0727 = "electrical-item-fluid-neighbour-connectable"
  report.state, report.severity = corrected_state(report)
  if previous_state ~= report.state then
    stat("reports-corrected")
    stat("from-" .. tostring(previous_state or "nil"))
    stat("to-" .. tostring(report.state or "nil"))
  end
  return report
end

local function patch_readiness(readiness)
  if not (readiness and type(readiness.inspect_entity) == "function") then return false end
  if readiness.fusion_reactor_readiness_guard_0727_active then return true end
  readiness.fusion_reactor_readiness_guard_0727_active = true
  previous_inspect = readiness.inspect_entity
  readiness.inspect_entity = function(...)
    local report, why = previous_inspect(...)
    return correct_report(report), why
  end
  _G.tech_priests_energy_family_inspect_0705 = readiness.inspect_entity
  return true
end

local function patch_diagnostics()
  local diagnostics = rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
    or rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diagnostics and type(diagnostics.pair_dump_lines) == "function") then return false end
  if diagnostics.fusion_reactor_readiness_guard_0727_wrapped then return true end
  diagnostics.fusion_reactor_readiness_guard_0727_wrapped = true
  local previous = diagnostics.pair_dump_lines
  diagnostics.pair_dump_lines = function(...)
    local lines = previous(...)
    lines = type(lines) == "table" and lines or {}
    local state = root()
    lines[#lines + 1] = "PAIR-DUMP-0468 FUSION-READINESS-GUARD-0727 enabled="
      .. safe(state.enabled)
      .. " corrected=" .. safe(state.stats["reports-corrected"] or 0)
      .. " heat_requirement=false"
      .. " mutations=0"
    return lines
  end
  return true
end

function M.install()
  root()
  local ok, readiness = pcall(require, "scripts.core.energy_family_readiness_0705")
  if not (ok and readiness) then return false end
  local readiness_ok = patch_readiness(readiness)
  local diagnostics_ok = patch_diagnostics()
  _G.TechPriestsFusionReactorReadinessGuard0727 = M
  if log then
    log("[Tech-Priests 0.1.674-dev] fusion reactor readiness correction armed readiness="
      .. safe(readiness_ok) .. " diagnostics=" .. safe(diagnostics_ok))
  end
  return readiness_ok and diagnostics_ok
end

return M
