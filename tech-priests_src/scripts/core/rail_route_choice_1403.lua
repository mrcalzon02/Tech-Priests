-- Read-only, deterministic rail-extension ranker for the original 0836 Magos.
-- A plan is NOT a ghost, a construction request, a paid item, or an actual rail.
local M={version="0.1.676.1403",max_input=32,max_output=3}
local function finite(n)
  return type(n)=="number" and n==n and math.abs(n)<math.huge
end
local function point(p)
  return type(p)=="table" and finite(p.x) and finite(p.y)
end
local function distance_sq(a,b)
  local dx=a.x-b.x
  local dy=a.y-b.y
  return dx*dx+dy*dy
end

-- Returns a small primitive-only recommendation set. Native placement and
-- connection proof still belong to Factorio and the original 0836/0338 owner.
-- Avoid backtracking into the home end of the railway, trivial cycles,
-- non-progressing rail probes, and claiming another frontier's candidates.
function M.rank(frontier,raw,target,opts)
  opts=opts or{}
  if type(frontier)~="table" or not point(frontier.position)
    or not finite(frontier.unit_number) or not point(target)
    or type(raw)~="table"then
    return {},"invalid-rail-geometry-1403"
  end
  local start_distance=distance_sq(frontier.position,target)
  if not finite(start_distance) then
    return {},"invalid-rail-distance-1403"
  end
  local maximum=math.min(M.max_input,math.max(0,math.floor(
    tonumber(opts.max_input) or M.max_input)))
  local seen,ranked={},{}
  for i=1,math.min(#raw,maximum)do
    local candidate=raw[i]
    local p=candidate and candidate.position
    local direction=candidate and candidate.direction
    local name=candidate and candidate.name
    if point(p) and finite(direction) and direction>=0
      and direction<=15 and direction==math.floor(direction)
      and type(name)=="string" and #name>0 and #name<96
      and candidate.from_rail_unit==frontier.unit_number then
      local step_dx=p.x-frontier.position.x
      local step_dy=p.y-frontier.position.y
      local outward=(target.x-frontier.position.x)*step_dx
        +(target.y-frontier.position.y)*step_dy
      local dist=distance_sq(p,target)
      local movement=step_dx*step_dx+step_dy*step_dy
      -- Native output still needs useful positive progress toward target.
      -- Detours requiring an initial backward step need a later bounded
      -- multi-step route solver; never guess one from an existing rail end.
      if finite(dist) and finite(movement) and movement>0
        and outward>0 and dist<start_distance then
        local key=name..":"..tostring(p.x)..":"..tostring(p.y)
          ..":"..tostring(direction)
        if not seen[key] then
          seen[key]=true
          ranked[#ranked+1]={
            name=name,position={x=p.x,y=p.y},direction=direction,
            from_rail_unit=frontier.unit_number,
            rail_end_direction=candidate.rail_end_direction,
            distance_sq=dist,
          }
        end
      end
    end
  end
  table.sort(ranked,function(a,b)
    if a.distance_sq~=b.distance_sq then
      return a.distance_sq<b.distance_sq end
    if a.name~=b.name then return a.name<b.name end
    if a.position.x~=b.position.x then return a.position.x<b.position.x end
    if a.position.y~=b.position.y then return a.position.y<b.position.y end
    return a.direction<b.direction
  end)
  local output={}
  local max_output=math.min(M.max_output,math.max(0,math.floor(
    tonumber(opts.max_output) or M.max_output)))
  for i=1,math.min(#ranked,max_output)do output[i]=ranked[i]end
  return output,#output>0 and "native-progressive-rail-options-1403"
    or "no-progressive-rail-extension-1403"
end
return M
