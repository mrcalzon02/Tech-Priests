-- 1406: explicit opt-in first Cogitator cold placement profiler.
-- Factorio LuaProfiler durations are LocalisedStrings, NOT numeric Lua data.
-- Hold timers only in module locals; never store LuaProfiler in save storage.
-- Absolutely no extra tick handlers, objects, ghosts or inventory changes.
local M={version="0.1.681.1406",enabled_flag="first_station_cold_profile_1406"}
local active_event,active_pair=nil,nil
local function state()
  return storage and storage.tech_priests
    and storage.tech_priests[M.enabled_flag] or nil
end
local function tick()return game and game.tick or 0 end
function M.enabled()
  local s=state()
  return s and s.enabled==true or false
end
local function timer()
  if not(game and type(game.create_profiler)=="function")then return nil end
  local ok,profiler=pcall(game.create_profiler,false)
  return ok and profiler or nil
end
local function stop(profiler)
  if not profiler then return end
  pcall(function()profiler.stop()end)
end
local function write(scope,unit,phase,profiler,why)
  if not(log and profiler)then return end
  -- Factorio formats LuaProfiler only in LocalisedString contexts. Do
  -- not parse tostring(profiler) as a reliable elapsed number.
  pcall(log,{"",
    "[TP-FIRST-STATION-1406] tick=",tick(),
    " scope=",scope," unit=",unit or 0,
    " phase=",phase or "unknown",
    " result=",why or "observed",
    " duration=",profiler,
  })
end
local function first_station(entity)
  if not(entity and entity.valid and entity.unit_number
    and type(entity.name)=="string")then return false end
  local tiers=rawget(_G,"TIER_CONFIGS")
  if not(type(tiers)=="table" and tiers[entity.name])then
    return false
  end
  local tp=storage and storage.tech_priests
  local pairs=tp and tp.pairs_by_station
  if type(pairs)=="table" then
    for _,pair in pairs(pairs)do
      if pair and pair.station and pair.station.valid then return false end
    end
  end
  return true
end
function M.start_event(_,event)
  if not M.enabled()or active_event then return nil end
  local entity=event and (event.entity or event.created_entity
    or event.destination)
  if not first_station(entity)then return nil end
  local profiler=timer()
  if not profiler then return nil end
  active_event={profiler=profiler,unit=entity.unit_number,
    began=tick()}
  return active_event
end
function M.stop_event(token)
  if not(token and token==active_event)then return false end
  local event=active_event
  active_event=nil
  stop(event.profiler)
  write("all-build-event-routes",event.unit,"registered-handlers",
    event.profiler,"measured")
  return true
end
function M.begin_pair(station)
  if not M.enabled()or active_pair or not first_station(station)
    then return false end
  local total=timer()
  local segment=timer()
  if not total or not segment then return false end
  active_pair={total=total,segment=segment,phase="spawn-configuration",
    unit=station.unit_number,parts={},began=tick()}
  return true
end
function M.checkpoint(phase)
  local a=active_pair
  if not a then return false end
  stop(a.segment)
  a.parts[#a.parts+1]={phase=a.phase,profiler=a.segment}
  a.phase=phase or "unknown"
  a.segment=timer()
  return true
end
function M.finish_pair(reason)
  local a=active_pair
  if not a then return false end
  active_pair=nil
  stop(a.segment)
  a.parts[#a.parts+1]={phase=a.phase,profiler=a.segment}
  stop(a.total)
  for _,part in ipairs(a.parts)do
    write("create-pair-stage",a.unit,part.phase,part.profiler,reason)
  end
  write("create-pair-total",a.unit,"all-creation-phases",
    a.total,reason)
  local s=state()
  if s then s.last_observed_station=a.unit;s.last_observed_tick=tick()end
  return true
end
function M.service_start(service,broker_state,t)
  if not M.enabled()then return nil end
  local wake=broker_state and broker_state.first_station_wake_1407
  if not(wake and wake.completed and t>=wake.tick
    and t<=wake.tick+300 and service and service.name)then
    return nil
  end
  local stats=broker_state.service_stats
    and broker_state.service_stats[service.name]
  if stats and (tonumber(stats.run)or 0)>0 then return nil end
  return timer()
end
function M.service_stop(service,profiler)
  if not profiler then return end
  stop(profiler)
  write("first-broker-service",nil,service.name,profiler,
    service.category)
end
function M.set_enabled(yes)
  if not(storage and storage.tech_priests)then return false end
  local s=state()
  if not s then s={};storage.tech_priests[M.enabled_flag]=s end
  s.enabled=yes==true
  return s.enabled
end
function M.install()
  _G.TechPriestsFirstStationColdProfile1406=M
  if commands and type(commands.add_command)=="function"then
    commands.add_command("tp-profile-first-station-1406",
      "Opt-in native first-station phase/broker profiling: on|off|status",
      function(event)
        local input=tostring(event and event.parameter or "status")
        local mode=input:lower():match("^%s*(.-)%s*$")
        if mode=="on"then M.set_enabled(true)
        elseif mode=="off"then M.set_enabled(false)
        elseif mode~="status"then
          mode="invalid"
        end
        local message="[TP-FIRST-STATION-1406] enabled="..
          tostring(M.enabled()).." mode="..mode..
          " tick="..tostring(tick())
        local player=event and event.player_index
          and game and game.get_player(event.player_index)
        if player and player.valid then player.print(message)
        elseif log then log(message)end
      end)
  end
  return true
end
return M
