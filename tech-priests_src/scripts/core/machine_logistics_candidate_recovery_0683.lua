-- Tech Priests 0.1.664 machine-logistics candidate recovery.
--
-- The original 0528 automation test treated any belt, pipe, splitter, or pump
-- within two tiles as proof that an assembler/furnace was automated. This narrow
-- recovery pass runs only when 0528 reports no machine task and identifies item
-- automation by actual inserter/loader connection instead of ambient proximity.
-- It seeds the existing 0528 state machine; 0682 still owns physical custody,
-- reservations, admission, movement truth, and terminal cleanup.

local M = {
  version = "0.1.664",
  storage_key = "machine_logistics_candidate_recovery_0683",
  max_scan_entities = 160,
  service_radius_floor = 28,
  service_radius_cap = 96,
  min_fuel_count = 3,
  max_transfer = 50,
}

local previous_integrity_activate
local previous_machine_service

local WASTE_ITEMS = {
  ["mechanical-detritus"] = true,
  scrap = true,
}

local FUEL_CANDIDATES = {
  "coal", "wood", "solid-fuel", "rocket-fuel", "nuclear-fuel",
}

local function now()
  return game and game.tick or 0
end

local function valid(entity)
  return entity and entity.valid
end

local function safe(value)
  if value == nil then return "nil" end
  local ok, text = pcall(tostring, value)
  return ok and text or "?"
end

local function dist_sq(a, b)
  if not (a and b) then return 999999999 end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end

local function valid_pair(pair)
  return pair and valid(pair.station) and valid(pair.priest)
end

local function station_unit(pair)
  return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil
end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    connection_aware_automation = true,
    stats = {},
    recent = {},
  }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.connection_aware_automation == nil then r.connection_aware_automation = true end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  return r
end

local function stat(name, amount)
  local r = root()
  r.stats[name] = (r.stats[name] or 0) + (amount or 1)
end

local function record(pair, action, detail)
  local r = root()
  stat(action)
  r.recent[#r.recent + 1] = {
    tick = now(),
    action = tostring(action or "event"),
    station = safe(station_unit(pair)),
    detail = tostring(detail or ""),
  }
  while #r.recent > 120 do table.remove(r.recent, 1) end
end

local function item_exists(name)
  return type(name) == "string"
    and name ~= ""
    and prototypes
    and prototypes.item
    and prototypes.item[name] ~= nil
end

local function inventory(entity, inventory_id)
  if not (valid(entity) and inventory_id and entity.get_inventory) then return nil end
  local ok, inv = pcall(function() return entity.get_inventory(inventory_id) end)
  return ok and inv and inv.valid and inv or nil
end

local function inventory_count(inv, item)
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
        and tonumber(value.count or value.amount or value[2])
        or tonumber(value)
    elseif type(value) == "table" then
      name = value.name or value.item or value[1]
      count = tonumber(value.count or value.amount or value[2])
    end
    if type(name) == "string" and name ~= "" and (tonumber(count) or 0) > 0 then
      callback(name, tonumber(count) or 1)
    end
  end
end

