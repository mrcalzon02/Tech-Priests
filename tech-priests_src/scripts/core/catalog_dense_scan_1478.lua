-- Bounded deterministic subdivision for dense station Auspex scans.
-- No global event handlers or world mutations; caller-owned continuations are serializable.
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

-- Only primitives, arrays/maps and LuaEntity references are saved here.
-- key_of is supplied to step(), never retained in the continuation.
function M.begin(area, opts)
  opts = opts or {}
  local x1, y1, x2, y2 = bounds(area)
  local info = { complete = true, queries = 0, splits = 0,
    saturated_queries = 0, truncated_leaves = 0, unique = 0,
    identity_collisions = 0, budget_exhausted = false, reason = "complete",
    filtered_queries = 0, prefilter_fallbacks = 0 }
  if not (x1 and x2 > x1 and y2 > y1) then
    info.complete, info.reason = false, "invalid-scan-request"
    return nil, info
  end
  local excluded = {}
  for _, kind in ipairs(opts.exclude_types or {}) do excluded[#excluded + 1] = kind end
  return { version = 1, info = info,
    limit = math.max(1, math.floor(tonumber(opts.limit) or 768)),
    max_queries = math.max(1, math.floor(tonumber(opts.max_queries) or M.max_queries)),
    max_depth = math.max(0, math.floor(tonumber(opts.max_depth) or M.max_depth)),
    max_entities = math.max(1, math.floor(tonumber(opts.max_entities) or M.max_entities)),
    min_extent = tonumber(opts.min_extent) or M.min_extent,
    pending = {{x1, y1, x2, y2, 0}}, cursor = 1,
    results = {}, seen = {}, collisions = {}, exclude_types = excluded,
    prefilter_available = #excluded > 0,
  }, info
end

local function finish(state, reason)
  state.done = true
  state.info.unique = #state.results
  if reason then
    state.info.complete, state.info.reason = false, reason
  end
end

local function accept(state, entity, key, batch, keys)
  if #state.results >= state.max_entities then
    state.info.budget_exhausted = true
    finish(state, "entity-budget")
    return false
  end
  state.results[#state.results + 1] = entity
  batch[#batch + 1], keys[#keys + 1] = entity, key
  state.info.unique = #state.results
  return true
end

local function finish_result(state)
  local current = state.current
  local item = current.area
  if #current.entities >= state.limit then
    local ax, ay, bx, by, depth = item[1], item[2], item[3], item[4], item[5]
    state.info.saturated_queries = state.info.saturated_queries + 1
    if depth >= state.max_depth or bx - ax <= state.min_extent or by - ay <= state.min_extent then
      state.info.complete = false
      state.info.truncated_leaves = state.info.truncated_leaves + 1
      state.info.reason = "saturated-leaf"
    else
      local mx, my = (ax + bx) / 2, (ay + by) / 2
      local pending = state.pending
      pending[#pending + 1] = {ax, ay, mx, my, depth + 1}
      pending[#pending + 1] = {mx, ay, bx, my, depth + 1}
      pending[#pending + 1] = {ax, my, mx, by, depth + 1}
      pending[#pending + 1] = {mx, my, bx, by, depth + 1}
      state.info.splits = state.info.splits + 1
    end
  end
  state.current = nil
end

-- Budget counts include invalid/duplicate result rows and every collision
-- comparison, so a yielded native result cannot hide an unbounded Lua walk.
-- Native calls and result traversal have separate GLOBAL caller budgets.
function M.step(surface, state, opts)
  opts = opts or {}
  local batch, keys = {}, {}
  local work = { queries = 0, entities = 0, keys = keys }
  if not state then return batch, nil, true, work end
  if not (surface and type(surface.find_entities_filtered) == "function") then
    finish(state, "invalid-scan-request")
  end
  local query_budget = math.max(0, math.floor(tonumber(opts.query_budget) or 0))
  local entity_budget = math.max(0, math.floor(tonumber(opts.entity_budget) or 0))
  while not state.done do
    if state.candidate then
      if work.entities >= entity_budget then break end
      local candidate = state.candidate
      local group = state.collisions[candidate.key]
      work.entities = work.entities + 1
      if group[candidate.index] == candidate.entity then
        state.candidate = nil -- same actual entity from an overlapping cell
      elseif candidate.index < #group then
        candidate.index = candidate.index + 1
      else
        group[#group + 1] = candidate.entity
        state.info.identity_collisions = state.info.identity_collisions + 1
        state.info.complete, state.info.reason = false, "identity-collision"
        accept(state, candidate.entity, candidate.key, batch, keys)
        state.candidate = nil
      end
    elseif state.current then
      local current = state.current
      if current.cursor > #current.entities then
        finish_result(state)
      else
        if work.entities >= entity_budget then break end
        local entity = current.entities[current.cursor]
        current.cursor = current.cursor + 1
        work.entities = work.entities + 1
        if entity and entity.valid then
          local key = identity(entity, opts.key_of)
          local first = state.seen[key]
          if not first then
            state.seen[key] = entity
            accept(state, entity, key, batch, keys)
          elseif first ~= entity then
            if not state.collisions[key] then state.collisions[key] = {first} end
            state.candidate = {entity = entity, key = key, index = 1}
          end
        end
      end
    else
      if not state.retry and state.cursor > #state.pending then
        finish(state)
      elseif state.info.queries >= state.max_queries then
        state.info.budget_exhausted = true
        finish(state, state.retry and "prefilter-fallback-budget" or "query-budget")
      elseif work.queries >= query_budget then
        break
      else
        local item = state.retry or state.pending[state.cursor]
        if not state.retry then state.cursor = state.cursor + 1 end
        local filtered = not state.retry and state.prefilter_available
        state.retry = nil
        local query = {area = {{item[1], item[2]}, {item[3], item[4]}}, limit = state.limit}
        if filtered then
          query.type, query.invert = state.exclude_types, true
          state.info.filtered_queries = state.info.filtered_queries + 1
        end
        state.info.queries = state.info.queries + 1
        work.queries = work.queries + 1
        local ok, found = pcall(surface.find_entities_filtered, query)
        if (not ok or type(found) ~= "table") and filtered then
          state.info.prefilter_fallbacks = state.info.prefilter_fallbacks + 1
          state.prefilter_available = false
          state.retry = item -- retry uses a later pulse if its call budget is spent
        elseif not ok or type(found) ~= "table" then
          state.info.error = not ok and tostring(found) or "non-table-result"
          finish(state, "surface-query-failed")
        else
          state.had_result = true
          state.current = {area = item, entities = found, cursor = 1}
        end
      end
    end
  end
  return batch, state.info, state.done == true, work
end

-- Explicit synchronous compatibility for manual callers and fixtures. The
-- scheduled catalog path calls begin/step through its existing registry owner.
function M.scan(surface, area, opts)
  local state, info = M.begin(area, opts)
  if not state then return nil, info end
  while not state.done do
    M.step(surface, state, {query_budget = state.max_queries,
      entity_budget = math.huge, key_of = opts and opts.key_of})
  end
  if not state.had_result and state.info.queries <= 1
      and (state.info.reason == "surface-query-failed"
        or state.info.reason == "invalid-scan-request") then return nil, state.info end
  return state.results, state.info
end

return M
