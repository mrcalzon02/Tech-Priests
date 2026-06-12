-- scripts/core/command_surface_pruner_0653.lua
-- Tech Priests 0.1.653
--
-- Command surface pruner.
--
-- During the 0.1.63x-0.1.65x repair cycle many modules gained temporary
-- /tp-* diagnostic commands.  Those were useful while isolating crashes,
-- movement drift, acquisition target churn, placement bugs, and proxy ammo bugs,
-- but most of them are not player-facing hard functions.  This module removes
-- known temporary diagnostic commands from the runtime command surface without
-- disabling the underlying repair modules.
--
-- No slash command is registered by this module.

local M = {}
M.version = "0.1.653"
M.storage_key = "command_surface_pruner_0653"
M.tick_interval = 90
M.stop_after_tick = 60 * 30

-- Keep this list intentionally broad. commands.remove_command is pcalled, so
-- absent commands are harmless. Existing behavior remains in modules; only the
-- ad-hoc command/debug entry points are removed.
M.disposable_commands = {
  -- 0630-0639 emergency/bootstrap/inventory repair diagnostics
  "tp-ground-route-0633",
  "tp-deposit-safety-0638",
  "tp-supply-satisfaction-0639",
  "tp-bootstrap-resource-0637",
  "tp-infra-first-0640",

  -- 0642-0645 behavior/infrastructure/bootstrap diagnostics
  "tp-behavior-tree-0642",
  "tp-emergency-placement-0643",
  "tp-infra-plan-0644",
  "tp-bootstrap-ghost-0645",

  -- 0649-0652 acquisition/combat/movement hardener diagnostics
  "tp-direct-physical-0649",
  "tp-proxy-ammo-0649",
  "tp-direct-lock-0650",
  "tp-movement-vector-0651",
  "tp-target-reconcile-0652",

  -- older recurring repair/debug commands that are not core player controls
  "tp-direct-acquisition-0513",
  "tp-movement-0429",
  "tp-build-0359",
  "tp-runtime-report",
  "tp-runtime-profiler",
  "tp-task-auspex",
  "tp-scan-routing-0610",
  "tp-event-feeder-0608",
  "tp-pair-buckets",
  "tp-work-queue",
  "tp-work-reservations",
  "tp-spatial-interest-0609",
  "tp-movement-authority-audit",
  "tp-combat-leftovers",
}

local function now() return game and game.tick or 0 end
local function safe(v) if v == nil then return "nil" end local ok, out = pcall(function() return tostring(v) end); return ok and out or "?" end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or { version = M.version, enabled = true, removed = {}, attempts = 0, last_tick = 0 }
  local r = storage.tech_priests[M.storage_key]
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  r.removed = r.removed or {}
  return r
end

function M.prune(reason)
  local r = root()
  if r.enabled == false or not (commands and commands.remove_command) then return 0 end
  local removed = 0
  for _, name in ipairs(M.disposable_commands) do
    local ok = pcall(function() commands.remove_command(name) end)
    r.removed[name] = (r.removed[name] or 0) + 1
    if ok then removed = removed + 1 end
  end
  r.attempts = (tonumber(r.attempts) or 0) + 1
  r.last_tick = now()
  r.last_reason = tostring(reason or "prune")
  r.last_removed_attempts = removed
  if log then log("[Tech-Priests 0.1.653] command surface pruned reason=" .. safe(reason) .. " command_names=" .. safe(#M.disposable_commands) .. " remove_attempts=" .. safe(removed)) end
  return removed
end

local function install_tick_pruner()
  local function tick()
    if now() <= M.stop_after_tick then M.prune("startup-window") end
  end
  local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if R and type(R.on_nth_tick) == "function" then
    R.on_nth_tick(M.tick_interval, tick, { owner = "command_surface_pruner_0653", category = "cleanup", priority = "late" })
  elseif script and script.on_nth_tick then
    script.on_nth_tick(M.tick_interval, tick)
  end
end

function M.install()
  root()
  _G.TechPriestsCommandSurfacePruner0653 = M
  M.prune("install")
  install_tick_pruner()
  if log then log("[Tech-Priests 0.1.653] command surface pruner installed; temporary diagnostic /tp-* commands are removed during startup") end
  return true
end

return M
