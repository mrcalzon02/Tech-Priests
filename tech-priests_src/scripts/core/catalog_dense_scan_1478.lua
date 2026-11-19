-- Bounded deterministic subdivision for dense station Auspex scans.
-- No polling, saved LuaObjects, global event handlers, or world mutations.
local M = { version = "0.1.674-dev", max_queries = 13,
  max_depth = 2, max_entities = 3072, min_extent = 2 }

local function bounds(area)
  local a, b = area and area[1], area and area[2]
  if not (a and b) then return nil end
  local ax, ay = tonumber(a.x or a[1]), tonumber(a.y or a[2])
  local bx, by = tonumber(b.x or b[1]), tonumber(b.y or b[2])
  if not (ax and ay and bx and by) then return nil end
  return math.min(ax, bx), math.min(ay, by), math.max(ax, bx), math.max(ay, by)
end

local function identity(entity, key_of)
  if key_of then
    local ok, key = pcall(key_of, entity)
    if ok and key ~= nil then return tostring(key) end
  end
  if entity.unit_number then return "u:" .. tostring(entity.unit_number) end
  local p = entity.position or { x = 0, y = 0 }
  return tostring(entity.name or entity.type or "?") .. ":" ..
    tostring(p.x or p[1] or 0) .. ":" .. tostring(p.y or p[2] or 0)
end

function M.scan(surface, area, opts)
  opts = opts or {}
  local x1, y1, x2, y2 = bounds(area)
  local info = { complete = true, queries = 0, splits = 0,
    saturated_queries = 0, truncated_leaves = 0, unique = 0,
    budget_exhausted = false, reason = "complete" }
  if not (surface and type(surface.find_entities_filtered) == "function"
      and x1 and x2 > x1 and y2 > y1) then
    info.complete, info.reason = false, "invalid-scan-request"
    return nil, info
  end
  local limit = math.max(1, math.floor(tonumber(opts.limit) or 768))
  local max_queries = math.max(1, math.floor(tonumber(opts.max_queries) or M.max_queries))
  local max_depth = math.max(0, math.floor(tonumber(opts.max_depth) or M.max_depth))
  local max_entities = math.max(1, math.floor(tonumber(opts.max_entities) or M.max_entities))
  local min_extent = tonumber(opts.min_extent) or M.min_extent
  local pending = { {x1, y1, x2, y2, 0} }
  local cursor, out, seen = 1, {}, {}
  while cursor <= #pending and info.queries < max_queries do
    local item = pending[cursor]
    cursor = cursor + 1
    local ax, ay, bx, by, depth = item[1], item[2], item[3], item[4], item[5]
    info.queries = info.queries + 1
    local ok, found = pcall(surface.find_entities_filtered,
      {area = {{ax, ay}, {bx, by}}, limit = limit})
    if not ok or type(found) ~= "table" then
      info.complete = false
      info.reason = "surface-query-failed"
      info.error = not ok and tostring(found) or "non-table-result"
      if info.queries == 1 then return nil, info end
      break
    end
    for _, entity in ipairs(found) do
      if entity and entity.valid then
        local key = identity(entity, opts.key_of)
        if not seen[key] then
          if #out >= max_entities then
            info.complete, info.budget_exhausted = false, true
            info.reason = "entity-budget"
            info.unique = #out
            return out, info
          end
          seen[key] = true
          out[#out + 1] = entity
        end
      end
    end
    if #found >= limit then
      info.saturated_queries = info.saturated_queries + 1
      if depth >= max_depth or bx - ax <= min_extent or by - ay <= min_extent then
        info.complete = false
        info.truncated_leaves = info.truncated_leaves + 1
        info.reason = "saturated-leaf"
      else
        local mx, my = (ax + bx) / 2, (ay + by) / 2
        -- Fixed quadrant order keeps entity and ownership decisions deterministic.
        pending[#pending + 1] = {ax, ay, mx, my, depth + 1}
        pending[#pending + 1] = {mx, ay, bx, my, depth + 1}
        pending[#pending + 1] = {ax, my, mx, by, depth + 1}
        pending[#pending + 1] = {mx, my, bx, by, depth + 1}
        info.splits = info.splits + 1
      end
    end
  end
  if cursor <= #pending then
    info.complete = false
    info.budget_exhausted = true
    info.reason = "query-budget"
  end
  info.unique = #out
  return out, info
end

return M
