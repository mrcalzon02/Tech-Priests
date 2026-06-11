-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 61-74
local function remember_recent_pair_for_player_0461(player, pair, reason)
  if not (storage and player and player.valid and valid_pair(pair)) then return false end
  storage.tech_priests = storage.tech_priests or {}
  local bucket = storage.tech_priests.last_opened_pair_by_player_0461 or {}
  storage.tech_priests.last_opened_pair_by_player_0461 = bucket
  bucket[tostring(player.index)] = {
    station_unit = unit(pair),
    priest_unit = valid(pair.priest) and pair.priest.unit_number or nil,
    tick = now(),
    reason = tostring(reason or "workstate-open"),
  }
  return true
end

