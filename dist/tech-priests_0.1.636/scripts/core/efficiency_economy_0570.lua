-- scripts/core/efficiency_economy_0570.lua
-- Tech Priests 0.1.570
--
-- Second clean megabase-efficiency step.  This module adds shared dirty-region
-- query helpers and negative-result cooldowns around expensive resource doctrine
-- fallback scans.  It is a governor over existing scheduler/dispatcher/executor
-- authorities: it does not choose work, move priests, mine, consecrate, repair,
-- construct, or complete orders.

local M = {}
M.version = "0.1.608"
M.storage_key = "efficiency_economy_0570"
M.negative_source_cooldown_ticks = 60 * 8
M.negative_cache_keep_ticks = 60 * 60 * 10
M.negative_cache_prune_ticks = 60 * 60
M.dirty_cell_radius_padding = 1

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok,out=pcall(function() return tostring(v) end); return ok and out or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function metric(k,n) local fn=rawget(_G,"tech_priests_runtime_metric_0606"); if type(fn)=="function" then pcall(fn,k,n or 1) end end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function valid_pair(pair) return type(pair)=="table" and valid(pair.station) and valid(pair.priest) end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key]
  if type(r) ~= "table" then
    r = { version=M.version, enabled=true, negative_cache_enabled=true, stats={}, negative_until={}, recent={} }
    storage.tech_priests[M.storage_key] = r
  end
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.negative_cache_enabled == nil then r.negative_cache_enabled = true end
  r.stats = r.stats or {}
  r.negative_until = r.negative_until or {}
  r.recent = r.recent or {}
  return r
end

