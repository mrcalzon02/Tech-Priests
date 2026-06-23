-- Tech Priests 0.1.660 repair executor integrity hardener.
-- Keeps repair_executor_0516 as the sole repair state machine while enforcing
-- truthful movement, reservation release, timer cleanup, physical pack cost,
-- verified task submission, and immediate order handoff.

local M = { version = "0.1.660", storage_key = "repair_executor_integrity_0673" }
local previous_service, previous_submit, previous_active, previous_install

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function lower(v) return string.lower(tostring(v or "")) end
local function safe(v) if v == nil then return "nil" end; local ok,s=pcall(tostring,v); return ok and s or "?" end
local function valid_pair(p) return type(p)=="table" and valid(p.station) and valid(p.priest) end
local function station_unit(p) return p and (p.station_unit or (valid(p.station) and p.station.unit_number) or "nil") or "nil" end
local function dist_sq(a,b) if not(a and b) then return nil end; local dx=(a.x or a[1] or 0)-(b.x or b[1] or 0); local dy=(a.y or a[2] or 0)-(b.y or b[2] or 0); return dx*dx+dy*dy end
local function load(name, global_name) local ok,m=pcall(require,name); if ok then return m end; return rawget(_G,global_name) end
local function Repair() return load("scripts.core.repair_executor_0516","TechPriestsRepairExecutor0516") end
local function Reservations() return load("scripts.core.work_reservations","TechPriestsWorkReservations0601") end
local function OrderQueue() return load("scripts.core.order_queue_0469","TECH_PRIESTS_ORDER_QUEUE_0469") end

function M.root()
  storage.tech_priests=storage.tech_priests or {}
  local r=storage.tech_priests[M.storage_key] or {version=M.version,enabled=true,stats={},recent={}}
  storage.tech_priests[M.storage_key]=r; r.version=M.version
  if r.enabled==nil then r.enabled=true end; r.stats=r.stats or {}; r.recent=r.recent or {}
  return r
