-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1279-1300
local function add_task_memory_display(parent, pair, task_name, task, superior, juniors)
  local mem = observe_task_state(pair, "gui")
  add_label(parent, "Primitive task memory / augury slate")
  add_label(parent, "  The slate records the last five task-state omens and reserves five likely rite-slots for pending machine-service.")
  add_label(parent, "  Last five task states")
  local history = mem and mem.history or {}
  for i = 1, 5 do
    local rec = history[i]
    if rec then
      add_label(parent, "    -" .. tostring(i) .. " " .. tostring(rec.task_name or "?") .. " :: " .. tostring(rec.summary or "") .. " [" .. task_age_text(rec.tick) .. "]")
    else
      add_label(parent, "    -" .. tostring(i) .. " EMPTY HISTORY SLOT")
    end
  end
  local projections = projection_rows(pair, task_name, task, superior, juniors)
  add_label(parent, "  Next five augured rite-slots")
  for i = 1, 5 do
    local rec = projections[i]
    add_label(parent, "    +" .. tostring(i) .. " " .. tostring(rec.label) .. " :: " .. tostring(rec.basis))
  end
end

