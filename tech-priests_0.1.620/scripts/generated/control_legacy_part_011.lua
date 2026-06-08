-- Auto-split control.lua fragment 011 for Tech Priests 0.1.438.
-- Generated mechanically from 0.1.437 monolithic control.lua.
-- Purpose: reduce Lua main-chunk local/register pressure without deleting behavior.


function tech_priests_lifecycle_surface_label_0202(pair, entity)
  local e = entity and entity.valid and entity or (pair and pair.priest and pair.priest.valid and pair.priest) or (pair and pair.station and pair.station.valid and pair.station) or nil
  if e and e.valid and e.surface then return e.surface.name end
  if pair and pair.surface then return tostring(pair.surface) end
  return "unknown-surface"
end

function tech_priests_lifecycle_task_label_0202(pair)
  if not pair then return "task=?" end
  local task = nil
  if tech_priests_task_summary_0189 then pcall(function() task = tech_priests_task_summary_0189(pair) end) end
  if not task then task = pair.mode or "idle" end
  return tostring(task)
end

function tech_priests_lifecycle_line_0202(kind, pair, entity, extra)
  local surface = tech_priests_lifecycle_surface_label_0202(pair, entity)
  local subject = entity and entity.valid and entity or (pair and pair.priest and pair.priest.valid and pair.priest) or (pair and pair.station and pair.station.valid and pair.station) or nil
  local position = tech_priests_lifecycle_safe_coord_0202(subject)
  return "[Tech-Priest Lifecycle][tick " .. tostring(game and game.tick or 0) .. "][" .. tostring(surface) .. " @ " .. tostring(position) .. "][" .. tostring(kind or "trace") .. "] " .. tech_priests_lifecycle_station_label_0202(pair) .. " " .. tech_priests_lifecycle_priest_label_0202(pair, entity) .. " task=\"" .. tech_priests_lifecycle_task_label_0202(pair) .. "\"" .. (extra and extra ~= "" and (" :: " .. tostring(extra)) or "")
end

function tech_priests_lifecycle_try_write_file_0203(line)
  if not TECH_PRIESTS_LIFECYCLE_FILE_ENABLED_0202 then return false end
  local wrote = false

  -- Factorio 2.x exposes file output through helpers.write_file.  Do not probe
  -- LuaGameScript.write_file directly; some runtimes throw on missing keys.
  if helpers then
    local ok_get, writer = pcall(function() return helpers.write_file end)
    if ok_get and writer then
      local ok_write = pcall(function() writer(TECH_PRIESTS_LIFECYCLE_LOG_FILE_0202, line .. "\n", true) end)
      wrote = ok_write or wrote
    end
  end

  -- Older runtimes may still provide game.write_file.  Probe it only inside
  -- pcall so a missing API member cannot crash configuration migration.
  if not wrote and game then
    local ok_get, writer = pcall(function() return game.write_file end)
    if ok_get and writer then
      local ok_write = pcall(function() writer(TECH_PRIESTS_LIFECYCLE_LOG_FILE_0202, line .. "\n", true) end)
      wrote = ok_write or wrote
    end
  end

  return wrote
end

function tech_priests_lifecycle_emit_0202(kind, pair, entity, extra)
  if not TECH_PRIESTS_LIFECYCLE_TRACE_ENABLED_0202 then return end
  local line = tech_priests_lifecycle_line_0202(kind, pair, entity, extra)
  if log then pcall(function() log(line) end) end
  tech_priests_lifecycle_try_write_file_0203(line)
end

function tech_priests_lifecycle_bucket_0202()
  ensure_storage()
  storage.tech_priests.priest_lifecycle_debug_0201 = storage.tech_priests.priest_lifecycle_debug_0201 or {}
  return storage.tech_priests.priest_lifecycle_debug_0201
end

-- Redefine the 0.1.201 note function so every note also reaches the real log.
function tech_priests_lifecycle_note_0201(pair, reason, entity, extra)
  local bucket = tech_priests_lifecycle_bucket_0202()
  local station = pair and pair.station and pair.station.valid and pair.station or nil
  local subject = entity and entity.valid and entity or (pair and pair.priest and pair.priest.valid and pair.priest) or station
  bucket[#bucket + 1] = {
    tick = game and game.tick or 0,
    reason = tostring(reason or "unknown"),
    station_unit = pair and pair.station_unit or (station and station.unit_number) or nil,
    priest_unit = subject and subject.valid and subject.unit_number or (pair and pair.priest_unit) or nil,
    surface = subject and subject.valid and subject.surface and subject.surface.name or station and station.surface and station.surface.name or "unknown",
    position = subject and subject.valid and { x = subject.position.x, y = subject.position.y } or nil,
    extra = tostring(extra or "")
  }
  while #bucket > TECH_PRIESTS_LIFECYCLE_DEBUG_LIMIT_0202 do table.remove(bucket, 1) end
  tech_priests_lifecycle_emit_0202(reason or "note", pair, entity, extra)
end

function tech_priests_lifecycle_snapshot_0202(pair)
  if not pair then return "nil-pair" end
  local priest = pair.priest and pair.priest.valid and pair.priest or nil
  local station = pair.station and pair.station.valid and pair.station or nil
  local priest_unit = priest and priest.unit_number or pair.priest_unit or "missing"
  local station_unit = station and station.unit_number or pair.station_unit or "missing"
  local surface = tech_priests_lifecycle_surface_label_0202(pair, priest or station)
  local priest_pos = priest and tech_priests_lifecycle_safe_coord_0202(priest) or "missing"
  local station_pos = station and tech_priests_lifecycle_safe_coord_0202(station) or "missing"
  return table.concat({ tostring(station_unit), tostring(priest_unit), tostring(surface), tostring(station_pos), tostring(priest_pos), tech_priests_lifecycle_task_label_0202(pair) }, "|")
end

