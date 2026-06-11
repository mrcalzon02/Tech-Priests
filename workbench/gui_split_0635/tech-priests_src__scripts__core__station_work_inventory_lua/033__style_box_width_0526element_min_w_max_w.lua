-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 278-284
local function style_box_width_0526(element, min_w, max_w)
  if not (element and element.valid and element.style) then return end
  if min_w then pcall(function() element.style.minimal_width = min_w end) end
  if max_w then pcall(function() element.style.maximal_width = max_w end) end
  pcall(function() element.style.horizontally_stretchable = false end)
end

