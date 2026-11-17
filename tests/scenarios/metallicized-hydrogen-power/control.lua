-- Factorio 2.1 with Tech Priests, base or Space Age. Allow 45,200 ticks.
local fuel = "tp-mh7-contained-metallicized-pellet"
local tiers = {"minoris", "majoris", "maximus"}
local keys = {"purifier", "electrolyzer", "compressor", "crucible", "forge", "fabricator", "assembler"}
local machine_kw = {50, 200, 375, 2500, 200, 150, 125}
local reactor_watts = {1e6, 2e6, 4e6}
local shell = "tp-mh7-empty-pressure-shell"
local formed = "tp-mh7-forged-metallicized-pellet"
local critical = formed .. "-critical"
local canister_joules = 3e9

local function pellet_deadline(stack)
  if script.feature_flags.spoiling then return stack.spoil_tick end
  return stack.tags.mh7_spoil_tick
end

local function create_shell_first_line(surface, force)
  local function place(name, x, y, direction)
    return assert(surface.create_entity{
      name = name, position = {x, y}, direction = direction or defines.direction.north,
      force = force, raise_built = true,
    })
  end
  local line = {}
  line.sealer = place("tp-mh7-canister-assembler", 80, -20)
  line.shells = place("steel-chest", 80.5, -23.5)
  line.pellets = place("steel-chest", 76.5, -19.5)
  line.output = place("steel-chest", 83.5, -19.5)
  place("inserter", 80.5, -22.5, defines.direction.north)
  place("inserter", 77.5, -19.5, defines.direction.west)
  place("inserter", 82.5, -19.5, defines.direction.west)
  place("substation", 84, -25)
  local supply = place("electric-energy-interface", 86, -25)
  supply.power_production = 1e6 / 60
  supply.power_usage = 0
  assert(line.shells.insert{name = shell, count = 40} == 40)
  return line
end

