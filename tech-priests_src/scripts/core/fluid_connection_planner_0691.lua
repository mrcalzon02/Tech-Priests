-- Tech Priests 0.1.674-dev standard-fluid route coordinator.
-- Consumes exact read-only input/output proposals from 0689, owns route search,
-- route reservations, retries, and completion verification, and publishes one
-- identified construction request at a time. construction_planner alone moves,
-- carries pipe items, and places entities.

local M={version="0.1.674-dev",storage_key="fluid_connection_planner_0691",pipe_item="pipe",pipe_entity="pipe",max_route_tiles=48,max_search_nodes=4096,reservation_ttl=60*30,proposal_max_age=60*20,rejection_cooldown=60*10,max_retries_per_tile=3,connection_settle_ticks=120,adjacency_radius=1.15,wrapper_free=true,input_output_integrated=true,construction_handoff=true,structured_scan_truth=true}
local FLUID_TYPES={"pipe","pipe-to-ground","pump","storage-tank","offshore-pump","assembling-machine","furnace","mining-drill","boiler","generator","reactor","rocket-silo","fluid-turret"}
local function now()return game and game.tick or 0 end
local function valid(e)return e and e.valid end
local function safe(v)if v==nil then return"nil"end;local ok,s=pcall(tostring,v);return ok and s or"?"end
local function valid_pair(p)return type(p)=="table"and valid(p.station)and valid(p.priest)end
local function station_unit(p)return p and(p.station_unit or(valid(p.station)and p.station.unit_number))or nil end
local function pair_map()return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or{}end
local function dist_sq(a,b)if not(a and b)then return math.huge end;local x=(a.x or 0)-(b.x or 0);local y=(a.y or 0)-(b.y or 0);return x*x+y*y end
local function normalized_position(v)if not v then return nil end;local x=tonumber(v.x or v[1]);local y=tonumber(v.y or v[2]);if not(x and y)then return nil end;return{x=x,y=y}end
local function position_key(p)return p and(tostring(p.x)..","..tostring(p.y))or"nil"end
function M.root()
 storage.tech_priests=storage.tech_priests or{};local r=storage.tech_priests[M.storage_key]or{version=M.version,enabled=true,wrapper_free=true,input_output_integrated=true,construction_handoff=true,structured_scan_truth=true,stats={},recent={},plans={},cursor=0};storage.tech_priests[M.storage_key]=r;r.version=M.version
 if r.enabled==nil then r.enabled=true end;r.wrapper_free=true;r.input_output_integrated=true;r.construction_handoff=true;r.structured_scan_truth=true;r.stats=r.stats or{};r.recent=r.recent or{};r.plans=r.plans or{};r.cursor=tonumber(r.cursor)or 0;return r
