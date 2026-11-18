local NAME = "tech-priests-emergency-assembler"
local GRAPHICAL = GRAPHICAL or false
local function check(ok, message) assert(ok, "[ASSEMBLER V07 NATIVE] " .. message) end
local function output(site)
  return site.entity.get_output_inventory().get_item_count(site.product)
end
local function input(site)
  return site.entity.get_inventory(defines.inventory.crafter_input).get_item_count(site.ingredient)
end
local function screenshot(t, tick, label)
  if not GRAPHICAL then return end
  local name = string.format("%04d-%s.png", tick, label)
  game.take_screenshot{
    surface = game.surfaces["assembler-v07-native"], position = {0, -.5},
    resolution = {1600, 900}, zoom = 3, show_gui = false, force_render = true,
    path = "emergency-assembler-v07/" .. name,
  }
  t.screenshots[#t.screenshots + 1] = name
end

script.on_init(function()
  -- A private --create save uses freeplay's level script. Its crash-site
  -- cutscene ends in a pausing modal when a graphical player joins. Disable
  -- only that test-world introduction so native screenshot ticks can run.
  if remote.interfaces.freeplay then
    remote.call("freeplay", "set_skip_intro", true)
    remote.call("freeplay", "set_disable_crashsite", true)
  end
  local surface = game.create_surface("assembler-v07-native", {
    water = 0, default_enable_all_autoplace_controls = false,
    autoplace_settings = {
      entity = {treat_missing_as_default = false, settings = {}},
      decorative = {treat_missing_as_default = false, settings = {}},
    },
  })
  surface.request_to_generate_chunks({0, 0}, 2)
  surface.force_generate_chunk_requests()
  surface.always_day = true
  local tiles = {}
  for x = -15, 15 do for y = -10, 10 do
    tiles[#tiles + 1] = {name = "refined-concrete", position = {x, y}}
  end end
  surface.set_tiles(tiles)
  local force = game.forces.player
  force.recipes["copper-cable"].enabled = true
  force.recipes["iron-gear-wheel"].enabled = true
  storage.assembler_v07_test = {sites = {}, last_tick = 0, screenshots = {}, samples = {}}
  local t = storage.assembler_v07_test
  for index, facing in ipairs({"north", "east", "south", "west"}) do
    local entity = surface.create_entity{
      name = NAME, position = {-6 + (index - 1) * 4, .5},
      direction = defines.direction[facing], force = force,
    }
    check(entity and entity.valid, "real production assembler created")
    check(entity.direction == defines.direction[facing], "four native directions")
    local cable = index % 2 == 1
    local site = {
      entity = entity, direction = facing,
      recipe = cable and "copper-cable" or "iron-gear-wheel",
      ingredient = cable and "copper-plate" or "iron-plate",
      product = cable and "copper-cable" or "iron-gear-wheel",
      ingredient_per_craft = cable and 1 or 2,
      product_per_craft = cable and 2 or 1,
      inserted = 20, natural_starvation = false, recovered = false,
    }
    entity.set_recipe(site.recipe)
    check(entity.get_recipe().name == site.recipe, "real base recipe selected: " .. site.recipe)
    check(entity.insert{name = site.ingredient, count = 20} == 20, "real recipe ingredients inserted")
    check(entity.burner and entity.burner.remaining_burning_fuel == 0, "native chemical burner starts empty")
    t.sites[#t.sites + 1] = site
    if GRAPHICAL then
      rendering.draw_text{text = facing, surface = surface,
        target = {entity.position.x, 2}, color = {1, 1, 1}, alignment = "center", scale = .8}
    end
  end
  if GRAPHICAL then game.speed = 16 end
end)

local first_tick = true
script.on_event(defines.events.on_tick, function(event)
  local t = storage.assembler_v07_test
  if not t then return end
  local tick = event.tick
  -- Let the graphical renderer settle and drain screenshot requests at normal
  -- simulation speed around both exact twelve-second timing anchors.
  if GRAPHICAL then
    if tick == 342 or tick == 1062 then game.speed = 1 end
    if tick == 362 or tick == 1082 then game.speed = 16 end
  end
  if first_tick then
    first_tick = false
    if GRAPHICAL then game.speed = 16 end
    if t.last_tick > 0 then
      local working = 0
      for _, site in ipairs(t.sites) do
        if site.entity.is_crafting() then working = working + 1 end
      end
      t.resume = {saved_tick = t.last_tick, tick = tick, working = working}
      check(tick == t.last_tick + 1, "save resumes on exact next native tick")
      check(working == 4, "all real machines resume mid-production")
    end
  end
  for _, site in ipairs(t.sites) do
    local entity = site.entity
    check(entity.valid and entity.name == NAME, "production identity preserved")
    check(entity.direction == defines.direction[site.direction], "native direction preserved")
    if tick == 100 then
      check(output(site) == 0 and entity.crafting_progress == 0,
        "unfuelled production must remain idle")
      -- The engine may reserve one recipe batch before it obtains fuel.
      check(input(site) >= site.inserted - site.ingredient_per_craft,
        "unfuelled machine cannot consume more than its reserved native batch")
      site.initial_starvation = true
    elseif tick == 121 then
      check(entity.get_fuel_inventory().insert{name = "wood", count = 1} == 1,
        "one native wood starts the chemical burner")
    elseif tick == 500 then
      check(output(site) > 0 and entity.is_crafting(), "fuel starts actual recipe output")
      site.initial_working_output = output(site)
    end
    if tick >= 1450 and tick <= 1850 then
      if entity.burner.remaining_burning_fuel == 0 and entity.get_fuel_inventory().is_empty() then
        if not site.starved_at then
          site.starved_at = tick
          site.starved_output = output(site)
          site.starved_progress = entity.crafting_progress
        elseif tick >= site.starved_at + 120 then
          check(output(site) == site.starved_output, "natural fuel depletion stops output")
          check(math.abs(entity.crafting_progress - site.starved_progress) < .00001,
            "natural starvation freezes the actual crafting cycle")
          site.natural_starvation = true
        end
      end
    end
    if tick == 1900 then
      check(site.natural_starvation, "one wood must exhaust during this test")
      site.before_recovery = output(site)
      check(entity.get_fuel_inventory().insert{name = "coal", count = 2} == 2,
        "native coal restores the burner")
    elseif tick == 2300 then
      check(output(site) > site.before_recovery, "production recovers without recreation")
      site.recovered = true
    end
  end
  if tick == 520 then game.auto_save("emergency-assembler-v07-mid-cycle") end
  local labels = {
    [80] = "idle-no-fuel", [350] = "working-open", [500] = "working-cycle",
    [352] = "cycle-anchor", [1072] = "cycle-repeat",
    [680] = "working-late-cycle", [900] = "working-next-cycle",
    [1700] = "natural-fuel-starvation", [2100] = "recovered-working",
    [5350] = "finished-idle",
  }
  if tick == 352 or tick == 1072 then
    for _, site in ipairs(t.sites) do
      check(site.entity.is_crafting(), "continuous native production at twelve-second phase anchor")
    end
  end
  if labels[tick] then screenshot(t, tick, labels[tick]) end
  if tick % 100 == 0 then
    local sample = {tick = tick, machines = {}}
    for _, site in ipairs(t.sites) do
      sample.machines[#sample.machines + 1] = {
        direction = site.direction, output = output(site),
        progress = site.entity.crafting_progress, working = site.entity.is_crafting(),
        remaining_burning_fuel = site.entity.burner.remaining_burning_fuel,
      }
    end
    t.samples[#t.samples + 1] = sample
  end
  t.last_tick = tick
  if tick == 5400 then
    local rows = {}
    for _, site in ipairs(t.sites) do
      local finished = site.entity.products_finished
      local expected_crafts = site.inserted / site.ingredient_per_craft
      check(finished > 0, "native lifetime production counter advanced")
      check(input(site) == 0, "no ingredient loss or unconsumed stock")
      check(output(site) == expected_crafts * site.product_per_craft,
        "native recipe output exactly matches all supplied ingredient batches")
      check(not site.entity.is_crafting(), "finished machine returns to native idle")
      rows[#rows + 1] = {
        direction = site.direction, recipe = site.recipe, product = site.product,
        finished = finished, completed_batches = expected_crafts,
        output = output(site), input_remaining = input(site),
        initial_starvation = site.initial_starvation,
        initial_working_output = site.initial_working_output,
        natural_starvation = site.natural_starvation,
        starved_at = site.starved_at, starved_output = site.starved_output,
        recovered = site.recovered, exact_output_accounting = true,
      }
    end
    local result = {
      status = "PASS", production_source = true, tick = tick, sites = rows,
      resume = t.resume, screenshots = t.screenshots, samples = t.samples,
      real_recipes = {"copper-cable", "iron-gear-wheel"},
      real_fuel = {"wood", "coal"},
      graphical_client = GRAPHICAL,
    }
    helpers.write_file("emergency-assembler-v07/" .. (GRAPHICAL and "graphical.json" or "result.json"),
      helpers.table_to_json(result), false)
  end
end)
