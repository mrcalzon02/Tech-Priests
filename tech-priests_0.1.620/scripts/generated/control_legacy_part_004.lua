-- Auto-split control.lua fragment 004 for Tech Priests 0.1.438.
-- Generated mechanically from 0.1.437 monolithic control.lua.
-- Purpose: reduce Lua main-chunk local/register pressure without deleting behavior.



function safe_insert_into_player_inventory(player, stack)
  if not (player and player.valid and stack and stack.name and stack.count and stack.count > 0) then return 0 end
  if not get_item_prototype(stack.name) then return 0 end

  local inserted = 0
  local ok, result = pcall(function()
    return player.insert(stack)
  end)
  if ok and type(result) == "number" then
    inserted = result
  end

  local remainder = stack.count - inserted
  if remainder > 0 and player.surface and player.surface.valid and player.character and player.character.valid then
    pcall(function()
      player.surface.spill_item_stack({
        position = player.position,
        stack = { name = stack.name, count = remainder, quality = stack.quality },
        enable_looted = true,
        force = player.force,
        allow_belts = false
      })
    end)
  end

  return inserted
end

function get_starting_bonus_ammo_name()
  for _, name in ipairs(STARTING_BONUS_AMMO_CANDIDATES) do
    if get_item_prototype(name) then
      return name
    end
  end
  return nil
end

function grant_tech_priest_first_spawn_bonus(player)
  if not (player and player.valid) then return false end
  ensure_storage()

  local player_index = player.index
  if storage.tech_priests.starting_bonus_granted_by_player_index[player_index] then return true end

  local inserted_station = safe_insert_into_player_inventory(player, { name = STARTING_BONUS_STATION_NAME, count = 1 }) or 0
  if inserted_station <= 0 then
    storage.tech_priests.pending_starting_bonus_by_player_index_0190 = storage.tech_priests.pending_starting_bonus_by_player_index_0190 or {}
    storage.tech_priests.pending_starting_bonus_by_player_index_0190[player_index] = game.tick + 60
    return false
  end

  -- Multiplayer receives additional practical field supplies. This intentionally runs
  -- after Factorio/scenario starting items have already been granted and never clears
  -- or replaces the player's inventory.
  if game and game.is_multiplayer() then
    safe_insert_into_player_inventory(player, { name = "repair-pack", count = STARTING_BONUS_MULTIPLAYER_REPAIR_PACKS })
    safe_insert_into_player_inventory(player, { name = SACRED_OIL_NAME, count = STARTING_BONUS_MULTIPLAYER_SACRED_OIL })

    local ammo_name = get_starting_bonus_ammo_name()
    if ammo_name then
      local stack_size = 100
      local ammo_proto = get_item_prototype(ammo_name)
      if ammo_proto and ammo_proto.stack_size then
        stack_size = math.max(1, ammo_proto.stack_size)
      end
      safe_insert_into_player_inventory(player, { name = ammo_name, count = stack_size })
    end
  end

  storage.tech_priests.starting_bonus_granted_by_player_index[player_index] = true
  storage.tech_priests.pending_starting_bonus_by_player_index_0190 = storage.tech_priests.pending_starting_bonus_by_player_index_0190 or {}
  storage.tech_priests.pending_starting_bonus_by_player_index_0190[player_index] = nil
  return true
end

function schedule_tech_priest_first_spawn_bonus_0190(player_index, delay_ticks)
  ensure_storage()
  storage.tech_priests.pending_starting_bonus_by_player_index_0190 = storage.tech_priests.pending_starting_bonus_by_player_index_0190 or {}
  storage.tech_priests.pending_starting_bonus_by_player_index_0190[player_index] = game.tick + math.max(1, delay_ticks or 60)
end

function service_tech_priest_starting_bonus_queue_0190()
  ensure_storage()
  local pending = storage.tech_priests.pending_starting_bonus_by_player_index_0190
  if not pending then return end
  for player_index, due_tick in pairs(pending) do
    if game.tick >= (due_tick or 0) then
      local player = game.get_player(player_index)
      if player and player.valid then
        if not grant_tech_priest_first_spawn_bonus(player) then
          pending[player_index] = game.tick + 60
        end
      else
        pending[player_index] = nil
      end
    end
  end
end


function enable_tech_priest_emergency_micro_industry_for_force(force)
  if not (force and force.valid and force.recipes) then return end
  for _, recipe_name in ipairs(TECH_PRIESTS_EMERGENCY_MICRO_INDUSTRY_RECIPES) do
    local recipe = force.recipes[recipe_name]
    if recipe then
      recipe.enabled = true
    end
  end
end

function enable_tech_priest_emergency_micro_industry_for_all_forces()
  if not (game and game.forces) then return end
  for _, force in pairs(game.forces) do
    enable_tech_priest_emergency_micro_industry_for_force(force)
  end
end

TechPriestsRuntimeEventRegistry.on_init(function()
  ensure_storage()
  if storage.tech_priests then storage.tech_priests.emergency_quarry_outputs = nil end
  enable_tech_priest_emergency_micro_industry_for_all_forces()
  if game and game.players then for _, player in pairs(game.players) do schedule_tech_priest_first_spawn_bonus_0190(player.index, 90) end end
  clear_all_runtime_rendering()
  storage.tech_priests.consecration.render_cleanup_revision = 65
  storage.tech_priests.consecration.last_config = get_current_consecration_config_snapshot()
  scan_existing_consecration_targets()
  scan_existing_void_fusion_thrusters()
  tech_priests_scan_existing_emergency_miners_0183()
end)

TechPriestsRuntimeEventRegistry.on_event(defines.events.on_player_created, function(event)
  if not (event and event.player_index) then return end
  local player = game.get_player(event.player_index)
  if player and player.valid and player.force then
    enable_tech_priest_emergency_micro_industry_for_force(player.force)
  end
  -- Defer starter provisioning until after scenario/freeplay starter inventory has settled.
  if event and event.player_index then schedule_tech_priest_first_spawn_bonus_0190(event.player_index, 90) end
end)

TechPriestsRuntimeEventRegistry.on_configuration_changed(function()
  ensure_storage()
  if storage.tech_priests then storage.tech_priests.emergency_quarry_outputs = nil end
  enable_tech_priest_emergency_micro_industry_for_all_forces()
  rebuild_all_hidden_logistic_caches()
  if (storage.tech_priests.consecration.render_cleanup_revision or 0) < 65 then
    clear_all_runtime_rendering()
    storage.tech_priests.consecration.render_cleanup_revision = 65
  end
  apply_consecration_config_change_to_existing_machines()
  scan_existing_consecration_targets()
  tech_priests_scan_existing_emergency_miners_0183()
  for _, record in pairs(storage.tech_priests.consecration.machines) do
    normalise_consecration_record(record)
    if record.entity and record.entity.valid then
      pcall(function() record.entity.disabled_by_script = false end)
    end
  end
  -- Existing pairs from older versions were Junior-only and had fixed radii.
  -- Refresh them so existing saves pick up researched range bonuses immediately.
  for _, pair in pairs(storage.tech_priests.pairs_by_station) do
    if pair.station and pair.station.valid then
      apply_pair_display_names(pair)
      refresh_pair_radius(pair)
      upgrade_pair_priest_to_current_mobility(pair)
      ensure_pair_priest(pair, false)
      if is_cogitator_logistic_requisition_enabled(pair.station.force) and get_station_logistic_network(pair.station) then
        ensure_pair_logistic_caches(pair)
      end
    end
  end
end)

