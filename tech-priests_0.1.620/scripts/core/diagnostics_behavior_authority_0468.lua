-- scripts/core/diagnostics_behavior_authority_0468.lua
-- Tech Priests 0.1.468
-- Three narrow live-test fixes:
--   1. Keep the docked Known Resources refresh inside the Known Resources tab.
--      (The primary patch is in station_work_inventory.lua; this module stays as
--      the late authority marker.)
--   2. Add periodic pair-state snapshots to the existing emergency diagnostics
--      log, controlled by a runtime setting and commands.
--   3. Stop stale combat/fallback laser logic from treating neutral scenery
--      boulders/rocks as hostile red-beam targets. Acquisition may still quarry
--      valid neutral rock/tree/resource targets, but it is normalized out of
--      combat-looking state and tinted as acquisition, not combat.

local M = {}
M.version = "0.1.468"
M.storage_key = "diagnostics_behavior_authority_0468"
M.default_interval_ticks = 7200
M.min_interval_ticks = 600
M.file = "tech-priests-emergency-diagnostics.log"

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok, out = pcall(function() return tostring(v) end); return ok and out or "?" end

local function ensure_root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or { version = M.version }
  local root = storage.tech_priests[M.storage_key]
  root.version = M.version
  if root.enabled == nil then root.enabled = nil end -- nil means use runtime setting
  root.next_tick = root.next_tick or 0
  root.stats = root.stats or {}
  return root
end

local function setting_value(name, fallback)
  local ok, value = pcall(function()
    local s = settings and settings.global and settings.global[name]
    if s ~= nil then return s.value end
    return nil
  end)
  if ok and value ~= nil then return value end
  return fallback
end

local function diagnostics_enabled()
  local root = ensure_root()
  if root.enabled ~= nil then return root.enabled == true end
  local setting = setting_value("tech-priests-enable-emergency-diagnostics", nil)
  if setting ~= nil then return setting == true end
  -- Existing debug setting remains the fallback authority in older saves.
  return setting_value("tech-priests-enable-full-priority-diagnostics", true) == true
end

local function diagnostics_interval()
  local v = tonumber(setting_value("tech-priests-emergency-diagnostics-interval-ticks", nil))
  if not v then v = tonumber(setting_value("tech-priests-priority-diagnostics-interval-ticks", M.default_interval_ticks)) end
  return math.max(M.min_interval_ticks, tonumber(v) or M.default_interval_ticks)
end

local function write_line(text)
  if tech_priests_0264_log then
    local ok = pcall(function() tech_priests_0264_log("PAIR-DUMP-0468 " .. tostring(text or ""), true) end)
    if ok then return true end
  end
  local line = "[Tech-Priests " .. M.version .. "][tick " .. safe(now()) .. "] PAIR-DUMP-0468 " .. tostring(text or "") .. "\n"
  if helpers then
    local ok_get, writer = pcall(function() return helpers.write_file end)
    if ok_get and type(writer) == "function" then
      local ok_write = pcall(function() writer(M.file, line, true) end)
      if ok_write then return true end
    end
  end
  if log then pcall(function() log(line) end) end
  return false
end

local function pair_map()
  return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
end

local function ent_label(e)
  if not valid(e) then return "invalid" end
  local pos = e.position or { x = 0, y = 0 }
  return safe(e.name) .. "#" .. safe(e.unit_number) .. "@" .. string.format("%.1f,%.1f", tonumber(pos.x) or 0, tonumber(pos.y) or 0)
end

local function pos_text(pos)
  if type(pos) ~= "table" then return safe(pos) end
  return string.format("%.1f,%.1f", tonumber(pos.x) or 0, tonumber(pos.y) or 0)
end

local function task_name(pair)
  local task = pair and (pair.active_task or pair.active_task_0285) or nil
  if type(task) == "table" then return safe(task.kind or task.type or task.name) end
  return safe(task or (pair and pair.current_task) or nil)
end

local function entity_type(e)
  if not valid(e) then return "nil" end
  return safe(e.type) .. ":" .. safe(e.name) .. "#" .. safe(e.unit_number) .. ":force=" .. safe(e.force and e.force.name)
end

local function combatish_mode(pair)
  local mode = string.lower(safe(pair and (pair.visual_state_0276 or pair.mode or pair.task_phase_0276 or "")))
  if mode:find("combat", 1, true) then return true end
  if mode:find("defending", 1, true) then return true end
  if mode:find("laser%-fallback") then return true end
  return false
end

local function pair_from_priest(priest)
  if not valid(priest) then return nil end
  if storage and storage.tech_priests and storage.tech_priests.pairs_by_priest then
    local pair = storage.tech_priests.pairs_by_priest[priest.unit_number]
    if pair then return pair end
  end
  if _G.find_pair_for_entity then local ok, pair = pcall(_G.find_pair_for_entity, priest); if ok then return pair end end
  return nil
