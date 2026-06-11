-- split source: tech-priests_src/scripts/core/consecration/history_gui.lua lines 617-626
function M.refresh_all_open()
  if not (game and game.connected_players) then return end
  local root = ensure_root()
  for _, player in pairs(game.connected_players) do
    if player and player.valid and root.open[player.index] then
      M.refresh_open_frame(player)
    end
  end
end

