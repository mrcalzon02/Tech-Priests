-- scripts/gui/gui_router.lua
-- Tech Priests 0.1.427 GUI routing switchboard.
--
-- This module is the runtime owner for GUI opened/closed/click dispatch.
-- control.lua and older modules may register GUI handlers here, but the actual
-- Factorio event registration is centralized through runtime_event_registry.lua.
-- The goal is to turn control.lua into a switchboard rather than another GUI
-- brain with scattered GUI event handlers.

local Router = {}
Router.version = "0.1.427"
Router.storage_key = "gui_router_0427"
Router.handlers = Router.handlers or { opened = {}, closed = {}, click = {} }
Router.installed = Router.installed or false
Router.labels = Router.labels or {}

local function has_storage()
  return type(storage) == "table"
end

local function ensure_root()
  if not has_storage() then return nil end
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[Router.storage_key] = storage.tech_priests[Router.storage_key] or {
    version = Router.version,
    stats = {},
    errors = {},
    routes = {}
  }
  local root = storage.tech_priests[Router.storage_key]
  root.version = Router.version
  root.stats = root.stats or {}
  root.errors = root.errors or {}
  root.routes = root.routes or {}
  return root
end

local function count(kind)
  local list = Router.handlers and Router.handlers[kind] or nil
  return list and #list or 0
end

local function route_name(route, index)
  if route and route.label then return tostring(route.label) end
  return "route-" .. tostring(index or "?")
end

local function remember_route(kind, route)
  local root = ensure_root()
  if not root then return end
  root.routes[kind] = root.routes[kind] or {}
  root.routes[kind][#root.routes[kind] + 1] = {
    label = route.label or "anonymous",
    registered_tick = game and game.tick or 0,
    stop_on_truthy = route.stop_on_truthy and true or false
  }
end

function Router.register(kind, handler, label, opts)
  if type(handler) ~= "function" then return false end
  kind = tostring(kind or "")
  if kind ~= "opened" and kind ~= "closed" and kind ~= "click" then return false end
  opts = opts or {}
  Router.handlers = Router.handlers or { opened = {}, closed = {}, click = {} }
  Router.handlers[kind] = Router.handlers[kind] or {}
  local route_label = label or opts.label
  if route_label then
    local key = kind .. ":" .. tostring(route_label)
    if Router.labels[key] then return true end
    Router.labels[key] = true
  end
  local route = {
    handler = handler,
    label = route_label,
    stop_on_truthy = opts.stop_on_truthy and true or false
  }
  Router.handlers[kind][#Router.handlers[kind] + 1] = route
  remember_route(kind, route)
  return true
end

local function dispatch(kind, event)
  local root = ensure_root()
  if root then
    root.stats[kind] = (root.stats[kind] or 0) + 1
    root.stats.last_kind = kind
    root.stats.last_tick = game and game.tick or 0
  end
  local routes = Router.handlers and Router.handlers[kind] or nil
  if not routes then return false end
  for index, route in ipairs(routes) do
    local ok, result = pcall(route.handler, event)
    if not ok then
      if root then
        root.stats.errors = (root.stats.errors or 0) + 1
        root.stats.last_error = tostring(result)
        root.stats.last_error_route = route_name(route, index)
        root.errors[#root.errors + 1] = {
          tick = game and game.tick or 0,
          kind = kind,
          route = route_name(route, index),
          error = tostring(result)
        }
        while #root.errors > 20 do table.remove(root.errors, 1) end
      end
      if log then log("[Tech-Priests 0.1.427 GUI router] " .. tostring(kind) .. " route " .. route_name(route, index) .. " failed: " .. tostring(result)) end
    elseif result and route.stop_on_truthy then
      return true
    end
  end
  return false
end

function Router.dispatch_opened(event) return dispatch("opened", event) end
function Router.dispatch_closed(event) return dispatch("closed", event) end
function Router.dispatch_click(event) return dispatch("click", event) end

function Router.install()
  if Router.installed then return true end
  Router.installed = true
  ensure_root()
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then
    local ok, found = pcall(require, "scripts.core.runtime_event_registry")
    if ok then registry = found end
  end
  if registry and registry.on_event and defines and defines.events then
    registry.on_event(defines.events.on_gui_opened, Router.dispatch_opened, nil, { owner = "scripts.gui.gui_router", category = "gui", note = "opened dispatcher" })
    registry.on_event(defines.events.on_gui_closed, Router.dispatch_closed, nil, { owner = "scripts.gui.gui_router", category = "gui", note = "closed dispatcher" })
    registry.on_event(defines.events.on_gui_click, Router.dispatch_click, nil, { owner = "scripts.gui.gui_router", category = "gui", note = "click dispatcher" })
  else
    if log then log("[Tech-Priests 0.1.427 GUI router] runtime_event_registry unavailable; GUI dispatchers not installed") end
  end
  return true
end

function Router.summary()
  local root = ensure_root()
  local stats = root and root.stats or {}
  return {
    version = Router.version,
    installed = Router.installed,
    opened_handlers = count("opened"),
    closed_handlers = count("closed"),
    click_handlers = count("click"),
    opened_events = stats.opened or 0,
    closed_events = stats.closed or 0,
    click_events = stats.click or 0,
    errors = stats.errors or 0,
    last_error = stats.last_error or "none",
    last_error_route = stats.last_error_route or "none"
  }
end

function Router.print_summary(player)
  if not (player and player.valid) then return end
  local s = Router.summary()
  player.print("[Tech Priests 0.1.427] GUI router installed=" .. tostring(s.installed)
    .. " opened=" .. tostring(s.opened_handlers)
    .. " closed=" .. tostring(s.closed_handlers)
    .. " click=" .. tostring(s.click_handlers)
    .. " events=" .. tostring(s.opened_events) .. "/" .. tostring(s.closed_events) .. "/" .. tostring(s.click_events)
    .. " errors=" .. tostring(s.errors)
    .. " last=" .. tostring(s.last_error_route) .. ": " .. tostring(s.last_error))
end

function Router.install_debug_command()
  local registry = rawget(_G, "TechPriestsDebugCommandRegistry")
  if not registry then
    local ok, found = pcall(require, "scripts.core.debug.debug_command_registry")
    if ok then registry = found end
  end
  if registry and registry.add then
    registry.add("tp-gui-router-0427", "Tech Priests: print GUI router route/event summary.", function(command)
      local player = command and command.player_index and game.get_player(command.player_index) or nil
      Router.print_summary(player)
    end)
  elseif commands and commands.add_command then
    pcall(function()
      commands.add_command("tp-gui-router-0427", "Tech Priests: print GUI router route/event summary.", function(command)
        local player = command and command.player_index and game.get_player(command.player_index) or nil
        Router.print_summary(player)
      end)
    end)
  end
end

return Router
