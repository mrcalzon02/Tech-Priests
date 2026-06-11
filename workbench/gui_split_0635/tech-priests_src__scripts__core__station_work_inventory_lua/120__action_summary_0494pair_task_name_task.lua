-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1923-1933
local function action_summary_0494(pair, task_name, task)
  local arb = rawget(_G, "TECH_PRIESTS_ACTION_STATE_ARBITER_0488")
  if arb and arb.action then
    local ok, a = pcall(arb.action, pair)
    if ok and type(a) == "table" then return a end
  end
  local item = nil
  if type(task) == "table" then item = task.item or task.item_name or task.resource or task.recipe or task.recipe_name or task.output_item or task.requested_item end
  return { kind = tostring(task_name or "idle"), item = item, target = type(task) == "table" and (task.target or task.entity or task.resource_entity) or nil }
end

