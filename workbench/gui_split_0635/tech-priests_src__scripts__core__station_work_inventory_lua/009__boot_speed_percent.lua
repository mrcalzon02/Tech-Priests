-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 84-90
local function boot_speed_percent()
  local v = tonumber(runtime_global_setting_value(M.boot_speed_setting_name, 50)) or 50
  if v < 1 then v = 1 end
  if v > 100 then v = 100 end
  return v
end

