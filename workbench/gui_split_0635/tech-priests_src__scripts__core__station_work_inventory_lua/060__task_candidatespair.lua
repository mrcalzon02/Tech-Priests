-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 752-765
local function task_candidates(pair)
  local candidates = {
    { name = "construction", value = pair and (pair.construction_task_0338 or pair.construction_task_0340 or pair.construction_task_0342 or pair.construction_task_0357) },
    { name = "station-craft", value = pair and pair.station_crafting_task_0337 },
    { name = "direct-acquisition", value = pair and pair.direct_acquisition_task_0336 },
    { name = "active-acquisition", value = pair and pair.active_acquisition_0333 },
    { name = "emergency-operation", value = pair and (pair.emergency_operation or pair.independent_emergency_operation or pair.independent_emergency_operation_0184) },
    { name = "emergency-craft", value = pair and pair.emergency_craft },
    { name = "active-task", value = pair and (pair.active_task or pair.current_task) },
  }
  for _, c in ipairs(candidates) do if c.value then return c.name, c.value end end
  return "none", nil
end

