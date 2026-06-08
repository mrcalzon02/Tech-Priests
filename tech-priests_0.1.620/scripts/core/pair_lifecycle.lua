-- scripts/core/pair_lifecycle.lua
-- Tech Priests 0.1.426 station/priest lifecycle extraction facade.
--
-- This is the lifecycle switchboard. It pulls identity, naming, spawn position,
-- and death/re-imprint handling into named modules so control.lua stops owning
-- paired-life behavior directly.

local M = {}
M.version = "0.1.426"
M.installed = false

function M.install()
  if M.installed then return true end
  M.installed = true

  local spawn_positions = require("scripts.core.pair_spawn_positions")
  local naming = require("scripts.core.pair_naming")
  local death_and_respawn = require("scripts.core.pair_death_and_respawn")

  if spawn_positions and spawn_positions.install then spawn_positions.install() end
  if naming and naming.install then naming.install() end
  if death_and_respawn and death_and_respawn.install then death_and_respawn.install() end

  _G.TechPriestsPairLifecycle = M
  if log then log("[Tech-Priests 0.1.426] pair lifecycle facade installed") end
  return true
end

function M.find_pair(entity)
  local death = _G.TechPriestsPairDeathAndRespawn
  if death and death.find_pair then return death.find_pair(entity) end
  return nil
end

function M.enter_reimprint(pair, priest, reason)
  local death = _G.TechPriestsPairDeathAndRespawn
  if death and death.enter_reimprint then return death.enter_reimprint(pair, priest, reason) end
  return false
end

return M
