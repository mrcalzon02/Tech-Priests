-- scripts/core/priest_recovery_safety_0503.lua
-- Tech Priests 0.1.503
--
-- Recovery stabilization pass after the 0.1.502 station-side acquisition test
-- stopped the visible Tech-Priest vanish loop.  This module keeps the 0.1.502
-- native-unit movement quarantine for direct emergency acquisition, but reopens
-- legitimate pair safety systems: watchdog roots, missing-priest rescue,
-- recall/teleport recovery, and the authorized belt-immunity mobility swap.
-- It does not reopen arbitrary priest destruction; only station cleanup and the
-- explicit belt-immunity replacement rite may remove an old visible priest.

local M = {}
M.version = "0.1.503"
M.storage_key = "priest_recovery_safety_0503"
M.tick_interval = 41
M.rebind_radius = 32
M.teleport_distance_sq = 96 * 96
M.max_per_tick = 24

local PRIEST_BY_RANK = {
  junior = { normal = "junior-tech-priest", immune = "junior-tech-priest-belt-immune" },
  intermediate = { normal = "intermediate-tech-priest", immune = "intermediate-tech-priest-belt-immune" },
  senior = { normal = "senior-tech-priest", immune = "senior-tech-priest-belt-immune" },
  ["planetary-magos"] = { normal = "planetary-magos-tech-priest", immune = "planetary-magos-tech-priest-belt-immune" },
  void = { normal = "void-tech-priest", immune = "void-tech-priest-belt-immune" }
}

local STATION_TO_RANK = {
  ["junior-cogitator-station"] = "junior",
  ["intermediate-cogitator-station"] = "intermediate",
  ["senior-cogitator-station"] = "senior",
  ["planetary-magos-cogitator-station"] = "planetary-magos",
  ["void-cogitator-station"] = "void"
}

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) local ok, out = pcall(function() return tostring(v) end); return ok and out or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function tp_root() storage.tech_priests = storage.tech_priests or {}; return storage.tech_priests end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function stat(k, n) local r = M.root(); r.stats[k] = (r.stats[k] or 0) + (n or 1) end

