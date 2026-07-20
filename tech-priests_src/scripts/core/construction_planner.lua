-- scripts/core/construction_planner.lua
-- Tech Priests 0.1.674-dev recovery.
-- Sole physical construction owner. Broker work is discovery only; the pure action
-- classifier recommends cached work and single_dispatcher_0510 alone executes it.

local M={version="0.1.674-dev",storage_key="construction_planner",discovery_interval=233,max_pairs_per_discovery=6,move_priority=968,move_ttl=60*12,reservation_ttl=60*20,request_timeout=60*20,pickup_reach_sq=2.56,build_reach_sq=4,return_reach_sq=2.56,dispatcher_owned=true,discovery_only_broker=true,positional_reservation=true,exact_item_custody=true}
local function now()return game and game.tick or 0 end
local function valid(e)return e and e.valid end
local function safe(v)if v==nil then return"nil"end;local ok,s=pcall(tostring,v);return ok and s or"?"end
local function valid_pair(p)return type(p)=="table"and valid(p.station)and valid(p.priest)end
local function station_unit(p)return p and(p.station_unit or(valid(p.station)and p.station.unit_number))or nil end
local function pair_map()return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or{}end
local function dist_sq(a,b)if not(a and b)then return math.huge end;local x=(a.x or 0)-(b.x or 0);local y=(a.y or 0)-(b.y or 0);return x*x+y*y end
function M.root()
 storage.tech_priests=storage.tech_priests or{};local r=storage.tech_priests[M.storage_key]or{version=M.version,enabled=true,dispatcher_owned=true,discovery_only_broker=true,positional_reservation=true,exact_item_custody=true,stats={},recent={},cursor=0};storage.tech_priests[M.storage_key]=r;r.version=M.version
 if r.enabled==nil then r.enabled=true end;r.dispatcher_owned=true;r.discovery_only_broker=true;r.positional_reservation=true;r.exact_item_custody=true;r.stats=r.stats or{};r.recent=r.recent or{};r.cursor=tonumber(r.cursor)or 0;return r
