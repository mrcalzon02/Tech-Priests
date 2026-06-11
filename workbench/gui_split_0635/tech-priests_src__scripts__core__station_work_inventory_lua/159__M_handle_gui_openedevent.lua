-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 2629-2643
function M.handle_gui_opened(event)
  -- 0.1.410: Auspex Ledger are docked into the Dictator Work State tabbed pane.
  -- Do not auto-open the old standalone catalog window when a Cogitator is opened.
  local player = event and event.player_index and game.get_player(event.player_index) or nil
  local entity = event and event.entity
  if not (player and player.valid and entity and entity.valid) then return end
  local pair = nil
  if _G.find_pair_for_entity then local ok, found = pcall(_G.find_pair_for_entity, entity); if ok then pair = found end end
  if pair and valid(pair.station) and entity == pair.station then
    remember_recent_pair_for_player_0461(player, pair, "on-gui-opened-station")
    start_boot_if_needed(player, pair)
    M.show_gui(player, pair)
  end
end

