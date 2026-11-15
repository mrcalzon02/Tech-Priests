-- Sole colony placement owner. One-time starter resources, then normal paired
-- priest planning, construction, logistics, research and defense take ownership.
local M = {}
local Registry = require("scripts.core.runtime_event_registry")
local Colony = require("scripts.core.enemy_colony")
local Options = require("scripts.core.enemy_colony_options")
local NAME = "planetary-magos-cogitator-station"
-- One candidate chunk per square region: priority planets have twice the density.

local function enabled()
  local setting = settings.global["tech-priests-enemy-planetary-spawning"]
  return not setting or setting.value
end

function M.seed_chunk(surface, chunk)
  if not enabled() or not (surface and surface.valid) or surface.platform
      or (surface.peaceful_mode and Options.get("respect-peaceful",true)) then return false end
  local planet = surface.planet and surface.planet.name or surface.name
  if not Options.allowed_planet(planet)then return false end
  local size=Options.get((planet=="fulgora"or planet=="vulcanus")
    and "priority-spacing"or "other-spacing",24)
  local seed = surface.map_gen_settings.seed or 0
  local rx, ry = math.floor(chunk.x / size), math.floor(chunk.y / size)
  -- Coordinate hash avoids consuming gameplay RNG or depending on exploration order.
  local hash = (rx * 73856093 + ry * 19349663 + seed) % 2147483647
  if chunk.x % size ~= hash % size
      or chunk.y % size ~= math.floor(hash / size) % size then return false end
  local center = {x = chunk.x * 32 + 16, y = chunk.y * 32 + 16}
  local clearance=Options.get("spawn-clearance",384)
  if center.x * center.x + center.y * center.y < clearance^2 then return false end
  for _, force in pairs(game.forces) do
    if force.name ~= "enemy" and force.name ~= "neutral" then
      local spawn = force.get_spawn_position(surface)
      if (center.x-spawn.x)^2 + (center.y-spawn.y)^2 < clearance^2 then return false end
      if surface.count_entities_filtered{position = center, radius = Options.get("base-clearance",96),
          force = force, limit = 1} > 0 then return false end
    end
  end
  storage.tech_priests = storage.tech_priests or {}
  local root = storage.tech_priests
  root.enemy_planetary_seeding = root.enemy_planetary_seeding or {}
  local seeded = root.enemy_planetary_seeding[surface.index] or {}
  root.enemy_planetary_seeding[surface.index] = seeded
  local key = chunk.x .. ":" .. chunk.y
  if seeded[key] then return false end
  if not Options.admit_colony(surface,planet)then return false end
  -- Stay inside the delivered chunk: never force terrain generation or landfill.
  local position = center
  if not Colony.can_place(surface,position) then return false end
  if surface.count_entities_filtered{position = position, radius = Options.get("colony-clearance",192),
      name = NAME, limit = 1} > 0 then return false end
  local colony=Colony.create(surface,position,planet)
  if not colony then return false end
  -- Remember destruction as well as success: explored territory stays cleared.
  seeded[key] = colony
  return true
end

function M.install()
  local opts = {owner = "enemy_planetary_seeding", category = "world-generation"}
  assert(Registry.on_event(defines.events.on_chunk_generated, function(event)
    M.seed_chunk(event.surface, event.position)
  end, nil, opts), "Enemy planetary chunk-generation route unavailable")
  -- Also covers existing saves as radar/player charting revisits generated land.
  assert(Registry.on_event(defines.events.on_chunk_charted, function(event)
    M.seed_chunk(game.surfaces[event.surface_index], event.position)
  end, nil, opts), "Enemy planetary chart route unavailable")
  assert(Registry.on_event(defines.events.on_surface_deleted, function(event)
    local root = storage.tech_priests
    if root and root.enemy_planetary_seeding then
      root.enemy_planetary_seeding[event.surface_index] = nil
    end
  end, nil, opts), "Enemy planetary surface-deletion route unavailable")
  return true
end
return M
