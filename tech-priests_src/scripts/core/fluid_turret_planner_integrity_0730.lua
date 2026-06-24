-- Tech Priests 0.1.674-dev fluid-turret planner integrity guard.
--
-- Wraps the existing 0719 construction-planner integration without adding another
-- timing or construction authority. Only recently validated 0718 proposals may
-- begin a new route. Completed/aborted root plan records are pruned while per-pair
-- last-plan history remains intact. Runtime diagnostics expose wrapper activation.

local M = {
  version = "0.1.674-dev",
  storage_key = "fluid_turret_planner_integrity_0730",
  proposal_freshness_ticks = 60 * 30,
  audit_interval = 317,
}

local previous_build_install
local previous_build_service_pair

local function now() return game and game.tick or 0 end
local function valid(entity) return entity and entity.valid end
local function safe(value)
  if value == nil then return "nil" end
  local ok, text = pcall(tostring, value)
  return ok and text or "?"
end
local function valid_pair(pair) return pair and valid(pair.station) and valid(pair.priest) end
local function pair_map()
  return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  local state = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    stats = {},
    last = {},
  }
  storage.tech_priests[M.storage_key] = state
  state.version = M.version
  if state.enabled == nil then state.enabled = true end
  state.stats = state.stats or {}
  state.last = state.last or {}
  return state
end

local function stat(name, amount)
  local state = root()
  state.stats[name] = (state.stats[name] or 0) + (amount or 1)
end

local function proposal_safe(pair, proposal)
  if type(proposal) ~= "table" or proposal.integrity_0718 ~= "safe" then
    return false, "integrity-missing"
  end
  local integrity_tick = tonumber(proposal.integrity_tick_0718) or -1000000
  if now() - integrity_tick > M.proposal_freshness_ticks then
    return false, "integrity-stale"
  end
  if (tonumber(proposal.expires_tick) or 0) < now() then
    return false, "proposal-expired"
  end
  if not (valid_pair(pair) and valid(proposal.turret)
    and proposal.source and valid(proposal.source.entity))
  then
    return false, "endpoint-invalid"
  end
  if proposal.turret.surface ~= pair.station.surface
    or proposal.source.entity.surface ~= pair.station.surface
  then
    return false, "surface-mismatch"
  end
  if proposal.turret.force ~= pair.station.force
    or proposal.source.entity.force ~= pair.station.force
  then
    return false, "force-mismatch"
  end
  if not proposal.fluidbox_index or not proposal.source.fluidbox_index then
    return false, "fluidbox-identity-missing"
  end
  if #(proposal.connection_targets or {}) == 0
    or #(proposal.source.interfaces or {}) == 0
  then
    return false, "port-identity-missing"
  end
  return true, "safe"
end

