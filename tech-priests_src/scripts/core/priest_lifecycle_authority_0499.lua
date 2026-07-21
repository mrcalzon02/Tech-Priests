-- scripts/core/priest_lifecycle_authority_0499.lua
-- Tech Priests 0.1.499
--
-- Hard rule pass after repeated reports of visible Tech-Priests vanishing while
-- doing ordinary work: scripts may retire/destroy a priest only as part of a
-- Cogitator Station removal/death cleanup.  Stuck/recall/respawn/purge systems
-- are moved into observation/quarantine mode until the deletion source is proven.

local M = {}
M.version = "0.1.674-dev"
M.storage_key = "priest_lifecycle_authority_0499"
M.tick_interval = 53
M.service_budget = 24
M.rebind_radius = 18
M.broker_required = true
M.pair_link_integrated = true
M.destruction_authority_integrated = true
M.replacement_authority_integrated = true
M.controlled_missing_recovery = true
M.reimprint_integrated = true
M.reimprint_presentation = "generated-0298"
M.missing_recovery_delay_ticks = 180
M.replacement_lease_ticks = 30
M.recovery_attempt_cooldown_ticks = 600

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local OrderQueue0469
local function order_queue_0469()
  if not OrderQueue0469 then local ok,module=pcall(require,"scripts.core.order_queue_0469");if ok then OrderQueue0469=module end end
  return OrderQueue0469
end
local function pause_order_for_missing_priest(pair,reason)
  local queue=order_queue_0469();if queue and type(queue.pause_for_missing_priest)=="function"then return queue.pause_for_missing_priest(pair,reason)end
  return false,"order-queue-unavailable"
end
local function resume_order_after_priest_recovery(pair,reason)
  local queue=order_queue_0469();if queue and type(queue.resume_after_priest_recovery)=="function"then return queue.resume_after_priest_recovery(pair,reason)end
  return false,"order-queue-unavailable"
end
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
  r.pair_link_integrated = true
  r.destruction_authority_integrated = true
  r.replacement_authority_integrated = true
  r.controlled_missing_recovery = true
  r.reimprint_integrated = true
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
  if log then log("[Tech-Priests 0.1.674-dev] " .. rec.action .. " station=" .. safe(rec.station) .. " priest=" .. safe(rec.priest) .. " " .. rec.detail) end
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
  pcall(function() pair.priest.destructible = false end)
  if not pair.space_platform_fallback_0204 then pcall(function() pair.priest.active = true end) end
  return true
end


local function active_reimprint(pair)
  local state = pair and pair.reimprint_0298 or nil
  return state and state.active == true and state or nil
end

function M.is_reimprinting(pair)
  local state = active_reimprint(pair)
  return state ~= nil and now() < (tonumber(state.finish_tick) or 0)
end

local function clear_old_priest_maps(pair, dead_priest)
  local tp = tp_root()
  tp.pairs_by_priest = tp.pairs_by_priest or {}
  tp.station_by_priest = tp.station_by_priest or {}
  local old_unit = (dead_priest and dead_priest.unit_number) or (pair and pair.priest_unit)
  if old_unit then
    tp.pairs_by_priest[old_unit] = nil
    tp.station_by_priest[old_unit] = nil
  end
end

