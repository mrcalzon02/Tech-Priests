-- Bounded deterministic subdivision for dense station Auspex scans.
-- Plain continuation data; entity references are values, never saved keys.
-- No polling, callback closures in state, event handlers, or world mutations.
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

function M.begin(area, opts)
  opts = opts or {}
  local x1, y1, x2, y2 = bounds(area)
  local info = { complete = true, queries = 0, splits = 0,
    saturated_queries = 0, truncated_leaves = 0, unique = 0,
    identity_collisions = 0, budget_exhausted = false, reason = "complete",
    filtered_queries = 0, prefilter_fallbacks = 0 }
  local state = {
    schema = 1, info = info, out = {}, seen = {}, collisions = {},
    pending = {}, cursor = 1, done = false,
    limit = math.max(1, math.floor(tonumber(opts.limit) or 768)),
    max_queries = math.max(1, math.floor(tonumber(opts.max_queries) or M.max_queries)),
    max_depth = math.max(0, math.floor(tonumber(opts.max_depth) or M.max_depth)),
    max_entities = math.max(1, math.floor(tonumber(opts.max_entities) or M.max_entities)),
    min_extent = tonumber(opts.min_extent) or M.min_extent,
  }
  -- Only native type names belong in this option. Do not retain opts itself:
  -- its key_of callback must be supplied anew to step after a module reload.
  if type(opts.exclude_types) == "table" and #opts.exclude_types > 0 then
    state.exclude_types = {}
    for index, name in ipairs(opts.exclude_types) do
      if type(name) == "string" then state.exclude_types[index] = name end
    end
  end
  state.prefilter_available = state.exclude_types ~= nil and #state.exclude_types > 0
  if not (x1 and x2 > x1 and y2 > y1) then
    info.complete, info.reason = false, "invalid-scan-request"
    state.done, state.nil_result = true, true
  else
    state.pending[1] = {x1, y1, x2, y2, 0}
  end
  return state
end

local function result(state, usage)
  state.info.unique = #state.out
  local out = state.out
  if state.nil_result then out = nil end
  return state.done, out, state.info, usage
end

local function finish(state, check_pending)
  if check_pending and state.cursor <= #state.pending then
    state.info.complete, state.info.budget_exhausted = false, true
    state.info.reason = "query-budget"
  end
  state.done, state.buffer, state.buffer_index, state.current = true, nil, nil, nil
end

local function finish_buffer(state)
  local item, info = state.current, state.info
  local ax, ay, bx, by, depth = item[1], item[2], item[3], item[4], item[5]
  if #state.buffer >= state.limit then
    info.saturated_queries = info.saturated_queries + 1
    if depth >= state.max_depth or bx - ax <= state.min_extent or by - ay <= state.min_extent then
      info.complete = false
      info.truncated_leaves = info.truncated_leaves + 1
      info.reason = "saturated-leaf"
    else
      local mx, my = (ax + bx) / 2, (ay + by) / 2
      -- Preserve the original breadth-first fixed quadrant order.
      local pending = state.pending
      pending[#pending + 1] = {ax, ay, mx, my, depth + 1}
      pending[#pending + 1] = {mx, ay, bx, my, depth + 1}
      pending[#pending + 1] = {ax, my, mx, by, depth + 1}
      pending[#pending + 1] = {mx, my, bx, by, depth + 1}
      info.splits = info.splits + 1
    end
  end
  state.buffer, state.buffer_index, state.current = nil, nil, nil
end

-- info.complete is a coverage result only when done is true. Per-call usage
-- counts real engine queries and every inspected buffer entry, even an invalid
-- or duplicate entity. A caller may classify just the newly appended out tail.
function M.step(state, surface, budget, key_of)
  local usage = {queries = 0, entities = 0}
  if state.done then return result(state, usage) end
  if not (surface and surface.valid ~= false
      and type(surface.find_entities_filtered) == "function") then
    state.info.complete, state.info.reason = false, "invalid-scan-request"
    state.nil_result = true
    finish(state, false)
    return result(state, usage)
  end
  budget = budget or {}
  local queries = math.max(0, math.floor(tonumber(budget.queries) or 1))
  local entities = math.max(0, math.floor(tonumber(budget.entities) or 128))
  local info = state.info
  while not state.done do
    if state.buffer then
      local entity = state.buffer[state.buffer_index]
      if entity == nil then
        finish_buffer(state)
      elseif usage.entities >= entities then
        return result(state, usage)
      else
        state.buffer_index = state.buffer_index + 1
        usage.entities = usage.entities + 1
        if entity and entity.valid then
          local key = identity(entity, key_of)
          local first = state.seen[key]
          local duplicate = first ~= nil and first == entity
          if first and not duplicate then
            -- LuaEntity equality distinguishes colliding unitless identities.
            -- References are retained as values under deterministic string keys.
            local group = state.collisions[key]
            if not group then group = {first}; state.collisions[key] = group end
            for i = 1, #group do
              if group[i] == entity then duplicate = true; break end
            end
            if not duplicate then
              group[#group + 1] = entity
              info.identity_collisions = info.identity_collisions + 1
              info.complete = false
              info.reason = "identity-collision"
            end
          elseif not first then
            state.seen[key] = entity
          end
          if not duplicate then
            if #state.out >= state.max_entities then
              info.complete, info.budget_exhausted = false, true
              info.reason = "entity-budget"
              finish(state, false)
              return result(state, usage)
            end
            state.out[#state.out + 1] = entity
          end
        end
      end
    else
      if not state.current then
        if state.cursor > #state.pending or info.queries >= state.max_queries then
          finish(state, true)
          return result(state, usage)
        end
        state.current = state.pending[state.cursor]
        state.cursor = state.cursor + 1
      end
      if usage.queries >= queries then return result(state, usage) end
      local item = state.current
      local query = {area = {{item[1], item[2]}, {item[3], item[4]}}, limit = state.limit}
      local filtered = state.prefilter_available
      if filtered then
        query.type, query.invert = state.exclude_types, true
        info.filtered_queries = info.filtered_queries + 1
      end
      info.queries, usage.queries = info.queries + 1, usage.queries + 1
      local ok, found = pcall(surface.find_entities_filtered, query)
      if (not ok or type(found) ~= "table") and filtered then
        info.prefilter_fallbacks = info.prefilter_fallbacks + 1
        state.prefilter_available = false
        if info.queries >= state.max_queries then
          info.complete, info.budget_exhausted = false, true
          info.reason = "prefilter-fallback-budget"
          finish(state, true)
        end
        -- Keep the current partition for an unfiltered retry. It consumes a
        -- second real query, in a later admission when this one's budget ends.
      elseif not ok or type(found) ~= "table" then
        info.complete, info.reason = false, "surface-query-failed"
        info.error = not ok and tostring(found) or "non-table-result"
        state.nil_result = info.queries == 1
        finish(state, not state.nil_result)
      else
        state.buffer, state.buffer_index = found, 1
      end
    end
  end
  return result(state, usage)
end

-- Compatibility callers deliberately retain the synchronous public API.
function M.scan(surface, area, opts)
  local state = M.begin(area, opts)
  local done, out, info
  repeat
    done, out, info = M.step(state, surface,
      {queries = state.max_queries, entities = math.huge}, opts and opts.key_of)
  until done
  return out, info
end

return M
