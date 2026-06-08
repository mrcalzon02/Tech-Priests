-- Tech Priests 0.1.347 consecration modularization pass 1.

local function tech_priests_effect_text_0448(entity, offset_y, text, color, ttl, scale)
  if not (entity and entity.valid and entity.surface and entity.position and tech_priests_safe_floating_text_0448) then return false end
  return tech_priests_safe_floating_text_0448(entity.surface, { x = entity.position.x, y = entity.position.y + (tonumber(offset_y) or 0) }, text, color, { ttl = ttl or 120, scale = scale or 0.76 }) and true or false
end
-- Extracted from control.lua to isolate machine-spirit state logic.

function apply_low_sanctification_pollution(record)
  if not (record and record.entity and record.entity.valid) then return end
  local ratio = get_sanctification_ratio(record)
  if ratio >= 1.0 then return end

  -- This is the first safe runtime stand-in for the "wasteful, power-hungry"
  -- state: low sanctification visibly dirties the factory while the active-time
  -- throttle makes each completed operation take much longer.
  local pollution_per_tick_window = LOW_SANCTIFICATION_EXTRA_POLLUTION_PER_SECOND * (1 - ratio) * 10 / 60
  if pollution_per_tick_window <= 0 then return end
  pcall(function()
    record.entity.surface.pollute(record.entity.position, pollution_per_tick_window)
  end)
end

function set_machine_throttle_status(entity)
  set_machine_ritual_status(entity, {
    { "tech-priests-consecration.status-cooling-off" },
    { "tech-priests-consecration.status-resetting" },
    { "tech-priests-consecration.status-awaiting-restart" }
  }, get_nonoperating_status_diode())
end

function apply_sanctification_performance(record)
  if not (record and record.entity and record.entity.valid) then return end
  update_waste_jam_state(record)
  if record.waste_jammed then return end

  local entity = record.entity
  local ratio = get_sanctification_ratio(record)
  pcall(function() entity.disabled_by_script = false end)
  if entity.active == false then entity.active = true end

  if ratio >= 0.999 then
    record.throttle_hold_progress = nil
    clear_machine_custom_status(entity)
    return
  end

  local progress = get_current_crafting_progress(entity)
  if not progress or progress <= 0 then
    record.throttle_hold_progress = nil
    clear_machine_custom_status(entity)
    return
  end

  local active_ticks = math.max(10, math.floor(SANCTIFICATION_THROTTLE_CYCLE_TICKS * ratio + 0.5))
  local cycle_position = game.tick % SANCTIFICATION_THROTTLE_CYCLE_TICKS

  if cycle_position >= active_ticks then
    record.throttle_hold_progress = record.throttle_hold_progress or progress
    pcall(function() entity.crafting_progress = record.throttle_hold_progress end)
    set_machine_throttle_status(entity)
  else
    record.throttle_hold_progress = nil
    clear_machine_custom_status(entity)
  end

  apply_low_sanctification_pollution(record)
end

function spawn_machine_damage_smoke(entity, severe)
  if not (entity and entity.valid and entity.surface and entity.position) then return end

  -- Damage smoke should be visible proof that the machine just suffered real
  -- harm: either physical hit-point damage or maximum-sanctification capacity
  -- damage. Use a small explosion-puff plus a brief trivial-smoke bloom. The
  -- prototype now starts small, expands hard, and fades after roughly a second
  -- or two so the player can see the injury without blanketing the factory.
  local surface = entity.surface
  local position = entity.position
  local count = severe and 2 or 1

  for i = 1, count do
    local angle = ((i - 1) / count) * math.pi * 2 + ((game and game.tick or 0) % 37) * 0.13
    local distance = severe and 0.34 or 0.20
    local smoke_position = {
      x = position.x + math.cos(angle) * distance,
      y = position.y + math.sin(angle) * distance
    }

    surface.create_entity({
      name = MACHINE_DAMAGE_SMOKE_ENTITY_NAME,
      position = smoke_position
    })

    if surface.create_trivial_smoke then
      surface.create_trivial_smoke({
        name = MACHINE_DAMAGE_SMOKE_CLOUD_NAME,
        position = smoke_position
      })
    else
      surface.create_entity({
        name = MACHINE_DAMAGE_SMOKE_CLOUD_NAME,
        position = smoke_position
      })
    end
  end
