-- Tech Priests 0.1.417 consecration/detritus pointer diagnostics.
-- Runtime-only audit helpers.  This module does not own behavior; it exposes the
-- wiring state so live tests can prove whether decay, Detritus, max-cap damage,
-- and the visible sanctity bar are being driven by the same machine record.

local M = { name = "scripts.core.consecration.diagnostics", version = "0.1.452" }

local function safe_tostring(value)
  if value == nil then return "nil" end
  return tostring(value)
end

local function fmt_number(value, digits)
  value = tonumber(value)
  if not value then return "nil" end
  return string.format("%." .. tostring(digits or 2) .. "f", value)
end

local function selected_record(player)
  local entity = player and player.valid and player.selected or nil
  if not (entity and entity.valid) then return nil, nil, false end
  local is_target = is_consecration_target and is_consecration_target(entity) or false
  local record = is_target and get_consecration_record and get_consecration_record(entity) or nil
  return entity, record, is_target
end

local function recipe_name(recipe)
  if not recipe then return "nil" end
  local ok, name = pcall(function() return recipe.name end)
  if ok and name then return tostring(name) end
  if recipe.prototype then
    ok, name = pcall(function() return recipe.prototype.name end)
    if ok and name then return tostring(name) end
  end
  return tostring(recipe)
end

