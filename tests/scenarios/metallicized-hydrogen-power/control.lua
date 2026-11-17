-- Run as a separate Factorio 2.1 test scenario with only the Tech Priests mod enabled.
local fuel = "tp-mh7-contained-metallicized-pellet"
local tiers = {"minoris", "majoris", "maximus"}
local keys = {"purifier", "electrolyzer", "compressor", "crucible", "forge", "fabricator", "assembler"}

script.on_init(function()
  assert(not script.active_mods["tp-hydrogen-production"] and not script.active_mods["tp-mh7-pellet-decay"])
  local force = game.forces.player
  force.technologies["tp-metallicized-hydrogen-production"].researched = true
  for _, key in ipairs(keys) do
    local recipe = force.recipes["tp-hydrogen-build-" .. key]
    assert(recipe and recipe.enabled, key .. " construction recipe missing")
    local product = recipe.products[1]
    local machine = prototypes.item[product.name].place_result
    assert(machine and machine.type == "assembling-machine", key .. " cannot be placed")
  end

  local surface = game.surfaces[1]
  surface.request_to_generate_chunks({75, 12}, 4)
  surface.force_generate_chunk_requests()
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
    assert(not inventory.can_insert{name = "tp-mh7-inert-pellet", count = 1})
    assert(inventory.insert{name = fuel, count = 1} == 1)
    storage.grids[i] = {reactor = reactor, load = load, pole = pole}
  end
end)

script.on_event(defines.events.on_tick, function(event)
  if event.tick ~= 7500 then return end
  for _, grid in ipairs(storage.grids) do
    local stats = grid.pole.electric_network_statistics
    local produced = stats.get_input_count(grid.reactor.name) + stats.get_output_count(grid.reactor.name)
    local consumed = stats.get_input_count(grid.load.name) + stats.get_output_count(grid.load.name)
    assert(math.abs(produced - prototypes.item[fuel].fuel_value) < 100, grid.reactor.name .. " fuel yield")
    assert(math.abs(produced - consumed) < 100, grid.reactor.name .. " load mismatch")
    assert(grid.reactor.status == defines.entity_status.no_fuel, grid.reactor.name .. " did not finish burning")
    log(grid.reactor.name .. " supplied " .. produced .. " joules")
  end
  script.finish_test(true)
end)
