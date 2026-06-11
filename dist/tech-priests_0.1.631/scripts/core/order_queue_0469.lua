-- scripts/core/order_queue_0469.lua
-- Tech Priests 0.1.469
-- Per-pair order queue / resource writ authority.
--
-- Purpose:
--   Stop scheduler/resource thrash by converting repeated resource, recipe,
--   logistics, scavenge, assignment, repair, consecration, and combat claims
--   into stable per-priest orders.  An order key may exist only once in either
--   the active order or pending queue.  Higher-priority work can preempt lower
--   work, but the lower work is paused and resumed rather than destroyed.

local M = {}
M.version = "0.1.469"
M.storage_key = "order_queue_0469"
M.queue_limit = 8
M.default_timeout_ticks = 60 * 120
M.lease_ticks = 60 * 6
M.tick_interval = 17
M.diag_file = "tech-priests-emergency-diagnostics.log"

local original_assign_task = nil
local original_cancel_task = nil
local original_emergency_acquire = nil
local original_maybe_supply_scavenge = nil
local original_start_scavenge_scan = nil
local original_handle_scavenge = nil
local Doctrine = nil
local original_doctrine_start_direct = nil
local original_doctrine_handle_no_source = nil

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v)
  if v == nil then return "nil" end
  local ok, out = pcall(function() return tostring(v) end)
  return ok and out or "?"
end

local function lower(v) return string.lower(tostring(v or "")) end

local function ensure_root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    stats = {},
  }
  local root = storage.tech_priests[M.storage_key]
  root.version = M.version
  if root.enabled == nil then root.enabled = true end
  root.stats = root.stats or {}
  return root
end

local function enabled()
  local root = ensure_root()
  return root.enabled ~= false
end

local function root_stat(name, delta)
  local root = ensure_root()
  root.stats[name] = (root.stats[name] or 0) + (delta or 1)
end

local function pair_map()
  return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
end

local function valid_pair(pair)
  return type(pair) == "table" and valid(pair.station) and valid(pair.priest)
end

local function station_unit(pair)
  return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil
end

local function surface_name(pair)
  if pair and valid(pair.station) and pair.station.surface then return safe(pair.station.surface.name) end
  return "unknown-surface"
end

local function item_from(v)
  if type(v) == "string" then return v end
  if type(v) ~= "table" then return nil end
  return v.item_name or v.item or v.name or v.output_item or v.wanted_item or v.requested_item or v.kind
end

local function entity_key(entity)
  if not valid(entity) then return nil end
  return safe(entity.name) .. "#" .. safe(entity.unit_number or 0)
end

local function target_key(target)
  if valid(target) then return entity_key(target) end
  if type(target) == "table" and target.x and target.y then
    return string.format("pos:%.1f,%.1f", tonumber(target.x) or 0, tonumber(target.y) or 0)
  end
  return nil
end

local priority_by_kind = {
  validate = 1000,
  combat = 900,
  defense = 900,
  repair = 800,
  consecration = 700,
  sanctify = 700,
  assignment = 610,
  logistics = 600,
  supply = 590,
  scavenge = 580,
  acquisition = 570,
  gather = 570,
  direct_mine = 570,
  emergency_craft = 540,
  emergency = 530,
  return_to_station = 400,
  idle = 0,
}

local function priority_for(kind, explicit)
  if tonumber(explicit) then return tonumber(explicit) end
  return priority_by_kind[lower(kind)] or 100
end

local function normalize_kind(kind)
  local k = lower(kind)
  if k == "" then return "idle" end
  if k:find("combat", 1, true) or k:find("defend", 1, true) or k:find("laser%-fallback") then return "combat" end
  if k:find("repair", 1, true) then return "repair" end
  if k:find("consecr", 1, true) or k:find("sanct", 1, true) then return "consecration" end
  if k:find("assign", 1, true) then return "assignment" end
  if k:find("logistic", 1, true) then return "logistics" end
  if k:find("scavenge", 1, true) then return "scavenge" end
  if k:find("mine", 1, true) or k:find("acqui", 1, true) or k:find("gather", 1, true) or k:find("resource", 1, true) then return "acquisition" end
  if k:find("emergency", 1, true) or k:find("craft", 1, true) then return "emergency_craft" end
  return k
end

local function order_label(order)
  if not order then return "none" end
  return safe(order.key) .. " kind=" .. safe(order.kind) .. " pri=" .. safe(order.priority) .. " item=" .. safe(order.item) .. " status=" .. safe(order.status)
end

