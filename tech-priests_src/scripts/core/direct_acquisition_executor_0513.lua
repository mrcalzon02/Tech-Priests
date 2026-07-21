-- scripts/core/direct_acquisition_executor_0513.lua
-- Tech Priests 0.1.674-dev base-state recovery.
-- Dispatcher-owned direct acquisition with exact target identity, physical
-- extraction, persistent custody, real return travel, atomic deposit, and
-- truthful terminal or station-craft handoff.

local M={version="0.1.674-dev",storage_key="direct_acquisition_executor_0513",
  close_distance_sq=2.25,station_distance_sq=4,move_refresh_ticks=120,
  stall_ticks=240,work_ticks=90,visual_ticks=18,max_pairs_per_pulse=24,
  default_direct_radius=32,default_hard_leash=48,bounds_integrated=true,target_safety_integrated=true,
  direct_radius_by_tier={
    ["planetary-magos"]=24,["planetary_magos"]=24,planetary=24,
    senior=32,intermediate=34,junior=36,
  },
  hard_leash_by_tier={
    ["planetary-magos"]=36,["planetary_magos"]=36,planetary=36,
    senior=48,intermediate=52,junior=56,
  },
}
local DIRECT_KINDS={["direct-mine-0273"]=true,["direct-dirt-0273"]=true,dirt=true,["direct-mine-0336"]=true}
local function now()return game and game.tick or 0 end
local function valid(e)return e and e.valid end
local function safe(v)local ok,s=pcall(tostring,v);return ok and s or"?"end
local function unit(e)return valid(e)and e.unit_number end
local function valid_pair(p)return p and valid(p.station)and valid(p.priest)end
local function pairs_map()return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or{}end
local function dist2(a,b)if not(a and b)then return 1e12 end;local x=(a.x or 0)-(b.x or 0);local y=(a.y or 0)-(b.y or 0);return x*x+y*y end
local function lower(v)return string.lower(tostring(v or""))end
local function tier_key(p)local t=lower(p and(p.tier or p.rank or p.station_tier or(valid(p.station)and p.station.name)or""));if t:find("planetary",1,true)or t:find("magos",1,true)then return"planetary-magos"end;if t:find("senior",1,true)then return"senior"end;if t:find("intermediate",1,true)then return"intermediate"end;if t:find("junior",1,true)then return"junior"end;return"default"end
local function runtime_radius(p)local r=tonumber(p and p.radius);if type(_G.refresh_pair_radius)=="function"and p then local ok,v=pcall(_G.refresh_pair_radius,p);if ok and tonumber(v)then r=tonumber(v)end end;if not r and type(_G.get_station_operating_radius)=="function"and valid(p and p.station)then local ok,v=pcall(_G.get_station_operating_radius,p.station);if ok and tonumber(v)then r=tonumber(v)end end;return r end
function M.direct_radius(p)local cap=M.direct_radius_by_tier[tier_key(p)]or M.default_direct_radius;return math.max(8,math.min(runtime_radius(p)or cap,cap))end
function M.hard_leash(p)local cap=M.hard_leash_by_tier[tier_key(p)]or M.default_hard_leash;local direct=M.direct_radius(p);local runtime=runtime_radius(p)or cap;return math.max(direct+6,math.min(math.max(runtime,direct+6),cap))end
function M.target_within_bounds(p,pos)
 if not(valid(p and p.station)and pos)then return true,nil,nil end
 local corridor=rawget(_G,"tech_priests_0574_position_allowed");if type(corridor)=="function"then local ok,allowed=pcall(corridor,p,pos,"direct-acquisition-bounds-0513",{owner="direct-acquisition-0513"});if ok and allowed then return true,nil,nil end end
 local distance=math.sqrt(dist2(p.station.position,pos));local maximum=M.direct_radius(p);return distance<=maximum,distance,maximum
end
local function item_exists(n)return type(n)=="string"and n~=""and prototypes and prototypes.item and prototypes.item[n]~=nil end
local function priest_or_station(e)
 if not valid(e)then return false end;local n=tostring(e.name or"");return n:find("tech%-priest",1,false)~=nil or n:find("cogitator%-station",1,false)~=nil
end
function M.target_is_safe(p,e)
 if not valid(e)or priest_or_station(e)or(valid(p and p.station)and e==p.station)then return false,"protected-target"end
 local t=e.type;if t=="resource"or t=="tree"then return true end
 if t=="simple-entity"or t=="simple-entity-with-owner"or t=="rock"then if valid(p and p.station)and e.force and e.force==p.station.force then return false,"owned-simple-entity"end;return true end
 return false,"unsupported-target-type:"..safe(t)
