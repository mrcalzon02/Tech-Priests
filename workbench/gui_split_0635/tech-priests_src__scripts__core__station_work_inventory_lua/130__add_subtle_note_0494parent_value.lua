-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 2027-2032
local function add_subtle_note_0494(parent, value)
  local label = add_label(parent, tostring(value or ""))
  pcall(function() label.style.font_color = { r = 0.50, g = 0.95, b = 0.50 } end)
  return label
end

