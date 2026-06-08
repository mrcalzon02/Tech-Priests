-- Auto-split control.lua fragment 013 for Tech Priests 0.1.438.
-- Generated mechanically from 0.1.437 monolithic control.lua.
-- Purpose: reduce Lua main-chunk local/register pressure without deleting behavior.


function tech_priests_0219_platform_maneuver_target(pair, destination, reason)
  return tech_priests_0220_begin_hover_glide(pair, destination, reason or "void-duty maneuvering thrusters")
end

function tech_priests_platform_path_guard_0209(pair, reason)
  if not (pair and pair.priest and pair.priest.valid and pair.space_platform_pathing_0209 and pair.space_platform_pathing_0209.active) then return false end
  local priest = pair.priest
  if not (pair.station and pair.station.valid and priest.surface == pair.station.surface) then return false end
  if not tech_priests_0220_in_radius(pair, priest.position) then return false end
  local path = pair.space_platform_pathing_0209
  if (tech_priests_0220_tick() - (path.started_tick or tech_priests_0220_tick())) > TECH_PRIESTS_PLATFORM_HOVER_TIMEOUT_0220 then return false end
  path.last_seen_tick = tech_priests_0220_tick()
  return true
end

function tech_priests_0220_hover_step_pair(pair)
  if not (pair and pair.priest and pair.priest.valid and pair.space_platform_pathing_0209 and pair.space_platform_pathing_0209.active) then return false end
  local path = pair.space_platform_pathing_0209
  local now = tech_priests_0220_tick()
  if now < (path.last_hover_step_tick_0220 or 0) + TECH_PRIESTS_PLATFORM_HOVER_STEP_TICKS_0220 then return true end
  path.last_hover_step_tick_0220 = now
  local priest = pair.priest
  if not tech_priests_platform_path_guard_0209(pair, "hover-glide precheck") then
    if tech_priests_platform_clear_path_0209 then tech_priests_platform_clear_path_0209(pair, "hover-glide guard ended") else pair.space_platform_pathing_0209 = nil end
    return false
  end
  local target = path.target
  if not target then return false end
  local px, py = priest.position.x, priest.position.y
  local dx = target.x - px
  local dy = target.y - py
  local dist = math.sqrt(dx * dx + dy * dy)
  if dist <= TECH_PRIESTS_PLATFORM_HOVER_EPSILON_0220 then
    pcall(function() priest.active = true end)
    if tech_priests_platform_clear_path_0209 then tech_priests_platform_clear_path_0209(pair, "hover-glide arrived") else pair.space_platform_pathing_0209 = nil end
    return true
  end
  local step = math.min(TECH_PRIESTS_PLATFORM_HOVER_STEP_DISTANCE_0220, dist)
  local next_pos = { x = px + dx / dist * step, y = py + dy / dist * step }
  if not tech_priests_0220_in_radius(pair, next_pos) then
    if tech_priests_platform_clear_path_0209 then tech_priests_platform_clear_path_0209(pair, "hover-glide radius limit") else pair.space_platform_pathing_0209 = nil end
    return false
  end
  tech_priests_0220_face_direction(priest, dx, dy)
  tech_priests_0220_emit_thruster_puff(pair, priest.position, dx, dy)
  -- This is a tiny per-frame translation, not a pathfinding teleport.  We do not
  -- validate local collision here; void-duty priests hover over obstructions.
  local ok, moved = true, false
  if tech_priests_platform_hover_translate_0430 then
    moved = tech_priests_platform_hover_translate_0430(pair, next_pos, "platform hover-glide step")
  else
    ok, moved = pcall(function() return priest.teleport(next_pos, priest.surface) end)
  end
  if ok and moved ~= false then
    path.last_seen_tick = now
    return true
  end
  -- If the engine refuses the unit placement at this coordinate, park this path
  -- without snapping the priest back to the locus.  The scheduler can pick a new
  -- target later, avoiding the visible jump-forward/jump-back loop.
  if tech_priests_platform_clear_path_0209 then tech_priests_platform_clear_path_0209(pair, "hover-glide placement refused") else pair.space_platform_pathing_0209 = nil end
  return false
end

function tech_priests_0216_platform_step_pair(pair)
  return tech_priests_0220_hover_step_pair(pair)
end

-- Any late movement call for a platform priest should set a hover target, not a
-- Factorio path command and not a station-locus snapback.
function move_priest_to(priest, target)
  local pair = tech_priests_pair_by_priest_0206 and tech_priests_pair_by_priest_0206(priest) or nil
  if pair and tech_priests_pair_on_space_platform_0204 and tech_priests_pair_on_space_platform_0204(pair) then
    local pos = nil
    if target then
      if target.valid and target.position then pos = target.position
      elseif target.position then pos = target.position
      elseif target.x and target.y then pos = target end
    end
    if not pos and tech_priests_0215_platform_patrol_destination then pos = tech_priests_0215_platform_patrol_destination(pair) end
    if pos then return tech_priests_0220_begin_hover_glide(pair, pos, "move_priest_to hover-glide") end
    return false
  end
  if TECH_PRIESTS_ORIGINAL_MOVE_PRIEST_TO_0206 then return TECH_PRIESTS_ORIGINAL_MOVE_PRIEST_TO_0206(priest, target) end
  return false
end


-- 0.1.221 Void Tech-Priest and platform movement de-snap pass.
-- Space priests are no longer to be treated as walkers.  Any legacy recovery
-- path that tries to hard-snap a platform priest to the spawn locus is softened
-- into a hover-glide recall, so the visible jump-forward/jump-back loop stops.
TECH_PRIESTS_PLANETSIDE_STATIONS_0221 = {
  ["junior-cogitator-station"] = true,
  ["intermediate-cogitator-station"] = true,
  ["senior-cogitator-station"] = true,
  ["planetary-magos-cogitator-station"] = true
}
TECH_PRIESTS_VOID_STATION_0221 = "void-cogitator-station"

function tech_priests_0221_is_space_pair(pair)
  return pair and tech_priests_pair_on_space_platform_0204 and tech_priests_pair_on_space_platform_0204(pair)
end

function tech_priests_0221_spawn_locus_position(pair)
  if pair and pair.spawn_locus_position_0208 then return pair.spawn_locus_position_0208 end
  if pair and pair.spawn_locus_position_0206 then return pair.spawn_locus_position_0206 end
  if pair and pair.spawn_position then return pair.spawn_position end
  if pair and pair.station and pair.station.valid then return pair.station.position end
  return nil
end

TECH_PRIESTS_ORIGINAL_FORCE_PRIEST_TO_PLATFORM_LOCUS_0221 = tech_priests_force_priest_to_platform_locus_0208
function tech_priests_force_priest_to_platform_locus_0208(pair, reason)
  if tech_priests_0221_is_space_pair(pair) and pair.priest and pair.priest.valid and pair.station and pair.station.valid and pair.priest.surface == pair.station.surface then
    local pos = tech_priests_0221_spawn_locus_position(pair)
    if pos and tech_priests_0220_begin_hover_glide then
      -- Do not hard teleport during normal platform operation.  The lore is that
      -- void-duty priests use maneuvering packs; mechanically this avoids the
      -- old tether/snap loop while still giving recall a destination.
      if not (pair.space_platform_pathing_0209 and pair.space_platform_pathing_0209.active and pair.space_platform_pathing_0209.hover_glide_0220) then
        tech_priests_0220_begin_hover_glide(pair, pos, "soft void-duty recall")
      end
      return true
    end
  end
  if TECH_PRIESTS_ORIGINAL_FORCE_PRIEST_TO_PLATFORM_LOCUS_0221 then
    return TECH_PRIESTS_ORIGINAL_FORCE_PRIEST_TO_PLATFORM_LOCUS_0221(pair, reason)
  end
  return false
end

-- Make platform safety checks obstruction-blind for hover-glide priests.  Surface
-- mismatch and station-radius containment still matter; belts, pipes, and entity
-- collision do not.
function tech_priests_platform_path_guard_0209(pair, reason)
  if not (pair and pair.priest and pair.priest.valid and pair.space_platform_pathing_0209 and pair.space_platform_pathing_0209.active) then return false end
  if not (pair.station and pair.station.valid and pair.priest.surface == pair.station.surface) then return false end
  if tech_priests_0220_in_radius then
    if not tech_priests_0220_in_radius(pair, pair.priest.position) then return false end
  end
  local path = pair.space_platform_pathing_0209
  if path.hover_glide_0220 then
    local now = (game and game.tick) or 0
    if (now - (path.started_tick or now)) > (TECH_PRIESTS_PLATFORM_HOVER_TIMEOUT_0220 or (60 * 30)) then return false end
    path.last_seen_tick = now
    return true
  end
  return true
end

-- Runtime placement doctrine: ordinary Tech-Priest stations belong planetside;
-- Void Cogitator Stations belong on space platforms.  Existing saves are not
-- force-destroyed here; this only rejects fresh invalid placement.
function tech_priests_0221_return_invalid_station_item(entity, player_index, reason)
  if not (entity and entity.valid) then return end
  local name = entity.name
  local pos = entity.position
  local surface = entity.surface
  local force = entity.force
  local player = player_index and game and game.get_player(player_index) or nil
  if player and player.valid and player.can_insert and player.can_insert({ name = name, count = 1 }) then
    pcall(function() player.insert({ name = name, count = 1 }) end)
  else
    pcall(function() surface.spill_item_stack({ position = pos, stack = { name = name, count = 1 }, force = force, allow_belts = false }) end)
  end
  pcall(function() entity.destroy({ raise_destroy = false }) end)
  if player and player.valid then
    player.print({ "", "[entity=" .. name .. "] ", { "entity-name." .. name }, " placement rejected: ", reason or "invalid surface doctrine", "." })
  end
