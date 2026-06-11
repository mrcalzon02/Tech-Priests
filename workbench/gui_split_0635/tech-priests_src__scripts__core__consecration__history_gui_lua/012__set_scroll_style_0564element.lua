-- split source: tech-priests_src/scripts/core/consecration/history_gui.lua lines 131-140
local function set_scroll_style_0564(element)
  if not (element and element.valid and element.style) then return end
  if not apply_style_0564(element, "tech_priests_cogitator_screen_scroll_0565") then
    apply_style_0564(element, "tech_priests_cogitator_screen_scroll_0564")
  end
  pcall(function() element.style.horizontally_stretchable = true end)
  pcall(function() element.style.vertically_stretchable = true end)
  pcall(function() element.style.padding = 6 end)
end

