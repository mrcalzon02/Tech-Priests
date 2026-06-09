-- scripts/core/logistics_machine_fulfillment_0528.lua
-- Tech Priests 0.1.528
--
-- Dispatcher-owned machine logistics fulfillment.  This is not a new free-running
-- controller: it is installed as a high-priority dispatcher wrapper, before raw
-- acquisition/emergency crafting, so a priest can service known local production
-- machines physically.  Non-automated assemblers/furnaces can have outputs
-- cleared, fuel supplied, and item ingredients supplied from station-known stock.
-- If the needed item exists elsewhere in the catalog, this module expresses that
-- need so logistics_fetch_executor_0527 can go fetch it before raw mining.

local M = {}
M.version = "0.1.628"
M.storage_key = "logistics_machine_fulfillment_0528"
M.service_radius = 28
M.machine_reach_sq = 2.56
M.storage_reach_sq = 2.56
M.move_priority = 740
M.move_ttl = 60 * 8
M.cooldown_ticks = 60 * 3
M.max_transfer_per_trip = 50
M.max_scan_entities = 96
M.min_fuel_count = 3

local WASTE_ITEMS = {
  ["mechanical-detritus"] = true,
  ["scrap"] = true,
}

local FUEL_CANDIDATES = {
  "coal", "wood", "solid-fuel", "rocket-fuel", "nuclear-fuel"
}

local MACHINE_TYPES = {
  ["assembling-machine"] = true,
  ["furnace"] = true,
}

local AUTOMATION_TYPES = {
  ["inserter"] = true,
  ["loader"] = true,
  ["loader-1x1"] = true,
  ["transport-belt"] = true,
  ["underground-belt"] = true,
  ["splitter"] = true,
  ["linked-belt"] = true,
  ["pipe"] = true,
  ["pipe-to-ground"] = true,
  ["pump"] = true,
}

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) local ok,o=pcall(function() return tostring(v) end); return ok and o or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function valid_pair(pair) return pair and valid(pair.station) and valid(pair.priest) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function dist_sq(a,b) if not (a and b) then return 999999999 end; local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end

local function routed_find(surface, filters, category, negative_key, ttl)
  local Scan = rawget(_G, "TechPriestsScanRouting0610")
  if not Scan then local okS, mod = pcall(require, "scripts.core.scan_routing_0610"); if okS then Scan = mod end end
  if Scan and type(Scan.find_entities) == "function" then
    local ents = select(1, Scan.find_entities(surface, filters, { category = category or "machine-logistics", negative_key = negative_key, negative_ttl = ttl or 60 * 4 }))
    return ents or {}
  end
  local ok, ents = pcall(function() return surface.find_entities_filtered(filters) end)
  return (ok and ents) or {}
end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    dispatcher_priority = true,
    service_unautomated_only = true,
    stats = {},
    recent = {},
    cooldowns = {},
    retention_boxes = {},
    waste_boxes = {},
  }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.dispatcher_priority == nil then r.dispatcher_priority = true end
  if r.service_unautomated_only == nil then r.service_unautomated_only = true end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  r.cooldowns = r.cooldowns or {}
  r.retention_boxes = r.retention_boxes or {}
  r.waste_boxes = r.waste_boxes or {}
  return r
end

