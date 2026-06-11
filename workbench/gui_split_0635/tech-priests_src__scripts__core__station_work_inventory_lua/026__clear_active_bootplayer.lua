-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 232-236
local function clear_active_boot(player)
  local r = root()
  if r and player and player.valid then r.open_by_player[tostring(player.index)] = nil end
end