local function station_count(pair, item)
  if not (valid_pair(pair) and item) then return 0 end
  if type(_G.tech_priests_0358_station_item_count) == "function" then
    local ok, count = pcall(_G.tech_priests_0358_station_item_count, pair, item)
    if ok then return tonumber(count) or 0 end
  end
  local d = defines and defines.inventory
  if not d then return 0 end
  local seen, total = {}, 0
  local ids = {}
  local function add_id(value) if value then ids[#ids + 1] = value end end
  add_id(d.chest)
  add_id(d.assembling_machine_input)
  add_id(d.assembling_machine_output)
  add_id(d.furnace_source)
  add_id(d.furnace_result)
  for _, inventory_id in ipairs(ids) do
    local inv = inventory(pair.station, inventory_id)
    local key = inv and safe(inv) or nil
    if inv and not seen[key] then
      seen[key] = true
      total = total + inventory_count(inv, item)
    end
  end
  return total
end

local function machine_input(machine)
  local d = defines and defines.inventory
  if not d then return nil end
  return inventory(machine, d.assembling_machine_input)
    or inventory(machine, d.furnace_source)
end

local function machine_output(machine)
  local d = defines and defines.inventory
  if not d then return nil end
  return inventory(machine, d.assembling_machine_output)
    or inventory(machine, d.furnace_result)
end

local function machine_fuel(machine)
  local d = defines and defines.inventory
  return d and inventory(machine, d.fuel) or nil
end

local function get_recipe(machine)
  if not (valid(machine) and machine.get_recipe) then return nil end
  local ok, recipe = pcall(function() return machine.get_recipe() end)
  return ok and recipe or nil
end

local function recipe_ingredients(recipe)
  local out = {}
  if not recipe then return out end
  local ingredients = nil
  local ok = pcall(function() ingredients = recipe.ingredients end)
  if not (ok and type(ingredients) == "table") then return out end
  for _, ingredient in pairs(ingredients) do
    local name = ingredient.name or ingredient[1]
    local ingredient_type = ingredient.type or (ingredient.name and "item")
    local amount = tonumber(ingredient.amount or ingredient.amount_min or ingredient[2]) or 1
    if ingredient_type ~= "fluid" and item_exists(name) then
      out[#out + 1] = {
        name = name,
        amount = math.max(1, math.ceil(amount)),
      }
    end
  end
  return out
end

local function position_inside_box(position, box, padding)
  if not (position and box and box.left_top and box.right_bottom) then return false end
  padding = tonumber(padding) or 0.15
  return position.x >= box.left_top.x - padding
    and position.x <= box.right_bottom.x + padding
    and position.y >= box.left_top.y - padding
    and position.y <= box.right_bottom.y + padding
end

local function machine_box(machine)
  if not valid(machine) then return nil end
  local ok, box = pcall(function() return machine.bounding_box end)
  if ok and box then return box end
  ok, box = pcall(function() return machine.selection_box end)
  return ok and box or nil
end

local function inserter_connected(inserter, machine)
  if not (valid(inserter) and valid(machine) and inserter.type == "inserter") then return false end
  local ok, pickup_target = pcall(function() return inserter.pickup_target end)
  if ok and pickup_target == machine then return true end
  local ok2, drop_target = pcall(function() return inserter.drop_target end)
  if ok2 and drop_target == machine then return true end

  local box = machine_box(machine)
  local pickup_position, drop_position
  pcall(function() pickup_position = inserter.pickup_position end)
  pcall(function() drop_position = inserter.drop_position end)
  return position_inside_box(pickup_position, box, 0.25)
    or position_inside_box(drop_position, box, 0.25)
end

local function loader_connected(loader, machine)
  if not (valid(loader) and valid(machine)) then return false end
  if loader.type ~= "loader" and loader.type ~= "loader-1x1" then return false end
  local ok, target = pcall(function() return loader.loader_container end)
  if ok and target == machine then return true end
  -- Factorio/modded loaders do not expose loader_container consistently. A loader
  -- whose own collision box directly touches the machine is still strong evidence
  -- of a real item connection; unrelated belts farther away are ignored.
  local distance = math.sqrt(dist_sq(loader.position, machine.position))
  return distance <= 1.65
end

local function has_connected_item_automation(machine)
  if not valid(machine) then return false, nil end
  local box = machine_box(machine)
  local position = machine.position
  local padding = 3.0
  local area
  if box then
    area = {
      { box.left_top.x - padding, box.left_top.y - padding },
      { box.right_bottom.x + padding, box.right_bottom.y + padding },
    }
  else
    area = {
      { position.x - padding, position.y - padding },
      { position.x + padding, position.y + padding },
    }
  end

  local ok, entities = pcall(function()
    return machine.surface.find_entities_filtered({
      area = area,
      force = machine.force,
      type = { "inserter", "loader", "loader-1x1" },
      limit = 64,
    })
  end)
  if not (ok and entities) then return false, nil end
  for _, entity in pairs(entities) do
    if inserter_connected(entity, machine) or loader_connected(entity, machine) then
      return true, entity
    end
  end
  return false, nil
end

local function output_task(machine)
  local output = machine_output(machine)
  local tasks = {}
  if output then
    each_inventory_item(output, function(item, count)
      tasks[#tasks + 1] = {
        action = "clear-output",
        item = item,
        count = count,
        inv = output,
        machine = machine,
        kind = WASTE_ITEMS[item] and "waste" or "retention",
      }
    end)
  end
  local input = machine_input(machine)
  if input then
    local detritus = inventory_count(input, "mechanical-detritus")
    if detritus > 0 then
      tasks[#tasks + 1] = {
        action = "clear-output",
        item = "mechanical-detritus",
        count = detritus,
        inv = input,
        machine = machine,
        kind = "waste",
      }
    end
  end
  table.sort(tasks, function(a, b)
    if a.kind ~= b.kind then return a.kind == "waste" end
    return (a.count or 0) > (b.count or 0)
  end)
  return tasks[1]
end

local function fuel_task(pair, machine)
  local fuel = machine_fuel(machine)
  if not fuel then return nil end
  local total = 0
  each_inventory_item(fuel, function(_, count) total = total + count end)
  if total >= M.min_fuel_count then return nil end

  for _, item in ipairs(FUEL_CANDIDATES) do
    if item_exists(item) then
      local available = station_count(pair, item)
      if available > 0 then
        return {
          action = "supply-fuel",
          item = item,
          count = math.min(M.min_fuel_count - total, available, 10),
          machine = machine,
        }
      end
    end
  end
  for _, item in ipairs(FUEL_CANDIDATES) do
    if item_exists(item) then
      return {
        action = "request-fuel",
        item = item,
        count = math.max(1, M.min_fuel_count - total),
        machine = machine,
      }
    end
  end
  return nil
end

local function ingredient_task(pair, machine)
  local recipe = get_recipe(machine)
  local input = machine_input(machine)
  if not (recipe and input) then return nil end
  for _, ingredient in ipairs(recipe_ingredients(recipe)) do
    local have = inventory_count(input, ingredient.name)
    if have < ingredient.amount then
      local missing = ingredient.amount - have
      local available = station_count(pair, ingredient.name)
      if available > 0 then
        return {
          action = "supply-ingredient",
          item = ingredient.name,
          count = math.min(missing, available, M.max_transfer),
          machine = machine,
        }
      end
      return {
        action = "request-ingredient",
        item = ingredient.name,
        count = missing,
        machine = machine,
      }
    end
  end
  return nil
end

local function service_radius(pair)
  local radius = tonumber(pair and pair.radius) or M.service_radius_floor
  if type(_G.get_station_operating_radius) == "function" and valid(pair and pair.station) then
    local ok, current = pcall(_G.get_station_operating_radius, pair.station)
    if ok and tonumber(current) then radius = tonumber(current) end
  end
  return math.max(8, math.min(math.max(radius, M.service_radius_floor), M.service_radius_cap))
end

local function find_recovered_task(pair)
  if not valid_pair(pair) then return nil end
  local radius = service_radius(pair)
  local position = pair.station.position
  local ok, machines = pcall(function()
    return pair.station.surface.find_entities_filtered({
      area = {
        { position.x - radius, position.y - radius },
        { position.x + radius, position.y + radius },
      },
      force = pair.station.force,
      type = { "assembling-machine", "furnace" },
      limit = M.max_scan_entities,
    })
  end)
  if not (ok and machines) then return nil end

  local best, best_score
  for _, machine in pairs(machines) do
    if valid(machine) and machine ~= pair.station then
      local automated, automation_entity = has_connected_item_automation(machine)
      if automated then
        stat("connected_automation_skipped")
      else
        local task = output_task(machine)
          or fuel_task(pair, machine)
          or ingredient_task(pair, machine)
        if task then
          local priority = task.action == "clear-output" and 600
            or task.action == "supply-fuel" and 500
            or 420
          if task.kind == "waste" then priority = priority + 120 end
          local score = priority
            - math.sqrt(dist_sq(pair.priest.position, machine.position))
            - math.sqrt(dist_sq(pair.station.position, machine.position)) * 0.15
          if not best_score or score > best_score then
            best = task
            best_score = score
            best.recovery_automation_entity = automation_entity
          end
        end
      end
    end
  end
  return best
end

local function seed_task(pair, task)
  if not (valid_pair(pair) and task and valid(task.machine)) then return false end
  if task.action == "request-ingredient" or task.action == "request-fuel" then
    local fulfill = task.action == "request-fuel" and "supply-fuel" or "supply-ingredient"
    pair.active_supply_request = {
      item = task.item,
      count = task.count or 1,
      source = "machine-logistics-0528",
      purpose = fulfill,
      machine_unit = task.machine.unit_number,
      machine_name = task.machine.name,
      tick = now(),
      recovered_candidate_0683 = true,
    }
    pair.logistic_requested_item = {
      item = task.item,
      count = task.count or 1,
      source = "machine-logistics-0528",
      purpose = fulfill,
      machine_unit = task.machine.unit_number,
      recovered_candidate_0683 = true,
    }
    pair.machine_logistics_0528 = {
      phase = "waiting-known-source-fetch",
      action = task.action,
      fulfill_action = fulfill,
      item = task.item,
      count = task.count or 1,
      machine = task.machine,
      machine_unit = task.machine.unit_number,
      machine_name = task.machine.name,
      tick = now(),
      started_tick = now(),
      recovered_candidate_0683 = true,
    }
  else
    pair.machine_logistics_0528 = {
      phase = "move-to-machine",
      action = task.action,
      item = task.item,
      count = math.max(1, math.min(M.max_transfer, tonumber(task.count) or 1)),
      kind = task.kind,
      machine = task.machine,
      machine_unit = task.machine.unit_number,
      machine_name = task.machine.name,
      source_inv = task.inv,
      started_tick = now(),
      tick = now(),
      recovered_candidate_0683 = true,
    }
  end
  pair.mode = "machine-logistics-fulfillment"
  record(pair, "false-automation-candidate-recovered",
    task.action .. " " .. safe(task.item) .. " at " .. safe(task.machine.name)
      .. "#" .. safe(task.machine.unit_number))
  return true
end

local function should_recover(reason, pair)
  if not root().enabled or not valid_pair(pair) then return false end
  if pair.machine_logistics_0528 then return false end
  local text = tostring(reason or "")
  return text == "no-machine-task" or text == "cooldown"
end

local function patched_machine_service(pair, reason, ...)
  local acted, why = previous_machine_service(pair, reason, ...)
  if acted or not should_recover(why, pair) then return acted, why end

  local task = find_recovered_task(pair)
  if not task then
    stat("recovery_scan_miss")
    return acted, why
  end
  if not seed_task(pair, task) then return acted, why end

  stat("recovery_scan_hit")
  -- Run the 0682 integrity wrapper again with the newly seeded state. Supply
  -- tasks will be converted to station pickup; output tasks remain in 0528's
  -- physical removal/deposit path under reservation and custody protection.
  return previous_machine_service(pair, "candidate-recovery-0683", ...)
end

local function patch_diagnostics()
  local diagnostics = rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")
    or rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diagnostics and type(diagnostics.pair_dump_lines) == "function")
    or diagnostics.machine_logistics_candidate_recovery_0683_wrapped
  then
    return false
  end

  diagnostics.machine_logistics_candidate_recovery_0683_wrapped = true
  local previous = diagnostics.pair_dump_lines
  diagnostics.pair_dump_lines = function(...)
    local lines = previous(...)
    lines = type(lines) == "table" and lines or {}
    local r = root()
    lines[#lines + 1] = "PAIR-DUMP-0468 MACHINE-CANDIDATE-RECOVERY-0683 enabled="
      .. safe(r.enabled)
      .. " recovered=" .. safe(r.stats["false-automation-candidate-recovered"] or 0)
      .. " hits=" .. safe(r.stats.recovery_scan_hit or 0)
      .. " misses=" .. safe(r.stats.recovery_scan_miss or 0)
      .. " connected_skipped=" .. safe(r.stats.connected_automation_skipped or 0)
    return lines
  end
  return true
end

function M.activate(machine)
  if not (machine and type(machine.service_pair) == "function") then return false end
  if machine.machine_logistics_candidate_recovery_0683_active then return true end
  machine.machine_logistics_candidate_recovery_0683_active = true
  previous_machine_service = machine.service_pair
  machine.service_pair = patched_machine_service
  patch_diagnostics()
  _G.TechPriestsMachineLogisticsCandidateRecovery0683 = M
  return true
end

function M.install()
  root()
  local ok, integrity = pcall(require, "scripts.core.machine_logistics_integrity_0682")
  if not (ok and integrity and type(integrity.activate) == "function") then return false end

  if not integrity.machine_logistics_candidate_recovery_0683_activate_wrapped then
    integrity.machine_logistics_candidate_recovery_0683_activate_wrapped = true
    previous_integrity_activate = integrity.activate
    integrity.activate = function(machine, ...)
      local result = previous_integrity_activate(machine, ...)
      M.activate(machine)
      return result
    end
  end

  local machine = rawget(_G, "TECH_PRIESTS_MACHINE_LOGISTICS_FULFILLMENT_0528")
  if machine then M.activate(machine) end
  _G.TechPriestsMachineLogisticsCandidateRecovery0683 = M
  return true
end

return M
