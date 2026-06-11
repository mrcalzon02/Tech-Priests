-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 2457-2474
local function panel_dimensions(player)
  local width = 1120
  local screen_h = 900
  if player then
    pcall(function()
      if player.display_resolution and player.display_resolution.height then
        local scale = tonumber(player.display_scale) or 1
        screen_h = math.floor((tonumber(player.display_resolution.height) or screen_h) / math.max(0.5, scale))
      end
    end)
  end
  local top = 32
  local height = math.max(720, math.min(980, screen_h - top - 24))
  local tabs_h = math.max(560, height - 108)
  local scroll_h = math.max(480, tabs_h - 58)
  return width, height, top, tabs_h, scroll_h
end

