-- Tech Priests 0.1.347 consecration modularization pass 1.
-- Extracted from control.lua to isolate machine-spirit state logic.

-- 0.1.478: Every purity restoration now seals a source mark into the machine ledger.
local function tech_priests_0478_actor_name(player)
  if player and player.valid then return player.name or ("player#" .. tostring(player.index or "?")) end
  return "unknown celebrant"
end

function tech_priests_0478_record_consecration_source(record, entity, source, item_name, restored, before, after, maximum, player)
  if not (record and entity and entity.valid) then return false end
  record.consecration_history_0422 = record.consecration_history_0422 or {}
  local history = record.consecration_history_0422
  local tick = game and game.tick or 0
  local machine_id_text = tech_priests_0446_format_machine_id and tech_priests_0446_format_machine_id(record) or nil
  local entry = {
    tick = tick,
    operation = "purity+",
    event_type = "consecration-source",
    machine_id_text = machine_id_text,
    before = before,
    after = after,
    max = maximum,
    max_after = maximum,
    base_max = maximum,
    decay = 0,
    restored = restored,
    source = tostring(source or "unsealed rite"),
    item = item_name,
    actor = tech_priests_0478_actor_name(player),
    bell = tick,
  }
  history[#history + 1] = entry
  while #history > 80 do table.remove(history, 1) end
  record.last_consecration_source_0478 = entry.source
  record.last_consecration_item_0478 = item_name
  record.last_consecration_actor_0478 = entry.actor
  record.last_consecration_restored_0478 = restored
  record.last_consecration_tick_0478 = tick
  return true
end

function apply_consecration_item(player, entity, item_name)
  if not is_consecration_target(entity) then
    if player and player.valid then player.create_local_flying_text({ text = { "tech-priests-consecration.sanctification-invalid" }, position = entity and entity.valid and entity.position or player.position }) end
    return false
  end

  local record = get_consecration_record(entity)
  if not record then return false end

  local current = record.sanctification or get_base_sanctification_start()
  local maximum = record.max_sanctification or get_base_sanctification_max()
  if current >= maximum then
    if player and player.valid then
      player.create_local_flying_text({ text = { "tech-priests-consecration.sanctification-full", string.format("%.1f", current), string.format("%.0f", maximum) }, position = entity.position })
    end
    draw_sanctification_label(record)
    update_sanctification_overlay(record, true)
    return false
  end

  local restore_amount = get_player_consecration_item_restore_amount(item_name)
  if not restore_amount then return false end
  if not consume_consecration_item_from_player(player, item_name) then return false end

  local restored = math.min(restore_amount, maximum - current)
  record.sanctification = current + restored
  if tech_priests_0478_record_consecration_source then tech_priests_0478_record_consecration_source(record, entity, "hand-applied rite", item_name, restored, current, record.sanctification, maximum, player) end
  if player and player.valid then
    player.create_local_flying_text({
      text = { "tech-priests-consecration.sanctification-restored", string.format("%.1f", restored), string.format("%.1f", record.sanctification), string.format("%.0f", maximum) },
      position = entity.position
    })
  end
  draw_sanctification_label(record)
  update_sanctification_overlay(record, true)
  return true
end

function collect_consecration_targets_from_entities(entities)
  local valid_targets = {}
  for _, entity in pairs(entities or {}) do
    if is_consecration_target(entity) then
      local record = get_consecration_record(entity)
      if record then
        local current = record.sanctification or get_base_sanctification_start()
        local maximum = record.max_sanctification or get_base_sanctification_max()
        if current < maximum then
          valid_targets[#valid_targets + 1] = { entity = entity, record = record, current = current, maximum = maximum }
        end
      end
    end
  end
  return valid_targets
end

function restore_consecration_targets(valid_targets, restore_amount, player, source, item_name)
  local restored_count = 0
  local total_restored = 0
  for _, target in pairs(valid_targets or {}) do
    local restored = math.min(restore_amount, target.maximum - target.current)
    if restored > 0 then
      target.record.sanctification = target.current + restored
      if tech_priests_0478_record_consecration_source then tech_priests_0478_record_consecration_source(target.record, target.entity, source or "area consecration cloud", item_name, restored, target.current, target.record.sanctification, target.maximum, player) end
      draw_sanctification_label(target.record)
      update_sanctification_overlay(target.record, true)
      restored_count = restored_count + 1
      total_restored = total_restored + restored
      if player and player.valid then
        player.create_local_flying_text({
          text = { "tech-priests-consecration.sanctification-restored", string.format("%.1f", restored), string.format("%.1f", target.record.sanctification), string.format("%.0f", target.maximum) },
          position = target.entity.position
        })
      end
    end
  end
  return restored_count, total_restored
end

function apply_area_consecration_item(player, entities, item_name)
  local restore_amount = get_player_consecration_item_restore_amount(item_name)
  if not restore_amount then return false end
  local valid_targets = collect_consecration_targets_from_entities(entities)

  if #valid_targets == 0 then
    if player and player.valid then
      player.create_local_flying_text({ text = { "tech-priests-consecration.sanctification-invalid" }, position = player.position })
    end
    return false
  end

  if not consume_consecration_item_from_player(player, item_name) then return false end

  restore_consecration_targets(valid_targets, restore_amount, player, "area consecration rite", item_name)

  if player and player.valid then
    player.play_sound({ path = "utility/confirm" })
  end
  return true
end


function on_consecration_item_selected_area(event)
  if not (event and event.item and event.entities) then return end
  if event.item ~= SACRED_OIL_NAME and event.item ~= MACHINE_MAINTENANCE_LITANY_NAME and event.item ~= RITUAL_OF_MACHINE_APPEASEMENT_NAME then return end
  local player = game.get_player(event.player_index)
  if not (player and player.valid) then return end

  for _, entity in pairs(event.entities) do
    if apply_consecration_item(player, entity, event.item) then
      return
    end
  end
end

-- 0.1.351: explicit capsule/click application path. Capsule use is consumed by
-- Factorio before/while the runtime event fires, so this variant restores
-- sanctity without attempting to remove a second oil item from the cursor stack.
function tech_priests_0351_apply_consecration_no_consume(player, entity, item_name)
  if not (entity and entity.valid and is_consecration_target and is_consecration_target(entity)) then
    if player and player.valid then player.create_local_flying_text({ text = { "tech-priests-consecration.sanctification-invalid" }, position = entity and entity.valid and entity.position or player.position }) end
    return false
  end
  local record = get_consecration_record(entity)
  if not record then return false end
  local current = record.sanctification or get_base_sanctification_start()
  local maximum = record.max_sanctification or get_base_sanctification_max()
  if current >= maximum then
    if player and player.valid then
      player.create_local_flying_text({ text = { "tech-priests-consecration.sanctification-full", string.format("%.1f", current), string.format("%.0f", maximum) }, position = entity.position })
    end
    draw_sanctification_label(record)
    update_sanctification_overlay(record, true)
    return false
  end
  local restore_amount = get_player_consecration_item_restore_amount(item_name)
  if not restore_amount then return false end
  local restored = math.min(restore_amount, maximum - current)
  record.sanctification = current + restored
  if tech_priests_0478_record_consecration_source then tech_priests_0478_record_consecration_source(record, entity, "capsule-use rite", item_name, restored, current, record.sanctification, maximum, player) end
  if player and player.valid then
    player.create_local_flying_text({
      text = { "tech-priests-consecration.sanctification-restored", string.format("%.1f", restored), string.format("%.1f", record.sanctification), string.format("%.0f", maximum) },
      position = entity.position
    })
    player.play_sound({ path = "utility/confirm" })
  end
  draw_sanctification_label(record)
  update_sanctification_overlay(record, true)
  return true
end

-- 0.1.348: direct held-item application repair. The original selection-tool
-- path still handles drag-select, but after modularization some practical use
-- cases regressed where the player simply points at a machine with Sacred
-- Machine Oil / a litany / appeasement rite in hand. This helper is intentionally
-- conservative and is called by a late control.lua selected-entity wrapper.
function tech_priests_0348_try_apply_cursor_consecration(player, entity)
  if not (player and player.valid and entity and entity.valid) then return false end
  local cursor = player.cursor_stack
  if not (cursor and cursor.valid_for_read and cursor.name) then return false end
  local item = cursor.name
  if item ~= SACRED_OIL_NAME and item ~= MACHINE_MAINTENANCE_LITANY_NAME and item ~= RITUAL_OF_MACHINE_APPEASEMENT_NAME then return false end
  if not is_consecration_target(entity) then return false end
  -- Prevent machine-oil hover burn: only apply when the player is close enough
  -- that this behaves like a deliberate hand application rather than map-wide
  -- cursor drift. The selection-tool drag path remains available at any distance.
  local ch = player.character
  if ch and ch.valid then
    local dx = (ch.position.x or 0) - (entity.position.x or 0)
    local dy = (ch.position.y or 0) - (entity.position.y or 0)
    if dx * dx + dy * dy > 16 then return false end
  end
  local last = storage and storage.tech_priests and storage.tech_priests.consecration and storage.tech_priests.consecration.last_direct_apply_0348 or nil
  local unit = entity.unit_number or 0
  local pindex = player.index or 0
  local tick = game and game.tick or 0
  if last and last.player == pindex and last.unit == unit and tick - (last.tick or 0) < 20 then return false end
  local ok = apply_consecration_item(player, entity, item)
  if ok then
    storage.tech_priests.consecration.last_direct_apply_0348 = { player = pindex, unit = unit, tick = tick, item = item }
  end
  return ok
end


get_current_crafting_progress = function(entity)
  if not (entity and entity.valid) then return nil end
  local ok, progress = pcall(function() return entity.crafting_progress end)
  if ok then return progress end
  return nil
end

-- 0.1.413: Factorio 2.x machines can complete one or more short recipes between
-- the 10-tick consecration service pulses.  Watching only crafting_progress can
-- therefore miss the reset/wrap point entirely, making sanctification look frozen
-- during normal assembler work.  products_finished is the preferred monotonic
-- operation counter when the runtime exposes it; crafting_progress remains the
-- fallback sensor for older/unsupported entities.
get_current_products_finished = function(entity)
  if not (entity and entity.valid) then return nil end
  local ok, value = pcall(function() return entity.products_finished end)
  if ok and value ~= nil then
    value = tonumber(value)
    if value then return value end
  end
  return nil
end



-- 0.1.515: shared non-player consecration application path for Tech-Priest
-- capsule-style rites.  Player capsule use still uses the existing event path;
-- scripted priests call this function with an explicit source_context so the
-- machine ledger records who performed the rite and which Cogitator supplied it.
function tech_priests_0515_apply_consecration_from_source(entity, item_name, source_context)
  if not (entity and entity.valid and is_consecration_target and is_consecration_target(entity)) then return false, "invalid-target" end
  local record = get_consecration_record(entity)
  if not record then return false, "no-record" end
  local current = record.sanctification or get_base_sanctification_start()
  local maximum = record.max_sanctification or get_base_sanctification_max(entity.force)
  if current >= maximum then
    draw_sanctification_label(record)
    update_sanctification_overlay(record, true)
    return false, "full"
  end
  local restore_amount = get_player_consecration_item_restore_amount(item_name)
  if not restore_amount then return false, "bad-item" end
  local restored = math.min(restore_amount, maximum - current)
  if restored <= 0 then return false, "zero-restore" end
  record.sanctification = current + restored

  local ctx = type(source_context) == "table" and source_context or {}
  local source = ctx.method or ctx.source or "tech-priest capsule rite"
  if tech_priests_0478_record_consecration_source then
    tech_priests_0478_record_consecration_source(record, entity, source, item_name, restored, current, record.sanctification, maximum, nil)
  end

  local actor = ctx.priest_label or ctx.priest_display_name or ctx.priest_name or "Tech-Priest"
  local station_label = ctx.station_label or ctx.station_display_name or ctx.station_name or "Cogitator Station"
  local history = record.consecration_history_0422 or {}
  local entry = history[#history]
  if entry and entry.event_type == "consecration-source" then
    entry.actor = actor
    entry.station = station_label
    entry.priest_unit_0515 = ctx.priest_unit
    entry.station_unit_0515 = ctx.station_unit
    entry.method_0515 = source
    entry.order_id_0515 = ctx.order_id
    entry.source_context_0515 = {
      source_type = ctx.source_type or "tech-priest",
      method = source,
      priest_name = ctx.priest_name,
      priest_unit = ctx.priest_unit,
      priest_label = actor,
      station_name = ctx.station_name,
      station_unit = ctx.station_unit,
      station_label = station_label,
      order_id = ctx.order_id,
      item = item_name,
    }
  end
  record.last_consecration_source_0478 = source
  record.last_consecration_item_0478 = item_name
  record.last_consecration_actor_0478 = actor
  record.last_consecration_restored_0478 = restored
  record.last_consecration_tick_0478 = game and game.tick or 0
  record.last_consecration_priest_unit_0515 = ctx.priest_unit
  record.last_consecration_station_unit_0515 = ctx.station_unit
  record.last_consecration_station_label_0515 = station_label
  record.last_consecration_method_0515 = source
  record.last_consecration_order_0515 = ctx.order_id

  draw_sanctification_label(record)
  update_sanctification_overlay(record, true)
  return true, restored
end


return { name = 'scripts.core.consecration.api', version = '0.1.515' }
