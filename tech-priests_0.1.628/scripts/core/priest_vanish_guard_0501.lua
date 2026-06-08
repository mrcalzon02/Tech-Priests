-- scripts/core/priest_vanish_guard_0501.lua
-- Tech Priests 0.1.501
--
-- Follow-up forensic guard after the 0.1.500 lifecycle seal proved that a
-- priest can become invalid while the paired Cogitator Station and pair record
-- remain alive, with no authorized/blocked destroy log and no removal event.
-- This pass does three things:
--   * places the late direct-mining beam services (0312/0315) behind the same
--     protected-target gate that 0490 applied to the older 0273 service;
--   * neutralizes acquisition/direct-gather movement distraction so non-combat
--     work commands cannot wander off into native unit AI side behavior;
--   * re-enables only controlled missing-priest rebind/respawn after logging the
--     failure, so the mod is testable instead of leaving a dead pair forever.

local M = {}
M.version = "0.1.501"
M.storage_key = "priest_vanish_guard_0501"
M.tick_interval = 31
M.respawn_backoff_ticks = 180
M.rebind_radius = 24

local PRIEST_NAMES = {
  ["junior-tech-priest"] = true,
  ["intermediate-tech-priest"] = true,
  ["senior-tech-priest"] = true,
  ["planetary-magos-tech-priest"] = true,
  ["void-tech-priest"] = true,
  ["junior-tech-priest-belt-immune"] = true,
  ["intermediate-tech-priest-belt-immune"] = true,
  ["senior-tech-priest-belt-immune"] = true,
  ["planetary-magos-tech-priest-belt-immune"] = true,
  ["void-tech-priest-belt-immune"] = true
}

local STATION_NAMES = {
  ["junior-cogitator-station"] = true,
  ["intermediate-cogitator-station"] = true,
  ["senior-cogitator-station"] = true,
  ["planetary-magos-cogitator-station"] = true,
  ["void-cogitator-station"] = true,
  ["tech-priest-small-arms-proxy"] = true,
  ["tech-priests-hidden-requester-cache"] = true,
  ["tech-priests-hidden-return-cache"] = true
}

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) local ok, out = pcall(function() return tostring(v) end); return ok and out or "?" end
local function lname(v) return string.lower(tostring(v or "")) end

local function tp_root()
  storage.tech_priests = storage.tech_priests or {}
  return storage.tech_priests
end

local function pair_map()
  local tp = storage and storage.tech_priests
  return tp and tp.pairs_by_station or {}
end

