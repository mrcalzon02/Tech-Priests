-- Auto-split control.lua fragment 021 for Tech Priests 0.1.438.
-- Generated mechanically from 0.1.437 monolithic control.lua.
-- Purpose: reduce Lua main-chunk local/register pressure without deleting behavior.

function tech_priests_0305_refresh_pair_equipment(pair, reason)
  if not (pair and pair.station and pair.station.valid) then return nil end
  local grid = tech_priests_0305_pair_grid and tech_priests_0305_pair_grid(pair) or { width = 4, height = 4, label = "Sub-Equipment Grid" }
  local capacity = math.max(1, (grid.width or 4) * (grid.height or 4))
  local bay = tech_priests_0306_ensure_bay(pair)
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
  local function add_equipment(item_name, source)
    local allowed, why, equipment = tech_priests_0305_equipment_allowed(item_name)
    if not equipment then return end
    local area = tech_priests_0305_equipment_area and tech_priests_0305_equipment_area(equipment) or 1
    if allowed and (summary.used + area) <= capacity then
      summary.used = summary.used + area
      local etype = equipment.type
      if etype == "energy-shield-equipment" then summary.shield_capacity = summary.shield_capacity + (tech_priests_0305_equipment_energy_shield and tech_priests_0305_equipment_energy_shield(equipment) or 0)
      elseif etype == "movement-bonus-equipment" then summary.exoskeleton_count = summary.exoskeleton_count + 1
      elseif etype == "battery-equipment" then summary.battery_count = summary.battery_count + 1
      elseif etype == "inventory-bonus-equipment" then summary.toolbelt_count = summary.toolbelt_count + 1
      elseif etype == "active-defense-equipment" then
        if tech_priests_0305_is_discharge_equipment and tech_priests_0305_is_discharge_equipment(equipment) then summary.discharge_count = summary.discharge_count + 1 else summary.laser_count = summary.laser_count + 1 end
      end
      summary.accepted[#summary.accepted + 1] = { item = item_name, count = 1, equipment = equipment.name, type = equipment.type, area = area, source = source or "grid" }
    else
      summary.rejected[#summary.rejected + 1] = { item = item_name, reason = allowed and "grid-full" or why, equipment = equipment.name, type = equipment.type, source = source or "grid" }
    end
  end
  for idx = 1, capacity do
    local slot = bay and bay.slots and bay.slots[idx]
    if slot and slot.item then add_equipment(slot.item, "visible-grid") end
  end
  pair.sub_equipment_0305 = summary
  pair.sub_equipment_grid_0302 = grid and { width = grid.width, height = grid.height, label = grid.label, name = grid.name } or pair.sub_equipment_grid_0302
  pair.future_equipment_grid_0301 = pair.future_equipment_grid_0301 or {}
  pair.future_equipment_grid_0301.grid = grid.name
  pair.future_equipment_grid_0301.capacity = capacity
  pair.future_equipment_grid_0301.used = summary.used
  pair.future_equipment_grid_0301.accepted = summary.accepted
  pair.future_equipment_grid_0301.rejected = summary.rejected
  pair.future_equipment_grid_0301.bay_slots = bay and bay.slots or nil
  return summary
end

if commands and commands.add_command then
  pcall(function()
    TechPriestsDebugCommandRegistry.add("tp-grid-0306", "Tech Priests: open/inspect the visible Cogitator sub-equipment grid for the selected station.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      if not player then return end
      local pair = tech_priests_0306_find_pair_from_player(player)
      if not pair then player.print("[Tech Priests 0.1.306] Select/open a Cogitator Station or linked Tech-Priest."); return end
      tech_priests_0306_open_gui(player, pair)
      local s = tech_priests_0305_refresh_pair_equipment(pair, "debug-0306")
      player.print("[Tech Priests 0.1.306] visible-grid=" .. tostring(s.grid and (s.grid.width .. "x" .. s.grid.height) or "nil") .. " used=" .. tostring(s.used) .. "/" .. tostring(s.capacity) .. " shield=" .. tostring(math.floor(s.shield_capacity or 0)) .. " laser=" .. tostring(s.laser_count or 0) .. " discharge=" .. tostring(s.discharge_count or 0))
    end)
  end)
end

tech_priests_0306_log("visible Cogitator equipment grid + honest direct mining damage loaded")


-- ============================================================================
-- 0.1.307 Priest ambient/mode glow doctrine
-- Adds a soft white cogitator-lantern glow to every active Tech-Priest and a
-- second colored glow keyed to the current task/mode.  Render objects are
-- refreshed on a slow cadence and TTL-expire, so stale lights do not linger if
-- a priest dies, re-imprints, or gets replaced.
-- ============================================================================
TECH_PRIESTS_GLOW_VERSION_0307 = "0.1.307"
TECH_PRIESTS_GLOW_REFRESH_TICKS_0307 = 19
TECH_PRIESTS_GLOW_TTL_0307 = 34
TECH_PRIESTS_WHITE_GLOW_COLOR_0307 = { r = 1.0, g = 0.96, b = 0.86, a = 0.62 }

function tech_priests_0307_log(msg)
  if log then log("[Tech-Priests 0.1.307] " .. tostring(msg)) end
end

function tech_priests_0307_safe_destroy_render(id)
  tech_priests_0309_destroy_render_object(id)
end

function tech_priests_0307_pair_live_priest(pair)
  if not (pair and pair.priest and pair.priest.valid) then return nil end
  if is_priest then
    local ok, result = pcall(is_priest, pair.priest)
    if ok and not result then return nil end
  end
  return pair.priest
end

function tech_priests_0307_pair_mode_text(pair)
  if not pair then return "idle" end
  local active = pair.active_task or pair.active_task_0285 or nil
  local parts = {}
  local function add(v)
    if v ~= nil then parts[#parts + 1] = string.lower(tostring(v)) end
  end
  add(pair.mode)
  add(pair.phase)
  add(pair.current_task)
  add(pair.priority)
  if active then
    add(active.type)
    add(active.kind)
    add(active.item)
    add(active.reason)
  end
  if pair.inventory_scan then add("inventory-scan") end
  if pair.scavenge then add("scavenge") end
  if pair.emergency_craft then add("craft") end
  if pair.reimprinting_0298 or pair.reimprint_0298 then add("reimprinting") end
  return table.concat(parts, " ")
end

function tech_priests_0307_mode_color(pair)
  local mode = tech_priests_0307_pair_mode_text(pair)

  -- Emergency/independent doctrines are intentionally alarming.
  if string.find(mode, "pinned") or string.find(mode, "no%-ammo") then
    return { r = 1.00, g = 0.08, b = 0.02, a = 0.78 }, "pinned/no-ammo"
  end
  if string.find(mode, "emergency") or string.find(mode, "independent") or string.find(mode, "survival") then
    return { r = 1.00, g = 0.10, b = 0.02, a = 0.70 }, "emergency"
  end
  if string.find(mode, "retreat") or string.find(mode, "reimprint") or string.find(mode, "recover") or string.find(mode, "healing") then
    return { r = 0.92, g = 0.15, b = 1.00, a = 0.66 }, "recovery"
  end

  -- Combat should read as weapon discipline rather than logistic work.
  if string.find(mode, "combat") or string.find(mode, "defend") or string.find(mode, "attack") or string.find(mode, "enemy") then
    return { r = 1.00, g = 0.22, b = 0.02, a = 0.70 }, "combat"
  end

  -- Service tasks.
  if string.find(mode, "repair") then
    return { r = 0.20, g = 1.00, b = 0.24, a = 0.64 }, "repair"
  end
  if string.find(mode, "sanct") or string.find(mode, "consecr") or string.find(mode, "oil") then
    return { r = 0.00, g = 0.95, b = 0.34, a = 0.64 }, "sanctification"
  end

  -- Radar/scanning/inventory reads are blue.
  if string.find(mode, "scan") or string.find(mode, "inventory") or string.find(mode, "radar") or string.find(mode, "survey") then
    return { r = 0.05, g = 0.42, b = 1.00, a = 0.62 }, "scan"
  end

  -- Acquisition/quarry/mining/scavenging are work lights: orange/amber.
  if string.find(mode, "mine") or string.find(mode, "quarry") or string.find(mode, "gather") or string.find(mode, "scavenge") or string.find(mode, "resource") or string.find(mode, "acquisition") then
    return { r = 1.00, g = 0.54, b = 0.05, a = 0.64 }, "acquisition"
  end
  if string.find(mode, "craft") or string.find(mode, "logistic") or string.find(mode, "supply") or string.find(mode, "request") or string.find(mode, "assignment") then
    return { r = 1.00, g = 0.74, b = 0.04, a = 0.62 }, "logistics/craft"
  end

  -- Idle/ordinary duty: muted Mechanicus green.
  return { r = 0.16, g = 0.88, b = 0.20, a = 0.50 }, "idle"
end

function tech_priests_0307_draw_light(pair, priest, color, scale, intensity, minimum_darkness)
  if not (rendering and rendering.draw_light and priest and priest.valid) then return nil end
  local ok, id = pcall(function()
    return rendering.draw_light{
      sprite = "utility/light_medium",
      target = priest,
      surface = priest.surface,
      color = color,
      scale = scale or 3.0,
      intensity = intensity or 0.35,
      minimum_darkness = minimum_darkness or 0.0,
      time_to_live = TECH_PRIESTS_GLOW_TTL_0307,
      forces = { priest.force },
      draw_on_ground = true,
    }
  end)
  if ok then return id end
  return nil
end

function tech_priests_0307_refresh_pair_glow(pair)
  local priest = tech_priests_0307_pair_live_priest(pair)
  if not priest then
    if pair then
      tech_priests_0307_safe_destroy_render(pair.glow_ambient_0307)
      tech_priests_0307_safe_destroy_render(pair.glow_mode_0307)
      pair.glow_ambient_0307 = nil
      pair.glow_mode_0307 = nil
      pair.glow_mode_name_0307 = nil
    end
    return
  end

  -- Kill previous short-TTL lights so the mode hue changes cleanly instead of
  -- stacking into soup when the scheduler changes state rapidly.
  tech_priests_0307_safe_destroy_render(pair.glow_ambient_0307)
  tech_priests_0307_safe_destroy_render(pair.glow_mode_0307)

  local color, mode_name = tech_priests_0307_mode_color(pair)
  pair.glow_mode_name_0307 = mode_name
  pair.glow_mode_color_0307 = color
  pair.glow_last_tick_0307 = game and game.tick or 0

  -- White player-like glow, then the task-color aura.  The colored aura is a
  -- little larger and dimmer so it reads like operating status rather than a
  -- harsh sprite overlay.
  pair.glow_ambient_0307 = tech_priests_0307_draw_light(pair, priest, TECH_PRIESTS_WHITE_GLOW_COLOR_0307, 2.15, 0.23, 0.0)
  pair.glow_mode_0307 = tech_priests_0307_draw_light(pair, priest, color, 3.35, 0.31, 0.0)
end

function tech_priests_0307_refresh_all_glows()
  if not (storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return end
  for _, pair in pairs(storage.tech_priests.pairs_by_station or {}) do
    tech_priests_0307_refresh_pair_glow(pair)
  end
end

TechPriestsRuntimeEventRegistry.on_nth_tick(TECH_PRIESTS_GLOW_REFRESH_TICKS_0307, function()
  tech_priests_0307_refresh_all_glows()
end)

if commands and commands.add_command then
  pcall(function()
    TechPriestsDebugCommandRegistry.add("tp-glow-0307", "Tech Priests: refresh and report ambient/mode glow for the selected station or priest.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      if not player then return end
      local pair = nil
      local selected = player.selected
      if selected and selected.valid then
        if is_station and is_station(selected) and storage and storage.tech_priests and storage.tech_priests.pairs_by_station then
          pair = storage.tech_priests.pairs_by_station[selected.unit_number]
        elseif is_priest and is_priest(selected) and find_pair_by_priest then
          pair = find_pair_by_priest(selected)
        end
      end
      if not pair then player.print("[Tech Priests 0.1.307] Select a Cogitator Station or linked Tech-Priest."); return end
      tech_priests_0307_refresh_pair_glow(pair)
      local color, mode_name = tech_priests_0307_mode_color(pair)
      player.print("[Tech Priests 0.1.307] glow mode=" .. tostring(mode_name) .. " raw='" .. tostring(tech_priests_0307_pair_mode_text(pair)) .. "' color=" .. tostring(color.r) .. "," .. tostring(color.g) .. "," .. tostring(color.b))
    end)
  end)
end

tech_priests_0307_log("ambient white priest glow + mode-colored operating aura loaded")


-- 0.1.308 LuaRendering validity crash guard
TechPriestsDebugCommandRegistry.add("tp-glow-0308", "Tech Priests: force-refresh glow and report LuaRendering-safe destroy status", function(event)
  local player = game and game.get_player(event.player_index) or nil
  if not player then return end
  local pair = nil
  if player.selected and find_pair_for_entity then
    local ok, found = pcall(find_pair_for_entity, player.selected)
    if ok then pair = found end
  end
  if pair then
    if tech_priests_0307_refresh_pair_glow then pcall(tech_priests_0307_refresh_pair_glow, pair) end
    player.print("[Tech Priests 0.1.308] glow refresh safe; mode=" .. tostring(pair.glow_mode_name_0307 or "unknown"))
  else
    player.print("[Tech Priests 0.1.308] select a Cogitator Station or linked Tech-Priest to inspect glow state.")
  end
end)

if log then log("[Tech-Priests 0.1.308] LuaRendering-safe glow destroy guard loaded") end


-- ============================================================================
-- 0.1.309 LuaRendering destroy/clear guard
-- ============================================================================
if log then log("[Tech-Priests 0.1.309] LuaRendering destroy/clear guard loaded") end


-- ============================================================================
-- 0.1.310 Station inventory reopening, ranked priest names, daytime glow shim,
-- and station-damage defensive guards.
-- This pass repairs the 0.1.306 GUI registration that replaced older GUI
-- handlers and stole the normal chest/opened inventory by setting player.opened
-- to the scripted equipment frame.
-- ============================================================================
TECH_PRIESTS_PATCH_VERSION_0310 = "0.1.310"

function tech_priests_0310_log(msg)
  if log then log("[Tech-Priests 0.1.310] " .. tostring(msg)) end
end

function tech_priests_0310_rank_title_for_pair(pair)
  local name = nil
  if pair and pair.priest and pair.priest.valid then name = pair.priest.name end
  if not name and pair and pair.rank_key then name = tostring(pair.rank_key) end
  name = tostring(name or "")
  if string.find(name, "planetary%-magos") or string.find(name, "planetary_magos") then return "Planetary Magos" end
  if string.find(name, "void") then return "Void Tech-Priest" end
  if string.find(name, "senior") then return "Senior Tech-Priest" end
  if string.find(name, "intermediate") then return "Intermediate Tech-Priest" end
  if string.find(name, "junior") then return "Junior Tech-Priest" end
  return "Tech-Priest"
end

function tech_priests_0310_strip_old_priest_rank_prefix(text)
  text = tostring(text or "")
  local patterns = {
    "^Junior Tech%-Priest%s+", "^Intermediate Tech%-Priest%s+", "^Senior Tech%-Priest%s+",
    "^Planetary Magos%s+", "^Void Tech%-Priest%s+", "^Tech%-Priest%s+"
  }
  for _, pat in pairs(patterns) do text = string.gsub(text, pat, "") end
  return text
end

TECH_PRIESTS_PRE_RANKED_NAMES_0310 = apply_pair_display_names
function apply_pair_display_names(pair)
  if TECH_PRIESTS_PRE_RANKED_NAMES_0310 then pcall(function() TECH_PRIESTS_PRE_RANKED_NAMES_0310(pair) end) end
  if not pair then return end
  local cell_name = get_pair_display_name and get_pair_display_name(pair) or pair.cell_name or "Uncatalogued"
  if not pair.station_display_name or tostring(pair.station_display_name) == "" then
    pair.station_display_name = "Cogitator Station " .. tostring(cell_name)
  end
  local title = tech_priests_0310_rank_title_for_pair(pair)
  local base = tech_priests_0310_strip_old_priest_rank_prefix(pair.priest_display_name or pair.cell_name or cell_name)
  if base == "" then base = tostring(cell_name) end
  pair.priest_display_name = title .. " " .. base
  pair.player_facing_priest_name_0218 = pair.priest_display_name
  pair.player_facing_station_name_0218 = pair.station_display_name
  if pair.station and pair.station.valid then pcall(function() pair.station.backer_name = pair.station_display_name end) end
  if pair.priest and pair.priest.valid then pcall(function() pair.priest.backer_name = pair.priest_display_name end) end
end

-- Reopen the visible grid as a side-panel only.  Do not assign player.opened to
-- the scripted frame; that closes/steals the real Cogitator Station inventory.
TECH_PRIESTS_PRE_OPEN_GRID_0306_FOR_0310 = tech_priests_0306_open_gui
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
  local hint = frame.add({ type = "label", caption = "Cursor-click an empty cell to install. Click occupied cells to remove. The real Cogitator inventory remains the opened entity inventory." })
  pcall(function() hint.style.single_line = false; hint.style.maximal_width = 420 end)
  -- Deliberately no: player.opened = frame
end

function tech_priests_0310_find_pair_from_event_entity(entity)
  if not (entity and entity.valid) then return nil end
  if find_pair_for_entity then
    local ok, pair = pcall(function() return find_pair_for_entity(entity) end)
    if ok and pair then return pair end
  end
  if is_station and is_station(entity) and storage and storage.tech_priests and storage.tech_priests.pairs_by_station then
    return storage.tech_priests.pairs_by_station[entity.unit_number]
  end
  return nil
end

function tech_priests_0310_handle_overview_click(event)
  local element = event and event.element
  if not (element and element.valid) then return false end
  local name = element.name or ""
  local player = event.player_index and game.get_player(event.player_index) or nil
  if not (player and player.valid) then return false end
  if not (TECH_PRIESTS_COMMAND_OVERVIEW_PREFIX_0189 and tech_priests_build_command_overview_0189) then return false end
  if name == TECH_PRIESTS_COMMAND_OVERVIEW_CLOSE_0189 then
    if tech_priests_destroy_command_overview_0189 then tech_priests_destroy_command_overview_0189(player) end
    return true
  end
  if name == TECH_PRIESTS_COMMAND_OVERVIEW_REFRESH_0189 then
    tech_priests_build_command_overview_0189(player)
    return true
  end
  if name == TECH_PRIESTS_COMMAND_OVERVIEW_EMERGENCY_TOGGLE_0190 then
    local rows = tech_priests_valid_pairs_for_player_0189(player)
    local pair = tech_priests_get_selected_pair_0189(player, rows)
    if pair and tech_priests_set_emergency_operation_0184 and tech_priests_get_emergency_operation_0184 then
      local enable = tech_priests_get_emergency_operation_0184(pair) == nil
      if tech_priests_set_emergency_operation_0184(pair, enable, "overview-ui") then
        player.print({ "", "[Tech-Priest Command] Independent / emergency doctrine ", enable and "enabled" or "disabled", " for ", tech_priests_station_name_0189(pair), "." })
      end
    end
    tech_priests_build_command_overview_0189(player)
    return true
  end
  if name == TECH_PRIESTS_COMMAND_OVERVIEW_EMERGENCY_AUTO_0190 then
    local rows = tech_priests_valid_pairs_for_player_0189(player)
    local pair = tech_priests_get_selected_pair_0189(player, rows)
    if pair then
      pair.emergency_operation_auto_allowed_0190 = true
      player.print({ "", "[Tech-Priest Command] Frustration auto-enable is authorized for ", tech_priests_station_name_0189(pair), "." })
    end
    tech_priests_build_command_overview_0189(player)
    return true
  end
  if string.sub(name, 1, #TECH_PRIESTS_COMMAND_OVERVIEW_PREFIX_0189) == TECH_PRIESTS_COMMAND_OVERVIEW_PREFIX_0189 then
    local rest = string.sub(name, #TECH_PRIESTS_COMMAND_OVERVIEW_PREFIX_0189 + 1)
    local center = false
    if string.sub(rest, -7) == "_center" then center = true; rest = string.sub(rest, 1, -8) end
    local station_unit = tonumber(rest)
    if station_unit and storage and storage.tech_priests and storage.tech_priests.pairs_by_station then
      local pair = storage.tech_priests.pairs_by_station[station_unit]
      if pair and pair.station and pair.station.valid and pair.station.force == player.force then
        tech_priests_command_overview_storage_0189()[player.index] = station_unit
        if tech_priests_command_overview_set_selected_tab_0371 then tech_priests_command_overview_set_selected_tab_0371(player, "roster") end
        if center then
          local loc_entity = pair.priest and pair.priest.valid and pair.priest or pair.station
          player.print({ "", "[Tech-Priest Command] ", tech_priests_pair_name_0189(pair), " is on ", loc_entity.surface.name, " at ", tech_priests_entity_coord_0189(loc_entity), "." })
        end
        tech_priests_build_command_overview_0189(player)
      end
    end
    return true
  end
  return false
end

function tech_priests_0310_on_gui_opened(event)
  if tech_priests_on_gui_opened_0184 then pcall(function() tech_priests_on_gui_opened_0184(event) end) end
  local player = event and event.player_index and game.get_player(event.player_index) or nil
  local entity = event and event.entity or nil
  if not (player and player.valid and entity and entity.valid) then return end
  if is_station and is_station(entity) then
    local pair = tech_priests_0310_find_pair_from_event_entity(entity)
    if pair then
      if apply_pair_display_names then pcall(function() apply_pair_display_names(pair) end) end
      -- Side panel only; vanilla chest inventory remains open.
      tech_priests_0306_open_gui(player, pair)
    end
  end
end

function tech_priests_0310_on_gui_closed(event)
  if tech_priests_on_gui_closed_0184 then pcall(function() tech_priests_on_gui_closed_0184(event) end) end
  local player = event and event.player_index and game.get_player(event.player_index) or nil
  if player then tech_priests_0306_clear_gui(player) end
end

function tech_priests_0310_on_gui_click(event)
  if tech_priests_on_gui_click_0184 then pcall(function() tech_priests_on_gui_click_0184(event) end) end
  if tech_priests_0310_handle_overview_click(event) then return end
  if tech_priests_0306_gui_click then pcall(function() tech_priests_0306_gui_click(event) end) end
end

-- Re-register the GUI family after 0.1.306 so the scripted grid cooperates with
-- the normal inventory and older GUI/button handlers instead of replacing them.
if script and defines and defines.events then
  TechPriestsGuiRouter.register("opened", tech_priests_0310_on_gui_opened)
  TechPriestsGuiRouter.register("closed", tech_priests_0310_on_gui_closed)
  TechPriestsGuiRouter.register("click", tech_priests_0310_on_gui_click)
end

-- Daylight-visible glow shim.  Factorio lights can be hard to see in sandbox
-- noon, so draw a short-lived translucent sprite aura in addition to the actual
-- light.  Use protected method lookups because LuaRendering methods vary between
-- 1.1/2.0 and direct missing-key reads can crash.
function tech_priests_0310_rendering_method(name)
  if tech_priests_0309_rendering_method then return tech_priests_0309_rendering_method(name) end
  if not rendering then return nil end
  local ok, fn = pcall(function() return rendering[name] end)
  if ok and type(fn) == "function" then return fn end
  return nil
end

function tech_priests_0310_draw_glow_sprite(priest, color, scale, ttl)
  local draw_sprite = tech_priests_0310_rendering_method("draw_sprite")
  if not (draw_sprite and priest and priest.valid) then return nil end
  local ok, obj = pcall(function()
    return draw_sprite({
      sprite = "utility/light_medium",
      target = priest,
      surface = priest.surface,
      tint = color,
      x_scale = scale or 2.0,
      y_scale = scale or 2.0,
      render_layer = "light-effect",
      time_to_live = ttl or 34,
      forces = { priest.force },
      draw_on_ground = true,
    })
  end)
  if ok then return obj end
  return nil
end

TECH_PRIESTS_PRE_GLOW_REFRESH_0307_FOR_0310 = tech_priests_0307_refresh_pair_glow
function tech_priests_0307_refresh_pair_glow(pair)
  if TECH_PRIESTS_PRE_GLOW_REFRESH_0307_FOR_0310 then pcall(function() TECH_PRIESTS_PRE_GLOW_REFRESH_0307_FOR_0310(pair) end) end
  local priest = tech_priests_0307_pair_live_priest and tech_priests_0307_pair_live_priest(pair) or (pair and pair.priest and pair.priest.valid and pair.priest or nil)
  if not priest then
    if pair then
      tech_priests_0309_destroy_render_object(pair.glow_day_ambient_0310)
      tech_priests_0309_destroy_render_object(pair.glow_day_mode_0310)
      pair.glow_day_ambient_0310 = nil
      pair.glow_day_mode_0310 = nil
    end
    return
  end
  tech_priests_0309_destroy_render_object(pair.glow_day_ambient_0310)
  tech_priests_0309_destroy_render_object(pair.glow_day_mode_0310)
  local color, mode_name
  if tech_priests_0307_mode_color then
    local ok_color, c, m = pcall(function() return tech_priests_0307_mode_color(pair) end)
    if ok_color and c then
      color, mode_name = c, m
    end
  end
  color = color or { r = 0.2, g = 1.0, b = 0.2, a = 0.35 }
  mode_name = mode_name or "idle"
  local white = { r = 1.0, g = 0.96, b = 0.86, a = 0.18 }
  local mode_color = { r = color.r or 0.2, g = color.g or 1.0, b = color.b or 0.2, a = math.min(0.35, (color.a or 0.5) * 0.45) }
  pair.glow_day_ambient_0310 = tech_priests_0310_draw_glow_sprite(priest, white, 1.65, 38)
  pair.glow_day_mode_0310 = tech_priests_0310_draw_glow_sprite(priest, mode_color, 2.25, 38)
  pair.glow_mode_name_0307 = mode_name
end

-- Fast-forward/siege safety: avoid thousands of expensive station-damage side
-- effects while biters are chewing stations.  This does not change gameplay; it
-- only rate-limits the newest debug/glow/grid refresh layers that can be called
-- indirectly during combat/damage storms.
function tech_priests_0310_note_station_damage(event)
  local entity = event and event.entity
  if not (entity and entity.valid and is_station and is_station(entity)) then return end
  local pair = tech_priests_0310_find_pair_from_event_entity(entity)
  if not pair then return end
  pair.last_station_damage_tick_0310 = game.tick
  pair.station_damage_guard_until_0310 = math.max(pair.station_damage_guard_until_0310 or 0, game.tick + 30)
end

TECH_PRIESTS_PRE_DAMAGE_0305_FOR_0310 = tech_priests_0305_on_entity_damaged
function tech_priests_0310_on_entity_damaged(event)
  tech_priests_0310_note_station_damage(event)
  if TECH_PRIESTS_PRE_DAMAGE_0305_FOR_0310 then return TECH_PRIESTS_PRE_DAMAGE_0305_FOR_0310(event) end
end

if defines and defines.events and defines.events.on_entity_damaged then
  TechPriestsRuntimeEventRegistry.on_event(defines.events.on_entity_damaged, tech_priests_0310_on_entity_damaged)
end

-- Debug command for the reopened inventory/grid issue.
if commands and commands.add_command then
  pcall(function()
    TechPriestsDebugCommandRegistry.add("tp-gui-0310", "Tech Priests: report/open station inventory side-grid status for selected Cogitator Station.", function(event)
      local player = game.get_player(event.player_index)
      if not player then return end
      local pair = nil
      if player.selected and player.selected.valid then pair = tech_priests_0310_find_pair_from_event_entity(player.selected) end
      if not pair then player.print("[Tech Priests 0.1.310] Select a Cogitator Station."); return end
      apply_pair_display_names(pair)
      tech_priests_0306_open_gui(player, pair)
      player.print("[Tech Priests 0.1.310] station=" .. tostring(pair.station_display_name) .. " priest=" .. tostring(pair.priest_display_name) .. " grid side-panel opened; click station normally for real inventory.")
    end)
  end)
end

tech_priests_0310_log("station inventory + side equipment grid GUI chain, ranked priest names, daytime glow shim, and station-damage guard loaded")


-- 0.1.311: station/chest GUI and glow syntax crash repair marker.
TechPriestsDebugCommandRegistry.add("tp-0311", "Tech Priests 0.1.311 diagnostics marker", function(cmd)
  local p = game and game.players and game.players[cmd.player_index]
  if p then p.print("[Tech-Priests 0.1.311] syntax guard loaded; rank-tinted Cogitator prototypes active after restart.") end
end)

-- -----------------------------------------------------------------------------
-- 0.1.312 mining-laser fallback weapon + preserved cell display labels
-- -----------------------------------------------------------------------------
-- The Tech-Priest quarry/mining beam should be the same family of effect as the
-- personal point-defense laser: a small, slow laser pulse that actually damages
-- what it is pointing at.  It also becomes the no-ammunition fallback weapon so
-- priests are never completely helpless when their Cogitator shrine is empty of
-- magazines.  This is intentionally weak and cadence-limited.

TECH_PRIESTS_PATCH_0312 = "0.1.312-mining-laser-fallback-weapon"
TECH_PRIESTS_0312_MINING_LASER_DAMAGE = 5
TECH_PRIESTS_0312_MINING_LASER_TICKS = 15
TECH_PRIESTS_0312_FALLBACK_LASER_TICKS = 30
TECH_PRIESTS_0312_FALLBACK_LASER_RANGE = TECH_PRIESTS_POINT_BLANK_LASER_RANGE or 1.5

function tech_priests_0312_log(msg)
  if tech_priests_0264_log then
    pcall(function() tech_priests_0264_log("[0.1.312] " .. tostring(msg), true) end)
  elseif log then
    log("[Tech-Priests 0.1.312] " .. tostring(msg))
  end
end

function tech_priests_0312_valid_pair(pair)
  return pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid
end

function tech_priests_0312_item_exists(name)
  if not (name and name ~= "") then return false end
  if prototypes then
    local ok, proto = pcall(function() return prototypes.item[name] end)
    if ok and proto then return true end
  end
  if tech_priests_get_item_prototype_0440 and tech_priests_get_item_prototype_0440(name) then return true end
  return false
end

function tech_priests_0312_station_has_ammo(pair)
  if not (pair and pair.station and pair.station.valid) then return false end
  if count_station_ammo_items then
    local ok, n = pcall(function() return count_station_ammo_items(pair.station) end)
    if ok and n and n > 0 then return true end
  end
  local inv = get_station_inventory and get_station_inventory(pair.station) or nil
  if inv and find_ammo_item then
    local ok, ammo = pcall(function() return find_ammo_item(inv) end)
    if ok and ammo then return true end
  end
  if inv then
    local common = { "firearm-magazine", "piercing-rounds-magazine", "uranium-rounds-magazine" }
    for _, item in pairs(common) do
      if tech_priests_0312_item_exists(item) then
        local ok, count = pcall(function() return inv.get_item_count(item) end)
        if ok and count and count > 0 then return true end
      end
    end
  end
  return false
end

function tech_priests_0312_proxy_has_ammo(pair)
  if not (pair and pair.proxy and pair.proxy.valid) then return false end
  if get_turret_ammo_inventory and turret_inventory_has_ammo then
    local ok, inv = pcall(function() return get_turret_ammo_inventory(pair.proxy) end)
    if ok and inv then
      local ok2, has = pcall(function() return turret_inventory_has_ammo(inv) end)
      if ok2 and has then return true end
    end
  end
  return false
end

function tech_priests_0312_has_ballistic_ammo(pair)
  return tech_priests_0312_station_has_ammo(pair) or tech_priests_0312_proxy_has_ammo(pair)
end

function tech_priests_0312_radius(pair)
  if refresh_pair_radius then
    local ok, r = pcall(function() return refresh_pair_radius(pair) end)
    if ok and r then return r end
  end
  return pair and (pair.radius or COMBAT_FIRE_RANGE or TECH_PRIESTS_0312_FALLBACK_LASER_RANGE) or TECH_PRIESTS_0312_FALLBACK_LASER_RANGE
end

function tech_priests_0312_is_hostile(entity, force)
  if not (entity and entity.valid and entity.force and force) then return false end
  if entity.force == force then return false end
  local hostile = false
  local ok = pcall(function() hostile = force.is_enemy and force.is_enemy(entity.force) end)
  if ok and hostile then return true end
  ok = pcall(function() hostile = entity.force.is_enemy and entity.force.is_enemy(force) end)
  if ok and hostile then return true end
  return entity.force ~= force
end

function tech_priests_0312_find_enemy(pair, radius)
  if not tech_priests_0312_valid_pair(pair) then return nil end
  local priest = pair.priest
  local old = pair.combat_target or pair.target
  if old and old.valid and tech_priests_0312_is_hostile(old, priest.force) then return old end
  if find_enemy_target then
    local ok, target = pcall(function() return find_enemy_target(pair.station, radius or tech_priests_0312_radius(pair), priest) end)
    if ok and target and target.valid then return target end
  end
  local found = nil
  local ok = pcall(function()
    found = priest.surface.find_entities_filtered({ position = priest.position, radius = radius or tech_priests_0312_radius(pair), type = { "unit", "unit-spawner", "turret", "spider-vehicle" }, limit = 64 })
  end)
  if ok and found then
    local best, best_d2 = nil, nil
    for _, e in pairs(found) do
      if e and e.valid and tech_priests_0312_is_hostile(e, priest.force) then
        local dx = (e.position.x or 0) - (priest.position.x or 0)
        local dy = (e.position.y or 0) - (priest.position.y or 0)
        local d2 = dx * dx + dy * dy
        if not best_d2 or d2 < best_d2 then best, best_d2 = e, d2 end
      end
    end
    return best
  end
  return nil
end

function tech_priests_0312_fire_laser(priest, target, damage, reason, color)
  if not (priest and priest.valid and target and target.valid) then return false end
  damage = math.max(1, damage or TECH_PRIESTS_0312_MINING_LASER_DAMAGE)
  color = color or { r = 0.95, g = 0.25, b = 0.05, a = 0.75 }
  local ok_damage = pcall(function()
    if target.valid and target.health and target.health > 0 then
      target.damage(damage, priest.force, "laser", priest)
    elseif target.valid and target.type == "resource" then
      local amount = target.amount or 0
      if amount > 1 then target.amount = math.max(1, amount - damage) end
    end
  end)
  if rendering then
    pcall(function()
      rendering.draw_line({ color = color, width = 2, from = priest.position, to = target.position, surface = priest.surface, time_to_live = 12, forces = { priest.force } })
    end)
    pcall(function()
      rendering.draw_circle({ color = { r = color.r or 1, g = color.g or 0.5, b = color.b or 0.1, a = 0.18 }, radius = 0.35, width = 1, filled = true, target = target, surface = priest.surface, time_to_live = 8, forces = { priest.force } })
    end)
  end
  if spawn_emergency_craft_smoke then
    pcall(function() spawn_emergency_craft_smoke({ priest = priest, station = nil }, target.position, false) end)
  elseif priest.surface and priest.surface.create_trivial_smoke then
    pcall(function() priest.surface.create_trivial_smoke({ name = "smoke-fast", position = target.position }) end)
  end
  return ok_damage
end

function tech_priests_0312_service_direct_current(pair, task)
  local cur = task and task.current or nil
  if not cur then return false end
  if cur.kind ~= "direct-mine-0273" and cur.kind ~= "direct-dirt-0273" then return false end
  if not tech_priests_0312_valid_pair(pair) then return false end
  local priest = pair.priest
  local pos = cur.position or (cur.entity and cur.entity.valid and cur.entity.position) or pair.station.position
  local dx = priest.position.x - pos.x
  local dy = priest.position.y - pos.y
  if dx * dx + dy * dy > (EMERGENCY_CRAFT_PICKUP_DISTANCE_SQ or 2.25) then
    pcall(function()
      if tech_priests_request_movement_0418 then
        tech_priests_request_movement_0418(pair, pos, "legacy-direct-gather-0312", { radius = 0.75, owner = "direct-gather-0312", priority = 55, distraction = defines.distraction.by_enemy })
      else
        priest.set_command({ type = defines.command.go_to_location, destination = pos, radius = 0.75, distraction = defines.distraction.by_enemy })
      end
    end)
    pair.mode = cur.kind == "direct-dirt-0273" and "emergency-dirt-scraping" or "emergency-gathering"
    return true
  end
  if not task.direct_due_tick_0312 then
    task.direct_due_tick_0312 = (game and game.tick or 0) + (TECH_PRIESTS_DIRECT_GATHER_TICKS_0273 or 60)
    task.direct_due_tick_0273 = task.direct_due_tick_0312
  end
  pair.mode = cur.kind == "direct-dirt-0273" and "emergency-dirt-scraping" or "emergency-gathering"

  local tick = game and game.tick or 0
  if cur.entity and cur.entity.valid then
    if draw_emergency_craft_scan_line then pcall(function() draw_emergency_craft_scan_line(pair, cur.entity) end) end
    if tick >= (task.next_direct_laser_tick_0312 or 0) then
      task.next_direct_laser_tick_0312 = tick + TECH_PRIESTS_0312_MINING_LASER_TICKS
      tech_priests_0312_fire_laser(priest, cur.entity, TECH_PRIESTS_0312_MINING_LASER_DAMAGE, "direct-mining", { r = 1.0, g = 0.45, b = 0.05, a = 0.75 })
    end
  elseif cur.position and spawn_emergency_craft_smoke and tick >= (task.next_direct_laser_tick_0312 or 0) then
    task.next_direct_laser_tick_0312 = tick + TECH_PRIESTS_0312_MINING_LASER_TICKS
    pcall(function() spawn_emergency_craft_smoke(pair, cur.position, false) end)
  end

  if tick < (task.direct_due_tick_0312 or task.direct_due_tick_0273 or tick) then return true end

  -- Final extraction: the laser does a slightly heavier finishing cut and then
  -- the existing emergency craft doctrine receives one unit of the requested output.
  if cur.entity and cur.entity.valid then
    local e = cur.entity
    tech_priests_0312_fire_laser(priest, e, math.max(10, TECH_PRIESTS_0312_MINING_LASER_DAMAGE * 3), "direct-mining-final", { r = 1.0, g = 0.65, b = 0.1, a = 0.95 })
    pcall(function()
      if e.valid and e.type == "resource" then
        local amount = e.amount or 0
        if amount > 1 then e.amount = math.max(1, amount - 25) else e.destroy() end
      elseif e.valid and e.health and e.health <= 1 then
        e.destroy()
      end
    end)
  end

  local output = cur.output_item or (tech_priests_0273_output_from_task and tech_priests_0273_output_from_task(task)) or task.item_name or task.output_item or "stone"
  if not tech_priests_0312_item_exists(output) then output = "stone" end
  if tech_priests_0273_deposit then
    pcall(function() tech_priests_0273_deposit(pair, output, 1) end)
  else
    local inv = get_station_inventory and get_station_inventory(pair.station) or pair.station.get_inventory(defines.inventory.chest)
    if inv and inv.can_insert({ name = output, count = 1 }) then inv.insert({ name = output, count = 1 }) end
  end
  pair.last_direct_mining_laser_0312 = { tick = tick, output = output, source = cur.item_name or (cur.entity and cur.entity.name) or cur.kind }
  pair.emergency_craft = nil
  pair.mode = "returning"
  pair.target = nil
  if return_to_station then pcall(function() return_to_station(priest, pair.station) end) end
  return true
end

TECH_PRIESTS_0312_PRE_HANDLE_EMERGENCY_DESPERATION_CRAFT = handle_emergency_desperation_craft
function handle_emergency_desperation_craft(pair)
  if pair and pair.emergency_craft and pair.emergency_craft.current and (pair.emergency_craft.current.kind == "direct-mine-0273" or pair.emergency_craft.current.kind == "direct-dirt-0273") then
    return tech_priests_0312_service_direct_current(pair, pair.emergency_craft)
  end
  return TECH_PRIESTS_0312_PRE_HANDLE_EMERGENCY_DESPERATION_CRAFT and TECH_PRIESTS_0312_PRE_HANDLE_EMERGENCY_DESPERATION_CRAFT(pair) or false
end

function tech_priests_0423_point_blank_laser_range()
  local pickup_sq = tonumber(EMERGENCY_CRAFT_PICKUP_DISTANCE_SQ) or tonumber(TECH_PRIESTS_0315_MINING_LOCK_RADIUS_SQ) or 2.25
  local range = tonumber(TECH_PRIESTS_POINT_BLANK_LASER_RANGE) or math.sqrt(math.max(0.01, pickup_sq))
  return math.max(0.75, math.min(2.0, range))
end

function tech_priests_0312_fallback_combat_laser(pair, target, reason)
  if not tech_priests_0312_valid_pair(pair) then return false end
  target = (target and target.valid and target) or tech_priests_0312_find_enemy(pair, tech_priests_0312_radius(pair))
  if not (target and target.valid) then return false end

  local tick = game and game.tick or 0
  local priest = pair.priest
  local dx = (priest.position.x or 0) - (target.position.x or 0)
  local dy = (priest.position.y or 0) - (target.position.y or 0)
  local d2 = dx * dx + dy * dy
  local point_blank = tech_priests_0423_point_blank_laser_range()

  pair.task_kind = "combat"
  pair.target = target
  pair.combat_target = target
  pair.last_combat_fallback_0312 = { tick = tick, target = target.name, reason = reason or "no-ammo", dist_sq = d2, point_blank = point_blank }

  -- 0.1.423: the ammo-less combat laser is a desperate close-quarters cutter,
  -- not a 16-tile ranged weapon.  It uses the same near-point-blank band as
  -- direct mining.  If the priest is too far away, the movement controller owns
  -- approach; the laser does not fire until the priest is actually close.
  if d2 > point_blank * point_blank then
    pair.mode = "moving-to-laser-fallback"
    pair.next_fallback_laser_tick_0312 = math.max(pair.next_fallback_laser_tick_0312 or 0, tick + 10)
    if tech_priests_request_movement_0418 then
      pcall(function()
        tech_priests_request_movement_0418(pair, target.position, "fallback-combat-point-blank", {
          radius = math.max(0.55, point_blank * 0.65),
          owner = "fallback-combat-laser-0423",
          priority = 92,
          ttl = 60 * 4,
          distraction = defines and defines.distraction and defines.distraction.by_enemy or nil
        })
      end)
    elseif issue_priest_command then
      pcall(function()
        issue_priest_command(priest, { type = defines.command.go_to_location, destination = target.position, radius = math.max(0.55, point_blank * 0.65), distraction = defines.distraction.by_enemy })
      end)
    end
    return true
  end

  if tick < (pair.next_fallback_laser_tick_0312 or 0) then return true end
  pair.next_fallback_laser_tick_0312 = tick + TECH_PRIESTS_0312_FALLBACK_LASER_TICKS
  pair.mode = "defending-laser-fallback"
  tech_priests_0312_fire_laser(pair.priest, target, TECH_PRIESTS_0312_MINING_LASER_DAMAGE, "fallback-combat-point-blank", { r = 1.0, g = 0.15, b = 0.05, a = 0.75 })
  return true
end

TECH_PRIESTS_0312_PRE_PRIME_PROXY_ATTACK = tech_priests_0293_prime_proxy_attack
function tech_priests_0293_prime_proxy_attack(pair, target, reason)
  if tech_priests_0312_valid_pair(pair) and target and target.valid and not tech_priests_0312_has_ballistic_ammo(pair) then
    return tech_priests_0312_fallback_combat_laser(pair, target, reason or "proxy-no-ammo")
  end
  return TECH_PRIESTS_0312_PRE_PRIME_PROXY_ATTACK and TECH_PRIESTS_0312_PRE_PRIME_PROXY_ATTACK(pair, target, reason) or false
end

TECH_PRIESTS_0312_PRE_FORCE_COMBAT_TICK = tech_priests_0293_force_combat_tick
function tech_priests_0293_force_combat_tick(pair, reason, force)
  if tech_priests_0312_valid_pair(pair) and not tech_priests_0312_has_ballistic_ammo(pair) then
    local target = tech_priests_0312_find_enemy(pair, tech_priests_0312_radius(pair))
    if target and target.valid then
      return tech_priests_0312_fallback_combat_laser(pair, target, reason or "force-no-ammo")
    end
  end
  return TECH_PRIESTS_0312_PRE_FORCE_COMBAT_TICK and TECH_PRIESTS_0312_PRE_FORCE_COMBAT_TICK(pair, reason, force) or false
end
tech_priests_0292_force_combat_tick = tech_priests_0293_force_combat_tick

-- Preservation display polish: item-with-tags may or may not expose a visible
-- label in every Factorio context, so write every safe display field we can.
TECH_PRIESTS_0312_PRE_APPLY_RECORD_TO_STACK = tech_priests_0301_apply_record_to_stack
function tech_priests_0301_apply_record_to_stack(stack, record)
  local ok = TECH_PRIESTS_0312_PRE_APPLY_RECORD_TO_STACK and TECH_PRIESTS_0312_PRE_APPLY_RECORD_TO_STACK(stack, record) or false
  if stack and stack.valid_for_read and record then
    local display = record.station_display_name or (record.cell_name and ("Cogitator Station " .. tostring(record.cell_name))) or "Named Cogitator Station"
    local priest = record.priest_display_name or (record.cell_name and ("Tech-Priest " .. tostring(record.cell_name))) or "Linked Tech-Priest"
    pcall(function() stack.label = display end)
    pcall(function() stack.custom_description = display .. "\nLinked unit: " .. priest .. "\nPreserved cell: inventory and re-imprinting identity retained." end)
    pcall(function()
      local tags = stack.tags or {}
      tags[TECH_PRIESTS_PRESERVATION_TAG_0301] = record
      tags.display_name_0312 = display
      tags.priest_display_name_0312 = priest
      stack.tags = tags
    end)
  end
  return ok
end

if commands and commands.add_command then
  pcall(function()
    TechPriestsDebugCommandRegistry.add("tp-laser-0312", "Tech Priests: force the no-ammo mining-laser fallback weapon check for the selected pair.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      if not player then return end
      local selected = player.selected
      local pair = nil
      if selected and storage and storage.tech_priests then
        if storage.tech_priests.pairs_by_station and storage.tech_priests.pairs_by_station[selected.unit_number] then pair = storage.tech_priests.pairs_by_station[selected.unit_number] end
        if (not pair) and storage.tech_priests.pairs_by_priest and storage.tech_priests.pairs_by_priest[selected.unit_number] then pair = storage.tech_priests.pairs_by_priest[selected.unit_number] end
      end
      if not pair then player.print("[Tech Priests 0.1.312] Select a Cogitator Station or Tech-Priest first."); return end
      local target = tech_priests_0312_find_enemy(pair, tech_priests_0312_radius(pair))
      local did = tech_priests_0312_fallback_combat_laser(pair, target, "manual-command")
      player.print("[Tech Priests 0.1.312] fallback_laser=" .. tostring(did) .. " target=" .. tostring(target and target.valid and target.name or "none") .. " ballistic_ammo=" .. tostring(tech_priests_0312_has_ballistic_ammo(pair)) .. " mode=" .. tostring(pair.mode or "nil"))
    end)
  end)
end

tech_priests_0312_log("mining laser fallback weapon + preserved item display labels loaded")


-- ============================================================================
-- 0.1.313 Research-bonus doctrine; equipment-grid experiment abandoned.
-- ============================================================================
-- The scripted Cogitator sub-equipment grid proved to be the wrong abstraction:
-- it behaved like an inventory, fought the station inventory UI, and created
-- active-defense lifecycle crashes when priests died or re-imprinted.  From this
-- point the Cogitator Station has ONE meaningful storage surface: its normal
-- inventory.  Priest bonuses are force-wide research unlocks.

TECH_PRIESTS_PATCH_0313 = "0.1.313-research-bonuses-no-equipment-grid"

function tech_priests_0313_log(msg)
  if log then log("[Tech-Priests 0.1.313] " .. tostring(msg)) end
end

function tech_priests_0313_force_researched(force, tech_name)
  if not (force and tech_name) then return false end
  local ok, tech = pcall(function() return force.technologies and force.technologies[tech_name] end)
  return ok and tech and tech.researched == true
end

function tech_priests_0313_any_researched(force, names)
  for _, name in pairs(names or {}) do
    if tech_priests_0313_force_researched(force, name) then return true, name end
  end
  return false, nil
end

function tech_priests_0313_force_upgrade_profile(force)
  local exo, exo_tech = tech_priests_0313_any_researched(force, { "exoskeleton-equipment", "exoskeleton-mk2-equipment", "exoskeleton-mk3-equipment" })
  local battery, battery_tech = tech_priests_0313_any_researched(force, { "battery-equipment", "battery-mk2-equipment", "battery-mk3-equipment" })
  local pld, pld_tech = tech_priests_0313_any_researched(force, { "personal-laser-defense-equipment", "personal-laser-defense-mk2-equipment" })
  local belt, belt_tech = tech_priests_0313_any_researched(force, { "belt-immunity-equipment" })
  return {
    exoskeleton = exo,
    exoskeleton_tech = exo_tech,
    battery = battery,
    battery_tech = battery_tech,
    personal_laser_defense = pld,
    personal_laser_defense_tech = pld_tech,
    belt_immunity = belt,
    belt_immunity_tech = belt_tech,
    movement_speed_multiplier = exo and 1.35 or 1.0,
    mining_laser_damage = pld and 15 or 5,
    fallback_laser_damage = pld and 15 or 5,
    mining_laser_ticks = battery and 8 or 15,
    fallback_laser_ticks = battery and 15 or 30,
    mining_pulse_smoke = battery and 3 or 1
  }
end

function tech_priests_0313_global_upgrade_profile()
  local profile = {
    exoskeleton = false,
    battery = false,
    personal_laser_defense = false,
    belt_immunity = false,
    movement_speed_multiplier = 1.0,
    mining_laser_damage = 5,
    fallback_laser_damage = 5,
    mining_laser_ticks = 15,
    fallback_laser_ticks = 30,
    mining_pulse_smoke = 1
  }
  if game and game.forces then
    for _, force in pairs(game.forces) do
      local f = tech_priests_0313_force_upgrade_profile(force)
      profile.exoskeleton = profile.exoskeleton or f.exoskeleton
      profile.battery = profile.battery or f.battery
      profile.personal_laser_defense = profile.personal_laser_defense or f.personal_laser_defense
      profile.belt_immunity = profile.belt_immunity or f.belt_immunity
      profile.movement_speed_multiplier = math.max(profile.movement_speed_multiplier, f.movement_speed_multiplier or 1.0)
      profile.mining_laser_damage = math.max(profile.mining_laser_damage, f.mining_laser_damage or 5)
      profile.fallback_laser_damage = math.max(profile.fallback_laser_damage, f.fallback_laser_damage or 5)
      profile.mining_laser_ticks = math.min(profile.mining_laser_ticks, f.mining_laser_ticks or 15)
      profile.fallback_laser_ticks = math.min(profile.fallback_laser_ticks, f.fallback_laser_ticks or 30)
      profile.mining_pulse_smoke = math.max(profile.mining_pulse_smoke, f.mining_pulse_smoke or 1)
    end
  end
  return profile
end

function tech_priests_0313_refresh_research_bonuses(reason)
  local profile = tech_priests_0313_global_upgrade_profile()
  global = global or _G.global
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests.research_bonuses_0313 = profile
  -- 0.1.312 functions read these globals at call-time, so the unified research
  -- profile can safely tune the existing mining/fallback laser cadence.
  TECH_PRIESTS_0312_MINING_LASER_DAMAGE = profile.mining_laser_damage
  TECH_PRIESTS_0312_MINING_LASER_TICKS = profile.mining_laser_ticks
  TECH_PRIESTS_0312_FALLBACK_LASER_TICKS = profile.fallback_laser_ticks
  storage.tech_priests.research_bonuses_0313_reason = reason or "refresh"
  storage.tech_priests.research_bonuses_0313_tick = game and game.tick or 0
  return profile
end

function tech_priests_0313_profile_for_pair(pair)
  if pair and pair.priest and pair.priest.valid and pair.priest.force then
    return tech_priests_0313_force_upgrade_profile(pair.priest.force)
  end
  if pair and pair.station and pair.station.valid and pair.station.force then
    return tech_priests_0313_force_upgrade_profile(pair.station.force)
  end
  return (storage and storage.tech_priests and storage.tech_priests.research_bonuses_0313) or tech_priests_0313_global_upgrade_profile()
end

-- Disable fake grid GUI and fake grid active defenses.  The normal station
-- inventory remains the only storage surface.
function tech_priests_0306_open_gui(player, pair)
  return nil
end

function tech_priests_0306_clear_gui(player)
  if not (player and player.valid and player.gui and player.gui.screen) then return end
  local old = player.gui.screen["tech_priests_0306_equipment_frame"]
  if old and old.valid then pcall(function() old.destroy() end) end
end

function tech_priests_0306_gui_click(event)
  return nil
end

function tech_priests_0305_refresh_pair_equipment(pair, reason)
  local profile = tech_priests_0313_profile_for_pair(pair)
  local summary = {
    disabled = true,
    doctrine = "research-bonuses-station-inventory-only",
    reason = reason or "disabled",
    used = 0,
    capacity = 0,
    accepted = {},
    rejected = {},
    shield_capacity = 0,
    laser_count = profile.personal_laser_defense and 1 or 0,
    discharge_count = 0,
    exoskeleton_count = profile.exoskeleton and 1 or 0,
    battery_count = profile.battery and 1 or 0,
    toolbelt_count = 0,
    research_profile = profile
  }
  if pair then
    pair.sub_equipment_0305 = summary
    pair.sub_equipment_bay_0306 = nil
    pair.future_equipment_grid_0301 = nil
  end
  return summary
end

function tech_priests_0305_apply_active_defense(pair)
  return false
end

-- Replace the 83-tick fake-equipment service with a harmless research refresh.
TechPriestsRuntimeEventRegistry.on_nth_tick(83, function()
  tech_priests_0313_refresh_research_bonuses("periodic")
end)

-- Replace damage handling so abandoned fake shield equipment cannot touch dead
-- priests. Keep fixed armor mitigation and station-damage bookkeeping.
function tech_priests_0313_on_entity_damaged(event)
  local entity = event and event.entity
  if entity and entity.valid and is_station and is_station(entity) then
    local pair = nil
    if find_pair_for_entity then
      local ok, found = pcall(function() return find_pair_for_entity(entity) end)
      if ok then pair = found end
    end
    if pair then
      pair.last_station_damage_tick_0310 = game and game.tick or 0
      pair.station_damage_guard_until_0310 = math.max(pair.station_damage_guard_until_0310 or 0, (game and game.tick or 0) + 30)
    end
  end
  if tech_priests_0302_mitigate_damage then
    pcall(function() tech_priests_0302_mitigate_damage(event) end)
  elseif tech_priests_0297_mitigate_damage then
    pcall(function() tech_priests_0297_mitigate_damage(event) end)
  end
end

if script and defines and defines.events and defines.events.on_entity_damaged then
  TechPriestsRuntimeEventRegistry.on_event(defines.events.on_entity_damaged, tech_priests_0313_on_entity_damaged)
end

-- Re-register opened/closed/clicked handlers without the abandoned equipment
-- side panel. Older GUI systems still get their event calls.
function tech_priests_0313_on_gui_opened(event)
  if tech_priests_on_gui_opened_0184 then pcall(function() tech_priests_on_gui_opened_0184(event) end) end
  local player = event and event.player_index and game.get_player(event.player_index) or nil
  if player then tech_priests_0306_clear_gui(player) end
  local entity = event and event.entity or nil
  if entity and entity.valid and is_station and is_station(entity) then
    local pair = nil
    if find_pair_for_entity then
      local ok, found = pcall(function() return find_pair_for_entity(entity) end)
      if ok then pair = found end
    end
    if pair and apply_pair_display_names then pcall(function() apply_pair_display_names(pair) end) end
    -- Do not set player.opened here. Factorio already opened the container.
  end
end

function tech_priests_0313_on_gui_closed(event)
  if tech_priests_on_gui_closed_0184 then pcall(function() tech_priests_on_gui_closed_0184(event) end) end
  local player = event and event.player_index and game.get_player(event.player_index) or nil
  if player then tech_priests_0306_clear_gui(player) end
end

function tech_priests_0313_on_gui_click(event)
  if tech_priests_on_gui_click_0184 then pcall(function() tech_priests_on_gui_click_0184(event) end) end
  if tech_priests_0310_handle_overview_click and tech_priests_0310_handle_overview_click(event) then return end
  -- No equipment-grid click handling.
end

if script and defines and defines.events then
  TechPriestsGuiRouter.register("opened", tech_priests_0313_on_gui_opened)
  TechPriestsGuiRouter.register("closed", tech_priests_0313_on_gui_closed)
  TechPriestsGuiRouter.register("click", tech_priests_0313_on_gui_click)
end

-- Make the glow sane after the daylight-visible aura test.  Keep mode colour,
-- but stop painting the whole screen like an overzealous saint projector.
TECH_PRIESTS_WHITE_GLOW_COLOR_0307 = { r = 1.0, g = 0.96, b = 0.86, a = 0.16 }
TECH_PRIESTS_GLOW_TTL_0307 = 28

function tech_priests_0313_soften_color(c)
  c = c or { r = 0.2, g = 1.0, b = 0.2, a = 0.25 }
  return { r = c.r or 0.2, g = c.g or 1.0, b = c.b or 0.2, a = math.min(0.22, (c.a or 0.5) * 0.25) }
end

TECH_PRIESTS_PRE_GLOW_REFRESH_0313 = tech_priests_0307_refresh_pair_glow

-- Faster/more emphatic mining pulses with impact smoke, but no laser-work on
-- loose item-on-ground stacks. They should simply be picked up by existing ground
-- stockpile acquisition.
TECH_PRIESTS_0313_PRE_FIRE_LASER = tech_priests_0312_fire_laser

-- Best-effort movement speed bonus. Unit prototypes do not expose a clean
-- per-force exoskeleton modifier, so this is intentionally conservative and
-- protected. If Factorio exposes LuaEntity.speed for this unit, it nudges it;
-- otherwise it records the bonus for later native use without crashing.
function tech_priests_0313_apply_pair_research_bonuses(pair)
  if not (pair and pair.priest and pair.priest.valid) then return end
  local profile = tech_priests_0313_force_upgrade_profile(pair.priest.force)
  pair.research_bonuses_0313 = profile
  if profile.exoskeleton then
    pcall(function()
      local current = pair.priest.speed or 0
      if current and current > 0 then pair.priest.speed = math.min(current * 1.08, current + 0.015) end
    end)
  end
end

TechPriestsRuntimeEventRegistry.on_nth_tick(37, function()
  tech_priests_0313_refresh_research_bonuses("movement-service")
  if not (storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return end
  local processed = 0
  for _, pair in pairs(storage.tech_priests.pairs_by_station) do
    tech_priests_0313_apply_pair_research_bonuses(pair)
    processed = processed + 1
    if processed >= 64 then break end
  end
end)

TechPriestsRuntimeEventRegistry.on_init(function() tech_priests_0313_refresh_research_bonuses("init") end)
TechPriestsRuntimeEventRegistry.on_configuration_changed(function() tech_priests_0313_refresh_research_bonuses("configuration-changed") end)

if defines and defines.events then
  TechPriestsRuntimeEventRegistry.on_event(defines.events.on_research_finished, function(event)
    tech_priests_0313_refresh_research_bonuses("research-finished:" .. tostring(event and event.research and event.research.name or "unknown"))
  end)
  if defines.events.on_technology_effects_reset then
    TechPriestsRuntimeEventRegistry.on_event(defines.events.on_technology_effects_reset, function(event)
      tech_priests_0313_refresh_research_bonuses("technology-effects-reset")
    end)
  end
end

if commands and commands.add_command then
  pcall(function()
    TechPriestsDebugCommandRegistry.add("tp-upgrades-0313", "Tech Priests: inspect research-unlocked unified priest bonuses.", function(event)
      local player = game and game.get_player(event.player_index) or nil
      if not player then return end
      local profile = tech_priests_0313_force_upgrade_profile(player.force)
      tech_priests_0313_refresh_research_bonuses("debug")
      player.print("[Tech Priests 0.1.313] equipment grids disabled; station inventory only.")
      player.print("  exoskeleton=" .. tostring(profile.exoskeleton) .. " speed x" .. tostring(profile.movement_speed_multiplier))
      player.print("  battery=" .. tostring(profile.battery) .. " mining-ticks=" .. tostring(profile.mining_laser_ticks) .. " fallback-ticks=" .. tostring(profile.fallback_laser_ticks))
      player.print("  personal-laser-defense=" .. tostring(profile.personal_laser_defense) .. " laser-damage=" .. tostring(profile.mining_laser_damage))
      player.print("  belt-immunity=" .. tostring(profile.belt_immunity) .. " handled by existing belt-immunity doctrine")
    end)
  end)
end

tech_priests_0313_log("equipment-grid experiment disabled; station inventory only; research-unlocked priest bonuses active")


-- -----------------------------------------------------------------------------
-- 0.1.315 - movement-locked mining beam origin repair + glow clamp
-- -----------------------------------------------------------------------------
-- The direct mining beam was still being drawn by two different systems: the old
-- emergency scan line and the newer damage pulse.  This made the visible line and
-- the actual damage hit disagree.  This layer makes direct mining use one beam:
-- the damage beam.  It emits from the same raised priest origin as the scan line,
-- pulses faster, makes impact smoke at the target, and locks the priest in place
-- once he has reached the quarry target unless combat interrupts the task.

TECH_PRIESTS_PATCH_0315 = "0.1.316-mining-lockdown-unified-beam-local-limit-fix"
TECH_PRIESTS_0315_MINING_LOCK_RADIUS_SQ = 2.25
TECH_PRIESTS_0315_MINING_PULSE_TICKS = 5
TECH_PRIESTS_0315_MINING_FINISH_TICKS = 60
TECH_PRIESTS_0315_INTERRUPT_RADIUS = 2.25
TECH_PRIESTS_0315_BEAM_WIDTH = 2
TECH_PRIESTS_0315_MODE_GLOW_INTENSITY = 0.13
TECH_PRIESTS_0315_AMBIENT_GLOW_INTENSITY = 0.07

function tech_priests_0315_log(msg)
  if tech_priests_0264_log then
    pcall(function() tech_priests_0264_log("[0.1.315] " .. tostring(msg), true) end)
  elseif log then
    log("[Tech-Priests 0.1.315] " .. tostring(msg))
  end
end

function tech_priests_0315_valid_pair(pair)
  return pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid
end

function tech_priests_0315_origin(priest)
  return { entity = priest, offset = TECH_PRIEST_SCAN_ORIGIN_OFFSET or { 0, -1.35 } }
end

function tech_priests_0315_target_position(target)
  if target and target.valid and target.position then return target.position end
  return target
end

function tech_priests_0315_destroy_render(obj)
  if tech_priests_0309_destroy_render_object then
    pcall(function() tech_priests_0309_destroy_render_object(obj) end)
    return
  end
  pcall(function() if obj and obj.valid and obj.destroy then obj.destroy() end end)
end

function tech_priests_0315_is_hostile_nearby(pair, radius)
  if not tech_priests_0315_valid_pair(pair) then return false end
  local priest = pair.priest
  local r = radius or TECH_PRIESTS_0315_INTERRUPT_RADIUS
  local found = nil
  local ok = pcall(function()
    found = priest.surface.find_entities_filtered({
      position = priest.position,
      radius = r,
      type = { "unit", "spider-unit", "spider-vehicle" },
      limit = 32
    })
  end)
  if not (ok and found) then return false end
  for _, e in pairs(found) do
    if e and e.valid and e.force and priest.force and e.force ~= priest.force then
      local hostile = false
      pcall(function() hostile = priest.force.is_enemy and priest.force.is_enemy(e.force) end)
      if hostile or e.force ~= priest.force then return true end
    end
  end
  return false
end

function tech_priests_0315_soft_color(c, a)
  c = c or { r = 0.3, g = 1.0, b = 0.25, a = 0.25 }
  return { r = c.r or 0.3, g = c.g or 1.0, b = c.b or 0.25, a = a or math.min(0.12, (c.a or 0.4) * 0.18) }
end

-- Final glow clamp.  The daylight sprite aura was too intense, and the original
-- 0.1.307 lights were drawn at minimum_darkness=0, which made sandbox daylight
-- look like a green plasma accident.  This version destroys all older glow render
-- handles and draws only very small lights which are mainly meaningful at night.
function tech_priests_0307_refresh_pair_glow(pair)
  if not (pair and pair.priest and pair.priest.valid) then return end
  tech_priests_0315_destroy_render(pair.glow_ambient_0307)
  tech_priests_0315_destroy_render(pair.glow_mode_0307)
  tech_priests_0315_destroy_render(pair.glow_day_ambient_0310)
  tech_priests_0315_destroy_render(pair.glow_day_mode_0310)
  pair.glow_ambient_0307 = nil
  pair.glow_mode_0307 = nil
  pair.glow_day_ambient_0310 = nil
  pair.glow_day_mode_0310 = nil

  local priest = pair.priest
  local mode_color, mode_name = nil, "idle"
  if tech_priests_0307_mode_color then
    local ok, c, m = pcall(function() return tech_priests_0307_mode_color(pair) end)
    if ok then mode_color = c; mode_name = m or mode_name end
  end
  mode_color = tech_priests_0315_soft_color(mode_color, 0.22)
  pair.glow_mode_name_0307 = mode_name
  pair.glow_mode_color_0307 = mode_color
  pair.glow_last_tick_0307 = game and game.tick or 0

  if rendering and rendering.draw_light then
    pcall(function()
      pair.glow_ambient_0307 = rendering.draw_light{
        sprite = "utility/light_medium",
        target = priest,
        surface = priest.surface,
        color = { r = 1.0, g = 0.96, b = 0.86, a = 0.16 },
        scale = 1.50,
        intensity = TECH_PRIESTS_0315_AMBIENT_GLOW_INTENSITY,
        minimum_darkness = 0.45,
        time_to_live = 36,
        forces = { priest.force }
      }
    end)
    pcall(function()
      pair.glow_mode_0307 = rendering.draw_light{
        sprite = "utility/light_medium",
        target = priest,
        surface = priest.surface,
        color = mode_color,
        scale = 2.30,
        intensity = TECH_PRIESTS_0315_MODE_GLOW_INTENSITY,
        minimum_darkness = 0.35,
        time_to_live = 36,
        forces = { priest.force }
      }
    end)
  end
end

-- Direct scan-line override: for actual mining/quarry/dirt current tasks, do not
-- draw the old decorative scan beam.  The damage pulse below is now the one beam
-- used for visible mining and impact.  Inventory scans can still use the softer
-- old amber line.
TECH_PRIESTS_0315_PRE_DRAW_EMERGENCY_CRAFT_SCAN_LINE = draw_emergency_craft_scan_line
function draw_emergency_craft_scan_line(pair, target_entity)
  local cur = pair and pair.emergency_craft and pair.emergency_craft.current or nil
  if cur and (cur.kind == "direct-mine-0273" or cur.kind == "direct-dirt-0273") then
    return nil
  end
  if target_entity and target_entity.valid and target_entity.type == "item-entity" then
    return nil
  end
  if TECH_PRIESTS_0315_PRE_DRAW_EMERGENCY_CRAFT_SCAN_LINE then
    return TECH_PRIESTS_0315_PRE_DRAW_EMERGENCY_CRAFT_SCAN_LINE(pair, target_entity)
  end
end

function tech_priests_0315_effective_profile(force)
  if tech_priests_0313_force_upgrade_profile then
    local ok, profile = pcall(function() return tech_priests_0313_force_upgrade_profile(force) end)
    if ok and profile then return profile end
  end
  return { mining_laser_damage = TECH_PRIESTS_0312_MINING_LASER_DAMAGE or 5, mining_laser_ticks = TECH_PRIESTS_0315_MINING_PULSE_TICKS, mining_pulse_smoke = 2 }
end

-- Unified beam: one line, one source, one impact point, optional damage.  This is
-- used both by direct mining and by the no-ammo fallback weapon.
function tech_priests_0312_fire_laser(priest, target, damage, reason, color)
  if not (priest and priest.valid and target and target.valid) then return false end
  if target.type == "item-entity" then return false end
  local pos = tech_priests_0315_target_position(target)
  if not pos then return false end
  local force = priest.force
  local profile = tech_priests_0315_effective_profile(force)
  local d = math.max(1, damage or profile.mining_laser_damage or 5)
  color = color or { r = 1.0, g = 0.25, b = 0.05, a = 0.68 }

  local ok_damage = true
  pcall(function()
    if target.valid and target.type == "resource" then
      local amount = target.amount or 0
      if amount and amount > 1 then target.amount = math.max(1, amount - math.max(1, math.floor(d * 0.35))) end
    elseif target.valid and target.health and target.health > 0 then
      target.damage(d, force, "laser", priest)
    end
  end)

  if rendering and rendering.draw_line then
    pcall(function()
      rendering.draw_line({
        color = color,
        width = TECH_PRIESTS_0315_BEAM_WIDTH,
        from = tech_priests_0315_origin(priest),
        to = pos,
        surface = priest.surface,
        time_to_live = 7,
        forces = { force }
      })
    end)
    pcall(function()
      rendering.draw_circle({
        color = { r = color.r or 1, g = color.g or 0.4, b = color.b or 0.05, a = 0.24 },
        radius = 0.22,
        width = 1,
        filled = true,
        target = target,
        surface = priest.surface,
        time_to_live = 6,
        forces = { force }
      })
    end)
  end

  local smoke_count = math.max(2, profile.mining_pulse_smoke or 2)
  for i = 1, smoke_count do
    pcall(function()
      priest.surface.create_trivial_smoke({ name = "smoke-fast", position = { x = pos.x + (i - 1.5) * 0.07, y = pos.y + ((i % 2) - 0.5) * 0.08 } })
    end)
  end
  pcall(function() priest.surface.create_entity({ name = "spark-explosion", position = pos }) end)
  return ok_damage
end
