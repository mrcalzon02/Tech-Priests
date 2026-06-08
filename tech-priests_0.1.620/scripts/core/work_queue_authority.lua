-- scripts/core/work_queue_authority.lua
-- Tech Priests 0.1.604
-- Shared surface/force/category work queues.  Work is discovered once, queued,
-- then claimed by suitable pairs through the reservation authority.

local M = {}
M.version = "0.1.620"
M.storage_key = "work_queue_authority_0601"
M.default_ttl = 1800
M.spatial_cell_size = 64
M.spatial_claim_radius = 128
M.no_work_ttl = 60 * 2
M.full_fallback_budget = 192
M.categories = { "repair", "sanctify", "resource", "construction", "pickup", "emergency", "combat" }

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end; local ok,o=pcall(function() return tostring(v) end); return ok and o or "?" end
local function metric(k,n) local fn=rawget(_G,"tech_priests_runtime_metric_0606"); if type(fn)=="function" then pcall(fn,k,n or 1) end end
local function dist_sq(a,b) if not (a and b) then return 999999999 end; local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end
local function pair_id(pair) return valid(pair and pair.station) and safe(pair.station.unit_number) or safe(pair and pair.station_unit or "unknown") end
local function get_reservations() local ok,R=pcall(require,"scripts.core.work_reservations"); if ok then return R end return rawget(_G,"TechPriestsWorkReservations0601") end
local function indexed_entities_for_area(surface, area)
  local fn = rawget(_G, "tech_priests_efficiency_0579_entities_for_area")
  if type(fn) == "function" then
    local ok, entities = pcall(fn, surface, area)
    if ok and type(entities) == "table" then return entities, "indexed-0579" end
  end
  local okM, Index = pcall(require, "scripts.core.efficiency_economy_0579")
  if okM and Index and type(Index.entities_for_area) == "function" then
    local ok, entities = pcall(Index.entities_for_area, surface, area)
    if ok and type(entities) == "table" then return entities, "indexed-0579" end
  end
  return nil, "index-miss"
end
local function note_area_scan(surface, area, entities)
  local fn = rawget(_G, "tech_priests_efficiency_0579_note_area_scan")
  if type(fn) == "function" then pcall(fn, surface, area, entities); return end
  local okM, Index = pcall(require, "scripts.core.efficiency_economy_0579")
  if okM and Index and type(Index.note_area_scan) == "function" then pcall(Index.note_area_scan, surface, area, entities) end
end

local function missing_health(entity)
  if not (valid(entity) and entity.health and entity.max_health) then return 0 end
  return math.max(0, (tonumber(entity.max_health) or 0) - (tonumber(entity.health) or 0))
end

local function is_damaged_repair_target(entity, force)
  if not (valid(entity) and entity.health and entity.max_health) then return false end
  if force and entity.force and entity.force.name ~= force.name then return false end
  local name = string.lower(tostring(entity.name or ""))
  if name:find("tech%-priest") or name:find("tech_priest") or name == "tech-priest-proxy-turret" then return false end
  return missing_health(entity) > 0.01
end

local function repair_priority(entity, origin)
  local missing = missing_health(entity)
  local maxh = tonumber(entity.max_health) or 1
  local ratio = maxh > 0 and missing / maxh or 0
  local type_bonus = 0
  local t = string.lower(tostring(entity.type or ""))
  local n = string.lower(tostring(entity.name or ""))
  if t:find("turret",1,true) or n:find("turret",1,true) then type_bonus = 220
  elseif t == "wall" or n:find("wall",1,true) or t == "gate" then type_bonus = 200
  elseif t:find("assembling",1,true) or t:find("furnace",1,true) then type_bonus = 100
  elseif t:find("generator",1,true) or t:find("boiler",1,true) or t:find("reactor",1,true) then type_bonus = 90 end
  return math.floor(ratio * 10000 + missing * 2 + type_bonus - math.sqrt(dist_sq(origin, entity.position)) * 4)
