-- Auto-split control.lua fragment 006 for Tech Priests 0.1.438.
-- Generated mechanically from 0.1.437 monolithic control.lua.
-- Purpose: reduce Lua main-chunk local/register pressure without deleting behavior.


function tech_priests_start_consecration_priority(pair, radius)
  if not (pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid) then return false end
  radius = radius or (refresh_pair_radius and refresh_pair_radius(pair) or get_station_operating_radius(pair.station))
  if station_has_consecration_item and station_has_consecration_item(pair.station) then
    local target = find_consecration_target_for_station and find_consecration_target_for_station(pair.station, radius, pair.priest) or nil
    if target then
      tech_priests_clear_interruptible_supply_work(pair)
      pair.target = target
      return sanctify_target_with_priest(pair, target) == true
    end
  else
    local target = find_consecration_status_target and find_consecration_status_target(pair.station, radius, pair.priest, false, false) or nil
    if target then
      tech_priests_clear_interruptible_supply_work(pair)
      pair.mode = "missing-consecration-supplies"
      pair.target = target
      if maybe_start_supply_scavenge and maybe_start_supply_scavenge(pair, "consecration", target) then return true end
      return_to_station(pair.priest, pair.station)
      return true
    end
  end
  return false
end

function tech_priests_check_higher_priority_after_scan(pair)
  if not (pair and pair.inventory_scan) then return false end
  if tech_priests_try_interrupt_for_hostiles(pair) then return true end

  local scan = pair.inventory_scan
  local current_kind = scan.request and scan.request.kind or scan.kind
  local radius = refresh_pair_radius and refresh_pair_radius(pair) or (pair.station and pair.station.valid and get_station_operating_radius(pair.station) or 0)

  -- Priority order remains: combat > repair > consecration > logistics errands.
  -- A repair scan should not be interrupted by consecration; an ammo/combat scan
  -- should not be interrupted by ordinary maintenance.
  if current_kind ~= "ammo" and current_kind ~= "repair" then
    if tech_priests_start_repair_priority(pair, radius) then return true end
  end

  if current_kind ~= "ammo" and current_kind ~= "repair" and current_kind ~= "consecration" then
    if tech_priests_start_consecration_priority(pair, radius) then return true end
  end

  return false
end

original_0131_handle_logistic_inventory_scan = handle_logistic_inventory_scan
function handle_logistic_inventory_scan(pair)
  if pair and pair.inventory_scan and pair.inventory_scan.scan_due_tick and game.tick >= pair.inventory_scan.scan_due_tick then
    if tech_priests_check_higher_priority_after_scan(pair) then return true end
  end
  return original_0131_handle_logistic_inventory_scan(pair)
end

original_0131_tick_pair = tick_pair
function tick_pair(pair)
  if tech_priests_try_interrupt_for_hostiles(pair) then return end
  return original_0131_tick_pair(pair)
end


-- 0.1.132 logistics countdown and diagnostics repair pass:
-- * Timed missing-supply states redraw once per second and always show a countdown.
-- * Hidden requester-cache writes are diagnosed and retried through every known request API path.
-- * Optional station overlay shows where logistics breaks: network, cache, request write, readback, stock, cache contents, station space.
LOGISTIC_DEBUG_RENDER_TTL = 75
LOGISTIC_TIMED_STATUS_REFRESH_TICKS = 60

function tech_priests_logistic_item_label(item_name)
  if not item_name or item_name == "" then return "-" end
  return "[item=" .. tostring(item_name) .. "]"
end

function tech_priests_get_force_has_logistic_system(force)
  if not (force and force.valid and force.technologies) then return false end
  local tech = force.technologies["logistic-system"]
  return tech and tech.researched or false
end

function tech_priests_get_active_logistics_remaining(pair)
  if not pair then return nil end
  local due = pair.logistic_frustration_due_tick
  if pair.mode == "logistics-cram-countdown" and pair.logistic_cram_due_tick then due = pair.logistic_cram_due_tick end
  if pair.mode == "logistics-no-network" and pair.logistic_frustration_due_tick then due = pair.logistic_frustration_due_tick end
  if not due then return nil end
  return math.max(0, math.ceil((due - (game and game.tick or 0)) / 60))
end

original_0132_get_priest_status_symbol = get_priest_status_symbol
function get_priest_status_symbol(pair)
  tech_priests_normalize_logistic_frustration_timer(pair)
  local symbol = original_0132_get_priest_status_symbol(pair)
  local remaining = tech_priests_get_active_logistics_remaining(pair)
  if pair and remaining ~= nil then
    local state = classify_priest_visual_state(pair)
    local timed = {
      ["repair-missing-supplies"] = true,
      ["consecrate-missing-supplies"] = true,
      ["ammo-missing-supplies"] = true,
      ["awaiting-logistics"] = true,
      ["logistics-requested"] = true,
      ["logistics-scavenge-countdown"] = true,
      ["logistics-cram-countdown"] = true,
      ["logistics-no-network"] = true
    }
    if timed[state] then
      local text = tostring(symbol or "")
      text = text:gsub("{seconds}", tostring(remaining))
      text = text:gsub("{item}", tostring(pair.logistic_requested_item or ""))
      if not string.find(text, tostring(remaining), 1, true) then
        text = text .. " " .. tostring(remaining)
      end
      if pair.logistic_requested_item and pair.logistic_requested_item ~= "" and not string.find(text, pair.logistic_requested_item, 1, true) then
        text = tech_priests_logistic_item_label(pair.logistic_requested_item) .. " " .. text
      end
      return text
    end
  end
  return symbol
end

function tech_priests_pair_has_timed_logistic_status(pair)
  if not pair then return false end
  if tech_priests_get_active_logistics_remaining(pair) == nil then return false end
  local state = classify_priest_visual_state(pair)
  return state == "repair-missing-supplies"
      or state == "consecrate-missing-supplies"
      or state == "ammo-missing-supplies"
      or state == "awaiting-logistics"
      or state == "logistics-requested"
      or state == "logistics-scavenge-countdown"
      or state == "logistics-cram-countdown"
      or state == "logistics-no-network"
end

original_0132_update_priest_status_bubbles = update_priest_status_bubbles
function update_priest_status_bubbles()
  original_0132_update_priest_status_bubbles()
  ensure_storage()
  for _, pair in pairs(storage.tech_priests.pairs_by_station or {}) do
    if pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid and tech_priests_pair_has_timed_logistic_status(pair) then
      if game.tick >= (pair.next_timed_status_bubble_tick or 0) then
        draw_priest_status_bubble(pair)
        pair.next_timed_status_bubble_tick = game.tick + LOGISTIC_TIMED_STATUS_REFRESH_TICKS
      end
    end
  end
end

function tech_priests_get_request_section_from_requester_point(entity)
  if not (entity and entity.valid) then return nil end
  local ok, point = pcall(function()
    if entity.get_requester_point then return entity.get_requester_point() end
    return nil
  end)
  if not (ok and point) then return nil end
  pcall(function() point.enabled = true end)
  pcall(function() point.trash_not_requested = false end)
  local section = nil
  pcall(function() if point.get_section then section = point.get_section(1) end end)
  if not section then pcall(function() if point.add_section then section = point.add_section() end end) end
  if section then
    pcall(function() section.active = true end)
    pcall(function() section.group = "Tech-Priests Requisition" end)
  end
  return section
end

original_0132_get_or_create_manual_logistic_section = get_or_create_manual_logistic_section
function get_or_create_manual_logistic_section(entity)
  local section = tech_priests_get_request_section_from_requester_point(entity)
  if section then return section end
  return original_0132_get_or_create_manual_logistic_section(entity)
end

function tech_priests_read_request_slot(entity, slot_index)
  if not (entity and entity.valid) then return nil end
  slot_index = slot_index or 1
  local section = get_or_create_manual_logistic_section(entity)
  if section and section.get_slot then
    local ok, slot = pcall(function() return section.get_slot(slot_index) end)
    if ok and slot then return slot end
  end
  local ok, slot = pcall(function()
    if entity.get_request_slot then return entity.get_request_slot(slot_index) end
    return nil
  end)
  if ok then return slot end
  return nil
