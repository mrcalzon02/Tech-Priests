-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 2000-2008
local function craft_timer_readable_0494(pair)
  local task = pair and (pair.emergency_craft or pair.station_crafting_task_0337 or pair.active_craft_0479) or nil
  if type(task) ~= "table" then return "no active craft timer" end
  local due = tonumber(task.craft_due_tick or task.build_due_tick or task.station_craft_due_tick_0337 or task.due_tick)
  if not due then return "craft slate present; no countdown seal" end
  local remain = math.max(0, math.ceil((due - now()) / 60))
  return tostring(remain) .. "s remaining"
end

