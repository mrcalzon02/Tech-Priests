-- Tech Priests 0.1.446 consecration runtime bridge.
-- Purpose: reassert machine-spirit tracking after the 0.1.438 split and later
-- direct event-wrapper layers. This module does not change sanctification balance;
-- it makes registration/scanning/visible bar refresh auditable and resilient.

local M = { name = "scripts.core.consecration.runtime_bridge", version = "0.1.452" }

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

local function remove_entity(event)
  local entity = event and event.entity or nil
  if entity and entity.valid and remove_consecration_target then
    pcall(remove_consecration_target, entity)
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
  if registry and registry.on_event and defines and defines.events then
    registry.on_event({
      defines.events.on_built_entity,
      defines.events.on_robot_built_entity,
      defines.events.script_raised_built,
      defines.events.script_raised_revive
    }, register_entity, nil, { owner = "consecration-runtime-bridge", category = "consecration", priority = "front" })

    registry.on_event({
      defines.events.on_entity_died,
      defines.events.on_pre_player_mined_item,
      defines.events.on_robot_pre_mined,
      defines.events.script_raised_destroy
    }, remove_entity, nil, { owner = "consecration-runtime-bridge", category = "consecration", priority = "front" })

    registry.on_nth_tick(89, service_scan, { owner = "consecration-runtime-bridge", category = "consecration" })
  elseif script and defines and defines.events then
    -- Fallback only.  The registry path is preferred so this does not fight the
    -- event switchboard in normal builds.
    script.on_nth_tick(89, service_scan)
  end

  return true
end

return M
