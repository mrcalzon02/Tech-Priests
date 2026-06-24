-- Tech Priests 0.1.674-dev energy automation guard installation assertion.
--
-- This module performs no gameplay work. It fails the enclosing hardener chain if
-- 0722 did not actually wrap readiness, logistics, and automatic diagnostics.

local M = { version = "0.1.674-dev" }

local function safe(value)
  if value == nil then return "nil" end
  local ok, text = pcall(tostring, value)
  return ok and text or "?"
end

function M.install()
  local ok_readiness, readiness = pcall(require, "scripts.core.energy_family_readiness_0705")
  local ok_logistics, logistics = pcall(require, "scripts.core.energy_family_logistics_0707")
  local diagnostics = rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
    or rawget(_G, "TechPriestsEmergencyDiagnostics0468")

  local readiness_ok = ok_readiness and readiness
    and readiness.energy_item_automation_guard_0722_active == true
    and type(readiness.inspect_entity) == "function"
    and _G.tech_priests_energy_family_inspect_0705 == readiness.inspect_entity
  local logistics_ok = ok_logistics and logistics
    and logistics.energy_item_automation_guard_0722_active == true
    and type(logistics.service_pair) == "function"
  local diagnostics_ok = diagnostics
    and diagnostics.energy_item_automation_guard_0722_wrapped == true
    and type(diagnostics.pair_dump_lines) == "function"
  local global_ok = rawget(_G, "TechPriestsEnergyItemAutomationGuard0722") ~= nil

  M.last = {
    readiness = readiness_ok == true,
    logistics = logistics_ok == true,
    diagnostics = diagnostics_ok == true,
    global = global_ok == true,
  }
  M.complete = M.last.readiness and M.last.logistics
    and M.last.diagnostics and M.last.global
  _G.TechPriestsEnergyAutomationGuardInstallAssertion0726 = M

  if log then
    log("[Tech-Priests 0.1.674-dev] energy automation guard install assertion readiness="
      .. safe(M.last.readiness) .. " logistics=" .. safe(M.last.logistics)
      .. " diagnostics=" .. safe(M.last.diagnostics)
      .. " global=" .. safe(M.last.global)
      .. " complete=" .. safe(M.complete))
  end
  return M.complete
end

return M