if defines.events.on_force_created then
  TechPriestsRuntimeEventRegistry.on_event(defines.events.on_force_created, function(event)
    if event and event.force then
      enable_tech_priest_emergency_micro_industry_for_force(event.force)
    end
  end)
end

TechPriestsRuntimeEventRegistry.on_event({
  defines.events.on_built_entity,
  defines.events.on_robot_built_entity,
  defines.events.script_raised_built,
  defines.events.script_raised_revive
}, on_built)

TechPriestsRuntimeEventRegistry.on_event({
  defines.events.on_entity_died,
  defines.events.on_pre_player_mined_item,
  defines.events.on_robot_pre_mined,
  defines.events.script_raised_destroy
}, on_removed)

TechPriestsRuntimeEventRegistry.on_event({
  defines.events.on_player_selected_area,
  defines.events.on_player_alt_selected_area
}, on_consecration_item_selected_area)

TechPriestsRuntimeEventRegistry.on_event(defines.events.on_script_trigger_effect, apply_sacred_incense_impact)


TechPriestsRuntimeEventRegistry.on_event(defines.events.on_research_finished, function(event)
  if not (event and event.research and event.research.force) then return end
  ensure_storage()
  storage.tech_priests.last_researched_technology_by_force = storage.tech_priests.last_researched_technology_by_force or {}
  storage.tech_priests.last_researched_technology_by_force[event.research.force.name] = event.research.name
  if RANGE_TECH_BONUSES[event.research.name] then
    for _, pair in pairs(storage.tech_priests.pairs_by_station) do
      if pair.station and pair.station.valid and pair.station.force == event.research.force then
        refresh_pair_radius(pair)
      end
    end
  end
  if event.research.name == TECH_PRIEST_BELT_IMMUNITY_TECH then
    upgrade_force_priests_to_current_mobility(event.research.force)
  end
  if event.research.name == COGITATOR_LOGISTIC_REQUISITION_TECH then
    for _, pair in pairs(storage.tech_priests.pairs_by_station or {}) do
      if pair.station and pair.station.valid and pair.station.force == event.research.force then
        ensure_pair_logistic_caches(pair)
        if tech_priests_update_logistic_debug then
          tech_priests_update_logistic_debug(pair, {
            stage = "research-unlocked",
            ok = true,
            has_logistic_system = tech_priests_get_force_has_logistic_system and tech_priests_get_force_has_logistic_system(pair.station.force) or nil,
            requester_valid = pair.logistic_requester and pair.logistic_requester.valid or false,
            return_valid = pair.logistic_return_cache and pair.logistic_return_cache.valid or false
          })
        end
      end
    end
  end
  if is_sanctification_baseline_technology(event.research.name) then
    local previous_base_max = get_base_sanctification_max(event.research.force) - (MAX_SANCTIFICATION_TECH_BONUSES[event.research.name] or 0)
    apply_sanctification_research_to_existing_machines(event.research.force, previous_base_max, get_base_sanctification_max(event.research.force))
  end
end)


function on_player_rotated_entity(event)
  local entity = event and event.entity
  if not is_station(entity) then return end
  local pair = find_pair_for_entity(entity)
  if pair then
    pair.deploy_direction = entity.direction
    ensure_pair_priest(pair, true)
  end
end

TechPriestsRuntimeEventRegistry.on_event(defines.events.on_selected_entity_changed, on_selected_entity_changed)
if defines.events.on_player_rotated_entity then
  TechPriestsRuntimeEventRegistry.on_event(defines.events.on_player_rotated_entity, on_player_rotated_entity)
end

TechPriestsRuntimeEventRegistry.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
  if event and event.setting and string.sub(event.setting, 1, 13) == "tech-priests-" then
    if string.find(event.setting, "tech%-priests%-priest%-status%-") or event.setting == "tech-priests-enable-priest-status-bubbles" then
      if storage and storage.tech_priests and storage.tech_priests.priest_bubbles then
        for station_unit, object in pairs(storage.tech_priests.priest_bubbles) do
          destroy_render_object(object)
          storage.tech_priests.priest_bubbles[station_unit] = nil
        end
      end
    else
      apply_consecration_config_change_to_existing_machines()
    end
  end
end)

TechPriestsRuntimeEventRegistry.on_nth_tick(RADIUS_RENDER_REFRESH_TICKS, function()
  refresh_radius_rendering_for_players()
end)

TechPriestsRuntimeEventRegistry.on_nth_tick(PRIEST_STATUS_BUBBLE_UPDATE_TICKS, function()
  update_priest_status_bubbles()
end)

TechPriestsRuntimeEventRegistry.on_nth_tick(PRIEST_SANITY_RECALL_TICKS, function()
  sanity_recall_all_priests(false)
end)

TechPriestsRuntimeEventRegistry.on_nth_tick(10, function()
  ensure_storage()
  service_tech_priest_starting_bonus_queue_0190()
  enable_tech_priest_emergency_micro_industry_for_all_forces()
  process_priest_deployment_queue(PRIEST_DEPLOYMENT_QUEUE_PROCESS_LIMIT)
  process_active_sacred_incense_clouds()
  service_void_fusion_thrusters()
  update_all_consecration_targets()
  for _, pair in pairs(storage.tech_priests.pairs_by_station) do
    tick_pair(pair)
  end
end)

TechPriestsRuntimeEventRegistry.on_nth_tick(257, function()
  ensure_storage()
  tech_priests_service_emergency_quarry_miners_0183()
end)

TechPriestsGuiRouter.register("opened", tech_priests_on_gui_opened_0183)
TechPriestsGuiRouter.register("closed", tech_priests_on_gui_closed_0183)
TechPriestsGuiRouter.register("click", tech_priests_on_gui_click_0183)

function find_repair_waiting_target(station, radius, priest, require_full_usefulness)
  if not (station and station.valid) then return nil end
  local surface = station.surface
  local force = station.force
  local position = station.position
  local area = {
    { position.x - radius, position.y - radius },
    { position.x + radius, position.y + radius }
  }

  local entities = surface.find_entities_filtered({ area = area, force = force })
  local best = nil
  local best_score = nil
  for _, entity in pairs(entities) do
    if entity.valid and entity.health and entity.max_health and entity.max_health > 0 and not is_priest(entity) and entity.name ~= PROXY_NAME then
      local missing = get_repair_pack_useful_missing_health(entity)
      local matches = false
      if require_full_usefulness then
        matches = missing >= REPAIR_AMOUNT_PER_PACK
      else
        matches = missing > 0 and missing < REPAIR_AMOUNT_PER_PACK
      end
      if matches then
        local dx = entity.position.x - position.x
        local dy = entity.position.y - position.y
        local station_distance = dx * dx + dy * dy
        if station_distance <= radius * radius then
          local score = station_distance
          if priest and priest.valid then
            local pdx = entity.position.x - priest.position.x
            local pdy = entity.position.y - priest.position.y
            score = math.min(station_distance, pdx * pdx + pdy * pdy)
          end
          if not best_score or score < best_score then
            best = entity
            best_score = score
          end
        end
      end
    end
  end
  return best
end

