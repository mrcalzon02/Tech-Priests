local bridge = "tech_priests_voidship"
local prefix = "tech-priests-voidship-"
local launchers = {prefix .. "macro-cannon", prefix .. "prow-launcher"}
local round_names = {prefix .. "incoming-macro-shell", prefix .. "incoming-plasma-torpedo"}
local defenses = {{"gun-turret", "firearm-magazine", 2}, {"laser-turret", nil, 2},
                  {"rocket-turret", "rocket", 1}, {"railgun-turret", "railgun-ammo", 1}}
local point = {x = 13.5, y = 3.5}

local function call(method, ...)
  return remote.call(bridge, method, ...)
end

local function near(actual, expected, label)
  assert(math.abs(actual - expected) < .12, label .. " got " .. actual .. ", wanted " .. expected)
end

local function ship(force, name)
  force.technologies["space-platform"].researched = true
  local platform = assert(force.create_space_platform{
    name = name, planet = "nauvis", starter_pack = "space-platform-starter-pack",
  })
  if not platform.hub then assert(platform.apply_starter_pack(true)) end
  local surface = platform.surface
  surface.request_to_generate_chunks({0, 0}, 1)
  surface.force_generate_chunk_requests()
  local tiles = {}
  for x = -20, 21 do
    for y = -8, 32 do
      tiles[#tiles + 1] = {name = "space-platform-foundation", position = {x, y}}
    end
  end
  surface.set_tiles(tiles, true, false, false)
  return platform
end

local function place(ship, name, x, y, direction)
  local args = {name = name, position = {x, y}, direction = direction or defines.direction.north, force = ship.force,
    raise_built = true, build_check_type = defines.build_check_type.manual}
  assert(ship.surface.can_place_entity(args), "cannot place " .. name .. " on " .. ship.name)
  return assert(ship.surface.create_entity(args))
end

local function defending_turrets(platform, defense)
  for i = 1, defense[3] do
    local column = defense[1] == "railgun-turret" and point.x or (i == 1 and 10.5 or 16.5)
    local turret = place(platform, defense[1], column, 26.5, defines.direction.south)
    if defense[2] then
      assert(turret.get_inventory(defines.inventory.turret_ammo).insert{name = defense[2], count = 10} == 10)
    end
  end
  local power = place(platform, "electric-energy-interface", 4, 24)
  power.power_production = 40e6 / 60
  power.power_usage = 0
  power.energy = 40e6
end

local function salvo(mount, ship, cell)
  return assert(call("fire_at", mount, ship.surface.index, cell.x, cell.y))
end

local function setup()
  assert(script.active_mods["tech-priests"] and remote.interfaces[bridge].fire_at)
  local attacker = game.forces.player
  local defender = game.create_force("crossfire-defenders")
  attacker.set_friend(defender, false)
  defender.set_friend(attacker, false)
  attacker.set_cease_fire(defender, false)
  defender.set_cease_fire(attacker, false)
  local source = ship(attacker, "Live fire source")
  local cargo = assert(source.hub.get_inventory(defines.inventory.hub_main))
  assert(cargo.insert{name = prefix .. "plasma-torpedo", count = 7} == 7)
  storage.cases = {}
  storage.source, storage.attacker, storage.defender = source, attacker, defender
  for i, definition in ipairs(launchers) do
    for j, defense in ipairs(defenses) do
      local platform = ship(defender, "Intercept " .. i .. " " .. defense[1])
      local hull = place(platform, "fixture-voidship-armor-target", point.x, point.y)
      defending_turrets(platform, defense)
      local mount = place(source, definition, j * 6 - 18, 10 + i * 8)
      if i == 1 then
        assert(mount.get_inventory(defines.inventory.chest).insert{name = "artillery-shell", count = 1} == 1)
      end
      local shot = salvo(mount, platform, {x = 13, y = 3})
      storage.cases[platform.surface.index] = {ship = platform, hull = hull, turret = defense[1],
        projectile = round_names[i], id = shot.round_id, entry = shot.entry_tick, impact = shot.impact_tick,
        damage = 0, intercepted = false}
    end
  end

  local unguarded = ship(defender, "Cross-surface live impact")
  local cannon = place(source, launchers[1], 14, 18)
  local payload = place(source, launchers[2], 14, 26)
  local shells = cannon.get_inventory(defines.inventory.chest)
  assert(shells.insert{name = "artillery-shell", count = 2} == 2)
  local denied, reason = call("fire_at", cannon, unguarded.surface.index, -95, -90)
  assert(not denied and reason == "invalid-cell" and shells.get_item_count("artillery-shell") == 2)
  local same, reason = call("fire_at", cannon, source.surface.index, 14, 18)
  assert(not same and reason == "same-platform" and shells.get_item_count("artillery-shell") == 2)
  local moved = place(unguarded, "fixture-voidship-armor-target", point.x, point.y)
  local direct = assert(call("fire", cannon, moved))
  local torpedo_cell = {x = 15.5, y = 10.5}
  local torpedo_hull = place(unguarded, "fixture-voidship-armor-target", torpedo_cell.x, torpedo_cell.y)
  local torpedo_shot = salvo(payload, unguarded, torpedo_cell)
  local empty_cell = {x = -5.5, y = 16.5}
  local empty_shot = salvo(place(source, launchers[2], -14, 6), unguarded, empty_cell)
  place(unguarded, "tesla-turret", point.x, 24)
  storage.live = {ship = unguarded, moved = moved, shell = direct, torpedo = torpedo_shot,
    empty_cell = empty_cell, empty_shot = empty_shot, torpedo_hull = torpedo_hull,
    shield = place(unguarded, prefix .. "void-shield", -13, 10)}
end

local function marker(surface, position)
  local matches = {}
  for _, object in pairs(rendering.get_all_objects("tech-priests")) do
    if object.surface == surface and object.type == "sprite"
        and (object.sprite == "tp-voidship-fx-target-brackets" or object.sprite == "tp-voidship-fx-target-cell") then
      local target = object.target.position
      if target and math.abs(target.x - position.x) < .1 and math.abs(target.y - position.y) < .1 then
        matches[#matches + 1] = object
      end
    end
  end
  return matches
end

local function verify_entry(test)
  local status = assert(call("round_status", test.id))
  local pos, target = status.position, status.target
  assert(status.stage == "incoming" and status.surface_index == test.ship.surface.index)
  near(target.x, point.x, "cell column center")
  near(target.y, point.y, "cell row center")
  assert(pos.y - target.y > 62 and test.ship.surface.get_tile(pos).name == "empty-space",
    "round did not enter from open space 64 tiles away")
  local entities = test.ship.surface.find_entities_filtered{name = test.projectile}
  assert(#entities == 1 and entities[1].force == storage.attacker and entities[1].destructible)
  assert(#marker(test.ship.surface, point) >= 2, "destination warning did not mark the targeted cell")
  local plasma = test.projectile == round_names[2]
  local name = plasma and "tp-voidship-fx-plasma-plume" or "tp-voidship-fx-macro-plume"
  local trail
  for _, object in pairs(rendering.get_all_objects("tech-priests")) do
    if object.surface == test.ship.surface and object.type == "animation"
        and object.target.entity == entities[1] and object.animation == name then
      trail = object
      break
    end
  end
  assert(trail and trail.animation_speed > 0, "incoming round lost its animated plume")
  test.trail, test.early_length = trail, trail.sprite_height
  test.first_y = pos.y
end

script.on_event(defines.events.on_entity_damaged, function(event)
  local test = storage.cases and storage.cases[event.entity.surface.index]
  if test and event.entity.name == test.projectile then
    assert(event.cause and event.cause.valid and event.cause.name == test.turret and event.cause.force == storage.defender)
    test.damage = test.damage + event.final_damage_amount
  end
end)

script.on_event(defines.events.on_entity_died, function(event)
  local test = storage.cases and storage.cases[event.entity.surface.index]
  if test and event.entity.name == test.projectile then
    assert(event.cause and event.cause.valid and event.cause.name == test.turret)
    assert(game.tick < test.impact)
    test.intercepted = true
  end
end)

script.on_event(defines.events.on_tick, function(event)
  local tick = event.tick
  if tick == 1 then setup(); return end
  local live = storage.live
  if not live then return end
  if tick == 2 then
    for _, test in pairs(storage.cases) do
      assert(call("round_status", test.id).stage == "transit")
      local reticle = marker(test.ship.surface, point)
      assert(#reticle == 2, "alert was missing before arrival")
      for _, part in ipairs(reticle) do
        if part.sprite == "tp-voidship-fx-target-brackets" then
          test.brackets, test.initial_size, test.initial_alpha = part, part.sprite_width, part.color.a
        end
      end
      assert(test.brackets and test.initial_size > 5.5)
    end
    assert(live.moved.teleport{17.5, 3.5})
    live.replacement = place(live.ship, "fixture-voidship-armor-target", point.x, point.y)
  elseif tick == 102 then
    assert(call("round_status", live.shell.round_id).stage == "incoming")
    assert(call("round_status", live.torpedo.round_id).stage == "incoming")
    game.auto_save("voidship-crossfire-flight")
  elseif tick == live.shell.impact_tick + 1 then
    near(live.replacement.health, live.replacement.max_health - 20000, "shell hit the selected cell")
    near(live.moved.health, live.moved.max_health, "shell followed a structure away from its cell")
    near(live.torpedo_hull.health, live.torpedo_hull.max_health, "shell damaged a different cell")
  elseif tick == live.torpedo.impact_tick - 1 then
    near(live.torpedo_hull.health, live.torpedo_hull.max_health, "torpedo dealt damage in flight")
    live.shield.energy = 25000000
  elseif tick == live.torpedo.impact_tick + 1 then
    near(live.torpedo_hull.health, live.torpedo_hull.max_health - 8000, "rebalanced torpedo shield spill")
    near(live.shield.energy, 0, "arriving torpedo entered the shield")
    assert(#marker(live.ship.surface, point) == 0, "impact left a warning behind")
    assert(not call("round_status", live.empty_shot.round_id))
    local empty_flash = false
    for _, image in pairs(rendering.get_all_objects("tech-priests")) do
      if image.surface == live.ship.surface and image.type == "light" and image.scale > 4 then
        local pos = image.target.position
        if pos and pos.x == live.empty_cell.x and pos.y == live.empty_cell.y then empty_flash = true end
      end
    end
    assert(empty_flash, "empty selected cell did not get the impact flash")
  end
  for _, test in pairs(storage.cases) do
    if tick == test.entry + 1 then verify_entry(test) end
    if tick == test.entry + 17 then
      local current = call("round_status", test.id)
      if current then
        assert(current.position.y < test.first_y - 2, "incoming round did not move")
        assert(test.trail.valid and test.trail.sprite_height > test.early_length * 2, "plume did not build up")
        assert(test.brackets.sprite_width < test.initial_size and test.brackets.color.a ~= test.initial_alpha,
          "target bracket did not tighten and pulse")
        local mote_present = false
        for _, object in pairs(rendering.get_all_objects("tech-priests")) do
          if object.surface == test.ship.surface and object.type == "animation"
              and object.animation == "tp-voidship-fx-wake-mote" and not object.target.entity then
            mote_present = true
          end
        end
        assert(mote_present, "plume did not leave a decaying world-space wake")
      end
    end
  end
  if tick == 420 then
    for _, test in pairs(storage.cases) do
      assert(test.intercepted and test.damage > 0, test.turret .. " did not stop " .. test.projectile)
      assert(not call("round_status", test.id), "interception left flight state behind")
      assert(#marker(test.ship.surface, point) == 0, "interception left a warning behind")
      near(test.hull.health, test.hull.max_health, "intercepted missile damaged its intended cell")
      log("VOIDSHIP_INTERCEPT " .. test.turret .. " " .. test.projectile .. " damage=" .. test.damage)
    end
    log("TECH_PRIESTS_CROSSFIRE_PASS: hostile stock gun, laser, rocket and railgun interception of both rounds; "
      .. "64-tile open-space approach, exact cell warnings, fixed destinations, and shielded impacts.")
    script.finish_test(true)
  end
end)
