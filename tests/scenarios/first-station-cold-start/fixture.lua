-- CI-only first station placement benchmark. Installed ONLY in disposable
-- test mod copies. Never bundled in normal Tech Priests releases.
-- Distinguishes empty-world baseline from first-station wake. Uses actual
-- Factorio LuaSurface.create_entity and script_raised_built, never synthetic
-- inventory, ghost credit or completion. Human on_built_entity must also be
-- profiled separately from the opt-in in-game command.
local M={version="1408",prefix="[TP-FIRST-STATION-BENCH-1408] "}
local at=600
local function logline(phase,detail)
  if log then log(M.prefix..phase.." tick="..tostring(game and game.tick)
    .." "..tostring(detail or ""))end
end
local function first_pair_count()
  local pairs_by=storage and storage.tech_priests
    and storage.tech_priests.pairs_by_station
  local count=0
  for _,pair in pairs(pairs_by or {})do
    if pair and pair.station and pair.station.valid
      and pair.priest and pair.priest.valid then count=count+1 end
  end
  return count
end
local function station_name()
  return "junior-cogitator-station"
end
local function place_first_station()
  local surface=game.surfaces[1]
  local force=game.forces["player"]
  if not(surface and force and surface.find_non_colliding_position
    and surface.create_entity)then
    logline("FAIL","surface-or-native-create-api-missing")
    return false
  end
  local name=station_name()
  if not(prototypes and prototypes.entity and prototypes.entity[name])then
    logline("FAIL","station-prototype-missing name="..name)
    return false
  end
  local start={x=36,y=36}
  local ok,pos=pcall(function()
    return surface.find_non_colliding_position(name,start,48,1,false)end)
  if not(ok and pos)then
    logline("FAIL","no-native-station-build-position")
    return false
  end
  local made,station=pcall(function()
    -- Factorio script-raised build exercises canonical runtime build routes.
    -- Manual player on_built_entity requires an in-client follow-up.
    return surface.create_entity{
      name=name,position=pos,force=force,raise_built=true}
  end)
  if not(made and station and station.valid and station.unit_number)then
    logline("FAIL","real-station-placement-refused "..tostring(station))
    return false
  end
  local registered=storage and storage.tech_priests
    and storage.tech_priests.pairs_by_station
    and storage.tech_priests.pairs_by_station[station.unit_number]
  if not(registered and registered.station==station
    and registered.priest and registered.priest.valid)then
    logline("FAIL","first-native-station-not-registered")
    return false
  end
  logline("PLACED","station="..station.unit_number
    .." priest="..registered.priest.unit_number
    .." mode=script-raised-build")
  return true
end
function M.install()
  local case=rawget(_G,"TP_CI_FIRST_STATION_1408_CASE")
  if case~="baseline" and case~="placement"
    and case~="placement-unprofiled" then
    error("first-station fixture case must be baseline or placement")
  end
  local Profile=require("scripts.core.first_station_cold_profile_1406")
  local Registry=require("scripts.core.runtime_event_registry")
  Registry.on_init(function()
    storage.tech_priests=storage.tech_priests or{}
    storage.tech_priests.first_station_fixture_1408={
      case=case,placed=false,passed=false}
    Profile.set_enabled(case=="placement")
  end,{owner="first-station-cold-start-1408",
    route="prepare-native-placement",priority=900})
  local event=defines and defines.events and defines.events.on_tick
  if not event then error("native on_tick API missing")end
  local registered=Registry.on_event(event,function(tick_event)
    local t=tick_event and tick_event.tick or game.tick
    local f=storage.tech_priests.first_station_fixture_1408
    if not f then return end
    if t==540 then
      local pre=first_pair_count()
      logline("BEFORE","pairs="..pre)
      if pre~=0 then logline("FAIL","nonempty-baseline-before-test")end
    elseif t==at then
      if f.case=="placement"or f.case=="placement-unprofiled"then
        f.placed=place_first_station()
      else
        logline("NO-PLACEMENT","pairs="..first_pair_count())
      end
    elseif t==at+5 or t==at+60 or t==at+180
      or t==at+600 or t==1800 then
      local broker=rawget(_G,"TechPriestsRuntimeTickBroker0600")
      local root=broker and broker.root and broker.root() or nil
      local wake=root and root.first_station_wake_1407
      logline("SAMPLE","pairs="..first_pair_count()
        .." staggered="..tostring(wake and wake.deferred_services or 0)
        .." critical="..tostring(wake and wake.immediate_services or 0)
        .." runtime_callbacks="..tostring(root
          and root.stats and root.stats.services_run or 0))
      if t==1800 then
        if f.case=="placement" or f.case=="placement-unprofiled" then
          f.passed=f.placed and first_pair_count()==1
            and wake and wake.completed==true
            and wake.deferred_services>0
            and wake.longest_delay_ticks<=120 or false
        else
          f.passed=first_pair_count()==0
            and not wake
        end
        if f.passed then logline("PASS","case="..f.case
          .." native_first_station_wake="..tostring(f.case~="baseline"))
        else logline("FAIL","case="..f.case
          .." missing-engine-pair-or-scheduling-proof")end
      end
    end
  end,nil,{owner="first-station-cold-start-1408",
    route="single-native-placement-at-600",priority=900})
  if not registered then error("first-station benchmark on_tick route unavailable")end
  return true
end
return M
