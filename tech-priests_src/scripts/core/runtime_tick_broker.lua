-- scripts/core/runtime_tick_broker.lua
-- Tech Priests 0.1.607
-- Central budgeted runtime service broker.
--
-- This is the first spine for replacing many independent broad nth-tick loops
-- with one auditable service broker.  Services register here with an interval,
-- priority, category, and soft budget.  The broker pulses from one registry
-- route and decides which services are due.

local M = {}
M.version = "0.1.626"
M.storage_key = "runtime_tick_broker_0600"
M.base_interval = 5
M.services = M.services or {}
M.installed = M.installed or false

local function now() return game and game.tick or 0 end
local function safe(v) if v == nil then return "nil" end; local ok,o=pcall(function() return tostring(v) end); return ok and o or "?" end

local function count_table_0625(t)
  local n = 0
  if type(t) == "table" then for _ in pairs(t) do n = n + 1 end end
  return n
end

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
    profiler = { enabled = true, routes = {}, recent = {}, debug_output = {} },
  }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  r.stats = r.stats or {}
  r.service_stats = r.service_stats or {}
  r.recent = r.recent or {}
  r.windows = r.windows or {}
  r.external_stats = r.external_stats or {}
  r.profiler = r.profiler or { enabled = true, routes = {}, recent = {}, debug_output = {} }
  if r.profiler.enabled == nil then r.profiler.enabled = true end
  r.profiler.routes = r.profiler.routes or {}
  r.profiler.recent = r.profiler.recent or {}
  r.profiler.debug_output = r.profiler.debug_output or {}
  return r
end

local function window_key(tick)
  return math.floor((tonumber(tick) or now()) / 3600)
end

local function remember_window(metric, n)
  local r = M.root()
  local key = window_key(now())
  r.windows[key] = r.windows[key] or {}
  r.windows[key][metric] = (r.windows[key][metric] or 0) + (n or 1)
  local floor_key = key - 30
  for old in pairs(r.windows or {}) do
    if tonumber(old) and tonumber(old) < floor_key then r.windows[old] = nil end
  end
end

local function stat(k, n)
  local r = M.root()
  r.stats[k] = (r.stats[k] or 0) + (n or 1)
  remember_window(k, n or 1)
end

local function service_stat(name, k, n)
  local r = M.root()
  r.service_stats[name] = r.service_stats[name] or {}
  r.service_stats[name][k] = (r.service_stats[name][k] or 0) + (n or 1)
  remember_window("service:" .. tostring(name or "?") .. ":" .. tostring(k or "event"), n or 1)
end
local function profiler_ms(profiler)
  if not profiler then return nil, "" end
  local text = safe(profiler)
  local n = text:match("([%d%.]+)")
  return tonumber(n), text
end

local function profile_key(section, name)
  return tostring(section or "runtime") .. ":" .. tostring(name or "?")
end

function M.profiler_enabled()
  local cfg = rawget(_G or {}, "TechPriestsRuntimeConfig0626")
  if cfg and cfg.is_debug_enabled then
    local ok, enabled = pcall(cfg.is_debug_enabled, "profiler")
    if ok then return enabled == true end
  end
  local r = M.root()
  return r.profiler and r.profiler.enabled ~= false
end

function M.set_profiler_enabled(enabled)
  local r = M.root()
  r.profiler.enabled = enabled ~= false
  return r.profiler.enabled
end

function M.start_profiler()
  if not M.profiler_enabled() then return nil end
  if not (game and game.create_profiler) then return nil end
  local ok, profiler = pcall(function() return game.create_profiler(false) end)
  if ok then return profiler end
  return nil
end

