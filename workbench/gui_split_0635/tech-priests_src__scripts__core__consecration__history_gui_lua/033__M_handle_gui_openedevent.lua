-- split source: tech-priests_src/scripts/core/consecration/history_gui.lua lines 580-593
function M.handle_gui_opened(event)
  local player = event and event.player_index and game and game.get_player(event.player_index) or nil
  if not (player and player.valid) then return end
  local entity = event.entity
  if not (entity and entity.valid) then
    pcall(function() if player.opened and player.opened.valid then entity = player.opened end end)
  end
  if entity and entity.valid then
    M.open_for_player(player, entity)
  else
    local root = ensure_root(); root.stats.open_event_no_entity = (root.stats.open_event_no_entity or 0) + 1
  end
end

