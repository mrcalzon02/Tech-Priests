-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1859-1872
local function add_command_node_table_0521(parent, caption, rows, H, empty_text)
  local frame = parent.add({ type = "frame", caption = caption, direction = "vertical" })
  apply_display_frame_style_0540(frame)
  if not rows or #rows == 0 then
    add_label(frame, "  " .. tostring(empty_text or "none"))
    return frame
  end
  local t = frame.add({ type = "table", column_count = 7 })
  apply_screen_table_style_0564(t)
  add_command_tree_header_0521(t)
  for _, rec in ipairs(rows) do add_command_tree_row_0495(t, rec.relation, rec.pair, H) end
  return frame
end

