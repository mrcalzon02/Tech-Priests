-- Tech Priests 0.1.422 consecration history GUI and operation ledger.
-- This module has two jobs:
--   1. Keep a compact operation-by-operation sanctification history per machine.
--   2. Display that history when the machine GUI is opened, so live tests can
--      verify consecration decay, max-cap damage, waste, and backlash behavior.

local M = { name = "scripts.core.consecration.history_gui", version = "0.1.526" }

local FRAME_NAME = "tech_priests_consecration_history_0422"
local CLOSE_NAME = "tech_priests_consecration_history_close_0422"
local REFRESH_NAME = "tech_priests_consecration_history_refresh_0422"
local HISTORY_LIMIT = 80
local GRAPH_WIDTH = 28
local TRAIT_TABLE_WIDTH = 850

local function fmt(value, digits)
  value = tonumber(value)
  if not value then return "n/a" end
  return string.format("%." .. tostring(digits or 1) .. "f", value)
end

local function ensure_root()
  if ensure_storage then pcall(ensure_storage) end
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests.consecration_history_gui_0422 = storage.tech_priests.consecration_history_gui_0422 or {
    open = {},
    version = M.version,
    stats = {}
  }
  local root = storage.tech_priests.consecration_history_gui_0422
  root.open = root.open or {}
  root.stats = root.stats or {}
  root.version = M.version
  return root
end

local function get_record(entity)
  if not (entity and entity.valid) then return nil end
  if not (is_consecration_target and is_consecration_target(entity)) then return nil end
  if not get_consecration_record then return nil end
  local ok, record = pcall(get_consecration_record, entity)
  if ok then return record end
  return nil
end

local function find_record_by_unit(unit)
  unit = tonumber(unit)
  if not unit then return nil end
  if ensure_storage then pcall(ensure_storage) end
  local machines = storage and storage.tech_priests and storage.tech_priests.consecration and storage.tech_priests.consecration.machines or nil
  local record = machines and machines[unit] or nil
  if record and record.entity and record.entity.valid then return record end
  return nil
end

local function machine_display_name(entity)
  if not (entity and entity.valid) then return "unknown-machine" end
  return entity.localised_name or entity.name or "machine"
end

local function machine_spirit_header_text_0526(record, entity)
  local spirit = record and record.machine_spirit_0523 or {}
  local machine_id = tech_priests_0446_format_machine_id and tech_priests_0446_format_machine_id(record) or ("unit#" .. tostring(record and record.unit_number or (entity and entity.valid and entity.unit_number) or "?"))
  local name = spirit.display_name or (spirit.named and "Machine" or "Unnamed Machine-Spirit")
  return tostring(name) .. " // " .. tostring(machine_id)
end

local set_label_style

local function bar_counts(after, max_value, base_max)
  after = tonumber(after) or 0
  max_value = tonumber(max_value) or 0
  base_max = math.max(1, tonumber(base_max) or max_value or 1)

  local current_cells = math.max(0, math.min(GRAPH_WIDTH, math.floor((after / base_max) * GRAPH_WIDTH + 0.5)))
  local max_cells = math.max(0, math.min(GRAPH_WIDTH, math.floor((max_value / base_max) * GRAPH_WIDTH + 0.5)))
  if current_cells > max_cells then current_cells = max_cells end
  return current_cells, math.max(0, max_cells - current_cells), math.max(0, GRAPH_WIDTH - max_cells)
end

local function add_bar_segment(parent, caption, color)
  if caption == "" then return nil end
  local label = parent.add{ type = "label", caption = caption }
  set_label_style(label, nil, color)
  pcall(function() label.style.single_line = true end)
  pcall(function() label.style.font = "default-bold" end)
  return label
end

local function add_sanctity_bar(parent, after, max_value, base_max, width)
  local flow = parent.add{ type = "flow", direction = "horizontal" }
  pcall(function() flow.style.minimal_width = width or 335 end)
  pcall(function() flow.style.maximal_width = width or 620 end)
  local current_cells, empty_cells, lost_cells = bar_counts(after, max_value, base_max)
  local function reps(ch, n)
    if n <= 0 then return "" end
    return string.rep(ch, n)
  end
  add_bar_segment(flow, reps("█", current_cells), { r = 0.15, g = 0.95, b = 0.20 })
  add_bar_segment(flow, reps("░", empty_cells), { r = 0.42, g = 0.45, b = 0.42 })
  add_bar_segment(flow, reps("█", lost_cells), { r = 1.0, g = 0.18, b = 0.12 })
  if current_cells + empty_cells + lost_cells <= 0 then
    add_bar_segment(flow, reps("░", GRAPH_WIDTH), { r = 0.42, g = 0.45, b = 0.42 })
  end
  return flow
end

set_label_style = function(label, width, font_color)
  if not (label and label.valid and label.style) then return end
  if width then pcall(function() label.style.width = width end) end
  if font_color then pcall(function() label.style.font_color = font_color end) end
  pcall(function() label.style.single_line = false end)
end