end

function tech_priests_request_slot_to_item_name(slot)
  if not slot then return nil end
  if type(slot) == "string" then return slot end
  if type(slot) ~= "table" then return nil end
  if slot.name then return slot.name end
  if slot.value then
    if type(slot.value) == "string" then return slot.value end
    if type(slot.value) == "table" then return slot.value.name end
  end
  if slot[1] then
    if type(slot[1]) == "string" then return slot[1] end
    if type(slot[1]) == "table" then return slot[1].name end
  end
  return nil
end

function tech_priests_request_slot_to_count(slot)
  if type(slot) ~= "table" then return nil end
  return slot.min or slot.count or slot.amount or slot[2]
end

original_0132_verify_logistic_request_slot = verify_logistic_request_slot
function verify_logistic_request_slot(entity, slot_index, stack)
  local slot = tech_priests_read_request_slot(entity, slot_index or 1)
  local name = tech_priests_request_slot_to_item_name(slot)
  if name and stack and name == stack.name then return true end
  return original_0132_verify_logistic_request_slot(entity, slot_index, stack)
end

-- TECH-PRIESTS 0.1.431: removed superseded duplicate function tech_priests_set_logistic_request_slot_diagnostics (old lines 7429-7493); next definition begins at old line 7765. No intervening capture/registration/reference was detected by tools/audit_control_deletion_candidates.py.


function tech_priests_update_logistic_debug(pair, fields)
  if not pair then return end
  pair.logistic_debug = pair.logistic_debug or {}
  for k, v in pairs(fields or {}) do pair.logistic_debug[k] = v end
  pair.logistic_debug.tick = game and game.tick or 0
end

-- TECH-PRIESTS 0.1.431: removed superseded duplicate function tech_priests_get_cache_network_present (old lines 7504-7508); next definition begins at old line 7812. No intervening capture/registration/reference was detected by tools/audit_control_deletion_candidates.py.

original_0132_issue_station_logistic_request = issue_station_logistic_request

original_0132_transfer_cache_inventory_to_station = transfer_cache_inventory_to_station
function transfer_cache_inventory_to_station(pair)
  local moved = original_0132_transfer_cache_inventory_to_station(pair)
  if pair and pair.logistic_requested_item then
    local cache_inventory = get_hidden_cache_inventory(pair.logistic_requester)
    local station_inventory = get_station_inventory(pair.station)
    tech_priests_update_logistic_debug(pair, {
      moved = moved,
      cache_count = cache_inventory and cache_inventory.get_item_count(pair.logistic_requested_item) or 0,
      station_count = station_inventory and station_inventory.get_item_count(pair.logistic_requested_item) or 0,
      station_can_insert = station_inventory and station_inventory.can_insert({ name = pair.logistic_requested_item, count = 1 }) or false
    })
  end
  return moved
end

function clear_station_logistic_debug_text(pair)
  ensure_storage()
  storage.tech_priests.logistic_debug_text = storage.tech_priests.logistic_debug_text or {}
  local station_unit = pair and (pair.station_unit or (pair.station and pair.station.valid and pair.station.unit_number))
  if not station_unit then return end
  local obj = storage.tech_priests.logistic_debug_text[station_unit]
  if obj then destroy_render_object(obj) end
  storage.tech_priests.logistic_debug_text[station_unit] = nil
end

