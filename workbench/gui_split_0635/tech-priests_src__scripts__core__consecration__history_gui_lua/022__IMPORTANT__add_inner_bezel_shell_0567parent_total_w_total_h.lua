-- split source: tech-priests_src/scripts/core/consecration/history_gui.lua lines 245-274
local function add_inner_bezel_shell_0567(parent, total_w, total_h)
  local bezel = 20
  local content_w = math.max(560, math.floor((total_w or 720) - bezel * 2))
  local content_h = math.max(500, math.floor((total_h or 620) - bezel * 2))
  local shell = parent.add{ type = "flow", direction = "vertical", name = "tech_priests_machine_spirit_inner_bezel_shell_0567" }
  style_fixed_flow_0567(shell, content_w + bezel * 2, content_h + bezel * 2, "vertical")
  local top = shell.add{ type = "flow", direction = "horizontal" }
  style_fixed_flow_0567(top, content_w + bezel * 2, bezel, "horizontal")
  add_frame_slice_0567(top, "0536", "inner-bezel-tl", bezel, bezel)
  add_frame_slice_0567(top, "0536", "inner-bezel-t", content_w, bezel)
  add_frame_slice_0567(top, "0536", "inner-bezel-tr", bezel, bezel)
  local mid = shell.add{ type = "flow", direction = "horizontal" }
  style_fixed_flow_0567(mid, content_w + bezel * 2, content_h, "horizontal")
  add_frame_slice_0567(mid, "0536", "inner-bezel-l", bezel, content_h)
  local content = mid.add{ type = "frame", name = "tech_priests_machine_spirit_gui_body_0567", direction = "vertical" }
  set_display_frame_style_0565(content)
  pcall(function() content.style.padding = 10 end)
  pcall(function() content.style.minimal_width = content_w end)
  pcall(function() content.style.maximal_width = content_w end)
  pcall(function() content.style.minimal_height = content_h end)
  pcall(function() content.style.maximal_height = content_h end)
  add_frame_slice_0567(mid, "0536", "inner-bezel-r", bezel, content_h)
  local bottom = shell.add{ type = "flow", direction = "horizontal" }
  style_fixed_flow_0567(bottom, content_w + bezel * 2, bezel, "horizontal")
  add_frame_slice_0567(bottom, "0536", "inner-bezel-bl", bezel, bezel)
  add_frame_slice_0567(bottom, "0536", "inner-bezel-b", content_w, bezel)
  add_frame_slice_0567(bottom, "0536", "inner-bezel-br", bezel, bezel)
  return content, content_w, content_h
end

