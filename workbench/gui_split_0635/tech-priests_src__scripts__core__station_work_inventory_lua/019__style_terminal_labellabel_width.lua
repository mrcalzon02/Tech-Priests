-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 172-183
local function style_terminal_label(label, width)
  if not (label and label.valid) then return end
  local w = width or M.label_wrap_width
  pcall(function() label.style.single_line = false end)
  pcall(function() label.style.maximal_width = w end)
  pcall(function() label.style.minimal_width = math.min(w, 120) end)
  pcall(function() label.style.horizontally_stretchable = false end)
  pcall(function() label.style.font = M.font_terminal end)
  pcall(function() label.style.font_color = { r = 0.20, g = 1.00, b = 0.22 } end)
end