function find_consecration_status_target(station, radius, priest, require_station_has_items, require_waiting_for_usefulness)
  if not (station and station.valid) then return nil end
  if require_station_has_items ~= nil then
    local has_items = station_has_consecration_item(station)
    if require_station_has_items and not has_items then return nil end
    if require_station_has_items == false and has_items then return nil end
  end

  local targets = station.surface.find_entities_filtered({
    name = CONSECRATION_TARGET_NAME_LIST,
    force = station.force,
    position = station.position,
    radius = radius or get_station_consecration_radius(station)
  })

  local best = nil
  local best_ratio = 1.01
  local best_distance = nil
  for _, entity in pairs(targets) do
    local record = get_consecration_record(entity)
    if record then
      local max_value = record.max_sanctification or get_base_sanctification_max()
      local value = record.sanctification or 0
      if max_value > 0 and value < max_value then
        local missing = max_value - value
        local useful_item = get_available_station_consecration_item(station, missing)
        local matches = true
        if require_waiting_for_usefulness then
          matches = not useful_item
        end
        if matches then
          local ratio = value / max_value
          local dx = station.position.x - entity.position.x
          local dy = station.position.y - entity.position.y
          local distance = dx * dx + dy * dy
          if priest and priest.valid then
            local pdx = priest.position.x - entity.position.x
            local pdy = priest.position.y - entity.position.y
            distance = math.min(distance, pdx * pdx + pdy * pdy)
          end
          if ratio < best_ratio or (math.abs(ratio - best_ratio) < 0.001 and (not best_distance or distance < best_distance)) then
            best = entity
            best_ratio = ratio
            best_distance = distance
          end
        end
      end
    end
  end
  return best
end


-- 0.1.116 explicit local inventory scanning for logistics frustration/cram mode.
-- The older behavior selected a source/destination immediately. This override makes
-- the priest physically approach and inspect candidate structures one at a time.
LOGISTIC_INVENTORY_SCAN_TICKS = 60 * 3
LOGISTIC_SCAN_LINE_TTL = 20

original_0116_handle_priest_scavenge_task = handle_priest_scavenge_task
original_0116_handle_priest_cram_task = handle_priest_cram_task
original_0116_maybe_start_cram_mode = maybe_start_cram_mode
original_0116_get_priest_current_target = get_priest_current_target

function clear_logistic_inventory_scan(pair)
  if not pair then return end
  if pair.scan_line_render then
    destroy_render_object(pair.scan_line_render)
    pair.scan_line_render = nil
  end
  pair.inventory_scan = nil
end

function draw_logistic_inventory_scan_line(pair, target_entity)
  if not (pair and pair.priest and pair.priest.valid and target_entity and target_entity.valid and rendering and rendering.draw_line) then return end
  if pair.scan_line_render then
    destroy_render_object(pair.scan_line_render)
    pair.scan_line_render = nil
  end
  local color = { r = 0.30, g = 0.90, b = 1.00, a = 0.82 }
  if pair.inventory_scan and pair.inventory_scan.kind == "cram" then
    color = { r = 1.00, g = 0.55, b = 0.12, a = 0.86 }
  end
  local ok, line = pcall(function()
    return rendering.draw_line({
      color = color,
      width = 2,
      from = { entity = pair.priest, offset = TECH_PRIEST_SCAN_ORIGIN_OFFSET },
      to = { entity = target_entity, offset = { 0, -0.10 } },
      surface = pair.priest.surface,
      time_to_live = LOGISTIC_SCAN_LINE_TTL
    })
  end)
  if ok and line then pair.scan_line_render = line end
end

function get_inventory_scan_entity_priority(entity)
  if not (entity and entity.valid) then return 99 end

  -- Prefer actual storage first: chests, logistic chests, and Cogitator Stations.
  -- Machinery is intentionally scanned later so priests do not waste time poking
  -- assemblers/furnaces before checking the places players normally store supplies.
  if entity.name == JUNIOR_STATION_NAME or entity.name == INTERMEDIATE_STATION_NAME or entity.name == SENIOR_STATION_NAME then
    return 1
  end

  local entity_type = entity.type
  if entity_type == "container" or entity_type == "logistic-container" or entity_type == "infinity-container" then
    return 1
  end

  if entity_type == "cargo-wagon" or entity_type == "car" or entity_type == "spider-vehicle" then
    return 2
  end

  if entity_type == "assembling-machine" or entity_type == "furnace" or entity_type == "mining-drill" or entity_type == "rocket-silo" or entity_type == "lab" then
    return 4
  end

  return 3
end

function build_sorted_inventory_scan_candidates(pair)
  if not (pair and pair.station and pair.station.valid) then return {} end
  local station = pair.station
  local radius = refresh_pair_radius(pair)
  local position = station.position
  local area = {{position.x - radius, position.y - radius}, {position.x + radius, position.y + radius}}
  local ids = get_scavenge_inventory_ids()
  local candidates = {}
  local entities = station.surface.find_entities_filtered({ area = area, force = station.force })
  for _, entity in pairs(entities) do
    if entity.valid and entity ~= station and entity.name ~= PROXY_NAME and entity.name ~= LOGISTIC_REQUESTER_CACHE_NAME and entity.name ~= LOGISTIC_RETURN_CACHE_NAME and not is_priest(entity) then
      local dx = entity.position.x - position.x
      local dy = entity.position.y - position.y
      local station_distance_sq = dx * dx + dy * dy
      if station_distance_sq <= radius * radius then
        local scan_priority = get_inventory_scan_entity_priority(entity)
        for _, inventory_id in pairs(ids) do
          local inventory = get_entity_inventory_safe(entity, inventory_id)
          if inventory then
            candidates[#candidates + 1] = {
              entity = entity,
              inventory_id = inventory_id,
              station_distance_sq = station_distance_sq,
              scan_priority = scan_priority,
              unit_number = entity.unit_number or 0
            }
          end
        end
      end
    end
  end
  table.sort(candidates, function(a, b)
    if (a.scan_priority or 99) ~= (b.scan_priority or 99) then
      return (a.scan_priority or 99) < (b.scan_priority or 99)
    end
    if math.abs(a.station_distance_sq - b.station_distance_sq) > 0.001 then
      return a.station_distance_sq < b.station_distance_sq
    end
    if (a.unit_number or 0) ~= (b.unit_number or 0) then
      return (a.unit_number or 0) < (b.unit_number or 0)
    end
    return (a.inventory_id or 0) < (b.inventory_id or 0)
  end)
  return candidates
end

-- TECH-PRIESTS 0.1.431: removed superseded duplicate function start_logistic_scavenge_inventory_scan (old lines 4815-4829); next definition begins at old line 5157. No intervening capture/registration/reference was detected by tools/audit_control_deletion_candidates.py.

function start_logistic_cram_inventory_scan(pair, item)
  if not (pair and pair.station and pair.station.valid and item and item.name) then return false end
  clear_logistic_inventory_scan(pair)
  pair.inventory_scan = {
    kind = "cram",
    item = item,
    candidates = build_sorted_inventory_scan_candidates(pair),
    index = 1,
    scan_due_tick = nil,
    started_tick = game.tick,
    dump_due_tick = game.tick + LOGISTIC_CRAM_SEARCH_BEFORE_DUMP_TICKS
  }
  pair.cram = { scanning = true }
  pair.mode = "cramming-supplies"
  return true
end

function advance_logistic_inventory_scan(pair)
  if not (pair and pair.inventory_scan) then return false end
  local scan = pair.inventory_scan
  scan.index = (scan.index or 1) + 1
  scan.scan_due_tick = nil
  scan.current = nil
  pair.target = nil
  return true
end