function M.begin_reimprint(pair, dead_priest, reason)
  if not (pair and valid(pair.station)) then return false end
  local current = active_reimprint(pair)
  if current then
    pair.lifecycle_0499 = pair.lifecycle_0499 or {}
    pair.lifecycle_0499.missing_since = pair.lifecycle_0499.missing_since or tonumber(current.started_tick) or now()
    pause_order_for_missing_priest(pair, "reimprint-active-0499")
    return true
  end
  clear_old_priest_maps(pair, dead_priest)
  local entered = false
  if type(_G.tech_priests_0298_enter_reimprint) == "function" then
    local ok, result = pcall(_G.tech_priests_0298_enter_reimprint, pair, dead_priest, reason or "priest-death-0499")
    entered = ok and result == true
  end
  if not entered then
    local duration = 60 * 90
    if type(_G.tech_priests_0298_reimprint_duration) == "function" then
      local ok, value = pcall(_G.tech_priests_0298_reimprint_duration, pair.station.force)
      if ok and tonumber(value) then duration = math.max(1, math.floor(tonumber(value))) end
    end
    pair.priest = nil
    pair.priest_unit = nil
    pair.mode = "re-imprinting"
    pair.target = nil
    pair.combat_target = nil
    pair.movement_request_0418 = nil
    pair.pathing_target_0418 = nil
    pair.reimprint_0298 = {
      active = true,
      started_tick = now(),
      finish_tick = now() + duration,
      duration = duration,
      reason = reason or "priest-death-fallback-0499",
      station_unit = station_unit(pair),
    }
    pair.next_allowed_priest_respawn_tick = pair.reimprint_0298.finish_tick
    if type(_G.tech_priests_0298_update_reimprint_render) == "function" then pcall(_G.tech_priests_0298_update_reimprint_render, pair) end
    entered = true
  end
  if not entered then return false end
  local lifecycle = pair.lifecycle_0499 or {}
  pair.lifecycle_0499 = lifecycle
  local state = active_reimprint(pair)
  lifecycle.missing_since = tonumber(state and state.started_tick) or now()
  lifecycle.replacement_lease = nil
  lifecycle.reimprint_started_tick = now()
  lifecycle.reimprint_reason = tostring(reason or "priest-death-0499")
  lifecycle.last_reimprint_report_tick = nil
  pair.priest_removed_0499 = {tick=now(),event="on_entity_died",entity=describe_entity(dead_priest),cause="intentional-reimprint"}
  pause_order_for_missing_priest(pair, "reimprint-started-0499")
  for _, key in ipairs({"lost_priest_0490","missing_priest_rescue_0490","pending_recall","recalling","force_recall","movement_stuck_0418","movement_stabilizer_0417","movement_lockdown_0416","stuck_since","space_missing_priest_seen_0204","direct_target_lease_0414"}) do pair[key] = nil end
  record("priest-reimprint-started", pair, "reason=" .. safe(reason) .. " finish=" .. safe(state and state.finish_tick))
  return true
end

local function controlled_missing_request(reason, opts)
  opts = opts or {}
  return tostring(reason or "") == "controlled-missing-recovery-0503"
    and tostring(opts.owner or "") == "priest_recovery_safety_0503"
    and tostring(opts.kind or "") == "missing-priest-recovery"
end

function M.authorize_missing_recovery(pair, reason, opts)
  opts = opts or {}
  if not controlled_missing_request(reason, opts) or not (pair and valid(pair.station)) or valid(pair.priest) then
    stat("replacement-denied")
    return false, "invalid-controlled-recovery-request"
  end
  pair.lifecycle_0499 = pair.lifecycle_0499 or {}
  local lifecycle = pair.lifecycle_0499
  local reimprint = active_reimprint(pair)
  if reimprint and now() < (tonumber(reimprint.finish_tick) or 0) then return false, "reimprint-in-progress" end
  local missing_since = tonumber(lifecycle.missing_since)
  if not missing_since then stat("replacement-denied-unobserved"); return false, "missing-state-not-observed" end
  if now() - missing_since < M.missing_recovery_delay_ticks then return false, "missing-observation-delay" end
  local last_attempt = tonumber(lifecycle.last_recovery_attempt_tick or -1000000) or -1000000
  if now() - last_attempt < M.recovery_attempt_cooldown_ticks then return false, "recovery-attempt-cooldown" end
  local lease = {
    owner = "priest_recovery_safety_0503",
    kind = "missing-priest-recovery",
    reason = "controlled-missing-recovery-0503",
    issued_tick = now(),
    expires_tick = now() + M.replacement_lease_ticks,
    station_unit = station_unit(pair),
  }
  lifecycle.replacement_lease = lease
  lifecycle.last_recovery_attempt_tick = now()
  record("missing-recovery-lease-issued", pair, "expires=" .. safe(lease.expires_tick))
  return true, lease
end

function M.consume_replacement_lease(pair, reason, opts)
  opts = opts or {}
  if not controlled_missing_request(reason, opts) or not (pair and valid(pair.station)) or valid(pair.priest) then
    stat("replacement-lease-denied")
    return false
  end
  pair.lifecycle_0499 = pair.lifecycle_0499 or {}
  local lifecycle = pair.lifecycle_0499
  local lease = lifecycle.replacement_lease
  lifecycle.replacement_lease = nil
  if type(lease) ~= "table"
    or lease.owner ~= "priest_recovery_safety_0503"
    or lease.kind ~= "missing-priest-recovery"
    or lease.reason ~= "controlled-missing-recovery-0503"
    or tonumber(lease.station_unit) ~= tonumber(station_unit(pair))
    or now() > (tonumber(lease.expires_tick) or -1)
  then
    stat("replacement-lease-denied")
    return false
  end
  lifecycle.last_replacement_lease_consumed_tick = now()
  record("missing-recovery-lease-consumed", pair, "issued=" .. safe(lease.issued_tick))
  return true
