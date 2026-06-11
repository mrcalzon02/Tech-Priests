-- split source: tech-priests_src/scripts/core/consecration/history_gui.lua lines 594-605
function M.handle_gui_closed(event)
  local player = event and event.player_index and game and game.get_player(event.player_index) or nil
  if not (player and player.valid) then return end
  local root = ensure_root()
  local open = root.open[player.index]
  if not open then return end
  local entity = event.entity
  if entity and entity.valid and open.unit and entity.unit_number == open.unit then
    destroy_frame(player)
  end
end

