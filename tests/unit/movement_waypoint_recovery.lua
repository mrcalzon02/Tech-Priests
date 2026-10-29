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

-- A machine carrying output may not declare arrival using the generic
-- +0.35 loiter pad, which leaves it outside the two-tile transfer boundary.
game.tick = 8000
local precision = pair_at(18, 0, 210)
precision.priest.position = { x = 0, y = 207.84 }
local precision_route = begin(precision, { x = 0, y = 208.15 },
  "logistics_machine_fulfillment_0528",
  "machine-logistics-return-custody-0528")
check(precision_route.radius == 0.25, "precision fixture incorrectly initialized")
check(Movement.request_status(precision).status == "active",
  "precise machine custody status falsely reported waypoint arrival")
local issued = precision.priest.commandable.issued
check(#issued > 0 and issued[#issued].type == defines.command.go_to_location,
  "machine cargo route loitered before reaching exact contact waypoint")

-- 0877: all four station-reversal carrier stages must recover a bad
-- route through a fresh native command, never a coordinate teleport. This
-- regression exercises the production 0418 controller; actual Factorio
-- travel, cargo and save/reload remain separate engine acceptance gates.
for index,suffix in ipairs({"0851","0853","0854","0855"}) do
  local start_tick=9000+index*1000
  game.tick=start_tick
  local worker=pair_at(30+index,0,250+index*30)
  local cargo={item="station-item-from-real-inventory",count=1}
  worker.station_recovery_test_cargo=cargo
  local owner="station-recovery-"..suffix
  local reason="station-recovery-return-"..suffix
  check(Movement.request(worker,
    {x=12,y=worker.station.position.y},reason,
    {owner=owner,priority=56,ttl=1200,radius=2}),
    "station recovery route was rejected: "..suffix)
  Movement.service(nil,24)
  local route=worker.movement_request_0418
  local issued=worker.priest.commandable.issued
  local commands_before=#issued
  local teleports_before=teleports
  for delta=10,190,10 do
    step(worker,start_tick+delta,-delta/50,worker.station.position.y)
  end
  check(teleports==teleports_before,
    "station recovery teleported the original carrier: "..suffix)
  check(worker.priest.position.x==-3.8,
    "physical repath pretended to move the carrier: "..suffix)
  check(#issued==commands_before+1
    and issued[#issued].type==defines.command.go_to_location,
    "station recovery did not issue exactly one native repath: "..suffix)
  check(worker.movement_request_0418==route
    and route.last_command_tick==game.tick
    and worker.movement_controller_state_0418=="station-recovery-physical-repath",
    "station recovery lost canonical route ownership: "..suffix)
  check(worker.station_recovery_test_cargo==cargo and cargo.count==1,
    "station recovery repath mutated held station item: "..suffix)
  Movement.stop(worker,"0877-next-stage")
end

-- A blocked short waypoint must be escalated to the same real final
-- goal, allowing Factorio to path around an obstacle instead of repeatedly
-- retrying the straight 18-tile segment or teleporting through it.
game.tick=17000
local detour=pair_at(48,0,500)
check(Movement.request(detour,{x=100,y=500},
  "station-recovery-return-0851",
  {owner="station-recovery-0851",priority=56,ttl=1200,radius=2}),
  "detour fixture did not accept canonical full goal")
Movement.service(nil,24)
local detour_req=detour.movement_request_0418
check(detour_req.ground_route_chunked==true and detour_req.x==18
  and detour_req.ground_route_final_destination.x==100,
  "detour fixture did not start with an actual short waypoint")
local detour_teleports=teleports
for delta=10,190,10 do
  step(detour,17000+delta,-delta/50,500)
end
local detour_commands=detour.priest.commandable.issued
check(teleports==detour_teleports and detour.priest.position.x==-3.8,
  "obstacle fallback moved the carrier without engine travel")
check(detour.movement_request_0418==detour_req
  and detour_req.x==100 and detour_req.ground_route_chunked==false
  and detour_req.ground_route_final_destination.x==100,
  "native full-goal fallback lost original destination or request identity")
check(#detour_commands==2
  and detour_commands[2].destination.x==100
  and Movement.request_status(detour).status=="active",
  "physical detour did not command full goal or falsely declared arrival")
Movement.stop(detour,"0877-detour-complete")

-- Refused physical repath must fail closed: never fall back to teleport,
-- invent arrival, discard cargo or replace the live movement request.
game.tick=15000
local refused=pair_at(39,0,420)
local held_item={count=1}
refused.station_recovery_test_cargo=held_item
check(Movement.request(refused,{x=12,y=420},
  "station-recovery-return-0851",
  {owner="station-recovery-0851",priority=56,ttl=1200,radius=2}),
  "refused-repath fixture did not accept initial route")
Movement.service(nil,24)
local refused_route=refused.movement_request_0418
local before_refusal=teleports
refused.priest.commandable.valid=false
for delta=10,190,10 do
  step(refused,15000+delta,-delta/50,420)
end
check(teleports==before_refusal
  and refused.movement_request_0418==refused_route
  and held_item.count==1,
  "refused physical repath teleported or lost custody")
check(refused_route.last_recovery_blocker=="station-recovery-physical-repath-refused",
  "refused native path command lacked fail-closed diagnostic")
Movement.stop(refused,"0877-complete")

-- 0969: A real resource-return courier must NEVER inherit the legacy
-- coordinate-teleport waypoint recovery. When an 18-tile segment cannot
-- be navigated, ask Factorio to path to the SAME authorized natural ore
-- goal. Invalidation of the mission must fail closed without movement,
-- changing a physical item, or substituting an unverified path.
game.tick=19000
local home=pair_at(61,0,700)
local ore_worker=pair_at(62,0,720)
ore_worker.station.surface=home.station.surface
ore_worker.priest.surface=home.station.surface
ore_worker.station.force=home.station.force
ore_worker.priest.force=home.station.force
ore_worker.remote_resource_assignment_0820={root_station_unit=61}
local courier_state={
  phase="to-natural-ore",hop_index=1,quantity=0,
  source_station_unit=62,destination_station_unit=61,
  carrier_priest_unit=ore_worker.priest.unit_number,
  item="iron-ore",
}
local mission={
  status="reached-resource",root_station_unit=61,need="iron-ore",
  target={x=19,y=720},return_courier_0837=courier_state,
}
home.resource_expansion_0259={chain_0820=mission}
local Chain=require("scripts.core.resource_station_chain_0820")
local original_route=Chain.return_route
local original_radius=Chain.operating_radius
Chain.return_route=function(magos)
  if magos==home then return {62,61} end
  return original_route(magos)
end
Chain.operating_radius=function(worker)
  if worker==ore_worker then return 30 end
  return original_radius and original_radius(worker) or 20
end
check(Movement.request(ore_worker,mission.target,
  "resource-return-natural-ore-0953",
  {owner="resource-return-courier-0953",priority=72,
    ttl=600,radius=2,bounds_exempt=true,skip_corridor_planner=true}),
  "authorized physical ore courier could not start")
Movement.service(nil,24)
local ore_request=ore_worker.movement_request_0418
check(ore_request and ore_request.ground_route_chunked==true
  and ore_request.ground_route_final_destination.x==19,
  "ore courier did not preserve its exact natural-ore goal")
local before_courier=teleports
local before_commands=#ore_worker.priest.commandable.issued
for delta=10,190,10 do
  step(ore_worker,19000+delta,-delta/50,720)
end
local ore_commands=ore_worker.priest.commandable.issued
check(teleports==before_courier
  and ore_worker.priest.position.x==-3.8,
  "resource courier recovered by teleporting its priest")
check(ore_worker.movement_request_0418==ore_request
  and ore_request.x==19 and ore_request.ground_route_chunked==false
  and ore_commands[#ore_commands].destination.x==19
  and #ore_commands==before_commands+1,
  "resource courier did not repath natively to its authorized final goal")
check(ore_worker.movement_controller_state_0418
    =="resource-courier-physical-repath-0969"
  and (storage.tech_priests.movement_controller_0419.stats
    .resource_courier_physical_repaths_0969 or 0)>=1,
  "resource courier physical repath was not recorded")
mission.status="suspended"
for delta=200,410,10 do
  step(ore_worker,19000+delta,-delta/50,720)
end
check(teleports==before_courier
  and ore_worker.movement_request_0418==ore_request
  and ore_request.last_recovery_blocker
    =="resource-courier-physical-route-unverified"
  and courier_state.quantity==0 and courier_state.inventory==nil,
  "invalidated ore mission teleported, fabricated ore or lost the route")
Movement.stop(ore_worker,"0969-complete")
Chain.return_route=original_route
Chain.operating_radius=original_radius
print("[resource-courier-physical-repath-0969] PASS native full-goal repath, zero teleports, unchanged custody, invalidated-route refusal")

print("[station-recovery-physical-repath-0877] PASS four real movement owners, no teleport, retained cargo, refused command")
print("[movement-waypoint-recovery] PASS scenarios=8")
