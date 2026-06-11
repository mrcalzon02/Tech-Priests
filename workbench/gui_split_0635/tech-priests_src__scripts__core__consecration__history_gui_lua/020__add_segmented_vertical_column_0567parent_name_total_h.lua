-- split source: tech-priests_src/scripts/core/consecration/history_gui.lua lines 213-222
local function add_segmented_vertical_column_0567(parent, name, total_h)
  local col = parent.add{ type = "flow", direction = "vertical", name = "tech_priests_machine_spirit_gui_frame_0567_" .. name }
  style_fixed_flow_0567(col, 64, total_h, "vertical")
  local mid_h = math.max(1, math.floor((total_h or 256) - 128))
  add_frame_slice_0567(col, "0540", name .. "-cap-top", 64, 64)
  add_tiled_mid_0567(col, "0540", name .. "-mid", mid_h, 128, 64, nil, false)
  add_frame_slice_0567(col, "0540", name .. "-cap-bottom", 64, 64)
  return col
end

