-- Auto-split control.lua fragment 003 for Tech Priests 0.1.438.
-- Generated mechanically from 0.1.437 monolithic control.lua.
-- Purpose: reduce Lua main-chunk local/register pressure without deleting behavior.


function dump_unwanted_station_stack_near_priest(pair, item)
  if not (pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid and item and item.name) then return false end
  local station_inventory = get_station_inventory(pair.station)
  if not station_inventory then return false end
  local count = math.min(math.max(1, item.count or 1), get_item_stack_size(item.name))
  local stack = make_item_stack_identification(item.name, count, item.quality)
  local removed = station_inventory.remove(stack)
  if removed <= 0 then return false end

  local drop_stack = make_item_stack_identification(item.name, removed, item.quality)
  local surface = pair.priest.surface or pair.station.surface
  local position = pair.priest.position or pair.station.position
  local ok = false
  if surface and surface.spill_item_stack then
    ok = pcall(function()
      surface.spill_item_stack{
        position = position,
        stack = drop_stack,
        enable_looted = false,
        allow_belts = false,
        force = pair.station.force
      }
    end)
  end
  if not ok and surface and surface.create_entity then
    ok = pcall(function()
      surface.create_entity{ name = "item-on-ground", position = position, stack = drop_stack }
    end)
  end
  if not ok then
    station_inventory.insert(drop_stack)
    return false
  end

  pair.mode = "returning"
  pair.target = nil
  pair.cram = nil
  pair.logistic_cram_start_tick = nil
  pair.logistic_cram_due_tick = nil
  pair.cram_search_started_tick = nil
  pair.cram_dump_due_tick = nil
  return_to_station(pair.priest, pair.station)
  return true
end

function handle_priest_cram_task(pair)
  if not (pair and pair.priest and pair.priest.valid and pair.station and pair.station.valid and pair.cram) then return false end
  local destination = pair.cram.destination
  if not (destination and destination.valid) then
    pair.cram = nil
    pair.next_cram_search_tick = game.tick + LOGISTIC_SCAVENGE_RETRY_TICKS
    return false
  end
  local dx = pair.priest.position.x - destination.position.x
  local dy = pair.priest.position.y - destination.position.y
  if dx * dx + dy * dy > LOGISTIC_SCAVENGE_PICKUP_DISTANCE_SQ then
    move_priest_to(pair.priest, destination)
    pair.mode = "moving-to-cram"
    pair.target = destination
    return true
  end
  if try_deposit_cram_item(pair) then return true end
  pair.cram = nil
  pair.next_cram_search_tick = game.tick + LOGISTIC_SCAVENGE_RETRY_TICKS
  return false
end

function maybe_start_cram_mode(pair, request)
  if not (pair and pair.station and pair.station.valid and request) then return false end
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
  if not pair.cram_search_started_tick then
    pair.cram_search_started_tick = game.tick
    pair.cram_dump_due_tick = game.tick + LOGISTIC_CRAM_SEARCH_BEFORE_DUMP_TICKS
  end
  if game.tick < (pair.next_cram_search_tick or 0) then
    pair.mode = "logistics-cram-countdown"
    return false
  end
  local unwanted = find_unwanted_station_stack_for_request(pair, request)
  if not unwanted then
    pair.next_cram_search_tick = game.tick + LOGISTIC_SCAVENGE_RETRY_TICKS
    pair.mode = "logistics-cram-countdown"
    return false
  end
  local destination = find_cram_destination_for_item(pair, unwanted)
  if destination then
    pair.cram = destination
    pair.mode = "cramming-supplies"
    pair.target = destination.destination
    return handle_priest_cram_task(pair)
  end
  if game.tick >= (pair.cram_dump_due_tick or 0) then
    return dump_unwanted_station_stack_near_priest(pair, unwanted)
  end
  pair.next_cram_search_tick = game.tick + LOGISTIC_SCAVENGE_RETRY_TICKS
  pair.mode = "logistics-cram-countdown"
  return false
end

-- 0.1.112 logistics bridge: use real requester/provider logistics instead of
-- directly removing items from the logistic network. The visible Cogitator
-- Station stays a normal container; these hidden caches let bots do the hauling.
function configure_hidden_logistic_cache(entity)
  if not (entity and entity.valid) then return end
  pcall(function() entity.destructible = false end)
  pcall(function() entity.operable = false end)
  pcall(function() entity.minable = false end)
  pcall(function() entity.rotatable = false end)
  pcall(function() entity.request_from_buffers = true end)
  pcall(function()
    local point = entity.get_requester_point and entity.get_requester_point()
    if point then
      point.enabled = true
      point.trash_not_requested = false
    end
  end)
end

function create_hidden_logistic_cache_for_pair(pair, entity_name, offset)
  if not (pair and pair.station and pair.station.valid) then return nil end
  local station = pair.station
  -- Spawn exactly under the Cogitator Station. Offset helper chests leak badly
  -- through the logistic-network overlay and make the station look duplicated.
  local entity = station.surface.create_entity({
    name = entity_name,
    position = station.position,
    force = station.force,
    raise_built = false
  })
  configure_hidden_logistic_cache(entity)
  return entity
end

function ensure_pair_logistic_caches(pair)
  if not (pair and pair.station and pair.station.valid) then return false end
  if not (pair.logistic_requester and pair.logistic_requester.valid) then
    pair.logistic_requester = create_hidden_logistic_cache_for_pair(pair, LOGISTIC_REQUESTER_CACHE_NAME)
  else
    pcall(function() if tech_priests_align_hidden_support_0430 then tech_priests_align_hidden_support_0430(pair.logistic_requester, pair.station, "hidden requester cache follows station", pair) else pair.logistic_requester.teleport(pair.station.position) end end)
    configure_hidden_logistic_cache(pair.logistic_requester)
  end
  if not (pair.logistic_return_cache and pair.logistic_return_cache.valid) then
    pair.logistic_return_cache = create_hidden_logistic_cache_for_pair(pair, LOGISTIC_RETURN_CACHE_NAME)
  else
    pcall(function() if tech_priests_align_hidden_support_0430 then tech_priests_align_hidden_support_0430(pair.logistic_return_cache, pair.station, "hidden return cache follows station", pair) else pair.logistic_return_cache.teleport(pair.station.position) end end)
    configure_hidden_logistic_cache(pair.logistic_return_cache)
  end
  return pair.logistic_requester and pair.logistic_requester.valid
