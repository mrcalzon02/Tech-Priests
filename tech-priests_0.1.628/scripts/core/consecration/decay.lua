-- Tech Priests 0.1.347 consecration modularization pass 1.
-- Extracted from control.lua to isolate machine-spirit state logic.

TECH_PRIESTS_SANCTIFICATION_LABEL_REFRESH_TICKS_0446 = TECH_PRIESTS_SANCTIFICATION_LABEL_REFRESH_TICKS_0446 or 60

local function render_object_valid_0446(object)
  if not object then return false end
  local ok, valid = pcall(function() return object.valid end)
  return ok and valid == true
end

function tech_priests_0446_consecration_render_valid(render)
  if type(render) ~= "table" then return false end
  if render_object_valid_0446(render.background) then return true end
  if render_object_valid_0446(render.frame) then return true end
  if render_object_valid_0446(render.fill) then return true end
  if render_object_valid_0446(render.label_current) then return true end
  return false
end

function tech_priests_0446_refresh_sanctification_label_if_due(record, force)
  if not (record and record.entity and record.entity.valid and draw_sanctification_label) then return false end
  ensure_storage()
  local tick = game and game.tick or 0
  local unit = record.entity.unit_number
  local render = unit and storage.tech_priests.consecration.renders[unit] or nil
  local due = force or not tech_priests_0446_consecration_render_valid(render) or tick >= (record.next_sanctification_label_refresh_tick_0446 or 0)
  if not due then return false end
  local ok, err = pcall(draw_sanctification_label, record)
  record.next_sanctification_label_refresh_tick_0446 = tick + TECH_PRIESTS_SANCTIFICATION_LABEL_REFRESH_TICKS_0446
  record.last_sanctification_label_refresh_tick_0446 = tick
  if not ok then
    record.last_sanctification_label_error_0446 = tostring(err)
    return false
  end
  return true
end

function sanctification_decay_amount()
  local min_decay, max_decay = get_sanctification_decay_min_max()
  local base_decay = min_decay
  if max_decay > min_decay then
    base_decay = min_decay + (math.random() * (max_decay - min_decay))
  end

  -- 0.1.447: add explicit per-operation random jitter so live testing can see
  -- each operation bite the sanctity bar differently. The configured min/max still
  -- provide the core envelope; jitter is a controlled overshoot/undershoot layer
  -- clamped at zero and at a bounded upper cap so it cannot explode accidentally.
  local jitter_fraction = 0
  if get_sanctification_decay_random_jitter_fraction then
    jitter_fraction = get_sanctification_decay_random_jitter_fraction()
  end
  if jitter_fraction <= 0 then return base_decay end

  local envelope = math.max(max_decay - min_decay, base_decay, 1)
  local jitter = (math.random() * 2 - 1) * envelope * jitter_fraction
  local upper_cap = math.max(max_decay, base_decay) * (1 + jitter_fraction)
  return math.max(0, math.min(upper_cap, base_decay + jitter))
end


function tech_priests_0453_output_inventory_recipe_total(entity, recipe)
  if not (entity and entity.valid and get_machine_output_inventory) then return nil end
  local inventory = get_machine_output_inventory(entity)
  if not inventory then return nil end
  local allow = nil
  if recipe then
    local products = nil
    pcall(function() products = recipe.products end)
    if not products and recipe.prototype then pcall(function() products = recipe.prototype.products end) end
    if type(products) == "table" then
      allow = {}
      for _, product in pairs(products) do
        if type(product) == "table" then
          local name = product.name or product[1]
          local ptype = product.type or product[2]
          if name and (not ptype or ptype == "item") then allow[name] = true end
        end
      end
    end
  end
  local total = 0
  local ok, contents = pcall(function() return inventory.get_contents() end)
  if not ok or type(contents) ~= "table" then return nil end
  for key, value in pairs(contents) do
    local name = nil
    local count = 0
    if type(value) == "number" then
      name = tostring(key)
      count = value
    elseif type(value) == "table" then
      name = value.name or value[1] or tostring(key)
      count = tonumber(value.count or value.amount or value[2] or 0) or 0
    end
    if name and name ~= (MECHANICAL_DETRITUS_NAME or "mechanical-detritus") and count > 0 then
      if not allow or allow[name] then total = total + count end
    end
  end
  return total
end

