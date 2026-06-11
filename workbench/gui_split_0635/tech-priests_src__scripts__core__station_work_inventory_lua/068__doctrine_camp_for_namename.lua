-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 834-838
local function doctrine_camp_for_name(name)
  local school = doctrine_by_name(name)
  return DoctrineMap.camp(school and school.camp or nil)
end

