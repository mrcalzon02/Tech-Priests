-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1727-1732
local function add_plan_table_header_0521(table_el)
  local headers = { "#", "Plan Seal", "Tithe / Structure", "State", "Priority", "Site", "Age", "Mandate" }
  local widths = { 34, 210, 155, 105, 72, 130, 120, 230 }
  for i, h in ipairs(headers) do add_table_cell_0521(table_el, h, widths[i], true) end
end