end

local function neutral_scenery(target)
  if not valid(target) then return false end
  local typ = target.type
  if typ ~= "simple-entity" and typ ~= "rock" and typ ~= "tree" and typ ~= "resource" then return false end
  local force_name = target.force and target.force.name or nil
  return force_name == nil or force_name == "neutral"
end

local function hostile_target(pair, target)
  if not (pair and valid(target)) then return false end
  local Mutex = rawget(_G, "TECH_PRIESTS_BEHAVIOR_MUTEX_0466")
  if Mutex and Mutex.is_hostile then local ok, hostile = pcall(Mutex.is_hostile, pair, target); if ok then return hostile == true end end
  local CombatSafety = nil
  pcall(function() CombatSafety = require("scripts.core.combat_safety") end)
  if CombatSafety and CombatSafety.is_valid_hostile_target then
    local ok, hostile = pcall(CombatSafety.is_valid_hostile_target, pair.priest or pair.station or pair, target)
    if ok then return hostile == true end
  end
  local owner_force = pair.priest and pair.priest.valid and pair.priest.force or pair.station and pair.station.valid and pair.station.force or nil
  local target_force = target.force
  if not (owner_force and target_force) then return false end
  if owner_force == target_force or target_force.name == "neutral" then return false end
  local hostile = false
  pcall(function() if owner_force.is_enemy then hostile = owner_force.is_enemy(target_force) end end)
  return hostile == true
end

local function clear_stale_combat(pair, target, reason)
  if not pair then return end
  if pair.combat_target == target then pair.combat_target = nil end
  if pair.target == target then pair.target = nil end
  if pair.proxy and pair.proxy.valid then pcall(function() pair.proxy.shooting_target = nil end) end
  pair.last_0468_stale_combat_clear = { tick = now(), target = entity_type(target), reason = reason or "stale-neutral-combat-target" }
end

