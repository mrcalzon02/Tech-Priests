-- Auto-split control.lua fragment 005 for Tech Priests 0.1.438.
-- Generated mechanically from 0.1.437 monolithic control.lua.
-- Purpose: reduce Lua main-chunk local/register pressure without deleting behavior.


function get_idle_scan_endpoint_position(pair)
  local scan = pair and pair.idle_scan
  local target = scan and scan.target
  if not (target and target.valid) then return nil end
  local elapsed = math.max(0, (game.tick or 0) - (scan.started_tick or game.tick or 0))
  -- Deterministic slow spiral: radius grows and shrinks over a 6 second sweep.
  local sweep = (elapsed % 360) / 360
  local wave = sweep <= 0.5 and (sweep * 2) or ((1 - sweep) * 2)
  local radius = IDLE_SCAN_SPIRAL_RADIUS * wave
  local angle = elapsed / 18
  return { x = target.position.x + math.cos(angle) * radius, y = target.position.y + math.sin(angle) * radius }
end

function draw_idle_scan_line(pair)
  if not (pair and pair.priest and pair.priest.valid and pair.idle_scan and pair.idle_scan.target and pair.idle_scan.target.valid) then return end
  ensure_storage()
  storage.tech_priests.idle_scan_lines = storage.tech_priests.idle_scan_lines or {}
  clear_idle_scan_line(pair)
  local endpoint = get_idle_scan_endpoint_position(pair)
  if not endpoint then return end
  local ok, line = pcall(function()
    return rendering.draw_line({
      color = { r = 0.20, g = 1.00, b = 0.25, a = 0.70 },
      width = 2,
      from = { entity = pair.priest, offset = TECH_PRIEST_SCAN_ORIGIN_OFFSET },
      to = endpoint,
      surface = pair.priest.surface,
      time_to_live = IDLE_SCAN_RENDER_TTL
    })
  end)
  if ok and line then storage.tech_priests.idle_scan_lines[pair.station.unit_number] = line end
end

function update_idle_scan_behavior(pair)
  if not is_pair_available_for_idle_scan(pair) then
    stop_idle_scan(pair)
    return false
  end
  if not (pair.idle_scan and pair.idle_scan.target and pair.idle_scan.target.valid) or game.tick >= (pair.idle_scan.due_tick or 0) or game.tick >= (pair.idle_scan.next_retarget_tick or 0) then
    stop_idle_scan(pair)
    start_idle_scan(pair)
  end
  if not (pair.idle_scan and pair.idle_scan.target and pair.idle_scan.target.valid) then return false end
  local target = pair.idle_scan.target
  local dx = pair.priest.position.x - target.position.x
  local dy = pair.priest.position.y - target.position.y
  if dx * dx + dy * dy > IDLE_SCAN_MIN_DISTANCE_SQ then
    move_priest_to(pair.priest, target)
  end
  draw_idle_scan_line(pair)
  return true
end

original_0121_get_priest_current_target = get_priest_current_target
function get_priest_current_target(pair)
  if pair and pair.idle_scan and pair.idle_scan.target and pair.idle_scan.target.valid then
    return pair.idle_scan.target
  end
  return original_0121_get_priest_current_target(pair)
end

original_0121_get_priest_target_line_color = get_priest_target_line_color
function get_priest_target_line_color(pair)
  if pair and pair.idle_scan and pair.idle_scan.target and pair.idle_scan.target.valid then
    return { r = 0.20, g = 1.00, b = 0.25, a = 0.72 }
  end
  return original_0121_get_priest_target_line_color(pair)
end

original_0121_update_priest_status_bubbles = update_priest_status_bubbles
function update_priest_status_bubbles()
  original_0121_update_priest_status_bubbles()
  ensure_storage()
  for _, pair in pairs(storage.tech_priests.pairs_by_station) do
    if pair.station and pair.station.valid then
      draw_station_request_icon(pair)
    elseif pair.station_unit then
      clear_station_request_icon(pair)
    end
  end
end

original_0121_tick_pair = tick_pair
function tick_pair(pair)
  original_0121_tick_pair(pair)
  if update_idle_conversation_behavior and update_idle_conversation_behavior(pair) then return end
  update_idle_scan_behavior(pair)
end

-- 0.1.121 follow-up: give active logistics inventory scans the same subtle
-- sweeping endpoint treatment as idle scans, while preserving scavenge/cram colors.
original_0121b_draw_logistic_inventory_scan_line = draw_logistic_inventory_scan_line
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
  local elapsed = math.max(0, (game.tick or 0) - ((pair.inventory_scan and pair.inventory_scan.started_tick) or game.tick or 0))
  local sweep = (elapsed % 180) / 180
  local wave = sweep <= 0.5 and (sweep * 2) or ((1 - sweep) * 2)
  local radius = 0.45 * wave
  local angle = elapsed / 12
  local endpoint = { x = target_entity.position.x + math.cos(angle) * radius, y = target_entity.position.y + math.sin(angle) * radius }
  local ok, line = pcall(function()
    return rendering.draw_line({
      color = color,
      width = 2,
      from = { entity = pair.priest, offset = TECH_PRIEST_SCAN_ORIGIN_OFFSET },
      to = endpoint,
      surface = pair.priest.surface,
      time_to_live = LOGISTIC_SCAN_LINE_TTL
    })
  end)
  if ok and line then pair.scan_line_render = line end
end


-- 0.1.124 logistics scan hardening:
-- Hidden requester/provider cache entities are real logistic containers, but they
-- are implementation details. Priests must never spend their scan cycle on them,
-- including old offset helper entities that may still exist in older saves.
function is_hidden_logistic_helper_entity(entity, pair)
  if not (entity and entity.valid) then return false end
  if entity.name == LOGISTIC_REQUESTER_CACHE_NAME or entity.name == LOGISTIC_RETURN_CACHE_NAME then return true end
  if pair then
    if pair.logistic_requester and pair.logistic_requester.valid and entity == pair.logistic_requester then return true end
    if pair.logistic_return_cache and pair.logistic_return_cache.valid and entity == pair.logistic_return_cache then return true end
  end
  -- Extra defensive check for old/migrated helper names if the prototype name is
  -- ever extended. This is deliberately narrow so real Cogitator Stations still
  -- remain valid polite scavenge targets.
  if type(entity.name) == "string" and entity.name:find("^tech%-priests%-cogitator%-.*cache$") then return true end
  return false
end

function is_logistic_scan_candidate_entity(pair, entity)
  if not (entity and entity.valid) then return false end
  if pair and pair.station and pair.station.valid and entity == pair.station then return false end
  if entity.name == PROXY_NAME then return false end
  if is_priest(entity) then return false end
  if is_hidden_logistic_helper_entity(entity, pair) then return false end
  return true
end

-- Override all local inventory candidate building so helper entities are skipped
-- at the source rather than merely ignored after the priest has already walked to
-- them. Real Cogitator Stations are still allowed; they are handled politely.
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
  for _, entity in pairs(entities or {}) do
    if is_logistic_scan_candidate_entity(pair, entity) then
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

