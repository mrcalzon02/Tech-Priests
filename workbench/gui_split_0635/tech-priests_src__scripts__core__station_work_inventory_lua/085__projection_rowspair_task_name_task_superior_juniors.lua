-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1241-1270
local function projection_rows(pair, task_name, task, superior, juniors)
  local rows = {}
  local function add(label, basis)
    rows[#rows + 1] = { label = label, basis = basis or "unconfirmed augury" }
  end
  if task_name and task_name ~= "none" then
    add("Continue / complete current " .. tostring(task_name), "actual active task observed: " .. short_value(task))
  else
    add("Await scheduler pulse or new station request", "no active task currently exposed")
  end
  if superior then add("Check superior station compiled instruction stack", "nearby higher-rank station: " .. station_label(superior)) end
  if juniors and #juniors > 0 then add("Distribute or reconcile junior station work claims", tostring(#juniors) .. " subordinate station(s) nearby") end
  if pair and (pair.construction_task_0338 or pair.construction_task_0340 or pair.construction_task_0342 or pair.construction_task_0357) then
    add("Resolve construction planner placement/fetch instruction", "construction task field is populated")
  else
    add("Hold writ-slot for sanctioned construction augury", "no blessed build-site writ is presently exposed")
  end
  if pair and (pair.supply_request or pair.active_supply_request or pair.direct_acquisition_task_0336 or pair.active_acquisition_0333) then
    add("Resolve acquisition request and return materials to station stock", "acquisition or supply field is populated")
  else
    add("Hold writ-slot for acquisition or emergency bootstrap tithe", "no material writ is presently exposed")
  end
  local sched = get_scheduler_lines(pair, 2)
  for _, line in ipairs(sched) do add("Scheduler-observed follow-up", line) end
  while #rows < 5 do add("UNWRITTEN RITE-SLOT " .. tostring(#rows + 1), "augury only; awaiting senior sanction, scheduler writ, or construction rite") end
  local out = {}
  for i = 1, 5 do out[i] = rows[i] end
  return out
end

