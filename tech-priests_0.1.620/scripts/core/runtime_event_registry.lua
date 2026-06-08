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
  local ok, result = pcall(entry.handler, event)
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

-- Stage 2 audit repair: expose the canonical registry under the global name
-- many late modules already probe before falling back to direct script handlers.
_G.TechPriestsRuntimeEventRegistry = Registry

return Registry
