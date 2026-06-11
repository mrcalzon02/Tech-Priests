-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 208-214
local function boot_seen(pair, player)
  local r = root()
  local fk = force_key(pair, player)
  local sk = station_key(pair)
  return r and r.seen_by_force and r.seen_by_force[fk] and r.seen_by_force[fk][sk]
end