end
local function stat(k,n)local r=M.root();r.stats[k]=(tonumber(r.stats[k])or 0)+(tonumber(n)or 1)end
local function record(pair,action,detail)local r=M.root();r.recent[#r.recent+1]={tick=now(),station=safe(station_unit(pair)),action=tostring(action),detail=tostring(detail or"")};while#r.recent>160 do table.remove(r.recent,1)end;stat(action)end
local function doctrine()return rawget(_G,"TechPriestsFluidNetworkDoctrine0689")or package.loaded["scripts.core.fluid_network_doctrine_0689"]end
local function constraints()return rawget(_G,"TechPriestsPlanningConstraints0646")or package.loaded["scripts.core.planning_constraints_0646"]end
local function reservations_module()local r=rawget(_G,"TechPriestsWorkReservations0601")or package.loaded["scripts.core.work_reservations"];if not r then local ok,m=pcall(require,"scripts.core.work_reservations");if ok then r=m end end;return r end
local function ensure_reservation_category()
 local r=reservations_module();if not r then return nil end;local category="standard-fluid-pipe-route";local found=false;for _,v in ipairs(r.categories or{})do if v==category then found=true break end end;if not found then r.categories=r.categories or{};r.categories[#r.categories+1]=category end;local state=type(r.root)=="function"and r.root()or nil;if state then state.reservations=state.reservations or{};state.reservations[category]=state.reservations[category]or{}end;return r
end
local NATIVE_FLUIDBOX_1279=require("scripts.core.native_fluidbox_1279")
local SteamReorientation=require("scripts.core.steam_outlet_reorientation_1288")
local function fluidbox(e)return NATIVE_FLUIDBOX_1279.observe(e)end
local function segment_contents(box,index)local out={};if box and box.valid then pcall(function()out=box.get_fluid_segment_contents(index)or{}end)end;return type(out)=="table"and out or{}end
local function segment_id(box,index)
 local v;if box and box.valid then
  pcall(function()v=box.get_fluid_segment_id(index)end)
  -- Native 2.1 output-only boxes feed a neighbouring segment instead of
  -- belonging to one. Observe the exact connected pipe, never geometry.
  if v==nil then
   local connections={};pcall(function()connections=box.get_connections(index)or{}end)
   for _,entity in pairs(connections)do
    if valid(entity)and(entity.type=="pipe"or entity.type=="pipe-to-ground")then
     local neighbour=fluidbox(entity)
     if neighbour then pcall(function()v=neighbour.get_fluid_segment_id(1)end)end
     if v~=nil then break end
    end
   end
  end
 end;return v
end
local function filter_name(box,index)
 local function name(v)if type(v)=="string"then return v end;local ok,n=pcall(function()return v and v.name end);return ok and n or nil end
 local f;if box and box.valid then pcall(function()f=name(box.get_filter(index))end);if not f then pcall(function()f=name(box.get_locked_fluid(index))end)end end;return type(f)=="string"and f~=""and f or nil
end
local function segment_state(e,index,fluid)
 local box=fluidbox(e);if not box then return nil,"no-fluidbox"end;local contents=segment_contents(box,index);local same=tonumber(contents[fluid])or 0;local wrong;for name,amount in pairs(contents)do if name~=fluid and(tonumber(amount)or 0)>.001 then wrong=name break end end;return{box=box,same=same,wrong=wrong,filter=filter_name(box,index),segment_id=segment_id(box,index)},"ok"
end
local function inside_territory(pair,p,plan)
 local c=constraints()
 local function allowed(margin)
  if c and type(c.interior_position_allowed)=="function"then
   local ok,v=pcall(c.interior_position_allowed,pair,p,margin);return ok and v==true
  end
  return dist_sq(pair.station.position,p)<=math.max(8,(tonumber(pair.radius)or 28)-margin)^2
 end
 if allowed(2.5)then return true end
 -- A legally installed shoreline pump can expose its actual output just
 -- outside the ordinary pipe inset. Admit only that observed native port,
 -- still inside station territory; route interiors retain the normal inset.
 local remote=plan and plan.remote;local e=remote and remote.entity
 if not(plan and plan.direction=="input"and plan.fluid=="water"
   and valid(e)and e.name=="offshore-pump"and e.type=="offshore-pump"
   and e.force==pair.station.force and e.surface==pair.station.surface
   and valid(plan.machine)and plan.machine.name=="boiler"
   and plan.machine.force==pair.station.force and plan.machine.surface==pair.station.surface
   and allowed(0.5))then return false end
 local box=fluidbox(e);local connections={}
 if box then pcall(function()connections=box.get_pipe_connections(remote.fluidbox_index)or{}end)end
 for _,connection in pairs(connections)do
  local target=connection.target_position or connection.position
  if target and dist_sq(target,p)<0.0225 then
   for _,port in ipairs(remote.interfaces or{})do if dist_sq(port,p)<0.0225 then return true end end
  end
 end
 return false
end
local function entities_at(surface,p,radius,types)local entities={};pcall(function()entities=surface.find_entities_filtered({area={{p.x-radius,p.y-radius},{p.x+radius,p.y+radius}},type=types,limit=64})or{}end);return entities end
local function existing_compatible_pipe(pair,p,plan)
 for _,e in pairs(entities_at(pair.station.surface,p,.35,{"pipe","pipe-to-ground"}))do if valid(e)and e.force==pair.station.force then local box=fluidbox(e);if box then for index=1,#box do local state=segment_state(e,index,plan.fluid);if state and not state.wrong then local known=state.same>.001 or state.filter==plan.fluid or(state.segment_id and(state.segment_id==plan.remote_segment_id or state.segment_id==plan.machine_segment_id));if known then return e end end end end end end;return nil
end
local function preserves_native_boiler_ports(p,plan)
 if plan.boiler_geometry_1288 then
  for _,port in ipairs(plan.boiler_geometry_1288.inputs)do
   if dist_sq(port,p)<=1.0225 then return false end
  end
 end
 for _,e in pairs({plan.machine,plan.remote and plan.remote.entity})do
  if valid(e)and e.name=="boiler"and e.type=="boiler"then
   local box=fluidbox(e)
   if box then for index=1,#box do
    local fluid=filter_name(box,index)
    if fluid and fluid~=plan.fluid then
     local connections={};pcall(function()connections=box.get_pipe_connections(index)or{}end)
     for _,connection in pairs(connections)do
      local port=connection.target_position or connection.position
      -- Preserve both the other fluid's actual port and its adjacent pipe
      -- contacts. A steam pipe beside an unbuilt water inlet seals it off.
      if port and not connection.target and dist_sq(port,p)<=1.0225 then return false end
     end
    end
   end end
  end
 end
 return true
end
local function adjacent_safe(pair,p,plan)
 if not preserves_native_boiler_ports(p,plan)then return false,"reserved-native-boiler-other-fluid-port"end
 for _,e in pairs(entities_at(pair.station.surface,p,M.adjacency_radius,FLUID_TYPES))do
  if valid(e)and e.force==pair.station.force then
   local box=fluidbox(e)
   if box then for index=1,#box do
    -- Nearby bounding boxes can expose separate water and steam ports.
    -- Only the fluidbox whose real connection reaches this tile can mix.
    local connections={};pcall(function()connections=box.get_pipe_connections(index)or{}end)
    local touches=false
    for _,c in pairs(connections)do
     local target=c.target_position or c.position
     if target and dist_sq(target,p)<0.0225 then touches=true;break end
    end
    if touches then
     local state=segment_state(e,index,plan.fluid)
     if state then
      if state.wrong then return false,"adjacent-wrong-fluid:"..state.wrong end
      if state.filter and state.filter~=plan.fluid then return false,"adjacent-wrong-fluid-filter:"..state.filter end
      local endpoint=e==plan.machine or e==plan.remote.entity
      local known=state.same>.001 or state.filter==plan.fluid or
       (state.segment_id and(state.segment_id==plan.remote_segment_id or state.segment_id==plan.machine_segment_id))
      if not(endpoint or known)then return false,"adjacent-ambiguous-fluidbox:"..safe(e.name)end
     end
    end
   end end
  end
 end
 return true,"safe"
end
local function tile_available(pair,p,plan)
 if not inside_territory(pair,p,plan)then return false,"outside-station-interior"end;if existing_compatible_pipe(pair,p,plan)then return true,"existing"end;local ok_adj,why=adjacent_safe(pair,p,plan);if not ok_adj then return false,why end;local ok,allowed=pcall(function()return pair.station.surface.can_place_entity({name=M.pipe_entity,position=p,force=pair.station.force,build_check_type=defines and defines.build_check_type and defines.build_check_type.manual or nil})end);if not ok then ok,allowed=pcall(function()return pair.station.surface.can_place_entity({name=M.pipe_entity,position=p,force=pair.station.force})end)end;if ok and not allowed and plan.boiler_geometry_1288 and SteamReorientation.ignorable_tree_tile(pair,p,plan.boiler_geometry_1288.ignore_tree_1288)then return true,"conditional-native-tree-clearance"end;return ok and allowed==true,ok and(allowed and"placeable"or"blocked")or"can-place-error"
end
local function reconstruct(came,current,positions)local reverse={};while current do reverse[#reverse+1]=positions[current];current=came[current]end;local route={};for i=#reverse,1,-1 do route[#route+1]=reverse[i]end;return route end
local function route_between(pair,start_position,goal_position,plan)
 local start=normalized_position(start_position);local goal=normalized_position(goal_position)
 if not(start and goal)then return nil,"invalid-endpoint"end
 local dirs={{1,0},{-1,0},{0,1},{0,-1}};local reversed=false
 local function degree(point)
  local n=0;for _,d in ipairs(dirs)do
   if tile_available(pair,{x=point.x+d[1],y=point.y+d[2]},plan)then n=n+1 end
  end;return n
 end
 -- Start at the more constrained real endpoint. A two-tile shoreline pocket
 -- should exhaust two nodes, not scan the whole factory from its generator.
 -- Only swap placeable endpoints; never bypass a native collision refusal.
 if tile_available(pair,goal,plan)and tile_available(pair,start,plan)
   and degree(goal)<degree(start)then start,goal=goal,start;reversed=true end
 local queue={start};local head=1;local sk,gk=position_key(start),position_key(goal)
 local visited={[sk]=true};local came,positions={}, {[sk]=start};local nodes=0
 while head<=#queue and nodes<M.max_search_nodes do
  local current=queue[head];head=head+1;nodes=nodes+1;local ck=position_key(current)
  if ck==gk then
   local route=reconstruct(came,ck,positions)
   if#route>M.max_route_tiles then return nil,"route-too-long"end
   if reversed then local ordered={};for i=#route,1,-1 do ordered[#ordered+1]=route[i]end;route=ordered end
   return route,"found"
  end
  for _,d in ipairs(dirs)do
   local np={x=current.x+d[1],y=current.y+d[2]};local key=position_key(np)
   if not visited[key]then
    local allowed=tile_available(pair,np,plan)
    if allowed then visited[key]=true;came[key]=ck;positions[key]=np;queue[#queue+1]=np end
   end
  end
 end
 return nil,nodes>=M.max_search_nodes and"search-budget-exhausted"or"no-route"
end
local function shortest_route(pair,p,plan)
 local best;local remote=p.direction=="input"and p.source or p.sink;for _,machine_target in ipairs(p.connection_targets or{})do for _,remote_target in ipairs(remote.interfaces or{})do local route=route_between(pair,machine_target,remote_target,plan);if route and(not best or#route<#best)then best=route end end end;return best,best and"found"or"no-route"
end
local function preview_reorientation(pair,proposal,geometry)
 local source={};for k,v in pairs(proposal.source)do source[k]=v end
 source.interfaces=geometry.outputs
 local p={};for k,v in pairs(proposal)do p[k]=v end;p.source=source
 local plan={direction="input",fluid="steam",machine=p.machine,machine_fluidbox_index=p.fluidbox_index,
  machine_segment_id=segment_id(fluidbox(p.machine),p.fluidbox_index),remote=source,
  remote_segment_id=source.segment_id,boiler_geometry_1288=geometry}
 return shortest_route(pair,p,plan)
end
function M.reorientation_request_valid(pair,request,full)
 if not SteamReorientation.valid_request(pair,request)then return false end
 if not full then return true end
 if valid(request.clear_tree)then return false end
 local route=preview_reorientation(pair,request.proposal,request.geometry)
 return route~=nil
end
local function new_tiles(pair,route,plan)local tiles={};for _,p in ipairs(route or{})do if not existing_compatible_pipe(pair,p,plan)then tiles[#tiles+1]={x=p.x,y=p.y}end end;local remote_first={};for i=#tiles,1,-1 do remote_first[#remote_first+1]=tiles[i]end;return remote_first end
local function claim_route(pair,plan)
 local r=ensure_reservation_category();if not(r and type(r.claim)=="function")then return false,"reservation-unavailable"end;local claimed={};for _,p in ipairs(plan.tiles or{})do local target={surface_index=pair.station.surface.index,position={x=p.x,y=p.y}};local ok,why=r.claim("standard-fluid-pipe-route",target,pair,M.reservation_ttl,{surface_index=pair.station.surface.index,force_index=pair.station.force.index,fluid=plan.fluid,direction=plan.direction,plan_id=plan.id,source="standard-fluid-route-0691"});if not ok then for _,old in ipairs(claimed)do pcall(r.release,"standard-fluid-pipe-route",old,pair)end;return false,why or"reservation-denied"end;claimed[#claimed+1]=target end;plan.reservation_targets=claimed;return true,"reserved"
end
local function release_route(pair,plan)local r=reservations_module();if r and type(r.release)=="function"then for _,target in ipairs(plan and plan.reservation_targets or{})do pcall(r.release,"standard-fluid-pipe-route",target,pair)end end;if plan then plan.reservation_targets={}end end
local function set_plan_fields(pair,plan)pair.standard_fluid_route_plan_0691=plan;if plan and plan.direction=="input"then pair.fluid_pipe_plan_0691=plan;pair.fluid_output_pipe_plan_0696=nil elseif plan then pair.fluid_output_pipe_plan_0696=plan;pair.fluid_pipe_plan_0691=nil else pair.fluid_pipe_plan_0691=nil;pair.fluid_output_pipe_plan_0696=nil end end
local function request_owned(pair,plan)local req=pair and pair.construction_request;return type(req)=="table"and req.source=="standard-fluid-route-0691"and req.route_plan_id==plan.id end
local function clear_owned_request(pair,plan)if request_owned(pair,plan)then pair.construction_request=nil end end
local function complete_plan(pair,plan,reason)clear_owned_request(pair,plan);release_route(pair,plan);plan.state="complete";plan.completed_tick=now();plan.result=reason;pair.standard_fluid_route_last_0691=plan;set_plan_fields(pair,nil);M.root().plans[plan.id]=nil;record(pair,"plan-completed",reason);return true end
local function abort_plan(pair,plan,reason)clear_owned_request(pair,plan);release_route(pair,plan);plan.state="aborted";plan.aborted_tick=now();plan.result=reason;pair.standard_fluid_route_last_0691=plan;pair.standard_fluid_route_reject_until_0691=now()+M.rejection_cooldown;set_plan_fields(pair,nil);M.root().plans[plan.id]=nil;record(pair,"plan-aborted",reason);return false end
local function proposal_lists(pair)local all={};for _,p in ipairs(pair.fluid_connection_proposals_0689 or{})do all[#all+1]=p end;for _,p in ipairs(pair.fluid_output_sink_proposals_0694 or{})do all[#all+1]=p end;table.sort(all,function(a,b)if a.direction~=b.direction then return a.direction=="input"end;return dist_sq(a.machine.position,(a.direction=="input"and a.source or a.sink).entity.position)<dist_sq(b.machine.position,(b.direction=="input"and b.source or b.sink).entity.position)end);return all end
local function create_plan(pair,p)
 if pair.fluid_turret_pipe_plan_0719 then return nil,"fluid-turret-route-busy"end;local d=doctrine();if not(d and type(d.validate_proposal)=="function")then return nil,"doctrine-unavailable"end;local ok,why,report=d.validate_proposal(pair,p);if not ok then return nil,why end;local remote=p.direction=="input"and p.source or p.sink;local plan={version=M.version,id=safe(station_unit(pair))..":"..p.direction..":"..safe(p.machine_unit)..":"..now(),state="planning",direction=p.direction,fluid=p.fluid,machine=p.machine,machine_name=p.machine_name,machine_unit=p.machine_unit,machine_fluidbox_index=p.fluidbox_index,machine_segment_id=segment_id(fluidbox(p.machine),p.fluidbox_index),remote=remote,remote_segment_id=remote.segment_id,proposal=p,proposal_tick=p.tick,report_tick=report and report.tick,current_index=1,retries={},last_task_tick=-1}
 local route,rwhy=shortest_route(pair,p,plan);if not route then
  if rwhy=="no-route"then SteamReorientation.propose(pair,p,function(proposal,geometry)
   return preview_reorientation(pair,proposal,geometry)end)end
  return nil,rwhy
 end;plan.route=route;plan.tiles=new_tiles(pair,route,plan);if#plan.tiles==0 then return nil,"already-connected"end;plan.state="planned";local claimed,cwhy=claim_route(pair,plan);if not claimed then return nil,cwhy end;M.root().plans[plan.id]=plan;set_plan_fields(pair,plan);record(pair,"plan-created",plan.direction..":"..plan.fluid.." tiles="..#plan.tiles);return plan,"created"
end
local function current_tile(plan)return plan and plan.tiles and plan.tiles[tonumber(plan.current_index)or 1]or nil end
local function connection_complete(pair,plan)
 -- A first pipe on the machine is not a completed route. Both physical
 -- endpoints must belong to the same live native fluid segment.
 local machine_segment=segment_id(fluidbox(plan.machine),plan.machine_fluidbox_index)
 local remote_segment=plan.remote and segment_id(fluidbox(plan.remote.entity),plan.remote.fluidbox_index)
 if machine_segment==nil or remote_segment==nil or machine_segment~=remote_segment then return false,"endpoint-segments-disconnected"end
 local d=doctrine();if not(d and type(d.inspect_machine)=="function"and valid(plan.machine))then return false,"doctrine-unavailable"end;local report=d.inspect_machine(pair,plan.machine,true);if not report then return false,"report-unavailable"end;for _,rec in ipairs(report.records or{})do if rec.index==plan.machine_fluidbox_index and rec.requirement and rec.requirement.name==plan.fluid then if rec.connected then return true,"machine-port-connected"end;return false,"machine-port-unconnected"end end;return false,"machine-port-missing"
end
local function validate_plan(pair,plan)
 plan.machine_segment_id=segment_id(fluidbox(plan.machine),plan.machine_fluidbox_index)
 if plan.remote then plan.remote_segment_id=segment_id(fluidbox(plan.remote.entity),plan.remote.fluidbox_index)end
 if not(valid(plan.machine)and plan.remote and valid(plan.remote.entity))then return false,"endpoint-invalid"end;local complete=connection_complete(pair,plan);if complete then return true,"connected"end;local d=doctrine();if not(d and type(d.validate_proposal)=="function")then return false,"doctrine-unavailable"end;local ok,why=d.validate_proposal(pair,plan.proposal,true);if not ok then return false,why end;local tile=current_tile(plan);if tile then local allowed,twhy=tile_available(pair,tile,plan);if not allowed then return false,twhy end end;return true,"valid"
end
local function observe_construction(pair,plan)
 local task=pair.construction_last_task_0338;if type(task)~="table"or task.request_field~="construction_request"or type(task.request_value)~="table"or task.request_value.source~="standard-fluid-route-0691"or task.request_value.route_plan_id~=plan.id then return end;local tick=tonumber(task.completed_tick)or-1;if tick<=(tonumber(plan.last_task_tick)or-1)then return end;plan.last_task_tick=tick;local index=tonumber(task.request_value.route_index)or tonumber(plan.current_index)or 1;local tile=plan.tiles[index]
 if task.built_entity or(tile and existing_compatible_pipe(pair,tile,plan))then plan.current_index=index+1;plan.retries[index]=nil;stat("tiles-completed");record(pair,"tile-complete",position_key(tile))else plan.retries[index]=(tonumber(plan.retries[index])or 0)+1;record(pair,"tile-failed",safe(task.result));if plan.retries[index]>=M.max_retries_per_tile then abort_plan(pair,plan,"tile-failed:"..safe(task.result)..":"..position_key(tile))end end
end
local function publish_request(pair,plan)
 -- An unstarted discovery candidate is not physical custody. Publish an exact
 -- route for the builder to arbitrate, without touching existing cargo/tasks.
 if pair.construction_task_0338 or pair.construction_custody_0338 then return false,"construction-busy"end;if pair.construction_request and not request_owned(pair,plan)then return false,"external-construction-request"end;local tile=current_tile(plan);while tile and existing_compatible_pipe(pair,tile,plan)do plan.current_index=(tonumber(plan.current_index)or 1)+1;tile=current_tile(plan)end;if not tile then clear_owned_request(pair,plan);plan.state="awaiting-connection";plan.settle_until=now()+M.connection_settle_ticks;return false,"awaiting-connection"end
 pair.construction_request={item_name=M.pipe_item,entity_name=M.pipe_entity,category="standard-fluid-pipe",position={x=tile.x,y=tile.y},site_reason="standard-fluid-route:"..plan.direction..":"..plan.fluid,source="standard-fluid-route-0691",route_plan_id=plan.id,route_index=plan.current_index,route_direction=plan.direction};plan.state="construction-requested";return true,"request-published"
end
function M.refresh_pair(pair)
 if M.root().enabled==false or not valid_pair(pair)then return{processed=0,failed=not valid_pair(pair)and 1 or 0,detail="disabled-or-invalid"}end;local plan=pair.standard_fluid_route_plan_0691
 if plan then observe_construction(pair,plan);plan=pair.standard_fluid_route_plan_0691;if not plan then return{processed=1,blocked=1,detail="plan-aborted"}end;local ok,why=validate_plan(pair,plan);if not ok then abort_plan(pair,plan,why);return{processed=1,blocked=1,detail="plan-invalid:"..safe(why)}end;if why=="connected"then complete_plan(pair,plan,"route-connected");return{processed=1,acted=0,detail="connected"}end;if plan.state=="awaiting-connection"then if now()>(tonumber(plan.settle_until)or 0)then abort_plan(pair,plan,"route-built-not-connected");return{processed=1,blocked=1,detail="not-connected"}end;return{processed=1,waiting=1,detail="awaiting-connection"}end;local published,pwhy=publish_request(pair,plan);return{processed=1,acted=0,waiting=published and 1 or 0,blocked=(not published and pwhy~="construction-busy")and 1 or 0,detail=pwhy}
 end
 if(tonumber(pair.standard_fluid_route_reject_until_0691)or 0)>now()then return{processed=1,waiting=1,detail="cooldown"}end;local d=doctrine();if d and type(d.scan_pair)=="function"then pcall(d.scan_pair,pair,true)end;for _,proposal in ipairs(proposal_lists(pair))do local ok,created,why=pcall(create_plan,pair,proposal);if not ok then pair.standard_fluid_route_refusal_0691={tick=now(),reason=tostring(created)};return {processed=1,failed=1,detail=tostring(created)}end;if not created then pair.standard_fluid_route_refusal_0691={tick=now(),reason=tostring(why)}end;if created then local published,pwhy=publish_request(pair,created);return{processed=1,acted=0,waiting=published and 1 or 0,blocked=published and 0 or 1,detail=pwhy}end end;return{processed=1,waiting=1,detail="no-safe-proposal"}
end
function M.abort_pair(pair,reason)local plan=pair and pair.standard_fluid_route_plan_0691;if not plan then return false,"no-plan"end;return abort_plan(pair,plan,reason or"aborted")end
function M.describe_pair(pair)local plan=pair and pair.standard_fluid_route_plan_0691;if not plan then return"No standard fluid route."end;return"Standard fluid route "..safe(plan.direction).." "..safe(plan.fluid).." state="..safe(plan.state).." index="..safe(plan.current_index).."/"..safe(#(plan.tiles or{}))end
function M.service_all(_,budget)
 local list={};for key,pair in pairs(pair_map())do if valid_pair(pair)then list[#list+1]={key=tostring(key),pair=pair}end end;table.sort(list,function(a,b)return a.key<b.key end);local state=M.root();local limit=math.min(#list,math.max(0,math.floor(tonumber(budget)or 6)));if limit==0 then return{processed=0,acted=0,detail="no-pairs"}end;local start=state.cursor%#list+1;local blocked,waiting,failed=0,0,0;for i=0,limit-1 do local pair=list[((start+i-1)%#list)+1].pair;local ok,out=pcall(M.refresh_pair,pair);if ok and type(out)=="table"then blocked=blocked+(tonumber(out.blocked)or 0);waiting=waiting+(tonumber(out.waiting)or 0)else failed=failed+1 end end;state.cursor=(start+limit-2)%#list+1;return{processed=limit,acted=0,blocked=blocked,waiting=waiting,failed=failed,exhausted=#list>limit,detail="pairs="..limit}
end
local function patch_diagnostics()
 local d=rawget(_G,"TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")or rawget(_G,"TechPriestsEmergencyDiagnostics0468");if not(d and type(d.pair_dump_lines)=="function")or d.fluid_connection_planner_0691_wrapped then return false end;d.fluid_connection_planner_0691_wrapped=true;local previous=d.pair_dump_lines;d.pair_dump_lines=function(...)local lines=previous(...);lines=type(lines)=="table"and lines or{};local r=M.root();lines[#lines+1]="PAIR-DUMP-0468 STANDARD-FLUID-ROUTE-0691 enabled="..safe(r.enabled).." wrapper_free=true plans="..safe(r.stats["plan-created"]or 0).." complete="..safe(r.stats["plan-completed"]or 0).." aborted="..safe(r.stats["plan-aborted"]or 0);return lines end;return true
end
local function canonical_broker()
 local broker=rawget(_G,"TechPriestsRuntimeTickBroker0600")or package.loaded["scripts.core.runtime_tick_broker"];if not broker then local ok,m=pcall(require,"scripts.core.runtime_tick_broker");if not ok then return nil end;broker=m end;if not(broker and type(broker.install)=="function")then return nil end;local ok,installed=pcall(broker.install);if not(ok and installed==true)then return nil end;return broker
end
local function register_service()
 local broker=canonical_broker();if not(broker and type(broker.register_service)=="function")then return false end;local service=broker.register_service({name="standard_fluid_route_discovery_0691",category="planning",interval=241,priority=75,budget=6,note="safe standard fluid input/output route planning and construction request publication",fn=function(_,budget)return M.service_all("broker",budget)end});return service~=nil
end
function M.install()M.root();_G.TechPriestsFluidConnectionPlanner0691=M;if not register_service()then return false end;patch_diagnostics();if log then log("[Tech-Priests recovery] wrapper-free standard fluid route coordinator armed")end;return true end
return M
