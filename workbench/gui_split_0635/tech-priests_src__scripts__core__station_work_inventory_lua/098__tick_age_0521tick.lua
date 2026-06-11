-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1561-1568
local function tick_age_0521(tick)
  tick = tonumber(tick)
  if not tick or tick <= 0 then return "—" end
  local delta = math.max(0, now() - tick)
  if delta < 120 then return tostring(delta) .. "t" end
  return tostring(math.floor(delta / 60)) .. "s"
end