end

function tech_priests_0221_station_surface_valid(entity)
  if not (entity and entity.valid) then return true end
  local is_space = false
  if tech_priests_surface_is_space_platform_0204 then
    local ok, result = pcall(function() return tech_priests_surface_is_space_platform_0204(entity.surface) end)
    is_space = ok and result or false
  else
    local ok_platform, platform_obj = pcall(function() return entity.surface and entity.surface.platform end)
    is_space = ok_platform and platform_obj ~= nil
  end
  if entity.name == TECH_PRIESTS_VOID_STATION_0221 then return is_space end
  if TECH_PRIESTS_PLANETSIDE_STATIONS_0221[entity.name] then return not is_space end
  return true
end

function tech_priests_0221_on_station_built(event)
  local entity = event and (event.entity or event.created_entity or event.destination)
  if not (entity and entity.valid) then return end
  if not (TECH_PRIESTS_PLANETSIDE_STATIONS_0221[entity.name] or entity.name == TECH_PRIESTS_VOID_STATION_0221) then return end
  if not tech_priests_0221_station_surface_valid(entity) then
    local reason = entity.name == TECH_PRIESTS_VOID_STATION_0221 and "Void Cogitator Stations require a space platform" or "this Cogitator tier is planetside-only; use a Void Cogitator Station in space"
    tech_priests_0221_return_invalid_station_item(entity, event.player_index, reason)
  end
end

if on_built and defines and defines.events then
  TECH_PRIESTS_ORIGINAL_ON_BUILT_0221 = on_built
  function tech_priests_on_built_wrapper_0221(event)
    TECH_PRIESTS_ORIGINAL_ON_BUILT_0221(event)
    tech_priests_0221_on_station_built(event)
  end
  TechPriestsRuntimeEventRegistry.on_event({
    defines.events.on_built_entity,
    defines.events.on_robot_built_entity,
    defines.events.script_raised_built,
    defines.events.script_raised_revive
  }, tech_priests_on_built_wrapper_0221)
end


-- 0.1.247 Station registration and nearby-machine diagnostics.
TECH_PRIESTS_DIAG_PREFIX_0247 = "[Tech Priests 0.1.247] "

function tech_priests_0247_diag(message)
  if not game then return end
  local line = TECH_PRIESTS_DIAG_PREFIX_0247 .. tostring(message)
  log(line)
  if settings and settings.global and settings.global["tech-priests-enable-full-priority-diagnostics"] and settings.global["tech-priests-enable-full-priority-diagnostics"].value then
    for _, player in pairs(game.connected_players or {}) do
      if player and player.valid then player.print(line) end
    end
  end
end

function tech_priests_0247_count_nearby_machine_categories(station)
  local counts = { entities = 0, damaged = 0, assemblers = 0, furnaces = 0, miners = 0, turrets = 0, belts = 0 }
  if not (station and station.valid and station.surface) then return counts end
  local radius = 0
  if get_station_operating_radius then radius = get_station_operating_radius(station) or 0 end
  if radius <= 0 then radius = 30 end
  local area = { { station.position.x - radius, station.position.y - radius }, { station.position.x + radius, station.position.y + radius } }
  local ok, ents = pcall(function() return station.surface.find_entities_filtered({ area = area, force = station.force }) end)
  if not ok or type(ents) ~= "table" then return counts end
  for _, e in pairs(ents) do
    if e and e.valid and e.unit_number ~= station.unit_number then
      counts.entities = counts.entities + 1
      local max_health = nil
      local ok_max_health, read_max_health = pcall(function() return e.max_health end)
      if ok_max_health then max_health = read_max_health end
      if e.health and max_health and max_health > 0 and e.health < max_health then counts.damaged = counts.damaged + 1 end
      if e.type == "assembling-machine" then counts.assemblers = counts.assemblers + 1 end
      if e.type == "furnace" then counts.furnaces = counts.furnaces + 1 end
      if e.type == "mining-drill" then counts.miners = counts.miners + 1 end
      if e.type == "ammo-turret" or e.type == "electric-turret" or e.type == "fluid-turret" then counts.turrets = counts.turrets + 1 end
      if e.type == "transport-belt" or e.type == "splitter" or e.type == "underground-belt" then counts.belts = counts.belts + 1 end
    end
  end
  return counts
end

function tech_priests_0247_report_station_registration(station, context)
  if not (station and station.valid) then
    tech_priests_0247_diag((context or "station") .. ": invalid station reference")
    return
  end
  ensure_storage()
  local cfg = get_station_config and get_station_config(station) or nil
  local priest_name = cfg and get_priest_name_for_force and get_priest_name_for_force(cfg, station.force) or "nil"
  local pair = storage.tech_priests and storage.tech_priests.pairs_by_station and storage.tech_priests.pairs_by_station[station.unit_number] or nil
  local c = tech_priests_0247_count_nearby_machine_categories(station)
  tech_priests_0247_diag((context or "station") ..
    " name=" .. tostring(station.name) ..
    " unit=" .. tostring(station.unit_number) ..
    " tier=" .. tostring(cfg and cfg.tier or "nil") ..
    " priest_proto=" .. tostring(priest_name) ..
    " pair=" .. tostring(pair ~= nil) ..
    " nearby=" .. tostring(c.entities) ..
    " damaged=" .. tostring(c.damaged) ..
    " assemblers=" .. tostring(c.assemblers) ..
    " furnaces=" .. tostring(c.furnaces) ..
    " miners=" .. tostring(c.miners) ..
    " turrets=" .. tostring(c.turrets) ..
    " belts=" .. tostring(c.belts))
end

tech_priests_original_create_pair_0247 = create_pair
function create_pair(station)
  tech_priests_0247_report_station_registration(station, "create_pair before")
  local ok, result = pcall(function() return tech_priests_original_create_pair_0247(station) end)
  if not ok then
    tech_priests_0247_diag("create_pair crash trapped: " .. tostring(result))
    error(result)
  end
  tech_priests_0247_report_station_registration(station, "create_pair after")
  return result
end

TechPriestsDebugCommandRegistry.add("tp-scan-nearby", "Tech Priests: report nearby machine registration around selected station.", function(event)
  local player = game.get_player(event.player_index)
  if not (player and player.valid) then return end
  local selected = player.selected
  if not (selected and selected.valid and is_station(selected)) then
    player.print("Select a Cogitator Station first, then run /tp-scan-nearby.")
    return
  end
  tech_priests_0247_report_station_registration(selected, "manual /tp-scan-nearby")
end)


-- 0.1.222 Void Doctrine Consolidation Pass.
-- 0.1.223 fixes entity-vs-pair doctrine resolution so LuaEntity userdata is never treated as a pair table.
-- Void Tech-Priests are now treated as a distinct spaceborne doctrine class,
-- not as Senior priests who happen to stand on a platform.  This final shim is
-- deliberately late in the file so it overrides the older 0.1.206-0.1.221
-- platform tether/pathing experiments that could still snap priests back to
-- the station or run them through walker assumptions.
TECH_PRIESTS_VOID_PRIEST_NAMES_0222 = {
  ["void-tech-priest"] = true,
  ["void-tech-priest-belt-immune"] = true
}
TECH_PRIESTS_VOID_STATION_NAME_0222 = "void-cogitator-station"

function tech_priests_resolve_pair_for_void_doctrine_0223(subject)
  if not subject then return nil end

  -- Normal case: this is one of our stored pair tables.  Keep this check
  -- deliberately table-only because Factorio LuaEntity userdata does not allow
  -- arbitrary field access such as .tier.
  if type(subject) == "table" then
    if subject.station or subject.priest or subject.tier or subject.doctrine or subject.movement_mode then
      return subject
    end
  end

  -- Compatibility case: several older helpers call return_to_station() with a
  -- priest entity rather than the pair record.  Resolve that entity back to its
  -- pair before attempting to read or write doctrine fields.
  local ok_valid, is_valid = pcall(function() return subject.valid end)
  if ok_valid and is_valid and find_pair_for_entity then
    local ok_pair, found_pair = pcall(find_pair_for_entity, subject)
    if ok_pair and found_pair then return found_pair end
  end

  return nil
end

function tech_priests_entity_is_void_doctrine_0223(subject)
  if not subject then return false end
  local ok_valid, is_valid = pcall(function() return subject.valid end)
  if not (ok_valid and is_valid) then return false end
  local ok_name, name = pcall(function() return subject.name end)
  if ok_name and name and (TECH_PRIESTS_VOID_PRIEST_NAMES_0222[name] or name == TECH_PRIESTS_VOID_STATION_NAME_0222) then
    return true
  end
  return false
end

function tech_priests_pair_is_void_doctrine_0222(subject)
  local pair = tech_priests_resolve_pair_for_void_doctrine_0223(subject)
  if not pair then return tech_priests_entity_is_void_doctrine_0223(subject) end
  if pair.tier == "void" or pair.doctrine == "void" or pair.movement_mode == "hover" then return true end
  if pair.station and pair.station.valid and pair.station.name == TECH_PRIESTS_VOID_STATION_NAME_0222 then return true end
  if pair.priest and pair.priest.valid and TECH_PRIESTS_VOID_PRIEST_NAMES_0222[pair.priest.name] then return true end
  return false
end

function tech_priests_mark_void_doctrine_0222(subject)
  local pair = tech_priests_resolve_pair_for_void_doctrine_0223(subject)
  if not pair then return nil end
  if tech_priests_pair_is_void_doctrine_0222(pair) then
    pair.tier = "void"
    pair.doctrine = "void"
    pair.movement_mode = "hover"
    pair.allowed_surfaces = "space-platform"
    pair.task_summary = pair.task_summary or "Void doctrine · standing by"
    pair.space_platform_tether_0206 = pair.space_platform_tether_0206 or {}
    pair.space_platform_tether_0206.allow_pathing = true
    pair.space_platform_tether_0206.disabled_for_void_doctrine_0222 = true
  end
  return pair
