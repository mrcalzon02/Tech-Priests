-- Tech Priests common math helpers.
-- 0.1.421: shared utility module introduced during control.lua cleanup.

local M = {}

function M.clamp(value, min_value, max_value)
  if value == nil then return min_value end
  if min_value ~= nil and value < min_value then return min_value end
  if max_value ~= nil and value > max_value then return max_value end
  return value
end

function M.dist_sq(a, b)
  if not (a and b) then return 0 end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end

function M.distance(a, b)
  return math.sqrt(M.dist_sq(a, b))
end

function M.round(value, places)
  local mult = 10 ^ (places or 0)
  return math.floor((value or 0) * mult + 0.5) / mult
end

return M