local function apply_style_0564(element, style_name)
  if not (element and element.valid and style_name) then return false end
  return pcall(function() element.style = style_name end)
end

local function set_table_style(element)
  if not (element and element.valid and element.style) then return end
  apply_style_0564(element, "tech_priests_cogitator_screen_table_0564")
  pcall(function() element.style.column_alignments[1] = "right" end)
  pcall(function() element.style.column_alignments[2] = "left" end)
  pcall(function() element.style.column_alignments[3] = "right" end)
  pcall(function() element.style.column_alignments[4] = "right" end)
  pcall(function() element.style.column_alignments[5] = "right" end)
  pcall(function() element.style.cell_padding = 4 end)
end

local function set_scroll_style_0564(element)
  if not (element and element.valid and element.style) then return end
  if not apply_style_0564(element, "tech_priests_cogitator_screen_scroll_0565") then
    apply_style_0564(element, "tech_priests_cogitator_screen_scroll_0564")
  end
  pcall(function() element.style.horizontally_stretchable = true end)
  pcall(function() element.style.vertically_stretchable = true end)
  pcall(function() element.style.padding = 6 end)
end

local function set_display_frame_style_0565(element)
  if not (element and element.valid and element.style) then return end
  if not apply_style_0564(element, "tech_priests_cogitator_display_frame_0540") then
    apply_style_0564(element, "tech_priests_cogitator_inner_frame_0532")
  end
  pcall(function() element.style.horizontally_stretchable = true end)
  pcall(function() element.style.padding = 8 end)
end


local function add_gui_sprite_0567(parent, sprite_name, width, height, tooltip)
  if not (parent and parent.valid and sprite_name) then return nil end
  local ok, elem = pcall(function()
    return parent.add{ type = "sprite", sprite = sprite_name, tooltip = tooltip }
  end)
  if not (ok and elem and elem.valid) then return nil end
  pcall(function() elem.style.width = width end)
  pcall(function() elem.style.height = height end)
  pcall(function() elem.style.minimal_width = width end)
  pcall(function() elem.style.minimal_height = height end)
  pcall(function() elem.style.maximal_width = width end)
  pcall(function() elem.style.maximal_height = height end)
  pcall(function() elem.style.stretch_image_to_widget_size = true end)
  pcall(function() elem.ignored_by_interaction = true end)
  return elem
end

local function style_fixed_flow_0567(flow, width, height, direction)
  if not (flow and flow.valid) then return end
  if direction then pcall(function() flow.direction = direction end) end
  pcall(function() flow.style.padding = 0 end)
  pcall(function() flow.style.margin = 0 end)
  pcall(function() flow.style.horizontal_spacing = 0 end)
  pcall(function() flow.style.vertical_spacing = 0 end)
  if width then
    pcall(function() flow.style.width = width end)
    pcall(function() flow.style.minimal_width = width end)
    pcall(function() flow.style.maximal_width = width end)
  end
  if height then
    pcall(function() flow.style.height = height end)
    pcall(function() flow.style.minimal_height = height end)
    pcall(function() flow.style.maximal_height = height end)
  end
end

local function gui_frame_sprite_0567(prefix, name)
  return "tech-priests-gui-frame-" .. tostring(prefix or "0536") .. "-" .. tostring(name or "")
end

local function add_frame_slice_0567(parent, prefix, name, width, height)
  return add_gui_sprite_0567(parent, gui_frame_sprite_0567(prefix, name), math.max(1, math.floor(width or 1)), math.max(1, math.floor(height or 1)))
end

local function add_tiled_mid_0567(parent, prefix, name, total_len, tile_len, width, height, horizontal)
  local remaining = math.max(1, math.floor(total_len or tile_len or 1))
  local tile = math.max(1, math.floor(tile_len or 32))
  while remaining > 0 do
    local span = math.min(tile, remaining)
    if horizontal then add_frame_slice_0567(parent, prefix, name, span, height) else add_frame_slice_0567(parent, prefix, name, width, span) end
    remaining = remaining - span
  end
end

local function add_segmented_horizontal_rail_0567(parent, name, total_w, height)
  local cap = 24
  local mid_w = math.max(1, math.floor((total_w or 80) - cap * 2))
  add_frame_slice_0567(parent, "0540", name .. "-cap-a", cap, height)
  add_tiled_mid_0567(parent, "0540", name .. "-mid", mid_w, 32, nil, height, true)
  add_frame_slice_0567(parent, "0540", name .. "-cap-b", cap, height)
end

local function add_segmented_vertical_column_0567(parent, name, total_h)
  local col = parent.add{ type = "flow", direction = "vertical", name = "tech_priests_machine_spirit_gui_frame_0567_" .. name }
  style_fixed_flow_0567(col, 64, total_h, "vertical")
  local mid_h = math.max(1, math.floor((total_h or 256) - 128))
  add_frame_slice_0567(col, "0540", name .. "-cap-top", 64, 64)
  add_tiled_mid_0567(col, "0540", name .. "-mid", mid_h, 128, 64, nil, false)
  add_frame_slice_0567(col, "0540", name .. "-cap-bottom", 64, 64)
  return col