function M.install()
  if not (commands and commands.add_command) then return true end

  pcall(function() commands.remove_command("tp-detritus-0417") end)
  pcall(function() commands.remove_command("tp-consecration-0417") end)

  local function report(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    if not (player and player.valid) then return end
    local entity, record, is_target = selected_record(player)
    if not (entity and entity.valid) then
      player.print("[tp-detritus-0417] Select a machine, vehicle, or sanctified entity.")
      return
    end

    local recipe = get_current_recipe and get_current_recipe(entity) or nil
    local progress = get_current_crafting_progress and get_current_crafting_progress(entity) or nil
    local products_finished = get_current_products_finished and get_current_products_finished(entity) or nil
    local output_sensor_total = tech_priests_0453_output_inventory_recipe_total and tech_priests_0453_output_inventory_recipe_total(entity, recipe) or nil
    local has_slot = recipe and recipe_accepts_machine_detritus_output and recipe_accepts_machine_detritus_output(recipe) or false
    local output_inventory = get_machine_output_inventory and get_machine_output_inventory(entity) or nil
    local can_insert = false
    if output_inventory and make_item_stack_identification then
      local stack = make_item_stack_identification(MECHANICAL_DETRITUS_NAME or "mechanical-detritus", 1, get_entity_quality_name and get_entity_quality_name(entity) or nil)
      local ok, result = pcall(function() return output_inventory.can_insert(stack) end)
      can_insert = ok and result or false
    end

    local entity_type = nil
    pcall(function() entity_type = entity.type end)
    local machine_id = record and tech_priests_0446_format_machine_id and tech_priests_0446_format_machine_id(record) or "untracked"
    player.print("[tp-detritus-0417] selected=" .. safe_tostring(entity.name) .. " type=" .. safe_tostring(entity_type) .. " target=" .. safe_tostring(is_target) .. " machine=" .. safe_tostring(machine_id) .. " recipe=" .. recipe_name(recipe))
    player.print("  products_finished=" .. safe_tostring(products_finished) .. " output_total=" .. safe_tostring(output_sensor_total) .. " progress=" .. safe_tostring(progress) .. " sensor=" .. safe_tostring(record and record.last_operation_sensor_0446 or "n/a") .. " detritus_slot=" .. safe_tostring(has_slot) .. " output_inv=" .. safe_tostring(output_inventory ~= nil) .. " can_insert_detritus=" .. safe_tostring(can_insert))

    if not record then
      player.print("  no consecration record; decay/waste/max-cap damage cannot run for this entity.")
      return
    end

    local base_max = get_base_sanctification_max and get_base_sanctification_max(entity.force) or 100
    local current = tonumber(record.sanctification) or 0
    local max_value = tonumber(record.max_sanctification) or base_max
    local base_ratio = base_max > 0 and (current / base_max) or 0
    local current_ratio = max_value > 0 and (current / max_value) or 0
    local waste_chance = get_waste_chance_from_ratio and get_waste_chance_from_ratio(get_sanctification_ratio(record)) or 0

    player.print("  sanctity=" .. fmt_number(current, 2) .. "/" .. fmt_number(max_value, 2) .. " base=" .. fmt_number(base_max, 2) .. " base_ratio=" .. fmt_number(base_ratio * 100, 1) .. "% current_ratio=" .. fmt_number(current_ratio * 100, 1) .. "%")
    player.print("  completed_seen=" .. safe_tostring(record.completed_operations_seen_0417 or record.completed_operations_seen_0413 or 0) .. " last_decay_tick=" .. safe_tostring(record.last_sanctification_decay_tick_0417 or record.last_sanctification_decay_tick_0413 or "never") .. " last_decay=" .. fmt_number(record.last_operation_decay_amount_0417, 3))
    player.print("  last_before=" .. fmt_number(record.last_operation_sanctity_before_0417, 2) .. " last_after=" .. fmt_number(record.last_operation_sanctity_after_0417, 2) .. " computed_waste_chance=" .. fmt_number(waste_chance * 100, 1) .. "%")
    player.print("  detritus_expected=" .. fmt_number(record.last_detritus_expected_0417, 3) .. " roll=" .. safe_tostring(record.last_detritus_roll_0417) .. " inserted=" .. safe_tostring(record.last_detritus_inserted_0417) .. " remaining=" .. safe_tostring(record.last_detritus_remaining_0417))
    player.print("  detritus_last_slot=" .. safe_tostring(record.last_detritus_recipe_slot_0417) .. " last_can_insert=" .. safe_tostring(record.last_detritus_can_insert_0417) .. " blocked=" .. safe_tostring(record.last_detritus_blocked_reason_0417 or "none"))
    player.print("  max-cap threshold=" .. safe_tostring(get_max_sanctification_degradation_config and select(1, get_max_sanctification_degradation_config()) or "n/a") .. " min_cap=" .. safe_tostring(get_min_degraded_sanctification_max and get_min_degraded_sanctification_max() or "n/a"))
    player.print("  label_last_refresh=" .. safe_tostring(record.last_sanctification_label_refresh_tick_0446 or "never") .. " label_error=" .. safe_tostring(record.last_sanctification_label_error_0446 or "none") .. " last_scan_tick=" .. safe_tostring(record.last_sensor_service_tick_0446 or "never"))
    player.print("  output_sensor_last=" .. safe_tostring(record.last_output_inventory_total_0453 or "nil") .. " output_seen=" .. safe_tostring(record.last_output_inventory_total_seen_0453 or "nil") .. " operation_debug=" .. safe_tostring(record.consecration_operation_debug_0453 and record.consecration_operation_debug_0453.operations or 0))
  end

  commands.add_command("tp-detritus-0417", "Tech Priests: inspect selected machine detritus/decay/max-sanctity wiring.", report)
  commands.add_command("tp-consecration-0417", "Tech Priests: alias for /tp-detritus-0417 consecration pointer audit.", report)

  pcall(function() commands.remove_command("tp-consecration-0446") end)
  commands.add_command("tp-consecration-0446", "Tech Priests: consecration tracker audit. Use 'rescan' or 'force-op' on selected machine.", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    if not (player and player.valid) then return end
    ensure_storage()
    local parameter = tostring(event.parameter or "")
    if parameter == "rescan" then
      local registered = 0
      local scanned = 0
      if scan_existing_consecration_targets then
        local ok, reg, scan = pcall(scan_existing_consecration_targets)
        if ok then
          registered = tonumber(reg or 0) or 0
          scanned = tonumber(scan or 0) or 0
        end
      end
      local last = storage.tech_priests.consecration.last_scan_0446 or {}
      player.print("[tp-consecration-0446] rescan complete: registered=" .. safe_tostring(registered) .. " scanned=" .. safe_tostring(scanned or last.scanned or "?"))
    elseif parameter == "force-op" or parameter == "force-operation" then
      local entity, record, is_target = selected_record(player)
      if record and apply_completed_sanctification_operation then
        local recipe = get_current_recipe and get_current_recipe(entity) or nil
        local ok, changed = pcall(apply_completed_sanctification_operation, record, recipe)
        if ok and changed then
          if draw_sanctification_label then pcall(draw_sanctification_label, record) end
          if update_sanctification_overlay then pcall(update_sanctification_overlay, record, true) end
          player.print("[tp-consecration-0446] forced one synthetic completed operation for " .. safe_tostring(tech_priests_0446_format_machine_id and tech_priests_0446_format_machine_id(record) or entity.name) .. ".")
        else
          player.print("[tp-consecration-0446] force-op failed: " .. safe_tostring(changed))
        end
      else
        player.print("[tp-consecration-0446] force-op requires a selected tracked machine. target=" .. safe_tostring(is_target))
      end
    end

    local count = 0
    local active = 0
    local supported = { products_finished = 0, crafting_progress = 0, ["distance-or-unsupported"] = 0, ["not-yet-serviced"] = 0 }
    for _, record in pairs(storage.tech_priests.consecration.machines or {}) do
      count = count + 1
      if record and record.entity and record.entity.valid then active = active + 1 end
      local sensor = record and record.last_operation_sensor_0446 or "not-yet-serviced"
      supported[sensor] = (supported[sensor] or 0) + 1
    end
    local last = storage.tech_priests.consecration.last_scan_0446 or {}
    player.print("[tp-consecration-0446] tracked=" .. count .. " active=" .. active .. " last_scan_tick=" .. safe_tostring(last.tick or "never") .. " scanned=" .. safe_tostring(last.scanned or "?") .. " registered=" .. safe_tostring(last.registered or "?"))
    player.print("  sensors products_finished=" .. safe_tostring(supported.products_finished or 0) .. " crafting_progress=" .. safe_tostring(supported.crafting_progress or 0) .. " unsupported/distance=" .. safe_tostring(supported["distance-or-unsupported"] or 0) .. " not-yet-serviced=" .. safe_tostring(supported["not-yet-serviced"] or 0))
    report(event)
  end)

  return true
end

return M
