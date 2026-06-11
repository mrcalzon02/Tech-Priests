-- split source: tech-priests_src/scripts/core/consecration/history_gui.lua lines 275-291
local function add_machine_spirit_sliced_shell_0567(parent, panel_w, panel_h)
  local total_w = math.max(780, math.floor((panel_w or 900) - 20))
  local total_h = math.max(720, math.floor((panel_h or 860) - 40))
  local middle_h = math.max(560, total_h - 128)
  local center_w = math.max(640, total_w - 128)
  local outer = parent.add{ type = "flow", direction = "vertical", name = "tech_priests_machine_spirit_sliced_cogitator_shell_0567" }
  style_fixed_flow_0567(outer, total_w, total_h, "vertical")
  add_top_or_bottom_frame_row_0567(outer, "top", total_w)
  local middle = outer.add{ type = "flow", direction = "horizontal", name = "tech_priests_machine_spirit_gui_frame_0567_middle" }
  style_fixed_flow_0567(middle, total_w, middle_h, "horizontal")
  add_segmented_vertical_column_0567(middle, "left-column", middle_h)
  local body, content_w, content_h = add_inner_bezel_shell_0567(middle, center_w, middle_h)
  add_segmented_vertical_column_0567(middle, "right-column", middle_h)
  add_top_or_bottom_frame_row_0567(outer, "bottom", total_w)
  return body, content_w, content_h, total_w, total_h
end

