-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 574-589
local function station_inventories(pair)
  local out, seen = {}, {}
  if not valid(pair and pair.station) then return out end
  local ids = {
    defines.inventory.chest,
    defines.inventory.assembling_machine_input,
    defines.inventory.assembling_machine_output,
    defines.inventory.furnace_source,
    defines.inventory.furnace_result,
    defines.inventory.fuel,
    defines.inventory.burnt_result,
  }
  for _, id in ipairs(ids) do add_unique(out, seen, safe_inventory(pair.station, id), pair.station, "owning-station", id) end
  return out
end