function M.record_profile(section, name, category, profiler, ok)
  local r = M.root()
  r.profiler = r.profiler or { enabled = true, routes = {}, recent = {}, debug_output = {} }
  local ms, text = profiler_ms(profiler)
  local key = profile_key(section, name)
  local rec = r.profiler.routes[key] or { section = tostring(section or "runtime"), name = tostring(name or "?"), category = tostring(category or "?"), calls = 0, total_ms = 0, worst_ms = 0, errors = 0, last_ms = 0, last_text = "" }
  rec.calls = (rec.calls or 0) + 1
  rec.category = tostring(category or rec.category or "?")
  if ok == false then rec.errors = (rec.errors or 0) + 1 end
  rec.last_text = text or ""
  if ms then
    rec.last_ms = ms
    rec.total_ms = (rec.total_ms or 0) + ms
    if ms > (rec.worst_ms or 0) then rec.worst_ms = ms; rec.worst_tick = now() end
    rec.avg_ms = rec.total_ms / math.max(1, rec.calls or 1)
  end
  r.profiler.routes[key] = rec
  r.profiler.recent[#r.profiler.recent + 1] = { tick = now(), section = rec.section, name = rec.name, ms = rec.last_ms, text = rec.last_text, ok = ok ~= false }
  while #r.profiler.recent > 80 do table.remove(r.profiler.recent, 1) end
  return rec
end

function M.note_debug_output(channel, owner, n)
  local r = M.root()
  r.profiler = r.profiler or { enabled = true, routes = {}, recent = {}, debug_output = {} }
  local key = tostring(channel or "debug") .. ":" .. tostring(owner or "unknown")
  local rec = r.profiler.debug_output[key] or { channel = tostring(channel or "debug"), owner = tostring(owner or "unknown"), count = 0, last_tick = 0 }
  rec.count = (rec.count or 0) + (n or 1)
  rec.last_tick = now()
  r.profiler.debug_output[key] = rec
  M.note_metric("debug_output_" .. tostring(channel or "debug"), n or 1)
  return true
end

local function sorted_profile_records(limit)
  local r = M.root()
  local out = {}
  for _, rec in pairs((r.profiler or {}).routes or {}) do out[#out + 1] = rec end
  table.sort(out, function(a, b)
    local aw = tonumber(a.worst_ms or 0) or 0
    local bw = tonumber(b.worst_ms or 0) or 0
    if aw == bw then return tostring(a.name) < tostring(b.name) end
    return aw > bw
  end)
  if limit and #out > limit then
    local trimmed = {}
    for i = 1, limit do trimmed[i] = out[i] end
    return trimmed
  end
  return out
end

function M.profiler_report_lines(limit)
  local r = M.root()
  local lines = {}
  lines[#lines + 1] = "[tp-runtime-report] profiler-0625 enabled=" .. safe((r.profiler or {}).enabled ~= false) .. " tracked=" .. safe(count_table_0625((r.profiler or {}).routes)) .. " debug_channels=" .. safe(count_table_0625((r.profiler or {}).debug_output))
  local top = sorted_profile_records(limit or 8)
  if #top == 0 then
    lines[#lines + 1] = "  profiler top-slowest: no samples yet"
  else
    for i, rec in ipairs(top) do
      lines[#lines + 1] = "  slow[" .. safe(i) .. "] " .. safe(rec.section) .. ":" .. safe(rec.name) .. " cat=" .. safe(rec.category) .. " calls=" .. safe(rec.calls or 0) .. " avg_ms=" .. safe(rec.avg_ms or 0) .. " worst_ms=" .. safe(rec.worst_ms or 0) .. " errors=" .. safe(rec.errors or 0) .. " last=" .. safe(rec.last_text or "")
    end
  end
  local debug = {}
  for _, rec in pairs((r.profiler or {}).debug_output or {}) do debug[#debug + 1] = rec end
  table.sort(debug, function(a,b) return (tonumber(a.count or 0) or 0) > (tonumber(b.count or 0) or 0) end)
  for i = 1, math.min(#debug, 6) do
    local d = debug[i]
    lines[#lines + 1] = "  debug-output[" .. safe(i) .. "] " .. safe(d.channel) .. ":" .. safe(d.owner) .. " count=" .. safe(d.count or 0) .. " last_tick=" .. safe(d.last_tick or 0)
  end
  return lines
end


function M.note_metric(metric, n)
  local r = M.root()
  metric = tostring(metric or "unknown")
  r.external_stats[metric] = (r.external_stats[metric] or 0) + (n or 1)
  remember_window(metric, n or 1)
  return true
end

function M.rolling_sum(metric, windows_back)
  local r = M.root()
  local cur = window_key(now())
  local total = 0
  for i = 0, tonumber(windows_back or 1) - 1 do
    local b = r.windows[cur - i]
    if b then total = total + (tonumber(b[metric] or 0) or 0) end
  end
  return total
end


local function clamp(n, lo, hi)
  n = tonumber(n) or 0
  if n < lo then return lo end
  if n > hi then return hi end
  return n
end

local function pressure_value(category)
  category = tostring(category or "")
  -- 0.1.618: adaptive budget weighting lives inside the broker authority.  It
  -- reads existing rolling telemetry and adjusts only the soft budget passed to
  -- services; it does not change service cadence, priority, scheduling, target
  -- choice, reservations, queues, movement, or execution ownership.
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

local function budget_multiplier_for_pressure(pressure)
  pressure = tonumber(pressure) or 0
  if pressure >= 240 then return 3.0 end
  if pressure >= 120 then return 2.25 end
  if pressure >= 60 then return 1.75 end
  if pressure >= 20 then return 1.35 end
  return 1.0
end

local function effective_budget_for_service(svc)
  local base = math.max(1, tonumber(svc and svc.budget) or 8)
  if svc and svc.dynamic_budget == false then return base, 1.0, 0 end
  local pressure = pressure_value(svc and svc.category)
  local mult = budget_multiplier_for_pressure(pressure)
  local eff = math.floor(base * mult + 0.5)
  eff = clamp(eff, 1, math.max(base, 64))
  if mult > 1.0 then
    stat("adaptive_budget_boosts", 1)
    service_stat(svc.name, "adaptive_budget_boosts", 1)
    local r = M.root()
    r.adaptive_budget = r.adaptive_budget or {}
    r.adaptive_budget[svc.name] = { tick = now(), category = tostring(svc.category or "?"), base = base, effective = eff, pressure = pressure, multiplier = mult }
  end
  return eff, mult, pressure
end

local function remember(name, action, detail)
  local r = M.root()
  local ev = { tick = now(), service = tostring(name or "?"), action = tostring(action or "event"), detail = tostring(detail or "") }
  r.recent[#r.recent + 1] = ev
  while #r.recent > 80 do table.remove(r.recent, 1) end
end

local function normalize_service(spec)
  if type(spec) ~= "table" then return nil, "spec-not-table" end
  if type(spec.fn) ~= "function" then return nil, "missing-fn" end
  local name = tostring(spec.name or spec.owner or ("service-" .. tostring(#M.services + 1)))
  return {
    name = name,
    category = tostring(spec.category or "uncategorized"),
    priority = tonumber(spec.priority) or 100,
    interval = math.max(1, tonumber(spec.interval) or 60),
    budget = math.max(1, tonumber(spec.budget) or 8),
    fn = spec.fn,
    enabled = spec.enabled ~= false,
    next_due_tick = tonumber(spec.next_due_tick) or 0,
    note = tostring(spec.note or ""),
    dynamic_budget = spec.dynamic_budget ~= false,
  }
end

function M.register_service(spec)
  local svc, why = normalize_service(spec)
  if not svc then return nil, why end
  -- Replace by name so reload/install is idempotent.
  for i = 1, #M.services do
    if M.services[i] and M.services[i].name == svc.name then
      M.services[i] = svc
      service_stat(svc.name, "registered", 1)
      return svc
    end
  end
  M.services[#M.services + 1] = svc
  table.sort(M.services, function(a, b)
    if (a.priority or 100) == (b.priority or 100) then return tostring(a.name) < tostring(b.name) end
    return (a.priority or 100) < (b.priority or 100)
  end)
  service_stat(svc.name, "registered", 1)
  return svc
end

function M.service_count()
  return #M.services
end

function M.pulse(event)
  local r = M.root()
  if r.enabled == false then stat("skipped_disabled"); return end
  local tick = event and event.tick or now()
  stat("pulses")
  for i = 1, #M.services do
    local svc = M.services[i]
    if svc and svc.enabled ~= false then
      if tick >= (tonumber(svc.next_due_tick) or 0) then
        svc.next_due_tick = tick + (tonumber(svc.interval) or 60)
        service_stat(svc.name, "due", 1)
        local effective_budget, budget_mult, budget_pressure = effective_budget_for_service(svc)
        service_stat(svc.name, "budget_offered", effective_budget)
        local profiler = M.start_profiler()
        local ok, acted, detail = pcall(svc.fn, event or { tick = tick }, effective_budget, svc)
        if profiler and profiler.stop then pcall(function() profiler.stop() end) end
        M.record_profile("broker", svc.name, svc.category, profiler, ok)
        if ok then
          stat("services_run")
          service_stat(svc.name, "run", 1)
          local d = string.lower(tostring(detail or acted or ""))
          if d:find("budget", 1, true) then
            stat("budget_exhausted")
            service_stat(svc.name, "budget_exhausted", 1)
          end
          if acted == false then
            if d:find("sleep", 1, true) or d:find("dormant", 1, true) then
              stat("skipped_sleeping")
              service_stat(svc.name, "skipped_sleeping", 1)
            else
              stat("skipped_empty")
              service_stat(svc.name, "skipped_empty", 1)
            end
          else
            service_stat(svc.name, "acted", 1)
          end
        else
          stat("errors")
          service_stat(svc.name, "errors", 1)
          remember(svc.name, "error", acted)
          if log then log("[Tech-Priests 0.1.600 runtime broker] service failure " .. safe(svc.name) .. ": " .. safe(acted)) end
        end
      else
        stat("skipped_not_due")
      end
    else
      stat("skipped_disabled")
    end
  end
end



local function registry_route_counts()
  local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not R then return 0, 0, 0 end
  local keys, handlers = 0, 0
  if type(R.nth_tick_routes) == "table" then
    for _, route in pairs(R.nth_tick_routes) do
      keys = keys + 1
      if type(route) == "table" then handlers = handlers + #route end
    end
  elseif type(R.count_nth_tick_handlers) == "function" then
    handlers = R.count_nth_tick_handlers() or 0
  end
  local raw = rawget(R, "direct_fallback_warning_count_0605") or 0
  return keys, handlers, raw
end

local direct_fallback_audit_0605 = {
  "acquisition_executor", "acquisition_repair", "acquisition_unstick", "action_state_arbiter_0488",
  "alt_writ_visual_stability_0474", "behavior_contracts_0479", "behavior_stack_cleanup_0509",
  "bootstrap_runtime", "chatter", "combat_magos_movement_authority_0472", "command_hierarchy_0480",
  "conversation_voice_0530", "crafting_executor", "diagnostics_behavior_authority_0468",
  "direct_mining_safety_0490", "doctrine_argument", "emergency_supply_reserve_0497",
  "magos_planning_queue_0471", "movement_bounds_contract_0511", "placeholder_audio_0533",
  "priest_lifecycle_authority_0499", "priest_lifecycle_seal_0500", "priest_recovery_safety_0503",
  "priest_vanish_guard_0501", "priest_vanish_guard_0502", "proxy_turret_alignment",
  "scheduler_contract_0512", "self_station_scan_visual_authority_0489", "single_dispatcher_0510",
  "sound_manager_0475", "startup_provisioning", "station_catalog", "station_network_overlay",
  "station_pair_recovery", "station_work_inventory", "status_churn_damper_0532",
  "status_state_sanity", "stone_cache_filter_0534", "task_execution_sound_governor_0477",
  "task_lifecycle_authority_0478", "task_pair_audit_0498"
}

local function direct_fallback_audit_count() return #direct_fallback_audit_0605 end

local function count_table(t)
  local n = 0
  if type(t) == "table" then for _ in pairs(t) do n = n + 1 end end
  return n
end

local function report_efficiency_authorities(lines)
  local tp = storage and storage.tech_priests or {}
  local e0569 = tp.efficiency_economy_0569 or {}
  local dirty0569 = count_table(e0569.dirty_regions)
  lines[#lines + 1] = "[tp-runtime-report] efficiency-authorities canonical: timing=runtime_tick_broker pairs=pair_bucket_registry work=work_queue_authority claims=work_reservations execution=order_queue_0469 dirty-scan=indexed-catalog-0579 sleep=dormant-0595/adaptive-0599"
  lines[#lines + 1] = "  dirty-scaffold-0569 enabled=" .. safe(e0569.enabled) .. " dirty_regions=" .. safe(dirty0569) .. " marks=" .. safe((e0569.stats or {}).dirty_region_marks or 0) .. " pruned=" .. safe((e0569.stats or {}).dirty_regions_pruned or 0)
  local e0570 = tp.efficiency_economy_0570 or {}
  lines[#lines + 1] = "  dirty-aware-helper-0570 enabled=" .. safe(e0570.enabled) .. " negative_entries=" .. safe(count_table(e0570.negative_until)) .. " dirty_hits=" .. safe((e0570.stats or {}).dirty_region_hits or 0) .. " negative_skips=" .. safe((e0570.stats or {}).negative_source_skipped or 0)
  local e0579 = tp.efficiency_economy_0579 or {}
  local cells, entities, dirty = 0, 0, 0
  for _, sidx in pairs(e0579.surfaces or {}) do
    for _, rec in pairs(sidx.cells or {}) do cells = cells + 1; entities = entities + count_table(rec.entities) end
    dirty = dirty + count_table(sidx.dirty)
  end
  lines[#lines + 1] = "  indexed-catalog-0579 enabled=" .. safe(e0579.enabled) .. " cells=" .. safe(cells) .. " entities=" .. safe(entities) .. " dirty=" .. safe(dirty) .. " hits=" .. safe((e0579.stats or {}).area_index_hits or 0) .. " misses=" .. safe((e0579.stats or {}).area_index_miss_dirty_or_unknown or 0)
  local e0585 = tp.efficiency_economy_0585 or {}
  lines[#lines + 1] = "  dirty-coalescer-0585 enabled=" .. safe(e0585.enabled) .. " pending=" .. safe(count_table(e0585.pending)) .. " flushed=" .. safe(((e0585.stats or {}).flushed_dirty0579 or 0) + ((e0585.stats or {}).flushed_dirty0580 or 0) + ((e0585.stats or {}).flushed_record0580 or 0))
  local e0582 = tp.efficiency_economy_0582 or {}
  lines[#lines + 1] = "  idle-cache-0582 enabled=" .. safe(e0582.enabled) .. " tracked=" .. safe(count_table(e0582.pair)) .. " dispatcher_skipped=" .. safe((e0582.stats or {}).dispatcher_idle_skipped or 0) .. " legacy_skipped=" .. safe((e0582.stats or {}).legacy_idle_skipped or 0)
  local e0595 = tp.efficiency_economy_0595 or {}
  lines[#lines + 1] = "  dormant-gate-0595 sleeping=" .. safe(e0595.sleeping) .. " reason=" .. safe(e0595.reason) .. " skipped=" .. safe((e0595.stats or {}).nth_tick_skipped or 0) .. " awaken=" .. safe((e0595.stats or {}).awaken or 0)
  local e0599 = tp.efficiency_economy_0599 or {}
  lines[#lines + 1] = "  adaptive-priest-sleep-0599 enabled=" .. safe(e0599.enabled) .. " pair_states=" .. safe(count_table(e0599.pair_state)) .. " sleeps=" .. safe((e0599.stats or {}).sleep or 0) .. " wake_dirty=" .. safe((e0599.stats or {}).wake_dirty or 0)
end

local function install_command()
  if not (commands and commands.add_command) then return end
  pcall(function() if commands.remove_command then commands.remove_command("tp-runtime-report") end end)
  pcall(function()
    commands.add_command("tp-runtime-report", "Tech Priests: central runtime broker, pair bucket, and reservation/caching efficiency report.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      local r = M.root()
      local lines = {}
      local registry_keys, registry_handlers, registry_raw_warnings = registry_route_counts()
      lines[#lines + 1] = "[tp-runtime-report] broker enabled=" .. safe(r.enabled) .. " services=" .. safe(#M.services) .. " pulses=" .. safe(r.stats.pulses or 0) .. " run=" .. safe(r.stats.services_run or 0) .. " skipped_empty=" .. safe(r.stats.skipped_empty or 0) .. " skipped_sleeping=" .. safe(r.stats.skipped_sleeping or 0) .. " skipped_not_due=" .. safe(r.stats.skipped_not_due or 0) .. " skipped_disabled=" .. safe(r.stats.skipped_disabled or 0) .. " budget_exhausted=" .. safe(r.stats.budget_exhausted or 0) .. " errors=" .. safe(r.stats.errors or 0)
      lines[#lines + 1] = "[tp-runtime-report] timing-authority registry_nth_keys=" .. safe(registry_keys) .. " registry_nth_handlers=" .. safe(registry_handlers) .. " broker_services=" .. safe(#M.services) .. " direct_fallback_audit_remaining=" .. safe(direct_fallback_audit_count()) .. " raw_direct_warnings=" .. safe(registry_raw_warnings)
      lines[#lines + 1] = "[tp-runtime-report] rolling-60s run=" .. safe(M.rolling_sum("services_run", 1)) .. " errors=" .. safe(M.rolling_sum("errors", 1)) .. " path_requests=" .. safe(M.rolling_sum("path_requests", 1)) .. " active_movement_processed=" .. safe(M.rolling_sum("movement_active_requests_processed", 1)) .. " movement_budget_exhausted=" .. safe(M.rolling_sum("movement_service_budget_exhausted", 1) + M.rolling_sum("movement_sample_budget_exhausted", 1)) .. " direct_scans=" .. safe(M.rolling_sum("direct_surface_scans", 1)) .. " cache_hits=" .. safe(M.rolling_sum("indexed_cache_hits", 1)) .. " cache_misses=" .. safe(M.rolling_sum("indexed_cache_misses", 1)) .. " event_repair_submitted=" .. safe(M.rolling_sum("event_repair_submitted", 1)) .. " directed_wake=" .. safe(M.rolling_sum("directed_wake_issued", 1)) .. " negative_clears=" .. safe(M.rolling_sum("negative_cache_clears_from_event", 1))
      lines[#lines + 1] = "[tp-runtime-report] adaptive-budget-0618 boosts=" .. safe(r.stats.adaptive_budget_boosts or 0) .. " rolling_boosts=" .. safe(M.rolling_sum("adaptive_budget_boosts", 1)) .. " repair_pressure=" .. safe(pressure_value("repair")) .. " movement_pressure=" .. safe(pressure_value("movement")) .. " construction_pressure=" .. safe(pressure_value("construction")) .. " sanctify_pressure=" .. safe(pressure_value("sanctify")) .. " pickup_pressure=" .. safe(pressure_value("pickup"))
      local profiler_lines = M.profiler_report_lines(8)
      for i = 1, #profiler_lines do lines[#lines + 1] = profiler_lines[i] end
      local Rprof = rawget(_G, "TechPriestsRuntimeEventRegistry")
      if Rprof and type(Rprof.profiler_report_lines) == "function" then
        local rlines = Rprof.profiler_report_lines(8)
        for i = 1, #rlines do lines[#lines + 1] = rlines[i] end
      end
      for i = 1, #M.services do
        local svc = M.services[i]
        local ss = r.service_stats[svc.name] or {}
        lines[#lines + 1] = "  service " .. safe(svc.name) .. " cat=" .. safe(svc.category) .. " interval=" .. safe(svc.interval) .. " priority=" .. safe(svc.priority) .. " budget=" .. safe(svc.budget) .. " offered=" .. safe(ss.budget_offered or 0) .. " adaptive_boosts=" .. safe(ss.adaptive_budget_boosts or 0) .. " run=" .. safe(ss.run or 0) .. " skipped_empty=" .. safe(ss.skipped_empty or ss.empty_or_idle or 0) .. " skipped_sleeping=" .. safe(ss.skipped_sleeping or 0) .. " budget_exhausted=" .. safe(ss.budget_exhausted or 0) .. " errors=" .. safe(ss.errors or 0)
      end
      local okB, Buckets = pcall(require, "scripts.core.pair_bucket_registry")
      if okB and Buckets and Buckets.report_lines then
        local b = Buckets.report_lines()
        for i = 1, #b do lines[#lines + 1] = b[i] end
      end
      local okR, Reservations = pcall(require, "scripts.core.work_reservations")
      if okR and Reservations and Reservations.report_lines then
        local rr = Reservations.report_lines()
        for i = 1, #rr do lines[#lines + 1] = rr[i] end
      end
      local okQ, WorkQueues = pcall(require, "scripts.core.work_queue_authority")
      if okQ and WorkQueues and WorkQueues.report_lines then
        local qq = WorkQueues.report_lines()
        for i = 1, #qq do lines[#lines + 1] = qq[i] end
      end
      local xs = r.external_stats or {}
      lines[#lines + 1] = "[tp-runtime-report] scan-accounting attempted=" .. safe(xs.scans_attempted or 0) .. " redirected_to_cache=" .. safe(xs.scans_redirected_to_cache or 0) .. " cache_hits=" .. safe(xs.indexed_cache_hits or 0) .. " cache_misses=" .. safe(xs.indexed_cache_misses or 0) .. " negative_cache_skips=" .. safe(xs.negative_cache_skips or 0) .. " direct_surface_scans=" .. safe(xs.direct_surface_scans or 0) .. " estimated_scans_avoided=" .. safe((xs.indexed_cache_hits or 0) + (xs.negative_cache_skips or 0))
      lines[#lines + 1] = "[tp-runtime-report] pathing-accounting requests=" .. safe(xs.path_requests or 0) .. " collapsed=" .. safe(xs.path_requests_collapsed or 0) .. " retargets_held=" .. safe(xs.path_retargets_held or 0) .. " task_transition_held=" .. safe(xs.path_task_transition_held or 0) .. " active_processed=" .. safe(xs.movement_active_requests_processed or 0) .. " active_samples=" .. safe(xs.movement_active_samples_processed or 0) .. " movement_budget_exhausted=" .. safe((xs.movement_service_budget_exhausted or 0) + (xs.movement_sample_budget_exhausted or 0)) .. " engine_commands=" .. safe(xs.path_engine_commands or 0)
      lines[#lines + 1] = "[tp-runtime-report] event-fed-accounting repair_candidates=" .. safe(xs.event_repair_candidates or 0) .. " repair_submitted=" .. safe(xs.event_repair_submitted or 0) .. " duplicate_folded=" .. safe(xs.event_repair_duplicate_folded or 0) .. " submit_failed=" .. safe(xs.event_repair_submit_failed or 0) .. " budget_skipped=" .. safe(xs.event_repair_budget_skipped or 0) .. " construction_submitted=" .. safe(xs.event_construction_submitted or 0) .. " sanctify_submitted=" .. safe(xs.event_sanctify_submitted or 0) .. " pickup_submitted=" .. safe(xs.event_pickup_submitted or 0) .. " directed_wake=" .. safe(xs.directed_wake_issued or 0) .. " wake_construction=" .. safe(xs.directed_wake_construction_issued or 0) .. " wake_sanctify=" .. safe(xs.directed_wake_sanctify_issued or 0) .. " wake_pickup=" .. safe(xs.directed_wake_pickup_issued or 0) .. " wake_already=" .. safe(xs.directed_wake_already_awake or 0) .. " wake_no_pair=" .. safe(xs.directed_wake_no_pair or 0) .. " negative_clears=" .. safe(xs.negative_cache_clears_from_event or 0)
      local okE, EventFeeder = pcall(require, "scripts.core.event_driven_work_feeder_0608")
      if okE and EventFeeder and EventFeeder.report_lines then
        local ee = EventFeeder.report_lines()
        for i = 1, #ee do lines[#lines + 1] = ee[i] end
      end
      local okSI, SpatialInterest = pcall(require, "scripts.core.spatial_interest_0609")
      if okSI and SpatialInterest and SpatialInterest.report_lines then
        local si = SpatialInterest.report_lines()
        for i = 1, #si do lines[#lines + 1] = si[i] end
      end
      local okMV, Movement = pcall(require, "scripts.core.movement_controller")
      if okMV and Movement and Movement.report_lines then
        local mv = Movement.report_lines()
        for i = 1, #mv do lines[#lines + 1] = mv[i] end
      end
      local okSR, ScanRouting = pcall(require, "scripts.core.scan_routing_0610")
      if okSR and ScanRouting and ScanRouting.report_lines then
        local sr = ScanRouting.report_lines()
        for i = 1, #sr do lines[#lines + 1] = sr[i] end
      end
      local okTA, TaskAuspex = pcall(require, "scripts.core.task_auspex_0622")
      if okTA and TaskAuspex and TaskAuspex.report_lines then
        local ta = TaskAuspex.report_lines()
        for i = 1, #ta do lines[#lines + 1] = ta[i] end
      end
      local okCfg, RuntimeConfig = pcall(require, "scripts.core.runtime_config_0626")
      if okCfg and RuntimeConfig and RuntimeConfig.report_lines then
        local cfg = RuntimeConfig.report_lines(8)
        for i = 1, #cfg do lines[#lines + 1] = cfg[i] end
      end
      report_efficiency_authorities(lines)
      local msg = table.concat(lines, "\n")
      if player and player.valid then player.print(msg) elseif game and game.print then game.print(msg) end
    end)
  end)
end

function M.install()
  M.root()
  local cfg = rawget(_G or {}, "TechPriestsRuntimeConfig0626")
  if cfg and cfg.is_debug_enabled then
    local ok, enabled = pcall(cfg.is_debug_enabled, "profiler")
    if ok then M.set_profiler_enabled(enabled == true) end
  end
  if not M.installed then
    local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
    if not (R and type(R.on_nth_tick) == "function") then
      local ok_registry, required_registry = pcall(require, "scripts.core.runtime_event_registry")
      if ok_registry and required_registry and type(required_registry.on_nth_tick) == "function" then
        R = required_registry
      end
    end
    if R and type(R.on_nth_tick) == "function" then
      R.on_nth_tick(M.base_interval, function(event) M.pulse(event) end, { owner = "runtime_tick_broker_0600", category = "runtime", priority = "first", note = "central budgeted service broker" })
    elseif script and script.on_nth_tick then
      script.on_nth_tick(M.base_interval, function(event) M.pulse(event) end)
    end
    M.installed = true
  end
  install_command()
  _G.TechPriestsRuntimeTickBroker0600 = M
  _G.tech_priests_runtime_metric_0606 = function(metric, n) return M.note_metric(metric, n) end
  _G.tech_priests_runtime_profile_0625 = function(section, name, category, profiler, ok) return M.record_profile(section, name, category, profiler, ok) end
  _G.tech_priests_debug_output_0625 = function(channel, owner, n) return M.note_debug_output(channel, owner, n) end
  return true
end

return M
