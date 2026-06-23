-- Tech Priests 0.1.669 safe output-fluid connection planner.
--
-- Builds ordinary pipe routes only for 0694 proposals that prove a real compatible
-- sink. Every route is revalidated against current sink identity and free segment
-- capacity before each construction step. Tiles stay inside station territory,
-- reject incompatible or ambiguous adjacent fluid segments, and are reserved in
-- the shared construction category. The existing construction planner remains the
-- sole item-removal, movement, placement, and refund authority.
--
-- No fluid mutation, recipe change, direct entity placement, output venting,
-- underground pipe, pump, or tank construction occurs here.

local M = {
  version = "0.1.669",
  storage_key = "fluid_output_connection_planner_0696",
  pipe_item = "pipe",
  pipe_entity = "pipe",
  max_route_tiles = 48,
  max_search_nodes = 4096,
  reservation_ttl = 60 * 30,
  proposal_max_age = 60 * 20,
  rejection_cooldown = 60 * 10,
  max_retries_per_tile = 3,
  adjacency_radius = 1.15,
}

local previous_build_install
local previous_build_service_pair

local FLUID_NEIGHBOR_TYPES = {
  "pipe", "pipe-to-ground", "pump", "storage-tank", "offshore-pump",
  "assembling-machine", "furnace", "mining-drill", "boiler", "generator",
  "reactor", "fluid-turret", "rocket-silo",
}

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v==nil then return "nil" end local ok,s=pcall(tostring,v); return ok and s or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function valid_pair(pair) return pair and valid(pair.station) and valid(pair.priest) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function dist_sq(a,b) if not (a and b) then return 999999999 end local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end

local function pos(value)
  if not value then return nil end
  local x=tonumber(value.x or value[1]); local y=tonumber(value.y or value[2])
  if not (x and y) then return nil end
  return {x=math.floor(x+0.5),y=math.floor(y+0.5)}
end
local function pos_key(p) return p and (tostring(p.x)..","..tostring(p.y)) or "nil" end
local function same_pos(a,b) return a and b and math.abs(a.x-b.x)<0.1 and math.abs(a.y-b.y)<0.1 end

local function root()
  storage.tech_priests=storage.tech_priests or {}
  local r=storage.tech_priests[M.storage_key] or {
    version=M.version, enabled=true, ordinary_pipe_only=true,
    compatible_sink_required=true, stats={}, recent={}, plans={}
  }
  storage.tech_priests[M.storage_key]=r
  r.version=M.version
  if r.enabled==nil then r.enabled=true end
  if r.ordinary_pipe_only==nil then r.ordinary_pipe_only=true end
  if r.compatible_sink_required==nil then r.compatible_sink_required=true end
  r.stats=r.stats or {}; r.recent=r.recent or {}; r.plans=r.plans or {}
  return r
