-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 215-226
local function mark_boot_seen(pair, player)
  local r = root()
  if not r then return end
  local fk = force_key(pair, player)
  local sk = station_key(pair)
  r.seen_by_force[fk] = r.seen_by_force[fk] or {}
  if not r.seen_by_force[fk][sk] then
    r.stats.completed = (r.stats.completed or 0) + 1
  end
  r.seen_by_force[fk][sk] = now()
end

