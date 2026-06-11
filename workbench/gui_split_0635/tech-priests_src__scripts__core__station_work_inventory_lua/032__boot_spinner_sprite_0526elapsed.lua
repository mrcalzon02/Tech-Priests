-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 273-277
local function boot_spinner_sprite_0526(elapsed)
  local frame = (math.floor((tonumber(elapsed) or 0) / math.max(1, tonumber(M.boot_refresh_ticks) or 15)) % 12) + 1
  return string.format("tech-priests-gui-boot-spinner-0526-%02d", frame)
end