end
local function stat(name,n) local r=root(); r.stats[name]=(r.stats[name] or 0)+(n or 1) end
local function record(pair,action,detail)
  local r=root(); stat(action)
  r.recent[#r.recent+1]={tick=now(),action=tostring(action),station=safe(station_unit(pair)),detail=tostring(detail or "")}
  while #r.recent>180 do table.remove(r.recent,1) end
end

local function constraints()
  return rawget(_G,"TechPriestsPlanningConstraints0646") or package.loaded["scripts.core.planning_constraints_0646"]
end
local function reservations()
  local r=rawget(_G,"TechPriestsWorkReservations0601")
  if r then return r end
  local ok,module=pcall(require,"scripts.core.work_reservations")
  return ok and module or nil
end
local function doctrine()
  local d=rawget(_G,"TechPriestsFluidNetworkDoctrine0689")
  if d then return d end
  local ok,module=pcall(require,"scripts.core.fluid_network_doctrine_0689")
  return ok and module or nil
end

local function fluidbox(entity)
  if not valid(entity) then return nil end
  local ok,box=pcall(function() return entity.fluidbox end)
  return ok and box and box.valid and box or nil
end
local function prototype_records(box,index)
  local out={}; if not (box and box.valid and index) then return out end
  local ok,value=pcall(function() return box.get_prototype(index) end)
  if not ok or value==nil then return out end
  if type(value)=="table" and value.object_name==nil then for _,p in pairs(value) do if p then out[#out+1]=p end end else out[#out+1]=value end
  return out
end
local function accepts_input(box,index)
  local saw=false
  for _,prototype in ipairs(prototype_records(box,index)) do
    local production; pcall(function() production=prototype.production_type end); production=lower(production)
    if production~="" then saw=true end
    if production=="input" or production=="input-output" then return true end
  end
  return not saw
end
local function filter_name(box,index)
  local filter; pcall(function() filter=box.get_filter(index) end)
  if type(filter)=="table" and filter.name then return filter.name,"runtime-filter" end
  local locked; pcall(function() locked=box.get_locked_fluid(index) end)
  if type(locked)=="string" and locked~="" then return locked,"locked-fluid" end
  for _,prototype in ipairs(prototype_records(box,index)) do
    local fp; pcall(function() fp=prototype.filter end)
    if fp then local name; pcall(function() name=fp.name end); if type(name)=="string" and name~="" then return name,"prototype-filter" end end
  end
  return nil,nil
end
local function segment_contents(box,index)
  local contents={}; if not (box and box.valid and index) then return contents end
  pcall(function() contents=box.get_fluid_segment_contents(index) or {} end)
  return type(contents)=="table" and contents or {}
end
local function local_fluid(box,index)
  local fluid; pcall(function() fluid=box[index] end)
  if type(fluid)=="table" and fluid.name and (tonumber(fluid.amount) or 0)>0 then return {name=fluid.name,amount=tonumber(fluid.amount) or 0} end
  return nil
end
local function segment_capacity(box,index) local n=0; pcall(function() n=tonumber(box.get_capacity(index)) or 0 end); return n end
local function segment_id(box,index) local id; pcall(function() id=box.get_fluid_segment_id(index) end); return id end
local function sum_contents(contents) local n=0; for _,amount in pairs(contents or {}) do n=n+(tonumber(amount) or 0) end; return n end

local function segment_state(entity,index,fluid)
  local box=fluidbox(entity); if not box then return nil,"no-fluidbox" end
  local contents=segment_contents(box,index); local local_rec=local_fluid(box,index)
  if next(contents)==nil and local_rec then contents[local_rec.name]=local_rec.amount end
  local same=tonumber(contents[fluid]) or 0; local wrong
  for name,amount in pairs(contents) do if name~=fluid and (tonumber(amount) or 0)>0.001 then wrong=name; break end end
  local filter,filter_source=filter_name(box,index)
  local occupied=sum_contents(contents); local capacity=segment_capacity(box,index)
  return {
    box=box, contents=contents, same=same, wrong=wrong,
    filter=filter, filter_source=filter_source,
    occupied=occupied, capacity=capacity, free=math.max(0,capacity-occupied),
    segment_id=segment_id(box,index),
  },"ok"
end

local function pipe_connections(entity,index)
  local out={}; local box=fluidbox(entity); if not box or not index then return out end
  local connections={}; pcall(function() connections=box.get_pipe_connections(index) or {} end)
  for _,connection in pairs(connections or {}) do
    if type(connection)=="table" then
      local owner; if connection.target then pcall(function() owner=connection.target.owner end) end
      local position=connection.target_position or connection.position
      out[#out+1]={position=position and {x=position.x,y=position.y} or nil,connected=connection.target~=nil or valid(owner)}
    end
  end
  return out
end
local function free_interfaces(entity,index)
  local out={}; for _,connection in ipairs(pipe_connections(entity,index)) do if not connection.connected and connection.position then out[#out+1]=connection.position end end; return out
end

local function revalidate_sink(proposal)
  local sink=proposal and proposal.sink
  if not (proposal and sink and valid(sink.entity) and sink.fluidbox_index and proposal.fluid) then return false,"sink-invalid" end
  local state=segment_state(sink.entity,sink.fluidbox_index,proposal.fluid)
  if not state then return false,"sink-no-fluidbox" end
  if not accepts_input(state.box,sink.fluidbox_index) then return false,"sink-not-input-capable" end
  if state.wrong then return false,"sink-contaminated:"..state.wrong end
  if state.filter and state.filter~=proposal.fluid then return false,"sink-filter-changed:"..state.filter end
  if state.same<=0.001 and state.filter~=proposal.fluid then return false,"sink-became-empty-unfiltered" end
  local need=math.max(0.001,tonumber(proposal.amount_per_craft) or tonumber(sink.needed_capacity) or 0.001)
  if state.free+0.001<need then return false,"sink-full" end
  local interfaces=free_interfaces(sink.entity,sink.fluidbox_index)
  if #interfaces==0 then return false,"sink-interface-unavailable" end
  sink.current_amount=state.same; sink.occupied=state.occupied; sink.capacity=state.capacity; sink.free_capacity=state.free; sink.segment_id=state.segment_id; sink.interfaces=interfaces
  return true,"sink-valid",state
end

local function machine_output_segment(proposal)
  if not (proposal and valid(proposal.machine) and proposal.output_fluidbox_index) then return nil end
  local box=fluidbox(proposal.machine)
  return box and segment_id(box,proposal.output_fluidbox_index) or nil
end

local function territory_allowed(pair,position)
  local c=constraints()
  if c and type(c.interior_position_allowed)=="function" then local ok,allowed=pcall(c.interior_position_allowed,pair,position,2.5); return ok and allowed==true end
  local radius=tonumber(pair.radius) or 28
  return dist_sq(pair.station.position,position)<=math.max(8,radius-2.5)^2
end

local function entities_at(surface,position)
  local entities={}; pcall(function() entities=surface.find_entities_filtered({area={{position.x-0.35,position.y-0.35},{position.x+0.35,position.y+0.35}}}) or {} end); return entities
end

local function existing_route_pipe(pair,position,plan)
  for _,entity in pairs(entities_at(pair.station.surface,position)) do
    if valid(entity) and entity.force==pair.station.force and (entity.type=="pipe" or entity.type=="pipe-to-ground") then
      local box=fluidbox(entity)
      if box then
        for index=1,#box do
          local state=segment_state(entity,index,plan.fluid)
          if state and not state.wrong then
            local explicitly_typed=state.filter==plan.fluid
            local same_fluid=state.same>0.001
            local allowed_segment=state.segment_id and (state.segment_id==plan.sink_segment_id or state.segment_id==plan.output_segment_id)
            if same_fluid or explicitly_typed or allowed_segment then return entity end
          end
        end
      end
    end
  end
  return nil
end

local function adjacent_safe(pair,position,plan)
  local radius=M.adjacency_radius; local entities={}
  pcall(function() entities=pair.station.surface.find_entities_filtered({area={{position.x-radius,position.y-radius},{position.x+radius,position.y+radius}},force=pair.station.force,type=FLUID_NEIGHBOR_TYPES,limit=48}) or {} end)
  for _,entity in pairs(entities) do
    local box=fluidbox(entity)
    if box then
      for index=1,#box do
        local state=segment_state(entity,index,plan.fluid)
        if state then
          if state.wrong then return false,"adjacent-wrong-fluid:"..state.wrong end
          local same=state.same>0.001
          local typed=state.filter==plan.fluid
          local allowed_segment=state.segment_id and (state.segment_id==plan.sink_segment_id or state.segment_id==plan.output_segment_id)
          local endpoint_entity=entity==plan.machine or entity==plan.sink.entity
          if not (same or typed or allowed_segment or endpoint_entity) then return false,"adjacent-empty-unfiltered:"..safe(entity.name) end
        end
      end
    end
  end
  return true,"adjacent-safe"
end

local function can_route_tile(pair,position,plan)
  if not territory_allowed(pair,position) then return false,"outside-station-interior" end
  if existing_route_pipe(pair,position,plan) then return true,"existing-compatible" end
  local safe_adj,why=adjacent_safe(pair,position,plan); if not safe_adj then return false,why end
  local ok,allowed=pcall(function() return pair.station.surface.can_place_entity({name=M.pipe_entity,position=position,force=pair.station.force,build_check_type=defines and defines.build_check_type and defines.build_check_type.manual or nil}) end)
  if not ok then ok,allowed=pcall(function() return pair.station.surface.can_place_entity({name=M.pipe_entity,position=position,force=pair.station.force}) end) end
  return ok and allowed==true,ok and (allowed and "placeable" or "blocked") or "can-place-error"
end

local function reconstruct(came,current,positions)
  local route={}; while current do route[#route+1]=positions[current]; current=came[current] end
  local out={}; for i=#route,1,-1 do out[#out+1]=route[i] end; return out
end

local function bfs(pair,start_position,goal_position,plan)
  local start=pos(start_position); local goal=pos(goal_position); if not (start and goal) then return nil,"invalid-endpoint" end
  local queue={start}; local head=1; local start_key=pos_key(start); local goal_key=pos_key(goal)
  local visited={[start_key]=true}; local came={}; local positions={[start_key]=start}; local nodes=0
  local directions={{1,0},{-1,0},{0,1},{0,-1}}
  while head<=#queue and nodes<M.max_search_nodes do
    local current=queue[head]; head=head+1; nodes=nodes+1; local current_key=pos_key(current)
    if current_key==goal_key then
      local route=reconstruct(came,current_key,positions)
      if #route>M.max_route_tiles then return nil,"route-too-long:"..tostring(#route) end
      stat("route_nodes_visited",nodes)
      return route,"route-found"
    end
    for _,direction in ipairs(directions) do
      local next_position={x=current.x+direction[1],y=current.y+direction[2]}; local key=pos_key(next_position)
      if not visited[key] then
        local allowed=can_route_tile(pair,next_position,plan)
        if allowed then visited[key]=true; came[key]=current_key; positions[key]=next_position; queue[#queue+1]=next_position end
      end
    end
  end
  stat("route_search_exhausted")
  return nil,nodes>=M.max_search_nodes and "search-budget-exhausted" or "no-route"
end

local function best_route(pair,proposal,plan)
  local machine_targets=proposal.connection_targets or {}; local sink_targets=proposal.sink.interfaces or {}
  if #machine_targets==0 then return nil,"machine-output-interface-unavailable" end
  if #sink_targets==0 then return nil,"sink-interface-unavailable" end
  local best,best_why
  for _,machine_target in ipairs(machine_targets) do
    for _,sink_target in ipairs(sink_targets) do
      local route,why=bfs(pair,machine_target,sink_target,plan)
      if route and (not best or #route<#best) then best,best_why=route,why end
    end
  end
  return best,best_why or "no-compatible-output-route"
end

local function new_tiles(pair,route,plan)
  local tiles={}
  for _,position in ipairs(route or {}) do if not existing_route_pipe(pair,position,plan) then tiles[#tiles+1]={x=position.x,y=position.y} end end
  local reversed={}; for i=#tiles,1,-1 do reversed[#reversed+1]=tiles[i] end
  return reversed
end

local function claim_route(pair,plan)
  local r=reservations(); if not (r and type(r.claim)=="function") then return false,"reservation-unavailable" end
  local claimed={}
  for _,position in ipairs(plan.tiles or {}) do
    local target={position={x=position.x,y=position.y}}
    local ok,why=r.claim("construction",target,pair,M.reservation_ttl,{surface_index=pair.station.surface.index,force_index=pair.station.force.index,fluid=plan.fluid,plan_id=plan.id,source="fluid-output-connection-planner-0696"})
    if not ok then for _,old in ipairs(claimed) do pcall(r.release,"construction",old,pair) end; stat("route_reservation_denied"); return false,why or "reservation-denied" end
    claimed[#claimed+1]=target
  end
  plan.reservation_targets=claimed; stat("route_tiles_reserved",#claimed); return true,"reserved"
end
local function release_route(pair,plan)
  local r=reservations(); if r and type(r.release)=="function" then for _,target in ipairs(plan and plan.reservation_targets or {}) do pcall(r.release,"construction",target,pair) end end
  if plan then plan.reservation_targets={} end
end

local function station_pipe_count(pair)
  if type(_G.tech_priests_0358_station_item_count)=="function" then local ok,n=pcall(_G.tech_priests_0358_station_item_count,pair,M.pipe_item); if ok then return tonumber(n) or 0 end end
  local total=0
  if type(_G.tech_priests_inventory_steward_sources_for_pair)=="function" then
    local ok,sources=pcall(_G.tech_priests_inventory_steward_sources_for_pair,pair)
    if ok and type(sources)=="table" then for _,src in ipairs(sources) do local inv=src and src.inv; if inv and inv.valid then local ok2,n=pcall(function() return inv.get_item_count(M.pipe_item) end); if ok2 then total=total+(tonumber(n) or 0) end end end end
  end
  return total
end
local function pipe_unlocked(pair)
  local c=constraints(); if c and type(c.item_unlocked)=="function" then local ok,unlocked,why=pcall(c.item_unlocked,pair.station.force,M.pipe_item); if ok then return unlocked==true,why end end
  return true,"unknown-assumed-unlocked"
end
local function request_pipes(pair,plan)
  local remaining=math.max(1,#(plan.tiles or {})-(tonumber(plan.current_index) or 1)+1)
  pair.active_supply_request={item=M.pipe_item,count=remaining,source="fluid-output-connection-planner-0696",purpose="construction-output-pipe",fluid=plan.fluid,plan_id=plan.id,tick=now()}
  pair.logistic_requested_item={item=M.pipe_item,count=remaining,source="fluid-output-connection-planner-0696",purpose="construction-output-pipe",plan_id=plan.id}
  plan.state="waiting-pipe-items"; stat("pipe_item_requests")
end
local function clear_pipe_request(pair,plan)
  for _,field in ipairs({"active_supply_request","logistic_requested_item"}) do local req=pair and pair[field]; if type(req)=="table" and req.source=="fluid-output-connection-planner-0696" and (not plan or req.plan_id==plan.id) then pair[field]=nil end end
end

local function blocker(pair)
  if not valid_pair(pair) then return "invalid-pair" end
  if valid(pair.combat_target) then return "combat" end
  if pair.fluid_pipe_plan_0691 then return "input-pipe-plan" end
  if pair.machine_logistics_custody_0682 then return "machine-custody" end
  for _,field in ipairs({"repair_0516","combat_repair_0517","consecration_0515"}) do local state=pair[field]; local phase=lower(type(state)=="table" and state.phase or ""); if phase~="" and phase~="complete" and phase~="completed" and phase~="done" then return field end end
  if pair.direct_acquisition_target_lock_0650 then return "direct-acquisition" end
  return nil
end

local function actionable_input_proposal(pair)
  for _,proposal in ipairs(pair.fluid_connection_proposals_0689 or {}) do if type(proposal)=="table" and proposal.action=="connect-fluid-input" and proposal.state=="source-network-found" and valid(proposal.machine) and proposal.source and valid(proposal.source.entity) then return true end end
  return false
end

local function proposal_candidate(pair)
  if actionable_input_proposal(pair) then return nil end
  for _,proposal in ipairs(pair.fluid_output_sink_proposals_0694 or {}) do
    if type(proposal)=="table" and proposal.action=="connect-fluid-output" and proposal.state=="compatible-sink-found" and proposal.sink and valid(proposal.sink.entity) and valid(proposal.machine) and now()-(tonumber(proposal.tick) or -1000000)<=M.proposal_max_age then return proposal end
  end
  return nil
end

local function create_plan(pair,proposal)
  local unlocked,why=pipe_unlocked(pair); if not unlocked then record(pair,"output-pipe-technology-locked",safe(why)); return nil,"pipe-locked" end
  local sink_ok,sink_why,sink_state=revalidate_sink(proposal); if not sink_ok then record(pair,"output-sink-rejected",sink_why); return nil,sink_why end
  local plan={version=M.version,id=tostring(station_unit(pair) or "?")..":"..tostring(proposal.machine_unit or proposal.machine_name)..":out:"..tostring(now()),state="planning",created_tick=now(),fluid=proposal.fluid,machine=proposal.machine,machine_name=proposal.machine_name,machine_unit=proposal.machine_unit,output_fluidbox_index=proposal.output_fluidbox_index,sink=proposal.sink,sink_segment_id=sink_state.segment_id,output_segment_id=machine_output_segment(proposal),amount_per_craft=proposal.amount_per_craft,current_index=1,retries={},ordinary_pipe_only=true}
  local route,route_why=best_route(pair,proposal,plan); if not route then record(pair,"output-pipe-route-rejected",route_why); return nil,route_why end
  local tiles=new_tiles(pair,route,plan); if #tiles==0 then return nil,"already-connected-or-existing-route" end
  if #tiles>M.max_route_tiles then return nil,"too-many-new-tiles" end
  plan.route=route; plan.tiles=tiles; plan.state="planned"
  local claimed,claim_why=claim_route(pair,plan); if not claimed then return nil,claim_why end
  root().plans[plan.id]=plan; pair.fluid_output_pipe_plan_0696=plan; pair.fluid_output_pipe_reject_until_0696=nil
  stat("output_pipe_plans_created"); stat("output_pipe_tiles_planned",#tiles)
  record(pair,"output-pipe-plan-created",plan.fluid.." tiles="..tostring(#tiles).." machine="..safe(plan.machine_name).." sink="..safe(plan.sink.entity_name))
  return plan,"created"
end

local function ensure_plan(pair)
  local plan=pair.fluid_output_pipe_plan_0696
  if type(plan)=="table" and plan.state~="complete" and plan.state~="aborted" then return plan,"existing" end
  if (tonumber(pair.fluid_output_pipe_reject_until_0696) or 0)>now() then return nil,"rejection-cooldown" end
  if pair.construction_task_0338 then return nil,"construction-busy" end
  local blocked=blocker(pair); if blocked then return nil,"blocked:"..blocked end
  local proposal=proposal_candidate(pair); if not proposal then return nil,"no-output-proposal" end
  return create_plan(pair,proposal)
end
local function current_tile(plan) return plan and plan.tiles and plan.tiles[tonumber(plan.current_index) or 1] or nil end

local function validate_plan(pair,plan)
  if not (plan and valid(plan.machine) and plan.sink and valid(plan.sink.entity)) then return false,"endpoint-invalid" end
  local proposal={fluid=plan.fluid,amount_per_craft=plan.amount_per_craft,sink=plan.sink}
  local ok,why,state=revalidate_sink(proposal); if not ok then return false,why end
  plan.sink_segment_id=state.segment_id
  local output_box=fluidbox(plan.machine); if not output_box or not plan.output_fluidbox_index then return false,"machine-output-invalid" end
  local output_state=segment_state(plan.machine,plan.output_fluidbox_index,plan.fluid)
  if not output_state then return false,"machine-output-invalid" end
  if output_state.wrong then return false,"machine-output-contaminated:"..output_state.wrong end
  plan.output_segment_id=output_state.segment_id
  if plan.sink_segment_id and plan.output_segment_id and plan.sink_segment_id==plan.output_segment_id then return false,"already-connected" end
  local tile=current_tile(plan); if tile then local allowed,reason=can_route_tile(pair,tile,plan); if not allowed then return false,reason end end
  return true,"valid"
end

local function seed_task(pair,plan)
  if pair.construction_task_0338 then return true end
  local tile=current_tile(plan); if not tile then return false end
  if existing_route_pipe(pair,tile,plan) then plan.current_index=(tonumber(plan.current_index) or 1)+1; stat("output_pipe_tiles_adopted_existing"); return seed_task(pair,plan) end
  if station_pipe_count(pair)<=0 then request_pipes(pair,plan); return false end
  clear_pipe_request(pair,plan); plan.state="building"
  pair.construction_task_0338={item_name=M.pipe_item,entity_name=M.pipe_entity,entity_type="pipe",category="deferred-network",target_position={x=tile.x,y=tile.y},plan_reason="fluid-output-connection-plan-0696",phase="planned",created_tick=now(),source="fluid-output-connection-planner-0696",fluid_output_pipe_plan_0696=true,fluid_output_pipe_plan_id_0696=plan.id,fluid_output_pipe_index_0696=plan.current_index,fluid_name_0696=plan.fluid}
  plan.active_tile={x=tile.x,y=tile.y}; plan.active_task_tick=now(); stat("output_pipe_tasks_seeded"); return true
end

local function complete_plan(pair,plan,reason)
  release_route(pair,plan); clear_pipe_request(pair,plan); plan.state="complete"; plan.completed_tick=now(); plan.result=reason or "complete"; pair.fluid_output_pipe_plan_last_0696=plan; pair.fluid_output_pipe_plan_0696=nil
  local d=doctrine(); if d and type(d.inspect_machine)=="function" and valid(plan.machine) then pcall(d.inspect_machine,pair,plan.machine,true) end
  stat("output_pipe_plans_completed"); record(pair,"output-pipe-plan-completed",plan.fluid.." tiles="..tostring(#(plan.tiles or {})))
end
local function abort_plan(pair,plan,reason)
  release_route(pair,plan); clear_pipe_request(pair,plan)
  if pair.construction_task_0338 and pair.construction_task_0338.fluid_output_pipe_plan_id_0696==plan.id then pair.construction_task_0338=nil end
  plan.state="aborted"; plan.aborted_tick=now(); plan.result=tostring(reason or "aborted"); pair.fluid_output_pipe_plan_last_0696=plan; pair.fluid_output_pipe_plan_0696=nil; pair.fluid_output_pipe_reject_until_0696=now()+M.rejection_cooldown
  stat("output_pipe_plans_aborted"); record(pair,"output-pipe-plan-aborted",safe(reason))
end
local function task_succeeded(pair,task)
  local success=pair.last_construction_success_0338
  return task and success and (tonumber(success.tick) or -1)>=(tonumber(task.created_tick) or now()) and success.entity==M.pipe_entity and same_pos({x=success.x,y=success.y},task.target_position)
end
local function after_service(pair,plan,task,acted,why)
  if not (plan and task and task.fluid_output_pipe_plan_id_0696==plan.id) then return acted,why end
  local index=tonumber(task.fluid_output_pipe_index_0696) or tonumber(plan.current_index) or 1
  if task_succeeded(pair,task) or existing_route_pipe(pair,task.target_position,plan) then
    plan.current_index=index+1; plan.retries[index]=nil; plan.active_tile=nil; stat("output_pipe_tiles_completed")
    if not current_tile(plan) then complete_plan(pair,plan,"route-built"); return true,"fluid-output-pipe-plan-complete" end
    seed_task(pair,plan); return true,"fluid-output-pipe-tile-complete"
  end
  if why=="missing-item" then request_pipes(pair,plan); return false,"waiting-output-pipe-items" end
  if why=="blocked" or why=="create-failed" or why=="remove-failed" then
    plan.retries[index]=(tonumber(plan.retries[index]) or 0)+1; stat("output_pipe_tile_retries")
    if plan.retries[index]>=M.max_retries_per_tile then abort_plan(pair,plan,"tile-failed:"..safe(why)..":"..pos_key(task.target_position)); return false,"fluid-output-pipe-plan-aborted" end
    return acted,"fluid-output-pipe-tile-retry:"..safe(why)
  end
  return acted,why
end

local function patched_service_pair(pair,reason,...)
  if root().enabled==false or not valid_pair(pair) then return previous_build_service_pair(pair,reason,...) end
  local plan=pair.fluid_output_pipe_plan_0696
  if not plan then plan=select(1,ensure_plan(pair)) end
  if plan then
    local ok,why=validate_plan(pair,plan); if not ok then abort_plan(pair,plan,why); return false,"fluid-output-pipe-plan-invalid:"..safe(why) end
    if plan.state=="waiting-pipe-items" and not pair.construction_task_0338 and station_pipe_count(pair)<=0 then request_pipes(pair,plan); stat("output_construction_slot_held"); return false,"fluid-output-pipe-waiting-items" end
    seed_task(pair,plan)
  end

  -- Input proposals are already given precedence before output plan creation. Once
  -- an output plan exists, hide both fluid proposal sets while the inner input
  -- planner and generic construction service run, preventing a second route plan.
  local hidden_inputs,hidden_outputs
  if plan then hidden_inputs=pair.fluid_connection_proposals_0689; hidden_outputs=pair.fluid_output_sink_proposals_0694; pair.fluid_connection_proposals_0689=nil; pair.fluid_output_sink_proposals_0694=nil end
  local task=pair.construction_task_0338
  local acted,why=previous_build_service_pair(pair,reason,...)
  if plan then pair.fluid_connection_proposals_0689=hidden_inputs; pair.fluid_output_sink_proposals_0694=hidden_outputs end
  return after_service(pair,plan,task,acted,why)
end

local function patch_build(build)
  if not (build and type(build.service_pair)=="function") or build.fluid_output_connection_planner_0696_active then return false end
  build.fluid_output_connection_planner_0696_active=true; previous_build_service_pair=build.service_pair; build.service_pair=patched_service_pair; return true
end

local function patch_diagnostics()
  local diag=rawget(_G,"TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468") or rawget(_G,"TechPriestsEmergencyDiagnostics0468")
  if not (diag and type(diag.pair_dump_lines)=="function") or diag.fluid_output_connection_planner_0696_wrapped then return false end
  diag.fluid_output_connection_planner_0696_wrapped=true; local prev=diag.pair_dump_lines
  diag.pair_dump_lines=function(...)
    local lines=prev(...); lines=type(lines)=="table" and lines or {}; local r=root()
    lines[#lines+1]="PAIR-DUMP-0468 FLUID-OUTPUT-CONNECTION-0696 enabled="..safe(r.enabled).." ordinary_pipe_only=true compatible_sink_required=true direct_placements=0 fluid_mutations=0 plans="..safe(r.stats.output_pipe_plans_created or 0).." completed="..safe(r.stats.output_pipe_plans_completed or 0).." aborted="..safe(r.stats.output_pipe_plans_aborted or 0).." tiles_planned="..safe(r.stats.output_pipe_tiles_planned or 0).." tiles_reserved="..safe(r.stats.route_tiles_reserved or 0).." tiles_completed="..safe(r.stats.output_pipe_tiles_completed or 0).." item_requests="..safe(r.stats.pipe_item_requests or 0)
    for _,pair in pairs(pair_map()) do if valid_pair(pair) then local plan=pair.fluid_output_pipe_plan_0696 or {}; local tile=current_tile(plan); lines[#lines+1]="PAIR-DUMP-0468 fluid-output-pipe["..safe(station_unit(pair)).."] state="..safe(plan.state or "none").." fluid="..safe(plan.fluid or "none").." index="..safe(plan.current_index or 0).."/"..safe(plan.tiles and #plan.tiles or 0).." tile="..safe(tile and pos_key(tile) or "none").." machine="..safe(plan.machine_name or "none").." sink="..safe(plan.sink and plan.sink.entity_name or "none").." reject_until="..safe(pair.fluid_output_pipe_reject_until_0696 or 0) end end
    for i=math.max(1,#r.recent-10),#r.recent do local ev=r.recent[i]; if ev then lines[#lines+1]="PAIR-DUMP-0468 fluid-output-pipe.recent["..safe(i).."] tick="..safe(ev.tick).." action="..safe(ev.action).." station="..safe(ev.station).." "..safe(ev.detail) end end
    return lines
  end
  return true
end

function M.activate(build) patch_build(build); patch_diagnostics(); _G.TechPriestsFluidOutputConnectionPlanner0696=M; return true end
function M.install()
  root(); pcall(require,"scripts.core.fluid_output_sink_doctrine_0694")
  local ok,build=pcall(require,"scripts.core.construction_planner"); if not (ok and build) then return false end
  if not build.fluid_output_connection_planner_0696_install_wrapped then
    build.fluid_output_connection_planner_0696_install_wrapped=true; previous_build_install=build.install
    build.install=function(...) local result=type(previous_build_install)=="function" and previous_build_install(...) or true; M.activate(build); return result end
  end
  if rawget(_G,"TECH_PRIESTS_CONSTRUCTION_PLANNER_0338") then M.activate(build) end
  patch_diagnostics(); _G.TechPriestsFluidOutputConnectionPlanner0696=M
  if log then log("[Tech-Priests 0.1.669] compatible-sink output pipe planner armed; construction executor remains sole placement authority") end
  return true
end

return M
