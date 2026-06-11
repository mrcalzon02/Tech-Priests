-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 91-96
local function boot_stage_ticks()
  -- 25 is the old excruciating debug speed: 360 ticks per phase.
  -- 50 is the new default: 180 ticks per phase. 100 is twice that again.
  return math.max(30, math.floor((tonumber(M.boot_stage_ticks) or 360) * 25 / boot_speed_percent() + 0.5))
end

