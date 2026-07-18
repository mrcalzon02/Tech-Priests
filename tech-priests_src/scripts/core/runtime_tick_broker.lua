-- scripts/core/runtime_tick_broker.lua
-- Tech Priests 0.1.674-dev base-state recovery.
-- Central budgeted broker with strict service-result normalization.

local M = {
  version = "0.1.674-dev",
  storage_key = "runtime_tick_broker_0600",
  base_interval = 5,
  services = {},
  installed = false,
}

local function now() return game and game.tick or 0 end
local function safe(v)
  if v == nil then return "nil" end
  local ok, s = pcall(tostring, v)
  return ok and s or "?"
end
local function count_table(t)
  local n = 0
  if type(t) == "table" then for _ in pairs(t) do n = n + 1 end end
  return n
end
local function window_key(tick) return math.floor((tonumber(tick) or now()) / 3600) end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    stats = {},
    service_stats = {},
    recent = {},
    windows = {},
    external_stats = {},
    profiler = { enabled = false, routes = {}, recent = {}, debug_output = {} },
  }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  r.stats = r.stats or {}
  r.service_stats = r.service_stats or {}
  r.recent = r.recent or {}
  r.windows = r.windows or {}
  r.external_stats = r.external_stats or {}
  r.profiler = r.profiler or { enabled = false, routes = {}, recent = {}, debug_output = {} }
  if r.profiler.enabled == nil then r.profiler.enabled = false end
  r.profiler.routes = r.profiler.routes or {}
  r.profiler.recent = r.profiler.recent or {}
  r.profiler.debug_output = r.profiler.debug_output or {}
  return r
end

local function remember_window(metric, n)
  local r = M.root()
  local key = window_key(now())
  r.windows[key] = r.windows[key] or {}
  r.windows[key][metric] = (r.windows[key][metric] or 0) + (tonumber(n) or 1)
  for old in pairs(r.windows) do
    if tonumber(old) and tonumber(old) < key - 30 then r.windows[old] = nil end
  end
end
local function stat(k, n)
  local r = M.root()
  r.stats[k] = (r.stats[k] or 0) + (tonumber(n) or 1)
  remember_window(k, n)
end
local function service_stat(name, k, n)
  local r = M.root()
  r.service_stats[name] = r.service_stats[name] or {}
  r.service_stats[name][k] = (r.service_stats[name][k] or 0) + (tonumber(n) or 1)
  remember_window("service:" .. safe(name) .. ":" .. safe(k), n)
end
local function remember(name, action, detail)
  local r = M.root()
  r.recent[#r.recent + 1] = {
    tick = now(),
    service = safe(name),
    action = safe(action),
    detail = safe(detail),
  }
  while #r.recent > 100 do table.remove(r.recent, 1) end
end

function M.note_metric(metric, n)
  local r = M.root()
  metric = tostring(metric or "unknown")
  r.external_stats[metric] = (r.external_stats[metric] or 0) + (tonumber(n) or 1)
  remember_window(metric, n)
  return true
end
function M.rolling_sum(metric, windows_back)
  local r, total, current = M.root(), 0, window_key(now())
  for i = 0, math.max(1, tonumber(windows_back) or 1) - 1 do
    local bucket = r.windows[current - i]
    if bucket then total = total + (tonumber(bucket[metric]) or 0) end
  end
  return total
end

function M.profiler_enabled()
  local cfg = rawget(_G or {}, "TechPriestsRuntimeConfig0626")
  if cfg and type(cfg.is_debug_enabled) == "function" then
    local ok, enabled = pcall(cfg.is_debug_enabled, "profiler")
    if ok then return enabled == true end
  end
  return M.root().profiler.enabled == true
end
function M.set_profiler_enabled(enabled)
  M.root().profiler.enabled = enabled == true
  return M.root().profiler.enabled
end
function M.start_profiler()
  if not M.profiler_enabled() or not (game and game.create_profiler) then return nil end
  local ok, profiler = pcall(game.create_profiler, false)
  return ok and profiler or nil
end
local function profiler_ms(profiler)
  if not profiler then return nil, "" end
  local text = safe(profiler)
  return tonumber(text:match("([%d%.]+)")), text
