local logistics = require("scripts.core.logistics_machine_fulfillment_0528")
local roles = require("scripts.core.storage_role_authority_0686")
local doctrine = require("scripts.core.fluid_network_doctrine_0689")
local planner = require("scripts.core.fluid_connection_planner_0691")
local reservations = require("scripts.core.work_reservations")
local discovery

TechPriestsRuntimeTickBroker0600 = {
  register_service = function(service)
    if service.name == "machine_logistics_discovery_0528" then discovery = service.fn end
    return true
  end,
}
TechPriestsStorageRoleAuthority0686 = roles
TechPriestsFluidNetworkDoctrine0689 = doctrine
TechPriestsWorkReservations0601 = reservations
TECH_PRIESTS_WORK_RESERVATIONS_0601 = reservations

local cases = {
  {machine = "workbench", recipe = "clay-pit", product = "clay-pit", count = 1},
  {machine = "cooking-fire", recipe = "steam-meal", product = "meal", count = 10, fluid_in = "steam"},
  {machine = "tank-ammo-assembling-machine", recipe = "tank-ammo-industrial-coke",
    product = "coal", count = 50, fluid_out = "crude-oil", fluid_count = 100},
  {machine = "tank-ammo-assembling-machine", recipe = "Rubberized-timber",
    product = "wood", count = 40, fluid_in = "crude-oil"},
}

local function check(value, why)
  return assert(value, "TP_SPECIALTY " .. why)
end

local function place(surface, force, name, pos)
  return check(surface.create_entity{name = name, position = pos, force = force},
    "could not place " .. name)
end

