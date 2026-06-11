-- split source: tech-priests_src/scripts/core/consecration/history_gui.lua lines 205-212
local function add_segmented_horizontal_rail_0567(parent, name, total_w, height)
  local cap = 24
  local mid_w = math.max(1, math.floor((total_w or 80) - cap * 2))
  add_frame_slice_0567(parent, "0540", name .. "-cap-a", cap, height)
  add_tiled_mid_0567(parent, "0540", name .. "-mid", mid_w, 32, nil, height, true)
  add_frame_slice_0567(parent, "0540", name .. "-cap-b", cap, height)
end

