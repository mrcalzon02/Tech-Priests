-- Auto-split control.lua fragment 008 for Tech Priests 0.1.438.
-- Generated mechanically from 0.1.437 monolithic control.lua.
-- Purpose: reduce Lua main-chunk local/register pressure without deleting behavior.


function tech_priests_record_player_context_0170(player, activity, entity)
  if not (player and player.valid and player.force) then return end
  tech_priests_ensure_player_awareness_storage_0170()
  local context = {
    tick = game.tick,
    player_index = player.index,
    player_name = player.name or ("Player " .. tostring(player.index)),
    force_name = player.force.name,
    surface_name = player.surface and player.surface.name or "unknown surface",
    activity = activity or "observed",
    entity_name = entity and entity.valid and entity.name or nil,
    entity_type = entity and entity.valid and entity.type or nil,
    entity_health = entity and entity.valid and entity.health or nil,
    entity_max_health = entity and entity.valid and entity.max_health or nil,
    entity_unit_number = entity and entity.valid and entity.unit_number or nil,
    entity_surface_name = entity and entity.valid and entity.surface and entity.surface.name or nil,
    entity_position = entity and entity.valid and { x = entity.position.x, y = entity.position.y } or nil
  }
  storage.tech_priests.last_player_context_by_player[player.index] = context
  storage.tech_priests.last_player_context_by_force[player.force.name] = context
end

tech_priests_original_on_selected_entity_changed_0170 = on_selected_entity_changed
function on_selected_entity_changed(event)
  if tech_priests_original_on_selected_entity_changed_0170 then
    tech_priests_original_on_selected_entity_changed_0170(event)
  end
  local player = event and game.get_player(event.player_index)
  if player and player.valid then
    tech_priests_record_player_context_0170(player, player.selected and "inspected" or "looked away", player.selected)
  end
end
TechPriestsRuntimeEventRegistry.on_event(defines.events.on_selected_entity_changed, on_selected_entity_changed)

function tech_priests_register_high_fabricator_command_0170()
  if not (commands and commands.add_command) then return end
  TechPriestsDebugCommandRegistry.add(TECH_PRIESTS_HIGH_FABRICATOR_COMMAND_0170, "Designate the High Fabricator for Tech-Priest address doctrine. Usage: /tech-priests-high-fabricator [player-name]", function(command)
    tech_priests_ensure_player_awareness_storage_0170()
    local caller = command and command.player_index and game.get_player(command.player_index) or nil
    local target = nil
    if command and command.parameter and command.parameter ~= "" then
      target = game.get_player(command.parameter)
      if not target then
        for _, candidate in pairs(game.players) do
          if candidate and candidate.valid and string.lower(candidate.name or "") == string.lower(command.parameter) then
            target = candidate
            break
          end
        end
      end
    elseif caller then
      target = caller
    end
    if not (target and target.valid) then
      if caller then caller.print("Tech-Priests: High Fabricator designation failed. Player not found.") end
      return
    end
    storage.tech_priests.high_fabricator_player_index = target.index
    local message = "Tech-Priests: " .. target.name .. " is now addressed as High Fabricator."
    if caller then caller.print(message) else log(message) end
  end)
end
tech_priests_register_high_fabricator_command_0170()

function tech_priests_get_player_title_0170(player)
  if not (player and player.valid) then return "Archmagos" end
  tech_priests_ensure_player_awareness_storage_0170()
  if not tech_priests_is_multiplayer_0170() then
    return "High Fabricator"
  end
  if storage.tech_priests.high_fabricator_player_index and storage.tech_priests.high_fabricator_player_index == player.index then
    return "High Fabricator"
  end
  return "Archmagos"
end

function tech_priests_format_player_address_0170(player)
  if not (player and player.valid) then return "Archmagos Unknown" end
  return tech_priests_get_player_title_0170(player) .. " " .. (player.name or tostring(player.index))
end

function tech_priests_force_current_research_name_0170(force)
  if not (force and force.valid) then return nil end
  local ok, research = pcall(function() return force.current_research end)
  if ok and research then
    if type(research) == "string" then return research end
    if research.name then return research.name end
  end
  return nil
end

function tech_priests_get_planet_name_0170(surface)
  if not surface then return "this questionable world" end
  if surface.planet and surface.planet.name then return surface.planet.name end
  return surface.name or "this questionable world"
end

function tech_priests_choose_player_for_pair_0170(pair)
  if not (pair and pair.priest and pair.priest.valid) then return nil, nil end
  tech_priests_ensure_player_awareness_storage_0170()
  local force = pair.priest.force
  local surface = pair.priest.surface
  local best_player = nil
  local best_distance_sq = nil
  for _, player in pairs(game.connected_players) do
    if player and player.valid and player.force == force and player.surface == surface and player.character and player.character.valid then
      local dx = player.position.x - pair.priest.position.x
      local dy = player.position.y - pair.priest.position.y
      local d2 = dx * dx + dy * dy
      if d2 <= TECH_PRIESTS_PLAYER_CONTEXT_RADIUS_SQ_0170 and (not best_distance_sq or d2 < best_distance_sq) then
        best_player = player
        best_distance_sq = d2
      end
    end
  end
  if best_player then
    local context = storage.tech_priests.last_player_context_by_player[best_player.index]
    return best_player, context
  end
  if force and force.valid then
    local context = storage.tech_priests.last_player_context_by_force[force.name]
    if context and context.player_index and game.tick - (context.tick or 0) <= TECH_PRIESTS_PLAYER_CONTEXT_MAX_AGE_TICKS_0170 then
      local player = game.get_player(context.player_index)
      if player and player.valid then return player, context end
    end
  end
  return nil, nil
end

function tech_priests_classify_player_context_0170(context)
  if not context then return "question" end
  if context.entity_health and context.entity_max_health and context.entity_max_health > 0 then
    local ratio = context.entity_health / context.entity_max_health
    if ratio < 0.45 then return "condemnation" end
    if ratio < 0.85 then return "question" end
  end
  if context.entity_type == "lab" or context.activity == "inspected" then return "question" end
  return "praise"
end

function tech_priests_build_player_topic_context_0170(pair, player, context)
  local force = pair and pair.priest and pair.priest.valid and pair.priest.force or (player and player.force)
  local surface = (player and player.valid and player.surface) or (pair and pair.priest and pair.priest.valid and pair.priest.surface)
  local current_research = tech_priests_force_current_research_name_0170(force)
  local last_research = tech_priests_get_last_researched_technology_0167(force)
  local tech_for_icon = current_research or last_research
  local planet = tech_priests_get_planet_name_0170(surface)
  local entity_name = context and context.entity_name or nil
  local entity_icon = entity_name and ("[entity=" .. tostring(entity_name) .. "]") or ""
  local tech_icon = tech_for_icon and ("[technology=" .. tostring(tech_for_icon) .. "]") or ""
  return {
    force = force,
    surface = surface,
    planet = planet,
    current_research = current_research,
    last_research = last_research,
    tech_for_icon = tech_for_icon,
    tech_icon = tech_icon,
    entity_name = entity_name,
    entity_type = context and context.entity_type or nil,
    entity_icon = entity_icon,
    activity = context and context.activity or "observed",
    tone = tech_priests_classify_player_context_0170(context)
  }
end

