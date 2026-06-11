-- split source: tech-priests_src/scripts/core/consecration/history_gui.lua lines 90-114
local function add_sanctity_bar(parent, after, max_value, base_max, width)
  local flow = parent.add{ type = "flow", direction = "horizontal" }
  pcall(function() flow.style.minimal_width = width or 335 end)
  pcall(function() flow.style.maximal_width = width or 620 end)
  local current_cells, empty_cells, lost_cells = bar_counts(after, max_value, base_max)
  local function reps(ch, n)
    if n <= 0 then return "" end
    return string.rep(ch, n)
  end
  add_bar_segment(flow, reps("█", current_cells), { r = 0.15, g = 0.95, b = 0.20 })
  add_bar_segment(flow, reps("░", empty_cells), { r = 0.42, g = 0.45, b = 0.42 })
  add_bar_segment(flow, reps("█", lost_cells), { r = 1.0, g = 0.18, b = 0.12 })
  if current_cells + empty_cells + lost_cells <= 0 then
    add_bar_segment(flow, reps("░", GRAPH_WIDTH), { r = 0.42, g = 0.45, b = 0.42 })
  end
  return flow
end

set_label_style = function(label, width, font_color)
  if not (label and label.valid and label.style) then return end
  if width then pcall(function() label.style.width = width end) end
  if font_color then pcall(function() label.style.font_color = font_color end) end
  pcall(function() label.style.single_line = false end)
end