end

function destroy_all_hidden_logistic_caches_on_surface(surface)
  if not surface then return end
  for _, name in pairs({ LOGISTIC_REQUESTER_CACHE_NAME, LOGISTIC_RETURN_CACHE_NAME }) do
    local entities = surface.find_entities_filtered({ name = name })
    for _, entity in pairs(entities or {}) do
      if entity and entity.valid then entity.destroy({ raise_destroy = false }) end
    end
  end
end

function rebuild_all_hidden_logistic_caches()
  ensure_storage()
  for _, surface in pairs(game.surfaces or {}) do
    destroy_all_hidden_logistic_caches_on_surface(surface)
  end
  for _, pair in pairs(storage.tech_priests.pairs_by_station or {}) do
    pair.logistic_requester = nil
    pair.logistic_return_cache = nil
    if pair.station and pair.station.valid and is_cogitator_logistic_requisition_enabled(pair.station.force) and get_station_logistic_network(pair.station) then
      ensure_pair_logistic_caches(pair)
    end
  end
end

function get_hidden_cache_inventory(entity)
  if not (entity and entity.valid) then return nil end
  local ok, inv = pcall(function() return entity.get_inventory(defines.inventory.chest) end)
  if ok and inv and inv.valid then return inv end
  return nil
end

function clear_logistic_request_slots(entity)
  if not (entity and entity.valid) then return false end
  local any = false
  for i = 1, LOGISTIC_REQUESTER_SLOT_COUNT do
    local ok = pcall(function() entity.set_request_slot(nil, i) end)
    any = any or ok
    local ok2 = pcall(function()
      local cb = entity.get_control_behavior and entity.get_control_behavior()
      if cb and cb.set_request_slot then cb.set_request_slot(nil, i) end
    end)
    any = any or ok2
  end
  local ok3, cleared = pcall(function()
    local point = entity.get_requester_point and entity.get_requester_point()
    if not point then return false end
    point.enabled = true
    local section = nil
    if point.get_section then section = point.get_section(1) end
    if not section and point.add_section then section = point.add_section() end
    if not section then return false end
    if section.active ~= nil then section.active = true end
    for i = 1, LOGISTIC_REQUESTER_SLOT_COUNT do
      if section.clear_slot then section.clear_slot(i) end
    end
    return true
  end)
  any = any or (ok3 and cleared)
  return any
end

function set_logistic_request_slot(entity, slot_index, stack)
  if not (entity and entity.valid and stack and stack.name and (stack.count or 0) > 0) then return false end
  slot_index = slot_index or 1
  local request = make_item_stack_identification(stack.name, stack.count, stack.quality)

  -- Factorio 1.1/compatibility API. Verify success instead of accepting a
  -- protected no-op as success.
  local ok, result = pcall(function()
    if not entity.set_request_slot then return false end
    entity.set_request_slot(request, slot_index)
    local readback = entity.get_request_slot and entity.get_request_slot(slot_index) or nil
    return readback and readback.name == stack.name
  end)
  if ok and result then return true end

  -- Some builds expose the slot method on the control behavior.
  ok, result = pcall(function()
    local cb = entity.get_control_behavior and entity.get_control_behavior()
    if not (cb and cb.set_request_slot) then return false end
    cb.set_request_slot(request, slot_index)
    return true
  end)
  if ok and result then return true end

  -- Factorio 2.x requester chests use LuaLogisticPoint/LuaLogisticSection.
  -- The logistic point has get_section/add_section methods; point.sections is
  -- just the section array, not the section manager.
  ok, result = pcall(function()
    local point = entity.get_requester_point and entity.get_requester_point()
    if not point then return false end
    point.enabled = true
    pcall(function() point.trash_not_requested = false end)
    pcall(function() entity.request_from_buffers = true end)

    local section = nil
    if point.get_section then section = point.get_section(1) end
    if not section and point.add_section then section = point.add_section() end
    if not section then return false end
    if section.active ~= nil then section.active = true end

    local filter = {
      value = { type = "item", name = stack.name },
      min = stack.count or 1
    }
    -- Setting max to min avoids a tiny hidden requester accumulating far more
    -- than the station can accept when many stations are active.
    filter.max = stack.count or 1
    if stack.quality and stack.quality ~= "normal" then
      filter.value.quality = stack.quality
    end
    if not section.set_slot then return false end
    section.set_slot(slot_index, filter)
    local readback = section.get_slot and section.get_slot(slot_index) or nil
    return readback and readback.value and readback.value.name == stack.name
  end)
  return ok and result or false
end

function transfer_cache_inventory_to_station(pair)
  if not (pair and pair.station and pair.station.valid and pair.logistic_requester and pair.logistic_requester.valid) then return 0 end
  local source = get_hidden_cache_inventory(pair.logistic_requester)
  local station_inventory = get_station_inventory(pair.station)
  if not (source and station_inventory and source.valid and station_inventory.valid) then return 0 end
  local moved = 0

  for i = 1, #source do
    local stack = source[i]
    if stack and stack.valid_for_read then
      -- Cache every LuaItemStack field we need before removing anything.
      -- After source.remove() empties a slot, that LuaItemStack can become invalid for read.
      local item_name = stack.name
      local quality_name = get_stack_quality_name(stack)
      local count = stack.count

      if item_name and count and count > 0 then
        local request = make_item_stack_identification(item_name, count, quality_name)
        if station_inventory.can_insert(request) then
          local removed = source.remove(request)
          if removed and removed > 0 then
            local inserted = station_inventory.insert(make_item_stack_identification(item_name, removed, quality_name))
            moved = moved + inserted
            if inserted < removed then
              source.insert(make_item_stack_identification(item_name, removed - inserted, quality_name))
            end
          end
        end
      end
    end
  end

  if moved > 0 then
    clear_logistic_frustration(pair)
  end
  return moved
