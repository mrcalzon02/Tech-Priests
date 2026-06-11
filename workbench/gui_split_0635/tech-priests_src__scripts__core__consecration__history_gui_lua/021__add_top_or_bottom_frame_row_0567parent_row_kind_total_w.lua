-- split source: tech-priests_src/scripts/core/consecration/history_gui.lua lines 223-244
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

