-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 819-825
local function pick_from(list, seed, salt)
  if not (list and #list > 0) then return "unknown" end
  return list[deterministic_number(seed, salt, #list)]
end

local DOCTRINAL_SCHOOLS_0368 = DoctrineMap.schools