local function filter_safe_proposals(pair)
  if pair.fluid_turret_pipe_plan_0719 then return 0 end
  local original = pair.fluid_turret_safe_proposals_0718
  if type(original) ~= "table" then return 0 end
  local filtered, rejected = {}, 0
  for _, proposal in ipairs(original) do
    local ok, why = proposal_safe(pair, proposal)
    if ok then
      filtered[#filtered + 1] = proposal
    else
      rejected = rejected + 1
      stat("proposal-rejected-" .. why)
    end
  end
  if rejected > 0 then pair.fluid_turret_safe_proposals_0718 = filtered end
  return rejected
end

local function planner_root()
  local tp = storage and storage.tech_priests or nil
  return tp and tp.fluid_turret_connection_planner_0719 or nil
end

local function prune_terminal_plans()
  local state = planner_root()
  if not (state and type(state.plans) == "table") then return 0 end
  local removed = 0
  for id, plan in pairs(state.plans) do
    local phase = type(plan) == "table" and tostring(plan.state or "") or "invalid"
    if phase == "complete" or phase == "aborted" or phase == "invalid" then
      state.plans[id] = nil
      removed = removed + 1
    end
  end
  if removed > 0 then stat("terminal-plans-pruned", removed) end
  return removed
end

local function patched_service_pair(pair, reason, ...)
  if root().enabled ~= false and valid_pair(pair) then
    filter_safe_proposals(pair)
  end
  local acted, why = previous_build_service_pair(pair, reason, ...)
  prune_terminal_plans()
  return acted, why
end

local function patch_build(build)
  if not (build and type(build.service_pair) == "function") then return false end
  if build.fluid_turret_planner_integrity_0730_active then return true end
  if build.fluid_turret_connection_planner_0719_active ~= true then return false end
  build.fluid_turret_planner_integrity_0730_active = true
  previous_build_service_pair = build.service_pair
  build.service_pair = patched_service_pair
  return true
end

function M.activate(build)
  local planner = rawget(_G, "TechPriestsFluidTurretConnectionPlanner0719")
    or package.loaded["scripts.core.fluid_turret_connection_planner_0719"]
  if planner and type(planner.activate) == "function" then pcall(planner.activate, build) end
  local active = patch_build(build)
  root().last.activation_tick = now()
  root().last.active = active
  return active
end

local function installation_hook(build)
  if not build then return false end
  if build.fluid_turret_planner_integrity_0730_install_wrapped then return true end
  build.fluid_turret_planner_integrity_0730_install_wrapped = true
  previous_build_install = build.install
  build.install = function(...)
    local result = type(previous_build_install) == "function"
      and previous_build_install(...) or true
    M.activate(build)
    return result
  end
  return true
end

function M.audit()
  local state = root()
  local build = package.loaded["scripts.core.construction_planner"]
  local planner = rawget(_G, "TechPriestsFluidTurretConnectionPlanner0719")
  local snapshot = {
    tick = now(),
    planner_global = planner ~= nil,
    planner_wrapper = build and build.fluid_turret_connection_planner_0719_active == true or false,
    integrity_wrapper = build and build.fluid_turret_planner_integrity_0730_active == true or false,
    terminal_pruned = prune_terminal_plans(),
  }
  snapshot.complete = snapshot.planner_global
    and snapshot.planner_wrapper and snapshot.integrity_wrapper
  state.last = snapshot
  stat("audits")
  if snapshot.complete then stat("complete-observations") else stat("incomplete-observations") end
  return snapshot
end

local function patch_diagnostics()
  local diagnostics = rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
    or rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diagnostics and type(diagnostics.pair_dump_lines) == "function") then return false end
  if diagnostics.fluid_turret_planner_integrity_0730_wrapped then return true end
  diagnostics.fluid_turret_planner_integrity_0730_wrapped = true
  local previous = diagnostics.pair_dump_lines
  diagnostics.pair_dump_lines = function(...)
    local lines = previous(...)
    lines = type(lines) == "table" and lines or {}
    local state = root()
    local last = state.last
    if not last or last.tick == nil then last = M.audit() end
    lines[#lines + 1] = "PAIR-DUMP-0468 FLUID-TURRET-PLANNER-INTEGRITY-0730 enabled="
      .. safe(state.enabled)
      .. " complete=" .. safe(last.complete)
      .. " planner_global=" .. safe(last.planner_global)
      .. " planner_wrapper=" .. safe(last.planner_wrapper)
      .. " integrity_wrapper=" .. safe(last.integrity_wrapper)
      .. " terminal_pruned=" .. safe(state.stats["terminal-plans-pruned"] or 0)
      .. " stale_rejected=" .. safe(state.stats["proposal-rejected-integrity-stale"] or 0)
      .. " expired_rejected=" .. safe(state.stats["proposal-rejected-proposal-expired"] or 0)
    return lines
  end
  return true
end

local function register_service()
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if not (broker and type(broker.register_service) == "function") then return false end
  local service = broker.register_service({
    name = "fluid_turret_planner_integrity_0730",
    category = "diagnostics",
    interval = M.audit_interval,
    priority = 995,
    budget = 1,
    dynamic_budget = false,
    note = "read-only fluid turret planner wrapper activation and terminal ledger audit",
    fn = function()
      local snapshot = M.audit()
      return not snapshot.complete, "complete=" .. safe(snapshot.complete)
    end,
  })
  return service ~= nil
end

function M.install()
  root()
  local ok, build = pcall(require, "scripts.core.construction_planner")
  if not (ok and build) then return false end
  local hook_ok = installation_hook(build)
  if rawget(_G, "TECH_PRIESTS_CONSTRUCTION_PLANNER_0338") then M.activate(build) end
  local diagnostics_ok = patch_diagnostics()
  local broker_ok = register_service()
  _G.TechPriestsFluidTurretPlannerIntegrity0730 = M
  if log then
    log("[Tech-Priests 0.1.674-dev] fluid turret planner integrity armed hook="
      .. safe(hook_ok) .. " diagnostics=" .. safe(diagnostics_ok)
      .. " broker=" .. safe(broker_ok))
  end
  return hook_ok and diagnostics_ok and broker_ok
end

return M
