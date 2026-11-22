-- Resolve the player actually driving a tracked machine-spirit vehicle.
-- No player-table scan for empty vehicles. No passenger-as-driver matches.
local M = {}

local function live_player(player, vehicle)
  return player and player.valid and player.connected
    and player.vehicle and player.vehicle.valid and player.vehicle == vehicle
end

function M.get_player(entity, players)
  if not (entity and entity.valid) then return nil end
  -- Factorio 2.1 returns the native driver as LuaPlayer or LuaEntity. A nil
  -- driver is authoritative, even if a passenger occupies the vehicle.
  local ok, driver = pcall(function() return entity.get_driver() end)
  if not ok or not driver then return nil end
  -- Most vehicles return the LuaPlayer directly; no connected-player scan.
  if driver.object_name == "LuaPlayer" and live_player(driver, entity) then
    return driver
  end
  -- Some controllers return the character LuaEntity. Resolve only the exact
  -- matching character; do not mistake a passenger in the same car for driver.
  for _, player in pairs(players or {}) do
    if live_player(player, entity) and (player == driver or player.character == driver) then
      return player
    end
  end
  return nil
end

return M