function tech_priests_lifecycle_transition_audit_0202(force_heartbeat)
  if not (storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return end
  storage.tech_priests.lifecycle_snapshot_0202 = storage.tech_priests.lifecycle_snapshot_0202 or {}
  storage.tech_priests.lifecycle_last_heartbeat_0202 = storage.tech_priests.lifecycle_last_heartbeat_0202 or 0
  local heartbeat = force_heartbeat or ((game.tick - storage.tech_priests.lifecycle_last_heartbeat_0202) >= TECH_PRIESTS_LIFECYCLE_HEARTBEAT_TICKS_0202)
  if heartbeat then storage.tech_priests.lifecycle_last_heartbeat_0202 = game.tick end
  for station_unit, pair in pairs(storage.tech_priests.pairs_by_station or {}) do
    if pair then
      local snapshot = tech_priests_lifecycle_snapshot_0202(pair)
      local previous = storage.tech_priests.lifecycle_snapshot_0202[station_unit]
      if previous ~= snapshot then
        storage.tech_priests.lifecycle_snapshot_0202[station_unit] = snapshot
        tech_priests_lifecycle_note_0201(pair, "state transition", nil, "from=" .. tostring(previous or "new") .. " to=" .. tostring(snapshot))
      elseif heartbeat then
        tech_priests_lifecycle_emit_0202("heartbeat", pair, nil, "snapshot=" .. tostring(snapshot))
      end
      if pair.station and pair.station.valid and not (pair.priest and pair.priest.valid) then
        tech_priests_lifecycle_note_0201(pair, "missing priest entity", nil, "station remains valid; recall/spawn path should run next")
      end
    end
  end
end

-- Log before/after all normal removal events.  This intentionally re-registers the
-- same event list with a wrapper that calls the previously registered handler.
if on_removed and defines and defines.events then
  TECH_PRIESTS_ORIGINAL_ON_REMOVED_0202 = on_removed
  function tech_priests_on_removed_trace_wrapper_0202(event)
    local entity = event and event.entity
    local pair = nil
    if entity and entity.valid and find_pair_for_entity then pcall(function() pair = find_pair_for_entity(entity) end) end
    if entity and entity.valid and is_priest and is_priest(entity) then
      tech_priests_lifecycle_note_0201(pair, "priest removal event BEFORE core handler", entity, "event=" .. tostring(event and event.name or "?") .. " cause=" .. tostring(event and event.cause and event.cause.name or "none"))
    elseif entity and entity.valid and is_cogitator_station and is_cogitator_station(entity) then
      tech_priests_lifecycle_note_0201(pair, "station removal event BEFORE core handler", entity, "event=" .. tostring(event and event.name or "?") .. " cause=" .. tostring(event and event.cause and event.cause.name or "none"))
    end
    TECH_PRIESTS_ORIGINAL_ON_REMOVED_0202(event)
    if pair then tech_priests_lifecycle_transition_audit_0202(false) end
  end
  TechPriestsRuntimeEventRegistry.on_event({
    defines.events.on_entity_died,
    defines.events.on_pre_player_mined_item,
    defines.events.on_robot_pre_mined,
    defines.events.script_raised_destroy
  }, tech_priests_on_removed_trace_wrapper_0202)
end

-- Log recall/spawn attempts by wrapping the central priest maintenance function.
if ensure_pair_priest then
  TECH_PRIESTS_ORIGINAL_ENSURE_PAIR_PRIEST_0202 = ensure_pair_priest
  ensure_pair_priest = function(pair, force_recall, immediate)
    local before = pair and pair.priest and pair.priest.valid and pair.priest.unit_number or nil
    tech_priests_lifecycle_emit_0202("ensure_pair_priest BEFORE", pair, pair and pair.priest, "force_recall=" .. tostring(force_recall) .. " immediate=" .. tostring(immediate) .. " before_priest=" .. tostring(before))
    local result = TECH_PRIESTS_ORIGINAL_ENSURE_PAIR_PRIEST_0202(pair, force_recall, immediate)
    local after = pair and pair.priest and pair.priest.valid and pair.priest.unit_number or nil
    if before ~= after then
      tech_priests_lifecycle_note_0201(pair, "priest entity changed by ensure_pair_priest", pair and pair.priest, "before=" .. tostring(before) .. " after=" .. tostring(after) .. " force_recall=" .. tostring(force_recall) .. " immediate=" .. tostring(immediate))
    else
      tech_priests_lifecycle_emit_0202("ensure_pair_priest AFTER", pair, pair and pair.priest, "priest=" .. tostring(after))
    end
    return result
  end
end

TechPriestsRuntimeEventRegistry.on_nth_tick(379, function()
  tech_priests_lifecycle_transition_audit_0202(false)
end)

if commands then
  TechPriestsDebugCommandRegistry.add("tech-priests-lifecycle-log", "Toggle or flush Tech-Priest lifecycle logging. Usage: /tech-priests-lifecycle-log [on|off|heartbeat|file-on|file-off]", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local force = player and player.valid and player.force or game.forces.player
    local parameter = event and event.parameter and string.lower(event.parameter) or ""
    if parameter == "on" then
      TECH_PRIESTS_LIFECYCLE_TRACE_ENABLED_0202 = true
      force.print("[Tech-Priest Debug] Lifecycle trace logging ENABLED. Output goes to factorio-current.log; script-output file logging is used when the runtime exposes a safe writer.")
    elseif parameter == "off" then
      TECH_PRIESTS_LIFECYCLE_TRACE_ENABLED_0202 = false
      force.print("[Tech-Priest Debug] Lifecycle trace logging DISABLED.")
    elseif parameter == "file-on" then
      TECH_PRIESTS_LIFECYCLE_FILE_ENABLED_0202 = true
      force.print("[Tech-Priest Debug] Lifecycle script-output file logging ENABLED when supported by this Factorio runtime.")
    elseif parameter == "file-off" then
      TECH_PRIESTS_LIFECYCLE_FILE_ENABLED_0202 = false
      force.print("[Tech-Priest Debug] Lifecycle script-output file logging DISABLED; factorio-current.log remains controlled by on/off.")
    elseif parameter == "heartbeat" or parameter == "flush" then
      tech_priests_lifecycle_transition_audit_0202(true)
      force.print("[Tech-Priest Debug] Lifecycle heartbeat flushed to log.")
    else
      force.print("[Tech-Priest Debug] Lifecycle trace is " .. (TECH_PRIESTS_LIFECYCLE_TRACE_ENABLED_0202 and "ON" or "OFF") .. "; file output is " .. (TECH_PRIESTS_LIFECYCLE_FILE_ENABLED_0202 and "ON" or "OFF") .. ". Use on, off, file-on, file-off, or heartbeat.")
    end
  end)
end


-- 0.1.204 space-platform fallback doctrine and priest lifecycle hardening.
-- Emergency Martian micro-industry is intentionally planetside-only.  When a
-- station lives on a space platform, the priest must not sit forever in
-- "Emergency Operation · invalid-surface".  It instead falls back to ordinary
-- station doctrine: scavenge reachable inventories, answer normal repair /
-- consecration / combat / logistics needs, and otherwise accept that it is in
-- space and must deal with it.

TECH_PRIESTS_SPACE_FALLBACK_STATUS_TICKS_0204 = 60 * 10
TECH_PRIESTS_SPACE_RESPAWN_RETRY_TICKS_0204 = 60 * 5
TECH_PRIESTS_SPACE_RECENT_MISSING_LIMIT_0204 = 8

function tech_priests_surface_is_space_platform_0204(surface)
  if not surface then return false end
  local ok_platform, platform = pcall(function() return surface.platform end)
  if ok_platform and platform then return true end
  local name = tostring(surface.name or "")
  local lower = string.lower(name)
  if string.find(lower, "platform", 1, true) then return true end
  if string.find(lower, "space", 1, true) then return true end
  if tech_priests_surface_is_space_or_void_0183 then
    local ok, invalid = pcall(function() return tech_priests_surface_is_space_or_void_0183(surface) end)
    if ok and invalid then return true end
  end
  return false
end

function tech_priests_pair_on_space_platform_0204(pair)
  local surface = nil
  if pair and pair.station and pair.station.valid then surface = pair.station.surface end
  if not surface and pair and pair.priest and pair.priest.valid then surface = pair.priest.surface end
  return tech_priests_surface_is_space_platform_0204(surface)
end

function tech_priests_note_space_fallback_0204(pair, reason)
  if not (pair and pair.station and pair.station.valid) then return end
  pair.space_platform_fallback_0204 = true
  pair.last_space_fallback_reason_0204 = tostring(reason or "space-platform")
  if game and game.tick and game.tick >= (pair.next_space_fallback_status_tick_0204 or 0) then
    pair.next_space_fallback_status_tick_0204 = game.tick + TECH_PRIESTS_SPACE_FALLBACK_STATUS_TICKS_0204
    if tech_priests_draw_emergency_operation_status_0184 then
      tech_priests_draw_emergency_operation_status_0184(pair, "[virtual-signal=signal-info] Space platform doctrine: local scrounge, normal operations")
    elseif pair.station.surface and pair.station.surface.create_entity then
      pcall(function()
        if tech_priests_safe_floating_text_0448 then tech_priests_safe_floating_text_0448(pair.station.surface, pair.station.position, "Space platform doctrine", { r = 0.6, g = 0.85, b = 1, a = 1 }, { ttl = 180, scale = 0.78 }) end
      end)
    end
    if tech_priests_lifecycle_note_0201 then
      tech_priests_lifecycle_note_0201(pair, "space platform fallback doctrine", pair.priest, tostring(reason or "invalid-surface"))
    end
  end
end

function tech_priests_clear_planetside_emergency_tasks_for_space_0204(pair, op)
  if op then
    op.phase = "space-platform-fallback"
    op.space_platform_fallback_0204 = true
    op.construction = nil
    op.site = nil
    op.need_item = nil
    op.target_item = nil
    op.current_item = nil
    op.next_tick = game and game.tick and (game.tick + TECH_PRIESTS_SPACE_FALLBACK_STATUS_TICKS_0204) or op.next_tick
  end
  if pair then
    pair.independent_emergency_operation_0184 = op or pair.independent_emergency_operation_0184
    pair.emergency_construction_0186 = nil
    -- Emergency fabrication created by ordinary missing-supply doctrine is left alone;
    -- only micro-industry site construction is impossible in space.
    if pair.mode == "independent-emergency-operation" or pair.mode == "emergency-construction" then
      pair.mode = "space-platform-doctrine"
    end
  end
end

if tech_priests_service_independent_emergency_operation_0184 then
  TECH_PRIESTS_ORIGINAL_SERVICE_INDEPENDENT_EMERGENCY_OPERATION_0204 = tech_priests_service_independent_emergency_operation_0184
  function tech_priests_service_independent_emergency_operation_0184(pair)
    local op = tech_priests_get_emergency_operation_0184 and tech_priests_get_emergency_operation_0184(pair) or (pair and pair.independent_emergency_operation_0184)
    if op and op.enabled and pair and pair.station and pair.station.valid and tech_priests_pair_on_space_platform_0204(pair) then
      tech_priests_clear_planetside_emergency_tasks_for_space_0204(pair, op)
      tech_priests_note_space_fallback_0204(pair, "Martian emergency facilities unavailable in space")
      if pair.inventory_scan and handle_logistic_inventory_scan then return handle_logistic_inventory_scan(pair) end
      if pair.scavenge and handle_priest_scavenge_task then return handle_priest_scavenge_task(pair) end
      return false
    end
    return TECH_PRIESTS_ORIGINAL_SERVICE_INDEPENDENT_EMERGENCY_OPERATION_0204(pair)
  end
end

if tech_priests_maybe_auto_enter_emergency_operation_0184 then
  TECH_PRIESTS_ORIGINAL_MAYBE_AUTO_ENTER_EMERGENCY_OPERATION_0204 = tech_priests_maybe_auto_enter_emergency_operation_0184
  function tech_priests_maybe_auto_enter_emergency_operation_0184(pair)
    if pair and pair.station and pair.station.valid and tech_priests_pair_on_space_platform_0204(pair) then
      tech_priests_note_space_fallback_0204(pair, "frustration auto-emergency suppressed in space")
      return false
    end
    return TECH_PRIESTS_ORIGINAL_MAYBE_AUTO_ENTER_EMERGENCY_OPERATION_0204(pair)
  end
end

if tech_priests_task_summary_0189 then
  TECH_PRIESTS_ORIGINAL_TASK_SUMMARY_0204 = tech_priests_task_summary_0189
  function tech_priests_task_summary_0189(pair)
    local op = nil
    if tech_priests_get_emergency_operation_0184 then op = tech_priests_get_emergency_operation_0184(pair) end
    op = op or (pair and pair.independent_emergency_operation_0184)
    if pair and pair.space_platform_fallback_0204 and tech_priests_pair_on_space_platform_0204(pair) then
      if pair.inventory_scan then return "Space platform doctrine · local inventory scan" end
      if pair.scavenge then return "Space platform doctrine · local scrounge" end
      if op and op.enabled then return "Space platform doctrine · normal operations" end
    end
    if op and op.enabled and op.phase == "space-platform-fallback" then
      return "Space platform doctrine · normal operations"
    end
    return TECH_PRIESTS_ORIGINAL_TASK_SUMMARY_0204(pair)
  end
end

-- Strengthen spawn-locus validation for dense space platforms. 0.1.201 already
-- rejected belt entities; this extension rejects additional moving-floor / loader
-- variants and avoids tiles that are occupied by any entity that would immediately
-- fight the unit controller.
TECH_PRIESTS_EXTRA_BAD_SPAWN_TYPES_0204 = {
  ["transport-belt"] = true,
  ["underground-belt"] = true,
  ["splitter"] = true,
  ["loader"] = true,
  ["loader-1x1"] = true,
  ["linked-belt"] = true,
  ["inserter"] = true,
  ["pipe"] = true,
  ["pipe-to-ground"] = true
}

function tech_priests_tile_has_bad_spawn_entity_0204(surface, position)
  if not (surface and position) then return false end
  local area = { { position.x - 0.49, position.y - 0.49 }, { position.x + 0.49, position.y + 0.49 } }
  local ok, entities = pcall(function() return surface.find_entities_filtered({ area = area }) end)
  if not (ok and entities) then return false end
  for _, entity in pairs(entities) do
    if entity and entity.valid and TECH_PRIESTS_EXTRA_BAD_SPAWN_TYPES_0204[entity.type] then return true end
  end
  return false
end

if tech_priests_can_spawn_at_tile_0176 then
  TECH_PRIESTS_ORIGINAL_CAN_SPAWN_AT_TILE_0204 = tech_priests_can_spawn_at_tile_0176
  function tech_priests_can_spawn_at_tile_0176(station, priest_name, position)
    if station and station.valid and position and tech_priests_tile_has_bad_spawn_entity_0204(station.surface, position) then return false end
    return TECH_PRIESTS_ORIGINAL_CAN_SPAWN_AT_TILE_0204(station, priest_name, position)
  end
end

if ensure_pair_priest then
  TECH_PRIESTS_ORIGINAL_ENSURE_PAIR_PRIEST_0204 = ensure_pair_priest
  function ensure_pair_priest(pair, force_recall, immediate)
    if pair and pair.station and pair.station.valid and tech_priests_pair_on_space_platform_0204(pair) and not (pair.priest and pair.priest.valid) then
      pair.space_missing_priest_seen_0204 = (pair.space_missing_priest_seen_0204 or 0) + 1
      if pair.space_missing_priest_seen_0204 >= 2 then
        immediate = true
      end
      if game and game.tick and game.tick < (pair.next_space_respawn_retry_tick_0204 or 0) and not immediate then
        return false
      end
      pair.next_space_respawn_retry_tick_0204 = game and game.tick and (game.tick + TECH_PRIESTS_SPACE_RESPAWN_RETRY_TICKS_0204) or pair.next_space_respawn_retry_tick_0204
    elseif pair then
      pair.space_missing_priest_seen_0204 = 0
    end
    return TECH_PRIESTS_ORIGINAL_ENSURE_PAIR_PRIEST_0204(pair, force_recall, immediate)
  end
end

if respawn_pair_priest then
  TECH_PRIESTS_ORIGINAL_RESPAWN_PAIR_PRIEST_0204 = respawn_pair_priest
  function respawn_pair_priest(pair, reason)
    if pair and pair.station and pair.station.valid and tech_priests_pair_on_space_platform_0204(pair) then
      if tech_priests_lifecycle_note_0201 then tech_priests_lifecycle_note_0201(pair, "space respawn attempt", pair.priest, tostring(reason or "unknown")) end
    end
    local ok = TECH_PRIESTS_ORIGINAL_RESPAWN_PAIR_PRIEST_0204(pair, reason)
    if pair and pair.station and pair.station.valid and tech_priests_pair_on_space_platform_0204(pair) then
      if ok and pair.priest and pair.priest.valid then
        pair.space_missing_priest_seen_0204 = 0
        if tech_priests_lifecycle_note_0201 then tech_priests_lifecycle_note_0201(pair, "space respawn success", pair.priest, "priest=" .. tostring(pair.priest.unit_number)) end
      else
        if tech_priests_lifecycle_note_0201 then tech_priests_lifecycle_note_0201(pair, "space respawn failed", nil, "reason=" .. tostring(reason or "unknown")) end
      end
    end
    return ok
  end
end

-- 0.1.205 space-platform priest lifecycle stabilization.
-- The 0.1.204 logs show that some platform priests can be created at a locus,
-- then become invalid a few ticks later without a normal removal event reaching
-- our handler.  Treat those loci as unstable and rotate to another valid platform
-- tile instead of reusing the same remembered spawn forever.

TECH_PRIESTS_SPACE_SPAWN_BLACKLIST_TICKS_0205 = 60 * 60 * 5
TECH_PRIESTS_SPACE_PLATFORM_EXTRA_SEARCH_RADIUS_0205 = 36
TECH_PRIESTS_SPACE_PRIEST_TETHER_TICKS_0205 = 60 * 2

function tech_priests_ensure_space_spawn_debug_storage_0205()
  ensure_storage()
  storage.tech_priests.space_spawn_blacklist_0205 = storage.tech_priests.space_spawn_blacklist_0205 or {}
end

function tech_priests_space_spawn_key_0205(position)
  if not position then return nil end
  return tostring(math.floor((position.x or 0) * 10 + 0.5) / 10) .. "," .. tostring(math.floor((position.y or 0) * 10 + 0.5) / 10)
end

function tech_priests_blacklist_space_spawn_0205(pair, position, reason)
  if not (pair and pair.station and pair.station.valid and position) then return end
  if not tech_priests_pair_on_space_platform_0204(pair) then return end
  tech_priests_ensure_space_spawn_debug_storage_0205()
  local unit = pair.station.unit_number
  if not unit then return end
  local bucket = storage.tech_priests.space_spawn_blacklist_0205[unit] or {}
  storage.tech_priests.space_spawn_blacklist_0205[unit] = bucket
  local key = tech_priests_space_spawn_key_0205(position)
  if not key then return end
  bucket[key] = { x = position.x, y = position.y, until_tick = (game and game.tick or 0) + TECH_PRIESTS_SPACE_SPAWN_BLACKLIST_TICKS_0205, reason = tostring(reason or "unstable") }
  if storage.tech_priests.spawn_positions_by_station then storage.tech_priests.spawn_positions_by_station[unit] = nil end
  pair.spawn_position = nil
  if tech_priests_lifecycle_note_0201 then
    tech_priests_lifecycle_note_0201(pair, "space spawn locus blacklisted", pair.priest, key .. " reason=" .. tostring(reason or "unstable"))
  end
end

function tech_priests_space_spawn_is_blacklisted_0205(station, position)
  if not (station and station.valid and position) then return false end
  tech_priests_ensure_space_spawn_debug_storage_0205()
  local bucket = storage.tech_priests.space_spawn_blacklist_0205[station.unit_number]
  if not bucket then return false end
  local key = tech_priests_space_spawn_key_0205(position)
  local record = key and bucket[key]
  if not record then return false end
  if game and game.tick and record.until_tick and game.tick > record.until_tick then
    bucket[key] = nil
    return false
  end
  return true
end

function tech_priests_space_tile_is_foundation_0205(surface, position)
  if not (surface and position) then return false end
  local ok_tile, tile = pcall(function() return surface.get_tile(position) end)
  if not (ok_tile and tile and tile.valid) then return false end
  local name = string.lower(tostring(tile.name or ""))
  if name == "empty-space" or name == "out-of-map" then return false end
  if string.find(name, "empty%-space", 1, false) or string.find(name, "out%-of%-map", 1, false) then return false end
  if string.find(name, "space", 1, true) and not string.find(name, "platform", 1, true) and not string.find(name, "foundation", 1, true) then return false end
  return true
end

function tech_priests_platform_spawn_candidate_ok_0205(station, priest_name, position)
  if not (station and station.valid and priest_name and position) then return false end
  if tech_priests_space_spawn_is_blacklisted_0205(station, position) then return false end
  if not tech_priests_space_tile_is_foundation_0205(station.surface, position) then return false end
  if tech_priests_tile_has_bad_spawn_entity_0204 and tech_priests_tile_has_bad_spawn_entity_0204(station.surface, position) then return false end
  local ok_place, can_place = pcall(function()
    return station.surface.can_place_entity({ name = priest_name, position = position, force = station.force })
  end)
  if ok_place and can_place then return true end
  local ok_near, nearby = pcall(function()
    return station.surface.find_non_colliding_position(priest_name, position, 0.75, 0.25, false)
  end)
  return ok_near and nearby and tech_priests_space_tile_is_foundation_0205(station.surface, nearby) and not tech_priests_space_spawn_is_blacklisted_0205(station, nearby)
end

function tech_priests_find_space_platform_spawn_tile_0205(station, priest_name)
  if not (station and station.valid and priest_name and tech_priests_surface_is_space_platform_0204(station.surface)) then return nil end
  local base = tech_priests_round_tile_center_0176 and tech_priests_round_tile_center_0176(station.position) or { x = math.floor(station.position.x) + 0.5, y = math.floor(station.position.y) + 0.5 }
  local radius = TECH_PRIESTS_SPACE_PLATFORM_EXTRA_SEARCH_RADIUS_0205
  local best = nil
  local best_dist = nil
  for ring = 1, radius do
    for dx = -ring, ring do
      for dy = -ring, ring do
        if math.max(math.abs(dx), math.abs(dy)) == ring then
          local position = { x = base.x + dx, y = base.y + dy }
          if tech_priests_platform_spawn_candidate_ok_0205(station, priest_name, position) then
            local ddx = position.x - station.position.x
            local ddy = position.y - station.position.y
            local dist = ddx * ddx + ddy * ddy
            if not best_dist or dist < best_dist then
              best = position
              best_dist = dist
            end
          end
        end
      end
    end
    if best then
      if tech_priests_lifecycle_note_0201 then
        local pair = storage and storage.tech_priests and storage.tech_priests.pairs_by_station and storage.tech_priests.pairs_by_station[station.unit_number]
        tech_priests_lifecycle_note_0201(pair, "space spawn candidate selected", nil, tostring(best.x) .. "," .. tostring(best.y) .. " ring=" .. tostring(ring))
      end
      return best
    end
  end
  return nil
end

if find_spawn_position then
  TECH_PRIESTS_ORIGINAL_FIND_SPAWN_POSITION_0205 = find_spawn_position
  function find_spawn_position(station, priest_name)
    if station and station.valid and priest_name and tech_priests_surface_is_space_platform_0204 and tech_priests_surface_is_space_platform_0204(station.surface) then
      local platform_position = tech_priests_find_space_platform_spawn_tile_0205(station, priest_name)
      if platform_position then
        if tech_priests_set_remembered_spawn_position_0176 then tech_priests_set_remembered_spawn_position_0176(station, platform_position) end
        return platform_position
      end
    end
    return TECH_PRIESTS_ORIGINAL_FIND_SPAWN_POSITION_0205(station, priest_name)
  end
end

function tech_priests_sanitize_platform_pair_state_0205(pair)
  if not (pair and pair.station and pair.station.valid and tech_priests_pair_on_space_platform_0204(pair)) then return false end
  if pair.mode == "independent-emergency-operation" or pair.mode == "emergency-construction" then pair.mode = "space-platform-doctrine" end
  if pair.independent_emergency_operation_0184 and pair.independent_emergency_operation_0184.enabled then
    pair.independent_emergency_operation_0184.phase = "space-platform-fallback"
    pair.independent_emergency_operation_0184.construction = nil
    pair.independent_emergency_operation_0184.site = nil
  end
  if pair.emergency_construction_0186 then pair.emergency_construction_0186 = nil end
  pair.space_platform_fallback_0204 = true
  return true
end

if ensure_pair_priest then
  TECH_PRIESTS_ORIGINAL_ENSURE_PAIR_PRIEST_0205 = ensure_pair_priest
  function ensure_pair_priest(pair, force_recall, immediate)
    if pair and pair.station and pair.station.valid and tech_priests_pair_on_space_platform_0204 and tech_priests_pair_on_space_platform_0204(pair) then
      tech_priests_sanitize_platform_pair_state_0205(pair)
      if not (pair.priest and pair.priest.valid) and pair.last_space_spawn_position_0205 then
        tech_priests_blacklist_space_spawn_0205(pair, pair.last_space_spawn_position_0205, "priest missing after prior platform spawn")
        pair.last_space_spawn_position_0205 = nil
      end
      immediate = true
    end
    local result = TECH_PRIESTS_ORIGINAL_ENSURE_PAIR_PRIEST_0205(pair, force_recall, immediate)
    if result and pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid and tech_priests_pair_on_space_platform_0204 and tech_priests_pair_on_space_platform_0204(pair) then
      pair.last_space_spawn_position_0205 = { x = pair.priest.position.x, y = pair.priest.position.y }
      pair.last_space_priest_seen_tick_0205 = game and game.tick or 0
    end
    return result
  end
end

if respawn_pair_priest then
  TECH_PRIESTS_ORIGINAL_RESPAWN_PAIR_PRIEST_0205 = respawn_pair_priest
  function respawn_pair_priest(pair, reason)
    if pair and pair.station and pair.station.valid and tech_priests_pair_on_space_platform_0204 and tech_priests_pair_on_space_platform_0204(pair) then
      tech_priests_sanitize_platform_pair_state_0205(pair)
      if pair.last_space_spawn_position_0205 then
        tech_priests_blacklist_space_spawn_0205(pair, pair.last_space_spawn_position_0205, "respawn requested after platform disappearance")
        pair.last_space_spawn_position_0205 = nil
      end
    end
    local ok = TECH_PRIESTS_ORIGINAL_RESPAWN_PAIR_PRIEST_0205(pair, reason)
    if pair and pair.station and pair.station.valid and tech_priests_pair_on_space_platform_0204 and tech_priests_pair_on_space_platform_0204(pair) then
      if ok and pair.priest and pair.priest.valid then
        pair.last_space_spawn_position_0205 = { x = pair.priest.position.x, y = pair.priest.position.y }
        pair.last_space_priest_seen_tick_0205 = game and game.tick or 0
      else
        local config = get_station_config and get_station_config(pair.station) or nil
        local priest_name = config and get_priest_name_for_force and get_priest_name_for_force(config, pair.station.force) or nil
        local diagnostic = priest_name and tech_priests_find_space_platform_spawn_tile_0205(pair.station, priest_name) or nil
        if tech_priests_lifecycle_note_0201 then
          tech_priests_lifecycle_note_0201(pair, "space respawn hard failure", nil, "reason=" .. tostring(reason or "unknown") .. " next_candidate=" .. (diagnostic and (tostring(diagnostic.x) .. "," .. tostring(diagnostic.y)) or "none"))
        end
      end
    end
    return ok
  end
end

TechPriestsRuntimeEventRegistry.on_nth_tick(541, function()
  if not (storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return end
  for _, pair in pairs(storage.tech_priests.pairs_by_station) do
    if pair and pair.station and pair.station.valid and tech_priests_pair_on_space_platform_0204 and tech_priests_pair_on_space_platform_0204(pair) then
      tech_priests_sanitize_platform_pair_state_0205(pair)
      if pair.priest and pair.priest.valid then
        pair.last_space_priest_seen_tick_0205 = game.tick
        pair.last_space_spawn_position_0205 = pair.last_space_spawn_position_0205 or { x = pair.priest.position.x, y = pair.priest.position.y }
        if tech_priests_space_tile_is_foundation_0205 and not tech_priests_space_tile_is_foundation_0205(pair.priest.surface, pair.priest.position) then
          if tech_priests_lifecycle_note_0201 then tech_priests_lifecycle_note_0201(pair, "space priest found on unsafe tile", pair.priest, "teleporting to spawn locus") end
          local config = get_station_config(pair.station)
          local priest_name = config and get_priest_name_for_force(config, pair.station.force)
          local pos = priest_name and find_spawn_position(pair.station, priest_name) or nil
          if pos then pcall(function() pair.priest.teleport(pos, pair.station.surface) end) end
        end
      else
        ensure_pair_priest(pair, false, true)
      end
    end
  end
end)


-- 0.1.206 Space-platform priest tether / no-free-walk diagnostic pass.
-- Observation from live testing: priests on platforms spawn, move briefly, then disappear.
-- Until platform unit movement is proven stable, platform doctrine pins priests to a safe locus
-- and blocks ordinary movement commands from pushing them into platform/void edge cases.
TECH_PRIESTS_SPACE_TETHER_TICKS_0206 = 3
TECH_PRIESTS_SPACE_TETHER_MAX_DRIFT_SQ_0206 = 0.36

function tech_priests_pair_for_priest_entity_0206(priest)
  if not (priest and priest.valid and storage and storage.tech_priests and storage.tech_priests.station_by_priest and storage.tech_priests.pairs_by_station) then return nil end
  local station_unit = storage.tech_priests.station_by_priest[priest.unit_number]
  return station_unit and storage.tech_priests.pairs_by_station[station_unit] or nil
end

function tech_priests_platform_pair_0206(pair)
  return pair and pair.station and pair.station.valid and tech_priests_pair_on_space_platform_0204 and tech_priests_pair_on_space_platform_0204(pair)
end

function tech_priests_stop_platform_priest_0206(pair, reason)
  if not (tech_priests_platform_pair_0206(pair) and pair.priest and pair.priest.valid) then return false end
  local priest = pair.priest
  pcall(function()
    if priest.commandable then priest.commandable.set_command({ type = defines.command.stop }) end
  end)
  pcall(function() priest.active = false end)
  pcall(function() priest.destructible = false end)
  pair.mode = "space-platform-doctrine"
  pair.target = nil
  pair.combat_target = nil
  pair.space_platform_fallback_0204 = true
  pair.space_platform_tether_0206 = pair.space_platform_tether_0206 or {}
  if reason and tech_priests_lifecycle_note_0201 then
    local last_reason = pair.space_platform_tether_0206.last_reason
    local last_tick = pair.space_platform_tether_0206.last_log_tick or 0
    if last_reason ~= reason or (game.tick - last_tick) > 600 then
      pair.space_platform_tether_0206.last_reason = reason
      pair.space_platform_tether_0206.last_log_tick = game.tick
      tech_priests_lifecycle_note_0201(pair, "space platform movement suppressed", priest, tostring(reason))
    end
  end
  return true
end

function tech_priests_get_space_tether_position_0206(pair)
  if not tech_priests_platform_pair_0206(pair) then return nil end
  if pair.space_platform_tether_0206 and pair.space_platform_tether_0206.position then
    local pos = pair.space_platform_tether_0206.position
    if tech_priests_space_tile_is_foundation_0205 and tech_priests_space_tile_is_foundation_0205(pair.station.surface, pos)
        and not (tech_priests_tile_has_bad_spawn_entity_0204 and tech_priests_tile_has_bad_spawn_entity_0204(pair.station.surface, pos)) then
      return pos
    end
  end
  local config = get_station_config and get_station_config(pair.station) or nil
  local priest_name = config and get_priest_name_for_force and get_priest_name_for_force(config, pair.station.force) or (pair.priest and pair.priest.valid and pair.priest.name) or nil
  local pos = priest_name and find_spawn_position and find_spawn_position(pair.station, priest_name) or nil
  if pos then
    pair.space_platform_tether_0206 = pair.space_platform_tether_0206 or {}
    pair.space_platform_tether_0206.position = { x = pos.x, y = pos.y }
    if tech_priests_lifecycle_note_0201 then tech_priests_lifecycle_note_0201(pair, "space tether locus selected", pair.priest, tostring(pos.x) .. "," .. tostring(pos.y)) end
  end
  return pos
end

function tech_priests_tether_platform_priest_0206(pair, reason)
  if not (tech_priests_platform_pair_0206(pair) and pair.priest and pair.priest.valid) then return false end
  tech_priests_sanitize_platform_pair_state_0205(pair)
  tech_priests_stop_platform_priest_0206(pair, reason or "tether")
  local priest = pair.priest
  local pos = tech_priests_get_space_tether_position_0206(pair) or pair.station.position
  if priest.surface ~= pair.station.surface then
    pcall(function() priest.teleport(pos, pair.station.surface) end)
    if tech_priests_lifecycle_note_0201 then tech_priests_lifecycle_note_0201(pair, "space priest surface corrected", priest, tostring(reason or "surface mismatch")) end
    return true
  end
  local dx = priest.position.x - pos.x
  local dy = priest.position.y - pos.y
  local drift_sq = dx * dx + dy * dy
  if drift_sq > TECH_PRIESTS_SPACE_TETHER_MAX_DRIFT_SQ_0206 then
    if tech_priests_lifecycle_note_0201 then
      tech_priests_lifecycle_note_0201(pair, "space priest drift intercepted", priest, "drift_sq=" .. tostring(drift_sq) .. " reason=" .. tostring(reason or "unknown"))
    end
    pcall(function() priest.teleport(pos, pair.station.surface) end)
  end
  pair.last_space_spawn_position_0205 = { x = pos.x, y = pos.y }
  pair.last_space_priest_seen_tick_0205 = game.tick
  return true
end

-- Block the two common movement issue paths on platform priests. Planet priests keep normal behavior.
if return_to_station then
  TECH_PRIESTS_ORIGINAL_RETURN_TO_STATION_0206 = return_to_station
end

if move_priest_to then
  TECH_PRIESTS_ORIGINAL_MOVE_PRIEST_TO_0206 = move_priest_to
end

if respawn_pair_priest then
  TECH_PRIESTS_ORIGINAL_RESPAWN_PAIR_PRIEST_0206 = respawn_pair_priest
  function respawn_pair_priest(pair, reason)
    local ok = TECH_PRIESTS_ORIGINAL_RESPAWN_PAIR_PRIEST_0206(pair, reason)
    if ok and tech_priests_platform_pair_0206(pair) and pair.priest and pair.priest.valid then
      tech_priests_tether_platform_priest_0206(pair, "post-respawn platform tether")
    end
    return ok
  end
end

if ensure_pair_priest then
  TECH_PRIESTS_ORIGINAL_ENSURE_PAIR_PRIEST_0206 = ensure_pair_priest
  function ensure_pair_priest(pair, force_recall, immediate)
    local result = TECH_PRIESTS_ORIGINAL_ENSURE_PAIR_PRIEST_0206(pair, force_recall, immediate)
    if result and tech_priests_platform_pair_0206(pair) and pair.priest and pair.priest.valid then
      tech_priests_tether_platform_priest_0206(pair, "post-ensure platform tether")
    end
    return result
  end
end

TechPriestsRuntimeEventRegistry.on_nth_tick(TECH_PRIESTS_SPACE_TETHER_TICKS_0206, function()
  if not (storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return end
  for _, pair in pairs(storage.tech_priests.pairs_by_station) do
    if tech_priests_platform_pair_0206(pair) then
      if pair.priest and pair.priest.valid then
        tech_priests_tether_platform_priest_0206(pair, "periodic platform tether")
      else
        -- Missing again after movement suppression means the engine or another script removed it.
        if tech_priests_lifecycle_note_0201 then tech_priests_lifecycle_note_0201(pair, "space priest missing under tether", nil, "respawn requested") end
        ensure_pair_priest(pair, false, true)
      end
    end
  end
end)


-- 0.1.207 Space-platform spawn-locus enforcement patch.
-- 0.1.206 proved that free movement/pathing was causing platform priests to vanish,
-- but its tether cache could fall back to the Cogitator Station's own position.  That
-- made newly respawned priests appear inside/on top of the station instead of on the
-- visible ⊕ spawn-locus marker.  This patch makes the remembered spawn marker the
-- authoritative tether/respawn point and refuses to use the station tile as a fallback.
TECH_PRIESTS_PLATFORM_SPAWN_ENFORCE_EPSILON_SQ_0207 = 0.04
TECH_PRIESTS_PLATFORM_STATION_TILE_EPSILON_SQ_0207 = 0.64

function tech_priests_position_distance_sq_0207(a, b)
  if not (a and b) then return 999999999 end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end

function tech_priests_platform_spawn_locus_valid_0207(pair, position, priest_name)
  if not (pair and pair.station and pair.station.valid and position and priest_name) then return false end
  if not (tech_priests_pair_on_space_platform_0204 and tech_priests_pair_on_space_platform_0204(pair)) then return false end
  -- Never accept the station's own occupied tile as a platform tether/spawn locus.
  if tech_priests_position_distance_sq_0207(position, pair.station.position) <= TECH_PRIESTS_PLATFORM_STATION_TILE_EPSILON_SQ_0207 then return false end
  if tech_priests_platform_spawn_candidate_ok_0205 then
    return tech_priests_platform_spawn_candidate_ok_0205(pair.station, priest_name, position)
  end
  if tech_priests_can_spawn_at_tile_0176 then
    return tech_priests_can_spawn_at_tile_0176(pair.station, priest_name, position)
  end
  return false
end

function tech_priests_get_authoritative_platform_spawn_locus_0207(pair, priest_name)
  if not (pair and pair.station and pair.station.valid) then return nil end
  if not (tech_priests_pair_on_space_platform_0204 and tech_priests_pair_on_space_platform_0204(pair)) then return nil end
  priest_name = priest_name or (pair.priest and pair.priest.valid and pair.priest.name) or nil
  if not priest_name then
    local cfg = get_station_config and get_station_config(pair.station) or nil
    priest_name = cfg and get_priest_name_for_force and get_priest_name_for_force(cfg, pair.station.force) or nil
  end
  if not priest_name then return nil end

  -- The marker/memory from 0.1.176 is the source of truth.  It is the position the
  -- player sees, and it is where the priest should be created and held.
  local stored = nil
  if tech_priests_get_remembered_spawn_position_0176 then stored = tech_priests_get_remembered_spawn_position_0176(pair.station) end
  if stored and tech_priests_platform_spawn_locus_valid_0207(pair, stored, priest_name) then
    pair.spawn_position = { x = stored.x, y = stored.y }
    pair.space_platform_tether_0206 = pair.space_platform_tether_0206 or {}
    pair.space_platform_tether_0206.position = { x = stored.x, y = stored.y }
    return { x = stored.x, y = stored.y }
  end

  if pair.spawn_position and tech_priests_platform_spawn_locus_valid_0207(pair, pair.spawn_position, priest_name) then
    if tech_priests_set_remembered_spawn_position_0176 then tech_priests_set_remembered_spawn_position_0176(pair.station, pair.spawn_position) end
    pair.space_platform_tether_0206 = pair.space_platform_tether_0206 or {}
    pair.space_platform_tether_0206.position = { x = pair.spawn_position.x, y = pair.spawn_position.y }
    return { x = pair.spawn_position.x, y = pair.spawn_position.y }
  end

  -- If the 0.1.206 tether cached the station tile, discard it.  This is the bug the
  -- player observed: the tether was holding priests on the station instead of on the marker.
  if pair.space_platform_tether_0206 and pair.space_platform_tether_0206.position then
    if not tech_priests_platform_spawn_locus_valid_0207(pair, pair.space_platform_tether_0206.position, priest_name) then
      if tech_priests_lifecycle_note_0201 then
        tech_priests_lifecycle_note_0201(pair, "discarded invalid platform tether cache", pair.priest, tostring(pair.space_platform_tether_0206.position.x) .. "," .. tostring(pair.space_platform_tether_0206.position.y))
      end
      pair.space_platform_tether_0206.position = nil
    end
  end

  local selected = nil
  if tech_priests_find_space_platform_spawn_tile_0205 then selected = tech_priests_find_space_platform_spawn_tile_0205(pair.station, priest_name) end
  if selected and tech_priests_platform_spawn_locus_valid_0207(pair, selected, priest_name) then
    if tech_priests_set_remembered_spawn_position_0176 then tech_priests_set_remembered_spawn_position_0176(pair.station, selected) end
    pair.spawn_position = { x = selected.x, y = selected.y }
    pair.space_platform_tether_0206 = pair.space_platform_tether_0206 or {}
    pair.space_platform_tether_0206.position = { x = selected.x, y = selected.y }
    if tech_priests_lifecycle_note_0201 then tech_priests_lifecycle_note_0201(pair, "platform spawn marker repaired", pair.priest, tostring(selected.x) .. "," .. tostring(selected.y)) end
    return { x = selected.x, y = selected.y }
  end

  return nil
end

-- Override the 0.1.206 tether-position resolver.  The critical change is: no station-position fallback.
function tech_priests_get_space_tether_position_0206(pair)
  local pos = tech_priests_get_authoritative_platform_spawn_locus_0207(pair)
  if pos then return pos end
  if tech_priests_lifecycle_note_0201 and pair and pair.station and pair.station.valid then
    tech_priests_lifecycle_note_0201(pair, "no valid platform tether locus", pair.priest, "refusing station-position fallback")
  end
  return nil
end

-- Override the 0.1.206 tether so a missing/invalid marker does not teleport priests onto the station.
function tech_priests_tether_platform_priest_0206(pair, reason)
  if not (tech_priests_platform_pair_0206 and tech_priests_platform_pair_0206(pair) and pair.priest and pair.priest.valid) then return false end
  if tech_priests_sanitize_platform_pair_state_0205 then tech_priests_sanitize_platform_pair_state_0205(pair) end
  if tech_priests_stop_platform_priest_0206 then tech_priests_stop_platform_priest_0206(pair, reason or "tether") end
  local priest = pair.priest
  local pos = tech_priests_get_authoritative_platform_spawn_locus_0207(pair, priest.name)
  if not pos then
    -- Hold current position only. Do not snap onto the station.
    if tech_priests_lifecycle_note_0201 then tech_priests_lifecycle_note_0201(pair, "platform tether deferred", priest, "no valid locus; station fallback forbidden") end
    return false
  end
  if priest.surface ~= pair.station.surface then
    pcall(function() priest.teleport(pos, pair.station.surface) end)
    if tech_priests_lifecycle_note_0201 then tech_priests_lifecycle_note_0201(pair, "space priest surface corrected", priest, tostring(reason or "surface mismatch")) end
    return true
  end
  local drift_sq = tech_priests_position_distance_sq_0207(priest.position, pos)
  if drift_sq > TECH_PRIESTS_SPACE_TETHER_MAX_DRIFT_SQ_0206 then
    if tech_priests_lifecycle_note_0201 then
      tech_priests_lifecycle_note_0201(pair, "space priest drift intercepted", priest, "drift_sq=" .. tostring(drift_sq) .. " target=" .. tostring(pos.x) .. "," .. tostring(pos.y) .. " reason=" .. tostring(reason or "unknown"))
    end
    pcall(function() priest.teleport(pos, pair.station.surface) end)
  end
  pair.last_space_spawn_position_0205 = { x = pos.x, y = pos.y }
  pair.last_space_priest_seen_tick_0205 = game and game.tick or 0
  return true
end

-- Final enforcement after any respawn/ensure wrapper chain: if a platform priest is created
-- anywhere other than the visible marker, immediately move it to the marker and log it.
if respawn_pair_priest then
  TECH_PRIESTS_ORIGINAL_RESPAWN_PAIR_PRIEST_0207 = respawn_pair_priest
  function respawn_pair_priest(pair, reason)
    local ok = TECH_PRIESTS_ORIGINAL_RESPAWN_PAIR_PRIEST_0207(pair, reason)
    if ok and tech_priests_platform_pair_0206 and tech_priests_platform_pair_0206(pair) and pair.priest and pair.priest.valid then
      local pos = tech_priests_get_authoritative_platform_spawn_locus_0207(pair, pair.priest.name)
      if pos and tech_priests_position_distance_sq_0207(pair.priest.position, pos) > TECH_PRIESTS_PLATFORM_SPAWN_ENFORCE_EPSILON_SQ_0207 then
        if tech_priests_lifecycle_note_0201 then
          tech_priests_lifecycle_note_0201(pair, "platform spawn locus enforced", pair.priest, "from=" .. tostring(pair.priest.position.x) .. "," .. tostring(pair.priest.position.y) .. " to=" .. tostring(pos.x) .. "," .. tostring(pos.y))
        end
        pcall(function() pair.priest.teleport(pos, pair.station.surface) end)
      end
      if tech_priests_tether_platform_priest_0206 then tech_priests_tether_platform_priest_0206(pair, "post-respawn spawn-locus enforcement") end
    end
    return ok
  end
end

if ensure_pair_priest then
  TECH_PRIESTS_ORIGINAL_ENSURE_PAIR_PRIEST_0207 = ensure_pair_priest
  function ensure_pair_priest(pair, force_recall, immediate)
    local result = TECH_PRIESTS_ORIGINAL_ENSURE_PAIR_PRIEST_0207(pair, force_recall, immediate)
    if result and tech_priests_platform_pair_0206 and tech_priests_platform_pair_0206(pair) and pair.priest and pair.priest.valid then
      local pos = tech_priests_get_authoritative_platform_spawn_locus_0207(pair, pair.priest.name)
      if pos and tech_priests_position_distance_sq_0207(pair.priest.position, pos) > TECH_PRIESTS_PLATFORM_SPAWN_ENFORCE_EPSILON_SQ_0207 then
        if tech_priests_lifecycle_note_0201 then
          tech_priests_lifecycle_note_0201(pair, "platform ensure locus enforced", pair.priest, "from=" .. tostring(pair.priest.position.x) .. "," .. tostring(pair.priest.position.y) .. " to=" .. tostring(pos.x) .. "," .. tostring(pos.y))
        end
        pcall(function() pair.priest.teleport(pos, pair.station.surface) end)
      end
      if tech_priests_tether_platform_priest_0206 then tech_priests_tether_platform_priest_0206(pair, "post-ensure spawn-locus enforcement") end
    end
    return result
  end
end

TechPriestsRuntimeEventRegistry.on_nth_tick(557, function()
  if not (storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return end
  for _, pair in pairs(storage.tech_priests.pairs_by_station) do
    if tech_priests_platform_pair_0206 and tech_priests_platform_pair_0206(pair) then
      local pos = tech_priests_get_authoritative_platform_spawn_locus_0207(pair)
      if pos and pair.priest and pair.priest.valid and tech_priests_position_distance_sq_0207(pair.priest.position, pos) > TECH_PRIESTS_PLATFORM_SPAWN_ENFORCE_EPSILON_SQ_0207 then
        if tech_priests_lifecycle_note_0201 then tech_priests_lifecycle_note_0201(pair, "periodic platform locus correction", pair.priest, tostring(pos.x) .. "," .. tostring(pos.y)) end
        pcall(function() pair.priest.teleport(pos, pair.station.surface) end)
      end
    end
  end
end)


-- 0.1.208 Exact platform spawn-locus enforcement.
-- 0.1.207 proved the marker/tether choice could still be based on a lenient
-- find_non_colliding_position result: the rendered marker could sit on a tile
-- where the priest entity itself could not actually stand, so create/teleport
-- snapped or remained near the station.  Platform spawn loci must now be exact.
TECH_PRIESTS_PLATFORM_EXACT_EPSILON_SQ_0208 = 0.16
TECH_PRIESTS_PLATFORM_RECREATE_OFFSETS_0208 = {
  { x = 0, y = 0 },
  { x = 0.15, y = 0 }, { x = -0.15, y = 0 },
  { x = 0, y = 0.15 }, { x = 0, y = -0.15 }
}

function tech_priests_exact_platform_tile_free_0208(station, priest_name, position)
  if not (station and station.valid and priest_name and position) then return false end
  if tech_priests_space_spawn_is_blacklisted_0205 and tech_priests_space_spawn_is_blacklisted_0205(station, position) then return false end
  if not (tech_priests_space_tile_is_foundation_0205 and tech_priests_space_tile_is_foundation_0205(station.surface, position)) then return false end
  if tech_priests_tile_has_bad_spawn_entity_0204 and tech_priests_tile_has_bad_spawn_entity_0204(station.surface, position) then return false end
  local ok_place, can_place = pcall(function()
    return station.surface.can_place_entity({ name = priest_name, position = position, force = station.force })
  end)
  return ok_place and can_place or false
end

function tech_priests_pair_priest_is_at_0208(pair, position)
  if not (pair and pair.priest and pair.priest.valid and position) then return false end
  if pair.priest.surface ~= pair.station.surface then return false end
  local dx = pair.priest.position.x - position.x
  local dy = pair.priest.position.y - position.y
  return (dx * dx + dy * dy) <= TECH_PRIESTS_PLATFORM_EXACT_EPSILON_SQ_0208
end

function tech_priests_exact_platform_locus_valid_0208(pair, position, priest_name)
  if not (pair and pair.station and pair.station.valid and position and priest_name) then return false end
  if not (tech_priests_pair_on_space_platform_0204 and tech_priests_pair_on_space_platform_0204(pair)) then return false end
  if tech_priests_position_distance_sq_0207 and tech_priests_position_distance_sq_0207(position, pair.station.position) <= TECH_PRIESTS_PLATFORM_STATION_TILE_EPSILON_SQ_0207 then return false end
  if tech_priests_pair_priest_is_at_0208(pair, position) then return true end
  return tech_priests_exact_platform_tile_free_0208(pair.station, priest_name, position)
end

function tech_priests_find_exact_space_platform_spawn_tile_0208(station, priest_name)
  if not (station and station.valid and priest_name and tech_priests_surface_is_space_platform_0204 and tech_priests_surface_is_space_platform_0204(station.surface)) then return nil end
  local base = tech_priests_round_tile_center_0176 and tech_priests_round_tile_center_0176(station.position) or { x = math.floor(station.position.x) + 0.5, y = math.floor(station.position.y) + 0.5 }
  local radius = TECH_PRIESTS_SPACE_PLATFORM_EXTRA_SEARCH_RADIUS_0205 or 36
  for ring = 1, radius do
    for dx = -ring, ring do
      for dy = -ring, ring do
        if math.max(math.abs(dx), math.abs(dy)) == ring then
          local position = { x = base.x + dx, y = base.y + dy }
          if tech_priests_exact_platform_tile_free_0208(station, priest_name, position) then
            if tech_priests_lifecycle_note_0201 then
              local pair = storage and storage.tech_priests and storage.tech_priests.pairs_by_station and storage.tech_priests.pairs_by_station[station.unit_number]
              tech_priests_lifecycle_note_0201(pair, "exact platform spawn candidate selected", nil, tostring(position.x) .. "," .. tostring(position.y) .. " ring=" .. tostring(ring))
            end
            return position
          end
        end
      end
    end
  end
  return nil
end

-- Replace the lenient 0.1.205 platform candidate tester. It must not accept a
-- nearby non-colliding position unless that exact nearby position becomes the marker.
function tech_priests_platform_spawn_candidate_ok_0205(station, priest_name, position)
  return tech_priests_exact_platform_tile_free_0208(station, priest_name, position)
end

-- Replace the 0.1.205 platform finder with exact-tile search.
function tech_priests_find_space_platform_spawn_tile_0205(station, priest_name)
  return tech_priests_find_exact_space_platform_spawn_tile_0208(station, priest_name)
end

-- Platform find_spawn_position must return the same exact tile that will be rendered.
if find_spawn_position then
  TECH_PRIESTS_ORIGINAL_FIND_SPAWN_POSITION_0208 = find_spawn_position
  function find_spawn_position(station, priest_name)
    if station and station.valid and priest_name and tech_priests_surface_is_space_platform_0204 and tech_priests_surface_is_space_platform_0204(station.surface) then
      local pair = storage and storage.tech_priests and storage.tech_priests.pairs_by_station and storage.tech_priests.pairs_by_station[station.unit_number]
      local stored = tech_priests_get_remembered_spawn_position_0176 and tech_priests_get_remembered_spawn_position_0176(station) or nil
      if pair and stored and tech_priests_exact_platform_locus_valid_0208(pair, stored, priest_name) then
        return { x = stored.x, y = stored.y }
      end
      if stored and not tech_priests_exact_platform_tile_free_0208(station, priest_name, stored) then
        if storage and storage.tech_priests and storage.tech_priests.spawn_positions_by_station then storage.tech_priests.spawn_positions_by_station[station.unit_number] = nil end
        if pair then pair.spawn_position = nil end
        if tech_priests_lifecycle_note_0201 then tech_priests_lifecycle_note_0201(pair, "discarded non-exact platform spawn marker", pair and pair.priest, tostring(stored.x) .. "," .. tostring(stored.y)) end
      end
      local selected = tech_priests_find_exact_space_platform_spawn_tile_0208(station, priest_name)
      if selected then
        if tech_priests_set_remembered_spawn_position_0176 then tech_priests_set_remembered_spawn_position_0176(station, selected) end
        return selected
      end
      return nil
    end
    return TECH_PRIESTS_ORIGINAL_FIND_SPAWN_POSITION_0208(station, priest_name)
  end
end

-- Override authoritative platform locus again, using exact validation only.
function tech_priests_get_authoritative_platform_spawn_locus_0207(pair, priest_name)
  if not (pair and pair.station and pair.station.valid) then return nil end
  if not (tech_priests_pair_on_space_platform_0204 and tech_priests_pair_on_space_platform_0204(pair)) then return nil end
  priest_name = priest_name or (pair.priest and pair.priest.valid and pair.priest.name) or nil
  if not priest_name then
    local cfg = get_station_config and get_station_config(pair.station) or nil
    priest_name = cfg and get_priest_name_for_force and get_priest_name_for_force(cfg, pair.station.force) or nil
  end
  if not priest_name then return nil end

  local stored = tech_priests_get_remembered_spawn_position_0176 and tech_priests_get_remembered_spawn_position_0176(pair.station) or nil
  if stored and tech_priests_exact_platform_locus_valid_0208(pair, stored, priest_name) then
    pair.spawn_position = { x = stored.x, y = stored.y }
    pair.space_platform_tether_0206 = pair.space_platform_tether_0206 or {}
    pair.space_platform_tether_0206.position = { x = stored.x, y = stored.y }
    return { x = stored.x, y = stored.y }
  end

  if stored then
    if storage and storage.tech_priests and storage.tech_priests.spawn_positions_by_station then storage.tech_priests.spawn_positions_by_station[pair.station.unit_number] = nil end
    pair.spawn_position = nil
    if pair.space_platform_tether_0206 then pair.space_platform_tether_0206.position = nil end
    if tech_priests_lifecycle_note_0201 then tech_priests_lifecycle_note_0201(pair, "platform marker invalidated for exact spawn", pair.priest, tostring(stored.x) .. "," .. tostring(stored.y)) end
  end

  local selected = tech_priests_find_exact_space_platform_spawn_tile_0208(pair.station, priest_name)
  if selected then
    if tech_priests_set_remembered_spawn_position_0176 then tech_priests_set_remembered_spawn_position_0176(pair.station, selected) end
    pair.spawn_position = { x = selected.x, y = selected.y }
    pair.space_platform_tether_0206 = pair.space_platform_tether_0206 or {}
    pair.space_platform_tether_0206.position = { x = selected.x, y = selected.y }
    if tech_priests_lifecycle_note_0201 then tech_priests_lifecycle_note_0201(pair, "platform exact spawn marker repaired", pair.priest, tostring(selected.x) .. "," .. tostring(selected.y)) end
    return { x = selected.x, y = selected.y }
  end
  return nil
end

function tech_priests_platform_entity_close_enough_0208(entity, position)
  if not (entity and entity.valid and position) then return false end
  local dx = entity.position.x - position.x
  local dy = entity.position.y - position.y
  return (dx * dx + dy * dy) <= TECH_PRIESTS_PLATFORM_EXACT_EPSILON_SQ_0208
end

function tech_priests_force_priest_to_platform_locus_0208(pair, reason)
  if not (pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid) then return false end
  if not (tech_priests_pair_on_space_platform_0204 and tech_priests_pair_on_space_platform_0204(pair)) then return false end
  local priest = pair.priest
  local pos = tech_priests_get_authoritative_platform_spawn_locus_0207(pair, priest.name)
  if not pos then return false end
  if tech_priests_platform_entity_close_enough_0208(priest, pos) then return true end

  pcall(function() if priest.commandable then priest.commandable.set_command({ type = defines.command.stop }) end end)
  pcall(function() priest.active = true end)
  local ok_teleport = false
  local ok_a, result_a = pcall(function() return priest.teleport(pos, pair.station.surface) end)
  if ok_a and result_a ~= false and tech_priests_platform_entity_close_enough_0208(priest, pos) then ok_teleport = true end
  if not ok_teleport then
    local ok_b, result_b = pcall(function() return priest.teleport(pos) end)
    if ok_b and result_b ~= false and tech_priests_platform_entity_close_enough_0208(priest, pos) then ok_teleport = true end
  end

  if ok_teleport then
    if tech_priests_lifecycle_note_0201 then tech_priests_lifecycle_note_0201(pair, "platform priest exact teleport success", priest, tostring(reason or "enforce") .. " to=" .. tostring(pos.x) .. "," .. tostring(pos.y)) end
    pcall(function() priest.active = false end)
    pcall(function() priest.destructible = false end)
    return true
  end

  -- Teleport can fail for unit entities on space platforms.  Recreate the unit at
  -- the exact marker and only swap mappings if the new entity actually lands there.
  local old = priest
  local old_unit = old.unit_number
  local old_health_ratio = get_health_ratio and get_health_ratio(old) or pair.linked_health_ratio or 1
  local created = nil
  for _, off in ipairs(TECH_PRIESTS_PLATFORM_RECREATE_OFFSETS_0208) do
    local try_pos = { x = pos.x + off.x, y = pos.y + off.y }
    local ok_create, ent = pcall(function()
      return pair.station.surface.create_entity({
        name = old.name,
        position = try_pos,
        direction = pair.station.direction or defines.direction.east,
        quality = get_entity_quality_name and get_entity_quality_name(pair.station) or nil,
        force = pair.station.force,
        raise_built = false
      })
    end)
    if ok_create and ent and ent.valid and tech_priests_platform_entity_close_enough_0208(ent, pos) then
      created = ent
      break
    elseif ok_create and ent and ent.valid then
      if tech_priests_destroy_priest_0500 and tech_priests_is_priest_0500 and tech_priests_is_priest_0500(ent) then
        tech_priests_destroy_priest_0500(ent, "platform-recreate-rejected-new-priest", pair)
      else
        pcall(function() ent.destroy({ raise_destroy = false }) end)
      end
    end
  end

  if created and created.valid and created.unit_number then
    if old and old.valid then
      if tech_priests_destroy_priest_0500 then
        tech_priests_destroy_priest_0500(old, "platform-recreate-old-priest", pair)
      else
        pcall(function() old.destroy({ raise_destroy = false }) end)
      end
    end
    if old_unit and storage and storage.tech_priests and storage.tech_priests.station_by_priest then storage.tech_priests.station_by_priest[old_unit] = nil end
    pair.priest = created
    pair.priest_unit = created.unit_number
    pair.station_unit = pair.station.unit_number
    pair.force = pair.station.force.name
    pair.surface = pair.station.surface.index
    if set_health_ratio then set_health_ratio(created, old_health_ratio) end
    if storage and storage.tech_priests then
      storage.tech_priests.station_by_priest = storage.tech_priests.station_by_priest or {}
      storage.tech_priests.pairs_by_station = storage.tech_priests.pairs_by_station or {}
      storage.tech_priests.station_by_priest[created.unit_number] = pair.station.unit_number
      storage.tech_priests.pairs_by_station[pair.station.unit_number] = pair
    end
    if apply_pair_display_names then apply_pair_display_names(pair) end
    if tech_priests_stop_platform_priest_0206 then tech_priests_stop_platform_priest_0206(pair, "exact platform recreate") end
    if tech_priests_lifecycle_note_0201 then tech_priests_lifecycle_note_0201(pair, "platform priest recreated at exact locus", created, tostring(reason or "recreate") .. " to=" .. tostring(pos.x) .. "," .. tostring(pos.y)) end
    return true
  end

  if tech_priests_lifecycle_note_0201 then tech_priests_lifecycle_note_0201(pair, "platform exact locus enforcement failed", old, tostring(reason or "unknown") .. " target=" .. tostring(pos.x) .. "," .. tostring(pos.y)) end
  pcall(function() old.active = false end)
  pcall(function() old.destructible = false end)
  return false
end

-- Final override of platform tether to use exact teleport/recreate behavior.

if respawn_pair_priest then
  TECH_PRIESTS_ORIGINAL_RESPAWN_PAIR_PRIEST_0208 = respawn_pair_priest
  function respawn_pair_priest(pair, reason)
    local ok = TECH_PRIESTS_ORIGINAL_RESPAWN_PAIR_PRIEST_0208(pair, reason)
    if ok and tech_priests_platform_pair_0206 and tech_priests_platform_pair_0206(pair) and pair.priest and pair.priest.valid then
      tech_priests_force_priest_to_platform_locus_0208(pair, "post-respawn exact locus")
    end
    return ok
  end
end

if ensure_pair_priest then
  TECH_PRIESTS_ORIGINAL_ENSURE_PAIR_PRIEST_0208 = ensure_pair_priest
  function ensure_pair_priest(pair, force_recall, immediate)
    local result = TECH_PRIESTS_ORIGINAL_ENSURE_PAIR_PRIEST_0208(pair, force_recall, immediate)
    if result and tech_priests_platform_pair_0206 and tech_priests_platform_pair_0206(pair) and pair.priest and pair.priest.valid then
      tech_priests_force_priest_to_platform_locus_0208(pair, "post-ensure exact locus")
    end
    return result
  end
end

TechPriestsRuntimeEventRegistry.on_nth_tick(431, function()
  if not (storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return end
  for _, pair in pairs(storage.tech_priests.pairs_by_station) do
    if tech_priests_platform_pair_0206 and tech_priests_platform_pair_0206(pair) and pair.priest and pair.priest.valid then
      tech_priests_force_priest_to_platform_locus_0208(pair, "periodic exact platform locus")
    end
  end
end)

-- 0.1.209 Space-platform controlled pathfinding restoration.
-- 0.1.208 proved exact platform spawn/tether loci are stable, but the diagnostic
-- tether still suppressed all platform movement.  This patch changes the platform
-- tether into a safety guard: priests may pathfind to validated platform targets
-- inside their station radius, while unsafe drift or invalid targets snap them back
-- to the authoritative spawn locus.
TECH_PRIESTS_PLATFORM_PATH_MAX_DRIFT_SQ_0209 = 2.25
TECH_PRIESTS_PLATFORM_PATH_TARGET_REACHED_SQ_0209 = 1.44
TECH_PRIESTS_PLATFORM_PATH_STALE_TICKS_0209 = 60 * 12
TECH_PRIESTS_PLATFORM_PATH_LOG_TICKS_0209 = 60 * 6

function tech_priests_position_from_target_0209(target)
  if not target then return nil end
  if target.valid ~= nil and target.position then return target.position end
  if target.position then return target.position end
  if target.x and target.y then return target end
  if type(target) == "table" and target[1] and target[2] then return { x = target[1], y = target[2] } end
  return nil
end

function tech_priests_platform_position_in_station_radius_0209(pair, position)
  if not (pair and pair.station and pair.station.valid and position) then return false end
  local radius = (refresh_pair_radius and refresh_pair_radius(pair)) or pair.radius or (get_station_operating_radius and get_station_operating_radius(pair.station)) or 30
  local dx = (position.x or 0) - pair.station.position.x
  local dy = (position.y or 0) - pair.station.position.y
  return (dx * dx + dy * dy) <= (radius + 2) * (radius + 2)
end


function tech_priests_platform_begin_path_0209(pair, target, reason)
  if not (tech_priests_platform_pair_0206 and tech_priests_platform_pair_0206(pair) and pair.priest and pair.priest.valid) then return false end
  local pos = tech_priests_position_from_target_0209(target)
  if not pos then return false end
  if not tech_priests_platform_position_in_station_radius_0209(pair, pos) then
    if tech_priests_lifecycle_note_0201 then tech_priests_lifecycle_note_0201(pair, "platform path rejected", pair.priest, "outside radius " .. tostring(pos.x) .. "," .. tostring(pos.y)) end
    return false
  end
  if tech_priests_space_tile_is_foundation_0205 and not tech_priests_space_tile_is_foundation_0205(pair.station.surface, pos) then
    if tech_priests_lifecycle_note_0201 then tech_priests_lifecycle_note_0201(pair, "platform path rejected", pair.priest, "non-foundation " .. tostring(pos.x) .. "," .. tostring(pos.y)) end
    return false
  end

  pair.space_platform_pathing_0209 = {
    active = true,
    target = { x = pos.x, y = pos.y },
    started_tick = game.tick,
    last_seen_tick = game.tick,
    reason = tostring(reason or "platform movement"),
    last_log_tick = game.tick
  }
  pair.space_platform_tether_0206 = pair.space_platform_tether_0206 or {}
  pair.space_platform_tether_0206.allow_pathing = true
  pair.mode = pair.mode == "space-platform-doctrine" and "platform-working" or pair.mode
  pcall(function() pair.priest.active = true end)
  pcall(function() pair.priest.destructible = false end)
  if tech_priests_lifecycle_note_0201 then
    tech_priests_lifecycle_note_0201(pair, "platform pathfinding resumed", pair.priest, tostring(reason or "move") .. " target=" .. tostring(pos.x) .. "," .. tostring(pos.y))
  end
  return true
end

function tech_priests_platform_clear_path_0209(pair, reason)
  if not pair then return end
  if pair.space_platform_pathing_0209 and pair.space_platform_pathing_0209.active and tech_priests_lifecycle_note_0201 and pair.priest and pair.priest.valid then
    tech_priests_lifecycle_note_0201(pair, "platform pathing cleared", pair.priest, tostring(reason or "complete"))
  end
  pair.space_platform_pathing_0209 = nil
  if pair.space_platform_tether_0206 then pair.space_platform_tether_0206.allow_pathing = nil end
end

function tech_priests_platform_path_guard_0209(pair, reason)
  if not (tech_priests_platform_pair_0206 and tech_priests_platform_pair_0206(pair) and pair.priest and pair.priest.valid) then return false end
  local path = pair.space_platform_pathing_0209
  if not (path and path.active and path.target) then return false end
  local priest = pair.priest
  local target = path.target

  if priest.surface ~= pair.station.surface then
    tech_priests_platform_clear_path_0209(pair, "surface mismatch")
    return false
  end

  local px, py = priest.position.x, priest.position.y
  local tx, ty = target.x, target.y
  local dx, dy = px - tx, py - ty
  local target_sq = dx * dx + dy * dy
  if target_sq <= TECH_PRIESTS_PLATFORM_PATH_TARGET_REACHED_SQ_0209 then
    path.last_seen_tick = game.tick
    tech_priests_platform_clear_path_0209(pair, "target reached")
    pcall(function() if priest.commandable then priest.commandable.set_command({ type = defines.command.stop }) end end)
    return true
  end

  if (game.tick - (path.started_tick or game.tick)) > TECH_PRIESTS_PLATFORM_PATH_STALE_TICKS_0209 then
    tech_priests_platform_clear_path_0209(pair, "stale timeout")
    if tech_priests_lifecycle_note_0201 then tech_priests_lifecycle_note_0201(pair, "platform path stale; returning to locus", priest, tostring(reason or "guard")) end
    return false
  end

  if tech_priests_space_tile_is_foundation_0205 and not tech_priests_space_tile_is_foundation_0205(pair.station.surface, priest.position) then
    tech_priests_platform_clear_path_0209(pair, "unsafe current tile")
    if tech_priests_lifecycle_note_0201 then tech_priests_lifecycle_note_0201(pair, "platform unsafe drift", priest, "current tile unsafe") end
    return false
  end

  if not tech_priests_platform_position_in_station_radius_0209(pair, priest.position) then
    tech_priests_platform_clear_path_0209(pair, "outside station radius")
    if tech_priests_lifecycle_note_0201 then tech_priests_lifecycle_note_0201(pair, "platform path outside radius", priest, "returning to locus") end
    return false
  end

  local last_log = path.last_log_tick or 0
  if tech_priests_lifecycle_note_0201 and (game.tick - last_log) > TECH_PRIESTS_PLATFORM_PATH_LOG_TICKS_0209 then
    path.last_log_tick = game.tick
    tech_priests_lifecycle_note_0201(pair, "platform path guard", priest, tostring(path.reason or "move") .. " target=" .. tostring(tx) .. "," .. tostring(ty))
  end
  return true
end

-- Re-enable ordinary move commands on platforms, but only after we record a guard target.
if TECH_PRIESTS_ORIGINAL_MOVE_PRIEST_TO_0206 then
end

if TECH_PRIESTS_ORIGINAL_RETURN_TO_STATION_0206 then
end

-- Turn the hard tether into a guard.  During active guarded pathing, do not snap the
-- priest back to the marker unless the guard reports unsafe/stale movement.

-- Additional slow guard/heartbeat for platform pathing. The older 3-tick tether still
-- calls the overridden tether function above, so this mainly adds explicit audit notes.
TechPriestsRuntimeEventRegistry.on_nth_tick(257, function()
  if not (storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return end
  for _, pair in pairs(storage.tech_priests.pairs_by_station) do
    if tech_priests_platform_pair_0206 and tech_priests_platform_pair_0206(pair) and pair.priest and pair.priest.valid then
      if pair.space_platform_pathing_0209 and pair.space_platform_pathing_0209.active then
        tech_priests_platform_path_guard_0209(pair, "257 path guard")
      end
    end
  end
end)

-- 0.1.211 emergency doctrine readability and material-delivery pass:
-- * Stack/status text lines by pair so emergency operation chatter does not render
--   four unreadable overlapping lines on top of a priest.
-- * Abbreviate long writ identifiers and suppress duplicate status spam.
-- * Ensure emergency-scrounged raw goods are represented in station inventories
--   where possible, and ensure assist jobs try to hand acquired goods to the lead
--   shrine immediately after acquisition/crafting.

function tech_priests_pair_status_key_0211(pair)
  if pair and pair.station and pair.station.valid then return pair.station.unit_number or 0 end
  if pair and pair.priest and pair.priest.valid then return pair.priest.unit_number or 0 end
  return 0
end

function tech_priests_trim_text_0211(text, limit)
  text = tostring(text or "")
  limit = limit or 92
  if #text <= limit then return text end
  return string.sub(text, 1, limit - 3) .. "..."
end

function tech_priests_abbrev_writ_0211(text)
  text = tostring(text or "")
  text = string.gsub(text, "Writ ([%d:]+)", function(id)
    local tail = string.sub(tostring(id), -7)
    return "Writ #" .. tail
  end)
  text = string.gsub(text, "Task%-force writ ([%d:]+)", function(id)
    local tail = string.sub(tostring(id), -7)
    return "Task-force writ #" .. tail
  end)
  text = string.gsub(text, "seniority%-task%-force%-assignment", "task-force")
  text = string.gsub(text, "raw%-resource:wood", "wood")
  text = string.gsub(text, "Emergency Operation · ", "Emergency · ")
  return text
end

function tech_priests_sanitize_status_text_0211(text)
  text = tech_priests_abbrev_writ_0211(text)
  -- Drop obviously malformed nested rich-text item tags rather than letting one
  -- bad item-name smear across the entire screen.
  text = string.gsub(text, "%[item=([^%]]*%[[^%]]*)%]", "[item=wood]")
  text = string.gsub(text, "%[item=([^%]]*=+[^%]]*)%]", "")
  return tech_priests_trim_text_0211(text, 96)
end

function tech_priests_draw_stacked_status_text_0211(pair, text, color, ttl, scale, channel)
  if not (pair and pair.priest and pair.priest.valid and text and rendering and rendering.draw_text) then return false end
  text = tech_priests_sanitize_status_text_0211(text)
  if text == "" then return false end
  pair.tech_priests_status_render_0211 = pair.tech_priests_status_render_0211 or {}
  pair.tech_priests_status_last_0211 = pair.tech_priests_status_last_0211 or {}
  channel = channel or "general"
  local now = game.tick
  local last = pair.tech_priests_status_last_0211[channel]
  if last and last.text == text and now < (last.next_tick or 0) then return true end
  pair.tech_priests_status_last_0211[channel] = { text = text, next_tick = now + 60 }
  local row = (pair.tech_priests_status_row_0211 or 0) % 5
  pair.tech_priests_status_row_0211 = row + 1
  local offset_y = -2.75 - (row * 0.58)
  pcall(function()
    rendering.draw_text({
      text = text,
      target = { entity = pair.priest, offset = { 0, offset_y } },
      surface = pair.priest.surface,
      color = color or { r = 1.0, g = 0.65, b = 0.18, a = 0.95 },
      scale = scale or 0.62,
      alignment = "center",
      time_to_live = ttl or 150
    })
  end)
  return true
end

-- Override the two most spammy emergency/status text emitters with the stacked,
-- throttled renderer. Keep their names unchanged so all older doctrine code uses
-- the improved display automatically.
function tech_priests_draw_emergency_operation_status_0184(pair, text)
  return tech_priests_draw_stacked_status_text_0211(pair, text, { r = 1.0, g = 0.55, b = 0.12, a = 0.95 }, 60 * 3, 0.62, "emergency")
end

function tech_priests_task_force_snippet_0187(pair, text)
  return tech_priests_draw_stacked_status_text_0211(pair, text, { r = 1.0, g = 0.78, b = 0.22, a = 0.95 }, 60 * 4, 0.60, "task-force")
end

function tech_priests_safe_insert_station_item_0211(pair, item_name, count, quality)
  if not (pair and pair.station and pair.station.valid and item_name) then return 0 end
  local inv = get_station_inventory(pair.station)
  if not inv then return 0 end
  count = math.max(1, count or 1)
  local stack = make_item_stack_identification and make_item_stack_identification(item_name, count, quality) or { name = item_name, count = count }
  local inserted = 0
  pcall(function() inserted = inv.insert(stack) or 0 end)
  if inserted > 0 and tech_priests_draw_emergency_operation_status_0184 then
    tech_priests_draw_emergency_operation_status_0184(pair, "[item=" .. item_name .. "] deposited in Cogitator Station")
  end
  return inserted or 0
end

-- Emergency desperation gathering used to convert raw salvage directly into an
-- invisible pseudo-counter.  Keep the pseudo-counter for compatibility, but also
-- put one visibly scavenged unit into the station when practical so the player can
-- see the doctrine actually stocking the shrine.
TECH_PRIESTS_ORIGINAL_ACQUIRE_EMERGENCY_MATERIAL_0211 = acquire_emergency_material
function acquire_emergency_material(pair, task, candidate)
  local before_units = task and task.gathered_units or 0
  local result = TECH_PRIESTS_ORIGINAL_ACQUIRE_EMERGENCY_MATERIAL_0211(pair, task, candidate)
  if result and pair and candidate and candidate.item_name then
    local gained_units = math.max(0, (task and task.gathered_units or 0) - (before_units or 0))
    if gained_units > 0 then
      -- Insert one representative item per successful gather action. This avoids
      -- dumping entire chests but makes inventory-raids, tree salvage, resource
      -- scrounging, and asteroid salvage visible to the station/lead doctrine.
      tech_priests_safe_insert_station_item_0211(pair, candidate.item_name, 1, candidate.quality)
    end
  end
  return result
end

function tech_priests_try_fulfill_assist_job_now_0211(pair)
  local job = pair and pair.emergency_assist_job_0187 or nil
  if not job then return false end
  local lead_pair = nil
  if job.lead_station_unit and storage and storage.tech_priests and storage.tech_priests.pairs_by_station then
    lead_pair = storage.tech_priests.pairs_by_station[job.lead_station_unit]
  end
  if not (lead_pair and lead_pair.station and lead_pair.station.valid and pair.station and pair.station.valid) then return false end
  local own_inv = get_station_inventory(pair.station)
  if not (own_inv and job.item_name and own_inv.get_item_count(job.item_name) > 0) then return false end
  local moved = tech_priests_transfer_between_station_inventories_0187 and tech_priests_transfer_between_station_inventories_0187(pair, lead_pair, job.item_name, job.count or 1) or 0
  if moved and moved > 0 then
    tech_priests_task_force_snippet_0187(pair, "[item=" .. job.item_name .. "] Writ " .. tostring(job.id) .. " fulfilled to lead shrine.")
    tech_priests_task_force_snippet_0187(lead_pair, "[item=" .. job.item_name .. "] Writ " .. tostring(job.id) .. " delivered to lead inventory.")
    local lead_op = lead_pair.independent_emergency_operation_0184
    if lead_op and lead_op.task_force_jobs_0187 then lead_op.task_force_jobs_0187[job.id] = nil end
    pair.emergency_assist_job_0187 = nil
    pair.emergency_assist_op_0187 = nil
    return true
  end
  return false
end

TECH_PRIESTS_ORIGINAL_FINISH_EMERGENCY_DESPERATION_CRAFT_0211 = finish_emergency_desperation_craft
