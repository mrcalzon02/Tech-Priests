-- Auto-split control.lua fragment 020 for Tech Priests 0.1.438.
-- Generated mechanically from 0.1.437 monolithic control.lua.
-- Purpose: reduce Lua main-chunk local/register pressure without deleting behavior.


-- Prevent the existing missing-priest recall path from instantly respawning a
-- killed priest before the recovery timer expires.
if ensure_pair_priest then
  TECH_PRIESTS_PRE_REIMPRINT_ENSURE_PAIR_PRIEST_0298 = ensure_pair_priest
  function ensure_pair_priest(pair, force_recall, immediate)
    if tech_priests_0298_pair_is_reimprinting(pair) then
      return false
    end
    return TECH_PRIESTS_PRE_REIMPRINT_ENSURE_PAIR_PRIEST_0298(pair, force_recall, immediate)
  end
end

if respawn_pair_priest then
  TECH_PRIESTS_PRE_REIMPRINT_RESPAWN_PAIR_PRIEST_0298 = respawn_pair_priest
  function respawn_pair_priest(pair, reason)
    if tech_priests_0298_pair_is_reimprinting(pair) then return false end
    local ok = TECH_PRIESTS_PRE_REIMPRINT_RESPAWN_PAIR_PRIEST_0298(pair, reason or "reimprint-complete")
    if ok and pair then
      tech_priests_0298_clear_reimprint_render(pair)
      pair.reimprint_0298 = nil
      pair.mode = "deploying"
      if pair.priest and pair.priest.valid and pair.priest.max_health and pair.priest.max_health > 0 then
        pcall(function() pair.priest.health = pair.priest.max_health end)
      end
      if tech_priests_0297_refresh_pair_armor_profile then pcall(function() tech_priests_0297_refresh_pair_armor_profile(pair, "reimprint-respawn") end) end
      if pair.station and pair.station.valid and pair.station.force then
        pair.station.force.print({"", "[Tech Priests] Re-imprinting complete at ", tech_priests_station_name_0189 and tech_priests_station_name_0189(pair) or "Cogitator Station", ". The useful corpse has been reissued."})
      end
    end
    return ok
  end
end

function tech_priests_0298_service_reimprints(limit)
  ensure_storage()
  local n = 0
  for _, pair in pairs(storage.tech_priests.pairs_by_station or {}) do
    if pair and pair.reimprint_0298 and pair.reimprint_0298.active and pair.station and pair.station.valid then
      n = n + 1
      if game.tick >= (pair.reimprint_0298.finish_tick or 0) then
        respawn_pair_priest(pair, "reimprint-complete")
      else
        tech_priests_0298_update_reimprint_render(pair)
      end
      if limit and n >= limit then return end
    end
  end
end

TechPriestsRuntimeEventRegistry.on_nth_tick(47, function() tech_priests_0298_service_reimprints(32) end)

-- Extend the command overview/status text so dead priests show up as dead and
-- the camera/location defaults to the surviving Cogitator Station.
if tech_priests_task_summary_0189 then
  TECH_PRIESTS_PRE_REIMPRINT_TASK_SUMMARY_0298 = tech_priests_task_summary_0189
  function tech_priests_task_summary_0189(pair)
    local status = tech_priests_0298_reimprint_status(pair)
    if status then return status end
    return TECH_PRIESTS_PRE_REIMPRINT_TASK_SUMMARY_0298(pair)
  end
end

function tech_priests_0298_pair_life_status(pair)
  if tech_priests_0298_pair_is_reimprinting(pair) then
    return "DEAD · " .. tech_priests_0298_reimprint_status(pair)
  end
  if pair and pair.reimprint_0298 and pair.reimprint_0298.active then return "DEAD · re-imprint ready" end
  if pair and pair.priest and pair.priest.valid then return "Active" end
  return "Missing / pending recovery"
end

if tech_priests_build_command_overview_0189 then
  TECH_PRIESTS_PRE_REIMPRINT_BUILD_OVERVIEW_0298 = tech_priests_build_command_overview_0189
  function tech_priests_build_command_overview_0189(player)
    if not (player and player.valid) then return end
    tech_priests_destroy_command_overview_0189(player)
    local rows = tech_priests_valid_pairs_for_player_0189(player)
    local selected_pair = tech_priests_get_selected_pair_0189(player, rows)
    if selected_pair then tech_priests_command_overview_storage_0189()[player.index] = tech_priests_station_unit_0189(selected_pair) end

    local frame = player.gui.screen.add({ type = "frame", name = TECH_PRIESTS_COMMAND_OVERVIEW_FRAME_0189, direction = "vertical", caption = "Tech-Priest Command Overview" })
    frame.auto_center = true
    frame.style.width = 1120
    frame.style.height = 760
    frame.style.minimal_width = 1120
    frame.style.minimal_height = 760

    local top = frame.add({ type = "flow", direction = "horizontal" })
    top.style.horizontally_stretchable = true
    local title = top.add({ type = "label", caption = "[entity=senior-tech-priest] Force roster · Shift+Y" })
    title.style.horizontally_stretchable = true
    top.add({ type = "button", name = TECH_PRIESTS_COMMAND_OVERVIEW_REFRESH_0189, caption = "Refresh" })
    top.add({ type = "button", name = TECH_PRIESTS_COMMAND_OVERVIEW_CLOSE_0189, caption = "Close" })

    local tabs = frame.add({ type = "tabbed-pane", name = TECH_PRIESTS_COMMAND_OVERVIEW_TABS_0371 })
    tabs.style.vertically_stretchable = true
    tabs.style.horizontally_stretchable = true
    tabs.style.height = 660

    local roster_tab = tabs.add({ type = "tab", caption = "Roster / Selected Unit" })
    local roster_page = tabs.add({ type = "flow", direction = "horizontal" })
    roster_page.style.vertically_stretchable = true
    roster_page.style.horizontally_stretchable = true
    roster_page.style.height = 640
    tabs.add_tab(roster_tab, roster_page)

    local conclave_tab = tabs.add({ type = "tab", caption = "Conclave Statistics / Doctrine Heat Map" })
    local conclave_page = tabs.add({ type = "flow", direction = "vertical" })
    conclave_page.style.vertically_stretchable = true
    conclave_page.style.horizontally_stretchable = true
    conclave_page.style.height = 640
    tabs.add_tab(conclave_tab, conclave_page)

    local body = roster_page

    local left = body.add({ type = "scroll-pane", direction = "vertical" })
    left.style.width = 720
    left.style.height = 625
    left.style.maximal_height = 625
    left.style.vertically_stretchable = true
    left.style.horizontally_stretchable = false

    local table_el = left.add({ type = "table", column_count = 6 })
    table_el.add({ type = "label", caption = "Priest" })
    table_el.add({ type = "label", caption = "Rank" })
    table_el.add({ type = "label", caption = "Station" })
    table_el.add({ type = "label", caption = "Surface" })
    table_el.add({ type = "label", caption = "Location" })
    table_el.add({ type = "label", caption = "Current task" })
    if #rows == 0 then
      table_el.add({ type = "label", caption = "No active Cogitator Stations / Tech-Priests for this force." })
    else
      for _, pair in ipairs(rows) do
        local station_unit = tech_priests_station_unit_0189(pair) or 0
        local selected = selected_pair and station_unit == tech_priests_station_unit_0189(selected_pair)
        local btn = table_el.add({ type = "button", name = TECH_PRIESTS_COMMAND_OVERVIEW_PREFIX_0189 .. tostring(station_unit), caption = (selected and "▶ " or "") .. tech_priests_pair_name_0189(pair) })
        btn.style.width = 155
        table_el.add({ type = "label", caption = tech_priests_pair_rank_label_0189(pair) })
        table_el.add({ type = "label", caption = tech_priests_station_name_0189(pair) })
        table_el.add({ type = "label", caption = pair.station.surface.name })
        local loc = pair.priest and pair.priest.valid and tech_priests_entity_coord_0189(pair.priest) or tech_priests_entity_coord_0189(pair.station)
        table_el.add({ type = "label", caption = loc })
        local task = table_el.add({ type = "label", caption = tech_priests_task_summary_0189(pair) })
        task.style.single_line = false
        task.style.width = 300
      end
    end

    local right_frame = body.add({ type = "frame", direction = "vertical", caption = "Selected unit preview" })
    right_frame.style.width = 360
    right_frame.style.height = 625
    right_frame.style.maximal_height = 625
    right_frame.style.vertically_stretchable = false

    local right = right_frame.add({ type = "scroll-pane", direction = "vertical" })
    right.style.width = 340
    right.style.height = 585
    right.style.maximal_height = 585
    right.style.vertically_stretchable = true
    right.style.horizontally_stretchable = true

    if selected_pair and selected_pair.station and selected_pair.station.valid then
      local preview_target = (selected_pair.priest and selected_pair.priest.valid and selected_pair.priest) or selected_pair.station
      local ok = pcall(function()
        local cam = right.add({ type = "camera", name = "tech_priests_command_camera_0189", position = preview_target.position, surface_index = preview_target.surface.index, zoom = 0.45 })
        cam.style.width = 320
        cam.style.height = 210
      end)
      if not ok then right.add({ type = "label", caption = "Camera preview unavailable in this runtime; use the coordinates below." }) end
      tech_priests_add_labeled_line_0189(right, "Life state", tech_priests_0298_pair_life_status(selected_pair))
      tech_priests_add_labeled_line_0189(right, "Priest", tech_priests_pair_name_0189(selected_pair))
      tech_priests_add_labeled_line_0189(right, "Rank", tech_priests_pair_rank_label_0189(selected_pair))
      tech_priests_add_labeled_line_0189(right, "Station", tech_priests_station_name_0189(selected_pair))
      tech_priests_add_labeled_line_0189(right, "Surface", selected_pair.station.surface.name)
      tech_priests_add_labeled_line_0189(right, "Station coords", tech_priests_entity_coord_0189(selected_pair.station))
      tech_priests_add_labeled_line_0189(right, "Priest coords", (selected_pair.priest and selected_pair.priest.valid) and tech_priests_entity_coord_0189(selected_pair.priest) or "dead; camera on station")
      tech_priests_add_labeled_line_0189(right, "Station health", tech_priests_pair_health_0189(selected_pair.station))
      tech_priests_add_labeled_line_0189(right, "Priest health", (selected_pair.priest and selected_pair.priest.valid) and tech_priests_pair_health_0189(selected_pair.priest) or "—")
      if selected_pair.reimprint_0298 and selected_pair.reimprint_0298.active then
        local rem = math.max(0, (selected_pair.reimprint_0298.finish_tick or game.tick) - game.tick)
        tech_priests_add_labeled_line_0189(right, "Respawn", "Re-imprinting · " .. tech_priests_0298_format_time(rem))
      end
      tech_priests_add_labeled_line_0189(right, "Task", tech_priests_task_summary_0189(selected_pair))
      tech_priests_add_labeled_line_0189(right, "Inventory", tech_priests_station_inventory_summary_0189(selected_pair))
      local emergency_op_0190 = (tech_priests_get_emergency_operation_0184 and tech_priests_get_emergency_operation_0184(selected_pair)) or selected_pair.independent_emergency_operation_0184
      local emergency_status_0190 = emergency_op_0190 and "Independent / Emergency doctrine: ENABLED" or "Independent / Emergency doctrine: disabled"
      tech_priests_add_labeled_line_0189(right, "Emergency", emergency_status_0190)
      right.add({ type = "button", name = TECH_PRIESTS_COMMAND_OVERVIEW_EMERGENCY_TOGGLE_0190, caption = emergency_op_0190 and "Disable independent / emergency mode" or "Enable independent / emergency mode" })
      right.add({ type = "button", name = TECH_PRIESTS_COMMAND_OVERVIEW_EMERGENCY_AUTO_0190, caption = "Allow frustration auto-enable" })
      right.add({ type = "button", name = TECH_PRIESTS_COMMAND_OVERVIEW_PREFIX_0189 .. tostring(tech_priests_station_unit_0189(selected_pair) or 0) .. "_center", caption = (selected_pair.priest and selected_pair.priest.valid) and "Mark selected priest in chat" or "Mark re-imprinting station in chat" })
      if tech_priests_0272_subordinate_summary then tech_priests_add_labeled_line_0189(right, "Subordinates", tech_priests_0272_subordinate_summary(selected_pair, 4)) end
      if tech_priests_0272_requested_assignment_summary then tech_priests_add_labeled_line_0189(right, "Requested work", tech_priests_0272_requested_assignment_summary(selected_pair, 3)) end
    else
      right.add({ type = "label", caption = "No Tech-Priest selected." })
    end

    if _G.tech_priests_0370_render_conclave_content then
      local ok_conclave, err_conclave = pcall(_G.tech_priests_0370_render_conclave_content, conclave_page, player, { embedded = true, max_height = 585, min_width = 1030 })
      if not ok_conclave then conclave_page.add({ type = "label", caption = "Conclave Statistics tab failed to render: " .. tostring(err_conclave) }) end
    else
      conclave_page.add({ type = "label", caption = "Conclave Statistics tab is waiting for doctrine_argument.lua to install." })
      conclave_page.add({ type = "label", caption = "This tab is the intended home for the doctrine heat map; no separate management hotkey should be added." })
    end

    if tech_priests_command_overview_selected_tab_0371(player) == "conclave" then
      pcall(function() tabs.selected_tab_index = 2 end)
    else
      pcall(function() tabs.selected_tab_index = 1 end)
    end
  end
