-- scripts/core/construction_planner.lua
-- Tech Priests 0.1.674-dev recovery.
-- Sole physical construction owner. Broker work is discovery only; the pure action
-- classifier recommends cached work and single_dispatcher_0510 alone executes it.

local M={version="0.1.674-dev",storage_key="construction_planner",discovery_interval=233,max_pairs_per_discovery=6,move_priority=968,move_ttl=60*12,reservation_ttl=60*20,request_timeout=60*20,travel_ticks_per_tile=20,max_travel_extra_ticks=60*120,pickup_reach_sq=2.56,build_reach_sq=4,return_reach_sq=2.56,dispatcher_owned=true,discovery_only_broker=true,positional_reservation=true,exact_item_custody=true}
local function now()return game and game.tick or 0 end
local function valid(e)return e and e.valid end
local function safe(v)if v==nil then return"nil"end;local ok,s=pcall(tostring,v);return ok and s or"?"end
local function valid_pair(p)return type(p)=="table"and valid(p.station)and valid(p.priest)end
local function station_unit(p)return p and(p.station_unit or(valid(p.station)and p.station.unit_number))or nil end
local function pair_map()return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or{}end
local function dist_sq(a,b)if not(a and b)then return math.huge end;local x=(a.x or 0)-(b.x or 0);local y=(a.y or 0)-(b.y or 0);return x*x+y*y end
local function within_entity_reach(position,entity,limit_sq)
 if not(position and valid(entity))then return false end
 -- Factorio reports the entity box in world coordinates. A priest beside a
 -- large station can legitimately reach its inventory while remaining more
 -- than one tile from the station's center.
 local ok,box=pcall(function()return entity.selection_box or entity.bounding_box end)
 if ok and box then
  local lt=box.left_top or box[1];local rb=box.right_bottom or box[2]
  if lt and rb and type(lt.x)=="number"and type(lt.y)=="number"
   and type(rb.x)=="number"and type(rb.y)=="number"then
   local x=math.max(math.min(lt.x,rb.x),math.min(math.max(lt.x,rb.x),position.x))
   local y=math.max(math.min(lt.y,rb.y),math.min(math.max(lt.y,rb.y),position.y))
   return dist_sq(position,{x=x,y=y})<=limit_sq
  end
 end
 return dist_sq(position,entity.position)<=limit_sq
end
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
local function source_approach_position(pair,entity,margin,avoid_station)
 if not(valid_pair(pair)and valid(entity))then return nil end
 local ok,box=pcall(function()return entity.selection_box end)
 if not(ok and box)then
  ok,box=pcall(function()return entity.bounding_box end)
 end
 if not(ok and box)then return entity.position end
 local lt=box.left_top or box[1];local rb=box.right_bottom or box[2]
 if not(lt and rb and lt.x and lt.y and rb.x and rb.y)then return entity.position end
 local x0,x1=math.min(lt.x,rb.x),math.max(lt.x,rb.x)
 local y0,y1=math.min(lt.y,rb.y),math.max(lt.y,rb.y)
 local p=pair.priest.position
 local clamp=function(v,a,b)return math.max(a,math.min(b,v))end
 -- The center of a multi-tile station cannot be entered. Request a reachable
 -- external service point at the closest side, inside inventory reach.
 local gap=math.max(0.3,tonumber(margin)or 0.6)
 local points={
  {x=x0-gap,y=clamp(p.y,y0,y1)},
  {x=x1+gap,y=clamp(p.y,y0,y1)},
  {x=clamp(p.x,x0,x1),y=y0-gap},
  {x=clamp(p.x,x0,x1),y=y1+gap},
 }
 local best,score=nil,math.huge
 for _,point in ipairs(points)do
  -- Ghost retry standoffs must be on the exterior side of the building,
  -- away from the Cogitator footprint. Choosing the closest point to the
  -- priest can lead straight into the station's impassable collision box.
  local d=avoid_station and -dist_sq(pair.station.position,point)
    or dist_sq(p,point)
  if d<score then best=point;score=d end
 end
 return best
end
local function request_move(pair,target,reason)
 if not valid(target)then return false end
 local dest=source_approach_position(pair,target)
 return request_move_position(pair,dest or target.position,reason,dest and 0.5 or 1.5)
