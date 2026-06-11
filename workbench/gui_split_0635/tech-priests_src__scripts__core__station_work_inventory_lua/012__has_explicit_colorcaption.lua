-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 101-104
local function has_explicit_color(caption)
  return tostring(caption or ""):find("%[color=", 1, false) ~= nil
end

