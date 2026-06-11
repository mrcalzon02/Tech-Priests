-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 267-272
local function boot_pick(pool, seed)
  if not pool or #pool < 1 then return "" end
  seed = math.floor(tonumber(seed) or 1)
  return pool[(seed % #pool) + 1]
end

