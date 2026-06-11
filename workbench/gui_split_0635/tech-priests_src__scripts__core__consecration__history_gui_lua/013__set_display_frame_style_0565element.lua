-- split source: tech-priests_src/scripts/core/consecration/history_gui.lua lines 141-150
local function set_display_frame_style_0565(element)
  if not (element and element.valid and element.style) then return end
  if not apply_style_0564(element, "tech_priests_cogitator_display_frame_0540") then
    apply_style_0564(element, "tech_priests_cogitator_inner_frame_0532")
  end
  pcall(function() element.style.horizontally_stretchable = true end)
  pcall(function() element.style.padding = 8 end)
end