end

function spawn_sanctification_damage_floating_text(entity, amount)
  if not (entity and entity.valid and entity.surface and entity.position) then return end

  local display_amount = math.max(1, math.floor((tonumber(amount) or 0) + 0.5))
  local position = {
    x = entity.position.x,
    y = entity.position.y - 1.1
  }

  tech_priests_effect_text_0448(entity, -1.1, "-" .. tostring(display_amount) .. " sanctity", { r = 1.0, g = 0.18, b = 0.12, a = 1 }, 120, 0.78)
end

function spawn_priest_translocation_smoke(surface, position, force, large)
  if not (surface and position) then return end

  -- Keep priest translocation visuals cheap and brief. Recall/redeploy logic can
  -- affect many priests in a short window; spawning multiple lingering puffs per
  -- priest quickly becomes visual spam. One quick puff is enough to show the
  -- sanctioned disappearance/reappearance without blanketing the station block.
  local tick_phase = (game and game.tick or 0)
  local angle = (tick_phase % 53) * 0.09
  local distance = large and 0.08 or 0.04
  local smoke_position = {
    x = position.x + math.cos(angle) * distance,
    y = position.y + math.sin(angle) * distance
  }

  pcall(function()
    surface.create_entity({
      name = PRIEST_TRANSLOCATION_SMOKE_ENTITY_NAME,
      position = smoke_position,
      force = force
    })
  end)
end

function spawn_priest_smoke_for_entity(entity, large)
  if not (entity and entity.valid and entity.surface and entity.position) then return end
  spawn_priest_translocation_smoke(entity.surface, entity.position, entity.force, large)
end


function get_entity_fuel_inventory(entity)
  if not (entity and entity.valid) then return nil end

  local ok, inventory = pcall(function()
    if entity.get_fuel_inventory then
      return entity.get_fuel_inventory()
    end
    return nil
  end)
  if ok and inventory and inventory.valid ~= false then return inventory end

  if defines and defines.inventory and defines.inventory.fuel then
    ok, inventory = pcall(function()
      return entity.get_inventory(defines.inventory.fuel)
    end)
    if ok and inventory and inventory.valid ~= false then return inventory end
  end

  return nil
end

