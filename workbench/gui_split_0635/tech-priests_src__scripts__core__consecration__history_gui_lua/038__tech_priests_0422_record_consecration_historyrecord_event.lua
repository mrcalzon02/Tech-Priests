-- split source: tech-priests_src/scripts/core/consecration/history_gui.lua lines 677-688
function tech_priests_0422_record_consecration_history(record, event)
  if not (record and record.entity and record.entity.valid and event) then return false end
  record.consecration_history_0422 = record.consecration_history_0422 or {}
  local history = record.consecration_history_0422
  history[#history + 1] = event
  while #history > HISTORY_LIMIT do table.remove(history, 1) end
  record.completed_operations_seen_0422 = (record.completed_operations_seen_0422 or 0) + 1
  record.last_history_tick_0422 = event.tick or (game and game.tick or 0)
  return true
end

return M
