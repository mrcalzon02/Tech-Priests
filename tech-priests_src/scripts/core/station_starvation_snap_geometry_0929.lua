-- 0929: Factorio 2.0.77 can snap a requested entity-ghost center.
-- For a reversal station the *actual* physical center must remain closer
-- to natural ore, not merely the requested pre-snap point. Triangle
-- inequality guarantees that every displacement <= max_shift keeps progress.
-- This is only a site-selection guard. The independent post-create native
-- ghost identity, radius, observed-position and progress checks still apply.
local M={}
local function point(p)
  return type(p)=="table" and type(p.x)=="number"
    and type(p.y)=="number"
    and p.x==p.x and p.y==p.y
    and math.abs(p.x)<math.huge and math.abs(p.y)<math.huge
end
local function distance(a,b)
  local dx,dy=a.x-b.x,a.y-b.y
  return math.sqrt(dx*dx+dy*dy)
end
function M.forward_after_snap(origin,requested,target,max_shift)
  if not(point(origin) and point(requested) and point(target)
      and type(max_shift)=="number" and max_shift>=0
      and max_shift<math.huge) then return false end
  return distance(requested,target)+max_shift<distance(origin,target)
end
return M
