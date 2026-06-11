-- scripts/core/status_state_sanity.lua
-- Tech Priests 0.1.448: prevent stale combat symbols from lingering after
-- target loss or non-hostile selection without cancelling non-combat mining lasers.

local M = { version = "0.1.448" }

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
  for _, pair in pairs(pairs_by_station()) do M.inspect_pair(pair) end
end

function M.wrap_status()
  if _G.classify_priest_visual_state and not _G.TECH_PRIESTS_0448_PREVIOUS_CLASSIFY_PRIEST_VISUAL_STATE then
    _G.TECH_PRIESTS_0448_PREVIOUS_CLASSIFY_PRIEST_VISUAL_STATE = _G.classify_priest_visual_state
    _G.classify_priest_visual_state = function(pair)
      M.inspect_pair(pair)
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
  _G.TECH_PRIESTS_STATUS_STATE_SANITY_0448 = M
  M.wrap_status()
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then pcall(function() registry = require("scripts.core.runtime_event_registry") end) end
  if registry and registry.on_nth_tick then
    registry.on_nth_tick(31, function() M.service() end, { owner = "status_state_sanity", category = "combat", note = "clear stale combat display state" })
  elseif script and script.on_nth_tick then
    script.on_nth_tick(31, function() M.service() end)
  end
  return true
end

return M
