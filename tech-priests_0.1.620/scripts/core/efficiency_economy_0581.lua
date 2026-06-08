-- scripts/core/efficiency_economy_0581.lua
-- Tech Priests 0.1.581
--
-- Legacy wrapper consolidation economy pass.  This module does not create a new
-- behavior controller.  It installs short-lived caches around the oldest global
-- helper routes that are still called from many generated fragments: pair lookup
-- and station-radius lookup.  The goal is to reduce repeated pcall / reverse-map
-- scans while preserving the old public function names for compatibility.

local M = {}
M.version = "0.1.581"
M.storage_key = "efficiency_economy_0581"
M.pair_lookup_ttl = 30
M.radius_lookup_ttl = 120
M.selected_lookup_ttl = 10
M.cleanup_interval = 60 * 31

local original_find_pair = nil
local original_selected_pair = nil
local original_refresh_radius = nil
local original_get_radius = nil

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok,out=pcall(function() return tostring(v) end); return ok and out or "?" end
local function lower(v) return string.lower(tostring(v or "")) end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key]
  if type(r) ~= "table" then
    r = {
      version = M.version,
      enabled = true,
      pair_by_unit = {},
      selected_by_player = {},
      radius_by_station = {},
      stats = {},
      recent = {},
    }
    storage.tech_priests[M.storage_key] = r
  end
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  r.pair_by_unit = r.pair_by_unit or {}
  r.selected_by_player = r.selected_by_player or {}
  r.radius_by_station = r.radius_by_station or {}
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  return r
end

