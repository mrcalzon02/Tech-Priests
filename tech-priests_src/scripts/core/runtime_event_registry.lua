-- Tech Priests runtime event registry.
-- 0.1.425: event/nth-tick switchboard with dispatcher ownership.
--
-- This module is the single runtime surface that should touch script.on_event,
-- script.on_nth_tick, and script.on_init during the current control.lua cleanup
-- series. Legacy handlers may still live in control.lua, but registration now
-- goes through this auditable dispatcher.
--
-- Important Factorio rule: a given event id or nth-tick cadence can only have
-- one active handler in script.on_event/script.on_nth_tick. Earlier append-only
-- patch layers could silently replace each other. The registry now keeps a list
-- of registered handlers for each event/cadence and installs one dispatcher that
-- calls them in registered order. Passing nil as the handler clears that route.

local Registry = {}

Registry.events = Registry.events or {}
Registry.nth_ticks = Registry.nth_ticks or {}
Registry.event_routes = Registry.event_routes or {}
Registry.nth_tick_routes = Registry.nth_tick_routes or {}
Registry.init_handlers = Registry.init_handlers or {}
Registry.configuration_changed_handlers = Registry.configuration_changed_handlers or {}
Registry.installed_configuration_changed = Registry.installed_configuration_changed or false
Registry.installed_events = Registry.installed_events or {}
Registry.installed_nth_ticks = Registry.installed_nth_ticks or {}
Registry.installed_init = Registry.installed_init or false

local function safe_string(value)
  if value == nil then return "" end
  return tostring(value)
end
local function safe(value)
  if value == nil then return "nil" end
  local ok, out = pcall(function() return tostring(value) end)
  return ok and out or "?"
end

local function count_table_0625(t)
  local n = 0
  if type(t) == "table" then for _ in pairs(t) do n = n + 1 end end
  return n
end

local function profiler_root_0625()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests.runtime_event_registry_profiler_0625 or { enabled = true, routes = {}, recent = {}, debug_output = {} }
  storage.tech_priests.runtime_event_registry_profiler_0625 = r
  if r.enabled == nil then r.enabled = true end
  r.routes = r.routes or {}
  r.recent = r.recent or {}
  r.debug_output = r.debug_output or {}
  return r
end

local function registry_profiler_enabled_0625()
  local cfg = rawget(_G or {}, "TechPriestsRuntimeConfig0626")
  if cfg and cfg.is_debug_enabled then
    local ok, enabled = pcall(cfg.is_debug_enabled, "profiler")
    if ok then return enabled == true end
  end
  local r = profiler_root_0625()
  return r.enabled ~= false
end

local function start_profiler_0625()
  if not registry_profiler_enabled_0625() then return nil end
  if not (game and game.create_profiler) then return nil end
  local ok, profiler = pcall(function() return game.create_profiler(false) end)
  if ok then return profiler end
  return nil
end

local function profiler_ms_0625(profiler)
  if not profiler then return nil, "" end
  local text = safe(profiler)
  local n = text:match("([%d%.]+)")
  return tonumber(n), text
end

local function route_profile_key_0625(entry)
  if not entry then return "registry:?" end
  local section = entry.tick and ("nth:" .. tostring(entry.tick)) or (entry.event and ("event:" .. tostring(entry.event)) or "registry")
  return section .. ":" .. tostring(entry.owner or "?") .. ":" .. tostring(entry.source or "?") .. ":" .. tostring(entry.line or 0)
end

