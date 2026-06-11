-- scripts/core/pair_naming.lua
-- Tech Priests 0.1.426 pair lifecycle extraction: naming facade.
--
-- Names are part of pair identity, not movement/combat/crafting behavior. This
-- facade gives lifecycle code one place to refresh display names without owning
-- the older train-station-style name generator yet.

local M = {}
M.version = "0.1.426"

local function valid(e) return e and e.valid end
local function safe_tostring(v)
  local ok, out = pcall(function() return tostring(v) end)
  if ok then return out end
  return "?"
end

function M.station_name(pair)
  if _G.tech_priests_station_name_0189 then
    local ok, name = pcall(_G.tech_priests_station_name_0189, pair)
    if ok and name then return name end
  end
  if valid(pair and pair.station) then return safe_tostring(pair.station.backer_name or pair.station.name) end
  return "Cogitator Station"
end

function M.priest_name(pair)
  if _G.tech_priests_pair_name_0189 then
    local ok, name = pcall(_G.tech_priests_pair_name_0189, pair)
    if ok and name then return name end
  end
  if valid(pair and pair.priest) then return safe_tostring(pair.priest.backer_name or pair.priest.name) end
  return "Tech-Priest"
end

function M.refresh(pair, reason)
  if _G.apply_pair_display_names then
    local ok = pcall(_G.apply_pair_display_names, pair, reason or "pair-naming-0426")
    if ok then return true end
  end
  return false
end

function M.install()
  _G.TechPriestsPairNaming = M
  return true
end

return M
