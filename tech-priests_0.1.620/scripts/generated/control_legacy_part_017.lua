-- Auto-split control.lua fragment 017 for Tech Priests 0.1.438.
-- Generated mechanically from 0.1.437 monolithic control.lua.
-- Purpose: reduce Lua main-chunk local/register pressure without deleting behavior.


function tech_priests_radar_angle_0278(from, to)
  local dy = to.y - from.y
  local dx = to.x - from.x
  local angle = nil
  if math.atan2 then
    angle = math.atan2(dy, dx)
  else
    angle = math.atan(dy, dx)
  end
  if angle < 0 then angle = angle + (math.pi * 2) end
  return angle
end

function tech_priests_radar_angle_delta_0278(a, b)
  local delta = math.abs(a - b) % (math.pi * 2)
  if delta > math.pi then delta = (math.pi * 2) - delta end
  return delta
end

function tech_priests_radar_distance_sq_0278(a, b)
  local dx = a.x - b.x
  local dy = a.y - b.y
  return dx * dx + dy * dy
end

function tech_priests_radar_position_key_0278(entity)
  if not (entity and entity.valid and entity.position) then return nil end
  return tostring(entity.name) .. ":" .. tostring(math.floor(entity.position.x * 10)) .. ":" .. tostring(math.floor(entity.position.y * 10))
end

function tech_priests_radar_entity_key_0278(entity)
  if not (entity and entity.valid) then return nil end
  return entity.unit_number or tech_priests_radar_position_key_0278(entity)
end

function tech_priests_radar_is_rock_0278(entity)
  if not (entity and entity.valid and entity.name) then return false end
  local name = entity.name
  return name == "rock-big" or name == "rock-huge" or name == "sand-rock-big" or string.find(name, "rock", 1, true) ~= nil
end

function tech_priests_radar_is_resource_candidate_0278(entity)
  if not (entity and entity.valid) then return false end
  if entity.type == "resource" or entity.type == "tree" then return true end
  if entity.type == "simple-entity" and tech_priests_radar_is_rock_0278(entity) then return true end
  return false
end

function tech_priests_radar_classify_entity_0278(pair, entity)
  if not (pair and pair.station and pair.station.valid and entity and entity.valid) then return nil end
  local station = pair.station
  local priest = pair.priest

  if priest and priest.valid and entity == priest then
    return { kind = "priest", phase = "task-refresh", sprite = "entity/" .. entity.name, priority = 90 }
  end

  if entity.force and station.force and entity.force.valid and station.force.valid and entity.force ~= station.force then
    local is_friend = false
    if entity.force.get_friend then
      local ok_friend, friend_result = pcall(function() return entity.force.get_friend(station.force) end)
      is_friend = ok_friend and friend_result or false
    end
    if not is_friend then
      return { kind = "combat", phase = "target-detected", sprite = "entity/" .. entity.name, priority = 100 }
    end
  end

  if entity.health and entity.max_health and entity.health > 0 and entity.health < entity.max_health then
    return { kind = "repair", phase = "maintenance-needed", sprite = "entity/" .. entity.name, priority = 80 }
  end

  if is_consecration_target and get_consecration_record and is_consecration_target(entity) then
    local record = get_consecration_record(entity)
    if record then
      local current = record.sanctification or 0
      local maximum = record.max_sanctification or (get_base_sanctification_max and get_base_sanctification_max(entity.force)) or 100
      if current < maximum then
        return { kind = "consecration", phase = "sanctification-needed", sprite = "entity/" .. entity.name, priority = 70 }
      end
    end
  end

  if tech_priests_radar_is_resource_candidate_0278(entity) then
    return { kind = "resource", phase = "gatherable-detected", sprite = "entity/" .. entity.name, priority = 40 }
  end

  return nil
end

function tech_priests_radar_try_draw_sprite_0278(args, sprite)
  args.sprite = sprite
  local ok, object = pcall(function() return rendering.draw_sprite(args) end)
  if ok and object then return object end
  return nil
end

function tech_priests_radar_flash_entity_icon_0278(player, entity, info)
  if not (player and player.valid and entity and entity.valid and info) then return nil end
  local args = {
    sprite = info.sprite or ("entity/" .. entity.name),
    target = { entity = entity, offset = { 0, -1.15 } },
    surface = entity.surface,
    x_scale = 0.55,
    y_scale = 0.55,
    tint = { r = 1.0, g = 0.84, b = 0.28, a = 0.92 },
    players = { player },
    time_to_live = TECH_PRIESTS_RADAR_FLASH_TTL_0278,
    render_layer = "air-object"
  }

  local object = tech_priests_radar_try_draw_sprite_0278(args, info.sprite or ("entity/" .. entity.name))
  if not object then object = tech_priests_radar_try_draw_sprite_0278(args, "item/" .. entity.name) end
  if not object then object = tech_priests_radar_try_draw_sprite_0278(args, "virtual-signal/signal-info") end

  local text = nil
  local label = nil
  if info.kind == "combat" then label = "!"
  elseif info.kind == "repair" then label = "+"
  elseif info.kind == "consecration" then label = "✠"
  elseif info.kind == "resource" then label = "◇"
  elseif info.kind == "priest" then label = "↻"
  end

  if label then
    local ok_text, drawn_text = pcall(function()
      return rendering.draw_text({
        text = label,
        target = { entity = entity, offset = { 0.42, -1.25 } },
        surface = entity.surface,
        color = { r = 1.0, g = 0.82, b = 0.20, a = 0.98 },
        scale = 0.85,
        alignment = "center",
        players = { player },
        time_to_live = TECH_PRIESTS_RADAR_FLASH_TTL_0278
      })
    end)
    if ok_text then text = drawn_text end
  end

  return { flash = object, text = text }
end