end
local function item_count(inv,item)if not(inv and inv.valid and item)then return 0 end;local ok,n=pcall(function()return inv.get_item_count(item)end);return ok and(tonumber(n)or 0)or 0 end
local function remove_item(inv,item,count)if not(inv and inv.valid and item and(tonumber(count)or 0)>0)then return 0 end;local ok,n=pcall(function()return inv.remove({name=item,count=count})end);return ok and(tonumber(n)or 0)or 0 end
local function insert_item(inv,item,count)if not(inv and inv.valid and item and(tonumber(count)or 0)>0)then return 0 end;local ok,n=pcall(function()return inv.insert({name=item,count=count})end);return ok and(tonumber(n)or 0)or 0 end
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
 -- Remote ore demand takes priority over UNSTARTED routine construction.
 -- The original request and station ghost remain queued for later.
 local remote=pair.remote_drill_request_1011
 if remote~=nil then
  local p=normalize_placeable(remote)
  if not(type(remote)=="table" and p
    and remote.remote_drill_terminal_1011==station_unit(pair)
    and (remote.item_name=="burner-mining-drill"
      or remote.item_name=="wooden-chest")) then return nil end
  return{field="remote_drill_request_1011",value=remote,
    placeable=p,position=remote.position,
    site_reason=remote.site_reason}
 end
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
-- Only an unfunded waiting-source task may yield to the resource mission.
-- Release its site reservation; retain the original request and never
-- preempt an item already carried or held under 0338 custody.
local function defer_unfunded_for_remote(pair)
 local task=pair.construction_task_0338
 local priority=pair.remote_drill_request_1011
 if not(priority and task and task.request_value~=priority
   and task.phase=="waiting-source" and not task.carried
   and not pair.construction_custody_0338
   and not source_for_item(pair,task.item_name)) then return false end
 if task.reserved_0338 and not release_site(pair,task) then return false end
 pair.construction_task_0338=nil
 pair.construction_candidate_0338=nil
 stat("unfunded_construction_deferred_for_remote")
 record(pair,"unfunded-deferred-for-remote",task.item_name)
 return true
end
function M.discover_pair(pair,force)
 local state=M.root();if state.enabled==false or not valid_pair(pair)then return nil end
 defer_unfunded_for_remote(pair)
 if pair.construction_task_0338 or pair.construction_custody_0338 then return pair.construction_candidate_0338 end
 local priority=pair.remote_drill_request_1011
 if priority and (not pair.construction_candidate_0338
   or pair.construction_candidate_0338.request_value~=priority) then
  pair.construction_candidate_0338=nil
  force=true
 end
 if not force and now()<(tonumber(pair.construction_cooldown_0338)or 0)then return pair.construction_candidate_0338 end
 local request=construction_request(pair);if not request then pair.construction_candidate_0338=nil;return nil end;local pos,why,effect=plan_request(pair,request);if not pos then pair.construction_candidate_0338=nil;pair.construction_blocked_reason_0338=why;pair.construction_cooldown_0338=now()+180;record(pair,"site-blocked",why);return nil end
 local c={version=M.version,tick=now(),item_name=request.placeable.item_name,entity_name=request.placeable.entity_name,category=request.placeable.category,position={x=pos.x,y=pos.y},direction=request.placeable.direction,site_reason=why,effectiveness=effect,request_field=request.field,request_value=request.value,ghost=request.ghost,source="construction-planner-0338"};pair.construction_candidate_0338=c;pair.construction_blocked_reason_0338=nil;stat("candidates-discovered");return c
end
function M.recommend_action(pair)
 if not pair then return nil end;local task=pair.construction_task_0338;local custody=pair.construction_custody_0338;local candidate=pair.construction_candidate_0338;local v=task or custody or candidate;if not v then return nil end;-- Do not monopolize the sole action dispatcher while a requested item has not yet been produced.
 if task and task.phase=="waiting-source" and not source_for_item(pair,task.item_name) then return nil end
 if not task and not custody and candidate and not source_for_item(pair,candidate.item_name) then return nil end
 return{kind="construction",family="construction",target=valid(v.ghost)and v.ghost or nil,position=v.position,item=v.item_name or v.item,phase=v.phase or(task and task.phase)or"candidate",source="construction-planner-0338",reason=v.site_reason or v.reason or"construction-request",active=task~=nil or custody~=nil}
