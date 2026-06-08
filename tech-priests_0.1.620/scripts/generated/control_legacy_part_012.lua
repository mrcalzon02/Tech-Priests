-- Auto-split control.lua fragment 012 for Tech Priests 0.1.438.
-- Generated mechanically from 0.1.437 monolithic control.lua.
-- Purpose: reduce Lua main-chunk local/register pressure without deleting behavior.

function finish_emergency_desperation_craft(pair)
  local result = TECH_PRIESTS_ORIGINAL_FINISH_EMERGENCY_DESPERATION_CRAFT_0211(pair)
  if result then
    -- If this craft was performed as an assistant writ, immediately try to hand
    -- the item to the lead shrine instead of waiting through another full service
    -- cycle. This makes task-force construction resources actually arrive where
    -- the lead Tech-Priest can use them.
    tech_priests_try_fulfill_assist_job_now_0211(pair)
  end
  return result
end

TECH_PRIESTS_ORIGINAL_HANDLE_PRIEST_SCAVENGE_TASK_0211 = handle_priest_scavenge_task
function handle_priest_scavenge_task(pair)
  local result = TECH_PRIESTS_ORIGINAL_HANDLE_PRIEST_SCAVENGE_TASK_0211(pair)
  if result then
    tech_priests_try_fulfill_assist_job_now_0211(pair)
  end
  return result
end

-- 0.1.212 Space-platform guarded walking restoration pass.
-- 0.1.208/0.1.209 made platform priests stable at the exact spawn locus, but
-- the legacy 0.1.206 tether was still effectively keeping them parked unless an
-- already-active path guard existed.  This pass adds a small platform-safe work
-- walk scheduler: priests can periodically path to nearby valid platform work
-- objects/inspection points, then the existing guard returns them to the exact
-- locus if the path becomes stale, unsafe, or complete.
TECH_PRIESTS_PLATFORM_WALK_TEST_TICKS_0212 = 73
TECH_PRIESTS_PLATFORM_WALK_COOLDOWN_TICKS_0212 = 60 * 6
TECH_PRIESTS_PLATFORM_WALK_MIN_DISTANCE_SQ_0212 = 2.25
TECH_PRIESTS_PLATFORM_STAND_OFFSETS_0212 = {
  { x = 0, y = -1.5 }, { x = 1.5, y = 0 }, { x = 0, y = 1.5 }, { x = -1.5, y = 0 },
  { x = 1.5, y = -1.5 }, { x = 1.5, y = 1.5 }, { x = -1.5, y = 1.5 }, { x = -1.5, y = -1.5 },
  { x = 0, y = -2.0 }, { x = 2.0, y = 0 }, { x = 0, y = 2.0 }, { x = -2.0, y = 0 }
}
TECH_PRIESTS_PLATFORM_WALK_TARGET_TYPES_0212 = {
  ["container"] = true,
  ["logistic-container"] = true,
  ["assembling-machine"] = true,
  ["furnace"] = true,
  ["mining-drill"] = true,
  ["boiler"] = true,
  ["generator"] = true,
  ["reactor"] = true,
  ["roboport"] = true,
  ["solar-panel"] = true,
  ["accumulator"] = true,
  ["inserter"] = true,
  ["pipe"] = true,
  ["pipe-to-ground"] = true,
  ["pump"] = true,
  ["electric-pole"] = true,
  ["lab"] = true,
  ["ammo-turret"] = true,
  ["electric-turret"] = true,
  ["fluid-turret"] = true,
  ["radar"] = true,
  ["cargo-landing-pad"] = true,
  ["space-platform-hub"] = true
}

function tech_priests_platform_exact_walk_tile_0212(pair, position)
  if not (pair and pair.station and pair.station.valid and position) then return nil end
  local surface = pair.station.surface
  if tech_priests_space_tile_is_foundation_0205 and not tech_priests_space_tile_is_foundation_0205(surface, position) then return nil end
  if tech_priests_tile_has_bad_spawn_entity_0204 and tech_priests_tile_has_bad_spawn_entity_0204(surface, position) then return nil end
  if tech_priests_platform_position_in_station_radius_0209 and not tech_priests_platform_position_in_station_radius_0209(pair, position) then return nil end
  local priest_name = pair.priest and pair.priest.valid and pair.priest.name or "tech-priest"
  local ok, place = pcall(function()
    return surface.find_non_colliding_position(priest_name, position, 0.15, 0.05, true)
  end)
  if ok and place then
    local dx = (place.x or 0) - (position.x or 0)
    local dy = (place.y or 0) - (position.y or 0)
    if (dx * dx + dy * dy) <= 0.09 then return { x = place.x, y = place.y } end
  end
  return nil
end

function tech_priests_platform_find_stand_near_entity_0212(pair, entity)
  if not (pair and entity and entity.valid and entity.position) then return nil end
  for _, off in ipairs(TECH_PRIESTS_PLATFORM_STAND_OFFSETS_0212) do
    local candidate = { x = entity.position.x + off.x, y = entity.position.y + off.y }
    local stand = tech_priests_platform_exact_walk_tile_0212(pair, candidate)
    if stand then return stand end
  end
  return nil
end

function tech_priests_platform_find_walk_target_0212(pair)
  if not (tech_priests_platform_pair_0206 and tech_priests_platform_pair_0206(pair) and pair.priest and pair.priest.valid and pair.station and pair.station.valid) then return nil end
  local radius = (refresh_pair_radius and refresh_pair_radius(pair)) or pair.radius or (get_station_operating_radius and get_station_operating_radius(pair.station)) or 30
  local pos = pair.station.position
  local area = { { pos.x - radius, pos.y - radius }, { pos.x + radius, pos.y + radius } }
  local ok, entities = pcall(function() return pair.station.surface.find_entities_filtered({ area = area, force = pair.station.force }) end)
  if not (ok and entities) then return nil end
  local best, best_sq = nil, nil
  for _, entity in pairs(entities) do
    if entity and entity.valid and entity ~= pair.station and entity ~= pair.priest and TECH_PRIESTS_PLATFORM_WALK_TARGET_TYPES_0212[entity.type] then
      local stand = tech_priests_platform_find_stand_near_entity_0212(pair, entity)
      if stand then
        local dxs = stand.x - pair.station.position.x
        local dys = stand.y - pair.station.position.y
        local station_sq = dxs * dxs + dys * dys
        if station_sq <= (radius + 0.5) * (radius + 0.5) then
          local dx = stand.x - pair.priest.position.x
          local dy = stand.y - pair.priest.position.y
          local priest_sq = dx * dx + dy * dy
          if priest_sq >= TECH_PRIESTS_PLATFORM_WALK_MIN_DISTANCE_SQ_0212 and (not best_sq or priest_sq < best_sq) then
            best = { position = stand, entity = entity }
            best_sq = priest_sq
          end
        end
      end
    end
  end
  return best
end

function tech_priests_platform_command_walk_0212(pair, destination, reason)
  if not (pair and pair.priest and pair.priest.valid and destination) then return false end
  if not (tech_priests_platform_begin_path_0209 and tech_priests_platform_begin_path_0209(pair, destination, reason or "platform doctrine walk")) then return false end
  local priest = pair.priest
  pcall(function() priest.active = true end)
  pcall(function() priest.destructible = false end)
  local issued = false
  pcall(function()
    if priest.commandable then
      priest.commandable.set_command({
        type = defines.command.go_to_location,
        destination = destination,
        distraction = defines.distraction.none
      })
      issued = true
    end
  end)
  if not issued then
    pcall(function()
      priest.set_command({
        type = defines.command.go_to_location,
        destination = destination,
        distraction = defines.distraction.none
      })
      issued = true
    end)
  end
  if issued then
    pair.platform_last_walk_command_tick_0212 = game.tick
    if tech_priests_lifecycle_note_0201 then
      tech_priests_lifecycle_note_0201(pair, "platform walk command issued", priest, tostring(reason or "walk") .. " to=" .. tostring(destination.x) .. "," .. tostring(destination.y))
    end
    return true
  end
  tech_priests_platform_clear_path_0209(pair, "command issue failed")
  if tech_priests_lifecycle_note_0201 then tech_priests_lifecycle_note_0201(pair, "platform walk command failed", priest, tostring(reason or "walk")) end
  return false
end

-- Override the old hard-stop helper.  Hard recoveries still stop; ordinary periodic
-- tethers should keep the unit active so guarded commands can execute.
function tech_priests_stop_platform_priest_0206(pair, reason)
  if not (tech_priests_platform_pair_0206 and tech_priests_platform_pair_0206(pair) and pair.priest and pair.priest.valid) then return false end
  local priest = pair.priest
  local text = tostring(reason or "")
  local hard = string.find(text, "unsafe", 1, true) or string.find(text, "recovery", 1, true) or string.find(text, "surface", 1, true) or string.find(text, "recreate", 1, true)
  if hard then
    pcall(function() if priest.commandable then priest.commandable.set_command({ type = defines.command.stop }) end end)
  end
  pcall(function() priest.active = true end)
  pcall(function() priest.destructible = false end)
  pair.space_platform_fallback_0204 = true
  pair.space_platform_tether_0206 = pair.space_platform_tether_0206 or {}
  if reason and tech_priests_lifecycle_note_0201 then
    local last_reason = pair.space_platform_tether_0206.last_reason_0212
    local last_tick = pair.space_platform_tether_0206.last_log_tick_0212 or 0
    if last_reason ~= reason or (game.tick - last_tick) > 600 then
      pair.space_platform_tether_0206.last_reason_0212 = reason
      pair.space_platform_tether_0206.last_log_tick_0212 = game.tick
      tech_priests_lifecycle_note_0201(pair, hard and "space platform hard stop" or "space platform guard active", priest, tostring(reason))
    end
  end
  return true
end

-- Final override: when no guarded path is active, do not permanently suppress motion;
-- simply enforce gross safety and leave the priest eligible for the scheduler below.