function finish_failed_logistic_inventory_scan(pair)
  if not (pair and pair.inventory_scan) then return false end
  local scan = pair.inventory_scan
  if scan.kind == "cram" and scan.item then
    clear_logistic_inventory_scan(pair)
    pair.cram = nil
    return dump_unwanted_station_stack_near_priest(pair, scan.item)
  end
  clear_logistic_inventory_scan(pair)
  pair.scavenge = nil
  pair.next_scavenge_search_tick = game.tick + LOGISTIC_SCAVENGE_RETRY_TICKS
  pair.mode = "returning"
  if pair.priest and pair.priest.valid and pair.station and pair.station.valid then
    return_to_station(pair.priest, pair.station)
  end
  return false
end

function handle_logistic_inventory_scan(pair)
  if not (pair and pair.priest and pair.priest.valid and pair.station and pair.station.valid and pair.inventory_scan) then return false end
  local scan = pair.inventory_scan
  local candidates = scan.candidates or {}

  while true do
    local candidate = candidates[scan.index or 1]
    if not candidate then
      return finish_failed_logistic_inventory_scan(pair)
    end
    if candidate.entity and candidate.entity.valid then
      scan.current = candidate
      break
    end
    scan.index = (scan.index or 1) + 1
  end

  local candidate = scan.current
  local entity = candidate.entity
  pair.target = entity
  draw_logistic_inventory_scan_line(pair, entity)

  local dx = pair.priest.position.x - entity.position.x
  local dy = pair.priest.position.y - entity.position.y
  if dx * dx + dy * dy > LOGISTIC_SCAVENGE_PICKUP_DISTANCE_SQ then
    move_priest_to(pair.priest, entity)
    if scan.kind == "cram" then
      pair.mode = "cramming-supplies"
    else
      pair.mode = "scavenging-supplies"
    end
    scan.scan_due_tick = nil
    return true
  end

  if not scan.scan_due_tick then
    scan.scan_due_tick = game.tick + LOGISTIC_INVENTORY_SCAN_TICKS
    return true
  end
  if game.tick < scan.scan_due_tick then
    return true
  end

  local inventory = get_entity_inventory_safe(entity, candidate.inventory_id)
  if scan.kind == "scavenge" then
    local found = inventory_has_insertable_request_item(pair, inventory, scan.request)
    if found then
      local real_task = { source = entity, inventory_id = candidate.inventory_id, item_name = found.name, count = found.count or 1, quality = found.quality, kind = scan.request and scan.request.kind }
      clear_logistic_inventory_scan(pair)
      pair.scavenge = real_task
      pair.mode = "scavenging-supplies"
      pair.target = entity
      return original_0116_handle_priest_scavenge_task(pair)
    end
  elseif scan.kind == "cram" and scan.item then
    if inventory and inventory.can_insert(make_item_stack_identification(scan.item.name, 1, scan.item.quality)) then
      local real_task = { destination = entity, inventory_id = candidate.inventory_id, item_name = scan.item.name, count = scan.item.count or 1, quality = scan.item.quality }
      clear_logistic_inventory_scan(pair)
      pair.cram = real_task
      pair.mode = "cramming-supplies"
      pair.target = entity
      return original_0116_handle_priest_cram_task(pair)
    end
    if game.tick >= (scan.dump_due_tick or 0) then
      local item = scan.item
      clear_logistic_inventory_scan(pair)
      pair.cram = nil
      return dump_unwanted_station_stack_near_priest(pair, item)
    end
  end

  advance_logistic_inventory_scan(pair)
  return true
end

function handle_priest_scavenge_task(pair)
  if pair and pair.inventory_scan and pair.inventory_scan.kind == "scavenge" then
    return handle_logistic_inventory_scan(pair)
  end
  return original_0116_handle_priest_scavenge_task(pair)
end

function handle_priest_cram_task(pair)
  if pair and pair.inventory_scan and pair.inventory_scan.kind == "cram" then
    return handle_logistic_inventory_scan(pair)
  end
  return original_0116_handle_priest_cram_task(pair)
end

function maybe_start_cram_mode(pair, request)
  if not (pair and pair.station and pair.station.valid and request) then return false end
  if pair.inventory_scan and pair.inventory_scan.kind == "cram" then return handle_logistic_inventory_scan(pair) end
  if pair.cram then return handle_priest_cram_task(pair) end
  if request_has_station_space(pair, request) then
    pair.logistic_cram_start_tick = nil
    pair.logistic_cram_due_tick = nil
    pair.cram_search_started_tick = nil
    pair.cram_dump_due_tick = nil
    return false
  end
  if not pair.logistic_cram_due_tick then
    pair.logistic_cram_start_tick = game.tick
    pair.logistic_cram_due_tick = game.tick + LOGISTIC_FRUSTRATION_THRESHOLD_TICKS
  end
  if game.tick < pair.logistic_cram_due_tick then
    pair.mode = "logistics-cram-countdown"
    return false
  end
  local unwanted = find_unwanted_station_stack_for_request(pair, request)
  if not unwanted then
    pair.mode = "logistics-cram-countdown"
    return false
  end
  start_logistic_cram_inventory_scan(pair, unwanted)
  return handle_logistic_inventory_scan(pair)
end


function get_priest_current_target(pair)
  if pair and pair.inventory_scan and pair.inventory_scan.current and pair.inventory_scan.current.entity and pair.inventory_scan.current.entity.valid then
    return pair.inventory_scan.current.entity
  end
  return original_0116_get_priest_current_target(pair)
end


-- 0.1.117 logistics scan refinement:
-- * show an actual per-inventory scan countdown over the priest
-- * remember recently scanned objects so priests do not loop on the same chest/station
-- * apply Mechanicus politeness when scavenging from another Cogitator Station: take only half of available stock
LOGISTIC_RECENT_SCAN_TTL_TICKS = 60 * 120

original_0117_classify_priest_visual_state = classify_priest_visual_state
original_0117_get_priest_status_setting_name = get_priest_status_setting_name
original_0117_get_priest_status_fallback_symbol = get_priest_status_fallback_symbol
original_0117_get_priest_target_line_color = get_priest_target_line_color
original_0117_get_priest_status_symbol = get_priest_status_symbol

function get_inventory_scan_item_name(scan)
  if not scan then return "" end
  if scan.request then
    if scan.request.item_name then return tostring(scan.request.item_name) end
    if scan.request.candidates and scan.request.candidates[1] and scan.request.candidates[1].name then return tostring(scan.request.candidates[1].name) end
    if scan.request.kind then return tostring(scan.request.kind) end
  end
  if scan.item and scan.item.name then return tostring(scan.item.name) end
  return ""
end

function get_inventory_scan_key(candidate, kind, item_name)
  if not (candidate and candidate.entity and candidate.entity.valid) then return nil end
  local entity_key = candidate.entity.unit_number or (candidate.entity.name .. "@" .. math.floor(candidate.entity.position.x * 32) .. ":" .. math.floor(candidate.entity.position.y * 32))
  return tostring(kind or "?") .. ":" .. tostring(entity_key) .. ":" .. tostring(candidate.inventory_id or "?") .. ":" .. tostring(item_name or "")
end

function prune_recent_inventory_scans(pair)
  if not (pair and pair.recent_inventory_scans) then return end
  for key, expire_tick in pairs(pair.recent_inventory_scans) do
    if (expire_tick or 0) <= game.tick then
      pair.recent_inventory_scans[key] = nil
    end
  end
end