end
local function sync_custody(pair,task,reason)
 local carried=task and task.carried;if carried and carried.item_name and(tonumber(carried.count)or 0)>0 then pair.construction_custody_0338={version=M.version,tick=now(),phase="removed-not-built",item_name=carried.item_name,count=carried.count,entity_name=task.entity_name,category=task.category,position=task.position,direction=task.direction,source_entity=task.source_entity,source_inv=task.source_inv,source_label=task.source_label,request_field=task.request_field,request_value=task.request_value,reason=reason or task.phase};return true end;pair.construction_custody_0338=nil;return false
end
local function release_terminal_movement(pair)
 -- A high-priority construction route is valid only while this pair still
 -- owns a physical construction task. Terminal cleanup must free it so the
 -- next material acquisition is not denied for the remainder of a 720-tick
 -- movement lease. Never stop combat, rescue or another family's route.
 local controller=rawget(_G,"TECH_PRIESTS_MOVEMENT_CONTROLLER_0418")
 if not(controller and type(controller.request_status)=="function"
   and type(controller.stop)=="function")then return false end
 local ok,status=pcall(controller.request_status,pair)
 if not(ok and type(status)=="table" and status.active==true
   and status.owner=="construction-planner-0338")then return false end
 local stopped,accepted=pcall(controller.stop,pair,"construction-terminal-handoff-0338")
 if stopped and accepted==true then
  stat("terminal_movement_released")
  return true
 end
 stat("terminal_movement_release_failed")
 return false
end
local function finish(pair,task,built,reason)
 release_terminal_movement(pair)
 release_site(pair,task)
 if built then clear_request(pair,task)end
 pair.construction_candidate_0338=nil
 pair.construction_custody_0338=nil
 pair.construction_task_0338=nil
 pair.construction_task=nil
 pair.construction_cooldown_0338=now()+(built and 90 or 180)
 task.phase=built and "complete" or "aborted"
 task.completed_tick=now()
 task.result=reason
 task.built_entity=built
 pair.construction_last_task_0338=task
 record(pair,built and "built" or "aborted",reason)
 if not built and task.request_field=="construction_bootstrap_ghost_0645"
   and type(reason)=="string"
   and reason:find("^site%-invalid:occupied%-by%-physical%-entity:")
   and (not task.carried or (tonumber(task.carried.count)or 0)<=0) then
  -- The carried machine was physically refunded before finish() ran.
  -- Replan immediately now that no task/custody owns the obsolete ghost.
  -- Never discard a live machine or wait for a later planning pulse just
  -- to retire a site already obstructed by real infrastructure.
  local planner=rawget(_G,"TechPriestsConstructionBootstrapGhostPlanner0645")
    or package.loaded["scripts.core.construction_bootstrap_ghost_planner_0645"]
  if planner and type(planner.service_pair)=="function"then
   local ok,changed=pcall(planner.service_pair,pair,"construction-obstruction-refunded-0338")
   if ok and changed==true then
    pair.construction_cooldown_0338=now()+60
    stat("occupied-sites-replanned-after-refund")
   end
  end
 end
 return{processed=1,acted=built and 1 or 0,blocked=built and 0 or 1,detail=reason}
end
local function deposit_exact(pair,item,count,reason)local a=storage_authority();if a and type(a.deposit_exact)=="function"then return a.deposit_exact(pair,item,count,reason,{})end;return false,"storage-authority-unavailable",0 end
local function return_custody(pair,task)
 local failure=task.failure_reason_0338
 local carried=task.carried;if not(carried and carried.item_name and(tonumber(carried.count)or 0)>0)then return finish(pair,task,false,failure and (failure..";empty-custody") or "empty-custody")end
 if valid(task.source_entity)and task.source_inv and task.source_inv.valid then
  if not within_entity_reach(pair.priest.position,task.source_entity,M.return_reach_sq) then task.phase="return-custody";sync_custody(pair,task,"returning-source");if not request_move(pair,task.source_entity,"construction-custody-source-return-0338")then return{processed=1,blocked=1,detail="source-return-movement-blocked"}end;return{processed=1,waiting=1,detail="returning-source-custody"}end
  local inserted=insert_item(task.source_inv,carried.item_name,carried.count);carried.count=carried.count-inserted;if carried.count<=0 then return finish(pair,task,false,failure and (failure..";custody-returned-source") or "custody-returned-source")end;task.source_entity=nil;task.source_inv=nil;sync_custody(pair,task,"source-return-partial")
 end
 if not within_entity_reach(pair.priest.position,pair.station,M.return_reach_sq) then task.phase="return-custody";sync_custody(pair,task,"returning-station");if not request_move(pair,pair.station,"construction-custody-station-return-0338")then return{processed=1,blocked=1,detail="station-return-movement-blocked"}end;return{processed=1,waiting=1,detail="returning-station-custody"}end
 local accepted,why,inserted=deposit_exact(pair,carried.item_name,carried.count,"construction-custody-return-0338");inserted=tonumber(inserted)or 0;carried.count=carried.count-inserted;if accepted==true and carried.count<=0 then return finish(pair,task,false,failure and (failure..";custody-stored") or "custody-stored")end;sync_custody(pair,task,"storage-blocked");return{processed=1,blocked=1,detail="storage-blocked:"..safe(why)}
