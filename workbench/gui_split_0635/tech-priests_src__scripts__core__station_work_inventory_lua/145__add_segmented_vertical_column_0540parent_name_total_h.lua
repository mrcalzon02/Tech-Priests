-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 2308-2321
local function add_segmented_vertical_column_0540(parent, name, total_h)
  local m = GUI_FRAME_0536
  local col = parent.add({ type = "flow", direction = "vertical", name = "tech_priests_gui_frame_0540_" .. name })
  style_fixed_flow_0536(col, m.side_column, total_h, "vertical")
  local cap = 64
  local mid_h = math.max(1, math.floor((total_h or 256) - cap * 2))
  add_frame_slice_0540(col, name .. "-cap-top", m.side_column, cap)
  -- 0.1.541: side-column middles are tiled sections, not a single stretched
  -- vertical smear. This preserves the gauge/cable detail in the end caps.
  add_tiled_frame_mid_0541(col, name, name .. "-mid", mid_h, 128, m.side_column, nil, false)
  add_frame_slice_0540(col, name .. "-cap-bottom", m.side_column, cap)
  return col
end

