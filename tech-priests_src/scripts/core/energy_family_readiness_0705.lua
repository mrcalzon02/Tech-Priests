-- scripts/core/energy_family_readiness_0705.lua
-- Tech Priests 0.1.674-dev recovery.
-- Canonical read-only energy readiness doctrine. It owns bounded inspection only:
-- fuel eligibility, burnt-result capacity, fluid/electric/heat prerequisites, and
-- connected item-automation ownership. It never moves priests or transfers items.

local M = {
  version = "0.1.674-dev",
  storage_key = "energy_family_readiness_0705",
  scan_interval = 179,
  machine_cache_ticks = 60 * 4,
  service_radius_floor = 28,
  service_radius_cap = 96,
  max_scan_entities = 160,
  max_pairs_per_scan = 8,
  minimum_fuel_items = 2,
  minimum_input_fluid = 0.001,
  minimum_output_free = 0.001,
}

local ENERGY_TYPES = {
  "boiler", "burner-generator", "reactor", "fusion-reactor",
  "generator", "fusion-generator",
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

local function entity_key(entity)
  if not valid(entity) then return nil end
  if entity.unit_number then return "unit:" .. tostring(entity.unit_number) end
  local position = entity.position or { x = 0, y = 0 }
  return tostring(entity.surface and entity.surface.index or "?") .. ":"
    .. tostring(entity.name) .. ":" .. tostring(math.floor((position.x or 0) * 10))
    .. ":" .. tostring(math.floor((position.y or 0) * 10))
end

function M.root()
  storage.tech_priests = storage.tech_priests or {}
  local state = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    read_only = true,
    fusion_heat_semantics_integrated = true,
    item_automation_ownership_integrated = true,
    corrected_diagnostics_integrated = true,
    stats = {}, recent = {}, scan_due = {}, machine_due = {}, reports = {}, cursor = 0,
  }
  storage.tech_priests[M.storage_key] = state
  state.version = M.version
  if state.enabled == nil then state.enabled = true end
  if state.read_only == nil then state.read_only = true end
  if state.fusion_heat_semantics_integrated == nil then state.fusion_heat_semantics_integrated = true end
  if state.item_automation_ownership_integrated == nil then state.item_automation_ownership_integrated = true end
  if state.corrected_diagnostics_integrated == nil then state.corrected_diagnostics_integrated = true end
  state.stats = state.stats or {}; state.recent = state.recent or {}
  state.scan_due = state.scan_due or {}; state.machine_due = state.machine_due or {}
  state.reports = state.reports or {}; state.cursor = tonumber(state.cursor) or 0
  return state
end
local function stat(name, amount)
  local state = M.root()
  state.stats[name] = (tonumber(state.stats[name]) or 0) + (tonumber(amount) or 1)
end
local function record(pair, action, detail)
  local state = M.root(); stat(action)
  state.recent[#state.recent + 1] = {
    tick = now(), action = tostring(action or "event"),
    station = safe(station_unit(pair)), detail = tostring(detail or ""),
  }
  while #state.recent > 160 do table.remove(state.recent, 1) end
end

local function inventory_count(inv)
  local total = 0
  if not (inv and inv.valid) then return total end
  local ok, values = pcall(function() return inv.get_contents() end)
  if not (ok and type(values) == "table") then return total end
  for _, value in pairs(values) do
    total = total + (type(value) == "table"
      and (tonumber(value.count or value.amount or value[2]) or 0)
      or (tonumber(value) or 0))
  end
  return total
end
local function empty_slots(inv)
  if not (inv and inv.valid) then return 0 end
  local ok, count = pcall(function() return inv.count_empty_stacks() end)
  return ok and (tonumber(count) or 0) or 0
end
local function fuel_inventory(entity)
  if not valid(entity) then return nil end
  local inv
  if entity.get_fuel_inventory then pcall(function() inv = entity.get_fuel_inventory() end) end
  if inv and inv.valid then return inv end
  local burner; pcall(function() burner = entity.burner end)
  if burner then pcall(function() inv = burner.inventory end) end
  return inv and inv.valid and inv or nil
end
local function burnt_inventory(entity)
  if not valid(entity) then return nil end
  local inv
  if entity.get_burnt_result_inventory then
    pcall(function() inv = entity.get_burnt_result_inventory() end)
  end
  if inv and inv.valid then return inv end
  local burner; pcall(function() burner = entity.burner end)
  if burner then pcall(function() inv = burner.burnt_result_inventory end) end
  return inv and inv.valid and inv or nil