function remove_one_fuel_from_inventory(inventory)
  if not inventory then return nil end

  local candidates = {}
  local ok, length = pcall(function() return #inventory end)
  if not ok or not length then return nil end

  for i = 1, length do
    local stack = inventory[i]
    if stack and stack.valid_for_read and (stack.count or 0) > 0 then
      candidates[#candidates + 1] = i
    end
  end

  if #candidates <= 0 then return nil end
  local slot = candidates[math.random(#candidates)]
  local stack = inventory[slot]
  if not (stack and stack.valid_for_read and (stack.count or 0) > 0) then return nil end

  local name = stack.name
  local ok_clear = false
  if stack.count <= 1 then
    ok_clear = pcall(function() stack.clear() end)
  else
    ok_clear = pcall(function() stack.count = stack.count - 1 end)
  end

  if ok_clear then return name end
  return nil
end

function spawn_low_sanctification_fuel_loss_text(entity, fuel_name, reason)
  if not (entity and entity.valid and entity.surface and entity.position and fuel_name) then return end
  local label = "[item=" .. fuel_name .. "] fuel profaned"
  if reason == "physical-damage" then
    label = "[item=" .. fuel_name .. "] fuel jarred loose"
  elseif reason == "max-sanctification-damage" then
    label = "[item=" .. fuel_name .. "] reserve fouled"
  end

  tech_priests_effect_text_0448(entity, -1.35, label, { r = 1.0, g = 0.42, b = 0.05, a = 1 }, 120, 0.74)
end

function maybe_delete_fuel_from_low_sanctification_burner(record, reason, severity)
  if not (record and record.entity and record.entity.valid) then return false end
  local entity = record.entity
  local ratio = get_sanctification_ratio(record)
  if ratio > LOW_SANCTIFICATION_FUEL_LOSS_RATIO then return false end

  local inventory = get_entity_fuel_inventory(entity)
  if not inventory then return false end

  severity = math.max(0, math.min(1, tonumber(severity) or 0))
  local threshold_severity = math.max(0, math.min(1, (LOW_SANCTIFICATION_FUEL_LOSS_RATIO - ratio) / LOW_SANCTIFICATION_FUEL_LOSS_RATIO))
  local chance = LOW_SANCTIFICATION_FUEL_LOSS_MAX_CHANCE * math.max(severity, threshold_severity)
  if math.random() >= chance then return false end

  local fuel_name = remove_one_fuel_from_inventory(inventory)
  if not fuel_name then return false end

  spawn_low_sanctification_fuel_loss_text(entity, fuel_name, reason)
  return true
end


SANCTIFICATION_PLAYER_OPERATED_ENTITY_TYPES = {
  car = true,
  ["spider-vehicle"] = true,
  locomotive = true
}

SANCTIFICATION_DISTANCE_OPERATED_ENTITY_TYPES = {
  car = true,
  ["spider-vehicle"] = true,
  locomotive = true
}

function is_sanctification_player_operated_entity(entity)
  return entity and entity.valid and SANCTIFICATION_PLAYER_OPERATED_ENTITY_TYPES[entity.type] == true
end

function is_sanctification_distance_operated_entity(entity)
  return entity and entity.valid and SANCTIFICATION_DISTANCE_OPERATED_ENTITY_TYPES[entity.type] == true
end

function get_player_operating_sanctified_entity(entity)
  if not (entity and entity.valid and game and game.connected_players) then return nil end
  for _, player in pairs(game.connected_players) do
    if player and player.valid and player.connected and player.vehicle and player.vehicle.valid and player.vehicle == entity then
      return player
    end
  end
  return nil
end

function spawn_vehicle_control_malfunction_text(entity)
  if not (entity and entity.valid and entity.surface and entity.position) then return end
  tech_priests_effect_text_0448(entity, -1.45, "control malfunction", { r = 1.0, g = 0.04, b = 0.02, a = 1 }, 120, 0.76)
end

function spawn_vehicle_operator_ejected_text(entity)
  if not (entity and entity.valid and entity.surface and entity.position) then return end
  tech_priests_effect_text_0448(entity, -1.65, "operator rejected", { r = 1.0, g = 0.08, b = 0.02, a = 1 }, 120, 0.76)
end

function set_vehicle_temporarily_unresponsive(record, duration_ticks)
  if not (record and record.entity and record.entity.valid) then return false end
  local entity = record.entity
  duration_ticks = math.max(LOW_SANCTIFICATION_CONTROL_MALFUNCTION_MIN_TICKS, math.min(LOW_SANCTIFICATION_CONTROL_MALFUNCTION_MAX_TICKS, math.floor(tonumber(duration_ticks) or LOW_SANCTIFICATION_CONTROL_MALFUNCTION_MIN_TICKS)))
  record.control_malfunction_until_tick = math.max(record.control_malfunction_until_tick or 0, game.tick + duration_ticks)
  record.control_malfunction_original_active = record.control_malfunction_original_active
  if record.control_malfunction_original_active == nil then
    local ok, active = pcall(function() return entity.active end)
    if ok then record.control_malfunction_original_active = active end
  end
  pcall(function() entity.active = false end)
  pcall(function() entity.speed = 0 end)
  spawn_vehicle_control_malfunction_text(entity)
  return true
end

function maintain_vehicle_control_malfunction(record)
  if not (record and record.entity and record.entity.valid) then return end
  local entity = record.entity
  local until_tick = record.control_malfunction_until_tick or 0
  if until_tick > game.tick then
    pcall(function() entity.active = false end)
    pcall(function() entity.speed = 0 end)
    return
  end
  if until_tick > 0 then
    local restore_active = record.control_malfunction_original_active
    if restore_active == nil then restore_active = true end
    pcall(function() entity.active = restore_active end)
    record.control_malfunction_until_tick = nil
    record.control_malfunction_original_active = nil
  end
end

function maybe_start_vehicle_control_malfunction(record, operation_severity)
  if not (record and record.entity and record.entity.valid) then return false end
  local entity = record.entity
  if not is_sanctification_player_operated_entity(entity) then return false end
  local player = get_player_operating_sanctified_entity(entity)
  if not player then return false end

  local ratio = get_sanctification_ratio(record)
  if ratio > LOW_SANCTIFICATION_CONTROL_MALFUNCTION_RATIO then return false end

  local range = math.max(0.001, LOW_SANCTIFICATION_CONTROL_MALFUNCTION_RATIO - LOW_SANCTIFICATION_CONTROL_FLOOR_RATIO)
  local severity = math.max(0, math.min(1, (LOW_SANCTIFICATION_CONTROL_MALFUNCTION_RATIO - ratio) / range))
  operation_severity = math.max(0, math.min(1, tonumber(operation_severity) or 0))
  local chance = LOW_SANCTIFICATION_CONTROL_MALFUNCTION_MAX_CHANCE * math.max(severity, operation_severity)
  if math.random() >= chance then return false end

  local duration = LOW_SANCTIFICATION_CONTROL_MALFUNCTION_MIN_TICKS + math.floor((LOW_SANCTIFICATION_CONTROL_MALFUNCTION_MAX_TICKS - LOW_SANCTIFICATION_CONTROL_MALFUNCTION_MIN_TICKS) * severity + 0.5)
  return set_vehicle_temporarily_unresponsive(record, duration)
end

function maybe_eject_player_from_low_sanctification_vehicle(record, reason, severity)
  if not (record and record.entity and record.entity.valid) then return false end
  local entity = record.entity
  if not is_sanctification_player_operated_entity(entity) then return false end

  local ratio = get_sanctification_ratio(record)
  if ratio > LOW_SANCTIFICATION_OPERATOR_EJECT_RATIO then return false end

  local player = get_player_operating_sanctified_entity(entity)
  if not player then return false end

  severity = math.max(0, math.min(1, tonumber(severity) or 0))
  local threshold_severity = math.max(0, math.min(1, (LOW_SANCTIFICATION_OPERATOR_EJECT_RATIO - ratio) / LOW_SANCTIFICATION_OPERATOR_EJECT_RATIO))
  local chance = 0.35 * math.max(severity, threshold_severity)
  if reason == "max-sanctification-damage" then chance = chance * 0.65 end
  if math.random() >= chance then return false end

  pcall(function() player.driving = false end)
  pcall(function() entity.speed = 0 end)
  spawn_vehicle_operator_ejected_text(entity)
  return true
end

function update_distance_based_sanctification_operation(record)
  if not (record and record.entity and record.entity.valid) then return false end
  local entity = record.entity
  if not is_sanctification_distance_operated_entity(entity) then return false end

  maintain_vehicle_control_malfunction(record)

  local position = entity.position
  if not position then return true end
  local last = record.last_operation_position
  record.last_operation_position = { x = position.x, y = position.y }
  if not last then return true end

  local dx = position.x - last.x
  local dy = position.y - last.y
  local distance = math.sqrt(dx * dx + dy * dy)
  if distance <= 0.001 then return true end

  record.distance_operation_accumulator = (record.distance_operation_accumulator or 0) + distance
  if record.distance_operation_accumulator < VEHICLE_SANCTIFICATION_DISTANCE_OPERATION_TILES then return true end
  record.distance_operation_accumulator = math.max(0, record.distance_operation_accumulator - VEHICLE_SANCTIFICATION_DISTANCE_OPERATION_TILES)

  local value = record.sanctification or 0
  local max_value = record.max_sanctification or get_base_sanctification_max(entity.force)
  local minimum_value = max_value * get_minimum_sanctification_value_fraction()
  local ratio = get_sanctification_ratio(record)
  local operated_by_player = get_player_operating_sanctified_entity(entity) ~= nil

  -- Vehicles and trains degrade by distance travelled rather than recipe cycles.
  -- Idle rolling stock therefore remains stable, while filthy active machinery
  -- accumulates the same maximum-sanctification and physical backlash risks as
  -- manufacturing devices.
  apply_operation_degradation(record)
  record.sanctification = math.max(minimum_value, value - sanctification_decay_amount())
  clamp_machine_sanctification(record)

  if operated_by_player and ratio <= LOW_SANCTIFICATION_CONTROL_MALFUNCTION_RATIO then
    maybe_start_vehicle_control_malfunction(record, math.max(0, (LOW_SANCTIFICATION_CONTROL_MALFUNCTION_RATIO - ratio) / LOW_SANCTIFICATION_CONTROL_MALFUNCTION_RATIO))
  end

  draw_sanctification_label(record)
  update_sanctification_overlay(record, true)
  return true
end

function apply_operation_degradation(record)
  if not (record and record.entity and record.entity.valid) then return end

  local entity = record.entity
  local value = record.sanctification or 0
  local max_value = record.max_sanctification or get_base_sanctification_max()

  -- Below the configured threshold, the machine begins physically injuring itself.
  -- The closer it gets to zero, the more likely and more severe the damage is.
  local damage_threshold, damage_max_chance, damage_min_fraction, damage_max_fraction = get_physical_damage_config()
  if damage_threshold > 0 and value < damage_threshold and entity.health and entity.max_health and entity.health > 0 then
    local severity = math.max(0, math.min(1, (damage_threshold - value) / damage_threshold))
    local chance = severity * damage_max_chance
    if math.random() < chance then
      local damage_fraction = damage_min_fraction + ((damage_max_fraction - damage_min_fraction) * severity * math.random())
      local damage = math.max(1, entity.max_health * damage_fraction)
      spawn_machine_damage_smoke(entity, severity > 0.65)
      pcall(function() entity.damage(damage, entity.force, "impact") end)
      maybe_delete_fuel_from_low_sanctification_burner(record, "physical-damage", severity)
      maybe_eject_player_from_low_sanctification_vehicle(record, "physical-damage", severity)
    end
  end

  -- Below the configured maximum-sanctification damage threshold, completed
  -- operations can reduce the machine's maximum sanctification capacity. This
  -- represents fouling, misalignment, thermal insult, profaned lubricant residue,
  -- and other slowly accumulating insults that ordinary oil cannot fully undo yet.
  local max_damage_threshold, max_damage_chance, max_damage_min_amount, max_damage_max_amount = get_max_sanctification_degradation_config()
  if max_damage_threshold > 0 and value < max_damage_threshold and max_value > get_min_degraded_sanctification_max() then
    local severity = math.max(0, math.min(1, (max_damage_threshold - value) / max_damage_threshold))
    local chance = severity * max_damage_chance
    if math.random() < chance then
      local amount = max_damage_min_amount
      if max_damage_max_amount > max_damage_min_amount then
        amount = max_damage_min_amount + ((max_damage_max_amount - max_damage_min_amount) * math.random())
      end
      local old_max_value = max_value
      record.max_sanctification = math.max(get_min_degraded_sanctification_max(), max_value - amount)
      local actual_loss = math.max(0, old_max_value - record.max_sanctification)
      spawn_machine_damage_smoke(entity, actual_loss >= 17)
      if actual_loss > 0 then
        spawn_sanctification_damage_floating_text(entity, actual_loss)
        local severity_for_fuel_loss = math.max(0, math.min(1, (max_damage_threshold - value) / max_damage_threshold))
        maybe_delete_fuel_from_low_sanctification_burner(record, "max-sanctification-damage", severity_for_fuel_loss)
        maybe_eject_player_from_low_sanctification_vehicle(record, "max-sanctification-damage", severity_for_fuel_loss)
      end
      if (record.sanctification or 0) > record.max_sanctification then
        record.sanctification = record.max_sanctification
      end
      clamp_machine_sanctification(record)
    end
  end
end

function create_operation_waste(record, recipe)
  if not (record and record.entity and record.entity.valid) then return end

  local ratio = get_sanctification_ratio(record)
  local waste_chance = get_waste_chance_from_ratio(ratio)
  local product_units = get_recipe_item_output_units(recipe)
  local expected_waste = product_units * waste_chance

  record.last_detritus_ratio_0417 = ratio
  record.last_detritus_waste_chance_0417 = waste_chance
  record.last_detritus_product_units_0417 = product_units
  record.last_detritus_expected_0417 = expected_waste
  record.last_detritus_attempt_tick_0417 = game and game.tick or 0

  if waste_chance <= 0 then
    record.last_detritus_blocked_reason_0417 = "sanctity-clean-no-waste"
    return
  end

  local waste_count = roll_count_from_expected(expected_waste)
  record.last_detritus_roll_0417 = waste_count
  if waste_count <= 0 then
    record.last_detritus_blocked_reason_0417 = "probability-roll-zero"
    return
  end

  local has_detritus_output_slot = recipe_accepts_machine_detritus_output(recipe)
  record.last_detritus_recipe_slot_0417 = has_detritus_output_slot
  if not has_detritus_output_slot then
    -- Keep this explicit instead of silently returning: if the data-final-fixes
    -- zero-probability product slot fails to appear on a live recipe, the new
    -- /tp-detritus-0417 command will show the exact pointer failure.
    record.last_detritus_blocked_reason_0417 = "recipe-lacks-mechanical-detritus-output-slot"
    return
  end

  record.last_detritus_blocked_reason_0417 = nil
  add_mechanical_detritus(record, waste_count, false)
end

function get_player_consecration_item_restore_amount(item_name)
  if item_name == RITUAL_OF_MACHINE_APPEASEMENT_NAME then
    return RITUAL_OF_MACHINE_APPEASEMENT_RESTORE_AMOUNT
  end
  if item_name == SACRED_INCENSE_GRENADE_NAME then
    return SACRED_INCENSE_GRENADE_RESTORE_AMOUNT
  end
  if item_name == MACHINE_MAINTENANCE_LITANY_NAME then
    return MACHINE_MAINTENANCE_LITANY_RESTORE_AMOUNT
  end
  if item_name == SACRED_OIL_NAME then
    return get_sacred_oil_restore_amount()
  end
  return nil
end

function consume_consecration_item_from_player(player, item_name)
  if not (player and player.valid and item_name) then return false end

  local cursor = player.cursor_stack
  if cursor and cursor.valid_for_read and cursor.name == item_name then
    cursor.count = cursor.count - 1
    return true
  end

  local inventory = player.get_main_inventory()
  if inventory and inventory.remove({ name = item_name, count = 1 }) > 0 then
    return true
  end

  return false
end

function interpolate_color(a, b, t)
  t = math.max(0, math.min(1, t or 0))
  return {
    r = a.r + (b.r - a.r) * t,
    g = a.g + (b.g - a.g) * t,
    b = a.b + (b.b - a.b) * t,
    a = a.a + (b.a - a.a) * t
  }
end

function get_sanctification_percent(record)
  if not record then return 0 end
  local max_value = record.max_sanctification or get_base_sanctification_max()
  if max_value <= 0 then return 0 end
  return math.max(0, math.min(1.2, (record.sanctification or 0) / max_value))
end


return { name = 'scripts.core.consecration.effects', version = '0.1.347' }
