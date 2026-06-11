-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1993-1999
local function movement_readable_0494(pair)
  local mode = pair and (pair.movement_mode or pair.move_mode or pair.movement_state or pair.pathing_state) or nil
  local target = pair and (pair.move_target or pair.movement_target or pair.destination or pair.path_target) or nil
  if not mode and not target then return "no movement seal visible" end
  return tostring(mode or "movement requested") .. " -> " .. display_target_0494(target)
end

