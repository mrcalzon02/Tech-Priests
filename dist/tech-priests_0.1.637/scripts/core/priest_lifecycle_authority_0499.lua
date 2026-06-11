-- scripts/core/priest_lifecycle_authority_0499.lua
-- Tech Priests 0.1.499
--
-- Hard rule pass after repeated reports of visible Tech-Priests vanishing while
-- doing ordinary work: scripts may retire/destroy a priest only as part of a
-- Cogitator Station removal/death cleanup.  Stuck/recall/respawn/purge systems
-- are moved into observation/quarantine mode until the deletion source is proven.

local M = {}
M.version = "0.1.499"
M.storage_key = "priest_lifecycle_authority_0499"
M.tick_interval = 53
M.rebind_radius = 18

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function tp_root() storage.tech_priests = storage.tech_priests or {}; return storage.tech_priests end
local function safe(v) local ok, out = pcall(function() return tostring(v) end); return ok and out or "?" end
local function lname(v) return string.lower(tostring(v or "")) end

local function root()
  local tp = tp_root()
  local r = tp[M.storage_key] or { version = M.version, enabled = true, stats = {}, recent = {}, known_destroy_sites = {} }
  tp[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.respawn_disabled == nil then r.respawn_disabled = true end
  if r.stuck_watchdogs_disabled == nil then r.stuck_watchdogs_disabled = true end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  r.known_destroy_sites = r.known_destroy_sites or {}
  return r
end

local function stat(k, n) local r = root(); r.stats[k] = (r.stats[k] or 0) + (n or 1) end

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
  while #r.recent > 64 do table.remove(r.recent, 1) end
  if log then log("[Tech-Priests 0.1.499] " .. rec.action .. " station=" .. safe(rec.station) .. " priest=" .. safe(rec.priest) .. " " .. rec.detail) end
end

local function is_priest_name(name)
  name = tostring(name or "")
  return name:find("tech%-priest", 1, false) ~= nil and name:find("cogitator", 1, false) == nil
end

local function is_station_name(name)
  name = tostring(name or "")
  return name:find("cogitator%-station", 1, false) ~= nil
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
  if not valid(e) then return "invalid" end
  local p = e.position or {}
  return safe(e.name) .. "#" .. safe(e.unit_number) .. " type=" .. safe(e.type) .. " @" .. string.format("%.1f,%.1f", p.x or 0, p.y or 0)
end

local function event_name(event)
  if not event then return "nil" end
  if defines and defines.events then for k, v in pairs(defines.events) do if v == event.name then return k end end end
  return safe(event.name)
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
  pair.lifecycle_0499 = pair.lifecycle_0499 or {}
  pair.lifecycle_0499.last_valid_tick = now()
  pair.lifecycle_0499.last_valid_priest_unit = pair.priest.unit_number
  pair.lifecycle_0499.last_valid_position = { x = pair.priest.position.x, y = pair.priest.position.y, surface = pair.priest.surface and pair.priest.surface.name or nil }
  pair.lifecycle_0499.last_repair_reason = reason or "repair"
  return true
end

local function rank_from_pair(pair)
  local n = valid(pair and pair.station) and pair.station.name or tostring(pair and pair.station_name_0495 or pair and pair.station_name or "")
  if n:find("planetary%-magos", 1, false) then return "planetary-magos" end
  if n:find("senior", 1, false) then return "senior" end
  if n:find("intermediate", 1, false) then return "intermediate" end
  if n:find("junior", 1, false) then return "junior" end
  return tostring(pair and (pair.tier or pair.rank) or "")
end

local function priest_name_for_rank(rank)
  if rank == "planetary-magos" then return "planetary-magos-tech-priest" end
  if rank == "senior" then return "senior-tech-priest" end
  if rank == "intermediate" then return "intermediate-tech-priest" end
  if rank == "junior" then return "junior-tech-priest" end
  return nil
end

local function priest_bound_elsewhere(entity, own_pair)
  if not valid(entity) then return false end
  local tp = storage and storage.tech_priests or nil
  local other = tp and tp.pairs_by_priest and tp.pairs_by_priest[entity.unit_number] or nil
  return other ~= nil and other ~= own_pair
end

local function rebind_nearby_orphan(pair)
  if not (pair and valid(pair.station)) then return false end
  local pname = priest_name_for_rank(rank_from_pair(pair))
  if not pname then return false end
  local s = pair.station.surface
  if not (s and s.valid) then return false end
  local pos = pair.station.position
  local r = M.rebind_radius
  local ok, found = pcall(function() return s.find_entities_filtered{ area = {{pos.x-r, pos.y-r}, {pos.x+r, pos.y+r}}, name = pname, force = pair.station.force } end)
  if not ok or type(found) ~= "table" then return false end
  local best, best_d = nil, nil
  for _, e in pairs(found) do
    if valid(e) and not priest_bound_elsewhere(e, pair) then
      local dx, dy = e.position.x - pos.x, e.position.y - pos.y
      local d = dx*dx + dy*dy
      if not best_d or d < best_d then best, best_d = e, d end
    end
  end
  if best then
    pair.priest = best
    pair.priest_unit = best.unit_number
    pair.paused_by_missing_priest_0498 = nil
    pair.lost_priest_0490 = nil
    pair.link_0495 = pair.link_0495 or {}
    pair.link_0495.missing_since = nil
    repair_reverse_maps(pair, "rebound-nearby-orphan-0499")
    record("rebound-nearby-orphan", pair, "entity=" .. describe_entity(best) .. " distance_sq=" .. safe(best_d))
    return true
  end
  return false
end

local function clear_stuck_recovery_flags(pair)
  if not pair then return false end
  local changed = false
  for _, key in ipairs({
    "lost_priest_0490", "missing_priest_rescue_0490", "pending_recall", "recalling", "force_recall",
    "movement_stuck_0418", "movement_stabilizer_0417", "movement_lockdown_0416", "stuck_since",
    "space_missing_priest_seen_0204", "direct_target_lease_0414"
  }) do
    if pair[key] ~= nil then pair[key] = nil; changed = true end
  end
  if pair.execution_watchdog_0477 then
    pair.execution_watchdog_0477.disabled_by_0499 = true
    pair.execution_watchdog_0477.next_tick = now() + 60 * 60 * 24
    changed = true
  end
  return changed
end

local function disable_stuck_watchdog_roots()
  local tp = tp_root()
  tp.acquisition_repair_0337 = tp.acquisition_repair_0337 or { stats = {} }
  if tp.acquisition_repair_0337.enabled ~= false then
    tp.acquisition_repair_0337.enabled = false
    record("disabled-acquisition-repair-watchdog", nil, "storage.acquisition_repair_0337.enabled=false")
  end
  tp.task_execution_sound_governor_0477 = tp.task_execution_sound_governor_0477 or { stats = {} }
  if tp.task_execution_sound_governor_0477.enabled ~= false then
    tp.task_execution_sound_governor_0477.enabled = false
    record("disabled-execution-watchdog", nil, "storage.task_execution_sound_governor_0477.enabled=false")
  end
end

local function original_stack_reason(reason)
  return tostring(reason or "")
end

function M.patch_orphan_purge()
  if type(_G.purge_orphan_selected_priest) == "function" and not rawget(_G, "TECH_PRIESTS_0499_PRE_PURGE_ORPHAN_SELECTED_PRIEST") then
    _G.TECH_PRIESTS_0499_PRE_PURGE_ORPHAN_SELECTED_PRIEST = _G.purge_orphan_selected_priest
    _G.purge_orphan_selected_priest = function(priest)
      local pair = find_pair_for_entity(priest)
      if pair and valid(pair.station) then repair_reverse_maps(pair, "orphan-purge-blocked-0499") end
      record("orphan-purge-blocked", pair, "entity=" .. describe_entity(priest) .. " purge disabled; no priest destruction outside station removal")
      return false
    end
  end
end

function M.patch_respawn_and_recall()
  if type(_G.respawn_pair_priest) == "function" and not rawget(_G, "TECH_PRIESTS_0499_PRE_RESPAWN_PAIR_PRIEST") then
    _G.TECH_PRIESTS_0499_PRE_RESPAWN_PAIR_PRIEST = _G.respawn_pair_priest
    _G.respawn_pair_priest = function(pair, reason)
      if pair and valid(pair.priest) then
        repair_reverse_maps(pair, "respawn-blocked-valid-0499")
        record("respawn-blocked-valid-priest", pair, "reason=" .. original_stack_reason(reason) .. " unit=" .. safe(pair.priest.unit_number))
        return true
      end
      if rebind_nearby_orphan(pair) then
        record("respawn-converted-to-rebind", pair, "reason=" .. original_stack_reason(reason))
        return true
      end
      record("respawn-disabled", pair, "reason=" .. original_stack_reason(reason) .. " no script respawn while vanish bug is under audit")
      if pair then
        pair.respawn_disabled_0499 = { tick = now(), reason = original_stack_reason(reason) }
        clear_stuck_recovery_flags(pair)
      end
      return false
    end
  end

  if type(_G.ensure_pair_priest) == "function" and not rawget(_G, "TECH_PRIESTS_0499_PRE_ENSURE_PAIR_PRIEST") then
    _G.TECH_PRIESTS_0499_PRE_ENSURE_PAIR_PRIEST = _G.ensure_pair_priest
    _G.ensure_pair_priest = function(pair, force_recall, immediate)
      if pair and valid(pair.priest) then
        repair_reverse_maps(pair, "ensure-no-recall-0499")
        if force_recall or immediate then record("ensure-recall-blocked-valid", pair, "force=" .. safe(force_recall) .. " immediate=" .. safe(immediate)) end
        return true
      end
      if rebind_nearby_orphan(pair) then
        record("ensure-converted-to-rebind", pair, "force=" .. safe(force_recall) .. " immediate=" .. safe(immediate))
        return true
      end
      record("ensure-respawn-disabled", pair, "force=" .. safe(force_recall) .. " immediate=" .. safe(immediate))
      if pair then pair.ensure_disabled_0499 = { tick = now(), force = force_recall, immediate = immediate }; clear_stuck_recovery_flags(pair) end
      return false
    end
  end
end

function M.patch_mobility_upgrade_destroy()
  if type(_G.upgrade_pair_priest_to_current_mobility) == "function" and not rawget(_G, "TECH_PRIESTS_0499_PRE_UPGRADE_PAIR_MOBILITY") then
    _G.TECH_PRIESTS_0499_PRE_UPGRADE_PAIR_MOBILITY = _G.upgrade_pair_priest_to_current_mobility
    _G.upgrade_pair_priest_to_current_mobility = function(pair)
      if pair and valid(pair.priest) then
        repair_reverse_maps(pair, "mobility-upgrade-destroy-blocked-0499")
        record("mobility-upgrade-destroy-blocked", pair, "old replacement path disabled; priest preserved")
        return true
      end
      record("mobility-upgrade-missing-priest", pair, "replacement path disabled")
      return false
    end
  end

  if type(_G.upgrade_force_priests_to_current_mobility) == "function" and not rawget(_G, "TECH_PRIESTS_0499_PRE_UPGRADE_FORCE_MOBILITY") then
    _G.TECH_PRIESTS_0499_PRE_UPGRADE_FORCE_MOBILITY = _G.upgrade_force_priests_to_current_mobility
    _G.upgrade_force_priests_to_current_mobility = function(force)
      local count = 0
      for _, pair in pairs(pair_map()) do
        if pair and valid(pair.station) and (not force or pair.station.force == force) then
          count = count + 1
          repair_reverse_maps(pair, "force-mobility-upgrade-blocked-0499")
        end
      end
      record("force-mobility-upgrade-blocked", nil, "pairs=" .. safe(count) .. " priest replacement disabled")
      return true
    end
  end
end

function M.patch_recovery_modules()
  local safety = rawget(_G, "TechPriestsDirectMiningSafety0490")
  if safety and type(safety.rescue_missing_priests) == "function" and not safety.rescue_disabled_0499 then
    safety.rescue_disabled_0499 = true
    safety.rescue_missing_priests = function()
      record("direct-safety-rescue-disabled", nil, "0490 rescue/respawn disabled by lifecycle authority")
      return false
    end
  end

  local link = rawget(_G, "TechPriestsPairLinkHardening0495")
  if link and type(link.service_pair) == "function" and not link.service_pair_no_respawn_0499 then
    link.service_pair_no_respawn_0499 = true
    link.service_pair = function(pair)
      if not (pair and valid(pair.station)) then return false end
      if valid(pair.priest) then
        repair_reverse_maps(pair, "pair-link-no-respawn-valid-0499")
        if pair.link_0495 then pair.link_0495.missing_since = nil end
        clear_stuck_recovery_flags(pair)
        return true
      end
      if rebind_nearby_orphan(pair) then return true end
      pair.link_0495 = pair.link_0495 or {}
      pair.link_0495.missing_since = pair.link_0495.missing_since or now()
      pair.link_0495.rescue_disabled_0499 = true
      clear_stuck_recovery_flags(pair)
      record("pair-link-rescue-disabled", pair, "missing_for=" .. safe(now() - (pair.link_0495.missing_since or now())) .. " no respawn")
      return false
    end
    link.service_all = function()
      for _, pair in pairs(pair_map()) do link.service_pair(pair) end
      return true
    end
  end
end

function M.handle_removed(event)
  local e = event and event.entity
  if not (valid(e) and is_priest_entity(e)) then return false end
  local pair = find_pair_for_entity(e)
  local detail = event_name(event) .. " entity=" .. describe_entity(e)
    .. " cause=" .. describe_entity(event and event.cause)
    .. " allowed_script_context=" .. tostring(false)
  record("priest-removal-observed", pair, detail)
  if pair then
    pair.priest_removed_0499 = { tick = now(), event = event_name(event), entity = describe_entity(e), cause = describe_entity(event and event.cause) }
  end
  return false
end

function M.service_pair(pair)
  if not (pair and valid(pair.station)) then return false end
  if valid(pair.priest) then
    repair_reverse_maps(pair, "lifecycle-service-0499")
    clear_stuck_recovery_flags(pair)
    return true
  end
  if rebind_nearby_orphan(pair) then return true end
  clear_stuck_recovery_flags(pair)
  record("missing-priest-no-respawn", pair, "station valid; respawn/recall disabled until delete source is isolated")
  return false
end

function M.service_all()
  local r = root(); if r.enabled == false then return end
  disable_stuck_watchdog_roots()
  for _, pair in pairs(pair_map()) do M.service_pair(pair) end
end

local function populate_known_destroy_sites()
  local r = root()
  r.known_destroy_sites = {
    "generated/control_legacy_part_001.lua remove_pair_for_entity: priest.destroy only allowed when station cleanup is the trigger",
    "generated/control_legacy_part_002.lua respawn_pair_priest: old_priest.destroy now blocked by 0499 wrapper",
    "generated/control_legacy_part_003.lua upgrade_pair_priest_to_current_mobility: old_priest.destroy now blocked by 0499 wrapper",
    "generated/control_legacy_part_006.lua purge_orphan_selected_priest: priest.destroy now blocked by 0499 wrapper",
    "direct/item/resource destroy calls reviewed as non-priest paths and guarded by direct mining safety"
  }
end

function M.wrap_pair_dump()
  local diag = rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diag and type(diag.pair_dump_lines) == "function") or diag.priest_lifecycle_wrapped_0499 then return false end
  local prev = diag.pair_dump_lines
  diag.priest_lifecycle_wrapped_0499 = true
  diag.pair_dump_lines = function()
    local lines = prev()
    local r = root()
    lines[#lines+1] = "PAIR-DUMP-0468 PRIEST-LIFECYCLE-0499 BEGIN enabled=" .. safe(r.enabled)
      .. " respawn_disabled=" .. safe(r.respawn_disabled)
      .. " stuck_watchdogs_disabled=" .. safe(r.stuck_watchdogs_disabled)
      .. " removals=" .. safe(r.stats["priest-removal-observed"] or 0)
      .. " blocked_respawn=" .. safe((r.stats["respawn-disabled"] or 0) + (r.stats["respawn-blocked-valid-priest"] or 0))
      .. " blocked_purge=" .. safe(r.stats["orphan-purge-blocked"] or 0)
    for _, pair in pairs(pair_map()) do
      if pair and valid(pair.station) then
        lines[#lines+1] = "PAIR-DUMP-0468 lifecycle0499[pair " .. safe(station_unit(pair)) .. "] station=" .. describe_entity(pair.station)
          .. " priest=" .. (valid(pair.priest) and describe_entity(pair.priest) or "invalid")
          .. " last_removed=" .. safe(pair.priest_removed_0499 and pair.priest_removed_0499.event or pair.priest_removed_0498 and pair.priest_removed_0498.event or "nil")
          .. " respawn_disabled=" .. safe(pair.respawn_disabled_0499 and pair.respawn_disabled_0499.reason or "nil")
      end
    end
    for i = math.max(1, #r.recent - 12), #r.recent do
      local ev = r.recent[i]
      if ev then lines[#lines+1] = "PAIR-DUMP-0468 lifecycle0499[" .. safe(i) .. "] tick=" .. safe(ev.tick) .. " action=" .. safe(ev.action) .. " station=" .. safe(ev.station) .. " priest=" .. safe(ev.priest) .. " " .. safe(ev.detail) end
    end
    lines[#lines+1] = "PAIR-DUMP-0468 PRIEST-LIFECYCLE-0499 END"
    return lines
  end
  return true
end

function M.register_events()
  local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not R then pcall(function() R = require("scripts.core.runtime_event_registry") end) end
  if R and defines and defines.events then
    R.on_event({ defines.events.on_entity_died, defines.events.script_raised_destroy, defines.events.on_pre_player_mined_item, defines.events.on_robot_pre_mined }, function(event) return M.handle_removed(event) end, nil, { owner = "priest_lifecycle_authority_0499", category = "pair-lifecycle", priority = "last" })
    R.on_nth_tick(M.tick_interval, function() M.service_all() end, { owner = "priest_lifecycle_authority_0499", category = "pair-lifecycle", priority = "last" })
  elseif script and script.on_nth_tick then
    pcall(function() script.on_nth_tick(M.tick_interval, function() M.service_all() end) end)
  end
end

function M.register_commands()
  if not commands then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-priest-lifecycle-0499") end end)
  commands.add_command("tp-priest-lifecycle-0499", "Tech Priests 0.1.499: priest lifecycle authority. Usage: status|all|sites|on|off", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local p = lname(event and event.parameter or "status")
    local r = root()
    if p == "on" then r.enabled = true end
    if p == "off" then r.enabled = false end
    if p == "all" then M.service_all() end
    if player and player.valid then
      player.print("[tp-priest-lifecycle-0499] enabled=" .. safe(r.enabled)
        .. " respawn_disabled=" .. safe(r.respawn_disabled)
        .. " removed=" .. safe(r.stats["priest-removal-observed"] or 0)
        .. " blocked_respawn=" .. safe((r.stats["respawn-disabled"] or 0) + (r.stats["respawn-blocked-valid-priest"] or 0))
        .. " blocked_purge=" .. safe(r.stats["orphan-purge-blocked"] or 0))
      if p == "sites" or p == "all" then for _, line in ipairs(r.known_destroy_sites or {}) do player.print("[tp-priest-lifecycle-0499] " .. line) end end
    end
  end)
end

function M.install()
  if M.installed then return true end
  M.installed = true
  root()
  populate_known_destroy_sites()
  _G.TechPriestsPriestLifecycleAuthority0499 = M
  disable_stuck_watchdog_roots()
  M.patch_orphan_purge()
  M.patch_respawn_and_recall()
  M.patch_mobility_upgrade_destroy()
  M.patch_recovery_modules()
  M.wrap_pair_dump()
  M.register_events()
  M.register_commands()
  if log then log("[Tech-Priests 0.1.499] priest lifecycle authority installed; respawn/recall/orphan-purge/stuck watchdog deletion paths disabled") end
  return true
end

return M
