-- Read-only verification for Cogitator command-link overlays.
-- Never infer a command relationship from distance, tier, or force alone.
local M = {}

local function paired(pair)
  return type(pair) == "table"
    and pair.station and pair.station.valid and pair.station.unit_number
    and pair.priest and pair.priest.valid
end

local function member(list, unit)
  if type(list) ~= "table" then return false end
  for _, value in ipairs(list) do
    if value == unit then return true end
  end
  return false
end

local function same_domain(a, b)
  return a.station.force and a.station.force == b.station.force
    and a.station.surface and a.station.surface == b.station.surface
end

local function within_range(a, b, max_distance)
  if type(max_distance) ~= "number" or max_distance <= 0 then return false end
  local p, q = a.station.position, b.station.position
  if not (p and q and type(p.x) == "number" and type(p.y) == "number"
      and type(q.x) == "number" and type(q.y) == "number") then return false end
  local dx, dy = p.x - q.x, p.y - q.y
  return dx * dx + dy * dy <= max_distance * max_distance
end

-- Return only physical, reciprocal command records from 0480's live slates.
-- 'parent', 'child' order is canonical for solid links; peer order is arbitrary.
function M.classify(a, b, max_distance)
  if not (paired(a) and paired(b) and a ~= b
      and a.station.unit_number ~= b.station.unit_number
      and same_domain(a, b) and within_range(a, b, max_distance)) then
    return nil
  end
  local ah, bh = a.command_hierarchy_0480, b.command_hierarchy_0480
  if type(ah) ~= "table" or type(bh) ~= "table" then return nil end
  local ar, br = tonumber(ah.rank), tonumber(bh.rank)
  local au, bu = a.station.unit_number, b.station.unit_number
  if ar and br then
    if ar >= 2 and ar <= 4 and br == ar - 1
        and bh.superior_unit == au
        and member(ah.direct_subordinate_units, bu) then
      return "direct", a, b
    end
    if br >= 2 and br <= 4 and ar == br - 1
        and ah.superior_unit == bu
        and member(bh.direct_subordinate_units, au) then
      return "direct", b, a
    end
    if ar == 1 and br == 1
        and member(ah.peer_units, bu) and member(bh.peer_units, au) then
      return "peer", a, b
    end
  end
  return nil
end

function M.collect(pairs_list, limit, max_distance)
  local links = {}
  if type(pairs_list) ~= "table" or type(limit) ~= "number"
      or limit < 1 or type(max_distance) ~= "number"
      or max_distance <= 0 then return links end
  for i = 1, #pairs_list do
    for j = i + 1, #pairs_list do
      local kind, from, to = M.classify(pairs_list[i], pairs_list[j], max_distance)
      if kind then
        links[#links + 1] = {kind = kind, from = from, to = to}
        if #links >= limit then return links end
      end
    end
  end
  return links
end

return M
