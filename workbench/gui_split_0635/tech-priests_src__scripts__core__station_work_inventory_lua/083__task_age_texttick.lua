-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1220-1226
local function task_age_text(tick)
  tick = tonumber(tick) or 0
  local delta = math.max(0, now() - tick)
  if delta < 60 then return tostring(delta) .. "t ago" end
  return tostring(math.floor(delta / 60)) .. "s ago"
end

