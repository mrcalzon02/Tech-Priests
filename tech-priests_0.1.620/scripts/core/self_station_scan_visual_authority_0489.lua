-- scripts/core/self_station_scan_visual_authority_0489.lua
-- Tech Priests 0.1.489
--
-- Final hard gate for two related visual/behavior faults:
--   1. Cogitator radius/interstation/priest-link overlays are contextual tools,
--      not permanent decoration. They must decay/clear once the player stops
--      selecting/hovering a station/priest or holding a Cogitator Station.
--   2. A Tech-Priest must never scan or laser its own paired station. The home
--      Cogitator's inventory/state is already known to its priest; drawing scan
--      beams at the home station created false task/action signals.

local M = {}
M.version = "0.1.489"
M.storage_key = "self_station_scan_visual_authority_0489"
M.tick_interval = 17
M.context_ttl = 90
M.context_redraw = 60

local previous_emergency_scan = nil
local previous_logistic_scan = nil
local previous_fire_laser = nil
local previous_candidate_filter = nil

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok,s = pcall(function() return tostring(v) end); return ok and s or "?" end
local function lower(v) return string.lower(tostring(v or "")) end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or { version = M.version, enabled = true, stats = {} }
  local r = storage.tech_priests[M.storage_key]
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  r.stats = r.stats or {}
  return r
end

local function stat(k, d)
  local r = root()
  r.stats[k] = (r.stats[k] or 0) + (d or 1)
end

local function enabled() return root().enabled ~= false end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function priest_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_priest or {} end
local function valid_pair(pair) return type(pair) == "table" and valid(pair.station) and valid(pair.priest) end
local function pair_key(pair) return pair and valid(pair.station) and pair.station.unit_number or pair and pair.station_unit or "?" end

local function is_own_station(pair, entity)
  if not (valid_pair(pair) and valid(entity)) then return false end
  if entity == pair.station then return true end
  local su = pair.station_unit or pair.station.unit_number
  return su ~= nil and entity.unit_number ~= nil and su == entity.unit_number
end

local function pair_for_priest(priest)
  if not valid(priest) then return nil end
  return priest_map()[priest.unit_number]
end

local function destroy(obj)
  if not obj then return end
  pcall(function() if obj.valid == nil or obj.valid then obj.destroy() end end)
end

local function clear_beam_objects(pair)
  if not pair then return end
  destroy(pair.scan_line_render); pair.scan_line_render = nil
  destroy(pair.mining_beam_render); pair.mining_beam_render = nil
  destroy(pair.combat_laser_render); pair.combat_laser_render = nil
  local key = pair_key(pair)
  if storage and storage.tech_priests and key then
    local w = storage.tech_priests.tech_priests_work_visuals_0323
    if w and w.scan_lines then destroy(w.scan_lines[key]); w.scan_lines[key] = nil end
    if w and w.beams then destroy(w.beams[key]); w.beams[key] = nil end
  end
end

local function block_own_station(pair, target, reason)
  if not (enabled() and is_own_station(pair, target)) then return false end
  clear_beam_objects(pair)
  if pair.target == target then pair.target = nil end
  if pair.mining_target == target then pair.mining_target = nil end
  if pair.current_resource_target == target then pair.current_resource_target = nil end
  pair.self_station_scan_0489 = {
    tick = now(),
    reason = reason or "own-station-scan-blocked",
    station = pair.station and pair.station.unit_number or nil,
  }
  stat("own_station_scan_blocked")
  return true
end

local function candidate_entity(v)
  if valid(v) then return v end
  if type(v) == "table" then
    if valid(v.entity) then return v.entity end
    if valid(v.target) then return v.target end
    if valid(v.source) then return v.source end
    if valid(v.current and v.current.entity) then return v.current.entity end
  end
  return nil
end