function spawn_sanctification_decay_operation_text(record, decay)
  if not (record and record.entity and record.entity.valid and record.entity.surface and record.entity.position) then return false end
  if get_show_sanctification_decay_floaters and not get_show_sanctification_decay_floaters() then return false end
  local amount = tonumber(decay) or 0
  local minimum = get_sanctification_decay_floater_min_amount and get_sanctification_decay_floater_min_amount() or 0
  if amount < minimum then return false end
  local entity = record.entity
  local text = string.format("-%.1f sanctity", amount)
  local ok = false
  if tech_priests_safe_floating_text_0448 then
    ok = tech_priests_safe_floating_text_0448(entity.surface, { x = entity.position.x, y = entity.position.y - 1.20 }, text, { r = 0.95, g = 0.78, b = 0.18, a = 1 }, { ttl = 120, scale = 0.76 }) and true or false
  end
  if ok then
    record.last_sanctification_decay_floater_tick_0447 = game and game.tick or 0
    record.last_sanctification_decay_floater_text_0447 = text
    return true
  end
  return false
end

function apply_completed_sanctification_operation(record, recipe)
  if not (record and record.entity and record.entity.valid) then return false end

  -- 0.1.417 pointer audit repair:
  -- Earlier ordering ran waste and maximum-capacity backlash before the current
  -- operation actually spent sanctity.  That made dirty-machine consequences feel
  -- one cycle late, and in short tests looked as if Detritus/max-damage were not
  -- wired at all.  Spend sanctity first, then compute waste/backlash from the
  -- post-operation machine-spirit state.
  local force = record.entity and record.entity.valid and record.entity.force or nil
  local base_max = get_base_sanctification_max and get_base_sanctification_max(force) or DEFAULT_BASE_SANCTIFICATION_MAX
  local previous_sanctification = tonumber(record.sanctification) or get_base_sanctification_start(force)
  local previous_max = tonumber(record.max_sanctification) or base_max
  local previous_health = tonumber(record.entity.health) or nil
  local decay = sanctification_decay_amount()
  local maximum = tonumber(record.max_sanctification) or get_base_sanctification_max(force)
  local minimum_value = maximum * get_minimum_sanctification_value_fraction()

  record.sanctification = math.max(minimum_value, previous_sanctification - decay)
  clamp_machine_sanctification(record)

  record.last_operation_decay_amount_0417 = decay
  record.last_operation_decay_jitter_fraction_0447 = get_sanctification_decay_random_jitter_fraction and get_sanctification_decay_random_jitter_fraction() or 0
  record.last_operation_sanctity_before_0417 = previous_sanctification
  record.last_operation_sanctity_after_0417 = record.sanctification
  if spawn_sanctification_decay_operation_text then
    spawn_sanctification_decay_operation_text(record, decay)
  end

  local waste_before = tonumber(record.total_detritus_inserted_0422 or record.total_waste_inserted_0417 or 0) or 0
  create_operation_waste(record, recipe)
  local waste_after = tonumber(record.total_detritus_inserted_0422 or record.total_waste_inserted_0417 or waste_before) or waste_before
  local max_before_degradation = tonumber(record.max_sanctification) or previous_max
  apply_operation_degradation(record)

  clamp_machine_sanctification(record)
  local tick = game and game.tick or 0
  record.last_sanctification_decay_tick_0413 = tick
  record.last_sanctification_decay_tick_0417 = tick
  record.completed_operations_seen_0413 = (record.completed_operations_seen_0413 or 0) + 1
  record.completed_operations_seen_0417 = (record.completed_operations_seen_0417 or 0) + 1

  record.last_completed_operation_tick_0446 = tick
  record.last_completed_recipe_0446 = recipe and recipe.name or nil
  record.last_machine_id_text_0446 = tech_priests_0446_format_machine_id and tech_priests_0446_format_machine_id(record) or nil

  local history_event = {
    machine_id = record.machine_id_0446 or record.machine_id,
    machine_id_text = record.last_machine_id_text_0446,
    tick = tick,
    operation = record.completed_operations_seen_0417,
    recipe = recipe and recipe.name or nil,
    before = previous_sanctification,
    after = tonumber(record.sanctification) or 0,
    max_before = previous_max,
    max_after = tonumber(record.max_sanctification) or max_before_degradation,
    base_max = base_max,
    decay = decay,
    max_lost_this_operation = math.max(0, previous_max - (tonumber(record.max_sanctification) or previous_max)),
    waste_inserted = math.max(0, waste_after - waste_before),
    health_before = previous_health,
    health_after = tonumber(record.entity.health) or previous_health
  }
  record.last_consecration_history_event_0422 = history_event
  record.consecration_operation_debug_0453 = record.consecration_operation_debug_0453 or { operations = 0 }
  record.consecration_operation_debug_0453.operations = (record.consecration_operation_debug_0453.operations or 0) + 1
  record.consecration_operation_debug_0453.last_tick = tick
  record.consecration_operation_debug_0453.last_decay = decay
  if log and (tick - tonumber(record.last_consecration_operation_log_tick_0453 or 0) >= 60) then
    record.last_consecration_operation_log_tick_0453 = tick
    log("[Tech-Priests 0.1.453 consecration] operation machine=" .. tostring(history_event.machine_id_text or record.unit_number) .. " entity=" .. tostring(record.entity and record.entity.valid and record.entity.name or "nil") .. " recipe=" .. tostring(history_event.recipe or "nil") .. " before=" .. tostring(previous_sanctification) .. " after=" .. tostring(record.sanctification) .. " decay=" .. tostring(decay))
  end
  if tech_priests_0422_record_consecration_history then
    pcall(tech_priests_0422_record_consecration_history, record, history_event)
  end
  if tech_priests_0523_consider_machine_trait_milestone then
    pcall(tech_priests_0523_consider_machine_trait_milestone, record, history_event)
  end
  if tech_priests_0446_refresh_sanctification_label_if_due then
    tech_priests_0446_refresh_sanctification_label_if_due(record, true)
  end

  return true