-- Keep the older instant-source search path hardened as well, in case any branch
-- falls back to it before the explicit three-second scan starts.
function find_scavenge_source_for_request(pair, request)
  if not (pair and pair.station and pair.station.valid and request) then return nil end
  local station = pair.station
  local priest = pair.priest
  local radius = refresh_pair_radius(pair)
  local position = station.position
  local area = {
    { position.x - radius, position.y - radius },
    { position.x + radius, position.y + radius }
  }
  local ids = get_scavenge_inventory_ids()
  local best = nil
  local best_score = nil
  local entities = station.surface.find_entities_filtered({ area = area, force = station.force })

  for _, entity in pairs(entities or {}) do
    if is_logistic_scan_candidate_entity(pair, entity) then
      local sdx = entity.position.x - position.x
      local sdy = entity.position.y - position.y
      local station_distance_sq = sdx * sdx + sdy * sdy
      if station_distance_sq <= radius * radius then
        for _, inventory_id in pairs(ids) do
          local inventory = get_entity_inventory_safe(entity, inventory_id)
          local found = inventory_has_insertable_request_item(pair, inventory, request)
          if found then
            local score_distance = station_distance_sq
            if priest and priest.valid then
              local pdx = entity.position.x - priest.position.x
              local pdy = entity.position.y - priest.position.y
              score_distance = math.min(score_distance, pdx * pdx + pdy * pdy)
            end
            local item_bonus = (found.score or 0) * 0.0001
            local score = score_distance - item_bonus
            if not best_score or score < best_score then
              best_score = score
              best = { source = entity, inventory_id = inventory_id, item_name = found.name, count = found.count or 1, kind = request.kind, quality = found.quality }
            end
          end
        end
      end
    end
  end

  return best
end

original_0124_handle_logistic_inventory_scan = handle_logistic_inventory_scan
function handle_logistic_inventory_scan(pair)
  if pair and pair.inventory_scan and pair.inventory_scan.current and is_hidden_logistic_helper_entity(pair.inventory_scan.current.entity, pair) then
    advance_logistic_inventory_scan(pair)
    return true
  end
  return original_0124_handle_logistic_inventory_scan(pair)
end

-- 0.1.126 emergency desperation crafting pass:
-- If a priest exhausts every local inventory scan for a missing requested item,
-- he enters a last-ditch scavenger/crafting routine. This is intentionally not a
-- real assembler action: the priest collects rough substitute materials from the
-- local area into a pseudo-inventory, waits through a five-second rite, and then
-- inserts one emergency item into the Cogitator Station.
EMERGENCY_CRAFT_SCAN_TICKS = 60 * 3
EMERGENCY_CRAFT_INVENTORY_SCAN_TICKS = 60
EMERGENCY_CRAFT_WORK_TICKS = 60 * 5
EMERGENCY_CRAFT_PICKUP_DISTANCE_SQ = 2.25
EMERGENCY_CRAFT_RETRY_TICKS = 60 * 30
EMERGENCY_CRAFT_RESOURCE_SCAN_LIMIT = 80

original_0126_classify_priest_visual_state = classify_priest_visual_state
function classify_priest_visual_state(pair)
  if pair and pair.emergency_craft then
    if pair.mode == "emergency-crafting" then return "emergency-crafting" end
    return "emergency-gathering"
  end
  return original_0126_classify_priest_visual_state(pair)
end

original_0126_get_priest_status_setting_name = get_priest_status_setting_name
function get_priest_status_setting_name(state)
  if state == "emergency-gathering" then return "tech-priests-priest-status-symbol-emergency-gathering" end
  if state == "emergency-crafting" then return "tech-priests-priest-status-symbol-emergency-crafting" end
  return original_0126_get_priest_status_setting_name(state)
end

original_0126_get_priest_status_fallback_symbol = get_priest_status_fallback_symbol
function get_priest_status_fallback_symbol(state)
  if state == "emergency-gathering" then return "[item=iron-ore]?{craft_item}" end
  if state == "emergency-crafting" then return "[item={craft_item}]{craft_seconds}" end
  return original_0126_get_priest_status_fallback_symbol(state)
end

original_0126_get_priest_status_symbol = get_priest_status_symbol
function get_priest_status_symbol(pair)
  local symbol = original_0126_get_priest_status_symbol(pair)
  if pair and pair.emergency_craft then
    local task = pair.emergency_craft
    local item_name = task.output_item or task.item_name or "repair-pack"
    local remaining = 0
    if pair.mode == "emergency-crafting" and task.craft_due_tick then
      remaining = math.max(0, math.ceil((task.craft_due_tick - game.tick) / 60))
    elseif task.scan_due_tick then
      remaining = math.max(0, math.ceil((task.scan_due_tick - game.tick) / 60))
    end
    symbol = tostring(symbol or ""):gsub("{craft_item}", tostring(item_name))
    symbol = symbol:gsub("{craft_seconds}", tostring(remaining))
  end
  return symbol
end

function get_emergency_requested_item_from_request(pair, request)
  if not request then return nil end
  if request.kind == "repair" then return "repair-pack" end
  if request.kind == "ammo" then
    local stack = choose_logistic_request_stack and choose_logistic_request_stack(pair, request) or nil
    return (stack and stack.name) or "firearm-magazine"
  end
  if request.candidates and request.candidates[1] and request.candidates[1].name then
    return request.candidates[1].name
  end
  local stack = choose_logistic_request_stack and choose_logistic_request_stack(pair, request) or nil
  return stack and stack.name or nil
end

function add_emergency_raw_space_substitutes(recipe)
  if not recipe then return recipe end
  recipe.substitutes = recipe.substitutes or {}

  -- 0.1.154: deck-priest desperation crafting may consume rough local junk,
  -- asteroid salvage, and machine detritus as last-ditch substitute matter.
  -- These are deliberately inefficient value weights, not real recipes. They
  -- let a stranded Senior Tech-Priest improvise when the station, logistics,
  -- local inventories, and normal scavenging have all failed.
  local additions = {
    ["mechanical-detritus"] = 3,
    ["metallic-asteroid-chunk"] = 4,
    ["carbonic-asteroid-chunk"] = 3,
    ["oxide-asteroid-chunk"] = 3,
    ["blackstone-asteroid-chunk"] = 5,
    ["ice"] = 1,
    ["calcite"] = 1
  }

  -- If the Blackstone processing chain has advanced far enough that fragments
  -- or slabs are lying around unattended, the priest can absolutely misuse them
  -- as emergency ritual material. This is intentionally wasteful.
  additions["blackstone-fragment"] = 5
  additions["blackstone-slab"] = 12

  for name, value in pairs(additions) do
    if not recipe.substitutes[name] then
      recipe.substitutes[name] = value
    end
  end
  return recipe
end

