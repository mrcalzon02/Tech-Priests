-- Tech Priests 0.1.672 burner, heat, and generator readiness doctrine.
--
-- Read-only family audit for boilers, burner generators, reactors, fusion
-- reactors, and fluid generators. An empty fuel inventory is not enough to
-- authorize service. The doctrine proves the relevant non-item prerequisites:
-- fluid input/output viability, electrical output connection, heat-network
-- connectivity, and burnt-result capacity. It does not move priests, request
-- fuel, remove items, insert items, mutate fluid, change heat, or alter recipes.

local M = {
  version = "0.1.672",
  storage_key = "energy_family_readiness_0705",
  scan_interval = 60 * 5,
  machine_cache_ticks = 60 * 4,
  service_radius_floor = 28,
  service_radius_cap = 96,
  max_scan_entities = 160,
  minimum_fuel_items = 2,
  minimum_input_fluid = 0.001,
  minimum_output_free = 0.001,
}

local ENERGY_TYPES = {
  "boiler",
  "burner-generator",
  "reactor",
  "fusion-reactor",
  "generator",
  "fusion-generator",
}

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v==nil then return "nil" end local ok,s=pcall(tostring,v); return ok and s or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function valid_pair(pair) return pair and valid(pair.station) and valid(pair.priest) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function dist_sq(a,b) if not (a and b) then return 999999999 end local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end

local function entity_key(entity)
  if not valid(entity) then return nil end
  return entity.unit_number and ("unit:"..tostring(entity.unit_number))
    or (tostring(entity.surface and entity.surface.index or "?")..":"..tostring(entity.name)..":"..tostring(math.floor(entity.position.x*10))..":"..tostring(math.floor(entity.position.y*10)))
end

local function root()
  storage.tech_priests=storage.tech_priests or {}
  local r=storage.tech_priests[M.storage_key] or {version=M.version,enabled=true,read_only=true,stats={},recent={},scan_due={},machine_due={},reports={}}
  storage.tech_priests[M.storage_key]=r
  r.version=M.version
  if r.enabled==nil then r.enabled=true end
  if r.read_only==nil then r.read_only=true end
  r.stats=r.stats or {}; r.recent=r.recent or {}; r.scan_due=r.scan_due or {}; r.machine_due=r.machine_due or {}; r.reports=r.reports or {}
  return r