function mark_recent_inventory_scan(pair, candidate, kind, item_name)
  if not (pair and candidate) then return end
  prune_recent_inventory_scans(pair)
  local key = get_inventory_scan_key(candidate, kind, item_name)
  if not key then return end
  pair.recent_inventory_scans = pair.recent_inventory_scans or {}
  pair.recent_inventory_scans[key] = game.tick + LOGISTIC_RECENT_SCAN_TTL_TICKS
end

function was_inventory_scanned_recently(pair, candidate, kind, item_name)
  if not (pair and candidate) then return false end
  prune_recent_inventory_scans(pair)
  local key = get_inventory_scan_key(candidate, kind, item_name)
  if not (key and pair.recent_inventory_scans) then return false end
  return (pair.recent_inventory_scans[key] or 0) > game.tick
end

function classify_priest_visual_state(pair)
  if pair and pair.inventory_scan then
    if pair.inventory_scan.kind == "cram" then return "inventory-scan-cram" end
    return "inventory-scan-scavenge"
  end
  return original_0117_classify_priest_visual_state(pair)
end

function get_priest_status_setting_name(state)
  if state == "inventory-scan-scavenge" then return "tech-priests-priest-status-symbol-inventory-scan-scavenge" end
  if state == "inventory-scan-cram" then return "tech-priests-priest-status-symbol-inventory-scan-cram" end
  return original_0117_get_priest_status_setting_name(state)
end

function get_priest_status_fallback_symbol(state)
  if state == "inventory-scan-scavenge" then return "[item=steel-chest]?{scan_seconds}" end
  if state == "inventory-scan-cram" then return "[item=steel-chest]!{scan_seconds}" end
  return original_0117_get_priest_status_fallback_symbol(state)
end

function get_priest_target_line_color(pair)
  local state = classify_priest_visual_state(pair)
  if state == "inventory-scan-scavenge" then return { r = 0.20, g = 0.95, b = 1.00, a = 0.90 } end
  if state == "inventory-scan-cram" then return { r = 1.00, g = 0.48, b = 0.10, a = 0.92 } end
  return original_0117_get_priest_target_line_color(pair)
end

function get_priest_status_symbol(pair)
  local symbol
  if pair and pair.inventory_scan then
    local state = classify_priest_visual_state(pair)
    local raw = read_global_string_setting(get_priest_status_setting_name(state), get_priest_status_fallback_symbol(state))
    symbol = choose_priest_status_variant(raw, pair, state)
  else
    symbol = original_0117_get_priest_status_symbol(pair)
  end

  local scan_remaining = 0
  if pair and pair.inventory_scan then
    local scan = pair.inventory_scan
    if scan.scan_due_tick then
      scan_remaining = math.max(0, math.ceil((scan.scan_due_tick - game.tick) / 60))
    else
      scan_remaining = math.ceil(LOGISTIC_INVENTORY_SCAN_TICKS / 60)
    end
    symbol = tostring(symbol or ""):gsub("{scan_seconds}", tostring(scan_remaining))
    symbol = symbol:gsub("{scan_item}", tostring(get_inventory_scan_item_name(scan)))
  end
  return tostring(symbol or "")
end

