-- Tech Priests 0.1.347 consecration modularization pass 1.
-- Extracted from control.lua to isolate machine-spirit state logic.

function set_machine_waste_jam_status(entity)
  set_machine_ritual_status(entity, {
    { "tech-priests-consecration.status-seized" },
    { "tech-priests-consecration.status-cooling-off" },
    { "tech-priests-consecration.status-resetting" }
  }, get_nonoperating_status_diode())
end

function get_sanctification_ratio(record)
  if not record then return MINIMUM_SANCTIFICATION_EFFICIENCY end
  local max_value = record.max_sanctification or get_base_sanctification_max()
  if max_value <= 0 then return MINIMUM_SANCTIFICATION_EFFICIENCY end
  return math.max(MINIMUM_SANCTIFICATION_EFFICIENCY, math.min(1.0, (record.sanctification or 0) / max_value))
end

TECH_PRIESTS_BASE_DETRITUS_CHANCE_0423 = TECH_PRIESTS_BASE_DETRITUS_CHANCE_0423 or 0.015

function get_waste_chance_from_ratio(ratio)
  ratio = math.max(MINIMUM_SANCTIFICATION_EFFICIENCY, math.min(1.0, ratio or 1.0))

  -- 0.1.423: even a clean machine can occasionally shed filings, carbonized
  -- lubricant, ritual grit, and other tiny mechanical sins.  Low sanctity still
  -- ramps toward the old one-to-one contamination doctrine, but a perfect
  -- machine is no longer a guaranteed zero-Detritus machine forever.
  local base_chance = math.max(0, math.min(0.10, tonumber(TECH_PRIESTS_BASE_DETRITUS_CHANCE_0423) or 0.015))
  local dirty_span = math.max(0.001, 1.0 - MINIMUM_SANCTIFICATION_EFFICIENCY)
  local dirty_chance = math.max(0, math.min(1, (1.0 - ratio) / dirty_span))
  return math.max(0, math.min(1, base_chance + ((1.0 - base_chance) * dirty_chance)))
end

normalise_consecration_record = function(record)
  if not record then return end

  local force = record.entity and record.entity.valid and record.entity.force or nil
  local base_max = get_base_sanctification_max(force)
  local base_start = get_base_sanctification_start(force)
  local old_max = tonumber(record.max_sanctification) or base_max
  local old_value = tonumber(record.sanctification) or base_start

  -- One-time safety migration for the early 50-point prototype. After that,
  -- keep degraded maximums intact; do not silently heal a fouled machine back
  -- to the current researched cap just because the record was normalised.
  if not record.legacy_50_cap_migrated and old_max > 0 and old_max <= 50 and old_value <= old_max then
    local filled = old_value / old_max
    old_max = base_max
    old_value = filled * base_max
    record.legacy_50_cap_migrated = true
  end

  record.max_sanctification = math.max(get_min_degraded_sanctification_max(), math.min(base_max, old_max))

  local minimum_value = math.max(0, record.max_sanctification * get_minimum_sanctification_value_fraction())
  record.sanctification = math.max(minimum_value, math.min(record.max_sanctification, old_value))
end

function clamp_machine_sanctification(record)
  normalise_consecration_record(record)
end

function get_machine_output_inventory(entity)
  if not (entity and entity.valid) then return nil end
  local ok, inventory = pcall(function()
    return entity.get_inventory(defines.inventory.assembling_machine_output)
  end)
  if ok then return inventory end
  return nil
end

function get_current_recipe(entity)
  if not (entity and entity.valid) then return nil end
  local ok, recipe = pcall(function() return entity.get_recipe() end)
  if ok and recipe then return recipe end
  -- Factorio 2.x and some modded machine wrappers may expose the current recipe
  -- through a property rather than get_recipe().  Keep this protected; unsupported
  -- entities should simply report nil and remain tracked without operation waste.
  ok, recipe = pcall(function() return entity.recipe end)
  if ok and recipe then return recipe end
  return nil
end

function product_expected_amount(product)
  if type(product) ~= "table" then return 0 end
  if product.type and product.type ~= "item" then return 0 end
  local amount = product.amount
  if not amount and product.amount_min and product.amount_max then
    amount = (product.amount_min + product.amount_max) / 2
  end
  amount = amount or 1
  return amount * (product.probability or 1)
end

function get_recipe_item_output_units(recipe)
  if not recipe then return 1 end
  local products = nil
  pcall(function() products = recipe.products end)
  if not products and recipe.prototype then
    pcall(function() products = recipe.prototype.products end)
  end
  if not products then return 1 end

  local total = 0
  for _, product in pairs(products) do
    total = total + product_expected_amount(product)
  end
  return math.max(1, total)
end

function recipe_has_mechanical_detritus_output(recipe)
  if not recipe then return false end

  local products = nil
  pcall(function() products = recipe.products end)
  if not products and recipe.prototype then
    pcall(function() products = recipe.prototype.products end)
  end
  if type(products) ~= "table" then return false end

  for _, product in pairs(products) do
    local name = nil
    if type(product) == "table" then
      name = product.name or product[1]
    elseif type(product) == "string" then
      name = product
    end
    if name == MECHANICAL_DETRITUS_NAME then
      return true
    end
  end

  return false
end

