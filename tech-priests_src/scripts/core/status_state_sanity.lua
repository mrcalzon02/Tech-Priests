-- scripts/core/status_state_sanity.lua
-- Tech Priests 0.1.448: prevent stale combat symbols from lingering after
-- target loss or non-hostile selection without cancelling non-combat mining lasers.

local M = { version = "0.1.448" }
M.tick_interval = 31

local function valid(e) return e and e.valid end
local function now() return game and game.tick or 0 end

local function pairs_by_station()
  return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
end

local function is_combat_mode(pair)
  local mode = tostring(pair and pair.mode or "")
  return mode == "combat" or mode == "defending" or mode == "moving-to-combat" or (pair and pair.combat_target ~= nil)
end

local function hostile(pair, target)
  if not valid(target) then return false end
  if _G.TECH_PRIESTS_COMBAT_SAFETY_0322 and _G.TECH_PRIESTS_COMBAT_SAFETY_0322.is_valid_hostile_target then
    local ok, res = pcall(_G.TECH_PRIESTS_COMBAT_SAFETY_0322.is_valid_hostile_target, pair and (pair.priest or pair.station), target)
    if ok then return res == true end
  end
  if pair and pair.station and valid(pair.station) and target.force then
    local ok, same = pcall(function() return pair.station.force == target.force end)
    if ok and same then return false end
  end
  return true
end

function M.clear_pair(pair, reason)
  if not pair then return false end
  pair.combat_target = nil
  if is_combat_mode(pair) then pair.mode = "idle" end
  if pair.active_task and pair.active_task.type == "combat" then pair.active_task = nil end
  if pair.active_task_0285 and pair.active_task_0285.type == "combat" then pair.active_task_0285 = nil end
  pair.last_combat_status_sanity_clear_0448 = { tick = now(), reason = tostring(reason or "stale-combat") }
  return true
end

function M.inspect_pair(pair)
  if not pair then return false end
  if not is_combat_mode(pair) and not pair.combat_target then return false end
  local target = pair.combat_target or pair.target
  if not hostile(pair, target) then return M.clear_pair(pair, "no-valid-hostile-target") end
  return false
end

function M.service()
  local processed, acted = 0, 0
  for _, pair in pairs(pairs_by_station()) do
    processed = processed + 1
    if M.inspect_pair(pair) then acted = acted + 1 end
  end
  return { processed = processed, acted = acted, blocked = 0, failed = 0, exhausted = false }
end

function M.wrap_status()
  if _G.classify_priest_visual_state and not _G.TECH_PRIESTS_0448_PREVIOUS_CLASSIFY_PRIEST_VISUAL_STATE then
    _G.TECH_PRIESTS_0448_PREVIOUS_CLASSIFY_PRIEST_VISUAL_STATE = _G.classify_priest_visual_state
    _G.classify_priest_visual_state = function(pair)
      local state = _G.TECH_PRIESTS_0448_PREVIOUS_CLASSIFY_PRIEST_VISUAL_STATE(pair)
      if state == "combat" then
        local target = pair and (pair.combat_target or pair.target) or nil
        if not hostile(pair, target) then return "idle" end
      end
      return state
    end
  end
end

function M.install()
  if M.installed then return true end
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then
    local ok, found = pcall(require, "scripts.core.runtime_event_registry")
    if ok then registry = found end
  end
  if not (registry and type(registry.on_nth_tick) == "function") then
    if log then log("[Tech-Priests 0.1.448] status-state sanity not installed: canonical runtime event registry unavailable") end
    return false
  end
  local cadence = registry.on_nth_tick(M.tick_interval, function()
    M.service()
  end, {
    owner = "status_state_sanity_0448",
    route = "stale-combat-status-sanity",
    category = "combat",
    priority = "late",
    note = "clear stale combat state while keeping visual classification read-only"
  })
  if not cadence then
    if log then log("[Tech-Priests 0.1.448] status-state sanity not installed: canonical cadence registration rejected") end
    return false
  end
  _G.TECH_PRIESTS_STATUS_STATE_SANITY_0448 = M
  M.wrap_status()
  M.route_owner = "runtime-event-registry"
  M.installed = true
  return true
end

return M
