-- scripts/core/consecration_executor_0515.lua
-- Tech Priests 0.1.674-dev base-state recovery.
-- Dispatcher-owned consecration with truthful claims, movement, refunds,
-- terminal cleanup, scheduler admission, and persistent refund custody.

local M = {
  version = "0.1.674-dev",
  storage_key = "consecration_executor_0515",
  service_time_ticks = 90,
  pair_cooldown_ticks = 45,
  target_cooldown_ticks = 60 * 8,
  no_item_retry_ticks = 60 * 5,
  max_candidates = 96,
  travel_limit_by_tier = { junior=18, intermediate=24, senior=30, ["planetary-magos"]=22, planetary=22 },
}
local original_sanctify, original_scheduler_try
local function Reservations() return rawget(_G,"TechPriestsWorkReservations0601") or require("scripts.core.work_reservations") end
local function WorkQueue() return rawget(_G,"TechPriestsWorkQueueAuthority0601") or require("scripts.core.work_queue_authority") end

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok,s=pcall(tostring,v); return ok and s or "?" end
local function lower(v) return string.lower(tostring(v or "")) end
local function dist2(a,b) if not(a and b) then return 1e12 end local x=(a.x or 0)-(b.x or 0);local y=(a.y or 0)-(b.y or 0);return x*x+y*y end
local function valid_pair(p) return type(p)=="table" and valid(p.station) and valid(p.priest) end
local function station_unit(p) return p and (p.station_unit or (valid(p.station) and p.station.unit_number)) end
local function priest_unit(p) return p and (p.priest_unit or (valid(p.priest) and p.priest.unit_number)) end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function owner_id(p) return safe(station_unit(p))..":"..safe(priest_unit(p)) end

local function tier(p)
  local n=lower((p and (p.tier or p.rank or p.priest_name)) or (valid(p and p.priest) and p.priest.name) or "")
  if n:find("planetary",1,true) or n:find("magos",1,true) then return "planetary-magos" end
  if n:find("senior",1,true) then return "senior" end
  if n:find("intermediate",1,true) then return "intermediate" end
  return "junior"
end
local function within_limit(p,e)
  if not(valid_pair(p) and valid(e)) then return false,"invalid" end
  local lim=tonumber(M.travel_limit_by_tier[tier(p)] or 22) or 22
  local ds=dist2(p.station.position,e.position)
  return ds<=lim*lim, ds<=lim*lim and nil or ("target-too-far:"..string.format("%.1f",math.sqrt(ds))..">"..lim)
end

function M.root()
  storage.tech_priests=storage.tech_priests or {}
  local r=storage.tech_priests[M.storage_key] or {enabled=true,dispatcher_owned=true,wrap_legacy=true,stats={},recent={}}
  storage.tech_priests[M.storage_key]=r;r.version=M.version
  -- One-time save reconciliation: the private claim ledger is retired.
  -- The 0601 reservation authority alone owns live sanctify claims.
  if not r.private_claims_retired_0515 then
    local legacy=0
    for _ in pairs(r.claims or r.target_claims or {}) do legacy=legacy+1 end
    r.legacy_claims_retired_count=legacy
    r.claims={};r.target_claims=r.claims
    r.private_claims_retired_0515=true
  end
  r.stats=r.stats or {};r.recent=r.recent or {}
  if r.enabled==nil then r.enabled=true end;if r.dispatcher_owned==nil then r.dispatcher_owned=true end;if r.wrap_legacy==nil then r.wrap_legacy=true end
  return r
