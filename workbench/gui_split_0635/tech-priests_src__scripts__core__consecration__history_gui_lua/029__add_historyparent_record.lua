-- split source: tech-priests_src/scripts/core/consecration/history_gui.lua lines 412-459
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


