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
  local ok_spawn, spawn_positions = pcall(require, "scripts.core.pair_spawn_positions")
  local ok_naming, naming = pcall(require, "scripts.core.pair_naming")
  if not (ok_spawn and ok_naming and spawn_positions and naming
      and type(spawn_positions.install) == "function"
      and type(naming.install) == "function") then return false end
  local spawn_ok, spawn_result = pcall(spawn_positions.install)
  if not spawn_ok or spawn_result ~= true then return false end
  local naming_ok, naming_result = pcall(naming.install)
  if not naming_ok or naming_result ~= true then return false end
  _G.TechPriestsPairLifecycle = M
  M.installed = true
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
  if not (authority and type(authority.begin_reimprint) == "function") then
    return false
  end
  local ok, accepted = pcall(authority.begin_reimprint,
    pair, priest, reason or "pair-lifecycle-facade")
  return ok and accepted == true
end

return M