local function prepare_site(surface, x)
  surface.request_to_generate_chunks({x, 0}, 1)
  surface.force_generate_chunk_requests()
  for _, entity in pairs(surface.find_entities_filtered{area = {{x - 17, -17}, {x + 17, 17}},
      type = {"tree", "simple-entity", "cliff", "resource", "turret", "unit-spawner", "unit"}}) do
    entity.destroy()
  end
  local tiles = {}
  for px = math.floor(x) - 16, math.floor(x) + 16 do
    for y = -16, 16 do
      tiles[#tiles + 1] = {name = "grass-1", position = {px, y}}
    end
  end
  surface.set_tiles(tiles, true)
end

local function unlock_recipe(force, name)
  local recipe = check(force.recipes[name], "missing recipe " .. name)
  if recipe.enabled then return "initially-enabled" end
  for _, tech in pairs(force.technologies) do
    for _, effect in pairs(tech.prototype.effects) do
      if effect.type == "unlock-recipe" then
        local unlocked = effect.recipe
        if (type(unlocked) == "string" and unlocked or unlocked.name) == name then
          tech.researched = true
          check(recipe.enabled, "research did not unlock " .. name)
          return tech.name
        end
      end
    end
  end
  error("No native research unlock for " .. name)
end

local function port(machine, direction)
  for index = 1, machine.fluids_count do
    for _, connection in ipairs(machine.get_fluid_box_pipe_connections(index)) do
      if connection.flow_direction == direction then
        return index, connection
      end
    end
  end
  error("No native " .. direction .. " port for " .. machine.name)
end

local function prepare_fluid(case, definition)
  local direction = definition.fluid_in and "input" or "output"
  local box, connection = port(case.machine, direction)
  local target = connection.target_position
  local function sign(value) return value == 0 and 0 or (value > 0 and 1 or -1) end
  local dx, dy = sign(target.x - connection.position.x), sign(target.y - connection.position.y)
  check(math.abs(dx) + math.abs(dy) == 1, "pipe connection is not cardinal")
  local pipes = {}
  for gap = 3, 11 do
    pipes[#pipes + 1] = place(case.machine.surface, case.machine.force, "pipe",
      {x = target.x + dx * gap, y = target.y + dy * gap})
  end
  case.fluid = {direction = direction, box = box, pipes = pipes, target = target}
  if definition.fluid_in then
    local source = pipes[1]
    local capacity = source.get_fluid_segment_capacity(1)
    check(capacity >= 550, "native source network capacity is too small")
    source.set_fluid_segment_fluid(1, {
      name = definition.fluid_in, amount = 550,
      temperature = definition.fluid_in == "steam" and 165 or 25,
    })
  end
end

local function connect_fluid(case, definition)
  local fluid = case.fluid
  local name = definition.fluid_in or definition.fluid_out
  local pair, machine = case.pair, case.machine
  local report = check(doctrine.inspect_machine(pair, machine, true), "no canonical fluid report")
  local requirements = fluid.direction == "input" and report.missing_inputs or report.blocked_outputs
  check(requirements[1] and requirements[1].requirement.name == name,
    "canonical report did not identify " .. fluid.direction .. " " .. name)
  if definition.fluid_in == "steam" then
    local obstruction = place(machine.surface, machine.force, "wooden-chest", fluid.target)
    local blocked = planner.refresh_pair(pair)
    check(not pair.standard_fluid_route_plan_0691 and blocked.detail == "no-safe-proposal",
      "planner published construction into a physically blocked machine port")
    check(roles.generic_item_count(pair, "pipe") == 16, "blocked port spent held pipe stock")
    obstruction.destroy()
    log("PASS TP_SPECIALTY_OBSTRUCTED_STEAM_PORT")
  end
  local planned = planner.refresh_pair(pair)
  local proposals = fluid.direction == "input" and pair.fluid_connection_proposals_0689
    or pair.fluid_output_sink_proposals_0694
  if not pair.standard_fluid_route_plan_0691 and proposals and proposals[1] then
    local proposal = proposals[1]
    local valid, why = doctrine.validate_proposal(pair, proposal)
    local endpoint = proposal.source or proposal.sink
    log("TP_SPECIALTY_ROUTE_DIAGNOSTIC " .. helpers.table_to_json{
      valid = valid, reason = why, target = proposal.connection_targets,
      interfaces = endpoint.interfaces, station = pair.station.position,
      placeable = machine.surface.can_place_entity{
        name = "pipe", position = proposal.connection_targets[1], force = machine.force,
      },
    })
  end
  local plan = check(pair.standard_fluid_route_plan_0691,
    "canonical planner did not select a route (proposals=" .. #(proposals or {})
      .. ", result=" .. planned.detail .. ")")
  check(plan.direction == fluid.direction and plan.fluid == name, "unexpected planned fluid or direction")
  log("TP_SPECIALTY_NATIVE_ROUTE " .. helpers.table_to_json{
    target = fluid.target, tiles = plan.tiles, interfaces = plan.remote.interfaces,
  })
  local built = 0
  for _, tile in ipairs(plan.tiles) do
    -- The fixture places the proposed route so this test can isolate fluid
    -- discovery and machine fulfillment. Each new pipe consumes real stock.
    local position = {x = tile.x, y = tile.y}
    if not machine.surface.find_entity("pipe", position) then
      local parameters = {name = "pipe", position = position, force = machine.force,
        build_check_type = defines.build_check_type.manual}
      if not machine.surface.can_place_entity(parameters) then
        local neighbors = {}
        for _, entity in pairs(machine.surface.find_entities_filtered{
            area = {{position.x - 1, position.y - 1}, {position.x + 1, position.y + 1}},
        }) do
          neighbors[#neighbors + 1] = {name = entity.name, position = entity.position,
            box = entity.bounding_box}
        end
        error("TP_SPECIALTY native pipe collision " .. helpers.table_to_json{
          position = position, nearby = neighbors, tile = machine.surface.get_tile(position).name,
          machine_box = machine.bounding_box,
        })
      end
      check(roles.remove_generic_item(pair, "pipe", 1) == 1, "could not debit the route pipe")
      place(machine.surface, machine.force, "pipe", position)
      built = built + 1
    end
  end
  check(built >= 1, "no native pipe was built for the canonical route")
  planner.refresh_pair(pair)
  local _, attached = port(machine, fluid.direction)
  local pipe = attached.target
  check(pipe and pipe.valid and pipe.get_fluid_segment_id(1) == fluid.pipes[1].get_fluid_segment_id(1),
    "native pipe at the machine port did not join the planned network")
  return built
end

local function stock_case(index)
  local definition = cases[index]
  local surface = game.surfaces[1]
  local force = game.forces["specialty-test"] or game.create_force("specialty-test")
  local x = 100.5 + index * 100
  prepare_site(surface, x)
  local unlock = unlock_recipe(force, definition.recipe)
  local machine = place(surface, force, definition.machine, {x = x, y = 0.5})
  machine.disabled_by_script = true
  machine.set_recipe(definition.recipe)
  local recipe = check(machine.get_recipe(), "recipe setup missing")
  check(recipe.name == definition.recipe, "native machine rejected configured recipe")
  local station = place(surface, force, "steel-chest", {x = x - 10, y = 0.5})
  local priest = place(surface, force, "character", {x = x - 8.5, y = 0.5})
  local pair = {station = station, priest = priest, station_unit = station.unit_number, radius = 36}
  storage.tech_priests.pairs_by_station = {[station.unit_number] = pair}
  local stock = station.get_inventory(defines.inventory.chest)
  local items, fluids = {}, {}
  for _, ingredient in ipairs(recipe.ingredients) do
    if ingredient.type == "item" then
      local amount = check(ingredient.amount, "missing ingredient amount")
      check(stock.insert{name = ingredient.name, count = amount} == amount, "source stock could not be loaded")
      items[ingredient.name] = amount
    else
      fluids[ingredient.name] = ingredient.amount
    end
  end
  local burner = machine.get_fuel_inventory()
  if burner then
    check(stock.insert{name = "coal", count = 3} == 3, "could not stock burner fuel")
  else
    surface.always_day = true
    surface.daytime = 0
    place(surface, force, "substation", {x = x + 4.5, y = 0})
    for i = 0, 3 do
      place(surface, force, "solar-panel", {x = x + 9, y = -6.5 + 4 * i})
    end
  end
  local case = {index = index, machine = machine, pair = pair, items = items, fluids = fluids,
    recipe = recipe.name, categories = recipe.categories, unlock = unlock, phase = "feed",
    started = game.tick, moves = {}}
  storage.case = case
  if definition.fluid_in or definition.fluid_out then
    check(stock.insert{name = "pipe", count = 16} == 16, "could not stock route pipes")
    prepare_fluid(case, definition)
  end
  log("TP_SPECIALTY_CAPABILITY " .. helpers.table_to_json{
    machine = machine.name, recipe = case.recipe, categories = case.categories, unlock = unlock,
    items = items, fluid_inputs = fluids, fuel_slots = burner and #burner or 0,
    input_slots = #machine.get_inventory(defines.inventory.crafter_input),
    output_slots = #machine.get_output_inventory(), fluid_boxes = machine.fluids_count,
    qualities = {normal = prototypes.quality.normal ~= nil, uncommon = prototypes.quality.uncommon ~= nil},
  })
end

local function task(case, action)
  local pair = case.pair
  pair.machine_logistics_candidate_0528 = nil
  logistics.root().cooldowns[tostring(pair.station_unit)] = nil
  discovery(nil, 2)
  local job = pair.machine_logistics_candidate_0528
  if not job or (action and job.action ~= action) then return false end
  check(job.machine == case.machine, "planner selected a different machine")
  local stock = pair.station.get_inventory(defines.inventory.chest)
  local station_contact = {pair.station.position.x + 1.5, pair.station.position.y}
  local machine_contact = {case.machine.position.x - 1.5, case.machine.position.y}
  local output = job.action == "clear-output"
  local inv = output and case.machine.get_output_inventory()
    or (job.action == "supply-fuel" and case.machine.get_fuel_inventory()
    or case.machine.get_inventory(defines.inventory.crafter_input))
  local from, to = stock, inv
  if output then from, to = inv, stock end
  local from_before, to_before = from.get_item_count(job.item), to.get_item_count(job.item)
  check(pair.priest.teleport(output and machine_contact or station_contact), "fixture contact was blocked")
  local pickup = logistics.service_pair(pair, "specialty-fixture")
  check(pickup.acted == 1 and pair.machine_logistics_custody_0528,
    "native pickup stalled: " .. pickup.detail)
  local count = pair.machine_logistics_custody_0528.count
  check(pair.priest.teleport(output and station_contact or machine_contact), "fixture destination was blocked")
  local delivery = logistics.service_pair(pair, "specialty-fixture")
  check(delivery.acted == 1 and not pair.machine_logistics_custody_0528,
    "native delivery stalled: " .. delivery.detail)
  check(from.get_item_count(job.item) == from_before - count, "source inventory delta mismatch")
  check(to.get_item_count(job.item) == to_before + count, "destination inventory delta mismatch")
  case.moves[#case.moves + 1] = {kind = job.action, name = job.item, count = count}
  return true
end

script.on_init(function()
  storage.tech_priests = {pairs_by_station = {}}
  storage.results = {}
  stock_case(1)
end)

script.on_nth_tick(15, function()
  local case = storage.case
  if not case then return end
  if not discovery then check(logistics.install(), "cannot bind machine discovery") end
  local definition = cases[case.index]
  local machine = case.machine
  check(game.tick - case.started < 25000,
    "timed out on " .. machine.name .. "/" .. definition.recipe .. " in " .. case.phase)
  if case.phase == "feed" then
    if task(case) then return end
    local input = machine.get_inventory(defines.inventory.crafter_input)
    for name, amount in pairs(case.items) do
      check(input.get_item_count(name) == amount, "missing counted feed for " .. name)
    end
    machine.disabled_by_script = false
    case.phase = definition.fluid_in and "dry" or "craft"
    case.dry_since = game.tick
  elseif case.phase == "dry" and game.tick - case.dry_since >= 120 then
    check(machine.products_finished == 0 and machine.get_fluid_count(definition.fluid_in) == 0,
      "machine crafted while its fluid port was disconnected")
    case.pipes_built = connect_fluid(case, definition)
    case.phase = "craft"
  elseif case.phase == "craft" and machine.products_finished > 0 then
    machine.disabled_by_script = true
    check(machine.products_finished == 1, "expected one counted recipe batch")
    if definition.fluid_in then
      local fluid = case.fluid.pipes[1].get_fluid_segment_fluid(1)
      local used = case.fluids[definition.fluid_in]
      local remaining = (fluid and fluid.amount or 0) + machine.get_fluid_count(definition.fluid_in)
      check(math.abs(remaining - (550 - used)) < 0.01, "native fluid consumption mismatch")
      case.fluid_used = used
    end
    if definition.fluid_out then
      check(math.abs(machine.get_fluid_count(definition.fluid_out) - definition.fluid_count) < 0.01,
        "native fluid output amount mismatch")
      case.pipes_built = connect_fluid(case, definition)
      machine.disabled_by_script = false
      case.phase = "drain"
      return
    end
    case.phase = "collect"
  elseif case.phase == "drain" then
    local fluid = case.fluid.pipes[1].get_fluid_segment_fluid(1)
    if fluid and fluid.name == definition.fluid_out
        and math.abs(fluid.amount - definition.fluid_count) < 0.01 then
      check(machine.products_finished == 1, "machine started a second batch while draining")
      machine.disabled_by_script = true
      case.fluid_produced = fluid.amount
      case.phase = "collect"
    end
  elseif case.phase == "collect" then
    if task(case, "clear-output") then return end
    local stock = case.pair.station.get_inventory(defines.inventory.chest)
    local received = stock.get_item_count(definition.product)
    check(received == definition.count, "canonical collection output mismatch for " .. definition.recipe
      .. ": " .. received .. " received, " .. definition.count .. " expected")
    check(machine.get_output_inventory().is_empty(), "machine retained uncollected item byproducts")
    if case.index >= 3 then
      local waste = case.index == 3 and 20 or 10
      check(stock.get_item_count("tank-ammo-Industrialwaste") == waste, "native byproduct custody mismatch")
    end
    local receipt = {machine = machine.name, recipe = case.recipe, categories = case.categories,
      unlock = case.unlock, product = definition.product, count = definition.count,
      moves = case.moves, fluid_used = case.fluid_used, fluid_produced = case.fluid_produced,
      pipes_built = case.pipes_built}
    storage.results[#storage.results + 1] = receipt
    log("PASS TP_SPECIALTY_CASE " .. helpers.table_to_json(receipt))
    if case.index < #cases then
      stock_case(case.index + 1)
    else
      helpers.write_file("tp-specialty-production/results.json", helpers.table_to_json{
        tanks = script.active_mods.tanks_for_bob_fork, mods = script.active_mods, cases = storage.results,
      })
      log("PASS TP_SPECIALTY_ALL_FOUR_RECIPES")
      storage.case = nil
    end
  end
end)