end

function M.note_recovered_priest(pair, priest, reason)
  if not (pair and valid(pair.station) and valid(priest) and is_priest_entity(priest)) then return false end
  local reimprint = active_reimprint(pair)
  if reimprint and type(_G.tech_priests_0298_clear_reimprint_render) == "function" then pcall(_G.tech_priests_0298_clear_reimprint_render, pair) end
  pair.priest = priest
  pair.priest_unit = priest.unit_number
  pair.lifecycle_0499 = pair.lifecycle_0499 or {}
  pair.lifecycle_0499.missing_since = nil
  pair.lifecycle_0499.last_missing_report_tick = nil
  pair.lifecycle_0499.replacement_lease = nil
  pair.lifecycle_0499.last_recovered_tick = now()
  pair.lifecycle_0499.last_recovered_reason = tostring(reason or "controlled-missing-recovery-0503")
  pair.respawn_disabled_0499 = nil
  pair.ensure_disabled_0499 = nil
  if reimprint then
    pair.lifecycle_0499.last_reimprint_completed_tick = now()
    pair.lifecycle_0499.last_reimprint_duration = tonumber(reimprint.duration)
    pair.reimprint_0298 = nil
    pair.next_allowed_priest_respawn_tick = nil
    pcall(function() if priest.max_health and priest.max_health > 0 then priest.health = priest.max_health end end)
    if type(_G.tech_priests_0297_refresh_pair_armor_profile) == "function" then pcall(_G.tech_priests_0297_refresh_pair_armor_profile, pair, "reimprint-recovery-0499") end
    if type(_G.apply_pair_display_names) == "function" then pcall(_G.apply_pair_display_names, pair) end
    local naming = rawget(_G, "TechPriestsPairNaming")
    if naming and type(naming.refresh) == "function" then pcall(naming.refresh, pair, "reimprint-recovery-0499") end
    if pair.station.force then pair.station.force.print({"", "[Tech Priests] Re-imprinting complete at ", type(_G.tech_priests_station_name_0189) == "function" and _G.tech_priests_station_name_0189(pair) or "Cogitator Station", ". The useful corpse has been reissued."}) end
  end
  repair_reverse_maps(pair, reimprint and "reimprint-recovery-0499" or "controlled-recovery-0499")
  local refresh_pair_state = rawget(_G, "tech_priests_0362_refresh_pair_state")
  if type(refresh_pair_state) == "function" then
    pcall(refresh_pair_state, pair, reimprint and "canonical-reimprint-recovered" or "canonical-priest-recovered")
  end
  resume_order_after_priest_recovery(pair, reimprint and "reimprint-recovery-0499" or "controlled-recovery-0499")
  record(reimprint and "priest-reimprint-completed" or "missing-priest-recovered", pair, "reason=" .. safe(reason) .. " unit=" .. safe(priest.unit_number))
  return true
end

function M.replacement_authorized(pair, reason, opts)
  opts = opts or {}
  if opts.request_missing_recovery == true then return M.authorize_missing_recovery(pair, reason, opts) end
  if opts.consume_missing_recovery == true then return M.consume_replacement_lease(pair, reason, opts) end
  if pair then
    pair.lifecycle_0499 = pair.lifecycle_0499 or {}
    pair.lifecycle_0499.last_replacement_denied_tick = now()
    pair.lifecycle_0499.last_replacement_denied_reason = tostring(reason or "replacement")
  end
  stat("replacement-denied")
  return false
end

function M.destruction_authorized(pair, priest, reason, opts)
  opts = opts or {}
  reason = tostring(reason or "")
  if opts.allow_station_cleanup == true and reason == "station-cleanup-remove_pair_for_entity" then return true end
  if opts.allow_unbound_replacement_cleanup == true and reason == "platform-recreate-rejected-new-priest" and valid(priest) and (not pair or priest ~= pair.priest) then return true end
  if opts.allow_replacement == true then return M.replacement_authorized(pair, reason, opts) end
  return false
end

