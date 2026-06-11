-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 2475-2490
local function panel_location_x_0536(player, width)
  local screen_w = 1920
  if player then
    pcall(function()
      if player.display_resolution and player.display_resolution.width then
        local scale = tonumber(player.display_scale) or 1
        screen_w = math.floor((tonumber(player.display_resolution.width) or screen_w) / math.max(0.5, scale))
      end
    end)
  end
  -- 0.1.567: pin the Work-State Reliquary to the left side so the
  -- Machine-Spirit State Ledger can live on the right without overlapping.
  return 24
end


