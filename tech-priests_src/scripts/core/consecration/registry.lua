-- Tech Priests 0.1.347 consecration modularization pass 1.
-- Extracted from control.lua to isolate machine-spirit state logic.

local QualityBaseline = require("scripts.core.consecration.quality_baseline")
local CombatRoster = require("shared.combat_roster_catalog")

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
  if not (entity and entity.valid) then return false end
  -- Combat infantry use native car bodies for AAI movement. Their engine type
  -- does not make them machines; exclude the complete roster and every AAI
  -- composite form before the generic vehicle/type and name allowlists.
  if entity.type == "unit" or entity.type == "character" then return true end
  if CombatRoster.for_entity_name(entity.name) then return true end
  return CONSECRATION_EXCLUDED_NAME_SET_0448 and CONSECRATION_EXCLUDED_NAME_SET_0448[entity.name] == true
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
    -- Only newly registered machines receive the quality-based foundation.
    -- Existing records retain their worn condition across scanning and saves.
    local base_start = get_base_sanctification_start(entity.force)
    local base_max = get_base_sanctification_max(entity.force)
    local quality_name = QualityBaseline.entity_quality_name(entity)
    record = {
      entity = entity,
      unit_number = unit,
      sanctification = QualityBaseline.starting_sanctification(base_start, base_max, quality_name),
      max_sanctification = base_max,
      quality_at_initial_consecration = quality_name,
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

local function remove_consecration_record(unit, entity)
  ensure_storage()
  local consecration = storage.tech_priests.consecration
  local record = consecration.machines[unit]
  if record and entity and entity.valid then
    -- active is read-only in 2.1 and also reflects freezing/circuit state.
    -- Restore only the actual script flag captured by our malfunction setter.
    -- Older records only attempted a failing active write, so an unknown
    -- script-disable state belongs to AAI/another owner and must be preserved.
    if record.control_malfunction_until_tick
      and type(record.control_malfunction_original_disabled_by_script) == "boolean" then
      entity.disabled_by_script = record.control_malfunction_original_disabled_by_script
    end
    clear_machine_custom_status(entity)
  end
  consecration.machines[unit] = nil
  local render = consecration.renders[unit]
  if render then
    destroy_render_objects(render)
    consecration.renders[unit] = nil
  end
  clear_sanctification_overlay(unit)
end

function remove_consecration_target(entity)
  if not (entity and entity.unit_number) then return end
  remove_consecration_record(entity.unit_number, entity)
end

function prune_ineligible_consecration_targets()
  ensure_storage()
  for unit, record in pairs(storage.tech_priests.consecration.machines) do
    local entity = record and record.entity
    if not is_consecration_target(entity) then
      remove_consecration_record(unit, entity)
    end
  end
end

function scan_existing_consecration_targets(only_surface, area)
  if _G and _G.tech_priests_compatibility_scan_0626 then
    pcall(_G.tech_priests_compatibility_scan_0626, "consecration-targets",
      only_surface and "event-generated-chunk"
        or rawget(_G, "tech_priests_compatibility_scan_context_0626") or "initial-registry-seed", 1)
  end
  ensure_storage()
  -- Full registration is an initial/configuration/manual recovery operation.
  -- New chunks use the same authority over only their newly generated area.
  if not only_surface then prune_ineligible_consecration_targets() end
  local scanned = 0
  local registered = 0
  local complete = true
  local seen = {}

  local function scan_list(entities)
    for _, entity in pairs(entities or {}) do
      if entity and entity.valid and entity.unit_number and not seen[entity.unit_number] then
        seen[entity.unit_number] = true
        scanned = scanned + 1
        if tech_priests_0448_is_consecration_excluded and tech_priests_0448_is_consecration_excluded(entity) then
          remove_consecration_target(entity)
        elseif is_consecration_target(entity) then
          register_consecration_target(entity)
          registered = registered + 1
        end
      end
    end
  end

  for _, surface in pairs(only_surface and {only_surface} or game.surfaces or {}) do
    if CONSECRATION_TARGET_NAME_LIST and #CONSECRATION_TARGET_NAME_LIST > 0 then
      local ok_names, by_name = pcall(function()
        return surface.find_entities_filtered({ name = CONSECRATION_TARGET_NAME_LIST, area = area })
      end)
      if ok_names then scan_list(by_name) else complete = false end
    end

    for _, target_type in pairs(CONSECRATION_TARGET_TYPE_LIST or {}) do
      local ok_types, by_type = pcall(function()
        return surface.find_entities_filtered({ type = target_type, area = area })
      end)
      if ok_types then scan_list(by_type) else complete = false end
    end
  end

  local consecration = storage.tech_priests.consecration
  local receipt = {
    tick = game and game.tick or 0,
    scanned = scanned,
    registered = registered,
    tracked = not only_surface and table_size and table_size(consecration.machines or {}) or nil,
    complete = complete
  }
  if only_surface then
    consecration.last_area_scan_0446 = receipt
  else
    consecration.last_scan_0446 = receipt
    consecration.discovery_seeded_0446 = complete
  end
  return registered, scanned, complete
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