function tech_priests_radar_build_candidate_cache_0278(pair)
  if not (pair and pair.station and pair.station.valid) then return nil end
  local station = pair.station
  local radius = pair.radius or (refresh_pair_radius and refresh_pair_radius(pair)) or (get_station_operating_radius and get_station_operating_radius(station)) or 30
  local pos = station.position
  local area = { { pos.x - radius, pos.y - radius }, { pos.x + radius, pos.y + radius } }
  local candidates = {}
  local ok, entities = pcall(function() return station.surface.find_entities_filtered({ area = area }) end)
  if ok and entities then
    for _, entity in pairs(entities) do
      if entity and entity.valid and entity ~= station then
        local dist_sq = tech_priests_radar_distance_sq_0278(pos, entity.position)
        if dist_sq <= radius * radius then
          candidates[#candidates + 1] = entity
          if #candidates >= TECH_PRIESTS_RADAR_MAX_CANDIDATES_0278 then break end
        end
      end
    end
  end
  return {
    candidates = candidates,
    radius = radius,
    built_tick = game and game.tick or 0
  }
end

function tech_priests_radar_get_cache_0278(pair)
  if not (pair and pair.station and pair.station.valid and pair.station.unit_number) then return nil end
  local radar = tech_priests_radar_ensure_storage_0278()
  local station_unit = pair.station.unit_number
  local cache = radar.station_cache[station_unit]
  if not cache or game.tick >= (cache.next_refresh_tick or 0) then
    cache = tech_priests_radar_build_candidate_cache_0278(pair) or { candidates = {}, radius = pair.radius or 30 }
    cache.known = cache.known or {}
    cache.known_by_kind = cache.known_by_kind or {}
    cache.next_refresh_tick = game.tick + TECH_PRIESTS_RADAR_CANDIDATE_REFRESH_TICKS_0278
    radar.station_cache[station_unit] = cache
  end
  pair.radar = pair.radar or {}
  pair.radar.known = cache.known
  pair.radar.known_by_kind = cache.known_by_kind
  pair.radar.last_cache_tick = cache.built_tick
  return cache
end

function tech_priests_radar_remember_detection_0278(pair, entity, info)
  if not (pair and entity and entity.valid and info) then return end
  local cache = tech_priests_radar_get_cache_0278(pair)
  if not cache then return end
  cache.known = cache.known or {}
  cache.known_by_kind = cache.known_by_kind or {}
  local key = tech_priests_radar_entity_key_0278(entity)
  if not key then return end
  local record = {
    entity = entity,
    kind = info.kind,
    phase = info.phase,
    tick = game.tick,
    health = entity.health,
    max_health = entity.max_health,
    name = entity.name,
    position = { x = entity.position.x, y = entity.position.y }
  }
  cache.known[key] = record
  cache.known_by_kind[info.kind] = cache.known_by_kind[info.kind] or {}
  cache.known_by_kind[info.kind][key] = record
  pair.radar = pair.radar or {}
  pair.radar.last_detection_tick = game.tick
  pair.radar.last_detection_kind = info.kind
  pair.radar.last_detection_name = entity.name
end

function tech_priests_radar_entity_inside_station_0278(pair, entity)
  if not (pair and pair.station and pair.station.valid and entity and entity.valid) then return false end
  local radius = pair.radius or (refresh_pair_radius and refresh_pair_radius(pair)) or (get_station_operating_radius and get_station_operating_radius(pair.station)) or 30
  return tech_priests_radar_distance_sq_0278(pair.station.position, entity.position) <= radius * radius
end

function tech_priests_radar_target_still_valid_for_kind_0278(pair, target, kind)
  if not (target and target.valid) then return false end
  if not tech_priests_radar_entity_inside_station_0278(pair, target) then return false end
  if kind == "combat" then
    if not (pair.station and pair.station.valid and target.force and pair.station.force and target.force ~= pair.station.force) then return false end
    if target.health and target.health <= 0 then return false end
    return true
  elseif kind == "repair" then
    return target.health and target.max_health and target.health > 0 and target.health < target.max_health
  elseif kind == "consecration" then
    if not (is_consecration_target and get_consecration_record and is_consecration_target(target)) then return false end
    local record = get_consecration_record(target)
    if not record then return false end
    local current = record.sanctification or 0
    local maximum = record.max_sanctification or (get_base_sanctification_max and get_base_sanctification_max(target.force)) or 100
    return current < maximum
  elseif kind == "resource" then
    return tech_priests_radar_is_resource_candidate_0278(target)
  end
  return true
end

function tech_priests_radar_clear_invalid_task_0278(pair, reason)
  if not pair then return end
  pair.target = nil
  pair.scavenge = nil
  pair.cram = nil
  pair.inventory_scan = nil
  pair.next_scavenge_search_tick = nil
  if tech_priests_0277_clear_task then
    tech_priests_0277_clear_task(pair, reason)
  elseif tech_priests_clear_pair_task_0276 then
    tech_priests_clear_pair_task_0276(pair, reason)
  else
    pair.task_kind = nil
    pair.task_phase = nil
    pair.task_target = nil
    pair.visual_state = nil
  end
  pair.mode = "radar-task-reset"
  pair.last_radar_task_reset_reason_0278 = reason
  pair.last_radar_task_reset_tick_0278 = game and game.tick or 0
end

function tech_priests_radar_validate_priest_task_0278(pair)
  if not (pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid) then return false end

  if pair.target and (not tech_priests_radar_target_still_valid_for_kind_0278(pair, pair.target, pair.task_kind or pair.last_scheduler_priority_0277 or pair.mode)) then
    tech_priests_radar_clear_invalid_task_0278(pair, "radar-target-invalid")
    return true
  end

  if pair.scavenge and pair.scavenge.source and (not pair.scavenge.source.valid or not tech_priests_radar_entity_inside_station_0278(pair, pair.scavenge.source)) then
    tech_priests_radar_clear_invalid_task_0278(pair, "radar-scavenge-source-invalid")
    return true
  end

  if pair.cram and pair.cram.destination and (not pair.cram.destination.valid or not tech_priests_radar_entity_inside_station_0278(pair, pair.cram.destination)) then
    tech_priests_radar_clear_invalid_task_0278(pair, "radar-cram-destination-invalid")
    return true
  end

  if tech_priests_0277_scheduler_tick then
    -- Let the explicit scheduler immediately re-claim combat/repair/sanctify if
    -- the refreshed radar picture says the old assignment is gone or complete.
    tech_priests_0277_scheduler_tick(pair)
  end

  pair.last_radar_priest_refresh_tick_0278 = game.tick
  return true
end

function tech_priests_radar_process_sweep_hits_0278(player, pair, angle)
  local cache = tech_priests_radar_get_cache_0278(pair)
  if not cache then return end
  local station = pair.station
  local station_pos = station.position
  local flashed = 0

  for index = #cache.candidates, 1, -1 do
    local entity = cache.candidates[index]
    if not (entity and entity.valid) then
      table.remove(cache.candidates, index)
    else
      local entity_angle = tech_priests_radar_angle_0278(station_pos, entity.position)
      if tech_priests_radar_angle_delta_0278(angle, entity_angle) <= TECH_PRIESTS_RADAR_SWEEP_HALF_WIDTH_RADIANS_0278 then
        local info = tech_priests_radar_classify_entity_0278(pair, entity)
        if info then
          tech_priests_radar_remember_detection_0278(pair, entity, info)
          if info.kind == "priest" then
            tech_priests_radar_validate_priest_task_0278(pair)
          end
          if flashed < TECH_PRIESTS_RADAR_MAX_FLASHES_PER_STEP_0278 then
            tech_priests_radar_flash_entity_icon_0278(player, entity, info)
            flashed = flashed + 1
          end
        end
      end
    end
  end
end

function tech_priests_radar_draw_sweep_0278(player, pair, angle)
  if not (player and player.valid and pair and pair.station and pair.station.valid) then return end
  local radar = tech_priests_radar_ensure_storage_0278()
  local station = pair.station
  local radius = pair.radius or (refresh_pair_radius and refresh_pair_radius(pair)) or (get_station_operating_radius and get_station_operating_radius(station)) or 30
  local center = station.position
  local edge = { x = center.x + math.cos(angle) * radius, y = center.y + math.sin(angle) * radius }

  local player_state = radar.players[player.index] or {}
  if player_state.line then tech_priests_radar_destroy_object_0278(player_state.line) end
  if player_state.endcap then tech_priests_radar_destroy_object_0278(player_state.endcap) end

  local ok_line, line = pcall(function()
    return rendering.draw_line({
      color = { r = 1.0, g = 0.62, b = 0.08, a = 0.78 },
      width = 3,
      from = { entity = station, offset = { 0, -0.18 } },
      to = edge,
      surface = station.surface,
      players = { player },
      time_to_live = TECH_PRIESTS_RADAR_LINE_TTL_0278
    })
  end)

  local ok_cap, cap = pcall(function()
    return rendering.draw_circle({
      color = { r = 1.0, g = 0.82, b = 0.22, a = 0.70 },
      radius = 0.18,
      filled = true,
      target = edge,
      surface = station.surface,
      players = { player },
      time_to_live = TECH_PRIESTS_RADAR_LINE_TTL_0278
    })
  end)

  player_state.line = ok_line and line or nil
  player_state.endcap = ok_cap and cap or nil
  player_state.station_unit = station.unit_number
  player_state.last_tick = game.tick
  radar.players[player.index] = player_state
end

function tech_priests_radar_update_player_0278(player)
  local radar = tech_priests_radar_ensure_storage_0278()
  local pair = tech_priests_radar_get_hover_pair_0278(player)
  if not pair then
    local old = radar.players[player.index]
    if old then
      tech_priests_radar_destroy_objects_0278(old)
      radar.players[player.index] = nil
    end
    return
  end

  if refresh_pair_radius then pair.radius = refresh_pair_radius(pair) or pair.radius end
  if ensure_pair_priest then ensure_pair_priest(pair, false, true) end

  local station_unit = pair.station.unit_number or 0
  local sweep_ticks = tech_priests_radar_sweep_ticks_for_pair_0279(pair) or TECH_PRIESTS_RADAR_SWEEP_TICKS_0278
  local offset = (station_unit * 37) % sweep_ticks
  local sweep_tick = (game.tick + offset) % sweep_ticks
  local angle = (sweep_tick / sweep_ticks) * math.pi * 2

  tech_priests_radar_draw_sweep_0278(player, pair, angle)
  tech_priests_radar_process_sweep_hits_0278(player, pair, angle)
end

function tech_priests_radar_tick_0278()
  if not (game and game.connected_players) then return end
  tech_priests_radar_ensure_storage_0278()
  for _, player in pairs(game.connected_players) do
    tech_priests_radar_update_player_0278(player)
  end
end

TECH_PRIESTS_PRE_RADAR_ON_SELECTED_ENTITY_CHANGED_0278 = on_selected_entity_changed
function on_selected_entity_changed(event)
  if TECH_PRIESTS_PRE_RADAR_ON_SELECTED_ENTITY_CHANGED_0278 then
    TECH_PRIESTS_PRE_RADAR_ON_SELECTED_ENTITY_CHANGED_0278(event)
  end
  local player = event and event.player_index and game.get_player(event.player_index) or nil
  if player then tech_priests_radar_update_player_0278(player) end
end

TechPriestsRuntimeEventRegistry.on_event(defines.events.on_selected_entity_changed, on_selected_entity_changed)

TechPriestsRuntimeEventRegistry.on_nth_tick(TECH_PRIESTS_RADAR_TICK_INTERVAL_0278, function()
  tech_priests_radar_tick_0278()
end)

if commands and commands.add_command then
  pcall(function()
    TechPriestsDebugCommandRegistry.add("tp-radar-0278", "Tech Priests: report selected station Radar cache state.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      if not (player and player.valid) then return end
      local pair = tech_priests_radar_get_hover_pair_0278(player)
      if not pair then
        player.print("No hovered Tech Priest station/priest pair found for Radar.")
        return
      end
      local cache = tech_priests_radar_get_cache_0278(pair)
      local counts = {}
      if cache and cache.known_by_kind then
        for kind, records in pairs(cache.known_by_kind) do
          local count = 0
          for _, record in pairs(records) do
            if record and record.entity and record.entity.valid then count = count + 1 end
          end
          counts[#counts + 1] = tostring(kind) .. "=" .. tostring(count)
        end
      end
      local sweep_ticks, sweep_seconds, rank = tech_priests_radar_sweep_ticks_for_pair_0279(pair)
      player.print("Radar " .. tostring(TECH_PRIESTS_RADAR_VERSION_0278) .. " station#" .. tostring(pair.station_unit or (pair.station and pair.station.valid and pair.station.unit_number) or "?") ..
        " rank=" .. tostring(rank) ..
        " sweep=" .. tostring(sweep_seconds) .. "s" ..
        " last=" .. tostring(pair.radar and pair.radar.last_detection_kind or "none") ..
        " task_reset=" .. tostring(pair.last_radar_task_reset_reason_0278 or "none") ..
        " cache{" .. table.concat(counts, ", ") .. "}")
    end)
  end)
end


-- ============================================================================
-- 0.1.280 Radar overlay scaling and senior task-audit doctrine
-- ============================================================================
-- Adds the supplied RADARSPLASH overlay as a world-space rendering sprite.  The
-- overlay is scaled from the station's current operating radius every radar
-- frame, so radius technologies, quality radius, and later station-size/radius
-- changes resize the visual sweep footprint automatically.
--
-- Also deepens the "priest scanned by radar" pass.  When the sweep crosses a
-- higher-order priest/station pair, the station audits malformed scavenge/task
-- state, re-runs recipe-aware missing-ingredient checks when possible, and asks
-- nearby lower-rank stations to refresh their own assignments.  This is kept
-- deliberately conservative: it clears obviously stale/malformed state and lets
-- the existing scheduler reacquire work rather than hard-overwriting the old
-- behavior stack.

TECH_PRIESTS_RADAR_OVERLAY_SPRITE_0280 = "tech-priests-radar-overlay"
TECH_PRIESTS_RADAR_OVERLAY_BASE_TILE_DIAMETER_0280 = 32 -- 1024px / 32px-per-tile
TECH_PRIESTS_RADAR_OVERLAY_TTL_0280 = 240
TECH_PRIESTS_RADAR_OVERLAY_MIN_SCALE_0280 = 0.05
TECH_PRIESTS_RADAR_SUBORDINATE_REFRESH_RADIUS_MULTIPLIER_0280 = 1.35
TECH_PRIESTS_RADAR_SUBORDINATE_REFRESH_MAX_0280 = 8

function tech_priests_radar_pair_station_rank_0280(pair)
  if tech_priests_radar_station_rank_0279 then
    local ok, rank = pcall(function() return tech_priests_radar_station_rank_0279(pair) end)
    if ok and rank then return tonumber(rank) or 1 end
  end
  return 1
end

function tech_priests_radar_operating_radius_0280(pair)
  if not (pair and pair.station and pair.station.valid) then return 30 end
  local radius = nil
  if refresh_pair_radius then
    local ok, result = pcall(function() return refresh_pair_radius(pair) end)
    if ok and result then radius = result end
  end
  if not radius and get_station_operating_radius then
    local ok, result = pcall(function() return get_station_operating_radius(pair.station) end)
    if ok and result then radius = result end
  end
  radius = radius or pair.radius or 30
  pair.radius = radius
  return radius
end

function tech_priests_radar_draw_scaled_overlay_0280(player_state, player, pair, radius)
  if not (player_state and player and player.valid and pair and pair.station and pair.station.valid) then return end
  local station = pair.station
  local diameter = math.max(1, (tonumber(radius) or 30) * 2)
  local scale = diameter / TECH_PRIESTS_RADAR_OVERLAY_BASE_TILE_DIAMETER_0280
  scale = math.max(TECH_PRIESTS_RADAR_OVERLAY_MIN_SCALE_0280, scale)

  -- 0.1.465: restore the uploaded radar-splash image as the radar screen overlay.
  -- The bad visual was the separate full-radius station-light / filled green
  -- plate behavior, not the scope artwork itself.  Keep this sprite extremely
  -- faint and stable, and redraw it only before TTL expiry so it does not strobe.
  if player_state.overlay_ring_0464 then
    tech_priests_radar_destroy_object_0278(player_state.overlay_ring_0464)
    player_state.overlay_ring_0464 = nil
  end

  local now_tick = game and game.tick or 0
  local same_station = player_state.overlay_station_unit_0461 == station.unit_number
  local same_radius = math.abs((tonumber(player_state.overlay_radius) or -1) - (tonumber(radius) or 0)) < 0.01
  local next_redraw = tonumber(player_state.overlay_next_redraw_tick_0461) or 0
  if same_station and same_radius and player_state.overlay and player_state.overlay.valid and now_tick < next_redraw then
    return
  end

  local old_overlay = player_state.overlay
  local ok_overlay, overlay = pcall(function()
    return rendering.draw_sprite({
      sprite = TECH_PRIESTS_RADAR_OVERLAY_SPRITE_0280,
      target = station.position,
      surface = station.surface,
      players = { player },
      x_scale = scale,
      y_scale = scale,
      -- Deliberately low alpha.  The source art already contains green fill;
      -- high tint alpha turns it back into the flashing dinner plate.
      tint = { r = 0.18, g = 1.0, b = 0.22, a = 0.026 },
      render_layer = "radius-visualization",
      time_to_live = TECH_PRIESTS_RADAR_OVERLAY_TTL_0280
    })
  end)
  if ok_overlay and overlay then
    if old_overlay then tech_priests_radar_destroy_object_0278(old_overlay) end
    player_state.overlay = overlay
    player_state.overlay_station_unit_0461 = station.unit_number
    player_state.overlay_next_redraw_tick_0461 = now_tick + math.max(90, (TECH_PRIESTS_RADAR_OVERLAY_TTL_0280 or 180) - 12)
  else
    player_state.overlay = old_overlay
  end
  player_state.overlay_radius = radius
  player_state.overlay_scale = scale
  player_state.overlay_disabled_0463 = nil
end

function tech_priests_radar_resource_matches_requested_item_0280(pair, entity, requested)
  if not (entity and entity.valid and requested and requested ~= "") then return true end
  if entity.name == requested then return true end
  -- Recipe-aware emergency doctrine often asks for a crafted item while the
  -- field scavenge source is an ingredient/raw substitute.  Accept the source if
  -- it is one of the requested item's direct recipe ingredients.
  if tech_priests_get_recipe_ingredients_for_item_0185 then
    local ok, ingredients = pcall(function() return tech_priests_get_recipe_ingredients_for_item_0185(requested) end)
    if ok and ingredients then
      for _, ingredient in pairs(ingredients) do
        if ingredient and ingredient.name == entity.name then return true end
      end
    end
  end
  return false
end

function tech_priests_radar_scavenge_state_malformed_0280(pair)
  if not pair then return false, nil end
  local scavenge = pair.scavenge
  if not scavenge then return false, nil end
  if scavenge.scanning then return false, nil end
  local source = scavenge.source
  if not (source and source.valid) then return true, "scavenge-source-invalid" end
  if not tech_priests_radar_entity_inside_station_0278(pair, source) then return true, "scavenge-source-outside-radius" end

  local requested = scavenge.item_name or pair.logistic_requested_item or nil
  if pair.inventory_scan and pair.inventory_scan.request then
    requested = requested or pair.inventory_scan.request.item_name
  end
  if requested and source.type == "resource" then
    if not tech_priests_radar_resource_matches_requested_item_0280(pair, source, requested) then
      return true, "scavenge-resource-mismatch:" .. tostring(source.name) .. "/" .. tostring(requested)
    end
  end
  return false, nil
end

function tech_priests_radar_reconcile_recipe_aware_order_0280(pair)
  if not pair then return false end
  local malformed, reason = tech_priests_radar_scavenge_state_malformed_0280(pair)
  if malformed then
    tech_priests_radar_clear_invalid_task_0278(pair, reason or "radar-malformed-scavenge")
    return true
  end

  -- If a higher-level operation is trying to acquire a crafted item but the
  -- station already knows a missing direct ingredient, make that ingredient the
  -- requested item so the next scavenge/logistics pass does not chase the wrong
  -- resource class.
  local op = pair.independent_emergency_operation_0184
  local wanted = (op and op.acquisition and op.acquisition.item_name) or pair.logistic_requested_item
  if wanted and tech_priests_choose_missing_recipe_ingredient_0185 then
    local ok, ingredient = pcall(function() return tech_priests_choose_missing_recipe_ingredient_0185(pair, wanted) end)
    if ok and ingredient and ingredient.name and ingredient.name ~= wanted then
      pair.radar_recipe_audit_0280 = {
        wanted = wanted,
        ingredient = ingredient.name,
        tick = game.tick
      }
      if pair.scavenge and pair.scavenge.item_name and pair.scavenge.item_name ~= ingredient.name then
        tech_priests_radar_clear_invalid_task_0278(pair, "radar-recipe-aware-retarget:" .. tostring(wanted) .. "->" .. tostring(ingredient.name))
        pair.logistic_requested_item = ingredient.name
        pair.logistic_requested_count = math.max(1, ingredient.count or 1)
        return true
      end
    end
  end
  return false
end

function tech_priests_radar_refresh_subordinate_orders_0280(pair)
  if not (pair and pair.station and pair.station.valid and storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return 0 end
  local rank = tech_priests_radar_pair_station_rank_0280(pair)
  if rank < 3 then return 0 end
  local station = pair.station
  local radius = tech_priests_radar_operating_radius_0280(pair) * TECH_PRIESTS_RADAR_SUBORDINATE_REFRESH_RADIUS_MULTIPLIER_0280
  local refreshed = 0
  for _, other in pairs(storage.tech_priests.pairs_by_station or {}) do
    if refreshed >= TECH_PRIESTS_RADAR_SUBORDINATE_REFRESH_MAX_0280 then break end
    if other ~= pair and other.station and other.station.valid and other.priest and other.priest.valid and other.station.surface == station.surface and other.station.force == station.force then
      local other_rank = tech_priests_radar_pair_station_rank_0280(other)
      if other_rank < rank then
        local dx = other.station.position.x - station.position.x
        local dy = other.station.position.y - station.position.y
        if dx * dx + dy * dy <= radius * radius then
          tech_priests_radar_reconcile_recipe_aware_order_0280(other)
          if tech_priests_0277_scheduler_tick then pcall(function() tech_priests_0277_scheduler_tick(other) end) end
          other.last_radar_superior_refresh_tick_0280 = game.tick
          other.last_radar_superior_station_0280 = station.unit_number
          refreshed = refreshed + 1
        end
      end
    end
  end
  pair.last_radar_subordinate_refresh_count_0280 = refreshed
  pair.last_radar_subordinate_refresh_tick_0280 = game.tick
  return refreshed
end

tech_priests_radar_validate_priest_task_pre_0280 = tech_priests_radar_validate_priest_task_0278
function tech_priests_radar_validate_priest_task_0278(pair)
  if not (pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid) then return false end
  tech_priests_radar_reconcile_recipe_aware_order_0280(pair)
  local rank = tech_priests_radar_pair_station_rank_0280(pair)
  if rank >= 3 then tech_priests_radar_refresh_subordinate_orders_0280(pair) end
  local result = false
  if tech_priests_radar_validate_priest_task_pre_0280 then
    local ok, value = pcall(function() return tech_priests_radar_validate_priest_task_pre_0280(pair) end)
    result = ok and value or false
  end
  pair.last_radar_priest_deep_audit_tick_0280 = game.tick
  return result or true
end

function tech_priests_radar_draw_sweep_0278(player, pair, angle)
  if not (player and player.valid and pair and pair.station and pair.station.valid) then return end
  local radar = tech_priests_radar_ensure_storage_0278()
  local station = pair.station
  local radius = tech_priests_radar_operating_radius_0280(pair)
  local center = station.position
  local edge = { x = center.x + math.cos(angle) * radius, y = center.y + math.sin(angle) * radius }

  local player_state = radar.players[player.index] or {}
  if player_state.line then tech_priests_radar_destroy_object_0278(player_state.line) end
  if player_state.endcap then tech_priests_radar_destroy_object_0278(player_state.endcap) end

  tech_priests_radar_draw_scaled_overlay_0280(player_state, player, pair, radius)

  local ok_line, line = pcall(function()
    return rendering.draw_line({
      color = { r = 0.20, g = 1.0, b = 0.22, a = 0.92 },
      width = 3,
      from = { entity = station, offset = { 0, -0.18 } },
      to = edge,
      surface = station.surface,
      players = { player },
      time_to_live = TECH_PRIESTS_RADAR_LINE_TTL_0278
    })
  end)

  local ok_cap, cap = pcall(function()
    return rendering.draw_circle({
      color = { r = 0.35, g = 1.0, b = 0.35, a = 0.78 },
      radius = 0.18,
      filled = true,
      target = edge,
      surface = station.surface,
      players = { player },
      time_to_live = TECH_PRIESTS_RADAR_LINE_TTL_0278
    })
  end)

  player_state.line = ok_line and line or nil
  player_state.endcap = ok_cap and cap or nil
  player_state.station_unit = station.unit_number
  player_state.last_tick = game.tick
  radar.players[player.index] = player_state
end


-- ============================================================================
-- 0.1.281: command overview right-panel scroll fix, Factorio 2 inventory
--          content normalization, and sharper Radar acceleration floor.
-- ============================================================================
TECH_PRIESTS_PATCH_0281 = "0.1.281-command-overview-inventory-radar-timing"

-- 0.1.281 Radar timing doctrine:
-- Base/rank timings stay legible at 60/50/40/30/20 seconds.  The acceleration
-- technology now subtracts fifteen seconds and the hard floor is five seconds,
-- giving a researched Void Cogitator a five-second scan cycle.
TECH_PRIESTS_RADAR_TECH_SWEEP_SECONDS_0279 = 15
TECH_PRIESTS_RADAR_MIN_SWEEP_SECONDS_0279 = 5

function tech_priests_inventory_stack_caption_0281(name, count, quality)
  if type(name) ~= "string" or name == "" then return nil end
  local caption = "[item=" .. name .. "]×" .. tostring(count or 0)
  if quality and quality ~= "normal" then caption = caption .. " (" .. tostring(quality) .. ")" end
  return caption
end

function tech_priests_station_inventory_summary_0189(pair)
  if not (pair and pair.station and pair.station.valid and get_station_inventory) then return "—" end
  local inv = get_station_inventory(pair.station)
  if not inv or not inv.valid then return "—" end
  local contents = inv.get_contents()
  local parts = {}
  local n = 0

  for key, value in pairs(contents or {}) do
    local name = nil
    local count = nil
    local quality = nil

    -- Factorio 1.x style: { ["iron-plate"] = 42 }
    if type(key) == "string" and type(value) == "number" then
      name = key
      count = value

    -- Factorio 2.x / quality-aware style commonly arrives as an array of
    -- tables: { { name = "iron-plate", count = 42, quality = "normal" }, ... }
    elseif type(value) == "table" then
      name = value.name or value.item or value.item_name
      count = value.count or value.amount or value[2]
      quality = value.quality or value.quality_name
      if type(quality) == "table" then quality = quality.name end

    -- Defensive fallback for a strange mapped table shape.
    elseif type(key) == "table" then
      name = key.name or key.item or key.item_name
      count = value
      quality = key.quality or key.quality_name
      if type(quality) == "table" then quality = quality.name end
    end

    if name and count and count > 0 then
      n = n + 1
      if n <= 7 then
        local caption = tech_priests_inventory_stack_caption_0281(name, count, quality)
        if caption then parts[#parts + 1] = caption end
      end
    end
  end

  if n > 7 then parts[#parts + 1] = "+" .. tostring(n - 7) .. " more" end
  if #parts == 0 then return "empty" end
  return table.concat(parts, "  ")
end

function tech_priests_command_overview_set_size_0281(element, width, height, max_height)
  if not (element and element.valid and element.style) then return end
  if width then element.style.width = width end
  if height then element.style.height = height end
  if max_height then element.style.maximal_height = max_height end
end

-- Full rebuild of the 0.1.189 overview, with the right preview contained in a
-- scroll-pane.  This prevents the emergency/action buttons from being rendered
-- under the lower edge of the preview frame on 720p/800p-height displays.
function tech_priests_build_command_overview_0189(player)
  if not (player and player.valid) then return end
  tech_priests_destroy_command_overview_0189(player)
  local rows = tech_priests_valid_pairs_for_player_0189(player)
  local selected_pair = tech_priests_get_selected_pair_0189(player, rows)
  if selected_pair then tech_priests_command_overview_storage_0189()[player.index] = tech_priests_station_unit_0189(selected_pair) end

  local frame = player.gui.screen.add({ type = "frame", name = TECH_PRIESTS_COMMAND_OVERVIEW_FRAME_0189, direction = "vertical", caption = "Tech-Priest Command Overview" })
  frame.auto_center = true
  frame.style.width = 1120
  frame.style.height = 760
  frame.style.minimal_width = 1120
  frame.style.minimal_height = 760

  local top = frame.add({ type = "flow", direction = "horizontal" })
  top.style.horizontally_stretchable = true
  local title = top.add({ type = "label", caption = "[entity=senior-tech-priest] Force roster · Shift+Y" })
  title.style.horizontally_stretchable = true
  top.add({ type = "button", name = TECH_PRIESTS_COMMAND_OVERVIEW_REFRESH_0189, caption = "Refresh" })
  top.add({ type = "button", name = TECH_PRIESTS_COMMAND_OVERVIEW_CLOSE_0189, caption = "Close" })

  local tabs = frame.add({ type = "tabbed-pane", name = TECH_PRIESTS_COMMAND_OVERVIEW_TABS_0371 })
  tabs.style.vertically_stretchable = true
  tabs.style.horizontally_stretchable = true
  tabs.style.height = 660

  local roster_tab = tabs.add({ type = "tab", caption = "Roster / Selected Unit" })
  local roster_page = tabs.add({ type = "flow", direction = "horizontal" })
  roster_page.style.vertically_stretchable = true
  roster_page.style.horizontally_stretchable = true
  roster_page.style.height = 640
  tabs.add_tab(roster_tab, roster_page)

  local conclave_tab = tabs.add({ type = "tab", caption = "Conclave Statistics / Doctrine Heat Map" })
  local conclave_page = tabs.add({ type = "flow", direction = "vertical" })
  conclave_page.style.vertically_stretchable = true
  conclave_page.style.horizontally_stretchable = true
  conclave_page.style.height = 640
  tabs.add_tab(conclave_tab, conclave_page)

  local body = roster_page

  local left = body.add({ type = "scroll-pane", direction = "vertical" })
  left.style.width = 720
  left.style.height = 625
  left.style.maximal_height = 625
  left.style.vertically_stretchable = true
  left.style.horizontally_stretchable = false

  local table_el = left.add({ type = "table", column_count = 6 })
  table_el.add({ type = "label", caption = "Priest" })
  table_el.add({ type = "label", caption = "Rank" })
  table_el.add({ type = "label", caption = "Station" })
  table_el.add({ type = "label", caption = "Surface" })
  table_el.add({ type = "label", caption = "Location" })
  table_el.add({ type = "label", caption = "Current task" })

  if #rows == 0 then
    table_el.add({ type = "label", caption = "No active Cogitator Stations / Tech-Priests for this force." })
  else
    for _, pair in ipairs(rows) do
      local station_unit = tech_priests_station_unit_0189(pair) or 0
      local selected = selected_pair and station_unit == tech_priests_station_unit_0189(selected_pair)
      local btn = table_el.add({ type = "button", name = TECH_PRIESTS_COMMAND_OVERVIEW_PREFIX_0189 .. tostring(station_unit), caption = (selected and "▶ " or "") .. tech_priests_pair_name_0189(pair) })
      btn.style.width = 155
      table_el.add({ type = "label", caption = tech_priests_pair_rank_label_0189(pair) })
      table_el.add({ type = "label", caption = tech_priests_station_name_0189(pair) })
      table_el.add({ type = "label", caption = pair.station.surface.name })
      table_el.add({ type = "label", caption = tech_priests_entity_coord_0189(pair.station) })
      local task = table_el.add({ type = "label", caption = tech_priests_task_summary_0189(pair) })
      task.style.single_line = false
      task.style.width = 300
    end
  end

  local right_frame = body.add({ type = "frame", direction = "vertical", caption = "Selected unit preview" })
  right_frame.style.width = 360
  right_frame.style.height = 625
  right_frame.style.maximal_height = 625
  right_frame.style.vertically_stretchable = false

  local right = right_frame.add({ type = "scroll-pane", direction = "vertical" })
  right.style.width = 340
  right.style.height = 585
  right.style.maximal_height = 585
  right.style.vertically_stretchable = true
  right.style.horizontally_stretchable = true

  if selected_pair and selected_pair.station and selected_pair.station.valid then
    local preview_target = (selected_pair.priest and selected_pair.priest.valid and selected_pair.priest) or selected_pair.station
    local ok = pcall(function()
      local cam = right.add({
        type = "camera",
        name = "tech_priests_command_camera_0189",
        position = preview_target.position,
        surface_index = preview_target.surface.index,
        zoom = 0.45
      })
      cam.style.width = 320
      cam.style.height = 210
    end)
    if not ok then
      right.add({ type = "label", caption = "Camera preview unavailable in this runtime; use the coordinates below." })
    end

    tech_priests_add_labeled_line_0189(right, "Priest", tech_priests_pair_name_0189(selected_pair))
    tech_priests_add_labeled_line_0189(right, "Rank", tech_priests_pair_rank_label_0189(selected_pair))
    tech_priests_add_labeled_line_0189(right, "Station", tech_priests_station_name_0189(selected_pair))
    tech_priests_add_labeled_line_0189(right, "Surface", selected_pair.station.surface.name)
    tech_priests_add_labeled_line_0189(right, "Station coords", tech_priests_entity_coord_0189(selected_pair.station))
    tech_priests_add_labeled_line_0189(right, "Priest coords", tech_priests_entity_coord_0189(selected_pair.priest))
    tech_priests_add_labeled_line_0189(right, "Station health", tech_priests_pair_health_0189(selected_pair.station))
    tech_priests_add_labeled_line_0189(right, "Priest health", tech_priests_pair_health_0189(selected_pair.priest))
    tech_priests_add_labeled_line_0189(right, "Task", tech_priests_task_summary_0189(selected_pair))
    tech_priests_add_labeled_line_0189(right, "Inventory", tech_priests_station_inventory_summary_0189(selected_pair))
    local emergency_op_0190 = (tech_priests_get_emergency_operation_0184 and tech_priests_get_emergency_operation_0184(selected_pair)) or selected_pair.independent_emergency_operation_0184
    local emergency_status_0190 = emergency_op_0190 and "Independent / Emergency doctrine: ENABLED" or "Independent / Emergency doctrine: disabled"
    tech_priests_add_labeled_line_0189(right, "Emergency", emergency_status_0190)
    right.add({ type = "button", name = TECH_PRIESTS_COMMAND_OVERVIEW_EMERGENCY_TOGGLE_0190, caption = emergency_op_0190 and "Disable independent / emergency mode" or "Enable independent / emergency mode" })
    right.add({ type = "button", name = TECH_PRIESTS_COMMAND_OVERVIEW_EMERGENCY_AUTO_0190, caption = "Allow frustration auto-enable" })
    right.add({ type = "button", name = TECH_PRIESTS_COMMAND_OVERVIEW_PREFIX_0189 .. tostring(tech_priests_station_unit_0189(selected_pair) or 0) .. "_center", caption = "Mark selected priest in chat" })

    -- Preserve the 0.1.272 subordinate overview additions inside the scrollable
    -- preview so those lines cannot push buttons beneath the lower frame edge.
    if tech_priests_0272_subordinate_summary then
      tech_priests_add_labeled_line_0189(right, "Subordinates", tech_priests_0272_subordinate_summary(selected_pair, 4))
    end
    if tech_priests_0272_requested_assignment_summary then
      tech_priests_add_labeled_line_0189(right, "Requested work", tech_priests_0272_requested_assignment_summary(selected_pair, 3))
    end
  else
    right.add({ type = "label", caption = "No Tech-Priest selected." })
  end

  if _G.tech_priests_0370_render_conclave_content then
    local ok, err = pcall(_G.tech_priests_0370_render_conclave_content, conclave_page, player, { embedded = true, max_height = 585, min_width = 1030 })
    if not ok then conclave_page.add({ type = "label", caption = "Conclave Statistics tab failed to render: " .. tostring(err) }) end
  else
    conclave_page.add({ type = "label", caption = "Conclave Statistics tab is waiting for doctrine_argument.lua to install." })
    conclave_page.add({ type = "label", caption = "This tab is the intended home for the doctrine heat map; no separate management hotkey should be added." })
  end

  if tech_priests_command_overview_selected_tab_0371(player) == "conclave" then
    pcall(function() tabs.selected_tab_index = 2 end)
  else
    pcall(function() tabs.selected_tab_index = 1 end)
  end
end

if commands and commands.add_command then
  pcall(function()
    TechPriestsDebugCommandRegistry.add("tp-radar-0281", "Tech Priests: report selected station Radar timing after 0.1.281 acceleration-floor patch.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      if not (player and player.valid) then return end
      local pair = tech_priests_radar_get_hover_pair_0278 and tech_priests_radar_get_hover_pair_0278(player) or nil
      if not pair then player.print("No hovered Tech Priest station/priest pair found for Radar."); return end
      local sweep_ticks, sweep_seconds, rank = tech_priests_radar_sweep_ticks_for_pair_0279(pair)
      player.print("Radar 0.1.281 station#" .. tostring(pair.station_unit or (pair.station and pair.station.valid and pair.station.unit_number) or "?") ..
        " rank=" .. tostring(rank) ..
        " sweep=" .. tostring(sweep_seconds) .. "s" ..
        " tech_bonus=" .. tostring(TECH_PRIESTS_RADAR_TECH_SWEEP_SECONDS_0279) .. "s" ..
        " floor=" .. tostring(TECH_PRIESTS_RADAR_MIN_SWEEP_SECONDS_0279) .. "s")
    end)
  end)
end

if tech_priests_log then
  tech_priests_log("0.1.281 command overview scroll/inventory normalization + Radar timing floor loaded")
end


-- 0.1.282 Radar task scheduler refresh and sweep-time retune.
-- The rank ladder now starts five seconds faster while preserving the 15-second
-- acceleration technology and 5-second floor introduced by the previous patch:
-- Junior 55, Intermediate 45, Senior 35, Planetary Magos 25, Void 15; researched
-- Void remains clamped to 5 seconds.
TECH_PRIESTS_PATCH_0282 = "0.1.282-radar-task-scheduler-refresh"
TECH_PRIESTS_RADAR_BASE_SWEEP_SECONDS_0279 = 55
TECH_PRIESTS_RADAR_RANK_SWEEP_SECONDS_0279 = 10
TECH_PRIESTS_RADAR_TECH_SWEEP_SECONDS_0279 = 15
TECH_PRIESTS_RADAR_MIN_SWEEP_SECONDS_0279 = 5
TECH_PRIESTS_RADAR_SUPPLY_WAIT_TICKS_0282 = 60 * 15
TECH_PRIESTS_RADAR_REPAIR_REQUEST_STOCK_0282 = LOGISTIC_REQUISITION_REPAIR_TARGET_STOCK or 1
TECH_PRIESTS_RADAR_TASK_REFRESH_COOLDOWN_0282 = 30

function tech_priests_radar_mode_is_combat_0282(pair)
  if not pair then return false end
  local mode = pair.mode or pair.task_kind or pair.last_scheduler_priority_0277
  return mode == "defending" or mode == "moving-to-combat" or mode == "combat" or mode == "attack"
end

function tech_priests_radar_mode_is_repair_0282(pair)
  if not pair then return false end
  local mode = pair.mode or pair.task_kind or pair.last_scheduler_priority_0277
  return mode == "moving-to-repair" or mode == "repairing" or mode == "repair-waiting-usefulness" or mode == "missing-repair-supplies" or mode == "repair" or mode == "repair-missing-supplies"
end

function tech_priests_radar_target_is_damaged_0282(entity)
  return entity and entity.valid and entity.health and entity.max_health and entity.health > 0 and entity.health < entity.max_health
end

function tech_priests_radar_target_needs_consecration_0282(entity)
  if not (entity and entity.valid and is_consecration_target and get_consecration_record and is_consecration_target(entity)) then return false end
  local record = get_consecration_record(entity)
  if not record then return false end
  local maximum = record.max_sanctification or (get_base_sanctification_max and get_base_sanctification_max(entity.force)) or 100
  return (record.sanctification or 0) < maximum
end

function tech_priests_radar_request_hidden_logistics_0282(pair, item_name, count)
  if not (pair and pair.station and pair.station.valid and item_name) then return false end
  local requested = math.max(1, count or 1)
  local ok_cache = true
  if ensure_pair_logistic_caches then
    ok_cache = pcall(function() return ensure_pair_logistic_caches(pair) end)
  end
  if pair.logistic_requester and pair.logistic_requester.valid and set_logistic_request_slot then
    local ok_slot = pcall(function()
      return set_logistic_request_slot(pair.logistic_requester, 1, { name = item_name, count = requested })
    end)
    if ok_slot then return true end
  end
  return ok_cache == true
end

function tech_priests_radar_begin_supply_wait_0282(pair, kind, item_name, target)
  if not pair then return end
  local now = game and game.tick or 0
  pair.logistic_frustration_kind = kind
  pair.logistic_requested_item = item_name
  pair.logistic_requested_count = pair.logistic_requested_count or 1
  pair.logistic_frustration_start_tick = pair.logistic_frustration_start_tick or now
  pair.logistic_frustration_due_tick = pair.logistic_frustration_due_tick or (now + (LOGISTIC_FRUSTRATION_THRESHOLD_TICKS or TECH_PRIESTS_RADAR_SUPPLY_WAIT_TICKS_0282))
  pair.active_supply_request = pair.active_supply_request or { kind = kind, target = target, tick = now }
  pair.next_logistic_requisition_tick = now
end

function tech_priests_radar_queue_repair_pack_0282(pair, target)
  if not (pair and pair.station and pair.station.valid) then return false end
  local count = TECH_PRIESTS_RADAR_REPAIR_REQUEST_STOCK_0282
  tech_priests_radar_begin_supply_wait_0282(pair, "repair", "repair-pack", target)
  tech_priests_radar_request_hidden_logistics_0282(pair, "repair-pack", count)
  if perform_station_logistic_requisition then pcall(function() perform_station_logistic_requisition(pair) end) end
  return true
end

function tech_priests_radar_queue_consecration_supply_0282(pair, target)
  if not (pair and pair.station and pair.station.valid) then return false end
  local item_name = "sacred-machine-oil"
  if get_station_consecration_item_options then
    local ok, options = pcall(function() return get_station_consecration_item_options() end)
    if ok and options and options[1] and options[1].name then item_name = options[1].name end
  end
  tech_priests_radar_begin_supply_wait_0282(pair, "consecration", item_name, target)
  tech_priests_radar_request_hidden_logistics_0282(pair, item_name, 1)
  if perform_station_logistic_requisition then pcall(function() perform_station_logistic_requisition(pair) end) end
  return true
end

function tech_priests_radar_refresh_repair_task_0282(pair, target)
  if not (pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid and tech_priests_radar_target_is_damaged_0282(target)) then return false end
  if tech_priests_radar_mode_is_combat_0282(pair) then return false end
  if pair.last_radar_scheduler_refresh_tick_0282 and game and game.tick and game.tick - pair.last_radar_scheduler_refresh_tick_0282 < TECH_PRIESTS_RADAR_TASK_REFRESH_COOLDOWN_0282 and pair.target == target then return false end

  if tech_priests_clear_interruptible_supply_work then pcall(function() tech_priests_clear_interruptible_supply_work(pair) end) end
  pair.target = target
  pair.last_radar_scheduler_refresh_kind_0282 = "repair"
  pair.last_radar_scheduler_refresh_target_0282 = target.unit_number or target.name
  pair.last_radar_scheduler_refresh_tick_0282 = game and game.tick or 0

  if station_has_repair_pack and station_has_repair_pack(pair.station) then
    if repair_target then pcall(function() repair_target(pair, target) end) end
    return true
  end

  pair.mode = "missing-repair-supplies"
  tech_priests_radar_queue_repair_pack_0282(pair, target)
  if maybe_start_supply_scavenge then pcall(function() maybe_start_supply_scavenge(pair, "repair", target) end) end
  if return_to_station then pcall(function() return_to_station(pair.priest, pair.station) end) end
  return true
end

function tech_priests_radar_refresh_consecration_task_0282(pair, target)
  if not (pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid and tech_priests_radar_target_needs_consecration_0282(target)) then return false end
  if tech_priests_radar_mode_is_combat_0282(pair) or tech_priests_radar_mode_is_repair_0282(pair) then return false end
  if pair.last_radar_scheduler_refresh_tick_0282 and game and game.tick and game.tick - pair.last_radar_scheduler_refresh_tick_0282 < TECH_PRIESTS_RADAR_TASK_REFRESH_COOLDOWN_0282 and pair.target == target then return false end

  if tech_priests_clear_interruptible_supply_work then pcall(function() tech_priests_clear_interruptible_supply_work(pair) end) end
  pair.target = target
  pair.last_radar_scheduler_refresh_kind_0282 = "consecration"
  pair.last_radar_scheduler_refresh_target_0282 = target.unit_number or target.name
  pair.last_radar_scheduler_refresh_tick_0282 = game and game.tick or 0

  if station_has_consecration_item and station_has_consecration_item(pair.station) then
    if sanctify_target_with_priest then pcall(function() sanctify_target_with_priest(pair, target) end) end
    return true
  end

  pair.mode = "missing-consecration-supplies"
  tech_priests_radar_queue_consecration_supply_0282(pair, target)
  if maybe_start_supply_scavenge then pcall(function() maybe_start_supply_scavenge(pair, "consecration", target) end) end
  if return_to_station then pcall(function() return_to_station(pair.priest, pair.station) end) end
  return true
end

function tech_priests_radar_refresh_detected_task_0282(pair, entity, info)
  if not (pair and entity and entity.valid and info and info.kind) then return false end
  if info.kind == "repair" then
    return tech_priests_radar_refresh_repair_task_0282(pair, entity)
  elseif info.kind == "consecration" then
    return tech_priests_radar_refresh_consecration_task_0282(pair, entity)
  end
  return false
end

tech_priests_radar_process_sweep_hits_pre_0282 = tech_priests_radar_process_sweep_hits_0278
function tech_priests_radar_process_sweep_hits_0278(player, pair, angle)
  local cache = tech_priests_radar_get_cache_0278(pair)
  if not cache then return end
  local station = pair.station
  local station_pos = station.position
  local flashed = 0

  for index = #cache.candidates, 1, -1 do
    local entity = cache.candidates[index]
    if not (entity and entity.valid) then
      table.remove(cache.candidates, index)
    else
      local entity_angle = tech_priests_radar_angle_0278(station_pos, entity.position)
      if tech_priests_radar_angle_delta_0278(angle, entity_angle) <= TECH_PRIESTS_RADAR_SWEEP_HALF_WIDTH_RADIANS_0278 then
        local info = tech_priests_radar_classify_entity_0278(pair, entity)
        if info then
          tech_priests_radar_remember_detection_0278(pair, entity, info)
          if info.kind == "priest" then
            tech_priests_radar_validate_priest_task_0278(pair)
          elseif info.kind == "repair" or info.kind == "consecration" then
            tech_priests_radar_refresh_detected_task_0282(pair, entity, info)
          end
          if flashed < TECH_PRIESTS_RADAR_MAX_FLASHES_PER_STEP_0278 then
            tech_priests_radar_flash_entity_icon_0278(player, entity, info)
            flashed = flashed + 1
          end
        end
      end
    end
  end
end

if commands and commands.add_command then
  pcall(function()
    TechPriestsDebugCommandRegistry.add("tp-radar-0282", "Tech Priests: report selected station Radar timing and last Radar task scheduler refresh.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      if not (player and player.valid) then return end
      local pair = tech_priests_radar_get_hover_pair_0278 and tech_priests_radar_get_hover_pair_0278(player) or nil
      if not pair then player.print("No hovered Tech Priest station/priest pair found for Radar."); return end
      local sweep_ticks, sweep_seconds, rank = tech_priests_radar_sweep_ticks_for_pair_0279(pair)
      player.print("Radar 0.1.282 station#" .. tostring(pair.station_unit or (pair.station and pair.station.valid and pair.station.unit_number) or "?") ..
        " rank=" .. tostring(rank) ..
        " sweep=" .. tostring(sweep_seconds) .. "s" ..
        " base=" .. tostring(TECH_PRIESTS_RADAR_BASE_SWEEP_SECONDS_0279) .. "s" ..
        " rank_step=" .. tostring(TECH_PRIESTS_RADAR_RANK_SWEEP_SECONDS_0279) .. "s" ..
        " tech_bonus=" .. tostring(TECH_PRIESTS_RADAR_TECH_SWEEP_SECONDS_0279) .. "s" ..
        " floor=" .. tostring(TECH_PRIESTS_RADAR_MIN_SWEEP_SECONDS_0279) .. "s" ..
        " refresh=" .. tostring(pair.last_radar_scheduler_refresh_kind_0282 or "none") ..
        " target=" .. tostring(pair.last_radar_scheduler_refresh_target_0282 or "none"))
    end)
  end)
end

if tech_priests_log then
  tech_priests_log("0.1.282 Radar timing retune and detection-driven repair/consecration scheduler refresh loaded")
end


-- ============================================================================
-- 0.1.283: Radar phosphor afterglow, screen darkening, and hard task re-audit.
-- ============================================================================
TECH_PRIESTS_PATCH_0283 = "0.1.283-radar-phosphor-task-reaudit"

-- Retune the rank table the way the Omnissiah actually requested this time:
-- Junior 55, Intermediate 45, Senior 35, Planetary Magos 25, Void 15.
-- The existing acceleration technology still subtracts fifteen seconds and the
-- five-second floor remains in place, so researched Void Cogitators still land
-- at the intended five-second sweep cycle.
TECH_PRIESTS_RADAR_BASE_SWEEP_SECONDS_0279 = 55
TECH_PRIESTS_RADAR_RANK_SWEEP_SECONDS_0279 = 10
TECH_PRIESTS_RADAR_TECH_SWEEP_SECONDS_0279 = 15
TECH_PRIESTS_RADAR_MIN_SWEEP_SECONDS_0279 = 5

TECH_PRIESTS_RADAR_SCREEN_DIM_ALPHA_0283 = 0.46
TECH_PRIESTS_RADAR_SCREEN_DIM_RADIUS_MULTIPLIER_0283 = 12.0 -- 0.1.333 ultrawide-safe scope dimming
TECH_PRIESTS_RADAR_TRAIL_STEPS_0283 = 8
TECH_PRIESTS_RADAR_TRAIL_TTL_0283 = 22
TECH_PRIESTS_RADAR_TRAIL_WIDTH_0283 = 2
TECH_PRIESTS_RADAR_REAUDIT_COOLDOWN_0283 = 15

function tech_priests_radar_destroy_list_0283(list)
  if not list then return end
  for _, obj in pairs(list) do
    if obj then tech_priests_radar_destroy_object_0278(obj) end
  end
end

function tech_priests_radar_draw_screen_dim_0283(player_state, player, station, radius)
  if not (player_state and player and player.valid and station and station.valid) then return end
  if player_state.dim_0283 then tech_priests_radar_destroy_object_0278(player_state.dim_0283) end
  local dim_radius = math.max(24, (radius or 30) * TECH_PRIESTS_RADAR_SCREEN_DIM_RADIUS_MULTIPLIER_0283)
  local pos = station.position
  local ok_dim, dim = pcall(function()
    return rendering.draw_rectangle({
      color = { r = 0.0, g = 0.0, b = 0.0, a = TECH_PRIESTS_RADAR_SCREEN_DIM_ALPHA_0283 },
      filled = true,
      left_top = { x = pos.x - dim_radius, y = pos.y - dim_radius },
      right_bottom = { x = pos.x + dim_radius, y = pos.y + dim_radius },
      surface = station.surface,
      players = { player },
      render_layer = "radius-visualization",
      time_to_live = TECH_PRIESTS_RADAR_OVERLAY_TTL_0280 or 4
    })
  end)
  player_state.dim_0283 = ok_dim and dim or nil
end

function tech_priests_radar_draw_phosphor_trail_0283(player_state, player, station, center, radius, angle)
  if not (player_state and player and player.valid and station and station.valid and center and radius and angle) then return end
  local sweep_ticks = TECH_PRIESTS_RADAR_SWEEP_TICKS_0278 or 3600
  local ok_sweep, _, _ = pcall(function()
    if tech_priests_radar_sweep_ticks_for_pair_0279 and player_state.station_unit then
      -- calculated per draw call below where pair is available; harmless fallback here
    end
  end)
  local trail = player_state.trail_0283 or {}
  player_state.trail_0283 = trail

  -- Do not destroy these immediately: the whole point is phosphor persistence.
  -- They die by TTL, leaving a fading wedge behind the live sweep arm.
  for step = 1, TECH_PRIESTS_RADAR_TRAIL_STEPS_0283 do
    local behind = angle - (step * 0.018)
    local edge = { x = center.x + math.cos(behind) * radius, y = center.y + math.sin(behind) * radius }
    local alpha = math.max(0.025, 0.18 - (step * 0.020))
    local ttl = math.max(4, TECH_PRIESTS_RADAR_TRAIL_TTL_0283 - (step * 2))
    local ok_line, line = pcall(function()
      return rendering.draw_line({
        color = { r = 0.12, g = 1.0, b = 0.18, a = alpha },
        width = math.max(1, math.min(TECH_PRIESTS_RADAR_TRAIL_WIDTH_0283 or 2, 2)),
        from = { entity = station, offset = { 0, -0.18 } },
        to = edge,
        surface = station.surface,
        players = { player },
        time_to_live = ttl
      })
    end)
    if ok_line and line then trail[#trail + 1] = line end
  end
  if #trail > 96 then
    for i = 1, #trail - 96 do
      if trail[i] then tech_priests_radar_destroy_object_0278(trail[i]) end
      trail[i] = nil
    end
  end
end

function tech_priests_radar_emergency_task_requested_item_0283(task)
  if not task then return nil end
  return task.item_name or task.raw_item or task.material_item or task.ingredient_item or task.need_item or task.current_item or task.output_item or task.item or task.result
end

function tech_priests_radar_current_source_name_0283(cur)
  if not cur then return nil end
  if cur.entity and cur.entity.valid then return cur.entity.name end
  return cur.source_name or cur.resource_name or cur.item_name or cur.output_item or cur.name
end

function tech_priests_radar_resource_is_recipe_aware_match_0283(pair, source_name, requested)
  if not (source_name and requested) then return true end
  if source_name == requested then return true end
  if tech_priests_radar_resource_matches_requested_item_0280 then
    -- This helper expects an entity, so only use the recipe side directly below.
  end
  if tech_priests_get_recipe_ingredients_for_item_0185 then
    local ok, ingredients = pcall(function() return tech_priests_get_recipe_ingredients_for_item_0185(requested) end)
    if ok and ingredients then
      for _, ingredient in pairs(ingredients) do
        if ingredient and ingredient.name == source_name then return true end
      end
    end
  end
  if requested == "firearm-magazine" and (source_name == "iron-plate" or source_name == "iron-ore") then return true end
  if requested == "iron-plate" and source_name == "iron-ore" then return true end
  if requested == "copper-plate" and source_name == "copper-ore" then return true end
  if requested == "steel-plate" and (source_name == "iron-plate" or source_name == "iron-ore") then return true end
  return false
end

function tech_priests_radar_hard_reaudit_pair_0283(pair, reason)
  if not (pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid) then return false end
  local now = game and game.tick or 0
  if pair.last_radar_hard_reaudit_tick_0283 and now - pair.last_radar_hard_reaudit_tick_0283 < TECH_PRIESTS_RADAR_REAUDIT_COOLDOWN_0283 then return false end
  pair.last_radar_hard_reaudit_tick_0283 = now
  pair.last_radar_hard_reaudit_reason_0283 = reason or "radar-priest-scan"

  -- If a stale visible/task target is no longer valid, actually amputate it;
  -- the previous radar audit was too polite and left old emergency craft state
  -- sitting around like a servitor with a dead battery and a strong opinion.
  if pair.target and (not pair.target.valid or not tech_priests_radar_entity_inside_station_0278(pair, pair.target)) then
    tech_priests_radar_clear_invalid_task_0278(pair, "radar-hard-target-invalid")
  end

  local task = pair.emergency_craft
  if task then
    local requested = tech_priests_radar_emergency_task_requested_item_0283(task)
    local cur = task.current
    local source_name = tech_priests_radar_current_source_name_0283(cur)
    local malformed = false
    if cur and cur.entity and (not cur.entity.valid or not tech_priests_radar_entity_inside_station_0278(pair, cur.entity)) then
      malformed = true
      pair.last_radar_hard_malformed_reason_0283 = "emergency-current-invalid-or-outside-radius"
    elseif source_name and requested and not tech_priests_radar_resource_is_recipe_aware_match_0283(pair, source_name, requested) then
      malformed = true
      pair.last_radar_hard_malformed_reason_0283 = "emergency-current-mismatch:" .. tostring(source_name) .. "/" .. tostring(requested)
    end
    if malformed then
      task.current = nil
      task.candidates = nil
      task.index = nil
      task.scan_due_tick = now
      task.scan_started_tick = nil
      task.craft_due_tick = nil
      task.direct_due_tick_0273 = nil
      task.direct_assigned_tick_0274 = nil
      task.direct_completed_by_0274 = nil
      task.force_raw_fallback_0270 = true
      pair.scavenge = nil
      pair.cram = nil
      pair.next_scavenge_search_tick = now
    end
  end

  if tech_priests_radar_reconcile_recipe_aware_order_0280 then pcall(function() tech_priests_radar_reconcile_recipe_aware_order_0280(pair) end) end
  if tech_priests_0270_refresh_orders_for_pair then pcall(function() tech_priests_0270_refresh_orders_for_pair(pair, reason or "radar-sweep") end) end
  if perform_station_logistic_requisition then pcall(function() perform_station_logistic_requisition(pair) end) end
  if tech_priests_0277_scheduler_tick then pcall(function() tech_priests_0277_scheduler_tick(pair) end) end
  if pair.emergency_craft and handle_emergency_desperation_craft then pcall(function() handle_emergency_desperation_craft(pair) end) end
  if pair.scavenge and handle_priest_scavenge_task then pcall(function() handle_priest_scavenge_task(pair) end) end

  pair.last_radar_task_reset_reason_0278 = pair.last_radar_task_reset_reason_0278 or "radar-hard-reaudit"
  return true
end

tech_priests_radar_validate_priest_task_pre_0283 = tech_priests_radar_validate_priest_task_0278
function tech_priests_radar_validate_priest_task_0278(pair)
  local result = false
  if tech_priests_radar_validate_priest_task_pre_0283 then
    local ok, value = pcall(function() return tech_priests_radar_validate_priest_task_pre_0283(pair) end)
    result = ok and value or false
  end
  tech_priests_radar_hard_reaudit_pair_0283(pair, "radar-priest-scan")
  return result or true
end

-- Override the draw routine after 0.1.280/0.1.282 so the darkening is behind
-- the overlay and the phosphor trail is left behind the active sweep line.
tech_priests_radar_draw_sweep_pre_0283 = tech_priests_radar_draw_sweep_0278
function tech_priests_radar_draw_sweep_0278(player, pair, angle)
  if not (player and player.valid and pair and pair.station and pair.station.valid) then return end
  local radar = tech_priests_radar_ensure_storage_0278()
  local station = pair.station
  local radius = tech_priests_radar_operating_radius_0280 and tech_priests_radar_operating_radius_0280(pair) or pair.radius or 30
  local center = station.position
  local edge = { x = center.x + math.cos(angle) * radius, y = center.y + math.sin(angle) * radius }

  local player_state = radar.players[player.index] or {}
  -- 0.1.461: draw the replacement sweep arm before destroying the previous arm
  -- below.  This removes the one-frame blink on hover.

  tech_priests_radar_draw_screen_dim_0283(player_state, player, station, radius)
  if tech_priests_radar_draw_scaled_overlay_0280 then tech_priests_radar_draw_scaled_overlay_0280(player_state, player, pair, radius) end
  tech_priests_radar_draw_phosphor_trail_0283(player_state, player, station, center, radius, angle)

  local old_line = player_state.line
  local old_cap = player_state.endcap
  local line_ttl = math.max(TECH_PRIESTS_RADAR_LINE_TTL_0278 or 12, 18)
  local ok_line, line = pcall(function()
    return rendering.draw_line({
      color = { r = 0.20, g = 1.0, b = 0.22, a = 0.46 },
      width = 2,
      from = { entity = station, offset = { 0, -0.18 } },
      to = edge,
      surface = station.surface,
      players = { player },
      time_to_live = line_ttl
    })
  end)

  local ok_cap, cap = pcall(function()
    return rendering.draw_circle({
      color = { r = 0.55, g = 1.0, b = 0.55, a = 0.48 },
      radius = 0.14,
      filled = true,
      target = edge,
      surface = station.surface,
      players = { player },
      time_to_live = line_ttl
    })
  end)

  if ok_line and line then
    if old_line then tech_priests_radar_destroy_object_0278(old_line) end
    player_state.line = line
  else
    player_state.line = old_line
  end
  if ok_cap and cap then
    if old_cap then tech_priests_radar_destroy_object_0278(old_cap) end
    player_state.endcap = cap
  else
    player_state.endcap = old_cap
  end
  player_state.station_unit = station.unit_number
  player_state.last_tick = game.tick
  radar.players[player.index] = player_state
end

-- Replace the 0.1.282 hit loop with the same detection behavior plus the hard
-- re-audit when the priest is crossed. This makes the sweep a real scheduler
-- refresh point instead of only a pretty green sermon arm.
tech_priests_radar_process_sweep_hits_pre_0283 = tech_priests_radar_process_sweep_hits_0278
function tech_priests_radar_process_sweep_hits_0278(player, pair, angle)
  local cache = tech_priests_radar_get_cache_0278(pair)
  if not cache then return end
  local station = pair.station
  local station_pos = station.position
  local flashed = 0

  for index = #cache.candidates, 1, -1 do
    local entity = cache.candidates[index]
    if not (entity and entity.valid) then
      table.remove(cache.candidates, index)
    else
      local entity_angle = tech_priests_radar_angle_0278(station_pos, entity.position)
      if tech_priests_radar_angle_delta_0278(angle, entity_angle) <= TECH_PRIESTS_RADAR_SWEEP_HALF_WIDTH_RADIANS_0278 then
        local info = tech_priests_radar_classify_entity_0278(pair, entity)
        if info then
          tech_priests_radar_remember_detection_0278(pair, entity, info)
          if info.kind == "priest" then
            tech_priests_radar_validate_priest_task_0278(pair)
            tech_priests_radar_hard_reaudit_pair_0283(pair, "radar-crossed-priest")
          elseif info.kind == "repair" or info.kind == "consecration" then
            tech_priests_radar_refresh_detected_task_0282(pair, entity, info)
          end
          if flashed < TECH_PRIESTS_RADAR_MAX_FLASHES_PER_STEP_0278 then
            tech_priests_radar_flash_entity_icon_0278(player, entity, info)
            flashed = flashed + 1
          end
        end
      end
    end
  end
end

if commands and commands.add_command then
  pcall(function()
    TechPriestsDebugCommandRegistry.add("tp-radar-0283", "Tech Priests: report Radar phosphor/reaudit state.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      if not (player and player.valid) then return end
      local pair = tech_priests_radar_get_hover_pair_0278 and tech_priests_radar_get_hover_pair_0278(player) or nil
      if not pair then player.print("No hovered Tech Priest station/priest pair found for Radar."); return end
      local sweep_ticks, sweep_seconds, rank = tech_priests_radar_sweep_ticks_for_pair_0279(pair)
      local task = pair.emergency_craft
      local cur = task and task.current or nil
      player.print("Radar 0.1.283 station#" .. tostring(pair.station_unit or (pair.station and pair.station.valid and pair.station.unit_number) or "?") ..
        " rank=" .. tostring(rank) ..
        " sweep=" .. tostring(sweep_seconds) .. "s" ..
        " mode=" .. tostring(pair.mode or "nil") ..
        " hard_audit=" .. tostring(pair.last_radar_hard_reaudit_reason_0283 or "none") ..
        " malformed=" .. tostring(pair.last_radar_hard_malformed_reason_0283 or "none") ..
        " craft=" .. tostring(task and (task.item_name or task.output_item or task.item) or "nil") ..
        " current=" .. tostring(tech_priests_radar_current_source_name_0283(cur) or "nil"))
    end)
  end)
end

if tech_priests_log then
  tech_priests_log("0.1.283 Radar phosphor trail, darkened scope field, timing retune, and hard task re-audit loaded")
end

-- ============================================================================
-- 0.1.284 - 0.1.286 cumulative scheduler cleanup rebuild
-- ============================================================================
-- This section intentionally rebuilds the missing 0.1.284/0.1.285/0.1.286
-- artifacts as one cumulative append-only layer from the last surfaced 0.1.283
-- package.  It adds recipe fan-out, a canonical active task ledger, and a
-- governor/reconciliation pass that keeps old behavior fields from fighting the
-- canonical task state.

TECH_PRIESTS_PATCH_0286 = "0.1.286-scheduler-governor-reconciliation-rebuild"
