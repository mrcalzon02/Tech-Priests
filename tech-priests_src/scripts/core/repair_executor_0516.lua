-- scripts/core/repair_executor_0516.lua
-- Tech Priests 0.1.674-dev recovery.
-- Sole physical repair authority: dispatcher-owned movement, reservation, exact
-- repair-pack custody, verified health mutation, atomic refund, and queue truth.

local M={version="0.1.674-dev",storage_key="repair_executor_0516",repair_range_sq=16,
 pack_interval_ticks=45,target_cooldown_ticks=120,reservation_ttl_ticks=240,
 max_candidates=160,max_pairs_per_service=24}
local original_repair_target,original_scheduler_try_repair
local function now()return game and game.tick or 0 end
local function valid(e)return e and e.valid end
local function lower(v)return string.lower(tostring(v or""))end
local function safe(v)if v==nil then return"nil"end;local ok,s=pcall(tostring,v);return ok and s or"?"end
local function valid_pair(p)return type(p)=="table"and valid(p.station)and valid(p.priest)end
local function unit(p)return p and(p.station_unit or(valid(p.station)and p.station.unit_number))end
local function pairs_map()return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or{}end
local function dist_sq(a,b)if not(a and b)then return 999999999 end;local x=(a.x or 0)-(b.x or 0);local y=(a.y or 0)-(b.y or 0);return x*x+y*y end
local function result(t)t=t or{};return{processed=tonumber(t.processed)or 1,acted=tonumber(t.acted)or 0,blocked=tonumber(t.blocked)or 0,waiting=tonumber(t.waiting)or 0,failed=tonumber(t.failed)or 0,exhausted=t.exhausted==true,detail=safe(t.detail or"")}end
local function module(name,global)local m=rawget(_G,global);if m then return m end;local ok,v=pcall(require,name);return ok and v or nil end
local function Queue()return module("scripts.core.order_queue_0469","TECH_PRIESTS_ORDER_QUEUE_0469")end
local function Reservations()return module("scripts.core.work_reservations","TechPriestsWorkReservations0601")end
local function WorkQueue()return module("scripts.core.work_queue_authority","TechPriestsWorkQueueAuthority0601")end
function M.root()
 storage.tech_priests=storage.tech_priests or{};local r=storage.tech_priests[M.storage_key]or{enabled=true,dispatcher_owned=true,full_repair=true,stats={},recent={},cooldowns={},cursor=0};storage.tech_priests[M.storage_key]=r
 r.version=M.version;if r.enabled==nil then r.enabled=true end;if r.dispatcher_owned==nil then r.dispatcher_owned=true end;if r.full_repair==nil then r.full_repair=true end;r.stats=r.stats or{};r.recent=r.recent or{};r.cooldowns=r.cooldowns or{};r.cursor=tonumber(r.cursor)or 0;return r
