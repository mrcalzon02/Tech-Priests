-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 162-171
local function apply_screen_table_style_0564(element)
  if not (element and element.valid) then return false end
  apply_gui_style_0532(element, "tech_priests_cogitator_screen_table_0564")
  pcall(function() element.style.horizontally_stretchable = true end)
  pcall(function() element.style.cell_padding = 4 end)
  pcall(function() element.style.horizontal_spacing = 6 end)
  pcall(function() element.style.vertical_spacing = 4 end)
  return true
end

