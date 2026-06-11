-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1589-1594
local function add_order_table_header_0495(table_el)
  local headers = { "#", "Seal", "Rite", "Tithe", "State", "Priority", "Age / Lease", "Mandate" }
  local widths = { 34, 210, 120, 150, 110, 72, 150, 220 }
  for i, h in ipairs(headers) do add_table_cell_0521(table_el, h, widths[i], true) end
end

