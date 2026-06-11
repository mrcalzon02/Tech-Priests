-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 130-144
local function apply_screen_scroll_style_0564(element)
  if not (element and element.valid) then return false end
  -- 0.1.565: use the transparent/naked scroll-pane branch so the sliced
  -- green CRT display frame behind it remains visible.  The previous pass
  -- tinted the vanilla scroll pane itself, which still rendered as the same
  -- flat Factorio gray in live tests.
  if not apply_gui_style_0532(element, "tech_priests_cogitator_screen_scroll_0565") then
    apply_gui_style_0532(element, "tech_priests_cogitator_screen_scroll_0564")
  end
  pcall(function() element.style.horizontally_stretchable = true end)
  pcall(function() element.style.vertically_stretchable = true end)
  pcall(function() element.style.padding = 6 end)
  return true
end

