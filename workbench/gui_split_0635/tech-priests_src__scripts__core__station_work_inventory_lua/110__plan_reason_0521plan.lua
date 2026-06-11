-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1722-1726
local function plan_reason_0521(plan)
  if type(plan) ~= "table" then return "—" end
  return plan.reason or plan.status_reason or plan.blocker or plan.defer_reason or plan.source or "—"
end

