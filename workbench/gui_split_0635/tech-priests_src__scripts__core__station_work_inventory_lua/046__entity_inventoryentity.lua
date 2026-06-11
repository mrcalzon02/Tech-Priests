-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 602-610
local function entity_inventory(entity)
  return safe_inventory(entity, defines.inventory.chest)
      or safe_inventory(entity, defines.inventory.assembling_machine_input)
      or safe_inventory(entity, defines.inventory.assembling_machine_output)
      or safe_inventory(entity, defines.inventory.furnace_source)
      or safe_inventory(entity, defines.inventory.furnace_result)
      or safe_inventory(entity, defines.inventory.fuel)
end