end
function M.physical_item(task,cur,e)
 if not valid(e)then return nil,"invalid-target"end
 if e.type=="resource"then return item_exists(e.name)and e.name or nil,"resource"end
 if e.type=="tree"then return item_exists("wood")and"wood"or nil,"tree"end
 local named=cur and(cur.physical_yield_item or cur.output_item)or task and(task.physical_yield_item or task.output_item)
 if (e.type=="simple-entity"or e.type=="simple-entity-with-owner"or e.type=="rock")and item_exists(named)then return named,"declared-destructive-yield"end
 return nil,"exact-physical-yield-required"
end
local function target_id(e)return valid(e)and{unit=e.unit_number,name=e.name,surface=e.surface and e.surface.index}or nil end
local function same_target(id,e)return id and valid(e)and id.unit==e.unit_number and id.name==e.name and id.surface==(e.surface and e.surface.index)end

function M.root()
 storage.tech_priests=storage.tech_priests or{};local r=storage.tech_priests[M.storage_key]or{enabled=true,dispatcher_only=true,block_legacy_direct_controllers=true,physical_only=true,stats={},recent={},cursor=0};storage.tech_priests[M.storage_key]=r;r.version=M.version;r.stats=r.stats or{};r.recent=r.recent or{};for _,k in ipairs{"enabled","dispatcher_only","block_legacy_direct_controllers","physical_only"}do if r[k]==nil then r[k]=true end end;return r