function M.service_pair(pair)
  if not (enabled() and valid_pair(pair)) then return false end
  local changed = false

  -- Old surfaces sometimes leave the home station in pair.target/current scan
  -- slots. Remove those references and force the next executor pass to use the
  -- station inventory directly or choose an actual outside source/target.
  for _, field in ipairs({ "target", "mining_target", "current_resource_target" }) do
    if is_own_station(pair, pair[field]) then
      pair[field] = nil
      changed = true
    end
  end

  if pair.inventory_scan then
    local scan = pair.inventory_scan
    local current = candidate_entity(scan.current) or candidate_entity(scan.target) or candidate_entity(scan.source)
    if is_own_station(pair, current) then
      scan.current = nil
      scan.target = nil
      scan.source = nil
      scan.scan_due_tick = nil
      if type(_G.advance_logistic_inventory_scan) == "function" then
        pcall(_G.advance_logistic_inventory_scan, pair)
      end
      changed = true
      stat("inventory_home_station_skipped")
    end
  end

  if pair.emergency_craft then
    local craft = pair.emergency_craft
    local current = candidate_entity(craft.current) or candidate_entity(craft.target) or candidate_entity(craft.source)
    if is_own_station(pair, current) then
      craft.current = nil
      craft.target = nil
      craft.source = nil
      changed = true
      stat("emergency_home_station_skipped")
    end
  end

  if changed then
    clear_beam_objects(pair)
    pair.self_station_scan_0489 = pair.self_station_scan_0489 or {}
    pair.self_station_scan_0489.last_service_tick = now()
  end
  return changed
end

function M.tick_all()
  if not enabled() then return end
  M.patch_visual_authority()
  for _, pair in pairs(pair_map()) do pcall(M.service_pair, pair) end
end

function M.patch_visual_authority()
  -- Harden the retained 0.1.474/0.1.487 visual authorities. Active overlays
  -- are stable long enough not to flicker, but short enough to decay if a clear
  -- event is missed. The actual no-context clear is still owned by 0.1.487.
  local vis = rawget(_G, "TECH_PRIESTS_ALT_WRIT_VISUAL_STABILITY_0474")
  if vis then
    vis.ttl = M.context_ttl
    vis.redraw_period = M.context_redraw
    vis.refresh_period = math.min(tonumber(vis.refresh_period or 20) or 20, 20)
  end
  local lease = rawget(_G, "TECH_PRIESTS_VISUAL_LEASE_CLEANUP_0487")
  if lease then
    lease.overlay_ttl = M.context_ttl
    lease.redraw_period = M.context_redraw
  end
end

function M.wrap_scan_lines()
  if type(_G.draw_emergency_craft_scan_line) == "function" and not previous_emergency_scan then
    previous_emergency_scan = _G.draw_emergency_craft_scan_line
    _G.draw_emergency_craft_scan_line = function(pair, target_entity)
      if block_own_station(pair, target_entity, "emergency-craft-scan-line") then return false end
      return previous_emergency_scan(pair, target_entity)
    end
  end

  if type(_G.draw_logistic_inventory_scan_line) == "function" and not previous_logistic_scan then
    previous_logistic_scan = _G.draw_logistic_inventory_scan_line
    _G.draw_logistic_inventory_scan_line = function(pair, target_entity)
      if block_own_station(pair, target_entity, "logistic-inventory-scan-line") then return false end
      return previous_logistic_scan(pair, target_entity)
    end
  end

  if type(_G.tech_priests_0312_fire_laser) == "function" and not previous_fire_laser then
    previous_fire_laser = _G.tech_priests_0312_fire_laser
    _G.tech_priests_0312_fire_laser = function(priest, target, damage, reason, color)
      local pair = pair_for_priest(priest)
      if block_own_station(pair, target, reason or "laser-own-station") then return false end
      return previous_fire_laser(priest, target, damage, reason, color)
    end
  end
end

function M.wrap_candidate_filters()
  if type(_G.is_logistic_scan_candidate_entity) == "function" and not previous_candidate_filter then
    previous_candidate_filter = _G.is_logistic_scan_candidate_entity
    _G.is_logistic_scan_candidate_entity = function(pair, entity)
      if is_own_station(pair, entity) then stat("candidate_home_station_blocked"); return false end
      return previous_candidate_filter(pair, entity)
    end
  end
end