function M.destroy_priest_authorized(priest, reason, pair, opts)
  if not valid(priest) or not is_priest_entity(priest) then return false end
  pair = pair or find_pair_for_entity(priest)
  if not M.destruction_authorized(pair, priest, reason, opts) then
    pcall(function() priest.destructible = false end)
    if pair and not pair.space_platform_fallback_0204 then pcall(function() priest.active = true end) end
    if pair and valid(pair.station) then repair_reverse_maps(pair, "blocked-destroy-0499") end
    record("blocked-priest-destroy", pair, "reason=" .. safe(reason) .. " entity=" .. describe_entity(priest))
    return false
  end
  local ok, result = pcall(function() return priest.destroy({ raise_destroy = false }) end)
  local destroyed = ok and result ~= false
  record(destroyed and "authorized-priest-destroy" or "authorized-priest-destroy-failed", pair, "reason=" .. safe(reason) .. " entity=" .. describe_entity(priest))
  return destroyed
end

local function rank_from_pair(pair)
  local n = valid(pair and pair.station) and pair.station.name or tostring(pair and pair.station_name or "")
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
    pair.lost_priest_0490 = nil
    pair.lifecycle_0499 = pair.lifecycle_0499 or {}
    pair.lifecycle_0499.missing_since = nil
    pair.lifecycle_0499.last_rebound_tick = now()
    pair.lifecycle_0499.last_rebound_distance_sq = best_d
    repair_reverse_maps(pair, "rebound-nearby-orphan-0499")
    resume_order_after_priest_recovery(pair, "rebound-nearby-orphan-0499")
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

function M.handle_removed(event)
  local e = event and event.entity
  if not (valid(e) and is_priest_entity(e)) then return false end
  local pair = find_pair_for_entity(e)
  local name = event_name(event)
  local detail = name .. " entity=" .. describe_entity(e) .. " cause=" .. describe_entity(event and event.cause) .. " allowed_script_context=" .. tostring(false)
  record("priest-removal-observed", pair, detail)
  if pair then pair.priest_removed_0499 = {tick=now(),event=name,entity=describe_entity(e),cause=describe_entity(event and event.cause)} end
  if event and defines and defines.events and event.name == defines.events.on_entity_died and pair and valid(pair.station) then
    return M.begin_reimprint(pair, e, "priest-death-0499")
  end
  return false
end

function M.service_pair(pair)
  if not (pair and valid(pair.station)) then return false end
  pair.lifecycle_0499 = pair.lifecycle_0499 or {}
  pair["paused_by_missing_priest_" .. "04" .. "98"] = nil
  pair["priest_removed_" .. "04" .. "98"] = nil
  local lifecycle = pair.lifecycle_0499
  local reimprint = active_reimprint(pair)
  if reimprint and not valid(pair.priest) then
    lifecycle.missing_since = lifecycle.missing_since or tonumber(reimprint.started_tick) or now()
    lifecycle.replacement_lease = nil
    pause_order_for_missing_priest(pair, "reimprint-active-0499")
    clear_stuck_recovery_flags(pair)
    local finish_tick = tonumber(reimprint.finish_tick) or 0
    if now() < finish_tick then
      if type(_G.tech_priests_0298_update_reimprint_render) == "function" then pcall(_G.tech_priests_0298_update_reimprint_render, pair) end
      if not lifecycle.last_reimprint_report_tick or now() - lifecycle.last_reimprint_report_tick >= 600 then
        lifecycle.last_reimprint_report_tick = now()
        record("priest-reimprint-in-progress", pair, "remaining=" .. safe(finish_tick - now()))
      end
      return false
    end
    if not lifecycle.reimprint_ready_tick then lifecycle.reimprint_ready_tick = now();record("priest-reimprint-ready", pair, "0503 lease recovery eligible") end
    return false
  end
  if valid(pair.priest) then
    repair_reverse_maps(pair, "lifecycle-service-0499")
    lifecycle.missing_since = nil
    lifecycle.last_missing_report_tick = nil
    lifecycle.replacement_lease = nil
    clear_stuck_recovery_flags(pair)
    resume_order_after_priest_recovery(pair, "lifecycle-valid-0499")
    return true
  end
  if rebind_nearby_orphan(pair) then return true end
  lifecycle.missing_since = lifecycle.missing_since or now()
  pause_order_for_missing_priest(pair, "lifecycle-missing-0499")
  clear_stuck_recovery_flags(pair)
  if not lifecycle.last_missing_report_tick or now() - lifecycle.last_missing_report_tick >= 600 then
    lifecycle.last_missing_report_tick = now()
    record("missing-priest-awaiting-controlled-recovery", pair, "missing_for=" .. safe(now() - lifecycle.missing_since) .. " station valid; only 0503 lease recovery is eligible")
  end
  return false