end
-- Explicit admin-only test setting; never inferred from frustration.
local function creative_enabled()
 local root=M.root()
 return root.creative_instant_build==true
end
local function register_creative_command()
 if not(commands and commands.add_command)then return false end
 if commands.commands and commands.commands["tp-creative-build"] then return true end
 commands.add_command("tp-creative-build","Admin test toggle: /tp-creative-build on|off|status",function(event)
  local player=event.player_index and game.get_player(event.player_index) or nil
  if player and (not player.valid or not player.admin) then
   player.print("[Tech-Priests] Administrator access required.")
   return
  end
  local mode=tostring(event.parameter or "status"):lower():match("^%s*(.-)%s*$")
  local root=M.root()
  if mode=="on"then root.creative_instant_build=true
  elseif mode=="off"then root.creative_instant_build=false
  elseif mode~="status"then
   if player then player.print("Usage: /tp-creative-build on|off|status")end
   return
  end
  local message="[Tech-Priests] Creative construction: "..(root.creative_instant_build and "ON" or "OFF")
  if player then player.print(message)elseif log then log(message)end
 end)
 return true
end
local function begin_task(pair,c)
 local task={version=M.version,phase="waiting-source",item_name=c.item_name,entity_name=c.entity_name,category=c.category,position={x=c.position.x,y=c.position.y},direction=c.direction,site_reason=c.site_reason,effectiveness=c.effectiveness,request_field=c.request_field,request_value=c.request_value,ghost=c.ghost,started_tick=now()};local ok,why=claim_site(pair,task);if not ok then return nil,why end;pair.construction_task_0338=task;return task
end
local function restore_orphan_custody(pair)
 if pair.construction_task_0338 or type(pair.construction_custody_0338)~="table"then return false end;local c=pair.construction_custody_0338;if not(c.item_name and(tonumber(c.count)or 0)>0)then return false end;pair.construction_task_0338={version=M.version,phase="return-custody",item_name=c.item_name,entity_name=c.entity_name,category=c.category,position=c.position,direction=c.direction,carried={item_name=c.item_name,count=c.count},source_entity=c.source_entity,source_inv=c.source_inv,source_label=c.source_label,request_field=c.request_field,request_value=c.request_value,started_tick=now(),custody_recovery=true};record(pair,"orphan-custody-restored",c.item_name);return true
end
local function site_still_valid(pair,task)
 if task.request_field=="construction_bootstrap_ghost_0645"
   and not valid(task.ghost) then
  local record=pair.construction_bootstrap_ghost_0645
  if type(record)=="table" and valid(record.ghost)
    and record.entity_name==task.entity_name
    and dist_sq(record.ghost.position,task.position)<=0.36 then
   -- A rebuilt reference is legitimate only at the same reserved site.
   task.ghost=record.ghost
  else
   -- The ghost may have been replaced at a different site. Return the
   -- already-carried physical item rather than reviving or constructing at
   -- a superseded position.
   return false,"obsolete-or-missing-bootstrap-ghost"
  end
 end
 if valid(task.ghost)then
  local ghost_planner=rawget(_G,"TechPriestsConstructionBootstrapGhostPlanner0645")
    or package.loaded["scripts.core.construction_bootstrap_ghost_planner_0645"]
  if ghost_planner and type(ghost_planner.physical_site_obstruction)=="function"then
   local ok,occupied,other=pcall(ghost_planner.physical_site_obstruction,pair,task.ghost)
   if ok and occupied then
    return false,"occupied-by-physical-entity:"..safe(other and other.name)
   end
  end
  return true,"matching-ghost"
 end
 local planner=site_planner();if planner and type(planner.placement_effectiveness_report)=="function"and tostring(task.category or""):find("defense",1,true)then local ok,report,why=pcall(planner.placement_effectiveness_report,pair,task.entity_name,task.position,task.category);if ok and report then task.effectiveness=report;return true,"effectiveness-revalidated"end;return false,ok and(why or"ineffective-defense-site")or("effectiveness-error:"..safe(report))end
 local ok,can=pcall(function()return pair.station.surface.can_place_entity({name=task.entity_name,position=task.position,force=pair.station.force,direction=task.direction})end);return ok and can==true,ok and"engine-revalidated"or"engine-check-failed"
