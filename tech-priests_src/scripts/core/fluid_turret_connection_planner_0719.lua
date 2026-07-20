-- Tech Priests 0.1.674-dev fluid-turret route coordinator.
-- Canonical read-only route planning and route-ledger ownership. It consumes safe
-- 0717 proposals and exposes one fixed pipe construction request at a time to the
-- canonical construction planner. It never wraps construction, moves priests,
-- removes items, places entities, or mutates fluid networks.

local M={version="0.1.674-dev",storage_key="fluid_turret_connection_planner_0719",pipe_item="pipe",pipe_entity="pipe",max_route_tiles=48,max_search_nodes=4096,reservation_ttl=60*30,proposal_max_age=60*20,rejection_cooldown=60*10,max_retries_per_tile=3,connection_settle_ticks=120,adjacency_radius=1.15,read_only_route_planner=true,construction_handoff=true,wrapper_free=true,structured_scan_truth=true}
local FLUID_ENTITY_TYPES={"pipe","pipe-to-ground","pump","storage-tank","offshore-pump","assembling-machine","furnace","mining-drill","boiler","generator","reactor","fluid-turret","rocket-silo"}
local function now()return game and game.tick or 0 end
local function valid(e)return e and e.valid end
local function safe(v)if v==nil then return"nil"end;local ok,s=pcall(tostring,v);return ok and s or"?"end
local function valid_pair(p)return type(p)=="table"and valid(p.station)and valid(p.priest)end
local function station_unit(p)return p and(p.station_unit or(valid(p.station)and p.station.unit_number))or nil end
local function pair_map()return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or{}end
local function dist_sq(a,b)if not(a and b)then return math.huge end;local x=(a.x or 0)-(b.x or 0);local y=(a.y or 0)-(b.y or 0);return x*x+y*y end
local function normalized_position(v)if not v then return nil end;local x=tonumber(v.x or v[1]);local y=tonumber(v.y or v[2]);if not(x and y)then return nil end;return{x=math.floor(x+.5),y=math.floor(y+.5)}end
local function position_key(p)return p and(tostring(p.x)..","..tostring(p.y))or"nil"end
function M.root()
 storage.tech_priests=storage.tech_priests or{};local r=storage.tech_priests[M.storage_key]or{version=M.version,enabled=true,read_only_route_planner=true,construction_handoff=true,wrapper_free=true,structured_scan_truth=true,stats={},recent={},plans={},cursor=0};storage.tech_priests[M.storage_key]=r;r.version=M.version
 if r.enabled==nil then r.enabled=true end;r.read_only_route_planner=true;r.construction_handoff=true;r.wrapper_free=true;r.structured_scan_truth=true;r.stats=r.stats or{};r.recent=r.recent or{};r.plans=r.plans or{};r.cursor=tonumber(r.cursor)or 0;return r