end

local function add_top_or_bottom_frame_row_0567(parent, row_kind, total_w)
  local row = parent.add{ type = "flow", direction = "horizontal", name = "tech_priests_machine_spirit_gui_frame_0567_" .. row_kind }
  style_fixed_flow_0567(row, total_w, 64, "horizontal")
  local rail_total = math.max(80, (total_w or 0) - 128 - 96)
  local rail_left_w = math.floor(rail_total / 2)
  local rail_right_w = rail_total - rail_left_w
  if row_kind == "top" then
    add_frame_slice_0567(row, "0536", "corner-top-left", 64, 64)
    add_segmented_horizontal_rail_0567(row, "top-rail-left", rail_left_w, 64)
    add_frame_slice_0567(row, "0536", "top-center-emblem", 96, 64)
    add_segmented_horizontal_rail_0567(row, "top-rail-right", rail_right_w, 64)
    add_frame_slice_0567(row, "0536", "corner-top-right", 64, 64)
  else
    add_frame_slice_0567(row, "0536", "corner-bottom-left", 64, 64)
    add_segmented_horizontal_rail_0567(row, "bottom-rail-left", rail_left_w, 64)
    add_frame_slice_0567(row, "0536", "bottom-center-emblem", 96, 64)
    add_segmented_horizontal_rail_0567(row, "bottom-rail-right", rail_right_w, 64)
    add_frame_slice_0567(row, "0536", "corner-bottom-right", 64, 64)
  end
  return row
end

local function add_inner_bezel_shell_0567(parent, total_w, total_h)
  local bezel = 20
  local content_w = math.max(560, math.floor((total_w or 720) - bezel * 2))
  local content_h = math.max(500, math.floor((total_h or 620) - bezel * 2))
  local shell = parent.add{ type = "flow", direction = "vertical", name = "tech_priests_machine_spirit_inner_bezel_shell_0567" }
  style_fixed_flow_0567(shell, content_w + bezel * 2, content_h + bezel * 2, "vertical")
  local top = shell.add{ type = "flow", direction = "horizontal" }
  style_fixed_flow_0567(top, content_w + bezel * 2, bezel, "horizontal")
  add_frame_slice_0567(top, "0536", "inner-bezel-tl", bezel, bezel)
  add_frame_slice_0567(top, "0536", "inner-bezel-t", content_w, bezel)
  add_frame_slice_0567(top, "0536", "inner-bezel-tr", bezel, bezel)
  local mid = shell.add{ type = "flow", direction = "horizontal" }
  style_fixed_flow_0567(mid, content_w + bezel * 2, content_h, "horizontal")
  add_frame_slice_0567(mid, "0536", "inner-bezel-l", bezel, content_h)
  local content = mid.add{ type = "frame", name = "tech_priests_machine_spirit_gui_body_0567", direction = "vertical" }
  set_display_frame_style_0565(content)
  pcall(function() content.style.padding = 10 end)
  pcall(function() content.style.minimal_width = content_w end)
  pcall(function() content.style.maximal_width = content_w end)
  pcall(function() content.style.minimal_height = content_h end)
  pcall(function() content.style.maximal_height = content_h end)
  add_frame_slice_0567(mid, "0536", "inner-bezel-r", bezel, content_h)
  local bottom = shell.add{ type = "flow", direction = "horizontal" }
  style_fixed_flow_0567(bottom, content_w + bezel * 2, bezel, "horizontal")
  add_frame_slice_0567(bottom, "0536", "inner-bezel-bl", bezel, bezel)
  add_frame_slice_0567(bottom, "0536", "inner-bezel-b", content_w, bezel)
  add_frame_slice_0567(bottom, "0536", "inner-bezel-br", bezel, bezel)
  return content, content_w, content_h
end

local function add_machine_spirit_sliced_shell_0567(parent, panel_w, panel_h)
  local total_w = math.max(780, math.floor((panel_w or 900) - 20))
  local total_h = math.max(720, math.floor((panel_h or 860) - 40))
  local middle_h = math.max(560, total_h - 128)
  local center_w = math.max(640, total_w - 128)
  local outer = parent.add{ type = "flow", direction = "vertical", name = "tech_priests_machine_spirit_sliced_cogitator_shell_0567" }
  style_fixed_flow_0567(outer, total_w, total_h, "vertical")
  add_top_or_bottom_frame_row_0567(outer, "top", total_w)
  local middle = outer.add{ type = "flow", direction = "horizontal", name = "tech_priests_machine_spirit_gui_frame_0567_middle" }
  style_fixed_flow_0567(middle, total_w, middle_h, "horizontal")
  add_segmented_vertical_column_0567(middle, "left-column", middle_h)
  local body, content_w, content_h = add_inner_bezel_shell_0567(middle, center_w, middle_h)
  add_segmented_vertical_column_0567(middle, "right-column", middle_h)
  add_top_or_bottom_frame_row_0567(outer, "bottom", total_w)
  return body, content_w, content_h, total_w, total_h
