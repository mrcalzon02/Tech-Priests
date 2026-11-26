-- One deterministic planning executor per force, sharing one broker budget.
-- Callers submit/read jobs; only the broker advances them. All continuations
-- are ordinary saved tables. Handlers are registered again when Lua reloads.
local M = { storage_key = "force_planning_queue_1507", handlers = {},
  max_per_force = 64, max_jobs = 256, max_dependencies = 257,
  budget = 16, result_ttl = 3600 }
-- A saturated ordinary queue must still be able to build the indices its
-- existing jobs need. Only these two bounded coordinators use reserved slots;
-- they share the same executor/work budget and discard their completed jobs.
local DEPENDENCIES = { ["planning-items"] = true, ["planning-recipes"] = true }

local function tick() return game and game.tick or 0 end
local function root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key]
  if not r then
    r = { forces = {}, jobs = {}, next_id = 1, total = 0, stats = {} }
    storage.tech_priests[M.storage_key] = r
  end
  return r
end
M.root = root
local function metric(r, name, n) r.stats[name] = (r.stats[name] or 0) + (n or 1) end
local function key_for(kind, key) return tostring(kind) .. "\0" .. tostring(key) end

local function activate(r, f)
  if f.active then return end
  f.active = true
  f.prev_force, f.next_force = r.last_force, nil
  if r.last_force then r.forces[r.last_force].next_force = f.index
  else r.first_force = f.index end
  r.last_force = f.index
  if not r.next_force then r.next_force = f.index end
end
local function deactivate(r, f)
  if not f.active then return end
  local before, after = f.prev_force, f.next_force
  if before then r.forces[before].next_force = after else r.first_force = after end
  if after then r.forces[after].prev_force = before else r.last_force = before end
  if r.next_force == f.index then r.next_force = after or r.first_force end
  f.active, f.prev_force, f.next_force = nil, nil, nil
end
local function append(r, f, j)
  j.prev, j.next, j.queued = f.tail, nil, true
  if f.tail then r.jobs[f.tail].next = j.id else f.head = j.id end
  f.tail = j.id
  activate(r, f)
end
local function detach(r, f, j)
  if not j.queued then return end
  if j.prev then r.jobs[j.prev].next = j.next else f.head = j.next end
  if j.next then r.jobs[j.next].prev = j.prev else f.tail = j.prev end
  j.prev, j.next, j.queued = nil, nil, nil
  if not f.head then deactivate(r, f) end
end
local function terminal_append(r, j)
  j.terminal_prev, j.terminal_next, j.terminal = r.terminal_tail, nil, true
  if r.terminal_tail then r.jobs[r.terminal_tail].terminal_next = j.id
  else r.terminal_head = j.id end
  r.terminal_tail = j.id
end
local function terminal_detach(r, j)
  if not j.terminal then return end
  if j.terminal_prev then r.jobs[j.terminal_prev].terminal_next = j.terminal_next
  else r.terminal_head = j.terminal_next end
  if j.terminal_next then r.jobs[j.terminal_next].terminal_prev = j.terminal_prev
  else r.terminal_tail = j.terminal_prev end
  j.terminal_prev, j.terminal_next, j.terminal = nil, nil, nil
end

function M.register(kind, handler)
  assert(type(kind) == "string" and type(handler) == "function", "planner handler required")
  M.handlers[kind] = handler
end
function M.peek(force_index, kind, key)
  local r = root()
  local f = r.forces[force_index]
  local id = f and f.keys[key_for(kind, key)]
  local j = id and r.jobs[id]
  return j, j and j.status or "missing"
end
local function submit(force_index, kind, key, payload, dependency)
  assert(type(force_index) == "number", "numeric force index required")
  assert(type(kind) == "string" and key ~= nil, "planner kind/key required")
  local r, identity = root(), key_for(kind, key)
  local f = r.forces[force_index]
  local j = f and f.keys[identity] and r.jobs[f.keys[identity]]
  if j then return j, j.status end
  local full = dependency and ((r.dependencies or 0) >= M.max_dependencies
    or (f and (f.dependencies or 0) >= 2))
    or not dependency and (r.total - (r.dependencies or 0) >= M.max_jobs
    or (f and f.count - (f.dependencies or 0) >= M.max_per_force))
  if full then
    metric(r, "backpressure")
    return nil, "queue-full"
  end
  if not f then
    f = { index = force_index, keys = {}, count = 0 }
    r.forces[force_index] = f
  end
  j = { id = r.next_id, force_index = force_index, kind = kind, key = key,
    payload = payload or {}, state = {}, status = "pending", created_tick = tick(),
    dependency = dependency or nil }
  r.next_id, r.total, f.count = r.next_id + 1, r.total + 1, f.count + 1
  if dependency then
    r.dependencies, f.dependencies = (r.dependencies or 0) + 1, (f.dependencies or 0) + 1
  end
  r.jobs[j.id], f.keys[identity] = j, j.id
  append(r, f, j)
  metric(r, "submitted")
  return j, "pending"
