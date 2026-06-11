-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 2380-2401
local function add_sliced_cogitator_shell_0536(parent, panel_w, panel_h)
  local m = GUI_FRAME_0536
  local total_w = math.max(820, math.floor((panel_w or 1120) - m.outer_margin_w))
  local total_h = math.max(680, math.floor((panel_h or 900) - m.outer_margin_h))
  local middle_h = math.max(520, total_h - (m.top_bottom_h * 2))
  local center_w = math.max(620, total_w - (m.side_column * 2))

  local outer = parent.add({ type = "flow", direction = "vertical", name = "tech_priests_sliced_cogitator_shell_0536" })
  style_fixed_flow_0536(outer, total_w, total_h, "vertical")

  add_top_or_bottom_frame_row_0536(outer, "top", total_w)

  local middle = outer.add({ type = "flow", direction = "horizontal", name = "tech_priests_gui_frame_0536_middle" })
  style_fixed_flow_0536(middle, total_w, middle_h, "horizontal")
  add_segmented_vertical_column_0540(middle, "left-column", middle_h)
  local body, content_w, content_h = add_inner_bezel_shell_0536(middle, center_w, middle_h)
  add_segmented_vertical_column_0540(middle, "right-column", middle_h)

  add_top_or_bottom_frame_row_0536(outer, "bottom", total_w)
  return body, content_w, content_h, total_w, total_h
end

