-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 253-260
local function boot_model(rank)
  rank = tonumber(rank) or 1
  if rank >= 4 then return "JCS-PLM-0364" end
  if rank >= 3 then return "JCS-SR-0364" end
  if rank >= 2 then return "JCS-IM-0364" end
  return "JCS-JR-0364"
end

