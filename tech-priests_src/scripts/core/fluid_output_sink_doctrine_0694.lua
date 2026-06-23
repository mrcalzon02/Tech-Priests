-- Tech Priests 0.1.668 real output-fluid sink doctrine.
--
-- Read-only prerequisite for output pipe construction. A machine output may be
-- routed only to a real destination fluid segment that:
--   * accepts input or input-output flow;
--   * contains only the same fluid, or is empty and explicitly filtered/locked
--     to that fluid;
--   * has measured free segment capacity for at least one expected craft;
--   * exposes an actual unconnected pipe interface;
--   * is not already the machine output segment.
--
-- This module never mutates fluid, places pipes, changes recipes, reserves work,
-- or moves priests. Empty unfiltered segments are intentionally rejected.

local M = {
  version = "0.1.668",
  storage_key = "fluid_output_sink_doctrine_0694",
  service_radius_floor = 28,
  service_radius_cap = 96,
  max_scan_entities = 256,
  proposal_ttl = 60 * 20,
  minimum_capacity_multiplier = 1.0,
}

local previous_inspect_machine

local SINK_ENTITY_TYPES = {
  "storage-tank",
  "pipe",
  "pipe-to-ground",
  "pump",
  "assembling-machine",
  "furnace",
  "mining-drill",
  "boiler",
  "generator",
  "reactor",
  "fluid-turret",
  "rocket-silo",
}

local OUTPUT_STATES = {
  ["output-unconnected-buffer"] = true,
  ["output-unconnected-blocked"] = true,
}

local function now() return game and game.tick or 0 end
local function valid(entity) return entity and entity.valid end
local function safe(value) if value == nil then return "nil" end local ok,text=pcall(tostring,value); return ok and text or "?" end
local function lower(value) return string.lower(tostring(value or "")) end
local function valid_pair(pair) return pair and valid(pair.station) and valid(pair.priest) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function dist_sq(a,b) if not (a and b) then return 999999999 end local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end

local function entity_key(entity)
  if not valid(entity) then return nil end
  if entity.unit_number then return "unit:" .. tostring(entity.unit_number) end
  return tostring(entity.surface and entity.surface.index or "?") .. ":"
    .. tostring(entity.name or entity.type) .. ":"
    .. tostring(math.floor((entity.position.x or 0) * 10)) .. ":"
    .. tostring(math.floor((entity.position.y or 0) * 10))
end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests[M.storage_key] or {
    version = M.version,
    enabled = true,
    read_only = true,
    reject_empty_unfiltered = true,
    stats = {},
    recent = {},
    proposals = {},
  }
  storage.tech_priests[M.storage_key] = r
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  if r.read_only == nil then r.read_only = true end
  if r.reject_empty_unfiltered == nil then r.reject_empty_unfiltered = true end
  r.stats = r.stats or {}
  r.recent = r.recent or {}
  r.proposals = r.proposals or {}
  return r
end

