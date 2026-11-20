-- Module-local, bounded-age configuration snapshots for enemy planetary seeding.
-- Never persist LuaSurface objects or cache active colony counts/admission.
local M = { refresh_ticks = 600 }
local by_surface = {}

function M.for_surface(surface, Options)
  local tick = game and game.tick or 0
  local index = surface and surface.index
  if index == nil then return nil end
  local rec = by_surface[index]
  if rec and rec.surface == surface and tick >= rec.tick
      and tick - rec.tick < M.refresh_ticks then
    return rec
  end
  local planet = surface.planet and surface.planet.name or surface.name
  local priority = planet == "fulgora" or planet == "vulcanus"
  local created = {
    tick = tick,
    surface = surface,
    planet = planet,
    allowed = Options.allowed_planet(planet),
    spacing = Options.get(priority and "priority-spacing" or "other-spacing", 24),
    seed = surface.map_gen_settings.seed or 0,
    respect_peaceful = Options.get("respect-peaceful", true),
    spawn_clearance = Options.get("spawn-clearance", 384),
    base_clearance = Options.get("base-clearance", 96),
    colony_clearance = Options.get("colony-clearance", 192),
  }
  by_surface[index] = created
  return created
end

function M.invalidate(surface_index)
  if surface_index ~= nil then by_surface[surface_index] = nil end
end

function M.invalidate_all()
  by_surface = {}
end

return M