local function queue(pair)
  if not pair then return nil end
  pair.order_queue_0469 = pair.order_queue_0469 or {
    version = M.version,
    current = nil,
    pending = {},
    pending_keys = {},
    history = {},
    stats = {},
  }
  local q = pair.order_queue_0469
  q.version = M.version
  q.pending = q.pending or {}
  q.pending_keys = q.pending_keys or {}
  q.history = q.history or {}
  q.stats = q.stats or {}
  -- Rebuild pending key set defensively.  Older live saves may have stale keys
  -- after a reload or a previous failed promotion.
  q.pending_keys = {}
  local new_pending = {}
  for _, order in ipairs(q.pending or {}) do
    if order and order.key and order.status ~= "complete" and order.status ~= "failed" and order.status ~= "cancelled" then
      if not q.pending_keys[order.key] then
        q.pending_keys[order.key] = true
        new_pending[#new_pending + 1] = order
      end
    end
  end
  q.pending = new_pending
  return q
end

local function current_key(pair)
  local q = pair and pair.order_queue_0469
  return q and q.current and q.current.key or nil
end

local function has_order(pair, key)
  if not (pair and key) then return false, nil end
  local q = queue(pair)
  if q.current and q.current.key == key and q.current.status ~= "complete" and q.current.status ~= "failed" and q.current.status ~= "cancelled" then return true, q.current end
  if q.pending_keys[key] then
    for _, order in ipairs(q.pending or {}) do
      if order and order.key == key then return true, order end
    end
    return true, nil
  end
  return false, nil
end

local function make_key(pair, kind, item, target, role)
  local su = safe(station_unit(pair) or "?")
  local surface = surface_name(pair)
  kind = normalize_kind(kind)
  item = item or "none"
  if kind == "combat" then
    return "combat:" .. su .. ":" .. surface .. ":" .. safe(target_key(target) or "threat")
  elseif kind == "repair" or kind == "consecration" then
    return kind .. ":" .. su .. ":" .. surface .. ":" .. safe(target_key(target) or item or "target")
  elseif kind == "assignment" then
    return "assignment:" .. su .. ":" .. surface .. ":" .. safe(role or item or "job")
  elseif kind == "logistics" or kind == "scavenge" or kind == "acquisition" or kind == "gather" or kind == "direct_mine" or kind == "emergency_craft" then
    return "gather:" .. su .. ":" .. surface .. ":" .. safe(item)
  end
  return kind .. ":" .. su .. ":" .. surface .. ":" .. safe(item) .. ":" .. safe(target_key(target) or "none")
end

local function order_from_task(pair, task, source, reason)
  if not valid_pair(pair) then return nil end
  task = task or {}
  local kind = normalize_kind(task.type or task.kind or task.phase or source or pair.mode)
  local item = task.item or task.item_name or task.output_item or task.wanted_item or task.requested_item
  local target = task.target or task.source
  local role = nil
  if task.assignment then
    item = item or task.assignment.item_name
    role = task.assignment.id or task.assignment.role or task.owner_system
  end
  local key = task.order_key_0469 or make_key(pair, kind, item, target, role)
  return {
    key = key,
    kind = kind,
    source = source or "assign_task",
    reason = reason or task.owner_system or "scheduler",
    item = item,
    count = tonumber(task.count or task.amount or 1) or 1,
    target = target,
    target_key = target_key(target),
    priority = priority_for(kind, task.priority),
    task = task,
    role = role,
    station_unit = station_unit(pair),
    surface = surface_name(pair),
    created_tick = now(),
    updated_tick = now(),
    expires_tick = now() + (tonumber(task.timeout_ticks) or M.default_timeout_ticks),
    status = "queued",
  }
end

local function order_from_pair_surface(pair, source)
  if not valid_pair(pair) then return nil end
  if pair.active_task or pair.active_task_0285 then
    return order_from_task(pair, pair.active_task or pair.active_task_0285, source or "adopt-active", "surface-adopt")
  end
  if pair.scavenge then
    local sc = pair.scavenge
    local item = item_from(sc)
    local o = order_from_task(pair, { type = "scavenge", item = item, count = sc.count or 1, source = sc.source, target = sc.source }, source or "maybe_supply_scavenge", "surface-adopt")
    o.supply_kind = item
    o.supply_target = sc.source
    return o
  end
  if pair.direct_acquisition_task_0336 then
    local t = pair.direct_acquisition_task_0336
    local cur = t.current or t
    local item = item_from(cur) or item_from(t)
    local o = order_from_task(pair, { type = "acquisition", item = item, count = t.count or t.required_count or 1, target = cur.entity, source = cur.entity }, source or "doctrine_handle_no_source", "surface-adopt")
    o.wanted_item = item
    return o
  end
  if pair.emergency_craft then
    local t = pair.emergency_craft
    local cur = t.current or t
    local item = item_from(cur) or item_from(t)
    local o = order_from_task(pair, { type = cur.entity and "acquisition" or "emergency_craft", item = item, count = t.count or t.required_count or 1, target = cur.entity, source = cur.entity }, source or "doctrine_handle_no_source", "surface-adopt")
    o.wanted_item = item
    return o
  end
  if pair.logistic_requested_item then
    return order_from_task(pair, { type = "logistics", item = pair.logistic_requested_item, count = pair.logistic_requested_count or 1 }, source or "adopt-logistics", "surface-adopt")
  end
  return nil
end

local function remember_history(q, order, status, why)
  q.history = q.history or {}
  q.history[#q.history + 1] = {
    key = order and order.key or "nil",
    kind = order and order.kind or "nil",
    item = order and order.item or nil,
    status = status,
    reason = why,
    tick = now(),
  }
  while #q.history > 200 do table.remove(q.history, 1) end
end

local function put_pending_front(q, order)
  if not (q and order and order.key) then return false end
  if q.pending_keys[order.key] then return false end
  order.status = "paused"
  order.paused_tick = now()
  q.pending_keys[order.key] = true
  table.insert(q.pending, 1, order)
  return true
end

local function put_pending(q, order)
  if not (q and order and order.key) then return false end
  if q.pending_keys[order.key] then return false end
  if #q.pending >= M.queue_limit then
    q.stats.queue_full = (q.stats.queue_full or 0) + 1
    root_stat("queue_full")
    return false
  end
  order.status = "queued"
  q.pending_keys[order.key] = true
  q.pending[#q.pending + 1] = order
  q.stats.enqueued = (q.stats.enqueued or 0) + 1
  root_stat("enqueued")
  return true
end

local function mark_duplicate(pair, q, order, existing)
  q.stats.duplicates_blocked = (q.stats.duplicates_blocked or 0) + 1
  q.last_duplicate_blocked = {
    tick = now(),
    key = order and order.key,
    kind = order and order.kind,
    item = order and order.item,
    existing_status = existing and existing.status or "unknown",
  }
  root_stat("duplicates_blocked")
  if existing and order and tonumber(order.count) and tonumber(existing.count) then
    existing.count = math.max(tonumber(existing.count) or 1, tonumber(order.count) or 1)
    existing.updated_tick = now()
  end
end

function M.submit(pair, order, opts)
  opts = opts or {}
  if not enabled() then return true, "disabled" end
  if not valid_pair(pair) then return true, "invalid-pair" end
  if not order then return true, "nil-order" end
  local q = queue(pair)
  order.priority = tonumber(order.priority) or priority_for(order.kind)
  order.kind = normalize_kind(order.kind)
  order.key = order.key or make_key(pair, order.kind, order.item, order.target, order.role)
  order.updated_tick = now()
  order.expires_tick = order.expires_tick or now() + M.default_timeout_ticks

  local exists, existing = has_order(pair, order.key)
  if exists then
    mark_duplicate(pair, q, order, existing)
    return false, "duplicate", existing
  end

  if not q.current then
    order.status = "active"
    order.activated_tick = now()
    q.current = order
    pair.active_order_0469 = order
    q.stats.started = (q.stats.started or 0) + 1
    root_stat("started")
    return true, "active"
  end

  local current = q.current
  local curpri = tonumber(current.priority) or 0
  if order.priority > curpri then
    -- Combat/repair/sanctification can interrupt an acquisition writ, but the
    -- acquisition writ is paused and placed back at the front of the queue.
    current.preempted_by = order.key
    current.status = "paused"
    current.paused_tick = now()
    put_pending_front(q, current)
    order.status = "active"
    order.activated_tick = now()
    q.current = order
    pair.active_order_0469 = order
    q.stats.preemptions = (q.stats.preemptions or 0) + 1
    root_stat("preemptions")
    return true, "preempt"
  end

  put_pending(q, order)
  pair.last_order_queued_0469 = { tick = now(), key = order.key, behind = current.key }
  return false, "queued", q.current
end

local function active_task_matches(pair, order)
  if not (pair and order) then return false end
  local task = pair.active_task or pair.active_task_0285
  if type(task) == "table" then
    local active_order = order_from_task(pair, task, "compare", "compare")
    if active_order and active_order.key == order.key then return true end
    if normalize_kind(task.type or task.kind) == order.kind and (item_from(task) == order.item or order.kind == "combat" or order.kind == "repair" or order.kind == "consecration") then return true end
  end
  return false
end

local function lower_surfaces_active(pair, order)
  if not (pair and order) then return false end
  local k = order.kind
  if k == "combat" then
    local target = pair.combat_target or pair.target
    return valid(target) and (lower(pair.mode):find("combat", 1, true) or lower(pair.mode):find("defend", 1, true) or lower(pair.mode):find("laser%-fallback"))
  end
  if k == "repair" then return lower(pair.mode):find("repair", 1, true) ~= nil end
  if k == "consecration" then return lower(pair.mode):find("consecr", 1, true) ~= nil or lower(pair.mode):find("sanct", 1, true) ~= nil end
  if k == "assignment" then return pair.assignment_0252 ~= nil or pair.emergency_assist_job_0187 ~= nil end
  if k == "logistics" then return pair.logistic_requested_item ~= nil end
  if k == "scavenge" then return pair.scavenge ~= nil or pair.inventory_scan ~= nil end
  if k == "acquisition" or k == "direct_mine" or k == "gather" or k == "emergency_craft" then return pair.emergency_craft ~= nil or pair.direct_acquisition_task_0336 ~= nil or lower(pair.mode):find("gather", 1, true) ~= nil or lower(pair.mode):find("mine", 1, true) ~= nil end
  return active_task_matches(pair, order)
end

local function order_should_finish(pair, order)
  if not order then return true, "nil-order" end
  if order.expires_tick and now() > order.expires_tick then return true, "expired" end
  if not valid_pair(pair) then return true, "invalid-pair" end
  if order.target and type(order.target) == "table" and order.target.valid == false then return true, "target-invalid" end

  local mode = lower(pair.mode)
  if order.kind == "combat" then
    local Mutex = rawget(_G, "TECH_PRIESTS_BEHAVIOR_MUTEX_0466")
    if Mutex and Mutex.combat_active then
      local ok, active = pcall(Mutex.combat_active, pair)
      if ok and active then return false end
    end
    if mode:find("combat", 1, true) or mode:find("defend", 1, true) or mode:find("laser%-fallback") then return false end
    return true, "combat-cleared"
  end

  if lower_surfaces_active(pair, order) or active_task_matches(pair, order) then
    return false
  end

  -- If a lower-priority order was preempted and the old legacy state was cleared,
  -- do not immediately call it complete.  Keep it resumable for a short lease.
  if order.status == "paused" and now() < (order.paused_tick or 0) + M.lease_ticks then return false end

  if mode == "idle" or mode == "returning" or mode == "returning-to-station" or mode == "scheduler-0277" or mode == "" then
    return true, "legacy-surface-cleared"
  end
  return false
end

local function pop_next(q)
  if not q then return nil end
  while #q.pending > 0 do
    local order = table.remove(q.pending, 1)
    if order and order.key then q.pending_keys[order.key] = nil end
    if order and order.key and order.status ~= "complete" and order.status ~= "failed" and order.status ~= "cancelled" and (not order.expires_tick or now() <= order.expires_tick) then
      return order
    end
  end
  return nil
end

local function call_original_assign(pair, order)
  if not (original_assign_task and pair and order and order.task) then return false end
  local ok, did = pcall(original_assign_task, pair, order.task, "order-queue-0469-promote")
  return ok and did == true
end

local function activate_callback(pair, order)
  if not (pair and order) then return false end
  order.status = "active"
  order.activated_tick = now()
  pair.active_order_0469 = order

  if order.source == "assign_task" or order.source == "adopt-active" then
    return call_original_assign(pair, order)
  elseif order.source == "emergency_acquire" and original_emergency_acquire then
    local ok, did = pcall(original_emergency_acquire, pair, order.item, order.op, order.count or 1, order.depth or 0)
    return ok and did == true
  elseif order.source == "maybe_supply_scavenge" and original_maybe_supply_scavenge then
    local ok, did = pcall(original_maybe_supply_scavenge, pair, order.supply_kind or order.item, order.supply_target)
    return ok and did == true
  elseif order.source == "start_scavenge_scan" and original_start_scavenge_scan then
    local ok, did = pcall(original_start_scavenge_scan, pair, order.request or { item_name = order.item })
    return ok and did ~= false
  elseif order.source == "doctrine_start_direct" and original_doctrine_start_direct then
    local ok, did = pcall(original_doctrine_start_direct, pair, order.doctrine_source, order.wanted_item or order.item, order.reason or "order-queue-promote")
    return ok and did == true
  elseif order.source == "doctrine_handle_no_source" and original_doctrine_handle_no_source then
    local ok, did = pcall(original_doctrine_handle_no_source, pair, order.wanted_item or order.item, order.recipe, order.reason or "order-queue-promote")
    return ok and did == true
  elseif order.task then
    return call_original_assign(pair, order)
  end
  return false
end

function M.reactivate_current(pair, reason)
  if not valid_pair(pair) then return false, "invalid-pair", nil end
  local q = queue(pair)
  local order = q and q.current or nil
  if not order then return false, "no-current", nil end
  order.reactivate_attempts_0477 = (tonumber(order.reactivate_attempts_0477) or 0) + 1
  order.last_reactivate_tick_0477 = now()
  order.last_reactivate_reason_0477 = reason or "execution-watchdog-0477"
  remember_history(q, order, "reactivated", order.last_reactivate_reason_0477)
  local ok = activate_callback(pair, order)
  order.last_activate_result = ok and "ok" or "no-direct-callback"
  order.last_activate_tick = now()
  pair.last_order_reactivate_0477 = { tick = now(), key = order.key, item = order.item, result = order.last_activate_result, reason = order.last_reactivate_reason_0477 }
  return ok, order.last_activate_result, order
end

local function promote(pair, q, reason)
  local order = pop_next(q)
  if not order then
    q.current = nil
    pair.active_order_0469 = nil
    return false
  end
  q.current = order
  pair.active_order_0469 = order
  remember_history(q, order, "promoted", reason)
  root_stat("promotions")
  q.stats.promotions = (q.stats.promotions or 0) + 1
  local ok = activate_callback(pair, order)
  order.last_activate_result = ok and "ok" or "no-direct-callback"
  order.last_activate_tick = now()
  return true
end

function M.fail_current(pair, reason)
  if not valid_pair(pair) then return false, "invalid-pair" end
  local q = queue(pair)
  if not (q and q.current) then return false, "no-current" end
  q.current.status = "failed"
  q.current.finished_tick = now()
  q.current.finish_reason = reason or "failed-by-authority"
  remember_history(q, q.current, "failed", q.current.finish_reason)
  root_stat("failed_by_authority")
  q.current = nil
  pair.active_order_0469 = nil
  promote(pair, q, reason or "failed-by-authority")
  return true, "failed"
end

function M.tick_pair(pair, reason)
  if not enabled() or not valid_pair(pair) then return false end
  local q = queue(pair)
  if not q.current then
    local adopted = order_from_pair_surface(pair, "adopt-surface")
    if adopted then
      adopted.status = "active"
      adopted.activated_tick = now()
      q.current = adopted
      pair.active_order_0469 = adopted
      remember_history(q, adopted, "adopted", reason or "tick")
      root_stat("adopted")
      return true
    end
    promote(pair, q, "empty-current")
    return false
  end

  local done, why = order_should_finish(pair, q.current)
  if done then
    q.current.status = why == "expired" and "failed" or "complete"
    q.current.finished_tick = now()
    q.current.finish_reason = why
    remember_history(q, q.current, q.current.status, why)
    root_stat(q.current.status == "failed" and "expired" or "completed")
    q.stats.completed = (q.stats.completed or 0) + 1
    q.current = nil
    pair.active_order_0469 = nil
    promote(pair, q, why)
    return true
  end
  q.current.last_seen_tick = now()
  return false
end

local function selected_pair(player)
  if not (player and player.valid) then return nil end
  if _G.selected_pair_for_player then local ok, pair = pcall(_G.selected_pair_for_player, player); if ok and pair then return pair end end
  local selected = player.selected
  if selected and selected.valid then
    if _G.find_pair_for_entity then local ok, pair = pcall(_G.find_pair_for_entity, selected); if ok and pair then return pair end end
    if storage and storage.tech_priests then
      local s = storage.tech_priests.pairs_by_station and storage.tech_priests.pairs_by_station[selected.unit_number]
      if s then return s end
      local p = storage.tech_priests.pairs_by_priest and storage.tech_priests.pairs_by_priest[selected.unit_number]
      if p then return p end
    end
  end
  return nil
end

local function describe(pair)
  local q = pair and queue(pair) or nil
  local lines = {}
  if not q then
    lines[#lines + 1] = "no queue"
    return lines
  end
  lines[#lines + 1] = "current=" .. order_label(q.current)
  lines[#lines + 1] = "pending=" .. safe(#(q.pending or {})) .. " duplicate_blocks=" .. safe(q.stats.duplicates_blocked or 0) .. " preemptions=" .. safe(q.stats.preemptions or 0) .. " promotions=" .. safe(q.stats.promotions or 0)
  for i, order in ipairs(q.pending or {}) do
    lines[#lines + 1] = "pending[" .. i .. "]=" .. order_label(order)
  end
  if q.last_duplicate_blocked then
    lines[#lines + 1] = "last_duplicate=" .. safe(q.last_duplicate_blocked.key) .. " existing=" .. safe(q.last_duplicate_blocked.existing_status) .. " tick=" .. safe(q.last_duplicate_blocked.tick)
  end
  return lines
end

local function write_diag_line(text)
  local line = "[Tech-Priests " .. M.version .. "][tick " .. safe(now()) .. "] ORDER-QUEUE-0469 " .. tostring(text or "") .. "\n"
  if tech_priests_0264_log then
    local ok = pcall(function() tech_priests_0264_log("ORDER-QUEUE-0469 " .. tostring(text or ""), true) end)
    if ok then return true end
  end
  if helpers then
    local ok_get, writer = pcall(function() return helpers.write_file end)
    if ok_get and type(writer) == "function" then
      local ok_write = pcall(function() writer(M.diag_file, line, true) end)
      if ok_write then return true end
    end
  end
  if log then pcall(function() log(line) end) end
  return false
end

function M.write_all_queues(reason)
  write_diag_line("BEGIN reason=" .. safe(reason or "manual"))
  for key, pair in pairs(pair_map()) do
    if valid_pair(pair) then
      write_diag_line("pair[" .. safe(key) .. "] station=" .. safe(pair.station.name) .. "#" .. safe(pair.station.unit_number) .. " priest=" .. safe(pair.priest.name) .. "#" .. safe(pair.priest.unit_number) .. " mode=" .. safe(pair.mode))
      for _, line in ipairs(describe(pair)) do write_diag_line("pair[" .. safe(key) .. "] " .. line) end
    end
  end
  write_diag_line("END")
end


local function fail_current_if_order(pair, order, why)
  local q = pair and pair.order_queue_0469
  if q and q.current and order and q.current.key == order.key then
    q.current.status = "failed"
    q.current.finished_tick = now()
    q.current.finish_reason = why or "activation-failed"
    remember_history(q, q.current, "failed", why or "activation-failed")
    q.current = nil
    pair.active_order_0469 = nil
    root_stat("activation_failed")
  end
end

function M.wrap_assign_task()
  if type(rawget(_G, "tech_priests_0285_assign_task")) ~= "function" or rawget(_G, "TECH_PRIESTS_0469_PRE_ASSIGN_TASK") then return end
  original_assign_task = rawget(_G, "tech_priests_0285_assign_task")
  _G.TECH_PRIESTS_0469_PRE_ASSIGN_TASK = original_assign_task
  _G.tech_priests_0285_assign_task = function(pair, task, reason)
    if not enabled() or not valid_pair(pair) then return original_assign_task(pair, task, reason) end
    local order = order_from_task(pair, task or {}, "assign_task", reason or "assign-task")
    local allowed, state = M.submit(pair, order)
    if state == "duplicate" or state == "queued" then return true end
    if allowed then
      local did = original_assign_task(pair, task, reason)
      if not did then fail_current_if_order(pair, order, "assign-task-rejected") end
      return did
    end
    return true
  end
end

function M.wrap_cancel_task()
  if type(rawget(_G, "tech_priests_0285_cancel_task")) ~= "function" or rawget(_G, "TECH_PRIESTS_0469_PRE_CANCEL_TASK") then return end
  original_cancel_task = rawget(_G, "tech_priests_0285_cancel_task")
  _G.TECH_PRIESTS_0469_PRE_CANCEL_TASK = original_cancel_task
  _G.tech_priests_0285_cancel_task = function(pair, reason)
    local q = pair and pair.order_queue_0469
    if enabled() and q and q.current then
      q.current.status = "cancelled"
      q.current.finished_tick = now()
      q.current.finish_reason = reason or "cancel-task"
      remember_history(q, q.current, "cancelled", reason or "cancel-task")
      q.current = nil
      pair.active_order_0469 = nil
    end
    return original_cancel_task(pair, reason)
  end
end

function M.wrap_emergency_acquire()
  if type(rawget(_G, "tech_priests_emergency_operation_acquire_item_0185")) ~= "function" or rawget(_G, "TECH_PRIESTS_0469_PRE_EMERGENCY_ACQUIRE") then return end
  original_emergency_acquire = rawget(_G, "tech_priests_emergency_operation_acquire_item_0185")
  _G.TECH_PRIESTS_0469_PRE_EMERGENCY_ACQUIRE = original_emergency_acquire
  _G.tech_priests_emergency_operation_acquire_item_0185 = function(pair, item_name, op, count, depth)
    if not enabled() or not valid_pair(pair) or not item_name then return original_emergency_acquire(pair, item_name, op, count, depth) end
    local order = order_from_task(pair, { type = "logistics", item = item_name, count = count or 1, priority = priority_by_kind.logistics }, "emergency_acquire", "emergency-acquire")
    order.op = op; order.depth = depth or 0
    local allowed, state = M.submit(pair, order)
    if state == "duplicate" or state == "queued" then return true end
    local did = original_emergency_acquire(pair, item_name, op, count, depth)
    if not did then fail_current_if_order(pair, order, "emergency-acquire-rejected") end
    return did
  end
end

function M.wrap_supply_scavenge()
  if type(rawget(_G, "maybe_start_supply_scavenge")) == "function" and not rawget(_G, "TECH_PRIESTS_0469_PRE_MAYBE_SUPPLY_SCAVENGE") then
    original_maybe_supply_scavenge = rawget(_G, "maybe_start_supply_scavenge")
    _G.TECH_PRIESTS_0469_PRE_MAYBE_SUPPLY_SCAVENGE = original_maybe_supply_scavenge
    _G.maybe_start_supply_scavenge = function(pair, kind, target)
      local item = pair and pair.active_supply_request and item_from(pair.active_supply_request) or kind
      if item == "repair" then item = "repair-pack" end
      if not enabled() or not valid_pair(pair) or not item then return original_maybe_supply_scavenge(pair, kind, target) end
      local order = order_from_task(pair, { type = "scavenge", item = item, count = 1, source = target, target = target, priority = priority_by_kind.scavenge }, "maybe_supply_scavenge", "maybe-supply-scavenge")
      order.supply_kind = kind; order.supply_target = target
      local allowed, state = M.submit(pair, order)
      if state == "duplicate" or state == "queued" then return true end
      local did = original_maybe_supply_scavenge(pair, kind, target)
      if not did then fail_current_if_order(pair, order, "supply-scavenge-rejected") end
      return did
    end
  end

  if type(rawget(_G, "start_logistic_scavenge_inventory_scan")) == "function" and not rawget(_G, "TECH_PRIESTS_0469_PRE_START_SCAVENGE_SCAN") then
    original_start_scavenge_scan = rawget(_G, "start_logistic_scavenge_inventory_scan")
    _G.TECH_PRIESTS_0469_PRE_START_SCAVENGE_SCAN = original_start_scavenge_scan
    _G.start_logistic_scavenge_inventory_scan = function(pair, request)
      local item = item_from(request)
      if not enabled() or not valid_pair(pair) or not item then return original_start_scavenge_scan(pair, request) end
      local order = order_from_task(pair, { type = "scavenge", item = item, count = request and request.count or 1, priority = priority_by_kind.scavenge }, "start_scavenge_scan", "scavenge-scan")
      order.request = request
      local allowed, state = M.submit(pair, order)
      if state == "duplicate" or state == "queued" then return true end
      local did = original_start_scavenge_scan(pair, request)
      if did == false then fail_current_if_order(pair, order, "scavenge-scan-rejected") end
      return did
    end
  end
end

function M.wrap_doctrine()
  pcall(function() Doctrine = require("scripts.core.resource_doctrine") end)
  if not Doctrine then return end
  if type(Doctrine.start_direct_task) == "function" and not original_doctrine_start_direct then
    original_doctrine_start_direct = Doctrine.start_direct_task
    Doctrine.start_direct_task = function(pair, source, wanted, reason)
      local item = source and (source.output_item or source.item_name) or wanted
      if not enabled() or not valid_pair(pair) or not item then return original_doctrine_start_direct(pair, source, wanted, reason) end
      local order = order_from_task(pair, { type = "acquisition", item = item, count = source and source.count or 1, target = source and source.entity, source = source and source.entity, priority = priority_by_kind.acquisition }, "doctrine_start_direct", reason or "doctrine-start-direct")
      order.doctrine_source = source; order.wanted_item = wanted
      local allowed, state = M.submit(pair, order)
      if state == "duplicate" or state == "queued" then return true end
      local did = original_doctrine_start_direct(pair, source, wanted, reason)
      if not did then fail_current_if_order(pair, order, "doctrine-direct-rejected") end
      return did
    end
  end
  if type(Doctrine.handle_no_source) == "function" and not original_doctrine_handle_no_source then
    original_doctrine_handle_no_source = Doctrine.handle_no_source
    Doctrine.handle_no_source = function(pair, wanted, recipe, reason)
      if not enabled() or not valid_pair(pair) or not wanted then return original_doctrine_handle_no_source(pair, wanted, recipe, reason) end
      local order = order_from_task(pair, { type = "logistics", item = wanted, count = 1, priority = priority_by_kind.logistics }, "doctrine_handle_no_source", reason or "doctrine-handle-no-source")
      order.wanted_item = wanted; order.recipe = recipe
      local allowed, state = M.submit(pair, order)
      if state == "duplicate" or state == "queued" then return true end
      local did = original_doctrine_handle_no_source(pair, wanted, recipe, reason)
      if not did then fail_current_if_order(pair, order, "doctrine-no-source-rejected") end
      return did
    end
  end
end

function M.wrap_diagnostics()
  local diag = rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
  if not (diag and type(diag.pair_dump_lines) == "function") or rawget(_G, "TECH_PRIESTS_0469_PRE_PAIR_DUMP_LINES") then return end
  _G.TECH_PRIESTS_0469_PRE_PAIR_DUMP_LINES = diag.pair_dump_lines
  diag.pair_dump_lines = function()
    local lines = _G.TECH_PRIESTS_0469_PRE_PAIR_DUMP_LINES()
    lines[#lines + 1] = "ORDER-QUEUE-0469 BEGIN enabled=" .. safe(enabled())
    for key, pair in pairs(pair_map()) do
      if valid_pair(pair) then
        local q = queue(pair)
        lines[#lines + 1] = "orderq[" .. safe(key) .. "] current=" .. order_label(q.current) .. " pending=" .. safe(#(q.pending or {})) .. " duplicates=" .. safe(q.stats.duplicates_blocked or 0) .. " preemptions=" .. safe(q.stats.preemptions or 0)
        for i, order in ipairs(q.pending or {}) do
          lines[#lines + 1] = "orderq[" .. safe(key) .. "].pending[" .. i .. "]=" .. order_label(order)
        end
      end
    end
    lines[#lines + 1] = "ORDER-QUEUE-0469 END"
    return lines
  end
end

function M.install_commands()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-order-queue-0469") end end)
  pcall(function()
    commands.add_command("tp-order-queue-0469", "Tech Priests 0.1.469: per-priest order queue. Usage: status|all|write|on|off|clear", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      local param = lower(event and event.parameter or "status")
      local root = ensure_root()
      if param == "on" or param == "enable" then root.enabled = true end
      if param == "off" or param == "disable" then root.enabled = false end
      if param == "write" or param == "dump" then M.write_all_queues("manual-command") end
      local pair = selected_pair(player)
      if param == "clear" and pair then pair.order_queue_0469 = nil end
      if player and player.valid then
        player.print("[tp-order-queue-0469] enabled=" .. safe(enabled()) .. " started=" .. safe(root.stats.started or 0) .. " queued=" .. safe(root.stats.enqueued or 0) .. " dupes=" .. safe(root.stats.duplicates_blocked or 0) .. " preempts=" .. safe(root.stats.preemptions or 0))
        if param == "all" then
          for key, p in pairs(pair_map()) do
            player.print("[tp-order-queue-0469] pair[" .. safe(key) .. "] mode=" .. safe(p and p.mode))
            for _, line in ipairs(describe(p)) do player.print("[tp-order-queue-0469] " .. line) end
          end
        elseif pair then
          for _, line in ipairs(describe(pair)) do player.print("[tp-order-queue-0469] " .. line) end
        else
          player.print("[tp-order-queue-0469] select a Cogitator Station or Tech-Priest for pair-specific status.")
        end
      end
    end)
  end)
end

function M.tick_all(reason)
  if not enabled() then return end
  for _, pair in pairs(pair_map()) do
    if valid_pair(pair) then pcall(function() M.tick_pair(pair, reason or "periodic") end) end
  end
end

function M.install()
  ensure_root()
  M.wrap_assign_task()
  M.wrap_cancel_task()
  M.wrap_emergency_acquire()
  M.wrap_supply_scavenge()
  M.wrap_doctrine()
  M.wrap_diagnostics()
  M.install_commands()
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service) == "function" then
    broker.register_service({
      name = "order_queue_0469",
      category = "scheduler",
      interval = M.tick_interval,
      priority = 30,
      budget = 16,
      note = "per-pair order queue tick routed through central runtime broker",
      fn = function(event, budget)
        M.tick_all("broker-tick")
        return true, "tick-all"
      end
    })
  elseif TechPriestsRuntimeEventRegistry and TechPriestsRuntimeEventRegistry.on_nth_tick then
    TechPriestsRuntimeEventRegistry.on_nth_tick(M.tick_interval, function() M.tick_all("registry-tick") end, { owner = "order_queue_0469", category = "scheduler" })
  elseif script and script.on_nth_tick then
    script.on_nth_tick(M.tick_interval, function() M.tick_all("nth-tick") end)
  end
  _G.TECH_PRIESTS_ORDER_QUEUE_0469 = M
  _G.tech_priests_0469_submit_order = M.submit
  _G.tech_priests_0469_pair_queue_status = describe
  if log then log("[Tech-Priests 0.1.469/0.1.600] per-priest order queue installed; periodic service registered through runtime broker when available") end
  return true
end

return M
