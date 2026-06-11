-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1707-1711
local function plan_item_0521(plan)
  if type(plan) ~= "table" then return "none" end
  return plan.item or plan.item_name or plan.output_item or plan.requested_item or plan.wanted_item or plan.entity or plan.prototype or "none"
end

