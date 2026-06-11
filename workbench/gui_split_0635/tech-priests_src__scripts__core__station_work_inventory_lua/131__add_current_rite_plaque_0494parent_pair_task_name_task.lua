-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 2033-2046
local function add_current_rite_plaque_0494(parent, pair, task_name, task)
  local plaque = add_plaque_0494(parent, "Active Rite")
  local order = current_order_0494(pair)
  local action = action_summary_0494(pair, task_name, task)
  add_kv_0494(plaque, "Active rite", action_readable_0494(action, order, task_name, task))
  add_kv_0494(plaque, "Action owner", tostring(action and action.kind or task_name or "idle"))
  add_kv_0494(plaque, "Target seal", display_target_0494((action and action.target) or (type(task) == "table" and (task.target or task.entity or task.resource_entity) or nil)))
  add_kv_0494(plaque, "Movement verdict", movement_readable_0494(pair))
  add_kv_0494(plaque, "Craft timer", craft_timer_readable_0494(pair))
  add_kv_0494(plaque, "Active writ", order_summary_0494(order))
  if type(task) == "table" then add_kv_0494(plaque, "Lower executor slate", tostring(task_name or "none") .. " :: " .. short_value(task)) else add_kv_0494(plaque, "Lower executor slate", tostring(task_name or "none")) end
  return plaque
end

