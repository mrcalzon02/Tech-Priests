-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1837-1858
local function add_command_tree_row_0495(table_el, relation, p, H)
  local h = H and H.hierarchy and H.hierarchy(p) or {}
  local order = command_node_order_0521(p)
  local sockets = "—"
  if h then
    local direct = tostring(#(h.direct_subordinate_units or {})) .. "/" .. tostring(h.direct_limit or 0)
    local peers = tostring(#(h.peer_units or {})) .. "/" .. tostring(h.peer_limit or 0)
    sockets = "D " .. direct .. " P " .. peers
  end
  local row = {
    relation or "node",
    station_label(p),
    tostring(h.rank_name or station_rank(p)),
    sockets,
    tostring(p and p.mode or "idle"),
    tostring(order and (order.item or order.key or order.id) or "none"),
    command_node_priest_signal_0521(p),
  }
  local widths = { 110, 230, 120, 100, 130, 170, 180 }
  for i, value in ipairs(row) do add_table_cell_0521(table_el, order_cell_text_0495(value, i == 2 and 44 or 34), widths[i], false) end
end

