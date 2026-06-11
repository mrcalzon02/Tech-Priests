-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1733-1748
local function add_plan_table_row_0521(table_el, plan, fallback_status, row_index)
  plan = type(plan) == "table" and plan or {}
  local row = {
    row_index or "—",
    plan.key or plan.id or plan.plan_key or "unsealed",
    plan_item_0521(plan),
    plan.status or fallback_status or "queued",
    plan.priority or plan.pri or "—",
    plan_site_0521(plan),
    order_age_text_0521(plan),
    plan_reason_0521(plan),
  }
  local widths = { 34, 210, 155, 105, 72, 130, 120, 230 }
  for i, value in ipairs(row) do add_table_cell_0521(table_el, order_cell_text_0495(value, i == 2 and 46 or 34), widths[i], false) end
end