function M.wrap_diagnostics()
  local diag = rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
  if not (diag and type(diag.pair_dump_lines) == "function") or diag.self_station_scan_wrapped_0489 then return false end
  local prev = diag.pair_dump_lines
  diag.self_station_scan_wrapped_0489 = true
  diag.pair_dump_lines = function()
    local lines = prev()
    local r = root()
    lines[#lines + 1] = "SELF-STATION-SCAN-0489 BEGIN enabled=" .. safe(r.enabled) .. " blocked=" .. safe(r.stats.own_station_scan_blocked or 0) .. " inv_skipped=" .. safe(r.stats.inventory_home_station_skipped or 0) .. " craft_skipped=" .. safe(r.stats.emergency_home_station_skipped or 0)
    for key, pair in pairs(pair_map()) do
      if valid_pair(pair) then
        local rec = pair.self_station_scan_0489 or {}
        lines[#lines + 1] = "self-scan[" .. safe(key) .. "] target=" .. safe(valid(pair.target) and (pair.target.name .. "#" .. tostring(pair.target.unit_number or "?")) or "none") .. " last_reason=" .. safe(rec.reason) .. " last_tick=" .. safe(rec.tick or rec.last_service_tick)
      end
    end
    lines[#lines + 1] = "SELF-STATION-SCAN-0489 END"
    return lines
  end
  return true
end

local function player_pair(player)
  if not (player and player.valid and storage and storage.tech_priests) then return nil end
  local e = player.selected
  if valid(e) then return (storage.tech_priests.pairs_by_station or {})[e.unit_number] or (storage.tech_priests.pairs_by_priest or {})[e.unit_number] end
  return nil
end

function M.describe(pair)
  local r = root()
  local lines = { "enabled=" .. safe(r.enabled) .. " blocked=" .. safe(r.stats.own_station_scan_blocked or 0) .. " inv_skipped=" .. safe(r.stats.inventory_home_station_skipped or 0) .. " craft_skipped=" .. safe(r.stats.emergency_home_station_skipped or 0) }
  if valid_pair(pair) then
    local rec = pair.self_station_scan_0489 or {}
    lines[#lines + 1] = "pair=" .. safe(pair_key(pair)) .. " target=" .. safe(valid(pair.target) and (pair.target.name .. "#" .. tostring(pair.target.unit_number or "?")) or "none") .. " last_reason=" .. safe(rec.reason) .. " last_tick=" .. safe(rec.tick or rec.last_service_tick)
  end
  return lines
end

function M.register_commands()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-self-station-scan-0489") end end)
  commands.add_command("tp-self-station-scan-0489", "Tech Priests 0.1.489: inspect own-station scan suppression and visual lease hardening. Usage: status|all|on|off|clear", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local param = lower(event and event.parameter or "status")
    local r = root()
    if param == "off" or param == "disable" then r.enabled = false end
    if param == "on" or param == "enable" then r.enabled = true end
    if param == "clear" then
      local lease = rawget(_G, "TECH_PRIESTS_VISUAL_LEASE_CLEANUP_0487")
      if lease and type(lease.clear_player_overlays) == "function" and player then pcall(lease.clear_player_overlays, player, false) end
      local vis = rawget(_G, "TECH_PRIESTS_ALT_WRIT_VISUAL_STABILITY_0474")
      if vis and type(vis.clear_all) == "function" then pcall(vis.clear_all) end
    end
    if not (player and player.valid) then return end
    if param == "all" then
      for _, pair in pairs(pair_map()) do for _, line in ipairs(M.describe(pair)) do player.print("[tp-self-station-scan-0489] " .. line) end end
    else
      local pair = player_pair(player)
      for _, line in ipairs(M.describe(pair)) do player.print("[tp-self-station-scan-0489] " .. line) end
    end
  end)
end

function M.install()
  root()
  _G.TECH_PRIESTS_SELF_STATION_SCAN_VISUAL_AUTHORITY_0489 = M
  M.patch_visual_authority()
  M.wrap_scan_lines()
  M.wrap_candidate_filters()
  M.wrap_diagnostics()
  M.register_commands()
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then pcall(function() registry = require("scripts.core.runtime_event_registry") end) end
  if registry and registry.on_nth_tick then
    registry.on_nth_tick(M.tick_interval, function() M.tick_all(); M.wrap_scan_lines(); M.wrap_candidate_filters(); M.wrap_diagnostics() end, { owner = "self_station_scan_visual_authority_0489", category = "scheduler", priority = "last" })
  elseif script and script.on_nth_tick then
    pcall(function() script.on_nth_tick(M.tick_interval, function() M.tick_all(); M.wrap_scan_lines(); M.wrap_candidate_filters(); M.wrap_diagnostics() end) end)
  end
  if log then log("[Tech-Priests 0.1.489] own-station scan suppression and visual lease hardening installed") end
  return true
end

return M
