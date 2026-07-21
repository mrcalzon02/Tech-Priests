-- scripts/core/pair_lifecycle.lua
-- Canonical station/priest lifecycle facade. Spawn positioning and naming remain
-- modular; priest death and re-imprint ownership belongs to 0499/0503 while the
-- generated 0298 helpers remain presentation/state adapters only.

local M = {
  version = "0.1.674-dev",
  installed = false,
  death_wrapper_retired_0426 = true,
  reimprint_authority = "priest_lifecycle_authority_0499",
}

local function valid(entity) return entity and entity.valid end

local function lifecycle_authority()
  return rawget(_G, "TechPriestsPriestLifecycleAuthority0499")
end

function M.install()
  if M.installed then return true end
  M.installed = true
  local spawn_positions = require("scripts.core.pair_spawn_positions")
  local naming = require("scripts.core.pair_naming")
  if spawn_positions and spawn_positions.install then spawn_positions.install() end
  if naming and naming.install then naming.install() end
  _G.TechPriestsPairLifecycle = M
  if log then log("[Tech-Priests 0.1.674-dev] pair lifecycle facade installed without retired 0426 death wrapper") end
  return true
end

function M.find_pair(entity)
  if not valid(entity) then return nil end
  if type(_G.find_pair_for_entity) == "function" then
    local ok, pair = pcall(_G.find_pair_for_entity, entity)
    if ok and pair then return pair end
  end
  local tp = storage and storage.tech_priests or nil
  if tp and entity.unit_number then
    if tp.pairs_by_priest and tp.pairs_by_priest[entity.unit_number] then return tp.pairs_by_priest[entity.unit_number] end
    if tp.station_by_priest and tp.station_by_priest[entity.unit_number] and tp.pairs_by_station then
      return tp.pairs_by_station[tp.station_by_priest[entity.unit_number]]
    end
    if tp.pairs_by_station and tp.pairs_by_station[entity.unit_number] then return tp.pairs_by_station[entity.unit_number] end
  end
  return nil
end

function M.enter_reimprint(pair, priest, reason)
  local authority = lifecycle_authority()
  if authority and type(authority.begin_reimprint) == "function" then
    return authority.begin_reimprint(pair, priest, reason or "pair-lifecycle-facade")
  end
  if type(_G.tech_priests_0298_enter_reimprint) == "function" then
    local ok, result = pcall(_G.tech_priests_0298_enter_reimprint, pair, priest, reason or "pair-lifecycle-facade")
    return ok and result == true
  end
  return false
end

return M
