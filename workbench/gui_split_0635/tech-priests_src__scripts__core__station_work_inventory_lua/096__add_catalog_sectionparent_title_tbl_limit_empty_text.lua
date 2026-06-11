-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1482-1502
local function add_catalog_section(parent, title, tbl, limit, empty_text)
  local rows, total = catalog_top_rows(tbl, limit)
  local section = parent.add({ type = "frame", caption = tostring(title or "Auspex section") .. " (" .. tostring(total) .. ")", direction = "vertical" })
  apply_display_frame_style_0540(section)
  if #rows == 0 then add_label(section, "  " .. tostring(empty_text or "none cataloged")); return end
  local table_el = section.add({ type = "table", column_count = 5 })
  apply_screen_table_style_0564(table_el)
  pcall(function() table_el.style.horizontally_stretchable = true end)
  local headers = { "Sigil", "Count", "Sources", "Nearest / Owner", "Doctrine" }
  local widths = { 180, 60, 60, 150, 170 }
  for i, h in ipairs(headers) do add_table_cell_0521(table_el, h, widths[i], true) end
  for _, row in ipairs(rows) do
    local tag = title:lower():find("resource", 1, true) and "entity" or "item"
    add_table_cell_0521(table_el, "[" .. tag .. "=" .. tostring(row.name) .. "] " .. tostring(row.name), widths[1], false)
    add_table_cell_0521(table_el, tostring(row.count), widths[2], false)
    add_table_cell_0521(table_el, tostring(row.sources), widths[3], false)
    add_table_cell_0521(table_el, row.owner and ("station#" .. tostring(row.owner)) or "local sweep", widths[4], false)
    add_table_cell_0521(table_el, tag == "item" and "fetch physically before station credit" or "target must be reached before extraction", widths[5], false)
  end
end

