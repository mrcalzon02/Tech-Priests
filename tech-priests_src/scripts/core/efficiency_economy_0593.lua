-- 0.1.593: hard runtime performance firewall.
-- This is not a new behavior controller. It is a guard around legacy debug
-- output and the oldest direct-acquisition pathing loop, which the perf logs
-- showed still bypassing later economy governors.

local M = {}
M.version = "0.1.593"
M.storage_key = "efficiency_economy_0593"

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok,out=pcall(function() return tostring(v) end); return ok and out or "?" end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or {
    version = M.version,
    stats = {},
    direct_target_cache = {},
    direct_move_cache = {},
    log_suppressed = 0,
    file_suppressed = 0,
    cache_hits = 0,
    movement_reissues_held = 0,
    cache_pruned = 0,
    next_prune = 0,
  }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  r.stats = r.stats or {}
  r.direct_target_cache = r.direct_target_cache or {}
  r.direct_move_cache = r.direct_move_cache or {}
  return r
end

local function stat(k,n)
  local r = root()
  r.stats[k] = (r.stats[k] or 0) + (n or 1)
end

local function setting_bool(name, fallback)
  local ok, value = pcall(function()
    local s = settings and settings.global and settings.global[name]
    if s ~= nil then return s.value end
    return nil
  end)
  if ok and value ~= nil then return value == true end
  return fallback == true
end

local function diagnostics_enabled()
  return setting_bool("tech-priests-enable-emergency-diagnostics", false)
      or setting_bool("tech-priests-enable-full-priority-diagnostics", false)
end

local function message_is_critical(msg)
  msg = tostring(msg or "")
  local l = string.lower(msg)
  if l:find("failed to install", 1, true) then return true end
  if l:find("runtime error", 1, true) then return true end
  if l:find("script error", 1, true) then return true end
  if l:find("luaentity api call", 1, true) then return true end
  if l:find("invalid", 1, true) and (l:find("prototype", 1, true) or l:find("entity", 1, true)) then return true end
  if l:find("crash", 1, true) then return true end
  return false
end

local function is_tech_priest_runtime_log(msg)
  msg = tostring(msg or "")
  if msg:find("[Tech-Priests", 1, true) then return true end
  if msg:find("PAIR-DUMP-0468", 1, true) then return true end
  if msg:find("heartbeat:", 1, true) then return true end
  if msg:find("assignment worker active:", 1, true) then return true end
  if msg:find("orders refreshed", 1, true) then return true end
  if msg:find("direct gather target", 1, true) then return true end
  if msg:find("direct-target-rejected", 1, true) then return true end
  if msg:find("legacy-direct-blocked", 1, true) then return true end
  if msg:find("physical-direct-travel", 1, true) then return true end
  if msg:find("priority-stack ", 1, true) then return true end
  return false
end

local function install_log_firewall()
  if rawget(_G, "TECH_PRIESTS_0593_PRE_LOG") or type(log) ~= "function" then return false end
  local prev = log
  _G.TECH_PRIESTS_0593_PRE_LOG = prev
  _G.log = function(message)
    local msg = tostring(message or "")
    if not diagnostics_enabled() and is_tech_priest_runtime_log(msg) and not message_is_critical(msg) then
      local r = root()
      r.log_suppressed = (r.log_suppressed or 0) + 1
      stat("normal_runtime_log_suppressed")
      return
    end
    return prev(message)
  end
  return true
end

local function install_0264_firewall()
  if type(_G.tech_priests_0264_log) == "function" and not rawget(_G, "TECH_PRIESTS_0593_PRE_0264_LOG") then
    local prev = _G.tech_priests_0264_log
    _G.TECH_PRIESTS_0593_PRE_0264_LOG = prev
    _G.tech_priests_0264_log = function(text, also_file)
      local msg = tostring(text or "")
      if not diagnostics_enabled() and is_tech_priest_runtime_log(msg) and not message_is_critical(msg) then
        local r = root()
        r.log_suppressed = (r.log_suppressed or 0) + 1
        if also_file then r.file_suppressed = (r.file_suppressed or 0) + 1 end
        stat("normal_0264_log_suppressed")
        return false
      end
      if also_file and not diagnostics_enabled() then also_file = false end
      return prev(text, also_file)
    end
  end
  if type(_G.tech_priests_0264_try_write_file) == "function" and not rawget(_G, "TECH_PRIESTS_0593_PRE_0264_WRITE") then
    local prevw = _G.tech_priests_0264_try_write_file
    _G.TECH_PRIESTS_0593_PRE_0264_WRITE = prevw
    _G.tech_priests_0264_try_write_file = function(line)
      if not diagnostics_enabled() then
        local r = root()
        r.file_suppressed = (r.file_suppressed or 0) + 1
        stat("diagnostic_file_write_suppressed")
        return false
      end
      return prevw(line)
    end
  end
  return true
end

local function pos_key(pos)
  if not pos then return "nil" end
  return tostring(math.floor((pos.x or 0) * 10 + 0.5)) .. "," .. tostring(math.floor((pos.y or 0) * 10 + 0.5))
end

local function direct_cache_key(pair, output)
  local station = pair and pair.station
  if not valid(station) then return nil end
  return tostring(station.unit_number or "?") .. ":" .. tostring(station.surface and station.surface.index or "?") .. ":" .. tostring(output or "?")
end

