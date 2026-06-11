-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 112-117
local function apply_gui_style_0532(element, style_name)
  if not (element and element.valid and style_name) then return false end
  local ok = pcall(function() element.style = style_name end)
  return ok
end

