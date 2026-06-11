-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 2345-2379
local function add_inner_bezel_shell_0536(parent, total_w, total_h)
  local m = GUI_FRAME_0536
  local bezel = m.bezel
  local content_w = math.max(520, math.floor((total_w or 720) - bezel * 2))
  local content_h = math.max(420, math.floor((total_h or 620) - bezel * 2))
  local shell = parent.add({ type = "flow", direction = "vertical", name = "tech_priests_gui_inner_bezel_shell_0536" })
  style_fixed_flow_0536(shell, content_w + bezel * 2, content_h + bezel * 2, "vertical")

  local top = shell.add({ type = "flow", direction = "horizontal" })
  style_fixed_flow_0536(top, content_w + bezel * 2, bezel, "horizontal")
  add_frame_slice_0536(top, "inner-bezel-tl", bezel, bezel)
  add_frame_slice_0536(top, "inner-bezel-t", content_w, bezel)
  add_frame_slice_0536(top, "inner-bezel-tr", bezel, bezel)

  local mid = shell.add({ type = "flow", direction = "horizontal" })
  style_fixed_flow_0536(mid, content_w + bezel * 2, content_h, "horizontal")
  add_frame_slice_0536(mid, "inner-bezel-l", bezel, content_h)
  local content = mid.add({ type = "frame", name = "tech_priests_workstate_gui_body_0536", direction = "vertical" })
  apply_display_frame_style_0540(content)
  pcall(function() content.style.padding = 8 end)
  pcall(function() content.style.minimal_width = content_w end)
  pcall(function() content.style.maximal_width = content_w end)
  pcall(function() content.style.minimal_height = content_h end)
  pcall(function() content.style.maximal_height = content_h end)
  add_frame_slice_0536(mid, "inner-bezel-r", bezel, content_h)

  local bottom = shell.add({ type = "flow", direction = "horizontal" })
  style_fixed_flow_0536(bottom, content_w + bezel * 2, bezel, "horizontal")
  add_frame_slice_0536(bottom, "inner-bezel-bl", bezel, bezel)
  add_frame_slice_0536(bottom, "inner-bezel-b", content_w, bezel)
  add_frame_slice_0536(bottom, "inner-bezel-br", bezel, bezel)

  return content, content_w, content_h
end