function M.pair_dump_lines()
  local rows = {}
  local total, valid_stations, valid_priests = 0, 0, 0
  for key, pair in pairs(pair_map()) do
    total = total + 1
    if pair and valid(pair.station) then valid_stations = valid_stations + 1 end
    if pair and valid(pair.priest) then valid_priests = valid_priests + 1 end
    rows[#rows + 1] = { key = tostring(key), pair = pair }
  end
  table.sort(rows, function(a, b) return tostring(a.key) < tostring(b.key) end)

  local lines = {}
  lines[#lines + 1] = "BEGIN pair_count=" .. safe(total) .. " valid_stations=" .. safe(valid_stations) .. " valid_priests=" .. safe(valid_priests)
  for _, row in ipairs(rows) do
    local pair = row.pair
    local target = pair and ((pair.combat_target and pair.combat_target.valid and pair.combat_target) or (pair.target and pair.target.valid and pair.target)) or nil
    local move_target = pair and (pair.movement_target or pair.move_target or pair.target_position or pair.destination) or nil
    lines[#lines + 1] = "pair[" .. row.key .. "] station=" .. ent_label(pair and pair.station)
      .. " priest=" .. ent_label(pair and pair.priest)
      .. " tier=" .. safe(pair and pair.tier)
      .. " rank=" .. safe(pair and pair.rank)
      .. " mode=" .. safe(pair and pair.mode)
      .. " task=" .. task_name(pair)
      .. " movement_mode=" .. safe(pair and pair.movement_mode)
      .. " move_target=" .. pos_text(move_target)
      .. " combat_target=" .. entity_type(target)
      .. " hostile=" .. safe(target and hostile_target(pair, target) or false)
      .. " paused_by_combat=" .. safe(pair and pair.acquisition_paused_by_combat_0466 and pair.acquisition_paused_by_combat_0466.reason)
  end
  lines[#lines + 1] = "END"
  return lines
end

function M.write_pair_dump(reason, force)
  if (not force) and not diagnostics_enabled() then return false, "disabled" end
  local root = ensure_root()
  write_line("reason=" .. safe(reason or "periodic") .. " interval=" .. safe(diagnostics_interval()))
  for _, line in ipairs(M.pair_dump_lines()) do write_line(line) end
  root.stats.dumps_written = (root.stats.dumps_written or 0) + 1
  root.stats.last_dump_tick = now()
  return true
end

function M.tick()
  local root = ensure_root()
  if not diagnostics_enabled() then return end
  local tick = now()
  if tick < (root.next_tick or 0) then return end
  root.next_tick = tick + diagnostics_interval()
  M.write_pair_dump("periodic")
end

function M.wrap_laser()
  if not _G.tech_priests_0312_fire_laser or _G.TECH_PRIESTS_0468_PRE_0312_FIRE_LASER then return end
  _G.TECH_PRIESTS_0468_PRE_0312_FIRE_LASER = _G.tech_priests_0312_fire_laser
  _G.tech_priests_0312_fire_laser = function(priest, target, damage, reason, color)
    local pair = pair_from_priest(priest)
    local reason_text = tostring(reason or "")
    local direct = reason_text:find("direct%-mining") or reason_text:find("direct%-dirt") or reason_text:find("legacy%-direct")
    if pair and target and target.valid and neutral_scenery(target) then
      if not direct then
        clear_stale_combat(pair, target, "blocked-red-fallback-neutral-scenery:" .. reason_text)
        local root = ensure_root()
        root.stats.neutral_red_lasers_blocked = (root.stats.neutral_red_lasers_blocked or 0) + 1
        if log and now() >= (pair.next_0468_neutral_laser_log or 0) then
          pair.next_0468_neutral_laser_log = now() + 240
          log("[Tech-Priests 0.1.468] blocked red fallback laser against neutral scenery target=" .. entity_type(target) .. " mode=" .. safe(pair.mode) .. " reason=" .. reason_text)
        end
        return false
      end
      -- If acquisition is valid but the visible state is still combat-looking,
      -- repair the state label before drawing the acquisition beam. This keeps
      -- boulder/rock quarrying from presenting as combat.
      if combatish_mode(pair) and not hostile_target(pair, target) then
        clear_stale_combat(pair, target, "direct-acquisition-cleared-combat-label")
        pair.mode = reason_text:find("direct%-dirt") and "emergency-dirt-scraping" or "emergency-gathering"
      end
      color = { r = 1.0, g = 0.56, b = 0.05, a = 0.70 }
    end
    return _G.TECH_PRIESTS_0468_PRE_0312_FIRE_LASER(priest, target, damage, reason, color)
  end
end


function M.wrap_emergency_diagnostics_writer()
  if _G.tech_priests_0264_log and not _G.TECH_PRIESTS_0468_PRE_0264_LOG then
    _G.TECH_PRIESTS_0468_PRE_0264_LOG = _G.tech_priests_0264_log
    _G.tech_priests_0264_log = function(text, also_file)
      if also_file and not diagnostics_enabled() then also_file = false end
      return _G.TECH_PRIESTS_0468_PRE_0264_LOG(text, also_file)
    end
  end
  if _G.tech_priests_0264_try_write_file and not _G.TECH_PRIESTS_0468_PRE_0264_TRY_WRITE_FILE then
    _G.TECH_PRIESTS_0468_PRE_0264_TRY_WRITE_FILE = _G.tech_priests_0264_try_write_file
    _G.tech_priests_0264_try_write_file = function(line)
      if not diagnostics_enabled() then return false end
      return _G.TECH_PRIESTS_0468_PRE_0264_TRY_WRITE_FILE(line)
    end
  end
end

function M.install_commands()
  if not (commands and commands.add_command) then return end
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
  local function handler(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local param = string.lower(tostring(event and event.parameter or "status"))
    local root = ensure_root()
    if param == "on" or param == "enable" then root.enabled = true
    elseif param == "off" or param == "disable" then root.enabled = false
    elseif param == "setting" or param == "settings" or param == "auto" then root.enabled = nil
    elseif param == "once" or param == "write" or param == "dump" then local old = root.enabled; root.enabled = true; M.write_pair_dump("manual-command", true); root.enabled = old end
    if player and player.valid then
      player.print("[tp-emergency-diagnostics-0468] enabled=" .. safe(diagnostics_enabled())
        .. " override=" .. safe(root.enabled)
        .. " interval=" .. safe(diagnostics_interval())
        .. " next_tick=" .. safe(root.next_tick)
        .. " dumps=" .. safe(root.stats and root.stats.dumps_written))
    end
  end
  add("tp-emergency-diagnostics-0468", "Tech Priests 0.1.468: emergency diagnostics on/off/status/once/auto, including periodic pair dump snapshots.", handler)
  add("tp-emergency-diagnostics", "Tech Priests: emergency diagnostics on/off/status/once/auto.", handler)
end

function M.install()
  ensure_root()
  M.wrap_emergency_diagnostics_writer()
  M.wrap_laser()
  M.install_commands()
  if TechPriestsRuntimeEventRegistry and TechPriestsRuntimeEventRegistry.on_nth_tick then
    TechPriestsRuntimeEventRegistry.on_nth_tick(601, function() M.tick() end, { owner = "diagnostics_behavior_authority_0468", category = "diagnostics" })
  elseif script and script.on_nth_tick then
    script.on_nth_tick(601, function() M.tick() end)
  end
  _G.TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468 = M
  if log then log("[Tech-Priests 0.1.468] diagnostics pair dump + boulder fallback laser guard installed") end
  return true
end

return M
