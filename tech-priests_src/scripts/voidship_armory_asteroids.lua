local names = require("scripts.voidship_armory_names")
local M = {}
local forward = {
  [defines.direction.north] = {0, -1}, [defines.direction.east] = {1, 0},
  [defines.direction.south] = {0, 1}, [defines.direction.west] = {-1, 0},
}

function M.valid(target, surface)
  return target and target.valid and target.type == "asteroid" and target.surface == surface
    and target.destructible and target.health > 0
end

function M.heading(origin, position)
  return math.deg(math.atan2(position.x - origin.x, origin.y - position.y)) % 360
end

function M.check(mount, target, range)
  if not M.valid(target, mount.surface) then return nil, "invalid-asteroid" end
  local origin, position = mount.position, target.position
  local dx, dy = position.x - origin.x, position.y - origin.y
  local distance_squared = dx * dx + dy * dy
  if distance_squared > range * range then return nil, "asteroid-range" end
  if mount.name == names.launcher then
    local nose = forward[mount.direction] or forward[defines.direction.north]
    if dx * nose[1] + dy * nose[2] < .5 * math.sqrt(distance_squared) then return nil, "asteroid-arc" end
  end
  return distance_squared
end

function M.nearest(mount, range)
  local best, best_position, nearest_distance
  for _, target in ipairs(mount.surface.find_entities_filtered{type = "asteroid", position = mount.position, radius = range}) do
    local distance = M.check(mount, target, range)
    if distance then
      local position = target.position
      if not best or distance < nearest_distance or (distance == nearest_distance
          and (position.x < best_position.x or (position.x == best_position.x and position.y < best_position.y))) then
        best, best_position, nearest_distance = target, position, distance
      end
    end
  end
  return best
end

return M
