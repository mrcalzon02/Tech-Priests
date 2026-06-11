-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1602-1606
local function order_reason_0521(order)
  if type(order) ~= "table" then return "—" end
  return order.reason or order.finish_reason or order.fail_reason or order.preempted_by or order.source or order.owner or "—"
end