end
-- Factorio can refuse an otherwise valid receiver tile when the builder
-- itself occupies that tile. This is only a physical standoff proposal:
-- the engine must still approve the empty site after the priest walks away.
local function non_ghost_standoff(pair,task)
 if not (valid_pair(pair) and task and task.position
     and dist_sq(pair.priest.position,task.position)<1.21) then return nil end
 local surface=pair.station.surface
 local offsets={{1.4,0},{-1.4,0},{0,1.4},{0,-1.4},
   {0.99,0.99},{0.99,-0.99},{-0.99,0.99},{-0.99,-0.99}}
 local best,score=nil,math.huge
 for _,offset in ipairs(offsets) do
  local pos={x=task.position.x+offset[1],y=task.position.y+offset[2]}
  local ok,clear=pcall(function()
   return surface.can_place_entity{
     name=pair.priest.name,position=pos,force=pair.station.force}
  end)
  if ok and clear==true then
   local d=dist_sq(pair.priest.position,pos)
   if d<score then best=pos;score=d end
  end
 end
 return best
end
local function matching_ghost(pair,task)
 local ghost=task.ghost
 if not valid(ghost) then return false,"ghost-invalid" end
 local ok,why=pcall(function()
  if ghost.name~="entity-ghost" then return "wrong-entity-type:"..safe(ghost.name) end
  if ghost.ghost_name~=task.entity_name then return "wrong-ghost-prototype:"..safe(ghost.ghost_name).."/"..safe(task.entity_name) end
  if ghost.surface~=pair.station.surface then return "wrong-surface" end
  if ghost.force~=pair.station.force then return "wrong-force:"..safe(ghost.force and ghost.force.name).."/"..safe(pair.station.force and pair.station.force.name) end
  -- The ghost's engine-normalized position is authoritative. Bootstrap records
  -- may contain the requested placement coordinate before entity snapping.
  -- Preserve the original site claim; reject only a ghost that has moved
  -- materially away from the requested site.
  if dist_sq(ghost.position,task.position)>4 then return "wrong-position" end
  return nil
 end)
 if not ok then return false,"ghost-validation-error:"..safe(why) end
 return why==nil,why
end
local function create_entity(pair,task)
 if valid(task.ghost)then
  local matches,mismatch=matching_ghost(pair,task);if not matches then return nil,"ghost-mismatch:"..safe(mismatch)end
  -- Factorio 2.0 revive returns collided items, revived entity, and optionally a proxy.
  local ok,collided,entity=pcall(function()return task.ghost.revive({raise_revive=true})end)
  if ok and valid(entity) and entity.name==task.entity_name
   and entity.force==pair.station.force and entity.surface==pair.station.surface then return entity,"ghost-revived"end
  -- A failed revival is not authorization to create through the ghost.
  return nil,ok and"ghost-revive-refused"or"ghost-revive-error:"..safe(collided)
 end
 local ok,e=pcall(function()return pair.station.surface.create_entity({name=task.entity_name,position=task.position,force=pair.station.force,direction=task.direction,raise_built=true})end)
 if ok and valid(e) and e.name==task.entity_name and e.force==pair.station.force then return e,"entity-created"end
 return nil,ok and"create-refused"or"create-error:"..safe(e)
end
function M.abort_pair(pair,reason)local task=pair and pair.construction_task_0338;if not task then return{processed=0,detail="no-task"}end;if sync_custody(pair,task,reason)then task.phase="return-custody";return return_custody(pair,task)end;return finish(pair,task,false,reason or"aborted")end
local function construction_active_timeout(pair,task)
 if not task or task.phase=="waiting-source" then return false end
 if not task.active_started_tick_0338 then
  -- A station may take minutes to manufacture the requested placeable.
  -- Start a finite travel deadline only once the physical source exists.
  local source=valid(task.source_entity)and task.source_entity.position or pair.station.position
  local site=task.position or source
  local distance=math.sqrt(dist_sq(pair.priest.position,source))
    +math.sqrt(dist_sq(source,site))
  task.active_started_tick_0338=now()
  task.travel_allowance_ticks_0338=math.min(M.max_travel_extra_ticks,
    math.ceil(distance*M.travel_ticks_per_tile))
 end
 return now()-task.active_started_tick_0338>
   M.request_timeout+(tonumber(task.travel_allowance_ticks_0338)or 0)