end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or { version = M.version, enabled = true, queues = {}, spatial_index = {}, no_work_until = {}, category_generations = {}, stats = {}, cleanup_cursor_0620 = 1 }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  r.queues = r.queues or {}
  r.spatial_index = r.spatial_index or {}
  r.no_work_until = r.no_work_until or {}
  r.category_generations = r.category_generations or {}
  r.stats = r.stats or {}
  r.cleanup_cursor_0620 = tonumber(r.cleanup_cursor_0620) or 1
  return r
end

local function stat(k,n) local r=M.root(); r.stats[k]=(r.stats[k] or 0)+(n or 1) end
local function surface_index_from(order)
  if valid(order and order.target) and order.target.surface then return order.target.surface.index end
  return order and order.surface_index or 0
end
local function force_index_from(order)
  if valid(order and order.target) and order.target.force then return order.target.force.index end
  return order and order.force_index or 0
end
local function category_bucket(surface_index, force_index, category)
  local r=M.root(); surface_index=safe(surface_index or 0); force_index=safe(force_index or 0); category=tostring(category or "misc")
  r.queues[surface_index]=r.queues[surface_index] or {}; r.queues[surface_index][force_index]=r.queues[surface_index][force_index] or {}; r.queues[surface_index][force_index][category]=r.queues[surface_index][force_index][category] or {}
  return r.queues[surface_index][force_index][category]
end

local function cell_xy(pos)
  local size = tonumber(M.spatial_cell_size) or 64
  pos = pos or { x = 0, y = 0 }
  return math.floor((tonumber(pos.x) or tonumber(pos[1]) or 0) / size), math.floor((tonumber(pos.y) or tonumber(pos[2]) or 0) / size)
end

local function cell_key(pos)
  local cx, cy = cell_xy(pos)
  return tostring(cx) .. ":" .. tostring(cy)
end

local function spatial_root(surface_index, force_index, category)
  local r = M.root()
  r.spatial_index = r.spatial_index or {}
  surface_index=safe(surface_index or 0); force_index=safe(force_index or 0); category=tostring(category or "misc")
  r.spatial_index[surface_index] = r.spatial_index[surface_index] or {}
  r.spatial_index[surface_index][force_index] = r.spatial_index[surface_index][force_index] or {}
  r.spatial_index[surface_index][force_index][category] = r.spatial_index[surface_index][force_index][category] or {}
  return r.spatial_index[surface_index][force_index][category]
end

local function category_generation(surface_index, force_index, category)
  local r = M.root()
  r.category_generations = r.category_generations or {}
  surface_index=safe(surface_index or 0); force_index=safe(force_index or 0); category=tostring(category or "misc")
  r.category_generations[surface_index] = r.category_generations[surface_index] or {}
  r.category_generations[surface_index][force_index] = r.category_generations[surface_index][force_index] or {}
  return tonumber(r.category_generations[surface_index][force_index][category]) or 0
end

local function bump_category_generation(surface_index, force_index, category)
  local r = M.root()
  r.category_generations = r.category_generations or {}
  surface_index=safe(surface_index or 0); force_index=safe(force_index or 0); category=tostring(category or "misc")
  r.category_generations[surface_index] = r.category_generations[surface_index] or {}
  r.category_generations[surface_index][force_index] = r.category_generations[surface_index][force_index] or {}
  r.category_generations[surface_index][force_index][category] = (tonumber(r.category_generations[surface_index][force_index][category]) or 0) + 1
  stat("category_generation_bumped")
  return r.category_generations[surface_index][force_index][category]
end

local function no_work_root(surface_index, force_index, category)
  local r = M.root()
  r.no_work_until = r.no_work_until or {}
  surface_index=safe(surface_index or 0); force_index=safe(force_index or 0); category=tostring(category or "misc")
  r.no_work_until[surface_index] = r.no_work_until[surface_index] or {}
  r.no_work_until[surface_index][force_index] = r.no_work_until[surface_index][force_index] or {}
  r.no_work_until[surface_index][force_index][category] = r.no_work_until[surface_index][force_index][category] or {}
  return r.no_work_until[surface_index][force_index][category]
end

