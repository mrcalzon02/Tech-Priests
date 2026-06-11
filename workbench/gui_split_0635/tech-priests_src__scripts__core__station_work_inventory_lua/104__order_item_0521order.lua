-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1607-1611
local function order_item_0521(order)
  if type(order) ~= "table" then return "none" end
  return order.item or order.item_name or order.output_item or order.requested_item or order.wanted_item or (type(order.task) == "table" and (order.task.item or order.task.item_name or order.task.recipe or order.task.resource)) or "none"
end

