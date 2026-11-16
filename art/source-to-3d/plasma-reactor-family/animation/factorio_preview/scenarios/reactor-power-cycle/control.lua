-- Opt-in headless acceptance scenario. Each rig has its own isolated electrical network.
local names = {"minoris", "majoris", "maximus"}
local directions = {defines.direction.north, defines.direction.east, defines.direction.south, defines.direction.west}

local function spawn(surface, name, pos, dir)
  local entity = surface.create_entity{name = name, position = pos, direction = dir or defines.direction.north, force = "player"}
  assert(entity and entity.valid, "Could not place " .. name)
  return entity
end

script.on_init(function()
  local surface = game.surfaces[1]
  surface.request_to_generate_chunks({64, 48}, 4)
  surface.force_generate_chunk_requests()
  storage.tests = {}
  for t, class in ipairs(names) do
    for i, dir in ipairs(directions) do
      local x, y = 36 * i, 36 * t
      local reactor = spawn(surface, "mars-plasma-reactor-" .. class, {x,y}, dir)
      assert(reactor.direction == dir, "Placed direction mismatch for " .. class)
      -- Exercise the same cardinal rotation used by the player's rotate action.
      for turn = 1, 4 do
        assert(reactor.rotate(), "In-game rotation refused for " .. class)
        local expected = directions[(i - 1 + turn) % 4 + 1]
        assert(reactor.direction == expected, "Incorrect rotated direction for " .. class)
      end
      local pole = spawn(surface, "substation", {x+6,y})
      local sink = spawn(surface, "electric-energy-interface", {x+8,y+2})
      sink.power_production = 0
      sink.power_usage = 8000000 / 60
      sink.energy = 0
      table.insert(storage.tests, {g = reactor, pole = pole, sink = sink, class = class, dir = dir,
        working_ticks = 0, expected_work_ticks = 120 / (2 ^ (t - 1))})
    end
  end
end)

script.on_event(defines.events.on_tick, function(event)
  for _, test in ipairs(storage.tests) do
    local g, burner = test.g, test.g.burner
    if event.tick == 30 then
      assert(not burner.currently_burning, "Fuel unexpectedly present at startup")
      assert(g.status == defines.entity_status.no_fuel, "Expected initial no_fuel status")
      assert(assert(g.get_fuel_inventory()).insert{name = "wood", count = 1} == 1)
    elseif event.tick > 30 then
      if g.status == defines.entity_status.working and burner.currently_burning then
        test.working_ticks = test.working_ticks + 1
      end
    end
    if event.tick == 420 then
      local stats = test.pole.electric_network_statistics
      local joules = stats.get_input_count(g.name) + stats.get_output_count(g.name)
      local demand = stats.get_input_count(test.sink.name) + stats.get_output_count(test.sink.name)
      assert(math.abs(test.working_ticks - test.expected_work_ticks) <= 2,
        "Unexpected fuel burn duration at full load for " .. g.name .. ": " .. test.working_ticks)
      assert(joules > 0 and demand > 0, "No energy transfer recorded for " .. g.name)
      assert(g.get_fuel_inventory().is_empty() and not burner.currently_burning and g.status == defines.entity_status.no_fuel,
        "Expected exhausted generator to return to idle")
      log("MARS_POWER_CASE " .. helpers.table_to_json({tier = test.class, direction = test.dir,
        generator_joules = joules, load_joules = demand, fuel_items = 1, working_ticks = test.working_ticks, rotation_steps = 4, idle_active_idle = true}))
    end
  end
  if event.tick == 420 then
    log("MARS_POWER_PASS " .. helpers.table_to_json({cases = #storage.tests, tick = event.tick,
      sprite_resolution = settings.startup["mars-reactor-sprite-resolution"].value}))
    script.finish_test(true)
  end
end)