-- Compare four powered shell machines with four consecutive cycles in one forge.
local function create_forming_line(surface, force)
  local function place(name, x, y)
    return assert(surface.create_entity{name = name, position = {x, y}, force = force, raise_built = true})
  end
  local forge = place("tp-mh7-review-forge", 100.5, -44.5)
  local fabricators = {}
  for _, position in ipairs({{96, -50}, {104, -50}, {96, -55}, {104, -55}}) do
    local machine = place("tp-mh7-review-fabricator", position[1], position[2])
    fabricators[#fabricators + 1] = machine
  end
  place("substation", 100, -50)
  local supply = place("electric-energy-interface", 100, -54)
  supply.power_production = 2e6 / 60
  supply.power_usage = 0
  return {forge = forge, fabricators = fabricators}
end

local function check_process(force, recipe_name, input, input_amount, output, output_amount)
  local recipe = assert(force.recipes[recipe_name])
  assert(recipe.enabled and recipe.energy == 8, recipe_name .. " unlock or crafting time")
  local ingredients, products = recipe.ingredients, recipe.products
  assert(#ingredients == 1 and ingredients[1].name == input and ingredients[1].amount == input_amount,
    recipe_name .. " input")
  assert(products[1].name == output and products[1].amount == output_amount and products[1].independent_probability == 1,
    recipe_name .. " output")
end

script.on_init(function()
  assert(not script.active_mods["tp-hydrogen-production"] and not script.active_mods["tp-mh7-pellet-decay"])
  local force = game.forces.player
  force.technologies["tp-metallicized-hydrogen-production"].researched = true
  assert(prototypes.item[fuel].fuel_value == canister_joules, "sealed canister must supply 3 GJ")
  for index, key in ipairs(keys) do
    local recipe = force.recipes["tp-hydrogen-build-" .. key]
    assert(recipe and recipe.enabled, key .. " construction recipe missing")
    local product = recipe.products[1]
    local machine = prototypes.item[product.name].place_result
    assert(machine and machine.type == "assembling-machine", key .. " cannot be placed")
    assert(math.abs(machine.get_max_energy_usage("normal") * 60 - machine_kw[index] * 1000) < 1, key .. " power draw")
  end

  local surface = game.surfaces[1]
  surface.request_to_generate_chunks({75, 12}, 4)
  surface.force_generate_chunk_requests()
  local furnace = assert(surface.create_entity{name = "stone-furnace", position = {65, 0}, force = force})
  local chemical = furnace.get_fuel_inventory()
  assert(chemical.insert{name = "coal", count = 1} == 1)
  chemical.clear()
  assert(chemical.insert{name = fuel, count = 1} == 0, "plasma canister entered a chemical burner")
  furnace.destroy()
  log("Stone furnace accepted coal and rejected the sealed plasma canister")
  local gas, liquid = "tp-mh7-review-hydrogen-gas", "tp-mh7-review-compressed-hydrogen"
  check_process(force, "tp-mh7-review-compress", gas, 500, liquid, 10)
  check_process(force, "tp-mh7-review-metallize", liquid, 20, "tp-mh7-raw-metallicized-pellet", 1)
  local compressor = assert(surface.create_entity{name = "tp-mh7-review-compressor", position = {70, 0}, force = force})
  assert(compressor.insert_fluid{name = gas, amount = 500} == 500, "compressor cannot accept a full batch")
  compressor.destroy()
  local forging = force.recipes["tp-mh7-review-forge-work"]
  local hydroforming = force.recipes["tp-mh7-review-hydroform"]
  assert(forging.energy == 24 and hydroforming.energy == 4 * forging.energy, "four hydroformers per forge")
  local chest = assert(surface.create_entity{name = "steel-chest", position = {75, 0}, force = force})
  local inventory = chest.get_inventory(defines.inventory.chest)
  assert(inventory.insert{name = critical, count = 1} == 1)
  remote.call("tp-mh7-pellet-decay", "register_inventory", inventory)
  storage.pellets = {inventory = inventory, first_due = pellet_deadline(inventory[1])}
  storage.forming_line = create_forming_line(surface, force)
  storage.shell_first = create_shell_first_line(surface, force)
  storage.grids = {}
  for i, tier in ipairs(tiers) do
    local x = i * 50
    local function create(name, dx)
      return assert(surface.create_entity{name = name, position = {x + dx, 12}, force = force})
    end
    local reactor = create("mars-plasma-reactor-" .. tier, 0)
    local pole = create("substation", 6)
    local load = create("electric-energy-interface", 8)
    load.power_production = 0
    load.power_usage = 8000000 / 60
    load.energy = 0
    local inventory = reactor.get_fuel_inventory()
    assert(inventory.is_empty() and inventory.can_insert{name = fuel, count = 1})
    local refused = 0
    for name, prototype in pairs(prototypes.item) do
      if prototype.fuel_value > 0 and name ~= fuel then
        assert(not inventory.can_insert{name = name, count = 1}, reactor.name .. " accepted " .. name)
        assert(inventory.insert{name = name, count = 1} == 0, reactor.name .. " inserted " .. name)
        refused = refused + 1
      end
    end
    assert(refused > 0)
    for _, name in ipairs({"tp-mh7-raw-metallicized-pellet", formed, critical, shell, "tp-mh7-inert-pellet"}) do
      assert(inventory.insert{name = name, count = 1} == 0, reactor.name .. " inserted " .. name)
    end
    log(reactor.name .. " rejected all " .. refused .. " other fuel items and all tested unsealed material")
    assert(inventory.insert{name = fuel, count = 1} == 1)
    storage.grids[i] = {reactor = reactor, load = load, pole = pole}
  end
end)

script.on_event(defines.events.on_tick, function(event)
  local pellets = storage.pellets
  if event.tick == pellets.first_due - 60 then
    assert(pellets.inventory.insert{name = critical, count = 1} == 1)
    remote.call("tp-mh7-pellet-decay", "initialize_stack", pellets.inventory[2])
    assert(pellets.inventory[1].count == 1 and pellets.inventory[2].count == 1)
    assert(pellet_deadline(pellets.inventory[2]) > pellets.first_due)
  elseif event.tick == pellets.first_due + 5 then
    assert(pellets.inventory.get_item_count("tp-mh7-inert-pellet") == 1, "first pellet must expire alone")
    assert(pellets.inventory.get_item_count(critical) == 1, "second pellet must remain live")
  end
  local line = storage.forming_line
  if event.tick == 60 then
    for _, fabricator in ipairs(line.fabricators) do
      assert(fabricator.insert_fluid{name = "water", amount = 20} == 20, "water infeed")
      assert(fabricator.insert{name = "steel-plate", count = 2} == 2, "steel infeed")
    end
  end
  if event.tick <= 4545 and event.tick % 1500 == 45 then
    line.forge.get_output_inventory().clear()
  elseif event.tick <= 4560 and event.tick % 1500 == 60 then
    local count = (event.tick - 60) / 1500
    assert(line.forge.products_finished == count, "forge cadence")
    assert(line.forge.insert{name = "tp-mh7-raw-metallicized-pellet", count = 1} == 1)
  elseif event.tick == 5600 or event.tick == 6200 then
    local before = event.tick == 5600
    assert(line.forge.products_finished == (before and 3 or 4), "forge work clock")
    for _, fabricator in ipairs(line.fabricators) do
      assert(fabricator.get_output_inventory().get_item_count(shell) == (before and 0 or 1), "shell craft clock")
    end
  end
  if event.tick == 3000 then
    local line = storage.shell_first
    local job = remote.call("tp-mh7-assembler", "inspect", line.sealer)
    local queued = 0
    for _, stack in ipairs(job.stock) do
      if stack.name == shell then queued = queued + stack.count end
    end
    assert(queued == 3 and line.shells.get_item_count(shell) >= 36, "assembler overfilled with shells")
    assert(line.output.get_item_count(fuel) == 0 and line.sealer.can_insert{name = formed, count = 1},
      "shell queue blocked the first pellet")
    assert(line.pellets.insert{name = formed, count = 1} == 1)
  elseif event.tick == 4500 then
    local line = storage.shell_first
    assert(line.output.get_item_count(fuel) == 1, "first canister failed to reach the output chest")
    local job = remote.call("tp-mh7-assembler", "inspect", line.sealer)
    assert(job.completed == 1 and job.cycles == 1, "assembler failed to complete its powered cycle")
  end
  if event.tick == 600 or event.tick == 660 then
    for i, grid in ipairs(storage.grids) do
      local remaining = grid.reactor.burner.remaining_burning_fuel
      if event.tick == 600 then
        grid.last_fuel = remaining
      else
        assert(math.abs(grid.last_fuel - remaining - reactor_watts[i]) < 100, grid.reactor.name .. " full-load burn rate")
      end
    end
  end
  -- The 4 MW machine consumes a full canister in 45,000 game ticks.
  if event.tick ~= 45120 then return end
  for index, grid in ipairs(storage.grids) do
    local stats = grid.pole.electric_network_statistics
    local produced = stats.get_input_count(grid.reactor.name) + stats.get_output_count(grid.reactor.name)
    local consumed = stats.get_input_count(grid.load.name) + stats.get_output_count(grid.load.name)
    local remaining = grid.reactor.burner.remaining_burning_fuel
    local watts = reactor_watts[index]
    assert(math.abs(produced + remaining - canister_joules) < watts / 60 + 2000, grid.reactor.name .. " energy balance")
    assert(math.abs(produced - consumed) < 2000, grid.reactor.name .. " load mismatch")
    if index == 3 then
      assert(grid.reactor.status == defines.entity_status.no_fuel and math.abs(produced - canister_joules) < 2000)
    else
      assert(remaining > 0 and math.abs(produced - event.tick * watts / 60) < 2 * watts / 60)
    end
    log(grid.reactor.name .. " supplied " .. produced .. " joules; " .. remaining .. " joules remain")
  end
  script.finish_test(true)
end)
