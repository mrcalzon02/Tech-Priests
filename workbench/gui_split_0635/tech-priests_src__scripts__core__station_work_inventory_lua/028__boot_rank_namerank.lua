-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 245-252
local function boot_rank_name(rank)
  rank = tonumber(rank) or 1
  if rank >= 4 then return "PLANETARY MAGOS" end
  if rank >= 3 then return "SENIOR" end
  if rank >= 2 then return "INTERMEDIATE" end
  return "JUNIOR"
end