end

-- Preserve 0.1.297 research handling and add re-imprint refresh/shortening.
function tech_priests_0298_on_research_finished(event)
  if event and event.research and event.research.force then
    tech_priests_0297_on_research_finished(event)
    if tech_priests_0298_is_reimprint_tech(event.research.name) then
      for _, pair in pairs(storage.tech_priests.pairs_by_station or {}) do
        if pair.station and pair.station.valid and pair.station.force == event.research.force and pair.reimprint_0298 and pair.reimprint_0298.active then
          local new_duration = tech_priests_0298_reimprint_duration(event.research.force)
          local elapsed = game.tick - (pair.reimprint_0298.started_tick or game.tick)
          pair.reimprint_0298.duration = new_duration
          pair.reimprint_0298.finish_tick = math.max(game.tick, (pair.reimprint_0298.started_tick or game.tick) + new_duration)
          pair.next_allowed_priest_respawn_tick = pair.reimprint_0298.finish_tick
          tech_priests_0298_update_reimprint_render(pair)
        end
      end
    end
  end
end
if script and defines and defines.events then
  TechPriestsRuntimeEventRegistry.on_event(defines.events.on_research_finished, tech_priests_0298_on_research_finished)
  if defines.events.on_technology_effects_reset then
    TechPriestsRuntimeEventRegistry.on_event(defines.events.on_technology_effects_reset, function(event)
      if event and event.force then
        if tech_priests_0297_apply_force_armor_to_existing_priests then tech_priests_0297_apply_force_armor_to_existing_priests(event.force, "technology-effects-reset") end
        for _, pair in pairs(storage.tech_priests and storage.tech_priests.pairs_by_station or {}) do
          if pair.station and pair.station.valid and pair.station.force == event.force and pair.reimprint_0298 and pair.reimprint_0298.active then
            local new_duration = tech_priests_0298_reimprint_duration(event.force)
            pair.reimprint_0298.duration = new_duration
            pair.reimprint_0298.finish_tick = math.max(game.tick, (pair.reimprint_0298.started_tick or game.tick) + new_duration)
            pair.next_allowed_priest_respawn_tick = pair.reimprint_0298.finish_tick
          end
        end
      end
    end)
  end
end

pcall(function()
  TechPriestsDebugCommandRegistry.add("tp-reimprint-0298", "Tech Priests: show or force-service the selected priest re-imprinting state.", function(event)
    local player = game.get_player(event.player_index)
    if not (player and player.valid) then return end
    ensure_storage()
    local pair = nil
    local selected = player.selected
    if selected and selected.valid and find_pair_for_entity then pair = find_pair_for_entity(selected) end
    if not pair then player.print("[Tech Priests 0.1.299] Select a Cogitator Station or Tech-Priest."); return end
    tech_priests_0298_service_reimprints(64)
    local status = tech_priests_0298_pair_life_status(pair)
    local rem = pair.reimprint_0298 and pair.reimprint_0298.active and math.max(0, (pair.reimprint_0298.finish_tick or game.tick) - game.tick) or 0
    player.print("[Tech Priests 0.1.299] status=" .. tostring(status) .. " remaining=" .. tech_priests_0298_format_time(rem) .. " priest_valid=" .. tostring(pair.priest and pair.priest.valid) .. " station=" .. tostring(pair.station and pair.station.valid and pair.station.unit_number))
  end)
end)

log("[Tech-Priests 0.1.299] station-bound priest re-imprinting respawn module loaded")


-- -----------------------------------------------------------------------------
-- Tech Priests 0.1.299 - locale duplicate key repair marker
-- -----------------------------------------------------------------------------
if log then log('[Tech-Priests 0.1.299] 0.1.299 locale duplicate key repair package loaded') end


-- -----------------------------------------------------------------------------
-- 0.1.300 Armor Mirror nil-map crash guard
-- -----------------------------------------------------------------------------
if log then
  log("[Tech-Priests 0.1.300] armor mirror priest-name map crash guard loaded")
end


-- 0.1.301 Permanent named Cogitator cell preservation module.
-- Once a Cogitator Station has acquired its Administratum/forge-cell name, it
-- becomes a unique non-stackable item when mined.  Its name, station inventory,
-- and future extension fields survive pickup/replacement.  This is deliberately
-- implemented as an end-of-file preservation shell so it can wrap the historical
-- removal/build chain without trying to rewrite it yet.
TECH_PRIESTS_VERSION_0301 = "0.1.301"
TECH_PRIESTS_PRESERVATION_TAG_0301 = "tech_priests_preserved_cell_0301"

function tech_priests_0301_station_item_names()
  local names = {}
  if STATION_CONFIGS then
    for station_name, _ in pairs(STATION_CONFIGS) do names[station_name] = true end
  end
  for _, name in pairs({
    "junior-cogitator-station",
    "intermediate-cogitator-station",
    "senior-cogitator-station",
    "planetary-magos-cogitator-station",
    "void-cogitator-station"
  }) do names[name] = true end
  return names
end
TECH_PRIESTS_STATION_ITEM_NAMES_0301 = tech_priests_0301_station_item_names()

function tech_priests_0301_is_station_item_name(name)
  return name and TECH_PRIESTS_STATION_ITEM_NAMES_0301 and TECH_PRIESTS_STATION_ITEM_NAMES_0301[name] or false
end

function tech_priests_0301_safe_entity_name(entity)
  return entity and entity.valid and entity.name or nil
end

