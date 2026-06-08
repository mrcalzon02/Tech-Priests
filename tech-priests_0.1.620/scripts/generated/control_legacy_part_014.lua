-- Auto-split control.lua fragment 014 for Tech Priests 0.1.438.
-- Generated mechanically from 0.1.437 monolithic control.lua.
-- Purpose: reduce Lua main-chunk local/register pressure without deleting behavior.


function tech_priests_0248_is_repair_target(station, entity)
  if not (station and station.valid and entity and entity.valid) then return false end
  if is_priest and is_priest(entity) then return false end
  if entity.name == PROXY_NAME then return false end
  if entity.force and station.force and entity.force ~= station.force then return false end
  if not (entity.health and entity.max_health and entity.max_health > 0) then return false end
  if can_fully_use_repair_pack then return can_fully_use_repair_pack(entity) end
  return entity.health < entity.max_health
end

function tech_priests_0248_is_sanctification_target(entity)
  if not (entity and entity.valid) then return false end
  if is_consecration_target then
    local ok, value = pcall(function() return is_consecration_target(entity) end)
    if ok and value then return true end
  end
  return false
end

function tech_priests_0248_inventory_has_ammo(entity)
  if not (entity and entity.valid and entity.get_inventory) then return false end
  local inventories = {
    defines.inventory.chest,
    defines.inventory.cargo_wagon,
    defines.inventory.car_trunk,
    defines.inventory.spider_trunk,
    defines.inventory.character_main,
    defines.inventory.hub_main
  }
  for _, inv_id in pairs(inventories) do
    local ok, inv = pcall(function() return entity.get_inventory(inv_id) end)
    if ok and inv and inv.valid and find_ammo_item and find_ammo_item(inv) then return true end
  end
  return false
end

function tech_priests_0248_entity_score(entity, station, priest)
  if not (entity and entity.valid and station and station.valid) then return 999999999 end
  local station_score = tech_priests_0248_distance_sq(entity.position, station.position)
  local priest_score = priest and priest.valid and tech_priests_0248_distance_sq(entity.position, priest.position) or station_score
  return station_score + priest_score * 0.75
end

