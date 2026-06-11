-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1712-1721
local function plan_site_0521(plan)
  if type(plan) ~= "table" then return "—" end
  local v = plan.site or plan.target or plan.position or plan.ghost or plan.entity or plan.destination or plan.source
  if valid(v) then return tostring(v.name or "entity") .. "#" .. tostring(v.unit_number or "?") end
  if type(v) ~= "table" then return tostring(v or "—") end
  if v.x and v.y then return string.format("%.1f, %.1f", tonumber(v.x) or 0, tonumber(v.y) or 0) end
  if v.position and v.position.x and v.position.y then return string.format("%.1f, %.1f", tonumber(v.position.x) or 0, tonumber(v.position.y) or 0) end
  return tostring(v.name or v.item or v.key or "structured target")
end

