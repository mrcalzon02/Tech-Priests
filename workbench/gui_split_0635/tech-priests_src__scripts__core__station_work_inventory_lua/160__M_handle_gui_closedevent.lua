-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 2644-2654
function M.handle_gui_closed(event)
  local element = event and event.element
  local closed_name = element and element.valid and element.name or nil
  if _G.tech_priests_0327_catalog_gui_closed then pcall(_G.tech_priests_0327_catalog_gui_closed, event) end
  if _G.tech_priests_0370_doctrine_argument and _G.tech_priests_0370_doctrine_argument.handle_gui_closed then pcall(_G.tech_priests_0370_doctrine_argument.handle_gui_closed, event) end
  if closed_name and closed_name ~= M.gui_name then return end
  local player = event and event.player_index and game.get_player(event.player_index) or nil
  clear_active_boot(player)
  clear_gui(player)
end

