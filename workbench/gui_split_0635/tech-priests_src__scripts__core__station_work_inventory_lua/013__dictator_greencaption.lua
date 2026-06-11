-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 105-111
local function dictator_green(caption)
  caption = tostring(caption or "")
  if caption == "" or has_explicit_color(caption) then return caption end
  return "[color=" .. M.terminal_green_tag .. "]" .. caption .. "[/color]"
end