local function no_work_record_for(pair, category)
  if not (pair and valid(pair.station)) then return nil end
  local root = no_work_root(pair.station.surface.index, pair.station.force.index, category)
  return root[pair_id(pair)]
end

local function no_work_active(pair, category)
  if not (pair and valid(pair.station)) then return false end
  local root = no_work_root(pair.station.surface.index, pair.station.force.index, category)
  local key = pair_id(pair)
  local rec = root[key]
  if not rec then return false end
  local gen = category_generation(pair.station.surface.index, pair.station.force.index, category)
  if tonumber(rec.generation or -1) ~= gen then
    root[key] = nil
    stat("no_work_cleared_by_generation")
    return false
  end
  if (tonumber(rec.until_tick) or 0) > now() then return true end
  root[key] = nil
  stat("no_work_expired")
  return false
end

local function set_no_work(pair, category, ttl)
  if not (pair and valid(pair.station)) then return end
  local root = no_work_root(pair.station.surface.index, pair.station.force.index, category)
  root[pair_id(pair)] = {
    until_tick = now() + (tonumber(ttl) or M.no_work_ttl),
    generation = category_generation(pair.station.surface.index, pair.station.force.index, category),
    tick = now(),
  }
  stat("no_work_set")
end

local function spatial_add(order)
  if not (order and order.id and order.position) then return false end
  local idx = spatial_root(order.surface_index, order.force_index, order.category)
  local ck = cell_key(order.position)
  idx[ck] = idx[ck] or {}
  idx[ck][order.id] = true
  order.spatial_cell_0614 = ck
  return true
end

local function spatial_remove(order)
  if not (order and order.id) then return false end
  local idx = spatial_root(order.surface_index, order.force_index, order.category)
  local ck = order.spatial_cell_0614 or (order.position and cell_key(order.position))
  if ck and idx[ck] then idx[ck][order.id] = nil end
  return true
end

