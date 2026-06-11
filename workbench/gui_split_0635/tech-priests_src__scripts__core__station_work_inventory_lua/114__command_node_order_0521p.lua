-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1820-1823
local function command_node_order_0521(p)
  return p and ((p.order_queue_0469 and p.order_queue_0469.current) or p.active_order_0469) or nil
end

