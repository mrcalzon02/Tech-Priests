-- scripts/core/runtime_tick_broker.lua
-- Tech Priests 0.1.674-dev base-state recovery.
-- Central budgeted broker with strict service-result normalization and one
-- owner-keyed runtime-event-registry cadence. No direct script fallback exists.

local M = {
  version = "0.1.674-dev",
  storage_key = "runtime_tick_broker_0600",
  base_interval = 5,
  services = {},
  installed = false,
  install_state = { complete = false, reason = "not-installed" },
}

local function now() return game and game.tick or 0 end
local function safe(value)
  if value == nil then return "nil" end
  local ok, text = pcall(tostring, value)
  return ok and text or "?"
end
local function count_table(value)
  local count = 0
  if type(value) == "table" then
    for _ in pairs(value) do count = count + 1 end
  end
  return count
end
local function window_key(tick)
  return math.floor((tonumber(tick) or now()) / 3600)
end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local root = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    stats = {},
    service_stats = {},
    recent = {},
    windows = {},
    external_stats = {},
    profiler = { enabled = false, routes = {}, recent = {}, debug_output = {} },
    installation = {},
  }
  storage.tech_priests[M.storage_key] = root
  root.version = M.version
  if root.enabled == nil then root.enabled = true end
  root.stats = root.stats or {}
  root.service_stats = root.service_stats or {}
  root.recent = root.recent or {}
  root.windows = root.windows or {}
  root.external_stats = root.external_stats or {}
  root.profiler = root.profiler or {
    enabled = false, routes = {}, recent = {}, debug_output = {},
  }
  if root.profiler.enabled == nil then root.profiler.enabled = false end
  root.profiler.routes = root.profiler.routes or {}
  root.profiler.recent = root.profiler.recent or {}
  root.profiler.debug_output = root.profiler.debug_output or {}
  root.installation = root.installation or {}
  return root
end

local function remember_window(metric, amount)
  local root = M.root()
  local key = window_key(now())
  root.windows[key] = root.windows[key] or {}
  root.windows[key][metric] =
    (root.windows[key][metric] or 0) + (tonumber(amount) or 1)
  for old in pairs(root.windows) do
    if tonumber(old) and tonumber(old) < key - 30 then root.windows[old] = nil end
  end
end
local function stat(key, amount)
  local root = M.root()
  root.stats[key] = (root.stats[key] or 0) + (tonumber(amount) or 1)
  remember_window(key, amount)
end
local function service_stat(name, key, amount)
  local root = M.root()
  root.service_stats[name] = root.service_stats[name] or {}
  root.service_stats[name][key] =
    (root.service_stats[name][key] or 0) + (tonumber(amount) or 1)
  remember_window("service:" .. safe(name) .. ":" .. safe(key), amount)
end
local function remember(name, action, detail)
  local root = M.root()
  root.recent[#root.recent + 1] = {
    tick = now(),
    service = safe(name),
    action = safe(action),
    detail = safe(detail),
  }
  while #root.recent > 100 do table.remove(root.recent, 1) end
end

function M.note_metric(metric, amount)
  local root = M.root()
  metric = tostring(metric or "unknown")
  root.external_stats[metric] =
    (root.external_stats[metric] or 0) + (tonumber(amount) or 1)
  remember_window(metric, amount)
  return true
end
function M.rolling_sum(metric, windows_back)
  local root, total, current = M.root(), 0, window_key(now())
  for index = 0, math.max(1, tonumber(windows_back) or 1) - 1 do
    local bucket = root.windows[current - index]
    if bucket then total = total + (tonumber(bucket[metric]) or 0) end
  end
  return total
end

function M.profiler_enabled()
  local config = rawget(_G or {}, "TechPriestsRuntimeConfig0626")
  if config and type(config.is_debug_enabled) == "function" then
    local ok, enabled = pcall(config.is_debug_enabled, "profiler")
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
  local root = M.root()
  local key = safe(section) .. ":" .. safe(name)
  local milliseconds, text = profiler_ms(profiler)
  local record = root.profiler.routes[key] or {
    section = safe(section),
    name = safe(name),
    category = safe(category),
    calls = 0,
    total_ms = 0,
    worst_ms = 0,
    errors = 0,
  }
  record.calls = record.calls + 1
  if ok == false then record.errors = record.errors + 1 end
  record.last_text = text
  if milliseconds then
    record.last_ms = milliseconds
    record.total_ms = record.total_ms + milliseconds
    record.worst_ms = math.max(record.worst_ms, milliseconds)
    record.avg_ms = record.total_ms / record.calls
  end
  root.profiler.routes[key] = record
  return record