function roll_count_from_expected(expected)
  if expected <= 0 then return 0 end
  local whole = math.floor(expected)
  local fraction = expected - whole
  if fraction > 0 and math.random() < fraction then
    whole = whole + 1
  end
  return whole
end

machine_has_waste_room = function(entity, count)
  if not (entity and entity.valid) then return false end
  local inventory = get_machine_output_inventory(entity)
  if not inventory then return false end

  local stack = make_item_stack_identification(MECHANICAL_DETRITUS_NAME, count or 1, get_entity_quality_name(entity))
  local ok, can_insert = pcall(function() return inventory.can_insert(stack) end)
  return ok and can_insert
end

update_waste_jam_state = function(record)
  if not (record and record.entity and record.entity.valid) then return end
  local entity = record.entity

  -- Old prototype builds used disabled_by_script to enforce waste jams, which
  -- made the GUI report the ugly engine text "Disabled by script." The jam is
  -- now enforced by the assembler output inventory itself: Mechanical Detritus
  -- has a tiny stack size, and once the output cannot accept another piece, the
  -- assembler naturally stops as output-blocked. Clear the old script-disable
  -- flag for migrated saves and keep only the custom/status flavor layer.
  if entity.disabled_by_script then
    pcall(function() entity.disabled_by_script = false end)
  end

  if record.waste_jammed then
    if machine_has_waste_room(entity, 1) then
      record.waste_jammed = false
      clear_machine_custom_status(entity)
      if entity.active == false then entity.active = true end
    else
      set_machine_waste_jam_status(entity)
    end
  end
end

function set_machine_waste_jammed(record)
  if not (record and record.entity and record.entity.valid) then return end
  record.waste_jammed = true
  -- Do not set disabled_by_script here. Let the filled output inventory be the
  -- actual stoppage condition so the base GUI no longer says Disabled by script.
  pcall(function() record.entity.disabled_by_script = false end)
  set_machine_waste_jam_status(record.entity)
end


function spill_mechanical_detritus_from_machine(entity, count)
  if count <= 0 or not (entity and entity.valid and entity.surface) then return 0 end
  local stack = make_item_stack_identification(MECHANICAL_DETRITUS_NAME, count, get_entity_quality_name(entity))
  local spilled = 0
  local ok = pcall(function()
    local spilled_entities = entity.surface.spill_item_stack{
      position = entity.position,
      stack = stack,
      enable_looted = true,
      force = entity.force,
      allow_belts = false
    }
    if type(spilled_entities) == "table" then
      for _, item_entity in pairs(spilled_entities) do
        if item_entity and item_entity.valid and item_entity.stack and item_entity.stack.valid_for_read then
          spilled = spilled + (item_entity.stack.count or 0)
        end
      end
    else
      spilled = count
    end
  end)
  if ok then return spilled end

  ok = pcall(function()
    entity.surface.spill_item_stack(entity.position, stack, true, entity.force, false)
    spilled = count
  end)
  if ok then return spilled end
  return 0
end

function recipe_accepts_machine_detritus_output(recipe)
  return recipe_has_mechanical_detritus_output(recipe)
end

function add_mechanical_detritus(record, count, allow_spill_fallback)
  if count <= 0 or not (record and record.entity and record.entity.valid) then return true end

  local entity = record.entity
  local stack = make_item_stack_identification(MECHANICAL_DETRITUS_NAME, count, get_entity_quality_name(entity))
  local remaining = count
  local inventory = get_machine_output_inventory(entity)

  -- Mechanical Detritus is a machine-output contamination effect. Do not ever
  -- fall back to player inventories or generic inventories here; the only valid
  -- insertion target is the crafting machine's output inventory. The hidden
  -- probability-0 product slot on recipes exists specifically to make this
  -- output inventory accept Detritus and clog naturally.
  record.last_detritus_requested_0417 = count
  record.last_detritus_inserted_0417 = 0
  record.last_detritus_remaining_0417 = count
  record.last_detritus_has_output_inventory_0417 = inventory ~= nil

  if inventory then
    local ok_can, can_insert = pcall(function() return inventory.can_insert(stack) end)
    record.last_detritus_can_insert_0417 = ok_can and can_insert or false
    local ok, inserted = pcall(function() return inventory.insert(stack) end)
    if ok then
      inserted = inserted or 0
      record.last_detritus_inserted_0417 = inserted
      record.total_detritus_inserted_0422 = (record.total_detritus_inserted_0422 or 0) + inserted
      remaining = remaining - inserted
    else
      record.last_detritus_insert_error_0417 = tostring(inserted)
    end
  else
    record.last_detritus_can_insert_0417 = false
  end

  record.last_detritus_remaining_0417 = remaining

  -- Legacy compatibility: keep the parameter accepted, but do not spill for
  -- normal waste generation. If a recipe cannot accept Mechanical Detritus as a
  -- machine output, the caller should skip generation rather than dumping trash
  -- into the world or the player's inventory.
  if remaining > 0 and allow_spill_fallback == "explicit-spill" then
    local spilled = spill_mechanical_detritus_from_machine(entity, remaining)
    record.total_detritus_spilled_0422 = (record.total_detritus_spilled_0422 or 0) + (spilled or 0)
    remaining = math.max(0, remaining - (spilled or 0))
  end

  if remaining > 0 then
    set_machine_waste_jammed(record)
    return false
  end

  return true
end


return { name = 'scripts.core.consecration.detritus', version = '0.1.446' }