end
local function burner_state(entity)
  local burner; pcall(function() burner = entity.burner end)
  if not burner then return nil end
  local current, remaining, heat
  pcall(function() current = burner.currently_burning end)
  pcall(function() remaining = tonumber(burner.remaining_burning_fuel) or 0 end)
  pcall(function() heat = tonumber(burner.heat) or 0 end)
  return {
    currently_burning = type(current) == "table" and current.name
      or type(current) == "string" and current or nil,
    remaining_burning_fuel = remaining or 0, heat = heat or 0,
  }
end

local function fluidbox(entity)
  if not valid(entity) then return nil end
  local ok, box = pcall(function() return entity.fluidbox end)
  return ok and box and box.valid and box or nil
end
local function prototype_records(box, index)
  local out = {}
  if not (box and box.valid and index) then return out end
  local ok, value = pcall(function() return box.get_prototype(index) end)
  if not ok or value == nil then return out end
  if type(value) == "table" and value.object_name == nil then
    for _, prototype in pairs(value) do if prototype then out[#out + 1] = prototype end end
  else out[#out + 1] = value end
  return out
end
local function production_type(box, index)
  local input, output = false, false
  for _, prototype in ipairs(prototype_records(box, index)) do
    local production; pcall(function() production = prototype.production_type end)
    production = lower(production)
    if production == "input" or production == "input-output" then input = true end
    if production == "output" or production == "input-output" then output = true end
  end
  return input, output
end
local function filter_name(box, index)
  local filter; pcall(function() filter = box.get_filter(index) end)
  if type(filter) == "table" and filter.name then return filter.name end
  local locked; pcall(function() locked = box.get_locked_fluid(index) end)
  if type(locked) == "string" and locked ~= "" then return locked end
  for _, prototype in ipairs(prototype_records(box, index)) do
    local prototype_filter; pcall(function() prototype_filter = prototype.filter end)
    if prototype_filter then
      local name; pcall(function() name = prototype_filter.name end)
      if type(name) == "string" and name ~= "" then return name end
    end
  end
  return nil
end
local function segment_contents(box, index)
  local values = {}
  if box and box.valid then pcall(function() values = box.get_fluid_segment_contents(index) or {} end) end
  return type(values) == "table" and values or {}
end
local function local_fluid(box, index)
  local fluid; if box and box.valid then pcall(function() fluid = box[index] end) end
  if type(fluid) == "table" and fluid.name and (tonumber(fluid.amount) or 0) > 0 then
    return { name = fluid.name, amount = tonumber(fluid.amount) or 0,
      temperature = tonumber(fluid.temperature) }
  end
  return nil
end
local function segment_capacity(box, index)
  local capacity = 0
  if box and box.valid then pcall(function() capacity = tonumber(box.get_capacity(index)) or 0 end) end
  return capacity
end
local function connection_count(box, index)
  local count = 0; if not (box and box.valid) then return count end
  local connections = {}; pcall(function() connections = box.get_pipe_connections(index) or {} end)
  for _, connection in pairs(connections or {}) do
    if type(connection) == "table" then
      local owner; if connection.target then pcall(function() owner = connection.target.owner end) end
      if connection.target or valid(owner) then count = count + 1 end
    end
  end
  if count == 0 then
    local connected = {}; pcall(function() connected = box.get_connections(index) or {} end)
    for _, other in pairs(connected or {}) do if other and other.valid then count = count + 1 end end
  end
  return count
end
local function sum_contents(values)
  local total = 0; for _, amount in pairs(values or {}) do total = total + (tonumber(amount) or 0) end
  return total
end
local function fluid_records(entity)
  local out = {}; local box = fluidbox(entity); if not box then return out end
  for index = 1, #box do
    local input, output = production_type(box, index)
    local values = segment_contents(box, index); local local_record = local_fluid(box, index)
    if next(values) == nil and local_record then values[local_record.name] = local_record.amount end
    local capacity = segment_capacity(box, index); local occupied = sum_contents(values)
    out[#out + 1] = { index = index, input = input, output = output,
      filter = filter_name(box, index), contents = values, local_fluid = local_record,
      connections = connection_count(box, index), capacity = capacity,
      occupied = occupied, free = math.max(0, capacity - occupied) }
  end
  return out
end
local function fluid_prerequisites(entity)
  local records = fluid_records(entity)
  if #records == 0 then return { has_fluid = false, input_ready = true,
    output_ready = true, records = records } end
  local has_input, has_output, input_ready, output_ready = false, false, true, true
  local blockers = {}
  for _, rec in ipairs(records) do
    if rec.input then
      has_input = true; local total = sum_contents(rec.contents)
      if rec.connections <= 0 then input_ready = false; blockers[#blockers + 1] = "input-unconnected:" .. rec.index
      elseif total < M.minimum_input_fluid then input_ready = false; blockers[#blockers + 1] = "input-empty:" .. rec.index end
    end
    if rec.output then
      has_output = true
      if rec.connections <= 0 then output_ready = false; blockers[#blockers + 1] = "output-unconnected:" .. rec.index
      elseif rec.free < M.minimum_output_free then output_ready = false; blockers[#blockers + 1] = "output-full:" .. rec.index end
    end
  end
  return { has_fluid = true, has_input = has_input, has_output = has_output,
    input_ready = input_ready, output_ready = output_ready,
    records = records, blockers = blockers }
end
local function electric_ready(entity)
  local relevant = entity.type == "burner-generator" or entity.type == "generator"
    or entity.type == "fusion-generator" or entity.type == "fusion-reactor"
  if not relevant then return true, nil end
  local connected = false
  if entity.is_connected_to_electric_network then
    pcall(function() connected = entity.is_connected_to_electric_network() end)
  end
  local network_id; pcall(function() network_id = entity.electric_network_id end)
  return connected == true or network_id ~= nil, network_id
end
local function heat_ready(entity)
  -- Fusion reactors are not ordinary heat-buffer reactors.
  if entity.type ~= "reactor" then return true, 0 end
  local neighbours = {}; pcall(function() neighbours = entity.heat_neighbours or {} end)
  local count = 0; for _, neighbour in pairs(neighbours or {}) do if valid(neighbour) then count = count + 1 end end
  return count > 0, count
end
local function position_inside_box(position, box, padding)
  if not (position and box and box.left_top and box.right_bottom) then return false end
  padding = tonumber(padding) or 0.25
  return position.x >= box.left_top.x - padding and position.x <= box.right_bottom.x + padding
    and position.y >= box.left_top.y - padding and position.y <= box.right_bottom.y + padding
end
function M.connected_item_automation(entity)
  if not valid(entity) then return false, {} end
  local box; pcall(function() box = entity.bounding_box end)
  local position = entity.position; local padding = 3
  local area = box and {{box.left_top.x-padding,box.left_top.y-padding},{box.right_bottom.x+padding,box.right_bottom.y+padding}}
    or {{position.x-padding,position.y-padding},{position.x+padding,position.y+padding}}
  local nearby = {}; pcall(function() nearby = entity.surface.find_entities_filtered({
    area = area, force = entity.force, type = {"inserter","loader","loader-1x1"}, limit = 64 }) or {} end)
  local reasons = {}
  for _, candidate in pairs(nearby) do
    if candidate.type == "inserter" then
      local pickup, drop; pcall(function() pickup = candidate.pickup_target end); pcall(function() drop = candidate.drop_target end)
      if pickup == entity or drop == entity then reasons[#reasons + 1] = "connected-inserter:" .. safe(candidate.unit_number)
      else
        local pickup_position, drop_position; pcall(function() pickup_position = candidate.pickup_position end); pcall(function() drop_position = candidate.drop_position end)
        if position_inside_box(pickup_position, box, 0.25) or position_inside_box(drop_position, box, 0.25) then
          reasons[#reasons + 1] = "touching-inserter:" .. safe(candidate.unit_number)
        end
      end
    else
      local container; pcall(function() container = candidate.loader_container end)
      if container == entity or math.sqrt(dist_sq(candidate.position, entity.position)) <= 1.65 then
        reasons[#reasons + 1] = "connected-loader:" .. safe(candidate.unit_number)
      end
    end
  end
  return #reasons > 0, reasons
end
local function entity_status(entity) local value; pcall(function() value = entity.status end); return value end
local function entity_temperature(entity) local value; pcall(function() value = tonumber(entity.temperature) end); return value end
local function energy_generated(entity) local value; pcall(function() value = tonumber(entity.energy_generated_last_tick) end); return value end
local function neighbour_bonus(entity) local value; pcall(function() value = tonumber(entity.neighbour_bonus) end); return value end

function M.inspect_entity(pair, entity, force)
  if not (valid_pair(pair) and valid(entity)) then return nil, "invalid" end
  local key = entity_key(entity); local state = M.root()
  if not force and key and (tonumber(state.machine_due[key]) or 0) > now() then return state.reports[key], "cached" end
  if key then state.machine_due[key] = now() + M.machine_cache_ticks end
  local fuel_inv, burnt_inv, burner = fuel_inventory(entity), burnt_inventory(entity), burner_state(entity)
  local fuel_count, burnt_count = inventory_count(fuel_inv), inventory_count(burnt_inv)
  local burnt_ready = not burnt_inv or empty_slots(burnt_inv) > 0
  local fluid = fluid_prerequisites(entity); local electric, network_id = electric_ready(entity)
  local heat, heat_count = heat_ready(entity); local automated, reasons = M.connected_item_automation(entity)
  local has_item_fuel = fuel_inv ~= nil; local readiness_state, severity
  if not has_item_fuel then readiness_state,severity="monitor-only","monitor"
  elseif automated then readiness_state,severity="external-item-automation-owned","monitor"
  elseif not burnt_ready then readiness_state,severity="burnt-result-blocked","blocked"
  elseif not electric then readiness_state,severity="electric-network-missing","blocked"
  elseif not heat then readiness_state,severity="heat-network-missing","blocked"
  elseif not fluid.input_ready then readiness_state,severity="input-fluid-not-ready","blocked"
  elseif not fluid.output_ready then readiness_state,severity="output-fluid-not-ready","blocked"
  elseif fuel_count >= M.minimum_fuel_items or (burner and burner.remaining_burning_fuel > 0) then readiness_state,severity="fuel-sufficient","ready"
  else readiness_state,severity="fuel-service-eligible","eligible" end
  local report = { version=M.version,tick=now(),read_only=true,entity=entity,
    entity_name=entity.name,entity_unit=entity.unit_number,entity_type=entity.type,
    station_unit=station_unit(pair),state=readiness_state,severity=severity,
    has_item_fuel=has_item_fuel,fuel_inventory=fuel_inv,fuel_count=fuel_count,
    burner=burner,burnt_inventory=burnt_inv,burnt_count=burnt_count,burnt_ready=burnt_ready,
    fluid=fluid,electric_ready=electric,electric_network_id=network_id,
    heat_ready=heat,heat_neighbour_count=heat_count,
    connected_item_automation=automated,automation_reasons=reasons,
    fusion_heat_requirement_0727=entity.type=="fusion-reactor" and false or nil,
    fusion_readiness_basis_0727=entity.type=="fusion-reactor" and "electrical-item-fluid-neighbour-connectable" or nil,
    status=entity_status(entity),temperature=entity_temperature(entity),
    energy_generated_last_tick=energy_generated(entity),neighbour_bonus=neighbour_bonus(entity) }
  if key then state.reports[key] = report end
  stat("entities-inspected"); stat("state_" .. readiness_state)
  return report, "inspected"
end
local function service_radius(pair)
  local radius = tonumber(pair and pair.radius) or M.service_radius_floor
  if valid_pair(pair) and type(_G.get_station_operating_radius) == "function" then
    local ok, value = pcall(_G.get_station_operating_radius, pair.station); if ok and tonumber(value) then radius = tonumber(value) end
  end
  return math.max(8, math.min(math.max(radius,M.service_radius_floor),M.service_radius_cap))
end
local function routed_find(surface,filters,category,key,ttl)
  local scanner=rawget(_G,"TechPriestsScanRouting0610"); if not scanner then local ok,module=pcall(require,"scripts.core.scan_routing_0610"); if ok then scanner=module end end
  if scanner and type(scanner.find_entities)=="function" then local entities=select(1,scanner.find_entities(surface,filters,{category=category,negative_key=key,negative_ttl=ttl or 60*4})); return entities or {} end
  local ok,entities=pcall(function() return surface.find_entities_filtered(filters) end); return ok and entities or {}
end
function M.scan_pair(pair, force)
  if M.root().enabled==false or not valid_pair(pair) then return {processed=0,acted=0,failed=not valid_pair(pair) and 1 or 0,detail="disabled-or-invalid"} end
  local key=tostring(station_unit(pair) or "?"); local state=M.root()
  if not force and (tonumber(state.scan_due[key]) or 0)>now() then return {processed=0,acted=0,detail="cooldown"} end
  state.scan_due[key]=now()+M.scan_interval; local radius=service_radius(pair); local p=pair.station.position
  local entities=routed_find(pair.station.surface,{area={{p.x-radius,p.y-radius},{p.x+radius,p.y+radius}},force=pair.station.force,type=ENERGY_TYPES,limit=M.max_scan_entities},"energy-family-readiness","energy-family-readiness:"..tostring(pair.station.surface.index)..":"..tostring(pair.station.force.index)..":"..key,60*4)
  local reports,eligible,worst={},0,nil
  for _,entity in pairs(entities) do local report=M.inspect_entity(pair,entity,false); if report then reports[#reports+1]=report;if report.state=="fuel-service-eligible" then eligible=eligible+1 end;if not worst or report.severity=="blocked" or (report.severity=="eligible" and worst.severity~="blocked") then worst=report end end end
  pair.energy_family_reports_0705=reports;pair.energy_family_summary_0705={version=M.version,tick=now(),inspected=#reports,eligible=eligible,worst_state=worst and worst.state or "none",worst_entity=worst and worst.entity_name or nil,read_only=true}
  stat("pair-scans");stat("pair-entities-inspected",#reports);stat("eligible-found",eligible)
  return {processed=#reports,acted=0,failed=0,detail="inspected="..#reports.." eligible="..eligible}
end
local function scan_pairs(budget)
  local state=M.root();if state.enabled==false then return{processed=0,acted=0,detail="disabled"}end
  local list={};for key,pair in pairs(pair_map())do if valid_pair(pair)then list[#list+1]={key=tostring(key),pair=pair}end end;table.sort(list,function(a,b)return a.key<b.key end);if #list==0 then return{processed=0,acted=0,detail="no-pairs"}end
  local limit=math.max(1,math.min(#list,math.floor(tonumber(budget)or M.max_pairs_per_scan)));local start=state.cursor%#list+1;local processed,failed=0,0
  for index=0,limit-1 do local pair=list[((start+index-1)%#list)+1].pair;local ok,result=pcall(M.scan_pair,pair,false);if ok and type(result)=="table"then processed=processed+(tonumber(result.processed)or 0);failed=failed+(tonumber(result.failed)or 0)else failed=failed+1;record(pair,"readiness-scan-error",result)end end
  state.cursor=(start+limit-2)%#list+1;return{processed=processed,acted=0,failed=failed,exhausted=#list>limit,detail="pairs="..limit.." entities="..processed.." failed="..failed}
end
local function patch_diagnostics()
  local diagnostics=rawget(_G,"TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")or rawget(_G,"TechPriestsEmergencyDiagnostics0468");if not(diagnostics and type(diagnostics.pair_dump_lines)=="function")then return false end;if diagnostics.energy_family_readiness_0705_wrapped then return true end
  diagnostics.energy_family_readiness_0705_wrapped=true;local previous=diagnostics.pair_dump_lines;diagnostics.pair_dump_lines=function(...)local lines=previous(...);lines=type(lines)=="table"and lines or{};local state=M.root();local stats=state.stats or{};lines[#lines+1]="PAIR-DUMP-0468 ENERGY-READINESS-0705 enabled="..safe(state.enabled).." read_only=true item_mutations=0 fluid_mutations=0 heat_mutations=0 inspected="..safe(stats["entities-inspected"]or 0).." eligible="..safe(stats["state_fuel-service-eligible"]or 0).." fuel_sufficient="..safe(stats["state_fuel-sufficient"]or 0).." input_fluid_blocked="..safe(stats["state_input-fluid-not-ready"]or 0).." output_fluid_blocked="..safe(stats["state_output-fluid-not-ready"]or 0).." electric_blocked="..safe(stats["state_electric-network-missing"]or 0).." heat_blocked="..safe(stats["state_heat-network-missing"]or 0).." burnt_blocked="..safe(stats["state_burnt-result-blocked"]or 0).." automated="..safe(stats["state_external-item-automation-owned"]or 0).." monitor_only="..safe(stats["state_monitor-only"]or 0).." fusion_heat_semantics=integrated";return lines end;return true
end
function M.install()
  M.root();local broker=rawget(_G,"TechPriestsRuntimeTickBroker0600");if not(broker and type(broker.register_service)=="function")then return false end
  local service=broker.register_service({name="energy_family_readiness_0705",category="discovery",interval=M.scan_interval,priority=75,budget=M.max_pairs_per_scan,note="read-only energy prerequisite and external item-automation inspection",fn=function(_,budget)return scan_pairs(budget)end})
  if not service then return false end;patch_diagnostics();_G.TechPriestsEnergyFamilyReadiness0705=M;_G.tech_priests_energy_family_inspect_0705=M.inspect_entity
  if log then log("[Tech-Priests recovery] canonical read-only energy readiness installed")end;return true
end
return M