end

function item_matches_logistic_request(item_name, request)
  if not (item_name and request) then return false end
  if request.kind == "ammo" then return is_ammo_item(item_name) end
  for _, candidate in pairs(request.candidates or {}) do
    if candidate.name == item_name then return true end
  end
  return false
end

function eject_one_unwanted_station_item(pair, request)
  if not (pair and pair.station and pair.station.valid and pair.logistic_return_cache and pair.logistic_return_cache.valid) then return false end
  local station_inventory = get_station_inventory(pair.station)
  local return_inventory = get_hidden_cache_inventory(pair.logistic_return_cache)
  if not (station_inventory and return_inventory) then return false end

  for i = 1, #station_inventory do
    local stack = station_inventory[i]
    if stack and stack.valid_for_read and not item_matches_logistic_request(stack.name, request) then
      local quality = get_stack_quality_name(stack)
      local move = make_item_stack_identification(stack.name, math.min(get_item_stack_size(stack.name), stack.count), quality)
      if return_inventory.can_insert(move) then
        local removed = station_inventory.remove(move)
        if removed > 0 then
          local inserted = return_inventory.insert(make_item_stack_identification(stack.name, removed, quality))
          if inserted < removed then
            station_inventory.insert(make_item_stack_identification(stack.name, removed - inserted, quality))
          end
          pair.mode = "logistics-clearing-space"
          pair.logistic_clear_space_tick = game.tick
          return inserted > 0
        end
      end
    end
  end
  return false
end

function choose_logistic_request_stack(pair, request)
  if not (pair and pair.station and pair.station.valid and request) then return nil end
  local network = get_station_logistic_network(pair.station)
  local station_inventory = get_station_inventory(pair.station)
  if not station_inventory then return nil end

  if request.kind == "ammo" then
    local ammo_name = network and find_best_logistic_ammo_for_station(pair, network, station_inventory) or nil
    if not ammo_name then ammo_name = "firearm-magazine" end
    return { name = ammo_name, count = LOGISTIC_REQUISITION_AMMO_BATCH_SIZE }
  end

  local best = nil
  local best_available = nil
  for _, candidate in pairs(request.candidates or {}) do
    local available = network and logistic_network_item_count(network, { name = candidate.name, count = 1 }) or 0
    if available > 0 then
      if not best_available or (candidate.score or 0) > (best_available.score or 0) then
        best_available = candidate
      end
    end
    if not best or (candidate.score or 0) > (best.score or 0) then
      best = candidate
    end
  end
  local selected = best_available or best
  if selected then return { name = selected.name, count = selected.count or 1 } end
  return nil
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
  set_logistic_request_slot(pair.logistic_requester, 1, stack)
  return true
end

-- Override the previous direct network-vacuum requisition. This version sets
-- real requester-chest requests and lets robots deliver to the hidden cache,
-- then moves delivered goods into the visible Cogitator inventory when space
-- exists.
function perform_station_logistic_requisition(pair)
  if not (pair and pair.station and pair.station.valid) then return false end
  if not is_cogitator_logistic_requisition_enabled(pair.station.force) then return false end
  ensure_pair_logistic_caches(pair)
  if transfer_cache_inventory_to_station(pair) > 0 then return true end

  if station_has_enemy_pressure(pair) then
    return issue_station_logistic_request(pair, build_supply_request(pair, "ammo", pair.target))
  end
  if pair.mode == "missing-repair-supplies" then
    return issue_station_logistic_request(pair, build_supply_request(pair, "repair", pair.target))
  end
  if pair.mode == "missing-consecration-supplies" then
    return issue_station_logistic_request(pair, build_supply_request(pair, "consecration", pair.target))
  end

  -- Gentle background stocking, with the same one-class-per-cycle restraint as
  -- before. The requests are tiny because junior stations are intentionally tiny.
  local inventory = get_station_inventory(pair.station)
  if not inventory then return false end
  if count_station_ammo_items(pair.station) < LOGISTIC_REQUISITION_AMMO_TARGET_STOCK then
    return issue_station_logistic_request(pair, build_supply_request(pair, "ammo", pair.target))
  end
  if inventory.get_item_count("repair-pack") < LOGISTIC_REQUISITION_REPAIR_TARGET_STOCK then
    return issue_station_logistic_request(pair, build_supply_request(pair, "repair", pair.target))
  end
  if count_station_consecration_items(pair.station) < LOGISTIC_REQUISITION_CONSECRATION_TARGET_STOCK then
    return issue_station_logistic_request(pair, build_supply_request(pair, "consecration", pair.target))
  end
  clear_logistic_request_slots(pair.logistic_requester)
  return false
end

-- Override frustration/scavenging: after the logistics upgrade, the priest now
-- waits on the requester cache and, if blocked, makes room by pushing unwanted
-- station contents into the active-provider return cache instead of directly
-- stealing from nearby chests.
function maybe_start_supply_scavenge(pair, kind, target)
  if not (pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid) then return false end
  if not is_cogitator_logistic_requisition_enabled(pair.station.force) then return false end
  ensure_pair_logistic_caches(pair)
  transfer_cache_inventory_to_station(pair)
  if pair.scavenge then return handle_priest_scavenge_task(pair) end
  if pair.cram then return handle_priest_cram_task(pair) end

  local request = build_supply_request(pair, kind, target)
  if not request then return false end
  local issued = issue_station_logistic_request(pair, request)
  if not issued then return false end

  -- Timer 1: requested item did not arrive after the full logistics patience
  -- window, so the priest begins local scavenging inside station radius.
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

  local source = find_scavenge_source_for_request(pair, request)
  if source then
    pair.scavenge = source
    pair.mode = "scavenging-supplies"
    pair.target = source.source
    return handle_priest_scavenge_task(pair)
  end

  pair.next_scavenge_search_tick = game.tick + LOGISTIC_SCAVENGE_RETRY_TICKS
  pair.mode = "logistics-scavenge-countdown"
  return false