local function record_route_profile_0625(entry, profiler, ok)
  local r = profiler_root_0625()
  local ms, text = profiler_ms_0625(profiler)
  local key = route_profile_key_0625(entry)
  local rec = r.routes[key] or {
    key = key,
    section = entry and (entry.tick and ("nth:" .. tostring(entry.tick)) or (entry.event and ("event:" .. tostring(entry.event)) or "registry")) or "registry",
    owner = tostring(entry and entry.owner or "?"),
    category = tostring(entry and entry.category or "?"),
    source = tostring(entry and entry.source or "?"),
    line = tonumber(entry and entry.line or 0) or 0,
    calls = 0,
    total_ms = 0,
    worst_ms = 0,
    errors = 0,
    last_text = "",
  }
  rec.calls = (rec.calls or 0) + 1
  if ok == false then rec.errors = (rec.errors or 0) + 1 end
  rec.last_text = text or ""
  if ms then
    rec.last_ms = ms
    rec.total_ms = (rec.total_ms or 0) + ms
    if ms > (rec.worst_ms or 0) then rec.worst_ms = ms; rec.worst_tick = game and game.tick or 0 end
    rec.avg_ms = rec.total_ms / math.max(1, rec.calls or 1)
  end
  r.routes[key] = rec
  r.recent[#r.recent + 1] = { tick = game and game.tick or 0, key = key, ms = rec.last_ms, text = rec.last_text, ok = ok ~= false }
  while #r.recent > 80 do table.remove(r.recent, 1) end
  if _G and _G.tech_priests_runtime_profile_0625 then
    pcall(_G.tech_priests_runtime_profile_0625, "registry", rec.section .. ":" .. rec.owner, rec.category, profiler, ok)
  end
  return rec
end

function RegistryProfiler0625_report_lines(limit)
  local r = profiler_root_0625()
  local lines = {}
  lines[#lines + 1] = "[tp-runtime-report] registry-profiler-0625 enabled=" .. safe(r.enabled ~= false) .. " tracked=" .. safe(count_table_0625(r.routes))
  local top = {}
  for _, rec in pairs(r.routes or {}) do top[#top + 1] = rec end
  table.sort(top, function(a, b)
    local aw = tonumber(a.worst_ms or 0) or 0
    local bw = tonumber(b.worst_ms or 0) or 0
    if aw == bw then return tostring(a.owner) < tostring(b.owner) end
    return aw > bw
  end)
  if #top == 0 then
    lines[#lines + 1] = "  registry top-slowest: no samples yet"
  else
    for i = 1, math.min(#top, tonumber(limit or 8) or 8) do
      local rec = top[i]
      lines[#lines + 1] = "  registry-slow[" .. safe(i) .. "] " .. safe(rec.section) .. " owner=" .. safe(rec.owner) .. " cat=" .. safe(rec.category) .. " calls=" .. safe(rec.calls or 0) .. " avg_ms=" .. safe(rec.avg_ms or 0) .. " worst_ms=" .. safe(rec.worst_ms or 0) .. " errors=" .. safe(rec.errors or 0) .. " src=" .. safe(rec.source) .. ":" .. safe(rec.line) .. " last=" .. safe(rec.last_text or "")
    end
  end
  return lines
end


local function event_key(event_id)
  if type(event_id) == "table" then
    local parts = {}
    for i, value in ipairs(event_id) do
      parts[#parts + 1] = tostring(value)
    end
    return "{" .. table.concat(parts, ",") .. "}"
  end
  return tostring(event_id)
end

local function caller_info()
  if not debug or not debug.getinfo then return "unknown", 0 end
  local info = debug.getinfo(3, "Sl") or debug.getinfo(2, "Sl")
  if not info then return "unknown", 0 end
  return safe_string(info.short_src or info.source or "unknown"), tonumber(info.currentline or 0) or 0
end

local function normalize_opts(opts)
  if type(opts) ~= "table" then opts = {} end
  local src, line = caller_info()
  return {
    owner = safe_string(opts.owner or opts.module or "legacy-control"),
    category = safe_string(opts.category or "uncategorized"),
    note = safe_string(opts.note or ""),
    source = safe_string(opts.source or src),
    line = tonumber(opts.line or line) or 0,
    priority = safe_string(opts.priority or "normal"),
    stop_on_truthy = opts.stop_on_truthy and true or false
  }
end

local function call_handler(entry, event)
  if not entry or type(entry.handler) ~= "function" then return nil end
  local profiler = start_profiler_0625()
  local ok, result = pcall(entry.handler, event)
  if profiler and profiler.stop then pcall(function() profiler.stop() end) end
  record_route_profile_0625(entry, profiler, ok)
  if not ok then
    error("[Tech Priests event registry] handler failure owner=" .. safe_string(entry.owner)
      .. " category=" .. safe_string(entry.category)
      .. " source=" .. safe_string(entry.source) .. ":" .. safe_string(entry.line)
      .. " :: " .. safe_string(result), 0)
  end
  return result
end

local function ensure_event_dispatcher(event_id, filters)
  local key = event_key(event_id)
  if Registry.installed_events[key] then return end
  Registry.installed_events[key] = true

  if not (script and script.on_event) then return end

  script.on_event(event_id, function(event)
    local route = Registry.event_routes[key]
    if not route then return end
    for i = 1, #route do
      local handled = call_handler(route[i], event)
      if handled and route[i] and route[i].stop_on_truthy then return end
    end
  end, filters)
end

local function ensure_nth_tick_dispatcher(tick)
  local key = tostring(tick)
  if Registry.installed_nth_ticks[key] then return end
  Registry.installed_nth_ticks[key] = true

  if not (script and script.on_nth_tick) then return end

  script.on_nth_tick(tick, function(event)
    local route = Registry.nth_tick_routes[key]
    if not route then return end
    -- 0.1.595 dormant-mode gate: when no Tech-Priest runtime assets exist yet,
    -- do not wake the entire nth-tick service lattice. Events still run, so
    -- placing/unlocking/creating relevant entities can awaken the runtime.
    if _G and _G.tech_priests_should_run_nth_tick_0595 then
      local ok, allowed = pcall(_G.tech_priests_should_run_nth_tick_0595, tonumber(tick) or tick, route, event)
      if ok and allowed == false then return end
    end
    for i = 1, #route do
      local entry = route[i]
      local run_entry = true
      if _G and _G.tech_priests_route_budget_0598 then
        local ok, allowed = pcall(_G.tech_priests_route_budget_0598, entry, event, tonumber(tick) or tick)
        if ok and allowed == false then run_entry = false end
      end
      if run_entry then
        local handled = call_handler(entry, event)
        if handled and entry and entry.stop_on_truthy then return end
      end
    end
  end)
end

function Registry.on_event(event_id, handler, filters, opts)
  if type(event_id) == "table" and handler ~= nil then
    local result = nil
    for _, id in ipairs(event_id) do
      result = Registry.on_event(id, handler, filters, opts)
    end
    return result
  end

  local key = event_key(event_id)
  if handler == nil then
    Registry.event_routes[key] = nil
    Registry.events[#Registry.events + 1] = {
      event = key,
      action = "clear",
      registered_order = #Registry.events + 1
    }
    if script and script.on_event then script.on_event(event_id, nil) end
    Registry.installed_events[key] = nil
    return nil
  end

  local meta = normalize_opts(opts)
  local entry = {
    event = key,
    raw_event = event_id,
    handler = handler,
    handler_type = type(handler),
    has_filters = filters ~= nil,
    registered_order = #Registry.events + 1,
    owner = meta.owner,
    category = meta.category,
    note = meta.note,
    source = meta.source,
    line = meta.line,
    priority = meta.priority,
    stop_on_truthy = meta.stop_on_truthy
  }

  Registry.events[#Registry.events + 1] = entry
  Registry.event_routes[key] = Registry.event_routes[key] or {}
  if meta.priority == "first" or meta.priority == "front" then
    table.insert(Registry.event_routes[key], 1, entry)
  else
    Registry.event_routes[key][#Registry.event_routes[key] + 1] = entry
  end
  ensure_event_dispatcher(event_id, filters)
  return entry
end

function Registry.on_nth_tick(tick, handler, opts)
  local key = tostring(tick)

  if handler == nil then
    Registry.nth_tick_routes[key] = nil
    Registry.nth_ticks[#Registry.nth_ticks + 1] = {
      tick = tick,
      action = "clear",
      registered_order = #Registry.nth_ticks + 1
    }
    if script and script.on_nth_tick then script.on_nth_tick(tick, nil) end
    Registry.installed_nth_ticks[key] = nil
    return nil
  end

  local meta = normalize_opts(opts)
  local entry = {
    tick = tick,
    handler = handler,
    handler_type = type(handler),
    registered_order = #Registry.nth_ticks + 1,
    owner = meta.owner,
    category = meta.category,
    note = meta.note,
    source = meta.source,
    line = meta.line,
    priority = meta.priority,
    stop_on_truthy = meta.stop_on_truthy
  }

  Registry.nth_ticks[#Registry.nth_ticks + 1] = entry
  Registry.nth_tick_routes[key] = Registry.nth_tick_routes[key] or {}
  if meta.priority == "first" or meta.priority == "front" then
    table.insert(Registry.nth_tick_routes[key], 1, entry)
  else
    Registry.nth_tick_routes[key][#Registry.nth_tick_routes[key] + 1] = entry
  end
  ensure_nth_tick_dispatcher(tick)
  return entry
end

function Registry.on_init(handler, opts)
  if handler == nil then
    Registry.init_handlers = {}
    return nil
  end
  local meta = normalize_opts(opts)
  Registry.init_handlers[#Registry.init_handlers + 1] = {
    handler = handler,
    handler_type = type(handler),
    registered_order = #Registry.init_handlers + 1,
    owner = meta.owner,
    category = meta.category,
    note = meta.note,
    source = meta.source,
    line = meta.line
  }

  if not Registry.installed_init and script and script.on_init then
    Registry.installed_init = true
    script.on_init(function(event)
      for i = 1, #Registry.init_handlers do
        call_handler(Registry.init_handlers[i], event)
      end
    end)
  end
end


function Registry.on_configuration_changed(handler, opts)
  if handler == nil then
    Registry.configuration_changed_handlers = {}
    return nil
  end
  local meta = normalize_opts(opts)
  Registry.configuration_changed_handlers[#Registry.configuration_changed_handlers + 1] = {
    handler = handler,
    handler_type = type(handler),
    registered_order = #Registry.configuration_changed_handlers + 1,
    owner = meta.owner,
    category = meta.category,
    note = meta.note,
    source = meta.source,
    line = meta.line
  }

  if not Registry.installed_configuration_changed and script and script.on_configuration_changed then
    Registry.installed_configuration_changed = true
    script.on_configuration_changed(function(event)
      for i = 1, #Registry.configuration_changed_handlers do
        call_handler(Registry.configuration_changed_handlers[i], event)
      end
    end)
  end
end

function Registry.get_events()
  return Registry.events
end

function Registry.get_nth_ticks()
  return Registry.nth_ticks
end

function Registry.get_event_routes()
  return Registry.event_routes
end

function Registry.get_nth_tick_routes()
  return Registry.nth_tick_routes
end

function Registry.count_event_handlers()
  local count = 0
  for _, route in pairs(Registry.event_routes or {}) do
    count = count + #route
  end
  return count
end

function Registry.count_nth_tick_handlers()
  local count = 0
  for _, route in pairs(Registry.nth_tick_routes or {}) do
    count = count + #route
  end
  return count
end

function Registry.profiler_report_lines(limit)
  return RegistryProfiler0625_report_lines(limit)
end

function Registry.set_profiler_enabled(enabled)
  local r = profiler_root_0625()
  r.enabled = enabled ~= false
  return r.enabled
end

function Registry.print_summary(player)
  if not (player and player.valid) then return end
  player.print("[Tech Priests] Event route keys: " .. tostring(table_size and table_size(Registry.event_routes or {}) or "?"))
  player.print("[Tech Priests] Event handlers: " .. tostring(Registry.count_event_handlers()))
  player.print("[Tech Priests] Nth-tick route keys: " .. tostring(table_size and table_size(Registry.nth_tick_routes or {}) or "?"))
  player.print("[Tech Priests] Nth-tick handlers: " .. tostring(Registry.count_nth_tick_handlers()))
  player.print("[Tech Priests] Init handlers: " .. tostring(#(Registry.init_handlers or {})))
  player.print("[Tech Priests] Configuration-change handlers: " .. tostring(#(Registry.configuration_changed_handlers or {})))

  local shown = 0
  for key, route in pairs(Registry.event_routes or {}) do
    shown = shown + 1
    player.print("  event " .. tostring(key) .. " handlers=" .. tostring(#route))
    if shown >= 8 then break end
  end
  shown = 0
  for key, route in pairs(Registry.nth_tick_routes or {}) do
    shown = shown + 1
    player.print("  nth " .. tostring(key) .. " handlers=" .. tostring(#route))
    if shown >= 8 then break end
  end
end

return Registry
