-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1582-1588
local function add_order_line(parent, prefix, order)
  if not order then add_label(parent, prefix .. " none"); return end
  add_label(parent, prefix .. " " .. tostring(order.key or "unsealed") .. " | rite " .. tostring(order.kind or order.type or "unknown") .. " | tithe " .. tostring(order.item or "none") .. " | state " .. tostring(order.status or "unmarked") .. " | priority " .. tostring(order.priority or "—"))
  if order.finish_reason then add_label(parent, "    completion seal: " .. tostring(order.finish_reason)) end
  if order.reason then add_label(parent, "    mandate: " .. tostring(order.reason)) end
end

