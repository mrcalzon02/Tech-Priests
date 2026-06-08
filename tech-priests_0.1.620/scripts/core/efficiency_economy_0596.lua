-- scripts/core/efficiency_economy_0596.lua
-- Tech Priests 0.1.596
--
-- Early passive-service austerity gate.  This module is intentionally required
-- at the very top of control.lua, before legacy fragments and runtime modules
-- register script.on_nth_tick handlers.  It wraps raw nth-tick registrations so
-- old direct handlers cannot run in a new game before any Tech-Priest runtime
-- entity exists.  The actual wake/sleep authority remains the 0.1.595 dormant
-- runtime gate when available; this file only catches legacy direct handlers
-- that bypass the runtime_event_registry.

local M = {}
M.version = "0.1.596"
M.storage_key = "efficiency_economy_0596"

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key]
  if type(r) ~= "table" then
    r = { version = M.version, enabled = true, wrapped = 0, skipped = 0, ran = 0, cleared = 0 }
    storage.tech_priests[M.storage_key] = r
  end
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  return r
end

local function has_runtime_entities_fallback()
  local tp = storage and storage.tech_priests
  if type(tp) ~= "table" then return false end
  local maps = { "pairs_by_station", "pairs_by_priest", "stations_by_unit", "priests_by_unit", "conclave_centers", "stone_caches", "consecration_targets" }
  for _, key in ipairs(maps) do
    local t = tp[key]
    if type(t) == "table" then
      for _, v in pairs(t) do
        if valid(v) then return true end
        if type(v) == "table" and (valid(v.entity) or valid(v.station) or valid(v.priest)) then return true end
      end
    end
  end
  return false
end

local function runtime_active_for_tick(tick, event)
  local r = root()
  if r.enabled == false then return true end
  if _G and type(_G.tech_priests_should_run_nth_tick_0595) == "function" then
    local ok, allowed = pcall(_G.tech_priests_should_run_nth_tick_0595, tonumber(tick) or tick, nil, event)
    if ok then return allowed ~= false end
  end
  return has_runtime_entities_fallback()
end

local function wrap_handler(tick, handler)
  if type(handler) ~= "function" then return handler end
  local r = root()
  r.wrapped = (r.wrapped or 0) + 1
  return function(event)
    local rr = root()
    if runtime_active_for_tick(tick, event) then
      rr.ran = (rr.ran or 0) + 1
      return handler(event)
    end
    rr.skipped = (rr.skipped or 0) + 1
    return nil
  end
end

function M.install_early_hook()
  if not (script and script.on_nth_tick) then return false end
  if rawget(_G, "TECH_PRIESTS_0596_RAW_NTH_TICK_HOOKED") then return true end
  _G.TECH_PRIESTS_0596_RAW_NTH_TICK_HOOKED = true
  local original = script.on_nth_tick
  _G.tech_priests_original_on_nth_tick_0596 = original
  script.on_nth_tick = function(tick, handler)
    if handler == nil then
      local r = root(); r.cleared = (r.cleared or 0) + 1
      return original(tick, nil)
    end
    return original(tick, wrap_handler(tick, handler))
  end
  return true
end

function M.commands()
  if not commands then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-efficiency-economy-0596") end end)
  commands.add_command("tp-efficiency-economy-0596", "Report Tech Priests early passive-service austerity gate.", function(cmd)
    local r = root()
    local player = cmd and cmd.player_index and game and game.get_player(cmd.player_index) or nil
    local line = "[Tech-Priests 0.1.596] early-nth-gate enabled=" .. tostring(r.enabled)
      .. " wrapped=" .. tostring(r.wrapped or 0)
      .. " ran=" .. tostring(r.ran or 0)
      .. " skipped=" .. tostring(r.skipped or 0)
      .. " cleared=" .. tostring(r.cleared or 0)
      .. " tick=" .. tostring(now())
    if player and player.valid then player.print(line) elseif log then log(line) end
  end)
end

function M.install()
  root()
  M.commands()
  return true
end

return M
