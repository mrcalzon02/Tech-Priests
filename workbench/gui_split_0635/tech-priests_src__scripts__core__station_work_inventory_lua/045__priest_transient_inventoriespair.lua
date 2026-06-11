-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 590-601
local function priest_transient_inventories(pair)
  local out, seen = {}, {}
  if not valid(pair and pair.priest) then return out end
  local function add(inv, id) add_unique(out, seen, inv, pair.priest, "transient-priest-cargo", id) end
  if pair.priest.get_main_inventory then local ok, inv = pcall(function() return pair.priest.get_main_inventory() end); if ok then add(inv, "main") end end
  add(safe_inventory(pair.priest, defines.inventory.character_main), defines.inventory.character_main)
  add(safe_inventory(pair.priest, defines.inventory.chest), defines.inventory.chest)
  add(safe_inventory(pair.priest, defines.inventory.spider_trunk), defines.inventory.spider_trunk)
  add(safe_inventory(pair.priest, defines.inventory.car_trunk), defines.inventory.car_trunk)
  return out
end

