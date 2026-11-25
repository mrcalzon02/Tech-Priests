local interface = "tech_priests_voidship"
local macro = "tech-priests-voidship-macro-cannon"
local lance = "tech-priests-voidship-lance-battery"
local launcher = "tech-priests-voidship-prow-launcher"
local shield = "tech-priests-voidship-void-shield"
local facings = {defines.direction.north, defines.direction.east, defines.direction.south, defines.direction.west}
local compass = {"north", "east", "south", "west"}

local function call(method, ...)
  return remote.call(interface, method, ...)
end

local function ship(force, name)
  force.technologies["space-platform"].researched = true
  local platform = assert(force.create_space_platform{
    name = name, planet = "nauvis", starter_pack = "space-platform-starter-pack",
  })
  if not platform.hub then assert(platform.apply_starter_pack(true)) end
  platform.surface.request_to_generate_chunks({0, 0}, 2)
  platform.surface.force_generate_chunk_requests()
  return platform
end

local function deck(surface, x, y)
  local tiles = {}
  for dx = -2, 1 do
    for dy = -2, 1 do
      tiles[#tiles + 1] = {name = "space-platform-foundation", position = {x + dx, y + dy}}
    end
  end
  surface.set_tiles(tiles, true, false, false)
end

local function place(platform, prototype, x, y, direction)
  local surface = platform.surface
  local spec = {name = prototype, position = {x, y}, force = platform.force, direction = direction,
                raise_built = true, build_check_type = defines.build_check_type.manual}
  assert(not game.surfaces.nauvis.can_place_entity(spec), prototype .. " was accepted on a planet")
  deck(surface, x, y)
  surface.set_tiles({{name = "empty-space", position = {x - 2, y - 2}}}, true, false, false)
  assert(not surface.can_place_entity(spec), prototype .. " accepted a broken deck")
  deck(surface, x, y)
  assert(surface.can_place_entity(spec), prototype .. " rejected the full 4x4 deck")
  local entity = assert(surface.create_entity(spec))
  assert(entity.tile_width == 4 and entity.tile_height == 4 and entity.direction == direction)
  return entity
end

local function attached(entity, kind)
  local matches = {}
  for _, image in pairs(rendering.get_all_objects("tech-priests")) do
    if image.type == kind then
      local target = kind == "line" and image.from or image.target
      if target.entity == entity then matches[#matches + 1] = image end
    end
  end
  return matches
end

local function cap(entity, design, heading, frame, base)
  local status = assert(call("visual_status", entity))
  assert(status.base_direction == base and entity.direction == base, "traverse affected base direction")
  assert(status.displayed_heading == heading and status.frame == frame, "incorrect mounted pose")
  local matches = attached(entity, "animation")
  assert(#matches == 1, "expected one real Tech Priests turret animation")
  local image = matches[1]
  assert(image.surface == entity.surface and image.render_layer == "higher-object-above")
  assert(image.animation == ("tp-voidship-%s-%02d"):format(design, heading), "wrong authored turret heading")
  assert(image.animation_offset == frame and image.animation_speed == 0, "wrong authored pose on engine object")
  return image
end

local function traverse(entity, design, initial, base, settled)
  cap(entity, design, initial, 0, base)
  for heading = 0, 63 do
    assert(call("aim", entity, heading * 360 / 64) == heading)
    cap(entity, design, heading, 0, base)
  end
  assert(call("aim", entity, settled * 360 / 64) == settled)
  return cap(entity, design, settled, 0, base)
end

local function approx(actual, expected, label)
  assert(math.abs(actual - expected) < .1, label .. " got " .. tostring(actual) .. ", expected " .. tostring(expected))
end

local function setup()
  assert(script.active_mods["tech-priests"] and remote.interfaces[interface])
  assert(not script.active_mods["voidship-macro-candidate"] and not script.active_mods["voidship-shield-candidate"])
  local friendly, hostile = game.forces.player, game.create_force("voidship-native-hostile")
  friendly.set_friend(hostile, false)
  hostile.set_friend(friendly, false)
  friendly.set_cease_fire(hostile, false)
  hostile.set_cease_fire(friendly, false)
  local source, target_ship = ship(friendly, "Armory fixture"), ship(hostile, "Armory target")
  local planet = game.surfaces.nauvis
  planet.request_to_generate_chunks({0, 0}, 2)
  planet.force_generate_chunk_requests()
  deck(target_ship.surface, 16, 16)
  local target = assert(target_ship.surface.create_entity{
    name = "fixture-voidship-armor-target", position = {16.5, 16.5}, force = hostile,
  })
  local projector = place(target_ship, shield, -12, 16, facings[1])
  local backup = place(target_ship, shield, 6, 16, facings[1])
  assert(call("preview", projector) and #attached(projector, "light") == 4)
  local ripple = assert(attached(projector, "circle")[1])
  assert(ripple.radius < .5)

  projector.energy = 25000000
  target.health = 500
  local blocked = assert(call("apply_ship_damage", target, 1000, friendly.name, "physical"))
  approx(blocked.absorbed, 1000, "preemptive interception")
  approx(blocked.hull_damage, 0, "prevented lethal hit")
  approx(target.health, 500, "live hull behind generator")
  approx(projector.energy, 0, "intercept spent shield charge")
  target.health = target.max_health
  backup.energy = 25000000
  target.damage(100, friendly, "physical")
  approx(target.health, target.max_health, "native nonlethal shield protection")
  approx(backup.energy, 22500000, "second generator intercepts from elsewhere on deck")
  backup.energy = 0

  deck(source.surface, 22, 16)
  local ghost = assert(source.surface.create_entity{
    name = "entity-ghost", inner_name = macro, position = {22, 16}, direction = facings[2],
    force = friendly, raise_built = true,
  })
  local ghost_image = cap(ghost, "macro-cannon", 16, 0, facings[2])
  assert(ghost_image.color.a < .55)
  ghost.destroy()

  storage.motion, storage.target, storage.ripple = {}, target, ripple
  storage.shields = {projector, backup}
  local aimed = {9, 27, 42, 56}
  for i, facing in ipairs(facings) do
    local x = i * 6 - 12
    local cannon = place(source, macro, x, 16, facing)
    local battery = place(source, lance, x, 24, facing)
    local tube = place(source, launcher, x, 32, facing)
    local hull = target
    if i ~= 1 then
      deck(target_ship.surface, x, 32)
      hull = assert(target_ship.surface.create_entity{
        name = "fixture-voidship-armor-target", position = {x + .5, 32.5}, force = hostile,
      })
    end
    local shell_rack = cannon.get_inventory(defines.inventory.chest)
    assert(#shell_rack == 6 and shell_rack.insert{name = "iron-plate", count = 1} == 0)
    local rejected, reason = call("fire", cannon, target)
    assert(not rejected and reason == "no-shells")
    local heading, aim_lance = aimed[i], (aimed[i] + 7) % 64
    local image = traverse(cannon, "macro-cannon", (i - 1) * 16, facing, heading)
    traverse(battery, "lance-battery", (i - 1) * 16, facing, aim_lance)
    if i == 1 then
      cannon.direction = facings[3]
      assert(cap(cannon, "macro-cannon", heading, 0, facings[3]) == image)
      cannon.direction = facing
    end
    assert(shell_rack.insert{name = "artillery-shell", count = 2} == 2)
    local rejected, reason = call("fire", cannon, source.hub)
    assert(not rejected and reason == "same-platform")
    target_ship.space_location = "gleba"
    local rejected, reason = call("fire", cannon, target)
    assert(not rejected and reason == "out-of-range")
    target_ship.space_location = "nauvis"
    local shot = assert(call("fire", cannon, hull))
    approx(hull.health, hull.max_health, "macro damage before flight")
    assert(shot.entry_tick == 37 and shot.impact_tick == 251)
    assert(shot.shells_spent == 1 and shot.cooldown_until == game.tick + 900)
    assert(shell_rack.get_item_count("artillery-shell") == 1)
    local rejected, reason = call("fire", cannon, target)
    assert(not rejected and reason == "cooldown" and shell_rack.get_item_count("artillery-shell") == 1)
    assert(#attached(cannon, "light") == 1, "firing pose muzzle flash missing")
    assert(call("preview", battery))
    assert(#attached(battery, "line") == 0 and #attached(battery, "light") == 2)
    local rejected, reason = call("preview", tube, 5)
    assert(not rejected and reason == "invalid-bay")
    assert(call("preview", tube, i))
    local rocket = assert(attached(tube, "sprite")[1])
    assert(rocket.sprite == "tech-priests-voidship-censer-" .. compass[i])
    local plume = assert(attached(tube, "animation")[1])
    assert(plume.animation == "tp-voidship-fx-plasma-plume", "launch used the wrong drive effect")
    storage.motion[i] = {cannon = cannon, battery = battery, tube = tube, facing = facing,
      heading = heading, aim_lance = aim_lance, start = rocket.target.offset, hull = hull, round = shot.round_id}
  end
end

local macro_frames = {[4] = 1, [7] = 2, [12] = 3, [19] = 4, [29] = 5}
script.on_event(defines.events.on_tick, function(event)
  local tick = event.tick
  if tick == 1 then setup(); return end
  if macro_frames[tick] then
    for _, test in ipairs(storage.motion) do
      cap(test.cannon, "macro-cannon", test.heading, macro_frames[tick], test.facing)
      if tick == 19 then
        cap(test.battery, "lance-battery", test.aim_lance, 2, test.facing)
        assert(#attached(test.battery, "line") == 0)
        local offset = assert(attached(test.tube, "sprite")[1]).target.offset
        local dx, dy = offset[1] - test.start[1], offset[2] - test.start[2]
        assert(dx * dx + dy * dy > 1, "torpedo failed to leave launcher")
        assert(storage.ripple.valid and storage.ripple.radius > 1.8)
      end
    end
  elseif tick == 31 then
    for _, test in ipairs(storage.motion) do
      cap(test.battery, "lance-battery", test.aim_lance, 3, test.facing)
      local beams = attached(test.battery, "line")
      assert(#beams == 4, "charged lance did not fire both emitters")
      local angle = test.aim_lance * math.pi * 2 / 64
      local beam = beams[1]
      approx(beam.to.offset[1] - beam.from.offset[1], 8 * math.sin(angle) * math.cos(math.rad(6)),
             "beam follows turret rather than cardinal base")
    end
  elseif tick == 39 then
    for _, test in ipairs(storage.motion) do
      cap(test.cannon, "macro-cannon", test.heading, 0, test.facing)
      assert(#attached(test.tube, "sprite") == 0 and #attached(test.tube, "animation") == 0)
    end
    assert(not storage.ripple.valid)
  elseif tick == 67 then
    for _, test in ipairs(storage.motion) do
      cap(test.battery, "lance-battery", test.aim_lance, 0, test.facing)
      assert(#attached(test.battery, "line") == 0 and #attached(test.battery, "light") == 0)
    end
    local test = storage.motion[4]
    storage.doomed = cap(test.cannon, "macro-cannon", test.heading, 0, test.facing)
    test.cannon.destroy()
  elseif tick == 250 then
    storage.shields[1].energy, storage.shields[2].energy = 25000000, 12500000
    for _, test in ipairs(storage.motion) do
      assert(call("round_status", test.round).stage == "incoming")
      approx(test.hull.health, test.hull.max_health, "projectile dealt damage before reaching its cell")
    end
  elseif tick == 252 then
    for i, test in ipairs(storage.motion) do
      approx(test.hull.max_health - test.hull.health, i == 1 and 18500 or 20000, "macro shell shield spill")
      assert(not call("round_status", test.round))
      test.hull.health = test.hull.max_health
    end
  elseif tick == 900 then
    assert(not storage.doomed.valid, "removed cannon left orphan graphics")
    local result, reason = call("fire", storage.motion[1].cannon, storage.target)
    assert(not result and reason == "cooldown")
  elseif tick == 901 then
    local shot = assert(call("fire", storage.motion[1].cannon, storage.target))
    assert(shot.impact_tick == 1151)
  elseif tick == 1152 then
    approx(storage.target.max_health - storage.target.health, 20000, "reloaded macro strike")
    log("TECH_PRIESTS_VOIDSHIP_PASS: real mod; four-by-four orbital mounts; 512 independent heading/base pairs; "
      .. "native recoil, charge, torpedo bay effects; one artillery shell, 20,000 damage and 900-tick reload; shield interception.")
    script.finish_test(true)
  end
end)