end
local function stat(k,n)local r=M.root();r.stats[k]=(tonumber(r.stats[k])or 0)+(tonumber(n)or 1)end
local function record(pair,action,detail)local r=M.root();r.recent[#r.recent+1]={tick=now(),action=tostring(action),station=safe(station_unit(pair)),detail=tostring(detail or"")};while #r.recent>160 do table.remove(r.recent,1)end;stat(action)end
local function constraints()return rawget(_G,"TechPriestsPlanningConstraints0646")or package.loaded["scripts.core.planning_constraints_0646"]end
local function readiness()return rawget(_G,"TechPriestsFluidTurretReadiness0716")or package.loaded["scripts.core.fluid_turret_readiness_0716"]end
local function reservations_module()
 local r=rawget(_G,"TechPriestsWorkReservations0601")or package.loaded["scripts.core.work_reservations"];if not r then local ok,m=pcall(require,"scripts.core.work_reservations");if ok then r=m end end;return r
end
local function ensure_reservation_category()
 local r=reservations_module();if not r then return nil end;local category="fluid-turret-pipe-route";local found=false;for _,v in ipairs(r.categories or{})do if v==category then found=true break end end;if not found then r.categories=r.categories or{};r.categories[#r.categories+1]=category end;local state=type(r.root)=="function"and r.root()or nil;if state then state.reservations=state.reservations or{};state.reservations[category]=state.reservations[category]or{}end;return r
end
local function fluidbox(e)local ok,b=pcall(function()return e.fluidbox end);return ok and b and b.valid and b or nil end
local function segment_contents(box,index)local out={};if box and box.valid then pcall(function()out=box.get_fluid_segment_contents(index)or{}end)end;return type(out)=="table"and out or{}end
local function segment_id(box,index)local v;if box and box.valid then pcall(function()v=box.get_fluid_segment_id(index)end)end;return v end
local function filter_name(box,index)local f;if box and box.valid then pcall(function()f=box.get_filter(index)end);if type(f)=="table"then f=f.name end;if not f then pcall(function()f=box.get_locked_fluid(index)end)end end;return type(f)=="string"and f~=""and f or nil end
local function segment_state(e,index,fluid)
 local box=fluidbox(e);if not box then return nil,"no-fluidbox"end;local contents=segment_contents(box,index);local same=tonumber(contents[fluid])or 0;local wrong;for name,amount in pairs(contents)do if name~=fluid and(tonumber(amount)or 0)>.001 then wrong=name break end end;return{box=box,same=same,wrong=wrong,filter=filter_name(box,index),segment_id=segment_id(box,index)},"ok"
end
local function free_targets(e,index)
 local out={};local box=fluidbox(e);if not box then return out end;local connections={};pcall(function()connections=box.get_pipe_connections(index)or{}end);for _,c in pairs(connections)do if type(c)=="table"then local owner;if c.target then pcall(function()owner=c.target.owner end)end;local p=c.target_position or c.position;if c.target==nil and not valid(owner)and p then out[#out+1]={x=p.x,y=p.y}end end end;return out
end
local function inside_territory(pair,p)local c=constraints();if c and type(c.interior_position_allowed)=="function"then local ok,allowed=pcall(c.interior_position_allowed,pair,p,2.5);return ok and allowed==true end;local radius=tonumber(pair.radius)or 28;return dist_sq(pair.station.position,p)<=math.max(8,radius-2.5)^2 end
local function entities_at(surface,p)local entities={};pcall(function()entities=surface.find_entities_filtered({area={{p.x-.35,p.y-.35},{p.x+.35,p.y+.35}}})or{}end);return entities end
local function existing_compatible_pipe(pair,p,plan)
 for _,e in pairs(entities_at(pair.station.surface,p))do if valid(e)and e.force==pair.station.force and(e.type=="pipe"or e.type=="pipe-to-ground")then local box=fluidbox(e);if box then for index=1,#box do local state=segment_state(e,index,plan.fluid);if state and not state.wrong then local accepted=state.same>.001 or state.filter==plan.fluid or(state.segment_id and(state.segment_id==plan.source_segment_id or state.segment_id==plan.turret_segment_id));if accepted then return e end end end end end end;return nil
end
local function adjacent_is_safe(pair,p,plan)
 local entities={};local radius=M.adjacency_radius;pcall(function()entities=pair.station.surface.find_entities_filtered({area={{p.x-radius,p.y-radius},{p.x+radius,p.y+radius}},force=pair.station.force,type=FLUID_ENTITY_TYPES,limit=48})or{}end)
 for _,e in pairs(entities)do local box=fluidbox(e);if box then for index=1,#box do local state=segment_state(e,index,plan.fluid);if state then if state.wrong then return false,"adjacent-wrong-fluid:"..state.wrong end;local endpoint=e==plan.turret or e==plan.source.entity;local known=state.same>.001 or state.filter==plan.fluid or(state.segment_id and(state.segment_id==plan.source_segment_id or state.segment_id==plan.turret_segment_id));if not(endpoint or known)then return false,"adjacent-ambiguous-fluidbox:"..safe(e.name)end end end end end;return true,"safe"
end
local function tile_available(pair,p,plan)
 if not inside_territory(pair,p)then return false,"outside-station-interior"end;if existing_compatible_pipe(pair,p,plan)then return true,"existing"end;local adjacent_ok,why=adjacent_is_safe(pair,p,plan);if not adjacent_ok then return false,why end
 local ok,allowed=pcall(pair.station.surface.can_place_entity,pair.station.surface,{name=M.pipe_entity,position=p,force=pair.station.force,build_check_type=defines and defines.build_check_type and defines.build_check_type.manual or nil});if not ok then ok,allowed=pcall(pair.station.surface.can_place_entity,pair.station.surface,{name=M.pipe_entity,position=p,force=pair.station.force})end;return ok and allowed==true,ok and(allowed and"placeable"or"blocked")or"can-place-error"
end
local function source_safe(plan,require_interface)
 if not(plan.source and valid(plan.source.entity))then return false,"source-invalid"end;local state=segment_state(plan.source.entity,plan.source.fluidbox_index,plan.fluid);if not state then return false,"source-invalid"end;if state.wrong then return false,"source-contaminated:"..state.wrong end;if state.filter and state.filter~=plan.fluid then return false,"source-filter-changed"end;if state.same<=.001 and not(state.segment_id and state.segment_id==plan.source_segment_id)then return false,"source-identity-lost"end;if require_interface and#free_targets(plan.source.entity,plan.source.fluidbox_index)==0 then return false,"source-interface-unavailable"end;return true,"safe",state
end
local function turret_report(pair,plan)local d=readiness();if not(d and type(d.inspect_entity)=="function"and valid(plan.turret))then return nil,"readiness-unavailable"end;local report=d.inspect_entity(pair,plan.turret,true);if not(report and report.accepted_lookup and report.accepted_lookup[plan.fluid])then return nil,"fluid-no-longer-accepted"end;if#((report.pipeline and report.pipeline.wrong_fluids)or{})>0 or#((report.buffer and report.buffer.wrong_fluids)or{})>0 then return nil,"turret-contaminated"end;return report,"safe"end
local function current_proposal(pair)
 for _,p in ipairs(pair.fluid_turret_safe_proposals_0718 or{})do if p.integrity_0718=="safe"and p.state=="source-network-found"and valid(p.turret)and p.source and valid(p.source.entity)and now()-(tonumber(p.integrity_tick_0718)or-1000000)<=M.proposal_max_age and(tonumber(p.expires_tick)or 0)>=now()then return p end end;return nil
end
local function reconstruct(came,current,positions)local reverse={};while current do reverse[#reverse+1]=positions[current];current=came[current]end;local route={};for i=#reverse,1,-1 do route[#route+1]=reverse[i]end;return route end
local function route_between(pair,start_position,goal_position,plan)
 local start=normalized_position(start_position);local goal=normalized_position(goal_position);if not(start and goal)then return nil,"invalid-endpoint"end;local queue={start};local head=1;local sk,gk=position_key(start),position_key(goal);local visited={[sk]=true};local came,positions={}, {[sk]=start};local nodes=0;local dirs={{1,0},{-1,0},{0,1},{0,-1}}
 while head<=#queue and nodes<M.max_search_nodes do local current=queue[head];head=head+1;nodes=nodes+1;local ck=position_key(current);if ck==gk then local route=reconstruct(came,ck,positions);if#route>M.max_route_tiles then return nil,"route-too-long"end;return route,"found"end;for _,d in ipairs(dirs)do local np={x=current.x+d[1],y=current.y+d[2]};local key=position_key(np);if not visited[key]then local allowed=tile_available(pair,np,plan);if allowed then visited[key]=true;came[key]=ck;positions[key]=np;queue[#queue+1]=np end end end end;return nil,nodes>=M.max_search_nodes and"search-budget-exhausted"or"no-route"
end
local function shortest_route(pair,p,plan)local best;for _,turret_target in ipairs(p.connection_targets or{})do for _,source_target in ipairs(p.source.interfaces or{})do local route=route_between(pair,turret_target,source_target,plan);if route and(not best or#route<#best)then best=route end end end;return best,best and"found"or"no-route"end
local function new_tiles(pair,route,plan)local tiles={};for _,p in ipairs(route or{})do if not existing_compatible_pipe(pair,p,plan)then tiles[#tiles+1]={x=p.x,y=p.y}end end;local source_first={};for i=#tiles,1,-1 do source_first[#source_first+1]=tiles[i]end;return source_first end
local function claim_route(pair,plan)
 local r=ensure_reservation_category();if not(r and type(r.claim)=="function")then return false,"reservation-unavailable"end;local claimed={};for _,p in ipairs(plan.tiles or{})do local target={surface_index=pair.station.surface.index,position={x=p.x,y=p.y}};local ok,why=r.claim("fluid-turret-pipe-route",target,pair,M.reservation_ttl,{surface_index=pair.station.surface.index,force_index=pair.station.force.index,fluid=plan.fluid,plan_id=plan.id,source="fluid-turret-route-0719"});if not ok then for _,old in ipairs(claimed)do pcall(r.release,"fluid-turret-pipe-route",old,pair)end;return false,why or"reservation-denied"end;claimed[#claimed+1]=target end;plan.reservation_targets=claimed;return true,"reserved"
end
local function release_route(pair,plan)local r=reservations_module();if r and type(r.release)=="function"then for _,target in ipairs(plan and plan.reservation_targets or{})do pcall(r.release,"fluid-turret-pipe-route",target,pair)end end;if plan then plan.reservation_targets={}end end
local function complete_plan(pair,plan,reason)release_route(pair,plan);plan.state="complete";plan.completed_tick=now();plan.result=reason;pair.fluid_turret_pipe_plan_last_0719=plan;pair.fluid_turret_pipe_plan_0719=nil;M.root().plans[plan.id]=nil;record(pair,"plan-completed",reason);return true end
local function abort_plan(pair,plan,reason)release_route(pair,plan);plan.state="aborted";plan.aborted_tick=now();plan.result=reason;pair.fluid_turret_pipe_plan_last_0719=plan;pair.fluid_turret_pipe_plan_0719=nil;pair.fluid_turret_pipe_reject_until_0719=now()+M.rejection_cooldown;M.root().plans[plan.id]=nil;record(pair,"plan-aborted",reason);return false end
local function create_plan(pair,p)
 local plan={version=M.version,id=safe(station_unit(pair))..":turret:"..safe(p.turret_unit or p.turret_name)..":"..now(),state="planning",turret=p.turret,turret_name=p.turret_name,turret_unit=p.turret_unit,turret_fluidbox_index=p.fluidbox_index,fluid=p.fluid,source=p.source,source_segment_id=p.source.segment_id,turret_segment_id=segment_id(fluidbox(p.turret),p.fluidbox_index),current_index=1,retries={}}
 local source_ok,why,state=source_safe(plan,true);if not source_ok then return nil,why end;plan.source_segment_id=state.segment_id;local report,tw=turret_report(pair,plan);if not report or report.state~="input-pipeline-unconnected"then return nil,tw or"turret-not-unconnected"end;local route,rwhy=shortest_route(pair,p,plan);if not route then return nil,rwhy end;plan.route=route;plan.tiles=new_tiles(pair,route,plan);if#plan.tiles==0 then return nil,"already-connected"end;plan.state="planned";local claimed,cwhy=claim_route(pair,plan);if not claimed then return nil,cwhy end;M.root().plans[plan.id]=plan;pair.fluid_turret_pipe_plan_0719=plan;record(pair,"plan-created",plan.fluid.." tiles="..#plan.tiles);return plan,"created"
end
local function current_tile(plan)return plan and plan.tiles and plan.tiles[tonumber(plan.current_index)or 1]or nil end
local function validate_plan(pair,plan)
 if not(valid(plan.turret)and plan.source and valid(plan.source.entity))then return false,"endpoint-invalid"end;local source_ok,why,state=source_safe(plan,false);if not source_ok then return false,why end;plan.source_segment_id=state.segment_id;local report,tw=turret_report(pair,plan);if not report then return false,tw end;if plan.state~="awaiting-connection"and report.state~="input-pipeline-unconnected"then return false,"turret-no-longer-unconnected:"..safe(report.state)end;local tile=current_tile(plan);if tile then local allowed,twhy=tile_available(pair,tile,plan);if not allowed then return false,twhy end end;return true,"valid",report
end
function M.refresh_pair(pair)
 if M.root().enabled==false or not valid_pair(pair)then return{processed=0,failed=not valid_pair(pair)and 1 or 0,detail="disabled-or-invalid"}end;local plan=pair.fluid_turret_pipe_plan_0719
 if plan then local ok,why,report=validate_plan(pair,plan);if not ok then abort_plan(pair,plan,why);return{processed=1,blocked=1,detail="plan-invalid:"..safe(why)}end;if plan.state=="awaiting-connection"then if report and report.state~="input-pipeline-unconnected"then complete_plan(pair,plan,"route-connected");return{processed=1,acted=0,detail="connected"}elseif now()>(tonumber(plan.settle_until)or 0)then abort_plan(pair,plan,"route-built-not-connected");return{processed=1,blocked=1,detail="not-connected"}end end;return{processed=1,acted=0,waiting=1,detail=plan.state}end
 if(tonumber(pair.fluid_turret_pipe_reject_until_0719)or 0)>now()then return{processed=1,waiting=1,detail="cooldown"}end;local p=current_proposal(pair);if not p then return{processed=1,waiting=1,detail="no-safe-proposal"}end;local created,why=create_plan(pair,p);return created and{processed=1,acted=0,waiting=1,detail="plan-created"}or{processed=1,blocked=1,detail="plan-rejected:"..safe(why)}
end
function M.next_construction_request(pair)
 if not valid_pair(pair)then return nil end;local plan=pair.fluid_turret_pipe_plan_0719;if not plan then M.refresh_pair(pair);plan=pair.fluid_turret_pipe_plan_0719 end;if not plan or plan.state=="awaiting-connection"then return nil end
 local ok,why=validate_plan(pair,plan);if not ok then abort_plan(pair,plan,why);return nil end;local tile=current_tile(plan);while tile and existing_compatible_pipe(pair,tile,plan)do plan.current_index=(tonumber(plan.current_index)or 1)+1;tile=current_tile(plan)end;if not tile then plan.state="awaiting-connection";plan.settle_until=now()+M.connection_settle_ticks;return nil end
 return{field="fluid_turret_pipe_plan_0719",value=plan,placeable={item_name=M.pipe_item,entity_name=M.pipe_entity,category="fluid-turret-pipe",source="fluid-turret-route-0719"},position={x=tile.x,y=tile.y},site_reason="fluid-turret-route:"..plan.fluid,route_plan_id=plan.id,route_index=plan.current_index}
end
function M.construction_step_completed(pair,task,built_entity)
 local plan=pair and pair.fluid_turret_pipe_plan_0719;if not(plan and task and task.fluid_turret_pipe_plan_id_0719==plan.id)then return false,"plan-mismatch"end;local index=tonumber(task.fluid_turret_pipe_index_0719)or tonumber(plan.current_index)or 1;local tile=plan.tiles[index];if not(tile and(valid(built_entity)or existing_compatible_pipe(pair,tile,plan)))then return M.construction_step_failed(pair,task,"pipe-not-present")end;plan.current_index=index+1;plan.retries[index]=nil;stat("tiles-completed");if not current_tile(plan)then plan.state="awaiting-connection";plan.settle_until=now()+M.connection_settle_ticks end;return true,"step-complete"
end
function M.construction_step_failed(pair,task,reason)
 local plan=pair and pair.fluid_turret_pipe_plan_0719;if not(plan and task and task.fluid_turret_pipe_plan_id_0719==plan.id)then return false,"plan-mismatch"end;local index=tonumber(task.fluid_turret_pipe_index_0719)or tonumber(plan.current_index)or 1;plan.retries[index]=(tonumber(plan.retries[index])or 0)+1;if plan.retries[index]>=M.max_retries_per_tile then return abort_plan(pair,plan,"tile-failed:"..safe(reason)..":"..position_key(plan.tiles[index]))end;record(pair,"tile-retry",safe(reason));return false,"retry"
end
function M.abort_pair(pair,reason)local plan=pair and pair.fluid_turret_pipe_plan_0719;if not plan then return false,"no-plan"end;return abort_plan(pair,plan,reason or"aborted")end
function M.describe_pair(pair)local plan=pair and pair.fluid_turret_pipe_plan_0719;if not plan then return"No fluid-turret route."end;return"Fluid turret route "..safe(plan.fluid).." state="..safe(plan.state).." index="..safe(plan.current_index).."/"..safe(#(plan.tiles or{}))end
function M.service_all(_,budget)
 local list={};for key,pair in pairs(pair_map())do if valid_pair(pair)then list[#list+1]={key=tostring(key),pair=pair}end end;table.sort(list,function(a,b)return a.key<b.key end);local state=M.root();local limit=math.min(#list,math.max(0,math.floor(tonumber(budget)or 6)));if limit==0 then return{processed=0,acted=0,detail="no-pairs"}end;local start=state.cursor%#list+1;local blocked,waiting,failed=0,0,0;for i=0,limit-1 do local pair=list[((start+i-1)%#list)+1].pair;local ok,out=pcall(M.refresh_pair,pair);if ok and type(out)=="table"then blocked=blocked+(tonumber(out.blocked)or 0);waiting=waiting+(tonumber(out.waiting)or 0)else failed=failed+1 end end;state.cursor=(start+limit-2)%#list+1;return{processed=limit,acted=0,blocked=blocked,waiting=waiting,failed=failed,exhausted=#list>limit,detail="pairs="..limit}
end
local function patch_diagnostics()
 local d=rawget(_G,"TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468")or rawget(_G,"TechPriestsEmergencyDiagnostics0468");if not(d and type(d.pair_dump_lines)=="function")or d.fluid_turret_connection_planner_0719_wrapped then return false end;d.fluid_turret_connection_planner_0719_wrapped=true;local previous=d.pair_dump_lines;d.pair_dump_lines=function(...)local lines=previous(...);lines=type(lines)=="table"and lines or{};local r=M.root();lines[#lines+1]="PAIR-DUMP-0468 FLUID-TURRET-ROUTE-0719 enabled="..safe(r.enabled).." wrapper_free=true plans="..safe(r.stats["plan-created"]or 0).." completed="..safe(r.stats["plan-completed"]or 0).." aborted="..safe(r.stats["plan-aborted"]or 0);return lines end;return true
end
local function canonical_broker()
 local broker=rawget(_G,"TechPriestsRuntimeTickBroker0600")or package.loaded["scripts.core.runtime_tick_broker"];if not broker then local ok,m=pcall(require,"scripts.core.runtime_tick_broker");if not ok then return nil end;broker=m end;if not(broker and type(broker.install)=="function")then return nil end;local ok,installed=pcall(broker.install);if not(ok and installed==true)then return nil end;return broker
end
local function register_service()
 local broker=canonical_broker();if not(broker and type(broker.register_service)=="function")then return false end;local service=broker.register_service({name="fluid_turret_route_discovery_0719",category="planning",interval=239,priority=82,budget=6,note="read-only safe fluid turret pipe route discovery and construction handoff",fn=function(_,budget)return M.service_all("broker",budget)end});return service~=nil
end
function M.install()M.root();_G.TechPriestsFluidTurretConnectionPlanner0719=M;if not register_service()then return false end;patch_diagnostics();if log then log("[Tech-Priests recovery] wrapper-free fluid turret route coordinator armed")end;return true end
return M