end
function M.submit(force_index, kind, key, payload)
  return submit(force_index, kind, key, payload, false)
end
function M.submit_dependency(force_index, kind, key, payload)
  assert(DEPENDENCIES[kind], "only shared metadata may use dependency capacity")
  return submit(force_index, kind, key, payload, true)
end
function M.forget(force_index, kind, key)
  local r = root()
  local f = r.forces[force_index]
  local identity = key_for(kind, key)
  local j = f and f.keys[identity] and r.jobs[f.keys[identity]]
  if not j then return false end
  detach(r, f, j)
  terminal_detach(r, j)
  f.keys[identity], r.jobs[j.id] = nil, nil
  f.count, r.total = f.count - 1, r.total - 1
  if j.dependency then
    r.dependencies, f.dependencies = r.dependencies - 1, f.dependencies - 1
  end
  if f.count == 0 then r.forces[force_index] = nil end
  return true
end
function M.retry(job)
  local r = root()
  local j = job and r.jobs[job.id]
  if j ~= job then return false end
  if j.status == "pending" then return true end
  terminal_detach(r, j)
  j.status, j.result, j.error, j.completed_tick = "pending", nil, nil, nil
  append(r, r.forces[j.force_index], j)
  return true
end
-- Shared hard caps include rejected work and failed final live checks. These
-- are tick counters, never an elapsed-time decision or a per-caller budget.
function M.claim_tick(kind, limit)
  local r, at = root(), tick()
  if r.token_tick ~= at then r.token_tick, r.tokens = at, {} end
  local used = r.tokens[kind] or 0
  if used >= limit then return false end
  r.tokens[kind] = used + 1
  return true
end

function M.pulse(event, offered)
  local r, at = root(), event and event.tick or tick()
  if r.pulse_tick == at then return { processed = 0, detail = "already-serviced" } end
  r.pulse_tick = at
  local cap = math.min(M.budget, math.max(0, math.floor(tonumber(offered) or M.budget)))
  local used, acted, failures = 0, 0, 0
  -- Reclaim one expired result at a time; no unbounded queue maintenance sweep.
  while used < cap do
    local terminal = r.terminal_head and r.jobs[r.terminal_head]
    if terminal and at - terminal.completed_tick >= M.result_ttl then
      M.forget(terminal.force_index, terminal.kind, terminal.key)
      used = used + 1
      metric(r, "expired")
    else break end
  end
  while used < cap and r.first_force do
    local f = r.forces[r.next_force or r.first_force]
    r.next_force = f.next_force or r.first_force
    local j = r.jobs[f.head]
    detach(r, f, j)
    local handler = M.handlers[j.kind]
    -- One invocation is one charged attempt, even for rejected/invalid/empty
    -- work. Handlers may advance only one bounded operation per invocation.
    local ok, result = true, nil
    if handler then ok, result = pcall(handler, j, 1) end
    used = used + 1
    j.last_step_tick, j.steps = at, (j.steps or 0) + 1
    if not ok then
      result = { done = true, result = { error = tostring(result) } }
      j.error = result.result.error
      failures = failures + 1
    elseif type(result) ~= "table" then
      result = { waiting = true }
    end
    if (tonumber(result.processed) or 0) > 1 then
      -- Record an integration contract failure, never silently advertise a
      -- compliant budget after a handler has overrun it.
      j.error = "planner handler exceeded one-work allowance"
      metric(r, "budget_contract_errors")
      failures = failures + 1
    end
    acted = acted + math.max(0, tonumber(result.acted) or 0)
    failures = failures + math.max(0, tonumber(result.failed) or 0)
    if result.done then
      j.status, j.result, j.completed_tick = "ready", result.result, at
      metric(r, "completed")
      if j.dependency and not j.error then M.forget(j.force_index, j.kind, j.key)
      else terminal_append(r, j) end
    else
      append(r, f, j)
    end
  end
  metric(r, "work", used)
  metric(r, "failures", failures)
  r.last_work, r.last_acted = used, acted
  return { processed = used, acted = acted, failed = failures,
    exhausted = used == cap and r.first_force ~= nil,
    sleeping = r.first_force == nil, detail = "force planner bounded continuation" }
end
function M.install()
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
    or require("scripts.core.runtime_tick_broker")
  if M.broker == broker and M.service then return true end
  local service = broker.register_service({ name = "force_planning_queue_1507",
    category = "planning", priority = 58, interval = broker.base_interval or 5,
    budget = M.budget, dynamic_budget = false,
    fn = M.pulse, note = "shared force planner; one charged step per job visit" })
  if not service then return false end
  M.broker, M.service = broker, service
  _G.TechPriestsForcePlanningQueue1507 = M
  return true
end
return M
