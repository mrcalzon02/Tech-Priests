-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 227-231
local function active_boot(player)
  local r = root()
  return r and player and player.valid and r.open_by_player[tostring(player.index)] or nil
end

