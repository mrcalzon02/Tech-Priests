-- split source: tech-priests_src/scripts/core/consecration/history_gui.lua lines 115-119
local function apply_style_0564(element, style_name)
  if not (element and element.valid and style_name) then return false end
  return pcall(function() element.style = style_name end)
end

