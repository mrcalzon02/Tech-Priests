-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1939-1946
local function display_order_item_0494(order, task)
  if type(order) == "table" then
    return order.item or order.item_name or order.output_item or order.requested_item or order.wanted_item or (type(order.task) == "table" and (order.task.item or order.task.item_name or order.task.recipe or order.task.resource)) or nil
  end
  if type(task) == "table" then return task.item or task.item_name or task.recipe or task.recipe_name or task.resource or task.output_item or task.requested_item end
  return nil
end

