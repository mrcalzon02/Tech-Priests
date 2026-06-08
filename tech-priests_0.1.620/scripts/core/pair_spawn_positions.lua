-- scripts/core/pair_spawn_positions.lua
-- Tech Priests 0.1.426 pair lifecycle extraction: spawn-position authority facade.
--
-- This module is intentionally conservative. It exposes one place for station
-- and priest lifecycle modules to ask for a valid priest respawn/re-imprinting
-- position without keeping that logic embedded in control.lua. Existing legacy
-- helpers are used when present; this module supplies only a safe fallback.

local M = {}
M.version = "0.1.426"

local function valid(e) return e and e.valid end
local function pos_copy(pos) return pos and { x = pos.x or pos[1] or 0, y = pos.y or pos[2] or 0 } or { x = 0, y = 0 } end

function M.station_anchor(pair)
  if valid(pair and pair.station) then return pos_copy(pair.station.position), pair.station.surface end
  if valid(pair and pair.priest) then return pos_copy(pair.priest.position), pair.priest.surface end
  return { x = 0, y = 0 }, nil
end

function M.find_priest_spawn_position(pair, radius)
  local anchor, surface = M.station_anchor(pair)
  if not surface then return anchor end

  -- Prefer the historical helper if it exists; it may already know about station
  -- footprint, collision masks, and Space Age platform restrictions.
  if _G.find_spawn_position then
    local ok, found = pcall(_G.find_spawn_position, surface, anchor, radius or 6)
    if ok and found then return found end
  end

  if surface.find_non_colliding_position then
    local proto_name = (pair and pair.priest_name) or (pair and pair.rank and pair.rank >= 3 and "senior-tech-priest") or "junior-tech-priest"
    local ok, found = pcall(function()
      return surface.find_non_colliding_position(proto_name, anchor, radius or 8, 0.5)
    end)
    if ok and found then return found end
  end

  return { x = anchor.x + 1.5, y = anchor.y + 1.5 }
end

function M.install()
  _G.TechPriestsPairSpawnPositions = M
  return true
end

return M