end
local function stat(k,n)local r=M.root();r.stats[k]=(tonumber(r.stats[k])or 0)+(tonumber(n)or 1)end
local function record(pair,action,detail)local r=M.root();local ev={tick=now(),station=safe(station_unit(pair)),action=tostring(action or"event"),detail=tostring(detail or"")};r.recent[#r.recent+1]=ev;while #r.recent>160 do table.remove(r.recent,1)end;if pair then pair.construction_last_event_0338=ev end end
local function site_planner()return rawget(_G,"TECH_PRIESTS_CONSTRUCTION_SITE_PLANNER_0359")or package.loaded["scripts.core.construction_site_planner"]end
local function storage_authority()return rawget(_G,"TechPriestsStorageRoleAuthority0686")or package.loaded["scripts.core.storage_role_authority_0686"]end
local function reservations_module()
 local r=rawget(_G,"TechPriestsWorkReservations0601")or package.loaded["scripts.core.work_reservations"];if not r then local ok,m=pcall(require,"scripts.core.work_reservations");if ok then r=m end end;return r
end
local function ensure_reservation_category()
 local r=reservations_module();if not r then return nil end;local category="construction-placement";local found=false;for _,v in ipairs(r.categories or{})do if v==category then found=true break end end;if not found then r.categories=r.categories or{};r.categories[#r.categories+1]=category end
 local state=type(r.root)=="function"and r.root()or nil;if state then state.reservations=state.reservations or{};state.reservations[category]=state.reservations[category]or{}end;return r
end
local function position_target(pair,pos)return{position={x=pos.x,y=pos.y},surface_index=pair.station.surface.index,force_index=pair.station.force.index}end
local function claim_site(pair,task)
 local r=ensure_reservation_category();if not(r and type(r.claim)=="function"and task.position)then return false,"reservation-unavailable"end;task.reservation_target=position_target(pair,task.position)
 local ok,why=r.claim("construction-placement",task.reservation_target,pair,M.reservation_ttl,{surface_index=pair.station.surface.index,force_index=pair.station.force.index,family="construction",entity_name=task.entity_name,item=task.item_name,source="construction-planner-0338"});task.reserved_0338=ok==true;return ok==true,why
end
local function release_site(pair,task)
 if not(task and task.reservation_target)then return false end;local r=reservations_module();if r and type(r.release)=="function"then local ok,v=pcall(r.release,"construction-placement",task.reservation_target,pair);return ok and v==true end;return false
end
local function request_move_position(pair,pos,reason,radius)
 if not(valid_pair(pair)and pos)then return false end;local f=rawget(_G,"tech_priests_request_movement_0418");if type(f)~="function"then return false end
 local ok,accepted=pcall(f,pair,pos,reason,{owner="construction-planner-0338",priority=M.move_priority,ttl=M.move_ttl,radius=radius or 1.5,distraction=defines and defines.distraction and defines.distraction.none or nil});return ok and accepted==true
end
local function request_move(pair,target,reason)return valid(target)and request_move_position(pair,target.position,reason,1.5)or false end
local function item_count(inv,item)if not(inv and inv.valid and item)then return 0 end;local ok,n=pcall(inv.get_item_count,inv,item);return ok and(tonumber(n)or 0)or 0 end
local function remove_item(inv,item,count)if not(inv and inv.valid and item and(tonumber(count)or 0)>0)then return 0 end;local ok,n=pcall(inv.remove,inv,{name=item,count=count});return ok and(tonumber(n)or 0)or 0 end
local function insert_item(inv,item,count)if not(inv and inv.valid and item and(tonumber(count)or 0)>0)then return 0 end;local ok,n=pcall(inv.insert,inv,{name=item,count=count});return ok and(tonumber(n)or 0)or 0 end
local function generic_source_allowed(pair,src)
 local e=src and src.entity;local inv=src and src.inv;if not(inv and inv.valid and valid(e))then return false end;if e.surface~=pair.station.surface or e.force~=pair.station.force then return false end;if e==pair.station then return true end;return e.type=="container"or e.type=="logistic-container"or e.type=="car"or e.type=="spider-vehicle"
end
local function home_sources(pair)
 local out,seen={},{};local function add(src)if not generic_source_allowed(pair,src)then return end;local key=safe(src.inv);if seen[key]then return end;seen[key]=true;out[#out+1]={inv=src.inv,entity=src.entity,label=src.source or src.inventory_id or"generic-home-source"}end
 local a=storage_authority();if a and type(a.generic_station_inventories)=="function"then local ok,sources=pcall(a.generic_station_inventories,pair);if ok and type(sources)=="table"then for _,src in ipairs(sources)do add(src)end end end
 local steward=rawget(_G,"tech_priests_inventory_steward_sources_for_pair");if type(steward)=="function"then local ok,sources=pcall(steward,pair);if ok and type(sources)=="table"then for _,src in ipairs(sources)do add(src)end end end;return out
end
local function source_for_item(pair,item)
 local best;for _,src in ipairs(home_sources(pair))do local count=item_count(src.inv,item);if count>0 then local score=dist_sq(pair.priest.position,src.entity.position)-math.min(count,100);if not best or score<best.score then best={item_name=item,count=count,inv=src.inv,entity=src.entity,label=src.label,score=score}end end end;return best
end
local function entity_exists(name)return type(name)=="string"and name~=""and prototypes and prototypes.entity and prototypes.entity[name]~=nil end
local function item_exists(name)return type(name)=="string"and name~=""and prototypes and prototypes.item and prototypes.item[name]~=nil end
local function place_result(item_name)local item=item_exists(item_name)and prototypes.item[item_name]or nil;local result;if item then pcall(function()result=item.place_result end)end;return result and result.name or nil end
local function item_for_entity(entity_name)
 if not entity_exists(entity_name)then return nil end;local policy=rawget(_G,"TechPriestsPlanningConstraints0646")or package.loaded["scripts.core.planning_constraints_0646"];if policy and type(policy.item_for_entity)=="function"then local ok,item=pcall(policy.item_for_entity,entity_name);if ok and item then return item end end
 for name,item in pairs(prototypes and prototypes.item or{})do local result;pcall(function()result=item.place_result end);if result and result.name==entity_name then return name end end;return nil
end
local function entity_type(name)local p=entity_exists(name)and prototypes.entity[name]or nil;local typ;if p then pcall(function()typ=p.type end)end;return typ end
local function category_for(entity_name,requested)
 local typ=entity_type(entity_name);if requested and requested~=""and requested~="generic"then return requested end;if typ=="mining-drill"then return"miner"end;if typ=="furnace"then return"furnace"end;if typ=="assembling-machine"then return"assembler"end;if typ=="container"or typ=="logistic-container"then return"storage"end;if typ=="lab"then return"lab"end;if typ=="electric-pole"then return"emergency-power-pole"end;if typ=="roboport"then return"defense-roboport"end;if typ=="wall"or typ=="gate"then return"defense-wall"end;if typ=="artillery-turret"then return"defense-artillery"end;if typ=="ammo-turret"or typ=="electric-turret"or typ=="fluid-turret"then return"defense-turret"end;if typ=="radar"then return"defense-radar"end;if typ=="land-mine"then return"defense-mine"end;return"generic"
end
local function normalize_placeable(v)
 if type(v)=="string"then if item_exists(v)then local e=place_result(v);return e and{item_name=v,entity_name=e,category=category_for(e)}or nil end;if entity_exists(v)then local item=item_for_entity(v);return item and{item_name=item,entity_name=v,category=category_for(v)}or nil end;return nil end
 if type(v)~="table"then return nil end;local item=v.item_name or v.item or v.name;local entity=v.entity_name or v.entity or v.place_result;if entity and type(entity)=="table"then entity=entity.name end;if not entity and item then entity=place_result(item)end;if not item and entity then item=item_for_entity(entity)end;if not(item_exists(item)and entity_exists(entity))then return nil end;return{item_name=item,entity_name=entity,category=category_for(entity,v.category or v.class),source=v.source,direction=v.direction}
end
local request_fields={"structure_construction_requested_item","construction_requested_item","construction_request","pending_construction","build_request"}
local function bootstrap_request(pair)
 local rec=pair and pair.construction_bootstrap_ghost_0645;if type(rec)~="table"then return nil end;local ghost=valid(rec.ghost)and rec.ghost or nil;if not ghost and rec.position and valid_pair(pair)then local ok,e=pcall(pair.station.surface.find_entity,pair.station.surface,"entity-ghost",rec.position);if ok and valid(e)then ghost=e end end
 local placeable=normalize_placeable({item_name=rec.item,entity_name=rec.entity_name,category=rec.category or rec.class,source="construction-bootstrap-ghost-0645",direction=rec.direction});if not placeable or not rec.position then return nil end;return{field="construction_bootstrap_ghost_0645",value=rec,placeable=placeable,position={x=rec.position.x,y=rec.position.y},ghost=ghost,site_reason="bootstrap-ghost",effectiveness=rec.effectiveness}
end
local function construction_request(pair)
 local b=bootstrap_request(pair);if b then return b end;for _,field in ipairs(request_fields)do local value=pair[field];if value~=nil then local p=normalize_placeable(value);if p then return{field=field,value=value,placeable=p,position=type(value)=="table"and(value.position or value.site_position)or nil,site_reason=type(value)=="table"and value.site_reason or nil}end end end
 local legacy=pair.construction_task;if type(legacy)=="table"and legacy.item_name and legacy.entity_name then local p=normalize_placeable(legacy);if p then return{field="construction_task",value=legacy,placeable=p,position=legacy.site_position,site_reason=legacy.site_reason or"legacy-task-recovery"}end end;return nil
end
local function clear_request(pair,task)
 local field=task and task.request_field;if not field then return end;if field=="construction_bootstrap_ghost_0645"then if type(pair[field])=="table"then pair[field].status="built";pair[field].completed_tick=now()end;pair[field]=nil elseif pair[field]==task.request_value then pair[field]=nil end;if field=="construction_task"then pair.construction_task=nil end
end
local function plan_request(pair,request)
 if request.position then local planner=site_planner();local report;if planner and type(planner.placement_effectiveness_report)=="function"and tostring(request.placeable.category or""):find("defense",1,true)then local ok,r,why=pcall(planner.placement_effectiveness_report,pair,request.placeable.entity_name,request.position,request.placeable.category);if not(ok and r)then return nil,ok and(why or"ineffective-fixed-defense-site")or("site-effectiveness-error:"..safe(r))end;report=r end;return request.position,request.site_reason or"fixed-request-site",report end
 local planner=site_planner();if not(planner and type(planner.plan_site)=="function")then return nil,"site-planner-unavailable"end;local ok,pos,why,report=pcall(planner.plan_site,pair,request.placeable);if not ok then return nil,"site-planner-error:"..safe(pos)end;return pos,why,report
end
function M.discover_pair(pair,force)
 local state=M.root();if state.enabled==false or not valid_pair(pair)then return nil end;if pair.construction_task_0338 or pair.construction_custody_0338 then return pair.construction_candidate_0338 end;if not force and now()<(tonumber(pair.construction_cooldown_0338)or 0)then return pair.construction_candidate_0338 end
 local request=construction_request(pair);if not request then pair.construction_candidate_0338=nil;return nil end;local pos,why,effect=plan_request(pair,request);if not pos then pair.construction_candidate_0338=nil;pair.construction_blocked_reason_0338=why;pair.construction_cooldown_0338=now()+180;record(pair,"site-blocked",why);return nil end
 local c={version=M.version,tick=now(),item_name=request.placeable.item_name,entity_name=request.placeable.entity_name,category=request.placeable.category,position={x=pos.x,y=pos.y},direction=request.placeable.direction,site_reason=why,effectiveness=effect,request_field=request.field,request_value=request.value,ghost=request.ghost,source="construction-planner-0338"};pair.construction_candidate_0338=c;pair.construction_blocked_reason_0338=nil;stat("candidates-discovered");return c
end
function M.recommend_action(pair)
 if not pair then return nil end;local task=pair.construction_task_0338;local custody=pair.construction_custody_0338;local candidate=pair.construction_candidate_0338;local v=task or custody or candidate;if not v then return nil end;return{kind="construction",family="construction",target=valid(v.ghost)and v.ghost or nil,position=v.position,item=v.item_name or v.item,phase=v.phase or(task and task.phase)or"candidate",source="construction-planner-0338",reason=v.site_reason or v.reason or"construction-request",active=task~=nil or custody~=nil}
end
local function sync_custody(pair,task,reason)
 local carried=task and task.carried;if carried and carried.item_name and(tonumber(carried.count)or 0)>0 then pair.construction_custody_0338={version=M.version,tick=now(),phase="removed-not-built",item_name=carried.item_name,count=carried.count,entity_name=task.entity_name,category=task.category,position=task.position,direction=task.direction,source_entity=task.source_entity,source_inv=task.source_inv,source_label=task.source_label,request_field=task.request_field,request_value=task.request_value,reason=reason or task.phase};return true end;pair.construction_custody_0338=nil;return false
end
local function finish(pair,task,built,reason)
 release_site(pair,task);if built then clear_request(pair,task)end;pair.construction_candidate_0338=nil;pair.construction_custody_0338=nil;pair.construction_task_0338=nil;pair.construction_task=nil;pair.construction_cooldown_0338=now()+(built and 90 or 180);task.phase=built and"complete"or"aborted";task.completed_tick=now();task.result=reason;task.built_entity=built;pair.construction_last_task_0338=task;record(pair,built and"built"or"aborted",reason);return{processed=1,acted=built and 1 or 0,blocked=built and 0 or 1,detail=reason}
end
local function deposit_exact(pair,item,count,reason)local a=storage_authority();if a and type(a.deposit_exact)=="function"then return a.deposit_exact(pair,item,count,reason,{})end;return false,"storage-authority-unavailable",0 end
local function return_custody(pair,task)
 local carried=task.carried;if not(carried and carried.item_name and(tonumber(carried.count)or 0)>0)then return finish(pair,task,false,"empty-custody")end
 if valid(task.source_entity)and task.source_inv and task.source_inv.valid then
  if dist_sq(pair.priest.position,task.source_entity.position)>M.return_reach_sq then task.phase="return-custody";sync_custody(pair,task,"returning-source");if not request_move(pair,task.source_entity,"construction-custody-source-return-0338")then return{processed=1,blocked=1,detail="source-return-movement-blocked"}end;return{processed=1,waiting=1,detail="returning-source-custody"}end
  local inserted=insert_item(task.source_inv,carried.item_name,carried.count);carried.count=carried.count-inserted;if carried.count<=0 then return finish(pair,task,false,"custody-returned-source")end;task.source_entity=nil;task.source_inv=nil;sync_custody(pair,task,"source-return-partial")
 end
 if dist_sq(pair.priest.position,pair.station.position)>M.return_reach_sq then task.phase="return-custody";sync_custody(pair,task,"returning-station");if not request_move(pair,pair.station,"construction-custody-station-return-0338")then return{processed=1,blocked=1,detail="station-return-movement-blocked"}end;return{processed=1,waiting=1,detail="returning-station-custody"}end
 local accepted,why,inserted=deposit_exact(pair,carried.item_name,carried.count,"construction-custody-return-0338");inserted=tonumber(inserted)or 0;carried.count=carried.count-inserted;if accepted==true and carried.count<=0 then return finish(pair,task,false,"custody-stored")end;sync_custody(pair,task,"storage-blocked");return{processed=1,blocked=1,detail="storage-blocked:"..safe(why)}
end
local function begin_task(pair,c)
 local task={version=M.version,phase="waiting-source",item_name=c.item_name,entity_name=c.entity_name,category=c.category,position={x=c.position.x,y=c.position.y},direction=c.direction,site_reason=c.site_reason,effectiveness=c.effectiveness,request_field=c.request_field,request_value=c.request_value,ghost=c.ghost,started_tick=now()};local ok,why=claim_site(pair,task);if not ok then return nil,why end;pair.construction_task_0338=task;return task
end
local function restore_orphan_custody(pair)
 if pair.construction_task_0338 or type(pair.construction_custody_0338)~="table"then return false end;local c=pair.construction_custody_0338;if not(c.item_name and(tonumber(c.count)or 0)>0)then return false end;pair.construction_task_0338={version=M.version,phase="return-custody",item_name=c.item_name,entity_name=c.entity_name,category=c.category,position=c.position,direction=c.direction,carried={item_name=c.item_name,count=c.count},source_entity=c.source_entity,source_inv=c.source_inv,source_label=c.source_label,request_field=c.request_field,request_value=c.request_value,started_tick=now(),custody_recovery=true};record(pair,"orphan-custody-restored",c.item_name);return true
end
local function site_still_valid(pair,task)
 if valid(task.ghost)then return true,"matching-ghost"end;local planner=site_planner();if planner and type(planner.placement_effectiveness_report)=="function"and tostring(task.category or""):find("defense",1,true)then local ok,report,why=pcall(planner.placement_effectiveness_report,pair,task.entity_name,task.position,task.category);if ok and report then task.effectiveness=report;return true,"effectiveness-revalidated"end;return false,ok and(why or"ineffective-defense-site")or("effectiveness-error:"..safe(report))end
 local ok,can=pcall(pair.station.surface.can_place_entity,pair.station.surface,{name=task.entity_name,position=task.position,force=pair.station.force,direction=task.direction});return ok and can==true,ok and"engine-revalidated"or"engine-check-failed"
end
local function create_entity(pair,task)
 if valid(task.ghost)then local ok,a,b=pcall(task.ghost.revive,task.ghost,{raise_revive=true});local entity=valid(a)and a or valid(b)and b or nil;if ok and entity then return entity,"ghost-revived"end end
 local ok,e=pcall(pair.station.surface.create_entity,pair.station.surface,{name=task.entity_name,position=task.position,force=pair.station.force,direction=task.direction,raise_built=true});if ok and valid(e)then return e,"entity-created"end;return nil,ok and"create-refused"or"create-error:"..safe(e)
end
function M.abort_pair(pair,reason)local task=pair and pair.construction_task_0338;if not task then return{processed=0,detail="no-task"}end;if sync_custody(pair,task,reason)then task.phase="return-custody";return return_custody(pair,task)end;return finish(pair,task,false,reason or"aborted")end
function M.service_pair(pair,reason)
 local state=M.root();if state.enabled==false or not valid_pair(pair)then return{processed=0,failed=not valid_pair(pair)and 1 or 0,detail="disabled-or-invalid"}end;restore_orphan_custody(pair);local task=pair.construction_task_0338
 if valid(pair.combat_target)then if task and task.carried then task.phase="return-custody";sync_custody(pair,task,"combat-interrupted");return return_custody(pair,task)elseif task then return M.abort_pair(pair,"combat-priority")else return{processed=1,blocked=1,detail="combat-priority"}end end
 if not task then local c=pair.construction_candidate_0338 or M.discover_pair(pair,true);if not c then return{processed=1,waiting=1,detail="no-candidate"}end;local why;task,why=begin_task(pair,c);if not task then return{processed=1,blocked=1,detail="reservation-blocked:"..safe(why)}end end
 if task.phase=="return-custody"then return return_custody(pair,task)end;if now()-(tonumber(task.started_tick)or now())>M.request_timeout then return M.abort_pair(pair,"construction-timeout")end
 if task.phase=="waiting-source"then local source=source_for_item(pair,task.item_name);if not source then return{processed=1,waiting=1,detail="waiting-source"}end;task.source_entity=source.entity;task.source_inv=source.inv;task.source_label=source.label;task.phase="move-source"end
 if task.phase=="move-source"then if not valid(task.source_entity)then return M.abort_pair(pair,"source-invalid")end;if dist_sq(pair.priest.position,task.source_entity.position)>M.pickup_reach_sq then if not request_move(pair,task.source_entity,"construction-source-0338")then return{processed=1,blocked=1,detail="source-movement-blocked"}end;return{processed=1,waiting=1,detail="moving-source"}end;task.phase="pickup"end
 if task.phase=="pickup"then local removed=remove_item(task.source_inv,task.item_name,1);if removed~=1 then return M.abort_pair(pair,"source-remove-failed")end;task.carried={item_name=task.item_name,count=1};sync_custody(pair,task,"removed-source");task.phase="move-site"end
 if task.phase=="move-site"then if dist_sq(pair.priest.position,task.position)>M.build_reach_sq then if not request_move_position(pair,task.position,"construction-site-0338",1.75)then task.phase="return-custody";return return_custody(pair,task)end;return{processed=1,waiting=1,detail="moving-site"}end;task.phase="build"end
 if task.phase=="build"then local ok,why=site_still_valid(pair,task);if not ok then task.phase="return-custody";sync_custody(pair,task,"site-invalid:"..safe(why));return return_custody(pair,task)end;local built,build_why=create_entity(pair,task);if not built then task.phase="return-custody";sync_custody(pair,task,build_why);return return_custody(pair,task)end;task.carried.count=0;pair.construction_custody_0338=nil;stat("entities-built");return finish(pair,task,built,build_why)end
 return{processed=1,failed=1,detail="unknown-phase:"..safe(task.phase)}
end
function M.service_all(reason,budget)
 local list={};for key,pair in pairs(pair_map())do if valid_pair(pair)then list[#list+1]={key=tostring(key),pair=pair}end end;table.sort(list,function(a,b)return a.key<b.key end);local state=M.root();local limit=math.min(#list,math.max(0,math.floor(tonumber(budget)or M.max_pairs_per_discovery)));if limit==0 then return{processed=0,acted=0,detail="no-pairs"}end;local start=state.cursor%#list+1;local failed=0;for offset=0,limit-1 do local pair=list[((start+offset-1)%#list)+1].pair;local ok=pcall(M.discover_pair,pair,false);if not ok then failed=failed+1 end end;state.cursor=(start+limit-2)%#list+1;return{processed=limit,acted=0,failed=failed,exhausted=#list>limit,detail="pairs="..limit.." failed="..failed}
end
function M.describe_pair(pair)if not pair then return"No pair."end;local task=pair.construction_task_0338;if task then return"Construction "..safe(task.entity_name).." phase="..safe(task.phase).." site="..safe(task.position and(task.position.x..","..task.position.y))end;local c=pair.construction_candidate_0338;if c then return"Construction candidate "..safe(c.entity_name).." reason="..safe(c.site_reason)end;return"No construction work."end
local function canonical_broker()
 local broker=rawget(_G,"TechPriestsRuntimeTickBroker0600")or package.loaded["scripts.core.runtime_tick_broker"];if not broker then local ok,m=pcall(require,"scripts.core.runtime_tick_broker");if not ok then return nil end;broker=m end;if not(broker and type(broker.install)=="function")then return nil end;local ok,installed=pcall(broker.install);if not(ok and installed==true)then return nil end;return broker
end
local function register_service()
 local broker=canonical_broker();if not(broker and type(broker.register_service)=="function")then return false end;local service=broker.register_service({name="construction_discovery_0338",category="construction",interval=M.discovery_interval,priority=58,budget=M.max_pairs_per_discovery,note="discovery only; dispatcher owns physical construction",fn=function(_,budget)return M.service_all("broker-discovery",budget)end});return service~=nil
end
function M.install()M.root();_G.TechPriestsConstructionPlanner0338=M;_G.TECH_PRIESTS_CONSTRUCTION_PLANNER=M;if not register_service()then return false end;if log then log("[Tech-Priests recovery] dispatcher-owned construction planner armed; defense effectiveness and exact custody enabled")end;return true end
return M
