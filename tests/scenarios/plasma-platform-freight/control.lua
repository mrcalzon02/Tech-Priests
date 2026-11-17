-- Factorio 2.1 with Tech Priests and Space Age. Allow 22,000 ticks.
local fuel = "tp-mh7-contained-metallicized-pellet"
local shell = "tp-mh7-empty-pressure-shell"
local reactors = {
  {name = "mars-plasma-reactor-minoris", position = {-7, 0}, watts = 1e6},
  {name = "mars-plasma-reactor-majoris", position = {0, -10}, watts = 2e6},
  {name = "mars-plasma-reactor-maximus", position = {12, -10}, watts = 4e6},
}

local legendary = {name = "mars-plasma-reactor-maximus", position = {-15, 5}, quality = "legendary"}

local function create(surface, name, position)
  return assert(surface.create_entity{name = name, position = position, force = "player"})
end

local function create_platform(force)
  local platform = force.create_space_platform{
    name = "Plasma freight", planet = "nauvis", starter_pack = "space-platform-starter-pack",
  }
  local hub = assert(platform.apply_starter_pack())
  local space = hub.surface
  space.request_to_generate_chunks({0, 0}, 2)
  space.force_generate_chunk_requests()
  local floor = {}
  for x = -20, 20 do
    for y = -17, 9 do
      floor[#floor + 1] = {name = "space-platform-foundation", position = {x, y}}
    end
  end
  space.set_tiles(floor)
  for _, spec in ipairs(reactors) do
    assert(hub.get_item_count(spec.name) == 0)
    assert(space.can_place_entity{name = spec.name, position = spec.position, force = force,
      build_check_type = defines.build_check_type.manual}, spec.name .. " must fit the platform")
    assert(not space.can_place_entity{name = spec.name, position = {40, -10}, force = force,
      build_check_type = defines.build_check_type.manual}, spec.name .. " cannot float off the platform")
    assert(space.create_entity{name = "entity-ghost", inner_name = spec.name, position = spec.position, force = force})
    local power = {}
    for _, grade in ipairs({"normal", "uncommon", "rare", "epic", "legendary"}) do
      power[#power + 1] = prototypes.entity[spec.name].get_max_energy_production(grade) * 60
    end
    log(spec.name .. " chassis watts by quality: " .. table.concat(power, ", "))
  end
  assert(space.can_place_entity{name = legendary.name, quality = legendary.quality, position = legendary.position, force = force})
  assert(space.create_entity{name = "entity-ghost", inner_name = legendary.name, quality = legendary.quality,
    position = legendary.position, force = force})
  assert(space.has_global_electric_network)
  storage.accumulator = create(space, "accumulator", {8, 2})
  storage.accumulator.energy = 0
  return hub
end

local function prepare_freight()
  local nauvis = game.surfaces.nauvis
  nauvis.request_to_generate_chunks({0, 0}, 2)
  nauvis.force_generate_chunk_requests()
  create(nauvis, "cargo-landing-pad", {0, -12})
  create(nauvis, "substation", {0, 0})
  local power = create(nauvis, "electric-energy-interface", {0, 4})
  power.power_production = 12e6 / 60
  power.power_usage = 0
  local fuel_silo = create(nauvis, "rocket-silo", {-9, 0})
  local chassis_silo = create(nauvis, "rocket-silo", {9, 0})
  fuel_silo.rocket_parts = fuel_silo.prototype.rocket_parts_required
  chassis_silo.rocket_parts = chassis_silo.prototype.rocket_parts_required
  local fuel_cargo = fuel_silo.get_inventory(defines.inventory.rocket_silo_rocket)
  local chassis_cargo = chassis_silo.get_inventory(defines.inventory.rocket_silo_rocket)
  assert(fuel_cargo.insert{name = fuel, count = 10} == 10)
  for i = 1, 10 do
    assert(fuel_cargo[i].count == 1)
    fuel_cargo[i].tags = {test_batch = i}
  end
  for _, spec in ipairs(reactors) do
    assert(chassis_cargo.insert{name = spec.name, count = 1} == 1)
  end
  assert(chassis_cargo.insert{name = legendary.name, quality = legendary.quality, count = 1} == 1)
  return {fuel_silo, chassis_silo}
end

script.on_init(function()
  assert(script.active_mods["space-age"], "Space Age required")
  assert(prototypes.item[fuel].fuel_value == 240e6 and prototypes.item[fuel].weight == 100000)
  assert(prototypes.item[fuel].stack_size == 1 and prototypes.item[shell].stack_size == 20)
  for _, phase in ipairs({"raw", "forged"}) do
    for _, suffix in ipairs({"", "-waning", "-degraded", "-critical"}) do
      assert(prototypes.item["tp-mh7-" .. phase .. "-metallicized-pellet" .. suffix].stack_size == 1)
    end
  end
  assert(prototypes.item["tp-mh7-inert-pellet"].stack_size == 100)
  storage.hub = create_platform(game.forces.player)
  storage.silos = prepare_freight()
end)

local function unload_canisters()
  local hub = storage.hub
  if hub.get_item_count(fuel) ~= 10 or hub.surface.count_entities_filtered{type = "burner-generator"} ~= 4 then
    return false
  end
  local inventory = hub.get_inventory(defines.inventory.hub_main)
  local batches = {}
  for i = 1, #inventory do
    local stack = inventory[i]
    if stack.valid_for_read and stack.name == fuel then
      local batch = stack.tags.test_batch
      assert(stack.count == 1 and batch >= 1 and batch <= 10 and not batches[batch], "freight identity")
      batches[batch] = true
    end
  end
  assert(storage.accumulator.energy == 0, "unexpected platform power before fueling")
  storage.generators = {}
  for i, spec in ipairs(reactors) do
    local generator = assert(hub.surface.find_entity(spec.name, spec.position))
    assert(hub.get_item_count(spec.name) == 0, spec.name .. " construction item was not consumed")
    if i > 1 then
      assert(generator.get_fuel_inventory()[1].transfer_stack(inventory.find_item_stack(fuel)))
    end
    storage.generators[i] = generator
  end
  assert(hub.get_item_count(fuel) == 8)
  -- Two charged reactors bootstrap the electric inserter. Stop it after one delivery to meter one can.
  storage.arm = assert(hub.surface.create_entity{name = "inserter", position = {-4.5, 0.5},
    force = hub.force, direction = defines.direction.east})
  log("Platform received ten individually tagged fuel canisters and built three normal reactors and one legendary Maximus from the second rocket")
  return true
end

script.on_event(defines.events.on_tick, function()
  local arm = storage.arm
  if not arm then return end
  if arm.held_stack.valid_for_read then
    assert(arm.pickup_target == storage.hub and arm.drop_target == storage.generators[1], "hub-to-Minoris reach")
    assert(arm.held_stack.name == fuel and arm.held_stack.tags.test_batch, "inserter must pick up landed cargo")
    storage.arm_picked = true
  elseif storage.arm_picked then
    arm.disabled_by_script = true
    storage.arm = nil
    storage.arm_delivered = true
  end
end)

script.on_nth_tick(60, function(event)
  if not storage.fueled_at then
    for i, silo in pairs(storage.silos) do
      if silo.launch_rocket{type = defines.cargo_destination.station, station = storage.hub} then
        storage.silos[i] = nil
      end
    end
    if unload_canisters() then storage.fueled_at = event.tick end
    assert(event.tick < 6000, "freight or platform construction timed out")
    return
  end

  local age = event.tick - storage.fueled_at
  if age == 600 then
    assert(storage.arm_delivered and storage.hub.get_item_count(fuel) == 7, "platform inserter failed to fuel Minoris")
    log("The hub inserter fed one landed canister to Minoris; platform accumulator charge: " .. storage.accumulator.energy .. " J")
    assert(storage.accumulator.energy > 1e6, "reactors failed to charge a platform accumulator")
    storage.load = create(storage.hub.surface, "electric-energy-interface", {12, 2})
    storage.load.power_production = 0
    storage.load.energy = 0
    storage.load.power_usage = 8e6 / 60
  elseif age == 1200 or age == 1260 then
    storage.remaining = storage.remaining or {}
    for i, spec in ipairs(reactors) do
      local remaining = storage.generators[i].burner.remaining_burning_fuel
      if age == 1260 then
        assert(math.abs(storage.remaining[i] - remaining - spec.watts) < 100, spec.name .. " full-load rate")
      end
      storage.remaining[i] = remaining
    end
  elseif age == 16020 then
    local stats = storage.hub.surface.global_electric_network_statistics
    for i, spec in ipairs(reactors) do
      local produced = stats.get_input_count(spec.name) + stats.get_output_count(spec.name)
      assert(math.abs(produced - 240e6) < 100, spec.name .. " orbital electrical yield " .. produced)
      assert(storage.generators[i].status == defines.entity_status.no_fuel)
      log(spec.name .. " supplied " .. produced .. " J on the platform")
    end
    assert(storage.hub.get_item_count(fuel) == 7)
    local hub = storage.hub
    local generator = assert(hub.surface.find_entity({name = legendary.name, quality = legendary.quality}, legendary.position))
    assert(generator.quality.name == "legendary")
    storage.elite = generator
    local cargo = hub.get_inventory(defines.inventory.hub_main)
    assert(generator.get_fuel_inventory()[1].transfer_stack(cargo.find_item_stack(fuel)))
    storage.load.power_usage = 20e6 / 60
  elseif age == 16080 then
    storage.elite_remaining = storage.elite.burner.remaining_burning_fuel
  elseif age == 16140 then
    local used = storage.elite_remaining - storage.elite.burner.remaining_burning_fuel
    assert(math.abs(used - 10e6) < 100, "legendary Maximus burn rate")
    log("Legendary Maximus, joules of canister consumed in one second: " .. used)
  elseif age == 17580 then
    assert(storage.elite.status == defines.entity_status.no_fuel, "legendary Maximus full-load burn")
    local stats = storage.hub.surface.global_electric_network_statistics
    local item = {name = legendary.name, quality = legendary.quality}
    local output = stats.get_input_count(item) + stats.get_output_count(item)
    assert(math.abs(output - 240e6) < 100, "legendary Maximus electrical yield")
    log("Legendary Maximus, joules generated from one normal canister: " .. output)
    assert(storage.hub.get_item_count(fuel) == 6)
    script.finish_test(true)
  end
end)
