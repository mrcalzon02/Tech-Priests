-- scripts/core/efficiency_economy_0594.lua
-- Tech Priests 0.1.594
--
-- Adaptive runtime route economy.  This module does not create work, choose
-- targets, move priests, mine, craft, repair, consecrate, or complete orders.
-- It wraps existing RuntimeEventRegistry nth-tick routes after registration and
-- lets non-critical service routes breathe under large priest counts.  The goal
-- is graceful megabase degradation: critical movement/combat/recovery/order work
-- keeps running, while diagnostics/visual/audio/passive GUI refreshes and other
-- low-value background routes skip deterministic pulses instead of all waking
-- together.

local M = {}
M.version = "0.1.594"
M.storage_key = "efficiency_economy_0594"

local function now() return game and game.tick or 0 end
local function safe(v) if v == nil then return "nil" end local ok,out=pcall(function() return tostring(v) end); return ok and out or "?" end
local function lower(v) return string.lower(tostring(v or "")) end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key]
  if type(r) ~= "table" then
    r = {
      version = M.version,
      enabled = true,
      wrapped = 0,
      skipped = {},
      ran = {},
      recent_pair_count = 0,
      recent_tier = "quiet",
      last_scan_tick = 0,
      next_rescan_tick = 0,
      route_keys = {},
    }
    storage.tech_priests[M.storage_key] = r
  end
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  r.skipped = r.skipped or {}
  r.ran = r.ran or {}
  r.route_keys = r.route_keys or {}
  return r
end

local function stat(tbl, key, n)
  local r = root()
  r[tbl] = r[tbl] or {}
  r[tbl][key] = (r[tbl][key] or 0) + (n or 1)
end

local function settings_bool(name, fallback)
  local ok, value = pcall(function()
    local s = settings and settings.global and settings.global[name]
    if s ~= nil then return s.value end
    return nil
  end)
  if ok and value ~= nil then return value == true end
  return fallback == true
end

local function diagnostics_enabled()
  return settings_bool("tech-priests-enable-emergency-diagnostics", false)
      or settings_bool("tech-priests-enable-full-priority-diagnostics", false)
end

local function pair_count(force_rescan)
  local r = root()
  if (not force_rescan) and now() < (tonumber(r.next_rescan_tick) or 0) then
    return tonumber(r.recent_pair_count or 0) or 0
  end
  local n = 0
  local map = storage and storage.tech_priests and storage.tech_priests.pairs_by_station or nil
  if type(map) == "table" then
    for _, pair in pairs(map) do
      if pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid then n = n + 1 end
    end
  end
  r.recent_pair_count = n
  r.last_scan_tick = now()
  r.next_rescan_tick = now() + 300
  if n >= 160 then r.recent_tier = "extreme"
  elseif n >= 80 then r.recent_tier = "heavy"
  elseif n >= 35 then r.recent_tier = "busy"
  else r.recent_tier = "quiet" end
  return n
end

local function category_multiplier(category, owner)
  category = lower(category)
  owner = lower(owner)
  local n = pair_count(false)
  local diag = diagnostics_enabled()

  -- Diagnostics are entirely suppressed in normal play.  If diagnostics are on,
  -- they still receive a multiplier so pair dumps cannot synchronize with every
  -- other background service in a large priest population.
  if category == "diagnostics" or owner:find("diagnostics", 1, true) or owner:find("pair_dump", 1, true) then
    if not diag then return 999999, "diagnostics-off" end
    if n >= 80 then return 8, "diagnostics-heavy" end
    return 3, "diagnostics" 
  end

  -- Player-facing but noncritical services: visual sugar, audio, status refresh,
  -- command cameras, hover panels.  These are allowed to get slightly stale
  -- before gameplay logic gets expensive.
  if category == "visuals" or category == "audio" or category == "gui" or owner:find("visual", 1, true) or owner:find("overhead", 1, true) or owner:find("sound", 1, true) or owner:find("voice", 1, true) or owner:find("chatter", 1, true) then
    if n >= 160 then return 8, "presentation-extreme" end
    if n >= 80 then return 5, "presentation-heavy" end
    if n >= 35 then return 3, "presentation-busy" end
    return 1, "presentation-quiet"
  end

  -- Logistics/inventory/scheduler background pulses should still run, but not
  -- all at once under a huge priest count.  Combat, movement, recovery, and
  -- lifecycle are handled below and are not throttled here.
  if category == "inventory" or category == "scheduler" or category == "crafting" or owner:find("order_queue", 1, true) or owner:find("planning", 1, true) or owner:find("reserve", 1, true) or owner:find("inventory", 1, true) then
    if n >= 160 then return 3, "background-extreme" end
    if n >= 80 then return 2, "background-heavy" end
    return 1, "background-quiet"
  end

  return 1, "critical-or-unknown"