end
function M.service_pair(pair,reason)
 local state=M.root();if state.enabled==false or not valid_pair(pair)then return{processed=0,failed=not valid_pair(pair)and 1 or 0,detail="disabled-or-invalid"}end
 restore_orphan_custody(pair)
 defer_unfunded_for_remote(pair)
 local task=pair.construction_task_0338
 if valid(pair.combat_target)then if task and task.carried then task.phase="return-custody";sync_custody(pair,task,"combat-interrupted");return return_custody(pair,task)elseif task then return M.abort_pair(pair,"combat-priority")else return{processed=1,blocked=1,detail="combat-priority"}end end
 if not task then
  local priority=pair.remote_drill_request_1011
  local c=pair.construction_candidate_0338
  if priority and (not c or c.request_value~=priority) then c=nil end
  c=c or M.discover_pair(pair,true)
  if not c then return{processed=1,waiting=1,detail="no-candidate"}end
  local why;task,why=begin_task(pair,c)
  if not task then return{processed=1,blocked=1,detail="reservation-blocked:"..safe(why)}end
 end
 if task.phase=="return-custody"then return return_custody(pair,task)end
 if construction_active_timeout(pair,task)then
  -- A timed-out route still refunds the physical item, but the completed
  -- 0338 receipt must retain the actual timeout cause, not merely the
  -- generic custody-returned-source outcome.
  local why="construction-timeout:"..safe(task.phase)..":"..safe(task.item_name)
  task.failure_reason_0338=why
  return M.abort_pair(pair,why)
 end
 if task.phase=="waiting-source" and creative_enabled() then
  task.creative_build=true
  task.phase="move-site"
 end
 if task.phase=="waiting-source"then local source=source_for_item(pair,task.item_name);if not source then return{processed=1,waiting=1,detail="waiting-source"}end;task.source_entity=source.entity;task.source_inv=source.inv;task.source_label=source.label;task.phase="move-source"end
 if task.phase=="move-source"then if not valid(task.source_entity)then return M.abort_pair(pair,"source-invalid")end;if not within_entity_reach(pair.priest.position,task.source_entity,M.pickup_reach_sq) then if not request_move(pair,task.source_entity,"construction-source-0338")then return{processed=1,blocked=1,detail="source-movement-blocked"}end;return{processed=1,waiting=1,detail="moving-source"}end;task.phase="pickup"end
 if task.phase=="pickup"then local removed=remove_item(task.source_inv,task.item_name,1);if removed~=1 then return M.abort_pair(pair,"source-remove-failed")end;task.carried={item_name=task.item_name,count=1};sync_custody(pair,task,"removed-source");task.phase="move-site"end
 if task.phase=="move-site"then
  if dist_sq(pair.priest.position,task.position)>M.build_reach_sq then
   if not request_move_position(pair,task.position,"construction-site-0338",1.75)then
    -- Movement arbitration can temporarily refuse a new route even while
    -- the builder holds a real item. Keep the engine-owned source debit and
    -- its 0338 custody intact; retry until the existing finite travel
    -- deadline, when abort_pair physically returns the same item.
    task.movement_denials_0338=(tonumber(task.movement_denials_0338)or 0)+1
    sync_custody(pair,task,"construction-site-route-denied")
    return{processed=1,blocked=1,waiting=1,detail="construction-site-route-denied"}
   end
   task.movement_denials_0338=nil
   return{processed=1,waiting=1,detail="moving-site"}
  end
  task.phase="build"
 end
local function safely_clear_of_ghost(pair,ghost)
 if not (valid_pair(pair) and valid(ghost)) then return false end
 local ok,box=pcall(function()return ghost.selection_box end)
 if not(ok and box)then return false end
 local lt=box.left_top or box[1]
 local rb=box.right_bottom or box[2]
 if not(lt and rb and lt.x and lt.y and rb.x and rb.y)then return false end
 local p=pair.priest.position
 local dx=math.max(lt.x-p.x,0,p.x-rb.x)
 local dy=math.max(lt.y-p.y,0,p.y-rb.y)
 -- Clearance from the *world-space* footprint, plus actual build reach.
 -- A movement controller need not hit an arbitrarily precise waypoint if
 -- the priest is already far enough outside the ghost collision area.
 return dx*dx+dy*dy>=0.25
   and dist_sq(p,ghost.position)<=M.build_reach_sq