end

function tech_priests_mark_all_void_pairs_0222()
  if not (storage and storage.tech_priests and storage.tech_priests.pairs) then return end
  for _, pair in pairs(storage.tech_priests.pairs) do
    tech_priests_mark_void_doctrine_0222(pair)
  end
end

-- Hard safety conversion: any legacy platform tether request against a Void
-- Priest becomes a soft hover recall. It must not teleport, stop, or snap the
-- entity unless the entity is already missing and must be respawned elsewhere.
TECH_PRIESTS_ORIGINAL_TETHER_PLATFORM_PRIEST_0222 = tech_priests_tether_platform_priest_0206
function tech_priests_tether_platform_priest_0206(pair, reason)
  local resolved_pair_0223 = tech_priests_mark_void_doctrine_0222(pair) or pair
  pair = resolved_pair_0223
  if tech_priests_pair_is_void_doctrine_0222(pair) then
    if pair and pair.priest and pair.priest.valid and pair.station and pair.station.valid and pair.priest.surface == pair.station.surface then
      local locus = nil
      if tech_priests_0221_spawn_locus_position then locus = tech_priests_0221_spawn_locus_position(pair) end
      locus = locus or pair.spawn_position or pair.station.position
      if tech_priests_0220_begin_hover_glide and locus then
        return tech_priests_0220_begin_hover_glide(pair, locus, tostring(reason or "void soft recall"))
      end
      return true
    end
  end
  if TECH_PRIESTS_ORIGINAL_TETHER_PLATFORM_PRIEST_0222 then return TECH_PRIESTS_ORIGINAL_TETHER_PLATFORM_PRIEST_0222(pair, reason) end
  return false
end

-- Same conversion for the exact-locus enforcer: Void Priests recall by hover
-- target, not by forced teleport. Ground/legacy platform pairs keep the old path.
TECH_PRIESTS_ORIGINAL_FORCE_PLATFORM_LOCUS_0222 = tech_priests_force_priest_to_platform_locus_0208
function tech_priests_force_priest_to_platform_locus_0208(pair, reason)
  local resolved_pair_0223 = tech_priests_mark_void_doctrine_0222(pair) or pair
  pair = resolved_pair_0223
  if tech_priests_pair_is_void_doctrine_0222(pair) and pair and pair.priest and pair.priest.valid and pair.station and pair.station.valid and pair.priest.surface == pair.station.surface then
    local locus = nil
    if tech_priests_0221_spawn_locus_position then locus = tech_priests_0221_spawn_locus_position(pair) end
    locus = locus or pair.spawn_position or pair.station.position
    if tech_priests_0220_begin_hover_glide and locus then
      return tech_priests_0220_begin_hover_glide(pair, locus, tostring(reason or "void soft recall"))
    end
    return true
  end
  if TECH_PRIESTS_ORIGINAL_FORCE_PLATFORM_LOCUS_0222 then return TECH_PRIESTS_ORIGINAL_FORCE_PLATFORM_LOCUS_0222(pair, reason) end
  return false
end

-- Void movement accepts a target inside station jurisdiction and lets the hover
-- mover slide there; it does not ask the unit pathfinder, tile collision, belts,
-- inserters, pipes, or any other floor-bound doctrine for permission.
TECH_PRIESTS_ORIGINAL_MOVE_PRIEST_TO_0222 = move_priest_to
function move_priest_to(priest, target)
  local pair = priest and find_pair_for_entity and find_pair_for_entity(priest) or nil
  tech_priests_mark_void_doctrine_0222(pair)
  if pair and tech_priests_pair_is_void_doctrine_0222(pair) then
    local pos = nil
    if target then
      if target.valid and target.position then pos = target.position elseif target.x and target.y then pos = target end
    end
    if pos and tech_priests_0220_in_radius and not tech_priests_0220_in_radius(pair, pos) then
      local locus = tech_priests_0221_spawn_locus_position and tech_priests_0221_spawn_locus_position(pair) or pair.spawn_position
      pos = locus or pos
    end
    if pos and tech_priests_0220_begin_hover_glide then
      return tech_priests_0220_begin_hover_glide(pair, pos, "void hover movement")
    end
    return false
  end
  if TECH_PRIESTS_ORIGINAL_MOVE_PRIEST_TO_0222 then return TECH_PRIESTS_ORIGINAL_MOVE_PRIEST_TO_0222(priest, target) end
  return false
end

TECH_PRIESTS_ORIGINAL_RETURN_TO_STATION_0222 = return_to_station
function return_to_station(pair)
  local original_subject_0223 = pair
  local resolved_pair_0223 = tech_priests_mark_void_doctrine_0222(pair)
  pair = resolved_pair_0223 or pair
  if resolved_pair_0223 and tech_priests_pair_is_void_doctrine_0222(pair) then
    local locus = tech_priests_0221_spawn_locus_position and tech_priests_0221_spawn_locus_position(pair) or (pair and pair.spawn_position)
    if locus and tech_priests_0220_begin_hover_glide then return tech_priests_0220_begin_hover_glide(pair, locus, "void return to locus") end
    return true
  end
  if TECH_PRIESTS_ORIGINAL_RETURN_TO_STATION_0222 then return TECH_PRIESTS_ORIGINAL_RETURN_TO_STATION_0222(original_subject_0223) end
  return false
end

-- Keep debug defaults hard-off unless the user explicitly enables them by command.
function tech_priests_release_debug_defaults_0222()
  storage.tech_priests = storage.tech_priests or {}
  if storage.tech_priests.lifecycle_log_enabled == nil then storage.tech_priests.lifecycle_log_enabled = false end
  if storage.tech_priests.lifecycle_file_enabled == nil then storage.tech_priests.lifecycle_file_enabled = false end
  if storage.tech_priests.debug_overlays_enabled == nil then storage.tech_priests.debug_overlays_enabled = false end
  if storage.tech_priests.debug_request_icons_enabled == nil then storage.tech_priests.debug_request_icons_enabled = false end
end

-- The existing init/configuration handlers call init_storage and service loops; this
-- pass deliberately avoids replacing them.  Void records are marked lazily whenever
-- movement/tether code touches a pair.


-- 0.1.226 Planetary Magos conversation doctrine.
-- The Planetary Magos is the fourth planetary command rank.  It is above
-- Senior Tech-Priest authority but distinct from the Void Tech-Priest, which is
-- a spaceborne specialization rather than the ordinary planetary command tier.
TECH_PRIESTS_TIER_RANKS_0129 = TECH_PRIESTS_TIER_RANKS_0129 or {}
TECH_PRIESTS_TIER_RANKS_0129["planetary-magos"] = 4
TECH_PRIESTS_TIER_RANKS_0129["planetary_magos"] = 4
TECH_PRIESTS_TIER_RANKS_0129["magos"] = 4
TECH_PRIESTS_TIER_RANKS_0129["void"] = TECH_PRIESTS_TIER_RANKS_0129["void"] or 4

function tech_priests_normalize_conversation_rank_0226(rank)
  rank = tostring(rank or "junior")
  if rank == "planetary-magos" or rank == "planetary_magos" or rank == "magos" or rank == "planetary-magos-cogitator-station" or rank == "planetary-magos-tech-priest" then
    return "planetary-magos"
  end
  if rank == "senior" or rank == "senior-cogitator-station" or rank == "senior-tech-priest" then return "senior" end
  if rank == "intermediate" or rank == "intermediate-cogitator-station" or rank == "intermediate-tech-priest" then return "intermediate" end
  if rank == "void" or rank == "void-cogitator-station" or rank == "void-tech-priest" then return "void" end
  return "junior"
end

if tech_priests_get_pair_tier_name_0167 then
  TECH_PRIESTS_ORIGINAL_GET_PAIR_TIER_NAME_0226 = tech_priests_get_pair_tier_name_0167
  function tech_priests_get_pair_tier_name_0167(pair)
    local raw = TECH_PRIESTS_ORIGINAL_GET_PAIR_TIER_NAME_0226(pair)
    return tech_priests_normalize_conversation_rank_0226(raw)
  end
end

function get_pair_rank(pair)
  if tech_priests_get_pair_tier_name_0167 then
    return tech_priests_get_pair_tier_name_0167(pair)
  end
  return tech_priests_normalize_conversation_rank_0226(pair and pair.tier or "junior")
end

function tech_priests_rank_display_title_0226(rank)
  rank = tech_priests_normalize_conversation_rank_0226(rank)
  if rank == "planetary-magos" then return "Planetary Magos" end
  if rank == "void" then return "Void Tech-Priest" end
  if rank == "senior" then return "Senior Tech-Priest" end
  if rank == "intermediate" then return "Intermediate Tech-Priest" end
  return "Junior Tech-Priest"
end

