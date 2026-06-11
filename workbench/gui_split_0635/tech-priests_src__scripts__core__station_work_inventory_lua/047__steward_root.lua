-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 611-614
local function steward_root()
  return storage and storage.tech_priests and (storage.tech_priests.inventory_steward_0357 or storage.tech_priests.inventory_steward_0356) or nil
end