local function stat(name, n) local r=M.root(); r.stats[name]=(r.stats[name] or 0)+(n or 1) end
local function record(pair, event, detail)
  local r = M.root(); stat(event)
  local rec = { tick=now(), event=tostring(event or "event"), station=safe(station_unit(pair)), priest=safe(priest_unit(pair)), detail=tostring(detail or "") }
  r.recent[#r.recent+1] = rec
  while #r.recent > 180 do table.remove(r.recent, 1) end
  if pair then pair.machine_logistics_0528_last = rec end
  return rec
end

local function item_exists(name)
  return type(name) == "string" and name ~= "" and prototypes and prototypes.item and prototypes.item[name] ~= nil
end

local function inventory(entity, inv_id)
  if not (valid(entity) and entity.get_inventory and inv_id) then return nil end
  local ok, inv = pcall(function() return entity.get_inventory(inv_id) end)
  if ok and inv and inv.valid then return inv end
  return nil
end

local function count_inv(inv, item)
  if not (inv and inv.valid and item) then return 0 end
  local ok, n = pcall(function() return inv.get_item_count(item) end)
  return ok and (tonumber(n) or 0) or 0
end

local function remove_inv(inv, item, count)
  if not (inv and inv.valid and item and count and count > 0) then return 0 end
  local ok, n = pcall(function() return inv.remove({ name=item, count=count }) end)
  return ok and (tonumber(n) or 0) or 0
end

local function insert_inv(inv, item, count)
  if not (inv and inv.valid and item and count and count > 0) then return 0 end
  local ok, n = pcall(function() return inv.insert({ name=item, count=count }) end)
  return ok and (tonumber(n) or 0) or 0
end

local function can_insert(inv, item, count)
  if not (inv and inv.valid and item and count and count > 0) then return false end
  local ok, yes = pcall(function() return inv.can_insert({ name=item, count=count }) end)
  return ok and yes == true
end

local function each_inventory_item(inv, cb)
  if not (inv and inv.valid and type(cb) == "function") then return end
  local ok, contents = pcall(function() return inv.get_contents() end)
  if not (ok and type(contents) == "table") then return end
  for key, value in pairs(contents) do
    local name, count
    if type(key) == "string" then
      name = key
      if type(value) == "table" then count = tonumber(value.count or value.amount or value[2]) else count = tonumber(value) end
    elseif type(value) == "table" then
      name = value.name or value.item or value[1]
      count = tonumber(value.count or value.amount or value[2])
    end
    if type(name) == "string" and name ~= "" and (tonumber(count) or 0) > 0 then cb(name, tonumber(count) or 1) end
  end
end

local function station_inventories(pair)
  local out = {}
  if not valid_pair(pair) then return out end
  local ids = { defines.inventory.chest, defines.inventory.assembling_machine_input, defines.inventory.assembling_machine_output, defines.inventory.furnace_source, defines.inventory.furnace_result }
  local seen = {}
  for _, id in ipairs(ids) do
    local inv = inventory(pair.station, id)
    if inv and not seen[tostring(inv)] then out[#out+1] = inv; seen[tostring(inv)] = true end
  end
  return out
end

local function station_count(pair, item)
  if not (valid_pair(pair) and item) then return 0 end
  if type(_G.tech_priests_0358_station_item_count) == "function" then local ok,n=pcall(_G.tech_priests_0358_station_item_count,pair,item); if ok then return tonumber(n) or 0 end end
  local total = 0
  for _, inv in ipairs(station_inventories(pair)) do total = total + count_inv(inv, item) end
  return total
end

local function remove_from_station(pair, item, count)
  local remaining = math.max(1, tonumber(count) or 1)
  local removed = 0
  for _, inv in ipairs(station_inventories(pair)) do
    if remaining <= 0 then break end
    local n = remove_inv(inv, item, remaining)
    removed = removed + n
    remaining = remaining - n
  end
  return removed
end

local function machine_input_inventory(machine)
  return inventory(machine, defines.inventory.assembling_machine_input) or inventory(machine, defines.inventory.furnace_source)
end

local function machine_output_inventory(machine)
  return inventory(machine, defines.inventory.assembling_machine_output) or inventory(machine, defines.inventory.furnace_result)
end

local function machine_fuel_inventory(machine)
  return inventory(machine, defines.inventory.fuel)
end

local function get_recipe(machine)
  if not (valid(machine) and machine.get_recipe) then return nil end
  local ok, recipe = pcall(function() return machine.get_recipe() end)
  if ok and recipe then return recipe end
  return nil
end

local function recipe_ingredients(recipe)
  local out = {}
  if not recipe then return out end
  local raw = nil
  local ok = pcall(function() raw = recipe.ingredients end)
  if not ok or type(raw) ~= "table" then return out end
  for _, ing in pairs(raw) do
    local name = ing.name or ing[1]
    local amount = tonumber(ing.amount or ing.amount_min or ing[2]) or 1
    local typ = ing.type or (ing.name and "item") or nil
    if type(name) == "string" and name ~= "" and typ ~= "fluid" and item_exists(name) then out[#out+1] = { name=name, amount=math.max(1, math.ceil(amount)) } end
  end
  return out
end

local function recipe_has_fluid(recipe)
  if not recipe then return false end
  local raw = nil
  local ok = pcall(function() raw = recipe.ingredients end)
  if not ok or type(raw) ~= "table" then return false end
  for _, ing in pairs(raw) do if ing.type == "fluid" then return true end end
  return false
end

local function has_adjacent_automation(machine)
  if not valid(machine) then return false end
  local p = machine.position
  local area = { { p.x - 2.0, p.y - 2.0 }, { p.x + 2.0, p.y + 2.0 } }
  local ents = routed_find(machine.surface, { area = area, force = machine.force, limit = 48 }, "machine-automation", "machine-automation:" .. tostring(machine.surface.index) .. ":" .. tostring(machine.force.index) .. ":" .. tostring(machine.unit_number or "?"), 60 * 5)
  for _, e in pairs(ents) do
    if valid(e) and e ~= machine and AUTOMATION_TYPES[e.type] then return true, e end
  end
  return false, nil
end

local function is_machine(entity)
  return valid(entity) and MACHINE_TYPES[entity.type] == true
end

local function machine_label(e)
  if not valid(e) then return "nil" end
  return tostring(e.name) .. "#" .. tostring(e.unit_number or "?")
end

local function output_stacks(machine)
  local out = {}
  local inv = machine_output_inventory(machine)
  if inv then each_inventory_item(inv, function(name, count) out[#out+1] = { item=name, count=count, inv=inv, kind=WASTE_ITEMS[name] and "waste" or "retention" } end) end
  -- Mechanical detritus can be inserted into input/source inventories on some
  -- machines as a jam marker; treat it as waste even when found outside output.
  local inp = machine_input_inventory(machine)
  if inp then
    local n = count_inv(inp, "mechanical-detritus")
    if n > 0 then out[#out+1] = { item="mechanical-detritus", count=n, inv=inp, kind="waste" } end
  end
  return out
end

local function fuel_candidate(pair)
  for _, item in ipairs(FUEL_CANDIDATES) do
    if item_exists(item) and station_count(pair, item) > 0 then return item, station_count(pair,item) end
  end
  return nil, 0
end

local function machine_needs_fuel(pair, machine)
  local fuel = machine_fuel_inventory(machine)
  if not fuel then return nil end
  local fuel_count = 0
  each_inventory_item(fuel, function(_, count) fuel_count = fuel_count + count end)
  if fuel_count >= M.min_fuel_count then return nil end
  local item, available = fuel_candidate(pair)
  if item and available > 0 then return { action="supply-fuel", item=item, count=math.min(M.min_fuel_count - fuel_count, available, 10), machine=machine } end
  for _, candidate in ipairs(FUEL_CANDIDATES) do
    if item_exists(candidate) then
      return { action="request-fuel", item=candidate, count=math.max(1, M.min_fuel_count - fuel_count), machine=machine }
    end
  end
  return nil
end

local function machine_needs_ingredient(pair, machine)
  local recipe = get_recipe(machine)
  if not recipe then return nil end
  if recipe_has_fluid(recipe) then
    -- Fluid supply belongs to a later pipe/fluid logistics pass. If the machine
    -- has pipe automation, it will already be skipped by the automation check.
  end
  local inp = machine_input_inventory(machine)
  if not inp then return nil end
  for _, ing in ipairs(recipe_ingredients(recipe)) do
    local have = count_inv(inp, ing.name)
    if have < ing.amount then
      local missing = ing.amount - have
      local station_have = station_count(pair, ing.name)
      if station_have > 0 then
        return { action="supply-ingredient", item=ing.name, count=math.min(missing, station_have, M.max_transfer_per_trip), machine=machine }
      end
      -- Express the exact item need so universal known-resource fetch can obtain
      -- it before raw acquisition or emergency crafting. This is intentionally
      -- an intent handoff, not a hidden transfer.
      return { action="request-ingredient", item=ing.name, count=missing, machine=machine }
    end
  end
  return nil
end

local function best_machine_task(pair)
  if not valid_pair(pair) then return nil end
  local r = tonumber(pair.radius) or M.service_radius
  r = math.max(8, math.min(math.max(r, M.service_radius), 96))
  local p = pair.station.position
  local ents = routed_find(pair.station.surface, { area={{p.x-r,p.y-r},{p.x+r,p.y+r}}, force=pair.station.force, type={"assembling-machine","furnace"}, limit=M.max_scan_entities }, "machine-logistics", "machine-logistics:" .. tostring(pair.station.surface.index) .. ":" .. tostring(pair.station.force.index) .. ":" .. tostring(station_unit(pair) or "?"), 60 * 4)
  local best, best_score = nil, nil
  for _, machine in pairs(ents) do
    if is_machine(machine) and machine ~= pair.station then
      local automated = has_adjacent_automation(machine)
      if not (M.root().service_unautomated_only and automated) then
        local outputs = output_stacks(machine)
        local task = nil
        if #outputs > 0 then
          table.sort(outputs, function(a,b) if a.kind ~= b.kind then return a.kind == "waste" end; return (a.count or 0) > (b.count or 0) end)
          task = { action="clear-output", item=outputs[1].item, count=outputs[1].count, inv=outputs[1].inv, machine=machine, kind=outputs[1].kind }
        end
        if not task then task = machine_needs_fuel(pair, machine) end
        if not task then task = machine_needs_ingredient(pair, machine) end
        if task then
          local d = dist_sq(pair.priest.position, machine.position)
          local sd = dist_sq(pair.station.position, machine.position)
          local priority = (task.action == "clear-output" and 600 or task.action == "supply-fuel" and 500 or 420)
          if task.kind == "waste" then priority = priority + 120 end
          local score = priority - math.sqrt(d) - (math.sqrt(sd) * 0.15)
          if not best_score or score > best_score then best, best_score = task, score end
        end
      end
    end
  end
  return best
end

local function source_key(entity)
  if not valid(entity) then return nil end
  return tostring(entity.unit_number or (tostring(entity.name) .. ":" .. tostring(math.floor(entity.position.x*10)) .. ":" .. tostring(math.floor(entity.position.y*10))))
end

local function box_record_table(pair, kind)
  local r = M.root()
  local key = tostring(station_unit(pair) or "?")
  local root = kind == "waste" and r.waste_boxes or r.retention_boxes
  root[key] = root[key] or {}
  return root[key]
end

local function has_box_tag(pair, entity, kind)
  local bucket = box_record_table(pair, kind)
  local k = source_key(entity)
  return k and bucket[k] ~= nil
end

local function remember_box(pair, entity, kind, reason)
  if not (valid_pair(pair) and valid(entity)) then return end
  local bucket = box_record_table(pair, kind)
  local k = source_key(entity)
  if k then bucket[k] = { entity=entity, unit=entity.unit_number, name=entity.name, x=entity.position.x, y=entity.position.y, tick=now(), reason=tostring(reason or "identified") } end
end

local function container_inventory(e)
  return inventory(e, defines.inventory.chest) or inventory(e, defines.inventory.car_trunk) or inventory(e, defines.inventory.spider_trunk)
end

local function is_container_like(e)
  return valid(e) and (e.type == "container" or e.type == "logistic-container" or e.type == "car" or e.type == "spider-vehicle")
end

local function container_has_automation(e)
  local automated = has_adjacent_automation(e)
  return automated
end

local function box_can_accept(e, item, count)
  local inv = container_inventory(e)
  return inv and can_insert(inv, item, count or 1), inv
end

local function find_box(pair, item, count, kind)
  if not valid_pair(pair) then return nil, nil, "invalid" end
  count = math.max(1, tonumber(count) or 1)
  local bucket = box_record_table(pair, kind)
  for k, rec in pairs(bucket) do
    local e = rec and rec.entity
    if valid(e) then
      local ok, inv = box_can_accept(e, item, count)
      if ok then return e, inv, "remembered-" .. tostring(kind) end
    else
      bucket[k] = nil
    end
  end
  local radius = math.max(8, tonumber(pair.radius) or M.service_radius)
  local ents = routed_find(pair.station.surface, { position=pair.station.position, radius=radius, force=pair.station.force, type={"container","logistic-container","car","spider-vehicle"}, limit=96 }, "machine-container", "machine-container:" .. tostring(pair.station.surface.index) .. ":" .. tostring(pair.station.force.index) .. ":" .. tostring(station_unit(pair) or "?") .. ":" .. tostring(kind or "box"), 60 * 5)
  local best, best_inv, best_score = nil, nil, nil
  for _, e in pairs(ents) do
    if is_container_like(e) and e ~= pair.station and not container_has_automation(e) then
      local ok, inv = box_can_accept(e, item, count)
      if ok then
        local score = -dist_sq(e.position, pair.station.position)
        if kind == "waste" then
          local waste_count = count_inv(inv, "mechanical-detritus") + count_inv(inv, "scrap")
          if waste_count > 0 then score = score + 100000 end
        else
          local waste_count = count_inv(inv, "mechanical-detritus") + count_inv(inv, "scrap")
          if waste_count > 0 then score = score - 100000 end
        end
        if not best_score or score > best_score then best, best_inv, best_score = e, inv, score end
      end
    end
  end
  if best then
    remember_box(pair, best, kind, "auto-tag-0528")
    return best, best_inv, "auto-tagged-" .. tostring(kind)
  end
  if kind ~= "waste" then
    local inv = inventory(pair.station, defines.inventory.chest)
    if inv and can_insert(inv, item, count) then return pair.station, inv, "station-retention" end
  end
  return nil, nil, "no-box"
end

local function request_move(pair, target, reason, radius)
  if not (valid_pair(pair) and valid(target)) then return false end
  if type(_G.tech_priests_request_movement_0418) == "function" then
    local ok, res = pcall(_G.tech_priests_request_movement_0418, pair, target.position, reason or "machine-logistics-0528", { owner="machine-logistics-0528", priority=M.move_priority, ttl=M.move_ttl, radius=radius or 1.25, distraction=defines and defines.distraction and defines.distraction.none or nil })
    if ok and res ~= false then return true end
  end
  return false
end

local function begin_task(pair, task)
  if not (valid_pair(pair) and task and valid(task.machine)) then return false, "invalid-task" end
  if task.action == "request-ingredient" or task.action == "request-fuel" then
    local fulfill = task.action == "request-fuel" and "supply-fuel" or "supply-ingredient"
    pair.active_supply_request = { item=task.item, count=task.count or 1, source="machine-logistics-0528", purpose=fulfill, machine_unit=task.machine.unit_number, machine_name=task.machine.name, tick=now() }
    pair.logistic_requested_item = { item=task.item, count=task.count or 1, source="machine-logistics-0528", purpose=fulfill }
    pair.machine_logistics_0528 = { phase="waiting-known-source-fetch", action=task.action, fulfill_action=fulfill, item=task.item, count=task.count or 1, machine=task.machine, machine_unit=task.machine.unit_number, machine_name=task.machine.name, tick=now() }
    record(pair, "machine-need-handoff", tostring(task.item) .. " for " .. machine_label(task.machine) .. " purpose=" .. tostring(fulfill))
    return false, "handoff-to-known-source-fetch"
  end
  pair.machine_logistics_0528 = {
    phase = "move-to-machine",
    action = task.action,
    item = task.item,
    count = math.max(1, math.min(M.max_transfer_per_trip, tonumber(task.count) or 1)),
    kind = task.kind,
    machine = task.machine,
    machine_unit = task.machine.unit_number,
    machine_name = task.machine.name,
    source_inv = task.inv,
    started_tick = now(),
    tick = now(),
  }
  pair.mode = "machine-logistics-fulfillment"
  record(pair, "begin-machine-task", tostring(task.action) .. " " .. tostring(task.item) .. " x" .. tostring(task.count or 1) .. " at " .. machine_label(task.machine))
  return true, "began-machine-logistics"
end

local function deposit_carried(pair, task)
  local carried = task and task.carried
  if type(carried) ~= "table" or not carried.item or (tonumber(carried.count) or 0) <= 0 then return false, "no-carried" end
  local kind = carried.kind == "waste" and "waste" or "retention"
  local box, inv, why = find_box(pair, carried.item, carried.count, kind)
  if not (valid(box) and inv and inv.valid) then return false, why or "no-box" end
  if dist_sq(pair.priest.position, box.position) > M.storage_reach_sq then
    task.phase = "move-to-storage"
    task.storage = box
    task.storage_kind = kind
    task.storage_unit = box.unit_number
    local moved = request_move(pair, box, kind == "waste" and "waste-box-deposit-0528" or "retention-box-deposit-0528", 1.25)
    if not moved then
      record(pair, "movement-request-failed-0528", tostring(kind) .. " " .. tostring(carried.item) .. " x" .. tostring(carried.count) .. " -> " .. machine_label(box))
      return false, "movement-request-failed"
    end
    record(pair, "move-to-storage", tostring(kind) .. " " .. tostring(carried.item) .. " x" .. tostring(carried.count) .. " -> " .. machine_label(box))
    return true, "moving-to-storage"
  end
  local inserted = insert_inv(inv, carried.item, carried.count)
  if inserted > 0 then
    record(pair, kind == "waste" and "waste-deposited" or "retention-deposited", tostring(carried.item) .. " x" .. tostring(inserted) .. " -> " .. machine_label(box))
    if inserted < carried.count then
      carried.count = carried.count - inserted
      return true, "partial-storage-deposit"
    end
    pair.machine_logistics_0528 = { phase="complete", action="clear-output", item=carried.item, count=inserted, storage=box, storage_kind=kind, tick=now() }
    return true, "machine-output-deposited"
  end
  return false, "insert-failed"
end

local function continue_task(pair)
  local task = pair and pair.machine_logistics_0528 or nil
  if type(task) ~= "table" then return false, "no-active-machine-task" end
  if task.phase == "complete" then pair.machine_logistics_0528 = nil; return false, "complete-cleared" end
  local machine = task.machine
  if not valid(machine) then pair.machine_logistics_0528 = nil; return false, "machine-invalid" end
  if task.phase == "waiting-known-source-fetch" then
    if station_count(pair, task.item) >= math.max(1, tonumber(task.count) or 1) then
      task.phase = "move-to-machine"
      task.action = task.fulfill_action or "supply-ingredient"
      record(pair, "machine-need-now-stocked", tostring(task.item) .. " for " .. machine_label(machine) .. " action=" .. tostring(task.action))
      return true, "known-source-fetched-now-supply"
    end
    return false, "waiting-known-source-fetch"
  end
  if task.phase == "move-to-storage" then return deposit_carried(pair, task) end
  if task.phase == "move-to-machine" then
    if dist_sq(pair.priest.position, machine.position) > M.machine_reach_sq then
      local moved = request_move(pair, machine, "machine-service-0528", 1.25)
      if not moved then
        record(pair, "movement-request-failed-0528", "machine-service " .. machine_label(machine))
        return false, "movement-request-failed"
      end
      return true, "moving-to-machine"
    end
    if task.action == "clear-output" then
      local inv = task.source_inv
      if not (inv and inv.valid) then inv = machine_output_inventory(machine) or machine_input_inventory(machine) end
      if not (inv and inv.valid) then pair.machine_logistics_0528=nil; return false, "no-machine-inventory" end
      local want = math.max(1, math.min(M.max_transfer_per_trip, tonumber(task.count) or 1, count_inv(inv, task.item)))
      if want <= 0 then pair.machine_logistics_0528=nil; return false, "nothing-to-clear" end
      local removed = remove_inv(inv, task.item, want)
      if removed <= 0 then pair.machine_logistics_0528=nil; return false, "remove-output-failed" end
      task.carried = { item=task.item, count=removed, kind=task.kind == "waste" and "waste" or "retention" }
      task.phase = "move-to-storage"
      record(pair, "machine-output-cleared", tostring(task.item) .. " x" .. tostring(removed) .. " from " .. machine_label(machine))
      return deposit_carried(pair, task)
    elseif task.action == "supply-fuel" then
      local fuel = machine_fuel_inventory(machine)
      if not (fuel and fuel.valid) then pair.machine_logistics_0528=nil; return false, "no-fuel-inventory" end
      local removed = remove_from_station(pair, task.item, task.count)
      if removed <= 0 then pair.machine_logistics_0528=nil; return false, "no-station-fuel" end
      local inserted = insert_inv(fuel, task.item, removed)
      if inserted < removed then
        -- Return leftovers to station if possible; the station-bound inventory
        -- steward can route overflow to stash if needed.
        if type(_G.tech_priests_safe_deposit_item) == "function" then pcall(_G.tech_priests_safe_deposit_item, pair, task.item, removed-inserted, "machine-logistics-fuel-leftover-0528") end
      end
      pair.machine_logistics_0528 = { phase="complete", action=task.action, item=task.item, count=inserted, machine=machine, tick=now() }
      record(pair, "machine-fuel-supplied", tostring(task.item) .. " x" .. tostring(inserted) .. " -> " .. machine_label(machine))
      return inserted > 0, inserted > 0 and "machine-fuel-supplied" or "fuel-insert-failed"
    elseif task.action == "supply-ingredient" then
      local inp = machine_input_inventory(machine)
      if not (inp and inp.valid) then pair.machine_logistics_0528=nil; return false, "no-input-inventory" end
      local removed = remove_from_station(pair, task.item, task.count)
      if removed <= 0 then pair.machine_logistics_0528=nil; return false, "no-station-ingredient" end
      local inserted = insert_inv(inp, task.item, removed)
      if inserted < removed then
        if type(_G.tech_priests_safe_deposit_item) == "function" then pcall(_G.tech_priests_safe_deposit_item, pair, task.item, removed-inserted, "machine-logistics-input-leftover-0528") end
      end
      pair.machine_logistics_0528 = { phase="complete", action=task.action, item=task.item, count=inserted, machine=machine, tick=now() }
      record(pair, "machine-ingredient-supplied", tostring(task.item) .. " x" .. tostring(inserted) .. " -> " .. machine_label(machine))
      return inserted > 0, inserted > 0 and "machine-ingredient-supplied" or "ingredient-insert-failed"
    end
  end
  return false, "unknown-phase"
end

function M.service_pair(pair, reason)
  local r = M.root()
  if r.enabled == false or not valid_pair(pair) then return false, "disabled-or-invalid" end
  if valid(pair.combat_target) then return false, "combat-priority" end
  local active = pair.machine_logistics_0528
  if type(active) == "table" and active.phase and active.phase ~= "complete" then return continue_task(pair) end
  local key = tostring(station_unit(pair) or "?")
  if (r.cooldowns[key] or 0) > now() then return false, "cooldown" end
  local task = best_machine_task(pair)
  if not task then r.cooldowns[key] = now() + M.cooldown_ticks; return false, "no-machine-task" end
  return begin_task(pair, task)
end

local function patch_dispatcher()
  local okD, D = pcall(require, "scripts.core.single_dispatcher_0510")
  if not (okD and D and type(D.service_pair) == "function") or D.TECH_PRIESTS_0528_MACHINE_LOGISTICS_WRAPPED then return false end
  D.TECH_PRIESTS_0528_MACHINE_LOGISTICS_WRAPPED = true
  D.TECH_PRIESTS_0528_PRE_SERVICE_PAIR = D.service_pair
  D.service_pair = function(pair, reason, ...)
    local r = M.root()
    if r.enabled ~= false and r.dispatcher_priority ~= false and valid_pair(pair) then
      local acted, why = M.service_pair(pair, reason or "dispatcher-0528")
      if acted then
        pair.dispatcher_0510 = pair.dispatcher_0510 or {}
        pair.dispatcher_0510.tick = now()
        pair.dispatcher_0510.action = "machine-logistics"
        pair.dispatcher_0510.family = "logistics"
        pair.dispatcher_0510.reason = tostring(why or "machine-logistics-0528")
        pair.dispatcher_0510.acted = true
        pair.dispatcher_0510.result = tostring(why or "machine-logistics-0528")
        if type(_G.tech_priests_0507_action_claim) == "function" then pcall(_G.tech_priests_0507_action_claim, pair, "machine-logistics", "logistics_machine_fulfillment_0528", why or "machine-logistics") end
        return true, why
      end
    end
    return D.TECH_PRIESTS_0528_PRE_SERVICE_PAIR(pair, reason, ...)
  end
  return true
end

local function selected_pair(player)
  if _G.selected_pair_for_player then local ok,p=pcall(_G.selected_pair_for_player, player); if ok and p then return p end end
  local selected = player and player.selected
  if selected and selected.valid and storage and storage.tech_priests then
    local tp = storage.tech_priests
    return (tp.pairs_by_station and tp.pairs_by_station[selected.unit_number]) or (tp.pairs_by_priest and tp.pairs_by_priest[selected.unit_number])
  end
  return nil
end

function M.describe_pair(pair)
  if not valid_pair(pair) then return "invalid pair" end
  local task = pair.machine_logistics_0528 or {}
  local candidate = best_machine_task(pair)
  return "enabled=" .. tostring(M.root().enabled)
    .. " task_phase=" .. tostring(task.phase or "none")
    .. " task_action=" .. tostring(task.action or "none")
    .. " task_item=" .. tostring(task.item or "none")
    .. " candidate=" .. tostring(candidate and (candidate.action .. ":" .. tostring(candidate.item) .. "@" .. machine_label(candidate.machine)) or "none")
end

local function install_command()
  if not commands then return end
  pcall(function() commands.remove_command("tp-machine-logistics-0528") end)
  commands.add_command("tp-machine-logistics-0528", "Tech Priests 0.1.528: non-automated machine logistics fulfillment diagnostics. Params: all/on/off/auto-on/auto-off", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local param = lower(event and event.parameter or "status")
    local r = M.root()
    if param == "on" then r.enabled = true end
    if param == "off" then r.enabled = false end
    if param == "auto-on" then r.service_unautomated_only = true end
    if param == "auto-off" then r.service_unautomated_only = false end
    if param == "all" then for _,pair in pairs(pair_map()) do if valid_pair(pair) then pcall(M.service_pair, pair, "manual-all") end end end
    local pair = player and selected_pair(player) or nil
    local msg = "[tp-machine-logistics-0528] enabled=" .. tostring(r.enabled) .. " unautomated_only=" .. tostring(r.service_unautomated_only)
      .. " output=" .. safe(r.stats["machine-output-cleared"] or 0)
      .. " fuel=" .. safe(r.stats["machine-fuel-supplied"] or 0)
      .. " input=" .. safe(r.stats["machine-ingredient-supplied"] or 0)
      .. " handoff=" .. safe(r.stats["machine-need-handoff"] or 0)
    if pair then msg = msg .. "\n" .. M.describe_pair(pair) end
    if player and player.valid then player.print(msg) elseif game and game.print then game.print(msg) end
  end)
end

local function wrap_diagnostics()
  local diag = rawget(_G, "TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468") or rawget(_G, "TechPriestsEmergencyDiagnostics0468")
  if not (diag and type(diag.pair_dump_lines) == "function") or diag.machine_logistics_0528_wrapped then return false end
  local prev = diag.pair_dump_lines
  diag.machine_logistics_0528_wrapped = true
  diag.pair_dump_lines = function(...)
    local lines = prev(...)
    lines = type(lines) == "table" and lines or {}
    local r = M.root()
    lines[#lines+1] = "PAIR-DUMP-0468 MACHINE-LOGISTICS-0528 BEGIN enabled=" .. tostring(r.enabled) .. " unautomated_only=" .. tostring(r.service_unautomated_only)
      .. " output=" .. safe(r.stats["machine-output-cleared"] or 0)
      .. " fuel=" .. safe(r.stats["machine-fuel-supplied"] or 0)
      .. " input=" .. safe(r.stats["machine-ingredient-supplied"] or 0)
      .. " handoff=" .. safe(r.stats["machine-need-handoff"] or 0)
    for _, pair in pairs(pair_map()) do if valid_pair(pair) then lines[#lines+1] = "PAIR-DUMP-0468 machine-logistics[" .. safe(station_unit(pair)) .. "] " .. M.describe_pair(pair) end end
    for i=math.max(1,#r.recent-8),#r.recent do local ev=r.recent[i]; if ev then lines[#lines+1] = "PAIR-DUMP-0468 machine-logistics.recent[" .. tostring(i) .. "] tick=" .. safe(ev.tick) .. " event=" .. safe(ev.event) .. " station=" .. safe(ev.station) .. " priest=" .. safe(ev.priest) .. " " .. safe(ev.detail) end end
    lines[#lines+1] = "PAIR-DUMP-0468 MACHINE-LOGISTICS-0528 END"
    return lines
  end
  return true
end

function M.install()
  M.root()
  patch_dispatcher()
  wrap_diagnostics()
  install_command()
  _G.TECH_PRIESTS_MACHINE_LOGISTICS_FULFILLMENT_0528 = M
  if log then log("[Tech-Priests 0.1.628] dispatcher-owned machine logistics fulfillment loaded; unautomated assemblers/furnaces can request and receive fuel/ingredients physically") end
  return true
end

return M
