-- scripts/core/efficiency_economy_0578.lua
-- Tech Priests 0.1.578
--
-- Catalog/indexing economy pass. This is not a behavior controller. It exposes
-- diagnostics for the 0.1.578 station catalog prototype caches and adds a small
-- housekeeping pulse so future index work has a stable place to live. The heavy
-- lifting for this pass is in station_catalog.lua: prototype inventory support
-- and mineable products are cached by entity type/name instead of rediscovered
-- for every entity during every station catalog sweep.

local M = {}
M.version = "0.1.578"
M.storage_key = "efficiency_economy_0578"
M.housekeeping_interval = 60 * 20

local function safe(v) if v == nil then return "nil" end local ok,out=pcall(function() return tostring(v) end); return ok and out or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function now() return game and game.tick or 0 end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key]
  if type(r) ~= "table" then
    r = { version = M.version, enabled = true, stats = {}, last_housekeeping_tick = 0 }
    storage.tech_priests[M.storage_key] = r
  end
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  r.stats = r.stats or {}
  return r
end

local function cache_counts()
  local fn = rawget(_G, "tech_priests_0578_station_catalog_cache_counts")
  if type(fn) == "function" then
    local ok, inv, mine = pcall(fn)
    if ok then return tonumber(inv or 0) or 0, tonumber(mine or 0) or 0 end
  end
  return 0, 0
end

function M.housekeeping()
  local r = M.root()
  if r.enabled == false then return end
  r.last_housekeeping_tick = now()
  local inv, mine = cache_counts()
  r.stats.inventory_prototype_cache_entries = inv
  r.stats.mineable_prototype_cache_entries = mine
  r.stats.housekeeping_runs = (r.stats.housekeeping_runs or 0) + 1
end

local function install_command()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-efficiency-economy-0578") end end)
  commands.add_command("tp-efficiency-economy-0578", "Tech Priests 0.1.578 catalog prototype-cache economy. Params: on/off/status", function(event)
    local player = event and event.player_index and game and game.get_player(event.player_index) or nil
    local p = lower(event and event.parameter or "status")
    local r = M.root()
    if p == "on" then r.enabled = true elseif p == "off" then r.enabled = false end
    M.housekeeping()
    local inv, mine = cache_counts()
    local msg = "[tp-efficiency-economy-0578] enabled="..safe(r.enabled).." inventory_proto_cache="..safe(inv).." mineable_proto_cache="..safe(mine).." housekeeping="..safe(r.stats.housekeeping_runs or 0)
    if player and player.valid then player.print(msg) elseif game and game.print then game.print(msg) end
  end)
end

function M.install()
  local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not R then pcall(function() R = require("scripts.core.runtime_event_registry") end) end
  if not (R and type(R.on_nth_tick)=="function") then return false end
  local route_options = { owner="efficiency_economy_0578", route="prototype-cache-housekeeping", category="economy", priority="last", note="record catalog prototype-cache counters" }
  local route = R.on_nth_tick(M.housekeeping_interval, function() M.housekeeping() end, route_options)
  if not route then return false end
  local ok, err = pcall(function()
    M.root()
    install_command()
    _G.TechPriestsEfficiencyEconomy0578 = M
  end)
  if not ok then
    pcall(R.on_nth_tick, M.housekeeping_interval, nil, route_options)
    if log then log("[Tech-Priests 0.1.578] catalog prototype-cache economy install rolled back: "..tostring(err)) end
    return false
  end
  if log then log("[Tech-Priests 0.1.578] registry-owned catalog prototype-cache economy installed") end
  return true
end

return M
