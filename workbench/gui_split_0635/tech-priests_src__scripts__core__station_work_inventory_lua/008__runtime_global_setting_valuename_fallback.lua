-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 77-83
local function runtime_global_setting_value(name, fallback)
  if settings and settings.global and settings.global[name] and settings.global[name].value ~= nil then
    return settings.global[name].value
  end
  return fallback
end

