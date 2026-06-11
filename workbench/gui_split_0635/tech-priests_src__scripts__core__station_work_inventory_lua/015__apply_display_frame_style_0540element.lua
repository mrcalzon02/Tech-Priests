-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 118-129
local function apply_display_frame_style_0540(element)
  if not (element and element.valid) then return false end
  if not apply_gui_style_0532(element, "tech_priests_cogitator_display_frame_0540") then
    apply_gui_style_0532(element, "tech_priests_cogitator_inner_frame_0532")
  end
  pcall(function() element.style.horizontally_stretchable = true end)
  pcall(function() element.style.padding = 8 end)
  pcall(function() element.style.margin = 4 end)
  return true
end