end
local function stat(name,n) local r=root(); r.stats[name]=(r.stats[name] or 0)+(n or 1) end
local function record(pair,action,detail) local r=root(); stat(action); r.recent[#r.recent+1]={tick=now(),action=tostring(action),station=safe(station_unit(pair)),detail=tostring(detail or "")}; while #r.recent>160 do table.remove(r.recent,1) end end

local function inventory_count(inv)
  local total=0
  if not (inv and inv.valid) then return total end
  local ok,contents=pcall(function() return inv.get_contents() end)
  if ok and type(contents)=="table" then
    for _,value in pairs(contents) do total=total+(type(value)=="table" and (tonumber(value.count or value.amount or value[2]) or 0) or (tonumber(value) or 0)) end
  end
  return total
end
local function empty_slots(inv) if not (inv and inv.valid) then return 0 end local ok,n=pcall(function() return inv.count_empty_stacks() end); return ok and (tonumber(n) or 0) or 0 end

local function fuel_inventory(entity)
  if not valid(entity) then return nil end
  local inv; if entity.get_fuel_inventory then pcall(function() inv=entity.get_fuel_inventory() end) end
  if inv and inv.valid then return inv end
  local burner; pcall(function() burner=entity.burner end)
  if burner then pcall(function() inv=burner.inventory end) end
  return inv and inv.valid and inv or nil
end
local function burnt_inventory(entity)
  if not valid(entity) then return nil end
  local inv; if entity.get_burnt_result_inventory then pcall(function() inv=entity.get_burnt_result_inventory() end) end
  if inv and inv.valid then return inv end
  local burner; pcall(function() burner=entity.burner end)
  if burner then pcall(function() inv=burner.burnt_result_inventory end) end
  return inv and inv.valid and inv or nil
end

local function burner_state(entity)
  local burner; pcall(function() burner=entity.burner end)
  if not burner then return nil end
  local current,remaining,heat
  pcall(function() current=burner.currently_burning end)
  pcall(function() remaining=tonumber(burner.remaining_burning_fuel) or 0 end)
  pcall(function() heat=tonumber(burner.heat) or 0 end)
  local name=type(current)=="table" and current.name or type(current)=="string" and current or nil
  return {currently_burning=name,remaining_burning_fuel=remaining or 0,heat=heat or 0}
end

local function fluidbox(entity)
  if not valid(entity) then return nil end
  local ok,box=pcall(function() return entity.fluidbox end)
  return ok and box and box.valid and box or nil
end
local function prototype_records(box,index)
  local out={}; if not (box and box.valid and index) then return out end
  local ok,value=pcall(function() return box.get_prototype(index) end); if not ok or value==nil then return out end
  if type(value)=="table" and value.object_name==nil then for _,p in pairs(value) do if p then out[#out+1]=p end end else out[#out+1]=value end
  return out
end
local function production_type(box,index)
  local input,output=false,false
  for _,prototype in ipairs(prototype_records(box,index)) do local production; pcall(function() production=prototype.production_type end); production=lower(production); if production=="input" or production=="input-output" then input=true end; if production=="output" or production=="input-output" then output=true end end
  return input,output
end
local function filter_name(box,index)
  local filter; pcall(function() filter=box.get_filter(index) end); if type(filter)=="table" and filter.name then return filter.name end
  local locked; pcall(function() locked=box.get_locked_fluid(index) end); if type(locked)=="string" and locked~="" then return locked end
  for _,prototype in ipairs(prototype_records(box,index)) do local fp; pcall(function() fp=prototype.filter end); if fp then local name; pcall(function() name=fp.name end); if type(name)=="string" and name~="" then return name end end end
  return nil
end
local function segment_contents(box,index)
  local contents={}; if box and box.valid then pcall(function() contents=box.get_fluid_segment_contents(index) or {} end) end
  return type(contents)=="table" and contents or {}
end
local function local_fluid(box,index)
  local fluid; if box and box.valid then pcall(function() fluid=box[index] end) end
  return type(fluid)=="table" and fluid.name and (tonumber(fluid.amount) or 0)>0 and {name=fluid.name,amount=tonumber(fluid.amount) or 0,temperature=tonumber(fluid.temperature)} or nil
end
local function segment_capacity(box,index) local n=0; if box and box.valid then pcall(function() n=tonumber(box.get_capacity(index)) or 0 end) end; return n end
local function connection_count(box,index)
  local count=0; local connections={}; if not (box and box.valid) then return count end
  pcall(function() connections=box.get_pipe_connections(index) or {} end)
  for _,connection in pairs(connections or {}) do if type(connection)=="table" then local owner; if connection.target then pcall(function() owner=connection.target.owner end) end; if connection.target or valid(owner) then count=count+1 end end end
  if count==0 then local connected={}; pcall(function() connected=box.get_connections(index) or {} end); for _,other in pairs(connected or {}) do if other and other.valid then count=count+1 end end end
  return count
end
local function sum_contents(contents) local n=0; for _,amount in pairs(contents or {}) do n=n+(tonumber(amount) or 0) end; return n end

local function fluid_records(entity)
  local out={}; local box=fluidbox(entity); if not box then return out end
  for index=1,#box do
    local input,output=production_type(box,index)
    local contents=segment_contents(box,index); local local_rec=local_fluid(box,index)
    if next(contents)==nil and local_rec then contents[local_rec.name]=local_rec.amount end
    local capacity=segment_capacity(box,index); local occupied=sum_contents(contents)
    out[#out+1]={index=index,input=input,output=output,filter=filter_name(box,index),contents=contents,local_fluid=local_rec,connections=connection_count(box,index),capacity=capacity,occupied=occupied,free=math.max(0,capacity-occupied)}
  end
  return out
end

local function fluid_prerequisites(entity)
  local records=fluid_records(entity)
  if #records==0 then return {has_fluid=false,input_ready=true,output_ready=true,records=records} end
  local has_input,has_output=false,false; local input_ready,output_ready=true,true; local blockers={}
  for _,record_data in ipairs(records) do
    if record_data.input then
      has_input=true
      local total=sum_contents(record_data.contents)
      if record_data.connections<=0 then input_ready=false; blockers[#blockers+1]="input-unconnected:"..record_data.index
      elseif total<M.minimum_input_fluid then input_ready=false; blockers[#blockers+1]="input-empty:"..record_data.index end
    end
    if record_data.output then
      has_output=true
      if record_data.connections<=0 then output_ready=false; blockers[#blockers+1]="output-unconnected:"..record_data.index
      elseif record_data.free<M.minimum_output_free then output_ready=false; blockers[#blockers+1]="output-full:"..record_data.index end
    end
  end
  return {has_fluid=true,has_input=has_input,has_output=has_output,input_ready=input_ready,output_ready=output_ready,records=records,blockers=blockers}
end

local function electric_ready(entity)
  local relevant=entity.type=="burner-generator" or entity.type=="generator" or entity.type=="fusion-generator" or entity.type=="fusion-reactor"
  if not relevant then return true,nil end
  local connected=false
  if entity.is_connected_to_electric_network then pcall(function() connected=entity.is_connected_to_electric_network() end) end
  local network_id; pcall(function() network_id=entity.electric_network_id end)
  return connected==true or network_id~=nil,network_id
end

local function heat_ready(entity)
  if entity.type~="reactor" and entity.type~="fusion-reactor" then return true,0 end
  local neighbours={}; pcall(function() neighbours=entity.heat_neighbours or {} end)
  local count=0; for _,neighbour in pairs(neighbours or {}) do if valid(neighbour) then count=count+1 end end
  return count>0,count
end

local function entity_status(entity) local status; pcall(function() status=entity.status end); return status end
local function entity_temperature(entity) local temperature; pcall(function() temperature=tonumber(entity.temperature) end); return temperature end
local function energy_generated(entity) local generated; pcall(function() generated=tonumber(entity.energy_generated_last_tick) end); return generated end
local function neighbour_bonus(entity) local bonus; pcall(function() bonus=tonumber(entity.neighbour_bonus) end); return bonus end

function M.inspect_entity(pair,entity,force)
  if not (valid_pair(pair) and valid(entity)) then return nil,"invalid" end
  local key=entity_key(entity); local r=root()
  if not force and key and (r.machine_due[key] or 0)>now() then return r.reports[key],"cached" end
  if key then r.machine_due[key]=now()+M.machine_cache_ticks end

  local fuel_inv=fuel_inventory(entity); local burnt_inv=burnt_inventory(entity); local burner=burner_state(entity)
  local fuel_count=inventory_count(fuel_inv); local burnt_count=inventory_count(burnt_inv)
  local burnt_ready=not burnt_inv or empty_slots(burnt_inv)>0
  local fluid=fluid_prerequisites(entity)
  local electric,network_id=electric_ready(entity)
  local heat,heat_count=heat_ready(entity)
  local has_item_fuel=fuel_inv~=nil

  local state,severity
  if not has_item_fuel then
    state,severity="monitor-only","monitor"
  elseif not burnt_ready then
    state,severity="burnt-result-blocked","blocked"
  elseif not electric then
    state,severity="electric-network-missing","blocked"
  elseif not heat then
    state,severity="heat-network-missing","blocked"
  elseif not fluid.input_ready then
    state,severity="input-fluid-not-ready","blocked"
  elseif not fluid.output_ready then
    state,severity="output-fluid-not-ready","blocked"
  elseif fuel_count>=M.minimum_fuel_items or (burner and burner.remaining_burning_fuel>0) then
    state,severity="fuel-sufficient","ready"
  else
    state,severity="fuel-service-eligible","eligible"
  end

  local report={version=M.version,tick=now(),read_only=true,entity=entity,entity_name=entity.name,entity_unit=entity.unit_number,entity_type=entity.type,station_unit=station_unit(pair),state=state,severity=severity,has_item_fuel=has_item_fuel,fuel_inventory=fuel_inv,fuel_count=fuel_count,burner=burner,burnt_inventory=burnt_inv,burnt_count=burnt_count,burnt_ready=burnt_ready,fluid=fluid,electric_ready=electric,electric_network_id=network_id,heat_ready=heat,heat_neighbour_count=heat_count,status=entity_status(entity),temperature=entity_temperature(entity),energy_generated_last_tick=energy_generated(entity),neighbour_bonus=neighbour_bonus(entity)}
  if key then r.reports[key]=report end
  stat("entities_inspected"); stat("state_"..state)
  return report,"inspected"
end

local function service_radius(pair)
  local radius=tonumber(pair and pair.radius) or M.service_radius_floor
  if valid_pair(pair) and type(_G.get_station_operating_radius)=="function" then local ok,value=pcall(_G.get_station_operating_radius,pair.station); if ok and tonumber(value) then radius=tonumber(value) end end
  return math.max(8,math.min(math.max(radius,M.service_radius_floor),M.service_radius_cap))
end
local function routed_find(surface,filters,category,key,ttl)
  local scanner=rawget(_G,"TechPriestsScanRouting0610")
  if not scanner then local ok,module=pcall(require,"scripts.core.scan_routing_0610"); if ok then scanner=module end end
  if scanner and type(scanner.find_entities)=="function" then local entities=select(1,scanner.find_entities(surface,filters,{category=category,negative_key=key,negative_ttl=ttl or 60*4})); return entities or {} end
  local ok,entities=pcall(function() return surface.find_entities_filtered(filters) end); return ok and entities or {}
end

function M.scan_pair(pair,force)
  if root().enabled==false or not valid_pair(pair) then return 0 end
  local key=tostring(station_unit(pair) or "?"); local r=root()
  if not force and (r.scan_due[key] or 0)>now() then return 0 end
  r.scan_due[key]=now()+M.scan_interval
  local radius=service_radius(pair); local p=pair.station.position
  local entities=routed_find(pair.station.surface,{area={{p.x-radius,p.y-radius},{p.x+radius,p.y+radius}},force=pair.station.force,type=ENERGY_TYPES,limit=M.max_scan_entities},"energy-family-readiness","energy-family-readiness:"..tostring(pair.station.surface.index)..":"..tostring(pair.station.force.index)..":"..key,60*4)
  local reports={}; local eligible=0; local worst
  for _,entity in pairs(entities) do
    local report=M.inspect_entity(pair,entity,false)
    if report then reports[#reports+1]=report; if report.state=="fuel-service-eligible" then eligible=eligible+1 end; if not worst or report.severity=="blocked" or (report.severity=="eligible" and worst.severity~="blocked") then worst=report end end
  end
  pair.energy_family_reports_0705=reports
  pair.energy_family_summary_0705={version=M.version,tick=now(),inspected=#reports,eligible=eligible,worst_state=worst and worst.state or "none",worst_entity=worst and worst.entity_name or nil,read_only=true}
  stat("pair_scans"); stat("pair_entities_inspected",#reports); stat("eligible_found",eligible)
  return #reports
end

local function patch_diagnostics()
  local diag=rawget(_G,"TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468") or rawget(_G,"TechPriestsEmergencyDiagnostics0468")
  if not (diag and type(diag.pair_dump_lines)=="function") or diag.energy_family_readiness_0705_wrapped then return false end
  diag.energy_family_readiness_0705_wrapped=true; local prev=diag.pair_dump_lines
  diag.pair_dump_lines=function(...)
    local lines=prev(...); lines=type(lines)=="table" and lines or {}; local r=root()
    lines[#lines+1]="PAIR-DUMP-0468 ENERGY-READINESS-0705 enabled="..safe(r.enabled).." read_only=true item_mutations=0 fluid_mutations=0 heat_mutations=0 inspected="..safe(r.stats.entities_inspected or 0).." eligible="..safe(r.stats.state_fuel_service_eligible or 0).." fuel_sufficient="..safe(r.stats.state_fuel_sufficient or 0).." fluid_blocked="..safe((r.stats.state_input_fluid_not_ready or 0)+(r.stats.state_output_fluid_not_ready or 0)).." electric_blocked="..safe(r.stats.state_electric_network_missing or 0).." heat_blocked="..safe(r.stats.state_heat_network_missing or 0).." burnt_blocked="..safe(r.stats.state_burnt_result_blocked or 0).." monitor_only="..safe(r.stats.state_monitor_only or 0)
    for _,pair in pairs(pair_map()) do if valid_pair(pair) then local summary=pair.energy_family_summary_0705 or {}; lines[#lines+1]="PAIR-DUMP-0468 energy-readiness["..safe(station_unit(pair)).."] inspected="..safe(summary.inspected or 0).." eligible="..safe(summary.eligible or 0).." worst="..safe(summary.worst_state or "none").." entity="..safe(summary.worst_entity or "none") end end
    return lines
  end
  return true
end

local function register_service()
  local broker=rawget(_G,"TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service)=="function" then broker.register_service({name="energy_family_readiness_0705",category="machine-logistics",interval=179,priority=75,budget=8,note="read-only boiler burner-generator reactor and generator prerequisite inspection",fn=function(_,budget) local count=0; for _,pair in pairs(pair_map()) do if valid_pair(pair) then M.scan_pair(pair,false); count=count+1; if count>=(tonumber(budget) or 8) then break end end end; return count>0,"pairs="..safe(count) end}) end
end

function M.install()
  root(); register_service(); patch_diagnostics(); _G.TechPriestsEnergyFamilyReadiness0705=M; _G.tech_priests_energy_family_inspect_0705=M.inspect_entity
  if log then log("[Tech-Priests 0.1.672] read-only burner heat and generator readiness doctrine armed") end
  return true
end

return M
