local bridge = "tech_priests_voidship"
local prefix = "tech-priests-voidship-"
local torpedo = prefix .. "plasma-torpedo"
local capacitor = prefix .. "lance-capacitor"

local function call(method, ...)
  return remote.call(bridge, method, ...)
end

local function near(actual, expected, label)
  assert(math.abs(actual - expected) < .1, label .. " got " .. actual .. ", wanted " .. expected)
end

local function place(ship, name, x, y)
  local params = {name = name, position = {x, y}, force = ship.force,
    raise_built = true, build_check_type = defines.build_check_type.manual}
  assert(ship.surface.can_place_entity(params), "cannot place " .. name)
  return assert(ship.surface.create_entity(params))
end

local function platform(force, name)
  force.technologies["space-platform"].researched = true
  local ship = assert(force.create_space_platform{
    name = name, planet = "nauvis", starter_pack = "space-platform-starter-pack",
  })
  if not ship.hub then assert(ship.apply_starter_pack(true)) end
  ship.surface.request_to_generate_chunks({0, 0}, 2)
  ship.surface.force_generate_chunk_requests()
  local tiles = {}
  for x = -23, 23 do
    for y = -19, 22 do
      tiles[#tiles + 1] = {name = "space-platform-foundation", position = {x, y}}
    end
  end
  ship.surface.set_tiles(tiles, true, false, false)
  return ship
end

local function refuse(mount, reason)
  local shot, failure = call("fire", mount, storage.hull)
  assert(not shot and failure == reason, "expected " .. reason .. ", got " .. tostring(failure))
end

local function setup()
  assert(script.active_mods["tech-priests"] and remote.interfaces[bridge])
  local force, hostile = game.forces.player, game.create_force("ordnance-test-foe")
  force.set_friend(hostile, false)
  hostile.set_friend(force, false)
  force.set_cease_fire(hostile, false)
  hostile.set_cease_fire(force, false)
  local source = platform(force, "Ordnance test ship")
  local victim = platform(hostile, "Ordnance test target")
  storage.origin, storage.victim = source, victim
  storage.hull = place(victim, "fixture-voidship-armor-target", 16.5, 16.5)
  storage.shield = place(victim, prefix .. "void-shield", -16, 16)
  storage.lance = place(source, prefix .. "lance-battery", -12, 13)
  storage.launcher = place(source, prefix .. "prow-launcher", 0, 13)
  storage.second_launcher = place(source, prefix .. "prow-launcher", 12, 13)
  local banks = source.surface.find_entities_filtered{name = capacitor}
  assert(#banks == 1, "lance capacitor missing or duplicated")
  storage.bank = banks[1]
  near(storage.bank.energy, 0, "unpowered lance capacitor")
  refuse(storage.lance, "no-lance-power")
  refuse(storage.launcher, "no-torpedoes")
  assert(call("preview", storage.lance), "unpowered preview failed")
  near(storage.bank.energy, 0, "preview consumed or created energy")
  for i = 0, 7 do
    place(source, "solar-panel", -17.5 + i * 5, -12.5)
  end
  local cargo = assert(source.hub.get_inventory(defines.inventory.hub_main))
  assert(force.recipes[torpedo].enabled and cargo.insert{name = torpedo, count = 2} == 2)
  assert(cargo.insert{name = torpedo, count = 1, quality = "uncommon"} == 1)
  storage.cargo = cargo
end

local function first_shots(tick)
  near(storage.bank.energy, 6000000, "solar-powered native charge")
  local lance = assert(call("fire", storage.lance, storage.hull))
  assert(lance.joules_spent == 6000000 and lance.impact_tick == tick + 28 and lance.cooldown_until == tick + 600)
  near(storage.bank.energy, 0, "firing spent exactly one lance charge")
  local launch = assert(call("fire", storage.launcher, storage.hull))
  assert(launch.torpedoes_spent == 1 and launch.entry_tick == tick + 90 and launch.impact_tick == tick + 410
    and launch.bay == 1)
  storage.first_round = launch.round_id
  assert(launch.cooldown_until == tick + 900 and storage.cargo.get_item_count{name = torpedo, quality = "normal"} == 1)
  near(storage.hull.health, 60000, "damage before charge and flight completed")
  refuse(storage.lance, "cooldown")
  refuse(storage.launcher, "cooldown")
end

script.on_event(defines.events.on_tick, function(event)
  local tick = event.tick
  if tick == 1 then
    setup()
  elseif tick == 500 then
    first_shots(tick)
  elseif tick == 527 then
    near(storage.hull.health, 60000, "lance damage before beam")
    storage.shield.energy = 25000000
  elseif tick == 529 then
    near(storage.hull.health, 53000, "8,000 laser damage with 1,000 intercepted")
    near(storage.shield.energy, 0, "lance interception drained remote shield")
  elseif tick == 600 then
    local torpedo = assert(call("fire", storage.second_launcher, storage.hull))
    assert(torpedo.bay == 1 and torpedo.entry_tick == 690 and torpedo.impact_tick == 1010)
    storage.second_launcher.destroy()
  elseif tick == 650 then
    near(storage.hull.health, 53000, "target at the mid-flight save")
    assert(call("round_status", storage.first_round).stage == "incoming")
    assert(storage.cargo.get_item_count{name = torpedo, quality = "normal"} == 0)
    assert(storage.cargo.get_item_count{name = torpedo, quality = "uncommon"} == 1)
    game.auto_save("voidship-cross-platform-mid-flight")
  elseif tick == 909 then
    near(storage.hull.health, 53000, "torpedo damage before arrival")
    storage.shield.energy = 25000000
  elseif tick == 911 then
    near(storage.hull.health, 45000, "9,000 torpedo damage with 1,000 intercepted")
    near(storage.shield.energy, 0, "torpedo interception drained remote shield")
    assert(not call("round_status", storage.first_round), "live impact left a round in flight")
  elseif tick == 1011 then
    near(storage.hull.health, 36000, "launched torpedo continued after its mount was destroyed")
  elseif tick == 1100 then
    local lance = assert(call("fire", storage.lance, storage.hull))
    assert(lance.impact_tick == 1128)
    storage.lance.destroy()
  elseif tick == 1130 then
    near(storage.hull.health, 36000, "destroyed lance never discharged")
    assert(not storage.bank.valid, "destroyed lance left a capacitor behind")
  elseif tick == 1399 then
    refuse(storage.launcher, "cooldown")
  elseif tick == 1400 then
    assert(storage.cargo.get_item_count{name = torpedo, quality = "uncommon"} == 1)
    local launch = assert(call("fire", storage.launcher, storage.hull))
    assert(launch.bay == 2 and launch.torpedoes_spent == 1)
    storage.departed_target_round = launch.round_id
    assert(storage.cargo.get_item_count{name = torpedo, quality = "uncommon"} == 0)
    storage.victim.space_location = "gleba"
  elseif tick == 1492 then
    near(storage.hull.health, 36000, "torpedo hit a platform outside its firing orbit")
    assert(not call("round_status", storage.departed_target_round))
    log("TECH_PRIESTS_ORDNANCE_PASS: grid-powered lance; actual plasma torpedo cargo; 28-tick charge; cross-platform flight; "
      .. "both shielded; mount loss, bay rotation, and target departure handled.")
    script.finish_test(true)
  end
end)
