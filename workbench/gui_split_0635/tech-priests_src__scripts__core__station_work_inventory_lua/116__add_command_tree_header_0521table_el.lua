-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1831-1836
local function add_command_tree_header_0521(table_el)
  local headers = { "Relation", "Station", "Rank", "Sockets", "Mode", "Active Writ", "Priest Signal" }
  local widths = { 110, 230, 120, 100, 130, 170, 180 }
  for i, head in ipairs(headers) do add_table_cell_0521(table_el, head, widths[i], true) end
end