end
local function stat(k,n)local r=M.root();r.stats[k]=(r.stats[k]or 0)+(n or 1)end
local function record(k,p,d)local r=M.root();stat(k);r.recent[#r.recent+1]={tick=now(),action=k,station=p and(p.station_unit or unit(p.station)),priest=p and(p.priest_unit or unit(p.priest)),detail=safe(d)};while #r.recent>160 do table.remove(r.recent,1)end end
local function phase(p,k,d)p.dispatcher_action="direct-acquisition";p.dispatcher_phase=k;p.dispatcher_direct_0513=p.dispatcher_direct_0513 or{};local s=p.dispatcher_direct_0513;s.version=M.version;s.phase=k;s.tick=now();s.detail=safe(d);s.last_seen_tick=now();return s end

local function current_task(p)
 if not p then return nil end
 for _,key in ipairs{"emergency_craft","direct_acquisition_task_0336","active_acquisition_0333"}do local t=p[key];local cur=t and(t.current or t);if cur and DIRECT_KINDS[tostring(cur.kind or"")]then return t,cur,key end end
end
M.current_direct_task=current_task
local function entity(cur)return cur and(valid(cur.entity)and cur.entity or valid(cur.target)and cur.target or valid(cur.source)and cur.source)end
local function explicit_item(task,cur)
 for _,v in ipairs{cur and cur.output_item,cur and cur.item_name,cur and cur.wanted_item,cur and cur.requested_item,task and task.output_item,task and task.item_name,task and task.wanted_item,task and task.requested_item}do if item_exists(v)then return v end end
end
local function required(task)local n=task and task.recipe and tonumber(task.recipe.units)or tonumber(task and task.required_count)or tonumber(task and task.count)or 1;return math.max(1,math.min(50,math.floor(n)))end
local function clear_due(t)if not t then return end;for _,k in ipairs{"direct_due_tick_0273","direct_due_tick_0312","direct_due_tick_0315","direct_due_tick_0336","direct_started_tick_0336","next_direct_laser_tick_0315","direct_last_visual_tick_0306","direct_last_visual_tick_0336","direct_due_tick_0513","direct_started_tick_0513","direct_remaining_ticks_0513","direct_last_visual_tick_0513","scan_due_tick"}do t[k]=nil end end
local function clear_parent(p,key,t)clear_due(t);if t then t.current=nil end;if key then p[key]=nil end;p.target=nil end
local function queue_terminal(p,status,why,item)local q=rawget(_G,"TECH_PRIESTS_ORDER_QUEUE_0469");if not q then return false end;local f=status=="complete"and q.complete_current or q.fail_current;if type(f)~="function"then return false end;local ok,d=pcall(f,p,why,item);return ok and d==true end

local function release_clamp(p,why)
 p.movement_controller_clamp_0418=nil;if p.movement_controller_state_0418=="work-clamped"then p.movement_controller_state_0418="idle"end
 local f=rawget(_G,"tech_priests_clear_movement_lease_0518");if type(f)=="function"then pcall(f,p,why or"direct-release-clamp")else p.movement_lease_0518=nil end
end
local function clamp_for_work(p)
 local f=rawget(_G,"tech_priests_stop_movement_0418");if type(f)~="function"then return false,"stop-authority-unavailable"end
 local ok,d=pcall(f,p,"direct-acquisition-work-clamp-0513");if not(ok and d==true)then return false,d end
 p.movement_controller_state_0418="work-clamped";p.movement_controller_clamp_0418="direct-acquisition-work-0513";return true
end
local function request_move(p,pos,owner,priority,radius,why)
 release_clamp(p,"direct-movement-request")
 local f=rawget(_G,"tech_priests_request_movement_0418");if type(f)~="function"then return false,"movement-authority-unavailable"end
 local ok,d,detail=pcall(f,p,pos,why,{radius=radius,owner=owner,priority=priority,ttl=600,distraction=defines and defines.distraction and defines.distraction.none})
 return ok and d==true,ok and(detail or d)or d
end
local function within_bounds(p,pos)
 local ok,a,d,m=pcall(M.target_within_bounds,p,pos);if not ok then return false,"bounds-authority-error:"..safe(a)end;return a==true,d,m
end
local function recover_overleash(p,state)
 local maximum=M.hard_leash(p);local distance=math.sqrt(dist2(p.priest.position,p.station.position));if distance<=maximum then return false,nil end
 phase(p,"return-overleash","distance="..safe(distance).." max="..safe(maximum));p.mode="direct-acquisition-returning-overleash"
 local moved,why=request_move(p,p.station.position,"direct-acquisition-0513",760,1,"direct-acquisition-overleash-return-0513")
 state.next_overleash_retry_tick=now()+60;record(moved and"overleash-return-0513"or"overleash-return-failed-0513",p,"distance="..safe(distance).." max="..safe(maximum).." why="..safe(why));return true,moved and"returning-overleash"or"overleash-return-failed"
end

local function show(p,text,target,line)
 if type(_G.tech_priests_draw_emergency_operation_status_0184)=="function"then pcall(_G.tech_priests_draw_emergency_operation_status_0184,p,text)end
 if line and valid(target)and type(_G.draw_emergency_craft_scan_line)=="function"then pcall(_G.draw_emergency_craft_scan_line,p,target)end
end
local function visual(p,e,final)
 if not valid(e)then return end
 if type(_G.draw_emergency_craft_scan_line)=="function"then pcall(_G.draw_emergency_craft_scan_line,p,e)end
 if type(_G.spawn_emergency_craft_smoke)=="function"then pcall(_G.spawn_emergency_craft_smoke,p,e.position,final==true)end
end

local function exact_yield(task,cur,e,item)
 if not(valid(e)and item_exists(item))then return nil,"physical-target-required"end
 if e.type=="resource"then
  if (tonumber(e.amount)or 0)<1 then return nil,"resource-depleted"end
  return 1,"resource"
 end
 local named=cur and(cur.physical_yield_item or cur.output_item)or task and(task.physical_yield_item or task.output_item)
 local count=tonumber(cur and cur.physical_yield_count or task and task.physical_yield_count)
 if named~=item or not count or count<1 or count~=math.floor(count)then return nil,"exact-yield-metadata-required"end
 return count,"destructive"
end
local function extract(task,cur,e,item)
 local count,kind=exact_yield(task,cur,e,item);if not count then return false,kind end
 if kind=="resource"then
  local amount=tonumber(e.amount)or 0
  local ok=pcall(function()if amount<=1 then e.destroy{raise_destroy=true}else e.amount=amount-1 end end)
  if not ok then return false,"resource-mutation-failed"end
 else
  local ok,d=pcall(function()return e.destroy{raise_destroy=true}end);if not(ok and d~=false)then return false,"target-destroy-failed"end
 end
 return true,count
end
local function atomic_deposit(p,c)
 local f=rawget(_G,"tech_priests_safe_deposit_item");if type(f)~="function"then return false,"atomic-storage-unavailable"end
 local ok,d,why,n=pcall(f,p,c.item,c.count,"direct-acquisition-custody-0513");n=tonumber(n)or(d==true and c.count or 0);return ok and d==true and n==c.count,why
end

local function reset_target_state(state,t)
 clear_due(t);state.target_id=nil;state.target_label=nil;state.last_distance=nil;state.last_progress_tick=nil;state.last_move_tick=nil;state.work_started_tick=nil
end
local function fail_unsafe(p,t,key,state,why)
 release_clamp(p,why);clear_parent(p,key,t);p.direct_acquisition_custody_0513=nil;phase(p,"failed",why);p.mode="direct-acquisition-failed";queue_terminal(p,"failed",why);record("unsafe-failure-0513",p,why);return false,why
end
local function replan(p,t,state,why)
 release_clamp(p,why);clear_due(t);if t then t.current=nil end;state.target_id=nil;state.target_label=nil;p.target=nil;p.mode="direct-acquisition-replan";phase(p,"need-target",why);record("replan-0513",p,why);return false,why
end

local function finish_deposit(p,t,cur,key,state,c)
 local ok,why=atomic_deposit(p,c);if not ok then p.mode="direct-acquisition-deposit-blocked";phase(p,"deposit-blocked",why);record("deposit-blocked-0513",p,why);return true,"deposit-blocked"end
 p.direct_acquisition_custody_0513=nil;state.last_deposit_item=c.item;state.last_deposit_count=c.count;record("custody-deposited-0513",p,c.item.." x"..c.count)
 if not t then release_clamp(p,"task-lost-after-custody");p.mode="direct-acquisition-failed";phase(p,"failed","task-lost-after-custody");queue_terminal(p,"failed","task-lost-after-custody");return false,"task-lost-after-custody"end
 t.gathered_units=(tonumber(t.gathered_units)or 0)+c.count
 if t.gathered_units<required(t)then
  if valid(entity(cur))then reset_target_state(state,t);p.mode="direct-acquisition-next-unit";phase(p,"return-to-target",t.gathered_units.."/"..required(t));return true,"next-unit"end
  return replan(p,t,state,"target-depleted-before-required-count")
 end
 if t.recipe and item_exists(t.output_item)then
  local q=rawget(_G,"TECH_PRIESTS_ORDER_QUEUE_0469");local transitioned=true
  if q and type(q.transition_current)=="function"then local ok_transition,d=pcall(q.transition_current,p,{kind="emergency_craft",item=t.output_item,purpose="station-craft-handoff",source="emergency_production_executor_0514",clear_target=true,clear_task=true,priority=540},"direct-materials-ready-0513");transitioned=ok_transition and d==true
  elseif p.order_queue_0469 and p.order_queue_0469.current then transitioned=false end
  if not transitioned then return fail_unsafe(p,t,key,state,"station-craft-order-transition-failed")end
  clear_due(t);t.current=nil;if key~="emergency_craft"then p.emergency_craft=t;p[key]=nil end;t.station_craft_pending_0337=true;t.station_craft_pending_0513=true;p.target=nil;p.mode="emergency-production-station-craft";phase(p,"station-craft-handoff",t.output_item);record("station-craft-handoff-0513",p,t.output_item);return true,"ready-to-craft"
 end
 clear_parent(p,key,t);p.mode="idle";phase(p,"complete",c.item);queue_terminal(p,"complete","direct-acquisition-complete-0513",c.item);record("complete-0513",p,c.item);return true,"complete"
end
local function service_custody(p,t,cur,key,state)
 local c=p.direct_acquisition_custody_0513;if not c then return false,"no-custody"end
 if not(item_exists(c.item)and tonumber(c.count)and c.count>0)then return fail_unsafe(p,t,key,state,"invalid-custody-metadata")end
 if dist2(p.priest.position,p.station.position)>M.station_distance_sq then
  p.target=p.station;p.mode="direct-acquisition-returning-with-custody";phase(p,"return-with-custody",c.item)
  if not state.next_return_retry_tick or now()>=state.next_return_retry_tick then local moved,why=request_move(p,p.station.position,"direct-acquisition-0513",610,1,"direct-acquisition-return-0513");state.next_return_retry_tick=now()+60;if not moved then record("return-movement-failed-0513",p,why);return false,"return-movement-failed"end end
  return true,"returning-with-custody"
 end
 release_clamp(p,"at-station-with-custody");return finish_deposit(p,t,cur,key,state,c)
end

function M.service_pair(p,reason)
 if M.root().enabled==false then return false,"disabled"end;if not valid_pair(p)then return false,"invalid-pair"end
 local t,cur,key=current_task(p);local state=p.dispatcher_direct_0513 or{};p.dispatcher_direct_0513=state;state.version=M.version;state.reason=safe(reason);state.last_seen_tick=now()
 if p.direct_acquisition_custody_0513 then return service_custody(p,t,cur,key,state)end
 if not(t and cur)then phase(p,"none","no-direct-task");return false,"no-direct-task"end
 if not state.next_overleash_retry_tick or now()>=state.next_overleash_retry_tick then local returning,why=recover_overleash(p,state);if returning then return true,why end end
  local e=entity(cur);local item=explicit_item(t,cur)
  if not valid(e)then return replan(p,t,state,"physical-target-invalid")end
  if not item then return fail_unsafe(p,t,key,state,"explicit-output-item-required")end
  local safe_target,safety_reason=M.target_is_safe(p,e);if not safe_target then return fail_unsafe(p,t,key,state,safety_reason)end
  local physical_item,physical_reason=M.physical_item(t,cur,e);if not physical_item then return fail_unsafe(p,t,key,state,physical_reason)end
  if item~=physical_item then return fail_unsafe(p,t,key,state,"physical-output-mismatch:"..safe(item).."!="..safe(physical_item))end
  if e.surface~=p.station.surface then return fail_unsafe(p,t,key,state,"cross-surface-target")end
 local id=target_id(e)
 if state.target_id and not same_target(state.target_id,e)then reset_target_state(state,t)end
 state.target_id=id;state.target_label=safe(e.name).."#"..safe(e.unit_number);state.item=item;p.target=e
 local inside,d,maxd=within_bounds(p,e.position);if not inside then return replan(p,t,state,"target-out-of-bounds:"..safe(d)..">"..safe(maxd))end

 local ds=dist2(p.priest.position,e.position);state.distance=math.sqrt(ds)
 if ds>M.close_distance_sq then
  if t.direct_due_tick_0513 then t.direct_remaining_ticks_0513=math.max(1,t.direct_due_tick_0513-now());t.direct_due_tick_0513=nil end
  local last=tonumber(state.last_distance);local progress=not last or state.distance<last-.05;if progress then state.last_progress_tick=now()end;state.last_distance=state.distance
  local due=not state.last_move_tick or now()-state.last_move_tick>=M.move_refresh_ticks;local stalled=not progress and now()-(tonumber(state.last_progress_tick)or 0)>=M.stall_ticks
  if due or stalled then state.last_move_tick=now();local moved,why=request_move(p,e.position,"direct-acquisition-0513",650,.75,stalled and"direct-acquisition-repath-0513"or"direct-acquisition-travel-0513");if not moved then state.next_move_retry_tick=now()+60;p.mode="direct-acquisition-movement-failed";phase(p,"movement-request-failed",why);record("movement-failed-0513",p,why);return false,"movement-failed"end end
  p.mode="travelling-to-direct-acquisition";phase(p,"walk-to-target",state.target_label);show(p,"[item="..item.."] walking to direct target",nil,false);return true,"walking"
 end

 local clamped,why=clamp_for_work(p);if not clamped then return fail_unsafe(p,t,key,state,"work-clamp-failed:"..safe(why))end
 p.mode="direct-acquisition-working";phase(p,"work-target",state.target_label)
 if t.direct_remaining_ticks_0513 and not t.direct_due_tick_0513 then t.direct_due_tick_0513=now()+math.max(1,t.direct_remaining_ticks_0513);t.direct_remaining_ticks_0513=nil
 elseif not t.direct_due_tick_0513 then t.direct_due_tick_0513=now()+M.work_ticks;t.direct_started_tick_0513=now();record("work-started-0513",p,state.target_label)end
 if now()<t.direct_due_tick_0513 then if not t.direct_last_visual_tick_0513 or now()-t.direct_last_visual_tick_0513>=M.visual_ticks then t.direct_last_visual_tick_0513=now();visual(p,e,false)end;show(p,"[item="..item.."] extracting",e,true);return true,"working"end

 visual(p,e,true);local ok,count=extract(t,cur,e,item);clear_due(t);release_clamp(p,"physical-extraction-complete")
 if not ok then if count=="resource-depleted"or count=="physical-target-required"then return replan(p,t,state,count)end;return fail_unsafe(p,t,key,state,count)end
 p.direct_acquisition_custody_0513={version=M.version,item=item,count=count,target=id,parent_key=key,required_units=required(t),recipe_output=t.output_item,created_tick=now(),source_kind=e.type};record("physical-custody-acquired-0513",p,item.." x"..count);return service_custody(p,t,cur,key,state)
end

function M.service_all(reason,budget)
 local r=M.root();local list={};for k,p in pairs(pairs_map())do if valid_pair(p)and(current_task(p)or p.direct_acquisition_custody_0513)then list[#list+1]={key=tostring(k),pair=p}end end;table.sort(list,function(a,b)return a.key<b.key end);if #list==0 then return 0 end
 local lim=math.max(1,math.min(#list,math.floor(tonumber(budget)or M.max_pairs_per_pulse)));local start=(tonumber(r.cursor)or 0)%#list+1;local acted=0;for i=0,lim-1 do local p=list[((start+i-1)%#list)+1].pair;local ok,d=pcall(M.service_pair,p,reason or"service-all");if ok and d==true then acted=acted+1 end end;r.cursor=(start+lim-2)%#list+1;return acted
end
function M.report_lines()
 local r=M.root();local active,custody=0,0;for _,p in pairs(pairs_map())do if valid_pair(p)and current_task(p)then active=active+1 end;if p and p.direct_acquisition_custody_0513 then custody=custody+1 end end
 return{"[tp-runtime-report] direct-acquisition-0513 version="..M.version.." enabled="..safe(r.enabled).." active="..active.." custody="..custody.." acquired="..safe(r.stats["physical-custody-acquired-0513"]or 0).." deposited="..safe(r.stats["custody-deposited-0513"]or 0).." failed="..safe(r.stats["unsafe-failure-0513"]or 0).." return_failed="..safe(r.stats["return-movement-failed-0513"]or 0)}
end
local function should_block(p)local r=M.root();if r.enabled==false or r.block_legacy_direct_controllers==false or not valid_pair(p)then return false end;return current_task(p)~=nil or p.direct_acquisition_custody_0513~=nil end
local function wrap_legacy()
 local ok,E=pcall(require,"scripts.core.acquisition_executor");if ok and E and type(E.service_pair)=="function"and not E.direct_executor_0513_wrapped then E.direct_executor_0513_wrapped=true;E.TECH_PRIESTS_0513_PRE_SERVICE_PAIR=E.service_pair;E.service_pair=function(p,r,...)if M.root().enabled~=false then return M.service_pair(p,r or"acquisition-wrapper-0513")end;return E.TECH_PRIESTS_0513_PRE_SERVICE_PAIR(p,r,...)end end
 for _,name in ipairs{"tech_priests_0273_service_direct_current","tech_priests_0312_service_direct_current","tech_priests_0315_service_direct_current"}do local f=_G[name];local marker="TECH_PRIESTS_0513_PRE_"..string.upper(name);if type(f)=="function"and not rawget(_G,marker)then _G[marker]=f;_G[name]=function(p,t,...)if should_block(p)then record("legacy-direct-blocked-0513",p,name);return true end;return f(p,t,...)end end end
end
local function diagnostics()
 local d=rawget(_G,"TechPriestsEmergencyDiagnostics0468")or rawget(_G,"TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468");if not(d and type(d.pair_dump_lines)=="function")or d.direct_acquisition_0513_wrapped then return end;local prev=d.pair_dump_lines;d.direct_acquisition_0513_wrapped=true;d.pair_dump_lines=function()local lines=prev();local r=M.root();lines[#lines+1]="PAIR-DUMP-0468 DIRECT-ACQUISITION-0513 version="..M.version.." acquired="..safe(r.stats["physical-custody-acquired-0513"]or 0).." deposited="..safe(r.stats["custody-deposited-0513"]or 0).." unsafe="..safe(r.stats["unsafe-failure-0513"]or 0);for _,p in pairs(pairs_map())do if valid_pair(p)then local s=p.dispatcher_direct_0513 or{};local c=p.direct_acquisition_custody_0513;lines[#lines+1]="PAIR-DUMP-0468 direct["..safe(p.station_unit or unit(p.station)).."] phase="..safe(s.phase).." target="..safe(s.target_label).." item="..safe(s.item).." custody="..safe(c and(c.item.."x"..c.count)).." detail="..safe(s.detail)end end;return lines end
end
function M.install()
 M.root();wrap_legacy();diagnostics();if commands and commands.remove_command then pcall(commands.remove_command,"tp-direct-acquisition-0513")end;_G.TechPriestsDirectAcquisitionExecutor0513=M;_G.tech_priests_direct_target_within_bounds_0513=M.target_within_bounds;if log then log("[Tech-Priests 0.1.674-dev] direct acquisition physical-custody recovery armed")end;return true
end
return M
