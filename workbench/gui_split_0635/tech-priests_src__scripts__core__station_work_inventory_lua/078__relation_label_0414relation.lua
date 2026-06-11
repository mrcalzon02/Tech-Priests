-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1032-1039
local function relation_label_0414(relation)
  relation = tostring(relation or "neutral")
  if relation == "same" then return "[color=cyan]SELF[/color]" end
  if relation == "ally" then return "[color=green]ALLY[/color]" end
  if relation == "rival" then return "[color=red]RIVAL[/color]" end
  return "[color=yellow]NEUTRAL[/color]"
end