end
 if task.phase=="move-clear-site" then
  local stand=task.build_standoff_0338
  if not stand then task.failure_reason_0338="no-safe-build-standoff";task.phase="return-custody";return return_custody(pair,task)end
  if not valid(task.ghost) then
   local d=dist_sq(pair.priest.position,task.position)
   if d<1.21 or d>M.build_reach_sq then
    if not request_move_position(pair,stand,"construction-clear-occupied-site-0338",0.3) then
     -- Keep the real carried item and retry only within the bounded site
     -- obstruction deadline. A refused movement is not permission to build.
     sync_custody(pair,task,"site-clear-route-denied")
     return{processed=1,waiting=1,blocked=1,detail="site-clear-route-denied"}
    end
    return{processed=1,waiting=1,detail="clearing-occupied-site"}
   end
  elseif not safely_clear_of_ghost(pair,task.ghost) and dist_sq(pair.priest.position,stand)>0.16 then
   if not request_move_position(pair,stand,"construction-clear-ghost-footprint-0338",0.3) then
    task.failure_reason_0338="build-standoff-movement-blocked";task.phase="return-custody"
    return return_custody(pair,task)
   end
   return{processed=1,waiting=1,detail="clearing-build-footprint"}
  end
  task.phase="build"
 end
 if task.phase=="build"then
  local ok,why=site_still_valid(pair,task)
  if not ok then
   if not valid(task.ghost) and why=="engine-revalidated" and task.carried then
    -- A moving priest can briefly occupy the exact 1x1 receiver tile.
    -- Wait for the real engine obstruction to clear; never skip the check.
    -- Static obstructions expire and refund the original item.
    task.site_blocked_since_0338=task.site_blocked_since_0338 or now()
    if now()-task.site_blocked_since_0338<=60*10 then
     local stand=non_ghost_standoff(pair,task)
     if stand then
      task.build_standoff_0338=stand
      task.phase="move-clear-site"
     end
     sync_custody(pair,task,"engine-site-obstructed")
     return{processed=1,waiting=1,blocked=1,detail="engine-site-obstructed-retry"}
    end
   end
   task.failure_reason_0338="site-invalid:"..safe(why)
   task.phase="return-custody"
   sync_custody(pair,task,task.failure_reason_0338)
   return return_custody(pair,task)
  end
  task.site_blocked_since_0338=nil
  local built,build_why=create_entity(pair,task)
  if not built then
   -- A ghost revival may be refused because the builder or another moving
   -- actor occupies its footprint. Preserve exact item custody, walk aside
   -- outside the real ghost selection box and retry at most twice. Static
   -- blockers still fail closed and return the unchanged item to storage.
   if build_why=="ghost-revive-refused" and valid(task.ghost)
      and (tonumber(task.revive_reposition_attempts_0338)or 0)<2 then
    task.revive_reposition_attempts_0338=(tonumber(task.revive_reposition_attempts_0338)or 0)+1
    local margin=task.revive_reposition_attempts_0338==1 and 1.5 or 1.8
    task.build_standoff_0338=source_approach_position(pair,task.ghost,margin,true)
    if task.build_standoff_0338 then
     task.phase="move-clear-site"
     return{processed=1,waiting=1,detail="revival-refused-reposition"}
    end
   end
   task.failure_reason_0338=build_why;task.phase="return-custody";sync_custody(pair,task,build_why)
   return return_custody(pair,task)
  end
  if task.carried then task.carried.count=0 end
  pair.construction_custody_0338=nil
  stat("entities-built");if task.creative_build then stat("creative-entities-built")end
  return finish(pair,task,built,build_why)
 end
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
function M.install()M.root();register_creative_command();_G.TechPriestsConstructionPlanner0338=M;_G.TECH_PRIESTS_CONSTRUCTION_PLANNER=M;if not register_service()then return false end;if log then log("[Tech-Priests recovery] dispatcher-owned construction planner armed; defense effectiveness and exact custody enabled")end;return true end
return M