function get_emergency_craft_recipe(item_name)
  if not item_name then return nil end

  -- These recipes are deliberately rough field-expedient approximations. They
  -- are intentionally inefficient, but they give stranded stations a last-resort
  -- path instead of deadlocking forever when both logistics and local inventory
  -- scavenging fail.
  if item_name == "repair-pack" then
    return add_emergency_raw_space_substitutes({
      output = item_name,
      units = 8,
      primary = { ["iron-gear-wheel"] = 3, ["electronic-circuit"] = 3, ["iron-plate"] = 2 },
      substitutes = { ["iron-ore"] = 2, ["iron-plate"] = 2, ["stone"] = 1, ["coal"] = 1, ["wood"] = 1, ["copper-ore"] = 1, ["copper-plate"] = 1 }
    })
  end

  if item_name == "sacred-machine-oil" then
    return add_emergency_raw_space_substitutes({
      output = item_name,
      units = 6,
      primary = { ["wood"] = 2, ["coal"] = 2 },
      substitutes = { ["wood"] = 2, ["coal"] = 2, ["stone"] = 1, ["iron-ore"] = 1 }
    })
  end

  if item_name == "machine-maintenance-litany" then
    return add_emergency_raw_space_substitutes({
      output = item_name,
      units = 10,
      primary = { ["sacred-candle"] = 4, ["repair-pack"] = 4, ["iron-gear-wheel"] = 2 },
      substitutes = { ["wood"] = 2, ["coal"] = 2, ["iron-ore"] = 2, ["iron-plate"] = 2, ["stone"] = 1 }
    })
  end

  if item_name == "ritual-of-machine-appeasement" then
    return add_emergency_raw_space_substitutes({
      output = item_name,
      units = 14,
      primary = { ["machine-maintenance-litany"] = 6, ["servitor-parts"] = 4, ["sacred-machine-oil"] = 4 },
      substitutes = { ["wood"] = 2, ["coal"] = 2, ["iron-ore"] = 2, ["iron-plate"] = 2, ["stone"] = 1, ["copper-ore"] = 1 }
    })
  end

  if is_ammo_item and is_ammo_item(item_name) then
    return add_emergency_raw_space_substitutes({
      output = item_name,
      units = 8,
      primary = { ["iron-plate"] = 4, ["copper-plate"] = 2, ["iron-ore"] = 2 },
      substitutes = { ["iron-ore"] = 2, ["iron-plate"] = 2, ["copper-ore"] = 1, ["copper-plate"] = 1, ["coal"] = 1, ["stone"] = 1 }
    })
  end

  -- Generic fallback for modded consecration/ammo-like items. It is intentionally
  -- expensive in local raw junk so it remains a desperate field fabrication.
  return add_emergency_raw_space_substitutes({
    output = item_name,
    units = 12,
    primary = {},
    substitutes = { ["iron-ore"] = 2, ["iron-plate"] = 2, ["copper-ore"] = 1, ["copper-plate"] = 1, ["coal"] = 1, ["stone"] = 1, ["wood"] = 1 }
  })
end

function get_emergency_material_value(recipe, item_name)
  if not (recipe and item_name) then return 0 end
  if recipe.primary and recipe.primary[item_name] then return recipe.primary[item_name] end
  if recipe.substitutes and recipe.substitutes[item_name] then return recipe.substitutes[item_name] end
  return 0
end

function is_tree_entity(entity)
  if not (entity and entity.valid) then return false end
  local ok, typ = pcall(function() return entity.type end)
  return ok and typ == "tree"
end

function is_resource_entity(entity)
  if not (entity and entity.valid) then return false end
  local ok, typ = pcall(function() return entity.type end)
  return ok and typ == "resource"
end

