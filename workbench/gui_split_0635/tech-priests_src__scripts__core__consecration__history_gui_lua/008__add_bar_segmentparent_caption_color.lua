-- split source: tech-priests_src/scripts/core/consecration/history_gui.lua lines 81-89
local function add_bar_segment(parent, caption, color)
  if caption == "" then return nil end
  local label = parent.add{ type = "label", caption = caption }
  set_label_style(label, nil, color)
  pcall(function() label.style.single_line = true end)
  pcall(function() label.style.font = "default-bold" end)
  return label
end