end

local function is_critical(entry)
  local c = lower(entry and entry.category)
  local o = lower(entry and entry.owner)
  local text = c .. " " .. o
  if text:find("combat", 1, true) then return true end
  if text:find("movement", 1, true) then return true end
  if text:find("recovery", 1, true) then return true end
  if text:find("lifecycle", 1, true) then return true end
  if text:find("corridor", 1, true) then return true end
  if text:find("obstacle", 1, true) then return true end
  if text:find("dispatcher", 1, true) then return true end
  if text:find("arbiter", 1, true) then return true end
  return false
end

local function deterministic_bucket(event_tick, entry, mult)
  if mult <= 1 then return true end
  local key = tostring(entry.owner or "?") .. ":" .. tostring(entry.category or "?") .. ":" .. tostring(entry.tick or "?")
  local h = 0
  for i = 1, #key do h = (h + string.byte(key, i) * i) % 1000003 end
  return ((event_tick + h) % mult) == 0
end

local function wrap_entry(entry)
  if not entry or type(entry.handler) ~= "function" or entry.tech_priests_0594_wrapped then return false end
  if is_critical(entry) then return false end
  local prev = entry.handler
  entry.tech_priests_0594_wrapped = true
  entry.tech_priests_0594_prev_handler = prev
  entry.handler = function(event)
    local r = root()
    if r.enabled == false then return prev(event) end
    local mult, reason = category_multiplier(entry.category, entry.owner)
    local tick = (event and event.tick) or now()
    if mult > 1 and not deterministic_bucket(tick, entry, mult) then
      stat("skipped", reason or "skipped")
      return false
    end
    stat("ran", reason or "ran")
    return prev(event)
  end
  local r = root()
  r.wrapped = (r.wrapped or 0) + 1
  r.route_keys[#r.route_keys + 1] = tostring(entry.tick or "?") .. ":" .. tostring(entry.owner or "?") .. ":" .. tostring(entry.category or "?")
  return true
end

local function wrap_registry_routes()
  local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if type(R) ~= "table" then
    local ok, mod = pcall(require, "scripts.core.runtime_event_registry")
    if ok and type(mod) == "table" then R = mod end
  end
  if type(R) ~= "table" or type(R.nth_tick_routes) ~= "table" then return 0 end
  local count = 0
  for _, route in pairs(R.nth_tick_routes) do
    if type(route) == "table" then
      for _, entry in ipairs(route) do
        if wrap_entry(entry) then count = count + 1 end
      end
    end
  end
  return count
end

local function install_command()
  if not (commands and commands.add_command) or rawget(_G, "TECH_PRIESTS_0594_COMMAND_INSTALLED") then return false end
  _G.TECH_PRIESTS_0594_COMMAND_INSTALLED = true
  pcall(function() if commands.remove_command then commands.remove_command("tp-efficiency-economy-0594") end end)
  commands.add_command("tp-efficiency-economy-0594", "Tech Priests 0.1.594 adaptive route economy. Params: on/off/rescan/status", function(event)
    local player = event and event.player_index and game and game.get_player(event.player_index) or nil
    local param = lower(event and event.parameter or "status")
    local r = root()
    if param == "on" then r.enabled = true
    elseif param == "off" then r.enabled = false
    elseif param == "rescan" then r.next_rescan_tick = 0; pair_count(true); wrap_registry_routes() end
    local skipped = 0; for _,v in pairs(r.skipped or {}) do skipped = skipped + (tonumber(v) or 0) end
    local ran = 0; for _,v in pairs(r.ran or {}) do ran = ran + (tonumber(v) or 0) end
    local msg = "TP 0.1.594 adaptive route economy: enabled=" .. tostring(r.enabled)
      .. " pairs=" .. safe(pair_count(false)) .. " tier=" .. safe(r.recent_tier)
      .. " wrapped=" .. safe(r.wrapped or 0) .. " ran=" .. safe(ran) .. " skipped=" .. safe(skipped)
      .. " diagnostics=" .. tostring(diagnostics_enabled())
    if player and player.valid then player.print(msg) elseif game and game.print then game.print(msg) end
  end)
  return true
end

local function install_rescan_tick()
  if not (script and script.on_nth_tick) or rawget(_G, "TECH_PRIESTS_0594_RESCAN_TICK") then return false end
  _G.TECH_PRIESTS_0594_RESCAN_TICK = true
  script.on_nth_tick(1800, function()
    pair_count(true)
    wrap_registry_routes()
  end)
  return true
end

function M.install()
  root()
  pair_count(true)
  wrap_registry_routes()
  install_rescan_tick()
  install_command()
  return true
end

return M
