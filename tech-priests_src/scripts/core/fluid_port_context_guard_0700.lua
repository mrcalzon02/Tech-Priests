-- Tech Priests 0.1.670 fluid-port validation context guard.
-- Ensures the pair's active 0689 report belongs to the exact machine whose input
-- or output route is about to be validated. This prevents equal fluidbox indexes
-- on unrelated machines from being mistaken for the current recipe port map.

local M = {
  version = "0.1.670",
  storage_key = "fluid_port_context_guard_0700",
  report_max_age = 60 * 5,
}

local previous_build_install
local previous_build_service_pair

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v==nil then return "nil" end local ok,s=pcall(tostring,v); return ok and s or "?" end
local function valid_pair(pair) return pair and valid(pair.station) and valid(pair.priest) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end

local function root()
  storage.tech_priests=storage.tech_priests or {}
  local r=storage.tech_priests[M.storage_key] or {version=M.version,enabled=true,stats={},recent={}}
  storage.tech_priests[M.storage_key]=r
  r.version=M.version
  if r.enabled==nil then r.enabled=true end
  r.stats=r.stats or {}; r.recent=r.recent or {}
  return r
end
local function stat(name,n) local r=root(); r.stats[name]=(r.stats[name] or 0)+(n or 1) end
local function record(pair,action,detail) local r=root(); stat(action); r.recent[#r.recent+1]={tick=now(),action=tostring(action),station=safe(station_unit(pair)),detail=tostring(detail or "")}; while #r.recent>100 do table.remove(r.recent,1) end end

local function doctrine()
  local d=rawget(_G,"TechPriestsFluidNetworkDoctrine0689")
  if d then return d end
  local ok,module=pcall(require,"scripts.core.fluid_network_doctrine_0689")
  return ok and module or nil
end

local function proposal_machine(pair)
  local input_plan=pair.fluid_pipe_plan_0691
  if input_plan and valid(input_plan.machine) then return input_plan.machine,"active-input-plan" end
  local output_plan=pair.fluid_output_pipe_plan_0696
  if output_plan and valid(output_plan.machine) then return output_plan.machine,"active-output-plan" end
  for _,proposal in ipairs(pair.fluid_connection_proposals_0689 or {}) do if type(proposal)=="table" and valid(proposal.machine) then return proposal.machine,"input-proposal" end end
  for _,proposal in ipairs(pair.fluid_output_sink_proposals_0694 or {}) do if type(proposal)=="table" and valid(proposal.machine) then return proposal.machine,"output-proposal" end end
  return nil,"none"
end

local function report_matches(report,machine)
  return type(report)=="table" and valid(report.machine) and report.machine==machine and now()-(tonumber(report.tick) or -1000000)<=M.report_max_age
end

local function refresh_context(pair)
  local machine,reason=proposal_machine(pair)
  if not machine then return false,"no-machine" end
  if report_matches(pair.machine_fluid_network_0689,machine) then stat("matching_context_reused"); return true,"reused" end
  local d=doctrine()
  if not (d and type(d.inspect_machine)=="function") then return false,"doctrine-unavailable" end
  local ok,report=pcall(d.inspect_machine,pair,machine,true)
  if ok and report_matches(report,machine) then record(pair,"machine-context-refreshed",reason.." "..safe(machine.name).."#"..safe(machine.unit_number)); return true,"refreshed" end
  record(pair,"machine-context-refresh-failed",reason.." "..safe(machine.name).."#"..safe(machine.unit_number))
  return false,"refresh-failed"
end

local function patched_service_pair(pair,reason,...)
  if root().enabled~=false and valid_pair(pair) then refresh_context(pair) end
  return previous_build_service_pair(pair,reason,...)
end

local function patch_build(build)
  if not (build and type(build.service_pair)=="function") or build.fluid_port_context_guard_0700_active then return false end
  build.fluid_port_context_guard_0700_active=true; previous_build_service_pair=build.service_pair; build.service_pair=patched_service_pair; return true
end

local function patch_diagnostics()
  local diag=rawget(_G,"TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468") or rawget(_G,"TechPriestsEmergencyDiagnostics0468")
  if not (diag and type(diag.pair_dump_lines)=="function") or diag.fluid_port_context_guard_0700_wrapped then return false end
  diag.fluid_port_context_guard_0700_wrapped=true; local prev=diag.pair_dump_lines
  diag.pair_dump_lines=function(...)
    local lines=prev(...); lines=type(lines)=="table" and lines or {}; local r=root()
    lines[#lines+1]="PAIR-DUMP-0468 FLUID-PORT-CONTEXT-0700 enabled="..safe(r.enabled).." reused="..safe(r.stats.matching_context_reused or 0).." refreshed="..safe(r.stats["machine-context-refreshed"] or 0).." refresh_failed="..safe(r.stats["machine-context-refresh-failed"] or 0)
    return lines
  end
  return true
end

function M.activate(build) patch_build(build); patch_diagnostics(); _G.TechPriestsFluidPortContextGuard0700=M; return true end
function M.install()
  root(); pcall(require,"scripts.core.fluid_port_collision_validator_0699")
  local ok,build=pcall(require,"scripts.core.construction_planner"); if not (ok and build) then return false end
  if not build.fluid_port_context_guard_0700_install_wrapped then build.fluid_port_context_guard_0700_install_wrapped=true; previous_build_install=build.install; build.install=function(...) local result=type(previous_build_install)=="function" and previous_build_install(...) or true; M.activate(build); return result end end
  if rawget(_G,"TECH_PRIESTS_CONSTRUCTION_PLANNER_0338") then M.activate(build) end
  patch_diagnostics(); _G.TechPriestsFluidPortContextGuard0700=M
  if log then log("[Tech-Priests 0.1.670] fluid-port validation now refreshes the exact active machine context") end
  return true
end

return M
