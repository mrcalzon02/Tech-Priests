-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1202-1219
local function observe_task_state(pair, source)
  local mem = state_memory_for(pair)
  if not mem then return nil end
  local task_name, task = task_candidates(pair)
  local key = stable_task_key(task_name, task)
  local tick = now()
  if mem.last_task_key ~= key then
    table.insert(mem.history, 1, { tick = tick, source = source or "display", task_name = tostring(task_name), summary = short_value(task), key = key })
    while #mem.history > 5 do table.remove(mem.history) end
    mem.last_task_key = key
    mem.last_task_tick = tick
  else
    mem.last_task_tick = tick
    if mem.history[1] then mem.history[1].last_seen = tick end
  end
  return mem
end