function tech_priests_player_listener_response_0170(listener_rank, address, ctx)
  if listener_rank == "senior" then
    local lines = {
      "Agreed. " .. address .. " bends the factory toward consequence, but consequence still requires audit.",
      "A fair reading. On " .. ctx.planet .. ", even divine intent should be tested before celebration.",
      "Caution: praise and condemnation both require reproducible evidence, preferably before the smoke clears."
    }
    return lines[((game.tick + #address) % #lines) + 1]
  elseif listener_rank == "intermediate" then
    local lines = {
      "Clarification requested: should we prioritize the observed object or the active research chain?",
      "I understand the address doctrine, but the factory context remains unstable.",
      "Noted. I will correlate " .. (ctx.entity_icon ~= "" and ctx.entity_icon or "the recent object") .. " with current operational risk."
    }
    return lines[((game.tick + #address) % #lines) + 1]
  else
    local lines = {
      "Acknowledged. " .. address .. " is observed.",
      "Obedience maintained. Player intent accepted.",
      "The command presence is noted. Confusion suppressed."
    }
    return lines[((game.tick + #address) % #lines) + 1]
  end
end

function tech_priests_choose_player_address_lines_0170(speaker_pair, listener_pair)
  local player, context = tech_priests_choose_player_for_pair_0170(speaker_pair)
  if not (player and player.valid) then return nil end
  local address = tech_priests_format_player_address_0170(player)
  local speaker_rank = get_pair_rank and get_pair_rank(speaker_pair) or "junior"
  local listener_rank = get_pair_rank and get_pair_rank(listener_pair) or "junior"
  local ctx = tech_priests_build_player_topic_context_0170(speaker_pair, player, context)
  local line = nil

  if ctx.tone == "condemnation" then
    if speaker_rank == "senior" then
      line = address .. ", " .. ctx.entity_icon .. " has suffered neglect visible from the litany deck. Shall we call this testing, or merely supervision by optimism?"
    elseif speaker_rank == "intermediate" then
      line = address .. ", the recent state of " .. (ctx.entity_icon ~= "" and ctx.entity_icon or "the inspected machinery") .. " suggests a maintenance debt with teeth. Permission to worry formally?"
    else
      line = address .. ", damaged machine observed. I am not accusing. I am only shaking slightly."
    end
  elseif ctx.current_research then
    if speaker_rank == "senior" then
      line = ctx.tech_icon .. " " .. address .. ", the priesthood observes active research while stationed upon " .. ctx.planet .. ". Is this doctrine, ambition, or a cleverly dressed emergency?"
    elseif speaker_rank == "intermediate" then
      line = ctx.tech_icon .. " " .. address .. ", current research is reshaping local procedure. Should we prepare inventory doctrine before the machines notice?"
    else
      line = ctx.tech_icon .. " " .. address .. ", research continues. I do not understand it, but I am proud to be confused near it."
    end
  elseif ctx.entity_name then
    if speaker_rank == "senior" then
      line = address .. ", your attention upon " .. ctx.entity_icon .. " has been logged. Is this inspection, intervention, or the beginning of another beautiful administrative wound?"
    elseif speaker_rank == "intermediate" then
      line = address .. ", I observed recent focus on " .. ctx.entity_icon .. ". Should this object receive priority rites?"
    else
      line = address .. ", I saw the object. I await permission to understand it."
    end
  elseif ctx.last_research then
    if speaker_rank == "senior" then
      line = ctx.tech_icon .. " " .. address .. ", the last doctrine researched still echoes through the factory. Praise is available, pending casualties."
    elseif speaker_rank == "intermediate" then
      line = ctx.tech_icon .. " " .. address .. ", the previous research has practical implications. I request thresholds before implementation becomes folklore."
    else
      line = ctx.tech_icon .. " " .. address .. ", research remembered. Obedience refreshed."
    end
  else
    line = address .. ", the priesthood acknowledges command presence upon " .. ctx.planet .. ". Guidance, praise, or condemnation may now be issued in any order."
  end

  return {
    topic = "__player_address_context__",
    tech_name = ctx.tech_for_icon,
    speaker_line = line,
    response_line = tech_priests_player_listener_response_0170(listener_rank, address, ctx)
  }
end

tech_priests_original_choose_conversation_lines_0170 = tech_priests_choose_conversation_lines_0167
function tech_priests_choose_conversation_lines_0167(speaker_pair, listener_pair)
  local force = speaker_pair and speaker_pair.priest and speaker_pair.priest.valid and speaker_pair.priest.force or nil
  local enable_player_address = true
  if enable_player_address then
    local roll = ((game.tick + (speaker_pair.station_unit or 0) * 17 + (listener_pair.station_unit or 0) * 7) % 100)
    if roll < TECH_PRIESTS_PLAYER_ADDRESS_CHANCE_PERCENT_0170 then
      local chosen = tech_priests_choose_player_address_lines_0170(speaker_pair, listener_pair)
      if chosen then return chosen end
    end
  end
  return tech_priests_original_choose_conversation_lines_0170(speaker_pair, listener_pair)
end


-- 0.1.173 supplied-station search interrupt:
-- If a Tech-Priest is searching local inventories, scavenging, waiting to
-- scavenge, or emergency-fabricating an item, and that exact needed supply is
-- inserted into the Cogitator Station meanwhile, immediately abandon the search.
-- The existing station request icon remains active while the item is missing,
-- then clears as soon as the station inventory satisfies the request.

function tech_priests_get_active_search_request_0173(pair)
  if not pair then return nil end
  if pair.inventory_scan and pair.inventory_scan.kind == "scavenge" then
    return pair.inventory_scan.request or pair.active_supply_request
  end
  if pair.scavenge then
    return pair.scavenge.request or pair.active_supply_request
  end
  if pair.emergency_craft then
    return pair.emergency_craft.request or pair.active_supply_request
  end
  local mode = pair.mode or ""
  if mode == "logistics-scavenge-countdown" or mode == "logistics-no-network" or mode == "awaiting-logistics" or mode == "logistics-requested" then
    return pair.active_supply_request
  end
  return nil
end

function tech_priests_station_inventory_has_requested_supply_0173(pair, request)
  if not (pair and pair.station and pair.station.valid and request) then return nil end
  local inventory = get_station_inventory and get_station_inventory(pair.station) or nil
  if not inventory then return nil end

  if request.kind == "ammo" then
    for index = 1, #inventory do
      local stack = inventory[index]
      if stack and stack.valid_for_read and is_ammo_item and is_ammo_item(stack.name) then
        return stack.name
      end
    end
    return nil
  end

  for _, candidate in pairs(request.candidates or {}) do
    if candidate and candidate.name and inventory.get_item_count(candidate.name) > 0 then
      return candidate.name
    end
  end

  -- Last-resort compatibility: if a later request builder only recorded a
  -- representative item on the pair, honor that visible station request too.
  if pair.logistic_requested_item and pair.logistic_requested_item ~= "" and inventory.get_item_count(pair.logistic_requested_item) > 0 then
    return pair.logistic_requested_item
  end

  return nil
end

function tech_priests_clear_supply_search_because_station_was_supplied_0173(pair, supplied_item)
  if not pair then return false end

  if clear_logistic_inventory_scan then clear_logistic_inventory_scan(pair) end
  pair.inventory_scan = nil
  pair.scavenge = nil
  pair.emergency_craft = nil
  pair.next_scavenge_search_tick = nil
  pair.scan_line_render = nil

  -- Keep cram-mode separate: cram searches are disposal behavior, not a missing
  -- item search. Do not clear cram here.

  local request = pair.active_supply_request
  local target = request and request.target and request.target.valid and request.target or nil
  pair.active_supply_request = nil
  pair.logistic_requested_item = nil
  pair.logistic_requested_count = nil
  if clear_logistic_frustration then clear_logistic_frustration(pair) end

  if target then
    pair.target = target
    if request.kind == "repair" then
      pair.mode = "moving-to-repair"
      if pair.priest and pair.priest.valid then move_priest_to(pair.priest, target) end
    elseif request.kind == "consecration" then
      pair.mode = "moving-to-consecrate"
      if pair.priest and pair.priest.valid then move_priest_to(pair.priest, target) end
    else
      pair.mode = "returning"
      if pair.priest and pair.priest.valid and pair.station and pair.station.valid then return_to_station(pair.priest, pair.station) end
    end
  else
    pair.target = nil
    pair.mode = "returning"
    if pair.priest and pair.priest.valid and pair.station and pair.station.valid then return_to_station(pair.priest, pair.station) end
  end

  if clear_station_request_icon then clear_station_request_icon(pair) end

  -- Tiny acknowledgement over the station so the interruption is visible but not
  -- spammy. The normal priest/status bubbles will take over on the next cycle.
  if draw_priest_status_text and pair.station and pair.station.valid and supplied_item then
    draw_priest_status_text({
      text = "[item=" .. tostring(supplied_item) .. "] received",
      target = { entity = pair.station, offset = { 0, -3.15 } },
      surface = pair.station.surface,
      color = { r = 0.35, g = 1.00, b = 0.35, a = 0.95 },
      scale = 0.95,
      alignment = "center",
      time_to_live = 90
    })
  end

  return true
end

function tech_priests_interrupt_supply_search_if_station_supplied_0173(pair)
  local request = tech_priests_get_active_search_request_0173(pair)
  if not request then return false end
  local supplied_item = tech_priests_station_inventory_has_requested_supply_0173(pair, request)
  if not supplied_item then return false end
  return tech_priests_clear_supply_search_because_station_was_supplied_0173(pair, supplied_item)
end

tech_priests_original_tick_pair_0173 = tick_pair
function tick_pair(pair)
  if tech_priests_interrupt_supply_search_if_station_supplied_0173(pair) then return end
  return tech_priests_original_tick_pair_0173(pair)
end

tech_priests_original_should_show_station_request_icon_0173 = should_show_station_request_icon
function should_show_station_request_icon(pair)
  local request = tech_priests_get_active_search_request_0173(pair)
  if request and tech_priests_station_inventory_has_requested_supply_0173(pair, request) then
    return false
  end
  return tech_priests_original_should_show_station_request_icon_0173(pair)
end


-- 0.1.174 cram-disposal emptied-station interrupt:
-- If a Tech-Priest is trying to clear station clutter by finding somewhere to
-- put an unwanted item, and the player/logistics/another system removes that
-- item from the Cogitator Station first, immediately abandon the cram task.
-- This is intentionally separate from the 0.1.173 supplied-item interrupt:
-- supplied-item searches are about getting a needed item; cram is about making
-- room by disposing of station clutter.

function tech_priests_get_active_cram_item_0174(pair)
  if not pair then return nil end

  if pair.inventory_scan and pair.inventory_scan.kind == "cram" then
    local item = pair.inventory_scan.item
    if item and item.name then
      return { name = item.name, quality = item.quality }
    end
    local item_name = pair.inventory_scan.item_name
    if item_name and item_name ~= "" then
      return { name = item_name }
    end
  end

  if pair.cram and not pair.cram.scanning then
    local item_name = pair.cram.item_name
    if item_name and item_name ~= "" then
      return { name = item_name, quality = pair.cram.quality }
    end
  end

  return nil
end

function tech_priests_station_inventory_has_cram_item_0174(pair, item)
  if not (pair and pair.station and pair.station.valid and item and item.name) then return false end
  local inventory = get_station_inventory and get_station_inventory(pair.station) or nil
  if not inventory then return false end

  for index = 1, #inventory do
    local stack = inventory[index]
    if stack and stack.valid_for_read and stack.name == item.name then
      if not item.quality or item.quality == "" or not get_stack_quality_name or get_stack_quality_name(stack) == item.quality then
        return true
      end
    end
  end

  return false
end

function tech_priests_clear_cram_search_because_station_was_emptied_0174(pair, item)
  if not pair then return false end

  if clear_logistic_inventory_scan then clear_logistic_inventory_scan(pair) end
  pair.inventory_scan = nil
  pair.cram = nil
  pair.next_cram_search_tick = nil
  pair.cram_search_started_tick = nil
  pair.cram_dump_due_tick = nil
  pair.logistic_cram_start_tick = nil
  pair.logistic_cram_due_tick = nil
  pair.target = nil
  pair.mode = "returning"

  if pair.priest and pair.priest.valid and pair.station and pair.station.valid then
    return_to_station(pair.priest, pair.station)
  end

  if draw_priest_status_text and pair.station and pair.station.valid then
    local text = "station cleared"
    if item and item.name then text = "[item=" .. tostring(item.name) .. "] disposal cancelled" end
    draw_priest_status_text({
      text = text,
      target = { entity = pair.station, offset = { 0, -3.15 } },
      surface = pair.station.surface,
      color = { r = 1.00, g = 0.70, b = 0.20, a = 0.95 },
      scale = 0.95,
      alignment = "center",
      time_to_live = 90
    })
  end

  return true
end

function tech_priests_interrupt_cram_if_station_item_removed_0174(pair)
  if not pair then return false end
  if not ((pair.inventory_scan and pair.inventory_scan.kind == "cram") or pair.cram) then return false end

  local item = tech_priests_get_active_cram_item_0174(pair)
  if not item or not item.name then
    return false
  end

  if tech_priests_station_inventory_has_cram_item_0174(pair, item) then
    return false
  end

  return tech_priests_clear_cram_search_because_station_was_emptied_0174(pair, item)
end

tech_priests_original_handle_logistic_inventory_scan_0174 = handle_logistic_inventory_scan
function handle_logistic_inventory_scan(pair)
  if tech_priests_interrupt_cram_if_station_item_removed_0174(pair) then return true end
  return tech_priests_original_handle_logistic_inventory_scan_0174(pair)
end

tech_priests_original_handle_priest_cram_task_0174 = handle_priest_cram_task
function handle_priest_cram_task(pair)
  if tech_priests_interrupt_cram_if_station_item_removed_0174(pair) then return true end
  return tech_priests_original_handle_priest_cram_task_0174(pair)
end

tech_priests_original_tick_pair_0174 = tick_pair
function tick_pair(pair)
  if tech_priests_interrupt_cram_if_station_item_removed_0174(pair) then return end
  return tech_priests_original_tick_pair_0174(pair)
end


-- 0.1.176 spawn-tile memory and stuck-behavior watchdog pass:
-- * Tech-Priest spawn/recall now uses a remembered, validated spawn tile.
-- * The spawn tile is searched from the Cogitator Station outward, rejecting empty space, damaging-looking terrain, and non-pathable locations.
-- * Station hover debug rendering now shows the remembered spawn tile and an operation-radius circle centered on that tile.
-- * Long-running nonproductive behavior modes now have conservative watchdog timeouts that cancel the task and return the priest to station doctrine.

TECH_PRIESTS_SPAWN_SEARCH_STEP_0176 = 1
TECH_PRIESTS_SPAWN_MARKER_TTL_0176 = 90
TECH_PRIESTS_STUCK_WATCHDOG_CHECK_TICKS_0176 = 30
TECH_PRIESTS_DEFAULT_STUCK_TIMEOUT_TICKS_0176 = 60 * 120
TECH_PRIESTS_STUCK_TIMEOUTS_0176 = {
  ["moving-to-scavenge"] = 60 * 45,
  ["moving-to-cram"] = 60 * 45,
  ["moving-to-repair"] = 60 * 60,
  ["moving-to-consecrate"] = 60 * 60,
  ["moving-to-combat"] = 60 * 45,
  ["logistics-requested"] = 60 * 90,
  ["logistics-scavenge-countdown"] = 60 * 90,
  ["logistics-cram-countdown"] = 60 * 90,
  ["logistics-clearing-space"] = 60 * 75,
  ["logistics-no-network"] = 60 * 90,
  ["scavenging-supplies"] = 60 * 90,
  ["cramming-supplies"] = 60 * 90,
  ["emergency-gathering"] = 60 * 150,
  ["emergency-crafting"] = 60 * 150,
  ["awaiting-logistics"] = 60 * 120,
  ["missing-repair-supplies"] = 60 * 120,
  ["missing-consecration-supplies"] = 60 * 120,
  ["missing-ammo-supplies"] = 60 * 120,
  ["repair-waiting-usefulness"] = 60 * 180,
  ["consecrate-waiting-usefulness"] = 60 * 180,
  ["returning"] = 60 * 60,
  ["deploying"] = 60 * 45,
  ["idle-conversation"] = 60 * 25
}

function tech_priests_ensure_spawn_memory_storage_0176()
  ensure_storage()
  storage.tech_priests.spawn_positions_by_station = storage.tech_priests.spawn_positions_by_station or {}
  storage.tech_priests.spawn_marker_rendering_by_player = storage.tech_priests.spawn_marker_rendering_by_player or {}
end

function tech_priests_round_tile_center_0176(position)
  if not position then return nil end
  return { x = math.floor(position.x) + 0.5, y = math.floor(position.y) + 0.5 }
end

function tech_priests_is_tile_non_damaging_spawn_candidate_0176(surface, position)
  if not (surface and position) then return false end
  local ok_tile, tile = pcall(function() return surface.get_tile(position) end)
  if not (ok_tile and tile and tile.valid) then return false end
  local name = tostring(tile.name or "")
  local lower = string.lower(name)
  -- Space Age orbital surfaces can contain literal empty-space/out-of-map void tiles. A priest cannot deploy into a hole in reality.
  if string.find(lower, "empty%-space", 1, false) or string.find(lower, "out%-of%-map", 1, false) or lower == "empty-space" then return false end
  -- Avoid obvious environmental hazard tiles without relying on optional prototype fields that differ by Factorio version/mod stack.
  if string.find(lower, "lava", 1, true) or string.find(lower, "acid", 1, true) or string.find(lower, "hot", 1, true) then return false end
  local proto = tile.prototype
  if proto then
    local ok_speed, speed = pcall(function() return proto.walking_speed_modifier end)
    if ok_speed and speed and speed <= 0 then return false end
    local ok_collision, collides = pcall(function()
      if tile.collides_with then return tile.collides_with("player-layer") end
      return false
    end)
    if ok_collision and collides then return false end
  end
  return true
end

function tech_priests_can_spawn_at_tile_0176(station, priest_name, position)
  if not (station and station.valid and priest_name and position) then return false end
  if not tech_priests_is_tile_non_damaging_spawn_candidate_0176(station.surface, position) then return false end
  local ok_place, can_place = pcall(function()
    return station.surface.can_place_entity({ name = priest_name, position = position, force = station.force })
  end)
  return ok_place and can_place or false
end

function tech_priests_spawn_position_within_station_radius_0176(station, position)
  if not (station and station.valid and position) then return false end
  local radius = get_station_operating_radius(station)
  local dx = position.x - station.position.x
  local dy = position.y - station.position.y
  return dx * dx + dy * dy <= radius * radius
end

function tech_priests_get_remembered_spawn_position_0176(station)
  tech_priests_ensure_spawn_memory_storage_0176()
  local key = station and station.valid and station.unit_number
  if not key then return nil end
  local stored = storage.tech_priests.spawn_positions_by_station[key]
  if stored and stored.x and stored.y then return { x = stored.x, y = stored.y } end
  return nil
end

function tech_priests_set_remembered_spawn_position_0176(station, position)
  tech_priests_ensure_spawn_memory_storage_0176()
  local key = station and station.valid and station.unit_number
  if not (key and position) then return end
  local centered = tech_priests_round_tile_center_0176(position) or position
  storage.tech_priests.spawn_positions_by_station[key] = { x = centered.x, y = centered.y, surface_index = station.surface.index, tick = game and game.tick or 0 }
  local pair = storage.tech_priests.pairs_by_station and storage.tech_priests.pairs_by_station[key]
  if pair then pair.spawn_position = { x = centered.x, y = centered.y } end
end

function tech_priests_find_closest_spawn_tile_0176(station, priest_name)
  if not (station and station.valid and priest_name) then return nil end
  local radius = math.max(1, math.floor(get_station_operating_radius(station)))
  local base = tech_priests_round_tile_center_0176(station.position)
  local best = nil
  local best_dist = nil

  -- Search exact tile centers from the station outward. This intentionally prefers the closest legal tile to the station over the old deployment-vector preference.
  for ring = 0, radius do
    for dx = -ring, ring do
      for dy = -ring, ring do
        if math.max(math.abs(dx), math.abs(dy)) == ring then
          local position = { x = base.x + dx, y = base.y + dy }
          local ddx = position.x - station.position.x
          local ddy = position.y - station.position.y
          local dist = ddx * ddx + ddy * ddy
          if dist <= radius * radius and tech_priests_can_spawn_at_tile_0176(station, priest_name, position) then
            if not best_dist or dist < best_dist then
              best = position
              best_dist = dist
            end
          end
        end
      end
    end
    if best then return best end
  end
  return nil
end

tech_priests_original_find_spawn_position_0176 = find_spawn_position
function find_spawn_position(station, priest_name)
  if not (station and station.valid and priest_name) then return nil end
  tech_priests_ensure_spawn_memory_storage_0176()

  local remembered = tech_priests_get_remembered_spawn_position_0176(station)
  if remembered and tech_priests_spawn_position_within_station_radius_0176(station, remembered) and tech_priests_can_spawn_at_tile_0176(station, priest_name, remembered) then
    return remembered
  end

  local selected = tech_priests_find_closest_spawn_tile_0176(station, priest_name)
  if selected then
    tech_priests_set_remembered_spawn_position_0176(station, selected)
    return selected
  end

  -- Keep the old fallback as a last resort, but only accept it if it is still inside station range and on a valid non-damaging tile.
  local fallback = tech_priests_original_find_spawn_position_0176 and tech_priests_original_find_spawn_position_0176(station, priest_name) or nil
  if fallback and tech_priests_spawn_position_within_station_radius_0176(station, fallback) and tech_priests_can_spawn_at_tile_0176(station, priest_name, fallback) then
    fallback = tech_priests_round_tile_center_0176(fallback) or fallback
    tech_priests_set_remembered_spawn_position_0176(station, fallback)
    return fallback
  end

  return nil
end

tech_priests_original_create_pair_0176 = create_pair
function create_pair(station)
  local result = tech_priests_original_create_pair_0176(station)
  if station and station.valid and storage and storage.tech_priests and storage.tech_priests.pairs_by_station then
    local pair = storage.tech_priests.pairs_by_station[station.unit_number]
    local stored = tech_priests_get_remembered_spawn_position_0176(station)
    if pair and stored then pair.spawn_position = { x = stored.x, y = stored.y } end
  end
  return result
end

tech_priests_original_respawn_pair_priest_0176 = respawn_pair_priest
function respawn_pair_priest(pair, reason)
  -- Force validation before each recall/deployment. If the remembered tile was blocked, paved into hazard, or became orbital void, find_spawn_position will replace it.
  if pair and pair.station and pair.station.valid then
    local config = get_station_config(pair.station)
    local priest_name = get_priest_name_for_force(config, pair.station.force)
    if priest_name then
      local remembered = tech_priests_get_remembered_spawn_position_0176(pair.station)
      if not (remembered and tech_priests_spawn_position_within_station_radius_0176(pair.station, remembered) and tech_priests_can_spawn_at_tile_0176(pair.station, priest_name, remembered)) then
        storage.tech_priests.spawn_positions_by_station[pair.station.unit_number] = nil
        pair.spawn_position = nil
        local replacement = tech_priests_find_closest_spawn_tile_0176(pair.station, priest_name)
        if replacement then tech_priests_set_remembered_spawn_position_0176(pair.station, replacement) end
      end
    end
  end
  local ok = tech_priests_original_respawn_pair_priest_0176(pair, reason)
  if ok and pair and pair.station and pair.station.valid then
    local stored = tech_priests_get_remembered_spawn_position_0176(pair.station)
    if stored then pair.spawn_position = { x = stored.x, y = stored.y } end
  end
  return ok
end

function tech_priests_clear_spawn_marker_rendering_0176(player_index)
  tech_priests_ensure_spawn_memory_storage_0176()
  local bucket = storage.tech_priests.spawn_marker_rendering_by_player[player_index]
  if bucket then
    for _, object in pairs(bucket) do destroy_render_object(object) end
  end
  storage.tech_priests.spawn_marker_rendering_by_player[player_index] = nil
end

function tech_priests_draw_spawn_marker_for_player_0176(player, pair)
  if not (player and player.valid and pair and pair.station and pair.station.valid) then return end
  tech_priests_clear_spawn_marker_rendering_0176(player.index)
  local station = pair.station
  local config = get_station_config(station)
  local priest_name = get_priest_name_for_force(config, station.force)
  if not priest_name then return end
  local spawn_position = tech_priests_get_remembered_spawn_position_0176(station)
  if not (spawn_position and tech_priests_spawn_position_within_station_radius_0176(station, spawn_position) and tech_priests_can_spawn_at_tile_0176(station, priest_name, spawn_position)) then
    spawn_position = tech_priests_find_closest_spawn_tile_0176(station, priest_name)
    if spawn_position then tech_priests_set_remembered_spawn_position_0176(station, spawn_position) end
  end
  if not spawn_position then return end

  local renders = {}
  -- 0.1.213: Removed the large station-radius debug circle from the spawn-locus overlay; keep only the locus ring/text.

  local ok_inner, inner = pcall(function()
    return rendering.draw_circle({
      color = { r = 0.20, g = 0.95, b = 1.00, a = 0.72 },
      radius = 0.42,
      width = 4,
      filled = false,
      target = spawn_position,
      surface = station.surface,
      draw_on_ground = true,
      players = { player },
      time_to_live = TECH_PRIESTS_SPAWN_MARKER_TTL_0176
    })
  end)
  if ok_inner and inner then table.insert(renders, inner) end

  local ok_text, text = pcall(function()
    return rendering.draw_text({
      text = "⊕ Tech-Priest spawn locus",
      target = { x = spawn_position.x, y = spawn_position.y - 0.85 },
      surface = station.surface,
      color = { r = 0.65, g = 0.95, b = 1.00, a = 0.95 },
      scale = 0.70,
      alignment = "center",
      players = { player },
      time_to_live = TECH_PRIESTS_SPAWN_MARKER_TTL_0176
    })
  end)
  if ok_text and text then table.insert(renders, text) end

  storage.tech_priests.spawn_marker_rendering_by_player[player.index] = renders
end

tech_priests_original_clear_radius_rendering_0176 = clear_radius_rendering
function clear_radius_rendering(player_index)
  if tech_priests_original_clear_radius_rendering_0176 then tech_priests_original_clear_radius_rendering_0176(player_index) end
  tech_priests_clear_spawn_marker_rendering_0176(player_index)
end

tech_priests_original_draw_station_radius_for_player_0176 = draw_station_radius_for_player
function draw_station_radius_for_player(player)
  if tech_priests_original_draw_station_radius_for_player_0176 then tech_priests_original_draw_station_radius_for_player_0176(player) end
  if not (player and player.valid and player.selected) then return end
  local pair = nil
  if is_station(player.selected) or is_priest(player.selected) then
    pair = find_pair_for_entity and find_pair_for_entity(player.selected) or nil
  end
  if pair then tech_priests_draw_spawn_marker_for_player_0176(player, pair) end
end

function tech_priests_clear_activity_for_watchdog_0176(pair)
  if not pair then return end
  if stop_idle_scan then stop_idle_scan(pair) end
  if tech_priests_stop_idle_conversation_0167 then tech_priests_stop_idle_conversation_0167(pair) end
  if clear_logistic_inventory_scan then clear_logistic_inventory_scan(pair) end
  pair.inventory_scan = nil
  pair.scavenge = nil
  pair.cram = nil
  pair.emergency_craft = nil
  pair.target = nil
  pair.combat_target = nil
  pair.logistic_request = nil
  pair.logistic_request_item = nil
  pair.logistic_request_quality = nil
  pair.logistic_request_count = nil
  pair.logistic_request_started_tick = nil
  pair.logistic_scavenge_due_tick = nil
  pair.logistic_cram_due_tick = nil
  pair.logistic_frustration_due_tick = nil
  pair.cram_dump_due_tick = nil
  pair.scavenge_pickup_due_tick = nil
end

function tech_priests_get_mode_timeout_0176(mode)
  if not mode or mode == "" or mode == "idle" then return nil end
  return TECH_PRIESTS_STUCK_TIMEOUTS_0176[mode] or TECH_PRIESTS_DEFAULT_STUCK_TIMEOUT_TICKS_0176
end

function tech_priests_watchdog_allows_mode_0176(pair, mode)
  -- Do not break active combat or direct repair/consecration once the priest is actually performing the useful work.
  if mode == "defending" or mode == "repairing" or mode == "consecrating" then return false end
  return true
end

function tech_priests_activity_watchdog_0176(pair)
  if not (pair and pair.station and pair.station.valid) then return false end
  local mode = pair.mode or "idle"
  if pair.watchdog_mode_0176 ~= mode then
    pair.watchdog_mode_0176 = mode
    pair.watchdog_mode_started_tick_0176 = game.tick
    pair.watchdog_last_check_tick_0176 = game.tick
    return false
  end
  if game.tick < (pair.watchdog_last_check_tick_0176 or 0) + TECH_PRIESTS_STUCK_WATCHDOG_CHECK_TICKS_0176 then return false end
  pair.watchdog_last_check_tick_0176 = game.tick
  local timeout = tech_priests_get_mode_timeout_0176(mode)
  if not timeout then return false end
  if not tech_priests_watchdog_allows_mode_0176(pair, mode) then return false end
  local started = pair.watchdog_mode_started_tick_0176 or game.tick
  if game.tick - started < timeout then return false end

  local old_mode = mode
  tech_priests_clear_activity_for_watchdog_0176(pair)
  pair.mode = "returning"
  pair.watchdog_mode_0176 = "returning"
  pair.watchdog_mode_started_tick_0176 = game.tick
  if pair.priest and pair.priest.valid and pair.station and pair.station.valid then
    return_to_station(pair.priest, pair.station)
  end
  if draw_priest_status_text and pair.station and pair.station.valid then
    draw_priest_status_text({
      text = "activity timeout: " .. tostring(old_mode),
      target = { entity = pair.station, offset = { 0, -3.35 } },
      surface = pair.station.surface,
      color = { r = 1.00, g = 0.35, b = 0.20, a = 0.95 },
      scale = 0.78,
      alignment = "center",
      time_to_live = 120
    })
  end
  return true
end

tech_priests_original_tick_pair_0176 = tick_pair
function tick_pair(pair)
  if tech_priests_activity_watchdog_0176(pair) then return end
  tech_priests_original_tick_pair_0176(pair)
  tech_priests_activity_watchdog_0176(pair)
end


-- 0.1.177 base-game task sound mapping pass:
-- Adds a conservative audio layer for Tech-Priest behavior transitions.  The
-- sounds intentionally use utility/base-game candidates first and fall back
-- quietly if a path is absent in a given Factorio/mod build.  This is flavor
-- only; it does not alter repair, consecration, logistics, combat, or crafting
-- results.
TECH_PRIESTS_TASK_SOUND_DEFAULT_COOLDOWN_TICKS_0177 = 60 * 3
TECH_PRIESTS_TASK_SOUND_FAST_COOLDOWN_TICKS_0177 = 45
TECH_PRIESTS_TASK_SOUND_MODE_COOLDOWN_TICKS_0177 = 60 * 5

TECH_PRIESTS_TASK_SOUND_CANDIDATES_0177 = {
  deploy = { "utility/build_small", "utility/confirm" },
  recall = { "utility/console_message", "utility/confirm" },
  return_to_station = { "utility/armor_insert", "utility/confirm" },
  repair = { "utility/repair_pack", "utility/manual_repair", "utility/build_small", "utility/confirm" },
  consecrate = { "utility/armor_insert", "utility/build_small", "utility/confirm" },
  logistics_request = { "utility/wire_connect_pole", "utility/confirm" },
  logistics_wait = { "utility/cannot_build", "utility/confirm" },
  scan_scavenge = { "utility/wire_connect_pole", "utility/confirm" },
  scan_cram = { "utility/wire_disconnect", "utility/cannot_build", "utility/confirm" },
  scavenge_take = { "utility/inventory_move", "utility/armor_insert", "utility/confirm" },
  cram_deposit = { "utility/inventory_move", "utility/build_small", "utility/confirm" },
  cram_dump = { "utility/cannot_build", "utility/confirm" },
  emergency_scan_inventory = { "utility/wire_connect_pole", "utility/confirm" },
  emergency_scan_field = { "utility/wire_connect_pole", "utility/confirm" },
  emergency_take = { "utility/inventory_move", "utility/armor_insert", "utility/confirm" },
  emergency_craft = { "utility/build_small", "utility/confirm" },
  combat = { "utility/cannot_build", "utility/confirm" },
  idle_scan = { "utility/wire_connect_pole", "utility/confirm" },
  conversation_start = { "utility/console_message", "utility/confirm" },
  conversation_line = { "utility/console_message", "utility/confirm" },
  watchdog = { "utility/cannot_build", "utility/confirm" }
}

TECH_PRIESTS_MODE_SOUND_MAP_0177 = {
  ["moving-to-repair"] = "repair",
  ["repairing"] = "repair",
  ["moving-to-consecrate"] = "consecrate",
  ["consecrating"] = "consecrate",
  ["missing-repair-supplies"] = "logistics_wait",
  ["missing-consecration-supplies"] = "logistics_wait",
  ["missing-ammo-supplies"] = "logistics_wait",
  ["awaiting-logistics"] = "logistics_request",
  ["logistics-requested"] = "logistics_request",
  ["logistics-scavenge-countdown"] = "logistics_request",
  ["logistics-no-network"] = "logistics_wait",
  ["logistics-cram-countdown"] = "scan_cram",
  ["moving-to-scavenge"] = "scan_scavenge",
  ["scavenging-supplies"] = "scan_scavenge",
  ["moving-to-cram"] = "scan_cram",
  ["cramming-supplies"] = "scan_cram",
  ["moving-to-combat"] = "combat",
  ["defending"] = "combat",
  ["emergency-gathering"] = "emergency_scan_field",
  ["emergency-crafting"] = "emergency_craft",
  ["idle-conversation"] = "conversation_start",
  ["returning"] = "return_to_station",
  ["deploying"] = "deploy"
}

function tech_priests_task_sounds_enabled_0177()
  return read_global_bool_setting and read_global_bool_setting("tech-priests-enable-task-sounds", true)
end

function tech_priests_task_sound_volume_0177(multiplier)
  local percent = 70
  if settings and settings.global and settings.global["tech-priests-task-sound-volume-percent"] then
    percent = tonumber(settings.global["tech-priests-task-sound-volume-percent"].value) or percent
  end
  return math.max(0, math.min(1.5, (percent / 100) * (multiplier or 1)))
end

function tech_priests_pair_sound_position_0177(pair, fallback_position)
  if pair and pair.priest and pair.priest.valid then return pair.priest.position end
  if pair and pair.station and pair.station.valid then return pair.station.position end
  return fallback_position
end

function tech_priests_pair_sound_surface_0177(pair, fallback_surface)
  if pair and pair.priest and pair.priest.valid then return pair.priest.surface end
  if pair and pair.station and pair.station.valid then return pair.station.surface end
  return fallback_surface
end

function tech_priests_play_task_sound_0177(pair, sound_key, position, cooldown_ticks, volume_multiplier)
  if not tech_priests_task_sounds_enabled_0177() then return false end
  if not sound_key then return false end
  local surface = tech_priests_pair_sound_surface_0177(pair, nil)
  position = tech_priests_pair_sound_position_0177(pair, position)
  if not (surface and position) then return false end

  local tick = game and game.tick or 0
  cooldown_ticks = cooldown_ticks or TECH_PRIESTS_TASK_SOUND_DEFAULT_COOLDOWN_TICKS_0177
  if pair then
    pair.task_sound_next_tick_0177 = pair.task_sound_next_tick_0177 or {}
    local next_tick = pair.task_sound_next_tick_0177[sound_key] or 0
    if tick < next_tick then return false end
  end

  local candidates = TECH_PRIESTS_TASK_SOUND_CANDIDATES_0177[sound_key] or TECH_PRIESTS_TASK_SOUND_CANDIDATES_0177.logistics_request or { "utility/confirm" }
  local volume = tech_priests_task_sound_volume_0177(volume_multiplier or 0.55)
  if volume <= 0 then return false end

  for _, path in pairs(candidates) do
    local ok = pcall(function()
      surface.play_sound({ path = path, position = position, volume_modifier = volume })
    end)
    if ok then
      if pair then pair.task_sound_next_tick_0177[sound_key] = tick + cooldown_ticks end
      return true
    end
  end
  return false
end

function tech_priests_play_mode_transition_sound_0177(pair, mode)
  local sound_key = TECH_PRIESTS_MODE_SOUND_MAP_0177[mode or ""]
  if not sound_key then return false end
  return tech_priests_play_task_sound_0177(pair, sound_key, nil, TECH_PRIESTS_TASK_SOUND_MODE_COOLDOWN_TICKS_0177, 0.38)
end

tech_priests_original_respawn_pair_priest_0177 = respawn_pair_priest
function respawn_pair_priest(pair, reason)
  local result = tech_priests_original_respawn_pair_priest_0177(pair, reason)
  if result and pair then
    tech_priests_play_task_sound_0177(pair, (reason == "recall" or reason == "queued-recall" or reason == "lost") and "recall" or "deploy", nil, 60 * 4, 0.62)
  end
  return result
end

tech_priests_original_return_to_station_0177 = return_to_station
function return_to_station(priest, station)
  local result = tech_priests_original_return_to_station_0177(priest, station)
  local pair = nil
  if priest and priest.valid and storage and storage.tech_priests and storage.tech_priests.station_by_priest then
    local station_unit = storage.tech_priests.station_by_priest[priest.unit_number]
    pair = station_unit and storage.tech_priests.pairs_by_station and storage.tech_priests.pairs_by_station[station_unit] or nil
  end
  if pair then tech_priests_play_task_sound_0177(pair, "return_to_station", nil, 60 * 6, 0.30) end
  return result
end

tech_priests_original_issue_station_logistic_request_0177 = issue_station_logistic_request
function issue_station_logistic_request(pair, request)
  local before_item = pair and pair.logistic_requested_item or nil
  local result = tech_priests_original_issue_station_logistic_request_0177(pair, request)
  if result or (pair and pair.logistic_requested_item and pair.logistic_requested_item ~= before_item) then
    tech_priests_play_task_sound_0177(pair, "logistics_request", nil, 60 * 6, 0.42)
  end
  return result
end

tech_priests_original_start_logistic_scavenge_inventory_scan_0177 = start_logistic_scavenge_inventory_scan
function start_logistic_scavenge_inventory_scan(pair, request)
  local result = tech_priests_original_start_logistic_scavenge_inventory_scan_0177(pair, request)
  if result ~= false and pair and pair.inventory_scan and pair.inventory_scan.kind == "scavenge" then
    tech_priests_play_task_sound_0177(pair, "scan_scavenge", nil, 60 * 4, 0.38)
  end
  return result
end

tech_priests_original_start_logistic_cram_inventory_scan_0177 = start_logistic_cram_inventory_scan
function start_logistic_cram_inventory_scan(pair, item)
  local result = tech_priests_original_start_logistic_cram_inventory_scan_0177(pair, item)
  if result ~= false and pair and pair.inventory_scan and pair.inventory_scan.kind == "cram" then
    tech_priests_play_task_sound_0177(pair, "scan_cram", nil, 60 * 4, 0.42)
  end
  return result
end

tech_priests_original_draw_logistic_inventory_scan_line_0177 = draw_logistic_inventory_scan_line
function draw_logistic_inventory_scan_line(pair, target_entity)
  local result = tech_priests_original_draw_logistic_inventory_scan_line_0177(pair, target_entity)
  if pair and pair.inventory_scan and pair.inventory_scan.current and pair.inventory_scan.sound_current_key_0177 ~= pair.inventory_scan.current_key then
    pair.inventory_scan.sound_current_key_0177 = pair.inventory_scan.current_key
    tech_priests_play_task_sound_0177(pair, pair.inventory_scan.kind == "cram" and "scan_cram" or "scan_scavenge", target_entity and target_entity.position or nil, TECH_PRIESTS_TASK_SOUND_FAST_COOLDOWN_TICKS_0177, 0.30)
  end
  return result
end

tech_priests_original_try_withdraw_scavenge_item_0177 = try_withdraw_scavenge_item
function try_withdraw_scavenge_item(pair)
  local result = tech_priests_original_try_withdraw_scavenge_item_0177(pair)
  if result then tech_priests_play_task_sound_0177(pair, "scavenge_take", nil, 60 * 2, 0.50) end
  return result
end

tech_priests_original_try_deposit_cram_item_0177 = try_deposit_cram_item
function try_deposit_cram_item(pair)
  local result = tech_priests_original_try_deposit_cram_item_0177(pair)
  if result then tech_priests_play_task_sound_0177(pair, "cram_deposit", nil, 60 * 2, 0.50) end
  return result
end

tech_priests_original_dump_unwanted_station_stack_near_priest_0177 = dump_unwanted_station_stack_near_priest
function dump_unwanted_station_stack_near_priest(pair, item)
  local result = tech_priests_original_dump_unwanted_station_stack_near_priest_0177(pair, item)
  if result then tech_priests_play_task_sound_0177(pair, "cram_dump", nil, 60 * 2, 0.55) end
  return result
end

tech_priests_original_start_emergency_desperation_craft_0177 = start_emergency_desperation_craft
function start_emergency_desperation_craft(pair, request)
  local result = tech_priests_original_start_emergency_desperation_craft_0177(pair, request)
  if result then tech_priests_play_task_sound_0177(pair, "emergency_scan_field", nil, 60 * 4, 0.42) end
  return result
end

tech_priests_original_draw_emergency_craft_scan_line_0177 = draw_emergency_craft_scan_line
function draw_emergency_craft_scan_line(pair, target_entity)
  local result = tech_priests_original_draw_emergency_craft_scan_line_0177(pair, target_entity)
  if pair and pair.emergency_craft and pair.emergency_craft.current then
    local candidate = pair.emergency_craft.current
    local key = tostring(candidate.kind or "?") .. ":" .. tostring(candidate.unit_number or (candidate.entity and candidate.entity.unit_number) or "?") .. ":" .. tostring(candidate.item_name or "?")
    if pair.emergency_craft.sound_current_key_0177 ~= key then
      pair.emergency_craft.sound_current_key_0177 = key
      local sound_key = candidate.kind == "inventory" and "emergency_scan_inventory" or "emergency_scan_field"
      tech_priests_play_task_sound_0177(pair, sound_key, target_entity and target_entity.position or nil, TECH_PRIESTS_TASK_SOUND_FAST_COOLDOWN_TICKS_0177, candidate.kind == "inventory" and 0.32 or 0.42)
    end
  end
  return result
end

tech_priests_original_acquire_emergency_material_0177 = acquire_emergency_material
function acquire_emergency_material(pair, task, candidate)
  local result = tech_priests_original_acquire_emergency_material_0177(pair, task, candidate)
  if result then
    tech_priests_play_task_sound_0177(pair, "emergency_take", candidate and candidate.entity and candidate.entity.valid and candidate.entity.position or nil, 60, 0.48)
  end
  return result
end

tech_priests_original_finish_emergency_desperation_craft_0177 = finish_emergency_desperation_craft
function finish_emergency_desperation_craft(pair)
  local result = tech_priests_original_finish_emergency_desperation_craft_0177(pair)
  if result then tech_priests_play_task_sound_0177(pair, "emergency_craft", nil, 60 * 3, 0.65) end
  return result
end

tech_priests_original_sanctify_target_with_priest_0177 = sanctify_target_with_priest
sanctify_target_with_priest = function(pair, target)
  local before = nil
  if target and target.valid and get_consecration_record then
    local record = get_consecration_record(target)
    before = record and record.sanctification or nil
  end
  local result = tech_priests_original_sanctify_target_with_priest_0177(pair, target)
  local after = nil
  if target and target.valid and get_consecration_record then
    local record = get_consecration_record(target)
    after = record and record.sanctification or nil
  end
  if result and before and after and after > before then
    tech_priests_play_task_sound_0177(pair, "consecrate", target and target.position or nil, 60 * 3, 0.56)
  end
  return result
end

tech_priests_original_repair_target_0177 = repair_target
function repair_target(pair, target)
  local before = target and target.valid and target.health or nil
  local result = tech_priests_original_repair_target_0177(pair, target)
  local after = target and target.valid and target.health or nil
  if before and after and after > before then
    tech_priests_play_task_sound_0177(pair, "repair", target and target.position or nil, 60 * 3, 0.48)
  end
  return result
end

tech_priests_original_start_idle_scan_0177 = start_idle_scan
function start_idle_scan(pair)
  local result = tech_priests_original_start_idle_scan_0177(pair)
  if result then tech_priests_play_task_sound_0177(pair, "idle_scan", nil, 60 * 7, 0.26) end
  return result
end

tech_priests_original_start_idle_conversation_0177 = tech_priests_start_idle_conversation_0167
function tech_priests_start_idle_conversation_0167(pair, listener_pair)
  local result = tech_priests_original_start_idle_conversation_0177(pair, listener_pair)
  if result then
    tech_priests_play_task_sound_0177(pair, "conversation_start", nil, 60 * 8, 0.28)
    tech_priests_play_task_sound_0177(listener_pair, "conversation_start", nil, 60 * 8, 0.22)
  end
  return result
end

tech_priests_original_activity_watchdog_0177 = tech_priests_activity_watchdog_0176
function tech_priests_activity_watchdog_0176(pair)
  local old_mode = pair and pair.mode or nil
  local result = tech_priests_original_activity_watchdog_0177(pair)
  if result then tech_priests_play_task_sound_0177(pair, "watchdog", nil, 60 * 6, 0.55) end
  return result
end

tech_priests_original_tick_pair_0177 = tick_pair
function tick_pair(pair)
  local before_mode = pair and pair.mode or nil
  local result = tech_priests_original_tick_pair_0177(pair)
  if pair and pair.mode and pair.mode ~= before_mode then
    if pair.last_task_sound_mode_0177 ~= pair.mode then
      pair.last_task_sound_mode_0177 = pair.mode
      tech_priests_play_mode_transition_sound_0177(pair, pair.mode)
    end
  end
  return result
end


-- 0.1.179 conversation hard-freeze pass:
-- Conversations must not let either participant keep old movement orders, dance in
-- place, or path away while being addressed. This pass treats an active
-- conversation as a hard idle lock that runs before the normal pair behavior.
TECH_PRIESTS_IDLE_CONVERSATION_START_DISTANCE_SQ_0179 = 12.25
TECH_PRIESTS_IDLE_CONVERSATION_LOCK_EPSILON_SQ_0179 = 0.0004

function tech_priests_get_pair_by_station_unit_0179(station_unit)
  if not (station_unit and storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return nil end
  return storage.tech_priests.pairs_by_station[station_unit]
end

function tech_priests_pair_is_conversation_locked_0179(pair)
  if not pair then return false end
  if pair.idle_conversation then return true end
  if pair.idle_conversation_listener_until and game and game.tick and game.tick < pair.idle_conversation_listener_until then return true end
  if pair.idle_conversation_speaker_station_unit then return true end
  return false
end

function tech_priests_clear_conversation_lock_0179(pair)
  if not pair then return end
  pair.idle_conversation_lock_position_0179 = nil
  pair.idle_conversation_locked_surface_0179 = nil
  pair.idle_conversation_locked_force_0179 = nil
end

function tech_priests_set_conversation_lock_position_0179(pair)
  if not (pair and pair.priest and pair.priest.valid) then return end
  pair.idle_conversation_lock_position_0179 = { x = pair.priest.position.x, y = pair.priest.position.y }
  pair.idle_conversation_locked_surface_0179 = pair.priest.surface and pair.priest.surface.name or nil
  pair.idle_conversation_locked_force_0179 = pair.priest.force and pair.priest.force.name or nil
end

function tech_priests_clear_unit_command_0179(priest)
  if not (priest and priest.valid) then return false end
  if tech_priests_route_ground_command_0429 and defines and defines.command then
    local ok, result = pcall(function() return tech_priests_route_ground_command_0429(priest, { type = defines.command.stop }, "conversation-clear-unit-command-0179", { priority = 95, ttl = 60 }) end)
    if ok and result then return true end
  end
  local ok_any = false
  local commandable = priest.commandable
  if commandable and commandable.valid then
    pcall(function()
      commandable.set_command({ type = defines.command.stop })
      ok_any = true
    end)
  end
  pcall(function()
    priest.walking_state = { walking = false }
    ok_any = true
  end)
  pcall(function()
    priest.autopilot_destination = nil
    ok_any = true
  end)
  return ok_any
end

function tech_priests_hard_lock_conversation_priest_0179(pair)
  if not (pair and pair.priest and pair.priest.valid) then return false end
  local priest = pair.priest
  if not pair.idle_conversation_lock_position_0179 then
    tech_priests_set_conversation_lock_position_0179(pair)
  end
  tech_priests_clear_unit_command_0179(priest)

  local lock = pair.idle_conversation_lock_position_0179
  if lock then
    local dx = priest.position.x - lock.x
    local dy = priest.position.y - lock.y
    if dx * dx + dy * dy > TECH_PRIESTS_IDLE_CONVERSATION_LOCK_EPSILON_SQ_0179 then
      -- 0.1.412: do not snap/teleport ground priests back to a conversation
      -- pin.  That old hard lock looked like tree-to-tree teleporting when
      -- chatter overlapped with gather/path commands.  Stop the unit and adopt
      -- the current location as the new conversation pin instead.  Platform
      -- safety movement remains handled by its explicit platform-only code.
      tech_priests_clear_unit_command_0179(priest)
      pair.idle_conversation_lock_position_0179 = { x = priest.position.x, y = priest.position.y }
    end
  end
  pair.mode = "idle-conversation"
  pair.target = nil
  return true
end

function tech_priests_hard_lock_conversation_pair_0179(pair, listener_pair)
  tech_priests_hard_lock_conversation_priest_0179(pair)
  tech_priests_hard_lock_conversation_priest_0179(listener_pair)
end

-- Override the earlier halt helper used by the 0.1.169 conversation code. This
-- keeps all existing call sites, but turns them into actual lock-position pins.
function tech_priests_halt_priest_0169(priest)
  if not (priest and priest.valid) then return false end
  return tech_priests_clear_unit_command_0179(priest)
end

function tech_priests_halt_conversation_pair_0169(pair, listener_pair)
  return tech_priests_hard_lock_conversation_pair_0179(pair, listener_pair)
end

-- Override partner selection so conversations only begin when priests are already
-- close enough to speak. The previous behavior could start a conversation at
-- station-radius distance, then order the speaker to walk toward a listener who
-- still had a previous command. That looked like dancing or abandonment.

tech_priests_original_start_idle_conversation_0179 = tech_priests_start_idle_conversation_0167
function tech_priests_start_idle_conversation_0167(pair, listener_pair)
  if not (pair and listener_pair and pair.priest and pair.priest.valid and listener_pair.priest and listener_pair.priest.valid) then return false end
  local dx = pair.priest.position.x - listener_pair.priest.position.x
  local dy = pair.priest.position.y - listener_pair.priest.position.y
  if dx * dx + dy * dy > TECH_PRIESTS_IDLE_CONVERSATION_START_DISTANCE_SQ_0179 then
    return false
  end
  tech_priests_set_conversation_lock_position_0179(pair)
  tech_priests_set_conversation_lock_position_0179(listener_pair)
  tech_priests_hard_lock_conversation_pair_0179(pair, listener_pair)
  local result = tech_priests_original_start_idle_conversation_0179(pair, listener_pair)
  if result then
    pair.mode = "idle-conversation"
    listener_pair.mode = "idle-conversation"
    pair.target = nil
    listener_pair.target = nil
    tech_priests_hard_lock_conversation_pair_0179(pair, listener_pair)
  else
    tech_priests_clear_conversation_lock_0179(pair)
    tech_priests_clear_conversation_lock_0179(listener_pair)
  end
  return result
end

tech_priests_original_stop_idle_conversation_0179 = tech_priests_stop_idle_conversation_0167
function tech_priests_stop_idle_conversation_0167(pair)
  local listener_pair = nil
  if pair and pair.idle_conversation and pair.idle_conversation.listener_station_unit then
    listener_pair = tech_priests_get_pair_by_station_unit_0179(pair.idle_conversation.listener_station_unit)
  end
  tech_priests_original_stop_idle_conversation_0179(pair)
  tech_priests_clear_conversation_lock_0179(pair)
  if listener_pair then
    tech_priests_clear_conversation_lock_0179(listener_pair)
    listener_pair.idle_conversation_listener_until = nil
    listener_pair.idle_conversation_speaker_station_unit = nil
    if not tech_priests_pair_has_real_work_0167(listener_pair) then listener_pair.mode = "idle" end
  end
end

tech_priests_original_update_idle_conversation_behavior_0179 = update_idle_conversation_behavior
function update_idle_conversation_behavior(pair)
  if not pair then return false end

  if pair.idle_conversation then
    local listener_pair = tech_priests_get_pair_by_station_unit_0179(pair.idle_conversation.listener_station_unit)
    if listener_pair then
      tech_priests_hard_lock_conversation_pair_0179(pair, listener_pair)
    else
      tech_priests_stop_idle_conversation_0167(pair)
      return false
    end
  elseif pair.idle_conversation_listener_until and game.tick < pair.idle_conversation_listener_until then
    tech_priests_hard_lock_conversation_priest_0179(pair)
  end

  local result = tech_priests_original_update_idle_conversation_behavior_0179(pair)

  if result then
    if pair.idle_conversation then
      local listener_pair = tech_priests_get_pair_by_station_unit_0179(pair.idle_conversation.listener_station_unit)
      if listener_pair then tech_priests_hard_lock_conversation_pair_0179(pair, listener_pair) end
    elseif pair.idle_conversation_listener_until and game.tick < pair.idle_conversation_listener_until then
      tech_priests_hard_lock_conversation_priest_0179(pair)
    end
  else
    if not tech_priests_pair_is_conversation_locked_0179(pair) then
      tech_priests_clear_conversation_lock_0179(pair)
    end
  end

  return result
end

-- Pin active conversation participants every tick, not just on the 10-tick priest
-- logic cadence. This prevents old unit commands from producing visible drift
-- between behavior updates.
TechPriestsRuntimeEventRegistry.on_nth_tick(1, function()
  if not (storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return end
  for _, pair in pairs(storage.tech_priests.pairs_by_station) do
    if tech_priests_pair_is_conversation_locked_0179(pair) then
      tech_priests_hard_lock_conversation_priest_0179(pair)
    end
  end
end)

-- Final tick wrapper: active conversations are serviced before normal repair,
-- search, return, scan, or logistics behavior can issue fresh movement commands.
tech_priests_original_tick_pair_0179 = tick_pair
function tick_pair(pair)
  if pair and tech_priests_pair_is_conversation_locked_0179(pair) then
    if update_idle_conversation_behavior(pair) then return true end
  end
  return tech_priests_original_tick_pair_0179(pair)
end


-- 0.1.180 conversation approach and readability pass:
-- Restores a natural "walk together first" phase while preserving the 0.1.179
-- hard-freeze once the priests are close enough to actually speak.
TECH_PRIESTS_IDLE_CONVERSATION_APPROACH_DISTANCE_SQ_0180 = 1.69 -- about 1.3 tiles; close enough to look like a direct conversation
TECH_PRIESTS_IDLE_CONVERSATION_APPROACH_TIMEOUT_TICKS_0180 = 60 * 12
TECH_PRIESTS_IDLE_CONVERSATION_APPROACH_COMMAND_TICKS_0180 = 30
TECH_PRIESTS_IDLE_CONVERSATION_COMPLETE_HOLD_TICKS_0180 = 60 * 5
TECH_PRIESTS_IDLE_CONVERSATION_RENDER_TTL_0167 = 60 * 6
TECH_PRIESTS_IDLE_CONVERSATION_LINE_TICKS_0167 = 60 * 5

function tech_priests_pair_is_conversation_approaching_0180(pair)
  if not pair then return false end
  if pair.idle_conversation_approach_0180 then return true end
  if pair.idle_conversation_approach_listener_until_0180 and game and game.tick and game.tick < pair.idle_conversation_approach_listener_until_0180 then return true end
  if pair.idle_conversation_approach_speaker_station_unit_0180 then return true end
  return false
end

function tech_priests_clear_conversation_approach_0180(pair)
  if not pair then return end
  pair.idle_conversation_approach_0180 = nil
  pair.idle_conversation_approach_listener_until_0180 = nil
  pair.idle_conversation_approach_speaker_station_unit_0180 = nil
  pair.idle_conversation_next_approach_command_tick_0180 = nil
end

function tech_priests_clear_conversation_approach_pair_0180(pair, listener_pair)
  tech_priests_clear_conversation_approach_0180(pair)
  tech_priests_clear_conversation_approach_0180(listener_pair)
end

function tech_priests_command_priest_to_position_0180(pair, position, radius)
  if not (pair and pair.priest and pair.priest.valid and position) then return false end
  if tech_priests_request_movement_0418 then
    return tech_priests_request_movement_0418(pair, position, "conversation-approach-0180", { radius = radius or 0.35, owner = "conversation-approach-0180", priority = 75, ttl = 60 * 3, distraction = defines.distraction.by_enemy })
  end
  return issue_priest_command(pair.priest, {
    type = defines.command.go_to_location,
    destination = position,
    radius = radius or 0.35,
    distraction = defines.distraction.by_enemy
  })
end

function tech_priests_command_conversation_approach_0180(pair, listener_pair, force)
  if not (pair and listener_pair and pair.priest and pair.priest.valid and listener_pair.priest and listener_pair.priest.valid) then return false end
  if not force and game.tick < (pair.idle_conversation_next_approach_command_tick_0180 or 0) then return true end
  local p1 = pair.priest.position
  local p2 = listener_pair.priest.position
  local midpoint = { x = (p1.x + p2.x) * 0.5, y = (p1.y + p2.y) * 0.5 }
  tech_priests_command_priest_to_position_0180(pair, midpoint, 0.30)
  tech_priests_command_priest_to_position_0180(listener_pair, midpoint, 0.30)
  pair.idle_conversation_next_approach_command_tick_0180 = game.tick + TECH_PRIESTS_IDLE_CONVERSATION_APPROACH_COMMAND_TICKS_0180
  listener_pair.idle_conversation_next_approach_command_tick_0180 = game.tick + TECH_PRIESTS_IDLE_CONVERSATION_APPROACH_COMMAND_TICKS_0180
  return true
end
