-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 839-842
local function noospheric_id(pair)
  return "NOO-PAIR-" .. tostring(unit(pair) or "?")
end

