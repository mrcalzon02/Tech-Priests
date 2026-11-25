local prefix = "tech-priests-voidship-"
local bridge = "tech_priests_voidship"
local firing_tick = 300

local function call(method, ...)
  return remote.call(bridge, method, ...)
end

local function place(surface, force, name, position, direction)
  local args = {name = name, position = position, direction = direction or defines.direction.north, force = force,
                raise_built = true, build_check_type = defines.build_check_type.manual}
  assert(surface.can_place_entity(args), "cannot place " .. name)
  return assert(surface.create_entity(args))
end

local function platform(force, name)
  local ship = assert(force.create_space_platform{
    name = name, planet = "nauvis", starter_pack = "space-platform-starter-pack",
  })
  if not ship.hub then assert(ship.apply_starter_pack(true)) end
  ship.surface.request_to_generate_chunks({0, 0}, 3)
  ship.surface.force_generate_chunk_requests()
  return ship
end

local function native_rock(surface, name, position, velocity)
  return assert(surface.create_entity{name = name, position = position, velocity = velocity})
end

local function setup()
  local force = game.forces.player
  force.technologies["space-platform"].researched = true
  force.unlock_space_location("vulcanus")
  local ship = platform(force, "Armory underway")
  local surface = ship.surface
  local tiles = {}
  for x = -18, 19 do
    for y = -13, 15 do tiles[#tiles + 1] = {name = "space-platform-foundation", position = {x, y}} end
  end
  surface.set_tiles(tiles)
  local engine
  for distance = 12, 16 do
    local args = {name = "thruster", position = {10, distance}, direction = defines.direction.north,
                  force = force, build_check_type = defines.build_check_type.manual}
    if surface.can_place_entity(args) then engine = surface.create_entity(args); break end
  end
  assert(engine, "native thruster could not be placed")
  assert(engine.set_fluid(1, {name = "thruster-fuel", amount = engine.get_fluid_capacity(1)}) > 0)
  assert(engine.set_fluid(2, {name = "thruster-oxidizer", amount = engine.get_fluid_capacity(2)}) > 0)
  storage.initial_fuel = engine.get_fluid(1).amount
  local power = place(surface, force, "electric-energy-interface", {-9, 7})
  power.power_production = 6e6 / 60
  power.power_usage, power.energy = 0, 6e6
  storage.ship, storage.thruster = ship, engine
  storage.macro = place(surface, force, prefix .. "macro-cannon", {-10, -5}, defines.direction.east)
  storage.lance = place(surface, force, prefix .. "lance-battery", {0, -8})
  storage.launcher = place(surface, force, prefix .. "prow-launcher", {10, -5})
  storage.cover = place(surface, force, "pipe", {-9.5, -11.5})
  storage.cargo = assert(ship.hub.get_inventory(defines.inventory.hub_main))
  storage.ammo = assert(storage.macro.get_inventory(defines.inventory.chest))
  assert(storage.cargo.insert{name = prefix .. "plasma-torpedo", count = 2} == 2)
  assert(storage.ammo.insert{name = "artillery-shell", count = 2} == 2)
  storage.bank = assert(surface.find_entities_filtered{name = prefix .. "lance-capacitor"}[1])
  storage.foreign = platform(force, "Other platform").surface
  ship.schedule = {current = 1, records = {{station = "vulcanus", wait_conditions = {{type = "time", ticks = 3600}}}}}
  ship.paused = false
end

local function refuse(mount, target, expected)
  local shot, reason = call("fire_asteroid", mount, target)
  assert(not shot and reason == expected, "expected " .. expected .. ", got " .. tostring(reason))
end

local function firing()
  local ship, macro, lance, launcher = storage.ship, storage.macro, storage.lance, storage.launcher
  local surface = ship.surface
  assert(ship.speed > 0 and ship.space_connection and not ship.space_location, "shot fired before departure")
  assert(storage.thruster.get_fluid(1).amount < storage.initial_fuel, "native engine did not consume fuel")
  storage.firing_distance = ship.distance
  assert(storage.bank.energy == 6e6, "lance was not charged by the grid")

  -- Keep the test targets controlled while the engine moves each real asteroid.
  for _, object in pairs(surface.find_entities_filtered{type = "asteroid"}) do object.destroy() end
  local foreign = native_rock(storage.foreign, "small-metallic-asteroid", {0, -25}, {0, .05})
  local behind = native_rock(surface, "small-carbonic-asteroid", {11, 22}, {0, .05})
  local distant = native_rock(surface, "small-oxide-asteroid", {-10, -83}, {0, .025})
  refuse(macro, foreign, "invalid-asteroid")
  refuse(macro, distant, "asteroid-range")
  refuse(launcher, behind, "asteroid-arc")
  refuse(launcher, nil, "no-asteroids")
  refuse(lance, ship.hub, "invalid-asteroid")
  assert(storage.cargo.get_item_count(prefix .. "plasma-torpedo") == 2)
  assert(storage.ammo.get_item_count("artillery-shell") == 2 and storage.bank.energy == 6e6)

  local torpedo_target = native_rock(surface, "medium-carbonic-asteroid", {9, -41}, {-.045, .06})
  local torpedo = assert(call("fire_asteroid", launcher))
  assert(torpedo.asteroid == torpedo_target, "nearest eligible asteroid was not selected")
  assert(torpedo.torpedoes_spent == 1 and torpedo.entry_tick == game.tick + 30 and torpedo.bay == 1)
  assert(call("round_status", torpedo.round_id).stage == "launching")

  local shell_target = native_rock(surface, "medium-metallic-asteroid", {-10, -37}, {.095, .06})
  local shell = assert(call("fire", macro, shell_target))
  assert(shell.shells_spent == 1 and shell.cooldown_until == game.tick + 900)
  local shot = assert(call("round_status", shell.round_id))
  assert(shot.stage == "flight" and shot.surface_index == surface.index and shot.position.y < macro.position.y)
  local status = call("visual_status", macro)
  assert(status.base_direction == defines.direction.east and status.heading == 0, "macro cap did not aim independently")

  local lance_target = native_rock(surface, "medium-oxide-asteroid", {0, -40}, {.31, .06})
  local discharge = assert(call("fire", lance, lance_target))
  assert(discharge.impact_tick == game.tick + 28 and discharge.joules_spent == 6e6)
  assert(storage.bank.energy == 0 and storage.ammo.get_item_count("artillery-shell") == 1)
  assert(storage.cargo.get_item_count(prefix .. "plasma-torpedo") == 1)
  refuse(macro, shell_target, "cooldown")
  refuse(launcher, torpedo_target, "cooldown")
  refuse(lance, lance_target, "cooldown")
  storage.shots = {
    {weapon = macro, target = shell_target, from = shell_target.position, type = "physical", shot = shell},
    {weapon = launcher, target = torpedo_target, from = torpedo_target.position, type = "explosion", shot = torpedo},
    {weapon = lance, target = lance_target, from = lance_target.position, type = "laser", shot = discharge},
  }
end

script.on_event(defines.events.on_entity_damaged, function(event)
  for _, test in ipairs(storage.shots or {}) do
    if event.entity == test.target then
      assert(event.damage_type.name == test.type and event.cause == test.weapon, "wrong weapon caused asteroid impact")
      local ship, position = storage.ship, event.entity.position
      assert(ship.speed > 0 and ship.space_connection and not ship.space_location)
      assert(math.abs(ship.distance - storage.firing_distance) > 0, "ship did not advance during the shot")
      assert(math.abs(position.x - test.from.x) > .35, "asteroid did not drift after the shot")
      assert(game.tick >= (test.shot.entry_tick or test.shot.impact_tick), "damage occurred before flight or discharge")
      test.hit_tick, test.damage, test.ship_speed = game.tick, event.final_damage_amount, ship.speed
      if test.type == "laser" then
        local beams = 0
        for _, render in pairs(rendering.get_all_objects("tech-priests")) do
          if render.type == "line" and render.from.entity == test.weapon then
            local endpoint = render.to.position
            assert(endpoint and math.abs(endpoint.x - position.x) < .05 and math.abs(endpoint.y - position.y) < .05)
            beams = beams + 1
          end
        end
        assert(beams == 4, "lance beams did not reach the moving asteroid")
        local pose = call("visual_status", test.weapon)
        assert(pose.displayed_heading > 0 and pose.base_direction == defines.direction.north, "lance failed to track")
      end
    end
  end
end)

script.on_event(defines.events.on_tick, function(event)
  local tick = event.tick
  if tick == 1 then setup()
  elseif tick == firing_tick then firing()
  elseif tick == firing_tick + 12 then
    assert(call("round_status", storage.shots[1].shot.round_id).stage == "flight")
    assert(call("round_status", storage.shots[2].shot.round_id).stage == "launching")
    assert(storage.ship.speed > 0 and storage.ship.space_connection)
    game.auto_save("voidship-asteroid-underway")
  elseif tick == firing_tick + 32 then
    local torpedo = assert(call("round_status", storage.shots[2].shot.round_id))
    assert(torpedo.stage == "flight" and torpedo.position.y < storage.launcher.position.y - 5)
  elseif tick == 560 then
    for _, test in ipairs(storage.shots) do
      assert(test.hit_tick and test.damage > 0, test.weapon.name .. " failed to hit a moving asteroid")
      assert(not test.target.valid, test.weapon.name .. " did not break the original asteroid")
      if test.shot.round_id then assert(not call("round_status", test.shot.round_id), "resolved projectile leaked state") end
      log("VOIDSHIP_ASTEROID_HIT " .. test.weapon.name .. " at tick " .. test.hit_tick
        .. " damage=" .. test.damage .. " platform_speed=" .. test.ship_speed)
    end
    assert(storage.cover.health == storage.cover.max_health and storage.ship.speed > 0)
    log("TECH_PRIESTS_ASTEROIDS_PASS: native motion, three moving asteroid hits, ammo and charge, "
      .. "local range and arc, independent aim, and clean projectile handoff.")
    script.finish_test(true)
  end
end)
