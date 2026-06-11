-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 237-244
local function boot_phase_count(rank)
  rank = tonumber(rank) or 1
  if rank >= 4 then return 14 end
  if rank >= 3 then return 12 end
  if rank >= 2 then return 10 end
  return 8
end

