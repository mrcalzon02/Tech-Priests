-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1964-1974
local function order_summary_0494(order)
  if type(order) ~= "table" then return "no sealed writ" end
  local item = display_order_item_0494(order)
  local key = tostring(order.key or order.id or "unsealed")
  local kind = tostring(order.kind or order.type or order.source or "writ")
  local status = tostring(order.status or "active")
  return kind .. " :: " .. tostring(item or "unknown tithe") .. " :: " .. status .. " :: " .. key
end

local add_gui_sprite_0482

