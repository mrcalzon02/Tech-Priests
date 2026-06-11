-- split source: tech-priests_src/scripts/core/consecration/history_gui.lua lines 606-616
function M.handle_gui_click(event)
  local player = event and event.player_index and game and game.get_player(event.player_index) or nil
  local element = event and event.element
  if not (player and player.valid and element and element.valid) then return end
  if element.name == CLOSE_NAME then
    destroy_frame(player)
  elseif element.name == REFRESH_NAME then
    M.refresh_open_frame(player)
  end
end

