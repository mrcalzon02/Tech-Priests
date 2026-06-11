-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 2298-2307
local function add_segmented_horizontal_rail_0540(parent, name, total_w, height)
  local cap = 24
  local mid_w = math.max(1, math.floor((total_w or 80) - cap * 2))
  add_frame_slice_0540(parent, name .. "-cap-a", cap, height)
  -- 0.1.541: tile the rail middle instead of stretching one strip; the caps
  -- keep their authored detail and only the repeating pipe body fills length.
  add_tiled_frame_mid_0541(parent, name, name .. "-mid", mid_w, 32, nil, height, true)
  add_frame_slice_0540(parent, name .. "-cap-b", cap, height)
end

