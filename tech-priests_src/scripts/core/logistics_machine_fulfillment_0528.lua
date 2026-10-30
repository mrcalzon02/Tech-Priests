-- scripts/core/logistics_machine_fulfillment_0528.lua
-- Tech Priests 0.1.674-dev recovery.
-- One machine-logistics authority: broker-budgeted read-only candidate discovery,
-- dispatcher-owned execution, literal movement acceptance, container-only station
-- stock, dedicated target-machine inventories, persistent custody, and atomic return.

local M = {
  version = "0.1.674-dev",
  storage_key = "logistics_machine_fulfillment_0528",
  discovery_interval = 61,
  discovery_budget = 2,
  candidate_ttl = 360,
  service_radius = 28,
  radius_cap = 96,
  max_scan_entities = 96,
  machine_reach_sq = 2.56,
  station_reach_sq = 4,
  move_priority = 740,
  move_ttl = 480,
  max_transfer = 50,
  min_fuel_count = 3,
  no_task_cooldown = 180,
  reservation_ttl = 300,
}

local MACHINE_TYPES = {
  ["assembling-machine"] = true,
  furnace = true,
  ["mining-drill"] = true, -- fuel only: mined output has no generic inventory
  container = true,
  ["logistic-container"] = true, -- only drill-connected receivers are eligible
}
local WASTE_ITEMS = {
  ["mechanical-detritus"] = true,
  scrap = true,
}
local FUEL_CANDIDATES = {
  "coal", "wood", "solid-fuel", "rocket-fuel", "nuclear-fuel",
}
local TERMINAL_PHASES = {
  complete = true,
  failed = true,
  idle = true,
  none = true,
}

local function now() return game and game.tick or 0 end
local function valid(entity) return entity and entity.valid end
local function safe(value)
  if value == nil then return "nil" end
  local ok, text = pcall(tostring, value)
  return ok and text or "?"
end
local function lower(value) return string.lower(tostring(value or "")) end
local function valid_pair(pair)
  return type(pair) == "table" and valid(pair.station) and valid(pair.priest)
end
local function station_unit(pair)
  return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil
end
local function pair_map()
  return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
end
local function dist_sq(a, b)
  if not (a and b) then return 999999999 end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end
local function result(fields)
  fields = fields or {}
  return {
    processed = tonumber(fields.processed) or 1,
    acted = tonumber(fields.acted) or 0,
    blocked = tonumber(fields.blocked) or 0,
    waiting = tonumber(fields.waiting) or 0,
    failed = tonumber(fields.failed) or 0,
    exhausted = fields.exhausted == true,
    detail = safe(fields.detail or ""),
  }
end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local state = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    dispatcher_owned = true,
    connection_aware_automation = true,
    stats = {},
    recent = {},
    cooldowns = {},
    discovery_cursor = 0,
  }
  storage.tech_priests[M.storage_key] = state
  state.version = M.version
  if state.enabled == nil then state.enabled = true end
  if state.dispatcher_owned == nil then state.dispatcher_owned = true end
  if state.connection_aware_automation == nil then
    state.connection_aware_automation = true
  end
  state.stats = state.stats or {}
  state.recent = state.recent or {}
  state.cooldowns = state.cooldowns or {}
  state.discovery_cursor = tonumber(state.discovery_cursor) or 0
  return state
end
local function stat(name, amount)
  local state = M.root()
  state.stats[name] = (tonumber(state.stats[name]) or 0) + (tonumber(amount) or 1)
end
local function record(pair, action, detail)
  local state = M.root()
  stat(action)
  state.recent[#state.recent + 1] = {
    tick = now(),
    station = station_unit(pair),
    action = safe(action),
    detail = safe(detail),
  }
  while #state.recent > 160 do table.remove(state.recent, 1) end
end

local function inventory(entity, inventory_id)
  if not (valid(entity) and inventory_id and entity.get_inventory) then return nil end
  local ok, inv = pcall(function() return entity.get_inventory(inventory_id) end)
  return ok and inv and inv.valid and inv or nil
end
local function count_inventory(inv, item)
  if not (inv and inv.valid and item) then return 0 end
  local ok, count = pcall(function() return inv.get_item_count(item) end)
  return ok and (tonumber(count) or 0) or 0
end
local function each_inventory_item(inv, callback)
  if not (inv and inv.valid and type(callback) == "function") then return end
  local ok, contents = pcall(function() return inv.get_contents() end)
  if not (ok and type(contents) == "table") then return end
  for key, value in pairs(contents) do
    local name, count
    if type(key) == "string" then
      name = key
      count = type(value) == "table"
        and tonumber(value.count or value.amount or value[2]) or tonumber(value)
    elseif type(value) == "table" then
      name = value.name or value.item or value[1]
      count = tonumber(value.count or value.amount or value[2])
    end
    if type(name) == "string" and name ~= "" and (tonumber(count) or 0) > 0 then
      callback(name, tonumber(count) or 1)
    end
  end
end
local function remove_inventory(inv, item, count)
  if not (inv and inv.valid and item and (tonumber(count) or 0) > 0) then return 0 end
  local ok, removed = pcall(function()
    return inv.remove({ name = item, count = count })
  end)
  return ok and (tonumber(removed) or 0) or 0
end
local function insert_inventory(inv, item, count)
  if not (inv and inv.valid and item and (tonumber(count) or 0) > 0) then return 0 end
  local ok, inserted = pcall(function()
    return inv.insert({ name = item, count = count })
  end)
  return ok and (tonumber(inserted) or 0) or 0
end
local function machine_input(machine)
  local ids = defines and defines.inventory
  return ids and (inventory(machine, ids.assembling_machine_input)
    or inventory(machine, ids.furnace_source)) or nil
end
local function machine_output(machine)
  local ids = defines and defines.inventory
  if ids and (machine.type=="container" or machine.type=="logistic-container") then
    return inventory(machine,ids.chest)
  end
  return ids and (inventory(machine, ids.assembling_machine_output)
    or inventory(machine, ids.furnace_result)) or nil
end
local function machine_fuel(machine)
  local ids = defines and defines.inventory
  return ids and inventory(machine, ids.fuel) or nil
end
local function storage_authority()
  return rawget(_G, "TechPriestsStorageRoleAuthority0686")
    or package.loaded["scripts.core.storage_role_authority_0686"]
end
local function generic_count(pair, item)
  local storage = storage_authority()
  if storage and type(storage.generic_item_count) == "function" then
    local ok, count = pcall(storage.generic_item_count, pair, item)
    if ok then return tonumber(count) or 0 end
  end
  local helper = rawget(_G, "tech_priests_generic_station_item_count_0686")
  if type(helper) == "function" then
    local ok, count = pcall(helper, pair, item)
    if ok then return tonumber(count) or 0 end
  end
  return 0
