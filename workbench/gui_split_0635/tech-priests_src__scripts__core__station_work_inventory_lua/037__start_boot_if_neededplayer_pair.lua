-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 448-461
local function start_boot_if_needed(player, pair)
  if not (player and player.valid and valid_pair(pair)) then return false end
  if boot_seen(pair, player) then return false end
  local r = root()
  if not r then return false end
  local key = tostring(player.index)
  local existing = r.open_by_player[key]
  local sk = station_key(pair)
  if existing and existing.station_unit == sk then return true end
  r.open_by_player[key] = { station_unit = sk, start_tick = now(), last_stage = 0 }
  r.stats.started = (r.stats.started or 0) + 1
  return true
end