function tech_priests_choose_magos_line_0226(role, topic, tech_icon, ctx)
  local planet = (ctx and ctx.planet) or "this world"
  local entity_icon = (ctx and ctx.entity_icon and ctx.entity_icon ~= "" and ctx.entity_icon) or "the indicated machinery"
  local lines = {
    magos_to_magos = {
      tech_icon .. " Planetary command doctrine requires restraint: authorize the chain, reserve the materials, and let subordinates discover heroism at a safe distance.",
      tech_icon .. " Our concern is no longer a single machine, but whether the surrounding doctrine can survive contact with production.",
      tech_icon .. " Machine clusters, shrine inventories, and subordinate assignments must be judged together. Sanctity without logistics is theatre."
    },
    magos_to_senior = {
      tech_icon .. " Senior clergy will audit the local machine cluster. I will determine whether the failure is material, doctrinal, or managerial with better robes.",
      tech_icon .. " Prepare subordinate routing and sanctification priorities. The obvious machine is rarely the only machine sinning.",
      tech_icon .. " Your station will handle the immediate rites. I will decide whether the surrounding block deserves incense, grenades, or paperwork with teeth."
    },
    magos_to_intermediate = {
      tech_icon .. " Build the dependency map before touching the machinery. Inputs, outputs, sanctity, then movement; enthusiasm remains unsanctioned.",
      tech_icon .. " Question the chain, not the command. Where the ingredient starves, the factory lies about its intent.",
      tech_icon .. " Inspect the machines as a cluster. A single idle assembler may be the shadow of a failed belt, pipe, or subordinate shrine."
    },
    magos_to_junior = {
      tech_icon .. " You will obey the assigned writ, report shortages, and avoid interpreting strategic doctrine as permission to wander.",
      tech_icon .. " Remain within your station radius. Bring what is requested. Do not philosophize near explosives.",
      tech_icon .. " If issued a consecration grenade, you will not throw it unless a Magos-grade directive says the machine cluster deserves mercy."
    },
    senior_to_magos = {
      tech_icon .. " Planetary Magos, the local doctrine is stable enough to criticize and unstable enough to justify your attention.",
      tech_icon .. " I can hold the shrine line, Magos, but the surrounding production block requires command-level prioritization.",
      tech_icon .. " The subordinate stations can comply, provided we stop pretending their inventories are emotionally resilient."
    },
    intermediate_to_magos = {
      tech_icon .. " Planetary Magos, I request permission to model the input chain before the machines make their own argument.",
      tech_icon .. " The doctrine is comprehensible in pieces, Magos. It is the whole factory that appears to be negotiating with entropy.",
      tech_icon .. " Should I prioritize material shortage, sanctification loss, or whatever that belt is doing with suspicious confidence?"
    },
    junior_to_magos = {
      tech_icon .. " Planetary Magos acknowledged. Higher thought deferred upward.",
      tech_icon .. " Command authority recognized. Obedience consolidated.",
      tech_icon .. " I will not ask why the machine cluster looks guilty. I will report it."
    },
    void_to_magos = {
      tech_icon .. " Planetary Magos, void-side doctrine remains mobile, pale, and aggressively not walking.",
      tech_icon .. " Magos, the platform machinery can be inspected from any angle except the one where physics asks questions.",
      tech_icon .. " Stationborne rites continue. The floor is present only as a courtesy."
    },
    magos_to_void = {
      tech_icon .. " Void doctrine is authorized to maneuver without pretending the floor participates. Inspect the platform cluster and report drift, heat, and heresy.",
      tech_icon .. " Your movement profile is exceptional, not ornamental. Use it to reach the machines ordinary clergy cannot approach without embarrassing pathfinding.",
      tech_icon .. " Maintain platform consecration coverage. If the void resists walking, then we shall simply stop walking."
    },
    magos_player_equal = {
      tech_icon .. " Peer review requested, {ADDRESS}. On " .. planet .. ", your intent and my doctrine should agree before the machinery becomes creative.",
      tech_icon .. " {ADDRESS}, I will treat that as a command-level hypothesis, not an order immune to evidence.",
      tech_icon .. " {ADDRESS}, as one senior authority to another: the factory will obey better if we stop giving it contradictions to weaponize."
    },
    magos_player_equal_condemnation = {
      "{ADDRESS}, " .. entity_icon .. " is damaged enough to deserve honesty. Shall we call this field testing, or shall we repair the theology first?",
      "{ADDRESS}, I recognize your authority. I also recognize smoke, impact marks, and the statistical scent of preventable doctrine.",
      "{ADDRESS}, peer counsel: this machine cluster is not failing mysteriously. It is testifying."
    },
    magos_player_equal_research = {
      tech_icon .. " {ADDRESS}, active research proceeds. I recommend we define the implementation doctrine before revelation becomes inventory debt.",
      tech_icon .. " {ADDRESS}, this research deserves a command-level deployment plan, not merely applause and a new belt line.",
      tech_icon .. " {ADDRESS}, I can coordinate the clergy if you confirm whether this doctrine is priority, curiosity, or emergency disguised as progress."
    },
    magos_player_equal_entity = {
      "{ADDRESS}, your attention on " .. entity_icon .. " is noted. Shall I treat this as inspection, intervention, or a quiet accusation?",
      "{ADDRESS}, that object is now under Magos-grade suspicion. I await your counterargument.",
      "{ADDRESS}, I can assign subordinates to this cluster if your interest is operational rather than decorative."
    }
  }
  local list = lines[role] or lines.magos_to_magos
  local seed = (game and game.tick or 0) + #(topic or role or "")
  return list[(seed % #list) + 1]
end

TECH_PRIESTS_ORIGINAL_PLAYER_LISTENER_RESPONSE_0226 = tech_priests_player_listener_response_0170
function tech_priests_player_listener_response_0170(listener_rank, address, ctx)
  listener_rank = tech_priests_normalize_conversation_rank_0226(listener_rank)
  if listener_rank == "planetary-magos" then
    local tech_icon = (ctx and ctx.tech_icon) or ""
    local line = tech_priests_choose_magos_line_0226("magos_player_equal", "player-response", tech_icon, ctx)
    return string.gsub(line, "{ADDRESS}", address or "Archmagos")
  end
  return TECH_PRIESTS_ORIGINAL_PLAYER_LISTENER_RESPONSE_0226(listener_rank, address, ctx)
end

TECH_PRIESTS_ORIGINAL_CHOOSE_PLAYER_ADDRESS_LINES_0226 = tech_priests_choose_player_address_lines_0170
function tech_priests_choose_player_address_lines_0170(speaker_pair, listener_pair)
  local player, context = tech_priests_choose_player_for_pair_0170(speaker_pair)
  local speaker_rank = get_pair_rank(speaker_pair)
  if player and player.valid and speaker_rank == "planetary-magos" then
    local address = tech_priests_format_player_address_0170(player)
    local ctx = tech_priests_build_player_topic_context_0170(speaker_pair, player, context)
    local role = "magos_player_equal"
    if ctx.tone == "condemnation" then role = "magos_player_equal_condemnation"
    elseif ctx.current_research then role = "magos_player_equal_research"
    elseif ctx.entity_name then role = "magos_player_equal_entity" end
    local line = tech_priests_choose_magos_line_0226(role, "player-address", ctx.tech_icon or "", ctx)
    line = string.gsub(line, "{ADDRESS}", address)
    local listener_rank = get_pair_rank(listener_pair)
    return {
      topic = "__player_address_context__",
      tech_name = ctx.tech_for_icon,
      speaker_line = line,
      response_line = tech_priests_player_listener_response_0170(listener_rank, address, ctx)
    }
  end
  return TECH_PRIESTS_ORIGINAL_CHOOSE_PLAYER_ADDRESS_LINES_0226(speaker_pair, listener_pair)
end

TECH_PRIESTS_ORIGINAL_BUILD_DIRECT_PLAYER_LINE_0226 = tech_priests_build_direct_player_line_0181
function tech_priests_build_direct_player_line_0181(pair, player, context)
  local rank = get_pair_rank(pair)
  if rank == "planetary-magos" then
    local address = tech_priests_format_player_address_0170(player)
    local ctx = tech_priests_build_player_topic_context_0170(pair, player, context)
    local role = "magos_player_equal"
    if ctx.tone == "condemnation" then role = "magos_player_equal_condemnation"
    elseif ctx.current_research then role = "magos_player_equal_research"
    elseif ctx.entity_name then role = "magos_player_equal_entity" end
    local line = tech_priests_choose_magos_line_0226(role, "direct-player", ctx.tech_icon or "", ctx)
    return string.gsub(line, "{ADDRESS}", address)
  end
  return TECH_PRIESTS_ORIGINAL_BUILD_DIRECT_PLAYER_LINE_0226(pair, player, context)
end

TECH_PRIESTS_ORIGINAL_CHOOSE_CONVERSATION_LINES_0226 = tech_priests_choose_conversation_lines_0167
function tech_priests_choose_conversation_lines_0167(speaker_pair, listener_pair)
  local speaker_rank = get_pair_rank(speaker_pair)
  local listener_rank = get_pair_rank(listener_pair)
  if speaker_rank == "planetary-magos" or listener_rank == "planetary-magos" then
    local force = speaker_pair and speaker_pair.station and speaker_pair.station.valid and speaker_pair.station.force or speaker_pair and speaker_pair.priest and speaker_pair.priest.valid and speaker_pair.priest.force or nil
    local topic, tech_name = tech_priests_get_conversation_topic_for_force_0167(force)
    local tech_icon = tech_name and ("[technology=" .. tostring(tech_name) .. "]") or ""
    local role = "magos_to_" .. listener_rank
    if speaker_rank ~= "planetary-magos" then
      role = speaker_rank .. "_to_magos"
    elseif listener_rank == "planetary-magos" then
      role = "magos_to_magos"
    end
    local response_role = listener_rank .. "_to_magos"
    if listener_rank == "planetary-magos" and speaker_rank == "planetary-magos" then response_role = "magos_to_magos" end
    local speaker_line = tech_priests_choose_magos_line_0226(role, topic, tech_icon .. " ", nil)
    local response_line
    if listener_rank == "planetary-magos" then
      response_line = tech_priests_choose_magos_line_0226(response_role, topic, tech_icon .. " ", nil)
    else
      local response_lines = TECH_PRIESTS_CONVERSATION_RESPONSES_0167 and (TECH_PRIESTS_CONVERSATION_RESPONSES_0167[listener_rank] or TECH_PRIESTS_CONVERSATION_RESPONSES_0167.junior) or { "Acknowledged." }
      response_line = tech_priests_choose_deterministic_line_0167(response_lines, ((speaker_pair and speaker_pair.station_unit) or 0) + ((listener_pair and listener_pair.station_unit) or 0) + 9)
    end
    return {
      tech_name = tech_name,
      topic = topic,
      speaker_rank = speaker_rank,
      listener_rank = listener_rank,
      speaker_line = tech_priests_format_conversation_line_0167(speaker_line, tech_name),
      response_line = tech_priests_format_conversation_line_0167(response_line, tech_name)
    }
  end
  return TECH_PRIESTS_ORIGINAL_CHOOSE_CONVERSATION_LINES_0226(speaker_pair, listener_pair)
end

-- 0.1.227 Planetary Magos reserved recognition-name registry.
-- Special names live in scripts/planetary-magos-special-names.lua so they can be
-- edited without digging through the runtime control script.
TECH_PRIESTS_SPECIAL_MAGOS_NAMES_0227 = TECH_PRIESTS_SPECIAL_MAGOS_NAMES_0227 or require("scripts.planetary-magos-special-names")

function tech_priests_0227_normalize_name(value)
  local text = string.lower(tostring(value or ""))
  text = string.gsub(text, "[^%w]", "")
  return text
end

function tech_priests_0227_ensure_special_name_storage()
  ensure_storage()
  storage.tech_priests.special_magos_consumed_0227 = storage.tech_priests.special_magos_consumed_0227 or {}
  storage.tech_priests.special_magos_announced_0227 = storage.tech_priests.special_magos_announced_0227 or {}
  storage.tech_priests.special_magos_recent_matches_0227 = storage.tech_priests.special_magos_recent_matches_0227 or {}
end

function tech_priests_0227_special_entries()
  if TECH_PRIESTS_SPECIAL_MAGOS_NAMES_0227 and TECH_PRIESTS_SPECIAL_MAGOS_NAMES_0227.names then
    return TECH_PRIESTS_SPECIAL_MAGOS_NAMES_0227.names
  end
  return {}
end

function tech_priests_0227_entry_matches_player(entry, player_name)
  if not (entry and player_name and player_name ~= "") then return false end
  local player_key = tech_priests_0227_normalize_name(player_name)
  if player_key == "" then return false end
  local candidates = { entry.key, entry.display }
  if entry.aliases then for _, alias in pairs(entry.aliases) do table.insert(candidates, alias) end end
  for _, candidate in pairs(candidates) do
    local key = tech_priests_0227_normalize_name(candidate)
    if key ~= "" then
      if key == player_key then return true end
      -- Allow partial recognition for meaningful handles, but avoid tiny accidental
      -- matches like "qon" inside unrelated names.
      if string.len(key) >= 4 and string.len(player_key) >= 4 then
        if string.find(key, player_key, 1, true) or string.find(player_key, key, 1, true) then return true end
      end
    end
  end
  return false
end

function tech_priests_0227_find_special_entry_for_player(player)
  if not (player and player.valid) then return nil end
  for _, entry in pairs(tech_priests_0227_special_entries()) do
    if tech_priests_0227_entry_matches_player(entry, player.name) then return entry end
  end
  return nil
end

function tech_priests_0227_pair_is_planetary_magos(pair)
  if not pair then return false end
  local tier = tostring(pair.tier or pair.rank or pair.doctrine or "")
  if tier == "planetary-magos" or tier == "planetary_magos" or tier == "magos" then return true end
  local station_name = nil
  if pair.station and pair.station.valid then station_name = pair.station.name end
  local priest_name = nil
  if pair.priest and pair.priest.valid then priest_name = pair.priest.name end
  local joined = string.lower(tostring(station_name or "") .. " " .. tostring(priest_name or "") .. " " .. tostring(pair.station_display_name or "") .. " " .. tostring(pair.priest_display_name or ""))
  return string.find(joined, "planetary%-magos", 1, false) or string.find(joined, "magos", 1, true)
end

function tech_priests_0227_name_is_consumed_special(name)
  tech_priests_0227_ensure_special_name_storage()
  local key = tech_priests_0227_normalize_name(name)
  if key == "" then return false end
  return storage.tech_priests.special_magos_consumed_0227[key] == true
end

function tech_priests_0227_get_special_name_entry_by_display(name)
  local key = tech_priests_0227_normalize_name(name)
  if key == "" then return nil end
  for _, entry in pairs(tech_priests_0227_special_entries()) do
    if tech_priests_0227_normalize_name(entry.display or entry.key) == key or tech_priests_0227_normalize_name(entry.key) == key then return entry end
  end
  return nil
end

function tech_priests_0227_get_available_planetary_magos_name()
  tech_priests_0227_ensure_special_name_storage()
  for _, entry in pairs(tech_priests_0227_special_entries()) do
    local display = entry.display or entry.key
    local key = tech_priests_0227_normalize_name(display)
    if key ~= "" and not storage.tech_priests.special_magos_consumed_0227[key] and not storage.tech_priests.used_cell_names[display] then
      storage.tech_priests.used_cell_names[display] = true
      return display
    end
  end
  return generate_cell_name()
end

function tech_priests_0227_rename_pair_away_from_reserved_name(pair, reserved_display)
  if not (pair and tech_priests_0227_pair_is_planetary_magos(pair)) then return false end
  local current = pair.cell_name or pair.priest_display_name or pair.station_display_name or ""
  local current_key = tech_priests_0227_normalize_name(current)
  local reserved_key = tech_priests_0227_normalize_name(reserved_display)
  if current_key == "" or reserved_key == "" then return false end
  if current_key ~= reserved_key and not string.find(current_key, reserved_key, 1, true) and not string.find(reserved_key, current_key, 1, true) then return false end

  local old = pair.cell_name or reserved_display
  pair.cell_name = nil
  pair.station_display_name = nil
  pair.priest_display_name = nil
  pair.player_facing_priest_name_0218 = nil
  pair.player_facing_station_name_0218 = nil
  pair.cell_name = tech_priests_0227_get_available_planetary_magos_name()
  if apply_pair_display_names then pcall(function() apply_pair_display_names(pair) end) end
  if pair.force and game and game.forces and game.forces[pair.force] then
    game.forces[pair.force].print("[Tech-Priests] Reserved Magos name '" .. tostring(old) .. "' yielded to a living player; renamed to " .. tostring(pair.cell_name) .. ".")
  end
  return true
end

function tech_priests_0227_release_special_name_for_player(player)
  if not (player and player.valid) then return end
  local entry = tech_priests_0227_find_special_entry_for_player(player)
  if not entry then return end
  tech_priests_0227_ensure_special_name_storage()
  local display = entry.display or entry.key or player.name
  local key = tech_priests_0227_normalize_name(display)
  if key == "" then return end
  storage.tech_priests.special_magos_consumed_0227[key] = true
  storage.tech_priests.used_cell_names[display] = true
  storage.tech_priests.special_magos_recent_matches_0227[player.name] = display

  if storage.tech_priests.pairs_by_station then
    for _, pair in pairs(storage.tech_priests.pairs_by_station) do
      tech_priests_0227_rename_pair_away_from_reserved_name(pair, display)
    end
  end

  if not storage.tech_priests.special_magos_announced_0227[key] then
    storage.tech_priests.special_magos_announced_0227[key] = true
    local line = entry.line or ("High Fabricator " .. tostring(display) .. " detected. Reserved Magos nomenclature yielded to the living authority.")
    if player.force and player.force.valid then player.force.print("[Tech-Priests] " .. line) else game.print("[Tech-Priests] " .. line) end
  end
end

TECH_PRIESTS_ORIGINAL_APPLY_PAIR_DISPLAY_NAMES_0227 = apply_pair_display_names
function apply_pair_display_names(pair)
  if pair and tech_priests_0227_pair_is_planetary_magos(pair) then
    tech_priests_0227_ensure_special_name_storage()
    if not pair.cell_name or tech_priests_0227_name_is_consumed_special(pair.cell_name) then
      pair.cell_name = tech_priests_0227_get_available_planetary_magos_name()
      pair.station_display_name = nil
      pair.priest_display_name = nil
    end
  end
  if TECH_PRIESTS_ORIGINAL_APPLY_PAIR_DISPLAY_NAMES_0227 then TECH_PRIESTS_ORIGINAL_APPLY_PAIR_DISPLAY_NAMES_0227(pair) end
end

function tech_priests_0227_scan_players_for_special_magos_names()
  if not (game and game.players) then return end
  for _, player in pairs(game.players) do
    if player and player.valid and player.connected then tech_priests_0227_release_special_name_for_player(player) end
  end
end


-- 0.1.228/0.1.229 Annoyatron subroutine for selected named players.
-- Runtime logic remains here; editable target/item/line data now lives in
-- scripts/annoyatron.lua so the main behavior file is smaller and safer to patch.
TECH_PRIESTS_ANNOYATRON_CONFIG_0229 = TECH_PRIESTS_ANNOYATRON_CONFIG_0229 or require("scripts.annoyatron")
TECH_PRIESTS_ANNOYATRON_TARGETS_0228 = TECH_PRIESTS_ANNOYATRON_CONFIG_0229.targets or {}
TECH_PRIESTS_ANNOYATRON_ITEMS_0228 = TECH_PRIESTS_ANNOYATRON_CONFIG_0229.items or {}
TECH_PRIESTS_ANNOYATRON_LINES_0228 = TECH_PRIESTS_ANNOYATRON_CONFIG_0229.lines or {}

function tech_priests_0228_ensure_annoyatron_storage()
  ensure_storage()
  storage.tech_priests.annoyatron_0228 = storage.tech_priests.annoyatron_0228 or {}
end

function tech_priests_0228_player_annoyatron_key(player)
  if not (player and player.valid) then return nil end
  local player_key = tech_priests_0227_normalize_name and tech_priests_0227_normalize_name(player.name) or string.lower(string.gsub(tostring(player.name or ""), "[^%w]", ""))
  if player_key == "" then return nil end
  if TECH_PRIESTS_ANNOYATRON_TARGETS_0228[player_key] then return player_key end
  for key, enabled in pairs(TECH_PRIESTS_ANNOYATRON_TARGETS_0228) do
    if enabled and string.len(key) >= 4 and string.len(player_key) >= 4 then
      if string.find(key, player_key, 1, true) or string.find(player_key, key, 1, true) then return key end
    end
  end
  return nil
end

function tech_priests_0228_schedule_next_annoyatron(player_index, from_tick)
  tech_priests_0228_ensure_annoyatron_storage()
  local tick = tonumber(from_tick or (game and game.tick) or 0) or 0
  local minimum = 60 * 60 * 60       -- one hour at 60 UPS
  local maximum = 90 * 60 * 60       -- one and one half hours at 60 UPS
  local span = maximum - minimum
  local roll = math.random(0, span)
  storage.tech_priests.annoyatron_0228[player_index] = storage.tech_priests.annoyatron_0228[player_index] or {}
  storage.tech_priests.annoyatron_0228[player_index].next_tick = tick + minimum + roll
end

function tech_priests_0228_register_annoyatron_player(player)
  if not (player and player.valid) then return end
  local key = tech_priests_0228_player_annoyatron_key(player)
  if not key then return end
  tech_priests_0228_ensure_annoyatron_storage()
  local record = storage.tech_priests.annoyatron_0228[player.index] or {}
  record.enabled = true
  record.key = key
  record.player_name = player.name
  storage.tech_priests.annoyatron_0228[player.index] = record
  if not record.next_tick then tech_priests_0228_schedule_next_annoyatron(player.index, game.tick) end
end

function tech_priests_0228_annoyatron_item_exists(name)
  if prototypes and prototypes.item and prototypes.item[name] then return true end
  if tech_priests_get_item_prototype_0440 and tech_priests_get_item_prototype_0440(name) then return true end
  return false
end

function tech_priests_0228_pick_annoyatron_item()
  local valid = {}
  for _, name in pairs(TECH_PRIESTS_ANNOYATRON_ITEMS_0228) do
    if tech_priests_0228_annoyatron_item_exists(name) then table.insert(valid, name) end
  end
  if #valid <= 0 then return nil end
  return valid[math.random(1, #valid)]
end

function tech_priests_0228_run_annoyatron_for_player(player, record)
  if not (player and player.valid and player.connected and record and record.enabled) then return end
  local item = tech_priests_0228_pick_annoyatron_item()
  if not item then return end
  -- Probability gate keeps the event slightly irregular while the timer still
  -- defines the broad cadence. This is deterministic inside Factorio's runtime.
  if math.random(1, 100) <= 85 then
    local inserted = player.insert({ name = item, count = 1 }) or 0
    if inserted > 0 then
      local line = TECH_PRIESTS_ANNOYATRON_LINES_0228[record.key] or "Annoyatron subroutine confirms delivery of one needless object."
      player.print("[Tech-Priests] " .. line .. " [item=" .. item .. "]")
    end
  end
end

function tech_priests_0228_scan_annoyatron_players()
  if not (game and game.players) then return end
  for _, player in pairs(game.players) do
    if player and player.valid and player.connected then tech_priests_0228_register_annoyatron_player(player) end
  end
end

function tech_priests_0228_service_annoyatron()
  tech_priests_0228_ensure_annoyatron_storage()
  if not (game and game.players) then return end
  tech_priests_0228_scan_annoyatron_players()
  for player_index, record in pairs(storage.tech_priests.annoyatron_0228) do
    local player = game.get_player(player_index)
    if player and player.valid and player.connected and record and record.enabled then
      if not record.next_tick then tech_priests_0228_schedule_next_annoyatron(player_index, game.tick) end
      if record.next_tick and game.tick >= record.next_tick then
        tech_priests_0228_run_annoyatron_for_player(player, record)
        tech_priests_0228_schedule_next_annoyatron(player_index, game.tick)
      end
    end
  end
end

TechPriestsRuntimeEventRegistry.on_event(defines.events.on_player_joined_game, function(event)
  if not (event and event.player_index) then return end
  local player = game.get_player(event.player_index)
  tech_priests_0227_release_special_name_for_player(player)
  tech_priests_0228_register_annoyatron_player(player)
end)

TechPriestsRuntimeEventRegistry.on_nth_tick(60 * 5, function()
  tech_priests_0228_service_annoyatron()
end)



-- 0.1.246 rebase diagnostic stack and idle-priority quarantine.
-- This block deliberately lives at the end of control.lua so it observes the final
-- post-wrapper tick_pair path produced by the recovered 0.1.245 file.  It does
-- not port a new behavior router; it instruments and guards the existing one.
TECH_PRIESTS_DIAGNOSTIC_VERSION_0246 = "0.1.246"

function tech_priests_0246_bool_setting(name, fallback)
  if settings and settings.global and settings.global[name] ~= nil then
    local ok, value = pcall(function() return settings.global[name].value end)
    if ok and value ~= nil then return value == true end
  end
  return fallback == true
end

function tech_priests_0246_int_setting(name, fallback)
  if settings and settings.global and settings.global[name] ~= nil then
    local ok, value = pcall(function() return tonumber(settings.global[name].value) end)
    if ok and value then return math.floor(value) end
  end
  return fallback
end

function tech_priests_0246_diagnostics_enabled()
  return tech_priests_0246_bool_setting("tech-priests-enable-full-priority-diagnostics", true)
end

function tech_priests_0246_idle_quarantine_enabled()
  return tech_priests_0246_bool_setting("tech-priests-quarantine-idle-until-priorities-clear", true)
end

function tech_priests_0246_diag_line(message)
  local line = "[Tech-Priests " .. TECH_PRIESTS_DIAGNOSTIC_VERSION_0246 .. "] " .. tostring(message or "")
  pcall(function() log(line) end)
end

function tech_priests_0246_player_line(player, message)
  local line = "[Tech-Priests " .. TECH_PRIESTS_DIAGNOSTIC_VERSION_0246 .. "] " .. tostring(message or "")
  if player and player.valid then player.print(line) else game.print(line) end
  pcall(function() log(line) end)
end

function tech_priests_0246_entity_label(entity)
  if not (entity and entity.valid) then return "none" end
  local unit = entity.unit_number and ("#" .. tostring(entity.unit_number)) or "#no-unit"
  local health = ""
  if entity.health and entity.max_health then
    health = " hp=" .. tostring(math.floor(entity.health)) .. "/" .. tostring(math.floor(entity.max_health))
  end
  return tostring(entity.name) .. unit .. health
end

function tech_priests_0246_pair_label(pair)
  if not pair then return "pair=nil" end
  local station = pair.station and pair.station.valid and pair.station.name or "station=nil"
  local station_unit = pair.station_unit or (pair.station and pair.station.valid and pair.station.unit_number) or "?"
  local priest = pair.priest and pair.priest.valid and pair.priest.name or "priest=nil"
  return tostring(station) .. "#" .. tostring(station_unit) .. "/" .. tostring(priest)
end

function tech_priests_0246_priority_probe(pair)
  if not (pair and pair.station and pair.station.valid) then
    return { priority = "invalid", reason = "missing or invalid station" }
  end
  local station = pair.station
  local priest = pair.priest
  local radius = pair.radius or (refresh_pair_radius and refresh_pair_radius(pair)) or get_station_operating_radius(station)
  local result = { priority = "idle", reason = "no higher-priority target found", radius = radius }

  if pair.cram then
    result.priority = "cramming-supplies"
    result.reason = "active emergency/cram task present"
    result.detail = tostring(pair.cram.item or pair.cram.name or pair.cram.mode or "cram")
    return result
  end
  if pair.scavenge then
    result.priority = "scavenging-supplies"
    result.reason = "active scavenge task present"
    result.detail = tostring(pair.scavenge.item or pair.scavenge.name or pair.scavenge.mode or "scavenge")
    return result
  end

  local ok_enemy, enemy = pcall(function() return find_enemy_target and find_enemy_target(station, radius, priest) or nil end)
  if ok_enemy and enemy and enemy.valid then
    result.priority = "attack"
    result.reason = "enemy/threat inside station range"
    result.target = tech_priests_0246_entity_label(enemy)
    return result
  elseif not ok_enemy then
    result.attack_error = tostring(enemy)
  end

  local has_repair = station_has_repair_pack and station_has_repair_pack(station)
  if has_repair then
    local ok_repair, target = pcall(function() return find_damaged_target and find_damaged_target(station, radius, priest) or nil end)
    if ok_repair and target and target.valid then
      result.priority = "repair"
      result.reason = "repair pack available and damaged target can use a full repair"
      result.target = tech_priests_0246_entity_label(target)
      return result
    elseif not ok_repair then
      result.repair_error = tostring(target)
    end
    local ok_wait, wait_target = pcall(function() return find_repair_waiting_target and find_repair_waiting_target(station, radius, priest, false) or nil end)
    if ok_wait and wait_target and wait_target.valid then
      result.priority = "repair-waiting"
      result.reason = "repair pack available but target has not reached usefulness threshold"
      result.target = tech_priests_0246_entity_label(wait_target)
      return result
    elseif not ok_wait then
      result.repair_wait_error = tostring(wait_target)
    end
  else
    local ok_missing, missing_target = pcall(function() return find_repair_waiting_target and find_repair_waiting_target(station, radius, priest, true) or nil end)
    if ok_missing and missing_target and missing_target.valid then
      result.priority = "repair-missing-supplies"
      result.reason = "damaged target exists but station has no repair pack"
      result.target = tech_priests_0246_entity_label(missing_target)
      return result
    elseif not ok_missing then
      result.repair_missing_error = tostring(missing_target)
    end
  end

  local has_oil = station_has_consecration_item and station_has_consecration_item(station)
  if has_oil then
    local ok_sanctify, target = pcall(function() return find_consecration_target_for_station and find_consecration_target_for_station(station, radius, priest) or nil end)
    if ok_sanctify and target and target.valid then
      result.priority = "sanctify"
      result.reason = "sacred oil/litany available and consecration target below maximum"
      result.target = tech_priests_0246_entity_label(target)
      return result
    elseif not ok_sanctify then
      result.sanctify_error = tostring(target)
    end
    local ok_cwait, wait_target = pcall(function() return find_consecration_status_target and find_consecration_status_target(station, radius, priest, true, true) or nil end)
    if ok_cwait and wait_target and wait_target.valid then
      result.priority = "sanctify-waiting"
      result.reason = "consecration supply available but target is waiting for usefulness threshold"
      result.target = tech_priests_0246_entity_label(wait_target)
      return result
    elseif not ok_cwait then
      result.sanctify_wait_error = tostring(wait_target)
    end
  else
    local ok_cmissing, missing_target = pcall(function() return find_consecration_status_target and find_consecration_status_target(station, radius, priest, false, false) or nil end)
    if ok_cmissing and missing_target and missing_target.valid then
      result.priority = "sanctify-missing-supplies"
      result.reason = "consecration target exists but station has no sacred oil/litany"
      result.target = tech_priests_0246_entity_label(missing_target)
      return result
    elseif not ok_cmissing then
      result.sanctify_missing_error = tostring(missing_target)
    end
  end

  if pair.idle_scan and pair.idle_scan.target and pair.idle_scan.target.valid then
    result.priority = "idle-scan-animation"
    result.reason = "no higher-priority task; idle scan animation active"
    result.target = tech_priests_0246_entity_label(pair.idle_scan.target)
    return result
  end
  if pair.idle_conversation or pair.idle_conversation_listener_until then
    result.priority = "idle-conversation"
    result.reason = "no higher-priority task; idle conversation active or listening"
    return result
  end
  return result
end

function tech_priests_0246_priority_blocks_idle(pair)
  if not tech_priests_0246_idle_quarantine_enabled() then return false end
  local ok, probe = pcall(function() return tech_priests_0246_priority_probe(pair) end)
  if not ok or not probe then return false end
  local p = probe.priority
  return p ~= "idle" and p ~= "idle-scan-animation" and p ~= "idle-conversation" and p ~= "invalid"
end

function tech_priests_0246_pair_wait_summary(pair)
  local waits = {}
  local now = game and game.tick or 0
  local function add(name, tick)
    tick = tonumber(tick)
    if tick and tick > now then waits[#waits + 1] = name .. "=" .. tostring(math.ceil((tick - now) / 60)) .. "s" end
  end
  add("next-consecrate", pair and pair.next_consecration_tick)
  add("next-logistics", pair and pair.next_logistic_requisition_tick)
  add("frustration-due", pair and pair.logistic_frustration_due_tick)
  add("next-idle-convo", pair and pair.next_idle_conversation_tick)
  add("next-idle-convo-attempt", pair and pair.next_idle_conversation_attempt_tick)
  if pair and pair.idle_scan then
    add("idle-scan-due", pair.idle_scan.due_tick)
    add("idle-scan-retarget", pair.idle_scan.next_retarget_tick)
  end
  if pair and pair.inventory_scan then
    add("inventory-scan-due", pair.inventory_scan.scan_due_tick)
  end
  if #waits == 0 then return "waits=none" end
  return "waits=" .. table.concat(waits, ",")
end

function tech_priests_0246_log_pair_diagnostic(pair, stage, probe_before, mode_before, mode_after)
  if not tech_priests_0246_diagnostics_enabled() then return end
  ensure_storage()
  storage.tech_priests.diagnostics_0246 = storage.tech_priests.diagnostics_0246 or {}
  local key = pair and (pair.station_unit or (pair.station and pair.station.valid and pair.station.unit_number)) or 0
  local interval = math.max(30, tech_priests_0246_int_setting("tech-priests-priority-diagnostics-interval-ticks", 300))
  local record = storage.tech_priests.diagnostics_0246[key] or {}
  local now = game and game.tick or 0
  local priority = probe_before and probe_before.priority or "unknown"
  local target = probe_before and probe_before.target or "none"
  local reason = probe_before and probe_before.reason or "no reason"
  local signature = tostring(priority) .. "|" .. tostring(mode_before) .. "|" .. tostring(mode_after) .. "|" .. tostring(target)
  local should = (record.signature ~= signature) or now >= (record.next_log_tick or 0)
  if not should then return end
  record.signature = signature
  record.next_log_tick = now + interval
  storage.tech_priests.diagnostics_0246[key] = record
  tech_priests_0246_diag_line(stage .. " " .. tech_priests_0246_pair_label(pair) .. " priority=" .. tostring(priority) .. " mode=" .. tostring(mode_before) .. "->" .. tostring(mode_after) .. " target=" .. tostring(target) .. " " .. tech_priests_0246_pair_wait_summary(pair) .. " reason=" .. tostring(reason))
end

TECH_PRIESTS_ORIGINAL_IS_PAIR_AVAILABLE_FOR_IDLE_SCAN_0246 = is_pair_available_for_idle_scan
function is_pair_available_for_idle_scan(pair)
  if tech_priests_0246_priority_blocks_idle(pair) then
    if pair then pair.idle_scan_quarantined_0246 = game and game.tick or 0 end
    return false
  end
  if TECH_PRIESTS_ORIGINAL_IS_PAIR_AVAILABLE_FOR_IDLE_SCAN_0246 then return TECH_PRIESTS_ORIGINAL_IS_PAIR_AVAILABLE_FOR_IDLE_SCAN_0246(pair) end
  return false
end

TECH_PRIESTS_ORIGINAL_IS_PAIR_AVAILABLE_FOR_IDLE_CONVERSATION_0246 = tech_priests_is_pair_available_for_idle_conversation_0167
function tech_priests_is_pair_available_for_idle_conversation_0167(pair, as_listener)
  if tech_priests_0246_priority_blocks_idle(pair) then
    if pair then pair.idle_conversation_quarantined_0246 = game and game.tick or 0 end
    return false
  end
  if TECH_PRIESTS_ORIGINAL_IS_PAIR_AVAILABLE_FOR_IDLE_CONVERSATION_0246 then return TECH_PRIESTS_ORIGINAL_IS_PAIR_AVAILABLE_FOR_IDLE_CONVERSATION_0246(pair, as_listener) end
  return false
end

TECH_PRIESTS_FINAL_TICK_PAIR_BEFORE_DIAGNOSTICS_0246 = tick_pair
function tick_pair(pair)
  if not pair then return nil end
  local mode_before = pair.mode
  local ok_probe, probe_before = pcall(function() return tech_priests_0246_priority_probe(pair) end)
  if not ok_probe then probe_before = { priority = "probe-error", reason = tostring(probe_before) } end
  local ok_tick, result = pcall(function() return TECH_PRIESTS_FINAL_TICK_PAIR_BEFORE_DIAGNOSTICS_0246(pair) end)
  if not ok_tick then
    tech_priests_0246_diag_line("tick_pair ERROR " .. tech_priests_0246_pair_label(pair) .. " error=" .. tostring(result))
    error(result)
  end
  tech_priests_0246_log_pair_diagnostic(pair, "priority-stack", probe_before, mode_before, pair.mode)
  return result
end

function tech_priests_0246_count_registered_pairs()
  ensure_storage()
  local total, valid_stations, valid_priests = 0, 0, 0
  for _, pair in pairs(storage.tech_priests.pairs_by_station or {}) do
    total = total + 1
    if pair.station and pair.station.valid then valid_stations = valid_stations + 1 end
    if pair.priest and pair.priest.valid then valid_priests = valid_priests + 1 end
  end
  return total, valid_stations, valid_priests
end

function tech_priests_0246_rebuild_station_registry(player)
  ensure_storage()
  local found, created, already, invalid = 0, 0, 0, 0
  for _, surface in pairs(game.surfaces or {}) do
    for station_name, _ in pairs(TIER_CONFIGS or {}) do
      local entities = surface.find_entities_filtered({ name = station_name })
      for _, entity in pairs(entities or {}) do
        found = found + 1
        if entity and entity.valid and entity.unit_number then
          if storage.tech_priests.pairs_by_station[entity.unit_number] then
            already = already + 1
          else
            local before_total = tech_priests_0246_count_registered_pairs()
            pcall(function() create_pair(entity) end)
            if storage.tech_priests.pairs_by_station[entity.unit_number] then created = created + 1 else invalid = invalid + 1 end
          end
        else
          invalid = invalid + 1
        end
      end
    end
  end
  local total, valid_stations, valid_priests = tech_priests_0246_count_registered_pairs()
  tech_priests_0246_player_line(player, "registry scan found=" .. found .. " created=" .. created .. " already=" .. already .. " invalid=" .. invalid .. " registered=" .. total .. " valid-stations=" .. valid_stations .. " valid-priests=" .. valid_priests)
end

function tech_priests_0246_dump_state(player)
  ensure_storage()
  local total, valid_stations, valid_priests = tech_priests_0246_count_registered_pairs()
  tech_priests_0246_player_line(player, "state summary: registered=" .. total .. " valid-stations=" .. valid_stations .. " valid-priests=" .. valid_priests .. " deployment-queue=" .. tostring(#(storage.tech_priests.deployment_queue or {})) .. " consecration-records=" .. tostring(storage.tech_priests.consecration and storage.tech_priests.consecration.machines and table_size(storage.tech_priests.consecration.machines) or 0))
  local shown = 0
  for _, pair in pairs(storage.tech_priests.pairs_by_station or {}) do
    shown = shown + 1
    if shown <= 20 then
      local ok, probe = pcall(function() return tech_priests_0246_priority_probe(pair) end)
      if not ok then probe = { priority = "probe-error", reason = tostring(probe) } end
      tech_priests_0246_player_line(player, tech_priests_0246_pair_label(pair) .. " mode=" .. tostring(pair.mode) .. " priority=" .. tostring(probe.priority) .. " target=" .. tostring(probe.target or "none") .. " " .. tech_priests_0246_pair_wait_summary(pair) .. " reason=" .. tostring(probe.reason or ""))
    end
  end
  if shown > 20 then tech_priests_0246_player_line(player, "state dump truncated after 20 pairs; full pair transitions continue in factorio-current.log.") end
end

function tech_priests_0246_force_station_scan(player)
  ensure_storage()
  if scan_existing_consecration_targets then pcall(scan_existing_consecration_targets) end
  if scan_existing_void_fusion_thrusters then pcall(scan_existing_void_fusion_thrusters) end
  if tech_priests_scan_existing_emergency_miners_0183 then pcall(tech_priests_scan_existing_emergency_miners_0183) end
  tech_priests_0246_rebuild_station_registry(player)
end

function tech_priests_0246_command_player(command)
  if command and command.player_index then return game.get_player(command.player_index) end
  return nil
end

if commands and commands.add_command then
  pcall(function() TechPriestsDebugCommandRegistry.add("tp-debug", "Tech Priests: dump 0.1.246 priority diagnostics for registered stations.", function(command) tech_priests_0246_dump_state(tech_priests_0246_command_player(command)) end) end)
  pcall(function() TechPriestsDebugCommandRegistry.add("tp-dump-state", "Tech Priests: dump registered stations, priests, current priority, mode, target, and wait timers.", function(command) tech_priests_0246_dump_state(tech_priests_0246_command_player(command)) end) end)
  pcall(function() TechPriestsDebugCommandRegistry.add("tp-rebuild-registries", "Tech Priests: scan all surfaces for Cogitator Stations and rebuild missing station/priest registry pairs.", function(command) tech_priests_0246_rebuild_station_registry(tech_priests_0246_command_player(command)) end) end)
  pcall(function() TechPriestsDebugCommandRegistry.add("tp-force-station-scan", "Tech Priests: rescan stations, consecration targets, void thrusters, and emergency miners.", function(command) tech_priests_0246_force_station_scan(tech_priests_0246_command_player(command)) end) end)
end

TechPriestsRuntimeEventRegistry.on_nth_tick(73, function()
  if not tech_priests_0246_diagnostics_enabled() then return end
  ensure_storage()
  if not storage.tech_priests.diagnostics_0246_boot_printed then
    storage.tech_priests.diagnostics_0246_boot_printed = true
    local total, valid_stations, valid_priests = tech_priests_0246_count_registered_pairs()
    tech_priests_0246_diag_line("diagnostic heartbeat online; registered=" .. total .. " valid-stations=" .. valid_stations .. " valid-priests=" .. valid_priests)
  end
end)

tech_priests_0246_diag_line("control.lua loaded; final diagnostic wrapper installed; idle priority quarantine default active.")


--------------------------------------------------------------------------
-- 0.1.248: priority doctrine repair + station sweep acquisition.
--
-- This pass deliberately avoids replacing the entire historical behavior stack.
-- It repairs the broken movement wrapper call convention, adds a station-centered
-- sweep cache for target acquisition, and makes idle/conversation layers yield
-- when attack/repair/sanctify/supply work is visible.
--------------------------------------------------------------------------

TECH_PRIESTS_SWEEP_WIDTH_0248 = 0.85
TECH_PRIESTS_SWEEP_STEP_RADIANS_0248 = math.rad(18)
TECH_PRIESTS_SWEEP_CACHE_TTL_0248 = 900
TECH_PRIESTS_SWEEP_RENDER_TTL_0248 = 18

function tech_priests_0248_diag(message)
  if tech_priests_0246_diag_line then
    tech_priests_0246_diag_line("0.1.248 " .. tostring(message))
  elseif game then
    game.print("[Tech Priests 0.1.248] " .. tostring(message))
  end
end

function tech_priests_0248_valid_pair(pair)
  return pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid
end

function tech_priests_0248_get_pair_for_station(station)
  if not (station and station.valid and station.unit_number and storage and storage.tech_priests) then return nil end
  return storage.tech_priests.pairs_by_station and storage.tech_priests.pairs_by_station[station.unit_number] or nil
end

function tech_priests_0248_get_pair_for_priest(priest)
  if not (priest and priest.valid and storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return nil end
  if find_pair_for_entity then
    local ok, pair = pcall(function() return find_pair_for_entity(priest) end)
    if ok and pair then return pair end
  end
  for _, pair in pairs(storage.tech_priests.pairs_by_station or {}) do
    if pair and pair.priest == priest then return pair end
  end
  return nil
end

function tech_priests_0248_pair_is_void(pair)
  if not pair then return false end
  if tech_priests_mark_void_doctrine_0222 then
    local ok, marked = pcall(function() return tech_priests_mark_void_doctrine_0222(pair) end)
    if ok and marked then pair = marked end
  end
  if tech_priests_pair_is_void_doctrine_0222 then
    local ok, value = pcall(function() return tech_priests_pair_is_void_doctrine_0222(pair) end)
    if ok then return not not value end
  end
  return pair.tier == "void" or (pair.station and pair.station.valid and pair.station.name == "void-cogitator-station") or (pair.priest and pair.priest.valid and pair.priest.name == "void-tech-priest")
end

-- Repair the 0.1.222 void movement wrapper signature drift. Old code calls
-- return_to_station(priest, station); the void wrapper changed the visible
-- signature to return_to_station(pair). This final adapter explicitly supports
-- both forms and sends two-argument calls to the original two-argument body.
TECH_PRIESTS_RETURN_TO_STATION_BEFORE_0248 = return_to_station
function return_to_station(subject, maybe_station)
  local pair = nil
  local priest = nil
  local station = nil

  if maybe_station ~= nil then
    priest = subject
    station = maybe_station
    pair = tech_priests_0248_get_pair_for_priest(priest) or tech_priests_0248_get_pair_for_station(station)
  elseif type(subject) == "table" and subject.station and subject.priest then
    pair = subject
    priest = pair.priest
    station = pair.station
  elseif subject and subject.valid then
    priest = subject
    pair = tech_priests_0248_get_pair_for_priest(priest)
    station = pair and pair.station or nil
  end

  if pair and tech_priests_0248_pair_is_void(pair) then
    local locus = tech_priests_0221_spawn_locus_position and tech_priests_0221_spawn_locus_position(pair) or pair.spawn_position or (pair.station and pair.station.valid and pair.station.position)
    if locus and tech_priests_0220_begin_hover_glide then
      return tech_priests_0220_begin_hover_glide(pair, locus, "void return to locus via 0.1.248 adapter")
    end
    return true
  end

  if priest and priest.valid and station and station.valid then
    if TECH_PRIESTS_ORIGINAL_RETURN_TO_STATION_0222 then
      return TECH_PRIESTS_ORIGINAL_RETURN_TO_STATION_0222(priest, station)
    end
    if issue_priest_command then
      return issue_priest_command(priest, {
        type = defines.command.go_to_location,
        destination = station.position,
        radius = 2,
        distraction = defines.distraction.by_enemy
      })
    end
  end

  if TECH_PRIESTS_RETURN_TO_STATION_BEFORE_0248 and TECH_PRIESTS_RETURN_TO_STATION_BEFORE_0248 ~= return_to_station then
    local ok, result = pcall(function() return TECH_PRIESTS_RETURN_TO_STATION_BEFORE_0248(subject, maybe_station) end)
    if ok then return result end
    tech_priests_0248_diag("return_to_station fallback failed: " .. tostring(result))
  end
  tech_priests_0248_diag("return_to_station could not resolve subject=" .. tostring(subject and subject.name or subject) .. " station=" .. tostring(maybe_station and maybe_station.name or maybe_station))
  return false
end

function tech_priests_0248_distance_sq(a, b)
  if not (a and b) then return 999999999 end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end

function tech_priests_0248_distance_to_segment_sq(point, a, b)
  if not (point and a and b) then return 999999999 end
  local px, py = point.x or 0, point.y or 0
  local ax, ay = a.x or 0, a.y or 0
  local bx, by = b.x or 0, b.y or 0
  local vx, vy = bx - ax, by - ay
  local wx, wy = px - ax, py - ay
  local len_sq = vx * vx + vy * vy
  if len_sq <= 0.0001 then return tech_priests_0248_distance_sq(point, a) end
  local t = (wx * vx + wy * vy) / len_sq
  if t < 0 then t = 0 elseif t > 1 then t = 1 end
  local cx, cy = ax + t * vx, ay + t * vy
  local dx, dy = px - cx, py - cy
  return dx * dx + dy * dy
end

function tech_priests_0248_is_enemy_of_station(station, entity)
  if not (station and station.valid and entity and entity.valid) then return false end
  if is_asteroid_threat_entity and is_asteroid_threat_entity(entity) then return true end
  if not entity.force then return false end
  if station.force and station.force.is_enemy then
    local ok, value = pcall(function() return station.force.is_enemy(entity.force) end)
    if ok then return not not value end
  end
  return entity.force.name == "enemy" or (station.force and entity.force.name ~= station.force.name and entity.force.name ~= "neutral")
end
