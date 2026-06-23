-- Tech Priests 0.1.667 fluid-connection execution guard.
-- A live 0691 plan owns the construction slot while waiting for pipe items.
-- Recently rejected proposals are hidden briefly so the same failed route is not
-- recalculated every construction tick. Planning and placement remain in 0691
-- and construction_planner.lua.

local M = {
  version = "0.1.667",
  storage_key = "fluid_connection_execution_guard_0692",
  rejection_cooldown = 60 * 10,
}

local previous_build_install
local previous_build_service_pair

local REJECTIONS = {
  ["pipe-route-rejected"] = true,
  ["pipe-plan-technology-locked"] = true,
  ["pipe-plan-aborted"] = true,
}

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok,s=pcall(tostring,v); return ok and s or "?" end
local function valid_pair(pair) return pair and valid(pair.station) and valid(pair.priest) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or { version=M.version, enabled=true, stats={}, recent={} }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  return r
end

local function stat(name, n) local r=root(); r.stats[name]=(r.stats[name] or 0)+(n or 1) end
local function record(pair, action, detail)
  local r=root(); stat(action)
  r.recent[#r.recent+1]={tick=now(),action=tostring(action),station=safe(station_unit(pair)),detail=tostring(detail or "")}
  while #r.recent>100 do table.remove(r.recent,1) end
end

local function planner_root()
  return storage and storage.tech_priests and storage.tech_priests.fluid_connection_planner_0691 or nil
end

local function pipe_count(pair)
  if type(_G.tech_priests_0358_station_item_count)=="function" then
    local ok,n=pcall(_G.tech_priests_0358_station_item_count,pair,"pipe")
    if ok then return tonumber(n) or 0 end
  end
  local total=0
  if type(_G.tech_priests_inventory_steward_sources_for_pair)=="function" then
    local ok,sources=pcall(_G.tech_priests_inventory_steward_sources_for_pair,pair)
    if ok and type(sources)=="table" then
      for _,src in ipairs(sources) do
        local inv=src and src.inv
        if inv and inv.valid then
          local ok2,n=pcall(function() return inv.get_item_count("pipe") end)
          if ok2 then total=total+(tonumber(n) or 0) end
        end
      end
    end
  end
  return total
end

local function refresh_request(pair, plan)
  local remaining=math.max(1,#(plan.tiles or {})-(tonumber(plan.current_index) or 1)+1)
  pair.active_supply_request={item="pipe",count=remaining,source="fluid-connection-planner-0691",purpose="construction-pipe",fluid=plan.fluid,plan_id=plan.id,tick=now()}
  pair.logistic_requested_item={item="pipe",count=remaining,source="fluid-connection-planner-0691",purpose="construction-pipe",plan_id=plan.id}
end

local function latest_rejection(pair, since)
  local r=planner_root(); if not (r and type(r.recent)=="table") then return nil end
  local unit=safe(station_unit(pair))
  for i=#r.recent,math.max(1,#r.recent-8),-1 do
    local ev=r.recent[i]
    if ev and (tonumber(ev.tick) or -1)>=since and safe(ev.station)==unit and REJECTIONS[ev.action] then return ev end
  end
  return nil
end

local function patched_service_pair(pair, reason, ...)
  if root().enabled==false or not valid_pair(pair) then return previous_build_service_pair(pair,reason,...) end
  local plan=pair.fluid_pipe_plan_0691
  if type(plan)=="table" and plan.state=="waiting-pipe-items" and not pair.construction_task_0338 and pipe_count(pair)<=0 then
    refresh_request(pair,plan)
    stat("construction_slot_held")
    return false,"fluid-pipe-plan-waiting-items"
  end

  local hidden=nil
  if not plan and (tonumber(pair.fluid_pipe_reject_until_0692) or 0)>now() then
    hidden=pair.fluid_connection_proposals_0689
    pair.fluid_connection_proposals_0689=nil
    stat("rejection_cooldown_hit")
  end

  local started=now()
  local acted,why=previous_build_service_pair(pair,reason,...)
  if hidden then pair.fluid_connection_proposals_0689=hidden end

  local rejection=latest_rejection(pair,started)
  if rejection then
    pair.fluid_pipe_reject_until_0692=now()+M.rejection_cooldown
    pair.fluid_pipe_last_rejection_0692={tick=now(),action=rejection.action,detail=rejection.detail}
    record(pair,"proposal-rejection-cooled",safe(rejection.action).." "..safe(rejection.detail))
  elseif pair.fluid_pipe_plan_0691 then
    pair.fluid_pipe_reject_until_0692=nil
  end
  return acted,why
end

local function patch_build(build)
  if not (build and type(build.service_pair)=="function") or build.fluid_connection_execution_guard_0692_active then return false end
  build.fluid_connection_execution_guard_0692_active=true
  previous_build_service_pair=build.service_pair
  build.service_pair=patched_service_pair
  return true
end

local function patch_diagnostics()
  local diag=rawget(_G,"TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468") or rawget(_G,"TechPriestsEmergencyDiagnostics0468")
  if not (diag and type(diag.pair_dump_lines)=="function") or diag.fluid_connection_execution_guard_0692_wrapped then return false end
  diag.fluid_connection_execution_guard_0692_wrapped=true
  local prev=diag.pair_dump_lines
  diag.pair_dump_lines=function(...)
    local lines=prev(...); lines=type(lines)=="table" and lines or {}; local r=root()
    lines[#lines+1]="PAIR-DUMP-0468 FLUID-CONNECTION-GUARD-0692 enabled="..safe(r.enabled).." slot_holds="..safe(r.stats.construction_slot_held or 0).." cooldown_hits="..safe(r.stats.rejection_cooldown_hit or 0).." cooled="..safe(r.stats["proposal-rejection-cooled"] or 0)
    return lines
  end
  return true
end

function M.activate(build) patch_build(build); patch_diagnostics(); _G.TechPriestsFluidConnectionExecutionGuard0692=M; return true end

function M.install()
  root()
  local okp=pcall(require,"scripts.core.fluid_connection_planner_0691")
  local ok,build=pcall(require,"scripts.core.construction_planner")
  if not (okp and ok and build) then return false end
  if not build.fluid_connection_execution_guard_0692_install_wrapped then
    build.fluid_connection_execution_guard_0692_install_wrapped=true
    previous_build_install=build.install
    build.install=function(...)
      local result=type(previous_build_install)=="function" and previous_build_install(...) or true
      M.activate(build)
      return result
    end
  end
  if rawget(_G,"TECH_PRIESTS_CONSTRUCTION_PLANNER_0338") then M.activate(build) end
  patch_diagnostics()
  _G.TechPriestsFluidConnectionExecutionGuard0692=M
  if log then log("[Tech-Priests 0.1.667] fluid pipe execution guard armed") end
  return true
end

return M