TechPriestsRuntimeEventRegistry.on_nth_tick(TECH_PRIESTS_PLATFORM_WALK_TEST_TICKS_0212, function()
  if not (storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return end
  for _, pair in pairs(storage.tech_priests.pairs_by_station) do
    if tech_priests_platform_pair_0206 and tech_priests_platform_pair_0206(pair) and pair.priest and pair.priest.valid then
      pcall(function() pair.priest.active = true end)
      pcall(function() pair.priest.destructible = false end)
      if not (pair.space_platform_pathing_0209 and pair.space_platform_pathing_0209.active) then
        local next_tick = pair.next_platform_walk_attempt_tick_0212 or 0
        if game.tick >= next_tick then
          pair.next_platform_walk_attempt_tick_0212 = game.tick + TECH_PRIESTS_PLATFORM_WALK_COOLDOWN_TICKS_0212 + ((pair.station.unit_number or 0) % 180)
          local target = tech_priests_platform_find_walk_target_0212(pair)
          if target and target.position then
            pair.platform_walk_target_entity_0212 = target.entity and target.entity.valid and target.entity.unit_number or nil
            tech_priests_platform_command_walk_0212(pair, target.position, "space platform doctrine inspection")
          elseif tech_priests_lifecycle_note_0201 then
            tech_priests_lifecycle_note_0201(pair, "platform walk target unavailable", pair.priest, "no safe local work tile")
          end
        end
      end
    end
  end
end)


-- 0.1.214 platform movement and emergency scrounge stabilization.
-- * Rocks/simple mineable entities are valid emergency scrounge targets.
-- * Tree/rock scripted mining spills products onto the ground instead of silently
--   converting the entity into invisible doctrine points.
-- * Space-platform walking no longer targets belts/pipes/inserters and blacklists
--   failing path destinations that cause belt-bounce teleport loops.
-- * Platform priests remain active after locus recovery so later guarded movement
--   can actually resume.

TECH_PRIESTS_PLATFORM_BAD_WALK_TARGET_TTL_0214 = 60 * 30
TECH_PRIESTS_PLATFORM_BAD_WALK_MAX_0214 = 96

function tech_priests_0214_pos_key(position)
  if not position then return "nil" end
  return tostring(math.floor((position.x or 0) * 10 + 0.5) / 10) .. "," .. tostring(math.floor((position.y or 0) * 10 + 0.5) / 10)
end

function tech_priests_0214_is_bad_platform_walk_position(pair, position)
  if not (pair and position and pair.platform_bad_walk_positions_0214) then return false end
  local rec = pair.platform_bad_walk_positions_0214[tech_priests_0214_pos_key(position)]
  if not rec then return false end
  if game and game.tick and rec.until_tick and game.tick > rec.until_tick then
    pair.platform_bad_walk_positions_0214[tech_priests_0214_pos_key(position)] = nil
    return false
  end
  return true
end

function tech_priests_0214_blacklist_platform_walk_position(pair, position, reason)
  if not (pair and position) then return end
  pair.platform_bad_walk_positions_0214 = pair.platform_bad_walk_positions_0214 or {}
  local key = tech_priests_0214_pos_key(position)
  pair.platform_bad_walk_positions_0214[key] = { until_tick = (game and game.tick or 0) + TECH_PRIESTS_PLATFORM_BAD_WALK_TARGET_TTL_0214, reason = tostring(reason or "bad-platform-walk") }
  local n = 0
  for k in pairs(pair.platform_bad_walk_positions_0214) do
    n = n + 1
    if n > TECH_PRIESTS_PLATFORM_BAD_WALK_MAX_0214 then pair.platform_bad_walk_positions_0214[k] = nil end
  end
  if tech_priests_lifecycle_note_0201 then tech_priests_lifecycle_note_0201(pair, "platform walk target blacklisted", pair.priest, key .. " reason=" .. tostring(reason or "bad-platform-walk")) end
end

-- Do not choose belt-adjacent utility entities as platform stroll targets. These
-- were causing a priest to repeatedly try to step onto a belt, get snapped home,
-- and try again like a red-robed metronome with poor judgement.
if TECH_PRIESTS_PLATFORM_WALK_TARGET_TYPES_0212 then
  TECH_PRIESTS_PLATFORM_WALK_TARGET_TYPES_0212["transport-belt"] = nil
  TECH_PRIESTS_PLATFORM_WALK_TARGET_TYPES_0212["underground-belt"] = nil
  TECH_PRIESTS_PLATFORM_WALK_TARGET_TYPES_0212["splitter"] = nil
  TECH_PRIESTS_PLATFORM_WALK_TARGET_TYPES_0212["loader"] = nil
  TECH_PRIESTS_PLATFORM_WALK_TARGET_TYPES_0212["loader-1x1"] = nil
  TECH_PRIESTS_PLATFORM_WALK_TARGET_TYPES_0212["linked-belt"] = nil
  TECH_PRIESTS_PLATFORM_WALK_TARGET_TYPES_0212["inserter"] = nil
  TECH_PRIESTS_PLATFORM_WALK_TARGET_TYPES_0212["pipe"] = nil
  TECH_PRIESTS_PLATFORM_WALK_TARGET_TYPES_0212["pipe-to-ground"] = nil
  TECH_PRIESTS_PLATFORM_WALK_TARGET_TYPES_0212["pump"] = nil
end

function tech_priests_platform_safe_standing_position_0209(pair, position)
  if not (tech_priests_platform_pair_0206 and tech_priests_platform_pair_0206(pair) and pair.station and pair.station.valid and position) then return false end
  if tech_priests_0214_is_bad_platform_walk_position(pair, position) then return false end
  if not tech_priests_platform_position_in_station_radius_0209(pair, position) then return false end
  if tech_priests_space_tile_is_foundation_0205 and not tech_priests_space_tile_is_foundation_0205(pair.station.surface, position) then return false end
  if tech_priests_tile_has_bad_spawn_entity_0204 and tech_priests_tile_has_bad_spawn_entity_0204(pair.station.surface, position) then return false end
  local ok, place = pcall(function()
    return pair.station.surface.find_non_colliding_position(pair.priest and pair.priest.valid and pair.priest.name or "tech-priest", position, 0.20, 0.05, true)
  end)
  if ok and place then
    local dx = (place.x or 0) - (position.x or 0)
    local dy = (place.y or 0) - (position.y or 0)
    return (dx * dx + dy * dy) <= 0.16
  end
  return false
end

function tech_priests_platform_exact_walk_tile_0212(pair, position)
  if not (pair and pair.station and pair.station.valid and position) then return nil end
  if tech_priests_0214_is_bad_platform_walk_position(pair, position) then return nil end
  local surface = pair.station.surface
  if tech_priests_space_tile_is_foundation_0205 and not tech_priests_space_tile_is_foundation_0205(surface, position) then return nil end
  if tech_priests_tile_has_bad_spawn_entity_0204 and tech_priests_tile_has_bad_spawn_entity_0204(surface, position) then return nil end
  if tech_priests_platform_position_in_station_radius_0209 and not tech_priests_platform_position_in_station_radius_0209(pair, position) then return nil end
  local priest_name = pair.priest and pair.priest.valid and pair.priest.name or "tech-priest"
  local ok, place = pcall(function()
    return surface.find_non_colliding_position(priest_name, position, 0.20, 0.05, true)
  end)
  if ok and place then
    local dx = (place.x or 0) - (position.x or 0)
    local dy = (place.y or 0) - (position.y or 0)
    if (dx * dx + dy * dy) <= 0.16 then return { x = place.x, y = place.y } end
  end
  return nil
end

-- Harden platform path begin/guard after the 0.1.212 scheduler. A path that lands
-- on a belt/pipe/inserter tile is now considered failed and blacklisted briefly.
TECH_PRIESTS_ORIGINAL_PLATFORM_BEGIN_PATH_0214 = tech_priests_platform_begin_path_0209
function tech_priests_platform_begin_path_0209(pair, target, reason)
  local pos = tech_priests_position_from_target_0209 and tech_priests_position_from_target_0209(target) or target
  if not (pair and pos) then return false end
  if not tech_priests_platform_safe_standing_position_0209(pair, pos) then
    if tech_priests_lifecycle_note_0201 and pair.priest and pair.priest.valid then tech_priests_lifecycle_note_0201(pair, "platform path rejected", pair.priest, "unsafe exact target " .. tostring(pos.x) .. "," .. tostring(pos.y)) end
    return false
  end
  return TECH_PRIESTS_ORIGINAL_PLATFORM_BEGIN_PATH_0214(pair, { x = pos.x, y = pos.y }, reason)
end

TECH_PRIESTS_ORIGINAL_PLATFORM_PATH_GUARD_0214 = tech_priests_platform_path_guard_0209
function tech_priests_platform_path_guard_0209(pair, reason)
  if pair and pair.priest and pair.priest.valid and pair.station and pair.station.valid then
    if tech_priests_tile_has_bad_spawn_entity_0204 and tech_priests_tile_has_bad_spawn_entity_0204(pair.station.surface, pair.priest.position) then
      local target = pair.space_platform_pathing_0209 and pair.space_platform_pathing_0209.target
      if target then tech_priests_0214_blacklist_platform_walk_position(pair, target, "walked onto blocked/belt tile") end
      tech_priests_platform_clear_path_0209(pair, "blocked current tile")
      if tech_priests_lifecycle_note_0201 then tech_priests_lifecycle_note_0201(pair, "platform blocked-tile drift", pair.priest, "returning to locus") end
      return false
    end
  end
  return TECH_PRIESTS_ORIGINAL_PLATFORM_PATH_GUARD_0214(pair, reason)
end

TECH_PRIESTS_ORIGINAL_PLATFORM_FORCE_LOCUS_0214 = tech_priests_force_priest_to_platform_locus_0208
function tech_priests_force_priest_to_platform_locus_0208(pair, reason)
  local result = TECH_PRIESTS_ORIGINAL_PLATFORM_FORCE_LOCUS_0214(pair, reason)
  if pair and pair.priest and pair.priest.valid then
    pcall(function() pair.priest.active = true end)
    pcall(function() pair.priest.destructible = false end)
  end
  return result
end

-- Rebuild the scheduler's target finder so it ignores temporarily blacklisted
-- standing tiles and avoids selecting target entities that sit on bad/belt tiles.
function tech_priests_platform_find_walk_target_0212(pair)
  if not (tech_priests_platform_pair_0206 and tech_priests_platform_pair_0206(pair) and pair.priest and pair.priest.valid and pair.station and pair.station.valid) then return nil end
  local radius = (refresh_pair_radius and refresh_pair_radius(pair)) or pair.radius or (get_station_operating_radius and get_station_operating_radius(pair.station)) or 30
  local pos = pair.station.position
  local area = { { pos.x - radius, pos.y - radius }, { pos.x + radius, pos.y + radius } }
  local ok, entities = pcall(function() return pair.station.surface.find_entities_filtered({ area = area, force = pair.station.force }) end)
  if not (ok and entities) then return nil end
  local best, best_sq = nil, nil
  for _, entity in pairs(entities) do
    if entity and entity.valid and entity ~= pair.station and entity ~= pair.priest and TECH_PRIESTS_PLATFORM_WALK_TARGET_TYPES_0212 and TECH_PRIESTS_PLATFORM_WALK_TARGET_TYPES_0212[entity.type] then
      if not (tech_priests_tile_has_bad_spawn_entity_0204 and tech_priests_tile_has_bad_spawn_entity_0204(pair.station.surface, entity.position)) then
        local stand = tech_priests_platform_find_stand_near_entity_0212(pair, entity)
        if stand and not tech_priests_0214_is_bad_platform_walk_position(pair, stand) then
          local dxs = stand.x - pair.station.position.x
          local dys = stand.y - pair.station.position.y
          local station_sq = dxs * dxs + dys * dys
          if station_sq <= (radius + 0.5) * (radius + 0.5) then
            local dx = stand.x - pair.priest.position.x
            local dy = stand.y - pair.priest.position.y
            local priest_sq = dx * dx + dy * dy
            if priest_sq >= TECH_PRIESTS_PLATFORM_WALK_MIN_DISTANCE_SQ_0212 and (not best_sq or priest_sq < best_sq) then
              best = { position = stand, entity = entity }
              best_sq = priest_sq
            end
          end
        end
      end
    end
  end
  return best
end

function tech_priests_0214_get_mineable_products(entity)
  if not (entity and entity.valid and entity.prototype) then return {} end
  local ok, mineable = pcall(function() return entity.prototype.mineable_properties end)
  if not (ok and mineable and mineable.products) then return {} end
  local out = {}
  for _, product in pairs(mineable.products or {}) do
    local name = product.name or product[1]
    local amount = product.amount or product.amount_min or product[2] or 1
    if name and amount and amount > 0 then out[#out + 1] = { name = name, amount = math.max(1, math.floor(amount)) } end
  end
  return out
end

function tech_priests_0214_is_mineable_rock_entity(entity)
  if not (entity and entity.valid) then return false end
  local typ = entity.type
  if typ ~= "simple-entity" and typ ~= "simple-entity-with-owner" then return false end
  local name = string.lower(entity.name or "")
  if not (string.find(name, "rock", 1, true) or string.find(name, "stone", 1, true) or string.find(name, "coal", 1, true)) then return false end
  local products = tech_priests_0214_get_mineable_products(entity)
  return #products > 0
end

function tech_priests_0214_best_product_for_recipe(entity, recipe)
  local best_name, best_value, best_amount = nil, 0, 1
  for _, product in ipairs(tech_priests_0214_get_mineable_products(entity)) do
    local value = get_emergency_material_value(recipe, product.name)
    if value > best_value then
      best_name, best_value, best_amount = product.name, value, product.amount or 1
    end
  end
  return best_name, best_value, best_amount
end

TECH_PRIESTS_ORIGINAL_BUILD_EMERGENCY_CRAFT_CANDIDATES_0214 = build_emergency_craft_candidates
function build_emergency_craft_candidates(pair, recipe)
  local candidates = TECH_PRIESTS_ORIGINAL_BUILD_EMERGENCY_CRAFT_CANDIDATES_0214(pair, recipe) or {}
  if not (pair and pair.station and pair.station.valid and recipe) then return candidates end
  local station = pair.station
  local radius = refresh_pair_radius(pair)
  local pos = station.position
  local area = {{pos.x - radius, pos.y - radius}, {pos.x + radius, pos.y + radius}}
  local ok, rocks = pcall(function() return station.surface.find_entities_filtered({ area = area, type = {"simple-entity", "simple-entity-with-owner"}, limit = EMERGENCY_CRAFT_RESOURCE_SCAN_LIMIT }) end)
  if ok and rocks then
    for _, entity in pairs(rocks) do
      if tech_priests_0214_is_mineable_rock_entity(entity) then
        local item_name, value = tech_priests_0214_best_product_for_recipe(entity, recipe)
        if item_name and value and value > 0 then
          local dx = entity.position.x - pos.x
          local dy = entity.position.y - pos.y
          local dist = dx * dx + dy * dy
          if dist <= radius * radius then
            candidates[#candidates + 1] = { kind = "mineable-entity", entity = entity, item_name = item_name, value = value, station_distance_sq = dist, unit_number = entity.unit_number or 0 }
          end
        end
      end
    end
  end
  table.sort(candidates, function(a, b)
    local priority = { inventory = 1, ground = 2, ["asteroid-chunk"] = 3, ["mineable-entity"] = 4, resource = 5 }
    local ap = priority[a.kind] or 9
    local bp = priority[b.kind] or 9
    if ap ~= bp then return ap < bp end
    if math.abs((a.station_distance_sq or 0) - (b.station_distance_sq or 0)) > 0.001 then return (a.station_distance_sq or 0) < (b.station_distance_sq or 0) end
    return (a.unit_number or 0) < (b.unit_number or 0)
  end)
  return candidates
end

function tech_priests_0214_spill_products(pair, entity, fallback_item, fallback_count)
  if not (entity and entity.valid) then return false end
  local surface = entity.surface
  local position = entity.position
  local force = pair and pair.station and pair.station.valid and pair.station.force or nil
  local spilled = false
  local products = tech_priests_0214_get_mineable_products(entity)
  if #products == 0 and fallback_item then products = { { name = fallback_item, amount = fallback_count or 1 } } end
  for _, product in ipairs(products) do
    if product.name and product.amount and product.amount > 0 then
      pcall(function()
        surface.spill_item_stack({ position = position, stack = { name = product.name, count = math.max(1, product.amount) }, enable_looted = true, force = force, allow_belts = false })
      end)
      spilled = true
    end
  end
  return spilled
end

TECH_PRIESTS_ORIGINAL_ACQUIRE_EMERGENCY_MATERIAL_0214 = acquire_emergency_material
function acquire_emergency_material(pair, task, candidate)
  if not (pair and task and candidate and candidate.entity and candidate.entity.valid) then return TECH_PRIESTS_ORIGINAL_ACQUIRE_EMERGENCY_MATERIAL_0214(pair, task, candidate) end
  local value = math.max(1, candidate.value or 1)
  if candidate.kind == "mineable-entity" then
    tech_priests_0214_spill_products(pair, candidate.entity, candidate.item_name, 1)
    pcall(function() candidate.entity.destroy({ raise_destroy = false }) end)
    task.gathered_units = (task.gathered_units or 0) + value
    return true
  end
  if candidate.kind == "resource" and candidate.entity and candidate.entity.valid and is_tree_entity and is_tree_entity(candidate.entity) then
    tech_priests_0214_spill_products(pair, candidate.entity, "wood", 1)
    pcall(function() candidate.entity.destroy({ raise_destroy = false }) end)
    task.gathered_units = (task.gathered_units or 0) + value
    return true
  end
  return TECH_PRIESTS_ORIGINAL_ACQUIRE_EMERGENCY_MATERIAL_0214(pair, task, candidate)
end


-- 0.1.215 movement/text stabilization pass.
-- The previous platform movement restoration still left older wrapper chains able to
-- treat every platform move as "blocked" and every periodic tether as a hard snap.
-- This finalizes a gentler platform patrol model: direct guarded command issuance,
-- no legacy wrapper recursion, and no repeat attempts at failed belt/blocked tiles.

TECH_PRIESTS_PLATFORM_PATROL_COOLDOWN_TICKS_0215 = 60 * 4
TECH_PRIESTS_PLATFORM_PATROL_MIN_DISTANCE_SQ_0215 = 1.20 * 1.20
TECH_PRIESTS_PLATFORM_PATROL_MAX_DISTANCE_SQ_0215 = 8.00 * 8.00
TECH_PRIESTS_PLATFORM_PATROL_OFFSETS_0215 = {
  { x =  2, y =  0 }, { x = -2, y =  0 }, { x =  0, y =  2 }, { x =  0, y = -2 },
  { x =  3, y =  1 }, { x = -3, y =  1 }, { x =  3, y = -1 }, { x = -3, y = -1 },
  { x =  1, y =  3 }, { x = -1, y =  3 }, { x =  1, y = -3 }, { x = -1, y = -3 },
  { x =  4, y =  0 }, { x = -4, y =  0 }, { x =  0, y =  4 }, { x =  0, y = -4 },
  { x =  5, y =  2 }, { x = -5, y =  2 }, { x =  5, y = -2 }, { x = -5, y = -2 },
}

function tech_priests_0215_round_pos_key(position)
  if not position then return "nil" end
  return tostring(math.floor((position.x or 0) * 10 + 0.5) / 10) .. "," .. tostring(math.floor((position.y or 0) * 10 + 0.5) / 10)
end

function tech_priests_0215_platform_bad_neighbor(surface, position)
  if not (surface and position) then return true end
  local area = {{position.x - 0.55, position.y - 0.55}, {position.x + 0.55, position.y + 0.55}}
  local ok, ents = pcall(function() return surface.find_entities_filtered({ area = area }) end)
  if not (ok and ents) then return false end
  local bad = {
    ["transport-belt"] = true, ["underground-belt"] = true, ["splitter"] = true,
    ["loader"] = true, ["loader-1x1"] = true, ["linked-belt"] = true,
    ["inserter"] = true, ["pipe"] = true, ["pipe-to-ground"] = true, ["pump"] = true,
  }
  for _, e in pairs(ents) do
    if e and e.valid and bad[e.type] then return true end
  end
  return false
end

function tech_priests_0215_platform_exact_safe_tile(pair, position)
  if not (pair and pair.station and pair.station.valid and position) then return nil end
  local surface = pair.station.surface
  if tech_priests_0214_is_bad_platform_walk_position and tech_priests_0214_is_bad_platform_walk_position(pair, position) then return nil end
  if tech_priests_platform_position_in_station_radius_0209 and not tech_priests_platform_position_in_station_radius_0209(pair, position) then return nil end
  if tech_priests_space_tile_is_foundation_0205 and not tech_priests_space_tile_is_foundation_0205(surface, position) then return nil end
  if tech_priests_tile_has_bad_spawn_entity_0204 and tech_priests_tile_has_bad_spawn_entity_0204(surface, position) then return nil end
  if tech_priests_0215_platform_bad_neighbor(surface, position) then return nil end
  local priest_name = pair.priest and pair.priest.valid and pair.priest.name or "tech-priest"
  local ok, place = pcall(function()
    return surface.find_non_colliding_position(priest_name, position, 0.12, 0.04, true)
  end)
  if ok and place then
    local dx = (place.x or 0) - (position.x or 0)
    local dy = (place.y or 0) - (position.y or 0)
    if (dx * dx + dy * dy) <= 0.08 then return { x = place.x, y = place.y } end
  end
  return nil
end

function tech_priests_0215_platform_patrol_destination(pair)
  if not (tech_priests_platform_pair_0206 and tech_priests_platform_pair_0206(pair) and pair.priest and pair.priest.valid and pair.station and pair.station.valid) then return nil end
  local anchor = nil
  if tech_priests_get_authoritative_platform_spawn_locus_0207 then anchor = tech_priests_get_authoritative_platform_spawn_locus_0207(pair, pair.priest.name) end
  anchor = anchor or pair.spawn_position or pair.station.position
  local start = ((pair.station.unit_number or 0) + (game and game.tick or 0)) % #TECH_PRIESTS_PLATFORM_PATROL_OFFSETS_0215
  local best, best_sq = nil, nil
  for i = 1, #TECH_PRIESTS_PLATFORM_PATROL_OFFSETS_0215 do
    local off = TECH_PRIESTS_PLATFORM_PATROL_OFFSETS_0215[((start + i - 1) % #TECH_PRIESTS_PLATFORM_PATROL_OFFSETS_0215) + 1]
    local candidate = { x = anchor.x + off.x, y = anchor.y + off.y }
    local stand = tech_priests_0215_platform_exact_safe_tile(pair, candidate)
    if stand then
      local dx = stand.x - pair.priest.position.x
      local dy = stand.y - pair.priest.position.y
      local sq = dx * dx + dy * dy
      if sq >= TECH_PRIESTS_PLATFORM_PATROL_MIN_DISTANCE_SQ_0215 and sq <= TECH_PRIESTS_PLATFORM_PATROL_MAX_DISTANCE_SQ_0215 then
        if not best_sq or sq < best_sq then best, best_sq = stand, sq end
      end
    end
  end
  return best
end

function tech_priests_0215_direct_command_platform_walk(pair, destination, reason)
  if not (pair and pair.priest and pair.priest.valid and destination) then return false end
  if not tech_priests_0215_platform_exact_safe_tile(pair, destination) then return false end
  pair.space_platform_pathing_0209 = {
    active = true,
    target = { x = destination.x, y = destination.y },
    started_tick = game.tick,
    last_seen_tick = game.tick,
    reason = tostring(reason or "platform patrol"),
    last_log_tick = game.tick
  }
  pair.space_platform_tether_0206 = pair.space_platform_tether_0206 or {}
  pair.space_platform_tether_0206.allow_pathing = true
  pair.mode = "space-platform-doctrine"
  pair.task_summary = "Space platform doctrine · guarded movement"
  local priest = pair.priest
  pcall(function() priest.active = true end)
  pcall(function() priest.destructible = false end)
  local ok = pcall(function()
    if priest.commandable then
      priest.commandable.set_command({
        type = defines.command.go_to_location,
        destination = destination,
        distraction = defines.distraction.none
      })
    end
  end)
  if ok then
    if tech_priests_lifecycle_note_0201 then tech_priests_lifecycle_note_0201(pair, "platform patrol command issued", priest, tostring(destination.x) .. "," .. tostring(destination.y)) end
    return true
  end
  pair.space_platform_pathing_0209 = nil
  return false
end

-- Final movement override: never call the old platform-blocking wrapper path for platform priests.

function return_to_station(priest, station)
  local pair = tech_priests_pair_for_priest_entity_0206 and tech_priests_pair_for_priest_entity_0206(priest) or nil
  if tech_priests_platform_pair_0206 and tech_priests_platform_pair_0206(pair) then
    if tech_priests_platform_clear_path_0209 then tech_priests_platform_clear_path_0209(pair, "return to platform locus") end
    if tech_priests_force_priest_to_platform_locus_0208 then return tech_priests_force_priest_to_platform_locus_0208(pair, "return to platform locus") end
    return false
  end
  if TECH_PRIESTS_ORIGINAL_RETURN_TO_STATION_0206 then return TECH_PRIESTS_ORIGINAL_RETURN_TO_STATION_0206(priest, station) end
end

-- Final tether override: periodic and post-ensure calls are now safety checks only.
function tech_priests_tether_platform_priest_0206(pair, reason)
  if not (tech_priests_platform_pair_0206 and tech_priests_platform_pair_0206(pair) and pair.priest and pair.priest.valid) then return false end
  local priest = pair.priest
  pcall(function() priest.active = true end)
  pcall(function() priest.destructible = false end)
  if pair.space_platform_pathing_0209 and pair.space_platform_pathing_0209.active then
    if tech_priests_platform_path_guard_0209 and tech_priests_platform_path_guard_0209(pair, reason or "guard") then return true end
    local bad = pair.space_platform_pathing_0209 and pair.space_platform_pathing_0209.target
    if bad and tech_priests_0214_blacklist_platform_walk_position then tech_priests_0214_blacklist_platform_walk_position(pair, bad, "guard failed") end
    if tech_priests_platform_clear_path_0209 then tech_priests_platform_clear_path_0209(pair, "guard failed") end
    if tech_priests_force_priest_to_platform_locus_0208 then return tech_priests_force_priest_to_platform_locus_0208(pair, "platform guard recovery") end
    return false
  end
  if priest.surface ~= pair.station.surface then
    if tech_priests_force_priest_to_platform_locus_0208 then return tech_priests_force_priest_to_platform_locus_0208(pair, "surface recovery") end
    return false
  end
  if tech_priests_space_tile_is_foundation_0205 and not tech_priests_space_tile_is_foundation_0205(pair.station.surface, priest.position) then
    if tech_priests_force_priest_to_platform_locus_0208 then return tech_priests_force_priest_to_platform_locus_0208(pair, "unsafe tile recovery") end
    return false
  end
  if tech_priests_tile_has_bad_spawn_entity_0204 and tech_priests_tile_has_bad_spawn_entity_0204(pair.station.surface, priest.position) then
    if tech_priests_force_priest_to_platform_locus_0208 then return tech_priests_force_priest_to_platform_locus_0208(pair, "blocked tile recovery") end
    return false
  end
  if tech_priests_platform_position_in_station_radius_0209 and not tech_priests_platform_position_in_station_radius_0209(pair, priest.position) then
    if tech_priests_force_priest_to_platform_locus_0208 then return tech_priests_force_priest_to_platform_locus_0208(pair, "radius recovery") end
    return false
  end
  return true
end

-- A direct patrol scheduler independent of the old work-target scheduler. This gives
-- platform priests visible movement even when ordinary doctrine is too cautious.
TechPriestsRuntimeEventRegistry.on_nth_tick(60 * 2 + 17, function()
  if not (storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return end
  for _, pair in pairs(storage.tech_priests.pairs_by_station) do
    if tech_priests_platform_pair_0206 and tech_priests_platform_pair_0206(pair) and pair.priest and pair.priest.valid then
      pcall(function() pair.priest.active = true end)
      pcall(function() pair.priest.destructible = false end)
      if not (pair.space_platform_pathing_0209 and pair.space_platform_pathing_0209.active) then
        local due = pair.next_platform_patrol_tick_0215 or 0
        if game.tick >= due then
          pair.next_platform_patrol_tick_0215 = game.tick + TECH_PRIESTS_PLATFORM_PATROL_COOLDOWN_TICKS_0215 + ((pair.station.unit_number or 0) % 90)
          local dest = tech_priests_0215_platform_patrol_destination(pair)
          if dest then tech_priests_0215_direct_command_platform_walk(pair, dest, "platform patrol") end
        end
      end
    end
  end
end)

-- Reduce emergency/scrounge visual spam. The old display could alternate ore/plate
-- decomposition messages every few ticks across many priests, producing an unreadable
-- orange ceiling.  This keeps only a short throttled status per priest/channel.
function tech_priests_0215_normalize_status_key(text)
  text = tostring(text or "")
  text = string.gsub(text, "%s+", " ")
  text = string.gsub(text, "Writ%s+[%w:%-]+", "Writ")
  text = string.gsub(text, "%d+", "#")
  text = string.gsub(text, "acquisition in progress", "progress")
  return text
end

function tech_priests_draw_stacked_status_text_0211(pair, text, color, ttl, scale, channel)
  if not (pair and pair.priest and pair.priest.valid and text and rendering and rendering.draw_text) then return false end
  text = tech_priests_sanitize_status_text_0211 and tech_priests_sanitize_status_text_0211(text) or tostring(text)
  if text == "" then return false end
  channel = channel or "general"
  local now = game.tick
  pair.tech_priests_status_last_0215 = pair.tech_priests_status_last_0215 or {}
  local key = channel .. ":" .. tech_priests_0215_normalize_status_key(text)
  local last = pair.tech_priests_status_last_0215[channel]
  if last and (last.key == key or channel == "emergency" or channel == "task-force") and now < (last.next_tick or 0) then return true end
  pair.tech_priests_status_last_0215[channel] = { key = key, next_tick = now + (channel == "emergency" and 60 * 5 or 60 * 4) }
  pair.tech_priests_status_render_0215 = pair.tech_priests_status_render_0215 or {}
  local old = pair.tech_priests_status_render_0215[channel]
  if old then
    pcall(function()
      if old.valid then
        if tech_priests_destroy_priest_0500 and tech_priests_is_priest_0500 and tech_priests_is_priest_0500(old) then
          tech_priests_destroy_priest_0500(old, "platform-or-recreate-old-entity", pair)
        else
          old.destroy()
        end
      end
    end)
  end
  local offset_y = channel == "task-force" and -3.25 or -2.70
  local ok, obj = pcall(function()
    return rendering.draw_text({
      text = text,
      target = { entity = pair.priest, offset = { 0, offset_y } },
      surface = pair.priest.surface,
      color = color or { r = 1.0, g = 0.65, b = 0.18, a = 0.90 },
      scale = scale or 0.54,
      alignment = "center",
      time_to_live = ttl or 90,
      use_rich_text = true
    })
  end)
  if ok and obj then pair.tech_priests_status_render_0215[channel] = obj end
  return true
end

function tech_priests_draw_emergency_operation_status_0184(pair, text)
  return tech_priests_draw_stacked_status_text_0211(pair, text, { r = 1.0, g = 0.55, b = 0.12, a = 0.88 }, 90, 0.54, "emergency")
end

function tech_priests_task_force_snippet_0187(pair, text)
  return tech_priests_draw_stacked_status_text_0211(pair, text, { r = 1.0, g = 0.78, b = 0.22, a = 0.88 }, 110, 0.52, "task-force")
end


-- 0.1.216 task reservation, platform step-walk, and release-safe debug defaults.
-- This pass prevents emergency task-force spam by remembering active and recently
-- completed assignments, then replaces fragile space-platform unit pathing with
-- tiny validated step movement.  Release builds should not emit lifecycle traces
-- unless explicitly toggled by command.
TECH_PRIESTS_LIFECYCLE_TRACE_ENABLED_0202 = false
TECH_PRIESTS_LIFECYCLE_FILE_ENABLED_0202 = false
TECH_PRIESTS_TASK_RESERVATION_TTL_0216 = 60 * 90
TECH_PRIESTS_TASK_RECENT_DONE_TTL_0216 = 60 * 25
TECH_PRIESTS_PLATFORM_STEP_TICKS_0216 = 10
TECH_PRIESTS_PLATFORM_STEP_DISTANCE_0216 = 0.22
TECH_PRIESTS_PLATFORM_STEP_MAX_FAILS_0216 = 5
TECH_PRIESTS_PLATFORM_STEP_TARGET_EPSILON_0216 = 0.26

function tech_priests_0216_tick()
  return game and game.tick or 0
end

function tech_priests_0216_station_key(pair)
  if pair and pair.station_unit then return pair.station_unit end
  if pair and pair.station and pair.station.valid then return pair.station.unit_number end
  return 0
end

function tech_priests_0216_assignment_signature(lead_pair, assistant_pair, item_name, role)
  return tostring(tech_priests_0216_station_key(lead_pair)) .. ":" .. tostring(tech_priests_0216_station_key(assistant_pair)) .. ":" .. tostring(role or "acquire") .. ":" .. tostring(item_name or "?")
end

function tech_priests_0216_job_signature(job)
  if not job then return nil end
  return tostring(job.lead_station_unit or 0) .. ":" .. tostring(job.assistant_station_unit or 0) .. ":" .. tostring(job.role or "acquire") .. ":" .. tostring(job.item_name or "?")
end

function tech_priests_0216_job_active(job)
  if not job then return false end
  local status = tostring(job.status or "assigned")
  if status == "complete" or status == "completed" or status == "delivered" or status == "failed" or status == "expired" or status == "cancelled" then return false end
  if job.timeout_tick and tech_priests_0216_tick() > job.timeout_tick then return false end
  return true
end

function tech_priests_0216_prune_recent_task_memory(pair)
  if not pair then return end
  local now = tech_priests_0216_tick()
  if pair.tech_priests_recent_tasks_0216 then
    for sig, until_tick in pairs(pair.tech_priests_recent_tasks_0216) do
      if now >= (until_tick or 0) then pair.tech_priests_recent_tasks_0216[sig] = nil end
    end
  end
  if pair.tech_priests_reserved_task_0216 and now >= (pair.tech_priests_reserved_task_0216.until_tick or 0) then
    pair.tech_priests_reserved_task_0216 = nil
  end
end

function tech_priests_0216_pair_has_active_or_recent_task(pair)
  if not pair then return false end
  tech_priests_0216_prune_recent_task_memory(pair)
  if pair.tech_priests_reserved_task_0216 and tech_priests_0216_tick() < (pair.tech_priests_reserved_task_0216.until_tick or 0) then return true end
  if pair.tech_priests_recent_tasks_0216 then
    for _, until_tick in pairs(pair.tech_priests_recent_tasks_0216) do
      if tech_priests_0216_tick() < (until_tick or 0) then return true end
    end
  end
  if pair.emergency_assist_job_0187 and tech_priests_0216_job_active(pair.emergency_assist_job_0187) then return true end
  if pair.emergency_assist_op_0187 and pair.emergency_assist_op_0187.enabled then return true end
  return false
end

function tech_priests_0216_remember_recent_task(pair, signature, ttl)
  if not (pair and signature) then return end
  pair.tech_priests_recent_tasks_0216 = pair.tech_priests_recent_tasks_0216 or {}
  pair.tech_priests_recent_tasks_0216[signature] = tech_priests_0216_tick() + (ttl or TECH_PRIESTS_TASK_RECENT_DONE_TTL_0216)
  if pair.tech_priests_reserved_task_0216 and pair.tech_priests_reserved_task_0216.signature == signature then pair.tech_priests_reserved_task_0216 = nil end
end

function tech_priests_0216_reserve_pair_task(lead_pair, assistant_pair, item_name, role)
  if not assistant_pair then return false end
  if tech_priests_0216_pair_has_active_or_recent_task(assistant_pair) then return false end
  local sig = tech_priests_0216_assignment_signature(lead_pair, assistant_pair, item_name, role)
  assistant_pair.tech_priests_reserved_task_0216 = {
    signature = sig,
    item_name = item_name,
    role = role,
    lead_station_unit = tech_priests_0216_station_key(lead_pair),
    assigned_tick = tech_priests_0216_tick(),
    until_tick = tech_priests_0216_tick() + TECH_PRIESTS_TASK_RESERVATION_TTL_0216
  }
  return true
end

-- A task-force op should not issue the same parent request repeatedly while older
-- child writs are still alive. This is the main fix for ore/plate/ore/plate writ spam.
function tech_priests_0216_op_has_active_parent_job(op, parent_item)
  if not (op and parent_item) then return false end
  local now = tech_priests_0216_tick()
  if op.task_force_jobs_0187 then
    for _, job in pairs(op.task_force_jobs_0187) do
      if job and tech_priests_0216_job_active(job) and (job.parent_item == parent_item or job.item_name == parent_item) then return true end
      if job and job.timeout_tick and now > job.timeout_tick then job.status = job.status or "expired" end
    end
  end
  return false
end

if tech_priests_pair_available_for_seniority_task_force_0188 then
  TECH_PRIESTS_ORIGINAL_PAIR_AVAILABLE_SENIORITY_0216 = tech_priests_pair_available_for_seniority_task_force_0188
  function tech_priests_pair_available_for_seniority_task_force_0188(pair)
    if tech_priests_0216_pair_has_active_or_recent_task(pair) then return false end
    return TECH_PRIESTS_ORIGINAL_PAIR_AVAILABLE_SENIORITY_0216(pair)
  end
end

if tech_priests_is_pair_available_for_task_force_0187 then
  TECH_PRIESTS_ORIGINAL_PAIR_AVAILABLE_TASK_FORCE_0216 = tech_priests_is_pair_available_for_task_force_0187
  function tech_priests_is_pair_available_for_task_force_0187(pair)
    if tech_priests_0216_pair_has_active_or_recent_task(pair) then return false end
    return TECH_PRIESTS_ORIGINAL_PAIR_AVAILABLE_TASK_FORCE_0216(pair)
  end
end

if tech_priests_assign_seniority_task_force_jobs_0188 then
  TECH_PRIESTS_ORIGINAL_ASSIGN_SENIORITY_TASKS_0216 = tech_priests_assign_seniority_task_force_jobs_0188
  function tech_priests_assign_seniority_task_force_jobs_0188(lead_pair, item_name, op, count, depth)
    if tech_priests_0216_op_has_active_parent_job(op, item_name) then return false end
    local before = {}
    if storage and storage.tech_priests and storage.tech_priests.pairs_by_station then
      for _, p in pairs(storage.tech_priests.pairs_by_station) do before[p] = p and p.tech_priests_reserved_task_0216 end
    end
    local ok = TECH_PRIESTS_ORIGINAL_ASSIGN_SENIORITY_TASKS_0216(lead_pair, item_name, op, count, depth)
    if ok and storage and storage.tech_priests and storage.tech_priests.pairs_by_station then
      for _, p in pairs(storage.tech_priests.pairs_by_station) do
        if p and p.emergency_assist_job_0187 and tech_priests_0216_job_active(p.emergency_assist_job_0187) then
          local job = p.emergency_assist_job_0187
          p.tech_priests_reserved_task_0216 = {
            signature = tech_priests_0216_job_signature(job),
            item_name = job.item_name,
            role = job.role,
            lead_station_unit = job.lead_station_unit,
            assigned_tick = job.assigned_tick or tech_priests_0216_tick(),
            until_tick = job.timeout_tick or (tech_priests_0216_tick() + TECH_PRIESTS_TASK_RESERVATION_TTL_0216)
          }
        end
      end
    end
    return ok
  end
end

if tech_priests_assign_task_force_jobs_0187 then
  TECH_PRIESTS_ORIGINAL_ASSIGN_TASKS_0216 = tech_priests_assign_task_force_jobs_0187
  function tech_priests_assign_task_force_jobs_0187(lead_pair, item_name, op, count, depth)
    if tech_priests_0216_op_has_active_parent_job(op, item_name) then return false end
    local ok = TECH_PRIESTS_ORIGINAL_ASSIGN_TASKS_0216(lead_pair, item_name, op, count, depth)
    if ok and storage and storage.tech_priests and storage.tech_priests.pairs_by_station then
      for _, p in pairs(storage.tech_priests.pairs_by_station) do
        if p and p.emergency_assist_job_0187 and tech_priests_0216_job_active(p.emergency_assist_job_0187) then
          local job = p.emergency_assist_job_0187
          p.tech_priests_reserved_task_0216 = {
            signature = tech_priests_0216_job_signature(job),
            item_name = job.item_name,
            role = job.role,
            lead_station_unit = job.lead_station_unit,
            assigned_tick = job.assigned_tick or tech_priests_0216_tick(),
            until_tick = job.timeout_tick or (tech_priests_0216_tick() + TECH_PRIESTS_TASK_RESERVATION_TTL_0216)
          }
        end
      end
    end
    return ok
  end
end

if tech_priests_service_task_force_assist_job_0187 then
  TECH_PRIESTS_ORIGINAL_SERVICE_ASSIST_JOB_0216 = tech_priests_service_task_force_assist_job_0187
  function tech_priests_service_task_force_assist_job_0187(pair)
    local before_job = pair and pair.emergency_assist_job_0187 or nil
    local before_sig = before_job and tech_priests_0216_job_signature(before_job) or (pair and pair.tech_priests_reserved_task_0216 and pair.tech_priests_reserved_task_0216.signature)
    local result = TECH_PRIESTS_ORIGINAL_SERVICE_ASSIST_JOB_0216(pair)
    local after_job = pair and pair.emergency_assist_job_0187 or nil
    if before_sig and (not after_job or not tech_priests_0216_job_active(after_job)) then
      tech_priests_0216_remember_recent_task(pair, before_sig, TECH_PRIESTS_TASK_RECENT_DONE_TTL_0216)
    end
    return result
  end
end

-- Step-walk platform movement. Space platform unit pathing continues to be fragile
-- around belts/void/collision seams.  We keep the exact spawn-locus safety but move
-- priests in tiny validated teleports, which behaves like walking without trusting
-- pathfinding into platform machinery.
function tech_priests_0216_platform_distance_sq(a, b)
  if not (a and b) then return 999999 end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end

function tech_priests_0216_platform_step_position(pair)
  if not (pair and pair.priest and pair.priest.valid and pair.space_platform_pathing_0209 and pair.space_platform_pathing_0209.active) then return nil end
  local priest = pair.priest
  local target = pair.space_platform_pathing_0209.target
  if not target then return nil end
  local dx = target.x - priest.position.x
  local dy = target.y - priest.position.y
  local dist = math.sqrt(dx * dx + dy * dy)
  if dist <= TECH_PRIESTS_PLATFORM_STEP_TARGET_EPSILON_0216 then return { x = target.x, y = target.y, arrived = true } end
  local step = math.min(TECH_PRIESTS_PLATFORM_STEP_DISTANCE_0216, dist)
  return { x = priest.position.x + dx / dist * step, y = priest.position.y + dy / dist * step }
end

-- Override direct platform movement again: create a guarded step-walk target and do
-- not ask the engine pathfinder to walk across belts/void. The stepper will move it.

-- Do not let old path guard logic veto step-walk movement. It only verifies that
-- the priest remains on foundation, in radius, and not standing on blocked machinery.
function tech_priests_platform_path_guard_0209(pair, reason)
  if not (pair and pair.priest and pair.priest.valid and pair.space_platform_pathing_0209 and pair.space_platform_pathing_0209.active) then return false end
  local priest = pair.priest
  if not (pair.station and pair.station.valid and priest.surface == pair.station.surface) then return false end
  if tech_priests_space_tile_is_foundation_0205 and not tech_priests_space_tile_is_foundation_0205(pair.station.surface, priest.position) then return false end
  if tech_priests_tile_has_bad_spawn_entity_0204 and tech_priests_tile_has_bad_spawn_entity_0204(pair.station.surface, priest.position) then return false end
  if tech_priests_platform_position_in_station_radius_0209 and not tech_priests_platform_position_in_station_radius_0209(pair, priest.position) then return false end
  pair.space_platform_pathing_0209.last_seen_tick = tech_priests_0216_tick()
  return true
end

function tech_priests_0216_platform_step_pair(pair)
  if not (pair and pair.priest and pair.priest.valid and pair.space_platform_pathing_0209 and pair.space_platform_pathing_0209.active) then return false end
  local path = pair.space_platform_pathing_0209
  if tech_priests_0216_tick() < (path.last_step_tick_0216 or 0) + TECH_PRIESTS_PLATFORM_STEP_TICKS_0216 then return true end
  path.last_step_tick_0216 = tech_priests_0216_tick()
  local priest = pair.priest
  if not tech_priests_platform_path_guard_0209(pair, "step precheck") then
    path.step_failures_0216 = (path.step_failures_0216 or 0) + 1
    if path.step_failures_0216 >= TECH_PRIESTS_PLATFORM_STEP_MAX_FAILS_0216 then
      local bad = path.target
      if bad and tech_priests_0214_blacklist_platform_walk_position then tech_priests_0214_blacklist_platform_walk_position(pair, bad, "step guard failed") end
      if tech_priests_platform_clear_path_0209 then tech_priests_platform_clear_path_0209(pair, "step guard failed") end
      if tech_priests_force_priest_to_platform_locus_0208 then tech_priests_force_priest_to_platform_locus_0208(pair, "step guard recovery") end
    end
    return false
  end
  local next_pos = tech_priests_0216_platform_step_position(pair)
  if not next_pos then return false end
  if next_pos.arrived then
    if tech_priests_platform_hover_translate_0430 then tech_priests_platform_hover_translate_0430(pair, { x = next_pos.x, y = next_pos.y }, "platform step arrived") else pcall(function() priest.teleport({ x = next_pos.x, y = next_pos.y }, priest.surface) end) end
    if tech_priests_platform_clear_path_0209 then tech_priests_platform_clear_path_0209(pair, "platform step arrived") else pair.space_platform_pathing_0209 = nil end
    return true
  end
  local safe = tech_priests_0215_platform_exact_safe_tile and tech_priests_0215_platform_exact_safe_tile(pair, next_pos) or nil
  if not safe then
    path.step_failures_0216 = (path.step_failures_0216 or 0) + 1
    if path.step_failures_0216 >= TECH_PRIESTS_PLATFORM_STEP_MAX_FAILS_0216 then
      if path.target and tech_priests_0214_blacklist_platform_walk_position then tech_priests_0214_blacklist_platform_walk_position(pair, path.target, "step blocked") end
      if tech_priests_platform_clear_path_0209 then tech_priests_platform_clear_path_0209(pair, "step blocked") else pair.space_platform_pathing_0209 = nil end
      if tech_priests_force_priest_to_platform_locus_0208 then tech_priests_force_priest_to_platform_locus_0208(pair, "step blocked recovery") end
    end
    return false
  end
  local ok = false
  if tech_priests_platform_hover_translate_0430 then ok = tech_priests_platform_hover_translate_0430(pair, { x = safe.x, y = safe.y }, "platform step safe tile") else ok = pcall(function() return priest.teleport({ x = safe.x, y = safe.y }, priest.surface) end) end
  if ok then
    path.step_failures_0216 = 0
    path.last_seen_tick = tech_priests_0216_tick()
    return true
  end
  path.step_failures_0216 = (path.step_failures_0216 or 0) + 1
  return false
end

TechPriestsRuntimeEventRegistry.on_nth_tick(TECH_PRIESTS_PLATFORM_STEP_TICKS_0216, function()
  if not (storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return end
  for _, pair in pairs(storage.tech_priests.pairs_by_station) do
    if tech_priests_platform_pair_0206 and tech_priests_platform_pair_0206(pair) and pair.priest and pair.priest.valid then
      if pair.space_platform_pathing_0209 and pair.space_platform_pathing_0209.active then
        tech_priests_0216_platform_step_pair(pair)
      end
    end
  end
end)

-- Clamp lifecycle buffer and default tracing again during runtime. The in-memory
-- debug ring stays tiny and file/current-log emission remains command-gated.
TECH_PRIESTS_LIFECYCLE_DEBUG_LIMIT_0202 = math.min(TECH_PRIESTS_LIFECYCLE_DEBUG_LIMIT_0202 or 240, 120)

-- 0.1.218 Identity and task-ownership cleanup pass.
-- Keep internal unit numbers for lookup/debug, but make player-facing doctrine use
-- the named Cogitator cell assigned from Factorio's supporter/backer names.
TECH_PRIESTS_TASK_RECENT_DONE_TTL_0218 = 60 * 45
TECH_PRIESTS_TASK_RESERVATION_TTL_0218 = 60 * 180
TECH_PRIESTS_GLOBAL_TASK_TIMEOUT_0218 = 60 * 240

TECH_PRIESTS_ORIGINAL_ENSURE_STORAGE_0218 = ensure_storage
function ensure_storage()
  if TECH_PRIESTS_ORIGINAL_ENSURE_STORAGE_0218 then TECH_PRIESTS_ORIGINAL_ENSURE_STORAGE_0218() end
  storage.tech_priests.active_writs_0218 = storage.tech_priests.active_writs_0218 or {}
  storage.tech_priests.active_writs_by_signature_0218 = storage.tech_priests.active_writs_by_signature_0218 or {}
  storage.tech_priests.recent_writs_by_signature_0218 = storage.tech_priests.recent_writs_by_signature_0218 or {}
end

function tech_priests_0218_now()
  return game and game.tick or 0
end

function tech_priests_0218_station_key(pair)
  if pair and pair.station_unit then return pair.station_unit end
  if pair and pair.station and pair.station.valid then return pair.station.unit_number end
  return 0
end

function tech_priests_0218_force_names(pair)
  if pair and apply_pair_display_names then pcall(function() apply_pair_display_names(pair) end) end
  return pair
end

function tech_priests_0218_cell_name(pair)
  tech_priests_0218_force_names(pair)
  if pair and pair.cell_name then return tostring(pair.cell_name) end
  return "Uncatalogued"
end

function tech_priests_0218_priest_name(pair)
  tech_priests_0218_force_names(pair)
  if pair and pair.priest_display_name then return tostring(pair.priest_display_name) end
  return "Tech-Priest " .. tech_priests_0218_cell_name(pair)
end

function tech_priests_0218_station_name(pair)
  tech_priests_0218_force_names(pair)
  if pair and pair.station_display_name then return tostring(pair.station_display_name) end
  return "Cogitator Station " .. tech_priests_0218_cell_name(pair)
end

TECH_PRIESTS_ORIGINAL_APPLY_PAIR_DISPLAY_NAMES_0218 = apply_pair_display_names
function apply_pair_display_names(pair)
  if TECH_PRIESTS_ORIGINAL_APPLY_PAIR_DISPLAY_NAMES_0218 then TECH_PRIESTS_ORIGINAL_APPLY_PAIR_DISPLAY_NAMES_0218(pair) end
  if not pair then return end
  pair.player_facing_priest_name_0218 = pair.priest_display_name or ("Tech-Priest " .. tostring(pair.cell_name or "Uncatalogued"))
  pair.player_facing_station_name_0218 = pair.station_display_name or ("Cogitator Station " .. tostring(pair.cell_name or "Uncatalogued"))
end

-- Replace overview name helpers with name-first versions. Unit numbers remain in
-- the internal row buttons/tags, but the player sees the priest/station name.
function tech_priests_pair_name_0189(pair)
  return tech_priests_0218_priest_name(pair)
end

function tech_priests_station_name_0189(pair)
  return tech_priests_0218_station_name(pair)
end

function tech_priests_0218_clean_signature_text(value)
  local text = tostring(value or "?")
  text = string.gsub(text, "%s+", " ")
  return text
end

function tech_priests_0218_make_signature(lead_pair, assistant_pair, item_name, role, parent_item)
  return table.concat({
    tostring(tech_priests_0218_station_key(lead_pair)),
    tostring(tech_priests_0218_station_key(assistant_pair)),
    tech_priests_0218_clean_signature_text(role or "acquire"),
    tech_priests_0218_clean_signature_text(parent_item or item_name or "?"),
    tech_priests_0218_clean_signature_text(item_name or "?")
  }, "|")
end

function tech_priests_0218_prune_global_writs()
  ensure_storage()
  local now = tech_priests_0218_now()
  for id, writ in pairs(storage.tech_priests.active_writs_0218 or {}) do
    if not writ or now >= (writ.expires_tick or 0) or writ.status == "complete" or writ.status == "failed" or writ.status == "expired" or writ.status == "cancelled" then
      local sig = writ and writ.signature
      if sig then
        storage.tech_priests.active_writs_by_signature_0218[sig] = nil
        storage.tech_priests.recent_writs_by_signature_0218[sig] = now + TECH_PRIESTS_TASK_RECENT_DONE_TTL_0218
      end
      storage.tech_priests.active_writs_0218[id] = nil
    end
  end
  for sig, until_tick in pairs(storage.tech_priests.recent_writs_by_signature_0218 or {}) do
    if now >= (until_tick or 0) then storage.tech_priests.recent_writs_by_signature_0218[sig] = nil end
  end
end

function tech_priests_0218_signature_is_busy(signature)
  if not signature then return false end
  tech_priests_0218_prune_global_writs()
  if storage.tech_priests.active_writs_by_signature_0218[signature] then return true end
  local recent_until = storage.tech_priests.recent_writs_by_signature_0218[signature]
  if recent_until and tech_priests_0218_now() < recent_until then return true end
  return false
end

function tech_priests_0218_register_writ(lead_pair, assistant_pair, job, role)
  if not (job and job.id) then return nil end
  ensure_storage()
  local signature = tech_priests_0218_make_signature(lead_pair, assistant_pair, job.item_name, role or job.role, job.parent_item)
  local writ = {
    id = job.id,
    signature = signature,
    item_name = job.item_name,
    parent_item = job.parent_item,
    role = role or job.role or "acquire",
    lead_station_unit = tech_priests_0218_station_key(lead_pair),
    assistant_station_unit = tech_priests_0218_station_key(assistant_pair),
    lead_name = tech_priests_0218_station_name(lead_pair),
    assistant_name = tech_priests_0218_priest_name(assistant_pair),
    assigned_tick = job.assigned_tick or tech_priests_0218_now(),
    expires_tick = job.timeout_tick or (tech_priests_0218_now() + TECH_PRIESTS_GLOBAL_TASK_TIMEOUT_0218),
    status = job.status or "assigned"
  }
  job.signature_0218 = signature
  job.lead_name_0218 = writ.lead_name
  job.assistant_name_0218 = writ.assistant_name
  storage.tech_priests.active_writs_0218[job.id] = writ
  storage.tech_priests.active_writs_by_signature_0218[signature] = job.id
  if assistant_pair then
    assistant_pair.current_task_id = job.id
    assistant_pair.current_task_type = writ.role
    assistant_pair.current_task_owner_station = writ.lead_station_unit
    assistant_pair.current_task_started_tick = writ.assigned_tick
    assistant_pair.current_task_expires_tick = writ.expires_tick
    assistant_pair.current_task_signature_0218 = signature
    assistant_pair.current_task_summary_0218 = "Writ " .. tostring(job.id) .. " · " .. tech_priests_item_tag_0189(job.item_name) .. tostring(job.item_name or "?")
  end
  return writ
end

function tech_priests_0218_complete_writ(pair, job, status)
  if not job then return end
  ensure_storage()
  local sig = job.signature_0218 or (pair and pair.current_task_signature_0218)
  if job.id then storage.tech_priests.active_writs_0218[job.id] = nil end
  if sig then
    storage.tech_priests.active_writs_by_signature_0218[sig] = nil
    storage.tech_priests.recent_writs_by_signature_0218[sig] = tech_priests_0218_now() + TECH_PRIESTS_TASK_RECENT_DONE_TTL_0218
  end
  if pair then
    pair.last_completed_task_id = job.id or pair.current_task_id
    pair.last_completed_task_tick = tech_priests_0218_now()
    pair.last_completed_task_status_0218 = status or "complete"
    pair.current_task_id = nil
    pair.current_task_type = nil
    pair.current_task_owner_station = nil
    pair.current_task_started_tick = nil
    pair.current_task_expires_tick = nil
    pair.current_task_signature_0218 = nil
    pair.current_task_summary_0218 = nil
  end
end

-- Prefix floating task-force snippets with the named priest/cell, not an opaque
-- unit number. Keep the prefix compact to avoid recreating the text-overlap mess.
if tech_priests_task_force_snippet_0187 then
  TECH_PRIESTS_ORIGINAL_TASK_FORCE_SNIPPET_0218 = tech_priests_task_force_snippet_0187
  function tech_priests_task_force_snippet_0187(pair, text)
    local prefix = tech_priests_0218_cell_name(pair)
    local clean = tostring(text or "")
    if prefix and prefix ~= "" and not string.find(clean, prefix, 1, true) then
      clean = "[" .. prefix .. "] " .. clean
    end
    return TECH_PRIESTS_ORIGINAL_TASK_FORCE_SNIPPET_0218(pair, clean)
  end
end

-- Make seniority job descriptions readable by using the assigned priest and lead
-- shrine names in the phrase itself.
if tech_priests_seniority_job_phrase_0188 then
  TECH_PRIESTS_ORIGINAL_SENIORITY_JOB_PHRASE_0218 = tech_priests_seniority_job_phrase_0188
  function tech_priests_seniority_job_phrase_0188(role, lead_pair, assistant_pair, item_name, job_id)
    local assistant = tech_priests_0218_priest_name(assistant_pair)
    local lead = tech_priests_0218_station_name(lead_pair)
    local item = "[item=" .. tostring(item_name) .. "]"
    if role == "raw-resource" then
      return item .. " Writ " .. tostring(job_id) .. ": " .. assistant .. " assigned to raw acquisition for " .. lead .. "."
    elseif role == "construction" then
      return item .. " Writ " .. tostring(job_id) .. ": " .. assistant .. " assigned construction support for " .. lead .. "."
    end
    return item .. " Writ " .. tostring(job_id) .. ": " .. assistant .. " assigned component acquisition for " .. lead .. "."
  end
end

-- Before issuing new writs, scan current jobs and refuse duplicate active/recent
-- signatures. After assignment, stamp any new jobs with global ownership records.
if tech_priests_assign_seniority_task_force_jobs_0188 then
  TECH_PRIESTS_ORIGINAL_ASSIGN_SENIORITY_TASKS_0218 = tech_priests_assign_seniority_task_force_jobs_0188
  function tech_priests_assign_seniority_task_force_jobs_0188(lead_pair, item_name, op, count, depth)
    if op and item_name then
      local parent_sig = tech_priests_0218_make_signature(lead_pair, nil, item_name, "parent", item_name)
      if tech_priests_0218_signature_is_busy(parent_sig) then return false end
      storage.tech_priests.active_writs_by_signature_0218[parent_sig] = "parent:" .. tostring(tech_priests_0218_station_key(lead_pair)) .. ":" .. tostring(item_name)
      storage.tech_priests.active_writs_0218[storage.tech_priests.active_writs_by_signature_0218[parent_sig]] = {
        id = storage.tech_priests.active_writs_by_signature_0218[parent_sig],
        signature = parent_sig,
        item_name = item_name,
        role = "parent",
        lead_station_unit = tech_priests_0218_station_key(lead_pair),
        lead_name = tech_priests_0218_station_name(lead_pair),
        assigned_tick = tech_priests_0218_now(),
        expires_tick = tech_priests_0218_now() + TECH_PRIESTS_TASK_RESERVATION_TTL_0218,
        status = "planning"
      }
    end
    local ok = TECH_PRIESTS_ORIGINAL_ASSIGN_SENIORITY_TASKS_0218(lead_pair, item_name, op, count, depth)
    if ok and op and op.task_force_jobs_0187 then
      for _, job in pairs(op.task_force_jobs_0187) do
        if job and job.id and job.assistant_station_unit and not job.signature_0218 then
          local assistant_pair = storage.tech_priests.pairs_by_station[job.assistant_station_unit]
          tech_priests_0218_register_writ(lead_pair, assistant_pair, job, job.role)
        end
      end
    end
    return ok
  end
end

if tech_priests_assign_task_force_jobs_0187 then
  TECH_PRIESTS_ORIGINAL_ASSIGN_TASKS_0218 = tech_priests_assign_task_force_jobs_0187
  function tech_priests_assign_task_force_jobs_0187(lead_pair, item_name, op, count, depth)
    if op and item_name then
      local parent_sig = tech_priests_0218_make_signature(lead_pair, nil, item_name, "parent", item_name)
      if tech_priests_0218_signature_is_busy(parent_sig) then return false end
    end
    local ok = TECH_PRIESTS_ORIGINAL_ASSIGN_TASKS_0218(lead_pair, item_name, op, count, depth)
    if ok and op and op.task_force_jobs_0187 then
      for _, job in pairs(op.task_force_jobs_0187) do
        if job and job.id and job.assistant_station_unit and not job.signature_0218 then
          local assistant_pair = storage.tech_priests.pairs_by_station[job.assistant_station_unit]
          tech_priests_0218_register_writ(lead_pair, assistant_pair, job, job.role)
        end
      end
    end
    return ok
  end
end

if tech_priests_service_task_force_assist_job_0187 then
  TECH_PRIESTS_ORIGINAL_SERVICE_ASSIST_JOB_0218 = tech_priests_service_task_force_assist_job_0187
  function tech_priests_service_task_force_assist_job_0187(pair)
    local before_job = pair and pair.emergency_assist_job_0187 or nil
    local before_id = before_job and before_job.id
    local result = TECH_PRIESTS_ORIGINAL_SERVICE_ASSIST_JOB_0218(pair)
    local after_job = pair and pair.emergency_assist_job_0187 or nil
    if before_job and before_id and (not after_job or after_job.id ~= before_id) then
      tech_priests_0218_complete_writ(pair, before_job, "ended")
    end
    return result
  end
end

-- Improve overview task text with named task ownership fields when available.
if tech_priests_task_summary_0189 then
  TECH_PRIESTS_ORIGINAL_TASK_SUMMARY_0218 = tech_priests_task_summary_0189
  function tech_priests_task_summary_0189(pair)
    if pair and pair.current_task_summary_0218 then return tostring(pair.current_task_summary_0218) end
    if pair and pair.current_task_id then return "Writ " .. tostring(pair.current_task_id) end
    return TECH_PRIESTS_ORIGINAL_TASK_SUMMARY_0218(pair)
  end
end

TechPriestsRuntimeEventRegistry.on_nth_tick(60 * 30, function()
  if storage and storage.tech_priests then tech_priests_0218_prune_global_writs() end
end)


-- 0.1.219 Space-platform zero-G maneuvering pack movement.
-- Platform priests have proven too fragile when routed through Factorio ground
-- pathing/collision rules.  In space-platform doctrine they now "fly" directly
-- toward their target in short scripted increments.  This intentionally ignores
-- terrain occlusion and local obstructions; the fiction is that their void-duty
-- maneuvering packs let them translate over belts, pipes, machines, and gaps.
-- Safety remains limited to same-surface, station-radius, and final recovery to
-- the visible spawn locus if a teleport is rejected by the engine.
TECH_PRIESTS_PLATFORM_ZERO_G_STEP_DISTANCE_0219 = 0.45
TECH_PRIESTS_PLATFORM_ZERO_G_STEP_TICKS_0219 = 8
TECH_PRIESTS_PLATFORM_ZERO_G_EPSILON_0219 = 0.18
TECH_PRIESTS_PLATFORM_ZERO_G_TIMEOUT_0219 = 60 * 20

function tech_priests_0219_tick()
  return (game and game.tick) or 0
end

function tech_priests_0219_distance_sq(a, b)
  if not (a and b) then return 999999 end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end

function tech_priests_0219_in_station_radius(pair, pos)
  if not (pair and pair.station and pair.station.valid and pos) then return false end
  if tech_priests_platform_position_in_station_radius_0209 then
    local ok, result = pcall(function() return tech_priests_platform_position_in_station_radius_0209(pair, pos) end)
    if ok then return result and true or false end
  end
  local dx = (pair.station.position.x or 0) - (pos.x or 0)
  local dy = (pair.station.position.y or 0) - (pos.y or 0)
  local r = pair.operation_radius or pair.radius or 32
  return (dx * dx + dy * dy) <= (r * r)
end

-- TECH-PRIESTS 0.1.431: removed superseded duplicate function tech_priests_0219_platform_maneuver_target (old lines 17350-17380); next definition begins at old line 17521. No intervening capture/registration/reference was detected by tools/audit_control_deletion_candidates.py.

-- Replace the previous platform walking implementation.  Ground/Nauvis priests keep
-- the older movement functions; only platform pairs are routed through this shim.

-- TECH-PRIESTS 0.1.431: removed superseded duplicate function tech_priests_platform_path_guard_0209 (old lines 17386-17395); next definition begins at old line 17525. No intervening capture/registration/reference was detected by tools/audit_control_deletion_candidates.py.

function tech_priests_0219_next_zero_g_position(pair)
  if not (pair and pair.priest and pair.priest.valid and pair.space_platform_pathing_0209 and pair.space_platform_pathing_0209.active) then return nil end
  local priest = pair.priest
  local target = pair.space_platform_pathing_0209.target
  if not target then return nil end
  local dx = target.x - priest.position.x
  local dy = target.y - priest.position.y
  local dist = math.sqrt(dx * dx + dy * dy)
  if dist <= TECH_PRIESTS_PLATFORM_ZERO_G_EPSILON_0219 then return { x = target.x, y = target.y, arrived = true } end
  local step = math.min(TECH_PRIESTS_PLATFORM_ZERO_G_STEP_DISTANCE_0219, dist)
  return { x = priest.position.x + dx / dist * step, y = priest.position.y + dy / dist * step }
end



-- 0.1.220 Space-platform hover-glide movement.
-- The 0.1.219 zero-G maneuver tried to move platform priests by discrete
-- teleport hops, but the older platform safety layers could still snap them
-- back to the locus. This revision stops pretending they are walking at all.
-- On space platforms, priests are fictionally using low-power maneuvering
-- thrusters: they face their destination, glide in tiny increments, ignore
-- belts/pipes/machines/local collision, and leave small puffs of smoke. The
-- only hard constraints are same-surface and station-radius containment.
TECH_PRIESTS_PLATFORM_HOVER_STEP_DISTANCE_0220 = 0.075
TECH_PRIESTS_PLATFORM_HOVER_STEP_TICKS_0220 = 2
TECH_PRIESTS_PLATFORM_HOVER_EPSILON_0220 = 0.16
TECH_PRIESTS_PLATFORM_HOVER_TIMEOUT_0220 = 60 * 30
TECH_PRIESTS_PLATFORM_HOVER_SMOKE_TICKS_0220 = 14

function tech_priests_0220_tick()
  return (game and game.tick) or 0
end

function tech_priests_0220_dist_sq(a, b)
  if not (a and b) then return 999999 end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end

function tech_priests_0220_in_radius(pair, pos)
  if not (pair and pair.station and pair.station.valid and pos) then return false end
  local dx = (pair.station.position.x or 0) - (pos.x or 0)
  local dy = (pair.station.position.y or 0) - (pos.y or 0)
  local r = pair.operation_radius or pair.radius or 32
  return (dx * dx + dy * dy) <= (r * r)
end

function tech_priests_0220_clamp_to_radius(pair, pos)
  if not (pair and pair.station and pair.station.valid and pos) then return nil end
  local sx = pair.station.position.x or 0
  local sy = pair.station.position.y or 0
  local r = (pair.operation_radius or pair.radius or 32) - 0.75
  local dx = (pos.x or sx) - sx
  local dy = (pos.y or sy) - sy
  local d = math.sqrt(dx * dx + dy * dy)
  if d <= r then return { x = pos.x, y = pos.y } end
  if d <= 0.001 then return { x = sx, y = sy } end
  return { x = sx + dx / d * r, y = sy + dy / d * r }
end

function tech_priests_0220_face_direction(priest, dx, dy)
  if not (priest and priest.valid) then return end
  local dir = nil
  if math.abs(dx or 0) > math.abs(dy or 0) then
    dir = (dx or 0) >= 0 and defines.direction.east or defines.direction.west
  else
    dir = (dy or 0) >= 0 and defines.direction.south or defines.direction.north
  end
  pcall(function() priest.direction = dir end)
end

function tech_priests_0220_emit_thruster_puff(pair, from_pos, dx, dy)
  if not (pair and pair.priest and pair.priest.valid and from_pos and pair.priest.surface) then return end
  local path = pair.space_platform_pathing_0209 or {}
  local now = tech_priests_0220_tick()
  if now < (path.last_hover_smoke_tick_0220 or 0) + TECH_PRIESTS_PLATFORM_HOVER_SMOKE_TICKS_0220 then return end
  path.last_hover_smoke_tick_0220 = now
  pair.space_platform_pathing_0209 = path
  local d = math.sqrt((dx or 0) * (dx or 0) + (dy or 0) * (dy or 0))
  local bx, by = 0, 0
  if d > 0.001 then bx, by = -(dx or 0) / d * 0.18, -(dy or 0) / d * 0.18 end
  local p = { x = from_pos.x + bx, y = from_pos.y + by }
  local surface = pair.priest.surface
  pcall(function() surface.create_trivial_smoke({ name = "smoke-fast", position = p }) end)
  pcall(function() surface.create_entity({ name = "smoke-fast", position = p }) end)
end

function tech_priests_0220_begin_hover_glide(pair, destination, reason)
  if not (pair and pair.priest and pair.priest.valid and pair.station and pair.station.valid and destination) then return false end
  if not (tech_priests_pair_on_space_platform_0204 and tech_priests_pair_on_space_platform_0204(pair)) then return false end
  if pair.priest.surface ~= pair.station.surface then return false end
  local target = tech_priests_0220_clamp_to_radius(pair, { x = destination.x, y = destination.y })
  if not target then return false end
  pair.space_platform_pathing_0209 = {
    active = true,
    target = target,
    started_tick = tech_priests_0220_tick(),
    last_seen_tick = tech_priests_0220_tick(),
    last_hover_step_tick_0220 = 0,
    last_hover_smoke_tick_0220 = 0,
    reason = tostring(reason or "void-duty hover-glide"),
    hover_glide_0220 = true,
    zero_g_maneuver_0219 = false,
    step_walk_0216 = false,
    allow_obstruction_bypass_0220 = true
  }
  pair.space_platform_tether_0206 = pair.space_platform_tether_0206 or {}
  pair.space_platform_tether_0206.allow_pathing = true
  pair.mode = "space-platform-doctrine"
  pair.task_summary = "Space platform doctrine · maneuvering thrusters"
  pcall(function() pair.priest.active = false end)
  pcall(function() pair.priest.destructible = false end)
  if pair.priest.commandable then pcall(function() pair.priest.commandable.set_command({ type = defines.command.stop }) end) end
  if tech_priests_lifecycle_note_0201 then tech_priests_lifecycle_note_0201(pair, "hover-glide target set", pair.priest, tostring(target.x) .. "," .. tostring(target.y)) end
  return true
end

-- Replace all previous platform walking shims with hover-glide target setup.
function tech_priests_0215_direct_command_platform_walk(pair, destination, reason)
  return tech_priests_0220_begin_hover_glide(pair, destination, reason or "void-duty maneuvering thrusters")
end