end

function station_has_repair_pack(station)
  local inventory = get_station_inventory(station)
  return inventory and inventory.get_item_count("repair-pack") > 0
end

function consume_repair_pack(station)
  local inventory = get_station_inventory(station)
  if not inventory then return false end
  return inventory.remove({ name = "repair-pack", count = 1 }) > 0
end

function get_station_consecration_item_options()
  return {
    { name = RITUAL_OF_MACHINE_APPEASEMENT_NAME, amount = RITUAL_OF_MACHINE_APPEASEMENT_RESTORE_AMOUNT },
    { name = MACHINE_MAINTENANCE_LITANY_NAME, amount = MACHINE_MAINTENANCE_LITANY_RESTORE_AMOUNT },
    { name = SACRED_OIL_NAME, amount = PRIEST_CONSECRATION_AMOUNT_PER_OIL }
  }
end

function get_available_station_consecration_item(station, minimum_missing_sanctification)
  local inventory = get_station_inventory(station)
  if not inventory then return nil end

  local required_missing = minimum_missing_sanctification or 0
  for _, option in pairs(get_station_consecration_item_options()) do
    if inventory.get_item_count(option.name) > 0 and option.amount <= required_missing then
      return option
    end
  end

  return nil
end

function station_has_consecration_item(station)
  local inventory = get_station_inventory(station)
  if not inventory then return false end
  for _, option in pairs(get_station_consecration_item_options()) do
    if inventory.get_item_count(option.name) > 0 then return true end
  end
  return false
end

function consume_consecration_item_from_station(station, item_name)
  local inventory = get_station_inventory(station)
  if not inventory then return false end
  return inventory.remove({ name = item_name, count = 1 }) > 0
end

function get_turret_ammo_inventory(proxy)
  if not (proxy and proxy.valid) then return nil end
  local ok, inventory = pcall(function()
    return proxy.get_inventory(defines.inventory.turret_ammo)
  end)
  if ok then return inventory end
  return nil
end

function turret_inventory_has_ammo(inventory)
  return find_ammo_item(inventory) ~= nil
end

function count_inventory_items(inventory)
  if not inventory then return 0 end
  local total = 0
  for i = 1, #inventory do
    local stack = inventory[i]
    if stack and stack.valid_for_read then
      total = total + stack.count
    end
  end
  return total
end

function describe_proxy_state(pair, proxy, target, label)
  if not COMBAT_DEBUG then return end
  if not (pair and proxy and proxy.valid) then return end
  local inv = get_turret_ammo_inventory(proxy)
  local ammo_count = count_inventory_items(inv)
  local distance = -1
  if target and target.valid then
    local dx = proxy.position.x - target.position.x
    local dy = proxy.position.y - target.position.y
    distance = math.sqrt(dx * dx + dy * dy)
  end
  combat_debug(pair, label .. ": proxy ammo=" .. ammo_count .. ", distance=" .. string.format("%.1f", distance) .. ", active=" .. tostring(proxy.active))
end

function ensure_proxy(pair)
  if pair.proxy and pair.proxy.valid then
    return pair.proxy
  end

  local station = pair.station
  local priest = pair.priest
  if not (station and station.valid and priest and priest.valid) then return nil end

  local proxy = station.surface.create_entity({
    name = PROXY_NAME,
    position = priest.position,
    quality = get_entity_quality_name(station),
    force = station.force,
    raise_built = false,
    create_build_effect_smoke = false
  })

  if not (proxy and proxy.valid) then
    combat_debug(pair, "failed to create hidden small-arms proxy")
    return nil
  end

  pcall(function() proxy.destructible = false end)
  pcall(function() proxy.operable = false end)
  pcall(function() proxy.active = true end)

  pair.proxy = proxy
  combat_debug(pair, "created hidden small-arms proxy")
  return proxy
end

function deactivate_proxy(pair)
  if pair and pair.proxy and pair.proxy.valid then
    pcall(function() pair.proxy.shooting_target = nil end)
  end
end

function cleanup_expired_proxy(pair)
  if not (pair and pair.proxy and pair.proxy.valid) then return end
  if game.tick <= (pair.proxy_expires or 0) then return end
  pcall(function() pair.proxy.shooting_target = nil end)
end

function load_proxy_from_station(pair)
  local station = pair.station
  local proxy = ensure_proxy(pair)
  if not (station and station.valid and proxy and proxy.valid) then return false end

  local proxy_inventory = get_turret_ammo_inventory(proxy)
  if not proxy_inventory then
    combat_debug(pair, "proxy exists, but no turret ammo inventory was available")
    return false
  end

  if turret_inventory_has_ammo(proxy_inventory) then
    return true
  end

  local station_inventory = get_station_inventory(station)
  if not station_inventory then return false end

  -- The real compatibility path: if the hidden gun-turret inventory accepts the
  -- ammo item, we let Factorio fire that actual ammo behavior.
  for index = 1, #station_inventory do
    local stack = station_inventory[index]
    if stack and stack.valid_for_read and is_ammo_item(stack.name) then
      local ammo_name = stack.name
      local quality_name = get_stack_quality_name(stack)
      local transfer_stack = make_item_stack_identification(ammo_name, 1, quality_name)

      if proxy_inventory.can_insert(transfer_stack) then
        local removed = station_inventory.remove(transfer_stack)
        if removed > 0 then
          local inserted = proxy_inventory.insert(transfer_stack)
          if inserted > 0 then
            combat_debug(pair, "loaded proxy with accepted turret ammo: " .. ammo_name .. " [" .. quality_name .. "]")
            return true
          end

          local refund_stack = make_item_stack_identification(ammo_name, removed, quality_name)
          station_inventory.insert(refund_stack)
          combat_debug(pair, "proxy accepted test for " .. ammo_name .. " [" .. quality_name .. "] but insert failed")
        end
      else
        combat_debug(pair, "station ammo " .. ammo_name .. " [" .. quality_name .. "] is not accepted by the small-arms proxy")
      end
    end
  end

  combat_debug(pair, "enemy found, but no proxy-compatible ammo was found in Cogitator Station")
  return false