end

function update_machine_sanctification(record)
  if not (record and record.entity and record.entity.valid) then return false end
  clamp_machine_sanctification(record)
  record.last_sensor_service_tick_0446 = game and game.tick or 0

  update_waste_jam_state(record)
  if record.waste_jammed then
    if tech_priests_0446_refresh_sanctification_label_if_due then tech_priests_0446_refresh_sanctification_label_if_due(record, false) end
    return true
  end

  local entity = record.entity
  maintain_vehicle_control_malfunction(record)

  local products_finished = get_current_products_finished and get_current_products_finished(entity) or nil
  if products_finished ~= nil then
    record.last_operation_sensor_0446 = "products_finished"
    record.last_products_finished_seen_0446 = products_finished
    local last_products_finished = record.last_products_finished
    record.last_products_finished = products_finished

    if last_products_finished ~= nil and products_finished > last_products_finished then
      local completed_operations = math.min(20, math.floor(products_finished - last_products_finished))
      local recipe = get_current_recipe(entity)
      local changed = false
      for _ = 1, completed_operations do
        changed = apply_completed_sanctification_operation(record, recipe) or changed
      end
      if changed then
        draw_sanctification_label(record)
        update_sanctification_overlay(record, true)
      end
    end

    -- When the monotonic product counter is available, do not also use the
    -- progress-wrap fallback; that would double-count slow recipes.
    update_sanctification_overlay(record, false)
    if tech_priests_0446_refresh_sanctification_label_if_due then tech_priests_0446_refresh_sanctification_label_if_due(record, false) end
    apply_sanctification_performance(record)
    return true
  end

  local recipe_for_output_sensor = get_current_recipe and get_current_recipe(entity) or nil
  local output_total = tech_priests_0453_output_inventory_recipe_total and tech_priests_0453_output_inventory_recipe_total(entity, recipe_for_output_sensor) or nil
  if output_total ~= nil then
    record.last_operation_sensor_0446 = record.last_operation_sensor_0446 or "output-inventory"
    record.last_output_inventory_total_seen_0453 = output_total
    local last_output_total = record.last_output_inventory_total_0453
    record.last_output_inventory_total_0453 = output_total
    if last_output_total ~= nil and output_total > last_output_total then
      record.last_operation_sensor_0446 = "output-inventory"
      local completed_operations = math.min(5, math.max(1, math.floor(output_total - last_output_total)))
      local changed = false
      for _ = 1, completed_operations do
        changed = apply_completed_sanctification_operation(record, recipe_for_output_sensor) or changed
      end
      -- Re-sample after detritus insertion so the Detritus item itself does not
      -- cause a false operation on the next service tick.
      local post_total = tech_priests_0453_output_inventory_recipe_total(entity, recipe_for_output_sensor)
      if post_total ~= nil then record.last_output_inventory_total_0453 = post_total end
      if changed then
        draw_sanctification_label(record)
        update_sanctification_overlay(record, true)
      end
    end
  end

  local progress = get_current_crafting_progress(entity)
  if not progress then
    record.last_operation_sensor_0446 = "distance-or-unsupported"
    update_distance_based_sanctification_operation(record)
    update_sanctification_overlay(record, false)
    if tech_priests_0446_refresh_sanctification_label_if_due then tech_priests_0446_refresh_sanctification_label_if_due(record, false) end
    return true
  end

  record.last_operation_sensor_0446 = "crafting_progress"
  record.last_crafting_progress_seen_0446 = progress
  local last = record.last_progress
  record.last_progress = progress

  -- Only decay when an actual crafting cycle appears to complete. Idle machines
  -- therefore retain their current sanctification state. Waste is generated at
  -- the machine level per completed operation, scaled by recipe output count.
  if last and progress < last then
    local recipe = get_current_recipe(entity)
    if apply_completed_sanctification_operation(record, recipe) then
      draw_sanctification_label(record)
      update_sanctification_overlay(record, true)
    end
  end

  update_sanctification_overlay(record, false)
  if tech_priests_0446_refresh_sanctification_label_if_due then tech_priests_0446_refresh_sanctification_label_if_due(record, false) end
  apply_sanctification_performance(record)

  return true