end
function M.record_profile(section, name, category, profiler, ok)
  local r = M.root()
  local key = safe(section) .. ":" .. safe(name)
  local ms, text = profiler_ms(profiler)
  local rec = r.profiler.routes[key] or {
    section = safe(section), name = safe(name), category = safe(category),
    calls = 0, total_ms = 0, worst_ms = 0, errors = 0,
  }
  rec.calls = rec.calls + 1
  if ok == false then rec.errors = rec.errors + 1 end
  rec.last_text = text
  if ms then
    rec.last_ms = ms
    rec.total_ms = rec.total_ms + ms
    rec.worst_ms = math.max(rec.worst_ms, ms)
    rec.avg_ms = rec.total_ms / rec.calls
  end
  r.profiler.routes[key] = rec
  return rec
end
function M.note_debug_output(channel, owner, n)
  local r = M.root()
  local key = safe(channel) .. ":" .. safe(owner)
  local rec = r.profiler.debug_output[key] or {
    channel = safe(channel), owner = safe(owner), count = 0, last_tick = 0,
  }
  rec.count = rec.count + (tonumber(n) or 1)
  rec.last_tick = now()
  r.profiler.debug_output[key] = rec
  M.note_metric("debug_output_" .. safe(channel), n)
  return true
end
function M.profiler_report_lines(limit)
  local r, lines, records = M.root(), {}, {}
  lines[#lines + 1] = "[tp-runtime-report] broker-profiler enabled=" .. safe(r.profiler.enabled)
    .. " tracked=" .. safe(count_table(r.profiler.routes))
    .. " debug_channels=" .. safe(count_table(r.profiler.debug_output))
  for _, rec in pairs(r.profiler.routes) do records[#records + 1] = rec end
  table.sort(records, function(a, b)
    if (a.worst_ms or 0) == (b.worst_ms or 0) then return a.name < b.name end
    return (a.worst_ms or 0) > (b.worst_ms or 0)
  end)
  for i = 1, math.min(#records, tonumber(limit) or 8) do
    local rec = records[i]
    lines[#lines + 1] = "  slow[" .. i .. "] " .. rec.section .. ":" .. rec.name
      .. " calls=" .. safe(rec.calls) .. " avg_ms=" .. safe(rec.avg_ms or 0)
      .. " worst_ms=" .. safe(rec.worst_ms or 0) .. " errors=" .. safe(rec.errors)
  end
  return lines
end

local function pressure_value(category)
  category = tostring(category or "")
  if category == "repair" then
    return M.rolling_sum("event_repair_submitted", 1) + M.rolling_sum("directed_wake_issued", 1)
  elseif category == "construction" then
    return M.rolling_sum("event_construction_submitted", 1) + M.rolling_sum("directed_wake_construction_issued", 1)
  elseif category == "sanctify" or category == "consecration" then
    return M.rolling_sum("event_sanctify_submitted", 1) + M.rolling_sum("directed_wake_sanctify_issued", 1)
  elseif category == "pickup" or category == "logistics" then
    return M.rolling_sum("event_pickup_submitted", 1) + M.rolling_sum("directed_wake_pickup_issued", 1)
  elseif category == "movement" then
    return M.rolling_sum("path_requests", 1) + M.rolling_sum("movement_active_requests_processed", 1)
  elseif category == "combat" then
    return M.rolling_sum("combat_targets_seen", 1) + M.rolling_sum("combat_wake_issued", 1)
  end
  return 0
end
local function effective_budget(svc)
  local base = math.max(1, tonumber(svc.budget) or 8)
  if svc.dynamic_budget == false then return base, 1, 0 end
  local pressure = pressure_value(svc.category)
  local multiplier = pressure >= 240 and 3 or pressure >= 120 and 2.25
    or pressure >= 60 and 1.75 or pressure >= 20 and 1.35 or 1
  local offered = math.max(1, math.min(64, math.floor(base * multiplier + 0.5)))
  if multiplier > 1 then
    stat("adaptive_budget_boosts")
    service_stat(svc.name, "adaptive_budget_boosts")
  end
  return offered, multiplier, pressure
end

local function normalize_count(value)
  if value == true then return 1 end
  if value == false or value == nil then return 0 end
  local n = tonumber(value)
  return n and math.max(0, math.floor(n)) or 0
end
function M.normalize_result(primary, secondary)
  local result = {
    processed = 0, acted = 0, blocked = 0, waiting = 0, failed = 0,
    exhausted = false, sleeping = false, detail = "",
  }
  if type(primary) == "table" then
    result.processed = normalize_count(primary.processed)
    result.acted = normalize_count(primary.acted)
    result.blocked = normalize_count(primary.blocked)
    result.waiting = normalize_count(primary.waiting)
    result.failed = normalize_count(primary.failed)
    result.exhausted = primary.exhausted == true or primary.budget_exhausted == true
    result.sleeping = primary.sleeping == true or primary.dormant == true
    result.detail = safe(primary.detail or primary.reason or secondary or "")
  elseif type(primary) == "number" then
    result.acted = normalize_count(primary)
    result.processed = result.acted
    result.detail = safe(secondary or ("acted=" .. result.acted))
  elseif primary == true then
    result.acted, result.processed = 1, 1
    result.detail = safe(secondary or "acted")
  elseif type(primary) == "string" then
    result.detail = primary
  else
    result.detail = safe(secondary or primary or "")
  end
  local d = string.lower(result.detail)
  if result.processed == 0 then
    result.processed = result.acted + result.blocked + result.waiting + result.failed
  end
  if result.blocked == 0 and d:find("block", 1, true) then result.blocked = 1 end
  if result.waiting == 0 and (d:find("wait", 1, true) or d:find("cooldown", 1, true)) then result.waiting = 1 end
  if result.failed == 0 and d:find("fail", 1, true) then result.failed = 1 end
  if d:find("sleep", 1, true) or d:find("dormant", 1, true) then result.sleeping = true end
  if d:find("budget", 1, true) and d:find("exhaust", 1, true) then result.exhausted = true end
  return result
end

local function normalize_service(spec, previous)
  if type(spec) ~= "table" then return nil, "spec-not-table" end
  if type(spec.fn) ~= "function" then return nil, "missing-fn" end
  return {
    name = tostring(spec.name or spec.owner or "unnamed-service"),
    category = tostring(spec.category or "uncategorized"),
    priority = tonumber(spec.priority) or 100,
    interval = math.max(1, tonumber(spec.interval) or 60),
    budget = math.max(1, tonumber(spec.budget) or 8),
    fn = spec.fn,
    enabled = spec.enabled ~= false,
    next_due_tick = spec.next_due_tick ~= nil and tonumber(spec.next_due_tick)
      or previous and tonumber(previous.next_due_tick) or 0,
    note = tostring(spec.note or ""),
    dynamic_budget = spec.dynamic_budget ~= false,
  }
end
function M.register_service(spec)
  local previous, index
  local name = type(spec) == "table" and tostring(spec.name or spec.owner or "") or ""
  for i, svc in ipairs(M.services) do
    if svc.name == name then previous, index = svc, i break end
  end
  local svc, why = normalize_service(spec, previous)
  if not svc then return nil, why end
  if index then M.services[index] = svc else M.services[#M.services + 1] = svc end
  table.sort(M.services, function(a, b)
    if a.priority == b.priority then return a.name < b.name end
    return a.priority < b.priority
  end)
  service_stat(svc.name, index and "replaced" or "registered")
  return svc
end
function M.service_count() return #M.services end

local function record_result(svc, result, offered)
  service_stat(svc.name, "processed", result.processed)
  service_stat(svc.name, "acted", result.acted)
  service_stat(svc.name, "blocked", result.blocked)
  service_stat(svc.name, "waiting", result.waiting)
  service_stat(svc.name, "failed", result.failed)
  if result.acted > 0 then
    stat("service_actions", result.acted)
  elseif result.sleeping then
    stat("skipped_sleeping")
    service_stat(svc.name, "skipped_sleeping")
  elseif result.waiting > 0 then
    stat("skipped_waiting")
    service_stat(svc.name, "skipped_waiting")
  elseif result.blocked > 0 then
    stat("skipped_blocked")
    service_stat(svc.name, "skipped_blocked")
  else
    stat("skipped_empty")
    service_stat(svc.name, "skipped_empty")
  end
  if result.exhausted then
    stat("budget_exhausted")
    service_stat(svc.name, "budget_exhausted")
  end
  local ss = M.root().service_stats[svc.name]
  ss.last_result = {
    tick = now(), offered = offered, processed = result.processed,
    acted = result.acted, blocked = result.blocked, waiting = result.waiting,
    failed = result.failed, exhausted = result.exhausted, detail = result.detail,
  }
end

function M.pulse(event)
  local r = M.root()
  if r.enabled == false then stat("skipped_disabled") return end
  local tick = event and event.tick or now()
  stat("pulses")
  for _, svc in ipairs(M.services) do
    if svc.enabled == false then
      stat("skipped_disabled")
    elseif tick < (tonumber(svc.next_due_tick) or 0) then
      stat("skipped_not_due")
    else
      svc.next_due_tick = tick + svc.interval
      service_stat(svc.name, "due")
      local offered = effective_budget(svc)
      service_stat(svc.name, "budget_offered", offered)
      local profiler = M.start_profiler()
      local ok, primary, secondary = pcall(svc.fn, event or { tick = tick }, offered, svc)
      if profiler and profiler.stop then pcall(function() profiler.stop() end) end
      M.record_profile("broker", svc.name, svc.category, profiler, ok)
      stat("services_run")
      service_stat(svc.name, "run")
      if ok then
        local result = M.normalize_result(primary, secondary)
        record_result(svc, result, offered)
      else
        stat("errors")
        service_stat(svc.name, "errors")
        remember(svc.name, "error", primary)
        if log then
          log("[Tech-Priests broker] isolated service failure " .. svc.name .. ": " .. safe(primary))
        end
      end
    end
  end
end

function M.report_lines()
  local r, lines = M.root(), {}
  lines[#lines + 1] = "[tp-runtime-report] broker version=" .. M.version
    .. " enabled=" .. safe(r.enabled) .. " services=" .. #M.services
    .. " pulses=" .. safe(r.stats.pulses or 0)
    .. " run=" .. safe(r.stats.services_run or 0)
    .. " actions=" .. safe(r.stats.service_actions or 0)
    .. " empty=" .. safe(r.stats.skipped_empty or 0)
    .. " waiting=" .. safe(r.stats.skipped_waiting or 0)
    .. " blocked=" .. safe(r.stats.skipped_blocked or 0)
    .. " sleeping=" .. safe(r.stats.skipped_sleeping or 0)
    .. " exhausted=" .. safe(r.stats.budget_exhausted or 0)
    .. " errors=" .. safe(r.stats.errors or 0)
  for _, svc in ipairs(M.services) do
    local ss = r.service_stats[svc.name] or {}
    local last = ss.last_result or {}
    lines[#lines + 1] = "  service " .. svc.name .. " cat=" .. svc.category
      .. " interval=" .. svc.interval .. " priority=" .. svc.priority
      .. " budget=" .. svc.budget .. " run=" .. safe(ss.run or 0)
      .. " processed=" .. safe(ss.processed or 0)
      .. " acted=" .. safe(ss.acted or 0)
      .. " blocked=" .. safe(ss.blocked or 0)
      .. " waiting=" .. safe(ss.waiting or 0)
      .. " failed=" .. safe(ss.failed or 0)
      .. " last={" .. safe(last.acted or 0) .. "/" .. safe(last.processed or 0)
      .. " " .. safe(last.detail) .. "}"
  end
  return lines
end

function M.install()
  M.root()
  local cfg = rawget(_G or {}, "TechPriestsRuntimeConfig0626")
  if cfg and type(cfg.is_debug_enabled) == "function" then
    local ok, enabled = pcall(cfg.is_debug_enabled, "profiler")
    if ok then M.set_profiler_enabled(enabled == true) end
  end
  if not M.installed then
    local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
    if not (R and type(R.on_nth_tick) == "function") then
      local ok, required = pcall(require, "scripts.core.runtime_event_registry")
      if ok then R = required end
    end
    if R and type(R.on_nth_tick) == "function" then
      R.on_nth_tick(M.base_interval, function(event) M.pulse(event) end, {
        owner = "runtime_tick_broker_0600", route = "central-pulse",
        category = "runtime", priority = "first",
      })
    elseif script and script.on_nth_tick then
      script.on_nth_tick(M.base_interval, function(event) M.pulse(event) end)
      remember("runtime_tick_broker_0600", "direct-fallback", "event registry unavailable")
    end
    M.installed = true
  end
  if commands and commands.remove_command then pcall(commands.remove_command, "tp-runtime-report") end
  _G.TechPriestsRuntimeTickBroker0600 = M
  _G.tech_priests_runtime_metric_0606 = M.note_metric
  _G.tech_priests_runtime_profile_0625 = M.record_profile
  _G.tech_priests_debug_output_0625 = M.note_debug_output
  return true
end

return M