function build_emergency_craft_candidates(pair, recipe)
  if not (pair and pair.station and pair.station.valid and recipe) then return {} end
  local station = pair.station
  local radius = refresh_pair_radius(pair)
  local pos = station.position
  local area = {{pos.x - radius, pos.y - radius}, {pos.x + radius, pos.y + radius}}
  local ids = get_scavenge_inventory_ids()
  local candidates = {}

  local entities = station.surface.find_entities_filtered({ area = area, force = station.force })
  for _, entity in pairs(entities or {}) do
    if is_logistic_scan_candidate_entity(pair, entity) then
      local dx = entity.position.x - pos.x
      local dy = entity.position.y - pos.y
      local dist = dx * dx + dy * dy
      if dist <= radius * radius then
        for _, inventory_id in pairs(ids) do
          local inventory = get_entity_inventory_safe(entity, inventory_id)
          if inventory then
            for i = 1, #inventory do
              local stack = inventory[i]
              if stack and stack.valid_for_read then
                local value = get_emergency_material_value(recipe, stack.name)
                if value > 0 then
                  candidates[#candidates + 1] = { kind = "inventory", entity = entity, inventory_id = inventory_id, item_name = stack.name, value = value, station_distance_sq = dist, unit_number = entity.unit_number or 0 }
                  break
                end
              end
            end
          end
        end
      end
    end
  end

  local ground_items = station.surface.find_entities_filtered({ area = area, type = "item-entity" })
  for _, entity in pairs(ground_items or {}) do
    if entity.valid then
      local ok, stack = pcall(function() return entity.stack end)
      if ok and stack and stack.valid_for_read then
        local value = get_emergency_material_value(recipe, stack.name)
        if value > 0 then
          local dx = entity.position.x - pos.x
          local dy = entity.position.y - pos.y
          local dist = dx * dx + dy * dy
          if dist <= radius * radius then
            candidates[#candidates + 1] = { kind = "ground", entity = entity, item_name = stack.name, value = value, station_distance_sq = dist, unit_number = entity.unit_number or 0 }
          end
        end
      end
    end
  end

  -- Space Age asteroid chunks are not always ordinary ground item entities.
  -- Treat loose chunk entities as desperate raw material when their name maps to
  -- an emergency substitute value. This lets a Senior Tech-Priest salvage local
  -- platform debris instead of staring at a repair target forever.
  local ok_chunks, asteroid_chunks = pcall(function()
    return station.surface.find_entities_filtered({ area = area, type = "asteroid-chunk", limit = EMERGENCY_CRAFT_RESOURCE_SCAN_LIMIT })
  end)
  if ok_chunks then
    for _, entity in pairs(asteroid_chunks or {}) do
      if entity and entity.valid then
        local item_name = entity.name
        local value = get_emergency_material_value(recipe, item_name)
        if value > 0 then
          local dx = entity.position.x - pos.x
          local dy = entity.position.y - pos.y
          local dist = dx * dx + dy * dy
          if dist <= radius * radius then
            candidates[#candidates + 1] = { kind = "asteroid-chunk", entity = entity, item_name = item_name, value = value, station_distance_sq = dist, unit_number = entity.unit_number or 0 }
          end
        end
      end
    end
  end

  local resources = station.surface.find_entities_filtered({ area = area, type = {"resource", "tree"}, limit = EMERGENCY_CRAFT_RESOURCE_SCAN_LIMIT })
  for _, entity in pairs(resources or {}) do
    if entity.valid then
      local item_name = nil
      if is_tree_entity(entity) then
        item_name = "wood"
      else
        item_name = entity.name
      end
      local value = get_emergency_material_value(recipe, item_name)
      if value > 0 then
        local dx = entity.position.x - pos.x
        local dy = entity.position.y - pos.y
        local dist = dx * dx + dy * dy
        if dist <= radius * radius then
          candidates[#candidates + 1] = { kind = "resource", entity = entity, item_name = item_name, value = value, station_distance_sq = dist, unit_number = entity.unit_number or 0 }
        end
      end
    end
  end

  table.sort(candidates, function(a, b)
    local ap = a.kind == "inventory" and 1 or (a.kind == "ground" and 2 or (a.kind == "asteroid-chunk" and 3 or 4))
    local bp = b.kind == "inventory" and 1 or (b.kind == "ground" and 2 or (b.kind == "asteroid-chunk" and 3 or 4))
    if ap ~= bp then return ap < bp end
    if math.abs((a.station_distance_sq or 0) - (b.station_distance_sq or 0)) > 0.001 then
      return (a.station_distance_sq or 0) < (b.station_distance_sq or 0)
    end
    return (a.unit_number or 0) < (b.unit_number or 0)
  end)
  return candidates
end

function start_emergency_desperation_craft(pair, request)
  if not (pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid and request) then return false end
  local item_name = get_emergency_requested_item_from_request(pair, request)
  if not item_name then return false end
  local recipe = get_emergency_craft_recipe(item_name)
  if not recipe then return false end
  local candidates = build_emergency_craft_candidates(pair, recipe)
  pair.emergency_craft = {
    request = request,
    output_item = item_name,
    recipe = recipe,
    candidates = candidates,
    index = 1,
    gathered_units = 0,
    scan_due_tick = nil,
    craft_due_tick = nil,
    current = nil,
    started_tick = game.tick
  }
  pair.mode = "emergency-gathering"
  pair.target = nil
  return true
end

function acquire_emergency_material(pair, task, candidate)
  if not (pair and task and candidate and candidate.entity and candidate.entity.valid) then return false end
  local needed_units = math.max(0, (task.recipe.units or 1) - (task.gathered_units or 0))
  if needed_units <= 0 then return true end
  local value = math.max(1, candidate.value or 1)
  local take_count = math.max(1, math.ceil(needed_units / value))

  if candidate.kind == "inventory" then
    local inv = get_entity_inventory_safe(candidate.entity, candidate.inventory_id)
    if not inv then return false end
    local available = inv.get_item_count(candidate.item_name)
    if available <= 0 then return false end
    -- Inventory raids are a quick open-and-retrieve action, not bulk extraction.
    -- Take exactly one matching targeted item per orange inventory scan so the
    -- behavior reads as "scan, open, take one" instead of silently emptying a box.
    take_count = 1
    local removed = inv.remove({ name = candidate.item_name, count = take_count })
    if removed <= 0 then return false end
    task.gathered_units = (task.gathered_units or 0) + removed * value
    return true
  end

  if candidate.kind == "ground" then
    local ok, stack = pcall(function() return candidate.entity.stack end)
    if not (ok and stack and stack.valid_for_read and stack.name == candidate.item_name) then return false end
    take_count = math.min(take_count, stack.count or 1, get_item_stack_size(candidate.item_name))
    local remaining = (stack.count or 1) - take_count
    if remaining > 0 then
      pcall(function() stack.count = remaining end)
    else
      candidate.entity.destroy({ raise_destroy = false })
    end
    task.gathered_units = (task.gathered_units or 0) + take_count * value
    return true
  end

  if candidate.kind == "asteroid-chunk" then
    -- Loose asteroid chunks on platforms are raw salvage. Consume the chunk
    -- entity into the pseudo-inventory and let the red scan beam/smoke sell the
    -- improvised acquisition.
    local taken = 1
    pcall(function() candidate.entity.destroy({ raise_destroy = false }) end)
    task.gathered_units = (task.gathered_units or 0) + taken * value
    return true
  end

  if candidate.kind == "resource" then
    -- Units do not expose a true character mining animation here. This is a
    -- scripted field salvage: stand by the resource/tree, play the scan line and
    -- consume a small amount of local matter into the priest's pseudo-inventory.
    local taken = 1
    if is_tree_entity(candidate.entity) then
      candidate.entity.destroy({ raise_destroy = false })
    else
      local ok_amount, amount = pcall(function() return candidate.entity.amount end)
      if ok_amount and amount and amount > 1 then
        pcall(function() candidate.entity.amount = math.max(0, amount - taken) end)
      else
        pcall(function() candidate.entity.destroy({ raise_destroy = false }) end)
      end
    end
    task.gathered_units = (task.gathered_units or 0) + taken * value
    return true
  end

  return false
end


-- 0.1.127 desperation crafting visual pass:
-- Emergency material acquisition is now represented with a red Mechanicus scan
-- beam and small smoke/spark puffs instead of pretending the unit has a normal
-- character mining animation.
EMERGENCY_CRAFT_VISUAL_PULSE_TICKS = 30
EMERGENCY_CRAFT_SCAN_LINE_TTL = 12

function draw_emergency_craft_scan_line(pair, target_entity)
  if not (pair and pair.priest and pair.priest.valid and target_entity and target_entity.valid and rendering and rendering.draw_line) then return end
  if pair.scan_line_render then
    destroy_render_object(pair.scan_line_render)
    pair.scan_line_render = nil
  end

  local task = pair.emergency_craft or {}
  local current = task.current or {}
  local current_kind = current.kind or "resource"

  -- Red means actual desperate field acquisition: ore patch, tree, loose ground
  -- salvage, asteroid chunk, scrap-like matter. Inventory-bearing objects are not
  -- being "mined"; they are merely opened/raided, so use a softer amber line.
  local color = { r = 1.00, g = 0.08, b = 0.03, a = 0.88 }
  if current_kind == "inventory" then
    color = { r = 1.00, g = 0.72, b = 0.16, a = 0.82 }
  end

  local started = task.scan_started_tick or task.started_tick or game.tick or 0
  local elapsed = math.max(0, (game.tick or 0) - started)
  local sweep = (elapsed % 150) / 150
  local wave = sweep <= 0.5 and (sweep * 2) or ((1 - sweep) * 2)
  local radius = current_kind == "inventory" and (0.08 + 0.16 * wave) or (0.18 + 0.42 * wave)
  local angle = elapsed / 9
  local endpoint = {
    x = target_entity.position.x + math.cos(angle) * radius,
    y = target_entity.position.y + math.sin(angle) * radius
  }

  local ok, line = pcall(function()
    return rendering.draw_line({
      color = color,
      width = current_kind == "inventory" and 1 or 2,
      from = { entity = pair.priest, offset = TECH_PRIEST_SCAN_ORIGIN_OFFSET },
      to = endpoint,
      surface = pair.priest.surface,
      time_to_live = EMERGENCY_CRAFT_SCAN_LINE_TTL
    })
  end)
  if ok and line then pair.scan_line_render = line end
end

function spawn_emergency_craft_smoke(pair, position, strong)
  if not (pair and pair.station and pair.station.valid and position) then return end
  local surface = pair.station.surface
  local tick = game and game.tick or 0
  local count = strong and 2 or 1
  for i = 1, count do
    local angle = (tick * 0.17) + i * 2.399
    local distance = strong and 0.22 or 0.12
    local smoke_position = {
      x = position.x + math.cos(angle) * distance,
      y = position.y + math.sin(angle) * distance
    }
    pcall(function()
      surface.create_entity({
        name = MACHINE_DAMAGE_SMOKE_ENTITY_NAME,
        position = smoke_position
      })
    end)
  end
end

function maybe_emit_emergency_craft_visuals(pair, target_entity, strong)
  if not (pair and pair.emergency_craft) then return end
  local task = pair.emergency_craft
  local tick = game and game.tick or 0
  if task.next_visual_tick and tick < task.next_visual_tick then return end
  task.next_visual_tick = tick + EMERGENCY_CRAFT_VISUAL_PULSE_TICKS

  -- Do not play "mining" smoke on inventories, machines, belts, or containers.
  -- If the candidate is an inventory, the priest is taking an item from a box or
  -- machine inventory, not extracting raw matter from the environment.
  local current_kind = task.current and task.current.kind or nil
  if current_kind == "inventory" and pair.mode ~= "emergency-crafting" then
    return
  end

  local pos = nil
  if target_entity and target_entity.valid then
    pos = target_entity.position
  elseif pair.priest and pair.priest.valid then
    pos = pair.priest.position
  end
  if pos then spawn_emergency_craft_smoke(pair, pos, strong) end
end

function finish_emergency_desperation_craft(pair)
  if not (pair and pair.station and pair.station.valid and pair.emergency_craft) then return false end
  local task = pair.emergency_craft
  local inv = get_station_inventory(pair.station)
  if not inv then return false end
  local item_name = task.output_item
  if not item_name then return false end
  local count = 1
  if not inv.can_insert({ name = item_name, count = 1 }) then
    -- The crafted item has nowhere to go. Drop it by the priest as a last-ditch
    -- offering rather than deleting it.
    local surface = pair.priest and pair.priest.valid and pair.priest.surface or pair.station.surface
    local pos = pair.priest and pair.priest.valid and pair.priest.position or pair.station.position
    pcall(function() surface.spill_item_stack({ position = pos, stack = { name = item_name, count = count }, enable_looted = true, force = pair.station.force, allow_belts = false }) end)
  else
    inv.insert({ name = item_name, count = count })
  end
  pair.emergency_craft = nil
  clear_logistic_frustration(pair)
  pair.mode = "returning"
  pair.target = nil
  return_to_station(pair.priest, pair.station)
  return true
end

function handle_emergency_desperation_craft(pair)
  if not (pair and pair.priest and pair.priest.valid and pair.station and pair.station.valid and pair.emergency_craft) then return false end
  local task = pair.emergency_craft
  local recipe = task.recipe or {}
  local needed_units = math.max(1, recipe.units or 1)

  if (task.gathered_units or 0) >= needed_units then
    if not task.craft_due_tick then
      task.craft_due_tick = game.tick + EMERGENCY_CRAFT_WORK_TICKS
      pair.mode = "emergency-crafting"
      draw_priest_status_bubble(pair)
      maybe_emit_emergency_craft_visuals(pair, pair.priest, true)
      return true
    end
    if game.tick < task.craft_due_tick then
      pair.mode = "emergency-crafting"
      maybe_emit_emergency_craft_visuals(pair, pair.priest, true)
      return true
    end
    return finish_emergency_desperation_craft(pair)
  end

  local candidates = task.candidates or {}
  while true do
    local candidate = candidates[task.index or 1]
    if not candidate then
      -- Nothing left to scavenge. Return and let the normal frustration cycle try
      -- again later; the priest has exhausted the local area for now.
      pair.emergency_craft = nil
      pair.next_scavenge_search_tick = game.tick + EMERGENCY_CRAFT_RETRY_TICKS
      pair.mode = "returning"
      pair.target = nil
      return_to_station(pair.priest, pair.station)
      return true
    end
    if candidate.entity and candidate.entity.valid then
      task.current = candidate
      break
    end
    task.index = (task.index or 1) + 1
  end

  local candidate = task.current
  local entity = candidate.entity
  pair.target = entity
  draw_emergency_craft_scan_line(pair, entity)

  local dx = pair.priest.position.x - entity.position.x
  local dy = pair.priest.position.y - entity.position.y
  if dx * dx + dy * dy > EMERGENCY_CRAFT_PICKUP_DISTANCE_SQ then
    move_priest_to(pair.priest, entity)
    pair.mode = "emergency-gathering"
    task.scan_due_tick = nil
    return true
  end

  if not task.scan_due_tick then
    local scan_ticks = (candidate.kind == "inventory") and (EMERGENCY_CRAFT_INVENTORY_SCAN_TICKS or 60) or EMERGENCY_CRAFT_SCAN_TICKS
    task.scan_due_tick = game.tick + scan_ticks
    task.scan_started_tick = game.tick
    pair.mode = "emergency-gathering"
    draw_priest_status_bubble(pair)
    maybe_emit_emergency_craft_visuals(pair, entity, false)
    return true
  end
  if game.tick < task.scan_due_tick then
    pair.mode = "emergency-gathering"
    draw_emergency_craft_scan_line(pair, entity)
    maybe_emit_emergency_craft_visuals(pair, entity, false)
    return true
  end

  local acquired = acquire_emergency_material(pair, task, candidate)
  maybe_emit_emergency_craft_visuals(pair, entity, true)

  -- 0.1.175: orange inventory scans are quick one-item retrievals. If this
  -- inventory still contains the targeted emergency material and the pseudo-
  -- recipe still needs more units, keep the current candidate and perform
  -- another one-second open/retrieve pass instead of wandering away.
  if acquired and candidate.kind == "inventory" then
    local needed_units_after = math.max(0, (task.recipe.units or 1) - (task.gathered_units or 0))
    local inv = get_entity_inventory_safe(entity, candidate.inventory_id)
    if needed_units_after > 0 and inv and inv.get_item_count(candidate.item_name) > 0 then
      task.current = candidate
      task.scan_due_tick = nil
      task.scan_started_tick = nil
      pair.mode = "emergency-gathering"
      return true
    end
  end

  task.index = (task.index or 1) + 1
  task.current = nil
  task.scan_due_tick = nil
  return true
end

original_0126_finish_failed_logistic_inventory_scan = finish_failed_logistic_inventory_scan
function finish_failed_logistic_inventory_scan(pair)
  if pair and pair.inventory_scan and pair.inventory_scan.kind == "scavenge" then
    local request = pair.inventory_scan.request
    clear_logistic_inventory_scan(pair)
    pair.scavenge = nil
    if start_emergency_desperation_craft(pair, request) then
      return handle_emergency_desperation_craft(pair)
    end
  end
  return original_0126_finish_failed_logistic_inventory_scan(pair)
end

original_0126_maybe_start_supply_scavenge = maybe_start_supply_scavenge
function maybe_start_supply_scavenge(pair, kind, target)
  if pair and pair.emergency_craft then
    return handle_emergency_desperation_craft(pair)
  end
  return original_0126_maybe_start_supply_scavenge(pair, kind, target)
end

original_0126_tick_pair = tick_pair
function tick_pair(pair)
  if pair and pair.emergency_craft then
    if handle_emergency_desperation_craft(pair) then return end
  end
  return original_0126_tick_pair(pair)
end


-- 0.1.128 live supply-need cancellation pass:
-- Supply searches are now latched to the target that originally needed the item.
-- At each waiting/scanning/gathering stage, the priest re-checks whether that
-- target still needs the supply. If another priest/player/logistics action has
-- already repaired or consecrated the target, the search is cancelled instead of
-- continuing to rummage through inventories for an item that is no longer useful.

function get_consecration_item_amount_by_name(item_name)
  if not item_name then return nil end
  for _, option in pairs(get_station_consecration_item_options and get_station_consecration_item_options() or {}) do
    if option and option.name == item_name then return option.amount or 0 end
  end
  if item_name == "ritual-of-machine-appeasement" then return 20 end
  if item_name == "machine-maintenance-litany" then return 10 end
  if item_name == "sacred-machine-oil" then return PRIEST_CONSECRATION_AMOUNT_PER_OIL or 1 end
  return nil
end

function tech_priests_supply_request_target_still_needs_item(pair, request)
  if not request then return true end
  local kind = request.kind
  if kind ~= "repair" and kind ~= "consecration" then return true end

  local target = request.target
  if not (target and target.valid) and pair and pair.active_supply_request and pair.active_supply_request.target and pair.active_supply_request.target.valid then
    target = pair.active_supply_request.target
  end

  if kind == "repair" then
    if not (target and target.valid and target.health and target.max_health) then return false end
    -- The priest conserves repair packs, so if the target is no longer missing a
    -- full repair pack of health, this particular repair-pack search is obsolete.
    return can_fully_use_repair_pack and can_fully_use_repair_pack(target) or (target.health < target.max_health)
  end

  if kind == "consecration" then
    if not (target and target.valid and is_consecration_target and is_consecration_target(target)) then return false end
    local record = get_consecration_record and get_consecration_record(target) or nil
    if not record then return false end
    local maximum = record.max_sanctification or get_base_sanctification_max(target.force)
    local current = record.sanctification or 0
    local missing = maximum - current
    if missing <= 0 then return false end

    -- If this request was built for a specific useful consecration item, make
    -- sure at least one of those requested items is still fully useful. This
    -- prevents a priest from finishing a search for a +10 or +20 rite after the
    -- machine has already been topped up below that item's useful threshold.
    local candidates = request.candidates or {}
    if #candidates == 0 then return true end
    for _, candidate in pairs(candidates) do
      local amount = get_consecration_item_amount_by_name(candidate.name) or candidate.score or 0
      if amount > 0 and amount <= missing then return true end
    end
    return false
  end

  return true
end

function tech_priests_cancel_obsolete_supply_search(pair)
  if not pair then return false end
  if clear_logistic_inventory_scan then clear_logistic_inventory_scan(pair) end
  pair.scavenge = nil
  pair.emergency_craft = nil
  pair.active_supply_request = nil
  pair.logistic_requested_item = nil
  pair.logistic_requested_count = nil
  if clear_logistic_frustration then clear_logistic_frustration(pair) end
  pair.target = nil
  pair.mode = "returning"
  if pair.priest and pair.priest.valid and pair.station and pair.station.valid then
    return_to_station(pair.priest, pair.station)
  end
  return true
end

function tech_priests_abort_if_supply_request_obsolete(pair, request)
  request = request or (pair and pair.active_supply_request) or (pair and pair.inventory_scan and pair.inventory_scan.request) or (pair and pair.emergency_craft and pair.emergency_craft.request)
  if request and not tech_priests_supply_request_target_still_needs_item(pair, request) then
    return tech_priests_cancel_obsolete_supply_search(pair)
  end
  return false
end

original_0128_build_supply_request = build_supply_request
function build_supply_request(pair, kind, target)
  local request = original_0128_build_supply_request(pair, kind, target)
  if request then
    request.target = target
    request.target_unit_number = target and target.valid and target.unit_number or nil
  end
  return request
end

original_0128_start_logistic_scavenge_inventory_scan = start_logistic_scavenge_inventory_scan
function start_logistic_scavenge_inventory_scan(pair, request)
  if tech_priests_abort_if_supply_request_obsolete(pair, request) then return false end
  if pair then pair.active_supply_request = request end
  local result = original_0128_start_logistic_scavenge_inventory_scan(pair, request)
  if result and pair and pair.inventory_scan and request then
    pair.inventory_scan.request = request
    pair.inventory_scan.need_target = request.target
    pair.inventory_scan.need_target_unit_number = request.target_unit_number
  end
  return result
end

original_0128_handle_logistic_inventory_scan = handle_logistic_inventory_scan
function handle_logistic_inventory_scan(pair)
  if pair and pair.inventory_scan and pair.inventory_scan.kind == "scavenge" then
    if tech_priests_abort_if_supply_request_obsolete(pair, pair.inventory_scan.request) then return true end
  end
  return original_0128_handle_logistic_inventory_scan(pair)
end

original_0128_handle_priest_scavenge_task = handle_priest_scavenge_task
function handle_priest_scavenge_task(pair)
  if pair and pair.scavenge then
    if tech_priests_abort_if_supply_request_obsolete(pair, pair.scavenge.request or pair.active_supply_request) then return true end
  end
  return original_0128_handle_priest_scavenge_task(pair)
end

original_0128_try_withdraw_scavenge_item = try_withdraw_scavenge_item
function try_withdraw_scavenge_item(pair)
  if tech_priests_abort_if_supply_request_obsolete(pair, pair and (pair.scavenge and pair.scavenge.request or pair.active_supply_request)) then return false end
  return original_0128_try_withdraw_scavenge_item(pair)
end

original_0128_start_emergency_desperation_craft = start_emergency_desperation_craft
function start_emergency_desperation_craft(pair, request)
  if tech_priests_abort_if_supply_request_obsolete(pair, request) then return false end
  if pair then pair.active_supply_request = request end
  local result = original_0128_start_emergency_desperation_craft(pair, request)
  if result and pair and pair.emergency_craft then
    pair.emergency_craft.request = request
    pair.emergency_craft.need_target = request and request.target or nil
  end
  return result
end

original_0128_handle_emergency_desperation_craft = handle_emergency_desperation_craft
function handle_emergency_desperation_craft(pair)
  if pair and pair.emergency_craft then
    if tech_priests_abort_if_supply_request_obsolete(pair, pair.emergency_craft.request or pair.active_supply_request) then return true end
  end
  return original_0128_handle_emergency_desperation_craft(pair)
end

original_0128_issue_station_logistic_request = issue_station_logistic_request
function issue_station_logistic_request(pair, request)
  if tech_priests_abort_if_supply_request_obsolete(pair, request) then return false end
  if pair then pair.active_supply_request = request end
  return original_0128_issue_station_logistic_request(pair, request)
end

original_0128_maybe_start_supply_scavenge = maybe_start_supply_scavenge
function maybe_start_supply_scavenge(pair, kind, target)
  local request = nil
  if pair and pair.active_supply_request and pair.active_supply_request.kind == kind then
    request = pair.active_supply_request
  else
    request = build_supply_request(pair, kind, target)
  end
  if tech_priests_abort_if_supply_request_obsolete(pair, request) then return true end
  return original_0128_maybe_start_supply_scavenge(pair, kind, target)
end

original_0128_tick_pair = tick_pair
function tick_pair(pair)
  if pair and (pair.inventory_scan or pair.scavenge or pair.emergency_craft) then
    if tech_priests_abort_if_supply_request_obsolete(pair) then return end
  end
  return original_0128_tick_pair(pair)
end


-- 0.1.129 Tech-Priest tier doctrine gates:
-- Junior priests use only what is already in their Cogitator Station or what
-- logistics physically delivers there. Intermediate priests may search local
-- inventories and clear station clutter. Senior priests may escalate to the
-- last-ditch emergency fabrication routine after local scans fail.
TECH_PRIESTS_TIER_RANKS_0129 = { junior = 1, intermediate = 2, senior = 3, ["planetary-magos"] = 4, planetary_magos = 4, magos = 4, void = 5 }

function tech_priests_get_pair_tier_rank(pair)
  if not pair then return 1 end
  local tier = pair.tier
  if (not tier or tier == "") and pair.station and pair.station.valid and get_station_config then
    local cfg = get_station_config(pair.station)
    tier = cfg and cfg.tier or tier
  end
  return TECH_PRIESTS_TIER_RANKS_0129[tier or "junior"] or 1
end

function tech_priests_pair_allows_local_inventory_scan(pair)
  return tech_priests_get_pair_tier_rank(pair) >= 2
end

function tech_priests_pair_allows_emergency_desperation(pair)
  return tech_priests_get_pair_tier_rank(pair) >= 3
end

function tech_priests_clear_forbidden_advanced_supply_state(pair)
  if not pair then return end
  local rank = tech_priests_get_pair_tier_rank(pair)
  if rank < 2 then
    if clear_logistic_inventory_scan then clear_logistic_inventory_scan(pair) end
    pair.scavenge = nil
    pair.cram = nil
    pair.inventory_scan = nil
    pair.cram_search_started_tick = nil
    pair.cram_dump_due_tick = nil
    pair.next_cram_search_tick = nil
  end
  if rank < 3 then
    pair.emergency_craft = nil
  end
end

original_0129_start_logistic_scavenge_inventory_scan = start_logistic_scavenge_inventory_scan
function start_logistic_scavenge_inventory_scan(pair, request)
  if not tech_priests_pair_allows_local_inventory_scan(pair) then
    if pair then
      pair.mode = get_station_logistic_network and get_station_logistic_network(pair.station) and "logistics-scavenge-countdown" or "logistics-no-network"
    end
    return false
  end
  return original_0129_start_logistic_scavenge_inventory_scan(pair, request)
end

original_0129_start_logistic_cram_inventory_scan = start_logistic_cram_inventory_scan
function start_logistic_cram_inventory_scan(pair, item)
  if not tech_priests_pair_allows_local_inventory_scan(pair) then
    if pair then pair.mode = "logistics-cram-countdown" end
    return false
  end
  return original_0129_start_logistic_cram_inventory_scan(pair, item)
end

original_0129_maybe_start_cram_mode = maybe_start_cram_mode
function maybe_start_cram_mode(pair, request)
  if not tech_priests_pair_allows_local_inventory_scan(pair) then
    if pair and request and not request_has_station_space(pair, request) then
      if not pair.logistic_cram_due_tick then
        pair.logistic_cram_start_tick = game.tick
        pair.logistic_cram_due_tick = game.tick + LOGISTIC_FRUSTRATION_THRESHOLD_TICKS
      end
      pair.mode = "logistics-cram-countdown"
    end
    return false
  end
  return original_0129_maybe_start_cram_mode(pair, request)
end

original_0129_start_emergency_desperation_craft = start_emergency_desperation_craft
function start_emergency_desperation_craft(pair, request)
  if not tech_priests_pair_allows_emergency_desperation(pair) then
    if pair then
      pair.emergency_craft = nil
      pair.next_scavenge_search_tick = game.tick + LOGISTIC_SCAVENGE_RETRY_TICKS
      pair.mode = "returning"
      if pair.priest and pair.priest.valid and pair.station and pair.station.valid then
        return_to_station(pair.priest, pair.station)
      end
    end
    return false
  end
  return original_0129_start_emergency_desperation_craft(pair, request)
end

original_0129_finish_failed_logistic_inventory_scan = finish_failed_logistic_inventory_scan
function finish_failed_logistic_inventory_scan(pair)
  if pair and pair.inventory_scan and pair.inventory_scan.kind == "scavenge" and not tech_priests_pair_allows_emergency_desperation(pair) then
    clear_logistic_inventory_scan(pair)
    pair.scavenge = nil
    pair.next_scavenge_search_tick = game.tick + LOGISTIC_SCAVENGE_RETRY_TICKS
    pair.mode = "returning"
    if pair.priest and pair.priest.valid and pair.station and pair.station.valid then
      return_to_station(pair.priest, pair.station)
    end
    return false
  end
  return original_0129_finish_failed_logistic_inventory_scan(pair)
end

original_0129_find_scavenge_source_for_request = find_scavenge_source_for_request
function find_scavenge_source_for_request(pair, request)
  if not tech_priests_pair_allows_local_inventory_scan(pair) then return nil end
  return original_0129_find_scavenge_source_for_request(pair, request)
end

original_0129_handle_logistic_inventory_scan = handle_logistic_inventory_scan
function handle_logistic_inventory_scan(pair)
  if pair and pair.inventory_scan and not tech_priests_pair_allows_local_inventory_scan(pair) then
    clear_logistic_inventory_scan(pair)
    pair.scavenge = nil
    pair.cram = nil
    pair.mode = "returning"
    if pair.priest and pair.priest.valid and pair.station and pair.station.valid then
      return_to_station(pair.priest, pair.station)
    end
    return false
  end
  return original_0129_handle_logistic_inventory_scan(pair)
end

original_0129_handle_emergency_desperation_craft = handle_emergency_desperation_craft
function handle_emergency_desperation_craft(pair)
  if pair and pair.emergency_craft and not tech_priests_pair_allows_emergency_desperation(pair) then
    pair.emergency_craft = nil
    pair.mode = "returning"
    if pair.priest and pair.priest.valid and pair.station and pair.station.valid then
      return_to_station(pair.priest, pair.station)
    end
    return false
  end
  return original_0129_handle_emergency_desperation_craft(pair)
end

original_0129_maybe_start_supply_scavenge = maybe_start_supply_scavenge
function maybe_start_supply_scavenge(pair, kind, target)
  if not (pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid) then return false end
  if not is_cogitator_logistic_requisition_enabled(pair.station.force) then return false end

  tech_priests_clear_forbidden_advanced_supply_state(pair)

  if pair.emergency_craft then
    if tech_priests_pair_allows_emergency_desperation(pair) then return handle_emergency_desperation_craft(pair) end
    pair.emergency_craft = nil
  end
  if pair.inventory_scan then
    if tech_priests_pair_allows_local_inventory_scan(pair) then return handle_logistic_inventory_scan(pair) end
    clear_logistic_inventory_scan(pair)
  end
  if pair.scavenge then
    if tech_priests_pair_allows_local_inventory_scan(pair) then return handle_priest_scavenge_task(pair) end
    pair.scavenge = nil
  end
  if pair.cram then
    if tech_priests_pair_allows_local_inventory_scan(pair) then return handle_priest_cram_task(pair) end
    pair.cram = nil
  end

  local request = nil
  if pair.active_supply_request and pair.active_supply_request.kind == kind then
    request = pair.active_supply_request
  else
    request = build_supply_request(pair, kind, target)
  end
  if not request then return false end
  if tech_priests_abort_if_supply_request_obsolete and tech_priests_abort_if_supply_request_obsolete(pair, request) then return true end
  pair.active_supply_request = request

  local rank = tech_priests_get_pair_tier_rank(pair)
  local network = get_station_logistic_network(pair.station)

  if network then
    ensure_pair_logistic_caches(pair)
    transfer_cache_inventory_to_station(pair)
    issue_station_logistic_request(pair, request)
  else
    if pair.logistic_requester and pair.logistic_requester.valid then pair.logistic_requester.destroy({ raise_destroy = false }) end
    if pair.logistic_return_cache and pair.logistic_return_cache.valid then pair.logistic_return_cache.destroy({ raise_destroy = false }) end
    pair.logistic_requester = nil
    pair.logistic_return_cache = nil
  end

  -- Junior doctrine: no roaming, no inventory rummaging, no cramming, no field
  -- fabrication. The station can still be supplied by logistics, but the Junior
  -- priest only acts on supplies that are actually in the Cogitator inventory.
  if rank < 2 then
    if network then
      if not pair.logistic_frustration_due_tick or pair.logistic_frustration_kind ~= kind then
        pair.logistic_frustration_kind = kind
        pair.logistic_frustration_start_tick = game.tick
        pair.logistic_frustration_due_tick = game.tick + LOGISTIC_FRUSTRATION_THRESHOLD_TICKS
      end
      if request_has_station_space(pair, request) then
        pair.mode = "logistics-requested"
      else
        pair.mode = "logistics-clearing-space"
      end
    else
      pair.mode = "logistics-no-network"
    end
    return false
  end

  -- Intermediate and Senior doctrine: if there is no logistics network, give the
  -- station ten seconds of embarrassed waiting before beginning local scans.
  if not network then
    local no_network_key = "no-network-" .. tostring(kind)
    if pair.logistic_frustration_kind ~= no_network_key then
      pair.logistic_frustration_kind = no_network_key
      pair.logistic_requested_item = get_inventory_scan_item_name and get_inventory_scan_item_name({ request = request }) or nil
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

original_0129_tick_pair = tick_pair
function tick_pair(pair)
  if pair then tech_priests_clear_forbidden_advanced_supply_state(pair) end
  return original_0129_tick_pair(pair)
end


-- 0.1.130 logistics frustration timer visibility/tuning:
-- * shorten the standard logistics/scavenge/cram patience window from 120s to 60s
-- * clamp old in-save timers down to the new threshold
-- * force a visible countdown onto missing-supply bubbles, even if an older save
--   still has the old non-countdown runtime setting value.
function tech_priests_logistic_timer_limit_for_kind(kind)
  kind = tostring(kind or "")
  if string.sub(kind, 1, 11) == "no-network-" then
    return LOGISTIC_NO_NETWORK_SCAVENGE_TICKS or (60 * 10)
  end
  return LOGISTIC_FRUSTRATION_THRESHOLD_TICKS or (60 * 60)
end

function tech_priests_normalize_logistic_frustration_timer(pair)
  if not pair then return end
  if pair.logistic_frustration_start_tick and pair.logistic_frustration_due_tick then
    local limit = tech_priests_logistic_timer_limit_for_kind(pair.logistic_frustration_kind)
    local max_due = pair.logistic_frustration_start_tick + limit
    if pair.logistic_frustration_due_tick > max_due then
      pair.logistic_frustration_due_tick = max_due
    end
  end
  if pair.logistic_cram_start_tick and pair.logistic_cram_due_tick then
    local max_due = pair.logistic_cram_start_tick + (LOGISTIC_FRUSTRATION_THRESHOLD_TICKS or (60 * 60))
    if pair.logistic_cram_due_tick > max_due then
      pair.logistic_cram_due_tick = max_due
    end
  end
end

original_0130_get_priest_status_symbol = get_priest_status_symbol
function get_priest_status_symbol(pair)
  tech_priests_normalize_logistic_frustration_timer(pair)
  local symbol = original_0130_get_priest_status_symbol(pair)
  if pair and pair.logistic_frustration_due_tick then
    local state = classify_priest_visual_state(pair)
    if state == "repair-missing-supplies" or state == "consecrate-missing-supplies" or state == "ammo-missing-supplies" or state == "logistics-no-network" then
      local remaining = math.max(0, math.ceil((pair.logistic_frustration_due_tick - game.tick) / 60))
      local text = tostring(symbol or "")
      if not string.find(text, tostring(remaining), 1, true) and not string.find(text, "{seconds}", 1, true) then
        text = text .. " " .. tostring(remaining)
      end
      symbol = text:gsub("{seconds}", tostring(remaining))
    end
  end
  return symbol
end

original_0130_maybe_start_supply_scavenge = maybe_start_supply_scavenge
function maybe_start_supply_scavenge(pair, kind, target)
  tech_priests_normalize_logistic_frustration_timer(pair)
  local result = original_0130_maybe_start_supply_scavenge(pair, kind, target)
  tech_priests_normalize_logistic_frustration_timer(pair)
  return result
end


-- 0.1.131 priority interruption pass:
-- * Hostile creatures now interrupt active repair/consecration/logistics/scanning work.
-- * When an inventory scan timer finishes, the priest checks whether a higher-priority
--   duty has appeared before committing to the scanned inventory.

function tech_priests_get_supply_request_kind_from_pair(pair)
  if not pair then return nil end
  if pair.inventory_scan and pair.inventory_scan.request and pair.inventory_scan.request.kind then return pair.inventory_scan.request.kind end
  if pair.scavenge and pair.scavenge.kind then return pair.scavenge.kind end
  if pair.emergency_craft and pair.emergency_craft.request and pair.emergency_craft.request.kind then return pair.emergency_craft.request.kind end
  if pair.active_supply_request and pair.active_supply_request.kind then return pair.active_supply_request.kind end
  return nil
end

function tech_priests_clear_interruptible_supply_work(pair)
  if not pair then return end
  if clear_logistic_inventory_scan then clear_logistic_inventory_scan(pair) end
  pair.scavenge = nil
  pair.cram = nil
  pair.inventory_scan = nil
  pair.emergency_craft = nil
  pair.active_supply_request = nil
  pair.logistic_requested_item = nil
  pair.logistic_requested_count = nil
  if clear_logistic_frustration then clear_logistic_frustration(pair) end
end

function tech_priests_try_interrupt_for_hostiles(pair)
  if not (pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid) then return false end
  local radius = refresh_pair_radius and refresh_pair_radius(pair) or get_station_operating_radius(pair.station)
  local enemy = find_enemy_target and find_enemy_target(pair.station, radius, pair.priest) or nil
  if not (enemy and enemy.valid) then return false end

  local current_kind = tech_priests_get_supply_request_kind_from_pair(pair)
  -- Ammo acquisition is part of the combat response. Other supply chores are
  -- interruptible when flesh, claw, or chitin approaches the shrine.
  if current_kind ~= "ammo" then
    tech_priests_clear_interruptible_supply_work(pair)
  end

  pair.combat_target = enemy
  pair.target = enemy
  return handle_combat(pair)
end

function tech_priests_start_repair_priority(pair, radius)
  if not (pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid) then return false end
  radius = radius or (refresh_pair_radius and refresh_pair_radius(pair) or get_station_operating_radius(pair.station))
  if station_has_repair_pack and station_has_repair_pack(pair.station) then
    local target = find_damaged_target and find_damaged_target(pair.station, radius, pair.priest) or nil
    if target then
      tech_priests_clear_interruptible_supply_work(pair)
      pair.target = target
      repair_target(pair, target)
      return true
    end
  else
    local target = find_repair_waiting_target and find_repair_waiting_target(pair.station, radius, pair.priest, true) or nil
    if target then
      tech_priests_clear_interruptible_supply_work(pair)
      pair.mode = "missing-repair-supplies"
      pair.target = target
      if maybe_start_supply_scavenge and maybe_start_supply_scavenge(pair, "repair", target) then return true end
      return_to_station(pair.priest, pair.station)
      return true
    end
  end
  return false
end
