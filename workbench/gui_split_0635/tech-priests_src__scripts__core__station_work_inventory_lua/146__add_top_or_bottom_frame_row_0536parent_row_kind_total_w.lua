-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 2322-2344
local function add_top_or_bottom_frame_row_0536(parent, row_kind, total_w)
  local m = GUI_FRAME_0536
  local row = parent.add({ type = "flow", direction = "horizontal", name = "tech_priests_gui_frame_0536_" .. row_kind })
  style_fixed_flow_0536(row, total_w, m.top_bottom_h, "horizontal")
  local rail_total = math.max(80, (total_w or 0) - (m.corner * 2) - m.emblem_w)
  local rail_left_w = math.floor(rail_total / 2)
  local rail_right_w = rail_total - rail_left_w
  if row_kind == "top" then
    add_frame_slice_0536(row, "corner-top-left", m.corner, m.top_bottom_h)
    add_segmented_horizontal_rail_0540(row, "top-rail-left", rail_left_w, m.top_bottom_h)
    add_frame_slice_0536(row, "top-center-emblem", m.emblem_w, m.top_bottom_h)
    add_segmented_horizontal_rail_0540(row, "top-rail-right", rail_right_w, m.top_bottom_h)
    add_frame_slice_0536(row, "corner-top-right", m.corner, m.top_bottom_h)
  else
    add_frame_slice_0536(row, "corner-bottom-left", m.corner, m.top_bottom_h)
    add_segmented_horizontal_rail_0540(row, "bottom-rail-left", rail_left_w, m.top_bottom_h)
    add_frame_slice_0536(row, "bottom-center-emblem", m.emblem_w, m.top_bottom_h)
    add_segmented_horizontal_rail_0540(row, "bottom-rail-right", rail_right_w, m.top_bottom_h)
    add_frame_slice_0536(row, "corner-bottom-right", m.corner, m.top_bottom_h)
  end
  return row
end