end
local function remove_generic(pair, item, count)
  local storage = storage_authority()
  if storage and type(storage.remove_generic_item) == "function" then
    local ok, removed = pcall(storage.remove_generic_item, pair, item, count)
    if ok then return tonumber(removed) or 0 end
  end
  local helper = rawget(_G, "tech_priests_generic_station_remove_0686")
  if type(helper) == "function" then
    local ok, removed = pcall(helper, pair, item, count)
    if ok then return tonumber(removed) or 0 end
  end
  return 0
end
-- Real 0528 drill deliveries feeding a verified 0820 ranked return must land
-- in the terminal's ACTUAL Cogitator inventory. Generic retention storage can
-- otherwise choose a nearby buffer, leaving no locally pickable 0837 stock.
-- A matching ranked mission is a custody obligation, not a hint to
-- fall back to nearby retention storage when the live route is unavailable.
-- Return nil for an assigned-but-unverifiable route, false only for ordinary
-- machine output, and true only for the complete physical route.
local function ranked_return_station_deposit_0995(pair, item)
  local assignment=pair and pair.remote_resource_assignment_0820
  if not (valid_pair(pair) and type(assignment)=="table"
      and type(assignment.root_station_unit)=="number") then
    return false,"not-assigned-ranked-return"
  end
  local root=pair_map()[assignment.root_station_unit]
  local mission=root and root.resource_expansion_0259
    and root.resource_expansion_0259.chain_0820
  if not (type(mission)=="table" and mission.need==item
      and mission.root_station_unit==assignment.root_station_unit
      and mission.current_station_unit==station_unit(pair)) then
    return false,"not-current-ranked-output"
  end
  if not (valid_pair(root) and mission.status=="reached-resource"
      and type(assignment.parent_station_unit)=="number"
      and type(assignment.segment)=="number"
      and assignment.segment>=1
      and assignment.segment==math.floor(assignment.segment)) then
    return nil,"ranked-mission-or-assignment-invalid"
  end
  local loaded,chain=pcall(require,"scripts.core.resource_station_chain_0820")
  if not (loaded and chain and type(chain.return_route)=="function") then
    return nil,"ranked-route-authority-unavailable"
  end
  local ok,route,why=pcall(chain.return_route,root)
  if not (ok and type(route)=="table" and #route>=2
      and route[1]==station_unit(pair)
      and route[2]==assignment.parent_station_unit
      and route[#route]==assignment.root_station_unit) then
    return nil,"ranked-route-unverified:"..safe(ok and why or route)
  end
  return true,"ranked-physical-route-verified"
end

local function atomic_deposit(pair, item, count, reason, role, options)
  local storage = storage_authority()
  if not (storage and type(storage.deposit_exact) == "function") then
    return false, "storage-authority-unavailable"
  end
  local deposit_options={role=role}
  if options and options.station_only==true then
    deposit_options.station_only=true
    deposit_options.allow_create=false
  end
  local ok, accepted, why, inserted = pcall(
    storage.deposit_exact, pair, item, count, reason, deposit_options)
  inserted = tonumber(inserted) or (accepted == true and count or 0)
  return ok and accepted == true and inserted == count, why
end

local function request_move_position(pair, destination, reason, radius)
  local move = rawget(_G, "tech_priests_request_movement_0418")
  if not (valid_pair(pair) and destination and type(move) == "function") then
    return false, "movement-authority-unavailable"
  end
  local ok, accepted, detail = pcall(move, pair, destination, reason, {
    owner = "logistics_machine_fulfillment_0528",
    priority = M.move_priority,
    ttl = M.move_ttl,
    radius = radius or 1.25,
    distraction = defines and defines.distraction and defines.distraction.none,
  })
  return ok and accepted == true,
    ok and safe(detail or accepted) or "movement-error:" .. safe(accepted)
end
local function request_move(pair, target, reason)
  return request_move_position(pair, valid(target) and target.position, reason)
end

-- The station has a solid collision box. Machine logistics must use a real
-- standing point INSIDE the two-tile custody-transfer envelope; commanding
-- the priest to the station's blocked center creates perpetual return routes.
local function station_contact(pair, state)
  if not valid_pair(pair) then return nil end
  local priest, station = pair.priest, pair.station
  local surface = priest.surface
  if not (surface and surface.can_place_entity) then return nil end
  local function is_clear(pos)
    if dist_sq(pos, station.position) > M.station_reach_sq then return false end
    local ok, allowed = pcall(function()
      return surface.can_place_entity({
        name = priest.name, position = pos, force = priest.force })
    end)
    return ok and allowed == true
  end
  local remembered = state and state.station_contact_0528
  if remembered and is_clear(remembered) then return remembered end
  local offsets = {
    {1,0},{0,1},{-1,0},{0,-1},
    {0.70710678,0.70710678},{-0.70710678,0.70710678},
    {-0.70710678,-0.70710678},{0.70710678,-0.70710678},
  }
  local best, best_distance = nil, nil
  for _, radius in ipairs({1.35, 1.45, 1.55, 1.7, 1.85}) do
    for _, direction in ipairs(offsets) do
      local pos = {
        x = station.position.x + radius * direction[1],
        y = station.position.y + radius * direction[2],
      }
      if is_clear(pos) then
        -- Reach the cargo-transfer radius with margin. A merely nearest
        -- outer-ring contact can make the movement controller loiter at 2.1+
        -- tiles from the station, permanently withholding physical cargo.
        local distance = dist_sq(pos, station.position) * 10000
          + dist_sq(pos, priest.position)
        if not best_distance or distance < best_distance then
          best, best_distance = pos, distance
        end
      end
    end
  end
  if state then state.station_contact_0528 = best end
  return best
end
local function reservations()
  return rawget(_G, "TechPriestsWorkReservations0601")
    or package.loaded["scripts.core.work_reservations"]
end
local function claim_machine(pair, machine)
  local authority = reservations()
  if not (authority and type(authority.claim) == "function") then
    return false, "reservation-authority-unavailable"
  end
  local ok, accepted = pcall(
    authority.claim, "machine-logistics", machine, pair, M.reservation_ttl)
  return ok and accepted == true, ok and "claimed" or safe(accepted)
end
local function release_machine(pair, machine)
  local authority = reservations()
  if valid(machine) and authority and type(authority.release) == "function" then
    pcall(authority.release, "machine-logistics", machine, pair)
  end
end

local function item_exists(name)
  return type(name) == "string" and name ~= ""
    and prototypes and prototypes.item and prototypes.item[name] ~= nil
end
local function get_recipe(machine)
  if not (valid(machine) and machine.get_recipe) then return nil end
  local ok, recipe = pcall(function() return machine.get_recipe() end)
  return ok and recipe or nil
end
local function recipe_ingredients(recipe)
  local out = {}
  if not recipe then return out end
  local ingredients
  local ok = pcall(function() ingredients = recipe.ingredients end)
  if not (ok and type(ingredients) == "table") then return out end
  for _, ingredient in pairs(ingredients) do
    local name = ingredient.name or ingredient[1]
    local kind = ingredient.type or (ingredient.name and "item")
    local amount = tonumber(
      ingredient.amount or ingredient.amount_min or ingredient[2]) or 1
    if kind ~= "fluid" and item_exists(name) then
      out[#out + 1] = { name = name, amount = math.max(1, math.ceil(amount)) }
    end
  end
  return out
end
local function is_machine(entity)
  return valid(entity) and MACHINE_TYPES[entity.type] == true
end
local function machine_box(machine)
  if not valid(machine) then return nil end
  local ok, box = pcall(function() return machine.bounding_box end)
  if ok and box then return box end
  ok, box = pcall(function() return machine.selection_box end)
  return ok and box or nil
end
local function position_in_box(position, box, padding)
  if not (position and box and box.left_top and box.right_bottom) then return false end
  padding = tonumber(padding) or 0.25
  return position.x >= box.left_top.x - padding
    and position.x <= box.right_bottom.x + padding
    and position.y >= box.left_top.y - padding
    and position.y <= box.right_bottom.y + padding
end
local function inserter_connected(inserter, machine)
  if not (valid(inserter) and valid(machine) and inserter.type == "inserter") then
    return false
  end
  local pickup, drop
  pcall(function() pickup = inserter.pickup_target end)
  pcall(function() drop = inserter.drop_target end)
  if pickup == machine or drop == machine then return true end
  local pickup_position, drop_position
  pcall(function() pickup_position = inserter.pickup_position end)
  pcall(function() drop_position = inserter.drop_position end)
  local box = machine_box(machine)
  return position_in_box(pickup_position, box)
    or position_in_box(drop_position, box)
end
local function loader_connected(loader, machine)
  if not (valid(loader) and valid(machine)
    and (loader.type == "loader" or loader.type == "loader-1x1"))
  then
    return false
  end
  local container
  pcall(function() container = loader.loader_container end)
  if container == machine then return true end
  return dist_sq(loader.position, machine.position) <= 2.75
end
local function machine_automated(machine)
  if not valid(machine) then return false end
  local box = machine_box(machine)
  local position = machine.position
  local area = box and {
    { box.left_top.x - 3, box.left_top.y - 3 },
    { box.right_bottom.x + 3, box.right_bottom.y + 3 },
  } or {
    { position.x - 3, position.y - 3 },
    { position.x + 3, position.y + 3 },
  }
  local ok, entities = pcall(function()
    return machine.surface.find_entities_filtered({
      area = area,
      force = machine.force,
      type = { "inserter", "loader", "loader-1x1" },
      limit = 64,
    })
  end)
  if not (ok and entities) then return false end
  for _, entity in pairs(entities) do
    if inserter_connected(entity, machine) or loader_connected(entity, machine) then
      return true
    end
  end
  return false
end

local function output_candidate(machine)
  local output = machine_output(machine)
  local best
  if output then
    each_inventory_item(output, function(item, count)
      local candidate = {
        action = "clear-output",
        item = item,
        count = math.min(M.max_transfer, count),
        machine = machine,
        source_inventory = output,
        kind = WASTE_ITEMS[item] and "waste" or "retention",
      }
      if not best or candidate.kind == "waste"
        or candidate.count > best.count
      then
        best = candidate
      end
    end)
  end
  local input = machine_input(machine)
  local detritus = input and count_inventory(input, "mechanical-detritus") or 0
  if detritus > 0 then
    best = {
      action = "clear-output",
      item = "mechanical-detritus",
      count = math.min(M.max_transfer, detritus),
      machine = machine,
      source_inventory = input,
      kind = "waste",
    }
  end
  return best
end
local function fuel_candidate(pair, machine)
  local fuel = machine_fuel(machine)
  if not fuel then return nil end
  local total = 0
  each_inventory_item(fuel, function(_, count) total = total + count end)
  if total >= M.min_fuel_count then return nil end
  for _, item in ipairs(FUEL_CANDIDATES) do
    local available = generic_count(pair, item)
    if item_exists(item) and available > 0 then
      return {
        action = "supply-fuel",
        item = item,
        count = math.min(M.max_transfer, M.min_fuel_count - total, available),
        machine = machine,
      }
    end
  end
  return nil
end
local function ingredient_candidate(pair, machine)
  local input = machine_input(machine)
  local recipe = get_recipe(machine)
  if not (input and recipe) then return nil end
  for _, ingredient in ipairs(recipe_ingredients(recipe)) do
    local missing = ingredient.amount - count_inventory(input, ingredient.name)
    local available = generic_count(pair, ingredient.name)
    if missing > 0 and available > 0 then
      return {
        action = "supply-ingredient",
        item = ingredient.name,
        count = math.min(M.max_transfer, missing, available),
        machine = machine,
      }
    end
  end
  return nil
end
local function task_score(pair, task)
  local base = task.action == "clear-output" and 600
    or task.action == "supply-fuel" and 500 or 420
  if task.kind == "waste" then base = base + 120 end
  -- Completed Electronics parts are an actual researched-production
  -- dependency. If a priest keeps collecting easier raw ore or topping off
  -- neighboring drills, copper cable remains trapped in the assembler and
  -- circuits can never start. Prioritize that *existing* physical output;
  -- movement leases and real custody are still arbitrated elsewhere.
  if task.action=="clear-output"
      and task.machine.name=="tech-priests-emergency-assembler"
      and (task.item=="copper-cable" or task.item=="electronic-circuit") then
    base=math.max(base,950)
  end
  if task.action == "supply-fuel" and task.machine.type == "furnace" then
    local source = machine_input(task.machine)
    local pending = count_inventory(source, "iron-ore")
      + count_inventory(source, "copper-ore")
      + count_inventory(source, "stone")
    if pending > 0 then
      -- An ore-filled, unpowered smelter blocks plates, gears, and all
      -- electronics. It must beat routine drill refueling and incidental
      -- machine-output cleanup while actual fuel stock is available.
      base = math.max(base, 850)
    end
  end
  return base - math.sqrt(dist_sq(pair.priest.position, task.machine.position))
    - math.sqrt(dist_sq(pair.station.position, task.machine.position)) * 0.15
end
local function connected_drill_receiver(receiver,machines)
  if not valid(receiver) then return false end
  if receiver.type~="container" and receiver.type~="logistic-container" then
    return false
  end
  for _,drill in pairs(machines or {}) do
    if valid(drill) and drill.type=="mining-drill"
      and drill.surface==receiver.surface and drill.force==receiver.force then
      local drop,target
      pcall(function()drop=drill.drop_position;target=drill.drop_target end)
      if target==receiver then return drill end
      if drop and not valid(target) and dist_sq(drop,receiver.position)<=0.51 then
        return drill
      end
    end
  end
  return false
end
-- 0983: a receiver is a physical drill-output source only while the
-- real drill remains connected on the same force and surface. This is
-- provenance of the RECEIVER, not yet proof that the drill mined ore.
function M.connected_drill_source_0983(pair, receiver, drill)
  -- Revalidate the drill found in the existing bounded 0528 discovery
  -- scan; a second scan every pickup would regress the UPS baseline.
  if not (valid_pair(pair) and valid(receiver) and valid(drill)
      and drill.type=="mining-drill" and drill.unit_number
      and (receiver.type=="container" or receiver.type=="logistic-container")
      and receiver.surface==pair.station.surface
      and receiver.force==pair.station.force
      and drill.surface==receiver.surface and drill.force==receiver.force
      and receiver.position) then
    return nil,"drill-receiver-domain-invalid"
  end
  local read,drop,target=pcall(function()
    return drill.drop_position,drill.drop_target
  end)
  if read and (target==receiver
      or (drop and not valid(target)
        and dist_sq(drop,receiver.position)<=0.51)) then
    return drill,"physically-connected-drill-receiver"
  end
  return nil,"drill-receiver-disconnected"
end
local function discover_candidate(pair)
  if not valid_pair(pair) or valid(pair.combat_target) then return nil end
  local radius = math.max(M.service_radius,
    math.min(M.radius_cap, tonumber(pair.radius) or M.service_radius))
  local position = pair.station.position
  local ok, machines = pcall(function()
    return pair.station.surface.find_entities_filtered({
      area = {
        { position.x - radius, position.y - radius },
        { position.x + radius, position.y + radius },
      },
      force = pair.station.force,
      type = { "assembling-machine", "furnace", "mining-drill",
        "container", "logistic-container" },
      limit = M.max_scan_entities,
    })
  end)
  if not (ok and machines) then return nil end
  local best, best_score
  for _, machine in pairs(machines) do
    local is_receiver=machine.type=="container"
      or machine.type=="logistic-container"
    local drill_source=is_receiver and connected_drill_receiver(machine,machines)
      or nil
    local eligible=is_machine(machine) and machine ~= pair.station
      and (not is_receiver or drill_source)
    local automated=eligible and machine_automated(machine) or false
    -- Count only *observed* completed Electronics stacks during the normal
    -- bounded discovery scan. These counters diagnose whether collection is
    -- never discovered, excluded as automated, or superseded by another job.
    -- No inventory, candidate or movement authority is modified by telemetry.
    if eligible and machine.name=="tech-priests-emergency-assembler"
        and (count_inventory(machine_output(machine),"copper-cable")>0
          or count_inventory(machine_output(machine),"electronic-circuit")>0) then
      stat("electronics-output-observed-0528")
      if automated then stat("electronics-output-automated-excluded-0528") end
    end
    if eligible and not automated then
      local task = output_candidate(machine)
        or fuel_candidate(pair, machine)
        or ingredient_candidate(pair, machine)
      if task then
        if drill_source then task.drill_source_0983=drill_source end
        local score = task_score(pair, task)
        if not best_score or score > best_score then
          best, best_score = task, score
        end
      end
    end
  end
  if best then
    if best.action=="clear-output"
        and best.machine.name=="tech-priests-emergency-assembler"
        and (best.item=="copper-cable"
          or best.item=="electronic-circuit") then
      stat("electronics-output-selected-0528")
    end
    best.score = best_score
    best.discovered_tick = now()
    best.expires_tick = now() + M.candidate_ttl
    best.source = "machine-logistics-discovery-0528"
  end
  return best
end
local function active_state(pair)
  local state = pair and pair.machine_logistics_0528
  return type(state) == "table" and state.phase
    and not TERMINAL_PHASES[lower(state.phase)] and state or nil
end
local function physical_direct_active(pair)
  if not pair then return false end
  if pair.direct_acquisition_custody_0513 then return true end
  local direct=rawget(_G,"TechPriestsDirectAcquisitionExecutor0513")
    or package.loaded["scripts.core.direct_acquisition_executor_0513"]
  if direct and type(direct.current_direct_task)=="function" then
    local ok,task,current=pcall(direct.current_direct_task,pair)
    if ok then return task~=nil and current~=nil end
  end
  -- Equivalent compatibility check when the physical executor has not yet
  -- installed: direct mining may be held in emergency_craft.current.
  local kinds={["direct-mine-0336"]=true,["direct-mine-0273"]=true,
    ["direct-dirt-0273"]=true,["dirt"]=true}
  for _,key in ipairs({"emergency_craft","direct_acquisition_task_0336",
    "active_acquisition_0333"}) do
    local task=pair[key]
    local current=type(task)=="table" and (task.current or task) or nil
    if current and kinds[tostring(current.kind or "")] then return true end
  end
  return false
end
local function read_root()
  return storage and storage.tech_priests
    and storage.tech_priests[M.storage_key]
    or { enabled = true, cooldowns = {}, discovery_cursor = 0 }
end
local function bootstrap_mining_output(task)
  if not (task and task.action == "clear-output" and valid(task.machine)) then return false end
  if task.machine.name == "tech-priests-emergency-miner" then return true end
  -- The real Electronics chain can leave completed cable in the nearby
  -- emergency assembler while the priest is mining unrelated raw material.
  -- A *physically present* output stack can interrupt an unladen acquisition,
  -- following the same movement-and-custody route as existing miner output.
  -- Never grant virtual cable, teleport between Cogitators, or preempt cargo.
  if task.machine.name == "tech-priests-emergency-assembler"
      and task.machine.type == "assembling-machine"
      and (task.item=="copper-cable" or task.item=="electronic-circuit") then
    local output=task.source_inventory or machine_output(task.machine)
    return count_inventory(output,task.item)>0
  end
  -- Discovery admits containers here only when physically connected to a
  -- real mining drill. Do not preempt hand-mining to empty ordinary furnaces.
  local typ=task.machine.type
  return (typ == "container" or typ == "logistic-container")
    and (task.item == "iron-ore" or task.item == "copper-ore"
      or task.item == "stone" or task.item == "coal")
end
local function completed_machine_output_ready(pair, state)
  if bootstrap_mining_output(state) then return true end
  local candidate = pair and pair.machine_logistics_candidate_0528
  return bootstrap_mining_output(candidate)
    and (tonumber(candidate.expires_tick) or 0) >= now()
end
function M.completed_bootstrap_mining_output(pair)
  return pair and completed_machine_output_ready(pair,active_state(pair)) or false
end
function M.recommend_action(pair)
  if not valid_pair(pair) or read_root().enabled == false then return nil end
  local state = active_state(pair)
  -- A due physical strict craft owns the priest's return path, but a
  -- generic infrastructure gate must not starve a built miner of real fuel.
  local craft=pair.emergency_craft
  local direct_active=physical_direct_active(pair)
  local strict=type(craft)=="table" and craft.strict_recipe_0647==true
  local output_ready=completed_machine_output_ready(pair,state)
  -- Physical direct custody and strict manufacturing still own the priest.
  -- An unladen direct acquisition route may yield to real finished machine
  -- output; otherwise every new direct task indefinitely hides that output.
  if (strict or (direct_active
      and (pair.direct_acquisition_custody_0513 or not output_ready)))
    and not (state and state.custody) and not pair.machine_logistics_custody_0528
  then return nil end
  if state and valid(state.machine) then
    local target = state.machine
    if state.phase == "move-to-station"
      or state.phase == "return-custody-to-station"
    then
      target = pair.station
    end
    return {
      kind = "machine-logistics",
      target = target,
      item = state.item or (state.custody and state.custody.item),
      reason = state.phase,
      priority = 780,
      source = "logistics_machine_fulfillment_0528",
    }
  end
  local candidate = pair.machine_logistics_candidate_0528
  if type(candidate) ~= "table" or not valid(candidate.machine)
    or (tonumber(candidate.expires_tick) or 0) < now()
  then
    return nil
  end
  return {
    kind = "machine-logistics",
    target = candidate.machine,
    item = candidate.item,
    reason = candidate.action,
    priority = 760,
    source = "machine-logistics-discovery-0528",
  }
end

local function discover_pairs(budget)
  -- Never shadow Lua's pairs() iterator with the candidate collection.
  local stations = {}
  for _, pair in pairs(pair_map()) do
    if valid_pair(pair) then stations[#stations + 1] = pair end
  end
  table.sort(stations, function(a, b)
    return (station_unit(a) or 0) < (station_unit(b) or 0)
  end)
  if #stations == 0 then return result({ processed = 0, detail = "no-pairs" }) end
  local root = M.root()
  local limit = math.max(1, math.floor(tonumber(budget) or M.discovery_budget))
  local processed, acted = 0, 0
  for offset = 1, math.min(limit, #stations) do
    local index = ((root.discovery_cursor + offset - 1) % #stations) + 1
    local pair = stations[index]
    processed = processed + 1
    if not active_state(pair) then
      local key = tostring(station_unit(pair) or "?")
      if (tonumber(root.cooldowns[key]) or 0) <= now() then
        local candidate = discover_candidate(pair)
        pair.machine_logistics_candidate_0528 = candidate
        if candidate then acted = acted + 1
        else root.cooldowns[key] = now() + M.no_task_cooldown end
      end
    end
  end
  root.discovery_cursor = (root.discovery_cursor + math.min(limit, #stations)) % #stations
  return result({
    processed = processed,
    acted = acted,
    exhausted = #stations > limit,
    detail = "machine-candidates=" .. acted,
  })
end

local function begin_state(pair, candidate)
  local claimed, why = claim_machine(pair, candidate.machine)
  if not claimed then return false, "machine-reserved:" .. safe(why) end
  pair.machine_logistics_0528 = {
    version = M.version,
    phase = candidate.action == "clear-output" and "move-to-machine"
      or "move-to-station",
    action = candidate.action,
    item = candidate.item,
    count = math.max(1, math.min(M.max_transfer, tonumber(candidate.count) or 1)),
    kind = candidate.kind,
    machine = candidate.machine,
    machine_unit = candidate.machine.unit_number,
    machine_name = candidate.machine.name,
    source_inventory = candidate.source_inventory,
    drill_source_0983 = candidate.drill_source_0983,
    drill_source_unit_0983 = candidate.drill_source_0983
      and candidate.drill_source_0983.unit_number or nil,
    started_tick = now(),
    updated_tick = now(),
  }
  pair.machine_logistics_candidate_0528 = nil
  pair.mode = "machine-logistics"
  record(pair, "task-began", candidate.action .. ":" .. candidate.item)
  return true, "task-began"
end
local function clear_state(pair, phase, why)
  local state = pair.machine_logistics_0528
  local machine = state and state.machine
  release_machine(pair, machine)
  -- Terminal machine logistics must surrender only its own movement route.
  -- Otherwise the old priority-740 return lease can prevent the dispatcher
  -- from resuming lower-priority acquisition/production for hundreds of ticks.
  local controller=rawget(_G,"TECH_PRIESTS_MOVEMENT_CONTROLLER_0418")
  if controller and type(controller.request_status)=="function" and
      type(controller.stop)=="function" then
    local ok,status=pcall(controller.request_status,pair)
    if ok and status and status.active==true and
        status.owner=="logistics_machine_fulfillment_0528" then
      local stopped,accepted=pcall(controller.stop,pair,"machine-logistics-terminal-0528")
      if stopped and accepted==true then
        stat("terminal_movement_released")
      else
        stat("terminal_movement_release_failed")
      end
    end
  end
  pair.machine_logistics_0528 = {
    version = M.version,
    phase = phase or "complete",
    completed_tick = now(),
    last_blocker = why,
  }
  if pair.target == machine then pair.target = nil end
  pair.mode = valid(pair.combat_target) and "combat" or "idle"
end
local function refund_custody(pair, reason)
  local state = pair.machine_logistics_0528
  local custody = state and state.custody
  if not custody then return true, "no-custody" end
  -- A drill output hold cannot be refunded from a Lua count: its real items
  -- must pass the exact receiver-to-station deposit with inventory readback.
  if custody.inventory_0984 then
    return false, "drill-output-requires-canonical-deposit-0984"
  end
  local role = custody.kind == "waste" and "waste" or "general"
  local ok, why = atomic_deposit(
    pair, custody.item, custody.count, reason or "machine-custody-return-0528", role)
  if not ok then
    state.phase = "return-custody-to-station"
    state.last_blocker = safe(why)
    state.updated_tick = now()
    stat("custody_return_blocked")
    return false, why
  end
  state.custody = nil
  pair.machine_logistics_custody_0528 = nil
  stat("custody_returned")
  return true, "custody-returned"
end
local function acquire_station_custody(pair, state)
  local removed = remove_generic(pair, state.item, state.count)
  if removed <= 0 then return false, "station-stock-unavailable" end
  state.custody = {
    version = M.version,
    item = state.item,
    count = removed,
    kind = "supply",
    source = "generic-container-storage",
    created_tick = now(),
  }
  pair.machine_logistics_custody_0528 = state.custody
  stat("station_items_removed", removed)
  return true, "station-custody-acquired"
end
local function acquire_output_custody(pair, state)
  local inv = state.source_inventory
  if not (inv and inv.valid) then
    inv = machine_output(state.machine) or machine_input(state.machine)
  end
  if not (inv and inv.valid) then return false, "machine-source-inventory-invalid" end
  local drill
  if state.machine.type=="container" or state.machine.type=="logistic-container" then
    local reason
    drill,reason=M.connected_drill_source_0983(
      pair,state.machine,state.drill_source_0983)
    if not drill then return false,reason end
  end
  local available = count_inventory(inv, state.item)
  local wanted = math.min(state.count, available)
  if wanted <= 0 then return false, "machine-output-empty" end
  -- 0984: real drill output travels in a persistent engine-owned inventory,
  -- not the 0528 numeric custody ledger used by legacy machine tasks.
  -- Allocate before debiting the receiver; preserve the hold on uncertainty.
  local hold
  if drill then
    if not (game and type(game.create_inventory)=="function") then
      return false, "drill-engine-cargo-unavailable"
    end
    local created, cargo=pcall(function() return game.create_inventory(1) end)
    if not (created and cargo and cargo.valid) then
      return false, "drill-engine-cargo-create-failed"
    end
    hold=cargo
    state.drill_escrow_0984=hold
    local ok, fits=pcall(function()
      return hold.can_insert({name=state.item,count=wanted})
    end)
    if not (ok and fits==true and count_inventory(hold,state.item)==0) then
      pcall(function() hold.destroy() end)
      state.drill_escrow_0984=nil
      return false, "drill-engine-cargo-capacity"
    end
  end
  local removed = remove_inventory(inv, state.item, wanted)
  local after=count_inventory(inv,state.item)
  if drill and after~=available-wanted then
    -- A post-mutation exception or competing debit is ambiguous. Never
    -- credit a guessed amount or repeat the withdrawal after reload.
    state.phase="custody-uncertain-0983"
    state.last_blocker="drill-output-debit-ambiguous"
    state.drill_pickup_0983={
      receiver_unit=state.machine.unit_number,drill_unit=drill.unit_number,
      station_unit=station_unit(pair),priest_unit=pair.priest.unit_number,
      item=state.item,source_before=available,source_after=after,
      requested=wanted,reported_removed=removed,tick=now(),
      status="quarantined",
    }
    return false,state.last_blocker
  end
  -- A Factorio callback can throw AFTER debiting its real inventory.
  -- For a connected drill receiver, the exact observed debit is stronger
  -- evidence than a missing callback return; never withdraw twice.
  if drill and removed~=wanted and after==available-wanted then
    removed=wanted
  end
  if removed ~= wanted then
    if removed > 0 then
      local restored = insert_inventory(inv, state.item, removed)
      if drill and (restored~=removed or count_inventory(inv,state.item)~=available) then
        state.phase="custody-uncertain-0983"
        state.last_blocker="drill-source-rollback-ambiguous"
        return false,state.last_blocker
      end
      if hold then pcall(function() hold.destroy() end);state.drill_escrow_0984=nil end
      return false, restored == removed and "short-remove-rolled-back"
        or "short-remove-rollback-failed"
    end
    if hold then pcall(function() hold.destroy() end);state.drill_escrow_0984=nil end
    return false, "machine-output-remove-failed"
  end
  if hold then
    -- Callback exceptions after insertion are reconciled from the actual
    -- engine hold, never by blindly inserting the same stack twice.
    insert_inventory(hold,state.item,removed)
    if count_inventory(hold,state.item)~=removed then
      state.phase="custody-uncertain-0983"
      state.last_blocker="drill-engine-cargo-insert-ambiguous"
      return false,state.last_blocker
    end
  end
  state.custody = {
    version = M.version,
    item = state.item,
    count = removed,
    kind = state.kind == "waste" and "waste" or "retention",
    source = "machine-output",
    machine_unit = state.machine.unit_number,
    created_tick = now(),
    inventory_0984 = hold,
  }
  pair.machine_logistics_custody_0528 = state.custody
  if drill then
    state.drill_escrow_0984=nil
    state.drill_pickup_0983={
      receiver_unit=state.machine.unit_number,drill_unit=drill.unit_number,
      station_unit=station_unit(pair),priest_unit=pair.priest.unit_number,
      item=state.item,source_before=available,source_after=after,
      count=removed,tick=now(),status="carried",
    }
  end
  stat("machine_output_removed", removed)
  return true, "machine-output-custody-acquired"
end
local function deliver_supply(pair, state)
  local custody = state.custody
  if not custody then return false, "no-supply-custody" end
  local destination = state.action == "supply-fuel"
    and machine_fuel(state.machine) or machine_input(state.machine)
  if not (destination and destination.valid) then
    return false, "machine-destination-invalid"
  end
  local inserted = insert_inventory(destination, custody.item, custody.count)
  if inserted > 0 then
    custody.count = custody.count - inserted
    stat("machine_items_inserted", inserted)
    if state.action == "supply-fuel" then
      stat("fuel-fed:" .. custody.item, inserted)
    elseif state.action == "supply-ingredient" then
      stat("ingredient-fed:" .. custody.item, inserted)
    end
  end
  if custody.count <= 0 then
    state.custody = nil
    pair.machine_logistics_custody_0528 = nil
    clear_state(pair, "complete")
    record(pair, "supply-complete", state.action .. ":" .. state.item)
    return true, "machine-supply-complete"
  end
  state.phase = "return-custody-to-station"
  state.last_blocker = inserted > 0 and "partial-machine-insert" or "machine-insert-blocked"
  return inserted > 0, state.last_blocker
end
local function deposit_output(pair, state)
  local custody = state.custody
  if not custody then return false, "no-output-custody" end
  local proof=state.drill_pickup_0983
  if proof and not (proof.status=="carried"
      and proof.station_unit==station_unit(pair)
      and proof.priest_unit==pair.priest.unit_number
      and proof.receiver_unit==state.machine_unit
      and proof.drill_unit==state.drill_source_unit_0983
      and proof.item==custody.item and proof.item==state.item
      and proof.count==custody.count
      and proof.count>0
      and proof.source_after==proof.source_before-proof.count
      and proof.tick<=now()) then
    state.phase="custody-uncertain-0983"
    state.last_blocker="drill-output-custody-proof-invalid"
    return false,state.last_blocker
  end
  if custody.inventory_0984 and not proof then
    state.phase="custody-uncertain-0983"
    state.last_blocker="drill-engine-cargo-without-provenance"
    return false,state.last_blocker
  end
  local role = custody.kind == "waste" and "waste" or "retention"
  if proof and custody.inventory_0984 then
    local hold=custody.inventory_0984
    if not (hold.valid and count_inventory(hold,custody.item)==custody.count) then
      state.phase="custody-uncertain-0983"
      state.last_blocker="drill-engine-cargo-count-mismatch"
      return false,state.last_blocker
    end
    local authority=storage_authority()
    if not (authority and type(authority.generic_item_count)=="function") then
      return false,"drill-station-count-authority-unavailable"
    end
    local function station_count()
      local ok,value=pcall(authority.generic_item_count,pair,custody.item)
      return ok and tonumber(value) or nil
    end
    local before=station_count()
    if before==nil then return false,"drill-station-count-unobservable" end
    local station_only,ranked_reason=ranked_return_station_deposit_0995(
      pair,custody.item)
    if station_only==nil then
      -- Keep the same counted engine-owned hold. Never turn a temporarily
      -- unverified ranked return into generic nearby-stash inventory.
      state.last_blocker="ranked-return-deposit-route-blocked:"..safe(ranked_reason)
      return false,state.last_blocker
    end
    -- Only the canonical 0686 storage authority may inspect Cogitator stock.
    -- 0528 must not probe station inventory internals directly.
    local station_before=station_only and authority.station_item_count
      and authority.station_item_count(pair,custody.item) or nil
    if station_only and station_before==nil then
      return false,"ranked-station-inventory-unavailable"
    end
    -- Debit the REAL hold before the canonical station deposit. An exception
    -- after station mutation is resolved by physical destination readback.
    remove_inventory(hold,custody.item,custody.count)
    if count_inventory(hold,custody.item)~=0 then
      state.phase="custody-uncertain-0983"
      state.last_blocker="drill-engine-cargo-debit-ambiguous"
      return false,state.last_blocker
    end
    local accepted,why=atomic_deposit(
      pair,custody.item,custody.count,"machine-output-deposit-0528",role,
      station_only and {station_only=true} or nil)
    local after=station_count()
    local station_after=station_only and authority.station_item_count
      and authority.station_item_count(pair,custody.item) or nil
    if station_only and station_after~=station_before+custody.count then
      state.phase="custody-uncertain-0983"
      state.last_blocker="ranked-station-physical-deposit-ambiguous-0995"
      return false,state.last_blocker
    end
    if after==before+custody.count then
      if station_only then
        proof.station_only_0995=true
        proof.station_container_before_0995=station_before
        proof.station_container_after_0995=station_after
      end
      proof.cargo_before_0984=custody.count
      proof.cargo_after_0984=0
      proof.station_before_0984=before
      proof.station_after_0984=after
      pcall(function() hold.destroy() end)
    elseif after==before and not accepted then
      -- A confirmed refusal has not credited storage. Return the exact
      -- debited stack to the original real hold and retry only if verified.
      insert_inventory(hold,custody.item,custody.count)
      if count_inventory(hold,custody.item)==custody.count then
        state.phase="return-custody-to-station"
        state.last_blocker="drill-station-deposit-refused:"..safe(why)
        return false,state.last_blocker
      end
      state.phase="custody-uncertain-0983"
      state.last_blocker="drill-engine-cargo-refund-ambiguous"
      return false,state.last_blocker
    else
      -- Partial/unknown station mutations cannot be replayed safely.
      state.phase="custody-uncertain-0983"
      state.last_blocker="drill-station-deposit-ambiguous"
      return false,state.last_blocker
    end
  else
    -- Legacy in-flight numeric cargo remains readable across old saves;
    -- new connected drill pickups always take the real-inventory path.
    local ok,why=atomic_deposit(
      pair,custody.item,custody.count,"machine-output-deposit-0528",role)
    if not ok then
      state.phase="return-custody-to-station"
      state.last_blocker=safe(why)
      return false,"output-deposit-blocked:"..safe(why)
    end
  end
  if proof then
    -- Written only after the canonical real-station deposit accepts the
    -- entire physical pickup. Primitive evidence survives save/reload.
    local receipts=pair.drill_output_receipts_0983 or {}
    receipts[#receipts+1]={
      station_unit=proof.station_unit,priest_unit=proof.priest_unit,
      receiver_unit=proof.receiver_unit,drill_unit=proof.drill_unit,
      item=proof.item,count=proof.count,
      source_before=proof.source_before,source_after=proof.source_after,
      pickup_tick=proof.tick,deposit_tick=now(),
      cargo_before_0984=proof.cargo_before_0984,
      cargo_after_0984=proof.cargo_after_0984,
      station_only_0995=proof.station_only_0995,
      station_container_before_0995=proof.station_container_before_0995,
      station_container_after_0995=proof.station_container_after_0995,
      station_before_0984=proof.station_before_0984,
      station_after_0984=proof.station_after_0984,
      deposit_authority="storage-role-deposit-exact-0686",
    }
    while #receipts>32 do table.remove(receipts,1) end
    pair.drill_output_receipts_0983=receipts
  end
  state.custody = nil
  pair.machine_logistics_custody_0528 = nil
  clear_state(pair, "complete")
  record(pair, "output-complete", state.item)
  return true, "machine-output-complete"
end

function M.yield_for_bootstrap(pair, reason)
  local craft=pair and pair.emergency_craft
  local strict=type(craft)=="table" and craft.strict_recipe_0647==true
  local acquiring=physical_direct_active(pair)
  if not valid_pair(pair) or not (strict or acquiring) then
    return false,"no-active-physical-prerequisite"
  end
  local order=pair.order_queue_0469 and pair.order_queue_0469.current
  if order and order.status=="active" and
      (order.kind=="machine-logistics" or order.kind=="machine_logistics") then
    return false,"explicit-machine-order"
  end
  local state=active_state(pair)
  -- Retain an existing completed-output route while direct mining has no
  -- physical custody. The dispatcher can hand off safely instead of clearing
  -- the same collection candidate every pulse.
  if not strict and not pair.direct_acquisition_custody_0513
    and completed_machine_output_ready(pair,state) then
    return false,"completed-machine-output-awaits-collection"
  end
  -- Never dispose of coal or output already physically removed from storage.
  if (state and state.custody) or pair.machine_logistics_custody_0528 then
    return false,"machine-custody-owned"
  end
  pair.machine_logistics_candidate_0528=nil
  local controller=rawget(_G,"TECH_PRIESTS_MOVEMENT_CONTROLLER_0418")
  if controller and type(controller.request_status)=="function"
      and type(controller.stop)=="function" then
    local ok,status=pcall(controller.request_status,pair)
    if ok and type(status)=="table" and status.active==true and
        status.owner=="logistics_machine_fulfillment_0528" then
      pcall(controller.stop,pair,"bootstrap-prerequisite-machine-yield-0528")
    end
  end
  if state then
    local aborted=M.abort_pair(pair,reason or "bootstrap-prerequisite")
    if aborted.failed>0 or aborted.blocked>0 then return false,"abort-blocked" end
  end
  if pair.mode=="machine-logistics" or pair.mode=="idle" then
    pair.mode=acquiring and "direct-acquisition" or "emergency-production-station-craft"
  end
  stat("bootstrap_machine_yields")
  return true,"bootstrap-owned"
end

function M.abort_pair(pair, reason)
  if not valid_pair(pair) then return result({ failed = 1, detail = "invalid-pair" }) end
  local state = pair.machine_logistics_0528
  if type(state) ~= "table" then return result({ processed = 0, detail = "no-state" }) end
  if state.phase=="custody-uncertain-0983" then
    return result({blocked=1,detail=state.last_blocker or "drill-custody-quarantined"})
  end
  if state.custody then
    state.phase = "return-custody-to-station"
    if dist_sq(pair.priest.position, pair.station.position) > M.station_reach_sq then
      local contact = station_contact(pair, state)
      if not contact then
        state.last_blocker = "station-contact-unavailable"
        return result({ blocked = 1, detail = state.last_blocker })
      end
      local moved, why = request_move_position(
        pair, contact, "machine-logistics-abort-return-0528", 0.15)
      if not moved then
        state.last_blocker = why
        return result({ failed = 1, detail = "abort-movement-failed:" .. safe(why) })
      end
      return result({ waiting = 1, detail = "abort-returning-custody" })
    end
    local returned, why = refund_custody(pair, "machine-logistics-abort-0528")
    if not returned then return result({ blocked = 1, detail = why }) end
  end
  clear_state(pair, "failed", reason or "machine-logistics-aborted")
  record(pair, "aborted", reason)
  return result({ acted = 1, detail = reason or "machine-logistics-aborted" })
end

function M.service_pair(pair, reason)
  if M.root().enabled == false then return result({ processed = 0, detail = "disabled" }) end
  if not valid_pair(pair) then return result({ failed = 1, detail = "invalid-pair" }) end
  if valid(pair.combat_target) then
    if active_state(pair) then return M.abort_pair(pair, "combat-priority") end
    return result({ processed = 0, detail = "combat-priority" })
  end
  local state = active_state(pair)
  if state and state.phase=="custody-uncertain-0983" then
    return result({blocked=1,detail=state.last_blocker or "drill-custody-quarantined"})
  end
  if not state then
    local candidate = pair.machine_logistics_candidate_0528
    if type(candidate) ~= "table" or not valid(candidate.machine)
      or (tonumber(candidate.expires_tick) or 0) < now()
    then
      return result({ processed = 0, detail = "no-machine-candidate" })
    end
    local began, why = begin_state(pair, candidate)
    if not began then return result({ blocked = 1, detail = why }) end
    state = pair.machine_logistics_0528
  end
  if not valid(state.machine) then return M.abort_pair(pair, "machine-invalid") end
  state.updated_tick = now()
  pair.target = state.machine
  if state.phase == "move-to-station"
    or state.phase == "return-custody-to-station"
  then
    pair.target = pair.station
  end
  pair.mode = "machine-logistics"

  if state.phase == "move-to-station" then
    if dist_sq(pair.priest.position, pair.station.position) > M.station_reach_sq then
      local contact = station_contact(pair, state)
      if not contact then
        return result({ blocked = 1, detail = "station-contact-unavailable" })
      end
      local moved, why = request_move_position(
        pair, contact, "machine-logistics-collect-station-0528", 0.15)
      if not moved then
        return result({ failed = 1, detail = "movement-failed:" .. safe(why) })
      end
      return result({ waiting = 1, detail = "move-to-station" })
    end
    local acquired, why = acquire_station_custody(pair, state)
    if not acquired then return M.abort_pair(pair, why) end
    state.phase = "move-to-machine"
    return result({ acted = 1, detail = "station-custody-acquired" })
  end

  if state.phase == "move-to-machine" then
    if dist_sq(pair.priest.position, state.machine.position) > M.machine_reach_sq then
      local moved, why = request_move(
        pair, state.machine, "machine-logistics-move-to-machine-0528")
      if not moved then
        return result({ failed = 1, detail = "movement-failed:" .. safe(why) })
      end
      return result({ waiting = 1, detail = "move-to-machine" })
    end
    if state.action == "clear-output" and not state.custody then
      local acquired, why = acquire_output_custody(pair, state)
      if not acquired then return M.abort_pair(pair, why) end
      state.phase = "return-custody-to-station"
      return result({ acted = 1, detail = "machine-output-custody-acquired" })
    end
    local delivered, why = deliver_supply(pair, state)
    if delivered and state.phase == "complete" then
      return result({ acted = 1, detail = why })
    end
    return result({
      acted = delivered and 1 or 0,
      blocked = delivered and 0 or 1,
      detail = why,
    })
  end

  if state.phase == "return-custody-to-station" then
    if dist_sq(pair.priest.position, pair.station.position) > M.station_reach_sq then
      local contact = station_contact(pair, state)
      if not contact then
        return result({ blocked = 1, detail = "station-contact-unavailable" })
      end
      local moved, why = request_move_position(
        pair, contact, "machine-logistics-return-custody-0528", 0.15)
      if not moved then
        return result({ failed = 1, detail = "movement-failed:" .. safe(why) })
      end
      return result({ waiting = 1, detail = "return-custody-to-station" })
    end
    if state.action == "clear-output" then
      local deposited, why = deposit_output(pair, state)
      return result({
        acted = deposited and 1 or 0,
        blocked = deposited and 0 or 1,
        detail = why,
      })
    end
    local returned, why = refund_custody(pair, "machine-supply-leftover-0528")
    if not returned then return result({ blocked = 1, detail = why }) end
    clear_state(pair, "failed", state.last_blocker or "machine-insert-incomplete")
    return result({ acted = 1, detail = "supply-leftover-returned" })
  end

  return M.abort_pair(pair, "unknown-phase:" .. safe(state.phase))
end

function M.describe_pair(pair)
  if not valid_pair(pair) then return "invalid pair" end
  local state = pair.machine_logistics_0528 or {}
  local candidate = pair.machine_logistics_candidate_0528 or {}
  local custody = state.custody or pair.machine_logistics_custody_0528 or {}
  return "phase=" .. safe(state.phase or "none")
    .. " action=" .. safe(state.action or candidate.action or "none")
    .. " item=" .. safe(state.item or candidate.item or custody.item or "none")
    .. " custody=" .. safe(custody.count or 0)
    .. " machine=" .. safe(state.machine_name
      or (valid(candidate.machine) and candidate.machine.name) or "none")
end

local function register_discovery()
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if not (broker and type(broker.register_service) == "function") then return false end
  local service = broker.register_service({
    name = "machine_logistics_discovery_0528",
    category = "logistics",
    interval = M.discovery_interval,
    priority = 70,
    budget = M.discovery_budget,
    dynamic_budget = true,
    note = "bounded machine candidate discovery only; dispatcher owns execution",
    fn = function(_, budget) return discover_pairs(budget) end,
  })
  return service ~= nil
end
local function patch_diagnostics()
  local diagnostics = rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
    or rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diagnostics and type(diagnostics.pair_dump_lines) == "function") then
    return false
  end
  if diagnostics.machine_logistics_0528_recovery_wrapped then return true end
  diagnostics.machine_logistics_0528_recovery_wrapped = true
  local previous = diagnostics.pair_dump_lines
  diagnostics.pair_dump_lines = function(...)
    local lines = previous(...)
    lines = type(lines) == "table" and lines or {}
    local root = M.root()
    lines[#lines + 1] = "PAIR-DUMP-0468 MACHINE-LOGISTICS-0528 version="
      .. M.version .. " dispatcher_owned=" .. safe(root.dispatcher_owned)
      .. " station_removed=" .. safe(root.stats.station_items_removed or 0)
      .. " output_removed=" .. safe(root.stats.machine_output_removed or 0)
      .. " inserted=" .. safe(root.stats.machine_items_inserted or 0)
      .. " custody_returned=" .. safe(root.stats.custody_returned or 0)
      .. " station_machine_inventory_access=0"
    for _, pair in pairs(pair_map()) do
      if valid_pair(pair) then
        lines[#lines + 1] = "PAIR-DUMP-0468 machine-logistics["
          .. safe(station_unit(pair)) .. "] " .. M.describe_pair(pair)
      end
    end
    return lines
  end
  return true
end

function M.install()
  M.root()
  local discovery_ok = register_discovery()
  patch_diagnostics()
  if commands and commands.remove_command then
    pcall(commands.remove_command, "tp-machine-logistics-0528")
  end
  _G.TECH_PRIESTS_MACHINE_LOGISTICS_FULFILLMENT_0528 = M
  _G.TechPriestsMachineLogisticsFulfillment0528 = M
  if log then
    log("[Tech-Priests 0.1.674-dev] consolidated dispatcher-owned machine logistics installed")
  end
  return discovery_ok == true
end

return M
