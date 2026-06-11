-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1024-1031
local function relation_marker_0414(relation)
  relation = tostring(relation or "neutral")
  if relation == "same" then return "S" end
  if relation == "ally" then return "A" end
  if relation == "rival" then return "R" end
  return "N"
end