end

local function destroy_frame(player)
  if player and player.valid and player.gui and player.gui.screen then
    local frame = player.gui.screen[FRAME_NAME]
    if frame and frame.valid then frame.destroy() end
  end
  if storage and storage.tech_priests and storage.tech_priests.consecration_history_gui_0422 then
    storage.tech_priests.consecration_history_gui_0422.open[player.index] = nil
  end
end

local function choose_ledger_location(player, entity)
  local resolution = { width = 1920, height = 1080 }
  pcall(function()
    if player.display_resolution then resolution = player.display_resolution end
  end)
  local scale = 1
  pcall(function() scale = tonumber(player.display_scale) or 1 end)
  local screen_w = math.floor((tonumber(resolution.width) or 1920) / math.max(0.25, scale))
  local screen_h = math.floor((tonumber(resolution.height) or 1080) / math.max(0.25, scale))
  local frame_w = 940
  local x_right = math.max(24, screen_w - frame_w - 36)
  local y = math.max(24, math.min(72, math.floor(screen_h * 0.04)))
  -- 0.1.567: keep the Machine-Spirit ledger docked on the right so it
  -- does not overlap the left-pinned Work-State Reliquary.
  return { x = x_right, y = y }
end

local function add_summary(parent, record)
  local entity = record.entity
  local force = entity and entity.valid and entity.force or nil
  local base_max = get_base_sanctification_max and get_base_sanctification_max(force) or 100
  local current = tonumber(record.sanctification) or 0
  local max_value = tonumber(record.max_sanctification) or base_max
  local lost = math.max(0, base_max - max_value)
  local ops = tonumber(record.completed_operations_seen_0417 or record.completed_operations_seen_0413 or record.completed_operations_seen_0422 or 0) or 0

  local summary = parent.add{ type = "flow", direction = "vertical" }
  local machine_id = tech_priests_0446_format_machine_id and tech_priests_0446_format_machine_id(record) or "TP-M????"
  local spirit = record.machine_spirit_0523 or {}
  local machine_name = spirit.display_name or (spirit.named and "Machine" or "Unnamed Machine-Spirit")
  local id_line = summary.add{ type = "label", caption = "Sacred designation: " .. tostring(machine_name) .. " // " .. machine_id .. "    Shell unit: " .. tostring(record.unit_number or (entity and entity.valid and entity.unit_number) or "?") .. "    Auspex rite: " .. tostring(record.last_operation_sensor_0446 or "awaiting-incense") }
  set_label_style(id_line, 720, { r = 0.95, g = 0.86, b = 0.32 })
  local line1 = summary.add{ type = "label", caption = "Machine-spirit purity: " .. fmt(current, 2) .. " / " .. fmt(max_value, 2) .. "  (sanctioned vessel cap " .. fmt(base_max, 0) .. ")" }
  set_label_style(line1, 620, { r = 0.35, g = 1.0, b = 0.45 })
  local line2 = summary.add{ type = "label", caption = "Irrecoverable sanctity scarring: " .. fmt(lost, 2) .. "" }
  set_label_style(line2, 620, { r = 1.0, g = 0.22, b = 0.18 })
  local spirit_category = spirit.taxonomy_label_0524 or spirit.taxonomy_category_0524 or "taxonomy awaiting first milestone"
  local line_name = summary.add{ type = "label", caption = "Machine-spirit name: " .. tostring(machine_name) .. "    Caste: " .. tostring(spirit_category) .. "    Marks: " .. tostring((spirit.counts and spirit.counts.total_marks) or ((spirit.traits and #spirit.traits or 0) + (spirit.quirks and #spirit.quirks or 0) + (spirit.flaws and #spirit.flaws or 0))) }
  set_label_style(line_name, 720, { r = 0.82, g = 0.72, b = 1.0 })
  local line3 = summary.add{ type = "label", caption = "Completed work-rites witnessed: " .. tostring(ops) .. "    Last corrosion bell: " .. tostring(record.last_sanctification_decay_tick_0417 or record.last_sanctification_decay_tick_0413 or "none-recorded") }
  set_label_style(line3, 620, { r = 0.70, g = 0.95, b = 0.70 })
  local source_line = summary.add{ type = "label", caption = "Last purity source: " .. tostring(record.last_consecration_source_0478 or "no restoration rite recorded") .. " | item " .. tostring(record.last_consecration_item_0478 or "none") .. " | celebrant " .. tostring(record.last_consecration_actor_0478 or "none") }
  set_label_style(source_line, 720, { r = 0.95, g = 0.78, b = 0.40 })
  if record.last_consecration_priest_unit_0515 or record.last_consecration_station_unit_0515 or record.last_consecration_method_0515 then
    local priest_line = summary.add{ type = "label", caption = "Rite authority: priest-unit " .. tostring(record.last_consecration_priest_unit_0515 or "?") .. " | station " .. tostring(record.last_consecration_station_label_0515 or record.last_consecration_station_unit_0515 or "?") .. " | method " .. tostring(record.last_consecration_method_0515 or "?") .. " | order " .. tostring(record.last_consecration_order_0515 or "none") }
    set_label_style(priest_line, 720, { r = 0.72, g = 0.90, b = 1.0 })
  end

  add_sanctity_bar(summary, current, max_value, base_max, 620)
end

local function add_trait_table(parent, title, list, color, empty_text)
  local section = parent.add{ type = "flow", direction = "vertical" }
  pcall(function() section.style.minimal_width = TRAIT_TABLE_WIDTH end)
  pcall(function() section.style.horizontally_stretchable = true end)
  local heading = section.add{ type = "label", caption = tostring(title or "Machine-Spirit Marks") }
  set_label_style(heading, 820, color or { r = 0.95, g = 0.86, b = 0.32 })
  pcall(function() heading.style.font = "default-bold" end)
  list = list or {}
  if #list == 0 then
    local empty = section.add{ type = "label", caption = empty_text or "No marks recorded." }
    set_label_style(empty, 760, { r = 0.70, g = 0.70, b = 0.70 })
    return section
  end
  local table_el = section.add{ type = "table", column_count = 6 }
  set_table_style(table_el)
  local headers = { "rite", "milestone", "caste", "mark", "name", "record" }
  for _, h in ipairs(headers) do
    local header = table_el.add{ type = "label", caption = h }
    set_label_style(header, nil, { r = 0.95, g = 0.86, b = 0.32 })
  end
  for i = #list, 1, -1 do
    local mark = list[i]
    table_el.add{ type = "label", caption = tostring(mark.operation or "?") }
    table_el.add{ type = "label", caption = "10^" .. tostring(math.floor((math.log(tonumber(mark.milestone or 1)) / math.log(10)) + 0.5)) }
    local caste = table_el.add{ type = "label", caption = tostring(mark.category_label or mark.category or "sanctified machine") }
    set_label_style(caste, 130, { r = 0.72, g = 0.84, b = 1.0 })
    local kind = table_el.add{ type = "label", caption = tostring(mark.kind or mark.polarity or "mark") }
    set_label_style(kind, nil, color)
    local name = table_el.add{ type = "label", caption = tostring(mark.name or "Machine") }
    set_label_style(name, 150, color)
    local status = tostring(mark.implementation_status or "lore-only")
    local desc = table_el.add{ type = "label", caption = tostring(mark.text or "Awaiting lexmechanic annotation.") .. " [" .. status .. "]" }
    set_label_style(desc, 430, { r = 0.82, g = 0.88, b = 0.82 })
  end
  return section
end

local function add_machine_spirit_ledger(parent, record)
  local spirit = record.machine_spirit_0523 or {}
  local wrapper = parent.add{ type = "flow", direction = "vertical" }
  pcall(function() wrapper.style.minimal_width = 870 end)
  pcall(function() wrapper.style.horizontally_stretchable = true end)
  local ledger_heading = wrapper.add{ type = "label", caption = "Machine-Spirit Character Ledger" }
  set_label_style(ledger_heading, 820, { r = 0.95, g = 0.86, b = 0.32 })
  pcall(function() ledger_heading.style.font = "default-bold" end)
  local name = spirit.display_name or "Machine"
  local named = spirit.named and "sealed" or "awaiting two marks"
  local total = (spirit.counts and spirit.counts.total_marks) or ((spirit.traits and #spirit.traits or 0) + (spirit.quirks and #spirit.quirks or 0) + (spirit.flaws and #spirit.flaws or 0))
  local caste = spirit.taxonomy_label_0524 or spirit.taxonomy_category_0524 or "awaiting first sanctified operation"
  local summary = wrapper.add{ type = "label", caption = "Name seal: " .. tostring(name) .. " (" .. tostring(named) .. ")    Caste: " .. tostring(caste) .. "    Machine-spirit marks: " .. tostring(total) .. "    Roll gates: 1 / 10 / 100 / 1k / 10k / 100k / 1M work-rites" }
  set_label_style(summary, 820, { r = 0.82, g = 0.72, b = 1.0 })
  local policy = wrapper.add{ type = "label", caption = "Doctrine: only sanctification-eligible machines roll marks. Trait pools are now machine-caste aware; belts, inserters, pipes, walls, and other non-sanctified entities are ignored. Current trait effects are lore-only until deliberately wired through the relevant authority." }
  set_label_style(policy, 820, { r = 0.72, g = 0.95, b = 0.72 })

  add_trait_table(wrapper, "Virtues and Auspicious Quirks", spirit.positive_history or spirit.traits or {}, { r = 0.35, g = 1.0, b = 0.45 }, "No positive quirks or traits have been witnessed yet.")
  add_trait_table(wrapper, "Flaws and Machine-Spirit Complaints", spirit.negative_history or spirit.flaws or {}, { r = 1.0, g = 0.35, b = 0.24 }, "No flaws have been witnessed yet.")
  add_trait_table(wrapper, "Neutral Temperament Marks", spirit.neutral_history or {}, { r = 0.72, g = 0.84, b = 1.0 }, "No neutral quirks have been witnessed yet.")
end

local function add_history(parent, record)
  local entity = record.entity
  local force = entity and entity.valid and entity.force or nil
  local base_max = get_base_sanctification_max and get_base_sanctification_max(force) or 100
  local history = record.consecration_history_0422 or {}

  local caption = "Sanctity augury, newest rite first. Green marks present purity; grey marks recoverable vessel capacity; red marks sanctity permanently scarred."
  local note = parent.add{ type = "label", caption = caption }
  set_label_style(note, 760, { r = 0.72, g = 0.95, b = 0.72 })

  local scroll = parent.add{ type = "scroll-pane", name = "tech_priests_consecration_history_scroll_0422" }
  set_scroll_style_0564(scroll)
  pcall(function() scroll.style.maximal_height = 430 end)
  pcall(function() scroll.style.minimal_width = 840 end)

  local table_el = scroll.add{ type = "table", column_count = 9 }
  set_table_style(table_el)
  local headers = { "rite", "sigil", "source", "purity trace", "after", "loss", "scar", "detritus", "bell" }
  for _, h in ipairs(headers) do
    local header = table_el.add{ type = "label", caption = h }
    set_label_style(header, nil, { r = 0.95, g = 0.86, b = 0.32 })
  end

  if #history == 0 then
    local empty = scroll.add{ type = "label", caption = "No completed work-rites have yet been witnessed by this reliquary." }
    set_label_style(empty, 760, { r = 1.0, g = 0.65, b = 0.32 })
    return
  end

  for index = #history, 1, -1 do
    local entry = history[index]
    table_el.add{ type = "label", caption = tostring(entry.operation or index) }
    table_el.add{ type = "label", caption = tostring(entry.machine_id_text or (entry.machine_id and string.format("TP-M%04d", tonumber(entry.machine_id) or 0)) or "—") }
    local src = table_el.add{ type = "label", caption = tostring(entry.source or entry.actor or entry.event_type or "operation") }
    set_label_style(src, 130, { r = 0.95, g = 0.78, b = 0.40 })
    add_sanctity_bar(table_el, entry.after, entry.max_after or entry.max, entry.base_max or base_max, 335)
    table_el.add{ type = "label", caption = fmt(entry.after, 2) .. " / " .. fmt(entry.max_after or entry.max, 2) }
    table_el.add{ type = "label", caption = "-" .. fmt(entry.decay, 3) }
    local lost = tonumber(entry.max_lost_this_operation or 0) or 0
    local cap = table_el.add{ type = "label", caption = lost > 0 and ("-" .. fmt(lost, 3)) or "—" }
    if lost > 0 then set_label_style(cap, nil, { r = 1.0, g = 0.22, b = 0.18 }) end
    local waste = tonumber(entry.waste_inserted or 0) or 0
    table_el.add{ type = "label", caption = waste > 0 and tostring(waste) or "—" }
    table_el.add{ type = "label", caption = tostring(entry.tick or "?") }
  end
end


local function current_machine_spirit_tab_index_0567(player)
  local frame = player and player.valid and player.gui and player.gui.screen and player.gui.screen[FRAME_NAME] or nil
  if not (frame and frame.valid) then return nil end
  local function find_tabs(element)
    if not (element and element.valid) then return nil end
    local ok_name, name = pcall(function() return element.name end)
    if ok_name and name == "tech_priests_machine_spirit_tabs_0526" then return element end
    local ok_children, children = pcall(function() return element.children end)
    if ok_children and children then
      for _, child in pairs(children) do
        local found = find_tabs(child)
        if found then return found end
      end
    end
    return nil
  end
  local tabs = find_tabs(frame)
  local idx = nil
  if tabs and tabs.valid then pcall(function() idx = tabs.selected_tab_index end) end
  return tonumber(idx)
end

function M.open_for_player(player, entity)
  local root = ensure_root()
  root.stats.open_attempts = (root.stats.open_attempts or 0) + 1
  root.stats.last_open_attempt_tick = game and game.tick or 0
  root.stats.last_open_attempt_entity = entity and entity.valid and entity.name or tostring(entity)
  if not (player and player.valid and entity and entity.valid) then
    root.stats.open_invalid_context = (root.stats.open_invalid_context or 0) + 1
    return false
  end
  local record = get_record(entity)
  if not record then
    root.stats.open_no_record = (root.stats.open_no_record or 0) + 1
    root.stats.last_no_record_entity = entity.name
    return false
  end
  local previous_location = nil
  local previous_tab_index = current_machine_spirit_tab_index_0567(player)
  local previous = player.gui.screen and player.gui.screen[FRAME_NAME] or nil
  if previous and previous.valid then
    pcall(function() previous_location = previous.location end)
  end
  destroy_frame(player)

  local frame = player.gui.screen.add{ type = "frame", name = FRAME_NAME, direction = "vertical", caption = "Machine-Spirit State Ledger :: " .. machine_spirit_header_text_0526(record, entity) }
  apply_style_0564(frame, "tech_priests_cogitator_outer_frame_0532")
  local ledger_panel_w = 940
  local ledger_panel_h = 900
  pcall(function() frame.style.minimal_width = ledger_panel_w end)
  pcall(function() frame.style.maximal_width = ledger_panel_w end)
  pcall(function() frame.style.minimal_height = ledger_panel_h end)
  pcall(function() frame.style.maximal_height = ledger_panel_h end)
  if previous_location then
    pcall(function() frame.location = previous_location end)
  else
    pcall(function() frame.auto_center = false end)
    pcall(function() frame.location = choose_ledger_location(player, entity) end)
  end

  local shell_body, shell_content_w, shell_content_h = add_machine_spirit_sliced_shell_0567(frame, ledger_panel_w, ledger_panel_h)
  local ledger_parent = shell_body or frame

  local header = ledger_parent.add{ type = "flow", direction = "horizontal" }
  header.add{ type = "label", caption = machine_spirit_header_text_0526(record, entity) .. " // " .. tostring(machine_display_name(entity)) }
  header.add{ type = "empty-widget" }.style.horizontally_stretchable = true
  local refresh_button = header.add{ type = "button", name = REFRESH_NAME, caption = "Recast Machine Auspex" }
  apply_style_0564(refresh_button, "tech_priests_cogitator_button_0532")
  local close_button = header.add{ type = "button", name = CLOSE_NAME, caption = "Seal Reliquary" }
  apply_style_0564(close_button, "tech_priests_cogitator_button_0532")

  local screen_body = ledger_parent.add{ type = "frame", name = "tech_priests_machine_spirit_inner_screen_0565", direction = "vertical" }
  set_display_frame_style_0565(screen_body)
  pcall(function() screen_body.style.minimal_width = math.max(680, (shell_content_w or 760) - 22) end)
  pcall(function() screen_body.style.maximal_width = math.max(680, (shell_content_w or 760) - 22) end)
  pcall(function() screen_body.style.minimal_height = math.max(620, (shell_content_h or 720) - 72) end)
  local tabs = screen_body.add{ type = "tabbed-pane", name = "tech_priests_machine_spirit_tabs_0526" }
  apply_style_0564(tabs, "tech_priests_cogitator_tabbed_pane_0532")
  local summary_tab = tabs.add{ type = "tab", caption = "Spirit Seal" }
  apply_style_0564(summary_tab, "tech_priests_cogitator_tab_0541")
  local summary_page = tabs.add{ type = "scroll-pane", name = "tech_priests_machine_spirit_summary_scroll_0526", direction = "vertical" }
  set_scroll_style_0564(summary_page)
  pcall(function() summary_page.style.maximal_height = 640 end)
  tabs.add_tab(summary_tab, summary_page)
  add_summary(summary_page, record)

  local marks_tab = tabs.add{ type = "tab", caption = "Traits / Flaws" }
  apply_style_0564(marks_tab, "tech_priests_cogitator_tab_0541")
  local marks_page = tabs.add{ type = "scroll-pane", name = "tech_priests_machine_spirit_marks_scroll_0526", direction = "vertical" }
  set_scroll_style_0564(marks_page)
  pcall(function() marks_page.style.maximal_height = 680 end)
  tabs.add_tab(marks_tab, marks_page)
  add_machine_spirit_ledger(marks_page, record)

  local history_tab = tabs.add{ type = "tab", caption = "Rite History" }
  apply_style_0564(history_tab, "tech_priests_cogitator_tab_0541")
  local history_page = tabs.add{ type = "flow", name = "tech_priests_machine_spirit_history_page_0526", direction = "vertical" }
  pcall(function() history_page.style.horizontally_stretchable = true end)
  pcall(function() history_page.style.vertically_stretchable = true end)
  tabs.add_tab(history_tab, history_page)
  add_history(history_page, record)

  pcall(function() tabs.selected_tab_index = math.max(1, math.min(3, tonumber(previous_tab_index) or tonumber((root.open[player.index] or {}).tab_index) or 1)) end)
  root.open[player.index] = { unit = entity.unit_number, tick = game and game.tick or 0, tab_index = current_machine_spirit_tab_index_0567(player) or previous_tab_index or 1 }
  root.stats.open_success = (root.stats.open_success or 0) + 1
  root.stats.last_open_success_machine = tech_priests_0446_format_machine_id and tech_priests_0446_format_machine_id(record) or tostring(record.unit_number)
  return true
end

function M.refresh_open_frame(player)
  if not (player and player.valid) then return false end
  local root = ensure_root()
  local state = root.open[player.index]
  if not (state and state.unit) then return false end
  state.tab_index = current_machine_spirit_tab_index_0567(player) or state.tab_index or 1
  local record = find_record_by_unit(state.unit)
  if not record then destroy_frame(player); return false end
  return M.open_for_player(player, record.entity)
end

function M.handle_gui_opened(event)
  local player = event and event.player_index and game and game.get_player(event.player_index) or nil
  if not (player and player.valid) then return end
  local entity = event.entity
  if not (entity and entity.valid) then
    pcall(function() if player.opened and player.opened.valid then entity = player.opened end end)
  end
  if entity and entity.valid then
    M.open_for_player(player, entity)
  else
    local root = ensure_root(); root.stats.open_event_no_entity = (root.stats.open_event_no_entity or 0) + 1
  end
end

function M.handle_gui_closed(event)
  local player = event and event.player_index and game and game.get_player(event.player_index) or nil
  if not (player and player.valid) then return end
  local root = ensure_root()
  local open = root.open[player.index]
  if not open then return end
  local entity = event.entity
  if entity and entity.valid and open.unit and entity.unit_number == open.unit then
    destroy_frame(player)
  end
end

function M.handle_gui_click(event)
  local player = event and event.player_index and game and game.get_player(event.player_index) or nil
  local element = event and event.element
  if not (player and player.valid and element and element.valid) then return end
  if element.name == CLOSE_NAME then
    destroy_frame(player)
  elseif element.name == REFRESH_NAME then
    M.refresh_open_frame(player)
  end
end

function M.refresh_all_open()
  if not (game and game.connected_players) then return end
  local root = ensure_root()
  for _, player in pairs(game.connected_players) do
    if player and player.valid and root.open[player.index] then
      M.refresh_open_frame(player)
    end
  end
end

function M.install()
  ensure_root()
  local gui_bus = nil
  pcall(function() gui_bus = require("scripts.core.gui_bus") end)
  if gui_bus and gui_bus.register then
    gui_bus.register("opened", M.handle_gui_opened)
    gui_bus.register("closed", M.handle_gui_closed)
    gui_bus.register("click", M.handle_gui_click)
  elseif script and defines and defines.events and script.on_event then
    script.on_event(defines.events.on_gui_opened, M.handle_gui_opened)
    script.on_event(defines.events.on_gui_closed, M.handle_gui_closed)
    script.on_event(defines.events.on_gui_click, M.handle_gui_click)
  end
  -- 0.1.453: also register through the runtime event registry when available.
  -- This gives the machine history panel a second stable hook after the control.lua split.
  if TechPriestsRuntimeEventRegistry and TechPriestsRuntimeEventRegistry.on_event and defines and defines.events then
    pcall(function() TechPriestsRuntimeEventRegistry.on_event(defines.events.on_gui_opened, M.handle_gui_opened, nil, { owner = "consecration-history-gui", category = "gui" }) end)
    pcall(function() TechPriestsRuntimeEventRegistry.on_event(defines.events.on_gui_closed, M.handle_gui_closed, nil, { owner = "consecration-history-gui", category = "gui" }) end)
    pcall(function() TechPriestsRuntimeEventRegistry.on_event(defines.events.on_gui_click, M.handle_gui_click, nil, { owner = "consecration-history-gui", category = "gui" }) end)
  end

  if script and script.on_nth_tick then
    script.on_nth_tick(121, function() M.refresh_all_open() end)
  end

  if commands and commands.add_command then
    pcall(function() commands.remove_command("tp-consecration-history-0422") end)
    commands.add_command("tp-consecration-history-0422", "Tech Priests: open the Machine-Spirit State Ledger for the selected machine.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      if not (player and player.valid) then return end
      if M.open_for_player(player, player.selected) then return end
      player.print("[tp-consecration-history-0422] Select a machine known to the Cult Mechanicus ledger.")
    end)

    pcall(function() commands.remove_command("tp-consecration-history-0453") end)
    commands.add_command("tp-consecration-history-0453", "Tech Priests: open the Machine-Spirit State Ledger and rite trace for the selected machine.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      if not (player and player.valid) then return end
      local entity = player.selected
      if M.open_for_player(player, entity) then return end
      local root = ensure_root()
      local stats = root.stats or {}
      player.print("[tp-consecration-history-0453] The ledger found no awakened machine-spirit record. attempts=" .. tostring(stats.open_attempts or 0) .. " consecrated=" .. tostring(stats.open_success or 0) .. " unrecorded=" .. tostring(stats.open_no_record or 0) .. " last=" .. tostring(stats.last_open_attempt_entity or "nil"))
    end)
  end

  if log then log("[Tech-Priests 0.1.526] Machine-Spirit State Ledger GUI installed with named header and diegetic tabbed ledger") end
  return true
end

function tech_priests_0422_record_consecration_history(record, event)
  if not (record and record.entity and record.entity.valid and event) then return false end
  record.consecration_history_0422 = record.consecration_history_0422 or {}
  local history = record.consecration_history_0422
  history[#history + 1] = event
  while #history > HISTORY_LIMIT do table.remove(history, 1) end
  record.completed_operations_seen_0422 = (record.completed_operations_seen_0422 or 0) + 1
  record.last_history_tick_0422 = event.tick or (game and game.tick or 0)
  return true
end

return M