end

function get_entity_health_or_nil(entity)
  if not (entity and entity.valid) then return nil end
  local ok, health = pcall(function() return entity.health end)
  if ok then return health end
  return nil
end

function is_asteroid_threat_entity(entity)
  if not (entity and entity.valid) then return false end
  local ok_type, entity_type = pcall(function() return entity.type end)
  if ok_type and entity_type == "asteroid" then return true end

  -- Fallback for Space Age/prototype combinations where runtime filtering by
  -- type is not available or where modded asteroid entities expose only their
  -- prototype name. Do not classify collectible asteroid chunks as threats.
  local name = entity.name or ""
  if string.find(name, "%-asteroid%-chunk") then return false end
  return string.match(name, "^small%-.*%-asteroid$")
      or string.match(name, "^medium%-.*%-asteroid$")
      or string.match(name, "^big%-.*%-asteroid$")
      or string.match(name, "^huge%-.*%-asteroid$")
end

function get_asteroid_threat_weight(entity)
  local name = entity and entity.name or ""
  if string.find(name, "^huge%-") then return 3.00 end
  if string.find(name, "^big%-") then return 2.25 end
  if string.find(name, "^medium%-") then return 1.50 end
  return 1.00
end

function score_threat_to_station_and_priest(entity, station_position, priest)
  local sdx = entity.position.x - station_position.x
  local sdy = entity.position.y - station_position.y
  local station_distance_sq = sdx * sdx + sdy * sdy
  local score = station_distance_sq

  if priest and priest.valid then
    local pdx = entity.position.x - priest.position.x
    local pdy = entity.position.y - priest.position.y
    local priest_distance_sq = pdx * pdx + pdy * pdy
    -- Defend the most immediate threat either to the shrine/station or to the
    -- Tech-Priest himself.
    score = math.min(station_distance_sq, priest_distance_sq)
  end

  if is_asteroid_threat_entity(entity) then
    score = score / get_asteroid_threat_weight(entity)
  end

  return score, station_distance_sq
end

function find_space_asteroid_targets(surface, area)
  local targets = {}

  local ok, asteroids = pcall(function()
    return surface.find_entities_filtered({ area = area, type = "asteroid" })
  end)
  if ok and asteroids then
    for _, entity in pairs(asteroids) do
      if is_asteroid_threat_entity(entity) then
        table.insert(targets, entity)
      end
    end
    return targets
  end

  -- Conservative fallback. The station radius is small, so this is acceptable
  -- for Space Age surfaces if the type-filter form is unavailable.
  local ok_all, entities = pcall(function() return surface.find_entities_filtered({ area = area }) end)
  if ok_all and entities then
    for _, entity in pairs(entities) do
      if is_asteroid_threat_entity(entity) then
        table.insert(targets, entity)
      end
    end
  end

  return targets
end

function find_enemy_target(station, radius, priest)
  local surface = station.surface
  local position = station.position
  local area = {
    { position.x - radius, position.y - radius },
    { position.x + radius, position.y + radius }
  }

  local candidates = {}
  local enemies = surface.find_entities_filtered({ area = area, force = "enemy" })
  for _, entity in pairs(enemies) do
    table.insert(candidates, entity)
  end

  -- Space Age asteroids are not ordinary biter-style enemy creatures. Add an
  -- explicit asteroid pass so Cogitator Station defense can see incoming rocks
  -- the way platform turrets do, then let the existing proxy-turret combat path
  -- prove whether the selected asteroid can actually be engaged.
  for _, entity in pairs(find_space_asteroid_targets(surface, area)) do
    table.insert(candidates, entity)
  end

  local best = nil
  local best_score = nil

  for _, entity in pairs(candidates) do
    local health = get_entity_health_or_nil(entity)
    if entity.valid and (is_asteroid_threat_entity(entity) or (health and health > 0)) then
      local score, station_distance_sq = score_threat_to_station_and_priest(entity, position, priest)
      if station_distance_sq <= radius * radius then
        if not best_score or score < best_score then
          best = entity
          best_score = score
        end
      end
    end
  end

  return best
end

function enemy_inside_station_radius(station, enemy, radius)
  if not (station and station.valid and enemy and enemy.valid) then return false end
  local dx = enemy.position.x - station.position.x
  local dy = enemy.position.y - station.position.y
  return dx * dx + dy * dy <= radius * radius
end

