-- split source: tech-priests_src/scripts/core/consecration/history_gui.lua lines 302-318
local function choose_ledger_location(player, entity)
  local resolution = { width = 1920, height = 1080 }
  pcall(function()
    if player.display_resolution then resolution = player.display_resolution end
  end)
  local scale = 1
  pcall(function() scale = tonumber(player.display_scale) or 1 end)
  local screen_w = math.floor((tonumber(resolution.width) or 1920) / math.max(0.25, scale))
  local screen_h = math.floor((tonumber(resolution.height) or 1080) / math.max(0.25, scale))
  local frame_w = 940
  local x_right = math.max(24, screen_w - frame_w - 36)
  local y = math.max(24, math.min(72, math.floor(screen_h * 0.04)))
  -- 0.1.567: keep the Machine-Spirit ledger docked on the right so it
  -- does not overlap the left-pinned Work-State Reliquary.
  return { x = x_right, y = y }
end

