-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 58-58
local function unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
