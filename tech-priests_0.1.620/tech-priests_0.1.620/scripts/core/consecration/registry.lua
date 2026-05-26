-- Tech Priests 0.1.347 consecration modularization pass 1.
-- Extracted from control.lua to isolate machine-spirit state logic.

CONSECRATION_TARGET_TYPE_SET = CONSECRATION_TARGET_TYPE_SET or {
  ["assembling-machine"] = true,
  ["furnace"] = true,
  ["rocket-silo"] = true,
  ["lab"] = true,
  ["mining-drill"] = true,
  ["boiler"] = true,
  ["generator"] = true,
  ["reactor"] = true,
  ["roboport"] = true,
  ["car"] = true,
  ["spider-vehicle"] = true,
  ["locomotive"] = true
}
CONSECRATION_TARGET_TYPE_LIST = CONSECRATION_TARGET_TYPE_LIST or {
  "assembling-machine", "furnace", "rocket-silo", "lab", "mining-drill",
  "boiler", "generator", "reactor", "roboport", "car", "spider-vehicle", "locomotive"
}

CONSECRATION_EXCLUDED_NAME_SET_0448 = CONSECRATION_EXCLUDED_NAME_SET_0448 or {
  ["tech-priests-emergency-miner"] = true,
  ["tech-priests-emergency-boiler"] = true,
  ["tech-priests-emergency-steam-engine"] = true,
  ["tech-priests-emergency-smelter"] = true,
  ["tech-priests-emergency-assembler"] = true,
  ["tech-priests-emergency-laboratorium"] = true,
  ["tech-priests-emergency-power-grid"] = true,
  ["tech-priests-atmospheric-water-condenser"] = true
}

function tech_priests_0448_is_consecration_excluded(entity)
  return entity and entity.valid and CONSECRATION_EXCLUDED_NAME_SET_0448 and CONSECRATION_EXCLUDED_NAME_SET_0448[entity.name] == true
end

local function safe_entity_type_0446(entity)
  if not (entity and entity.valid) then return nil end
  local ok, value = pcall(function() return entity.type end)
  if ok then return value end
  return nil
end

local function consecration_type_allowed_0446(entity)
  local entity_type = safe_entity_type_0446(entity)
  return entity_type and CONSECRATION_TARGET_TYPE_SET and CONSECRATION_TARGET_TYPE_SET[entity_type] == true
end

is_consecration_target = function(entity)
  if not (entity and entity.valid and entity.unit_number ~= nil) then return false end
  if tech_priests_0448_is_consecration_excluded and tech_priests_0448_is_consecration_excluded(entity) then return false end
  if CONSECRATION_TARGET_NAME_SET and CONSECRATION_TARGET_NAME_SET[entity.name] then return true end
  return consecration_type_allowed_0446(entity)
end

function tech_priests_0446_next_machine_id()
  ensure_storage()
  local consecration = storage.tech_priests.consecration
  consecration.next_machine_id_0446 = tonumber(consecration.next_machine_id_0446 or 1) or 1
  local id = consecration.next_machine_id_0446
  consecration.next_machine_id_0446 = id + 1
  return id
end

function tech_priests_0446_format_machine_id(record)
  local id = record and tonumber(record.machine_id_0446 or record.machine_id) or nil
  if not id then return "TP-M????" end
  return string.format("TP-M%04d", id)
end

get_consecration_record = function(entity)
  if not is_consecration_target(entity) then return nil end
  ensure_storage()
  local unit = entity.unit_number
  local record = storage.tech_priests.consecration.machines[unit]
  if not record then
    record = {
      entity = entity,
      unit_number = unit,
      sanctification = get_base_sanctification_start(entity.force),
      max_sanctification = get_base_sanctification_max(entity.force),
      last_progress = nil,
      machine_id_0446 = tech_priests_0446_next_machine_id(),
      first_registered_tick_0446 = game and game.tick or 0,
      entity_name_0446 = entity.name,
      entity_type_0446 = safe_entity_type_0446(entity),
      unit_number = unit
    }
    record.machine_id = record.machine_id_0446
    storage.tech_priests.consecration.machines[unit] = record
  else
    record.entity = entity
    if not record.machine_id_0446 then
      record.machine_id_0446 = tech_priests_0446_next_machine_id()
    end
    record.machine_id = record.machine_id or record.machine_id_0446
    record.entity_name_0446 = entity.name
    record.entity_type_0446 = safe_entity_type_0446(entity)
    record.unit_number = unit
  end
  normalise_consecration_record(record)
  return record
end

function register_consecration_target(entity)
  if is_consecration_target(entity) then
    get_consecration_record(entity)
  end
end

function remove_consecration_target(entity)
  if not (entity and entity.unit_number) then return end
  clear_machine_custom_status(entity)
  ensure_storage()
  storage.tech_priests.consecration.machines[entity.unit_number] = nil
  local render = storage.tech_priests.consecration.renders[entity.unit_number]
  if render then
    destroy_render_objects(render)
    storage.tech_priests.consecration.renders[entity.unit_number] = nil
  end
  clear_sanctification_overlay(entity.unit_number)
end

function scan_existing_consecration_targets()
  ensure_storage()
  local scanned = 0
  local registered = 0
  local seen = {}

  local function scan_list(entities)
    for _, entity in pairs(entities or {}) do
      if entity and entity.valid and entity.unit_number and not seen[entity.unit_number] then
        seen[entity.unit_number] = true
        scanned = scanned + 1
        if tech_priests_0448_is_consecration_excluded and tech_priests_0448_is_consecration_excluded(entity) then
          if storage.tech_priests and storage.tech_priests.consecration and storage.tech_priests.consecration.machines then
            storage.tech_priests.consecration.machines[entity.unit_number] = nil
          end
          if clear_sanctification_overlay then pcall(clear_sanctification_overlay, entity.unit_number) end
        elseif is_consecration_target(entity) then
          register_consecration_target(entity)
          registered = registered + 1
        end
      end
    end
  end

  for _, surface in pairs(game.surfaces or {}) do
    local ok_names, by_name = pcall(function()
      return surface.find_entities_filtered({ name = CONSECRATION_TARGET_NAME_LIST })
    end)
    if ok_names then scan_list(by_name) end

    for _, target_type in pairs(CONSECRATION_TARGET_TYPE_LIST or {}) do
      local ok_types, by_type = pcall(function()
        return surface.find_entities_filtered({ type = target_type })
      end)
      if ok_types then scan_list(by_type) end
    end
  end

  storage.tech_priests.consecration.last_scan_0446 = {
    tick = game and game.tick or 0,
    scanned = scanned,
    registered = registered,
    tracked = table_size and table_size(storage.tech_priests.consecration.machines or {}) or nil
  }
  return registered, scanned
end

clear_machine_custom_status = function(entity)
  if not (entity and entity.valid) then return end
  pcall(function() entity.custom_status = nil end)
end

function set_machine_ritual_status(entity, labels, diode)
  if not (entity and entity.valid) then return end
  local label = labels[1]
  if #labels > 1 then
    label = labels[((math.floor(game.tick / 90) + (entity.unit_number or 0)) % #labels) + 1]
  end
  pcall(function()
    entity.custom_status = {
      diode = diode or defines.entity_status_diode.red,
      label = label
    }
  end)
end

function get_nonoperating_status_diode()
  if defines and defines.entity_status_diode and defines.entity_status_diode.yellow then
    return defines.entity_status_diode.yellow
  end
  return defines.entity_status_diode.red
end


return { name = 'scripts.core.consecration.registry', version = '0.1.448' }
