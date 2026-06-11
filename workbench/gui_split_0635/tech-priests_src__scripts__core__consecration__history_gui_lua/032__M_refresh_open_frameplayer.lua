-- split source: tech-priests_src/scripts/core/consecration/history_gui.lua lines 569-579
function M.refresh_open_frame(player)
  if not (player and player.valid) then return false end
  local root = ensure_root()
  local state = root.open[player.index]
  if not (state and state.unit) then return false end
  state.tab_index = current_machine_spirit_tab_index_0567(player) or state.tab_index or 1
  local record = find_record_by_unit(state.unit)
  if not record then destroy_frame(player); return false end
  return M.open_for_player(player, record.entity)
end

