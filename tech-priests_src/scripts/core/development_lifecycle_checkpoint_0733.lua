-- Tech Priests 0.1.674-dev lifecycle and migration checkpoint.
--
-- Persistent storage is restored after control.lua evaluation. Register lifecycle
-- callbacks through the canonical runtime event registry, then create/audit
-- persistent development state only from on_init, on_configuration_changed, or a
-- safe runtime broker pulse. The source-revision fallback supports development
-- source testing while info.json deliberately remains at the 0.1.672 baseline.
-- No on_load writes and no independent script event ownership are introduced.

local M = {
  version = "0.1.674-dev",
  source_revision = "0.1.674-dev-lifecycle-0733-a",
  storage_key = "development_lifecycle_checkpoint_0733",
  audit_interval = 601,
  owner = "development_lifecycle_checkpoint_0733",
}

local function now() return game and game.tick or 0 end
local function safe(value)
  if value == nil then return "nil" end
  local ok, text = pcall(tostring, value)
  return ok and text or "?"
end

local function persistent_root()
  storage.tech_priests = storage.tech_priests or {}
  local state = storage.tech_priests[M.storage_key] or {
    version = M.version,
    source_revision = nil,
    enabled = true,
    stats = {},
    recent = {},
    last = {},
  }
  storage.tech_priests[M.storage_key] = state
  state.version = M.version
  if state.enabled == nil then state.enabled = true end
  state.stats = state.stats or {}
  state.recent = state.recent or {}
  state.last = state.last or {}
  return state
end

local function stat(state, name, amount)
  state.stats[name] = (state.stats[name] or 0) + (amount or 1)
end

local function copy_failures(failures)
  local out = {}
  for _, failure in ipairs(failures or {}) do
    out[#out + 1] = {
      module = tostring(failure.module or "unknown"),
      label = tostring(failure.label or failure.module or "unknown"),
      reason = tostring(failure.reason or "unknown"),
    }
  end
  return out
end

local function installation_snapshot()
  local constraints = rawget(_G, "TechPriestsPlanningConstraints0646")
  if not constraints then
    return {
      available = false,
      complete = false,
      attempted = 0,
      passed = 0,
      failed = 1,
      failures = {
        {
          module = "scripts.core.planning_constraints_0646",
          label = "planning_constraints_0646",
          reason = "module-global-missing",
        },
      },
    }
  end
  local failures = copy_failures(constraints.install_failures)
  return {
    available = true,
    complete = constraints.install_complete == true and #failures == 0,
    attempted = tonumber(constraints.install_attempted) or 0,
    passed = tonumber(constraints.install_passed) or 0,
    failed = #failures,
    failures = failures,
  }
end

local function registry_snapshot()
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
    or package.loaded["scripts.core.runtime_event_registry"]
  local init_count, configuration_count = 0, 0
  for _, entry in ipairs(registry and registry.init_handlers or {}) do
    if entry.owner == M.owner then init_count = init_count + 1 end
  end
  for _, entry in ipairs(registry and registry.configuration_changed_handlers or {}) do
    if entry.owner == M.owner then configuration_count = configuration_count + 1 end
  end
  return {
    available = registry ~= nil,
    init_count = init_count,
    configuration_count = configuration_count,
    complete = registry ~= nil and init_count == 1 and configuration_count == 1,
  }
end

local function mod_change_snapshot(event)
  local changes = event and event.mod_changes or nil
  local own = type(changes) == "table" and changes["tech-priests"] or nil
  return {
    old_version = own and tostring(own.old_version or "") or nil,
    new_version = own and tostring(own.new_version or "") or nil,
    mod_change_present = own ~= nil,
  }
end

local function call_audit(module_global, module_path, method)
  local module = rawget(_G, module_global) or package.loaded[module_path]
  if not module then
    local ok, loaded = pcall(require, module_path)
    if ok then module = loaded end
  end
  if not (module and type(module[method]) == "function") then
    return { available = false, ok = false, detail = "method-unavailable" }
  end
  local ok, first, second = pcall(module[method])
  return {
    available = true,
    ok = ok,
    first = type(first) == "table" and first or safe(first),
    second = safe(second),
    error = ok and nil or safe(first),
  }
end