function tech_priests_0301_normalise_quality_name(quality)
  if not quality then return nil end
  if type(quality) == "string" then return quality end
  if type(quality) == "table" then return quality.name or quality[1] end
  local ok, name = pcall(function() return quality.name end)
  if ok then return name end
  return nil
end

function tech_priests_0301_collect_inventory(inventory)
  local stacks = {}
  if not (inventory and inventory.valid) then return stacks end
  local ok, contents = pcall(function() return inventory.get_contents() end)
  if ok and contents then
    for key, value in pairs(contents) do
      local name, count, quality = nil, nil, nil
      if type(key) == "string" and type(value) == "number" then
        name, count = key, value
      elseif type(value) == "table" then
        name = value.name or value.item or value.item_name
        count = value.count or value.amount or value[2]
        quality = tech_priests_0301_normalise_quality_name(value.quality or value.quality_name)
      elseif type(key) == "table" then
        name = key.name or key.item or key.item_name
        count = value
        quality = tech_priests_0301_normalise_quality_name(key.quality or key.quality_name)
      end
      if name and count and count > 0 then
        stacks[#stacks + 1] = { name = name, count = count, quality = quality }
      end
    end
  else
    -- Fallback for unusual inventories: walk slots and merge equivalent stacks.
    local merged = {}
    local ok_slots, size = pcall(function() return #inventory end)
    if ok_slots and size then
      for i = 1, size do
        local stack = inventory[i]
        if stack and stack.valid_for_read then
          local q = tech_priests_0301_normalise_quality_name(stack.quality)
          local key = stack.name .. "|" .. tostring(q or "")
          local row = merged[key]
          if not row then
            row = { name = stack.name, count = 0, quality = q }
            merged[key] = row
            stacks[#stacks + 1] = row
          end
          row.count = row.count + (stack.count or 1)
        end
      end
    end
  end
  return stacks
end

function tech_priests_0301_restore_inventory(inventory, stacks)
  if not (inventory and inventory.valid and stacks) then return 0 end
  local inserted = 0
  pcall(function() inventory.clear() end)
  for _, stack in pairs(stacks or {}) do
    if stack and stack.name and (stack.count or 0) > 0 then
      local spec = { name = stack.name, count = stack.count }
      if stack.quality then spec.quality = stack.quality end
      local ok, n = pcall(function() return inventory.insert(spec) end)
      if not ok or not n or n == 0 then
        spec.quality = nil
        ok, n = pcall(function() return inventory.insert(spec) end)
      end
      inserted = inserted + (ok and tonumber(n) or 0)
    end
  end
  return inserted
end

function tech_priests_0301_make_preservation_record(pair, entity, reason)
  if not (entity and entity.valid) then return nil end
  local inv = get_station_inventory and get_station_inventory(entity) or nil
  local cell_name = nil
  if pair and get_pair_display_name then
    local ok, name = pcall(function() return get_pair_display_name(pair) end)
    if ok then cell_name = name end
  end
  if not cell_name and pair then cell_name = pair.cell_name end
  local record = {
    version = TECH_PRIESTS_VERSION_0301,
    reason = reason or "mined",
    tick = game and game.tick or 0,
    station_name = entity.name,
    force = entity.force and entity.force.name or nil,
    surface = entity.surface and entity.surface.name or nil,
    cell_name = cell_name,
    station_display_name = pair and pair.station_display_name or nil,
    priest_display_name = pair and pair.priest_display_name or nil,
    tier = pair and pair.tier or nil,
    radius = pair and pair.radius or nil,
    deploy_direction = pair and pair.deploy_direction or (entity.direction or nil),
    linked_health_ratio = pair and pair.linked_health_ratio or nil,
    persistent_id_0301 = pair and pair.persistent_id_0301 or ("cell-" .. tostring(entity.unit_number or "?") .. "-" .. tostring(game and game.tick or 0)),
    inventory = tech_priests_0301_collect_inventory(inv),
    future_equipment_grid = pair and pair.future_equipment_grid_0301 or nil
  }
  if not record.station_display_name and record.cell_name then record.station_display_name = "Cogitator Station " .. record.cell_name end
  if not record.priest_display_name and record.cell_name then record.priest_display_name = "Tech-Priest " .. record.cell_name end
  return record
end

function tech_priests_0301_pending_bucket()
  ensure_storage()
  storage.tech_priests.preserved_cells_pending_0301 = storage.tech_priests.preserved_cells_pending_0301 or {}
  storage.tech_priests.preserved_cells_by_entity_0301 = storage.tech_priests.preserved_cells_by_entity_0301 or {}
  return storage.tech_priests.preserved_cells_pending_0301
end

function tech_priests_0301_capture_pre_mine(event)
  local entity = event and event.entity
  if not (entity and entity.valid and is_station and is_station(entity) and entity.unit_number) then return end
  local pair = find_pair_for_entity and find_pair_for_entity(entity) or nil
  local record = tech_priests_0301_make_preservation_record(pair, entity, "pre-mine")
  if not record then return end
  local bucket = tech_priests_0301_pending_bucket()
  bucket[entity.unit_number] = record
end

function tech_priests_0301_describe_record(record)
  if not record then return nil end
  local inv_count = 0
  for _, stack in pairs(record.inventory or {}) do inv_count = inv_count + (tonumber(stack.count) or 0) end
  return (record.station_display_name or record.cell_name or "Preserved Cogitator Cell") .. "\nPreserved inventory stacks: " .. tostring(#(record.inventory or {})) .. " / items: " .. tostring(inv_count)
end

function tech_priests_0301_stack_supports_tags(stack)
  if not (stack and stack.valid_for_read) then return false end
  local ok = pcall(function()
    local old = stack.tags
    stack.tags = old or {}
  end)
  return ok
end

function tech_priests_0301_apply_record_to_stack(stack, record)
  if not (stack and stack.valid_for_read and record) then return false end
  if not tech_priests_0301_is_station_item_name(stack.name) then return false end
  local tags = nil
  local ok_read, old_tags = pcall(function() return stack.tags end)
  if ok_read and type(old_tags) == "table" then tags = old_tags else tags = {} end
  tags[TECH_PRIESTS_PRESERVATION_TAG_0301] = record
  local ok = pcall(function() stack.tags = tags end)
  pcall(function() stack.custom_description = tech_priests_0301_describe_record(record) end)
  pcall(function() stack.label = record.station_display_name or record.cell_name end)
  return ok
end

function tech_priests_0301_tag_mined_buffer(event)
  local unit = event and event.entity and event.entity.unit_number
  local bucket = tech_priests_0301_pending_bucket()
  local record = unit and bucket[unit] or nil
  if not record then return end
  bucket[unit] = nil
  local buffer = event.buffer
  if not (buffer and buffer.valid) then return end
  local applied = false
  for i = 1, #buffer do
    local stack = buffer[i]
    if stack and stack.valid_for_read and tech_priests_0301_is_station_item_name(stack.name) then
      applied = tech_priests_0301_apply_record_to_stack(stack, record) or applied
      if applied then break end
    end
  end
end

function tech_priests_0301_record_from_event_stack(event)
  local stack = event and event.stack
  if not (stack and stack.valid_for_read) then return nil end
  local ok, tags = pcall(function() return stack.tags end)
  if not (ok and type(tags) == "table") then return nil end
  local record = tags[TECH_PRIESTS_PRESERVATION_TAG_0301]
  if type(record) == "table" then return record end
  return nil
end

function tech_priests_0301_apply_record_to_pair(pair, record, reason)
  if not (pair and pair.station and pair.station.valid and record) then return false end
  ensure_storage()
  pair.cell_name = record.cell_name or pair.cell_name
  pair.station_display_name = record.station_display_name or pair.station_display_name
  pair.priest_display_name = record.priest_display_name or pair.priest_display_name
  pair.persistent_id_0301 = record.persistent_id_0301 or pair.persistent_id_0301
  pair.future_equipment_grid_0301 = record.future_equipment_grid or pair.future_equipment_grid_0301
  pair.deploy_direction = record.deploy_direction or pair.deploy_direction
  if record.radius then pair.radius = record.radius end
  if storage.tech_priests.used_cell_names and pair.cell_name then storage.tech_priests.used_cell_names[pair.cell_name] = true end
  if apply_pair_display_names then pcall(function() apply_pair_display_names(pair) end) end
  local inv = get_station_inventory and get_station_inventory(pair.station) or nil
  local inserted = tech_priests_0301_restore_inventory(inv, record.inventory or {})
  pair.preserved_cell_restored_0301 = {
    tick = game and game.tick or 0,
    reason = reason or "built-from-preserved-stack",
    inserted = inserted,
    stacks = #(record.inventory or {})
  }
  if pair.station and pair.station.valid then
    pcall(function() pair.station.backer_name = pair.station_display_name end)
  end
  if pair.priest and pair.priest.valid then
    pcall(function() pair.priest.backer_name = pair.priest_display_name end)
  end
  return true
end

TECH_PRIESTS_PRE_PRESERVATION_ON_REMOVED_0301 = tech_priests_on_removed_reimprint_wrapper_0298 or on_removed
function tech_priests_on_removed_preservation_wrapper_0301(event)
  if event and (event.name == defines.events.on_pre_player_mined_item or event.name == defines.events.on_robot_pre_mined) then
    tech_priests_0301_capture_pre_mine(event)
  end
  if TECH_PRIESTS_PRE_PRESERVATION_ON_REMOVED_0301 then return TECH_PRIESTS_PRE_PRESERVATION_ON_REMOVED_0301(event) end
end

TECH_PRIESTS_PRE_PRESERVATION_ON_BUILT_0301 = on_built
function on_built(event)
  local record = tech_priests_0301_record_from_event_stack(event)
  if TECH_PRIESTS_PRE_PRESERVATION_ON_BUILT_0301 then TECH_PRIESTS_PRE_PRESERVATION_ON_BUILT_0301(event) end
  local entity = event and (event.entity or event.created_entity or event.destination)
  if not (record and entity and entity.valid and is_station and is_station(entity)) then return end
  local pair = find_pair_for_entity and find_pair_for_entity(entity) or nil
  if pair then tech_priests_0301_apply_record_to_pair(pair, record, "on-built") end
end

if script and defines and defines.events then
  TechPriestsRuntimeEventRegistry.on_event({
    defines.events.on_entity_died,
    defines.events.on_pre_player_mined_item,
    defines.events.on_robot_pre_mined,
    defines.events.script_raised_destroy
  }, tech_priests_on_removed_preservation_wrapper_0301)

  TechPriestsRuntimeEventRegistry.on_event({
    defines.events.on_built_entity,
    defines.events.on_robot_built_entity,
    defines.events.script_raised_built,
    defines.events.script_raised_revive
  }, on_built)

  if defines.events.on_player_mined_entity then
    TechPriestsRuntimeEventRegistry.on_event(defines.events.on_player_mined_entity, tech_priests_0301_tag_mined_buffer)
  end
  if defines.events.on_robot_mined_entity then
    TechPriestsRuntimeEventRegistry.on_event(defines.events.on_robot_mined_entity, tech_priests_0301_tag_mined_buffer)
  end
end

if commands then
  TechPriestsDebugCommandRegistry.add("tp-preserve-0301", "Inspect or force-tag a preserved Cogitator cell item. Select a station to print its persistent identity.", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    if not (player and player.valid) then return end
    ensure_storage()
    local selected = player.selected
    if selected and selected.valid and is_station and is_station(selected) then
      local pair = find_pair_for_entity and find_pair_for_entity(selected) or nil
      if pair then
        local inv = get_station_inventory and get_station_inventory(selected) or nil
        local stacks = tech_priests_0301_collect_inventory(inv)
        player.print("[Tech Priests 0.1.301] " .. tostring(pair.station_display_name or pair.cell_name or selected.name) .. " persistent_id=" .. tostring(pair.persistent_id_0301 or "pending") .. " inventory_stacks=" .. tostring(#stacks))
      else
        player.print("[Tech Priests 0.1.301] Selected station has no pair yet.")
      end
      return
    end
    local cursor = player.cursor_stack
    if cursor and cursor.valid_for_read and tech_priests_0301_is_station_item_name(cursor.name) then
      local ok, tags = pcall(function() return cursor.tags end)
      local record = ok and type(tags) == "table" and tags[TECH_PRIESTS_PRESERVATION_TAG_0301] or nil
      if record then
        player.print("[Tech Priests 0.1.301] Cursor carries preserved cell: " .. tostring(record.station_display_name or record.cell_name) .. " stacks=" .. tostring(#(record.inventory or {})))
      else
        player.print("[Tech Priests 0.1.301] Cursor station item has no preservation tag yet.")
      end
      return
    end
    player.print("[Tech Priests 0.1.301] Select a Cogitator Station, or hold a mined Cogitator item on the cursor.")
  end)
end

log("[Tech-Priests 0.1.301] permanent named Cogitator cell preservation loaded")

-- ============================================================================
-- 0.1.302 Independent Priest Health + Fixed Armor Rank Profiles
-- ============================================================================
-- This pass deliberately severs the old percentage-linked health doctrine.  A
-- Cogitator Station and its Tech-Priest now keep separate health pools.  The
-- station still owns the cell: if the station is destroyed/mined, the existing
-- station-removal chain deletes or preserves the priest as appropriate.  Priest
-- death is handled by the 0.1.298 re-imprinting module.
--
-- Armor handling is also moved away from the force-wide "best armor applies to
-- everyone" mirror. Each priest tier has a fixed doctrinal armor equivalent:
-- Junior=heavy, Intermediate=modular, Senior=power armor, Planetary=Power Armor
-- Mk2, Void=Mech armor when present, otherwise Power Armor Mk2.  The runtime
-- mitigation remains because entity prototype resistances cannot be changed per
-- force after load, but the chosen armor is now rank-local and gate-checked.

TECH_PRIESTS_VERSION_0302 = "0.1.302"

-- Kill the old linked-health synchronizer without removing the helper name that
-- older wrappers call.  Leaving the symbol in place prevents nil-call failures
-- while making the operation intentionally inert.
TECH_PRIESTS_PRE_INDEPENDENT_SYNC_LINKED_HEALTH_0302 = sync_linked_health
function sync_linked_health(pair)
  if pair then
    pair.linked_health_ratio = nil
    pair.health_link_removed_0302 = true
  end
end

TECH_PRIESTS_0302_ARMOR_BY_PRIEST = {
  ["junior-tech-priest"] = "heavy-armor",
  ["junior-tech-priest-belt-immune"] = "heavy-armor",
  ["intermediate-tech-priest"] = "modular-armor",
  ["intermediate-tech-priest-belt-immune"] = "modular-armor",
  ["senior-tech-priest"] = "power-armor",
  ["senior-tech-priest-belt-immune"] = "power-armor",
  ["planetary-magos-tech-priest"] = "power-armor-mk2",
  ["planetary-magos-tech-priest-belt-immune"] = "power-armor-mk2",
  ["void-tech-priest"] = "mech-armor",
  ["void-tech-priest-belt-immune"] = "mech-armor",
}

TECH_PRIESTS_0302_GRID_BY_PRIEST = {
  ["junior-tech-priest"] = { width = 4, height = 4, label = "heavy-armor-equivalent" },
  ["junior-tech-priest-belt-immune"] = { width = 4, height = 4, label = "heavy-armor-equivalent" },
  ["intermediate-tech-priest"] = { width = 6, height = 4, label = "modular-armor-equivalent" },
  ["intermediate-tech-priest-belt-immune"] = { width = 6, height = 4, label = "modular-armor-equivalent" },
  ["senior-tech-priest"] = { width = 7, height = 7, label = "power-armor-equivalent" },
  ["senior-tech-priest-belt-immune"] = { width = 7, height = 7, label = "power-armor-equivalent" },
  ["planetary-magos-tech-priest"] = { width = 10, height = 10, label = "power-armor-mk2-equivalent" },
  ["planetary-magos-tech-priest-belt-immune"] = { width = 10, height = 10, label = "power-armor-mk2-equivalent" },
  ["void-tech-priest"] = { width = 10, height = 12, label = "void/mech-armor-equivalent" },
  ["void-tech-priest-belt-immune"] = { width = 10, height = 12, label = "void/mech-armor-equivalent" },
}

function tech_priests_0302_is_priest(entity)
  if not (entity and entity.valid and entity.name) then return false end
  if is_priest then
    local ok, result = pcall(is_priest, entity)
    if ok and result then return true end
  end
  return TECH_PRIESTS_0302_ARMOR_BY_PRIEST[entity.name] ~= nil
end

function tech_priests_0302_item_prototype(name)
  if not name then return nil end
  if tech_priests_get_item_prototype_0440 then return tech_priests_get_item_prototype_0440(name) end
  if prototypes and prototypes.item and prototypes.item[name] then return prototypes.item[name] end
  return nil
end

function tech_priests_0302_recipe_outputs_item(recipe, item_name)
  if not (recipe and item_name) then return false end
  if recipe.name == item_name then return true end
  local products = nil
  if not pcall(function() products = recipe.products end) then return false end
  local found = false
  pcall(function()
    for _, product in pairs(products or {}) do
      local name = type(product) == "table" and (product.name or product[1]) or product
      if name == item_name then found = true; break end
    end
  end)
  return found
end

function tech_priests_0302_force_can_use_armor(force, armor_name)
  if not (force and force.valid and armor_name) then return false end
  -- Treat missing mech armor as a Space-Age/vanilla compatibility fall-through.
  if armor_name == "mech-armor" and not tech_priests_0302_item_prototype("mech-armor") then
    armor_name = "power-armor-mk2"
  end
  local recipes = force.recipes
  if not recipes then return false end
  local direct = recipes[armor_name]
  if direct and direct.enabled then return true end
  local found = false
  pcall(function()
    for _, recipe in pairs(recipes) do
      if recipe and recipe.enabled and tech_priests_0302_recipe_outputs_item(recipe, armor_name) then found = true; break end
    end
  end)
  return found
end

function tech_priests_0302_resistance_type_name(key, entry)
  if type(entry) == "table" then return entry.type or entry.name or entry.damage_type or key end
  return key
end

function tech_priests_0302_collect_resistances(armor_name)
  if armor_name == "mech-armor" and not tech_priests_0302_item_prototype("mech-armor") then
    armor_name = "power-armor-mk2"
  end
  local proto = tech_priests_0302_item_prototype(armor_name)
  local raw = nil
  if not pcall(function() raw = proto and proto.resistances end) or not raw then return nil end
  local resistances = {}
  pcall(function()
    for key, entry in pairs(raw) do
      local dtype = tech_priests_0302_resistance_type_name(key, entry)
      if dtype then
        resistances[dtype] = {
          decrease = type(entry) == "table" and tonumber(entry.decrease or entry.flat or entry.damage_decrease or 0) or 0,
          percent = type(entry) == "table" and tonumber(entry.percent or entry.resistance or entry.damage_percent or 0) or 0
        }
      end
    end
  end)
  return resistances, armor_name
end

function tech_priests_0302_rank_armor_for_pair(pair, entity)
  local name = nil
  if entity and entity.valid then name = entity.name end
  if not name and pair and pair.priest and pair.priest.valid then name = pair.priest.name end
  if not name and pair and pair.rank_key then
    if pair.rank_key == "junior" then name = "junior-tech-priest" end
    if pair.rank_key == "intermediate" then name = "intermediate-tech-priest" end
    if pair.rank_key == "senior" then name = "senior-tech-priest" end
    if pair.rank_key == "planetary-magos" then name = "planetary-magos-tech-priest" end
    if pair.rank_key == "void" then name = "void-tech-priest" end
  end
  local armor = name and TECH_PRIESTS_0302_ARMOR_BY_PRIEST[name] or nil
  if armor == "mech-armor" and not tech_priests_0302_item_prototype("mech-armor") then armor = "power-armor-mk2" end
  return armor, name
end

function tech_priests_0302_refresh_pair_fixed_armor(pair, reason)
  if not pair then return nil end
  local entity = pair.priest and pair.priest.valid and pair.priest or nil
  local armor, priest_name = tech_priests_0302_rank_armor_for_pair(pair, entity)
  local force = (entity and entity.force) or (pair.station and pair.station.valid and pair.station.force) or nil
  local grid = priest_name and TECH_PRIESTS_0302_GRID_BY_PRIEST[priest_name] or nil
  pair.sub_equipment_grid_0302 = grid and { width = grid.width, height = grid.height, label = grid.label } or nil
  pair.health_link_removed_0302 = true
  pair.linked_health_ratio = nil
  if not (armor and force and tech_priests_0302_force_can_use_armor(force, armor)) then
    pair.sub_equipment_armor_profile_0297 = nil
    pair.fixed_armor_profile_0302 = { armor = armor, gated = true, reason = reason or "refresh", tick = game and game.tick or 0 }
    return nil
  end
  local resistances, effective_armor = tech_priests_0302_collect_resistances(armor)
  if not resistances then return nil end
  local profile = {
    name = effective_armor or armor,
    requested = armor,
    priest_name = priest_name,
    resistances = resistances,
    reason = reason or "refresh",
    tick = game and game.tick or 0,
    grid = pair.sub_equipment_grid_0302
  }
  pair.fixed_armor_profile_0302 = profile
  pair.sub_equipment_armor_profile_0297 = {
    name = profile.name,
    score = 0,
    reason = "fixed-rank-0302",
    tick = profile.tick,
    grid = profile.grid
  }
  return profile
end

function tech_priests_0302_damage_type(event)
  local dtype = nil
  pcall(function() dtype = event and event.damage_type and (event.damage_type.name or event.damage_type) end)
  return dtype or "physical"
end

function tech_priests_0302_mitigate_damage(event)
  local entity = event and event.entity
  if not tech_priests_0302_is_priest(entity) then return end
  if not (entity.health and entity.health > 0) then return end
  local pair = find_pair_for_entity and find_pair_for_entity(entity) or nil
  local profile = tech_priests_0302_refresh_pair_fixed_armor(pair, "damage")
  if not (profile and profile.resistances) then return end
  local dtype = tech_priests_0302_damage_type(event)
  local resistance = profile.resistances[dtype] or profile.resistances["physical"]
  if not resistance then return end
  local final_damage = tonumber(event.final_damage_amount or event.original_damage_amount or 0) or 0
  if final_damage <= 0 then return end
  local decrease = math.max(0, tonumber(resistance.decrease) or 0)
  local percent = math.max(0, math.min(100, tonumber(resistance.percent) or 0))
  local after_decrease = math.max(0, final_damage - decrease)
  local after_percent = after_decrease * (1 - (percent / 100))
  local prevented = final_damage - after_percent
  if prevented <= 0 then return end
  local max_health = nil
  pcall(function() max_health = entity.prototype and entity.prototype.max_health end)
  local new_health = entity.health + prevented
  if max_health then new_health = math.min(max_health, new_health) end
  entity.health = new_health
  if pair then
    pair.last_armor_mitigation_0297 = { tick = game.tick, armor = profile.name, damage_type = dtype, prevented = prevented, final_damage = final_damage, health = entity.health, fixed_rank = true }
    pair.last_armor_mitigation_0302 = pair.last_armor_mitigation_0297
  end
end

-- Replace the old universal armor mitigation handler with the fixed-rank one.
if script and defines and defines.events and defines.events.on_entity_damaged then
  TechPriestsRuntimeEventRegistry.on_event(defines.events.on_entity_damaged, tech_priests_0302_mitigate_damage)
end

-- Keep old public armor-refresh names alive, but make them refresh fixed rank
-- profiles instead of force-wide best-armor doctrine.
function tech_priests_0297_apply_force_armor_to_existing_priests(force, reason)
  if not (storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return end
  for _, pair in pairs(storage.tech_priests.pairs_by_station) do
    local pforce = (pair.priest and pair.priest.valid and pair.priest.force) or (pair.station and pair.station.valid and pair.station.force)
    if pforce == force then tech_priests_0302_refresh_pair_fixed_armor(pair, reason or "force-refresh-0302") end
  end
end

TECH_PRIESTS_PRE_INDEPENDENT_ENSURE_PAIR_PRIEST_0302 = ensure_pair_priest
if ensure_pair_priest then
  function ensure_pair_priest(pair, force_recall, immediate)
    local before = pair and pair.priest and pair.priest.valid and pair.priest.unit_number or nil
    local result = TECH_PRIESTS_PRE_INDEPENDENT_ENSURE_PAIR_PRIEST_0302(pair, force_recall, immediate)
    local after = pair and pair.priest and pair.priest.valid and pair.priest.unit_number or nil
    if pair then
      pair.linked_health_ratio = nil
      pair.health_link_removed_0302 = true
      tech_priests_0302_refresh_pair_fixed_armor(pair, before ~= after and "priest-created-0302" or "ensure-0302")
    end
    return result
  end
end

TechPriestsRuntimeEventRegistry.on_nth_tick(887, function()
  if not (storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return end
  for _, pair in pairs(storage.tech_priests.pairs_by_station) do
    if pair then
      pair.linked_health_ratio = nil
      pair.health_link_removed_0302 = true
      tech_priests_0302_refresh_pair_fixed_armor(pair, "periodic-0302")
    end
  end
end)

if commands and commands.add_command then
  pcall(function()
    TechPriestsDebugCommandRegistry.add("tp-armor-0302", "Tech Priests: inspect fixed rank armor and independent health state.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      if not player then return end
      local selected = player.selected
      local pair = selected and find_pair_for_entity and find_pair_for_entity(selected) or nil
      if not pair then player.print("[Tech Priests 0.1.302] Select a Cogitator Station or Tech-Priest first."); return end
      local profile = tech_priests_0302_refresh_pair_fixed_armor(pair, "debug-command")
      local grid = pair.sub_equipment_grid_0302
      local p_hp = pair.priest and pair.priest.valid and tech_priests_pair_health_0189 and tech_priests_pair_health_0189(pair.priest) or "dead/re-imprinting"
      local s_hp = pair.station and pair.station.valid and tech_priests_pair_health_0189 and tech_priests_pair_health_0189(pair.station) or "missing"
      player.print("[Tech Priests 0.1.302] station_hp=" .. tostring(s_hp) .. " priest_hp=" .. tostring(p_hp) .. " armor=" .. tostring(profile and profile.name or (pair.fixed_armor_profile_0302 and pair.fixed_armor_profile_0302.armor or "none")) .. " gated=" .. tostring(pair.fixed_armor_profile_0302 and pair.fixed_armor_profile_0302.gated or false) .. " grid=" .. tostring(grid and (grid.width .. "x" .. grid.height) or "nil") .. " linked_health_removed=" .. tostring(pair.health_link_removed_0302 == true))
    end)
  end)
end

if tech_priests_0264_log then
  pcall(function() tech_priests_0264_log("[0.1.302] independent priest health + fixed rank armor profiles loaded", true) end)
elseif log then
  log("[Tech-Priests 0.1.302] independent priest health + fixed rank armor profiles loaded")
end

-- ============================================================================
-- Tech Priests 0.1.305 - Cogitator-hosted sub-equipment manager
-- ============================================================================
-- Native Factorio equipment grids cannot be safely bolted directly onto a
-- container-style Cogitator Station without changing the station's prototype
-- family.  This module therefore treats the station inventory as the first
-- Cogitator equipment bay: personal equipment items stored in the station are
-- read, blacklisted/allowed by policy, capacity-checked against the rank grid
-- dimensions, and then applied to the linked Tech-Priest through runtime effects.
-- The data stage also defines the real equipment category/grid prototypes so the
-- eventual GUI/native-grid migration has a clean target.

TECH_PRIESTS_0305_EQUIPMENT_CATEGORY = "tech-priests-sub-equipment"
TECH_PRIESTS_0305_BLACKLIST_TYPES = {
  ["belt-immunity-equipment"] = true,
  ["night-vision-equipment"] = true,
  ["roboport-equipment"] = true,
}
TECH_PRIESTS_0305_ALLOW_TYPES = {
  ["active-defense-equipment"] = true,
  ["energy-shield-equipment"] = true,
  ["battery-equipment"] = true,
  ["movement-bonus-equipment"] = true,
  ["solar-panel-equipment"] = true,
  ["generator-equipment"] = true,
  ["inventory-bonus-equipment"] = true,
}
TECH_PRIESTS_0305_BLACKLIST_NAME_PARTS = {
  "belt%-immunity",
  "night%-vision",
  "roboport",
}
TECH_PRIESTS_0305_GRID_BY_PRIEST = {
  ["junior-tech-priest"] = { width = 4, height = 4, name = "tech-priests-junior-sub-equipment-grid", label = "Junior Sub-Equipment Grid" },
  ["junior-tech-priest-belt-immune"] = { width = 4, height = 4, name = "tech-priests-junior-sub-equipment-grid", label = "Junior Sub-Equipment Grid" },
  ["intermediate-tech-priest"] = { width = 6, height = 4, name = "tech-priests-intermediate-sub-equipment-grid", label = "Intermediate Sub-Equipment Grid" },
  ["intermediate-tech-priest-belt-immune"] = { width = 6, height = 4, name = "tech-priests-intermediate-sub-equipment-grid", label = "Intermediate Sub-Equipment Grid" },
  ["senior-tech-priest"] = { width = 7, height = 7, name = "tech-priests-senior-sub-equipment-grid", label = "Senior Sub-Equipment Grid" },
  ["senior-tech-priest-belt-immune"] = { width = 7, height = 7, name = "tech-priests-senior-sub-equipment-grid", label = "Senior Sub-Equipment Grid" },
  ["planetary-magos-tech-priest"] = { width = 10, height = 10, name = "tech-priests-planetary-magos-sub-equipment-grid", label = "Planetary Magos Sub-Equipment Grid" },
  ["planetary-magos-tech-priest-belt-immune"] = { width = 10, height = 10, name = "tech-priests-planetary-magos-sub-equipment-grid", label = "Planetary Magos Sub-Equipment Grid" },
  ["void-tech-priest"] = { width = 10, height = 12, name = "tech-priests-void-sub-equipment-grid", label = "Void Sub-Equipment Grid" },
  ["void-tech-priest-belt-immune"] = { width = 10, height = 12, name = "tech-priests-void-sub-equipment-grid", label = "Void Sub-Equipment Grid" },
}

function tech_priests_0305_string_contains_blacklist(name)
  if type(name) ~= "string" then return false end
  for _, pat in pairs(TECH_PRIESTS_0305_BLACKLIST_NAME_PARTS) do
    if string.find(name, pat) then return true end
  end
  return false
end

function tech_priests_0305_equipment_for_item(item_name)
  if type(item_name) ~= "string" then return nil end
  local item_proto = prototypes and prototypes.item and prototypes.item[item_name]
  if not item_proto then return nil end
  local equipment = nil
  pcall(function() equipment = item_proto.place_as_equipment_result end)
  if type(equipment) == "string" then
    equipment = prototypes and prototypes.equipment and prototypes.equipment[equipment] or nil
  end
  if not equipment then return nil end
  return equipment
end

function tech_priests_0305_equipment_allowed(item_name)
  local equipment = tech_priests_0305_equipment_for_item(item_name)
  if not equipment then return false, "not-equipment", nil end
  local etype = equipment.type
  local ename = equipment.name or item_name
  if TECH_PRIESTS_0305_BLACKLIST_TYPES[etype] or tech_priests_0305_string_contains_blacklist(ename) or tech_priests_0305_string_contains_blacklist(item_name) then
    return false, "blacklisted", equipment
  end
  if TECH_PRIESTS_0305_ALLOW_TYPES[etype] then
    return true, "allowed", equipment
  end
  return false, "unsupported-type:" .. tostring(etype), equipment
end

function tech_priests_0305_pair_grid(pair)
  if pair and pair.priest and pair.priest.valid then
    local grid = TECH_PRIESTS_0305_GRID_BY_PRIEST[pair.priest.name]
    if grid then return grid end
  end
  if pair and pair.station and pair.station.valid then
    local s = pair.station.name
    if s == "junior-cogitator-station" then return { width = 4, height = 4, name = "tech-priests-junior-sub-equipment-grid", label = "Junior Sub-Equipment Grid" } end
    if s == "intermediate-cogitator-station" then return { width = 6, height = 4, name = "tech-priests-intermediate-sub-equipment-grid", label = "Intermediate Sub-Equipment Grid" } end
    if s == "senior-cogitator-station" then return { width = 7, height = 7, name = "tech-priests-senior-sub-equipment-grid", label = "Senior Sub-Equipment Grid" } end
    if s == "planetary-magos-cogitator-station" then return { width = 10, height = 10, name = "tech-priests-planetary-magos-sub-equipment-grid", label = "Planetary Magos Sub-Equipment Grid" } end
    if s == "void-cogitator-station" then return { width = 10, height = 12, name = "tech-priests-void-sub-equipment-grid", label = "Void Sub-Equipment Grid" } end
  end
  return { width = 4, height = 4, name = "tech-priests-junior-sub-equipment-grid", label = "Junior Sub-Equipment Grid" }
end

function tech_priests_0305_equipment_area(equipment)
  local shape = nil
  pcall(function() shape = equipment.shape end)
  if shape and shape.width and shape.height then return math.max(1, shape.width * shape.height) end
  local w, h = nil, nil
  pcall(function() w = equipment.width end)
  pcall(function() h = equipment.height end)
  if w and h then return math.max(1, w * h) end
  return 1
end

function tech_priests_0305_equipment_energy_shield(equipment)
  local v = 0
  pcall(function() v = equipment.max_shield_value or 0 end)
  return tonumber(v) or 0
end

function tech_priests_0305_is_laser_equipment(equipment)
  local name = equipment and equipment.name or ""
  return type(name) == "string" and (string.find(name, "laser", 1, true) ~= nil)
end

function tech_priests_0305_is_discharge_equipment(equipment)
  local name = equipment and equipment.name or ""
  return type(name) == "string" and (string.find(name, "discharge", 1, true) ~= nil)
end

function tech_priests_0305_refresh_pair_equipment(pair, reason)
  if not (pair and pair.station and pair.station.valid) then return nil end
  local grid = tech_priests_0305_pair_grid(pair)
  local capacity = math.max(1, (grid.width or 4) * (grid.height or 4))
  local inv = pair.station.get_inventory and pair.station.get_inventory(defines.inventory.chest) or nil
  local summary = {
    tick = game and game.tick or 0,
    reason = reason or "refresh",
    grid = grid,
    capacity = capacity,
    used = 0,
    accepted = {},
    rejected = {},
    laser_count = 0,
    discharge_count = 0,
    shield_capacity = 0,
    exoskeleton_count = 0,
    battery_count = 0,
    toolbelt_count = 0,
  }
  if not inv or not inv.valid then
    pair.sub_equipment_0305 = summary
    return summary
  end
  local contents = inv.get_contents()
  for item_name, count in pairs(contents or {}) do
    local allowed, why, equipment = tech_priests_0305_equipment_allowed(item_name)
    if equipment then
      local area = tech_priests_0305_equipment_area(equipment)
      local fit_count = 0
      for i = 1, count do
        if allowed and (summary.used + area) <= capacity then
          summary.used = summary.used + area
          fit_count = fit_count + 1
          local etype = equipment.type
          if etype == "energy-shield-equipment" then
            summary.shield_capacity = summary.shield_capacity + tech_priests_0305_equipment_energy_shield(equipment)
          elseif etype == "movement-bonus-equipment" then
            summary.exoskeleton_count = summary.exoskeleton_count + 1
          elseif etype == "battery-equipment" then
            summary.battery_count = summary.battery_count + 1
          elseif etype == "inventory-bonus-equipment" then
            summary.toolbelt_count = summary.toolbelt_count + 1
          elseif etype == "active-defense-equipment" then
            if tech_priests_0305_is_discharge_equipment(equipment) then
              summary.discharge_count = summary.discharge_count + 1
            else
              summary.laser_count = summary.laser_count + 1
            end
          end
        else
          summary.rejected[#summary.rejected + 1] = { item = item_name, reason = allowed and "grid-full" or why, equipment = equipment.name, type = equipment.type }
        end
      end
      if fit_count > 0 then
        summary.accepted[#summary.accepted + 1] = { item = item_name, count = fit_count, equipment = equipment.name, type = equipment.type, area = area }
      end
    end
  end
  pair.sub_equipment_0305 = summary
  pair.sub_equipment_grid_0302 = grid and { width = grid.width, height = grid.height, label = grid.label, name = grid.name } or pair.sub_equipment_grid_0302
  pair.future_equipment_grid_0301 = pair.future_equipment_grid_0301 or {}
  pair.future_equipment_grid_0301.grid = grid.name
  pair.future_equipment_grid_0301.capacity = capacity
  pair.future_equipment_grid_0301.used = summary.used
  pair.future_equipment_grid_0301.accepted = summary.accepted
  pair.future_equipment_grid_0301.rejected = summary.rejected
  return summary
end

function tech_priests_0305_find_enemy_near(entity, radius)
  if not (entity and entity.valid and entity.surface) then return nil end
  local candidates = entity.surface.find_entities_filtered({ position = entity.position, radius = radius or 15 })
  local best, best_d2 = nil, nil
  for _, e in pairs(candidates or {}) do
    if e and e.valid and e.force and entity.force and e.force ~= entity.force then
      local enemy = false
      pcall(function() enemy = entity.force.get_cease_fire and (not entity.force.get_cease_fire(e.force)) or (e.force ~= entity.force) end)
      if enemy and e.health and e.health > 0 and e.destructible ~= false then
        local dx = (e.position.x or 0) - (entity.position.x or 0)
        local dy = (e.position.y or 0) - (entity.position.y or 0)
        local d2 = dx * dx + dy * dy
        if not best or d2 < best_d2 then best, best_d2 = e, d2 end
      end
    end
  end
  return best
end

function tech_priests_0305_apply_active_defense(pair)
  if not (pair and pair.priest and pair.priest.valid) then return end
  local summary = pair.sub_equipment_0305
  if not summary or (game.tick - (summary.tick or 0)) > 120 then
    summary = tech_priests_0305_refresh_pair_equipment(pair, "active-defense")
  end
  if not summary then return end
  local priest = pair.priest
  if (summary.laser_count or 0) > 0 then
    pair.next_sub_equipment_laser_tick_0305 = pair.next_sub_equipment_laser_tick_0305 or 0
    if game.tick >= pair.next_sub_equipment_laser_tick_0305 then
      pair.next_sub_equipment_laser_tick_0305 = game.tick + 30
      local target = nil
      if pair.active_task and pair.active_task.target and pair.active_task.target.valid then target = pair.active_task.target end
      if not target then target = tech_priests_0305_find_enemy_near(priest, 15) end
      if target and target.valid then
        pcall(function()
          target.damage(6 * (summary.laser_count or 1), priest.force, "laser", priest)
        end)
        pair.last_sub_equipment_attack_0305 = { tick = game.tick, type = "personal-laser-defense", count = summary.laser_count, target = target.name }
        if rendering and rendering.draw_line then
          pcall(function()
            rendering.draw_line({ color = { r = 0.8, g = 0.05, b = 1.0, a = 0.65 }, width = 2, from = priest.position, to = target.position, surface = priest.surface, time_to_live = 12, forces = { priest.force } })
          end)
        end
      end
    end
  end
  if (summary.discharge_count or 0) > 0 then
    pair.next_sub_equipment_discharge_tick_0305 = pair.next_sub_equipment_discharge_tick_0305 or 0
    if game.tick >= pair.next_sub_equipment_discharge_tick_0305 then
      local nearby = tech_priests_0305_find_enemy_near(priest, 5)
      if nearby then
        pair.next_sub_equipment_discharge_tick_0305 = game.tick + 300
        local entities = priest.surface.find_entities_filtered({ position = priest.position, radius = 5 })
        local hit = 0
        for _, e in pairs(entities or {}) do
          if e and e.valid and e.force and priest.force and e.force ~= priest.force then
            local enemy = false
            pcall(function() enemy = priest.force.get_cease_fire and (not priest.force.get_cease_fire(e.force)) or (e.force ~= priest.force) end)
            if enemy and e.health and e.health > 0 then
              pcall(function() e.damage(15 * (summary.discharge_count or 1), priest.force, "electric", priest) end)
              hit = hit + 1
            end
          end
        end
        pair.last_sub_equipment_attack_0305 = { tick = game.tick, type = "discharge-defense", count = summary.discharge_count, hit = hit }
        if rendering and rendering.draw_circle then
          pcall(function()
            rendering.draw_circle({ color = { r = 0.2, g = 0.7, b = 1.0, a = 0.35 }, radius = 5, width = 2, filled = false, target = priest, surface = priest.surface, time_to_live = 30, forces = { priest.force } })
          end)
        end
      end
    end
  end
end

TECH_PRIESTS_PRE_SUB_EQUIPMENT_DAMAGE_0305 = tech_priests_0302_mitigate_damage
function tech_priests_0305_on_entity_damaged(event)
  if TECH_PRIESTS_PRE_SUB_EQUIPMENT_DAMAGE_0305 then
    pcall(function() TECH_PRIESTS_PRE_SUB_EQUIPMENT_DAMAGE_0305(event) end)
  end
  local entity = event and event.entity
  if not (entity and entity.valid) then return end
  local pair = find_pair_for_entity and find_pair_for_entity(entity) or nil
  if not (pair and pair.priest and pair.priest.valid and entity == pair.priest) then return end
  local summary = pair.sub_equipment_0305
  if not summary or (game.tick - (summary.tick or 0)) > 120 then
    summary = tech_priests_0305_refresh_pair_equipment(pair, "shield-damage")
  end
  if not summary or (summary.shield_capacity or 0) <= 0 then return end
  pair.sub_equipment_shield_energy_0305 = pair.sub_equipment_shield_energy_0305 or summary.shield_capacity
  if pair.sub_equipment_shield_energy_0305 > summary.shield_capacity then pair.sub_equipment_shield_energy_0305 = summary.shield_capacity end
  local final_damage = tonumber(event.final_damage_amount) or tonumber(event.original_damage_amount) or 0
  if final_damage <= 0 then return end
  local prevent = math.min(pair.sub_equipment_shield_energy_0305, final_damage)
  if prevent <= 0 then return end
  pair.sub_equipment_shield_energy_0305 = pair.sub_equipment_shield_energy_0305 - prevent
  local max_health = nil
  pcall(function() max_health = entity.prototype and entity.prototype.max_health end)
  local new_health = entity.health + prevent
  if max_health then new_health = math.min(max_health, new_health) end
  entity.health = new_health
  pair.last_sub_equipment_shield_0305 = { tick = game.tick, prevented = prevent, remaining = pair.sub_equipment_shield_energy_0305, capacity = summary.shield_capacity }
end

if script and defines and defines.events and defines.events.on_entity_damaged then
  TechPriestsRuntimeEventRegistry.on_event(defines.events.on_entity_damaged, tech_priests_0305_on_entity_damaged)
end

TechPriestsRuntimeEventRegistry.on_nth_tick(83, function()
  if not (storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return end
  for _, pair in pairs(storage.tech_priests.pairs_by_station) do
    if pair and pair.station and pair.station.valid then
      if not pair.sub_equipment_0305 or (game.tick - (pair.sub_equipment_0305.tick or 0)) > 300 then
        tech_priests_0305_refresh_pair_equipment(pair, "periodic")
      end
      if pair.sub_equipment_0305 and (pair.sub_equipment_0305.shield_capacity or 0) > 0 then
        pair.sub_equipment_shield_energy_0305 = math.min(pair.sub_equipment_0305.shield_capacity, (pair.sub_equipment_shield_energy_0305 or 0) + math.max(1, pair.sub_equipment_0305.shield_capacity * 0.02))
      end
      tech_priests_0305_apply_active_defense(pair)
    end
  end
end)

TECH_PRIESTS_PRE_SUB_EQUIPMENT_ENSURE_PAIR_PRIEST_0305 = ensure_pair_priest
if ensure_pair_priest then
  function ensure_pair_priest(pair, force_recall, immediate)
    local result = TECH_PRIESTS_PRE_SUB_EQUIPMENT_ENSURE_PAIR_PRIEST_0305(pair, force_recall, immediate)
    if pair then tech_priests_0305_refresh_pair_equipment(pair, "ensure-priest") end
    return result
  end
end

if commands and commands.add_command then
  pcall(function()
    TechPriestsDebugCommandRegistry.add("tp-grid-0305", "Tech Priests: inspect Cogitator sub-equipment bay and applied priest effects.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      if not player then return end
      local selected = player.selected
      local pair = selected and find_pair_for_entity and find_pair_for_entity(selected) or nil
      if not pair then player.print("[Tech Priests 0.1.305] Select a Cogitator Station or Tech-Priest first."); return end
      local s = tech_priests_0305_refresh_pair_equipment(pair, "debug")
      local accepted = {}
      local rejected = {}
      for _, row in pairs(s.accepted or {}) do accepted[#accepted+1] = row.item .. "x" .. tostring(row.count) end
      for _, row in pairs(s.rejected or {}) do rejected[#rejected+1] = row.item .. ":" .. tostring(row.reason) end
      player.print("[Tech Priests 0.1.305] grid=" .. tostring(s.grid and (s.grid.width .. "x" .. s.grid.height) or "nil") .. " used=" .. tostring(s.used) .. "/" .. tostring(s.capacity) .. " shield=" .. tostring(math.floor(s.shield_capacity or 0)) .. " laser=" .. tostring(s.laser_count or 0) .. " discharge=" .. tostring(s.discharge_count or 0) .. " exo=" .. tostring(s.exoskeleton_count or 0) .. " toolbelt=" .. tostring(s.toolbelt_count or 0))
      player.print("[Tech Priests 0.1.305] accepted=" .. (#accepted > 0 and table.concat(accepted, ", ") or "none"))
      player.print("[Tech Priests 0.1.305] rejected=" .. (#rejected > 0 and table.concat(rejected, ", ") or "none"))
    end)
  end)
end

if tech_priests_0264_log then
  pcall(function() tech_priests_0264_log("[0.1.305] Cogitator-hosted sub-equipment manager loaded", true) end)
elseif log then
  log("[Tech-Priests 0.1.305] Cogitator-hosted sub-equipment manager loaded")
end


-- ============================================================================
-- Tech Priests 0.1.306 - visible Cogitator sub-equipment grid + mining hit pass
-- ============================================================================
-- 0.1.305 applied station-inventory equipment effects, but the player-facing
-- station GUI still looked like a plain container.  This pass adds a custom
-- Cogitator Equipment Grid panel that opens alongside the station and stores a
-- real per-cell bay on the pair.  Factorio still does not expose a native
-- equipment grid for container entities, so this is a scripted bay with vanilla
-- sprite-button slot behavior and the same 0.1.304 allow/deny policy.

TECH_PRIESTS_VERSION_0306 = "0.1.306"
TECH_PRIESTS_0306_GUI_FRAME = "tech_priests_0306_equipment_frame"
TECH_PRIESTS_0306_GUI_SLOT_PREFIX = "tech_priests_0306_equipment_slot_"
TECH_PRIESTS_0306_GUI_CLOSE = "tech_priests_0306_equipment_close"

function tech_priests_0306_log(msg)
  if tech_priests_0264_log then
    pcall(function() tech_priests_0264_log("[0.1.306] " .. tostring(msg), true) end)
  elseif log then
    log("[Tech-Priests 0.1.306] " .. tostring(msg))
  end
end

function tech_priests_0306_find_pair_from_player(player)
  if not player then return nil end
  if player.opened and player.opened.valid and find_pair_for_entity then
    local ok, pair = pcall(function() return find_pair_for_entity(player.opened) end)
    if ok and pair then return pair end
  end
  if player.selected and player.selected.valid and find_pair_for_entity then
    local ok, pair = pcall(function() return find_pair_for_entity(player.selected) end)
    if ok and pair then return pair end
  end
  return nil
end

function tech_priests_0306_slot_index(name)
  if type(name) ~= "string" then return nil end
  local raw = string.match(name, "^" .. TECH_PRIESTS_0306_GUI_SLOT_PREFIX .. "(%d+)$")
  return raw and tonumber(raw) or nil
end

function tech_priests_0306_equipment_area_for_item(item_name)
  if not (tech_priests_0305_equipment_for_item and tech_priests_0305_equipment_area) then return 1 end
  local equipment = tech_priests_0305_equipment_for_item(item_name)
  if not equipment then return 1 end
  local ok, area = pcall(function() return tech_priests_0305_equipment_area(equipment) end)
  if ok and area then return math.max(1, tonumber(area) or 1) end
  return 1
end

function tech_priests_0306_grid_capacity(pair)
  local grid = tech_priests_0305_pair_grid and tech_priests_0305_pair_grid(pair) or nil
  grid = grid or (pair and pair.sub_equipment_grid_0302) or { width = 4, height = 4, label = "Sub-Equipment Grid" }
  local width = math.max(1, tonumber(grid.width) or 4)
  local height = math.max(1, tonumber(grid.height) or 4)
  return grid, width, height, width * height
end

function tech_priests_0306_ensure_bay(pair)
  if not pair then return nil end
  local grid, width, height, capacity = tech_priests_0306_grid_capacity(pair)
  pair.sub_equipment_bay_0306 = pair.sub_equipment_bay_0306 or { slots = {}, width = width, height = height, capacity = capacity }
  local bay = pair.sub_equipment_bay_0306
  bay.slots = bay.slots or {}
  bay.width, bay.height, bay.capacity = width, height, capacity
  bay.grid_name = grid and grid.name or nil
  bay.grid_label = grid and grid.label or "Tech-Priest Sub-Equipment Grid"
  return bay
end

function tech_priests_0306_used_capacity(pair)
  local bay = tech_priests_0306_ensure_bay(pair)
  if not bay then return 0 end
  local used = 0
  for _, slot in pairs(bay.slots or {}) do
    if slot and slot.item then used = used + tech_priests_0306_equipment_area_for_item(slot.item) end
  end
  return used
end

function tech_priests_0306_can_place(pair, item_name, replacing_index)
  if not item_name then return false, "no-item" end
  local allowed, why = false, "no-policy"
  if tech_priests_0305_equipment_allowed then
    local ok, a, w = pcall(function() return tech_priests_0305_equipment_allowed(item_name) end)
    if ok then allowed, why = a, w end
  end
  if not allowed then return false, why or "not-allowed" end
  local bay = tech_priests_0306_ensure_bay(pair)
  if not bay then return false, "no-bay" end
  local used = 0
  for idx, slot in pairs(bay.slots or {}) do
    if slot and slot.item and tonumber(idx) ~= tonumber(replacing_index) then
      used = used + tech_priests_0306_equipment_area_for_item(slot.item)
    end
  end
  local area = tech_priests_0306_equipment_area_for_item(item_name)
  if used + area > (bay.capacity or 1) then return false, "grid-full" end
  return true, "ok"
end

function tech_priests_0306_clear_gui(player)
  if not (player and player.valid and player.gui and player.gui.screen) then return end
  local old = player.gui.screen[TECH_PRIESTS_0306_GUI_FRAME]
  if old then old.destroy() end
end

function tech_priests_0306_slot_sprite(slot)
  return slot and slot.item and ("item/" .. slot.item) or nil
end

function tech_priests_0306_open_gui(player, pair)
  if not (player and player.valid and pair and pair.station and pair.station.valid) then return end
  tech_priests_0306_clear_gui(player)
  local bay = tech_priests_0306_ensure_bay(pair)
  local grid, width, height, capacity = tech_priests_0306_grid_capacity(pair)
  local frame = player.gui.screen.add({ type = "frame", name = TECH_PRIESTS_0306_GUI_FRAME, direction = "vertical", caption = "Cogitator Sub-Equipment Grid" })
  frame.auto_center = false
  pcall(function() frame.location = { x = 920, y = 220 } end)
  local top = frame.add({ type = "flow", direction = "horizontal" })
  top.add({ type = "label", caption = tostring(pair.station_display_name or pair.station.backer_name or pair.station.name) })
  top.add({ type = "empty-widget", style = "draggable_space_header" }).style.horizontally_stretchable = true
  top.add({ type = "sprite-button", name = TECH_PRIESTS_0306_GUI_CLOSE, sprite = "utility/close", style = "frame_action_button" })
  local used = tech_priests_0306_used_capacity(pair)
  frame.add({ type = "label", caption = tostring(bay.grid_label or (grid and grid.label) or "Sub-Equipment Grid") .. "  " .. tostring(width) .. "x" .. tostring(height) .. "  used " .. tostring(used) .. "/" .. tostring(capacity) })
  local table_el = frame.add({ type = "table", name = "tech_priests_0306_grid_table", column_count = width })
  for i = 1, capacity do
    local slot = bay.slots[i]
    local btn = table_el.add({ type = "sprite-button", name = TECH_PRIESTS_0306_GUI_SLOT_PREFIX .. tostring(i), style = "slot_button" })
    local spr = tech_priests_0306_slot_sprite(slot)
    if spr then btn.sprite = spr end
    btn.tooltip = slot and slot.item and {"", "[item=", slot.item, "] ", slot.item, "\nClick to remove."} or "Drop allowed equipment here. Blacklisted: belt immunity, night vision, personal roboports."
  end
  local hint = frame.add({ type = "label", caption = "Cursor-click an empty cell to install. Click occupied cells to remove. Effects apply to the linked Tech-Priest." })
  pcall(function() hint.style.single_line = false; hint.style.maximal_width = 420 end)
  player.opened = frame
end

function tech_priests_0306_refresh_player_gui(player)
  local pair = tech_priests_0306_find_pair_from_player(player)
  if pair then tech_priests_0306_open_gui(player, pair) end
end

function tech_priests_0306_return_item_to_player(player, item)
  if not (player and item) then return false end
  local stack = player.cursor_stack
  if stack and stack.valid_for_read == false then
    local ok = pcall(function() stack.set_stack({ name = item, count = 1 }) end)
    if ok then return true end
  end
  local ok_insert = pcall(function() return player.insert({ name = item, count = 1 }) end)
  if ok_insert then return true end
  return false
end

function tech_priests_0306_gui_click(event)
  local player = event and event.player_index and game.get_player(event.player_index) or nil
  if not player then return end
  local element = event.element
  if not (element and element.valid) then return end
  if element.name == TECH_PRIESTS_0306_GUI_CLOSE then tech_priests_0306_clear_gui(player); return end
  local idx = tech_priests_0306_slot_index(element.name)
  if not idx then return end
  local pair = tech_priests_0306_find_pair_from_player(player)
  if not pair then player.print("[Tech Priests] No linked Cogitator pair found for equipment grid."); return end
  local bay = tech_priests_0306_ensure_bay(pair)
  if not bay then return end
  local slot = bay.slots[idx]
  if slot and slot.item then
    local item = slot.item
    bay.slots[idx] = nil
    tech_priests_0306_return_item_to_player(player, item)
    tech_priests_0305_refresh_pair_equipment(pair, "grid-remove")
    tech_priests_0306_open_gui(player, pair)
    return
  end
  local cursor = player.cursor_stack
  if not (cursor and cursor.valid_for_read and cursor.name) then return end
  local item = cursor.name
  local can, why = tech_priests_0306_can_place(pair, item, idx)
  if not can then player.print("[Tech Priests] Equipment rejected: " .. tostring(why)); return end
  bay.slots[idx] = { item = item }
  cursor.count = cursor.count - 1
  tech_priests_0305_refresh_pair_equipment(pair, "grid-insert")
  tech_priests_0306_open_gui(player, pair)
end

if script and defines and defines.events then
  TechPriestsGuiRouter.register("opened", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local entity = event and event.entity
    if player and entity and entity.valid and is_station and is_station(entity) then
      local pair = find_pair_for_entity and find_pair_for_entity(entity) or nil
      if pair then tech_priests_0306_open_gui(player, pair) end
    end
  end)
  TechPriestsGuiRouter.register("closed", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    if player then tech_priests_0306_clear_gui(player) end
  end)
  TechPriestsGuiRouter.register("click", tech_priests_0306_gui_click)
end

-- Replace the 0.1.305 station-inventory reader with a bay-first reader.  Legacy
-- equipment lying in station inventory is still accepted as overflow/compatibility
-- input, but the visible 0.1.306 grid is the authoritative equipment inventory.
TECH_PRIESTS_PRE_GRID_REFRESH_0306 = tech_priests_0305_refresh_pair_equipment