end

function update_all_consecration_targets()
  ensure_storage()
  for unit, record in pairs(storage.tech_priests.consecration.machines) do
    if not update_machine_sanctification(record) then
      storage.tech_priests.consecration.machines[unit] = nil
      local render = storage.tech_priests.consecration.renders[unit]
      if render then destroy_render_objects(render) end
      storage.tech_priests.consecration.renders[unit] = nil
      clear_sanctification_overlay(unit)
    end
  end
end

function apply_sanctification_research_to_existing_machines(force, previous_base_max, new_base_max)
  ensure_storage()
  if not (force and force.valid) then return end
  previous_base_max = tonumber(previous_base_max) or DEFAULT_BASE_SANCTIFICATION_MAX
  new_base_max = tonumber(new_base_max) or get_base_sanctification_max(force)
  local delta = new_base_max - previous_base_max
  if delta <= 0 then return end

  for _, record in pairs(storage.tech_priests.consecration.machines or {}) do
    if record and record.entity and record.entity.valid and record.entity.force == force then
      -- Preserve any already-lost maximum capacity as damage. A clean 100/100
      -- machine becomes 100/110 after the first capacity rite; a fouled 80/100
      -- machine becomes 80/90, not magically healed back to perfection.
      record.max_sanctification = math.min(new_base_max, (tonumber(record.max_sanctification) or previous_base_max) + delta)
      normalise_consecration_record(record)
      draw_sanctification_label(record)
      update_sanctification_overlay(record, true)
    end
  end
end

function apply_consecration_config_change_to_existing_machines()
  ensure_storage()
  local consecration = storage.tech_priests.consecration
  local old_config = consecration.last_config or get_current_consecration_config_snapshot()
  local new_config = get_current_consecration_config_snapshot()

  local old_base = tonumber(old_config.base_max) or DEFAULT_BASE_SANCTIFICATION_MAX
  local new_base = tonumber(new_config.base_max) or DEFAULT_BASE_SANCTIFICATION_MAX
  local scale = old_base > 0 and (new_base / old_base) or 1

  for _, record in pairs(consecration.machines or {}) do
    if record then
      if scale ~= 1 then
        record.max_sanctification = (tonumber(record.max_sanctification) or old_base) * scale
        record.sanctification = (tonumber(record.sanctification) or old_config.base_start or DEFAULT_BASE_SANCTIFICATION_START) * scale
      end
      normalise_consecration_record(record)
      if record.entity and record.entity.valid then
        draw_sanctification_label(record)
        update_sanctification_overlay(record, true)
      end
    end
  end

  consecration.last_config = new_config
end


return { name = 'scripts.core.consecration.decay', version = '0.1.447' }
