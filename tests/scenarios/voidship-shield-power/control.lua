local projector_name = "tech-priests-voidship-void-shield"
local intake_name = "tech-priests-voidship-shield-power-intake"
local capacity = 25000000

local function near(actual, expected, tolerance, label)
  assert(math.abs(actual - expected) <= tolerance, label .. " got " .. actual .. ", wanted " .. expected)
end

local function set_power(watts)
  local generator = storage.generator
  generator.power_production = watts / 60
  generator.energy = 0
end

local function setup()
  assert(script.active_mods["tech-priests"])
  local force = game.forces.player
  force.technologies["space-platform"].researched = true
  local ship = assert(force.create_space_platform{
    name = "Shield power fixture", planet = "nauvis", starter_pack = "space-platform-starter-pack",
  })
  if not ship.hub then assert(ship.apply_starter_pack(true)) end
  local surface = ship.surface
  surface.request_to_generate_chunks({0, 0}, 2)
  surface.force_generate_chunk_requests()
  local deck = {}
  for x = -3, 18 do
    for y = -3, 17 do
      deck[#deck + 1] = {name = "space-platform-foundation", position = {x, y}}
    end
  end
  surface.set_tiles(deck, true, false, false)
  storage.projector = assert(surface.create_entity{name = projector_name,
    position = {12, 12}, force = force, raise_built = true})
  local intakes = surface.find_entities_filtered{name = intake_name}
  assert(#intakes == 1, "the shield needs one real power intake")
  storage.intake = intakes[1]
  storage.generator = assert(surface.create_entity{name = "electric-energy-interface",
    position = {6, 12}, force = force})
  storage.generator.electric_buffer_size = 100000
  set_power(2000000)
  near(storage.projector.energy, 0, 1, "fresh shield starts empty")
end

script.on_event(defines.events.on_tick, function(event)
  local tick = event.tick
  if tick == 1 then
    setup()
  elseif tick == 599 then
    assert(storage.intake.valid, "power intake was replaced during ordinary charging")
    log("Shield input after first ten seconds: " .. storage.intake.energy .. " J; supply buffer "
      .. storage.generator.energy .. " J; shield " .. storage.projector.energy .. " J")
  elseif tick == 600 then
    near(storage.projector.energy, 550000, 16000, "ten seconds at max input")
  elseif tick == 27000 then
    near(storage.projector.energy, 24750000, 22000, "charging after seven and a half minutes")
  elseif tick == 27600 then
    near(storage.projector.energy, capacity, 1, "full shield after the charging interval")
    set_power(100000)
  elseif tick == 28200 then
    near(storage.projector.energy, capacity, 2000, "continuous 100 kW holds the charge")
    set_power(50000)
  elseif tick == 29400 then
    local charge = storage.projector.energy
    assert(charge > 19800000 and charge < 21500000, "50 kW brownout left " .. charge .. " J")
    storage.charge_before_cut = charge
    storage.generator.destroy()
  elseif tick == 29700 then
    near(storage.charge_before_cut - storage.projector.energy, 2500000, 120000, "five seconds without power")
  elseif tick == 32700 then
    near(storage.projector.energy, 0, 1, "unpowered shield emptied")
    storage.projector.destroy()
  elseif tick == 32702 then
    assert(not storage.intake.valid, "destroyed shield left its intake consuming power")
    log("TECH_PRIESTS_SHIELD_POWER_PASS: native 1.2 MW intake; 5 percent conversion; slow full charge; "
      .. "100 kW continuous upkeep; brownout, offline discharge and removal.")
    script.finish_test(true)
  end
end)