end
local function stat(k,n) local r=M.root();r.stats[k]=(r.stats[k] or 0)+(n or 1) end
local function record(p,k,d) local r=M.root();stat(k);r.recent[#r.recent+1]={tick=now(),action=k,station=safe(station_unit(p)),priest=safe(priest_unit(p)),detail=safe(d)};while #r.recent>160 do table.remove(r.recent,1) end end

local function release_claim(p,state,why)
  local key=state and state.claim_key
  if not key then return false end
  local ok,R=pcall(Reservations)
  if not (ok and R and type(R.release_key)=="function") then return false end
  local released=R.release_key("sanctify",key,p)
  if released then record(p,"claim-release",safe(why).." key="..safe(key)) end
  return released
end
local function claim(p,e,state,why)
  local ok,R=pcall(Reservations)
  if not (ok and R and type(R.claim)=="function") then return false,"reservation-authority-unavailable" end
  local accepted,detail=R.claim("sanctify",e,p,60*12,{
    surface_index=e.surface.index,force_index=p.station.force.index,source="consecration-executor-0515"})
  if not accepted then return false,detail or "claimed-by-other" end
  state.claim_key=R.target_key(e)
  return true,detail
end

local function clear_timers(state)
  state.started_tick=nil;state.due_tick=nil;state.distance=nil;state.item=nil
end
local function stop_move(p,why)
  local f=rawget(_G,"tech_priests_stop_movement_0418")
  if type(f)=="function" then pcall(f,p,why or "consecration-terminal") end
end
local function current_order(p)
  local q=p and p.order_queue_0469
  return p and ((q and q.current) or p.active_order_0469)
end
local function is_consecration_order(o)
  local k=lower(o and (o.kind or o.type or o.key or o.source))
  return k:find("consecr",1,true)~=nil or k:find("sanct",1,true)~=nil
end
local function queue_terminal(p,state,status,why)
  local order=current_order(p)
  if not is_consecration_order(order) or (state.order_key and order.key~=state.order_key) then
    return false,"consecration-order-not-current"
  end
  local q=rawget(_G,"TECH_PRIESTS_ORDER_QUEUE_0469")
  local f=q and (status=="complete" and q.complete_current or status=="cancelled" and q.cancel_current or q.fail_current)
  if type(f)~="function" then return false,"canonical-queue-unavailable" end
  local ok,accepted,detail=pcall(f,p,why)
  return ok and accepted==true,ok and detail or safe(accepted)
end

local function terminal(p,state,status,why,keep_refund)
  release_claim(p,state,why);stop_move(p,why)
  -- Terminal acknowledgement must belong to this exact consecration order.
  -- If the queue cannot acknowledge it, retry without consuming a second item.
  if p.target==state.target then p.target=nil end
  p.mode=status=="complete" and "idle" or "consecration-"..status
  local acknowledged,detail=queue_terminal(p,state,status,why)
  if not acknowledged then
    p.mode="consecration-terminal-pending"
    state.phase="terminal-pending";state.pending_terminal_status=status
    state.pending_terminal_reason=why;state.last_blocker="order-terminal-blocked:"..safe(detail)
    record(p,"terminal-blocked",state.last_blocker)
    return false,state.last_blocker
  end
  clear_timers(state)
  state.phase=status;state.last_blocker=status=="complete" and nil or why
  state.target=nil;state.target_unit=nil;state.target_name=nil
  state.claim_key=nil;state.order_key=nil;state.pending_terminal_status=nil
  state.pending_terminal_reason=nil
  if not keep_refund then p.consecration_refund_custody_0515=nil end
  record(p,status,why)
  return status=="complete",why
end

local function target_from(v,seen)
  if valid(v) then return v end;if type(v)~="table" then return nil end;seen=seen or {};if seen[v] then return nil end;seen[v]=true
  for _,k in ipairs{"target","entity","machine","source","selected","current","task"} do local e=target_from(v[k],seen);if e then return e end end
end
local function requested_target(p) local o=current_order(p);return is_consecration_order(o) and target_from(o) or nil end
local function consecration_record(e) if valid(e) and type(_G.get_consecration_record)=="function" then local ok,r=pcall(_G.get_consecration_record,e);if ok then return r end end end
local function is_target(e) if valid(e) and type(_G.is_consecration_target)=="function" then local ok,v=pcall(_G.is_consecration_target,e);return ok and v==true end;return false end
local function maximum(rec,e)
  if rec and tonumber(rec.max_sanctification) then return tonumber(rec.max_sanctification) end
  if type(_G.get_base_sanctification_max)=="function" then local ok,v=pcall(_G.get_base_sanctification_max,e and e.force);if ok and tonumber(v) then return tonumber(v) end end
  return 100
end
local function item_for(station,missing) if type(_G.get_available_station_consecration_item)=="function" then local ok,v=pcall(_G.get_available_station_consecration_item,station,missing);if ok then return v end end end
local function station_has_item(station) if type(_G.station_has_consecration_item)=="function" then local ok,v=pcall(_G.station_has_consecration_item,station);return ok and v==true end;return false end
local function consume(station,name)
  if type(_G.consume_consecration_item_from_station)=="function" then local ok,v=pcall(_G.consume_consecration_item_from_station,station,name);return ok and v==true end
  return false
end
local function eligible(p,e,order)
  if not(valid_pair(p) and is_target(e)) then return false,"not-target" end
  if e.surface~=p.station.surface or e.force~=p.station.force then return false,"foreign-force-or-surface" end
  local in_range,why=within_limit(p,e);if not in_range then return false,why end
  local rec=consecration_record(e);if not rec then return false,"no-record" end
  local max=maximum(rec,e);local cur=tonumber(rec.sanctification) or 0;if max<=0 then return false,"bad-max" end;if cur>=max then return false,"full" end
  if (tonumber(rec.next_priest_consecration_tick_0515) or 0)>now() then return false,"target-cooldown" end
  local ok,R=pcall(Reservations);if not(ok and R and type(R.is_claimed)=="function") then return false,"reservation-authority-unavailable" end
  if R.is_claimed("sanctify",e,p) then return false,"claimed-by-other" end
  local missing=max-cur;local item=item_for(p.station,missing);if not item then return false,"no-useful-item" end
  local ratio=cur/max;local threshold=is_consecration_order(order) and .92 or (lower(p.mode):find("idle",1,true) and .70 or .50)
  if ratio>threshold and not is_consecration_order(order) then return false,"above-threshold" end
  return true,nil,{record=rec,current=cur,maximum=max,missing=missing,item=item,ratio=ratio}
end
local function find_target(p,order)
  if not station_has_item(p.station) then return nil,"no-consecration-item" end
  local explicit=requested_target(p)
  if explicit then
    local allowed,why,info=eligible(p,explicit,order)
    if allowed then return explicit,info,"explicit" end
    return nil,why or "explicit-target-ineligible"
  end
  local names=rawget(_G,"CONSECRATION_TARGET_NAME_LIST")
  if not names then return nil,"no-target-list" end
  local okW,W=pcall(WorkQueue)
  if not (okW and W and type(W.submit)=="function" and type(W.claim_nearest)=="function") then
    return nil,"shared-work-queue-unavailable"
  end
  local radius=tonumber(p.radius) or (type(_G.get_station_consecration_radius)=="function" and _G.get_station_consecration_radius(p.station)) or 32
  local entities={}
  local Scan=rawget(_G,"TechPriestsScanRouting0610")
  if Scan and type(Scan.find_entities)=="function" then
    local ok,found=pcall(Scan.find_entities,p.station.surface,{
      name=names,force=p.station.force,position=p.station.position,radius=radius
    },{category="consecration",record_negative=false})
    if ok then entities=found or {} end
  else
    local ok,found=pcall(function()
      return p.station.surface.find_entities_filtered{
        name=names,force=p.station.force,position=p.station.position,radius=radius}
    end)
    if ok then entities=found or {} end
  end
  local checked=0
  for _,e in pairs(entities) do
    checked=checked+1
    if checked>M.max_candidates then break end
    local allowed,_,info=eligible(p,e,order)
    if allowed then
      W.submit("sanctify",e,{
        priority=math.floor((1-info.ratio)*1000),
        ttl=60*15,source="consecration-discovery-0515"
      })
    end
  end
  local selected,why=W.claim_nearest(p,"sanctify",{
    search_radius=math.min(radius,M.travel_limit_by_tier[tier(p)] or radius),
    ttl=60*12,remove=false,
    accept=function(e) return select(1,eligible(p,e,order)) end
  })
  if not (selected and valid(selected.target)) then return nil,why or "no-eligible-target" end
  local _,_,info=eligible(p,selected.target,order)
  return selected.target,info,"shared-work"
end

local function move(p,e)
  local f=rawget(_G,"tech_priests_request_movement_0418");if type(f)~="function" then return false,"movement-authority-unavailable" end
  local ok,v,why=pcall(f,p,e.position,"consecration-executor-0515",{radius=1.25,owner="consecration_executor_0515",priority=705,ttl=900,distraction=defines and defines.distraction and defines.distraction.none})
  return ok and v==true, ok and (why or v) or v
end
local function apply(p,e,name,info)
  local ctx={source_type="tech-priest",method="priest-capsule-rite",priest_name=p.priest.name,priest_unit=p.priest.unit_number,station_name=p.station.name,station_unit=p.station.unit_number,item=name,order_id=current_order(p) and current_order(p).key,tick=now()}
  local f=rawget(_G,"tech_priests_0515_apply_consecration_from_source")
  if type(f)=="function" then local ok,d,r=pcall(f,e,name,ctx);return ok and d==true,r or d end
  return false,"apply-authority-unavailable"
end
local function refund(p,name,state,why)
  local f=rawget(_G,"tech_priests_safe_deposit_item")
  if type(f)=="function" then local ok,d,detail,n=pcall(f,p,name,1,"consecration-refund-0515");if ok and d==true and (tonumber(n) or 1)==1 then stat("refund-complete");return true end end
  p.consecration_refund_custody_0515={version=M.version,item=name,count=1,reason=why or "apply-failed",created_tick=now()}
  state.phase="return-refund";state.last_blocker="refund-storage-blocked";record(p,"refund-custody",name);return false
end
local function service_refund(p,state)
  local c=p.consecration_refund_custody_0515;if not c then return false,"no-refund" end
  local f=rawget(_G,"tech_priests_safe_deposit_item");if type(f)~="function" then state.phase="return-refund";return true,"storage-authority-unavailable" end
  local ok,d,why,n=pcall(f,p,c.item,c.count,"consecration-refund-retry-0515")
  if ok and d==true and (tonumber(n) or c.count)==c.count then p.consecration_refund_custody_0515=nil;return terminal(p,state,"failed",c.reason or "apply-failed") end
  state.phase="return-refund";state.last_blocker=safe(why);return true,"refund-blocked"
end

function M.on_order_released(p,order,why)
  if not (p and order and is_consecration_order(order)) then return false end
  local state=p.consecration_0515
  -- A new order must never inherit another rite's target or movement.
  if state and state.order_key==order.key then
    local preserve_terminal=why=="preempted" and state.pending_terminal_status~=nil
    release_claim(p,state,why);stop_move(p,"consecration-order-released")
    if p.target==state.target then p.target=nil end
    clear_timers(state);state.target=nil;state.target_unit=nil
    state.target_name=nil;state.claim_key=nil
    if preserve_terminal then
      -- The physical rite has already happened. Resumption only retries the
      -- queue terminal acknowledgement; it must not consume another capsule.
      state.phase="terminal-pending"
    else
      state.order_key=nil
      state.pending_terminal_status=nil;state.pending_terminal_reason=nil
      state.phase=p.consecration_refund_custody_0515 and "return-refund" or "none"
    end
  elseif order.reservation_key_0515 then
    local ok,R=pcall(Reservations)
    if ok and R and type(R.release_key)=="function" then R.release_key("sanctify",order.reservation_key_0515,p) end
  end
  if not p.consecration_refund_custody_0515 then
    local mode=lower(p.mode)
    if mode:find("consecr",1,true) or mode=="moving-to-consecrate" then p.mode="idle" end
  end
  record(p,"order-released",why)
  return true
end
function M.active(p)
  if not p then return false end
  if p.consecration_refund_custody_0515 then return true end
  local s=p.consecration_0515;local active={selected=true,["walk-to-target"]=true,["prepare-capsule-rite"]=true,["throw-or-apply-capsule"]=true,["return-refund"]=true}
  return (is_consecration_order(current_order(p)) and (not s or s.phase~="terminal-pending")) or (p.consecration_refund_custody_0515~=nil)
end
function M.service_pair(p,reason,forced)
  if M.root().enabled==false then return false,"disabled" end;if not valid_pair(p) then return false,"invalid-pair" end
  local state=p.consecration_0515 or {phase="none"};p.consecration_0515=state;state.version=M.version;state.last_service_tick=now();state.last_reason=safe(reason)
  if p.consecration_refund_custody_0515 then return service_refund(p,state) end
  local order=current_order(p)
  if not is_consecration_order(order) or order.status~="active" then
    release_claim(p,state,"not-current-order");state.target=nil;state.claim_key=nil;state.order_key=nil;clear_timers(state)
    state.phase="none";return false,"no-active-consecration-order"
  end
  if state.order_key and state.order_key~=order.key then
    release_claim(p,state,"order-changed");state.target=nil;state.claim_key=nil;clear_timers(state);state.phase="none"
  end
  state.order_key=order.key
  local ordered_target=requested_target(p)
  if valid(state.target) and valid(ordered_target) and state.target~=ordered_target then
    release_claim(p,state,"target-changed");state.target=nil;state.claim_key=nil;clear_timers(state)
  end
  if state.pending_terminal_status then
    return terminal(p,state,state.pending_terminal_status,state.pending_terminal_reason or "terminal-retry")
  end
  if (tonumber(p.next_consecration_tick) or 0)>now() then release_claim(p,state,"pair-cooldown");clear_timers(state);state.phase="cooldown";state.target=nil;state.claim_key=nil;p.target=nil;p.mode="consecration-cooldown";return false,"cooldown" end
  if state.no_item_retry_until and state.no_item_retry_until>now() and not forced then return false,"no-consecration-item-cooldown" end

  local explicit=requested_target(p)
  if valid(forced) and forced~=explicit then return false,"forced-target-not-current-order" end
  local target=explicit or (valid(state.target) and state.target);local info
  if target then local ok,why,i=eligible(p,target,order);if ok then info=i else return terminal(p,state,"failed",why or "target-invalid") end end
  if not target then
    target,info,state.target_source=find_target(p,order)
    if not target then release_claim(p,state,"no-target");clear_timers(state);state.target=nil;state.claim_key=nil;p.target=nil;state.phase="need-item";state.last_blocker=safe(info);if info=="no-consecration-item" or info=="no-useful-item" then state.no_item_retry_until=now()+M.no_item_retry_ticks end;p.mode=station_has_item(p.station) and "no-consecration-target" or "missing-consecration-supplies";record(p,"no-target",info);return false,info end
    local ok,why=claim(p,target,state,"selected-"..safe(state.target_source));if not ok then clear_timers(state);state.phase="target-claimed";state.last_blocker=why;return false,why end
    state.target=target;state.target_unit=target.unit_number;state.target_name=target.name
  else local ok,why=claim(p,target,state,"continue-"..safe(state.phase));if not ok then return terminal(p,state,"failed",why) end end
  p.target=target

  local reach=tonumber(rawget(_G,"PRIEST_CONSECRATION_REACH_DISTANCE_SQ")) or 16;local ds=dist2(p.priest.position,target.position)
  if ds>reach then local moved,why=move(p,target);state.distance=math.sqrt(ds);if not moved then return terminal(p,state,"failed","movement-request-failed:"..safe(why)) end;clear_timers(state);state.phase="walk-to-target";state.target=target;state.claim_key=Reservations().target_key(target);p.target=target;p.mode="moving-to-consecrate";record(p,"walk",state.distance);return true,"walk-to-target" end

  local item=info and info.item or item_for(p.station,info and info.missing or 1)
  if not(item and item.name) then state.no_item_retry_until=now()+M.no_item_retry_ticks;return terminal(p,state,"failed","no-useful-consecration-item") end
  if state.item~=item.name or state.target_unit~=target.unit_number then clear_timers(state) end
  state.item=item.name;state.target=target;state.target_unit=target.unit_number;state.target_name=target.name;state.claim_key=Reservations().target_key(target);state.phase="prepare-capsule-rite";state.started_tick=state.started_tick or now();state.due_tick=state.due_tick or now()+M.service_time_ticks;p.mode="performing-consecration-rite"
  if now()<state.due_tick then return true,"prepare-capsule-rite" end

  state.phase="throw-or-apply-capsule"
  if not consume(p.station,item.name) then state.no_item_retry_until=now()+M.no_item_retry_ticks;return terminal(p,state,"failed","consume-failed") end
  local ok,restored=apply(p,target,item.name,info)
  if not ok then if refund(p,item.name,state,"apply-failed:"..safe(restored)) then return terminal(p,state,"failed","apply-failed:"..safe(restored)) end;release_claim(p,state,"refund-pending");stop_move(p,"refund-pending");p.target=nil;p.mode="consecration-return-refund";return true,"refund-pending" end

  local rec=consecration_record(target);if rec then rec.next_priest_consecration_tick_0515=now()+M.target_cooldown_ticks end
  p.next_consecration_tick=now()+M.pair_cooldown_ticks;state.restored=restored;state.completed_tick=now();return terminal(p,state,"complete","consecration-complete-0515")
end

function M.submit_or_assign_consecration_task(p,target,reason)
  if not valid_pair(p) then return false,"invalid-pair" end
  local provisional=false
  if not valid(target) then
    local info,source
    target,info,source=find_target(p,current_order(p))
    provisional=source=="shared-work"
  end
  if not valid(target) then return false,"no-target" end
  local function release_provisional()
    if not provisional then return end
    local current=current_order(p)
    if is_consecration_order(current) and current.target==target then return end
    local ok,R=pcall(Reservations)
    if ok and R and type(R.release_key)=="function" then R.release_key("sanctify",R.target_key(target),p) end
  end
  local allowed,why=eligible(p,target,current_order(p))
  if not allowed then release_provisional();return false,"ineligible:"..safe(why) end
  local q=rawget(_G,"TECH_PRIESTS_ORDER_QUEUE_0469")
  if not (q and type(q.submit)=="function") then release_provisional();return false,"canonical-order-queue-unavailable" end
  local ok,accepted,status,order=pcall(q.submit,p,{
    kind="consecration",target=target,priority=700,
    reservation_key_0515=Reservations().target_key(target),
    source="consecration_executor_0515",purpose="consecration",
    reason=reason or "consecration-0515"
  })
  if not ok then release_provisional();return false,"queue-error:"..safe(accepted) end
  if status~="active" and status~="preempt" then release_provisional() end
  if accepted==true or status=="duplicate-merged" then
    record(p,"order-accepted",status)
    return true,status,order
  end
  release_provisional();record(p,"order-rejected",status)
  return false,status or "queue-rejected",order
end

local function wrap_legacy()
  if type(_G.sanctify_target_with_priest)=="function" and not original_sanctify then original_sanctify=_G.sanctify_target_with_priest;_G.TECH_PRIESTS_0515_PRE_SANCTIFY_TARGET_WITH_PRIEST=original_sanctify;_G.sanctify_target_with_priest=function(p,t,...)if M.root().enabled~=false and M.root().wrap_legacy~=false and valid_pair(p) then local ok,why=M.submit_or_assign_consecration_task(p,t,"legacy-adopted-0515");if not ok then return false,why end;return true,why end;return original_sanctify(p,t,...)end end
  local okS,S=pcall(require,"scripts.core.task_scheduler");if okS and S and type(S.try_consecration)=="function" and not original_scheduler_try then original_scheduler_try=S.try_consecration;S.TECH_PRIESTS_0515_PRE_TRY_CONSECRATION=original_scheduler_try;S.try_consecration=function(p)if M.root().enabled==false or not valid_pair(p) then return original_scheduler_try(p) end;local ok=M.submit_or_assign_consecration_task(p,requested_target(p),"scheduler-try-0515");return ok==true end end
end
local function wrap_diagnostics()
  local d=rawget(_G,"TechPriestsEmergencyDiagnostics0468") or rawget(_G,"TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468");if not(d and type(d.pair_dump_lines)=="function") or d.consecration_executor_0515_wrapped then return end
  local prev=d.pair_dump_lines;d.consecration_executor_0515_wrapped=true;d.pair_dump_lines=function()local lines=prev();local r=M.root();local claims=0;local ok,R=pcall(Reservations);if ok and R and type(R.count)=="function" then claims=R.count("sanctify") end;lines[#lines+1]="PAIR-DUMP-0468 CONSECRATION-0515 version="..M.version.." claims="..claims.." complete="..safe(r.stats.complete or 0).." refunds="..safe(r.stats["refund-complete"] or 0).." refund_custody="..safe(r.stats["refund-custody"] or 0);for _,p in pairs(pair_map()) do if valid_pair(p) then local s=p.consecration_0515 or {};local c=p.consecration_refund_custody_0515;lines[#lines+1]="PAIR-DUMP-0468 consecration["..safe(station_unit(p)).."] phase="..safe(s.phase).." target="..safe(s.target_name).."#"..safe(s.target_unit).." item="..safe(s.item).." blocker="..safe(s.last_blocker).." due="..safe(s.due_tick).." refund="..safe(c and c.item) end end;return lines end
end
function M.install()
  M.root();wrap_legacy();wrap_diagnostics();if commands and commands.remove_command then pcall(commands.remove_command,"tp-consecration-executor-0515") end
  _G.TechPriestsConsecrationExecutor0515=M
  if log then log("[Tech-Priests 0.1.674-dev] consecration lifecycle recovery armed") end
  return true
end
return M