end

function M.service_all(_, budget)
  local r = root()
  if r.enabled == false then return { processed = 0, acted = 0, detail = "disabled" } end
  disable_stuck_watchdog_roots()
  local limit = math.max(1, math.min(128, math.floor(tonumber(budget) or M.service_budget)))
  local processed, acted = 0, 0
  for _, pair in pairs(pair_map()) do
    if processed >= limit then break end
    if pair and valid(pair.station) then
      processed = processed + 1
      if M.service_pair(pair) then acted = acted + 1 end
    end
  end
  r.stats.service_processed = (r.stats.service_processed or 0) + processed
  r.stats.service_acted = (r.stats.service_acted or 0) + acted
  return { processed = processed, acted = acted, exhausted = processed >= limit, detail = "lifecycle-observation-only" }
end

local function populate_known_destroy_sites()
  local r = root()
  r.known_destroy_sites = {
    "generated/control_legacy_part_001.lua remove_pair_for_entity: canonical 0499 helper authorizes only station-triggered cleanup",
    "generated/control_legacy_part_002.lua respawn_pair_priest: replacement authorization is checked before creation",
    "generated/control_legacy_part_003.lua upgrade_pair_priest_to_current_mobility: replacement authorization is checked before creation",
    "generated/control_legacy_part_006.lua purge_orphan_selected_priest: orphan destruction is fail-closed",
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
          .. " last_removed=" .. safe(pair.priest_removed_0499 and pair.priest_removed_0499.event or "nil")
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
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then pcall(function() registry = require("scripts.core.runtime_event_registry") end) end
  if registry and defines and defines.events then
    registry.on_event({defines.events.on_entity_died,defines.events.script_raised_destroy,defines.events.on_pre_player_mined_item,defines.events.on_robot_pre_mined},function(event) return M.handle_removed(event) end,nil,{owner="priest_lifecycle_authority_0499",category="pair-lifecycle",priority="first",stop_on_truthy=true,note="priest death enters 0298 re-imprint before legacy linked-removal cleanup"})
    return true
  end
  return false
end

function M.register_broker_service()
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if not broker then pcall(function() broker = require("scripts.core.runtime_tick_broker") end) end
  if not (broker and type(broker.register_service) == "function") then return false end
  return broker.register_service({
    name = "priest_lifecycle_observation_0499",
    category = "pair-lifecycle",
    interval = M.tick_interval,
    priority = 24,
    budget = M.service_budget,
    fn = M.service_all,
    note = "reverse-map repair, priest-death re-imprint observation, conservative orphan rebind, and controlled recovery readiness",
  }) ~= false
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
  _G.tech_priests_is_priest_0499 = is_priest_entity
  _G.tech_priests_begin_reimprint_0499 = function(pair, priest, reason) return M.begin_reimprint(pair, priest, reason) end
  _G.tech_priests_pair_is_reimprinting_0499 = function(pair) return M.is_reimprinting(pair) end
  _G.tech_priests_priest_replacement_authorized_0499 = function(pair, reason, opts) return M.replacement_authorized(pair, reason, opts) end
  _G.tech_priests_authorize_missing_recovery_0499 = function(pair, reason, opts) return M.authorize_missing_recovery(pair, reason, opts) end
  _G.tech_priests_consume_replacement_lease_0499 = function(pair, reason, opts) return M.consume_replacement_lease(pair, reason, opts) end
  _G.tech_priests_note_recovered_priest_0499 = function(pair, priest, reason) return M.note_recovered_priest(pair, priest, reason) end
  _G.tech_priests_priest_destruction_authorized_0499 = function(pair, priest, reason, opts) return M.destruction_authorized(pair, priest, reason, opts) end
  _G.tech_priests_destroy_priest_authorized_0499 = function(priest, reason, pair, opts) return M.destroy_priest_authorized(priest, reason, pair, opts) end
  disable_stuck_watchdog_roots()
  M.patch_orphan_purge()
  M.patch_respawn_and_recall()
  M.patch_mobility_upgrade_destroy()
  M.wrap_pair_dump()
  M.register_events()
  if not M.register_broker_service() then M.installed = false; return false end
  M.register_commands()
  if log then log("[Tech-Priests 0.1.674-dev] broker-owned lifecycle and re-imprint observation installed; only one-shot 0503 recovery leases are authorized") end
  return true
end

return M
