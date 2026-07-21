-- Tech Priests 0.1.674-dev commandless runtime authority.
--
-- Tech Priests diagnostics are automatic. Legacy /tp-* toggle and status commands
-- can create hidden runtime configuration forks and are no longer authoritative.
-- Remove only commands confirmed as Tech Priests registrations. Historical names
-- are trusted only during the initial cleanup; later registrations require current
-- help-text ownership proof so another mod cannot lose a newly reused command name.

local M = {
  version = "0.1.674-dev",
  storage_key = "runtime_command_cleanup_0720",
  prefix = "tp-",
  audit_interval = 600,
  legacy_direct_route_cleanup_integrated = true,
}

local KNOWN_COMMANDS = {
  ["tp-direct-acquisition-0513"] = true,
  ["tp-dispatcher-0510"] = true,
  ["tp-movement-0418"] = true,
  ["tp-movement-0419"] = true,
  ["tp-movement-0429"] = true,
  ["tp-movement-bounds-0511"] = true,
  ["tp-movement-enforcement-0566"] = true,
  ["tp-void-movement-0630"] = true,
  ["tp-path-corridors-0574"] = true,
  ["tp-efficiency-economy-0572"] = true,
  ["tp-efficiency-economy-0577"] = true,
  ["tp-direct-recall-0632"] = true,
  ["tp-ground-route-0633"] = true,
  ["tp-direct-pulse-0631"] = true,
  ["tp-vanish-guard-0502"] = true,
  ["tp-pair-link-0495"] = true,
  ["tp-priest-lifecycle-0500"] = true,
  ["tp-priest-vanish-0501"] = true,
  ["tp-direct-mining-safety-0490"] = true,
  ["tp-mobility-recovery-0506"] = true,
  ["tp-movement-recovery-0508"] = true,
  ["tp-priest-recovery-0503"] = true,
  ["tp-task-pair-audit-0498"] = true,
  ["tp-behavior-0505"] = true,
  ["tp-lifecycle-0426"] = true,
  ["tp-pairstate-recover-0363"] = true,
  ["tp-armor-0302"] = true,
  ["tp-grid-0305"] = true,
  ["tp-grid-0306"] = true,
  ["tp-glow-0307"] = true,
  ["tp-glow-0308"] = true,
  ["tp-upgrades-0313"] = true,
  ["tp-gui-0310"] = true,
  ["tp-0311"] = true,
  ["tp-laser-0312"] = true,
  ["tp-debug"] = true,
  ["tp-dump-state"] = true,
  ["tp-rebuild-registries"] = true,
  ["tp-force-station-scan"] = true,
  ["tp-sweep-debug"] = true,
  ["tp-logistics-debug"] = true,
  ["tp-emergency-miner-debug"] = true,
  ["tp-assignment-debug"] = true,
  ["tp-power-chain-debug"] = true,
  ["tp-fuel-bootstrap-debug"] = true,
  ["tp-magos-planner-debug"] = true,
  ["tp-mining-0315"] = true,
  ["tp-mining-0316"] = true,
  ["tp-combat-safety-0322"] = true,
  ["tp-proxy-ammo-0649"] = true,
  ["tp-logistics-fetch-0527"] = true,
  ["tp-construction-0338"] = true,
}

local function now()
  return game and game.tick or 0
end

local function safe(value)
  if value == nil then return "nil" end
  local ok, text = pcall(tostring, value)
  return ok and text or "?"
end

local function lower(value)
  return string.lower(tostring(value or ""))
end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  local state = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    commandless = true,
    stats = {},
    recent = {},
    removed_names = {},
    initial_cleanup_complete = false,
  }
  storage.tech_priests[M.storage_key] = state
  state.version = M.version
  if state.enabled == nil then state.enabled = true end
  if state.commandless == nil then state.commandless = true end
  if state.initial_cleanup_complete == nil then state.initial_cleanup_complete = false end
  state.stats = state.stats or {}
  state.recent = state.recent or {}
  state.removed_names = state.removed_names or {}
  return state
end

local function stat(name, amount)
  local state = root()
  state.stats[name] = (state.stats[name] or 0) + (amount or 1)
end

local function localised_contains_owner(value, seen, depth)
  depth = tonumber(depth) or 0
  if depth > 20 then return false end
  local kind = type(value)
  if kind == "string" or kind == "number" or kind == "boolean" then
    local text = lower(value)
    return string.find(text, "tech priests", 1, true) ~= nil
      or string.find(text, "tech-priests", 1, true) ~= nil
      or string.find(text, "tech_priests", 1, true) ~= nil
  end
  if kind ~= "table" then return false end
  seen = seen or {}
  if seen[value] then return false end
  seen[value] = true
  for key, child in pairs(value) do
    if localised_contains_owner(key, seen, depth + 1)
      or localised_contains_owner(child, seen, depth + 1)
    then
      return true
    end
  end
  return false
end