-- Replace the 0.1.116 candidate builder with one that skips objects recently
-- inspected for the same purpose/item. This keeps priests from getting stuck
-- orbiting one unsuitable chest or endlessly re-checking nearby Cogitator Stations.
function build_sorted_inventory_scan_candidates(pair, scan_kind, item_name)
  if not (pair and pair.station and pair.station.valid) then return {} end
  prune_recent_inventory_scans(pair)
  local station = pair.station
  local radius = refresh_pair_radius(pair)
  local position = station.position
  local area = {{position.x - radius, position.y - radius}, {position.x + radius, position.y + radius}}
  local ids = get_scavenge_inventory_ids()
  local candidates = {}
  local entities = station.surface.find_entities_filtered({ area = area, force = station.force })
  for _, entity in pairs(entities) do
    if entity.valid and entity ~= station and entity.name ~= PROXY_NAME and entity.name ~= LOGISTIC_REQUESTER_CACHE_NAME and entity.name ~= LOGISTIC_RETURN_CACHE_NAME and not is_priest(entity) then
      local dx = entity.position.x - position.x
      local dy = entity.position.y - position.y
      local station_distance_sq = dx * dx + dy * dy
      if station_distance_sq <= radius * radius then
        for _, inventory_id in pairs(ids) do
          local inventory = get_entity_inventory_safe(entity, inventory_id)
          if inventory then
            local candidate = {
              entity = entity,
              inventory_id = inventory_id,
              station_distance_sq = station_distance_sq,
              unit_number = entity.unit_number or 0
            }
            if not was_inventory_scanned_recently(pair, candidate, scan_kind, item_name) then
              candidates[#candidates + 1] = candidate
            end
          end
        end
      end
    end
  end
  table.sort(candidates, function(a, b)
    if math.abs(a.station_distance_sq - b.station_distance_sq) > 0.001 then
      return a.station_distance_sq < b.station_distance_sq
    end
    if (a.unit_number or 0) ~= (b.unit_number or 0) then
      return (a.unit_number or 0) < (b.unit_number or 0)
    end
    return (a.inventory_id or 0) < (b.inventory_id or 0)
  end)
  return candidates
end

function start_logistic_scavenge_inventory_scan(pair, request)
  if not (pair and pair.station and pair.station.valid and request) then return false end
  clear_logistic_inventory_scan(pair)
  local item_name = get_inventory_scan_item_name({ request = request })
  pair.inventory_scan = {
    kind = "scavenge",
    request = request,
    candidates = build_sorted_inventory_scan_candidates(pair, "scavenge", item_name),
    index = 1,
    scan_due_tick = nil,
    started_tick = game.tick,
    item_name = item_name
  }
  pair.scavenge = { scanning = true }
  pair.mode = "scavenging-supplies"
  return true
end

function start_logistic_cram_inventory_scan(pair, item)
  if not (pair and pair.station and pair.station.valid and item and item.name) then return false end
  clear_logistic_inventory_scan(pair)
  pair.inventory_scan = {
    kind = "cram",
    item = item,
    candidates = build_sorted_inventory_scan_candidates(pair, "cram", item.name),
    index = 1,
    scan_due_tick = nil,
    started_tick = game.tick,
    dump_due_tick = game.tick + LOGISTIC_CRAM_SEARCH_BEFORE_DUMP_TICKS,
    item_name = item.name
  }
  pair.cram = { scanning = true }
  pair.mode = "cramming-supplies"
  return true
end

-- Replace the scan handler so every candidate gets exactly one short inspection,
-- displays a visible countdown during that inspection, and then advances cleanly.


-- 0.1.118 logistics/scanning repair pass:
-- * Use the Factorio 2.x logistic sections API more directly for hidden requester caches.
-- * Keep a 1.1-style fallback, but do not treat a no-op pcall as success.
-- * If no logistics network exists, wait only 10 seconds before beginning local scavenging.
-- * Add candidate approach timeouts so priests do not stare forever at one unreachable/unsuitable inventory.
LOGISTIC_NO_NETWORK_SCAVENGE_TICKS = 60 * 10
LOGISTIC_INVENTORY_APPROACH_TIMEOUT_TICKS = 60 * 10

function get_or_create_manual_logistic_section(entity)
  if not (entity and entity.valid) then return nil end

  local ok, sections = pcall(function()
    if entity.get_logistic_sections then return entity.get_logistic_sections() end
    return nil
  end)
  if ok and sections then
    local section = nil
    pcall(function()
      if sections.get_section then section = sections.get_section(1) end
    end)
    if not section then
      pcall(function()
        if sections.add_section then section = sections.add_section() end
      end)
    end
    if section then
      pcall(function() section.active = true end)
      pcall(function() section.group = "Tech-Priests Requisition" end)
      return section
    end
  end

  ok, sections = pcall(function()
    local point = nil
    if entity.get_requester_point then point = entity.get_requester_point() end
    if not point and entity.get_logistic_point then
      local idx = defines and defines.logistic_member_index and defines.logistic_member_index.logistic_container
      if idx then point = entity.get_logistic_point(idx) end
      if not point then point = entity.get_logistic_point() end
      if type(point) == "table" and not point.sections then
        point = point[1]
      end
    end
    return point and point.sections or nil
  end)
  if ok and sections then
    local section = nil
    pcall(function()
      if sections.get_section then section = sections.get_section(1) end
    end)
    if not section then
      pcall(function()
        if sections.add_section then section = sections.add_section() end
      end)
    end
    if section then
      pcall(function() section.active = true end)
      pcall(function() section.group = "Tech-Priests Requisition" end)
      return section
    end
  end

  return nil
end

function clear_logistic_request_slots(entity)
  if not (entity and entity.valid) then return false end
  local any = false

  local section = get_or_create_manual_logistic_section(entity)
  if section then
    for i = 1, LOGISTIC_REQUESTER_SLOT_COUNT do
      local ok = pcall(function()
        if section.clear_slot then section.clear_slot(i) end
      end)
      any = any or ok
    end
  end

  for i = 1, LOGISTIC_REQUESTER_SLOT_COUNT do
    local ok = pcall(function()
      if entity.set_request_slot then entity.set_request_slot(nil, i) end
    end)
    any = any or ok
    local ok2 = pcall(function()
      local cb = entity.get_control_behavior and entity.get_control_behavior()
      if cb and cb.set_request_slot then cb.set_request_slot(nil, i) end
    end)
    any = any or ok2
  end
  return any
end

function verify_logistic_request_slot(entity, slot_index, stack)
  if not (entity and entity.valid and stack and stack.name) then return false end
  local section = get_or_create_manual_logistic_section(entity)
  if section and section.get_slot then
    local ok, slot = pcall(function() return section.get_slot(slot_index or 1) end)
    if ok and slot then
      local value = slot.value or slot.name or slot[1]
      if type(value) == "table" then
        if value.name == stack.name then return true end
      elseif value == stack.name then
        return true
      end
    end
  end
  local ok, request = pcall(function()
    if entity.get_request_slot then return entity.get_request_slot(slot_index or 1) end
    return nil
  end)
  if ok and request then
    if type(request) == "table" and request.name == stack.name then return true end
    if request == stack.name then return true end
  end
  return false
end

function set_logistic_request_slot(entity, slot_index, stack)
  if not (entity and entity.valid and stack and stack.name and (stack.count or 0) > 0) then return false end
  slot_index = slot_index or 1
  local count = math.max(1, stack.count or 1)

  -- Factorio 2.x requester chests use logistic sections. LuaLogisticSection:set_slot
  -- is the API documented for setting requester filters; verify after setting so
  -- an empty/no-op pcall cannot masquerade as a successful request.
  local section = get_or_create_manual_logistic_section(entity)
  if section and section.set_slot then
    local filter = {
      value = { type = "item", name = stack.name },
      min = count,
      max = count
    }
    if stack.quality then filter.value.quality = stack.quality end
    local ok = pcall(function() section.set_slot(slot_index, filter) end)
    if ok and verify_logistic_request_slot(entity, slot_index, stack) then
      pcall(function() entity.request_from_buffers = true end)
      return true
    end

    -- Some API builds accept the older bare item stack shape through sections.
    ok = pcall(function()
      section.set_slot(slot_index, make_item_stack_identification(stack.name, count, stack.quality))
    end)
    if ok and verify_logistic_request_slot(entity, slot_index, stack) then
      pcall(function() entity.request_from_buffers = true end)
      return true
    end
  end

  -- Factorio 1.1/compatibility fallback.
  local request = make_item_stack_identification(stack.name, count, stack.quality)
  local ok = pcall(function()
    if entity.set_request_slot then entity.set_request_slot(request, slot_index) end
  end)
  if ok and verify_logistic_request_slot(entity, slot_index, stack) then return true end

  ok = pcall(function()
    local cb = entity.get_control_behavior and entity.get_control_behavior()
    if cb and cb.set_request_slot then cb.set_request_slot(request, slot_index) end
  end)
  if ok and verify_logistic_request_slot(entity, slot_index, stack) then return true end

  return false
end

original_0118_create_hidden_logistic_cache_for_pair = create_hidden_logistic_cache_for_pair
function create_hidden_logistic_cache_for_pair(pair, entity_name, offset)
  local entity = original_0118_create_hidden_logistic_cache_for_pair(pair, entity_name, offset)
  if entity and entity.valid then
    pcall(function() entity.request_from_buffers = true end)
    -- Wake the logistic point up once; requester sections are created lazily in
    -- some builds and this makes later request-slot writes more reliable.
    if entity_name == LOGISTIC_REQUESTER_CACHE_NAME then
      get_or_create_manual_logistic_section(entity)
    end
  end
  return entity
end

function issue_station_logistic_request(pair, request)
  if not (pair and pair.station and pair.station.valid and request) then return false end
  if not is_cogitator_logistic_requisition_enabled(pair.station.force) then return false end

  local network = get_station_logistic_network(pair.station)
  if not network then
    if pair.logistic_requester and pair.logistic_requester.valid then pair.logistic_requester.destroy({ raise_destroy = false }) end
    if pair.logistic_return_cache and pair.logistic_return_cache.valid then pair.logistic_return_cache.destroy({ raise_destroy = false }) end
    pair.logistic_requester = nil
    pair.logistic_return_cache = nil
    pair.mode = "logistics-no-network"
    return false
  end

  ensure_pair_logistic_caches(pair)
  if not (pair.logistic_requester and pair.logistic_requester.valid) then return false end

  transfer_cache_inventory_to_station(pair)

  local stack = choose_logistic_request_stack(pair, request)
  if not stack then return false end
  pair.logistic_requested_item = stack.name
  pair.logistic_requested_count = stack.count or 1
  pair.logistic_frustration_kind = request.kind
  if not pair.logistic_frustration_start_tick then
    pair.logistic_frustration_start_tick = game.tick
    pair.logistic_frustration_due_tick = game.tick + LOGISTIC_FRUSTRATION_THRESHOLD_TICKS
  end

  local station_inventory = get_station_inventory(pair.station)
  if station_inventory and not station_inventory.can_insert({ name = stack.name, count = 1 }) then
    if not pair.logistic_cram_due_tick then
      pair.logistic_cram_start_tick = game.tick
      pair.logistic_cram_due_tick = game.tick + LOGISTIC_FRUSTRATION_THRESHOLD_TICKS
    end
    pair.mode = "logistics-cram-countdown"
  else
    pair.logistic_cram_start_tick = nil
    pair.logistic_cram_due_tick = nil
    pair.mode = "logistics-scavenge-countdown"
  end

  clear_logistic_request_slots(pair.logistic_requester)
  local request_was_set = set_logistic_request_slot(pair.logistic_requester, 1, stack)
  pair.logistic_request_failed = not request_was_set
  return request_was_set
end

original_0118_advance_logistic_inventory_scan = advance_logistic_inventory_scan
function advance_logistic_inventory_scan(pair)
  if pair and pair.inventory_scan and pair.inventory_scan.current then
    mark_recent_inventory_scan(pair, pair.inventory_scan.current, pair.inventory_scan.kind, pair.inventory_scan.item_name or get_inventory_scan_item_name(pair.inventory_scan))
    pair.inventory_scan.approach_due_tick = nil
    pair.inventory_scan.scan_due_tick = nil
    pair.inventory_scan.current_key = nil
  end
  return original_0118_advance_logistic_inventory_scan(pair)
end

function get_inventory_scan_candidate_key(candidate)
  if not (candidate and candidate.entity and candidate.entity.valid) then return "invalid" end
  local entity_key = candidate.entity.unit_number or (candidate.entity.name .. "@" .. math.floor(candidate.entity.position.x * 32) .. ":" .. math.floor(candidate.entity.position.y * 32))
  return tostring(entity_key) .. ":" .. tostring(candidate.inventory_id or "?")
end

-- Override the 0.1.117 scan handler with an approach timeout. This fixes the
-- observed behavior where priests linger around the same inventory/Cogitator
-- Station instead of giving it one inspection and moving on.
function handle_logistic_inventory_scan(pair)
  if not (pair and pair.priest and pair.priest.valid and pair.station and pair.station.valid and pair.inventory_scan) then return false end
  local scan = pair.inventory_scan
  local candidates = scan.candidates or {}
  local item_name = scan.item_name or get_inventory_scan_item_name(scan)

  while true do
    local candidate = candidates[scan.index or 1]
    if not candidate then
      return finish_failed_logistic_inventory_scan(pair)
    end
    if candidate.entity and candidate.entity.valid and not was_inventory_scanned_recently(pair, candidate, scan.kind, item_name) then
      scan.current = candidate
      local key = get_inventory_scan_candidate_key(candidate)
      if scan.current_key ~= key then
        scan.current_key = key
        scan.approach_due_tick = game.tick + LOGISTIC_INVENTORY_APPROACH_TIMEOUT_TICKS
        scan.scan_due_tick = nil
      end
      break
    end
    scan.index = (scan.index or 1) + 1
  end

  local candidate = scan.current
  local entity = candidate.entity
  pair.target = entity
  draw_logistic_inventory_scan_line(pair, entity)

  local dx = pair.priest.position.x - entity.position.x
  local dy = pair.priest.position.y - entity.position.y
  if dx * dx + dy * dy > LOGISTIC_SCAVENGE_PICKUP_DISTANCE_SQ then
    if game.tick >= (scan.approach_due_tick or 0) then
      mark_recent_inventory_scan(pair, candidate, scan.kind, item_name)
      advance_logistic_inventory_scan(pair)
      return true
    end
    move_priest_to(pair.priest, entity)
    if scan.kind == "cram" then
      pair.mode = "cramming-supplies"
    else
      pair.mode = "scavenging-supplies"
    end
    return true
  end

  if not scan.scan_due_tick then
    scan.scan_due_tick = game.tick + LOGISTIC_INVENTORY_SCAN_TICKS
    draw_priest_status_bubble(pair)
    return true
  end
  if game.tick < scan.scan_due_tick then
    pair.mode = scan.kind == "cram" and "cramming-supplies" or "scavenging-supplies"
    return true
  end

  mark_recent_inventory_scan(pair, candidate, scan.kind, item_name)
  local inventory = get_entity_inventory_safe(entity, candidate.inventory_id)
  if scan.kind == "scavenge" then
    local found = inventory_has_insertable_request_item(pair, inventory, scan.request)
    if found then
      if is_station(entity) then
        local available = inventory and inventory.get_item_count(found.name) or 0
        local polite_count = math.floor(available / 2)
        if polite_count < 1 then
          advance_logistic_inventory_scan(pair)
          return true
        end
        found.count = math.min(found.count or polite_count, polite_count, get_item_stack_size(found.name))
      end
      local real_task = { source = entity, inventory_id = candidate.inventory_id, item_name = found.name, count = found.count or 1, quality = found.quality, kind = scan.request and scan.request.kind }
      clear_logistic_inventory_scan(pair)
      pair.scavenge = real_task
      pair.mode = "scavenging-supplies"
      pair.target = entity
      return original_0116_handle_priest_scavenge_task(pair)
    end
  elseif scan.kind == "cram" and scan.item then
    if inventory and inventory.can_insert(make_item_stack_identification(scan.item.name, 1, scan.item.quality)) then
      local real_task = { destination = entity, inventory_id = candidate.inventory_id, item_name = scan.item.name, count = scan.item.count or 1, quality = scan.item.quality }
      clear_logistic_inventory_scan(pair)
      pair.cram = real_task
      pair.mode = "cramming-supplies"
      pair.target = entity
      return original_0116_handle_priest_cram_task(pair)
    end
    if game.tick >= (scan.dump_due_tick or 0) then
      local item = scan.item
      clear_logistic_inventory_scan(pair)
      pair.cram = nil
      return dump_unwanted_station_stack_near_priest(pair, item)
    end
  end

  advance_logistic_inventory_scan(pair)
  return true
end

function maybe_start_supply_scavenge(pair, kind, target)
  if not (pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid) then return false end
  if not is_cogitator_logistic_requisition_enabled(pair.station.force) then return false end
  ensure_pair_logistic_caches(pair)
  transfer_cache_inventory_to_station(pair)
  if pair.inventory_scan then return handle_logistic_inventory_scan(pair) end
  if pair.scavenge then return handle_priest_scavenge_task(pair) end
  if pair.cram then return handle_priest_cram_task(pair) end

  local request = build_supply_request(pair, kind, target)
  if not request then return false end

  local network = get_station_logistic_network(pair.station)
  if not network then
    if pair.logistic_frustration_kind ~= ("no-network-" .. tostring(kind)) then
      pair.logistic_frustration_kind = "no-network-" .. tostring(kind)
      pair.logistic_requested_item = get_inventory_scan_item_name({ request = request })
      pair.logistic_frustration_start_tick = game.tick
      pair.logistic_frustration_due_tick = game.tick + LOGISTIC_NO_NETWORK_SCAVENGE_TICKS
    end
    if game.tick < (pair.logistic_frustration_due_tick or 0) then
      pair.mode = "logistics-no-network"
      return false
    end
    start_logistic_scavenge_inventory_scan(pair, request)
    return handle_logistic_inventory_scan(pair)
  end

  local issued = issue_station_logistic_request(pair, request)
  if not issued then
    -- If the requester-slot API failed, do not leave the priest idle forever.
    -- Treat it like a failed requisition and use the normal frustration path.
    if not pair.logistic_frustration_due_tick then
      pair.logistic_frustration_start_tick = game.tick
      pair.logistic_frustration_due_tick = game.tick + LOGISTIC_FRUSTRATION_THRESHOLD_TICKS
    end
  end

  if pair.logistic_frustration_kind ~= kind then
    pair.logistic_frustration_kind = kind
    pair.logistic_frustration_start_tick = game.tick
    pair.logistic_frustration_due_tick = game.tick + LOGISTIC_FRUSTRATION_THRESHOLD_TICKS
  end

  if maybe_start_cram_mode(pair, request) then return true end
  if pair.mode == "logistics-cram-countdown" then return false end

  if game.tick < (pair.logistic_frustration_due_tick or 0) then
    pair.mode = "logistics-scavenge-countdown"
    return false
  end
  if game.tick < (pair.next_scavenge_search_tick or 0) then
    pair.mode = "logistics-scavenge-countdown"
    return false
  end

  start_logistic_scavenge_inventory_scan(pair, request)
  return handle_logistic_inventory_scan(pair)
end


-- 0.1.121 debug display and idle scanner pass:
-- * show the currently missing/requested item above the Cogitator Station
-- * add a restrained idle scan behavior with a green animated beam
-- * use a small procedural spiral offset on the scan endpoint so the beam visibly sweeps the target
DEBUG_STATION_REQUEST_RENDER_TTL = 90
IDLE_SCAN_RENDER_TTL = 20
IDLE_SCAN_DURATION_TICKS = 60 * 8
IDLE_SCAN_RETARGET_TICKS = 60 * 10
IDLE_SCAN_MIN_DISTANCE_SQ = 2.25
IDLE_SCAN_SPIRAL_RADIUS = 0.55
TECH_PRIEST_SCAN_ORIGIN_OFFSET = { 0, -1.55 }

original_0121_clear_all_runtime_rendering = clear_all_runtime_rendering
function clear_all_runtime_rendering()
  original_0121_clear_all_runtime_rendering()
  if storage and storage.tech_priests then
    storage.tech_priests.station_request_icons = {}
    storage.tech_priests.idle_scan_lines = {}
    storage.tech_priests.idle_conversation_texts = {}
  end
end

function clear_station_request_icon(pair)
  ensure_storage()
  if not (storage.tech_priests.station_request_icons and pair) then return end
  local station_unit = pair.station_unit or (pair.station and pair.station.valid and pair.station.unit_number)
  if not station_unit then return end
  local object = storage.tech_priests.station_request_icons[station_unit]
  if object then destroy_render_object(object) end
  storage.tech_priests.station_request_icons[station_unit] = nil
end

function get_pair_requested_debug_item(pair)
  if not pair then return nil end
  if pair.inventory_scan then
    local item = get_inventory_scan_item_name(pair.inventory_scan)
    if item and item ~= "" then return item end
  end
  if pair.logistic_requested_item and pair.logistic_requested_item ~= "" then return pair.logistic_requested_item end
  if pair.scavenge and pair.scavenge.item_name then return pair.scavenge.item_name end
  if pair.cram and pair.cram.item_name then return pair.cram.item_name end
  return nil
end

function should_show_station_request_icon(pair)
  if not (pair and pair.station and pair.station.valid) then return false end
  local mode = pair.mode or ""
  if pair.inventory_scan or pair.scavenge or pair.cram then return true end
  if mode == "logistics-requested" or mode == "logistics-scavenge-countdown" or mode == "logistics-cram-countdown" or mode == "logistics-no-network" then return true end
  if mode == "missing-repair-supplies" or mode == "missing-consecration-supplies" or mode == "missing-ammo-supplies" then return true end
  return false
end

function draw_station_request_icon(pair)
  if not read_global_bool_setting("tech-priests-enable-station-request-debug-icons", false) then
    clear_station_request_icon(pair)
    return
  end
  if not should_show_station_request_icon(pair) then
    clear_station_request_icon(pair)
    return
  end
  local item_name = get_pair_requested_debug_item(pair)
  if not item_name or item_name == "" then
    clear_station_request_icon(pair)
    return
  end
  ensure_storage()
  storage.tech_priests.station_request_icons = storage.tech_priests.station_request_icons or {}
  clear_station_request_icon(pair)
  local text = "[item=" .. tostring(item_name) .. "]"
  local object = draw_priest_status_text({
    text = text,
    target = { entity = pair.station, offset = { 0, -3.15 } },
    surface = pair.station.surface,
    color = { r = 0.95, g = 0.85, b = 0.25, a = 0.95 },
    scale = 1.05,
    alignment = "center",
    time_to_live = DEBUG_STATION_REQUEST_RENDER_TTL
  })
  if object then storage.tech_priests.station_request_icons[pair.station.unit_number] = object end
end

function clear_idle_scan_line(pair)
  ensure_storage()
  if not (storage.tech_priests.idle_scan_lines and pair and pair.station_unit) then return end
  local object = storage.tech_priests.idle_scan_lines[pair.station_unit]
  if object then destroy_render_object(object) end
  storage.tech_priests.idle_scan_lines[pair.station_unit] = nil
end

function get_idle_scan_candidates(pair)
  if not (pair and pair.station and pair.station.valid) then return {} end
  local station = pair.station
  local radius = refresh_pair_radius(pair)
  local pos = station.position
  local area = {{pos.x - radius, pos.y - radius}, {pos.x + radius, pos.y + radius}}
  local candidates = {}
  local entities = station.surface.find_entities_filtered({ area = area, force = station.force })
  for _, entity in pairs(entities) do
    if entity.valid and entity ~= station and entity ~= pair.priest and entity.name ~= PROXY_NAME and entity.name ~= LOGISTIC_REQUESTER_CACHE_NAME and entity.name ~= LOGISTIC_RETURN_CACHE_NAME and not is_priest(entity) then
      local dx = entity.position.x - pos.x
      local dy = entity.position.y - pos.y
      local dist = dx * dx + dy * dy
      if dist > 0.25 and dist <= radius * radius then
        candidates[#candidates + 1] = { entity = entity, distance_sq = dist, unit_number = entity.unit_number or 0 }
      end
    end
  end
  table.sort(candidates, function(a, b)
    if math.abs(a.distance_sq - b.distance_sq) > 0.001 then return a.distance_sq < b.distance_sq end
    return (a.unit_number or 0) < (b.unit_number or 0)
  end)
  return candidates
end

function choose_idle_scan_target(pair)
  local candidates = get_idle_scan_candidates(pair)
  if #candidates == 0 then return nil end
  local bucket = math.floor((game.tick or 0) / IDLE_SCAN_RETARGET_TICKS)
  local station_unit = (pair.station and pair.station.valid and pair.station.unit_number) or pair.station_unit or 0
  local index = ((station_unit * 17 + bucket * 11) % #candidates) + 1
  return candidates[index].entity
end

function start_idle_scan(pair)
  if not (pair and pair.priest and pair.priest.valid and pair.station and pair.station.valid) then return false end
  local target = choose_idle_scan_target(pair)
  if not (target and target.valid) then return false end
  pair.idle_scan = {
    target = target,
    started_tick = game.tick,
    due_tick = game.tick + IDLE_SCAN_DURATION_TICKS,
    next_retarget_tick = game.tick + IDLE_SCAN_RETARGET_TICKS
  }
  return true
end

function stop_idle_scan(pair)
  if not pair then return end
  pair.idle_scan = nil
  clear_idle_scan_line(pair)
end

function is_pair_available_for_idle_scan(pair)
  if not read_global_bool_setting("tech-priests-enable-idle-scan-behavior", true) then return false end
  if not (pair and pair.priest and pair.priest.valid and pair.station and pair.station.valid) then return false end
  if pair.target and pair.target.valid then return false end
  if pair.idle_conversation or pair.idle_conversation_listener_until then return false end
  if pair.inventory_scan or pair.scavenge or pair.cram then return false end
  local mode = pair.mode or "idle"
  if mode ~= "idle" and mode ~= "returning" and mode ~= "" then return false end
  return true
end
