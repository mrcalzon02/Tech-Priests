-- Tech Priests 0.1.446 consecration runtime bridge.
-- Purpose: reassert machine-spirit tracking after the 0.1.438 split and later
-- direct event-wrapper layers. This module does not change sanctification balance;
-- it makes registration/scanning/visible bar refresh auditable and resilient.

local M = { name = "scripts.core.consecration.runtime_bridge", version = "0.1.452" }
local Doctrine = require("scripts.core.consecration.doctrine_effects")
local CloneCondition = require("scripts.core.consecration.clone_condition")

local function safe_entity_from_built_event(event)
  if not event then return nil end
  return event.entity or event.created_entity or event.destination
end

local function register_entity(event)
  local entity = safe_entity_from_built_event(event)
  if entity and entity.valid and register_consecration_target then
    pcall(register_consecration_target, entity)
    if is_consecration_target and is_consecration_target(entity) then
      local record = get_consecration_record and get_consecration_record(entity) or nil
      if record and tech_priests_0446_refresh_sanctification_label_if_due then
        pcall(tech_priests_0446_refresh_sanctification_label_if_due, record, true)
      elseif record and draw_sanctification_label then
        pcall(draw_sanctification_label, record)
      end
    end
  end
end

-- Factorio clone creation does not necessarily raise an ordinary built event.
-- Register its new unit immediately; carry only previously tracked physical
-- wear. Neither source state nor independently issued machine ID is copied.
local function register_cloned_entity(event)
  local source = event and event.source
  local destination = event and event.destination
  if not (source and source.valid and destination and destination.valid
    and source.unit_number and destination.unit_number
    and register_consecration_target) then return end
  local machines = storage and storage.tech_priests and storage.tech_priests.consecration
    and storage.tech_priests.consecration.machines
  local source_record = machines and machines[source.unit_number] or nil
  local destination_existed = machines and machines[destination.unit_number] ~= nil or false
  local ok = pcall(register_consecration_target, destination)
  if not ok or not (is_consecration_target and is_consecration_target(destination)) then return end
  local record = get_consecration_record and get_consecration_record(destination) or nil
  if not record then return end
  if not destination_existed and source_record then
    local transferred = CloneCondition.transfer(source_record, record, source, destination)
    if transferred and clamp_machine_sanctification then
      pcall(clamp_machine_sanctification, record)
    end
  end
  if tech_priests_0446_refresh_sanctification_label_if_due then
    pcall(tech_priests_0446_refresh_sanctification_label_if_due, record, true)
  elseif draw_sanctification_label then
    pcall(draw_sanctification_label, record)
  end
end

local function remove_entity(event)
  local entity = event and event.entity or nil
  if entity and entity.valid and remove_consecration_target then
    pcall(remove_consecration_target, entity)
  end
end

-- Direct player inventory actions identify the exact machine in Factorio 2.1.
-- Never scan a force/surface or register the machine merely to refresh modules.
-- Cursor edits are also observed on closing the entity GUI; robot/script edits
-- remain covered by the existing 60-tick on-demand doctrine snapshot.
local function refresh_changed_modules(event)
  local entity = event and event.entity
  if not (entity and entity.valid and entity.unit_number) then return end
  local tp = storage and storage.tech_priests
  local consecration = tp and tp.consecration
  local record = consecration and consecration.machines and consecration.machines[entity.unit_number]
  if not record then return end
  local previous = record.machine_spirit_module_snapshot
  Doctrine.invalidate(record)
  local updated = Doctrine.snapshot(record)
  if not Doctrine.snapshot_changed(previous, updated) then return end
  if tech_priests_0446_refresh_sanctification_label_if_due then
    pcall(tech_priests_0446_refresh_sanctification_label_if_due, record, true)
  elseif draw_sanctification_label then
    pcall(draw_sanctification_label, record)
  end
end

local function service_scan()
  if not (ensure_storage and storage and game) then return end
  ensure_storage()
  local consecration = storage.tech_priests.consecration
  if game.tick < (consecration.next_bridge_scan_0446 or 0) then return end
  consecration.next_bridge_scan_0446 = game.tick + 600
  if scan_existing_consecration_targets then
    local ok, registered, scanned = pcall(scan_existing_consecration_targets)
    consecration.last_bridge_scan_debug_0452 = { tick = game.tick, ok = ok, registered = registered, scanned = scanned }
    if ok and log and (consecration.debug_log_next_0452 == nil or game.tick >= consecration.debug_log_next_0452) then
      consecration.debug_log_next_0452 = game.tick + 3600
      log("[Tech-Priests 0.1.452 consecration] bridge scan registered=" .. tostring(registered) .. " scanned=" .. tostring(scanned))
    end
  end
end

function M.install()
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then
    local ok, found = pcall(require, "scripts.core.runtime_event_registry")
    if ok then registry = found end
  end
  if not (registry and registry.on_event and registry.on_nth_tick and defines and defines.events) then
    if log then log("[Tech-Priests 0.1.452 consecration] runtime bridge not installed: runtime event registry unavailable") end
    return false
  end

  local built = registry.on_event({
    defines.events.on_built_entity,
    defines.events.on_robot_built_entity,
    defines.events.script_raised_built,
    defines.events.script_raised_revive
  }, register_entity, nil, {
    owner = "consecration-runtime-bridge",
    route = "register-built-entity",
    category = "consecration",
    priority = "front"
  })

  local cloned = registry.on_event({
    defines.events.on_entity_cloned
  }, register_cloned_entity, nil, {
    owner = "consecration-runtime-bridge",
    route = "register-native-clone",
    category = "consecration",
    priority = "front"
  })

  local removed = registry.on_event({
    defines.events.on_entity_died,
    defines.events.on_pre_player_mined_item,
    defines.events.on_robot_pre_mined,
    defines.events.script_raised_destroy
  }, remove_entity, nil, {
    owner = "consecration-runtime-bridge",
    route = "remove-destroyed-entity",
    category = "consecration",
    priority = "front"
  })

  local module_changes = registry.on_event({
    defines.events.on_player_fast_transferred,
    defines.events.on_gui_closed
  }, refresh_changed_modules, nil, {
    owner = "consecration-runtime-bridge",
    route = "refresh-machine-modules-on-player-interaction",
    category = "consecration",
    priority = "front"
  })

  local scan = registry.on_nth_tick(89, service_scan, {
    owner = "consecration-runtime-bridge",
    route = "periodic-target-scan",
    category = "consecration"
  })
  if not (built and cloned and removed and module_changes and scan) then
    if log then log("[Tech-Priests 0.1.452 consecration] runtime bridge not installed: canonical route registration failed") end
    return false
  end
  return true
end

return M