local function nearby_cell_keys(pos, radius)
  local size = tonumber(M.spatial_cell_size) or 64
  local r = tonumber(radius) or M.spatial_claim_radius or 128
  local cx, cy = cell_xy(pos)
  local span = math.max(0, math.ceil(r / size))
  local keys = {}
  for dx = -span, span do
    for dy = -span, span do
      keys[#keys + 1] = tostring(cx + dx) .. ":" .. tostring(cy + dy)
    end
  end
  return keys
end

function M.order_key(category, target, explicit)
  if explicit then return safe(explicit) end
  local R=get_reservations(); local tk = R and R.target_key and R.target_key(target) or safe(target)
  return tostring(category or "work") .. ":" .. tk
end

function M.submit(category, target, opts)
  local r=M.root(); if r.enabled == false then return false,"disabled" end
  if not valid(target) and type(target) ~= "table" then return false,"invalid-target" end
  opts=opts or {}; category=tostring(category or opts.category or "misc")
  local order = {
    id = M.order_key(category, target, opts.id),
    category = category,
    target = target,
    position = opts.position or (valid(target) and target.position) or target.position or target,
    surface_index = opts.surface_index or (valid(target) and target.surface and target.surface.index) or 0,
    force_index = opts.force_index or (valid(target) and target.force and target.force.index) or 0,
    priority = tonumber(opts.priority) or 100,
    created_tick = opts.created_tick or now(),
    expires_tick = opts.expires_tick or (now() + (tonumber(opts.ttl) or M.default_ttl)),
    source = opts.source,
    reserved_by = nil,
  }
  local bucket = category_bucket(order.surface_index, order.force_index, category)
  local existing = bucket[order.id]
  if existing then
    -- 0.1.613: duplicate submissions fold into the existing backlog order but
    -- still refresh useful urgency/expiry metadata. This keeps event-fed work
    -- responsive without creating another queue layer or accumulating duplicate
    -- orders for the same target.
    existing.priority = math.max(tonumber(existing.priority) or 0, tonumber(order.priority) or 0)
    existing.expires_tick = math.max(tonumber(existing.expires_tick) or 0, tonumber(order.expires_tick) or 0)
    existing.position = existing.position or order.position
    if not existing.spatial_cell_0614 then spatial_add(existing) end
    existing.last_duplicate_tick_0613 = now()
    existing.duplicate_count_0613 = (existing.duplicate_count_0613 or 0) + 1
    existing.last_duplicate_source_0613 = order.source or existing.last_duplicate_source_0613
    bump_category_generation(order.surface_index, order.force_index, category)
    stat("duplicates_folded")
    stat("duplicates_refreshed")
    metric("work_queue_duplicates_refreshed", 1)
    return true,"duplicate",existing
  end
  bucket[order.id]=order; spatial_add(order); bump_category_generation(order.surface_index, order.force_index, category); stat("submitted_" .. category); stat("submitted_total"); stat("spatial_indexed")
  return true,"submitted",order
end

local function valid_order(order)
  if not order then return false end
  if (tonumber(order.expires_tick) or 0) <= now() then return false end
  if valid(order.target) then return true end
  if type(order.target)=="table" and (order.target.position or (order.target.x and order.target.y)) then return true end
  return false
end

local function consider_order_for_claim(bucket, id, order, pair, category, R, state)
  state.examined = state.examined + 1
  if not valid_order(order) then
    spatial_remove(order)
    bucket[id]=nil
    stat("expired_or_invalid_removed")
    return
  end
  local claimed = R and R.is_claimed and R.is_claimed(category, order.target, pair)
  if claimed then return end
  local score = (tonumber(order.priority) or 0) * 100000 - dist_sq(pair.station.position, order.position)
  if not state.best_score or score > state.best_score then
    state.best, state.best_score, state.best_id = order, score, id
  end
end

function M.claim_nearest(pair, category, opts)
  local r=M.root(); if r.enabled == false then return nil,"disabled" end
  if not (valid(pair and pair.station)) then return nil,"invalid-pair" end
  opts=opts or {}; category=tostring(category or "misc")
  if no_work_active(pair, category) then
    stat("no_work_skip_" .. category)
    stat("no_work_skip_total")
    metric("work_queue_no_work_skip", 1)
    return nil, "no-work-cooldown"
  end
  local bucket = category_bucket(pair.station.surface.index, pair.station.force.index, category)
  local R=get_reservations()
  local state = { examined = 0 }
  local search_radius = tonumber(opts.search_radius or pair.radius or M.spatial_claim_radius) or M.spatial_claim_radius
  local spatial_budget = tonumber(opts.spatial_budget or 96) or 96
  local used_spatial = false
  local idx = spatial_root(pair.station.surface.index, pair.station.force.index, category)
  for _, ck in ipairs(nearby_cell_keys(pair.station.position, search_radius)) do
    local ids = idx[ck]
    if ids then
      used_spatial = true
      for id in pairs(ids) do
        local order = bucket[id]
        if order then
          consider_order_for_claim(bucket, id, order, pair, category, R, state)
          if state.examined >= spatial_budget and state.best then break end
        else
          ids[id] = nil
        end
      end
    end
    if state.examined >= spatial_budget and state.best then break end
  end
  if used_spatial then
    stat("claim_spatial_attempts")
    stat("claim_spatial_examined", state.examined)
    metric("work_queue_spatial_claim_examined", state.examined)
  end
  local full_fallback_exhausted = false
  if not state.best then
    if used_spatial then stat("claim_spatial_miss") end
    -- 0.1.619: Safety fallback remains beneath this authority, but it is now
    -- budgeted. Spatial indexing should handle the common path; if the fallback
    -- must inspect a large backlog, defer rather than letting one priest consume
    -- an unbounded queue scan spike. Do not set a no-work cooldown when the
    -- fallback budget is exhausted, because unexamined orders may still exist.
    local fallback_budget = tonumber(opts.full_fallback_budget or M.full_fallback_budget) or 192
    local before = state.examined
    for id, order in pairs(bucket) do
      consider_order_for_claim(bucket, id, order, pair, category, R, state)
      if (state.examined - before) >= fallback_budget and not state.best then
        full_fallback_exhausted = true
        break
      end
    end
    stat("claim_full_fallbacks")
    stat("claim_full_fallback_examined", state.examined - before)
    if full_fallback_exhausted then
      stat("claim_full_fallback_budget_exhausted")
      metric("work_queue_full_fallback_budget_exhausted", 1)
    end
  else
    stat("claim_spatial_hit")
  end
  stat("claim_examined_" .. category, state.examined)
  stat("claim_examined_total", state.examined)
  metric("work_queue_claim_examined", state.examined)
  if not state.best then
    if full_fallback_exhausted then return nil,"claim-fallback-budget-exhausted" end
    stat("claim_none_" .. category); set_no_work(pair, category, opts.no_work_ttl or M.no_work_ttl); return nil,"none"
  end
  if R and R.claim then
    local ok,why = R.claim(category, state.best.target, pair, opts.ttl or 600, { surface_index=state.best.surface_index, force_index=state.best.force_index })
    if not ok then stat("claim_denied_" .. category); return nil,why or "claimed" end
  end
  state.best.reserved_by = pair_id(pair); state.best.reserved_tick = now(); stat("claimed_" .. category); stat("claimed_total")
  if opts.remove ~= false then spatial_remove(state.best); bucket[state.best_id] = nil end
  return state.best,"claimed"
end

function M.discover_repair_near(pair, opts)
  -- Authority boundary: work_queue_authority discovers/records shared work only.
  -- It does not execute repair behavior and does not assign per-priest orders.
  local r=M.root(); if r.enabled == false then return 0, "disabled" end
  if not (valid(pair and pair.station)) then return 0, "invalid-pair" end
  opts = opts or {}
  local station = pair.station
  local radius = tonumber(opts.radius or pair.radius) or 32
  local limit = tonumber(opts.limit) or 32
  local submitted = 0
  local checked = 0
  local area = {{station.position.x-radius, station.position.y-radius},{station.position.x+radius, station.position.y+radius}}
  local Scan = rawget(_G, "TechPriestsScanRouting0610")
  if not Scan then local okS, mod = pcall(require, "scripts.core.scan_routing_0610"); if okS then Scan = mod end end
  local entities, source
  if Scan and type(Scan.find_entities) == "function" then
    entities, source = Scan.find_entities(station.surface, { area = area }, { category = "repair", negative_key = "repair:" .. safe(station.surface.index) .. ":" .. safe(station.force.index) .. ":" .. safe(pair_id(pair)), negative_ttl = 60 * 4, record_negative = false })
  else
    entities, source = indexed_entities_for_area(station.surface, area)
  end
  if entities and source == "indexed-0579" then
    stat("repair_discovery_index_hits")
  elseif not entities then
    local ok, scanned = pcall(function()
      return station.surface.find_entities_filtered({ area=area })
    end)
    if not ok or not scanned then stat("repair_discovery_failed"); return 0, "scan-failed" end
    entities = scanned
    source = "direct-scan"
    stat("repair_discovery_direct_scans"); metric("direct_surface_scans",1); metric("scans_attempted",1)
    note_area_scan(station.surface, area, entities)
  end
  for _, entity in pairs(entities) do
    checked = checked + 1
    if checked > limit then break end
    if is_damaged_repair_target(entity, station.force) then
      local did = select(1, M.submit("repair", entity, {
        priority = repair_priority(entity, station.position),
        ttl = tonumber(opts.ttl) or 900,
        source = opts.source or "work_queue_repair_discovery",
      }))
      if did then submitted = submitted + 1 end
    end
  end
  if submitted == 0 and Scan and type(Scan.record_negative) == "function" then
    Scan.record_negative("repair", "repair:" .. safe(station.surface.index) .. ":" .. safe(station.force.index) .. ":" .. safe(pair_id(pair)), 60 * 4)
  end
  stat("repair_discovery_scans")
  stat("repair_discovery_checked", checked)
  stat("repair_discovery_submitted", submitted)
  return submitted, "source=" .. safe(source) .. " checked=" .. safe(checked) .. " submitted=" .. safe(submitted)
end

function M.cleanup(category, budget)
  local r=M.root(); local cleaned=0
  local cats
  if category then
    cats = { tostring(category) }
  else
    -- 0.1.620: rotate queue cleanup by category so maintenance does not sweep
    -- all shared backlog categories every broker pulse. This remains inside the
    -- existing work queue authority and only changes cleanup traversal pressure.
    local idx = tonumber(r.cleanup_cursor_0620) or 1
    if idx < 1 or idx > #M.categories then idx = 1 end
    cats = { M.categories[idx] }
    r.cleanup_cursor_0620 = (idx % #M.categories) + 1
    stat("cleanup_rotated_categories")
  end
  for _, surface_bucket in pairs(r.queues or {}) do
    for _, force_bucket in pairs(surface_bucket or {}) do
      for _, cat in ipairs(cats) do
        local bucket = force_bucket[cat] or {}
        for id, order in pairs(bucket) do
          if not valid_order(order) then
            spatial_remove(order); bucket[id]=nil; cleaned=cleaned+1; stat("cleanup_removed")
            if budget and cleaned >= budget then stat("cleanup_budget_exhausted"); return cleaned end
          end
        end
      end
    end
  end
  return cleaned
end

function M.count(category)
  local r=M.root(); local n=0
  for _, surface_bucket in pairs(r.queues or {}) do for _, force_bucket in pairs(surface_bucket or {}) do for id,_ in pairs(force_bucket[category] or {}) do n=n+1 end end end
  return n
end

function M.report_lines()
  M.cleanup(nil, 200)
  local r=M.root(); local parts={}
  for _, cat in ipairs(M.categories) do parts[#parts+1]=cat .. "=" .. safe(M.count(cat)) end
  return { "[tp-runtime-report] work-queues " .. table.concat(parts," ") .. " submitted=" .. safe(r.stats.submitted_total or 0) .. " claimed=" .. safe(r.stats.claimed_total or 0) .. " folded=" .. safe(r.stats.duplicates_folded or 0) .. " refreshed=" .. safe(r.stats.duplicates_refreshed or 0) .. " claim_examined=" .. safe(r.stats.claim_examined_total or 0) .. " spatial_hit=" .. safe(r.stats.claim_spatial_hit or 0) .. " spatial_miss=" .. safe(r.stats.claim_spatial_miss or 0) .. " spatial_examined=" .. safe(r.stats.claim_spatial_examined or 0) .. " full_fallback=" .. safe(r.stats.claim_full_fallbacks or 0) .. " fallback_examined=" .. safe(r.stats.claim_full_fallback_examined or 0) .. " fallback_budget_exhausted=" .. safe(r.stats.claim_full_fallback_budget_exhausted or 0) .. " no_work_set=" .. safe(r.stats.no_work_set or 0) .. " no_work_skip=" .. safe(r.stats.no_work_skip_total or 0) .. " no_work_gen_clear=" .. safe(r.stats.no_work_cleared_by_generation or 0) .. " removed=" .. safe(r.stats.cleanup_removed or 0) .. " cleanup_rotations=" .. safe(r.stats.cleanup_rotated_categories or 0) .. " cleanup_budget_exhausted=" .. safe(r.stats.cleanup_budget_exhausted or 0) .. " repair_scans=" .. safe(r.stats.repair_discovery_scans or 0) .. " repair_index_hits=" .. safe(r.stats.repair_discovery_index_hits or 0) .. " repair_direct_scans=" .. safe(r.stats.repair_discovery_direct_scans or 0) .. " repair_checked=" .. safe(r.stats.repair_discovery_checked or 0) .. " repair_submitted=" .. safe(r.stats.repair_discovery_submitted or 0) }
end

function M.install()
  M.root()
  _G.TechPriestsWorkQueueAuthority0601 = M
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service) == "function" then
    broker.register_service({
      name = "work_queue_authority_0601_cleanup",
      category = "runtime-cleanup",
      interval = 300,
      priority = 82,
      budget = 120,
      note = "expires invalid/stale shared work queue orders",
      fn = function(event, budget)
        local n = M.cleanup(nil, budget or 120)
        return n > 0, "removed=" .. safe(n)
      end
    })
  end
  return true
end

return M
