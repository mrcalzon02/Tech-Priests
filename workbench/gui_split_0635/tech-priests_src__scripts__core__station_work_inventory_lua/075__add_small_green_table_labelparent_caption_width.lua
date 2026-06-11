-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 992-998
local function add_small_green_table_label(parent, caption, width)
  local label = parent.add({ type = "label", caption = dictator_green(caption) })
  style_terminal_label(label, width or 160)
  pcall(function() label.style.minimal_width = math.min(width or 160, 220) end)
  return label
end