function M.checkpoint(reason, event)
  local state = persistent_root()
  if state.enabled == false then return false, "disabled" end

  local installation = installation_snapshot()
  local registry = registry_snapshot()
  local change = mod_change_snapshot(event)

  local hardener = call_audit(
    "TechPriestsHardenerInstallationAudit0723",
    "scripts.core.hardener_installation_audit_0723",
    "inspect"
  )
  local broker = call_audit(
    "TechPriestsBrokerRegistryIntegrity0725",
    "scripts.core.broker_registry_integrity_0725",
    "audit"
  )
  local planner = call_audit(
    "TechPriestsFluidTurretPlannerIntegrity0730",
    "scripts.core.fluid_turret_planner_integrity_0730",
    "audit"
  )
  local integration = call_audit(
    "TechPriestsDevelopmentIntegrationAudit0721",
    "scripts.core.development_integration_audit_0721",
    "audit_all"
  )
  local commandless = call_audit(
    "TechPriestsRuntimeCommandCleanup0720",
    "scripts.core.runtime_command_cleanup_0720",
    "remove_all"
  )

  state.source_revision = M.source_revision
  state.last = {
    tick = now(),
    reason = tostring(reason or "runtime"),
    source_revision = M.source_revision,
    installation = installation,
    registry = registry,
    mod_change = change,
    audits = {
      hardener = hardener,
      broker = broker,
      planner = planner,
      integration = integration,
      commandless = commandless,
    },
  }
  state.recent[#state.recent + 1] = {
    tick = state.last.tick,
    reason = state.last.reason,
    source_revision = M.source_revision,
    install_complete = installation.complete,
    install_failed = installation.failed,
    registry_complete = registry.complete,
    old_version = change.old_version,
    new_version = change.new_version,
  }
  while #state.recent > 40 do table.remove(state.recent, 1) end

  stat(state, "checkpoints")
  stat(state, "reason-" .. state.last.reason)
  if installation.complete then stat(state, "installation-complete")
  else stat(state, "installation-incomplete") end
  if registry.complete then stat(state, "registry-complete")
  else stat(state, "registry-incomplete") end

  local complete = installation.complete and registry.complete
    and hardener.ok and broker.ok and planner.ok and integration.ok and commandless.ok
  state.last.complete = complete
  if complete then stat(state, "complete") else stat(state, "incomplete") end
  return complete, state.last
end

local function lifecycle_handler(reason)
  return function(event)
    return M.checkpoint(reason, event)
  end
end

local function register_lifecycle()
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then
    local ok, loaded = pcall(require, "scripts.core.runtime_event_registry")
    if ok then registry = loaded end
  end
  if not (registry and type(registry.on_init) == "function"
    and type(registry.on_configuration_changed) == "function")
  then
    return false, false
  end

  registry.on_init(lifecycle_handler("on-init"), {
    owner = M.owner,
    category = "lifecycle",
    note = "post-storage development integration checkpoint",
  })
  registry.on_configuration_changed(lifecycle_handler("configuration-changed"), {
    owner = M.owner,
    category = "lifecycle",
    note = "post-storage development migration checkpoint",
  })
  return true, true
end

local function patch_diagnostics()
  local diagnostics = rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
    or rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diagnostics and type(diagnostics.pair_dump_lines) == "function") then return false end
  if diagnostics.development_lifecycle_checkpoint_0733_wrapped then return true end
  diagnostics.development_lifecycle_checkpoint_0733_wrapped = true
  local previous = diagnostics.pair_dump_lines
  diagnostics.pair_dump_lines = function(...)
    local lines = previous(...)
    lines = type(lines) == "table" and lines or {}
    local state = persistent_root()
    local last = state.last or {}
    local install = last.installation or {}
    local registry = last.registry or registry_snapshot()
    local change = last.mod_change or {}
    lines[#lines + 1] = "PAIR-DUMP-0468 DEVELOPMENT-LIFECYCLE-0733 enabled="
      .. safe(state.enabled)
      .. " source_revision=" .. safe(state.source_revision or "unseen")
      .. " checkpoints=" .. safe(state.stats.checkpoints or 0)
      .. " last_reason=" .. safe(last.reason or "none")
      .. " complete=" .. safe(last.complete == true)
      .. " install_complete=" .. safe(install.complete == true)
      .. " install_failed=" .. safe(install.failed or 0)
      .. " registry_complete=" .. safe(registry.complete == true)
      .. " init_handlers=" .. safe(registry.init_count or 0)
      .. " configuration_handlers=" .. safe(registry.configuration_count or 0)
      .. " old_version=" .. safe(change.old_version or "none")
      .. " new_version=" .. safe(change.new_version or "none")
      .. " on_load_writes=0"
    return lines
  end
  return true
end

local function register_service()
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if not (broker and type(broker.register_service) == "function") then return false end
  local service = broker.register_service({
    name = "development_lifecycle_checkpoint_0733",
    category = "diagnostics",
    interval = M.audit_interval,
    priority = 994,
    budget = 1,
    dynamic_budget = false,
    note = "post-storage init configuration-change and source-revision checkpoint",
    fn = function()
      local state = persistent_root()
      if state.source_revision ~= M.source_revision then
        local complete, detail = M.checkpoint("source-revision-change", nil)
        return not complete, "checkpoint=" .. safe(detail and detail.reason or "source-revision-change")
      end
      local registry = registry_snapshot()
      local installation = installation_snapshot()
      local complete = registry.complete and installation.complete
        and state.last and state.last.complete == true
      return not complete, "complete=" .. safe(complete)
        .. " checkpoints=" .. safe(state.stats.checkpoints or 0)
    end,
  })
  return service ~= nil
end

function M.install()
  local init_ok, configuration_ok = register_lifecycle()
  local diagnostics_ok = patch_diagnostics()
  local broker_ok = register_service()
  _G.TechPriestsDevelopmentLifecycleCheckpoint0733 = M
  if log then
    log("[Tech-Priests 0.1.674-dev] development lifecycle checkpoint armed init="
      .. safe(init_ok) .. " configuration=" .. safe(configuration_ok)
      .. " diagnostics=" .. safe(diagnostics_ok) .. " broker=" .. safe(broker_ok)
      .. " control_storage_writes=0 on_load_writes=0")
  end
  return init_ok and configuration_ok and diagnostics_ok and broker_ok
end

return M
