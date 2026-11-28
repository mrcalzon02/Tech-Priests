local config = require("__tech-priests__/hydrogen/config")
local decay = "tp-mh7-pellet-decay"
local materials = config.formed_stages[1].name
local has_quality = script.feature_flags.quality
local grades = has_quality and {"normal", "uncommon", "rare", "epic", "legendary"} or {"normal"}

local function check_grades()
  local stock = game.create_inventory(5)
  for p, pellet in ipairs(grades) do
    for s, shell in ipairs(grades) do
      stock[1].set_stack{name = materials, quality = pellet, health = .75}
      stock[2].set_stack{name = config.shell, quality = shell, health = .5}
      assert(remote.call(decay, "seal", stock[1], stock[2], stock[3]))
      local fuel = stock[3]
      assert(fuel.quality.name == grades[math.min(p, s)] and fuel.health == .75)
      assert(not stock[1].valid_for_read and not stock[2].valid_for_read)
      local remaining = fuel.tags.mh7_remaining_ticks
      assert(remote.call(decay, "unseal", fuel, stock[4], stock[5]))
      assert(stock[4].quality.name == pellet and stock[4].health == .75)
      assert(stock[5].quality.name == shell and stock[5].health == .5)
      local deadline = script.feature_flags.spoiling and stock[4].spoil_tick or stock[4].tags.mh7_spoil_tick
      assert(deadline - game.tick == remaining and not fuel.valid_for_read)
      stock.clear()
    end
  end
  local legacy_grade = grades[#grades]
  stock[1].set_stack{name = config.contained, quality = legacy_grade, health = .5, tags = {
    mh7_raw_name = materials, mh7_remaining_ticks = 239, mh7_integrity = .5,
    mh7_shell_quality = "normal", mh7_shell_health = .75,
  }}
  assert(remote.call(decay, "unseal", stock[1], stock[2], stock[3]))
  assert(stock[2].quality.name == legacy_grade and stock[3].quality.name == "normal")
  stock.destroy()
end

script.on_init(function()
  check_grades()
  local force = game.forces.player
  force.technologies["tp-metallicized-hydrogen-production"].researched = true
  if has_quality then
    for _, tech in ipairs({"quality-module", "epic-quality", "legendary-quality"}) do
      force.technologies[tech].researched = true
    end
  end
  local surface = game.surfaces[1]
  surface.request_to_generate_chunks({30, 0}, 3)
  surface.force_generate_chunk_requests()
  local function place(name, x, y, quality)
    return assert(surface.create_entity{name = name, force = force, position = {x, y},
      quality = quality or "normal", raise_built = true})
  end
  for i, key in ipairs({"purifier", "electrolyzer", "compressor", "crucible", "forge", "fabricator", "assembler"}) do
    local product = force.recipes["tp-hydrogen-build-" .. key].products[1]
    local machine = place(product.name, i * 8, 0, grades[#grades])
    local inv = machine.get_module_inventory()
    if key == "purifier" then
      assert(not inv or #inv == 0)
    else
      assert(#inv == 4 and inv.insert{name = "speed-module", count = 4} == 4, key .. " speed slots")
      inv.clear()
      assert(inv.insert{name = "efficiency-module", count = 4} == 4, key .. " efficiency slots")
      inv.clear()
      assert(not inv.can_insert{name = "productivity-module"}, key .. " allows productivity")
      if has_quality then
        local grades_product = key == "fabricator" or key == "crucible"
        assert(inv.can_insert{name = "quality-module"} == grades_product, key .. " quality modules")
      end
    end
  end
  local crucible = place("tp-mh7-review-crucible", 0, 10)
  local press = place("tp-mh7-review-fabricator", 8, 10)
  crucible.set_recipe("tp-mh7-review-metallize")
  place("substation", 4, 10)
  local power = place("electric-energy-interface", 4, 14)
  power.power_production = 100e6 / 60
  power.power_usage = 0
  if has_quality then
    assert(crucible.get_module_inventory().insert{name = "quality-module-3", quality = "legendary", count = 4} == 4)
  end
  press.set_recipe("tp-mh7-review-hydroform", grades[#grades])
  assert(press.get_inventory(defines.inventory.crafter_input).insert{name = "steel-plate", quality = grades[#grades], count = 2} == 2)
  assert(press.insert_fluid{name = "water", amount = 20} == 20)
  storage.crucible, storage.press = crucible, press
  storage.forge = place("tp-mh7-review-forge", 1, 5)
  storage.assembler = place("tp-mh7-canister-assembler", 8, 5)
  storage.output, storage.upgraded = 0, 0
end)

local function exercise_machine_windows()
  local player = assert(game.get_player(1))
  if not player.character then
    player.set_controller{type = defines.controllers.god}
    assert(player.create_character())
  end
  for _,machine in ipairs({storage.forge,storage.assembler}) do
    player.teleport({machine.position.x,machine.position.y+3},machine.surface)
    player.opened=machine
    assert(player.opened==machine and not player.gui.screen.tp_hydrogen_machine,"native machine GUI was intercepted")
    local inv=machine.get_module_inventory()
    assert(#inv==4 and not inv.can_insert{name="productivity-module"})
    assert(inv.insert{name="speed-module-3",count=3,quality=grades[#grades]}==3)
    if machine==storage.assembler then
      local grade=grades[3] or "normal"
      machine.set_recipe("tp-mh7-native-seal-fresh",grade)
      assert(machine.insert{name=config.shell,count=1,quality=grade}==1)
      assert(machine.insert{name=materials,count=1,quality=grade}==1)
    else
      machine.set_recipe("tp-mh7-native-forge-fresh",grades[#grades])
      assert(machine.insert{name=config.stages[1].name,count=1,quality=grades[#grades]}==1)
    end
    player.opened=nil
  end
end

script.on_event(defines.events.on_tick, function(event)
  if event.tick == 5 then exercise_machine_windows() end
  local crucible, press = storage.crucible, storage.press
  if event.tick % 10 == 0 then
    local formed = storage.forge.get_output_inventory()[1]
    if formed.valid_for_read and not storage.forged then
      assert(formed.name==materials and formed.quality.name==grades[#grades])
      assert(event.tick<24*60+5,"speed modules did not accelerate native pressing")
      storage.forged = true
      formed.clear()
    end
    crucible.insert_fluid{name = "tp-mh7-review-compressed-hydrogen", amount = 100}
    local pellet = crucible.get_output_inventory()[1]
    if pellet.valid_for_read then
      assert(pellet.name == config.stages[1].name and pellet.count == 1)
      storage.output = storage.output + 1
      if pellet.quality.level > 0 then storage.upgraded = storage.upgraded + 1 end
      pellet.clear()
    end
  end
  if event.tick < 6000 or (has_quality and storage.upgraded == 0) then return end
  assert(storage.output > 3 and storage.forged)
  local shell = press.get_output_inventory()[1]
  assert(shell.valid_for_read and shell.name == config.shell and shell.quality.name == grades[#grades])
  local sealed = storage.assembler.get_output_inventory()[1]
  local expected = grades[3] or "normal"
  assert(sealed.valid_for_read and sealed.name == config.contained and sealed.quality.name == expected)
  assert(storage.assembler.get_output_inventory().get_item_count(config.contained)==1,"native sealing batch incomplete")
  assert(storage.assembler.get_module_inventory().get_item_count() == 3, "module loss during recipe changes")
  log("Hydrogen quality: " .. (#grades)^2 .. " grade combinations, " .. storage.upgraded ..
    " quality upgrades in " .. storage.output .. " crucible crafts; hydroformed " .. shell.quality.name .. " shell")
  script.finish_test(true)
end)
