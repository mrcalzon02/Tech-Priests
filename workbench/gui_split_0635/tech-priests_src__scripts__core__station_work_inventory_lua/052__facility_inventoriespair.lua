-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 659-679
local function facility_inventories(pair)
  local out, seen = {}, {}
  for _, rec in ipairs(facility_records(pair)) do
    local e = rec.entity
    if valid(e) then
      local ids = {
        defines.inventory.chest,
        defines.inventory.assembling_machine_input,
        defines.inventory.assembling_machine_output,
        defines.inventory.furnace_source,
        defines.inventory.furnace_result,
        defines.inventory.fuel,
        defines.inventory.burnt_result,
        defines.inventory.lab_input,
      }
      for _, id in ipairs(ids) do add_unique(out, seen, safe_inventory(e, id), e, "personal-martian-facility", id) end
    end
  end
  return out
end