local function root()
  local tp = tp_root()
  local r = tp[M.storage_key] or { version = M.version, enabled = true, stats = {}, recent = {} }
  tp[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.controlled_respawn == nil then r.controlled_respawn = true end
  if r.harden_direct_mining == nil then r.harden_direct_mining = true end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  return r
end

local function unit_of(e) return valid(e) and e.unit_number or nil end
local function station_unit(pair) return pair and (pair.station_unit or unit_of(pair.station)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or unit_of(pair.priest)) or nil end

local function describe(e)
  if not valid(e) then return "invalid" end
  local p = e.position or { x = 0, y = 0 }
  return safe(e.name) .. "#" .. safe(e.unit_number) .. " type=" .. safe(e.type) .. " @" .. string.format("%.1f,%.1f", p.x or 0, p.y or 0)
end

local function record(action, pair, detail)
  local r = root()
  r.stats[action] = (r.stats[action] or 0) + 1
  local rec = { tick = now(), action = tostring(action or "event"), station = station_unit(pair), priest = priest_unit(pair), detail = tostring(detail or "") }
  r.recent[#r.recent + 1] = rec
  while #r.recent > 80 do table.remove(r.recent, 1) end
  if log then log("[Tech-Priests 0.1.501] " .. rec.action .. " station=" .. safe(rec.station) .. " priest=" .. safe(rec.priest) .. " " .. rec.detail) end
end

local function is_priest_name(name) return PRIEST_NAMES[tostring(name or "")] == true end
local function is_station_name(name) return STATION_NAMES[tostring(name or "")] == true or tostring(name or ""):find("cogitator%-station", 1, false) ~= nil end
local function is_priest_entity(e) return valid(e) and is_priest_name(e.name) end
local function is_protected_entity(e) return valid(e) and (is_priest_name(e.name) or is_station_name(e.name) or e.type == "unit" or e.type == "character") end

local function rank_from_pair(pair)
  local r = lname(pair and (pair.rank_key or pair.rank or pair.tier or pair.station and pair.station.name or pair.priest_name))
  if r:find("planetary") or r:find("magos") then return "planetary-magos" end
  if r:find("senior") then return "senior" end
  if r:find("intermediate") then return "intermediate" end
  if r:find("void") then return "void" end
  return "junior"
end

local function expected_priest_name(pair)
  if pair and pair.priest_name and prototypes and prototypes.entity and prototypes.entity[pair.priest_name] then return pair.priest_name end
  local rank = rank_from_pair(pair)
  local immune = pair and pair.station and pair.station.force and _G.force_has_priest_belt_immunity and _G.force_has_priest_belt_immunity(pair.station.force)
  if rank == "void" then return immune and "void-tech-priest-belt-immune" or "void-tech-priest" end
  if rank == "planetary-magos" then return immune and "planetary-magos-tech-priest-belt-immune" or "planetary-magos-tech-priest" end
  if rank == "senior" then return immune and "senior-tech-priest-belt-immune" or "senior-tech-priest" end
  if rank == "intermediate" then return immune and "intermediate-tech-priest-belt-immune" or "intermediate-tech-priest" end
  return immune and "junior-tech-priest-belt-immune" or "junior-tech-priest"
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
  pair.lifecycle_0501 = pair.lifecycle_0501 or {}
  pair.lifecycle_0501.last_valid_tick = now()
  pair.lifecycle_0501.last_valid_position = { x = pair.priest.position.x, y = pair.priest.position.y, surface = pair.priest.surface and pair.priest.surface.name or nil }
  pair.lifecycle_0501.last_repair_reason = tostring(reason or "repair")
  pcall(function() pair.priest.destructible = false end)
  pcall(function() pair.priest.active = true end)
  return true
end

local function clear_work_state_for_missing(pair)
  if not pair then return end
  pair.target = nil
  pair.combat_target = nil
  pair.active_task = nil
  pair.active_task_0285 = nil
  pair.current_task = nil
  pair.scavenge = nil
  pair.cram = nil
  pair.inventory_scan = nil
  pair.emergency_craft = nil
  pair.mining_lock_0315 = nil
  pair.direct_target_lease_0414 = nil
  pair.movement_request_0418 = nil
  pair.movement_lockdown_0416 = nil
  pair.movement_stabilizer_0417 = nil
  pair.recalling = nil
  pair.pending_recall = nil
  pair.force_recall = nil
  pair.stuck_since = nil
end

local function actual_direct_item(cur)
  if not cur then return nil end
  if cur.kind == "direct-dirt-0273" or cur.kind == "dirt" then return "stone" end
  local e = cur.entity
  if valid(e) then
    if e.type == "resource" then return e.name end
    if e.type == "tree" then return "wood" end
    if e.type == "simple-entity" or e.type == "simple-entity-with-owner" or e.type == "rock" then return "stone" end
  end
  return cur.item_name or cur.output_item or cur.wanted_item
end

local function is_safe_world_source(pair, e)
  if not valid(e) then return false end
  if is_protected_entity(e) then return false end
  if pair and valid(pair.station) and e == pair.station then return false end
  local t = e.type
  if t == "resource" or t == "tree" then return true end
  if t == "simple-entity" or t == "simple-entity-with-owner" or t == "rock" then
    if pair and valid(pair.station) and e.force and e.force == pair.station.force then return false end
    return true
  end
  return false
end

local function sanitize_direct_current(pair, task, source)
  if not (root().harden_direct_mining ~= false) then return true end
  local cur = task and task.current or nil
  if not cur then return true end
  if cur.kind ~= "direct-mine-0273" and cur.kind ~= "direct-dirt-0273" and cur.kind ~= "dirt" then return true end
  if cur.entity and cur.entity.valid and not is_safe_world_source(pair, cur.entity) then
    record("direct-current-cleared-protected-target", pair, "source=" .. safe(source) .. " target=" .. describe(cur.entity))
    task.current = nil
    task.direct_due_tick_0273 = nil
    task.direct_due_tick_0312 = nil
    task.direct_due_tick_0315 = nil
    task.next_direct_laser_tick_0312 = nil
    task.next_direct_laser_tick_0315 = nil
    if pair then pair.target = nil; pair.mining_lock_0315 = nil end
    return false
  end
  if cur.entity and cur.entity.valid then
    local actual = actual_direct_item(cur)
    if actual and cur.output_item and cur.output_item ~= actual then
      record("direct-current-output-normalized", pair, "source=" .. safe(source) .. " wanted=" .. safe(cur.output_item) .. " actual=" .. safe(actual) .. " target=" .. describe(cur.entity))
      cur.blocked_desired_output_0501 = cur.output_item
      cur.output_item = actual
      cur.item_name = actual
      cur.wanted_item = actual
    end
  elseif cur.kind == "direct-dirt-0273" or cur.kind == "dirt" then
    cur.output_item = "stone"
    cur.item_name = "stone"
    cur.wanted_item = "stone"
  end
  return true
end

local function sanitize_candidate(pair, cand, output, source)
  if cand and cand.entity and cand.entity.valid and not is_safe_world_source(pair, cand.entity) then
    record("direct-candidate-rejected-0501", pair, "source=" .. safe(source) .. " output=" .. safe(output) .. " target=" .. describe(cand.entity))
    return nil
  end
  if cand and cand.entity and cand.entity.valid then
    local actual = actual_direct_item(cand)
    if actual and cand.output_item and cand.output_item ~= actual then
      record("direct-candidate-output-normalized-0501", pair, "source=" .. safe(source) .. " output=" .. safe(output) .. " wanted=" .. safe(cand.output_item) .. " actual=" .. safe(actual))
      cand.blocked_desired_output_0501 = cand.output_item
      cand.output_item = actual
      cand.item_name = actual
      cand.wanted_item = actual
    end
  end
  return cand
end

function M.patch_direct_mining()
  if type(_G.tech_priests_0273_find_direct_target) == "function" and not rawget(_G, "TECH_PRIESTS_0501_PRE_FIND_DIRECT_TARGET") then
    _G.TECH_PRIESTS_0501_PRE_FIND_DIRECT_TARGET = _G.tech_priests_0273_find_direct_target
    _G.tech_priests_0273_find_direct_target = function(pair, output)
      local cand = _G.TECH_PRIESTS_0501_PRE_FIND_DIRECT_TARGET(pair, output)
      return sanitize_candidate(pair, cand, output, "0273-find")
    end
  end

  if type(_G.tech_priests_0273_service_direct_current) == "function" and not rawget(_G, "TECH_PRIESTS_0501_PRE_0273_SERVICE_DIRECT_CURRENT") then
    _G.TECH_PRIESTS_0501_PRE_0273_SERVICE_DIRECT_CURRENT = _G.tech_priests_0273_service_direct_current
    _G.tech_priests_0273_service_direct_current = function(pair, task)
      if not sanitize_direct_current(pair, task, "0273-service") then return false end
      return _G.TECH_PRIESTS_0501_PRE_0273_SERVICE_DIRECT_CURRENT(pair, task)
    end
  end

  if type(_G.tech_priests_0312_service_direct_current) == "function" and not rawget(_G, "TECH_PRIESTS_0501_PRE_0312_SERVICE_DIRECT_CURRENT") then
    _G.TECH_PRIESTS_0501_PRE_0312_SERVICE_DIRECT_CURRENT = _G.tech_priests_0312_service_direct_current
    _G.tech_priests_0312_service_direct_current = function(pair, task)
      if not sanitize_direct_current(pair, task, "0312-service") then return false end
      return _G.TECH_PRIESTS_0501_PRE_0312_SERVICE_DIRECT_CURRENT(pair, task)
    end
  end

  if type(_G.tech_priests_0315_service_direct_current) == "function" and not rawget(_G, "TECH_PRIESTS_0501_PRE_0315_SERVICE_DIRECT_CURRENT") then
    _G.TECH_PRIESTS_0501_PRE_0315_SERVICE_DIRECT_CURRENT = _G.tech_priests_0315_service_direct_current
    _G.tech_priests_0315_service_direct_current = function(pair, task)
      if not sanitize_direct_current(pair, task, "0315-service") then return false end
      return _G.TECH_PRIESTS_0501_PRE_0315_SERVICE_DIRECT_CURRENT(pair, task)
    end
  end

  if type(_G.tech_priests_0312_fire_laser) == "function" and not rawget(_G, "TECH_PRIESTS_0501_PRE_0312_FIRE_LASER") then
    _G.TECH_PRIESTS_0501_PRE_0312_FIRE_LASER = _G.tech_priests_0312_fire_laser
    _G.tech_priests_0312_fire_laser = function(priest, target, damage, reason, color)
      local reason_text = tostring(reason or "")
      local direct = reason_text:find("direct%-mining") or reason_text:find("direct%-dirt") or reason_text:find("mining")
      if direct and target and target.valid and not is_safe_world_source({ priest = priest, station = nil }, target) then
        record("direct-laser-blocked-protected-target", nil, "reason=" .. safe(reason) .. " priest=" .. describe(priest) .. " target=" .. describe(target))
        return false
      end
      return _G.TECH_PRIESTS_0501_PRE_0312_FIRE_LASER(priest, target, damage, reason, color)
    end
  end
end

function M.patch_movement_distraction()
  if type(_G.tech_priests_request_movement_0418) == "function" and not rawget(_G, "TECH_PRIESTS_0501_PRE_REQUEST_MOVEMENT") then
    _G.TECH_PRIESTS_0501_PRE_REQUEST_MOVEMENT = _G.tech_priests_request_movement_0418
    _G.tech_priests_request_movement_0418 = function(pair, destination, reason, opts)
      opts = opts or {}
      local r = tostring(reason or "")
      local owner = tostring(opts.owner or "")
      local noncombat = r:find("direct%-gather") or r:find("acquisition") or r:find("task%-lifecycle") or r:find("behavior%-contract") or r:find("action%-arbiter") or r:find("station%-craft") or owner:find("direct%-gather") or owner:find("acquisition")
      if noncombat and defines and defines.distraction then
        local copied = {}
        for k, v in pairs(opts) do copied[k] = v end
        opts = copied
        opts.distraction = defines.distraction.none
      end
      return _G.TECH_PRIESTS_0501_PRE_REQUEST_MOVEMENT(pair, destination, reason, opts)
    end
  end
end

local function find_pair_for_entity(e)
  if not valid(e) then return nil end
  if type(_G.find_pair_for_entity) == "function" then
    local ok, pair = pcall(_G.find_pair_for_entity, e)
    if ok and pair then return pair end
  end
  local tp = storage and storage.tech_priests
  if tp and e.unit_number then
    if tp.pairs_by_priest and tp.pairs_by_priest[e.unit_number] then return tp.pairs_by_priest[e.unit_number] end
    if tp.station_by_priest and tp.pairs_by_station and tp.station_by_priest[e.unit_number] then return tp.pairs_by_station[tp.station_by_priest[e.unit_number]] end
  end
  return nil
end

local function rebind_nearby_orphan(pair)
  if not (pair and valid(pair.station)) then return false end
  local surface = pair.station.surface
  local expected = expected_priest_name(pair)
  local area = {{ pair.station.position.x - M.rebind_radius, pair.station.position.y - M.rebind_radius }, { pair.station.position.x + M.rebind_radius, pair.station.position.y + M.rebind_radius }}
  local found = nil
  pcall(function()
    local entities = surface.find_entities_filtered({ area = area, name = expected, force = pair.station.force, limit = 12 })
    for _, e in pairs(entities or {}) do
      local owner = find_pair_for_entity(e)
      if valid(e) and (not owner or owner == pair) then found = e; break end
    end
  end)
  if not found then return false end
  pair.priest = found
  repair_reverse_maps(pair, "rebind-nearby-orphan-0501")
  record("rebound-nearby-orphan", pair, "entity=" .. describe(found))
  return true
end

local function create_replacement_priest(pair, reason)
  if not (pair and valid(pair.station)) then return false end
  local pname = expected_priest_name(pair)
  local surface = pair.station.surface
  if not (surface and surface.valid) then return false end
  local base = pair.lifecycle_0501 and pair.lifecycle_0501.last_valid_position or pair.lifecycle_0500 and pair.lifecycle_0500.last_valid_position
  local pos = { x = pair.station.position.x + 0.5, y = pair.station.position.y + 1.5 }
  if base and base.x and base.y and base.surface == surface.name then pos = { x = base.x, y = base.y } end
  local spawn = nil
  pcall(function() spawn = surface.find_non_colliding_position(pname, pos, 12, 0.25) end)
  spawn = spawn or pos
  local priest = nil
  local ok, err = pcall(function()
    priest = surface.create_entity({ name = pname, position = spawn, force = pair.station.force, raise_built = false })
  end)
  if not (ok and valid(priest)) then
    record("controlled-respawn-failed", pair, "reason=" .. safe(reason) .. " proto=" .. safe(pname) .. " error=" .. safe(err))
    return false
  end
  pair.priest = priest
  pair.priest_name = pname
  pair.mode = pair.mode == "re-imprinting" and "returning" or (pair.mode or "returning")
  pair.reimprint_0298 = nil
  pair.next_allowed_priest_respawn_tick = nil
  repair_reverse_maps(pair, "controlled-respawn-0501")
  clear_work_state_for_missing(pair)
  if type(_G.return_to_station) == "function" then pcall(_G.return_to_station, priest, pair.station) end
  record("controlled-respawn-created", pair, "reason=" .. safe(reason) .. " entity=" .. describe(priest))
  return true
end

function M.recover_missing_pair(pair, reason)
  if not (pair and valid(pair.station)) then return false end
  if valid(pair.priest) then return repair_reverse_maps(pair, "recover-valid-0501") end
  local r = root()
  record("missing-priest-detected-0501", pair, "reason=" .. safe(reason) .. " controlled_respawn=" .. safe(r.controlled_respawn))
  clear_work_state_for_missing(pair)
  if rebind_nearby_orphan(pair) then return true end
  if r.controlled_respawn == false then return false end
  pair.lifecycle_0501 = pair.lifecycle_0501 or {}
  if now() - (pair.lifecycle_0501.last_respawn_attempt or -1000000) < M.respawn_backoff_ticks then return false end
  pair.lifecycle_0501.last_respawn_attempt = now()

  local ok = false
  if type(_G.TECH_PRIESTS_0499_PRE_RESPAWN_PAIR_PRIEST) == "function" then
    local ok_call, result = pcall(_G.TECH_PRIESTS_0499_PRE_RESPAWN_PAIR_PRIEST, pair, "vanish-guard-0501:" .. tostring(reason or "missing"))
    ok = ok_call and result and valid(pair.priest)
    if ok then repair_reverse_maps(pair, "lower-respawn-0501"); record("controlled-respawn-via-lower-chain", pair, "reason=" .. safe(reason)); return true end
  end
  return create_replacement_priest(pair, reason)
end

function M.service_pair(pair)
  if not (pair and valid(pair.station)) then return false end
  if valid(pair.priest) then
    repair_reverse_maps(pair, "service-valid-0501")
    return true
  end
  return M.recover_missing_pair(pair, "service")
end

function M.service_all()
  if root().enabled == false then return false end
  for _, pair in pairs(pair_map()) do M.service_pair(pair) end
  return true
end

function M.patch_lifecycle_blocks()
  local link = rawget(_G, "TechPriestsPairLinkHardening0495")
  if link and not link.vanish_guard_wrapped_0501 then
    link.vanish_guard_wrapped_0501 = true
    link.service_pair = function(pair) return M.service_pair(pair) end
    link.service_all = function() return M.service_all() end
  end
  local safety = rawget(_G, "TechPriestsDirectMiningSafety0490")
  if safety and not safety.vanish_guard_wrapped_0501 then
    safety.vanish_guard_wrapped_0501 = true
    safety.rescue_missing_priests = function() return M.service_all() end
  end
  if type(_G.respawn_pair_priest) == "function" and not rawget(_G, "TECH_PRIESTS_0501_PRE_RESPAWN_PAIR_PRIEST") then
    _G.TECH_PRIESTS_0501_PRE_RESPAWN_PAIR_PRIEST = _G.respawn_pair_priest
    _G.respawn_pair_priest = function(pair, reason)
      if pair and valid(pair.priest) then repair_reverse_maps(pair, "respawn-request-valid-0501"); return true end
      return M.recover_missing_pair(pair, reason or "respawn-request")
    end
  end
  if type(_G.ensure_pair_priest) == "function" and not rawget(_G, "TECH_PRIESTS_0501_PRE_ENSURE_PAIR_PRIEST") then
    _G.TECH_PRIESTS_0501_PRE_ENSURE_PAIR_PRIEST = _G.ensure_pair_priest
    _G.ensure_pair_priest = function(pair, force_recall, immediate)
      if pair and valid(pair.priest) then repair_reverse_maps(pair, "ensure-valid-0501"); return true end
      return M.recover_missing_pair(pair, "ensure force=" .. safe(force_recall) .. " immediate=" .. safe(immediate))
    end
  end
end

function M.handle_removed(event)
  local e = event and event.entity
  local name = nil
  pcall(function() name = e and e.name end)
  if not is_priest_name(name) then return false end
  local pair = valid(e) and find_pair_for_entity(e) or nil
  record("priest-removal-event-seen-0501", pair, "event=" .. safe(event and event.name) .. " entity=" .. describe(e) .. " cause=" .. describe(event and event.cause))
  return false
end

function M.wrap_pair_dump()
  local diag = rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diag and type(diag.pair_dump_lines) == "function") or diag.vanish_guard_wrapped_0501 then return false end
  local prev = diag.pair_dump_lines
  diag.vanish_guard_wrapped_0501 = true
  diag.pair_dump_lines = function()
    local lines = prev()
    local r = root()
    lines[#lines + 1] = "PAIR-DUMP-0468 PRIEST-VANISH-GUARD-0501 BEGIN enabled=" .. safe(r.enabled) .. " controlled_respawn=" .. safe(r.controlled_respawn) .. " direct_blocks=" .. safe(r.stats["direct-current-cleared-protected-target"] or 0) .. " respawns=" .. safe(r.stats["controlled-respawn-created"] or 0)
    for _, pair in pairs(pair_map()) do
      if pair and valid(pair.station) then
        lines[#lines + 1] = "PAIR-DUMP-0468 vanish0501[pair " .. safe(station_unit(pair)) .. "] station=" .. describe(pair.station) .. " priest=" .. (valid(pair.priest) and describe(pair.priest) or "invalid") .. " last_valid=" .. safe(pair.lifecycle_0501 and pair.lifecycle_0501.last_valid_tick or "nil") .. " last_respawn_attempt=" .. safe(pair.lifecycle_0501 and pair.lifecycle_0501.last_respawn_attempt or "nil")
      end
    end
    for i = math.max(1, #r.recent - 18), #r.recent do
      local ev = r.recent[i]
      if ev then lines[#lines + 1] = "PAIR-DUMP-0468 vanish0501[" .. safe(i) .. "] tick=" .. safe(ev.tick) .. " action=" .. safe(ev.action) .. " station=" .. safe(ev.station) .. " priest=" .. safe(ev.priest) .. " " .. safe(ev.detail) end
    end
    lines[#lines + 1] = "PAIR-DUMP-0468 PRIEST-VANISH-GUARD-0501 END"
    return lines
  end
  return true
end

function M.register_events()
  local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not R then pcall(function() R = require("scripts.core.runtime_event_registry") end) end
  if R and defines and defines.events then
    R.on_event({ defines.events.on_entity_died, defines.events.script_raised_destroy, defines.events.on_pre_player_mined_item, defines.events.on_robot_pre_mined }, function(event) return M.handle_removed(event) end, nil, { owner = "priest_vanish_guard_0501", category = "pair-lifecycle", priority = "last" })
    R.on_nth_tick(M.tick_interval, function() M.service_all() end, { owner = "priest_vanish_guard_0501", category = "pair-lifecycle", priority = "last" })
  elseif script and script.on_nth_tick then
    pcall(function() script.on_nth_tick(M.tick_interval, function() M.service_all() end) end)
  end
end

function M.register_commands()
  if not commands then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-priest-vanish-0501") end end)
  commands.add_command("tp-priest-vanish-0501", "Tech Priests 0.1.501: priest vanish guard. Usage: status|all|on|off|respawn-on|respawn-off", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local p = lname(event and event.parameter or "status")
    local r = root()
    if p == "on" then r.enabled = true end
    if p == "off" then r.enabled = false end
    if p == "respawn-on" then r.controlled_respawn = true end
    if p == "respawn-off" then r.controlled_respawn = false end
    if p == "all" then M.service_all() end
    if player and player.valid then
      player.print("[tp-priest-vanish-0501] enabled=" .. safe(r.enabled) .. " controlled_respawn=" .. safe(r.controlled_respawn) .. " respawns=" .. safe(r.stats["controlled-respawn-created"] or 0) .. " direct_blocks=" .. safe(r.stats["direct-current-cleared-protected-target"] or 0))
      for i = math.max(1, #r.recent - 8), #r.recent do
        local ev = r.recent[i]
        if ev then player.print("[tp-priest-vanish-0501] tick=" .. safe(ev.tick) .. " " .. safe(ev.action) .. " station=" .. safe(ev.station) .. " priest=" .. safe(ev.priest) .. " " .. safe(ev.detail)) end
      end
    end
  end)
end

function M.install()
  if M.installed then return true end
  M.installed = true
  root()
  _G.TechPriestsPriestVanishGuard0501 = M
  M.patch_direct_mining()
  M.patch_movement_distraction()
  M.patch_lifecycle_blocks()
  M.wrap_pair_dump()
  M.register_events()
  M.register_commands()
  M.service_all()
  if log then log("[Tech-Priests 0.1.501] priest vanish guard installed; late direct mining sealed and controlled missing-priest respawn enabled") end
  return true
end

return M