end
function M.note_debug_output(channel, owner, amount)
  local root = M.root()
  local key = safe(channel) .. ":" .. safe(owner)
  local record = root.profiler.debug_output[key] or {
    channel = safe(channel), owner = safe(owner), count = 0, last_tick = 0,
  }
  record.count = record.count + (tonumber(amount) or 1)
  record.last_tick = now()
  root.profiler.debug_output[key] = record
  M.note_metric("debug_output_" .. safe(channel), amount)
  return true
end
function M.profiler_report_lines(limit)
  local root, lines, records = M.root(), {}, {}
  lines[#lines + 1] =
    "[tp-runtime-report] broker-profiler enabled=" .. safe(root.profiler.enabled)
    .. " tracked=" .. safe(count_table(root.profiler.routes))
    .. " debug_channels=" .. safe(count_table(root.profiler.debug_output))
  for _, record in pairs(root.profiler.routes) do records[#records + 1] = record end
  table.sort(records, function(a, b)
    if (a.worst_ms or 0) == (b.worst_ms or 0) then return a.name < b.name end
    return (a.worst_ms or 0) > (b.worst_ms or 0)
  end)
  for index = 1, math.min(#records, tonumber(limit) or 8) do
    local record = records[index]
    lines[#lines + 1] =
      "  slow[" .. index .. "] " .. record.section .. ":" .. record.name
      .. " calls=" .. safe(record.calls)
      .. " avg_ms=" .. safe(record.avg_ms or 0)
      .. " worst_ms=" .. safe(record.worst_ms or 0)
      .. " errors=" .. safe(record.errors)
  end
  return lines
end

local function pressure_value(category)
  category = tostring(category or "")
  if category == "repair" then
    return M.rolling_sum("event_repair_submitted", 1)
      + M.rolling_sum("directed_wake_issued", 1)
  elseif category == "construction" then
    return M.rolling_sum("event_construction_submitted", 1)
      + M.rolling_sum("directed_wake_construction_issued", 1)
  elseif category == "sanctify" or category == "consecration" then
    return M.rolling_sum("event_sanctify_submitted", 1)
      + M.rolling_sum("directed_wake_sanctify_issued", 1)
  elseif category == "pickup" or category == "logistics" then
    return M.rolling_sum("event_pickup_submitted", 1)
      + M.rolling_sum("directed_wake_pickup_issued", 1)
  elseif category == "movement" then
    return M.rolling_sum("path_requests", 1)
      + M.rolling_sum("movement_active_requests_processed", 1)
  elseif category == "combat" then
    return M.rolling_sum("combat_targets_seen", 1)
      + M.rolling_sum("combat_wake_issued", 1)
  end
  return 0
end
local function effective_budget(service)
  local base = math.max(1, tonumber(service.budget) or 8)
  if service.dynamic_budget == false then return base, 1, 0 end
  local pressure = pressure_value(service.category)
  local multiplier =
    pressure >= 240 and 3
    or pressure >= 120 and 2.25
    or pressure >= 60 and 1.75
    or pressure >= 20 and 1.35
    or 1
  local offered =
    math.max(1, math.min(64, math.floor(base * multiplier + 0.5)))
  if multiplier > 1 then
    stat("adaptive_budget_boosts")
    service_stat(service.name, "adaptive_budget_boosts")
  end
  return offered, multiplier, pressure
end

local function normalize_count(value)
  if value == true then return 1 end
  if value == false or value == nil then return 0 end
  local number = tonumber(value)
  return number and math.max(0, math.floor(number)) or 0
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
    result.exhausted =
      primary.exhausted == true or primary.budget_exhausted == true
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
  local detail = string.lower(result.detail)
  if result.processed == 0 then
    result.processed =
      result.acted + result.blocked + result.waiting + result.failed
  end
  if result.blocked == 0 and detail:find("block", 1, true) then
    result.blocked = 1
  end
  if result.waiting == 0
    and (detail:find("wait", 1, true) or detail:find("cooldown", 1, true))
  then
    result.waiting = 1
  end
  if result.failed == 0 and detail:find("fail", 1, true) then
    result.failed = 1
  end
  if detail:find("sleep", 1, true) or detail:find("dormant", 1, true) then
    result.sleeping = true
  end
  if detail:find("budget", 1, true) and detail:find("exhaust", 1, true) then
    result.exhausted = true
  end
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
    next_due_tick =
      spec.next_due_tick ~= nil and tonumber(spec.next_due_tick)
      or previous and tonumber(previous.next_due_tick)
      or 0,
    note = tostring(spec.note or ""),
    dynamic_budget = spec.dynamic_budget ~= false,
  }
end
function M.register_service(spec)
  local previous, index
  local name =
    type(spec) == "table" and tostring(spec.name or spec.owner or "") or ""
  for candidate_index, service in ipairs(M.services) do
    if service.name == name then
      previous, index = service, candidate_index
      break
    end
  end
  local service, why = normalize_service(spec, previous)
  if not service then return nil, why end
  if index then M.services[index] = service
  else M.services[#M.services + 1] = service end
  table.sort(M.services, function(a, b)
    if a.priority == b.priority then return a.name < b.name end
    return a.priority < b.priority
  end)
  service_stat(service.name, index and "replaced" or "registered")
  return service
end
function M.service_count() return #M.services end

local function record_result(service, result, offered)
  service_stat(service.name, "processed", result.processed)
  service_stat(service.name, "acted", result.acted)
  service_stat(service.name, "blocked", result.blocked)
  service_stat(service.name, "waiting", result.waiting)
  service_stat(service.name, "failed", result.failed)
  if result.acted > 0 then
    stat("service_actions", result.acted)
  elseif result.sleeping then
    stat("skipped_sleeping")
    service_stat(service.name, "skipped_sleeping")
  elseif result.waiting > 0 then
    stat("skipped_waiting")
    service_stat(service.name, "skipped_waiting")
  elseif result.blocked > 0 then
    stat("skipped_blocked")
    service_stat(service.name, "skipped_blocked")
  else
    stat("skipped_empty")
    service_stat(service.name, "skipped_empty")
  end
  if result.exhausted then
    stat("budget_exhausted")
    service_stat(service.name, "budget_exhausted")
  end
  local stats = M.root().service_stats[service.name]
  stats.last_result = {
    tick = now(),
    offered = offered,
    processed = result.processed,
    acted = result.acted,
    blocked = result.blocked,
    waiting = result.waiting,
    failed = result.failed,
    exhausted = result.exhausted,
    detail = result.detail,
  }
end

function M.pulse(event)
  local root = M.root()
  if root.enabled == false then stat("skipped_disabled") return end
  local tick = event and event.tick or now()
  stat("pulses")
  for _, service in ipairs(M.services) do
    if service.enabled == false then
      stat("skipped_disabled")
    elseif tick < (tonumber(service.next_due_tick) or 0) then
      stat("skipped_not_due")
    else
      service.next_due_tick = tick + service.interval
      service_stat(service.name, "due")
      local offered = effective_budget(service)
      service_stat(service.name, "budget_offered", offered)
      local profiler = M.start_profiler()
      local ok, primary, secondary =
        pcall(service.fn, event or { tick = tick }, offered, service)
      if profiler and profiler.stop then
        pcall(function() profiler.stop() end)
      end
      M.record_profile("broker", service.name, service.category, profiler, ok)
      stat("services_run")
      service_stat(service.name, "run")
      if ok then
        record_result(service, M.normalize_result(primary, secondary), offered)
      else
        stat("errors")
        service_stat(service.name, "errors")
        remember(service.name, "error", primary)
        if log then
          log(
            "[Tech-Priests broker] isolated service failure "
            .. service.name .. ": " .. safe(primary)
          )
        end
      end
    end
  end
end

function M.installation_summary()
  local state = M.install_state or {}
  return {
    version = M.version,
    complete = state.complete == true,
    installed = M.installed == true,
    registry_available = state.registry_available == true,
    route_id = state.route_id,
    route_registered = state.route_registered == true,
    reason = state.reason,
  }
end
function M.report_lines()
  local root, lines = M.root(), {}
  local installation = M.installation_summary()
  lines[#lines + 1] =
    "[tp-runtime-report] broker version=" .. M.version
    .. " enabled=" .. safe(root.enabled)
    .. " installed=" .. safe(installation.installed)
    .. " route_registered=" .. safe(installation.route_registered)
    .. " route_id=" .. safe(installation.route_id)
    .. " services=" .. #M.services
    .. " pulses=" .. safe(root.stats.pulses or 0)
    .. " run=" .. safe(root.stats.services_run or 0)
    .. " actions=" .. safe(root.stats.service_actions or 0)
    .. " empty=" .. safe(root.stats.skipped_empty or 0)
    .. " waiting=" .. safe(root.stats.skipped_waiting or 0)
    .. " blocked=" .. safe(root.stats.skipped_blocked or 0)
    .. " sleeping=" .. safe(root.stats.skipped_sleeping or 0)
    .. " exhausted=" .. safe(root.stats.budget_exhausted or 0)
    .. " errors=" .. safe(root.stats.errors or 0)
  for _, service in ipairs(M.services) do
    local stats = root.service_stats[service.name] or {}
    local last_result = stats.last_result or {}
    lines[#lines + 1] =
      "  service " .. service.name
      .. " cat=" .. service.category
      .. " interval=" .. service.interval
      .. " priority=" .. service.priority
      .. " budget=" .. service.budget
      .. " run=" .. safe(stats.run or 0)
      .. " processed=" .. safe(stats.processed or 0)
      .. " acted=" .. safe(stats.acted or 0)
      .. " blocked=" .. safe(stats.blocked or 0)
      .. " waiting=" .. safe(stats.waiting or 0)
      .. " failed=" .. safe(stats.failed or 0)
      .. " last={" .. safe(last_result.acted or 0)
      .. "/" .. safe(last_result.processed or 0)
      .. " " .. safe(last_result.detail) .. "}"
  end
  return lines
end

local function canonical_registry()
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if registry then return registry end
  local ok, loaded = pcall(require, "scripts.core.runtime_event_registry")
  if ok then return loaded end
  return nil, loaded
end
local function record_installation(complete, reason, registry, entry)
  M.installed = complete == true
  M.install_state = {
    complete = complete == true,
    registry_available = registry ~= nil,
    route_registered =
      type(entry) == "table"
      and entry.id == "runtime_tick_broker_0600:central-pulse",
    route_id = type(entry) == "table" and entry.id or nil,
    reason = tostring(reason or ""),
  }
  local root = M.root()
  root.installation = {
    version = M.version,
    complete = M.install_state.complete,
    installed = M.installed,
    registry_available = M.install_state.registry_available,
    route_registered = M.install_state.route_registered,
    route_id = M.install_state.route_id,
    reason = M.install_state.reason,
  }
  if complete then stat("install_complete") else stat("install_failed") end
end

function M.install()
  M.root()
  local config = rawget(_G or {}, "TechPriestsRuntimeConfig0626")
  if config and type(config.is_debug_enabled) == "function" then
    local ok, enabled = pcall(config.is_debug_enabled, "profiler")
    if ok then M.set_profiler_enabled(enabled == true) end
  end

  local registry, registry_error = canonical_registry()
  if not (registry and type(registry.on_nth_tick) == "function") then
    record_installation(
      false,
      "canonical-event-registry-unavailable:" .. safe(registry_error),
      registry,
      nil
    )
    remember(
      "runtime_tick_broker_0600",
      "install-failed",
      M.install_state.reason
    )
    return false
  end

  local entry = registry.on_nth_tick(
    M.base_interval,
    function(event) M.pulse(event) end,
    {
      owner = "runtime_tick_broker_0600",
      route = "central-pulse",
      category = "runtime",
      priority = "first",
      note = "single canonical broker cadence",
    }
  )
  local route_ok =
    type(entry) == "table"
    and entry.id == "runtime_tick_broker_0600:central-pulse"
  if not route_ok then
    record_installation(false, "central-route-registration-failed", registry, entry)
    remember(
      "runtime_tick_broker_0600",
      "install-failed",
      M.install_state.reason
    )
    return false
  end

  record_installation(true, "canonical-route-registered", registry, entry)
  if commands and commands.remove_command then
    pcall(commands.remove_command, "tp-runtime-report")
  end
  _G.TechPriestsRuntimeTickBroker0600 = M
  _G.tech_priests_runtime_metric_0606 = M.note_metric
  _G.tech_priests_runtime_profile_0625 = M.record_profile
  _G.tech_priests_debug_output_0625 = M.note_debug_output
  return true
end

return M