end
local function stat(k,n) local r=M.root(); r.stats[k]=(r.stats[k] or 0)+(n or 1) end
local function record(pair,k,detail)
  local r=M.root(); stat(k); r.recent[#r.recent+1]={tick=now(),station=station_unit(pair),action=k,detail=tostring(detail or "")}
  while #r.recent>120 do table.remove(r.recent,1) end
end
local function order_kind(o) return lower(o and (o.kind or o.type or o.key or o.source) or "") end
local function is_repair_order(o) local k=order_kind(o); return k=="repair" or k:find("repair",1,true)~=nil end
local function current_order(p) local q=p and p.order_queue_0469; return p and ((q and q.current) or p.active_order_0469) or nil end
local function target_from(v,seen)
  if valid(v) then return v end; if type(v)~="table" then return nil end
  seen=seen or {}; if seen[v] then return nil end; seen[v]=true
  for _,k in ipairs({"target","entity","machine","source","selected","current","task"}) do local t=target_from(v[k],seen); if t then return t end end
end
local function candidate_target(p,forced)
  if valid(forced) then return forced end
  local s=p and p.repair_0516; if s and valid(s.target) then return s.target end
  local o=current_order(p); if is_repair_order(o) then local t=target_from(o); if t then return t end end
  for _,f in ipairs({"active_task","active_task_0285"}) do local t=p and p[f]; if type(t)=="table" and is_repair_order(t) then local e=target_from(t); if e then return e end end end
end
local function keys(entity,state)
  if valid(entity) then
    if entity.unit_number then return tostring(entity.unit_number),"unit:"..tostring(entity.unit_number) end
    local p=entity.position or {x=0,y=0}; local pos=string.format("%.1f,%.1f",p.x or 0,p.y or 0)
    return tostring(entity.name).."@"..pos,"entity:"..tostring(entity.name)..":"..pos
  end
  local u=state and state.target_unit; if u then return tostring(u),"unit:"..tostring(u) end
end
local function missing_health(e)
  if not valid(e) then return 0 end
  local fn=rawget(_G,"get_repair_pack_useful_missing_health"); if type(fn)=="function" then local ok,v=pcall(fn,e); if ok and tonumber(v) then return math.max(0,tonumber(v)) end end
  if not(e.health and e.max_health) then return 0 end; return math.max(0,(tonumber(e.max_health) or 0)-(tonumber(e.health) or 0))
end
local function station_inventory(pair)
  local fn=rawget(_G,"get_station_inventory"); if type(fn)~="function" or not valid_pair(pair) then return nil end
  local ok,inv=pcall(fn,pair.station); return ok and inv and inv.valid and inv or nil
end
local function pack_count(pair) local inv=station_inventory(pair); if not inv then return 0 end; local ok,n=pcall(function() return inv.get_item_count("repair-pack") end); return ok and (tonumber(n) or 0) or 0 end
local function refund_pack(pair)
  local inv=station_inventory(pair); local inserted=0
  if inv then local ok,n=pcall(function() return inv.insert({name="repair-pack",count=1}) end); if ok then inserted=tonumber(n) or 0 end end
  if inserted<1 and valid_pair(pair) and pair.station.surface and pair.station.surface.spill_item_stack then
    local ok=pcall(function() pair.station.surface.spill_item_stack{position=pair.station.position,stack={name="repair-pack",count=1},enable_looted=true,force=pair.station.force,allow_belts=false} end)
    if ok then inserted=1 end
  end
  return inserted>=1
end
local function release(pair,target,state)
  local local_key,shared_key=keys(target,state); local R=Reservations()
  if R and type(R.release)=="function" and valid(target) then pcall(R.release,"repair",target,pair)
  elseif R and type(R.root)=="function" and shared_key then
    local ok,root=pcall(R.root); local bucket=ok and root and root.reservations and root.reservations.repair
    if bucket then local res=bucket[shared_key]; local pid=R.pair_id and R.pair_id(pair) or station_unit(pair); if not res or safe(res.pair_id)==safe(pid) then bucket[shared_key]=nil end end
  end
  local X=Repair(); if X and type(X.root)=="function" and local_key then local ok,r=pcall(X.root); if ok and r and r.reservations then r.reservations[local_key]=nil end end
end
local function clear_tasks(pair,target)
  for _,f in ipairs({"active_task","active_task_0285"}) do local t=pair[f]; if type(t)=="table" and is_repair_order(t) then local e=target_from(t); if not target or not e or e==target then pair[f]=nil end end end
end
local function clear_state(pair,phase,blocker,release_first)
  local s=pair.repair_0516 or {}; local old=valid(s.target) and s.target or nil
  if release_first then release(pair,old,s) end; if pair.target==old or (pair.target and not valid(pair.target)) then pair.target=nil end
  for _,f in ipairs({"target","target_unit","target_name","target_source","started_tick","due_tick","packs_used","distance","missing","max_health","last_restore","integrity_target_key_0673"}) do s[f]=nil end
  if phase then s.phase=phase end; if blocker~=nil then s.last_blocker=blocker end; pair.repair_0516=s
end
local function history(pair,order,status,why)
  local q=pair.order_queue_0469; if not(q and order) or order.integrity_history_0673 then return end
  q.history=q.history or {}; q.history[#q.history+1]={tick=now(),key=order.key,kind=order.kind,item=order.item,status=status,why=why,source="repair-integrity-0673"}
  while #q.history>200 do table.remove(q.history,1) end; order.integrity_history_0673=true
end
local function promote(pair,reason) local Q=OrderQueue(); if Q and type(Q.tick_pair)=="function" then pcall(Q.tick_pair,pair,reason or "repair-integrity-promote-0673"); stat("order_promote_attempted") end end
local function finish(pair,target,reason,set_target_cooldown)
  local X=Repair(); local s=pair.repair_0516 or {}; local r=X and type(X.root)=="function" and X.root() or {}; local k=keys(target,s)
  if set_target_cooldown and k then r.cooldowns=r.cooldowns or {}; r.cooldowns[k]=now()+(tonumber(X and X.target_cooldown_ticks) or 120) end
  release(pair,target,s); pair.next_repair_tick_0516=now()+(tonumber(X and X.pair_cooldown_ticks) or 20); pair.target=nil; pair.mode="idle"; clear_tasks(pair,target); clear_state(pair,"complete",nil,false)
  local o=current_order(pair); if is_repair_order(o) then o.status="complete"; o.finished_tick=now(); o.finish_reason=reason or "repair-complete-0673"; history(pair,o,"complete",o.finish_reason); local q=pair.order_queue_0469; if q and q.current==o then q.current=nil end; if pair.active_order_0469==o then pair.active_order_0469=nil end end
  promote(pair,reason)
end
local function movement_matches(pair,target)
  local req=pair.movement_request_0418
  if not req and storage and storage.tech_priests and storage.tech_priests.movement_controller_0419 then local root=storage.tech_priests.movement_controller_0419; req=root.requests and root.requests[tostring(station_unit(pair))] end
  if not(req and valid(target)) then return false end; local p=req.position or req.destination or req.target_position or req.target; if valid(p) then p=p.position end; if type(p)~="table" then return false end
  local owner=lower(req.owner or req.reason); if (dist_sq(p,target.position) or 999)>4 then return false end; return owner:find("repair",1,true)~=nil or owner:find("leaf",1,true)~=nil
end
local function task_installed(pair,target)
  local q=pair.order_queue_0469; local o=current_order(pair)
  if is_repair_order(o) then local e=target_from(o); if not target or not e or e==target then return true end end
  for _,o2 in ipairs(q and q.pending or {}) do if is_repair_order(o2) then local e=target_from(o2); if not target or not e or e==target then return true end end end
  for _,f in ipairs({"active_task","active_task_0285"}) do local t=pair[f]; if type(t)=="table" and is_repair_order(t) then local e=target_from(t); if not target or not e or e==target then return true end end end
  return false
end

local function patch_submit(X)
  if previous_submit or type(X.submit_or_assign_repair_task)~="function" then return end; previous_submit=X.submit_or_assign_repair_task
  X.submit_or_assign_repair_task=function(pair,target,reason)
    if M.root().enabled==false then return previous_submit(pair,target,reason) end
    local ok,accepted=pcall(previous_submit,pair,target,reason); if not ok then record(pair,"submit_error",accepted); return false end
    local actual=valid(target) and target or candidate_target(pair); if accepted~=false and task_installed(pair,actual) then return true end
    if not(valid_pair(pair) and valid(actual)) then record(pair,"submit_rejected","no-installed-task"); return false end
    local task={type="repair",kind="repair",phase="repair-service",key="repair",visual="repairing",target=actual,priority=800,owner_system="repair-executor-integrity-0673"}
    pair.active_task=task; pair.active_task_0285=task; pair.target=actual; pair.mode="repairing"
    local submit=rawget(_G,"tech_priests_0469_submit_order"); if type(submit)=="function" then local ok2,allowed,why=pcall(submit,pair,{kind="repair",item="repair-pack",target=actual,priority=800,source="repair_executor_integrity_0673",task=task}); if not ok2 then record(pair,"order_submit_error",allowed) elseif allowed==false and why~="queued" and why~="duplicate" then record(pair,"order_submit_rejected",why) end end
    record(pair,"submit_recovered",reason); return true
  end
end
local function patch_active(X)
  if previous_active or type(X.active)~="function" then return end; previous_active=X.active
  X.active=function(pair)
    if M.root().enabled==false then return previous_active(pair) end; if not pair then return false end
    local phase=lower((pair.repair_0516 or {}).phase); if phase=="walk-to-target" or phase=="repair-target" then return true end; if is_repair_order(current_order(pair)) then return true end
    if phase=="none" or phase=="complete" or phase=="cooldown" or phase=="no-target" or phase=="need-item" or phase=="target-invalid" or phase=="target-reserved" or phase=="movement-request-failed" then return false end
    return lower(pair.mode):find("repair",1,true)~=nil
  end
end
local function patch_service(X)
  if previous_service or type(X.service_pair)~="function" then return end; previous_service=X.service_pair
  X.service_pair=function(pair,reason,forced)
    if M.root().enabled==false then return previous_service(pair,reason,forced) end; if not valid_pair(pair) then return false,"invalid-pair" end
    local xr=type(X.root)=="function" and X.root() or {}; if xr.dispatcher_owned==false and lower(reason):find("dispatcher",1,true) then return false,"dispatcher-ownership-disabled" end
    local s=pair.repair_0516 or {phase="none"}; pair.repair_0516=s; local before_order=current_order(pair); local before_target=candidate_target(pair,forced); local before_health=valid(before_target) and tonumber(before_target.health); local before_count=pack_count(pair); local before_used=tonumber(s.packs_used) or 0
    if tonumber(pair.next_repair_tick_0516 or 0)>now() then release(pair,before_target,s); clear_state(pair,"cooldown",nil,false); pair.target=nil; pair.mode="repair-cooldown"; return true,"cooldown" end
    if valid(before_target) then
      local k=keys(before_target,s); local cd=k and xr.cooldowns and (tonumber(xr.cooldowns[k]) or 0)>now()
      if missing_health(before_target)<=0.01 or cd then finish(pair,before_target,cd and "repair-target-cooldown-0673" or "repair-already-full-0673",false); record(pair,"stale_target_completed",before_target.name); return true,"complete" end
      if s.integrity_target_key_0673~=k then s.started_tick=nil; s.due_tick=nil; s.packs_used=nil; s.integrity_target_key_0673=k end
    elseif s.target or s.target_unit then release(pair,nil,s); clear_state(pair,"target-invalid","invalid-stale-target",false) end
    local ok,acted,why=pcall(previous_service,pair,reason,forced); if not ok then release(pair,candidate_target(pair,forced),pair.repair_0516); clear_state(pair,"executor-error",safe(acted),false); pair.mode="repair-executor-error"; record(pair,"service_error",acted); return false,"repair-executor-error" end
    s=pair.repair_0516 or s; local after=valid(s.target) and s.target or before_target; if valid(after) and not s.integrity_target_key_0673 then s.integrity_target_key_0673=keys(after,s) end; local result=tostring(why or "")
    if result=="walk-to-target" and valid(after) and not movement_matches(pair,after) then release(pair,after,s); clear_state(pair,"movement-request-failed","missing-repair-movement-request-0673",false); pair.mode="repair-movement-failed"; record(pair,"false_movement_rejected",after.name); return false,"movement-request-failed" end
    if result=="no-repair-pack" or result=="consume-failed" or result=="movement-request-failed" or result=="target-reserved" or result=="no-eligible-target" or result=="target-invalid" then release(pair,after,s); clear_state(pair,s.phase,s.last_blocker or result,false); pair.target=nil; if result=="no-repair-pack" or result=="consume-failed" then pair.mode="missing-repair-supplies" end; record(pair,"blocked_state_released",result); return acted,why end
    local charged=(tonumber(s.packs_used) or 0)>before_used or pack_count(pair)<before_count
    if charged and valid(after) and before_health then local ah=tonumber(after.health) or before_health; if ah<=before_health+0.001 then refund_pack(pair); release(pair,after,s); clear_state(pair,"health-write-failed","repair-pack-refunded-0673",false); pair.mode="repair-health-write-failed"; record(pair,"health_write_failed",after.name); return false,"health-write-failed" end; s.last_restore=ah-before_health end
    if xr.full_repair==false and result=="repair-pack-applied" and valid(after) then finish(pair,after,"repair-single-pack-complete-0673",true); record(pair,"single_pack_complete",after.name); return true,"complete" end
    if result=="complete" or s.phase=="complete" then local completed=valid(after) and after or before_target; local o=before_order or current_order(pair); if is_repair_order(o) then o.status="complete"; o.finished_tick=o.finished_tick or now(); o.finish_reason=o.finish_reason or "repair-complete-0673"; history(pair,o,"complete",o.finish_reason) end; release(pair,completed,s); clear_tasks(pair,completed); clear_state(pair,"complete",nil,false); pair.target=nil; pair.mode="idle"; promote(pair,"repair-complete-promote-0673"); record(pair,"completion_hardened",completed and completed.name); return true,"complete" end
    return acted,why
  end
end
local function remove_command() if commands and commands.remove_command then pcall(commands.remove_command,"tp-repair-executor-0516") end end
local function patch_install(X) if previous_install or type(X.install)~="function" then return end; previous_install=X.install; X.install=function(...) local result=previous_install(...); remove_command(); return result end end
local function patch_diagnostics()
  local D=rawget(_G,"TechPriestsEmergencyDiagnostics0468") or rawget(_G,"TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468"); if not(D and type(D.pair_dump_lines)=="function") or D.repair_executor_integrity_0673_wrapped then return end
  local prev=D.pair_dump_lines; D.repair_executor_integrity_0673_wrapped=true; D.pair_dump_lines=function() local lines=prev(); local r=M.root(); lines[#lines+1]="PAIR-DUMP-0468 REPAIR-INTEGRITY-0673 enabled="..safe(r.enabled).." completed="..safe(r.stats.completion_hardened or 0).." released="..safe(r.stats.blocked_state_released or 0).." false_move="..safe(r.stats.false_movement_rejected or 0).." health_fail="..safe(r.stats.health_write_failed or 0).." submit_recovered="..safe(r.stats.submit_recovered or 0); return lines end
end
function M.install()
  M.root(); local X=Repair(); if not X then if log then log("[Tech-Priests 0.1.660] repair integrity unavailable: repair_executor_0516 missing") end; return false end
  patch_submit(X); patch_active(X); patch_service(X); patch_install(X); remove_command(); patch_diagnostics(); _G.TechPriestsRepairExecutorIntegrity0673=M
  if log then log("[Tech-Priests 0.1.660] repair integrity hardener installed; reservations, timers, movement, health writes, submission, and completion handoff verified") end
  return true
end
return M