local function stat(name, amount) local r=root(); r.stats[name]=(r.stats[name] or 0)+(amount or 1) end
local function record(pair, action, detail)
  local r=root(); stat(action)
  r.recent[#r.recent+1]={tick=now(),action=tostring(action or "event"),station=safe(station_unit(pair)),detail=tostring(detail or "")}
  while #r.recent>160 do table.remove(r.recent,1) end
end

local function fluidbox(entity)
  if not valid(entity) then return nil end
  local ok,box=pcall(function() return entity.fluidbox end)
  return ok and box and box.valid and box or nil
end

local function prototype_records(box,index)
  local out={}
  if not (box and box.valid and index) then return out end
  local ok,value=pcall(function() return box.get_prototype(index) end)
  if not ok or value==nil then return out end
  if type(value)=="table" and value.object_name==nil then
    for _,prototype in pairs(value) do if prototype then out[#out+1]=prototype end end
  else
    out[#out+1]=value
  end
  return out
end

local function accepts_input(box,index)
  local saw_type=false
  for _,prototype in ipairs(prototype_records(box,index)) do
    local production
    pcall(function() production=prototype.production_type end)
    production=lower(production)
    if production~="" then saw_type=true end
    if production=="input" or production=="input-output" then return true end
  end
  -- Pipe/tank prototypes may not expose a production direction. Treat them as
  -- bidirectional only when no explicit output-only direction was found.
  return not saw_type
end

local function filter_name(box,index)
  local filter
  pcall(function() filter=box.get_filter(index) end)
  if type(filter)=="table" and filter.name then return filter.name,"runtime-filter" end
  local locked
  pcall(function() locked=box.get_locked_fluid(index) end)
  if type(locked)=="string" and locked~="" then return locked,"locked-fluid" end
  for _,prototype in ipairs(prototype_records(box,index)) do
    local filter_proto
    pcall(function() filter_proto=prototype.filter end)
    if filter_proto then
      local name
      pcall(function() name=filter_proto.name end)
      if type(name)=="string" and name~="" then return name,"prototype-filter" end
    end
  end
  return nil,nil
end

local function segment_contents(box,index)
  local contents={}
  if not (box and box.valid and index) then return contents end
  pcall(function() contents=box.get_fluid_segment_contents(index) or {} end)
  return type(contents)=="table" and contents or {}
end

local function local_fluid(box,index)
  local fluid
  pcall(function() fluid=box[index] end)
  if type(fluid)=="table" and fluid.name and (tonumber(fluid.amount) or 0)>0 then
    return {name=fluid.name,amount=tonumber(fluid.amount) or 0,temperature=tonumber(fluid.temperature)}
  end
  return nil
end

local function segment_capacity(box,index)
  local capacity=0
  pcall(function() capacity=tonumber(box.get_capacity(index)) or 0 end)
  return capacity
end

local function segment_id(box,index)
  local id
  pcall(function() id=box.get_fluid_segment_id(index) end)
  return id
end

local function sum_contents(contents)
  local total=0
  for _,amount in pairs(contents or {}) do total=total+(tonumber(amount) or 0) end
  return total
end

local function segment_fluid_state(box,index,wanted)
  local contents=segment_contents(box,index)
  local current=local_fluid(box,index)
  if next(contents)==nil and current then contents[current.name]=current.amount end
  local wanted_amount=tonumber(contents[wanted]) or 0
  local wrong_name,wrong_amount
  for name,amount in pairs(contents) do
    if name~=wanted and (tonumber(amount) or 0)>0.001 then wrong_name,wrong_amount=name,tonumber(amount) or 0; break end
  end
  return {
    contents=contents,
    current=current,
    wanted_amount=wanted_amount,
    wrong_name=wrong_name,
    wrong_amount=wrong_amount or 0,
    occupied=sum_contents(contents),
  }
end

local function pipe_connections(box,index)
  local out={}
  if not (box and box.valid and index) then return out end
  local connections={}
  pcall(function() connections=box.get_pipe_connections(index) or {} end)
  for connection_index,connection in pairs(connections or {}) do
    if type(connection)=="table" then
      local owner
      if connection.target then pcall(function() owner=connection.target.owner end) end
      local position=connection.target_position or connection.position
      out[#out+1]={
        index=connection_index,
        position=position and {x=position.x,y=position.y} or nil,
        connected=connection.target~=nil or valid(owner),
        target=connection.target,
        target_owner=owner,
        target_fluidbox_index=connection.target_fluidbox_index,
      }
    end
  end
  return out
end

local function free_interfaces(box,index)
  local out={}
  for _,connection in ipairs(pipe_connections(box,index)) do
    if not connection.connected and connection.position then out[#out+1]=connection.position end
  end
  return out
end

local function output_segment_id(report,record)
  if not (report and valid(report.machine) and record and record.index) then return nil end
  local box=fluidbox(report.machine)
  return box and segment_id(box,record.index) or nil
end

local function service_radius(pair)
  local radius=tonumber(pair and pair.radius) or M.service_radius_floor
  if valid_pair(pair) and type(_G.get_station_operating_radius)=="function" then
    local ok,value=pcall(_G.get_station_operating_radius,pair.station)
    if ok and tonumber(value) then radius=tonumber(value) end
  end
  return math.max(8,math.min(math.max(radius,M.service_radius_floor),M.service_radius_cap))
end

local function routed_find(surface,filters,category,negative_key,ttl)
  local scanner=rawget(_G,"TechPriestsScanRouting0610")
  if not scanner then local ok,module=pcall(require,"scripts.core.scan_routing_0610"); if ok then scanner=module end end
  if scanner and type(scanner.find_entities)=="function" then
    local entities=select(1,scanner.find_entities(surface,filters,{category=category,negative_key=negative_key,negative_ttl=ttl or 60*4}))
    return entities or {}
  end
  local ok,entities=pcall(function() return surface.find_entities_filtered(filters) end)
  return ok and entities or {}
end

local function candidate_record(pair,report,output_record,entity,index)
  if not (valid_pair(pair) and report and valid(report.machine) and valid(entity)) then return nil,"invalid" end
  if entity==report.machine then return nil,"same-machine" end
  local box=fluidbox(entity)
  if not box or not accepts_input(box,index) then return nil,"not-input-capable" end

  local fluid=output_record.requirement.name
  local state=segment_fluid_state(box,index,fluid)
  if state.wrong_name then return nil,"wrong-fluid:"..state.wrong_name end

  local filter,filter_source=filter_name(box,index)
  if filter and filter~=fluid then return nil,"wrong-filter:"..filter end
  local explicitly_typed=filter==fluid
  local same_fluid=state.wanted_amount>0.001
  if not same_fluid and not explicitly_typed then return nil,"empty-unfiltered" end

  local capacity=segment_capacity(box,index)
  local free=math.max(0,capacity-state.occupied)
  local needed=math.max(0.001,(tonumber(output_record.requirement.amount) or 0)*M.minimum_capacity_multiplier)
  if free+0.001<needed then return nil,"insufficient-capacity" end

  local interfaces=free_interfaces(box,index)
  if #interfaces==0 then return nil,"no-free-interface" end

  local sink_segment=segment_id(box,index)
  local source_segment=output_segment_id(report,output_record)
  if sink_segment and source_segment and sink_segment==source_segment then return nil,"already-same-segment" end

  local nearest=dist_sq(entity.position,report.machine.position)
  for _,position in ipairs(output_record.pipe_connections or {}) do
    local target=position.target_position or position.position
    if target then nearest=math.min(nearest,dist_sq(entity.position,target)) end
  end

  local class=same_fluid and "same-fluid-segment" or "empty-filtered-sink"
  local score=(same_fluid and 0 or 10000)+nearest-(math.min(free,100000)*0.001)
  return {
    entity=entity,
    entity_name=entity.name,
    entity_unit=entity.unit_number,
    position={x=entity.position.x,y=entity.position.y},
    fluidbox_index=index,
    segment_id=sink_segment,
    fluid=fluid,
    current_amount=state.wanted_amount,
    occupied=state.occupied,
    capacity=capacity,
    free_capacity=free,
    needed_capacity=needed,
    filter=filter,
    filter_source=filter_source,
    sink_class=class,
    interfaces=interfaces,
    distance_sq=nearest,
    score=score,
    read_only=true,
  },"eligible"
end

local function find_sink(pair,report,output_record)
  local radius=service_radius(pair)
  local p=pair.station.position
  local fluid=output_record.requirement.name
  local entities=routed_find(pair.station.surface,{
    area={{p.x-radius,p.y-radius},{p.x+radius,p.y+radius}},
    force=pair.station.force,
    type=SINK_ENTITY_TYPES,
    limit=M.max_scan_entities,
  },"fluid-output-sink","fluid-output-sink:"..tostring(pair.station.surface.index)..":"..tostring(pair.station.force.index)..":"..tostring(fluid),60*4)

  local best,best_score
  local seen_segments={}
  local rejected={}
  for _,entity in pairs(entities) do
    local box=fluidbox(entity)
    if box then
      for index=1,#box do
        local candidate,why=candidate_record(pair,report,output_record,entity,index)
        if candidate then
          local segment_key=candidate.segment_id and ("segment:"..tostring(candidate.segment_id)) or (entity_key(entity)..":"..tostring(index))
          if not seen_segments[segment_key] then
            seen_segments[segment_key]=true
            if not best_score or candidate.score<best_score then best,best_score=candidate,candidate.score end
          end
        else
          rejected[why or "rejected"]=(rejected[why or "rejected"] or 0)+1
        end
      end
    end
  end
  return best,rejected
end

local function output_targets(record)
  local out={}
  for _,connection in ipairs(record.pipe_connections or {}) do
    local position=connection.target_position or connection.position
    if position and not connection.connected then out[#out+1]={x=position.x,y=position.y} end
  end
  return out
end

local function build_proposals(pair,report)
  if not (valid_pair(pair) and report and valid(report.machine)) then return {} end
  local proposals={}
  for _,record_data in ipairs(report.records or {}) do
    if record_data.direction=="output" and OUTPUT_STATES[record_data.state] then
      local targets=output_targets(record_data)
      if #targets>0 then
        local sink,rejected=find_sink(pair,report,record_data)
        local proposal={
          version=M.version,
          tick=now(),
          expires_tick=now()+M.proposal_ttl,
          read_only=true,
          action="connect-fluid-output",
          machine=report.machine,
          machine_name=report.machine_name,
          machine_unit=report.machine_unit,
          recipe_name=report.recipe_name,
          fluid=record_data.requirement.name,
          amount_per_craft=record_data.requirement.amount,
          output_fluidbox_index=record_data.index,
          output_segment_id=output_segment_id(report,record_data),
          connection_targets=targets,
          sink=sink,
          state=sink and "compatible-sink-found" or "no-compatible-sink-found",
          rejected_summary=rejected,
        }
        proposals[#proposals+1]=proposal
        if sink then
          stat("compatible_sinks_found")
          stat("sink_class_"..sink.sink_class)
        else
          stat("output_proposals_without_sink")
        end
      end
    end
  end
  pair.fluid_output_sink_proposals_0694=proposals
  local key=report.machine_unit and tostring(report.machine_unit) or entity_key(report.machine)
  if key then root().proposals[key]=proposals end
  stat("output_reports_processed")
  stat("output_sink_proposals",#proposals)
  return proposals
end

local function patched_inspect_machine(pair,machine,force,...)
  local report,why=previous_inspect_machine(pair,machine,force,...)
  if report and valid_pair(pair) then build_proposals(pair,report) end
  return report,why
end

local function patch_doctrine(doctrine)
  if not (doctrine and type(doctrine.inspect_machine)=="function") or doctrine.fluid_output_sink_doctrine_0694_active then return false end
  doctrine.fluid_output_sink_doctrine_0694_active=true
  previous_inspect_machine=doctrine.inspect_machine
  doctrine.inspect_machine=patched_inspect_machine
  _G.tech_priests_fluid_network_inspect_0689=doctrine.inspect_machine
  return true
end

local function patch_diagnostics()
  local diag=rawget(_G,"TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468") or rawget(_G,"TechPriestsEmergencyDiagnostics0468")
  if not (diag and type(diag.pair_dump_lines)=="function") or diag.fluid_output_sink_doctrine_0694_wrapped then return false end
  diag.fluid_output_sink_doctrine_0694_wrapped=true
  local prev=diag.pair_dump_lines
  diag.pair_dump_lines=function(...)
    local lines=prev(...); lines=type(lines)=="table" and lines or {}; local r=root()
    lines[#lines+1]="PAIR-DUMP-0468 FLUID-OUTPUT-SINK-0694 enabled="..safe(r.enabled)
      .." read_only=true fluid_mutations=0 direct_construction=0"
      .." processed="..safe(r.stats.output_reports_processed or 0)
      .." proposals="..safe(r.stats.output_sink_proposals or 0)
      .." sinks="..safe(r.stats.compatible_sinks_found or 0)
      .." same_fluid="..safe(r.stats["sink_class_same-fluid-segment"] or 0)
      .." filtered_empty="..safe(r.stats["sink_class_empty-filtered-sink"] or 0)
      .." no_sink="..safe(r.stats.output_proposals_without_sink or 0)
    for _,pair in pairs(pair_map()) do
      if valid_pair(pair) then
        local proposals=pair.fluid_output_sink_proposals_0694 or {}
        for index,proposal in ipairs(proposals) do
          if index>4 then break end
          local sink=proposal.sink
          lines[#lines+1]="PAIR-DUMP-0468 fluid-output-sink["..safe(station_unit(pair))..":"..safe(index).."]"
            .." state="..safe(proposal.state)
            .." fluid="..safe(proposal.fluid)
            .." machine="..safe(proposal.machine_name)
            .." sink="..safe(sink and sink.entity_name or "none")
            .." class="..safe(sink and sink.sink_class or "none")
            .." free="..safe(sink and string.format("%.2f",sink.free_capacity or 0) or "0")
            .." need="..safe(sink and string.format("%.2f",sink.needed_capacity or 0) or proposal.amount_per_craft)
        end
      end
    end
    for i=math.max(1,#r.recent-8),#r.recent do local ev=r.recent[i]; if ev then lines[#lines+1]="PAIR-DUMP-0468 fluid-output-sink.recent["..safe(i).."] tick="..safe(ev.tick).." action="..safe(ev.action).." station="..safe(ev.station).." "..safe(ev.detail) end end
    return lines
  end
  return true
end

function M.install()
  root()
  local ok,doctrine=pcall(require,"scripts.core.fluid_network_doctrine_0689")
  if not (ok and doctrine) then return false end
  patch_doctrine(doctrine)
  patch_diagnostics()
  _G.TechPriestsFluidOutputSinkDoctrine0694=M
  if log then log("[Tech-Priests 0.1.668] read-only real output-fluid sink doctrine armed; empty unfiltered segments are rejected") end
  return true
end

return M