function handle_combat(pair)
  local station = pair.station
  local priest = pair.priest
  local radius = refresh_pair_radius(pair)
  if not (station and station.valid and priest and priest.valid) then return false end

  local target = pair.combat_target
  if not enemy_inside_station_radius(station, target, radius) then
    target = find_enemy_target(station, radius, priest)
    pair.combat_target = target
  end

  if not target then
    deactivate_proxy(pair)
    return false
  end
  combat_debug(pair, "enemy target acquired: " .. target.name)

  local proxy = ensure_proxy(pair)
  if not proxy then return false end

  if tech_priests_align_proxy_to_priest_0430 then tech_priests_align_proxy_to_priest_0430(pair, proxy, priest, "combat proxy attached to visible priest") else pcall(function() proxy.teleport(priest.position) end) end
  pcall(function() proxy.active = true end)
  pcall(function() proxy.operable = false end)

  if not load_proxy_from_station(pair) then
    deactivate_proxy(pair)
    pair.mode = "missing-ammo-supplies"
    pair.target = target
    maybe_start_supply_scavenge(pair, "ammo", target)
    return true
  end

  local dx = priest.position.x - target.position.x
  local dy = priest.position.y - target.position.y
  local distance_sq = dx * dx + dy * dy

  local target_ok = pcall(function() proxy.shooting_target = target end)
  if target_ok then
    combat_debug(pair, "proxy assigned target while attached to priest")
  else
    combat_debug(pair, "proxy exists and is loaded, but shooting_target assignment failed")
  end
  describe_proxy_state(pair, proxy, target, "combat diagnostic")

  if distance_sq > COMBAT_FIRE_RANGE * COMBAT_FIRE_RANGE then
    issue_priest_command(priest, {
      type = defines.command.go_to_location,
      destination = target.position,
      radius = COMBAT_APPROACH_RADIUS,
      distraction = defines.distraction.by_enemy
    })
    pair.mode = "moving-to-combat"
    pair.target = target
    pair.proxy_expires = game.tick + PROXY_KEEPALIVE_TICKS
    return true
  end

  issue_priest_command(priest, {
    type = defines.command.attack,
    target = target,
    distraction = defines.distraction.none
  })

  pair.proxy_expires = game.tick + PROXY_KEEPALIVE_TICKS
  pair.mode = "defending"
  pair.target = target
  return true
end

function get_repair_pack_useful_missing_health(target)
  if not (target and target.valid and target.health and target.max_health) then return 0 end
  return math.max(0, target.max_health - target.health)
end

function can_fully_use_repair_pack(target)
  return get_repair_pack_useful_missing_health(target) >= REPAIR_AMOUNT_PER_PACK
end

function find_damaged_target(station, radius, priest)
  local surface = station.surface
  local force = station.force
  local position = station.position
  local area = {
    { position.x - radius, position.y - radius },
    { position.x + radius, position.y + radius }
  }

  local entities = surface.find_entities_filtered({ area = area, force = force })
  local best = nil
  local best_distance = nil

  for _, entity in pairs(entities) do
    if entity.valid and entity.health and entity.max_health and entity.max_health > 0 then
      if can_fully_use_repair_pack(entity) and not is_priest(entity) and entity.name ~= PROXY_NAME then
        local dx = entity.position.x - position.x
        local dy = entity.position.y - position.y
        local distance_sq = dx * dx + dy * dy
        if distance_sq <= radius * radius then
          local score = distance_sq
          if priest and priest.valid then
            local pdx = entity.position.x - priest.position.x
            local pdy = entity.position.y - priest.position.y
            score = math.min(distance_sq, pdx * pdx + pdy * pdy)
          end
          if not best_distance or score < best_distance then
            best = entity
            best_distance = score
          end
        end
      end
    end
  end

  return best
end

find_priest_service_position = function(priest, target)
  if not (priest and priest.valid and target and target.valid) then return nil end

  local surface = priest.surface
  local bbox = target.bounding_box
  local priest_pos = priest.position
  local center = target.position

  local candidates = {
    { x = center.x, y = bbox.left_top.y - 1.2 },
    { x = center.x, y = bbox.right_bottom.y + 1.2 },
    { x = bbox.left_top.x - 1.2, y = center.y },
    { x = bbox.right_bottom.x + 1.2, y = center.y },
    { x = bbox.left_top.x - 1.2, y = bbox.left_top.y - 1.2 },
    { x = bbox.right_bottom.x + 1.2, y = bbox.left_top.y - 1.2 },
    { x = bbox.left_top.x - 1.2, y = bbox.right_bottom.y + 1.2 },
    { x = bbox.right_bottom.x + 1.2, y = bbox.right_bottom.y + 1.2 }
  }

  table.sort(candidates, function(a, b)
    local adx = a.x - priest_pos.x
    local ady = a.y - priest_pos.y
    local bdx = b.x - priest_pos.x
    local bdy = b.y - priest_pos.y
    return (adx * adx + ady * ady) < (bdx * bdx + bdy * bdy)
  end)

  for _, candidate in pairs(candidates) do
    local ok, position = pcall(function()
      return surface.find_non_colliding_position(priest.name, candidate, 2.5, 0.25, false)
    end)
    if ok and position then return position end
  end

  local ok, fallback = pcall(function()
    return surface.find_non_colliding_position(priest.name, center, 7, 0.25, false)
  end)
  if ok and fallback then return fallback end

  return priest_pos
end

function move_priest_to(priest, target)
  local destination = find_priest_service_position(priest, target)
  if not destination then return false end
  return issue_priest_command(priest, {
    type = defines.command.go_to_location,
    destination = destination,
    radius = 0.75,
    distraction = defines.distraction.by_enemy
  })
end

function safe_create_repair_sparks(surface, position)
  if not (surface and position) then return end

  pcall(function()
    surface.create_entity({ name = "spark-explosion", position = position })
  end)

  pcall(function()
    surface.create_entity({
      name = "spark-explosion-higher",
      position = { x = position.x + 0.15, y = position.y - 0.15 }
    })
  end)

  local particle_positions = {
    { x = position.x - 0.20, y = position.y - 0.10 },
    { x = position.x + 0.18, y = position.y + 0.04 },
    { x = position.x + 0.02, y = position.y + 0.18 }
  }

  for index, particle_position in pairs(particle_positions) do
    pcall(function()
      surface.create_particle({
        name = "spark-particle",
        position = particle_position,
        movement = { x = (index - 2) * 0.035, y = -0.045 },
        height = 0.35,
        vertical_speed = 0.035,
        frame_speed = 0.5
      })
    end)
  end
end

function safe_play_repair_sound(surface, position)
  if not (surface and position) then return end
  local candidates = {
    "utility/repair_pack",
    "utility/manual_repair",
    "utility/build_small",
    "entity/electric-mining-drill/mining_sound"
  }
  for _, path in pairs(candidates) do
    local ok = pcall(function()
      surface.play_sound({ path = path, position = position, volume_modifier = 0.65 })
    end)
    if ok then return end
  end
