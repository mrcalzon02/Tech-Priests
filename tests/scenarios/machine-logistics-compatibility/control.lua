local logistics = require("scripts.core.logistics_machine_fulfillment_0528")
local storage_roles = require("scripts.core.storage_role_authority_0686")
local discover
TechPriestsRuntimeTickBroker0600 = {
  register_service = function(service)
    discover = service.fn
    return true
  end,
}
TechPriestsStorageRoleAuthority0686 = storage_roles
TechPriestsWorkReservations0601 = {
  register_category = function() return true end,
  claim = function() return true end,
  release = function() return true end,
}

local custom = "tp-fixture-fuel"
local spent = "tp-fixture-spent-fuel"
local uncommon_plate = {name = "iron-plate", quality = "uncommon"}
local uncommon_gear = {name = "iron-gear-wheel", quality = "uncommon"}

local function entity(surface, name, x)
  return assert(surface.create_entity{name = name, position = {x, 0}, force = "player"})
end

script.on_init(function()
  local surface = game.surfaces[1]
  surface.request_to_generate_chunks({0, 0}, 1)
  surface.force_generate_chunk_requests()
  for _, obstacle in pairs(surface.find_entities_filtered{area = {{-2, -3}, {13, 3}},
      type = {"tree", "simple-entity", "cliff", "resource"}}) do
    obstacle.destroy()
  end
  local tiles = {}
  for x = -2, 13 do
    for y = -3, 3 do
      tiles[#tiles + 1] = {name = "grass-1", position = {x, y}}
    end
  end
  surface.set_tiles(tiles)

  local station = entity(surface, "steel-chest", 0)
  local priest = entity(surface, "character", 2)
  local machine = entity(surface, "tp-fixture-burner-assembler", 10)
  machine.disabled_by_script = true
  machine.set_recipe("iron-gear-wheel")
  local pair = {station = station, priest = priest, station_unit = station.unit_number, radius = 12}
  storage.tech_priests = {pairs_by_station = {[pair.station_unit] = pair}}
  storage.fixture = {pair = pair, machine = machine, phase = "blocked"}
end)

local function candidate(pair)
  pair.machine_logistics_candidate_0528 = nil
  logistics.root().cooldowns[tostring(pair.station_unit)] = nil
  discover(nil, 2)
  return pair.machine_logistics_candidate_0528
end

local function call(pair, expected)
  local receipt = logistics.service_pair(pair, "fixture")
  assert(receipt.detail == expected, "expected " .. expected .. ", received " .. receipt.detail)
end

script.on_event(defines.events.on_tick, function()
  local fixture = storage.fixture
  if fixture.phase == "done" then return end
  if not discover then assert(logistics.install()) end
  local pair, machine = fixture.pair, fixture.machine
  local station = pair.station.get_inventory(defines.inventory.chest)
  local fuel = machine.get_fuel_inventory()
  local burnt = machine.get_burnt_result_inventory()
  local input = machine.get_inventory(defines.inventory.crafter_input)
  local output = machine.get_inventory(defines.inventory.crafter_output)

  if fixture.phase == "blocked" then
    assert(station.insert{name = custom, count = 6} == 6)
    assert(station.insert{name = "coal", count = 10} == 10)
    assert(burnt.insert{name = spent, count = prototypes.item[spent].stack_size} > 0)
    assert(not candidate(pair), "planned fuel into a blocked burnt-result inventory")
    burnt.clear()
    local job = assert(candidate(pair), "no machine fuel candidate")
    assert(job.action == "supply-fuel" and job.item == custom and job.count == 3,
      "expected stocked compatible modded fuel instead of coal")
    call(pair, "station-custody-acquired")
    assert(station.get_item_count(custom) == 3 and station.get_item_count("coal") == 10)
    assert(pair.priest.teleport{machine.position.x - 1.5, machine.position.y})
    call(pair, "machine-supply-complete")
    assert(fuel.get_item_count(custom) == 3 and fuel.get_item_count("coal") == 0)

    assert(station.insert{name = "iron-plate", count = 2} == 2)
    job = assert(candidate(pair), "no crafting ingredient candidate using 2.1 inventory")
    assert(job.action == "supply-ingredient" and job.item == "iron-plate" and job.count == 2)
    assert(pair.priest.teleport{2, 0})
    call(pair, "station-custody-acquired")
    assert(pair.priest.teleport{machine.position.x - 1.5, machine.position.y})
    call(pair, "machine-supply-complete")
    assert(input.get_item_count("iron-plate") == 2 and station.get_item_count("iron-plate") == 0)
    machine.disabled_by_script = false
    fixture.phase = "crafting"
  elseif fixture.phase == "crafting" and output.get_item_count("iron-gear-wheel") == 1 then
    machine.disabled_by_script = true
    local job = assert(candidate(pair), "no crafting output candidate using 2.1 inventory")
    assert(job.action == "clear-output" and job.item == "iron-gear-wheel" and job.count == 1)
    call(pair, "machine-output-custody-acquired")
    assert(pair.priest.teleport{2, 0})
    logistics.service_pair(pair, "fixture")
    assert(output.get_item_count("iron-gear-wheel") == 0)
    assert(station.get_item_count("iron-gear-wheel") == 1)
    log("PASS TP_FACTORY_LOGISTICS_NATIVE_CUSTOM_FUEL_AND_CRAFTER")
    assert(fuel.insert{name = custom, count = 1} == 1)
    machine.force.technologies["quality-module"].researched = true
    machine.set_recipe("iron-gear-wheel", "uncommon")
    assert(station.insert{name = "iron-plate", quality = "uncommon", count = 4} == 4)
    assert(station.insert{name = "iron-plate", count = 6} == 6)
    local quality_job = assert(candidate(pair), "uncommon recipe work was not discovered")
    assert(quality_job.action == "supply-ingredient" and quality_job.quality == "uncommon",
      "expected uncommon ingredient, received " .. quality_job.action .. ":" .. quality_job.item)
    call(pair, "station-custody-acquired")
    assert(station.get_item_count(uncommon_plate) == 2 and station.get_item_count("iron-plate") == 6)
    machine.set_recipe("iron-gear-wheel")
    assert(pair.priest.teleport{machine.position.x - 1.5, machine.position.y})
    call(pair, "machine-insert-blocked")
    assert(pair.machine_logistics_custody_0528.quality == "uncommon")
    assert(pair.priest.teleport{2, 0})
    call(pair, "supply-leftover-returned")
    assert(station.get_item_count(uncommon_plate) == 4 and station.get_item_count("iron-plate") == 6)

    machine.set_recipe("iron-gear-wheel", "uncommon")
    assert(candidate(pair).quality == "uncommon")
    call(pair, "station-custody-acquired")
    assert(pair.priest.teleport{machine.position.x - 1.5, machine.position.y})
    call(pair, "machine-supply-complete")
    assert(input.get_item_count(uncommon_plate) == 2 and input.get_item_count("iron-plate") == 0)
    machine.disabled_by_script = false
    fixture.phase = "quality-output"
  elseif fixture.phase == "quality-output" and output.get_item_count(uncommon_gear) == 1 then
    machine.disabled_by_script = true
    local quality_job = assert(candidate(pair), "uncommon output was not discovered")
    assert(quality_job.action == "clear-output" and quality_job.quality == "uncommon")
    call(pair, "machine-output-custody-acquired")
    assert(pair.priest.teleport{2, 0})
    logistics.service_pair(pair, "fixture")
    assert(output.get_item_count(uncommon_gear) == 0)
    assert(station.get_item_count(uncommon_gear) == 1 and station.get_item_count("iron-gear-wheel") == 1)
    assert(station.get_item_count(uncommon_plate) == 2 and station.get_item_count("iron-plate") == 6)
    log("PASS TP_FACTORY_LOGISTICS_NATIVE_UNCOMMON_CUSTODY")
    fixture.phase = "done"
  end
end)
