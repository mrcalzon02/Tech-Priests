-- Lua 5.2: machine logistics may not send a priest into the solid
-- cogitator station center, and must preserve exact physical cargo.
package.path = "tech-priests_src/?.lua;tech-priests_src/?/init.lua;" .. package.path
game = { tick = 1200 }
storage = { tech_priests = { pairs_by_station = {} } }
defines = { distraction = { none = 0 } }
local function check(ok, why)
  if not ok then error("machine-station-contact: " .. why, 2) end
end
local moves, deposits, supply_removed = {}, 0, 0
_G.tech_priests_request_movement_0418 = function(pair, pos, reason, options)
  moves[#moves + 1] = { pos = { x = pos.x, y = pos.y },
    reason = reason, options = options }
  return true
end
_G.TechPriestsStorageRoleAuthority0686 = {
  deposit_exact = function(_, item, count)
    check(item == "iron-ore", "wrong deposited item")
    deposits = deposits + count
    return true, "deposited", count
  end,
  remove_generic_item = function(_, item, count)
    check(item == "coal", "unexpected stock withdrawal")
    supply_removed = supply_removed + count
    return count
  end,
}
local Logistics = require("scripts.core.logistics_machine_fulfillment_0528")
local force = { index = 1 }
local surface = { index = 1 }
local station = { valid = true, name = "junior-cogitator-station",
  unit_number = 10, position = { x = 0, y = 0 },
  force = force, surface = surface }
surface.can_place_entity = function(args)
  local x, y = args.position.x, args.position.y
  -- Simulates an impassable station center with usable perimeter.
  return x * x + y * y >= 1.3 * 1.3
end
local priest = { valid = true, name = "tech-priests-junior-priest",
  unit_number = 11, position = { x = 9, y = 0 },
  force = force, surface = surface }
local machine = { valid = true, name = "tech-priests-emergency-miner",
  unit_number = 12, position = { x = 8, y = 0 },
  force = force, surface = surface, type = "assembling-machine" }
local pair = { station = station, priest = priest, station_unit = 10 }
storage.tech_priests.pairs_by_station[10] = pair
local carried = { item = "iron-ore", count = 5, kind = "retention" }
pair.machine_logistics_custody_0528 = carried
pair.machine_logistics_0528 = { phase = "return-custody-to-station",
  action = "clear-output", item = "iron-ore",
  count = 5, custody = carried, machine = machine }
local result = Logistics.service_pair(pair, "test-output")
check(result.waiting == 1 and #moves == 1,
  "missing physical station-contact movement")
local point = moves[1].pos
local squared = point.x * point.x + point.y * point.y
check(squared >= 1.3 * 1.3 and squared <= 1.55 * 1.55,
  "return destination did not prefer the innermost reachable station contact")
check(moves[1].options.radius == 0.15,
  "loose movement arrival tolerance risks stopping beyond custody range")
check(pair.machine_logistics_custody_0528 == carried and deposits == 0,
  "movement request discarded cargo or deposited remotely")
priest.position = { x = point.x, y = point.y }
result = Logistics.service_pair(pair, "test-output-arrival")
check(result.acted == 1 and deposits == 5,
  "output did not atomically deposit after reaching station perimeter")
check(pair.machine_logistics_custody_0528 == nil
  and pair.machine_logistics_0528.phase == "complete",
  "completed output delivery did not release custody/task")

-- Fuel supply starts at the exact same legally navigable station perimeter.
priest.position = { x = 9, y = 0 }
pair.machine_logistics_0528 = { phase = "move-to-station",
  action = "supply-fuel", item = "coal", count = 3, machine = machine }
result = Logistics.service_pair(pair, "test-supply")
check(result.waiting == 1 and #moves == 2
  and moves[2].pos.x ~= 0, "station fuel collection targeted solid center")
priest.position = moves[2].pos
result = Logistics.service_pair(pair, "test-supply-arrival")
check(result.acted == 1 and supply_removed == 3,
  "valid station contact failed to collect available coal")
check(pair.machine_logistics_custody_0528
  and pair.machine_logistics_custody_0528.count == 3,
  "fuel supply did not maintain custody")
check(pair.machine_logistics_0528.phase == "move-to-machine",
  "fuel custody did not proceed toward the intended machine")

-- The real machine's center is solid. The carrier must approach a free
-- perimeter contact, not repeatedly request a path into the collision box.
surface.can_place_entity = function(args)
  local x, y = args.position.x, args.position.y
  return x * x + y * y >= 1.3 * 1.3
    and (x - 8) * (x - 8) + y * y >= 1.25 * 1.25
end
result = Logistics.service_pair(pair, "test-supply-machine-contact")
check(result.waiting == 1 and #moves == 3,
  "fuel courier did not request an actual machine perimeter contact")
local machine_point = moves[3].pos
local machine_squared = (machine_point.x - 8)^2 + machine_point.y^2
check(machine_squared >= 1.25^2 and machine_squared <= 1.45^2,
  "machine contact was blocked or outside the physical transfer envelope")
check(moves[3].options.radius == 0.15,
  "machine arrival tolerance could permit a false out-of-reach delivery")
check(pair.machine_logistics_custody_0528.count == 3 and supply_removed == 3,
  "contact planning remotely spent or duplicated physically carried coal")
check(pair.machine_logistics_0528.machine_contact_unit_0528 == 12,
  "cached contact was not bound to the exact machine identity")
local remembered = pair.machine_logistics_0528.machine_contact_0528
result = Logistics.service_pair(pair, "test-machine-contact-retry")
check(result.waiting == 1 and #moves == 4
  and moves[4].pos.x == remembered.x
  and moves[4].pos.y == remembered.y,
  "repeated service changed a valid contact or lost physical cargo")

-- When every position in physical reach is blocked, refuse to deliver
-- remotely; retain the original coal custody for later recovery.
surface.can_place_entity = function(args)
  local x, y = args.position.x, args.position.y
  return (x - 8)^2 + y^2 > 1.5^2
end
result = Logistics.service_pair(pair, "test-machine-contact-blocked")
check(result.blocked == 1 and result.detail == "machine-contact-unavailable",
  "blocked machine did not fail closed")
check(pair.machine_logistics_custody_0528.count == 3
  and pair.machine_logistics_0528.phase == "move-to-machine"
  and supply_removed == 3 and #moves == 4,
  "blocked machine contact destroyed custody or issued an impossible move")

-- No legal adjacent tile is a truthful blocker, not a remote deposit or
-- an instruction to navigate through the station's collision geometry.
surface.can_place_entity = function() return false end
priest.position = { x = 9, y = 0 }
pair.machine_logistics_0528 = { phase = "return-custody-to-station",
  action = "clear-output", item = "iron-ore", count = 2,
  custody = { item = "iron-ore", count = 2, kind = "retention" },
  machine = machine }
pair.machine_logistics_custody_0528 = pair.machine_logistics_0528.custody
result = Logistics.service_pair(pair, "test-no-contact")
check(result.blocked == 1 and result.detail == "station-contact-unavailable",
  "unreachable station did not report a clear blocker")
check(#moves == 4 and deposits == 5,
  "blocked return attempted an impossible route or remote deposit")
check(pair.machine_logistics_custody_0528.count == 2,
  "blocked return silently lost machine-output custody")

print("[machine-station-contact] PASS scenarios=5")