local function install_direct_target_cache()
  if type(_G.tech_priests_0273_find_direct_target) == "function" and not rawget(_G, "TECH_PRIESTS_0593_PRE_FIND_DIRECT_TARGET") then
    local prev = _G.tech_priests_0273_find_direct_target
    _G.TECH_PRIESTS_0593_PRE_FIND_DIRECT_TARGET = prev
    _G.tech_priests_0273_find_direct_target = function(pair, output)
      local r = root()
      local key = direct_cache_key(pair, output)
      if key then
        local c = r.direct_target_cache[key]
        if c then
          local age = now() - (tonumber(c.tick) or 0)
          if c.nil_result and age < 600 then
            stat("direct_target_nil_cache_hit")
            r.cache_hits = (r.cache_hits or 0) + 1
            return nil
          end
          if c.result and age < 180 then
            local res = c.result
            if (not res.entity) or valid(res.entity) then
              stat("direct_target_cache_hit")
              r.cache_hits = (r.cache_hits or 0) + 1
              return res
            end
          end
        end
      end
      local res = prev(pair, output)
      if key then
        r.direct_target_cache[key] = { tick = now(), result = res, nil_result = res == nil }
      end
      return res
    end
  end
  return true
end

local function direct_move_key(pair, task)
  local cur = task and task.current
  if not (pair and valid(pair.station) and cur) then return nil, nil end
  local p = cur.position or (cur.entity and valid(cur.entity) and cur.entity.position)
  if not p then return nil, nil end
  local entity_key = cur.entity and valid(cur.entity) and tostring(cur.entity.unit_number or cur.entity.name or "?") or pos_key(p)
  return tostring(pair.station.unit_number or "?") .. ":" .. tostring(entity_key) .. ":" .. pos_key(p), p
end

local function install_direct_movement_reissue_guard()
  if type(_G.tech_priests_0273_service_direct_current) == "function" and not rawget(_G, "TECH_PRIESTS_0593_PRE_SERVICE_DIRECT_CURRENT") then
    local prev = _G.tech_priests_0273_service_direct_current
    _G.TECH_PRIESTS_0593_PRE_SERVICE_DIRECT_CURRENT = prev
    _G.tech_priests_0273_service_direct_current = function(pair, task)
      local cur = task and task.current
      if pair and valid(pair.priest) and cur and (cur.kind == "direct-mine-0273" or cur.kind == "direct-dirt-0273") then
        local p = cur.position or (cur.entity and valid(cur.entity) and cur.entity.position)
        if p then
          local dx = pair.priest.position.x - p.x
          local dy = pair.priest.position.y - p.y
          local pickup = rawget(_G, "EMERGENCY_CRAFT_PICKUP_DISTANCE_SQ") or 2.25
          if dx * dx + dy * dy > pickup then
            local key = direct_move_key(pair, task)
            if key then
              local r = root()
              local next_tick = tonumber(r.direct_move_cache[key] or 0) or 0
              if now() < next_tick then
                r.movement_reissues_held = (r.movement_reissues_held or 0) + 1
                stat("direct_movement_reissue_held")
                pair.mode = cur.kind == "direct-dirt-0273" and "emergency-dirt-scraping" or "emergency-gathering"
                return true
              end
              r.direct_move_cache[key] = now() + 90
            end
          end
        end
      end
      return prev(pair, task)
    end
  end
  return true
end

local function prune()
  local r = root()
  if now() < (tonumber(r.next_prune) or 0) then return end
  r.next_prune = now() + 3600
  local removed = 0
  for k,c in pairs(r.direct_target_cache or {}) do
    if now() - (tonumber(c.tick) or 0) > 3600 or (c.result and c.result.entity and not valid(c.result.entity)) then
      r.direct_target_cache[k] = nil
      removed = removed + 1
    end
  end
  for k,t in pairs(r.direct_move_cache or {}) do
    if now() > (tonumber(t) or 0) + 600 then
      r.direct_move_cache[k] = nil
      removed = removed + 1
    end
  end
  if removed > 0 then
    r.cache_pruned = (r.cache_pruned or 0) + removed
    stat("cache_pruned", removed)
  end
end

local function install_tick()
  if not (script and script.on_nth_tick) or rawget(_G, "TECH_PRIESTS_0593_TICK_INSTALLED") then return false end
  _G.TECH_PRIESTS_0593_TICK_INSTALLED = true
  script.on_nth_tick(1200, function() prune() end)
  return true
end

local function install_command()
  if not (commands and commands.add_command) or rawget(_G, "TECH_PRIESTS_0593_COMMAND_INSTALLED") then return false end
  _G.TECH_PRIESTS_0593_COMMAND_INSTALLED = true
  local function add(name, help, fn)
    pcall(function() if commands.remove_command then commands.remove_command(name) end end)
    pcall(function()
      if TechPriestsDebugCommandRegistry and TechPriestsDebugCommandRegistry.add then
        TechPriestsDebugCommandRegistry.add(name, help, fn)
      else
        commands.add_command(name, help, fn)
      end
    end)
  end
  add("tp-efficiency-economy-0593", "Print Tech Priests 0.1.593 hard runtime performance firewall counters.", function(event)
    local p = event and event.player_index and game.get_player(event.player_index) or nil
    local r = root()
    local msg = "TP 0.1.593 performance firewall: log_suppressed=" .. safe(r.log_suppressed or 0)
      .. " file_suppressed=" .. safe(r.file_suppressed or 0)
      .. " direct_cache_hits=" .. safe(r.cache_hits or 0)
      .. " movement_reissues_held=" .. safe(r.movement_reissues_held or 0)
      .. " cache_pruned=" .. safe(r.cache_pruned or 0)
      .. " diagnostics=" .. tostring(diagnostics_enabled())
    if p and p.valid then p.print(msg) elseif game and game.print then game.print(msg) end
  end)
  return true
end

function M.install()
  root()
  install_log_firewall()
  install_0264_firewall()
  install_direct_target_cache()
  install_direct_movement_reissue_guard()
  install_tick()
  install_command()
  return true
end

return M