local function belongs_to_tech_priests(name, description, initial_cleanup)
  if type(name) ~= "string" or string.sub(name, 1, #M.prefix) ~= M.prefix then
    return false
  end
  if initial_cleanup and KNOWN_COMMANDS[name] then return true end
  return localised_contains_owner(description)
end

local function command_names(initial_cleanup)
  local names = {}
  local registered
  if commands then pcall(function() registered = commands.commands end) end
  if type(registered) == "table" then
    for name, description in pairs(registered) do
      if belongs_to_tech_priests(name, description, initial_cleanup) then
        names[#names + 1] = name
      end
    end
  end
  if initial_cleanup then
    for name in pairs(KNOWN_COMMANDS) do names[#names + 1] = name end
  end
  table.sort(names)
  local unique, out = {}, {}
  for _, name in ipairs(names) do
    if not unique[name] then
      unique[name] = true
      out[#out + 1] = name
    end
  end
  return out, registered
end

function M.remove_legacy_direct_route(reason)
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then pcall(function() registry = require("scripts.core.runtime_event_registry") end) end
  local routes = registry and registry.nth_tick_routes and registry.nth_tick_routes["61"]
  if type(routes) ~= "table" then return 0, "route-unavailable" end
  local kept, removed = {}, 0
  for _, entry in ipairs(routes) do
    local source = tostring(entry.source or "")
    local line = tonumber(entry.line or 0) or 0
    if source:find("control_legacy_part_016.lua", 1, true) and line >= 820 and line <= 850 then
      removed = removed + 1
    else
      kept[#kept + 1] = entry
    end
  end
  if removed > 0 then
    registry.nth_tick_routes["61"] = kept
    local state = root()
    state.stats["legacy-direct-routes-removed"] = (state.stats["legacy-direct-routes-removed"] or 0) + removed
    state.last_route_cleanup_reason = tostring(reason or "cleanup")
    state.last_route_cleanup_tick = now()
  end
  return removed, removed > 0 and "legacy-direct-route-removed" or "legacy-direct-route-clean"
end

function M.remove_all(reason)
  local state = root()
  if state.enabled == false or state.commandless == false then return 0, "disabled" end
  if not (commands and commands.remove_command) then return 0, "command-api-unavailable" end

  local initial_cleanup = state.initial_cleanup_complete ~= true
  local names, registered = command_names(initial_cleanup)
  local removed = 0
  for _, name in ipairs(names) do
    local description = type(registered) == "table" and registered[name] or nil
    local existed = description ~= nil
    if existed and belongs_to_tech_priests(name, description, initial_cleanup) then
      local ok, did_remove = pcall(commands.remove_command, name)
      if ok and did_remove == true then
        removed = removed + 1
        state.removed_names[name] = (state.removed_names[name] or 0) + 1
        state.recent[#state.recent + 1] = {
          tick = now(),
          name = name,
          reason = tostring(reason or "cleanup"),
          initial = initial_cleanup,
        }
        while #state.recent > 80 do table.remove(state.recent, 1) end
      elseif not ok then
        stat("remove-errors")
      end
    end
  end
  state.initial_cleanup_complete = true
  stat("audits")
  if initial_cleanup then stat("initial-audits") else stat("periodic-audits") end
  if removed > 0 then stat("commands-removed", removed) end
  state.last_audit_tick = now()
  local routes_removed, route_why = M.remove_legacy_direct_route(reason)
  removed = removed + routes_removed
  state.last_removed = removed
  state.last_initial = initial_cleanup
  state.last_route_result = route_why
  return removed, removed > 0 and "removed" or "clean"
end

local function patch_diagnostics()
  local diagnostics = rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
    or rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diagnostics and type(diagnostics.pair_dump_lines) == "function") then
    return false
  end
  if diagnostics.runtime_command_cleanup_0720_wrapped then return true end
  diagnostics.runtime_command_cleanup_0720_wrapped = true
  local previous = diagnostics.pair_dump_lines
  diagnostics.pair_dump_lines = function(...)
    local lines = previous(...)
    lines = type(lines) == "table" and lines or {}
    local state = root()
    lines[#lines + 1] = "PAIR-DUMP-0468 COMMANDLESS-RUNTIME-0720 enabled="
      .. safe(state.enabled)
      .. " commandless=" .. safe(state.commandless)
      .. " initial_complete=" .. safe(state.initial_cleanup_complete)
      .. " audits=" .. safe(state.stats.audits or 0)
      .. " removed=" .. safe(state.stats["commands-removed"] or 0)
      .. " remove_errors=" .. safe(state.stats["remove-errors"] or 0)
      .. " last_removed=" .. safe(state.last_removed or 0)
      .. " last_initial=" .. safe(state.last_initial)
      .. " legacy_routes_removed=" .. safe(state.stats["legacy-direct-routes-removed"] or 0)
      .. " last_tick=" .. safe(state.last_audit_tick or 0)
    for index = math.max(1, #state.recent - 8), #state.recent do
      local event = state.recent[index]
      if event then
        lines[#lines + 1] = "PAIR-DUMP-0468 commandless.recent["
          .. safe(index) .. "] tick=" .. safe(event.tick)
          .. " name=" .. safe(event.name)
          .. " reason=" .. safe(event.reason)
          .. " initial=" .. safe(event.initial)
      end
    end
    return lines
  end
  return true
end

local function register_service()
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if not (broker and type(broker.register_service) == "function") then return false end
  local service = broker.register_service({
    name = "runtime_command_cleanup_0720",
    category = "diagnostics",
    interval = M.audit_interval,
    priority = 999,
    budget = 1,
    dynamic_budget = false,
    note = "remove late confirmed Tech Priests diagnostic commands; automatic diagnostics are authoritative",
    fn = function()
      local removed, why = M.remove_all("broker-audit")
      return removed > 0, why .. "=" .. safe(removed)
    end,
  })
  return service ~= nil
end

function M.install()
  root()
  M.remove_all("install")
  local diagnostics_ok = patch_diagnostics()
  local broker_ok = register_service()
  _G.TechPriestsRuntimeCommandCleanup0720 = M
  if log then
    log("[Tech-Priests 0.1.674-dev] commandless runtime authority armed diagnostics="
      .. safe(diagnostics_ok) .. " broker=" .. safe(broker_ok))
  end
  return diagnostics_ok and broker_ok
end

return M