local function stat(k,n) local r=M.root(); r.stats[k]=(r.stats[k] or 0)+(n or 1) end
local function remember(action, detail)
  local r=M.root()
  r.recent[#r.recent+1] = {tick=now(), action=tostring(action or "event"), detail=tostring(detail or "")}
  while #r.recent > 40 do table.remove(r.recent, 1) end
end

local function unit(entity)
  if not valid(entity) then return nil end
  return entity.unit_number
end

local function same_entity(a,b)
  return valid(a) and valid(b) and a.unit_number and b.unit_number and a.unit_number == b.unit_number
end

local function pair_still_matches(pair, entity)
  if type(pair) ~= "table" or not valid(entity) then return false end
  if same_entity(pair.station, entity) or same_entity(pair.priest, entity) then return true end
  local proxy = pair.proxy or pair.proxy_turret or pair.hidden_proxy
  if same_entity(proxy, entity) then return true end
  return false
end

local function valid_pair(pair)
  return type(pair) == "table" and valid(pair.station) and valid(pair.priest)
end

function M.invalidate_unit(unit_number, reason)
  if not unit_number then return end
  local r=M.root()
  r.pair_by_unit[tostring(unit_number)] = nil
  stat("invalidated_units")
end

function M.invalidate_all(reason)
  local r=M.root()
  r.pair_by_unit = {}
  r.selected_by_player = {}
  r.radius_by_station = {}
  stat("invalidated_all")
  remember("invalidate-all", reason or "unknown")
end

local function cached_find_pair(entity)
  local r=M.root()
  if r.enabled == false or type(original_find_pair) ~= "function" then
    return original_find_pair and original_find_pair(entity) or nil
  end
  local u = unit(entity)
  if not u then return original_find_pair(entity) end
  local key = tostring(u)
  local hit = r.pair_by_unit[key]
  if hit and tonumber(hit.expires or 0) >= now() then
    local pair = hit.pair
    if valid_pair(pair) and pair_still_matches(pair, entity) then
      stat("pair_lookup_hits")
      return pair
    end
    r.pair_by_unit[key] = nil
    stat("pair_lookup_stale")
  end
  local pair = original_find_pair(entity)
  if valid_pair(pair) and pair_still_matches(pair, entity) then
    r.pair_by_unit[key] = { pair = pair, expires = now() + M.pair_lookup_ttl }
    stat("pair_lookup_misses")
  else
    stat("pair_lookup_none")
  end
  return pair
end

local function cached_selected_pair(player)
  local r=M.root()
  if r.enabled == false or type(original_selected_pair) ~= "function" then
    return original_selected_pair and original_selected_pair(player) or nil
  end
  if not (player and player.valid) then return original_selected_pair(player) end
  local selected = player.selected
  if not valid(selected) then return original_selected_pair(player) end
  local selected_unit = selected.unit_number
  local key = tostring(player.index or 0)
  local hit = r.selected_by_player[key]
  if hit and tonumber(hit.expires or 0) >= now() and hit.selected_unit == selected_unit then
    if valid_pair(hit.pair) and pair_still_matches(hit.pair, selected) then
      stat("selected_lookup_hits")
      return hit.pair
    end
    r.selected_by_player[key] = nil
    stat("selected_lookup_stale")
  end
  local pair = original_selected_pair(player)
  if valid_pair(pair) and pair_still_matches(pair, selected) then
    r.selected_by_player[key] = { pair = pair, selected_unit = selected_unit, expires = now() + M.selected_lookup_ttl }
    stat("selected_lookup_misses")
  end
  return pair
end

local function station_radius_uncached(station)
  if type(original_get_radius) == "function" then return original_get_radius(station) end
  return nil
end

local function cached_get_radius(station)
  local r=M.root()
  if r.enabled == false or type(original_get_radius) ~= "function" then return station_radius_uncached(station) end
  if not valid(station) then return station_radius_uncached(station) end
  local u = station.unit_number
  if not u then return station_radius_uncached(station) end
  local key = tostring(u)
  local hit = r.radius_by_station[key]
  if hit and tonumber(hit.expires or 0) >= now() then
    stat("radius_lookup_hits")
    return hit.radius
  end
  local radius = station_radius_uncached(station)
  if tonumber(radius) then
    r.radius_by_station[key] = { radius = tonumber(radius), expires = now() + M.radius_lookup_ttl }
    stat("radius_lookup_misses")
  else
    stat("radius_lookup_none")
  end
  return radius
end

local function cached_refresh_radius(pair)
  local r=M.root()
  if r.enabled == false or type(original_refresh_radius) ~= "function" then
    return original_refresh_radius and original_refresh_radius(pair) or nil
  end
  if type(pair) ~= "table" or not valid(pair.station) then return original_refresh_radius(pair) end
  local radius = cached_get_radius(pair.station)
  if tonumber(radius) then
    pair.radius = tonumber(radius)
    stat("refresh_radius_cached")
    return tonumber(radius)
  end
  local out = original_refresh_radius(pair)
  if tonumber(out) then pair.radius = tonumber(out) end
  stat("refresh_radius_fallback")
  return out
end

local function install_wrappers()
  local changed = 0
  if type(_G.find_pair_for_entity) == "function" and not original_find_pair then
    original_find_pair = _G.find_pair_for_entity
    _G.TECH_PRIESTS_0581_PRE_FIND_PAIR_FOR_ENTITY = original_find_pair
    _G.find_pair_for_entity = function(entity, ...) return cached_find_pair(entity, ...) end
    changed = changed + 1
  end
  if type(_G.selected_pair_for_player) == "function" and not original_selected_pair then
    original_selected_pair = _G.selected_pair_for_player
    _G.TECH_PRIESTS_0581_PRE_SELECTED_PAIR_FOR_PLAYER = original_selected_pair
    _G.selected_pair_for_player = function(player, ...) return cached_selected_pair(player, ...) end
    changed = changed + 1
  end
  if type(_G.get_station_operating_radius) == "function" and not original_get_radius then
    original_get_radius = _G.get_station_operating_radius
    _G.TECH_PRIESTS_0581_PRE_GET_STATION_OPERATING_RADIUS = original_get_radius
    _G.get_station_operating_radius = function(station, ...) return cached_get_radius(station, ...) end
    changed = changed + 1
  end
  if type(_G.refresh_pair_radius) == "function" and not original_refresh_radius then
    original_refresh_radius = _G.refresh_pair_radius
    _G.TECH_PRIESTS_0581_PRE_REFRESH_PAIR_RADIUS = original_refresh_radius
    _G.refresh_pair_radius = function(pair, ...) return cached_refresh_radius(pair, ...) end
    changed = changed + 1
  end
  return changed
end

local function install_events()
  local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not (R and R.on_event and R.on_nth_tick and defines and defines.events) then return false end
  local events = defines.events
  local function invalidate_entity(event)
    local entity = event and (event.entity or event.created_entity or event.destination)
    if valid(entity) then
      M.invalidate_unit(entity.unit_number, "entity-event")
      if entity.name and tostring(entity.name):find("cogitator", 1, true) then M.invalidate_all("station-event") end
    end
  end
  R.on_event({ events.on_built_entity, events.on_robot_built_entity, events.script_raised_built, events.script_raised_revive, events.on_player_mined_entity, events.on_robot_mined_entity, events.on_entity_died, events.script_raised_destroy }, invalidate_entity, nil, { owner="efficiency_economy_0581", category="legacy-wrapper", note="invalidate pair/radius helper caches when entities change" })
  if events.on_research_finished then
    R.on_event(events.on_research_finished, function() M.invalidate_all("research-finished") end, nil, { owner="efficiency_economy_0581", category="legacy-wrapper", note="radius bonuses may have changed" })
  end
  R.on_nth_tick(M.cleanup_interval, function() M.cleanup() end, { owner="efficiency_economy_0581", category="economy", priority="last", note="prune helper caches" })
  return true
end

function M.cleanup()
  local r=M.root()
  local t=now()
  for key, hit in pairs(r.pair_by_unit or {}) do
    if (not hit) or tonumber(hit.expires or 0) < t or not valid_pair(hit.pair) then r.pair_by_unit[key] = nil; stat("cleanup_pair") end
  end
  for key, hit in pairs(r.selected_by_player or {}) do
    if (not hit) or tonumber(hit.expires or 0) < t or not valid_pair(hit.pair) then r.selected_by_player[key] = nil; stat("cleanup_selected") end
  end
  for key, hit in pairs(r.radius_by_station or {}) do
    if (not hit) or tonumber(hit.expires or 0) < t then r.radius_by_station[key] = nil; stat("cleanup_radius") end
  end
end

local function status()
  local r=M.root()
  local p=0; for _ in pairs(r.pair_by_unit or {}) do p=p+1 end
  local s=0; for _ in pairs(r.selected_by_player or {}) do s=s+1 end
  local rad=0; for _ in pairs(r.radius_by_station or {}) do rad=rad+1 end
  return "[tp-efficiency-economy-0581] enabled="..safe(r.enabled).." pair_cache="..safe(p).." selected_cache="..safe(s).." radius_cache="..safe(rad).." pair_hits="..safe(r.stats.pair_lookup_hits or 0).." radius_hits="..safe(r.stats.radius_lookup_hits or 0).." refresh_cached="..safe(r.stats.refresh_radius_cached or 0)
end

local function install_command()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-efficiency-economy-0581") end end)
  commands.add_command("tp-efficiency-economy-0581", "Tech Priests 0.1.581 legacy wrapper economy. Params: on/off/clear/status", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local param = lower(event and event.parameter or "status")
    local r=M.root()
    if param == "on" then r.enabled = true end
    if param == "off" then r.enabled = false end
    if param == "clear" then M.invalidate_all("command") end
    local msg = status()
    if player and player.valid then player.print(msg) elseif game and game.print then game.print(msg) end
  end)
end

function M.install()
  M.root()
  local wrapped = install_wrappers()
  install_events()
  install_command()
  _G.TechPriestsEfficiencyEconomy0581 = M
  if log then log("[Tech-Priests 0.1.581] legacy wrapper economy installed; wrapped="..safe(wrapped)) end
  return true
end

return M
