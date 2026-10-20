-- Lua 5.2 regression: three seconds of sustained wrong-direction, off-route
-- position, or stalled navigation may recover only onto a legal forward
-- waypoint. The active movement request and carried materials survive.
package.path = "tech-priests_src/?.lua;tech-priests_src/?/init.lua;" .. package.path
game = { tick = 1000 }
storage = { tech_priests = { pairs_by_station = {} } }
defines = { command = { stop = 1, go_to_location = 2 },
  distraction = { none = 0, by_enemy = 1 } }
_G.TechPriestsPairBucketRegistry0600 = { force_bucket = function() end }
local Movement = require("scripts.core.movement_controller")
local teleports = 0
local function check(value, message)
  if not value then error("movement-waypoint-recovery: " .. message, 2) end
end
local function pair_at(id, x, y, blocked)
  local surface = { index = id }
  surface.can_place_entity = function() return not blocked end
  surface.find_non_colliding_position = function(_, pos)
    return blocked and nil or { x = pos.x, y = pos.y }
  end
  local force = { index = 1 }
  local station = { valid = true, name = "junior-cogitator-station",
    unit_number = id, position = { x = x, y = y },
    surface = surface, force = force }
  local commandable = { valid = true, issued = {} }
  commandable.set_command = function(command)
    commandable.issued[#commandable.issued + 1] = command
  end
  local priest = { valid = true, name = "tech-priests-test-priest",
    unit_number = id + 500, position = { x = x, y = y },
    surface = surface, force = force, commandable = commandable }
  priest.teleport = function(position)
    teleports = teleports + 1
    priest.position = { x = position.x, y = position.y }
    return true
  end
  local pair = { station = station, priest = priest,
    station_unit = id, radius = 35 }
  storage.tech_priests.pairs_by_station[id] = pair
  return pair
end
local function begin(pair, destination, owner, reason)
  local ok = Movement.request(pair, destination, reason or "test-travel", {
    owner = owner or "direct-acquisition-0513", priority = 650,
    ttl = 1200, radius = 0.25 })
  check(ok == true, "could not establish test route")
  Movement.service(nil, 24)
  check(pair.movement_request_0418 and
    pair.movement_request_0418.last_command_tick == game.tick,
    "native movement command was not issued")
  return pair.movement_request_0418
end
local function step(pair, tick, x, y)
  game.tick = tick
  pair.priest.position = { x = x, y = y }
  Movement.service(nil, 24)
end
local starting = teleports
local wrong = pair_at(11, 0, 0)
local route = begin(wrong, { x = 12, y = 0 })
for tick = 1010, 1180, 10 do
  step(wrong, tick, -(tick - 1000) / 50, 0)
end
check(teleports == starting, "wrong-direction recovered before three seconds")
step(wrong, 1190, -3.8, 0)
check(teleports == starting + 1, "three-second wrong-direction recovery missing")
check(wrong.priest.position.x > 0 and wrong.priest.position.x <= 12,
  "wrong-direction recovery did not reach a forward objective waypoint")
check(wrong.movement_request_0418 == route, "recovery replaced the active path")
check(wrong.movement_controller_last_recovery_0418.reason == "wrong-direction",
  "incorrect wrong-direction recovery classification")
Movement.sample(nil, 24)
check((storage.tech_priests.movement_controller_0419.stats.high_speed_suppressed or 0) == 0,
  "intended teleport was misclassified as a movement snap")
Movement.stop(wrong, "test-next")

game.tick = 2000
local offroute = pair_at(12, 0, 30)
local second = begin(offroute, { x = 12, y = 30 })
for tick = 2010, 2180, 10 do
  step(offroute, tick, 0, 34.5)
end
check(teleports == starting + 1,
  "incorrect-position recovery happened before three seconds")
step(offroute, 2190, 0, 34.5)
check(teleports == starting + 2, "three-second incorrect-position recovery missing")
check(offroute.movement_controller_last_recovery_0418.reason == "wrong-position",
  "off-route recovery classified as a different failure")
check(offroute.movement_request_0418 == second, "off-route correction lost route")
Movement.stop(offroute, "test-next")

game.tick = 3000
local moving = pair_at(13, 0, 60)
begin(moving, { x = 14, y = 60 })
for tick = 3010, 3250, 10 do
  step(moving, tick, (tick - 3000) / 80, 62)
end
check(teleports == starting + 2,
  "valid forward movement with a small lateral detour was teleported")
Movement.stop(moving, "test-next")

game.tick = 4000
local blocked = pair_at(14, 0, 90, true)
local blocked_route = begin(blocked, { x = 12, y = 90 })
for tick = 4010, 4240, 10 do
  step(blocked, tick, -(tick - 4000) / 50, 90)
end
check(teleports == starting + 2, "teleported onto unverified collision geometry")
check(blocked.movement_request_0418 == blocked_route,
  "blocked recovery discarded active objective")
check(blocked_route.last_recovery_blocker ~= nil,
  "collision-blocked recovery had no diagnostic")
Movement.stop(blocked, "test-next")

game.tick = 5000
local carrying = pair_at(15, 0, 120)
carrying.priest.position = { x = 15, y = 120 }
carrying.direct_acquisition_custody_0513 = { item = "iron-ore", count = 3 }
local carrying_route = begin(carrying, { x = 0, y = 120 },
  "direct-acquisition-0513", "direct-acquisition-return-0513")
for tick = 5010, 5190, 10 do
  step(carrying, tick, 15 + (tick - 5000) / 50, 120)
end
check(teleports == starting + 3, "custody return did not recover wrong-way travel")
check(carrying.direct_acquisition_custody_0513.count == 3,
  "movement recovery destroyed physical resource custody")
check(carrying.movement_request_0418 == carrying_route,
  "cargo-return request lost route ownership")
check(carrying.priest.position.x < 15,
  "cargo return did not advance toward the cogitator station")
Movement.stop(carrying, "test-next")

game.tick = 6000
local stalled = pair_at(16, 0, 150)
local stall_route = begin(stalled, { x = 12, y = 150 })
for tick = 6010, 6170, 10 do
  game.tick = tick
  Movement.service(nil, 24)
end
check(teleports == starting + 3, "stalled path recovered early")
game.tick = 6180
Movement.service(nil, 24)
check(teleports == starting + 4, "stationary route failed to recover after three seconds")
check(stalled.movement_request_0418 == stall_route,
  "stationary route recovery dropped its request")
Movement.stop(stalled, "test-next")

game.tick = 7000
local completed = pair_at(17, 0, 180)
local prior = begin(completed, { x = 10, y = 180 },
  "logistics_machine_fulfillment_0528", "machine-logistics-move-to-machine-0528")
step(completed, 7010, 10, 180)
local accepted = Movement.request(completed, { x = 14, y = 180 },
  "direct-acquisition-travel-0513",
  { owner = "direct-acquisition-0513", priority = 650, ttl = 1200 })
check(accepted == true and completed.movement_request_0418 ~= prior
  and completed.movement_request_0418.owner == "direct-acquisition-0513",
  "completed non-custody machine lease blocked the next gathering route")
local updated = completed.movement_request_0418
local rejected = Movement.request(completed, { x = 200, y = 180 },
  "stale-outside-envelope", { owner = "obsolete", priority = 50 })
check(rejected == false and completed.movement_request_0418 == updated,
  "invalid retarget cleared a valid productive movement lease")

print("[movement-waypoint-recovery] PASS scenarios=7")
