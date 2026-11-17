-- Exercise the energy dispatcher's canister custody against native chests and a native reactor.
-- The fixture supplies the two movement arrivals and keeps unrelated discovery services isolated.
local logistics = require("__tech-priests__.scripts.core.energy_family_logistics_0707")
local authority = require("__tech-priests__.scripts.core.storage_role_authority_0686")
local fuel = "tp-mh7-contained-metallicized-pellet"

local function check_pellet(stack, quality)
  assert(stack.valid_for_read and stack.name == fuel and stack.quality.name == quality)
  assert(stack.health == 0.5 and stack.tags.mh7_remaining_ticks == 149)
  assert(stack.tags.mh7_shell_health == 0.25 and stack.custom_description == "transport test")
end

script.on_init(function()
  local surface, force = game.surfaces[1], game.forces.player
  surface.request_to_generate_chunks({0, 20}, 2)
  surface.force_generate_chunk_requests()
  local function place(name, x)
    return assert(surface.create_entity{name = name, position = {x, 20}, force = force})
  end
  local station = place("steel-chest", 0)
  local depot = place("steel-chest", 4)
  local reactor = place("mars-plasma-reactor-minoris", 10)
  local priest = {valid = true, unit_number = 349929, position = depot.position, surface = surface, force = force}
  local pair = {station = station, priest = priest, radius = 15}
  storage.tech_priests = {pairs_by_station = {[station.unit_number] = pair}}
  local source = depot.get_inventory(defines.inventory.chest)
  local dest = reactor.get_fuel_inventory()
  local report = {
    entity = reactor, entity_name = reactor.name, entity_unit = reactor.unit_number,
    state = "fuel-service-eligible", fuel_inventory = dest, fuel_count = 0
  }
  local discover
  _G.TechPriestsStorageRoleAuthority0686 = authority
  _G.TechPriestsEnergyFamilyReadiness0705 = {
    inspect_entity = function() return report end,
    scan_pair = function(p) p.energy_family_reports_0705 = {report} end
  }
  _G.TechPriestsWorkReservations0601 = {
    categories = {"energy-family-logistics"}, root = function() return {reservations = {}} end,
    claim = function() return true end, release = function() return true end
  }
  _G.tech_priests_inventory_steward_sources_for_pair = function() return {{entity = depot, inv = source}} end
  _G.tech_priests_request_movement_0418 = function() return true end
  _G.TechPriestsRuntimeTickBroker0600 = {
    register_service = function(service) discover = service.fn return service end
  }
  assert(logistics.install())

  local quality = prototypes.quality.rare and "rare" or "normal"
  local pellet = {
    name = fuel, count = 1, quality = quality, health = 0.5,
    tags = {mh7_remaining_ticks = 149, mh7_shell_health = 0.25}, custom_description = "transport test"
  }
  assert(source.is_empty() and dest.is_empty())
  assert(discover(nil, 1).acted == 1 and pair.energy_family_candidate_0707.item == fuel)
  assert(logistics.service_pair(pair, "begin").detail == "waiting-source")
  assert(pair.active_supply_request.item == fuel and pair.active_supply_request.target_unit == reactor.unit_number)
  assert(pair.logistic_requested_item.item == fuel and pair.logistic_requested_item.count > 0)
  assert(source.insert{name = "coal", count = 10} == 10)
  assert(logistics.service_pair(pair, "only-coal-available").detail == "waiting-source")
  assert(pair.active_supply_request.item == fuel and dest.is_empty())
  assert(source.insert(pellet) == 1)
  assert(logistics.service_pair(pair, "canister-arrives").detail == "source-ready")
  assert(logistics.service_pair(pair, "pickup").acted == 1 and source.get_item_count("coal") == 10)
  assert(not pair.active_supply_request and not pair.logistic_requested_item)
  log("Cold plasma reactor requested a sealed canister, waited through a coal delivery, and collected the canister")
  priest.position = reactor.position
  assert(logistics.service_pair(pair, "deliver").acted == 1)
  check_pellet(dest[1], quality)
  dest.clear()
  assert(source.remove{name = "coal", count = 10} == 10 and source.is_empty())

  assert(source.insert(pellet) == 1)
  pair.energy_family_candidate_0707 = {
    family = "energy-fuel", item = fuel, count = 1, target = reactor,
    source = {inv = source, entity = depot}, report = report
  }
  priest.position = depot.position
  assert(logistics.service_pair(pair, "begin-return").waiting == 1)
  assert(logistics.service_pair(pair, "pickup-return").acted == 1 and source.is_empty())
  pair.energy_family_logistics_0707 = nil
  depot.destroy()
  priest.position = station.position
  assert(logistics.service_pair(pair, "recover-orphan").acted == 1)
  check_pellet(station.get_inventory(defines.inventory.chest)[1], quality)
  log("HYDROGEN_TAGGED_CUSTODY " .. quality .. " discovery, delivery and orphan recovery passed")
end)

script.on_nth_tick(1, function() script.finish_test(true) end)
