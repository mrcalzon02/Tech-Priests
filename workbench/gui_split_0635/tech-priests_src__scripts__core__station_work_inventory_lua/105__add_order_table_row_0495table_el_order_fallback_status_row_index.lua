-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1612-1627
local function add_order_table_row_0495(table_el, order, fallback_status, row_index)
  order = type(order) == "table" and order or {}
  local row = {
    row_index or "—",
    order.key or order.id or "unsealed",
    order.kind or order.type or "writ",
    order_item_0521(order),
    order.status or fallback_status or "queued",
    order.priority or order.pri or "—",
    order_age_text_0521(order),
    order_reason_0521(order)
  }
  local widths = { 34, 210, 120, 150, 110, 72, 150, 220 }
  for i, value in ipairs(row) do add_table_cell_0521(table_el, order_cell_text_0495(value, i == 2 and 46 or 34), widths[i], false) end
end