function draw_station_logistic_debug_text(pair)
  if not read_global_bool_setting("tech-priests-enable-logistics-debug-overlay", false) then
    clear_station_logistic_debug_text(pair)
    return
  end
  if not (pair and pair.station and pair.station.valid) then return end
  local debug = pair.logistic_debug
  local active = pair.logistic_requested_item or pair.inventory_scan or pair.scavenge or pair.cram or pair.logistic_request_failed
  if not (debug and active) then
    clear_station_logistic_debug_text(pair)
    return
  end
  ensure_storage()
  storage.tech_priests.logistic_debug_text = storage.tech_priests.logistic_debug_text or {}
  clear_station_logistic_debug_text(pair)
  local remaining = tech_priests_get_active_logistics_remaining(pair)
  local parts = {
    "TP-LOG",
    tostring(debug.stage or "?"),
    tech_priests_logistic_item_label(debug.item or pair.logistic_requested_item),
    "t=" .. tostring(remaining or "-"),
    "set=" .. tostring(debug.ok),
    "m=" .. tostring(debug.method or "-"),
    "rd=" .. tostring(debug.read_name or "-"),
    "net=" .. tostring(debug.network_count or "-"),
    "cache=" .. tostring(debug.cache_count or "-"),
    "st=" .. tostring(debug.station_count or "-"),
    "space=" .. tostring(debug.station_can_insert),
    "cnet=" .. tostring(debug.cache_in_network),
    "LS=" .. tostring(debug.has_logistic_system)
  }
  if debug.error then parts[#parts + 1] = "err=" .. tostring(debug.error):sub(1, 28) end
  local text = table.concat(parts, " ")
  local obj = draw_priest_status_text({
    text = text,
    target = { entity = pair.station, offset = { 0, -3.85 } },
    surface = pair.station.surface,
    color = debug.ok and { r = 0.35, g = 1.00, b = 0.45, a = 0.92 } or { r = 1.00, g = 0.25, b = 0.12, a = 0.95 },
    scale = 0.62,
    alignment = "center",
    time_to_live = LOGISTIC_DEBUG_RENDER_TTL
  })
  if obj then storage.tech_priests.logistic_debug_text[pair.station.unit_number] = obj end
end

original_0132_clear_all_runtime_rendering = clear_all_runtime_rendering
function clear_all_runtime_rendering()
  original_0132_clear_all_runtime_rendering()
  if storage and storage.tech_priests then
    storage.tech_priests.logistic_debug_text = {}
  end
end

original_0132_update_priest_status_bubbles_second = update_priest_status_bubbles
function update_priest_status_bubbles()
  original_0132_update_priest_status_bubbles_second()
  ensure_storage()
  for _, pair in pairs(storage.tech_priests.pairs_by_station or {}) do
    draw_station_logistic_debug_text(pair)
  end
end


-- 0.1.133 logistics API repair pass:
-- * Stop probing nonexistent LuaEntity keys such as get_requester_point; Factorio
--   2.x exposes requester behavior through LuaEntity::get_logistic_point().
-- * Select the real requester logistic point, then use LuaLogisticPoint::get_section/add_section.
-- * Keep diagnostics short so the debug overlay shows the actual break point instead of a truncated Lua error.
function tech_priests_short_error(err)
  if not err then return nil end
  local text = tostring(err)
  text = text:gsub("LuaEntity doesn't contain key ", "no-key:")
  text = text:gsub("__tech%-priests__/control%.lua:%d+:%s*", "")
  if #text > 64 then text = text:sub(1, 64) end
  return text
end

function tech_priests_safe_entity_method(entity, method_name, ...)
  if not (entity and entity.valid) then return false, nil, "invalid-entity" end
  local args = { ... }
  local ok, result = pcall(function()
    local method = entity[method_name]
    if type(method) ~= "function" then return nil end
    return method(entity, table.unpack(args))
  end)
  if ok then return true, result, nil end
  return false, nil, tech_priests_short_error(result)
end

function tech_priests_safe_object_method(object, method_name, ...)
  if not object then return false, nil, "nil-object" end
  local args = { ... }
  local ok, result = pcall(function()
    local method = object[method_name]
    if type(method) ~= "function" then return nil end
    return method(object, table.unpack(args))
  end)
  if ok then return true, result, nil end
  return false, nil, tech_priests_short_error(result)
end

function tech_priests_logistic_mode_name(mode)
  if mode == nil then return "nil" end
  if defines and defines.logistic_mode then
    for name, value in pairs(defines.logistic_mode) do
      if value == mode then return name end
    end
  end
  return tostring(mode)
end

function tech_priests_collect_logistic_points(entity)
  local points = {}
  local seen = {}
  local last_error = nil
  local function add_point(point)
    if not point then return end
    if type(point) == "table" and not point.object_name and not point.mode and not point.get_section then
      for _, p in pairs(point) do add_point(p) end
      return
    end
    local ok_valid, valid = pcall(function() return point.valid end)
    if ok_valid and valid == false then return end
    local key = tostring(point)
    if not seen[key] then
      seen[key] = true
      points[#points + 1] = point
    end
  end

  -- First try every known logistic member index. This is the most reliable 2.x path.
  if defines and defines.logistic_member_index then
    for _, idx in pairs(defines.logistic_member_index) do
      local ok, result, err = tech_priests_safe_entity_method(entity, "get_logistic_point", idx)
      if ok then add_point(result) else last_error = err end
    end
  end

  -- Then try the no-index call, which may return all points as an array.
  local ok, result, err = tech_priests_safe_entity_method(entity, "get_logistic_point")
  if ok then add_point(result) else last_error = err end

  return points, last_error
end

function tech_priests_select_requester_logistic_point(entity)
  local points, err = tech_priests_collect_logistic_points(entity)
  local fallback = nil
  local requester_mode = defines and defines.logistic_mode and defines.logistic_mode.requester
  for _, point in pairs(points or {}) do
    local ok_mode, mode = pcall(function() return point.mode end)
    local ok_sections, sections_count = pcall(function() return point.sections_count end)
    if ok_mode and requester_mode and mode == requester_mode then
      return point, nil, tech_priests_logistic_mode_name(mode)
    end
    if ok_mode and tostring(mode) == "requester" then
      return point, nil, "requester"
    end
    if not fallback and (ok_sections or ok_mode) then
      fallback = point
    end
  end
  if fallback then
    local ok_mode, mode = pcall(function() return fallback.mode end)
    return fallback, nil, ok_mode and tech_priests_logistic_mode_name(mode) or "fallback"
  end
  return nil, err or "no-logistic-point", "none"
end

function tech_priests_get_requester_manual_section(entity)
  local point, err, mode_name = tech_priests_select_requester_logistic_point(entity)
  if not point then return nil, err or "no-requester-point", mode_name end

  pcall(function() point.enabled = true end)
  pcall(function() point.trash_not_requested = false end)

  local section = nil
  local ok, result, get_err = tech_priests_safe_object_method(point, "get_section", 1)
  if ok then section = result else err = get_err end
  if not section then
    ok, result, get_err = tech_priests_safe_object_method(point, "add_section", "Tech-Priests Requisition")
    if ok then section = result else err = get_err end
  end
  if not section then return nil, err or "no-section", mode_name end

  pcall(function() section.active = true end)
  pcall(function() section.group = "Tech-Priests Requisition" end)
  pcall(function() section.multiplier = 1 end)
  return section, nil, mode_name
end

function get_or_create_manual_logistic_section(entity)
  local section = tech_priests_get_requester_manual_section(entity)
  if section then return section end
  -- Do not fall back to the old get_requester_point probing path; on this
  -- runtime it reports noisy "LuaEntity doesn't contain key" errors and never
  -- creates a requester section for the hidden cache.
  return nil
end

function clear_logistic_request_slots(entity)
  if not (entity and entity.valid) then return false end
  local section = get_or_create_manual_logistic_section(entity)
  local any = false
  if section then
    for i = 1, LOGISTIC_REQUESTER_SLOT_COUNT do
      local ok = pcall(function()
        if section.clear_slot then section.clear_slot(i) end
      end)
      any = any or ok
    end
  end
  return any
end

function tech_priests_read_request_slot(entity, slot_index)
  if not (entity and entity.valid) then return nil end
  slot_index = slot_index or 1
  local section = get_or_create_manual_logistic_section(entity)
  if section then
    local ok, slot = pcall(function() return section.get_slot(slot_index) end)
    if ok then return slot end
  end
  return nil
end

-- TECH-PRIESTS 0.1.431: removed superseded duplicate function tech_priests_set_logistic_request_slot_diagnostics (old lines 7765-7808); next definition begins at old line 7903. No intervening capture/registration/reference was detected by tools/audit_control_deletion_candidates.py.


function tech_priests_get_cache_network_present(cache)
  if not (cache and cache.valid) then return false end
  local ok, network = pcall(function() return cache.logistic_network end)
  if ok and network then return true end
  if cache.surface and cache.force then
    ok, network = pcall(function() return cache.surface.find_logistic_network_by_position(cache.position, cache.force) end)
    if ok and network then return true end
  end
  return false
end

-- Keep the overlay readable enough for live debugging.
function draw_station_logistic_debug_text(pair)
  if not read_global_bool_setting("tech-priests-enable-logistics-debug-overlay", false) then
    clear_station_logistic_debug_text(pair)
    return
  end
  if not (pair and pair.station and pair.station.valid) then return end
  local debug = pair.logistic_debug
  local active = debug and game.tick <= (debug.tick or 0) + LOGISTIC_DEBUG_RENDER_TTL
  if not (debug and active) then
    clear_station_logistic_debug_text(pair)
    return
  end

  storage.tech_priests.logistic_debug_text = storage.tech_priests.logistic_debug_text or {}
  clear_station_logistic_debug_text(pair)

  local err = debug.error and (" err=" .. tostring(debug.error)) or ""
  local parts = {
    "TP-LOG " .. tostring(debug.stage or "?") .. " " .. tech_priests_logistic_item_label(debug.item or pair.logistic_requested_item),
    "set=" .. tostring(debug.ok) .. " m=" .. tostring(debug.method or "-") .. " mode=" .. tostring(debug.point_mode or "-"),
    "rd=" .. tostring(debug.read_name or "-") .. " net=" .. tostring(debug.network_count or "-") .. " cache=" .. tostring(debug.cache_count or "-") .. " st=" .. tostring(debug.station_count or "-"),
    "space=" .. tostring(debug.station_can_insert) .. " cnet=" .. tostring(debug.cache_in_network) .. " LS=" .. tostring(debug.has_logistic_system) .. err
  }

  local obj = rendering.draw_text({
    text = table.concat(parts, "\n"),
    surface = pair.station.surface,
    target = pair.station,
    target_offset = {0, -4.15},
    color = debug.ok and { r = 0.35, g = 1.00, b = 0.45, a = 0.92 } or { r = 1.00, g = 0.25, b = 0.12, a = 0.95 },
    alignment = "center",
    vertical_alignment = "bottom",
    scale = 0.66,
    use_rich_text = true,
    players = nil,
    time_to_live = LOGISTIC_DEBUG_RENDER_TTL
  })
  if obj then storage.tech_priests.logistic_debug_text[pair.station.unit_number] = obj end
end

-- Override the 0.1.132 request issuer so diagnostics include the corrected
-- requester point mode and no longer leak nonexistent-key errors.

-- 0.1.134 logistics API call fix (superseded by 0.1.135 overrides below):
-- Factorio LuaObject methods are already bound method closures. Calling a method
-- fetched from a LuaObject as method(object, ...) passes one argument too many
-- and produces errors such as: "Arguments count error for method: Expected 0 or
-- 1 arguments". This broke requester-cache section creation and prevented bots
-- from seeing any valid request. Override the helper wrappers so they call
-- fetched methods directly.
function tech_priests_safe_entity_method(entity, method_name, ...)
  if not (entity and entity.valid) then return false, nil, "invalid-entity" end
  local args = { ... }
  local ok, result = pcall(function()
    local method = entity[method_name]
    if type(method) ~= "function" then return nil end
    return method(table.unpack(args))
  end)
  if ok then return true, result, nil end
  return false, nil, tech_priests_short_error(result)
end

function tech_priests_safe_object_method(object, method_name, ...)
  if not object then return false, nil, "nil-object" end
  local args = { ... }
  local ok, result = pcall(function()
    local method = object[method_name]
    if type(method) ~= "function" then return nil end
    return method(table.unpack(args))
  end)
  if ok then return true, result, nil end
  return false, nil, tech_priests_short_error(result)
end

-- Force an explicit quality in request filters. Some Factorio 2.x builds reject
-- non-zero requests with non-trivial/implicit item filter conditions unless the
-- item filter specifies quality. Keep this override after the fixed wrappers so
-- the debug overlay reports whether a real request slot was written.
function tech_priests_set_logistic_request_slot_diagnostics(entity, slot_index, stack)
  local diag = { ok = false, method = "none", read_name = nil, read_count = nil, error = nil, point_mode = nil }
  if not (entity and entity.valid and stack and stack.name and (stack.count or 0) > 0) then
    diag.error = "bad-args"
    return false, diag
  end

  slot_index = slot_index or 1
  local count = math.max(1, stack.count or 1)
  local quality = stack.quality or "normal"
  local section, section_err, point_mode = tech_priests_get_requester_manual_section(entity)
  diag.point_mode = point_mode
  if not section then
    diag.error = section_err or "no-section"
    return false, diag
  end

  local filters = {
    { value = { type = "item", name = stack.name, quality = quality }, min = count, max = count },
    { value = { name = stack.name, type = "item", quality = quality }, min = count, max = count },
    { name = stack.name, quality = quality, count = count }
  }

  for i, filter in ipairs(filters) do
    local ok, err = pcall(function() section.set_slot(slot_index, filter) end)
    local slot = nil
    pcall(function() slot = section.get_slot(slot_index) end)
    diag.read_name = tech_priests_request_slot_to_item_name(slot)
    diag.read_count = tech_priests_request_slot_to_count(slot)
    if ok and diag.read_name == stack.name then
      diag.ok = true
      diag.method = "bound-section" .. tostring(i)
      return true, diag
    end
    if not ok then diag.error = tech_priests_short_error(err) end
  end

  if not diag.error then diag.error = "readback-mismatch" end
  return false, diag
end

function set_logistic_request_slot(entity, slot_index, stack)
  local ok = tech_priests_set_logistic_request_slot_diagnostics(entity, slot_index, stack)
  return ok
end

-- 0.1.135 logistics requester correction:
-- The hidden cache is a logistic-container deepcopy. Do not auto-select an
-- arbitrary logistic point from the entity; use the explicit logistic_container
-- member point, because non-requester/fallback points can accept sections in Lua
-- but never become robot delivery targets.
function tech_priests_select_requester_logistic_point(entity)
  if not (entity and entity.valid) then return nil, "invalid-entity", "none" end
  local idx = defines and defines.logistic_member_index and defines.logistic_member_index.logistic_container
  local point = nil
  local err = nil

  if idx and entity.get_logistic_point then
    local ok, result = pcall(function() return entity.get_logistic_point(idx) end)
    if ok and result then
      point = result
    elseif not ok then
      err = tech_priests_short_error(result)
    end
  end

  -- Fallback only for unexpected builds. Prefer a point whose mode is requester.
  if not point and entity.get_logistic_point then
    local ok, result = pcall(function() return entity.get_logistic_point() end)
    if ok and result then
      local requester_mode = defines and defines.logistic_mode and defines.logistic_mode.requester
      local function consider(p)
        if not p then return end
        local ok_mode, mode = pcall(function() return p.mode end)
        if ok_mode and requester_mode and mode == requester_mode then point = p end
        if not point and ok_mode and tostring(mode) == "requester" then point = p end
      end
      if type(result) == "table" and not result.object_name and not result.get_section then
        for _, p in pairs(result) do consider(p) end
      else
        consider(result)
      end
    elseif not ok then
      err = tech_priests_short_error(result)
    end
  end

  if not point then return nil, err or "no-logistic-container-point", "none" end
  local ok_mode, mode = pcall(function() return point.mode end)
  return point, nil, ok_mode and tech_priests_logistic_mode_name(mode) or "unknown"
end

function tech_priests_get_requester_manual_section(entity)
  local point, err, mode_name = tech_priests_select_requester_logistic_point(entity)
  if not point then return nil, err or "no-requester-point", mode_name end

  -- These fields are not universally writable, so keep them protected.
  pcall(function() point.enabled = true end)
  pcall(function() point.trash_not_requested = false end)
  pcall(function() entity.request_from_buffers = true end)

  local section = nil
  local ok, result = pcall(function() return point.get_section(1) end)
  if ok and result then section = result end
  if not section then
    ok, result = pcall(function() return point.add_section("Tech-Priests Requisition") end)
    if ok and result then section = result else err = tech_priests_short_error(result) end
  end
  if not section then return nil, err or "no-manual-section", mode_name end

  pcall(function() section.active = true end)
  pcall(function() section.group = "Tech-Priests Requisition" end)
  pcall(function() section.multiplier = 1 end)
  return section, nil, mode_name
end

function tech_priests_request_slot_to_item_name(slot)
  if not slot then return nil end
  if slot.value then
    if type(slot.value) == "string" then return slot.value end
    return slot.value.name
  end
  return slot.name
end

function tech_priests_request_slot_to_count(slot)
  if not slot then return nil end
  return slot.min or slot.count or slot.max
end

function tech_priests_get_logistic_point_network_present(entity)
  if not (entity and entity.valid) then return false end
  local point = nil
  local idx = defines and defines.logistic_member_index and defines.logistic_member_index.logistic_container
  if idx and entity.get_logistic_point then
    local ok, result = pcall(function() return entity.get_logistic_point(idx) end)
    if ok then point = result end
  end
  if point then
    local ok, network = pcall(function() return point.logistic_network end)
    if ok and network then return true end
  end
  return tech_priests_get_cache_network_present(entity)
end

function tech_priests_get_point_targeted_delivery_count(entity, item_name)
  if not (entity and entity.valid and item_name) then return 0 end
  local idx = defines and defines.logistic_member_index and defines.logistic_member_index.logistic_container
  local point = nil
  if idx and entity.get_logistic_point then
    local ok, result = pcall(function() return entity.get_logistic_point(idx) end)
    if ok then point = result end
  end
  if not point then return 0 end
  local ok, counts = pcall(function() return point.targeted_items_deliver end)
  if not (ok and counts) then return 0 end
  local direct = counts[item_name]
  if type(direct) == "number" then return direct end
  if type(direct) == "table" then return direct.count or direct["normal"] or 0 end
  return 0
end

function tech_priests_set_logistic_request_slot_diagnostics(entity, slot_index, stack)
  local diag = { ok = false, method = "none", read_name = nil, read_count = nil, error = nil, point_mode = nil }
  if not (entity and entity.valid and stack and stack.name and (stack.count or 0) > 0) then
    diag.error = "bad-args"
    return false, diag
  end

  slot_index = slot_index or 1
  local count = math.max(1, stack.count or 1)
  local quality = stack.quality or "normal"
  local section, section_err, point_mode = tech_priests_get_requester_manual_section(entity)
  diag.point_mode = point_mode
  if not section then
    diag.error = section_err or "no-section"
    return false, diag
  end

  -- Clear stale filters first so readback and robot targeting cannot be polluted
  -- by a previous failed request for a different item.
  pcall(function()
    for i = 1, LOGISTIC_REQUESTER_SLOT_COUNT do
      if section.clear_slot then section.clear_slot(i) end
    end
  end)

  local filters = {
    { value = { type = "item", name = stack.name, quality = quality, comparator = "=" }, min = count, max = count },
    { value = { name = stack.name, type = "item", quality = quality, comparator = "=" }, min = count },
    { value = stack.name, min = count, max = count }
  }

  for i, filter in ipairs(filters) do
    local ok, err = pcall(function() section.set_slot(slot_index, filter) end)
    local slot = nil
    pcall(function() slot = section.get_slot(slot_index) end)
    diag.read_name = tech_priests_request_slot_to_item_name(slot)
    diag.read_count = tech_priests_request_slot_to_count(slot)
    if ok and diag.read_name == stack.name then
      diag.ok = true
      diag.method = "logistic-container-section" .. tostring(i)
      return true, diag
    end
    if not ok then diag.error = tech_priests_short_error(err) end
  end

  if not diag.error then diag.error = "readback-mismatch" end
  return false, diag
end

-- Override request issuer once more so diagnostics include the explicit
-- logistic-container point network and targeted-delivery count.

-- Add targeted delivery to the overlay without making it run across the map.
original_0135_draw_station_logistic_debug_text = draw_station_logistic_debug_text
function draw_station_logistic_debug_text(pair)
  if not read_global_bool_setting("tech-priests-enable-logistics-debug-overlay", false) then
    clear_station_logistic_debug_text(pair)
    return
  end
  if not (pair and pair.station and pair.station.valid) then return end
  local debug = pair.logistic_debug
  local active = debug and game.tick <= (debug.tick or 0) + LOGISTIC_DEBUG_RENDER_TTL
  if not (debug and active) then
    clear_station_logistic_debug_text(pair)
    return
  end

  storage.tech_priests.logistic_debug_text = storage.tech_priests.logistic_debug_text or {}
  clear_station_logistic_debug_text(pair)

  local err = debug.error and (" err=" .. tostring(debug.error)) or ""
  local parts = {
    "TP-LOG " .. tostring(debug.stage or "?") .. " " .. tech_priests_logistic_item_label(debug.item or pair.logistic_requested_item),
    "set=" .. tostring(debug.ok) .. " m=" .. tostring(debug.method or "-") .. " mode=" .. tostring(debug.point_mode or "-"),
    "rd=" .. tostring(debug.read_name or "-") .. " want=" .. tostring(debug.read_count or "-") .. " tgt=" .. tostring(debug.targeted_delivery_count or 0),
    "net=" .. tostring(debug.network_count or "-") .. " cache=" .. tostring(debug.cache_count or "-") .. " st=" .. tostring(debug.station_count or "-"),
    "space=" .. tostring(debug.station_can_insert) .. " cnet=" .. tostring(debug.cache_in_network) .. " LS=" .. tostring(debug.has_logistic_system) .. err
  }

  local obj = rendering.draw_text({
    text = table.concat(parts, "\n"),
    surface = pair.station.surface,
    target = pair.station,
    target_offset = {0, -4.15},
    color = debug.ok and { r = 0.35, g = 1.00, b = 0.45, a = 0.92 } or { r = 1.00, g = 0.25, b = 0.12, a = 0.95 },
    alignment = "center",
    vertical_alignment = "bottom",
    scale = 0.62,
    use_rich_text = true,
    players = nil,
    time_to_live = LOGISTIC_DEBUG_RENDER_TTL
  })
  if obj then storage.tech_priests.logistic_debug_text[pair.station.unit_number] = obj end
end

-- 0.1.137 active-provider trash export:
-- Now that requester delivery is confirmed, make the opposite end useful too.
-- Cogitator Stations periodically move junk/excess inventory into their hidden
-- active-provider return cache so logistics robots can carry it back to storage.
LOGISTIC_TRASH_EXPORT_INTERVAL_TICKS = 90
LOGISTIC_TRASH_EXPORT_MAX_STACKS_PER_PASS = 1

function tech_priests_is_station_supply_item(item_name)
  if not item_name then return false end
  if item_name == "repair-pack" then return true end
  if is_ammo_item and is_ammo_item(item_name) then return true end
  for _, option in pairs(get_station_consecration_item_options and get_station_consecration_item_options() or {}) do
    if option.name == item_name then return true end
  end
  return false
end

function tech_priests_station_supply_reserve(item_name)
  if not item_name then return 0 end
  if item_name == "repair-pack" then return 10 end
  if is_ammo_item and is_ammo_item(item_name) then
    return math.max(10, math.min(50, get_item_stack_size(item_name)))
  end
  if item_name == "sacred-machine-oil" then return 20 end
  if item_name == "machine-maintenance-litany" then return 10 end
  if item_name == "ritual-of-machine-appeasement" then return 6 end
  return 5
end

function tech_priests_choose_station_trash_stack(pair)
  if not (pair and pair.station and pair.station.valid) then return nil end
  local inventory = get_station_inventory(pair.station)
  if not (inventory and inventory.valid) then return nil end
  local requested = pair.logistic_requested_item

  -- First pass: true junk. Never eject the thing we are actively waiting for.
  for i = 1, #inventory do
    local stack = inventory[i]
    if stack and stack.valid_for_read and stack.name ~= requested and not tech_priests_is_station_supply_item(stack.name) then
      local quality = get_stack_quality_name(stack)
      return {
        name = stack.name,
        count = math.min(get_item_stack_size(stack.name), stack.count),
        quality = quality,
        reason = "junk"
      }
    end
  end

  -- Second pass: overstocked supplies. Keep a small reserve so the priest does
  -- not throw away his own ammunition/oil/repair doctrine while cleaning space.
  for i = 1, #inventory do
    local stack = inventory[i]
    if stack and stack.valid_for_read and stack.name ~= requested and tech_priests_is_station_supply_item(stack.name) then
      local reserve = tech_priests_station_supply_reserve(stack.name)
      local total = inventory.get_item_count(stack.name)
      if total > reserve then
        local quality = get_stack_quality_name(stack)
        return {
          name = stack.name,
          count = math.min(get_item_stack_size(stack.name), stack.count, total - reserve),
          quality = quality,
          reason = "overstock"
        }
      end
    end
  end

  return nil
end

function tech_priests_return_cache_count(pair, item_name)
  if not (pair and pair.logistic_return_cache and pair.logistic_return_cache.valid and item_name) then return 0 end
  local inv = get_hidden_cache_inventory(pair.logistic_return_cache)
  if not inv then return 0 end
  return inv.get_item_count(item_name)
end

function tech_priests_export_station_trash_to_logistics(pair, reason)
  if not (pair and pair.station and pair.station.valid) then return 0 end
  if not is_cogitator_logistic_requisition_enabled(pair.station.force) then return 0 end
  local network = get_station_logistic_network(pair.station)
  if not network then return 0 end
  ensure_pair_logistic_caches(pair)
  if not (pair.logistic_return_cache and pair.logistic_return_cache.valid) then return 0 end

  local station_inventory = get_station_inventory(pair.station)
  local return_inventory = get_hidden_cache_inventory(pair.logistic_return_cache)
  if not (station_inventory and station_inventory.valid and return_inventory and return_inventory.valid) then return 0 end

  local moved_total = 0
  local moved_name = nil
  local moved_reason = nil
  for _ = 1, LOGISTIC_TRASH_EXPORT_MAX_STACKS_PER_PASS do
    local trash = tech_priests_choose_station_trash_stack(pair)
    if not trash or not trash.name or (trash.count or 0) <= 0 then break end
    local stack = make_item_stack_identification(trash.name, trash.count, trash.quality)
    if not return_inventory.can_insert(stack) then break end
    local removed = station_inventory.remove(stack)
    if removed and removed > 0 then
      local inserted = return_inventory.insert(make_item_stack_identification(trash.name, removed, trash.quality))
      if inserted < removed then
        station_inventory.insert(make_item_stack_identification(trash.name, removed - inserted, trash.quality))
      end
      if inserted > 0 then
        moved_total = moved_total + inserted
        moved_name = trash.name
        moved_reason = trash.reason
      end
    else
      break
    end
  end

  if moved_total > 0 then
    tech_priests_update_logistic_debug(pair, {
      stage = "trash-export",
      ok = true,
      item = moved_name,
      count = moved_total,
      method = tostring(reason or moved_reason or "provider"),
      cache_count = tech_priests_return_cache_count(pair, moved_name),
      station_count = station_inventory.get_item_count(moved_name),
      cache_in_network = tech_priests_get_cache_network_present(pair.logistic_return_cache),
      has_logistic_system = tech_priests_get_force_has_logistic_system(pair.station.force)
    })
  end
  return moved_total
end

-- Strengthen the existing cram eject path so it uses the same stack-based
-- provider cache exporter. The older function name is still called by cram
-- mode, but now it can move a whole junk/overstock stack when available.
original_0137_eject_one_unwanted_station_item = eject_one_unwanted_station_item
function eject_one_unwanted_station_item(pair, request)
  local moved = tech_priests_export_station_trash_to_logistics(pair, "cram-provider")
  if moved and moved > 0 then return true end
  return original_0137_eject_one_unwanted_station_item(pair, request)
end

original_0137_tick_pair = tick_pair
function tick_pair(pair)
  local result = original_0137_tick_pair(pair)
  if pair and pair.station and pair.station.valid then
    local unit = pair.station_unit or pair.station.unit_number or 0
    if ((game.tick + unit) % LOGISTIC_TRASH_EXPORT_INTERVAL_TICKS) == 0 then
      tech_priests_export_station_trash_to_logistics(pair, "periodic-provider")
    end
  end
  return result
end


-- 0.1.138 logistics priority repair:
-- * Reduce logistics/scavenge/cram patience to 10 seconds for faster debugging.
-- * Treat trash export as a prerequisite for accepting deliveries when the
--   station inventory is full.
-- * Do not keep requesting a wanted item into the hidden requester cache when
--   the visible Cogitator Station cannot accept it.
-- * Move junk/overstock into the hidden active-provider cache aggressively and
--   report both station and return-cache counts in the debug overlay.
LOGISTIC_FRUSTRATION_THRESHOLD_TICKS = 60 * 10
LOGISTIC_NO_NETWORK_SCAVENGE_TICKS = 60 * 10
LOGISTIC_CRAM_SEARCH_BEFORE_DUMP_TICKS = 60 * 10
LOGISTIC_TRASH_EXPORT_MAX_STACKS_PER_PASS_0138 = 3

function tech_priests_clear_requester_cache_request(pair)
  if pair and pair.logistic_requester and pair.logistic_requester.valid then
    clear_logistic_request_slots(pair.logistic_requester)
  end
end

function tech_priests_station_has_room_for_stack(pair, stack)
  if not (pair and pair.station and pair.station.valid and stack and stack.name) then return false end
  local inv = get_station_inventory(pair.station)
  return inv and inv.valid and inv.can_insert({ name = stack.name, count = 1, quality = stack.quality }) or false
end

function tech_priests_get_return_cache_inventory(pair)
  if not (pair and pair.logistic_return_cache and pair.logistic_return_cache.valid) then return nil end
  return get_hidden_cache_inventory(pair.logistic_return_cache)
end

function tech_priests_return_cache_item_count(pair, item_name)
  local inv = tech_priests_get_return_cache_inventory(pair)
  if not (inv and item_name) then return 0 end
  local ok, count = pcall(function() return inv.get_item_count(item_name) end)
  return ok and count or 0
end

-- Override the 0.1.137 exporter with a more aggressive stack pass. This keeps
-- Mechanical Detritus and other non-requested clutter from blocking the tiny
-- Cogitator Station inventory, while still preserving reserves of useful
-- supplies. It intentionally does not move the currently requested item.
function tech_priests_export_station_trash_to_logistics(pair, reason)
  if not (pair and pair.station and pair.station.valid) then return 0 end
  if not is_cogitator_logistic_requisition_enabled(pair.station.force) then return 0 end
  local network = get_station_logistic_network(pair.station)
  if not network then return 0 end
  ensure_pair_logistic_caches(pair)
  if not (pair.logistic_return_cache and pair.logistic_return_cache.valid) then return 0 end

  local station_inventory = get_station_inventory(pair.station)
  local return_inventory = get_hidden_cache_inventory(pair.logistic_return_cache)
  if not (station_inventory and station_inventory.valid and return_inventory and return_inventory.valid) then return 0 end

  local moved_total = 0
  local moved_name = nil
  local moved_reason = nil
  for _ = 1, LOGISTIC_TRASH_EXPORT_MAX_STACKS_PER_PASS_0138 do
    local trash = tech_priests_choose_station_trash_stack(pair)
    if not trash or not trash.name or (trash.count or 0) <= 0 then break end
    local move_count = math.min(trash.count or 1, get_item_stack_size(trash.name))
    local stack = make_item_stack_identification(trash.name, move_count, trash.quality)
    if not return_inventory.can_insert(stack) then
      tech_priests_update_logistic_debug(pair, {
        stage = "trash-cache-full",
        ok = false,
        item = trash.name,
        method = tostring(reason or trash.reason or "provider"),
        cache_count = tech_priests_return_cache_item_count(pair, trash.name),
        station_count = station_inventory.get_item_count(trash.name),
        cache_in_network = tech_priests_get_cache_network_present(pair.logistic_return_cache),
        has_logistic_system = tech_priests_get_force_has_logistic_system(pair.station.force)
      })
      break
    end

    local removed = station_inventory.remove(stack)
    if not removed or removed <= 0 then break end
    local inserted = return_inventory.insert(make_item_stack_identification(trash.name, removed, trash.quality))
    if inserted < removed then
      station_inventory.insert(make_item_stack_identification(trash.name, removed - inserted, trash.quality))
    end
    if inserted > 0 then
      moved_total = moved_total + inserted
      moved_name = trash.name
      moved_reason = trash.reason
    end
  end

  if moved_total > 0 then
    tech_priests_update_logistic_debug(pair, {
      stage = "trash-export",
      ok = true,
      item = moved_name,
      count = moved_total,
      method = tostring(reason or moved_reason or "provider"),
      cache_count = tech_priests_return_cache_item_count(pair, moved_name),
      station_count = station_inventory.get_item_count(moved_name),
      cache_in_network = tech_priests_get_cache_network_present(pair.logistic_return_cache),
      has_logistic_system = tech_priests_get_force_has_logistic_system(pair.station.force)
    })
  end
  return moved_total
end

-- Delivery is now gated by visible station capacity. If the station is clogged,
-- clear the requester slot and export junk first. This prevents the hidden
-- requester cache from accepting items the station cannot currently hold.
function issue_station_logistic_request(pair, request)
  if not (pair and pair.station and pair.station.valid and request) then return false end
  if not is_cogitator_logistic_requisition_enabled(pair.station.force) then
    tech_priests_update_logistic_debug(pair, { stage = "tech-off", ok = false })
    return false
  end

  local network = get_station_logistic_network(pair.station)
  if not network then
    tech_priests_update_logistic_debug(pair, { stage = "no-network", ok = false })
    if pair.logistic_requester and pair.logistic_requester.valid then pair.logistic_requester.destroy({ raise_destroy = false }) end
    if pair.logistic_return_cache and pair.logistic_return_cache.valid then pair.logistic_return_cache.destroy({ raise_destroy = false }) end
    pair.logistic_requester = nil
    pair.logistic_return_cache = nil
    pair.mode = "logistics-no-network"
    return false
  end

  ensure_pair_logistic_caches(pair)
  if not (pair.logistic_requester and pair.logistic_requester.valid) then
    tech_priests_update_logistic_debug(pair, { stage = "no-cache", ok = false })
    return false
  end

  local stack = choose_logistic_request_stack(pair, request)
  if not stack then
    tech_priests_update_logistic_debug(pair, { stage = "no-stack", ok = false, kind = request.kind })
    return false
  end

  pair.logistic_requested_item = stack.name
  pair.logistic_requested_count = stack.count or 1
  pair.logistic_frustration_kind = request.kind
  if not pair.logistic_frustration_start_tick then
    pair.logistic_frustration_start_tick = game.tick
    pair.logistic_frustration_due_tick = game.tick + LOGISTIC_FRUSTRATION_THRESHOLD_TICKS
  else
    pair.logistic_frustration_due_tick = math.min(pair.logistic_frustration_due_tick or (game.tick + LOGISTIC_FRUSTRATION_THRESHOLD_TICKS), game.tick + LOGISTIC_FRUSTRATION_THRESHOLD_TICKS)
  end

  local station_inventory = get_station_inventory(pair.station)
  local cache_inventory = get_hidden_cache_inventory(pair.logistic_requester)
  local station_can_insert = station_inventory and station_inventory.can_insert({ name = stack.name, count = 1, quality = stack.quality }) or false

  -- If bots already delivered the requested item to the hidden cache and the
  -- station has room, transfer it first. If there is no room, do not request
  -- more; export junk immediately.
  if station_can_insert then
    transfer_cache_inventory_to_station(pair)
    station_can_insert = station_inventory and station_inventory.can_insert({ name = stack.name, count = 1, quality = stack.quality }) or false
  end

  if not station_can_insert then
    tech_priests_clear_requester_cache_request(pair)
    local moved = tech_priests_export_station_trash_to_logistics(pair, "pre-delivery-trash")
    if not pair.logistic_cram_due_tick then
      pair.logistic_cram_start_tick = game.tick
      pair.logistic_cram_due_tick = game.tick + LOGISTIC_FRUSTRATION_THRESHOLD_TICKS
    else
      pair.logistic_cram_due_tick = math.min(pair.logistic_cram_due_tick, game.tick + LOGISTIC_FRUSTRATION_THRESHOLD_TICKS)
    end
    pair.mode = "logistics-clearing-space"
    tech_priests_update_logistic_debug(pair, {
      stage = moved > 0 and "clearing-space" or "blocked-full",
      ok = moved > 0,
      kind = request.kind,
      item = stack.name,
      count = stack.count or 1,
      method = "trash-first",
      read_name = nil,
      read_count = nil,
      network_count = logistic_network_item_count(network, { name = stack.name, count = 1 }),
      cache_count = cache_inventory and cache_inventory.get_item_count(stack.name) or 0,
      station_count = station_inventory and station_inventory.get_item_count(stack.name) or 0,
      station_can_insert = false,
      cache_in_network = tech_priests_get_logistic_point_network_present and tech_priests_get_logistic_point_network_present(pair.logistic_requester) or tech_priests_get_cache_network_present(pair.logistic_requester),
      targeted_delivery_count = tech_priests_get_point_targeted_delivery_count and tech_priests_get_point_targeted_delivery_count(pair.logistic_requester, stack.name) or 0,
      has_logistic_system = tech_priests_get_force_has_logistic_system(pair.station.force)
    })
    return false
  end

  pair.logistic_cram_start_tick = nil
  pair.logistic_cram_due_tick = nil
  pair.mode = "logistics-scavenge-countdown"

  clear_logistic_request_slots(pair.logistic_requester)
  local request_was_set, diag = tech_priests_set_logistic_request_slot_diagnostics(pair.logistic_requester, 1, stack)
  pair.logistic_request_failed = not request_was_set
  cache_inventory = get_hidden_cache_inventory(pair.logistic_requester)
  local cache_count = cache_inventory and cache_inventory.get_item_count(stack.name) or 0
  local station_count = station_inventory and station_inventory.get_item_count(stack.name) or 0
  local network_count = logistic_network_item_count(network, { name = stack.name, count = 1 })
  tech_priests_update_logistic_debug(pair, {
    stage = request_was_set and "request-set" or "request-failed",
    ok = request_was_set,
    kind = request.kind,
    item = stack.name,
    count = stack.count or 1,
    method = diag and diag.method or "?",
    point_mode = diag and diag.point_mode or "?",
    read_name = diag and diag.read_name or nil,
    read_count = diag and diag.read_count or nil,
    error = diag and diag.error or nil,
    network_count = network_count,
    cache_count = cache_count,
    station_count = station_count,
    station_can_insert = true,
    cache_in_network = tech_priests_get_logistic_point_network_present and tech_priests_get_logistic_point_network_present(pair.logistic_requester) or tech_priests_get_cache_network_present(pair.logistic_requester),
    targeted_delivery_count = tech_priests_get_point_targeted_delivery_count and tech_priests_get_point_targeted_delivery_count(pair.logistic_requester, stack.name) or 0,
    has_logistic_system = tech_priests_get_force_has_logistic_system(pair.station.force)
  })
  return request_was_set
end

-- Keep delivered items from sitting forever in the hidden cache when space later
-- becomes available, but do not force the transfer while the station is full.
original_0138_transfer_cache_inventory_to_station = transfer_cache_inventory_to_station
function transfer_cache_inventory_to_station(pair)
  if not (pair and pair.station and pair.station.valid and pair.logistic_requester and pair.logistic_requester.valid) then return 0 end
  local station_inventory = get_station_inventory(pair.station)
  if not (station_inventory and station_inventory.valid) then return 0 end
  if pair.logistic_requested_item and not station_inventory.can_insert({ name = pair.logistic_requested_item, count = 1 }) then
    tech_priests_export_station_trash_to_logistics(pair, "transfer-blocked-trash")
    return 0
  end
  return original_0138_transfer_cache_inventory_to_station(pair)
end

-- Clamp all already-running timers in existing saves down to the new 10-second
-- doctrine while this build is loaded.
original_0138_tick_pair = tick_pair
function tick_pair(pair)
  if pair then
    if pair.logistic_frustration_start_tick and pair.logistic_frustration_due_tick then
      pair.logistic_frustration_due_tick = math.min(pair.logistic_frustration_due_tick, pair.logistic_frustration_start_tick + LOGISTIC_FRUSTRATION_THRESHOLD_TICKS)
    end
    if pair.logistic_cram_start_tick and pair.logistic_cram_due_tick then
      pair.logistic_cram_due_tick = math.min(pair.logistic_cram_due_tick, pair.logistic_cram_start_tick + LOGISTIC_FRUSTRATION_THRESHOLD_TICKS)
    end
  end
  return original_0138_tick_pair(pair)
end


-- 0.1.139 logistics-coverage fallback and recall restraint:
-- * Intermediate/Senior priests no longer need the logistics research/coverage path
--   just to begin local scavenging. If no logistics coverage/research is available,
--   they wait briefly, then scan local inventories.
-- * Priest recall is now treated strictly as a missing/deleted-priest fallback in
--   the core functions above; valid priests are not destroyed merely for being far
--   from the station or busy with a task.
original_0139_maybe_start_supply_scavenge = maybe_start_supply_scavenge
function maybe_start_supply_scavenge(pair, kind, target)
  if not (pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid) then return false end

  -- If the advanced logistics research is absent, or if this station has no usable
  -- logistics network, Intermediate/Senior priests should still be able to become
  -- impatient and start the old local scan path after a short delay. Juniors still
  -- stay bound to station inventory only.
  local has_requisition = is_cogitator_logistic_requisition_enabled and is_cogitator_logistic_requisition_enabled(pair.station.force)
  local has_network = get_station_logistic_network and get_station_logistic_network(pair.station) ~= nil
  if (not has_requisition or not has_network) and tech_priests_pair_allows_local_inventory_scan and tech_priests_pair_allows_local_inventory_scan(pair) then
    tech_priests_clear_forbidden_advanced_supply_state(pair)
    if pair.inventory_scan then return handle_logistic_inventory_scan(pair) end
    if pair.scavenge then return handle_priest_scavenge_task(pair) end
    if pair.cram then return handle_priest_cram_task(pair) end
    if pair.emergency_craft and tech_priests_pair_allows_emergency_desperation(pair) then return handle_emergency_desperation_craft(pair) end

    local request = nil
    if pair.active_supply_request and pair.active_supply_request.kind == kind then
      request = pair.active_supply_request
    else
      request = build_supply_request(pair, kind, target)
    end
    if not request then return false end
    if tech_priests_abort_if_supply_request_obsolete and tech_priests_abort_if_supply_request_obsolete(pair, request) then return true end
    pair.active_supply_request = request
    pair.logistic_requested_item = get_inventory_scan_item_name and get_inventory_scan_item_name({ request = request }) or pair.logistic_requested_item

    local timer_kind = (has_requisition and "no-network-" or "no-logistics-coverage-") .. tostring(kind)
    if pair.logistic_frustration_kind ~= timer_kind then
      pair.logistic_frustration_kind = timer_kind
      pair.logistic_frustration_start_tick = game.tick
      pair.logistic_frustration_due_tick = game.tick + LOGISTIC_NO_NETWORK_SCAVENGE_TICKS
    else
      pair.logistic_frustration_due_tick = math.min(pair.logistic_frustration_due_tick or (game.tick + LOGISTIC_NO_NETWORK_SCAVENGE_TICKS), (pair.logistic_frustration_start_tick or game.tick) + LOGISTIC_NO_NETWORK_SCAVENGE_TICKS)
    end

    if game.tick < (pair.logistic_frustration_due_tick or 0) then
      pair.mode = "logistics-no-network"
      return false
    end

    start_logistic_scavenge_inventory_scan(pair, request)
    return handle_logistic_inventory_scan(pair)
  end

  return original_0139_maybe_start_supply_scavenge(pair, kind, target)
end


-- 0.1.157 recall throttle / asteroid collector salvage pass:
-- The recall system is only a fallback for genuinely vanished priests. Keep a
-- hard cooldown around replacement attempts so a transient invalid reference or
-- pathing oddity cannot become a smoke-spamming respawn loop.
TECH_PRIESTS_RESPAWN_COOLDOWN_TICKS_0157 = 60 * 20
TECH_PRIESTS_FAILED_RESPAWN_COOLDOWN_TICKS_0157 = 60 * 10

function tech_priests_pair_has_valid_priest_0157(pair)
  return pair and pair.priest and pair.priest.valid and pair.priest.unit_number ~= nil
end

function tech_priests_respawn_cooldown_ready_0157(pair)
  if not pair then return false end
  local tick = game and game.tick or 0
  return tick >= (pair.next_allowed_priest_respawn_tick or 0)
end

original_0157_enqueue_priest_deployment = enqueue_priest_deployment
function enqueue_priest_deployment(pair, force_recall)
  if not (pair and pair.station and pair.station.valid) then return false end
  -- Valid priests should not be queued for fallback redeployment. This includes
  -- force_recall callers; recall is no longer a repositioning mechanism.
  if tech_priests_pair_has_valid_priest_0157(pair) then
    pair.deployment_queued = nil
    return true
  end
  if not tech_priests_respawn_cooldown_ready_0157(pair) then
    return false
  end
  return original_0157_enqueue_priest_deployment(pair, false)
end

original_0157_respawn_pair_priest = respawn_pair_priest
function respawn_pair_priest(pair, reason)
  if not (pair and pair.station and pair.station.valid) then return false end
  if tech_priests_pair_has_valid_priest_0157(pair) then
    pair.deployment_queued = nil
    return true
  end
  local tick = game and game.tick or 0
  if tick < (pair.next_allowed_priest_respawn_tick or 0) then
    return false
  end
  -- Set the cooldown before attempting the spawn so a failing create_entity path
  -- cannot retry every 10 ticks and flood the map with translocation smoke.
  pair.next_allowed_priest_respawn_tick = tick + TECH_PRIESTS_FAILED_RESPAWN_COOLDOWN_TICKS_0157
  local ok = original_0157_respawn_pair_priest(pair, reason or "missing-cooldown")
  if ok then
    pair.last_priest_respawn_tick = tick
    pair.next_allowed_priest_respawn_tick = tick + TECH_PRIESTS_RESPAWN_COOLDOWN_TICKS_0157
  end
  return ok
end

original_0157_sanity_recall_all_priests = sanity_recall_all_priests
function sanity_recall_all_priests(force_recall)
  ensure_storage()
  for _, pair in pairs(storage.tech_priests.pairs_by_station) do
    if pair.station and pair.station.valid then
      if not tech_priests_pair_has_valid_priest_0157(pair) and tech_priests_respawn_cooldown_ready_0157(pair) then
        enqueue_priest_deployment(pair, false)
      end
    else
      cleanup_pair(pair)
    end
  end
end

-- Asteroid collector salvage hardening. The engine exposes collector content via
-- defines.inventory.asteroid_collector_output and sometimes the collector arm.
-- Make emergency acquisition resilient if the earlier candidate was created
-- before those IDs were present, or if a collector uses a non-standard output ID.
original_0157_acquire_emergency_material = acquire_emergency_material
function acquire_emergency_material(pair, task, candidate)
  if candidate and candidate.kind == "inventory" and candidate.entity and candidate.entity.valid then
    local ok_type, entity_type = pcall(function() return candidate.entity.type end)
    if ok_type and entity_type == "asteroid-collector" then
      local ids = get_scavenge_inventory_ids()
      for _, inventory_id in pairs(ids) do
        local inv = get_entity_inventory_safe(candidate.entity, inventory_id)
        if inv then
          local available = inv.get_item_count(candidate.item_name)
          if available and available > 0 then
            candidate.inventory_id = inventory_id
            break
          end
        end
      end
    end
  end
  return original_0157_acquire_emergency_material(pair, task, candidate)
end


-- 0.1.165 orphan priest purge and desperation acquisition hygiene.
-- If a priest entity has lost its station mapping, selecting/mousing over it should
-- make the broken servitor logic visibly self-terminate instead of pretending it
-- still has a Cogitator link.
ORPHAN_PRIEST_PURGE_COOLDOWN_TICKS = 60

function spawn_orphan_priest_purge_explosion(priest)
  if not (priest and priest.valid) then return end
  local surface = priest.surface
  local position = priest.position
  local force = priest.force
  local candidates = { "grenade-explosion", "medium-explosion", "explosion" }
  for _, name in pairs(candidates) do
    if get_entity_prototype_safe(name) then
      local ok = pcall(function()
        surface.create_entity({ name = name, position = position, force = force })
      end)
      if ok then break end
    end
  end
  pcall(function() spawn_priest_translocation_smoke(surface, position, force, true) end)
end

function purge_orphan_selected_priest(priest)
  if not (priest and priest.valid and is_priest(priest)) then return false end
  local pair = find_pair_for_entity and find_pair_for_entity(priest) or nil
  if pair and pair.station and pair.station.valid then return false end
  ensure_storage()
  storage.tech_priests.orphan_priest_purge_cooldowns = storage.tech_priests.orphan_priest_purge_cooldowns or {}
  local unit = priest.unit_number or 0
  local next_tick = storage.tech_priests.orphan_priest_purge_cooldowns[unit] or 0
  if game.tick < next_tick then return true end
  storage.tech_priests.orphan_priest_purge_cooldowns[unit] = game.tick + ORPHAN_PRIEST_PURGE_COOLDOWN_TICKS
  if unit and storage.tech_priests.station_by_priest then
    storage.tech_priests.station_by_priest[unit] = nil
  end
  spawn_orphan_priest_purge_explosion(priest)
  if tech_priests_destroy_priest_0500 then
    tech_priests_destroy_priest_0500(priest, "orphan-priest-purge", pair)
  else
    pcall(function() priest.destroy({ raise_destroy = false }) end)
  end
  return true
end

original_0165_draw_station_radius_for_player = draw_station_radius_for_player
function draw_station_radius_for_player(player)
  if player and player.valid and player.selected and is_priest(player.selected) then
    if purge_orphan_selected_priest(player.selected) then
      clear_radius_rendering(player.index)
      return
    end
  end
  return original_0165_draw_station_radius_for_player(player)
end
