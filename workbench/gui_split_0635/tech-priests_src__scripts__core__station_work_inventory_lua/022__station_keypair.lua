-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 204-207
local function station_key(pair)
  return tostring(unit(pair) or "?")
end