end

function play_repair_feedback(surface, position)
  safe_create_repair_sparks(surface, position)
  safe_play_repair_sound(surface, position)
end


function get_station_consecration_radius(station)
  return get_station_operating_radius(station)
end

find_consecration_target_for_station = function(station, radius, priest)
  if not (station and station.valid) then return nil end
  if not station_has_consecration_item(station) then return nil end

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
        if useful_item then
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

sanctify_target_with_priest = function(pair, target)
  local station = pair.station
  local priest = pair.priest
  if not (station and station.valid and priest and priest.valid and target and target.valid) then return false end

  local record = get_consecration_record(target)
  if not record then return false end

  local current = record.sanctification or get_base_sanctification_start()
  local maximum = record.max_sanctification or get_base_sanctification_max()
  if current >= maximum then return false end

  local dx = priest.position.x - target.position.x
  local dy = priest.position.y - target.position.y
  local distance_sq = dx * dx + dy * dy

  if distance_sq > PRIEST_CONSECRATION_REACH_DISTANCE_SQ then
    move_priest_to(priest, target)
    pair.mode = "moving-to-consecrate"
    pair.target = target
    return true
  end

  if game.tick < (pair.next_consecration_tick or 0) then
    pair.mode = "consecrating"
    pair.target = target
    return true
  end

  local missing_sanctification = maximum - current
  local consecration_item = get_available_station_consecration_item(station, missing_sanctification)
  if consecration_item and consume_consecration_item_from_station(station, consecration_item.name) then
    local restored = math.min(consecration_item.amount, maximum - current)
    record.sanctification = current + restored
    if tech_priests_0478_record_consecration_source then tech_priests_0478_record_consecration_source(record, target, "tech-priest station rite", consecration_item.name, restored, current, record.sanctification, maximum, nil) end
    pair.next_consecration_tick = game.tick + PRIEST_CONSECRATION_COOLDOWN_TICKS
    pair.mode = "consecrating"
    pair.target = target
    play_repair_feedback(station.surface, target.position)
    draw_sanctification_label(record)
    update_sanctification_overlay(record, true)
    return true
  end

  if station_has_consecration_item(station) and missing_sanctification > 0 then
    pair.mode = "consecrate-waiting-usefulness"
    pair.target = target
    return_to_station(priest, station)
    return true
  end

  pair.mode = "missing-consecration-supplies"
  pair.target = target
  return_to_station(priest, station)
  return true
end

function repair_target(pair, target)
  local station = pair.station
  local priest = pair.priest
  if not (station and station.valid and priest and priest.valid and target and target.valid) then return end

  local dx = priest.position.x - target.position.x
  local dy = priest.position.y - target.position.y
  local distance_sq = dx * dx + dy * dy

  if distance_sq > 16 then
    move_priest_to(priest, target)
    pair.mode = "moving-to-repair"
    pair.target = target
    return
  end

  if not can_fully_use_repair_pack(target) then
    pair.mode = "repair-waiting-usefulness"
    pair.target = target
    return_to_station(priest, station)
    return
  end

  if consume_repair_pack(station) then
    target.health = math.min(target.max_health, target.health + REPAIR_AMOUNT_PER_PACK)
    play_repair_feedback(station.surface, target.position)
    pair.mode = "repairing"
    pair.target = nil
  else
    pair.mode = "idle"
    pair.target = nil
    return_to_station(priest, station)
  end
end

function tick_pair(pair)
  if not pair then return end
  local station = pair.station
  local priest = pair.priest

  if not (station and station.valid) then
    cleanup_pair(pair)
    return
  end
  if not (priest and priest.valid) then
    ensure_pair_priest(pair, false)
    priest = pair.priest
    if not (priest and priest.valid) then
      return
    end
  end

  local radius = refresh_pair_radius(pair)
  sync_linked_health(pair)
  priest = pair.priest
  if not (priest and priest.valid) then
    ensure_pair_priest(pair, false)
    return
  end
  update_priest_footsteps(pair)
  priest = pair.priest
  if not (priest and priest.valid) then
    ensure_pair_priest(pair, false)
    return
  end

  local dx = priest.position.x - station.position.x
  local dy = priest.position.y - station.position.y
  local distance_sq = dx * dx + dy * dy
  if false and distance_sq > (radius + PRIEST_LOST_RANGE_PADDING) * (radius + PRIEST_LOST_RANGE_PADDING) then
    ensure_pair_priest(pair, true)
    return
  end

  cleanup_expired_proxy(pair)

  if game.tick >= (pair.next_logistic_requisition_tick or 0) then
    perform_station_logistic_requisition(pair)
    local station_unit = pair.station_unit or (station.unit_number or 0)
    pair.next_logistic_requisition_tick = game.tick + LOGISTIC_REQUISITION_INTERVAL_TICKS + (station_unit % 60)
  end

  if pair.cram and handle_priest_cram_task(pair) then
    return
  end

  if pair.scavenge and handle_priest_scavenge_task(pair) then
    return
  end

  -- Defense first: station ammo is transferred into the invisible proxy turret,
  -- which fires the actual accepted ammunition behavior.
  if handle_combat(pair) then
    return
  end

  -- Repair second: after enemies are handled, Tech-Priests preserve the
  -- physical machine body before spending time on ritual consecration.
  if station_has_repair_pack(station) then
    if pair.target and pair.target.valid and pair.target.health and pair.target.max_health and can_fully_use_repair_pack(pair.target) then
      repair_target(pair, pair.target)
      return
    end

    local repair_target_entity = find_damaged_target(station, radius, priest)
    if repair_target_entity then
      pair.target = repair_target_entity
      repair_target(pair, repair_target_entity)
      return
    end
  end

  -- Consecration third: once the station perimeter is safe and damaged
  -- machinery has been repaired, Tech-Priests spend Sacred Machine Oil from
  -- their Cogitator Station to restore Machine Spirit Sanctification.
  if pair.target and pair.target.valid and is_consecration_target(pair.target) then
    local record = get_consecration_record(pair.target)
    if record then
      local current = record.sanctification or 0
      local maximum = record.max_sanctification or get_base_sanctification_max(record.entity and record.entity.valid and record.entity.force or nil)
      if current < maximum and get_available_station_consecration_item(station, maximum - current) then
        if sanctify_target_with_priest(pair, pair.target) then return end
      end
    end
  end

  local consecration_target = find_consecration_target_for_station(station, radius, priest)
  if consecration_target and sanctify_target_with_priest(pair, consecration_target) then
    return
  end

  -- Diagnostic/waiting states. These do not consume supplies; they let the
  -- priest show that it sees a target, but is deliberately not spending an
  -- item because the item would be wasted, or because the station lacks the
  -- needed stock.
  if station_has_repair_pack(station) then
    local waiting_repair_target = find_repair_waiting_target(station, radius, priest, false)
    if waiting_repair_target then
      pair.mode = "repair-waiting-usefulness"
      pair.target = waiting_repair_target
      return_to_station(priest, station)
      return
    end
  else
    local missing_repair_supply_target = find_repair_waiting_target(station, radius, priest, true)
    if missing_repair_supply_target then
      pair.mode = "missing-repair-supplies"
      pair.target = missing_repair_supply_target
      if maybe_start_supply_scavenge(pair, "repair", missing_repair_supply_target) then return end
      return_to_station(priest, station)
      return
    end
  end

  if station_has_consecration_item(station) then
    local waiting_consecration_target = find_consecration_status_target(station, radius, priest, true, true)
    if waiting_consecration_target then
      pair.mode = "consecrate-waiting-usefulness"
      pair.target = waiting_consecration_target
      return_to_station(priest, station)
      return
    end
  else
    local missing_consecration_supply_target = find_consecration_status_target(station, radius, priest, false, false)
    if missing_consecration_supply_target then
      pair.mode = "missing-consecration-supplies"
      pair.target = missing_consecration_supply_target
      if maybe_start_supply_scavenge(pair, "consecration", missing_consecration_supply_target) then return end
      return_to_station(priest, station)
      return
    end
  end

  pair.mode = "idle"
  pair.target = nil
  pair.scavenge = nil
  pair.cram = nil
  clear_logistic_frustration(pair)
  return_to_station(priest, station)