function M.root()
  local tp = tp_root()
  local r = tp[M.storage_key] or { version = M.version, enabled = true, stats = {}, recent = {} }
  tp[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.restore_watchdogs == nil then r.restore_watchdogs = true end
  if r.recovery_teleports == nil then r.recovery_teleports = true end
  if r.authorized_mobility_swap == nil then r.authorized_mobility_swap = true end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  return r
end

local function station_unit(pair)
  return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil
end

local function priest_unit(pair)
  return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil
end

local function record(action, pair, detail)
  local r = M.root()
  stat(action)
  local rec = { tick = now(), action = tostring(action or "event"), station = station_unit(pair), priest = priest_unit(pair), detail = tostring(detail or "") }
  r.recent[#r.recent + 1] = rec
  while #r.recent > 96 do table.remove(r.recent, 1) end
  if log then log("[Tech-Priests 0.1.503] " .. rec.action .. " station=" .. safe(rec.station) .. " priest=" .. safe(rec.priest) .. " " .. rec.detail) end
end

local function describe(e)
  if not valid(e) then return "invalid" end
  local p = e.position or { x = 0, y = 0 }
  return safe(e.name) .. "#" .. safe(e.unit_number) .. " type=" .. safe(e.type) .. " @" .. string.format("%.1f,%.1f", p.x or 0, p.y or 0)
end

local function dist_sq(a, b)
  if not (a and b) then return nil end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end

local function is_priest_name(name)
  name = tostring(name or "")
  return name:find("tech%-priest", 1, false) ~= nil and name:find("cogitator", 1, false) == nil
end

local function is_priest_entity(e)
  if not valid(e) then return false end
  if type(_G.is_priest) == "function" then local ok, yes = pcall(_G.is_priest, e); if ok and yes then return true end end
  return is_priest_name(e.name)
end

local function find_pair_for_entity_local(e)
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

local function rank_from_pair(pair)
  local text = lower(pair and (pair.rank_key or pair.rank or pair.tier or pair.priest_name or ""))
  if text:find("planetary", 1, false) or text:find("magos", 1, false) then return "planetary-magos" end
  if text:find("senior", 1, false) then return "senior" end
  if text:find("intermediate", 1, false) then return "intermediate" end
  if text:find("void", 1, false) then return "void" end
  if valid(pair and pair.station) and STATION_TO_RANK[pair.station.name] then return STATION_TO_RANK[pair.station.name] end
  if valid(pair and pair.priest) then
    local n = pair.priest.name
    if n:find("planetary%-magos", 1, false) then return "planetary-magos" end
    if n:find("senior", 1, false) then return "senior" end
    if n:find("intermediate", 1, false) then return "intermediate" end
    if n:find("void", 1, false) then return "void" end
  end
  return "junior"
end

local function force_has_belt_immunity(force)
  if type(_G.force_has_priest_belt_immunity) == "function" then
    local ok, yes = pcall(_G.force_has_priest_belt_immunity, force)
    if ok then return yes == true end
  end
  if not (force and force.valid and force.technologies) then return false end
  local tech = force.technologies[rawget(_G, "TECH_PRIEST_BELT_IMMUNITY_TECH") or "belt-immunity-equipment"]
  return tech and tech.researched == true
end

local function desired_priest_name(pair, immune_override)
  if not valid(pair and pair.station) then return nil end
  if type(_G.get_station_config) == "function" and type(_G.get_priest_name_for_force) == "function" and immune_override == nil then
    local ok, name = pcall(function() return _G.get_priest_name_for_force(_G.get_station_config(pair.station), pair.station.force) end)
    if ok and name then return name end
  end
  local rank = rank_from_pair(pair)
  local names = PRIEST_BY_RANK[rank] or PRIEST_BY_RANK.junior
  local immune = immune_override
  if immune == nil then immune = force_has_belt_immunity(pair.station.force) end
  return immune and names.immune or names.normal
end

local function repair_reverse_maps(pair, reason)
  if not (pair and valid(pair.station) and valid(pair.priest)) then return false end
  local tp = tp_root()
  tp.pairs_by_station = tp.pairs_by_station or {}
  tp.pairs_by_priest = tp.pairs_by_priest or {}
  tp.station_by_priest = tp.station_by_priest or {}
  pair.station_unit = pair.station.unit_number
  pair.priest_unit = pair.priest.unit_number
  pair.priest_name = pair.priest.name
  tp.pairs_by_station[pair.station.unit_number] = pair
  tp.pairs_by_priest[pair.priest.unit_number] = pair
  tp.station_by_priest[pair.priest.unit_number] = pair.station.unit_number
  pair.lifecycle_0503 = pair.lifecycle_0503 or {}
  pair.lifecycle_0503.last_valid_tick = now()
  pair.lifecycle_0503.last_valid_position = { x = pair.priest.position.x, y = pair.priest.position.y, surface = pair.priest.surface and pair.priest.surface.name or nil }
  pair.lifecycle_0503.last_repair_reason = tostring(reason or "repair")
  pair.paused_by_missing_priest_0498 = nil
  pair.lost_priest_0490 = nil
  if pair.link_0495 then pair.link_0495.missing_since = nil; pair.link_0495.rescue_disabled_0499 = nil end
  pcall(function() pair.priest.destructible = false end)
  pcall(function() pair.priest.active = true end)
  return true
end

local function unpause_order(pair, reason)
  if not pair then return false end
  local changed = false
  local q = pair.order_queue_0469
  if q and q.current and q.current.status == "paused-missing-priest" then
    q.current.status = "active"
    q.current.paused_tick = nil
    q.current.pause_reason = nil
    pair.active_order_0469 = q.current
    changed = true
  end
  if pair.active_order_0469 and pair.active_order_0469.status == "paused-missing-priest" then
    pair.active_order_0469.status = "active"
    pair.active_order_0469.paused_tick = nil
    pair.active_order_0469.pause_reason = nil
    changed = true
  end
  if changed then record("order-unpaused-0503", pair, "reason=" .. safe(reason)) end
  return changed
end

local function anchor_position(pair, proto_name)
  if not valid(pair and pair.station) then return nil end
  local surface = pair.station.surface
  local base = { x = pair.station.position.x + 0.45, y = pair.station.position.y + 1.45 }
  if surface and surface.find_non_colliding_position then
    local ok, pos = pcall(function() return surface.find_non_colliding_position(proto_name or desired_priest_name(pair) or "character", base, 8, 0.25) end)
    if ok and pos then return pos end
  end
  return base
end

local function stop_priest(pair)
  if not valid(pair and pair.priest) then return false end
  pcall(function()
    if pair.priest.commandable and pair.priest.commandable.valid then
      pair.priest.commandable.set_command({ type = defines.command.stop })
    else
      pair.priest.set_command({ type = defines.command.stop })
    end
  end)
  return true
end

local function teleport_to_station(pair, reason)
  if not (M.root().recovery_teleports ~= false and valid(pair and pair.station) and valid(pair.priest)) then return false end
  local pos = anchor_position(pair, pair.priest.name)
  if not pos then return false end
  local ok = false
  pcall(function() ok = pair.priest.teleport(pos, pair.station.surface) end)
  stop_priest(pair)
  pair.movement_request_0418 = nil
  pair.pathing_target_0418 = nil
  pair.recalling = nil
  pair.pending_recall = nil
  pair.force_recall = nil
  pair.stuck_since = nil
  repair_reverse_maps(pair, "teleport-" .. tostring(reason or "recovery"))
  record("recovery-teleport-0503", pair, "reason=" .. safe(reason) .. " ok=" .. safe(ok))
  return ok
end

local function priest_bound_elsewhere(entity, own_pair)
  if not valid(entity) then return false end
  local tp = storage and storage.tech_priests or nil
  local other = tp and tp.pairs_by_priest and tp.pairs_by_priest[entity.unit_number] or nil
  return other ~= nil and other ~= own_pair
end

local function rebind_nearby(pair, reason)
  if not valid(pair and pair.station) then return false end
  local pname = desired_priest_name(pair)
  if not pname then return false end
  local surface = pair.station.surface
  local pos = pair.station.position
  local r = M.rebind_radius
  local found = nil
  pcall(function()
    local entities = surface.find_entities_filtered({ area = {{pos.x-r, pos.y-r}, {pos.x+r, pos.y+r}}, name = pname, force = pair.station.force, limit = 24 })
    local best, best_d = nil, nil
    for _, e in pairs(entities or {}) do
      if valid(e) and not priest_bound_elsewhere(e, pair) then
        local d = dist_sq(e.position, pos) or 0
        if not best_d or d < best_d then best, best_d = e, d end
      end
    end
    found = best
  end)
  if not found then return false end
  pair.priest = found
  repair_reverse_maps(pair, "rebind-nearby-0503")
  unpause_order(pair, "rebind-nearby-0503")
  record("rebound-nearby-orphan-0503", pair, "reason=" .. safe(reason) .. " entity=" .. describe(found))
  return true
end

local function create_priest(pair, reason)
  if not valid(pair and pair.station) then return false end
  local pname = desired_priest_name(pair)
  if not pname then return false end
  local surface = pair.station.surface
  if not (surface and surface.valid) then return false end
  local pos = anchor_position(pair, pname)
  local priest = nil
  local ok, err = pcall(function()
    priest = surface.create_entity({ name = pname, position = pos or pair.station.position, force = pair.station.force, quality = pair.station.quality and pair.station.quality.name or nil, raise_built = false })
  end)
  if not (ok and valid(priest)) then
    record("rescue-respawn-failed-0503", pair, "reason=" .. safe(reason) .. " proto=" .. safe(pname) .. " error=" .. safe(err))
    return false
  end
  pair.priest = priest
  pair.priest_name = pname
  pair.mode = pair.mode == "re-imprinting" and "returning" or (pair.mode or "returning")
  pair.target = pair.station
  pair.combat_target = nil
  pair.reimprint_0298 = nil
  pair.next_allowed_priest_respawn_tick = nil
  repair_reverse_maps(pair, "rescue-respawn-0503")
  unpause_order(pair, "rescue-respawn-0503")
  if type(_G.apply_pair_display_names) == "function" then pcall(_G.apply_pair_display_names, pair) end
  if type(_G.return_to_station) == "function" then pcall(_G.return_to_station, priest, pair.station) end
  record("rescue-respawn-created-0503", pair, "reason=" .. safe(reason) .. " entity=" .. describe(priest))
  return true
end

function M.ensure_pair_priest(pair, force_recall, immediate, reason)
  if not valid(pair and pair.station) then return false end
  if valid(pair.priest) then
    repair_reverse_maps(pair, "ensure-valid-0503")
    unpause_order(pair, "ensure-valid-0503")
    local d2 = dist_sq(pair.priest.position, pair.station.position) or 0
    if force_recall or immediate or pair.recalling or pair.pending_recall or pair.force_recall or d2 > M.teleport_distance_sq then
      teleport_to_station(pair, reason or "ensure")
    end
    return true
  end
  record("missing-priest-recovery-0503", pair, "reason=" .. safe(reason) .. " force_recall=" .. safe(force_recall) .. " immediate=" .. safe(immediate))
  if rebind_nearby(pair, reason or "ensure") then return true end
  return create_priest(pair, reason or "ensure")
end

local function restore_watchdog_roots()
  if M.root().restore_watchdogs == false then return false end
  local tp = tp_root()
  tp.acquisition_repair_0337 = tp.acquisition_repair_0337 or { stats = {} }
  tp.task_execution_sound_governor_0477 = tp.task_execution_sound_governor_0477 or { stats = {} }
  if tp.acquisition_repair_0337.enabled ~= true then tp.acquisition_repair_0337.enabled = true; record("watchdog-root-enabled-0503", nil, "acquisition_repair_0337") end
  if tp.task_execution_sound_governor_0477.enabled ~= true then tp.task_execution_sound_governor_0477.enabled = true; record("watchdog-root-enabled-0503", nil, "task_execution_sound_governor_0477") end
  return true
end

local function clear_quarantine_flags(pair)
  if not pair then return false end
  local changed = false
  for _, key in ipairs({ "respawn_disabled_0499", "ensure_disabled_0499", "paused_by_missing_priest_0498", "missing_priest_rescue_0490", "lost_priest_0490" }) do
    if pair[key] ~= nil then pair[key] = nil; changed = true end
  end
  if pair.link_0495 and pair.link_0495.rescue_disabled_0499 ~= nil then pair.link_0495.rescue_disabled_0499 = nil; changed = true end
  return changed
end

function M.service_pair(pair)
  if M.root().enabled == false then return false end
  if not valid(pair and pair.station) then return false end
  clear_quarantine_flags(pair)
  if not M.ensure_pair_priest(pair, false, false, "service") then return false end
  return true
end

function M.service_all()
  if M.root().enabled == false then return false end
  restore_watchdog_roots()
  local n = 0
  for _, pair in pairs(pair_map()) do
    pcall(function()
      if M.service_pair(pair) then n = n + 1 end
    end)
    if n >= M.max_per_tick then break end
  end
  return true
end

local function set_health_ratio(entity, ratio)
  if not valid(entity) then return end
  ratio = math.max(0.01, math.min(1, tonumber(ratio) or 1))
  pcall(function() entity.health = math.max(1, (entity.prototype.max_health or entity.health or 1) * ratio) end)
end

local function get_health_ratio(entity)
  if not valid(entity) then return 1 end
  local max = nil
  pcall(function() max = entity.prototype and entity.prototype.max_health end)
  max = tonumber(max) or tonumber(entity.health) or 1
  return math.max(0.01, math.min(1, (tonumber(entity.health) or max) / math.max(1, max)))
end

local function safe_destroy_old_for_mobility(pair, old_priest)
  if not valid(old_priest) then return true end
  pair.lifecycle_0503 = pair.lifecycle_0503 or {}
  pair.lifecycle_0503.authorized_mobility_destroy_until = now() + 5
  pair.lifecycle_0503.authorized_mobility_destroy_unit = old_priest.unit_number
  if pair.lifecycle_0500 then
    pair.lifecycle_0500.allow_priest_destroy_until = now() + 5
    pair.lifecycle_0500.allow_priest_destroy_reason = "authorized-mobility-swap-0503"
  end
  local ok = false
  if type(_G.tech_priests_destroy_priest_0500) == "function" then
    pcall(function() ok = _G.tech_priests_destroy_priest_0500(old_priest, "authorized-mobility-swap-0503", pair, { allow_station_cleanup = true }) end)
  else
    pcall(function() old_priest.destroy({ raise_destroy = false }) ok = true end)
  end
  record("authorized-mobility-old-priest-destroy-0503", pair, "old=" .. safe(pair.lifecycle_0503.authorized_mobility_destroy_unit) .. " ok=" .. safe(ok))
  return ok
end

function M.upgrade_pair_priest_to_current_mobility(pair, reason)
  if M.root().authorized_mobility_swap == false then return false end
  if not (pair and valid(pair.station)) then return false end
  if not valid(pair.priest) then return M.ensure_pair_priest(pair, true, true, reason or "mobility-missing") end
  local desired = desired_priest_name(pair)
  if not desired or pair.priest.name == desired then
    repair_reverse_maps(pair, "mobility-current-0503")
    return false
  end

  local old = pair.priest
  local old_unit = old.unit_number
  local ratio = get_health_ratio(old)
  local dir = old.direction
  local pos = old.position
  local surface = pair.station.surface
  local spawn = nil
  pcall(function()
    if surface.can_place_entity({ name = desired, position = pos, force = pair.station.force }) then spawn = pos end
  end)
  if not spawn then spawn = anchor_position(pair, desired) or pos end

  local new_priest = nil
  local ok, err = pcall(function()
    new_priest = surface.create_entity({ name = desired, position = spawn, direction = dir, force = pair.station.force, quality = pair.station.quality and pair.station.quality.name or nil, raise_built = false })
  end)
  if not (ok and valid(new_priest)) then
    record("mobility-swap-create-failed-0503", pair, "desired=" .. safe(desired) .. " error=" .. safe(err))
    return false
  end

  set_health_ratio(new_priest, ratio)
  pcall(function() new_priest.destructible = false end)
  pcall(function() new_priest.active = true end)
  pair.priest = new_priest
  pair.priest_name = desired
  pair.priest_unit = new_priest.unit_number
  pair.mode = "returning"
  pair.target = pair.station
  pair.combat_target = nil
  local tp = tp_root()
  tp.pairs_by_priest = tp.pairs_by_priest or {}
  tp.station_by_priest = tp.station_by_priest or {}
  if old_unit then tp.pairs_by_priest[old_unit] = nil; tp.station_by_priest[old_unit] = nil end
  repair_reverse_maps(pair, "mobility-swap-0503")
  if type(_G.apply_pair_display_names) == "function" then pcall(_G.apply_pair_display_names, pair) end
  if type(_G.tech_priests_0302_refresh_pair_fixed_armor) == "function" then pcall(_G.tech_priests_0302_refresh_pair_fixed_armor, pair, "mobility-swap-0503") end
  if type(_G.tech_priests_0305_refresh_pair_equipment) == "function" then pcall(_G.tech_priests_0305_refresh_pair_equipment, pair, "mobility-swap-0503") end
  if type(_G.return_to_station) == "function" then pcall(_G.return_to_station, new_priest, pair.station) end
  safe_destroy_old_for_mobility(pair, old)
  record("mobility-swap-complete-0503", pair, "old=" .. safe(old_unit) .. " new=" .. safe(new_priest.unit_number) .. " desired=" .. safe(desired) .. " reason=" .. safe(reason))
  return true
end

function M.upgrade_force_priests_to_current_mobility(force)
  local count = 0
  for _, pair in pairs(pair_map()) do
    if pair and valid(pair.station) and (not force or pair.station.force == force) then
      if M.upgrade_pair_priest_to_current_mobility(pair, "force-upgrade") then count = count + 1 end
    end
  end
  record("force-mobility-upgrade-0503", nil, "force=" .. safe(force and force.name) .. " swaps=" .. safe(count))
  return true
end

local function patch_global_recovery()
  _G.respawn_pair_priest = function(pair, reason)
    return M.ensure_pair_priest(pair, true, true, reason or "respawn-request")
  end
  _G.ensure_pair_priest = function(pair, force_recall, immediate)
    return M.ensure_pair_priest(pair, force_recall, immediate, "ensure-request")
  end
  _G.sanity_recall_all_priests = function(force_recall)
    for _, pair in pairs(pair_map()) do
      if pair and valid(pair.station) then M.ensure_pair_priest(pair, force_recall ~= false, true, "sanity-recall") end
    end
    return true
  end
  _G.upgrade_pair_priest_to_current_mobility = function(pair) return M.upgrade_pair_priest_to_current_mobility(pair, "global-call") end
  _G.upgrade_force_priests_to_current_mobility = function(force) return M.upgrade_force_priests_to_current_mobility(force) end
end

local function patch_quarantine_modules()
  local life499 = rawget(_G, "TechPriestsPriestLifecycleAuthority0499")
  if life499 then
    life499.service_pair = function(pair) return M.service_pair(pair) end
    life499.service_all = function() return M.service_all() end
  end
  local seal500 = rawget(_G, "TechPriestsPriestLifecycleSeal0500")
  if seal500 then
    seal500.service_pair = function(pair) return M.service_pair(pair) end
    seal500.service_all = function() return M.service_all() end
  end
  local guard501 = rawget(_G, "TechPriestsPriestVanishGuard0501")
  if guard501 then
    guard501.service_pair = function(pair) return M.service_pair(pair) end
    guard501.service_all = function() return M.service_all() end
  end
  local link495 = rawget(_G, "TechPriestsPairLinkHardening0495")
  if link495 then
    link495.service_pair = function(pair) return M.service_pair(pair) end
    link495.service_all = function() return M.service_all() end
  end
  local safety490 = rawget(_G, "TechPriestsDirectMiningSafety0490")
  if safety490 then
    safety490.rescue_missing_priests = function() return M.service_all() end
  end
end

local function wrap_pair_dump()
  local diag = rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diag and type(diag.pair_dump_lines) == "function") or diag.priest_recovery_safety_wrapped_0503 then return false end
  local prev = diag.pair_dump_lines
  diag.priest_recovery_safety_wrapped_0503 = true
  diag.pair_dump_lines = function()
    local lines = prev()
    local r = M.root()
    lines[#lines + 1] = "PAIR-DUMP-0468 PRIEST-RECOVERY-SAFETY-0503 BEGIN enabled=" .. safe(r.enabled)
      .. " restore_watchdogs=" .. safe(r.restore_watchdogs)
      .. " recovery_teleports=" .. safe(r.recovery_teleports)
      .. " mobility_swap=" .. safe(r.authorized_mobility_swap)
      .. " respawns=" .. safe(r.stats["rescue-respawn-created-0503"] or 0)
      .. " teleports=" .. safe(r.stats["recovery-teleport-0503"] or 0)
      .. " swaps=" .. safe(r.stats["mobility-swap-complete-0503"] or 0)
    for _, pair in pairs(pair_map()) do
      if pair and valid(pair.station) then
        local d = valid(pair.priest) and math.sqrt(dist_sq(pair.priest.position, pair.station.position) or 0) or nil
        lines[#lines + 1] = "PAIR-DUMP-0468 recovery0503[" .. safe(pair.station.unit_number) .. "] station=" .. describe(pair.station)
          .. " priest=" .. (valid(pair.priest) and describe(pair.priest) or "invalid")
          .. " desired=" .. safe(desired_priest_name(pair))
          .. " dist=" .. safe(d and string.format("%.1f", d) or "nil")
          .. " order=" .. safe(pair.order_queue_0469 and pair.order_queue_0469.current and pair.order_queue_0469.current.status or "none")
      end
    end
    for i = math.max(1, #r.recent - 12), #r.recent do
      local ev = r.recent[i]
      if ev then lines[#lines + 1] = "PAIR-DUMP-0468 recovery0503[" .. safe(i) .. "] tick=" .. safe(ev.tick) .. " action=" .. safe(ev.action) .. " station=" .. safe(ev.station) .. " priest=" .. safe(ev.priest) .. " " .. safe(ev.detail) end
    end
    lines[#lines + 1] = "PAIR-DUMP-0468 PRIEST-RECOVERY-SAFETY-0503 END"
    return lines
  end
  return true
end

local function commands_install()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-priest-recovery-0503") end end)
  commands.add_command("tp-priest-recovery-0503", "Tech Priests 0.1.503: recovery safety status/all/recall/mobility/on/off.", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local p = lower(event and event.parameter or "status")
    local r = M.root()
    if p == "on" then r.enabled = true end
    if p == "off" then r.enabled = false end
    if p == "watchdogs-on" then r.restore_watchdogs = true end
    if p == "watchdogs-off" then r.restore_watchdogs = false end
    if p == "teleports-on" then r.recovery_teleports = true end
    if p == "teleports-off" then r.recovery_teleports = false end
    if p == "mobility-on" then r.authorized_mobility_swap = true end
    if p == "mobility-off" then r.authorized_mobility_swap = false end
    if p == "all" or p == "rescue" then M.service_all() end
    if p == "recall" then for _, pair in pairs(pair_map()) do if pair and valid(pair.station) then M.ensure_pair_priest(pair, true, true, "debug-recall") end end end
    if p == "mobility" then M.upgrade_force_priests_to_current_mobility(player and player.force or nil) end
    local msg = "[tp-priest-recovery-0503] enabled=" .. safe(r.enabled)
      .. " watchdogs=" .. safe(r.restore_watchdogs)
      .. " teleports=" .. safe(r.recovery_teleports)
      .. " mobility=" .. safe(r.authorized_mobility_swap)
      .. " respawns=" .. safe(r.stats["rescue-respawn-created-0503"] or 0)
      .. " teleports_done=" .. safe(r.stats["recovery-teleport-0503"] or 0)
      .. " swaps=" .. safe(r.stats["mobility-swap-complete-0503"] or 0)
    if player and player.valid then player.print(msg) elseif log then log(msg) end
  end)
end

function M.install()
  M.root()
  _G.TechPriestsPriestRecoverySafety0503 = M
  patch_global_recovery()
  patch_quarantine_modules()
  wrap_pair_dump()
  commands_install()
  restore_watchdog_roots()
  M.service_all()
  if script and script.on_nth_tick then script.on_nth_tick(M.tick_interval, M.service_all) end
  if log then log("[Tech-Priests 0.1.503] recovery safety restored; watchdog roots enabled, missing-priest teleport/respawn active, and belt-immunity mobility swap authorized") end
  return true
end

return M
