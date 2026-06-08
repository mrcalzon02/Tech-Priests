-- scripts/core/priest_lifecycle_seal_0500.lua
-- Tech Priests 0.1.500
--
-- Direct hardening pass for the disappearing-priest failure.  The 0.1.499 pass
-- blocked several wrapper paths, but a direct LuaEntity.destroy({raise_destroy=false})
-- can still erase a priest without emitting the removal events we were watching.
-- This module provides a single destruction seal, disables stuck/recall deletion
-- mechanics again, and keeps visible priests non-destructible while the pair
-- lifecycle is under audit.

local M = {}
M.version = "0.1.500"
M.storage_key = "priest_lifecycle_seal_0500"
M.tick_interval = 17
M.rebind_radius = 24

local PRIEST_NAMES = {
  ["junior-tech-priest"] = true,
  ["intermediate-tech-priest"] = true,
  ["senior-tech-priest"] = true,
  ["planetary-magos-tech-priest"] = true,
}

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) local ok, out = pcall(function() return tostring(v) end); return ok and out or "?" end
local function lname(v) return string.lower(tostring(v or "")) end

local function tp_root()
  storage.tech_priests = storage.tech_priests or {}
  return storage.tech_priests
end

local function root()
  local tp = tp_root()
  local r = tp[M.storage_key] or { version = M.version, enabled = true, stats = {}, recent = {}, direct_sites = {} }
  tp[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.preserve_destructible == nil then r.preserve_destructible = true end
  if r.disable_recall_and_stuck == nil then r.disable_recall_and_stuck = true end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  r.direct_sites = r.direct_sites or {}
  return r
end

local function stat(k, n) local r = root(); r.stats[k] = (r.stats[k] or 0) + (n or 1) end

local function pair_map()
  return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
end

local function is_priest_name(name)
  if PRIEST_NAMES[tostring(name or "")] then return true end
  local n = tostring(name or "")
  return n:find("tech%-priest", 1, false) ~= nil and n:find("cogitator", 1, false) == nil
end

local function is_station_name(name)
  return tostring(name or ""):find("cogitator%-station", 1, false) ~= nil
end

local function is_priest_entity(e)
  if not valid(e) then return false end
  if type(_G.is_priest) == "function" then local ok, yes = pcall(_G.is_priest, e); if ok and yes then return true end end
  return is_priest_name(e.name)
end

local function is_station_entity(e)
  if not valid(e) then return false end
  if type(_G.is_station) == "function" then local ok, yes = pcall(_G.is_station, e); if ok and yes then return true end end
  return is_station_name(e.name)
end

local function describe_entity(e)
  if not e then return "nil" end
  local ok, desc = pcall(function()
    local p = e.position or {}
    return safe(e.name) .. "#" .. safe(e.unit_number) .. " type=" .. safe(e.type) .. " @" .. string.format("%.1f,%.1f", p.x or 0, p.y or 0)
  end)
  return ok and desc or "invalid-or-inaccessible"
end

local function station_unit(pair)
  return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil
end

local function priest_unit(pair)
  return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil
end

local function record(action, pair, detail)
  local r = root()
  stat(action)
  local rec = { tick = now(), action = tostring(action or "event"), station = station_unit(pair), priest = priest_unit(pair), detail = tostring(detail or "") }
  r.recent[#r.recent + 1] = rec
  while #r.recent > 96 do table.remove(r.recent, 1) end
  if log then log("[Tech-Priests 0.1.500] " .. rec.action .. " station=" .. safe(rec.station) .. " priest=" .. safe(rec.priest) .. " " .. rec.detail) end
end

local function find_pair_for_entity(e)
  if not valid(e) then return nil end
  if type(_G.find_pair_for_entity) == "function" then local ok, pair = pcall(_G.find_pair_for_entity, e); if ok and pair then return pair end end
  local tp = storage and storage.tech_priests or nil
  if tp and e.unit_number then
    if tp.pairs_by_priest and tp.pairs_by_priest[e.unit_number] then return tp.pairs_by_priest[e.unit_number] end
    if tp.station_by_priest and tp.station_by_priest[e.unit_number] and tp.pairs_by_station then return tp.pairs_by_station[tp.station_by_priest[e.unit_number]] end
    if tp.pairs_by_station and tp.pairs_by_station[e.unit_number] then return tp.pairs_by_station[e.unit_number] end
  end
  for _, pair in pairs(pair_map()) do
    if pair and (pair.priest == e or pair.station == e or pair.priest_unit == e.unit_number or pair.station_unit == e.unit_number) then return pair end
  end
  return nil
end

local function repair_reverse_maps(pair, reason)
  if not (pair and valid(pair.station) and valid(pair.priest)) then return false end
  local tp = tp_root()
  tp.pairs_by_station = tp.pairs_by_station or {}
  tp.pairs_by_priest = tp.pairs_by_priest or {}
  tp.station_by_priest = tp.station_by_priest or {}
  pair.station_unit = pair.station.unit_number
  pair.priest_unit = pair.priest.unit_number
  tp.pairs_by_station[pair.station.unit_number] = pair
  tp.pairs_by_priest[pair.priest.unit_number] = pair
  tp.station_by_priest[pair.priest.unit_number] = pair.station.unit_number
  pair.lifecycle_0500 = pair.lifecycle_0500 or {}
  pair.lifecycle_0500.last_valid_tick = now()
  pair.lifecycle_0500.last_valid_priest_unit = pair.priest.unit_number
  pair.lifecycle_0500.last_valid_position = { x = pair.priest.position.x, y = pair.priest.position.y, surface = pair.priest.surface and pair.priest.surface.name or nil }
  pair.lifecycle_0500.last_repair_reason = reason or "repair"
  return true
end

local function preserve_priest_entity(priest, pair, reason)
  if not valid(priest) then return false end
  pcall(function() priest.destructible = false end)
  if not (pair and pair.space_platform_fallback_0204) then pcall(function() priest.active = true end) end
  if pair then repair_reverse_maps(pair, reason or "preserve") end
  return true
end

local function disable_stuck_flags(pair)
  if not pair then return false end
  local changed = false
  for _, key in ipairs({
    "stuck_since", "movement_stuck_0418", "movement_stabilizer_0417", "movement_lockdown_0416",
    "pending_recall", "recalling", "force_recall", "deployment_queued", "lost_priest_0490",
    "missing_priest_rescue_0490", "space_missing_priest_seen_0204", "direct_target_lease_0414"
  }) do
    if pair[key] ~= nil then pair[key] = nil; changed = true end
  end
  if pair.execution_watchdog_0477 then
    pair.execution_watchdog_0477.disabled_by_0500 = true
    pair.execution_watchdog_0477.next_tick = now() + 60 * 60 * 24
    changed = true
  end
  return changed
end

local function disable_watchdog_roots()
  local tp = tp_root()
  tp.acquisition_repair_0337 = tp.acquisition_repair_0337 or { stats = {} }
  if tp.acquisition_repair_0337.enabled ~= false then tp.acquisition_repair_0337.enabled = false; record("disabled-acquisition-watchdog", nil, "storage.acquisition_repair_0337.enabled=false") end
  tp.task_execution_sound_governor_0477 = tp.task_execution_sound_governor_0477 or { stats = {} }
  if tp.task_execution_sound_governor_0477.enabled ~= false then tp.task_execution_sound_governor_0477.enabled = false; record("disabled-execution-watchdog", nil, "storage.task_execution_sound_governor_0477.enabled=false") end
end

local function destruction_allowed(pair, priest, reason, opts)
  opts = opts or {}
  if opts.allow_station_cleanup == true then return true end
  if pair and pair.lifecycle_0500 and pair.lifecycle_0500.allow_priest_destroy_until and now() <= pair.lifecycle_0500.allow_priest_destroy_until then return true end
  local r = root()
  local a = r.allowed_station_cleanup
  if a and now() <= (a.until_tick or -1) then
    if (not pair or not a.station_unit or station_unit(pair) == a.station_unit) and (not priest or not a.priest_unit or priest.unit_number == a.priest_unit) then return true end
  end
  return false
end

function M.allow_station_cleanup(pair, reason)
  if not pair then return false end
  local r = root()
  r.allowed_station_cleanup = { tick = now(), until_tick = now() + 4, station_unit = station_unit(pair), priest_unit = priest_unit(pair), reason = tostring(reason or "station-cleanup") }
  pair.lifecycle_0500 = pair.lifecycle_0500 or {}
  pair.lifecycle_0500.allow_priest_destroy_until = now() + 4
  pair.lifecycle_0500.allow_priest_destroy_reason = tostring(reason or "station-cleanup")
  record("station-cleanup-destroy-seal-opened", pair, tostring(reason or "station-cleanup"))
  return true
end

function M.destroy_priest(priest, reason, pair, opts)
  if not valid(priest) then return false end
  if not is_priest_entity(priest) then
    pcall(function() priest.destroy(opts or { raise_destroy = false }) end)
    return true
  end
  pair = pair or find_pair_for_entity(priest)
  if destruction_allowed(pair, priest, reason, opts) then
    record("authorized-priest-destroy", pair, "reason=" .. safe(reason) .. " entity=" .. describe_entity(priest))
    pcall(function() priest.destroy({ raise_destroy = false }) end)
    return true
  end
  preserve_priest_entity(priest, pair, "blocked-destroy-" .. tostring(reason or "unknown"))
  record("blocked-priest-destroy", pair, "reason=" .. safe(reason) .. " entity=" .. describe_entity(priest) .. " only Cogitator station removal may destroy priests")
  return false
end


function M.patch_create_pair()
  if type(_G.create_pair) ~= "function" or rawget(_G, "TECH_PRIESTS_0500_PRE_CREATE_PAIR") then return false end
  _G.TECH_PRIESTS_0500_PRE_CREATE_PAIR = _G.create_pair
  _G.create_pair = function(station, ...)
    local result = _G.TECH_PRIESTS_0500_PRE_CREATE_PAIR(station, ...)
    local pair = valid(station) and find_pair_for_entity(station) or nil
    if pair and valid(pair.priest) then
      preserve_priest_entity(pair.priest, pair, "create-pair-immediate-preserve-0500")
      record("create-pair-priest-sealed", pair, "entity=" .. describe_entity(pair.priest))
    end
    return result
  end
  return true
end

function M.patch_remove_pair_for_entity()
  if type(_G.remove_pair_for_entity) ~= "function" or rawget(_G, "TECH_PRIESTS_0500_PRE_REMOVE_PAIR_FOR_ENTITY") then return false end
  _G.TECH_PRIESTS_0500_PRE_REMOVE_PAIR_FOR_ENTITY = _G.remove_pair_for_entity
  _G.remove_pair_for_entity = function(entity, source_event)
    local pair = valid(entity) and find_pair_for_entity(entity) or nil
    if valid(entity) and is_priest_entity(entity) then
      preserve_priest_entity(entity, pair, "remove-pair-priest-trigger-blocked-0500")
      record("remove-pair-priest-trigger-blocked", pair, "event=" .. safe(source_event and source_event.name) .. " entity=" .. describe_entity(entity) .. " station retained")
      return false
    end
    if valid(entity) and is_station_entity(entity) then
      if pair then M.allow_station_cleanup(pair, "remove-pair-station-trigger-0500") end
    end
    return _G.TECH_PRIESTS_0500_PRE_REMOVE_PAIR_FOR_ENTITY(entity, source_event)
  end
  return true
end

function M.patch_respawn_and_recall()
  if type(_G.respawn_pair_priest) == "function" and not rawget(_G, "TECH_PRIESTS_0500_PRE_RESPAWN_PAIR_PRIEST") then
    _G.TECH_PRIESTS_0500_PRE_RESPAWN_PAIR_PRIEST = _G.respawn_pair_priest
    _G.respawn_pair_priest = function(pair, reason)
      if pair and valid(pair.priest) then
        preserve_priest_entity(pair.priest, pair, "respawn-blocked-valid-0500")
        record("respawn-blocked-valid", pair, "reason=" .. safe(reason))
        return true
      end
      record("respawn-blocked-missing", pair, "reason=" .. safe(reason) .. " no spawn/replace while delete source is under audit")
      return false
    end
  end
  if type(_G.ensure_pair_priest) == "function" and not rawget(_G, "TECH_PRIESTS_0500_PRE_ENSURE_PAIR_PRIEST") then
    _G.TECH_PRIESTS_0500_PRE_ENSURE_PAIR_PRIEST = _G.ensure_pair_priest
    _G.ensure_pair_priest = function(pair, force_recall, immediate)
      if pair and valid(pair.priest) then
        preserve_priest_entity(pair.priest, pair, "ensure-blocked-valid-0500")
        if force_recall or immediate then record("ensure-recall-blocked-valid", pair, "force=" .. safe(force_recall) .. " immediate=" .. safe(immediate)) end
        return true
      end
      record("ensure-respawn-blocked-missing", pair, "force=" .. safe(force_recall) .. " immediate=" .. safe(immediate))
      return false
    end
  end
  if type(_G.sanity_recall_all_priests) == "function" and not rawget(_G, "TECH_PRIESTS_0500_PRE_SANITY_RECALL_ALL_PRIESTS") then
    _G.TECH_PRIESTS_0500_PRE_SANITY_RECALL_ALL_PRIESTS = _G.sanity_recall_all_priests
    _G.sanity_recall_all_priests = function(force_recall)
      for _, pair in pairs(pair_map()) do if pair and valid(pair.priest) then preserve_priest_entity(pair.priest, pair, "sanity-recall-blocked-0500") end; disable_stuck_flags(pair) end
      record("sanity-recall-blocked", nil, "force=" .. safe(force_recall))
      return true
    end
  end
end

function M.patch_platform_replacement()
  if type(_G.tech_priests_force_priest_to_platform_locus_0208) == "function" and not rawget(_G, "TECH_PRIESTS_0500_PRE_FORCE_PLATFORM_LOCUS") then
    _G.TECH_PRIESTS_0500_PRE_FORCE_PLATFORM_LOCUS = _G.tech_priests_force_priest_to_platform_locus_0208
    _G.tech_priests_force_priest_to_platform_locus_0208 = function(pair, reason)
      if pair and valid(pair.priest) then preserve_priest_entity(pair.priest, pair, "platform-locus-recreate-blocked-0500") end
      record("platform-locus-recreate-blocked", pair, "reason=" .. safe(reason))
      return true
    end
  end
end

function M.patch_recovery_modules()
  local link = rawget(_G, "TechPriestsPairLinkHardening0495")
  if link and type(link.service_pair) == "function" then
    link.service_pair = function(pair)
      if not (pair and valid(pair.station)) then return false end
      disable_stuck_flags(pair)
      if valid(pair.priest) then preserve_priest_entity(pair.priest, pair, "pair-link-service-0500"); return true end
      record("pair-link-respawn-blocked", pair, "missing priest; respawn disabled in 0500")
      return false
    end
    link.service_all = function() for _, pair in pairs(pair_map()) do link.service_pair(pair) end; return true end
  end
  local safety = rawget(_G, "TechPriestsDirectMiningSafety0490")
  if safety and type(safety.rescue_missing_priests) == "function" then
    safety.rescue_missing_priests = function() record("direct-mining-rescue-blocked", nil, "0490 rescue disabled by 0500 lifecycle seal"); return false end
  end
end

function M.handle_removed(event)
  local e = event and event.entity
  local name = nil
  pcall(function() name = e and e.name end)
  if not is_priest_name(name) then return false end
  local pair = valid(e) and find_pair_for_entity(e) or nil
  record("priest-removal-event-observed", pair, "event=" .. safe(event and event.name) .. " entity=" .. describe_entity(e) .. " cause=" .. describe_entity(event and event.cause))
  if pair then pair.priest_removed_0500 = { tick = now(), event = safe(event and event.name), entity = describe_entity(e), cause = describe_entity(event and event.cause) } end
  return false
end

function M.service_pair(pair)
  if not (pair and valid(pair.station)) then return false end
  disable_stuck_flags(pair)
  if valid(pair.priest) then
    preserve_priest_entity(pair.priest, pair, "service-pair-0500")
    return true
  end
  record("missing-priest-held-for-diagnosis", pair, "no respawn; no script destruction allowed")
  return false
end

function M.service_all()
  local r = root(); if r.enabled == false then return false end
  disable_watchdog_roots()
  for _, pair in pairs(pair_map()) do M.service_pair(pair) end
  return true
end

function M.wrap_pair_dump()
  local diag = rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diag and type(diag.pair_dump_lines) == "function") or diag.priest_lifecycle_wrapped_0500 then return false end
  local prev = diag.pair_dump_lines
  diag.priest_lifecycle_wrapped_0500 = true
  diag.pair_dump_lines = function()
    local lines = prev()
    local r = root()
    lines[#lines+1] = "PAIR-DUMP-0468 PRIEST-LIFECYCLE-SEAL-0500 BEGIN enabled=" .. safe(r.enabled)
      .. " preserve_destructible=" .. safe(r.preserve_destructible)
      .. " blocked_destroy=" .. safe(r.stats["blocked-priest-destroy"] or 0)
      .. " authorized_destroy=" .. safe(r.stats["authorized-priest-destroy"] or 0)
      .. " removals=" .. safe(r.stats["priest-removal-event-observed"] or 0)
    for _, pair in pairs(pair_map()) do
      if pair and valid(pair.station) then
        lines[#lines+1] = "PAIR-DUMP-0468 lifecycle0500[pair " .. safe(station_unit(pair)) .. "] station=" .. describe_entity(pair.station)
          .. " priest=" .. (valid(pair.priest) and describe_entity(pair.priest) or "invalid")
          .. " last_valid=" .. safe(pair.lifecycle_0500 and pair.lifecycle_0500.last_valid_tick or "nil")
          .. " last_removed=" .. safe(pair.priest_removed_0500 and pair.priest_removed_0500.event or "nil")
      end
    end
    for i = math.max(1, #r.recent - 18), #r.recent do
      local ev = r.recent[i]
      if ev then lines[#lines+1] = "PAIR-DUMP-0468 lifecycle0500[" .. safe(i) .. "] tick=" .. safe(ev.tick) .. " action=" .. safe(ev.action) .. " station=" .. safe(ev.station) .. " priest=" .. safe(ev.priest) .. " " .. safe(ev.detail) end
    end
    lines[#lines+1] = "PAIR-DUMP-0468 PRIEST-LIFECYCLE-SEAL-0500 END"
    return lines
  end
  return true
end

function M.register_events()
  local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not R then pcall(function() R = require("scripts.core.runtime_event_registry") end) end
  if R and defines and defines.events then
    R.on_event({ defines.events.on_entity_died, defines.events.script_raised_destroy, defines.events.on_pre_player_mined_item, defines.events.on_robot_pre_mined }, function(event) return M.handle_removed(event) end, nil, { owner = "priest_lifecycle_seal_0500", category = "pair-lifecycle", priority = "last" })
    R.on_nth_tick(M.tick_interval, function() M.service_all() end, { owner = "priest_lifecycle_seal_0500", category = "pair-lifecycle", priority = "last" })
  elseif script and script.on_nth_tick then
    pcall(function() script.on_nth_tick(M.tick_interval, function() M.service_all() end) end)
  end
end

function M.register_commands()
  if not commands then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-priest-lifecycle-0500") end end)
  commands.add_command("tp-priest-lifecycle-0500", "Tech Priests 0.1.500: priest lifecycle seal. Usage: status|all|on|off", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local p = lname(event and event.parameter or "status")
    local r = root()
    if p == "on" then r.enabled = true end
    if p == "off" then r.enabled = false end
    if p == "all" then M.service_all() end
    if player and player.valid then
      player.print("[tp-priest-lifecycle-0500] enabled=" .. safe(r.enabled)
        .. " blocked_destroy=" .. safe(r.stats["blocked-priest-destroy"] or 0)
        .. " authorized_destroy=" .. safe(r.stats["authorized-priest-destroy"] or 0)
        .. " removal_events=" .. safe(r.stats["priest-removal-event-observed"] or 0))
      for i = math.max(1, #r.recent - 8), #r.recent do
        local ev = r.recent[i]
        if ev then player.print("[tp-priest-lifecycle-0500] tick=" .. safe(ev.tick) .. " " .. safe(ev.action) .. " station=" .. safe(ev.station) .. " priest=" .. safe(ev.priest) .. " " .. safe(ev.detail)) end
      end
    end
  end)
end

function M.install()
  if M.installed then return true end
  M.installed = true
  root()
  _G.TechPriestsPriestLifecycleSeal0500 = M
  _G.tech_priests_is_priest_0500 = is_priest_entity
  _G.tech_priests_destroy_priest_0500 = function(priest, reason, pair, opts) return M.destroy_priest(priest, reason, pair, opts) end
  _G.tech_priests_allow_priest_station_cleanup_0500 = function(pair, reason) return M.allow_station_cleanup(pair, reason) end
  disable_watchdog_roots()
  M.patch_create_pair()
  M.patch_remove_pair_for_entity()
  M.patch_respawn_and_recall()
  M.patch_platform_replacement()
  M.patch_recovery_modules()
  M.wrap_pair_dump()
  M.register_events()
  M.register_commands()
  M.service_all()
  if log then log("[Tech-Priests 0.1.500] priest lifecycle seal installed; direct priest destroy blocked except station cleanup and priests made non-destructible for audit") end
  return true
end

return M
