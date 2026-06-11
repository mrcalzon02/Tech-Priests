-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 97-100
local function boot_hold_ticks()
  return math.max(30, math.floor((tonumber(M.boot_hold_ticks) or 180) * 25 / boot_speed_percent() + 0.5))
end