function tech_priests_0248_insert_candidate(list, entity, score)
  if not (entity and entity.valid) then return end
  list[#list + 1] = { entity = entity, score = score or 0, tick = game and game.tick or 0 }
end

function tech_priests_0248_prune_cache_list(list)
  local now = game and game.tick or 0
  local out = {}
  for _, record in pairs(list or {}) do
    local e = record and record.entity
    if e and e.valid and now - (record.tick or now) <= TECH_PRIESTS_SWEEP_CACHE_TTL_0248 then
      out[#out + 1] = record
    end
  end
  table.sort(out, function(a, b) return (a.score or 0) < (b.score or 0) end)
  while #out > 64 do table.remove(out) end
  return out
end

function tech_priests_0248_render_sweep(pair, start_pos, end_pos, radius)
  if not (pair and pair.station and pair.station.valid and rendering and rendering.draw_line) then return end
  if not tech_priests_0246_diagnostics_enabled or not tech_priests_0246_diagnostics_enabled() then return end
  if not (storage and storage.tech_priests and storage.tech_priests.debug_overlays_enabled) then return end
  if pair.sweep_0248 and pair.sweep_0248.render_id then
    destroy_render_object(pair.sweep_0248.render_id)
  end
  local ok, id = pcall(function()
    return rendering.draw_line({
      color = { r = 0.6, g = 0.8, b = 1.0, a = 0.5 },
      width = 2,
      from = start_pos,
      to = end_pos,
      surface = pair.station.surface,
      time_to_live = TECH_PRIESTS_SWEEP_RENDER_TTL_0248,
      forces = { pair.station.force }
    })
  end)
  if ok and id then pair.sweep_0248.render_id = id end
end

function tech_priests_0248_update_station_sweep(pair)
  if not tech_priests_0248_valid_pair(pair) then return nil end
  local station = pair.station
  local priest = pair.priest
  local radius = refresh_pair_radius and refresh_pair_radius(pair) or (pair.radius or 20)
  if not (radius and radius > 0) then radius = 20 end
  local sweep = pair.sweep_0248 or { angle = 0, hostiles = {}, repair_targets = {}, sanctify_targets = {}, ammo_sources = {}, supply_sources = {} }
  pair.sweep_0248 = sweep
  sweep.angle = (sweep.angle or 0) + TECH_PRIESTS_SWEEP_STEP_RADIANS_0248
  if sweep.angle > math.pi * 2 then sweep.angle = sweep.angle - math.pi * 2 end
  sweep.last_tick = game and game.tick or 0
  sweep.radius = radius

  sweep.hostiles = tech_priests_0248_prune_cache_list(sweep.hostiles)
  sweep.repair_targets = tech_priests_0248_prune_cache_list(sweep.repair_targets)
  sweep.sanctify_targets = tech_priests_0248_prune_cache_list(sweep.sanctify_targets)
  sweep.ammo_sources = tech_priests_0248_prune_cache_list(sweep.ammo_sources)
  sweep.supply_sources = tech_priests_0248_prune_cache_list(sweep.supply_sources)

  local center = station.position
  local endpoint = { x = center.x + math.cos(sweep.angle) * radius, y = center.y + math.sin(sweep.angle) * radius }
  local area = {
    { math.min(center.x, endpoint.x) - 1.5, math.min(center.y, endpoint.y) - 1.5 },
    { math.max(center.x, endpoint.x) + 1.5, math.max(center.y, endpoint.y) + 1.5 }
  }
  local ok, entities = pcall(function() return station.surface.find_entities_filtered({ area = area }) end)
  if not ok or not entities then return sweep end

  local max_dist_sq = TECH_PRIESTS_SWEEP_WIDTH_0248 * TECH_PRIESTS_SWEEP_WIDTH_0248
  for _, entity in pairs(entities) do
    if entity and entity.valid and entity ~= station and tech_priests_0248_distance_to_segment_sq(entity.position, center, endpoint) <= max_dist_sq then
      local dist_sq = tech_priests_0248_distance_sq(entity.position, center)
      if dist_sq <= radius * radius then
        if tech_priests_0248_is_enemy_of_station(station, entity) then
          tech_priests_0248_insert_candidate(sweep.hostiles, entity, tech_priests_0248_entity_score(entity, station, priest))
        elseif tech_priests_0248_is_repair_target(station, entity) then
          tech_priests_0248_insert_candidate(sweep.repair_targets, entity, tech_priests_0248_entity_score(entity, station, priest))
        elseif tech_priests_0248_is_sanctification_target(entity) then
          tech_priests_0248_insert_candidate(sweep.sanctify_targets, entity, tech_priests_0248_entity_score(entity, station, priest))
        end
        if tech_priests_0248_inventory_has_ammo(entity) then
          tech_priests_0248_insert_candidate(sweep.ammo_sources, entity, dist_sq)
        end
      end
    end
  end

  tech_priests_0248_render_sweep(pair, center, endpoint, radius)
  return sweep
end

function tech_priests_0248_first_valid_from_cache(pair, key, validator)
  if not (pair and pair.sweep_0248 and pair.sweep_0248[key]) then return nil end
  pair.sweep_0248[key] = tech_priests_0248_prune_cache_list(pair.sweep_0248[key])
  for _, record in pairs(pair.sweep_0248[key]) do
    local entity = record and record.entity
    if entity and entity.valid and (not validator or validator(entity)) then return entity end
  end
  return nil
end

function tech_priests_0248_pair_for_station_and_priest(station, priest)
  return tech_priests_0248_get_pair_for_station(station) or tech_priests_0248_get_pair_for_priest(priest)
end

TECH_PRIESTS_FIND_ENEMY_TARGET_BEFORE_0248 = find_enemy_target
function find_enemy_target(station, radius, priest)
  local pair = tech_priests_0248_pair_for_station_and_priest(station, priest)
  if pair then
    local cached = tech_priests_0248_first_valid_from_cache(pair, "hostiles", function(entity)
      return tech_priests_0248_is_enemy_of_station(station, entity) and enemy_inside_station_radius and enemy_inside_station_radius(station, entity, radius or (pair.sweep_0248 and pair.sweep_0248.radius) or 20)
    end)
    if cached then return cached end
  end
  if TECH_PRIESTS_FIND_ENEMY_TARGET_BEFORE_0248 then return TECH_PRIESTS_FIND_ENEMY_TARGET_BEFORE_0248(station, radius, priest) end
  return nil
end

TECH_PRIESTS_FIND_DAMAGED_TARGET_BEFORE_0248 = find_damaged_target
function find_damaged_target(station, radius, priest)
  local pair = tech_priests_0248_pair_for_station_and_priest(station, priest)
  if pair then
    local cached = tech_priests_0248_first_valid_from_cache(pair, "repair_targets", function(entity)
      return tech_priests_0248_is_repair_target(station, entity)
    end)
    if cached then return cached end
  end
  if TECH_PRIESTS_FIND_DAMAGED_TARGET_BEFORE_0248 then return TECH_PRIESTS_FIND_DAMAGED_TARGET_BEFORE_0248(station, radius, priest) end
  return nil
end

TECH_PRIESTS_FIND_CONSECRATION_TARGET_BEFORE_0248 = find_consecration_target_for_station
find_consecration_target_for_station = function(station, radius, priest)
  local pair = tech_priests_0248_pair_for_station_and_priest(station, priest)
  if pair then
    local cached = tech_priests_0248_first_valid_from_cache(pair, "sanctify_targets", function(entity)
      return tech_priests_0248_is_sanctification_target(entity)
    end)
    if cached then return cached end
  end
  if TECH_PRIESTS_FIND_CONSECRATION_TARGET_BEFORE_0248 then return TECH_PRIESTS_FIND_CONSECRATION_TARGET_BEFORE_0248(station, radius, priest) end
  return nil
end

function tech_priests_0248_cancel_idle_layers(pair, reason)
  if not pair then return false end
  local changed = false
  if pair.idle_scan then pair.idle_scan = nil; changed = true end
  if pair.idle_conversation or pair.idle_conversation_listener_until or pair.idle_conversation_speaker_station_unit or pair.idle_conversation_approach_0180 or pair.idle_conversation_approach_listener_until_0180 or pair.idle_conversation_approach_speaker_station_unit_0180 then
    if tech_priests_stop_idle_conversation_0167 then pcall(function() tech_priests_stop_idle_conversation_0167(pair) end) end
    pair.idle_conversation = nil
    pair.idle_conversation_listener_until = nil
    pair.idle_conversation_speaker_station_unit = nil
    pair.idle_conversation_lock_position_0179 = nil
    pair.idle_conversation_locked_surface_0179 = nil
    pair.idle_conversation_locked_force_0179 = nil
    pair.idle_conversation_approach_0180 = nil
    pair.idle_conversation_approach_listener_until_0180 = nil
    pair.idle_conversation_approach_speaker_station_unit_0180 = nil
    changed = true
  end
  if changed then
    pair.idle_quarantine_reason_0248 = tostring(reason or "higher-priority work")
    pair.idle_quarantine_tick_0248 = game and game.tick or 0
    if tech_priests_0246_diagnostics_enabled and tech_priests_0246_diagnostics_enabled() then
      tech_priests_0248_diag("cancelled idle layers for " .. (tech_priests_0246_pair_label and tech_priests_0246_pair_label(pair) or tostring(pair.station_unit)) .. " reason=" .. tostring(reason))
    end
  end
  return changed
end

function tech_priests_0248_higher_priority_probe(pair)
  if not tech_priests_0248_valid_pair(pair) then return { priority = "invalid" } end
  local station, priest = pair.station, pair.priest
  local radius = refresh_pair_radius and refresh_pair_radius(pair) or (pair.radius or 20)
  local hostile = find_enemy_target and find_enemy_target(station, radius, priest) or nil
  if hostile and hostile.valid then return { priority = "attack", target = hostile } end
  if station_has_repair_pack and station_has_repair_pack(station) and find_damaged_target then
    local repair = find_damaged_target(station, radius, priest)
    if repair and repair.valid then return { priority = "repair", target = repair } end
  elseif find_damaged_target then
    local repair_missing = find_damaged_target(station, radius, priest)
    if repair_missing and repair_missing.valid then return { priority = "repair-missing-supplies", target = repair_missing } end
  end
  if station_has_consecration_supply and station_has_consecration_supply(station) and find_consecration_target_for_station then
    local sanctify = find_consecration_target_for_station(station, radius, priest)
    if sanctify and sanctify.valid then return { priority = "sanctify", target = sanctify } end
  elseif find_consecration_status_target then
    local ok, target = pcall(function() return find_consecration_status_target(station, radius, priest, false, false) end)
    if ok and target and target.valid then return { priority = "sanctify-missing-supplies", target = target } end
  end
  return { priority = "idle" }
end

-- Strengthen the 0.1.246 idle availability hooks by consulting a probe that
-- deliberately ignores already-active idle states. This prevents active idle
-- labels/conversations from making the probe self-justify as "idle work".
TECH_PRIESTS_IDLE_SCAN_AVAILABLE_BEFORE_0248 = is_pair_available_for_idle_scan
function is_pair_available_for_idle_scan(pair)
  local probe = tech_priests_0248_higher_priority_probe(pair)
  if probe and probe.priority and probe.priority ~= "idle" and probe.priority ~= "invalid" then
    tech_priests_0248_cancel_idle_layers(pair, probe.priority)
    return false
  end
  if TECH_PRIESTS_IDLE_SCAN_AVAILABLE_BEFORE_0248 then return TECH_PRIESTS_IDLE_SCAN_AVAILABLE_BEFORE_0248(pair) end
  return false
end

TECH_PRIESTS_IDLE_CONVERSATION_AVAILABLE_BEFORE_0248 = tech_priests_is_pair_available_for_idle_conversation_0167
function tech_priests_is_pair_available_for_idle_conversation_0167(pair, as_listener)
  local probe = tech_priests_0248_higher_priority_probe(pair)
  if probe and probe.priority and probe.priority ~= "idle" and probe.priority ~= "invalid" then
    tech_priests_0248_cancel_idle_layers(pair, probe.priority)
    return false
  end
  if TECH_PRIESTS_IDLE_CONVERSATION_AVAILABLE_BEFORE_0248 then return TECH_PRIESTS_IDLE_CONVERSATION_AVAILABLE_BEFORE_0248(pair, as_listener) end
  return false
end

TECH_PRIESTS_TICK_PAIR_BEFORE_0248 = tick_pair
function tick_pair(pair)
  if not pair then return nil end
  if tech_priests_0248_valid_pair(pair) then
    tech_priests_0248_update_station_sweep(pair)
    local probe = tech_priests_0248_higher_priority_probe(pair)
    if probe and probe.priority and probe.priority ~= "idle" and probe.priority ~= "invalid" then
      tech_priests_0248_cancel_idle_layers(pair, probe.priority)
      -- Hostiles are absolute priority. Do not let active idle/scavenge/cram
      -- wrappers consume the tick while a threat or asteroid is inside station
      -- jurisdiction. handle_combat will enter ammo-acquisition doctrine if the
      -- station/proxy lacks ammunition.
      if probe.priority == "attack" and handle_combat then
        local ok, handled = pcall(function() return handle_combat(pair) end)
        if ok and handled then return handled end
        if not ok then tech_priests_0248_diag("combat preemption failed: " .. tostring(handled)) end
      end
    end
  end
  return TECH_PRIESTS_TICK_PAIR_BEFORE_0248(pair)
end

TechPriestsDebugCommandRegistry.add("tp-sweep-debug", "Tech Priests: dump station sweep cache for the selected Cogitator Station.", function(command)
  local player = game.get_player(command.player_index)
  if not (player and player.valid) then return end
  local station = player.selected
  if not (station and station.valid and TIER_CONFIGS and TIER_CONFIGS[station.name]) then
    player.print("[Tech Priests] Select a Cogitator Station, then run /tp-sweep-debug.")
    return
  end
  local pair = tech_priests_0248_get_pair_for_station(station)
  if not pair then
    player.print("[Tech Priests] No registered pair for selected station unit=" .. tostring(station.unit_number))
    return
  end
  tech_priests_0248_update_station_sweep(pair)
  local sweep = pair.sweep_0248 or {}
  local function count(list)
    local n = 0
    for _, record in pairs(list or {}) do if record and record.entity and record.entity.valid then n = n + 1 end end
    return n
  end
  local probe = tech_priests_0248_higher_priority_probe(pair)
  player.print("[Tech Priests] sweep station=" .. station.name .. " unit=" .. tostring(station.unit_number) .. " angle=" .. tostring(math.floor(math.deg(sweep.angle or 0))) .. " radius=" .. tostring(sweep.radius or "?") .. " priority=" .. tostring(probe and probe.priority or "?") .. " hostiles=" .. count(sweep.hostiles) .. " repair=" .. count(sweep.repair_targets) .. " sanctify=" .. count(sweep.sanctify_targets) .. " ammo-sources=" .. count(sweep.ammo_sources))
end)

tech_priests_0248_diag("control.lua priority doctrine repair loaded")


-- 0.1.249 logistics/conversation split repair pass:
-- Keep this late in control.lua so the separated behavior files become the final
-- editable call layers after the historical wrapper stack above has finished loading.
function tech_priests_0249_inventory_contents_summary(inventory, limit)
  if not (inventory and inventory.valid) then return "<no inventory>" end
  local contents = inventory.get_contents()
  local parts = {}
  local n = 0
  for name, count in pairs(contents or {}) do
    n = n + 1
    if n <= (limit or 8) then
      parts[#parts + 1] = tostring(name) .. "=" .. tostring(count)
    end
  end
  if n > (limit or 8) then parts[#parts + 1] = "+" .. tostring(n - (limit or 8)) .. " more" end
  if #parts == 0 then return "empty" end
  table.sort(parts)
  return table.concat(parts, ", ")
end

function tech_priests_0249_logistic_request_slot_summary(entity)
  if not (entity and entity.valid) then return "<missing>" end
  local parts = {}
  for i = 1, LOGISTIC_REQUESTER_SLOT_COUNT or 5 do
    local ok, slot = pcall(function()
      if entity.get_request_slot then return entity.get_request_slot(i) end
      return nil
    end)
    if ok and slot and slot.name then
      parts[#parts + 1] = "slot" .. tostring(i) .. "=" .. tostring(slot.name) .. "x" .. tostring(slot.count or slot.min or 1)
    end
  end
  local ok2, section_parts = pcall(function()
    local point = entity.get_requester_point and entity.get_requester_point()
    if not point then return nil end
    local section = point.get_section and point.get_section(1) or nil
    if not section then return nil end
    local rows = {}
    for i = 1, LOGISTIC_REQUESTER_SLOT_COUNT or 5 do
      local slot = section.get_slot and section.get_slot(i) or nil
      if slot and slot.value and slot.value.name then
        rows[#rows + 1] = "section" .. tostring(i) .. "=" .. tostring(slot.value.name) .. " min" .. tostring(slot.min or "?")
      end
    end
    return rows
  end)
  if ok2 and section_parts then
    for _, row in pairs(section_parts) do parts[#parts + 1] = row end
  end
  if #parts == 0 then return "no active request slots" end
  return table.concat(parts, "; ")
end

function tech_priests_0249_report_logistics_for_station(station, player)
  ensure_storage()
  if not (station and station.valid and is_cogitator_station(station)) then
    if player and player.valid then player.print("[Tech Priests] Select a Cogitator Station first.") end
    return
  end
  local pair = storage.tech_priests.pairs_by_station and storage.tech_priests.pairs_by_station[station.unit_number] or nil
  if not pair then
    if player and player.valid then player.print("[Tech Priests] Selected station is not registered as a priest pair yet: unit " .. tostring(station.unit_number)) end
    return
  end
  local tech_enabled = is_cogitator_logistic_requisition_enabled(station.force)
  local network = get_station_logistic_network(station)
  if tech_enabled and network then ensure_pair_logistic_caches(pair) end
  if pair.logistic_requester and pair.logistic_requester.valid then configure_hidden_logistic_cache(pair.logistic_requester) end
  if pair.logistic_return_cache and pair.logistic_return_cache.valid then configure_hidden_logistic_cache(pair.logistic_return_cache) end
  local station_inventory = get_station_inventory(station)
  local requester_inventory = get_hidden_cache_inventory(pair.logistic_requester)
  local return_inventory = get_hidden_cache_inventory(pair.logistic_return_cache)
  local moved = transfer_cache_inventory_to_station(pair) or 0
  local exported = tech_priests_export_station_trash_to_logistics and tech_priests_export_station_trash_to_logistics(pair, "manual-debug") or 0
  local lines = {
    "[Tech Priests] Logistics debug for " .. tostring(station.name) .. " unit " .. tostring(station.unit_number),
    "  tech " .. tostring(COGITATOR_LOGISTIC_REQUISITION_TECH) .. " researched: " .. tostring(tech_enabled),
    "  logistic network at station: " .. tostring(network ~= nil),
    "  station inventory: " .. tech_priests_0249_inventory_contents_summary(station_inventory, 10),
    "  requester cache valid: " .. tostring(pair.logistic_requester and pair.logistic_requester.valid or false),
    "  requester cache in network: " .. tostring(pair.logistic_requester and pair.logistic_requester.valid and (tech_priests_get_cache_network_present and tech_priests_get_cache_network_present(pair.logistic_requester) or false) or false),
    "  requester inventory: " .. tech_priests_0249_inventory_contents_summary(requester_inventory, 10),
    "  requester slots: " .. tech_priests_0249_logistic_request_slot_summary(pair.logistic_requester),
    "  return/provider cache valid: " .. tostring(pair.logistic_return_cache and pair.logistic_return_cache.valid or false),
    "  return/provider cache in network: " .. tostring(pair.logistic_return_cache and pair.logistic_return_cache.valid and (tech_priests_get_cache_network_present and tech_priests_get_cache_network_present(pair.logistic_return_cache) or false) or false),
    "  return/provider inventory: " .. tech_priests_0249_inventory_contents_summary(return_inventory, 10),
    "  cache->station transfer this check: " .. tostring(moved),
    "  station->provider export this check: " .. tostring(exported),
    "  current requested item: " .. tostring(pair.logistic_requested_item or "none") .. " x" .. tostring(pair.logistic_requested_count or 0),
    "  current mode: " .. tostring(pair.mode or "unknown")
  }
  for _, line in pairs(lines) do
    if player and player.valid then player.print(line) else log(line) end
  end
end

TechPriestsDebugCommandRegistry.add("tp-logistics-debug", "Tech Priests: report selected station logistics-network state, caches, request slots, and inventory transfer/export status.", function(event)
  local player = event and event.player_index and game.get_player(event.player_index) or nil
  local selected = player and player.valid and player.selected or nil
  tech_priests_0249_report_logistics_for_station(selected, player)
end)

require("scripts.idle_priest_conversations")
require("scripts.idle_player_conversations")

-- 0.1.250 Emergency Micro-Miner pseudo-mining diagnostic command.
if commands and commands.add_command then
  pcall(function()
    TechPriestsDebugCommandRegistry.add("tp-emergency-miner-debug", "Tech Priests: report selected Emergency Micro-Miner pseudo-mining recipe state.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index)
      tech_priests_debug_emergency_miner_0250(player, player and player.selected)
    end)
  end)
end


-- 0.1.252 Ranked emergency assignment delegation.
-- Higher-ranking Cogitator Stations may decompose work into tracked item
-- acquisition assignments for lower-ranking stations inside doctrine range.
-- Assignments are intentionally conservative: they wrap the existing emergency
-- acquisition ladder rather than replacing it.
TECH_PRIESTS_ASSIGNMENT_VERSION_0252 = "0.1.252"
TECH_PRIESTS_ASSIGNMENT_RADIUS_MULTIPLIER_0252 = 1.35
TECH_PRIESTS_ASSIGNMENT_RETRY_TICKS_0252 = 60 * 8
TECH_PRIESTS_ASSIGNMENT_TIMEOUT_TICKS_0252 = 60 * 60 * 10
TECH_PRIESTS_ASSIGNMENT_MAX_CHAIN_DEPTH_0252 = 4
TECH_PRIESTS_ASSIGNMENT_DELIVERY_STACK_LIMIT_0252 = 50

function tech_priests_0252_diag(message)
  if log then log("[Tech Priests 0.1.252 assignments] " .. tostring(message)) end
end

function tech_priests_0252_ensure_assignment_storage()
  ensure_storage()
  storage.tech_priests.assignments_0252 = storage.tech_priests.assignments_0252 or {}
  storage.tech_priests.assignment_by_worker_0252 = storage.tech_priests.assignment_by_worker_0252 or {}
  storage.tech_priests.assignment_by_requester_0252 = storage.tech_priests.assignment_by_requester_0252 or {}
  storage.tech_priests.next_assignment_id_0252 = storage.tech_priests.next_assignment_id_0252 or 1
end

function tech_priests_0252_station_unit(pair)
  return pair and pair.station and pair.station.valid and pair.station.unit_number or nil
end

function tech_priests_0252_rank_number(pair)
  local tier = pair and (pair.tier or pair.station_tier or pair.rank)
  if not tier and pair and pair.station and pair.station.valid and TIER_CONFIGS and TIER_CONFIGS[pair.station.name] then
    tier = TIER_CONFIGS[pair.station.name].tier
  end
  if get_pair_rank then
    local ok, rank = pcall(function() return get_pair_rank(pair) end)
    if ok and rank then tier = rank end
  end
  if type(tier) == "number" then return tier end
  if tech_priests_get_tier_rank_0129 then
    local ok, n = pcall(function() return tech_priests_get_tier_rank_0129(tier) end)
    if ok and n then return n end
  end
  local ranks = TECH_PRIESTS_TIER_RANKS_0129 or { junior = 1, intermediate = 2, senior = 3, ["planetary-magos"] = 4, planetary_magos = 4, magos = 4, void = 5 }
  return ranks[tier or "junior"] or 1
end

function tech_priests_0252_valid_pair(pair)
  return pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid
end

function tech_priests_0252_distance_sq(a, b)
  if not (a and b) then return 999999999 end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end

function tech_priests_0252_pair_inventory_count(pair, item_name)
  local inv = pair and pair.station and pair.station.valid and get_station_inventory(pair.station) or nil
  if not (inv and item_name) then return 0 end
  return inv.get_item_count(item_name) or 0
end

function tech_priests_0252_pair_has_assignment(pair)
  tech_priests_0252_ensure_assignment_storage()
  local unit = tech_priests_0252_station_unit(pair)
  if not unit then return false end
  local id = storage.tech_priests.assignment_by_worker_0252[unit]
  local a = id and storage.tech_priests.assignments_0252[id] or nil
  return a ~= nil and a.status == "active"
end

function tech_priests_0252_get_pair_by_station_unit(unit)
  if not (unit and storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return nil end
  return storage.tech_priests.pairs_by_station[unit]
end

function tech_priests_0252_assignment_label(pair)
  if get_pair_display_name then
    local ok, name = pcall(function() return get_pair_display_name(pair) end)
    if ok and name then return tostring(name) end
  end
  return tostring(pair and pair.tier or "station") .. "#" .. tostring(tech_priests_0252_station_unit(pair) or "?")
end

function tech_priests_0252_find_subordinate_pair(requester_pair, item_name, count, chain_depth)
  if not tech_priests_0252_valid_pair(requester_pair) then return nil end
  if not (storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return nil end
  tech_priests_0252_ensure_assignment_storage()
  local requester_rank = tech_priests_0252_rank_number(requester_pair)
  local station = requester_pair.station
  local radius = (refresh_pair_radius and refresh_pair_radius(requester_pair) or requester_pair.radius or 20) * TECH_PRIESTS_ASSIGNMENT_RADIUS_MULTIPLIER_0252
  local best, best_score = nil, nil
  for _, other in pairs(storage.tech_priests.pairs_by_station or {}) do
    if other ~= requester_pair and tech_priests_0252_valid_pair(other) then
      if other.station.surface == station.surface and other.station.force == station.force then
        local other_unit = tech_priests_0252_station_unit(other)
        local other_rank = tech_priests_0252_rank_number(other)
        if other_rank < requester_rank and not storage.tech_priests.assignment_by_worker_0252[other_unit] then
          local dist_sq = tech_priests_0252_distance_sq(other.station.position, station.position)
          local other_radius = refresh_pair_radius and refresh_pair_radius(other) or other.radius or 20
          local allowed = math.max(radius, other_radius * TECH_PRIESTS_ASSIGNMENT_RADIUS_MULTIPLIER_0252)
          if dist_sq <= allowed * allowed then
            local score = dist_sq + (requester_rank - other_rank) * 0.01
            if not best_score or score < best_score then best, best_score = other, score end
          end
        end
      end
    end
  end
  return best
end

function tech_priests_0252_choose_delegatable_need(pair, item_name, count)
  -- Prefer delegating the missing ingredient of a recipe. This lets a Senior
  -- ask an Intermediate for plates, while that Intermediate can ask a Junior
  -- for ore/raw inputs. If no ingredient is known, delegate the item itself.
  if tech_priests_choose_missing_recipe_ingredient_0185 then
    local ok, ingredient = pcall(function() return tech_priests_choose_missing_recipe_ingredient_0185(pair, item_name) end)
    if ok and ingredient and ingredient.name and ingredient.name ~= item_name then
      return ingredient.name, math.max(1, ingredient.count or 1), "ingredient-of-" .. tostring(item_name)
    end
  end
  return item_name, math.max(1, count or 1), "direct"
end

function tech_priests_0252_create_assignment(requester_pair, worker_pair, item_name, count, reason, chain_depth, parent_id)
  if not (tech_priests_0252_valid_pair(requester_pair) and tech_priests_0252_valid_pair(worker_pair) and item_name) then return nil end
  tech_priests_0252_ensure_assignment_storage()
  local requester_unit = tech_priests_0252_station_unit(requester_pair)
  local worker_unit = tech_priests_0252_station_unit(worker_pair)
  if not (requester_unit and worker_unit) then return nil end
  if storage.tech_priests.assignment_by_worker_0252[worker_unit] then return nil end
  local id = storage.tech_priests.next_assignment_id_0252
  storage.tech_priests.next_assignment_id_0252 = id + 1
  local assignment = {
    id = id,
    status = "active",
    item_name = item_name,
    count = math.max(1, count or 1),
    requester_station_unit = requester_unit,
    worker_station_unit = worker_unit,
    requester_rank = tech_priests_0252_rank_number(requester_pair),
    worker_rank = tech_priests_0252_rank_number(worker_pair),
    reason = reason or "emergency-delegation",
    parent_id = parent_id,
    chain_depth = chain_depth or 0,
    created_tick = game.tick,
    updated_tick = game.tick,
    next_tick = game.tick,
    phase = "assigned"
  }
  storage.tech_priests.assignments_0252[id] = assignment
  storage.tech_priests.assignment_by_worker_0252[worker_unit] = id
  storage.tech_priests.assignment_by_requester_0252[requester_unit] = storage.tech_priests.assignment_by_requester_0252[requester_unit] or {}
  storage.tech_priests.assignment_by_requester_0252[requester_unit][id] = true
  worker_pair.assignment_0252 = assignment
  worker_pair.assignment_id_0252 = id
  if tech_priests_draw_emergency_operation_status_0184 then
    tech_priests_draw_emergency_operation_status_0184(requester_pair, "[item=" .. item_name .. "] assigned to " .. tech_priests_0252_assignment_label(worker_pair))
    tech_priests_draw_emergency_operation_status_0184(worker_pair, "[item=" .. item_name .. "] assignment received")
  end
  tech_priests_0252_diag("assignment #" .. tostring(id) .. " " .. tostring(item_name) .. "x" .. tostring(count or 1) .. " requester=" .. tostring(requester_unit) .. " worker=" .. tostring(worker_unit))
  return assignment
end

function tech_priests_0252_clear_assignment(assignment, status, note)
  if not assignment then return end
  tech_priests_0252_ensure_assignment_storage()
  assignment.status = status or "complete"
  assignment.completed_tick = game.tick
  assignment.note = note
  local worker_unit = assignment.worker_station_unit
  local requester_unit = assignment.requester_station_unit
  if worker_unit then storage.tech_priests.assignment_by_worker_0252[worker_unit] = nil end
  if requester_unit and storage.tech_priests.assignment_by_requester_0252[requester_unit] then
    storage.tech_priests.assignment_by_requester_0252[requester_unit][assignment.id] = nil
  end
  local worker = tech_priests_0252_get_pair_by_station_unit(worker_unit)
  if worker then worker.assignment_0252 = nil; worker.assignment_id_0252 = nil; worker.assignment_op_0252 = nil end
  storage.tech_priests.assignments_0252[assignment.id] = assignment
end

function tech_priests_0252_deliver_assignment_item(worker_pair, requester_pair, assignment)
  local worker_inv = worker_pair and worker_pair.station and worker_pair.station.valid and get_station_inventory(worker_pair.station) or nil
  local requester_inv = requester_pair and requester_pair.station and requester_pair.station.valid and get_station_inventory(requester_pair.station) or nil
  if not (worker_inv and requester_inv and assignment and assignment.item_name) then return false end
  local have = worker_inv.get_item_count(assignment.item_name)
  if have <= 0 then return false end
  local wanted = math.max(1, assignment.count or 1)
  local take = math.min(have, wanted, get_item_stack_size and get_item_stack_size(assignment.item_name) or TECH_PRIESTS_ASSIGNMENT_DELIVERY_STACK_LIMIT_0252)
  if get_insertable_item_count then take = get_insertable_item_count(requester_inv, assignment.item_name, take) end
  if take <= 0 then return false end
  local removed = worker_inv.remove({ name = assignment.item_name, count = take })
  if removed <= 0 then return false end
  local inserted = requester_inv.insert({ name = assignment.item_name, count = removed })
  if inserted < removed then worker_inv.insert({ name = assignment.item_name, count = removed - inserted }) end
  assignment.delivered = (assignment.delivered or 0) + inserted
  assignment.updated_tick = game.tick
  assignment.phase = "delivered"
  if inserted > 0 and tech_priests_draw_emergency_operation_status_0184 then
    tech_priests_draw_emergency_operation_status_0184(worker_pair, "[item=" .. assignment.item_name .. "] delivered upward")
    tech_priests_draw_emergency_operation_status_0184(requester_pair, "[item=" .. assignment.item_name .. "] received from subordinate")
  end
  if assignment.delivered >= wanted then tech_priests_0252_clear_assignment(assignment, "complete", "delivered") end
  return inserted > 0
end

TECH_PRIESTS_EMERGENCY_ACQUIRE_BEFORE_ASSIGNMENTS_0252 = tech_priests_emergency_operation_acquire_item_0185
function tech_priests_emergency_operation_acquire_item_0185(pair, item_name, op, count, depth)
  count = math.max(1, count or 1)
  depth = depth or 0
  if not (pair and pair.station and pair.station.valid and item_name and op) then
    if TECH_PRIESTS_EMERGENCY_ACQUIRE_BEFORE_ASSIGNMENTS_0252 then return TECH_PRIESTS_EMERGENCY_ACQUIRE_BEFORE_ASSIGNMENTS_0252(pair, item_name, op, count, depth) end
    return false
  end
  if tech_priests_station_inventory_has_item_0185 and tech_priests_station_inventory_has_item_0185(pair, item_name, count) then
    return false
  end
  tech_priests_0252_ensure_assignment_storage()
  op.assignment_requests_0252 = op.assignment_requests_0252 or {}
  local assign_key = tostring(item_name) .. ":" .. tostring(depth)
  local active_id = op.assignment_requests_0252[assign_key]
  local active = active_id and storage.tech_priests.assignments_0252[active_id] or nil
  if active and active.status == "active" then
    op.phase = "delegated-assignment-wait"
    op.last_item = item_name
    op.next_tick = game.tick + TECH_PRIESTS_ASSIGNMENT_RETRY_TICKS_0252
    return true
  else
    op.assignment_requests_0252[assign_key] = nil
  end

  if depth < TECH_PRIESTS_ASSIGNMENT_MAX_CHAIN_DEPTH_0252 then
    local delegated_item, delegated_count, reason = tech_priests_0252_choose_delegatable_need(pair, item_name, count)
    if delegated_item and not (tech_priests_station_inventory_has_item_0185 and tech_priests_station_inventory_has_item_0185(pair, delegated_item, delegated_count)) then
      local worker = tech_priests_0252_find_subordinate_pair(pair, delegated_item, delegated_count, depth)
      if worker then
        local assignment = tech_priests_0252_create_assignment(pair, worker, delegated_item, delegated_count, reason, depth, op.assignment_parent_id_0252)
        if assignment then
          op.assignment_requests_0252[assign_key] = assignment.id
          op.phase = "delegated-assignment"
          op.last_item = delegated_item
          op.next_tick = game.tick + TECH_PRIESTS_ASSIGNMENT_RETRY_TICKS_0252
          return true
        end
      end
    end
  end

  return TECH_PRIESTS_EMERGENCY_ACQUIRE_BEFORE_ASSIGNMENTS_0252(pair, item_name, op, count, depth)
end

function tech_priests_0252_service_assignment(pair)
  if not tech_priests_0252_valid_pair(pair) then return false end
  tech_priests_0252_ensure_assignment_storage()
  local unit = tech_priests_0252_station_unit(pair)
  local id = unit and storage.tech_priests.assignment_by_worker_0252[unit] or nil
  local assignment = id and storage.tech_priests.assignments_0252[id] or nil
  if not (assignment and assignment.status == "active") then return false end
  local requester = tech_priests_0252_get_pair_by_station_unit(assignment.requester_station_unit)
  if not tech_priests_0252_valid_pair(requester) then
    tech_priests_0252_clear_assignment(assignment, "cancelled", "requester missing")
    return false
  end
  if game.tick - (assignment.created_tick or game.tick) > TECH_PRIESTS_ASSIGNMENT_TIMEOUT_TICKS_0252 then
    tech_priests_0252_clear_assignment(assignment, "failed", "timeout")
    return false
  end
  -- Do not let assignment work override immediate defense/repair/sanctification.
  if tech_priests_0248_higher_priority_probe then
    local ok, probe = pcall(function() return tech_priests_0248_higher_priority_probe(pair) end)
    if ok and probe and probe.priority and probe.priority ~= "idle" and probe.priority ~= "invalid" then
      if probe.priority == "attack" and handle_combat then
        local ok2, handled = pcall(function() return handle_combat(pair) end)
        if ok2 and handled then return true end
      end
      return false
    end
  end
  pair.assignment_0252 = assignment
  pair.assignment_id_0252 = assignment.id
  if tech_priests_0252_pair_inventory_count(pair, assignment.item_name) >= math.max(1, assignment.count or 1) then
    return tech_priests_0252_deliver_assignment_item(pair, requester, assignment)
  end
  if game.tick < (assignment.next_tick or 0) then return true end
  assignment.next_tick = game.tick + TECH_PRIESTS_ASSIGNMENT_RETRY_TICKS_0252
  assignment.updated_tick = game.tick
  assignment.phase = "working"
  local op = pair.assignment_op_0252 or {
    enabled = true,
    reason = "assignment",
    phase = "assignment",
    site = tech_priests_find_emergency_operation_site_0184 and tech_priests_find_emergency_operation_site_0184(pair) or nil,
    next_tick = game.tick,
    started_tick = assignment.created_tick or game.tick,
    assignment_parent_id_0252 = assignment.id,
    assignment_requests_0252 = {}
  }
  pair.assignment_op_0252 = op
  if tech_priests_draw_emergency_operation_status_0184 then
    tech_priests_draw_emergency_operation_status_0184(pair, "[item=" .. assignment.item_name .. "] assignment working")
  end
  return tech_priests_emergency_operation_acquire_item_0185(pair, assignment.item_name, op, assignment.count or 1, (assignment.chain_depth or 0) + 1)
end

TECH_PRIESTS_TICK_PAIR_BEFORE_ASSIGNMENTS_0252 = tick_pair
function tick_pair(pair)
  if pair and tech_priests_0252_service_assignment(pair) then return true end
  return TECH_PRIESTS_TICK_PAIR_BEFORE_ASSIGNMENTS_0252(pair)
end

if commands and commands.add_command then
  pcall(function()
    TechPriestsDebugCommandRegistry.add("tp-assignment-debug", "Tech Priests: report ranked emergency assignment delegation state for selected station.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      if not (player and player.valid) then return end
      tech_priests_0252_ensure_assignment_storage()
      local selected = player.selected
      local pair = nil
      if selected and selected.valid then
        pair = find_pair_by_entity and find_pair_by_entity(selected) or nil
        if not pair and selected.unit_number then pair = tech_priests_0252_get_pair_by_station_unit(selected.unit_number) end
      end
      if not pair then
        player.print("[Tech Priests] Select a Cogitator Station or Tech-Priest for /tp-assignment-debug.")
        return
      end
      local unit = tech_priests_0252_station_unit(pair)
      player.print("[Tech Priests] assignment debug for " .. tech_priests_0252_assignment_label(pair) .. " rank=" .. tostring(tech_priests_0252_rank_number(pair)) .. " unit=" .. tostring(unit))
      local worker_id = storage.tech_priests.assignment_by_worker_0252[unit]
      if worker_id then
        local a = storage.tech_priests.assignments_0252[worker_id]
        player.print("  worker assignment #" .. tostring(worker_id) .. " item=" .. tostring(a and a.item_name) .. " x" .. tostring(a and a.count) .. " requester=" .. tostring(a and a.requester_station_unit) .. " phase=" .. tostring(a and a.phase) .. " status=" .. tostring(a and a.status))
      else
        player.print("  worker assignment: none")
      end
      local reqs = storage.tech_priests.assignment_by_requester_0252[unit]
      local any = false
      for id, _ in pairs(reqs or {}) do
        local a = storage.tech_priests.assignments_0252[id]
        if a then
          any = true
          player.print("  requested assignment #" .. tostring(id) .. " item=" .. tostring(a.item_name) .. " x" .. tostring(a.count) .. " worker=" .. tostring(a.worker_station_unit) .. " phase=" .. tostring(a.phase) .. " status=" .. tostring(a.status))
        end
      end
      if not any then player.print("  requested assignments: none") end
      local subordinate = tech_priests_0252_find_subordinate_pair(pair, "iron-ore", 1, 0)
      player.print("  nearest available subordinate: " .. (subordinate and tech_priests_0252_assignment_label(subordinate) or "none"))
    end)
  end)
end

tech_priests_0252_diag("ranked emergency assignment delegation loaded")

-- 0.1.253 Emergency Laboratorium powered-placement doctrine.
-- The tiny Martian Laboratorium should not be indulged into unpowered darkness.
-- When a priest reaches the lab construction layer it first attempts to place the
-- lab inside an existing electric supply area within the Cogitator Station's
-- command radius. If no such grid exists, the emergency operation is redirected
-- into the local Martian power chain in this order:
--   condenser -> boiler -> steam engine -> power pole -> Laboratorium.
-- This is intentionally implemented as a late doctrine wrapper so it repairs the
-- construction planner without disturbing the prior emergency acquisition stack.

TECH_PRIESTS_EMERGENCY_LAB_ITEM_0253 = "tech-priests-emergency-laboratorium"
TECH_PRIESTS_EMERGENCY_LAB_ENTITY_0253 = "tech-priests-emergency-laboratorium"
TECH_PRIESTS_EMERGENCY_POWER_CHAIN_0253 = {
  "tech-priests-atmospheric-water-condenser",
  "tech-priests-emergency-boiler",
  "tech-priests-emergency-steam-engine",
  "tech-priests-emergency-power-grid"
}
TECH_PRIESTS_EMERGENCY_POWER_CHAIN_NAMES_0253 = {
  ["tech-priests-atmospheric-water-condener"] = true,
  ["tech-priests-atmospheric-water-condenser"] = true,
  ["tech-priests-emergency-boiler"] = true,
  ["tech-priests-emergency-steam-engine"] = true,
  ["tech-priests-emergency-power-grid"] = true
}

function tech_priests_position_in_electric_supply_0253(pair, position)
  if not (pair and pair.station and pair.station.valid and position) then return false end
  local station = pair.station
  local surface = station.surface
  local radius = refresh_pair_radius(pair) or 20
  local area = {{position.x - radius, position.y - radius}, {position.x + radius, position.y + radius}}
  local ok, poles = pcall(function()
    return surface.find_entities_filtered({ area = area, type = "electric-pole", force = station.force })
  end)
  if not (ok and poles) then return false end
  for _, pole in pairs(poles) do
    if pole and pole.valid then
      local supply = 2.5
      pcall(function()
        if pole.prototype and pole.prototype.supply_area_distance then supply = pole.prototype.supply_area_distance end
      end)
      local dx = pole.position.x - position.x
      local dy = pole.position.y - position.y
      if dx * dx + dy * dy <= (supply + 0.35) * (supply + 0.35) then
        return true, pole
      end
    end
  end
  return false
end

function tech_priests_station_has_powered_lab_position_0253(pair)
  if not (pair and pair.station and pair.station.valid) then return false end
  local station = pair.station
  local radius = refresh_pair_radius(pair) or 20
  local area = {{station.position.x - radius, station.position.y - radius}, {station.position.x + radius, station.position.y + radius}}
  local ok, poles = pcall(function()
    return station.surface.find_entities_filtered({ area = area, type = "electric-pole", force = station.force, limit = 1 })
  end)
  return ok and poles and poles[1] ~= nil
end

function tech_priests_find_powered_laboratorium_position_0253(pair, op)
  if not (pair and pair.station and pair.station.valid) then return nil end
  local station = pair.station
  local surface = station.surface
  local site = op and (op.site or (tech_priests_find_emergency_operation_site_0184 and tech_priests_find_emergency_operation_site_0184(pair))) or nil
  local radius = math.min(refresh_pair_radius(pair) or 20, TECH_PRIESTS_EMERGENCY_CONSTRUCTION_RADIUS_0186 or 9)
  local origins = {}
  if site then origins[#origins + 1] = site end
  origins[#origins + 1] = station.position

  local candidates = {}
  for _, origin in pairs(origins) do
    for r = 0, radius do
      for dx = -r, r do
        for dy = -r, r do
          if math.max(math.abs(dx), math.abs(dy)) == r then
            local pos = { x = math.floor(origin.x) + dx + 0.5, y = math.floor(origin.y) + dy + 0.5 }
            local station_radius = refresh_pair_radius(pair) or 20
            if tech_priests_distance_sq_0186 and tech_priests_distance_sq_0186(pos, station.position) <= station_radius * station_radius then
              local in_grid = tech_priests_position_in_electric_supply_0253(pair, pos)
              if in_grid and (not tech_priests_can_place_emergency_entity_at_0186 or tech_priests_can_place_emergency_entity_at_0186(pair, TECH_PRIESTS_EMERGENCY_LAB_ENTITY_0253, pos)) then
                local score = tech_priests_distance_sq_0186 and tech_priests_distance_sq_0186(pos, site or station.position) or r
                candidates[#candidates + 1] = { position = pos, score = score }
              end
            end
          end
        end
      end
    end
  end
  table.sort(candidates, function(a, b) return a.score < b.score end)
  return candidates[1] and candidates[1].position or nil
end

function tech_priests_next_missing_power_chain_item_0253(pair)
  if not (pair and pair.station and pair.station.valid) then return nil end
  for _, item_name in pairs(TECH_PRIESTS_EMERGENCY_POWER_CHAIN_0253) do
    local entity_name = tech_priests_get_entity_prototype_name_from_item_0184 and tech_priests_get_entity_prototype_name_from_item_0184(item_name) or item_name
    if not (tech_priests_station_or_site_has_entity_0184 and tech_priests_station_or_site_has_entity_0184(pair, entity_name)) then
      return item_name
    end
  end
  return nil
end

function tech_priests_ensure_power_chain_before_laboratorium_0253(pair, op)
  if not (pair and pair.station and pair.station.valid and op) then return false end
  if tech_priests_station_or_site_has_entity_0184 and tech_priests_station_or_site_has_entity_0184(pair, TECH_PRIESTS_EMERGENCY_LAB_ENTITY_0253) then return false end
  if tech_priests_find_powered_laboratorium_position_0253(pair, op) then return false end

  local needed = tech_priests_next_missing_power_chain_item_0253(pair)
  if not needed then return false end
  local inv = get_station_inventory and get_station_inventory(pair.station) or nil
  if inv and inv.get_item_count(needed) > 0 then
    if tech_priests_draw_emergency_operation_status_0184 then
      tech_priests_draw_emergency_operation_status_0184(pair, "[item=" .. needed .. "] building Martian power chain before Laboratorium")
    end
    if tech_priests_begin_emergency_construction_0186 then
      return tech_priests_begin_emergency_construction_0186(pair, needed, op)
    end
  end
  if tech_priests_draw_emergency_operation_status_0184 then
    tech_priests_draw_emergency_operation_status_0184(pair, "[item=" .. needed .. "] acquiring Martian power-chain prerequisite")
  end
  if tech_priests_emergency_operation_acquire_item_0185 then
    return tech_priests_emergency_operation_acquire_item_0185(pair, needed, op, 1, 0)
  end
  return false
end

if tech_priests_find_emergency_build_position_0186 then
  TECH_PRIESTS_ORIGINAL_FIND_EMERGENCY_BUILD_POSITION_0253 = tech_priests_find_emergency_build_position_0186
  function tech_priests_find_emergency_build_position_0186(pair, item_name, op)
    if item_name == TECH_PRIESTS_EMERGENCY_LAB_ITEM_0253 then
      local powered = tech_priests_find_powered_laboratorium_position_0253(pair, op)
      if powered then return powered end
    end
    return TECH_PRIESTS_ORIGINAL_FIND_EMERGENCY_BUILD_POSITION_0253(pair, item_name, op)
  end
end

if tech_priests_service_independent_emergency_operation_0184 then
  TECH_PRIESTS_ORIGINAL_SERVICE_INDEPENDENT_EMERGENCY_OPERATION_0253 = tech_priests_service_independent_emergency_operation_0184
  function tech_priests_service_independent_emergency_operation_0184(pair)
    local op = tech_priests_get_emergency_operation_0184 and tech_priests_get_emergency_operation_0184(pair) or (pair and pair.independent_emergency_operation_0184)
    if op and op.enabled and pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid then
      -- Existing construction/craft/scavenge tasks are allowed to finish; this
      -- doctrine intercepts only the planning step before the lab is selected.
      if not op.construction and not pair.emergency_craft and not pair.scavenge then
        if not op.site and tech_priests_find_emergency_operation_site_0184 then op.site = tech_priests_find_emergency_operation_site_0184(pair) end
        if op.site and not (tech_priests_station_or_site_has_entity_0184 and tech_priests_station_or_site_has_entity_0184(pair, TECH_PRIESTS_EMERGENCY_LAB_ENTITY_0253)) then
          if tech_priests_ensure_power_chain_before_laboratorium_0253(pair, op) then return true end
        end
      end
    end
    return TECH_PRIESTS_ORIGINAL_SERVICE_INDEPENDENT_EMERGENCY_OPERATION_0253(pair)
  end
end

TechPriestsDebugCommandRegistry.add("tp-power-chain-debug", "Inspect Emergency Laboratorium powered-placement and Martian power-chain state for the selected Cogitator Station.", function(command)
  local player = game.get_player(command.player_index)
  if not player then return end
  local pair = tech_priests_find_pair_for_player_selection_0184 and tech_priests_find_pair_for_player_selection_0184(player) or nil
  if not pair then
    player.print("[Tech Priests] Select a Cogitator Station or its Tech-Priest first.")
    return
  end
  local op = tech_priests_get_emergency_operation_0184 and tech_priests_get_emergency_operation_0184(pair) or pair.independent_emergency_operation_0184
  local has_lab = tech_priests_station_or_site_has_entity_0184 and tech_priests_station_or_site_has_entity_0184(pair, TECH_PRIESTS_EMERGENCY_LAB_ENTITY_0253) ~= nil
  local powered_pos = tech_priests_find_powered_laboratorium_position_0253(pair, op or {})
  local missing_chain = tech_priests_next_missing_power_chain_item_0253(pair)
  local has_grid = tech_priests_station_has_powered_lab_position_0253(pair)
  player.print("[Tech Priests] Power-chain diagnostic:")
  player.print("  station=" .. tostring(pair.station and pair.station.valid and pair.station.name or "nil") .. " unit=" .. tostring(pair.station_unit or (pair.station and pair.station.valid and pair.station.unit_number) or "nil"))
  player.print("  emergency_op=" .. tostring(op and op.enabled or false) .. " site=" .. tostring(op and op.site and (math.floor(op.site.x) .. "," .. math.floor(op.site.y)) or "nil"))
  player.print("  existing_lab=" .. tostring(has_lab) .. " any_power_grid_in_range=" .. tostring(has_grid))
  player.print("  powered_lab_tile=" .. tostring(powered_pos and (math.floor(powered_pos.x) .. "," .. math.floor(powered_pos.y)) or "none"))
  player.print("  next_missing_power_chain_item=" .. tostring(missing_chain or "none"))
end)


-- 0.1.254 diagnostic command for the Martian fuel bootstrap chain.
if commands and commands.add_command then
  pcall(function()
    TechPriestsDebugCommandRegistry.add("tp-fuel-bootstrap-debug", "Tech Priests: report selected Cogitator Station Martian fuel-bootstrap state.", function(event)
      local player = game.get_player(event.player_index)
      if not player then return end
      local selected = player.selected
      local pair = selected and selected.valid and get_pair_by_station and get_pair_by_station(selected) or nil
      if not pair then
        player.print("[Tech Priests] Select a Cogitator Station for fuel bootstrap diagnostics.")
        return
      end
      player.print("[Tech Priests] Fuel bootstrap diagnostics for station " .. tostring(pair.station and pair.station.unit_number or "?"))
      for entity_name, _ in pairs(TECH_PRIESTS_EMERGENCY_FUELLED_ENTITIES_0254 or {}) do
        local entity = tech_priests_station_or_site_has_entity_0184(pair, entity_name)
        if entity then
          local fuel_inv = tech_priests_get_fuel_inventory_0254(entity)
          local coal = fuel_inv and fuel_inv.get_item_count("coal") or 0
          local wood = fuel_inv and fuel_inv.get_item_count("wood") or 0
          player.print(" - " .. entity_name .. ": present; fuel coal=" .. tostring(coal) .. ", wood=" .. tostring(wood))
        else
          player.print(" - " .. entity_name .. ": absent")
        end
      end
      local inv = get_station_inventory(pair.station)
      player.print(" - station fuel stock: coal=" .. tostring(inv and inv.get_item_count("coal") or 0) .. ", wood=" .. tostring(inv and inv.get_item_count("wood") or 0))
    end)
  end)
end


-- 0.1.255 Planetary Magos standard-industry degradation planner.
-- Planetary Magos rank and above may now expand Independent Emergency Mode
-- beyond the private Martian micro-industry set.  Once the emergency seed chain
-- is alive, Magos doctrine can request and construct standard vanilla machines
-- for mining, smelting, crafting, oil/chemical processing, power, science, and
-- crude belts/pipes/inserters to tie the growing field industry together.
TECH_PRIESTS_MAGOS_PLANNER_VERSION_0255 = "0.1.255"
TECH_PRIESTS_MAGOS_PLANNER_RETRY_TICKS_0255 = 60 * 10
TECH_PRIESTS_MAGOS_PLANNER_MIN_RANK_0255 = 4

TECH_PRIESTS_MAGOS_STANDARD_ENTITY_GROUPS_0255 = {
  power = { "offshore-pump", "boiler", "steam-engine", "small-electric-pole" },
  miners = { "electric-mining-drill", "burner-mining-drill" },
  smelters = { "stone-furnace", "steel-furnace", "electric-furnace" },
  assemblers = { "assembling-machine-1", "assembling-machine-2", "assembling-machine-3" },
  oil = { "oil-refinery" },
  chemical = { "chemical-plant" },
  labs = { "lab" },
  connectors = { "transport-belt", "inserter", "burner-inserter", "pipe", "pipe-to-ground" }
}

TECH_PRIESTS_MAGOS_STANDARD_LAYOUT_0255 = {
  ["offshore-pump"] = { x = -7, y = -3 },
  ["boiler"] = { x = -5, y = -3 },
  ["steam-engine"] = { x = -2, y = -3 },
  ["small-electric-pole"] = { x = 1, y = -3 },
  ["burner-mining-drill"] = { x = -6, y = 1 },
  ["electric-mining-drill"] = { x = -6, y = 1 },
  ["stone-furnace"] = { x = -3, y = 1 },
  ["steel-furnace"] = { x = -3, y = 1 },
  ["electric-furnace"] = { x = -3, y = 1 },
  ["assembling-machine-1"] = { x = 0, y = 1 },
  ["assembling-machine-2"] = { x = 0, y = 1 },
  ["assembling-machine-3"] = { x = 0, y = 1 },
  ["oil-refinery"] = { x = 4, y = 1 },
  ["chemical-plant"] = { x = 8, y = 1 },
  ["lab"] = { x = 0, y = 5 },
  ["transport-belt"] = { x = -1, y = 3 },
  ["inserter"] = { x = 0, y = 3 },
  ["burner-inserter"] = { x = 0, y = 3 },
  ["pipe"] = { x = 3, y = -2 },
  ["pipe-to-ground"] = { x = 4, y = -2 }
}

function tech_priests_0255_diag(message)
  if log then log("[Tech Priests 0.1.255 Magos planner] " .. tostring(message)) end
end

function tech_priests_0255_valid_item(item_name)
  return item_name and tech_priests_get_item_prototype_0440 and tech_priests_get_item_prototype_0440(item_name) ~= nil
end

function tech_priests_0255_valid_entity(entity_name)
  return entity_name and tech_priests_get_entity_prototype_0440 and tech_priests_get_entity_prototype_0440(entity_name) ~= nil
end

function tech_priests_0255_rank_number(pair)
  if tech_priests_0252_rank_number then
    local ok, rank = pcall(function() return tech_priests_0252_rank_number(pair) end)
    if ok and rank then return rank end
  end
  if get_pair_rank then
    local ok, rank = pcall(function() return get_pair_rank(pair) end)
    if ok and rank then
      local ranks = TECH_PRIESTS_TIER_RANKS_0129 or { junior = 1, intermediate = 2, senior = 3, ["planetary-magos"] = 4, planetary_magos = 4, magos = 4, void = 5 }
      return ranks[rank] or (type(rank) == "number" and rank) or 1
    end
  end
  return 1
end

function tech_priests_0255_pair_is_magos_planner(pair)
  if not (pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid) then return false end
  local tier = pair.tier or (TIER_CONFIGS and TIER_CONFIGS[pair.station.name] and TIER_CONFIGS[pair.station.name].tier) or ""
  if tier == "void" then return false end
  return tech_priests_0255_rank_number(pair) >= TECH_PRIESTS_MAGOS_PLANNER_MIN_RANK_0255
end

function tech_priests_0255_find_first_existing(pair, group_name)
  if not (pair and pair.station and pair.station.valid and group_name) then return nil end
  for _, entity_name in pairs(TECH_PRIESTS_MAGOS_STANDARD_ENTITY_GROUPS_0255[group_name] or {}) do
    if tech_priests_0255_valid_entity(entity_name) then
      local found = tech_priests_station_or_site_has_entity_0184 and tech_priests_station_or_site_has_entity_0184(pair, entity_name) or nil
      if found then return found, entity_name end
    end
  end
  return nil
end

function tech_priests_0255_group_present(pair, group_name)
  local found = tech_priests_0255_find_first_existing(pair, group_name)
  return found ~= nil
end

function tech_priests_0255_first_available_item(list)
  for _, item_name in pairs(list or {}) do
    if tech_priests_0255_valid_item(item_name) and tech_priests_0255_valid_entity(item_name) then return item_name end
  end
  return nil
end

function tech_priests_0255_recipe_points_to_oil_or_chemistry(item_name)
  if not item_name then return false end
  local recipe_prototypes = (tech_priests_prototype_table_0440 and tech_priests_prototype_table_0440("recipe")) or {}
  if not next(recipe_prototypes) then return false end
  local signal_words = {
    petroleum = true, sulfur = true, plastic = true, battery = true,
    lubricant = true, rocket = true, chemical = true, acid = true,
    oil = true, gas = true, fluid = true
  }
  for word, _ in pairs(signal_words) do
    if string.find(item_name, word, 1, true) then return true end
  end
  for _, recipe in pairs(recipe_prototypes) do
    local ok_products, products = pcall(function() return recipe.products end)
    if ok_products and products then
      local produces = false
      for _, p in pairs(products) do
        if p and p.name == item_name then produces = true break end
      end
      if produces then
        local ok_cat, category = pcall(function() return recipe.category end)
        if ok_cat and category and (category == "chemistry" or category == "oil-processing" or category == "chemistry-or-cryogenics") then return true end
        local ok_ing, ingredients = pcall(function() return recipe.ingredients end)
        if ok_ing and ingredients then
          for _, ing in pairs(ingredients) do
            if ing and (ing.type == "fluid" or ing.amount and ing.name and string.find(ing.name, "oil", 1, true)) then return true end
          end
        end
      end
    end
  end
  return false
end

function tech_priests_0255_recipe_points_to_smelting(item_name)
  if not item_name then return false end
  local recipe_prototypes = (tech_priests_prototype_table_0440 and tech_priests_prototype_table_0440("recipe")) or {}
  if not next(recipe_prototypes) then return false end
  for _, recipe in pairs(recipe_prototypes) do
    local ok_products, products = pcall(function() return recipe.products end)
    if ok_products and products then
      local produces = false
      for _, p in pairs(products) do if p and p.name == item_name then produces = true break end end
      if produces then
        local ok_cat, category = pcall(function() return recipe.category end)
        if ok_cat and category and (category == "smelting" or category == "metallurgy") then return true end
      end
    end
  end
  return false
end

function tech_priests_0255_current_planning_item(pair, op)
  if not op then return nil end
  if op.last_item then return op.last_item end
  if op.science_item then return op.science_item end
  if tech_priests_get_next_science_objective_0184 then
    local ok, science = pcall(function() return tech_priests_get_next_science_objective_0184(pair, op) end)
    if ok and science then return science end
  end
  return nil
end

function tech_priests_0255_pick_standard_need(pair, op)
  -- The Magos planner degrades from the sacred emergency chain into ordinary
  -- vanilla machinery.  It still acquires items through the existing recipe
  -- decomposition / scrounge / logistics ladder, so player infrastructure can
  -- accelerate the process without becoming mandatory.
  if not (pair and op) then return nil, nil end

  -- Basic vanilla power expansion.  The emergency chain can power the tiny lab;
  -- this chain is for broader standard factory growth.
  if not tech_priests_0255_group_present(pair, "power") then
    return tech_priests_0255_first_available_item(TECH_PRIESTS_MAGOS_STANDARD_ENTITY_GROUPS_0255.power), "standard-power"
  end

  if not tech_priests_0255_group_present(pair, "miners") then
    return tech_priests_0255_first_available_item(TECH_PRIESTS_MAGOS_STANDARD_ENTITY_GROUPS_0255.miners), "standard-mining"
  end
  if not tech_priests_0255_group_present(pair, "smelters") then
    return tech_priests_0255_first_available_item(TECH_PRIESTS_MAGOS_STANDARD_ENTITY_GROUPS_0255.smelters), "standard-smelting"
  end
  if not tech_priests_0255_group_present(pair, "assemblers") then
    return tech_priests_0255_first_available_item(TECH_PRIESTS_MAGOS_STANDARD_ENTITY_GROUPS_0255.assemblers), "standard-assembly"
  end
  if not tech_priests_0255_group_present(pair, "labs") then
    return tech_priests_0255_first_available_item(TECH_PRIESTS_MAGOS_STANDARD_ENTITY_GROUPS_0255.labs), "standard-science"
  end

  local objective_item = tech_priests_0255_current_planning_item(pair, op)
  if objective_item and tech_priests_0255_recipe_points_to_oil_or_chemistry(objective_item) then
    if not tech_priests_0255_group_present(pair, "oil") then
      return tech_priests_0255_first_available_item(TECH_PRIESTS_MAGOS_STANDARD_ENTITY_GROUPS_0255.oil), "oil-processing"
    end
    if not tech_priests_0255_group_present(pair, "chemical") then
      return tech_priests_0255_first_available_item(TECH_PRIESTS_MAGOS_STANDARD_ENTITY_GROUPS_0255.chemical), "chemical-processing"
    end
    if not tech_priests_0255_group_present(pair, "connectors") then
      return tech_priests_0255_first_available_item({ "pipe", "pipe-to-ground" }), "fluid-hookup"
    end
  end
  if objective_item and tech_priests_0255_recipe_points_to_smelting(objective_item) and not tech_priests_0255_group_present(pair, "smelters") then
    return tech_priests_0255_first_available_item(TECH_PRIESTS_MAGOS_STANDARD_ENTITY_GROUPS_0255.smelters), "smelting-bottleneck"
  end

  -- Crude hookup pass: one belt, one inserter, and one pipe/pipe-to-ground if
  -- those items exist.  This is intentionally primitive; it gives the planner
  -- physical hook points without pretending to solve factory routing perfectly.
  for _, item_name in pairs(TECH_PRIESTS_MAGOS_STANDARD_ENTITY_GROUPS_0255.connectors or {}) do
    if tech_priests_0255_valid_item(item_name) and tech_priests_0255_valid_entity(item_name) then
      if not (tech_priests_station_or_site_has_entity_0184 and tech_priests_station_or_site_has_entity_0184(pair, item_name)) then
        return item_name, "crude-hookup"
      end
    end
  end

  return nil, nil
end

function tech_priests_0255_find_offshore_pump_position(pair, op)
  if not (pair and pair.station and pair.station.valid) then return nil end
  local station = pair.station
  local surface = station.surface
  local radius = refresh_pair_radius(pair) or 20
  local base = op and op.site or station.position
  local candidates = {}
  for r = 1, radius do
    for dx = -r, r do
      for dy = -r, r do
        if math.max(math.abs(dx), math.abs(dy)) == r then
          local pos = { x = math.floor(base.x) + dx + 0.5, y = math.floor(base.y) + dy + 0.5 }
          if tech_priests_distance_sq_0186 and tech_priests_distance_sq_0186(pos, station.position) <= radius * radius then
            local ok, can = pcall(function()
              return surface.can_place_entity({ name = "offshore-pump", position = pos, force = station.force })
            end)
            if ok and can then
              candidates[#candidates + 1] = { position = pos, score = tech_priests_distance_sq_0186 and tech_priests_distance_sq_0186(pos, base) or r }
            end
          end
        end
      end
    end
  end
  table.sort(candidates, function(a, b) return (a.score or 0) < (b.score or 0) end)
  return candidates[1] and candidates[1].position or nil
end

if tech_priests_find_emergency_build_position_0186 then
  TECH_PRIESTS_ORIGINAL_FIND_EMERGENCY_BUILD_POSITION_0255 = tech_priests_find_emergency_build_position_0186
  function tech_priests_find_emergency_build_position_0186(pair, item_name, op)
    if tech_priests_0255_pair_is_magos_planner(pair) and item_name and TECH_PRIESTS_MAGOS_STANDARD_LAYOUT_0255[item_name] then
      if item_name == "offshore-pump" then
        local offshore = tech_priests_0255_find_offshore_pump_position(pair, op)
        if offshore then return offshore end
      end
      local station = pair and pair.station
      local site = op and (op.site or (tech_priests_find_emergency_operation_site_0184 and tech_priests_find_emergency_operation_site_0184(pair))) or nil
      if station and station.valid and site then
        op.site = site
        local layout = TECH_PRIESTS_MAGOS_STANDARD_LAYOUT_0255[item_name]
        local preferred = { x = math.floor(site.x + layout.x) + 0.5, y = math.floor(site.y + layout.y) + 0.5 }
        if tech_priests_can_place_emergency_entity_at_0186 and tech_priests_can_place_emergency_entity_at_0186(pair, item_name, preferred) then return preferred end
        local radius = math.min(refresh_pair_radius(pair) or 20, TECH_PRIESTS_EMERGENCY_CONSTRUCTION_RADIUS_0186 or 9)
        local candidates = {}
        for r = 0, radius do
          for dx = -r, r do
            for dy = -r, r do
              if math.max(math.abs(dx), math.abs(dy)) == r then
                local pos = { x = math.floor(preferred.x) + dx + 0.5, y = math.floor(preferred.y) + dy + 0.5 }
                if tech_priests_distance_sq_0186 and tech_priests_distance_sq_0186(pos, station.position) <= (refresh_pair_radius(pair) or 20) ^ 2 then
                  candidates[#candidates + 1] = { position = pos, score = tech_priests_distance_sq_0186(pos, preferred) }
                end
              end
            end
          end
        end
        table.sort(candidates, function(a, b) return (a.score or 0) < (b.score or 0) end)
        for _, c in pairs(candidates) do
          if tech_priests_can_place_emergency_entity_at_0186(pair, item_name, c.position) then return c.position end
        end
      end
    end
    return TECH_PRIESTS_ORIGINAL_FIND_EMERGENCY_BUILD_POSITION_0255(pair, item_name, op)
  end
end

function tech_priests_0255_service_magos_standard_planner(pair, op)
  if not (tech_priests_0255_pair_is_magos_planner(pair) and op and op.enabled) then return false end
  if op.construction or pair.emergency_craft or pair.scavenge then return false end
  if game.tick < (op.magos_planner_next_tick_0255 or 0) then return false end

  -- Do not let standard factory ambitions eclipse the survival seed.  The
  -- emergency Laboratorium is the marker that the Martian chain is alive.
  if not (tech_priests_station_or_site_has_entity_0184 and tech_priests_station_or_site_has_entity_0184(pair, "tech-priests-emergency-laboratorium")) then return false end

  local item_name, reason = tech_priests_0255_pick_standard_need(pair, op)
  if not item_name then
    op.magos_planner_next_tick_0255 = game.tick + TECH_PRIESTS_MAGOS_PLANNER_RETRY_TICKS_0255
    op.magos_planner_phase_0255 = "standard-plan-satisfied"
    return false
  end

  op.magos_planner_next_tick_0255 = game.tick + 30
  op.magos_planner_phase_0255 = reason or "standard-industry"
  op.magos_planner_item_0255 = item_name

  local inv = get_station_inventory and get_station_inventory(pair.station) or nil
  if inv and inv.get_item_count(item_name) > 0 then
    if tech_priests_draw_emergency_operation_status_0184 then
      tech_priests_draw_emergency_operation_status_0184(pair, "[item=" .. item_name .. "] Magos standard " .. tostring(reason or "industry") .. " construction")
    end
    if tech_priests_begin_emergency_construction_0186 then return tech_priests_begin_emergency_construction_0186(pair, item_name, op) end
    return false
  end

  if tech_priests_draw_emergency_operation_status_0184 then
    tech_priests_draw_emergency_operation_status_0184(pair, "[item=" .. item_name .. "] Magos recipe-degraded acquisition: " .. tostring(reason or "standard industry"))
  end
  if tech_priests_emergency_operation_acquire_item_0185 then
    return tech_priests_emergency_operation_acquire_item_0185(pair, item_name, op, 1, 0)
  end
  return false
end

if tech_priests_service_independent_emergency_operation_0184 then
  TECH_PRIESTS_ORIGINAL_SERVICE_INDEPENDENT_EMERGENCY_OPERATION_0255 = tech_priests_service_independent_emergency_operation_0184
  function tech_priests_service_independent_emergency_operation_0184(pair)
    local op = tech_priests_get_emergency_operation_0184 and tech_priests_get_emergency_operation_0184(pair) or (pair and pair.independent_emergency_operation_0184)
    if tech_priests_0255_service_magos_standard_planner(pair, op) then return true end
    return TECH_PRIESTS_ORIGINAL_SERVICE_INDEPENDENT_EMERGENCY_OPERATION_0255(pair)
  end
end

if commands and commands.add_command then
  pcall(function()
    TechPriestsDebugCommandRegistry.add("tp-magos-planner-debug", "Tech Priests: report Planetary Magos standard-industry degradation planning state for the selected station.", function(event)
      local player = game.get_player(event.player_index)
      if not player then return end
      local pair = nil
      if tech_priests_find_pair_for_player_selection_0184 then pair = tech_priests_find_pair_for_player_selection_0184(player) end
      if not pair and player.selected and player.selected.valid and get_pair_by_station then pair = get_pair_by_station(player.selected) end
      if not pair then
        player.print("[Tech Priests] Select a Planetary Magos Cogitator Station or its priest first.")
        return
      end
      local op = tech_priests_get_emergency_operation_0184 and tech_priests_get_emergency_operation_0184(pair) or pair.independent_emergency_operation_0184
      local item, reason = tech_priests_0255_pick_standard_need(pair, op or {})
      player.print("[Tech Priests] Planetary Magos planner diagnostics:")
      player.print("  station=" .. tostring(pair.station and pair.station.valid and pair.station.name or "nil") .. " unit=" .. tostring(pair.station and pair.station.valid and pair.station.unit_number or "nil"))
      player.print("  rank=" .. tostring(tech_priests_0255_rank_number(pair)) .. " magos_planner=" .. tostring(tech_priests_0255_pair_is_magos_planner(pair)))
      player.print("  emergency_op=" .. tostring(op and op.enabled or false) .. " phase=" .. tostring(op and op.phase or "nil"))
      player.print("  magos_phase=" .. tostring(op and op.magos_planner_phase_0255 or "nil") .. " magos_item=" .. tostring(op and op.magos_planner_item_0255 or "nil"))
      player.print("  next_standard_need=" .. tostring(item or "none") .. " reason=" .. tostring(reason or "none"))
      for group_name, _ in pairs(TECH_PRIESTS_MAGOS_STANDARD_ENTITY_GROUPS_0255) do
        local _, entity_name = tech_priests_0255_find_first_existing(pair, group_name)
        player.print("  group " .. tostring(group_name) .. " present=" .. tostring(entity_name or "no"))
      end
    end)
  end)
end

tech_priests_0255_diag("Planetary Magos standard-industry degradation planner loaded")

-- 0.1.256 ranked Cogitator Station expansion doctrine.
-- Split into scripts/magos_station_expansion.lua so the one-tier-lower ghost
-- construction rules can be edited without digging through the main control file.
pcall(function() require("scripts.magos_station_expansion") end)

-- 0.1.257 Planetary Magos ratio-aware recipe planning.
-- Split into scripts/magos_ratio_planning.lua so machine count/rate heuristics
-- can be tuned without digging through the main control file.
pcall(function() require("scripts.magos_ratio_planning") end)

-- 0.1.258 Magos placement safety and machine-detritus jam clearing.
-- Split into scripts/placement_safety_and_detritus.lua so pipe/belt contamination
-- rules and jam-clearing behavior can be edited without digging through control.lua.
pcall(function() require("scripts.placement_safety_and_detritus") end)


-- 0.1.259 Cogitator Station defensive perimeter planning.
-- Split into scripts/defense_perimeter.lua so wall-ring management, breach
-- response, turret placement, and turret ammo service can be edited safely.
pcall(function() require("scripts.defense_perimeter") end)


-- 0.1.259 Planetary Magos resource-directed expansion planning.
-- If dedicated resources are unavailable except through emergency pseudo-miners,
-- expand toward known patches or explore outward until missing resources are generated.
pcall(function() require("scripts.resource_expansion") end)

-- 0.1.264 Emergency arbiter and script-output diagnostics.
-- The UI was correctly displaying Independent / Emergency doctrine as enabled,
-- but the heartbeat/state summaries could still report idle and the script-output
-- folder stayed empty because the diagnostic layer only used log().  This late
-- wrapper makes emergency mode visible as command state, keeps it above idle, and
-- writes a small heartbeat file into script-output so external testing has a
-- durable artifact to inspect.
TECH_PRIESTS_VERSION_0264 = "0.1.265"
TECH_PRIESTS_EMERGENCY_DIAG_FILE_0264 = "tech-priests-emergency-diagnostics.log"

function tech_priests_0264_mod_version()
  local ok, v = pcall(function()
    if script and script.active_mods and script.active_mods["tech-priests"] then return script.active_mods["tech-priests"] end
    return TECH_PRIESTS_VERSION_0264
  end)
  if ok and v then return tostring(v) end
  return TECH_PRIESTS_VERSION_0264
end

function tech_priests_0264_diag_line(text)
  return "[Tech-Priests " .. tech_priests_0264_mod_version() .. "][tick " .. tostring(game and game.tick or 0) .. "] " .. tostring(text or "")
end

function tech_priests_0264_try_write_file(line)
  if not line then return false end

  -- Factorio 2.x exposes script-output file writes through helpers.write_file.
  -- Do not directly index game.write_file; in some 2.x runtimes that key is absent
  -- and the probe itself throws before pcall can protect the actual write.
  if helpers then
    local ok_get, writer = pcall(function() return helpers.write_file end)
    if ok_get and type(writer) == "function" then
      local ok_write = pcall(function()
        writer(TECH_PRIESTS_EMERGENCY_DIAG_FILE_0264, line .. "\n", true)
      end)
      if ok_write then return true end
    end
  end

  -- Older runtimes may still expose game.write_file. Probe only inside pcall.
  if game then
    local ok_get, writer = pcall(function() return game.write_file end)
    if ok_get and type(writer) == "function" then
      local ok_write = pcall(function()
        writer(TECH_PRIESTS_EMERGENCY_DIAG_FILE_0264, line .. "\n", true)
      end)
      if ok_write then return true end
    end
  end

  return false
end

function tech_priests_0264_log(text, also_file)
  local line = tech_priests_0264_diag_line(text)
  log(line)
  if also_file then
    pcall(function() tech_priests_0264_try_write_file(line) end)
  end
end