local function stat(k,n) local r=M.root(); r.stats[k]=(r.stats[k] or 0)+(n or 1) end
local function remember(action, detail)
  local r=M.root(); r.recent[#r.recent+1]={tick=now(), action=tostring(action or "event"), detail=tostring(detail or "")}
  while #r.recent > 48 do table.remove(r.recent,1) end
end

local function surface_key(surface)
  if not surface then return "nil" end
  return tostring(surface.index or surface.name or "surface")
end

function M.dirty_region_near_pair(pair, radius, since_tick)
  if not (valid_pair(pair) and pair.station and pair.station.valid) then return false end
  local econ = storage and storage.tech_priests and storage.tech_priests.efficiency_economy_0569 or nil
  local dirty = econ and econ.dirty_regions or nil
  if type(dirty) ~= "table" then return false end
  local station = pair.station
  local pos = station.position or {x=0,y=0}
  local cell_radius = math.ceil((tonumber(radius or pair.radius or 32) or 32) / 32) + M.dirty_cell_radius_padding
  local cx, cy = math.floor((pos.x or 0) / 32), math.floor((pos.y or 0) / 32)
  local sk = surface_key(station.surface)
  local since = tonumber(since_tick or 0) or 0
  for dx=-cell_radius,cell_radius do
    for dy=-cell_radius,cell_radius do
      local rec = dirty[sk..":"..tostring(cx+dx)..":"..tostring(cy+dy)]
      if type(rec)=="table" and (tonumber(rec.last_tick or 0) or 0) >= since then
        stat("dirty_region_hits")
        return true
      end
    end
  end
  return false
end

local function negative_key(pair, wanted)
  return safe(station_unit(pair)) .. ":" .. tostring(wanted or "nil")
end

local function wrap_resource_doctrine()
  local ok, Doctrine = pcall(require, "scripts.core.resource_doctrine")
  if not (ok and Doctrine and type(Doctrine.find_fallback_source)=="function") or Doctrine.efficiency_economy_0570_wrapped then return false end
  Doctrine.efficiency_economy_0570_wrapped = true
  Doctrine.TECH_PRIESTS_0570_PRE_FIND_FALLBACK_SOURCE = Doctrine.find_fallback_source
  Doctrine.find_fallback_source = function(pair, wanted, recipe, ...)
    local r=M.root()
    if r.enabled ~= false and r.negative_cache_enabled ~= false and valid_pair(pair) and wanted then
      local key = negative_key(pair, wanted)
      local until_tick = tonumber(r.negative_until[key] or 0) or 0
      if until_tick > now() and not M.dirty_region_near_pair(pair, pair.radius or 32, until_tick - M.negative_source_cooldown_ticks) then
        stat("negative_source_skipped")
        metric("negative_cache_skips", 1)
        pair.last_source_scan_skipped_0570 = { tick=now(), item=tostring(wanted), until_tick=until_tick }
        return nil
      end
      local result = Doctrine.TECH_PRIESTS_0570_PRE_FIND_FALLBACK_SOURCE(pair, wanted, recipe, ...)
      if result then
        r.negative_until[key] = nil
        stat("negative_source_cleared")
      else
        r.negative_until[key] = now() + M.negative_source_cooldown_ticks + ((tonumber(station_unit(pair) or 0) or 0) % 120)
        pair.last_negative_source_scan_0570 = { tick=now(), item=tostring(wanted), until_tick=r.negative_until[key] }
        stat("negative_source_recorded")
      end
      return result
    end
    return Doctrine.TECH_PRIESTS_0570_PRE_FIND_FALLBACK_SOURCE(pair, wanted, recipe, ...)
  end
  remember("resource-doctrine-negative-cache", "cooldown="..safe(M.negative_source_cooldown_ticks))
  return true
end


function M.clear_near_entity(entity, reason)
  -- Clears existing negative-source cooldowns for pairs near a world event.
  -- This is a leaf helper for event-driven wakeups. It does not create a new
  -- negative cache and does not choose or execute work.
  if not valid(entity) then return 0 end
  local r = M.root()
  if r.enabled == false or r.negative_cache_enabled == false then return 0 end
  local pair_map_table = storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
  local affected = {}
  local pos = entity.position or { x = 0, y = 0 }
  local radius = 128
  local r2 = radius * radius
  for _, pair in pairs(pair_map_table) do
    if valid_pair(pair) and pair.station.surface == entity.surface and (not entity.force or not pair.station.force or pair.station.force.name == entity.force.name) then
      local sp = pair.station.position or { x = 0, y = 0 }
      local dx, dy = (sp.x or 0) - (pos.x or 0), (sp.y or 0) - (pos.y or 0)
      if dx * dx + dy * dy <= r2 then affected[safe(station_unit(pair)) .. ":"] = true end
    end
  end
  local removed = 0
  for key in pairs(r.negative_until or {}) do
    for prefix in pairs(affected) do
      if tostring(key):sub(1, #prefix) == prefix then
        r.negative_until[key] = nil
        removed = removed + 1
        break
      end
    end
  end
  if removed > 0 then
    stat("negative_source_event_cleared", removed)
    metric("negative_cache_clears_from_event", removed)
    remember("negative-clear-near-entity", tostring(reason or "event") .. " removed=" .. safe(removed))
  end
  return removed
end

function M.service()
  local r=M.root()
  local removed = 0
  for k,until_tick in pairs(r.negative_until or {}) do
    if type(until_tick) ~= "number" or until_tick < now() - M.negative_cache_keep_ticks then
      r.negative_until[k] = nil; removed = removed + 1
    end
  end
  if removed > 0 then stat("negative_cache_pruned", removed) end
end

local function install_command()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-efficiency-economy-0570") end end)
  commands.add_command("tp-efficiency-economy-0570", "Tech Priests 0.1.570 dirty-aware scan economy. Params: on/off/negative-on/negative-off/status", function(event)
    local player = event and event.player_index and game and game.get_player(event.player_index) or nil
    local param = lower(event and event.parameter or "status")
    local r=M.root()
    if param=="on" then r.enabled=true elseif param=="off" then r.enabled=false
    elseif param=="negative-on" then r.negative_cache_enabled=true elseif param=="negative-off" then r.negative_cache_enabled=false end
    local n=0; for _ in pairs(r.negative_until or {}) do n=n+1 end
    local msg = "[tp-efficiency-economy-0570] enabled="..safe(r.enabled)
      .." negative_cache="..safe(r.negative_cache_enabled).." negative_entries="..safe(n)
      .." skipped="..safe(r.stats.negative_source_skipped or 0)
      .." recorded="..safe(r.stats.negative_source_recorded or 0)
      .." dirty_hits="..safe(r.stats.dirty_region_hits or 0)
    if player and player.valid then player.print(msg) elseif game and game.print then game.print(msg) end
  end)
end

function M.install()
  M.root()
  _G.TechPriestsEfficiencyEconomy0570 = M
  _G.tech_priests_efficiency_0570_dirty_near_pair = function(pair, radius, since_tick) return M.dirty_region_near_pair(pair, radius, since_tick) end
  wrap_resource_doctrine()
  local R = rawget(_G,"TechPriestsRuntimeEventRegistry")
  if not R then pcall(function() R=require("scripts.core.runtime_event_registry") end) end
  if R and R.on_nth_tick then
    R.on_nth_tick(M.negative_cache_prune_ticks, function() M.service() end, { owner="efficiency_economy_0570", category="economy", note="prune resource negative-result cooldowns" })
  elseif script and script.on_nth_tick then
    script.on_nth_tick(M.negative_cache_prune_ticks, function() M.service() end)
  end
  install_command()
  if log then log("[Tech-Priests 0.1.570] dirty-aware scan economy installed; resource doctrine negative-result cooldowns and station-catalog clean reuse helper enabled") end
  return true
end

return M
