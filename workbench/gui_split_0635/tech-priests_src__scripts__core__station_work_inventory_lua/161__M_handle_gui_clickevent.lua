-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 2655-2678
function M.handle_gui_click(event)
  local element = event and event.element
  local name = element and element.valid and element.name or nil

  -- 0.1.468: Work State owns its own refresh buttons. Do not pass the
  -- docked Auspex Ledger refresh click through the old catalog/main-menu GUI
  -- chain first, or the panel can redraw back to the default Work State page.
  if name == "tech_priests_workstate_refresh_0358" or name == "tech_priests_workstate_refresh_known_resources_0467" then
    local player = event.player_index and game.get_player(event.player_index) or nil
    if not (player and player.valid) then return true end
    local frame = player.gui.screen[M.gui_name]
    local su = frame and frame.valid and frame.tags and frame.tags.station_unit or nil
    local pair = su and pair_map()[su] or selected_pair(player)
    if pair and _G.tech_priests_0327_scan_station_catalog then pcall(_G.tech_priests_0327_scan_station_catalog, pair) end
    local keep_tab = current_workstate_tab_index_0541(player)
    if pair then M.show_gui(player, pair, name == "tech_priests_workstate_refresh_known_resources_0467" and 2 or keep_tab or 1) end
    return true
  end

  if _G.tech_priests_0327_catalog_gui_click then pcall(_G.tech_priests_0327_catalog_gui_click, event) end
  if _G.tech_priests_0370_doctrine_argument and _G.tech_priests_0370_doctrine_argument.handle_gui_click then pcall(_G.tech_priests_0370_doctrine_argument.handle_gui_click, event) end
end


