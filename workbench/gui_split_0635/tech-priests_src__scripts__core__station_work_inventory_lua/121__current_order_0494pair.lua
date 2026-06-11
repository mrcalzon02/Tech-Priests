-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1934-1938
local function current_order_0494(pair)
  local q = pair and pair.order_queue_0469 or nil
  return pair and ((q and q.current) or pair.active_order_0469) or nil
end