end


-- 0.1.347: consecration/machine-spirit runtime moved out of control.lua.
-- Keep global function names via the module files so existing priest/scheduler call sites remain compatible.
TECH_PRIESTS_CONSECRATION_SYSTEM_0347 = require("scripts.core.consecration.init").init()

TechPriestsDebugCommandRegistry.add("tp-consecration-0347", "Report consecration system modularization status for the selected machine.", function(command)
  local player = game.get_player(command.player_index)
  if not player then return end
  local selected = player.selected
  local system = TECH_PRIESTS_CONSECRATION_SYSTEM_0347 or {}
  local module_count = 0
  for _ in pairs(system.modules or {}) do module_count = module_count + 1 end
  local msg = "Consecration system 0.1.347 loaded; modules=" .. tostring(module_count)
  if selected and selected.valid and is_consecration_target and is_consecration_target(selected) then
    local record = get_consecration_record(selected)
    if record then
      msg = msg .. " selected=" .. selected.name .. " sanctity=" .. string.format("%.1f", tonumber(record.sanctification or 0)) .. "/" .. string.format("%.1f", tonumber(record.max_sanctification or 0))
      msg = msg .. " waste_jammed=" .. tostring(record.waste_jammed == true)
    end
  elseif selected and selected.valid then
    msg = msg .. " selected=" .. selected.name .. " consecration-target=false"
  end
  player.print(msg)
end)

function upgrade_pair_priest_to_current_mobility(pair)
  if not (pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid) then return false end
  local config = get_station_config(pair.station)
  local desired_name = get_priest_name_for_force(config, pair.station.force)
  if not desired_name or pair.priest.name == desired_name then return false end

  local old_priest = pair.priest
  local old_health_ratio = get_health_ratio(old_priest) or 1
  local old_position = old_priest.position
  local old_direction = old_priest.direction
  local old_unit_number = old_priest.unit_number

  local position = old_position
  if not pair.station.surface.can_place_entity({ name = desired_name, position = position, force = pair.station.force }) then
    position = find_spawn_position(pair.station, desired_name) or old_position
  end

  local new_priest = pair.station.surface.create_entity({
    name = desired_name,
    position = position,
    direction = old_direction,
    quality = get_entity_quality_name(pair.station),
    force = pair.station.force,
    raise_built = false
  })

  if not (new_priest and new_priest.valid and new_priest.unit_number) then return false end
  spawn_priest_smoke_for_entity(old_priest, true)
  spawn_priest_smoke_for_entity(new_priest, true)
  set_health_ratio(new_priest, old_health_ratio)
  if tech_priests_destroy_priest_0500 then
    tech_priests_destroy_priest_0500(old_priest, "mobility-upgrade-old-priest", pair)
  else
    old_priest.destroy({ raise_destroy = false })
  end

  storage.tech_priests.station_by_priest[old_unit_number] = nil
  storage.tech_priests.station_by_priest[new_priest.unit_number] = pair.station_unit
  pair.priest = new_priest
  pair.priest_unit = new_priest.unit_number
  apply_pair_display_names(pair)
  pair.mode = "idle"
  pair.target = nil
  pair.combat_target = nil
  return_to_station(new_priest, pair.station)
  return true
end

function upgrade_force_priests_to_current_mobility(force)
  ensure_storage()
  for _, pair in pairs(storage.tech_priests.pairs_by_station) do
    if pair.station and pair.station.valid and pair.station.force == force then
      upgrade_pair_priest_to_current_mobility(pair)
    end
  end
end
