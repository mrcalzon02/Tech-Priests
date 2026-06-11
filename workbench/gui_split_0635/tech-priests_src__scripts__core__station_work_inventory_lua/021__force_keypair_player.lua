-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 198-203
local function force_key(pair, player)
  if player and player.valid and player.force then return tostring(player.force.index or player.force.name or "force") end
  if valid(pair and pair.station) and pair.station.force then return tostring(pair.station.force.index or pair.station.force.name or "force") end
  return "force"
end