end
local function stat(k,n)local r=M.root();r.stats[k]=(tonumber(r.stats[k])or 0)+(tonumber(n)or 1)end
local function record(p,a,d)local r=M.root();stat(a);r.recent[#r.recent+1]={tick=now(),station=unit(p),action=safe(a),detail=safe(d)};while #r.recent>160 do table.remove(r.recent,1)end end
local function current_order(p)local q=p and p.order_queue_0469;return p and((q and q.current)or p.active_order_0469)or nil end
local function repair_order(o)if type(o)~="table"then return false end;local s=lower(o.kind).." "..lower(o.type).." "..lower(o.source).." "..lower(o.purpose).." "..lower(o.reason);return s:find("repair",1,true)~=nil end
local function target_from(v,seen)if valid(v)then return v end;if type(v)~="table"then return nil end;seen=seen or{};if seen[v]then return nil end;seen[v]=true;for _,k in ipairs{"target","entity","machine","source","selected","current","task"}do local e=target_from(v[k],seen);if e then return e end end end
local function order_target(p)local o=current_order(p);return repair_order(o)and target_from(o)or nil end
local function target_key(e)if not valid(e)then return nil end;if e.unit_number then return"unit:"..e.unit_number end;local p=e.position or{x=0,y=0};return safe(e.surface and e.surface.index)..":"..safe(e.name)..":"..string.format("%.1f,%.1f",p.x or 0,p.y or 0)end
local function missing(e)if not(valid(e)and e.health and e.max_health)then return 0 end;local f=rawget(_G,"get_repair_pack_useful_missing_health");if type(f)=="function"then local ok,n=pcall(f,e);if ok and tonumber(n)then return math.max(0,tonumber(n))end end;return math.max(0,(tonumber(e.max_health)or 0)-(tonumber(e.health)or 0))end
local function priest(e)if not valid(e)then return false end;local f=rawget(_G,"is_priest");if type(f)=="function"then local ok,v=pcall(f,e);if ok and v==true then return true end end;local n=lower(e.name);return n:find("tech%-priest")~=nil or n:find("tech_priest")~=nil end
local function eligible(p,e,owned)
 if not(valid_pair(p)and valid(e)and missing(e)>0.01)then return false,"not-damaged"end;if priest(e)then return false,"priest-excluded"end;if e.name==(rawget(_G,"PROXY_NAME")or"tech-priest-proxy-turret")then return false,"proxy-excluded"end;if e.force and p.station.force and e.force~=p.station.force then return false,"wrong-force"end
 local radius=math.max(8,tonumber(p.radius or p.base_radius)or 32);if dist_sq(p.station.position,e.position)>radius*radius then return false,"outside-radius"end;local key=target_key(e);if key and tonumber(M.root().cooldowns[key]or 0)>now()then return false,"target-cooldown"end
 local R=Reservations();if not owned and R and type(R.is_claimed)=="function"then local ok,v=pcall(R.is_claimed,"repair",e,p);if ok and v==true then return false,"reserved"end end;return true,"eligible"
end
local function score(p,e)local m=missing(e);return(m/math.max(1,tonumber(e.max_health)or 1))*10000+m*2-math.sqrt(dist_sq(p.priest.position,e.position))*12 end
local function find_target(p,explicit)
 if valid(explicit)and eligible(p,explicit,true)then return explicit,"explicit"end;local e=order_target(p);if valid(e)and eligible(p,e,true)then return e,"order"end
 local W=WorkQueue();if W and type(W.claim_nearest)=="function"then local ok,c=pcall(W.claim_nearest,p,"repair",{ttl=M.reservation_ttl_ticks});if ok and c and valid(c.target)and eligible(p,c.target,true)then return c.target,"work-queue"end end
 local radius=math.max(8,tonumber(p.radius or p.base_radius)or 32);local pos=p.station.position;local ok,list=pcall(function()return p.station.surface.find_entities_filtered({area={{pos.x-radius,pos.y-radius},{pos.x+radius,pos.y+radius}},force=p.station.force,limit=M.max_candidates})end);if not(ok and list)then return nil,"scan-failed"end
 local best,best_score;for _,candidate in ipairs(list)do if eligible(p,candidate,false)then local s=score(p,candidate);if not best_score or s>best_score then best,best_score=candidate,s end end end;return best,best and"bounded-scan"or"no-eligible-target"
end
local function sources(p)
 local out,seen={},{};local function add(inv,label)if not(inv and inv.valid)then return end;local k=safe(inv);if seen[k]then return end;seen[k]=true;out[#out+1]={inv=inv,label=label or"station"}end
 local f=rawget(_G,"tech_priests_inventory_steward_sources_for_pair");if type(f)=="function"then local ok,list=pcall(f,p);if ok and type(list)=="table"then for _,s in ipairs(list)do if s then add(s.inv or s.inventory,s.label or s.source or s.kind)end end end end
 local g=rawget(_G,"get_station_inventory");if type(g)=="function"then local ok,inv=pcall(g,p.station);if ok then add(inv,"station")end end;if defines and defines.inventory and p.station.get_inventory then local ok,inv=pcall(function()return p.station.get_inventory(defines.inventory.chest)end);if ok then add(inv,"station-chest")end end;return out
end
local function count(inv,item)if not(inv and inv.valid)then return 0 end;local ok,n=pcall(function()return inv.get_item_count(item)end);return ok and(tonumber(n)or 0)or 0 end
local function pack_count(p)local n=0;for _,s in ipairs(sources(p))do n=n+count(s.inv,"repair-pack")end;return n end
local function remove_pack(p)for _,s in ipairs(sources(p))do if count(s.inv,"repair-pack")>0 then local ok,n=pcall(function()return s.inv.remove({name="repair-pack",count=1})end);if ok and tonumber(n)==1 then return true,s.label end end end;return false,"no-pack-source"end
local function atomic_return(p,n,why)local f=rawget(_G,"tech_priests_safe_deposit_item");if type(f)~="function"then return false,"atomic-storage-unavailable"end;local ok,a,b,c=pcall(f,p,"repair-pack",n,why);c=tonumber(c)or(a==true and n or 0);return ok and a==true and c==n,b end
local function claim(p,e)local R=Reservations();if not(R and type(R.claim)=="function")then return false,"reservation-authority-unavailable"end;local ok,v=pcall(R.claim,"repair",e,p,M.reservation_ttl_ticks,{surface_index=e.surface and e.surface.index,force_index=e.force and e.force.index});return ok and v==true,ok and"claimed"or safe(v)end
local function release(p,e)local R=Reservations();if valid(e)and R and type(R.release)=="function"then pcall(R.release,"repair",e,p)end end
local function move(p,e)local f=rawget(_G,"tech_priests_request_movement_0418");if type(f)~="function"then return false,"movement-authority-unavailable"end;local ok,v=pcall(f,p,e.position,"repair-executor-0516-walk-to-target",{radius=1.4,owner="repair_executor_0516",priority=820,ttl=900,distraction=defines and defines.distraction and defines.distraction.none});return ok and v==true,ok and safe(v)or"movement-error:"..safe(v)end
local function clear_state(p,phase,why)local s=p.repair_0516 or{};local e=valid(s.target)and s.target or nil;if e then release(p,e)end;s.phase=phase or"none";s.last_blocker=why;s.target=nil;s.target_name=nil;s.target_unit=nil;s.target_source=nil;s.started_tick=nil;s.due_tick=nil;s.distance=nil;s.missing=nil;p.repair_0516=s;if p.target==e then p.target=nil end end
local function queue_terminal(p,kind,why)
 local o=current_order(p);if not repair_order(o)then return true,"no-repair-order"end;local Q=Queue();local fn=Q and Q[kind];if type(fn)~="function"then return false,"order-queue-unavailable"end;local ok,v,w=pcall(fn,p,why);return ok and v==true,ok and w or v
end
local function refund(p,why)local c=p.repair_pack_custody_0516;if not c then return true,"no-custody"end;local ok,w=atomic_return(p,tonumber(c.count)or 1,why or"repair-pack-refund-0516");if not ok then c.phase="return-pack";c.last_blocker=safe(w);c.updated_tick=now();record(p,"refund-blocked",w);return false,w end;p.repair_pack_custody_0516=nil;stat("packs-refunded");record(p,"refund-complete",why);return true,"refunded"end
local function apply_custody(p)
 local c=p.repair_pack_custody_0516;if not c then return true,"no-custody"end;if c.phase=="return-pack"then return refund(p,"repair-pack-refund-retry-0516")end;local e=c.target;if not valid(e)then c.phase="return-pack";return refund(p,"repair-pack-target-invalid-0516")end
 local expected=tonumber(c.expected_health)or tonumber(e.health)or 0;local before=tonumber(c.before_health)or tonumber(e.health)or 0;if(tonumber(e.health)or 0)<expected-0.001 then local ok=pcall(function()e.health=expected end);if not ok or(tonumber(e.health)or before)<=before+0.001 then c.phase="return-pack";local returned=refund(p,"repair-health-write-failed-0516");return false,returned and"health-write-failed-refunded"or"health-write-failed-refund-blocked"end end
 p.repair_pack_custody_0516=nil;local s=p.repair_0516 or{};s.packs_used=(tonumber(s.packs_used)or 0)+1;s.last_restore=math.max(0,expected-before);s.last_pack_tick=now();s.due_tick=now()+M.pack_interval_ticks;p.repair_0516=s;stat("packs-applied");return true,"pack-applied"
end
local function begin_pack(p,e)local ok,source=remove_pack(p);if not ok then return false,"consume-failed"end;local before=tonumber(e.health)or 0;local expected=math.min(tonumber(e.max_health)or before,before+(tonumber(rawget(_G,"REPAIR_AMOUNT_PER_PACK"))or 75));p.repair_pack_custody_0516={version=M.version,phase="pack-held",item="repair-pack",count=1,target=e,target_unit=e.unit_number,before_health=before,expected_health=expected,source=source,created_tick=now(),updated_tick=now()};stat("packs-removed");return apply_custody(p)end
local function complete(p,e,why)
 release(p,e);local key=target_key(e);if key then M.root().cooldowns[key]=now()+M.target_cooldown_ticks end;local ok,w=queue_terminal(p,"complete_current",why or"repair-complete-0516");if not ok then local s=p.repair_0516 or{};s.phase="completion-blocked";s.target=e;s.last_blocker=safe(w);p.repair_0516=s;return result{blocked=1,detail="order-completion-blocked:"..safe(w)}end;clear_state(p,"complete");p.mode="idle";record(p,"complete",why);return result{acted=1,detail="complete"}
end
function M.abort_pair(p,why,expected)
 if not valid_pair(p)then return result{failed=1,detail="invalid-pair"}end;local s=p.repair_0516 or{};local e=valid(s.target)and s.target or nil;if valid(expected)and valid(e)and expected~=e then return result{processed=0,detail="different-repair-target"}end
 if p.repair_pack_custody_0516 then p.repair_pack_custody_0516.phase="return-pack";local ok,w=refund(p,"repair-abort-refund-0516");if not ok then s.phase="refund-blocked";s.last_blocker=w;s.abort_after_refund=true;p.repair_0516=s;release(p,e);if p.target==e then p.target=nil end;p.mode=valid(p.combat_target)and"combat"or"idle";return result{blocked=1,detail="abort-refund-blocked:"..safe(w)}end end
 queue_terminal(p,"fail_current",why or"repair-aborted-0516");clear_state(p,"failed",why or"repair-aborted-0516");p.mode=valid(p.combat_target)and"combat"or"idle";record(p,"aborted",why);return result{acted=1,detail=why or"repair-aborted"}
end
function M.active(p)local s=p and p.repair_0516;return p and(p.repair_pack_custody_0516~=nil or(repair_order(current_order(p)))or(s and s.phase and s.phase~="none"and s.phase~="complete"and s.phase~="failed"))or false end
function M.submit_or_assign_repair_task(p,e,why)
 if not valid_pair(p)then return false,"invalid-pair"end;if not valid(e)then e=select(1,find_target(p))end;if not valid(e)then return false,"no-target"end;local Q=Queue();if not(Q and type(Q.submit)=="function")then return false,"order-queue-unavailable"end
 local ok,a,w,o=pcall(Q.submit,p,{kind="repair",item="repair-pack",target=e,priority=800,source="repair_executor_0516",purpose=why or"repair",reason=why or"repair"});if not ok then return false,"order-submit-error:"..safe(a)end;if a==true or w=="duplicate-merged"then record(p,"order-accepted",w);return true,w,o end;record(p,"order-rejected",w);return false,w,o
end
function M.service_pair(p,why,forced)
 local root=M.root();if root.enabled==false then return result{processed=0,detail="disabled"}end;if not valid_pair(p)then return result{failed=1,detail="invalid-pair"}end;local s=p.repair_0516 or{phase="none"};p.repair_0516=s;s.version=M.version;s.last_service_tick=now();s.last_reason=safe(why or"service")
 if p.repair_pack_custody_0516 then local ok,w=apply_custody(p);if not ok then return result{blocked=1,detail=w}end;if s.abort_after_refund then s.abort_after_refund=nil;clear_state(p,"failed",s.last_blocker or"repair-aborted-after-refund");p.mode=valid(p.combat_target)and"combat"or"idle";return result{acted=1,detail="repair-aborted-after-refund"}end end
 if s.phase=="failed"and not valid(forced)and not repair_order(current_order(p))then return result{processed=0,detail=s.last_blocker or"repair-failed"}end
 local e=valid(forced)and forced or(valid(s.target)and s.target)or order_target(p);if not valid(e)then e,s.target_source=find_target(p)end;if not valid(e)then s.phase=pack_count(p)>0 and"no-target"or"need-item";s.last_blocker=s.target_source or"no-target";return result{blocked=s.phase=="need-item"and 1 or 0,waiting=s.phase=="no-target"and 1 or 0,detail=s.last_blocker}end
 local allowed,w=eligible(p,e,true);if not allowed then local q=queue_terminal(p,"fail_current","repair-target-invalid:"..safe(w));clear_state(p,"failed",w);p.mode="idle";return result{failed=q and 1 or 0,blocked=q and 0 or 1,detail=w}end
 s.target=e;s.target_name=e.name;s.target_unit=e.unit_number;s.missing=missing(e);p.target=e;if s.phase=="completion-blocked"or s.missing<=0.01 then return complete(p,e,s.phase=="completion-blocked"and"repair-completion-retry-0516"or"repair-complete-0516")end
 local claimed,cwhy=claim(p,e);if not claimed then s.phase="target-reserved";s.last_blocker=cwhy;return result{blocked=1,detail="target-reserved:"..safe(cwhy)}end;if pack_count(p)<=0 then release(p,e);s.phase="need-item";s.last_blocker="no-repair-pack";p.mode="missing-repair-supplies";return result{blocked=1,detail="no-repair-pack"}end
 local d=dist_sq(p.priest.position,e.position);s.distance=math.sqrt(d);if d>M.repair_range_sq then local moved,mwhy=move(p,e);if not moved then release(p,e);s.phase="movement-request-failed";s.last_blocker=mwhy;p.mode="repair-movement-failed";return result{failed=1,detail="movement-request-failed:"..safe(mwhy)}end;s.phase="walk-to-target";p.mode="moving-to-repair";return result{waiting=1,detail="walk-to-target"}end
 s.phase="repair-target";s.started_tick=s.started_tick or now();s.due_tick=s.due_tick or(now()+M.pack_interval_ticks);p.mode="repairing";if now()<s.due_tick then return result{waiting=1,detail="repair-progress"}end
 local applied,awhy=begin_pack(p,e);if not applied then release(p,e);s.phase=p.repair_pack_custody_0516 and"refund-blocked"or"health-write-failed";s.last_blocker=awhy;return result{blocked=p.repair_pack_custody_0516 and 1 or 0,failed=p.repair_pack_custody_0516 and 0 or 1,detail=awhy}end;s.missing=missing(e);if s.missing<=0.01 or root.full_repair==false then return complete(p,e,"repair-complete-0516")end;return result{acted=1,detail="repair-pack-applied"}
end
function M.service_repair_bucket(why,budget)local list={};for _,p in pairs(pairs_map())do if valid_pair(p)and M.active(p)then list[#list+1]=p end end;table.sort(list,function(a,b)return(unit(a)or 0)<(unit(b)or 0)end);if #list==0 then return result{processed=0,detail="empty-repair-bucket"}end;local r=M.root();local limit=math.max(1,math.floor(tonumber(budget)or M.max_pairs_per_service));local out={processed=0,acted=0,blocked=0,waiting=0,failed=0};for off=1,math.min(limit,#list)do local i=((r.cursor+off-1)%#list)+1;local v=M.service_pair(list[i],why or"repair-bucket");for _,k in ipairs{"processed","acted","blocked","waiting","failed"}do out[k]=out[k]+(tonumber(v[k])or 0)end end;r.cursor=(r.cursor+math.min(limit,#list))%#list;out.exhausted=#list>limit;out.detail="repair-bucket";return result(out)end
local function wrap_legacy()
 if not original_repair_target and type(rawget(_G,"repair_target"))=="function"then original_repair_target=rawget(_G,"repair_target");_G.TECH_PRIESTS_0516_PRE_REPAIR_TARGET=original_repair_target;_G.repair_target=function(p,e,...)if M.root().enabled==false or not valid_pair(p)then return original_repair_target(p,e,...)end;local ok,w=M.submit_or_assign_repair_task(p,e,"legacy-repair-adopted-0516");if not ok then return false,w end;local v=M.service_pair(p,"legacy-repair-adopted-0516",e);return v.acted>0 or v.waiting>0,v.detail end end
 local ok,S=pcall(require,"scripts.core.task_scheduler");if ok and S and type(S.try_repair)=="function"and not original_scheduler_try_repair then original_scheduler_try_repair=S.try_repair;S.TECH_PRIESTS_0516_PRE_TRY_REPAIR=original_scheduler_try_repair;S.try_repair=function(p)if M.root().enabled==false or not valid_pair(p)then return original_scheduler_try_repair(p)end;local e=select(1,find_target(p));return valid(e)and M.submit_or_assign_repair_task(p,e,"scheduler-repair-adapter-0516")==true or false end end;return true
end
local function diagnostics()local D=rawget(_G,"TechPriestsEmergencyDiagnostics0468")or rawget(_G,"TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468");if not(D and type(D.pair_dump_lines)=="function")then return false end;if D.repair_executor_0516_recovery_wrapped then return true end;local previous=D.pair_dump_lines;D.repair_executor_0516_recovery_wrapped=true;D.pair_dump_lines=function(...)local lines=previous(...);lines=type(lines)=="table"and lines or{};local r=M.root();lines[#lines+1]="PAIR-DUMP-0468 REPAIR-EXECUTOR-0516 version="..M.version.." packs_removed="..safe(r.stats["packs-removed"]or 0).." packs_applied="..safe(r.stats["packs-applied"]or 0).." packs_refunded="..safe(r.stats["packs-refunded"]or 0).." refund_blocked="..safe(r.stats["refund-blocked"]or 0);return lines end;return true end
function M.install()M.root();wrap_legacy();diagnostics();if commands and commands.remove_command then pcall(commands.remove_command,"tp-repair-executor-0516")end;_G.TechPriestsRepairExecutor0516=M;if log then log("[Tech-Priests 0.1.674-dev] sole physical repair authority installed")end;return true end
return M
