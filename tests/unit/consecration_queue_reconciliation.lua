-- Canonical consecration ownership regression (plain Lua 5.2).
-- Shared work discovery -> reservations -> per-priest queue -> executor.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path

local Queue=require("scripts.core.order_queue_0469")
local Work=require("scripts.core.work_queue_authority")
local Reservations=require("scripts.core.work_reservations")
local Consecration=require("scripts.core.consecration_executor_0515")
local Arbiter=require("scripts.core.action_state_arbiter_0488")
local Dispatcher=require("scripts.core.single_dispatcher_0510")
_G.TECH_PRIESTS_ORDER_QUEUE_0469=Queue
_G.TechPriestsWorkQueueAuthority0601=Work
_G.TechPriestsWorkReservations0601=Reservations
_G.TechPriestsConsecrationExecutor0515=Consecration
_G.TECH_PRIESTS_ACTION_STATE_ARBITER_0488=Arbiter
_G.CONSECRATION_TARGET_NAME_LIST={"test-machine"}
_G.PRIEST_CONSECRATION_REACH_DISTANCE_SQ=16
defines={distraction={none=0}}
game={tick=1000}

local function check(yes,label)
  if not yes then error("consecration reconciliation regression: "..label,2) end
end
local function fresh()
  game.tick=game.tick+10000
  storage={tech_priests={pairs_by_station={}}}
  local force={index=1,name="player",valid=true}
  local surface={index=1,name="nauvis",entities={}}
  local records=setmetatable({}, {__mode="k"})
  local supply={count=20,consumed=0,applied=0,refunded=0,apply=true,deposit=true}
  function surface.find_entities_filtered(filter)
    local found={}
    for _,e in ipairs(surface.entities) do
      if e.valid and (not filter.force or filter.force==e.force) then
        local d=(e.position.x-(filter.position and filter.position.x or 0))^2+
                (e.position.y-(filter.position and filter.position.y or 0))^2
        if not filter.radius or d<=filter.radius^2 then found[#found+1]=e end
      end
    end
    return found
  end
  local next_id=0
  local function entity(x,name)
    next_id=next_id+1
    return {valid=true,unit_number=next_id,name=name,position={x=x,y=0},
            surface=surface,force=force}
  end
  local target=entity(2,"test-machine")
  surface.entities={target}
  records[target]={sanctification=0,max_sanctification=100}
  _G.station_has_consecration_item=function()return supply.count>0 end
  _G.get_available_station_consecration_item=function()
    if supply.count>0 then return {name="test-oil"} end
  end
  _G.consume_consecration_item_from_station=function()
    if supply.count<=0 then return false end
    supply.count=supply.count-1;supply.consumed=supply.consumed+1;return true
  end
  _G.get_consecration_record=function(e)return records[e] end
  _G.is_consecration_target=function(e)return e.valid and records[e]~=nil end
  _G.tech_priests_0515_apply_consecration_from_source=function(e)
    supply.applied=supply.applied+1
    if not supply.apply then return false,"mock-rejection" end
    records[e].sanctification=records[e].sanctification+10
    return true,10
  end
  _G.tech_priests_safe_deposit_item=function(_,name,n)
    if not supply.deposit then return false,"mock-full",0 end
    supply.count=supply.count+n;supply.refunded=supply.refunded+n
    return true,"deposited",n
  end
  local function pair(x)
    local st=entity(x or 0,"test-station")
    local priest=entity(x or 0,"test-priest")
    local p={station=st,priest=priest,station_unit=st.unit_number,
             priest_unit=priest.unit_number,radius=16,tier="junior",mode="idle"}
    storage.tech_priests.pairs_by_station[st.unit_number]=p
    return p
  end
  return {target=target,surface=surface,force=force,records=records,
          supply=supply,pair=pair,p=pair(0)}
end
local function submit(f,p)
  local ok,status=Consecration.submit_or_assign_consecration_task(p,nil,"test")
  check(ok,"submit: "..tostring(status))
  return status
end
local function service_until_ready(p)
  local ok,why=Consecration.service_pair(p,"test")
  check(ok and why=="prepare-capsule-rite","preparation: "..tostring(why))
  game.tick=game.tick+Consecration.service_time_ticks+1
  return Consecration.service_pair(p,"test-finish")
end
local total=0
local function scenario(name,body)
  body()
  total=total+1
  print("[consecration-queue-regression] PASS "..name)
end

scenario("shared discovery and ordered execution",function()
  local f=fresh()
  check(submit(f,f.p)=="active","expected active per-priest order")
  check(Work.count("sanctify")>0,"shared sanctify work not discovered")
  check(Reservations.is_claimed("sanctify",f.target),"not reserved")
  check(f.p.active_task==nil,"unexpected immediate legacy task")
  check(not Queue.tick_pair(f.p,"idle-surface"),"idle prematurely completed consecration")
  local ok=service_until_ready(f.p)
  check(ok,"physical rite failed")
  check(f.supply.consumed==1 and f.supply.applied==1,"exactly one capsule consumed/applied")
  check(f.p.order_queue_0469.current==nil,"terminal did not complete queue")
  check(not Reservations.is_claimed("sanctify",f.target),"terminal leaked reservation")
end)

scenario("preemption pauses rite and releases custody-free claim",function()
  local f=fresh();submit(f,f.p)
  check(Consecration.service_pair(f.p,"start"),"rite did not prepare")
  local ok=Queue.submit(f.p,{kind="repair",target=f.target,priority=800,source="test"})
  check(ok and f.p.order_queue_0469.current.kind=="repair","repair failed to preempt")
  check(not Reservations.is_claimed("sanctify",f.target),"preemption kept sanctify claim")
  check(not Consecration.service_pair(f.p,"should-wait"),"noncurrent consecration executed")
  check(f.supply.consumed==0,"preempted rite consumed an item")
  check(Queue.complete_current(f.p,"repair-done"),"repair completion failed")
  check(f.p.order_queue_0469.current.kind=="consecration","consecration was not resumed")
  check(service_until_ready(f.p),"resumed rite did not finish")
  check(f.supply.consumed==1,"resumed rite consumed duplicate items")
end)

scenario("pending request does not reserve or execute",function()
  local f=fresh()
  check(Queue.submit(f.p,{kind="repair",target=f.target,priority=800,source="test"}),"repair start")
  check(submit(f,f.p)=="queued","expected queued consecration")
  check(not Reservations.is_claimed("sanctify",f.target),"pending claim leaked")
  check(not Consecration.service_pair(f.p,"pending"),"queued rite executed")
  check(f.supply.consumed==0,"queued rite consumed item")
  check(Queue.complete_current(f.p,"repair-done"),"repair finish")
  check(f.p.order_queue_0469.current.kind=="consecration","pending was not promoted")
  check(service_until_ready(f.p),"promoted rite did not complete")
end)

scenario("cancellation and expiry release reservations",function()
  local f=fresh();submit(f,f.p)
  check(Queue.cancel_current(f.p,"cancelled"),"cancel failed")
  check(not Reservations.is_claimed("sanctify",f.target),"cancel leaked reservation")
  check(not Consecration.service_pair(f.p,"after-cancel"),"cancelled rite executed")
  submit(f,f.p)
  local o=f.p.order_queue_0469.current
  o.expires_tick=game.tick-1
  check(Queue.tick_pair(f.p,"expired"),"expired order not terminated")
  check(not Reservations.is_claimed("sanctify",f.target),"expiration leaked reservation")
end)

scenario("shared reservation excludes competing priests",function()
  local f=fresh();local other=f.pair(0)
  submit(f,f.p)
  local accepted=Consecration.submit_or_assign_consecration_task(other,f.target,"competing-priest")
  check(not accepted,"different priest stole reserved target")
  check(Queue.cancel_current(f.p,"withdrawn"),"cancel first owner")
  local ok=Consecration.submit_or_assign_consecration_task(other,f.target,"second-priest")
  check(ok,"released target could not be assigned to second priest")
  check(Queue.cancel_current(other,"withdrawn"),"cancel second owner")
end)

scenario("failed application retains and refunds exact capsule",function()
  local f=fresh();f.supply.apply=false;f.supply.deposit=false;submit(f,f.p)
  local prepared=Consecration.service_pair(f.p,"start")
  check(prepared,"preparation rejected")
  game.tick=game.tick+Consecration.service_time_ticks+1
  local ok,why=Consecration.service_pair(f.p,"application")
  check(ok and why=="refund-pending","expected durable refund custody")
  check(f.p.consecration_refund_custody_0515~=nil,"lost refund custody")
  check(f.p.order_queue_0469.current.kind=="consecration","refund order not retained")
  check(f.supply.consumed==1,"wrong capsule consumption")
  f.supply.deposit=true
  Consecration.service_pair(f.p,"refund")
  check(f.p.consecration_refund_custody_0515==nil,"refund custody not cleared")
  check(f.supply.refunded==1,"capsule refund not exact")
  check(f.supply.consumed==1,"failed rite retried consumption")
  check(f.p.order_queue_0469.current==nil,"refund terminal not acknowledged")
end)

scenario("foreign-force target rejected before queue admission",function()
  local f=fresh()
  local target=f.target
  local other={index=2,name="enemy",valid=true}
  target.force=other
  local ok=Consecration.submit_or_assign_consecration_task(f.p,target,"foreign")
  check(not ok,"foreign target accepted")
  check(f.p.order_queue_0469==nil,"foreign target entered queue")
end)

scenario("adopted legacy rite can preempt, resume and retire exactly once",function()
  local f=fresh()
  local task={type="consecration",target=f.target}
  f.p.active_task=task
  f.p.active_task_0285=task
  check(Queue.tick_pair(f.p,"adopt"),"legacy task not adopted")
  check(f.p.order_queue_0469.current.kind=="consecration","wrong adopted family")
  check(Consecration.service_pair(f.p,"start"),"adopted rite not started")
  check(Queue.submit(f.p,{kind="repair",target=f.target,priority=800,source="test"}),"repair preemption failed")
  check(Queue.complete_current(f.p,"repair-finished"),"repair terminal failed")
  check(f.p.order_queue_0469.current.kind=="consecration","adopted rite not resumed")
  check(service_until_ready(f.p),"adopted rite did not finish")
  check(f.p.active_task==nil and f.p.active_task_0285==nil,"legacy task resurrectable")
  check(not Queue.tick_pair(f.p,"post-complete"),"completed legacy task adopted twice")
end)

scenario("terminal queue rejection retries without second capsule",function()
  local f=fresh();submit(f,f.p)
  check(Consecration.service_pair(f.p,"begin"),"rite preparation failed")
  game.tick=game.tick+Consecration.service_time_ticks+1
  local saved=Queue.complete_current
  Queue.complete_current=function()return false,"simulated-temporary-rejection" end
  local result,why=Consecration.service_pair(f.p,"complete-with-blocked-queue")
  Queue.complete_current=saved
  check(not result and tostring(why):find("order-terminal-blocked",1,true),"failed to preserve terminal-pending")
  check(f.supply.consumed==1 and f.supply.applied==1,"initial application did not occur once")
  check(f.p.order_queue_0469.current~=nil,"queue unexpectedly acknowledged")
  local done=Consecration.service_pair(f.p,"terminal-retry")
  check(done,"terminal acknowledgement retry failed")
  check(f.supply.consumed==1 and f.supply.applied==1,"repeated application after terminal retry")
  check(f.p.order_queue_0469.current==nil,"terminal retry did not finish order")
end)

scenario("destroyed target fails order and releases shared claim",function()
  local f=fresh();submit(f,f.p)
  f.target.valid=false
  check(Queue.tick_pair(f.p,"target-destroyed"),"invalid target not failed")
  check(f.p.order_queue_0469.current==nil,"destroyed order remained active")
  check(not Reservations.is_claimed("sanctify",f.target),"destroyed target claim not released")
end)

scenario("legacy sanctify entry point enqueues without executing",function()
  local f=fresh()
  local old_calls=0
  _G.sanctify_target_with_priest=function()old_calls=old_calls+1;return true end
  check(Consecration.install(),"consecration install failed")
  local ok=_G.sanctify_target_with_priest(f.p,f.target)
  check(ok,"legacy entry point failed to enqueue")
  check(f.p.order_queue_0469.current.kind=="consecration","legacy entry did not create canonical order")
  check(old_calls==0 and f.supply.consumed==0,"legacy entry executed outside dispatcher")
  Queue.cancel_current(f.p,"test-done")
end)

scenario("acknowledged effect survives preemption without replay",function()
  local f=fresh();submit(f,f.p)
  check(Consecration.service_pair(f.p,"begin"),"preparation failed")
  game.tick=game.tick+Consecration.service_time_ticks+1
  local saved=Queue.complete_current
  Queue.complete_current=function()return false,"temporary" end
  Consecration.service_pair(f.p,"effect-applied")
  Queue.complete_current=saved
  check(f.supply.applied==1,"effect not applied")
  check(f.p.consecration_0515.pending_terminal_status=="complete","terminal state lost")
  check(Queue.submit(f.p,{kind="repair",target=f.target,priority=800,source="test"}),"preemption failed")
  check(Queue.complete_current(f.p,"repair-finished"),"repair complete failed")
  check(f.p.order_queue_0469.current.kind=="consecration","rite not promoted")
  check(Consecration.service_pair(f.p,"resume-ack"),"terminal acknowledgement failed")
  check(f.supply.consumed==1 and f.supply.applied==1,"consecration replayed after preemption")
end)

scenario("expired paused legacy rite is not resurrected",function()
  local f=fresh()
  local task={type="consecration",target=f.target}
  f.p.active_task=task
  check(Queue.tick_pair(f.p,"adopt"),"legacy adoption failed")
  check(Consecration.service_pair(f.p,"start"),"legacy start")
  check(Queue.submit(f.p,{kind="repair",target=f.target,priority=800,source="test"}),"preemption failed")
  local pending=f.p.order_queue_0469.pending[1]
  check(pending and pending.kind=="consecration","paused rite missing")
  pending.expires_tick=game.tick-1
  check(Queue.complete_current(f.p,"repair-done"),"repair completion failed")
  check(f.p.order_queue_0469.current==nil,"expired rite promoted")
  check(f.p.consecration_0515.phase=="none","expired rite state not cleared")
  check(f.p.active_task==nil,"expired legacy task still adoptable")
  check(not Queue.tick_pair(f.p,"post-expiry"),"expired task re-adopted")
end)

scenario("old private claims retired during save reconciliation",function()
  local f=fresh()
  storage.tech_priests.consecration_executor_0515={
    claims={legacy={owner="old",expires_tick=game.tick+9999}}
  }
  local root=Consecration.root()
  check(root.private_claims_retired_0515==true,"migration marker missing")
  check(root.legacy_claims_retired_count==1,"legacy claim count not recorded")
  check(next(root.claims)==nil,"old authority still holds claims")
end)

scenario("destroyed target stable-key release refuses nonowner",function()
  local f=fresh();local other=f.pair(0)
  check(Reservations.claim("sanctify",f.target,f.p),"initial reservation failed")
  local key=Reservations.target_key(f.target)
  f.target.valid=false
  check(not Reservations.release_key("sanctify",key,other),"foreign priest released reservation")
  check(Reservations.is_claimed("sanctify",f.target),"unauthorized release removed reservation")
  check(Reservations.release_key("sanctify",key,f.p),"original owner could not release by key")
  check(not Reservations.is_claimed("sanctify",f.target),"reservation retained after release")
end)

scenario("disabled shared reservation authority rejects admission",function()
  local f=fresh()
  local root=Reservations.root()
  root.enabled=false
  local ok=Consecration.submit_or_assign_consecration_task(f.p,f.target,"disabled-reservation")
  root.enabled=true
  check(not ok,"consecration admitted without shared reservation authority")
  check(f.p.order_queue_0469==nil,"order queued despite disabled reservation authority")
end)

scenario("unavailable canonical order queue releases provisional shared claim",function()
  local f=fresh()
  _G.TECH_PRIESTS_ORDER_QUEUE_0469=nil
  local ok=Consecration.submit_or_assign_consecration_task(f.p,nil,"queue-down")
  _G.TECH_PRIESTS_ORDER_QUEUE_0469=Queue
  check(not ok,"consecration accepted without per-priest queue")
  check(not Reservations.is_claimed("sanctify",f.target),"failed enqueue leaked provisional claim")
  check(submit(f,f.p)=="active","recovered queue could not take work")
end)


scenario("destroyed active target never redirects to a different machine",function()
  local f=fresh();submit(f,f.p)
  local spare={valid=true,unit_number=9001,name="test-machine",
    position={x=3,y=0},surface=f.surface,force=f.force}
  f.surface.entities[#f.surface.entities+1]=spare
  f.records[spare]={sanctification=0,max_sanctification=100}
  f.target.valid=false
  local ok=Consecration.service_pair(f.p,"direct-dispatch-after-destruction")
  check(not ok,"destroyed order should fail instead of silently redirecting")
  check(f.p.order_queue_0469.current==nil,"destroyed order was not retired")
  check(f.supply.consumed==0 and f.supply.applied==0,"invalid target consumed capsule")
  check(f.records[spare].sanctification==0,"replacement target was altered")
  check(not Reservations.is_claimed("sanctify",f.target),"destroyed order leaked claim")
end)

scenario("preempted terminal acknowledgement survives noncurrent service",function()
  local f=fresh();submit(f,f.p)
  check(Consecration.service_pair(f.p,"begin"),"preparation failed")
  game.tick=game.tick+Consecration.service_time_ticks+1
  local saved=Queue.complete_current
  Queue.complete_current=function()return false,"simulated-temporary-rejection" end
  Consecration.service_pair(f.p,"effect-applied")
  Queue.complete_current=saved
  check(f.supply.consumed==1 and f.supply.applied==1,"physical effect not applied once")
  check(Queue.submit(f.p,{kind="repair",priority=800,source="test"}),"preemption failed")
  local ok,reason=Consecration.service_pair(f.p,"out-of-turn-call")
  check(not ok and reason=="terminal-awaiting-own-order","foreign order erased pending acknowledgement")
  check(f.p.consecration_0515.pending_terminal_status=="complete","pending completion was lost")
  check(f.p.order_queue_0469.current.kind=="repair","preempting repair order mutated")
  check(Queue.complete_current(f.p,"repair-done"),"repair terminal failed")
  check(Consecration.service_pair(f.p,"resume-ack"),"rite acknowledgement failed")
  check(f.supply.consumed==1 and f.supply.applied==1,"rite repeated after foreign dispatch")
end)

scenario("refunded capsule remains tied to paused order",function()
  local f=fresh();f.supply.apply=false;f.supply.deposit=false
  submit(f,f.p)
  check(Consecration.service_pair(f.p,"begin"),"preparation failed")
  game.tick=game.tick+Consecration.service_time_ticks+1
  local ok,reason=Consecration.service_pair(f.p,"apply-rejected")
  check(ok and reason=="refund-pending","refund custody was not created")
  check(Queue.submit(f.p,{kind="repair",priority=800,source="test"}),"preemption failed")
  f.supply.deposit=true
  local restored,detail=Consecration.service_pair(f.p,"refund-while-preempted")
  check(restored and detail=="refund-restored-awaiting-order","preempted refund was not retained for its order")
  check(f.p.order_queue_0469.current.kind=="repair","refund completed unrelated repair")
  check(f.p.consecration_0515.pending_terminal_status=="failed","failed rite acknowledgement lost")
  check(Queue.complete_current(f.p,"repair-done"),"repair terminal failed")
  Consecration.service_pair(f.p,"failed-rite-acknowledge")
  check(f.p.order_queue_0469.current==nil,"failed rite not acknowledged")
  check(f.supply.consumed==1 and f.supply.refunded==1,"capsule custody was duplicated or lost")
end)

scenario("cancelled rite refunds without retiring subsequent order",function()
  local f=fresh();f.supply.apply=false;f.supply.deposit=false
  submit(f,f.p)
  check(Consecration.service_pair(f.p,"begin"),"preparation failed")
  game.tick=game.tick+Consecration.service_time_ticks+1
  Consecration.service_pair(f.p,"application")
  check(f.p.consecration_refund_custody_0515~=nil,"refund custody not created")
  check(Queue.cancel_current(f.p,"cancel-after-application"),"cancellation failed")
  check(Queue.submit(f.p,{kind="repair",priority=800,source="test"}),"replacement repair start failed")
  f.supply.deposit=true
  local ok,why=Consecration.service_pair(f.p,"custody-after-cancel")
  check(ok and why=="refund-restored-without-order","cancelled order kept or misacknowledged refund")
  check(f.p.order_queue_0469.current.kind=="repair","refund retired unrelated repair")
  check(f.supply.consumed==1 and f.supply.refunded==1,"cancelled refund inaccurate")
  check(f.p.consecration_refund_custody_0515==nil,"cancelled refund custody retained")
end)

scenario("disabled legacy entry point cannot bypass the canonical queue",function()
  local f=fresh()
  local root=Consecration.root()
  local old_root_enabled=root.enabled
  root.enabled=false
  local ok,why=_G.sanctify_target_with_priest(f.p,f.target)
  root.enabled=old_root_enabled
  check(ok==false and why=="consecration-disabled","disabled adapter invoked legacy executor")
  check(f.p.order_queue_0469==nil,"disabled adapter created order")
  check(f.supply.consumed==0 and f.supply.applied==0,"disabled adapter consumed a capsule")
end)

scenario("legacy wrap toggle cannot restore direct consecration",function()
  local f=fresh()
  local root=Consecration.root()
  root.wrap_legacy=false
  local accepted=_G.sanctify_target_with_priest(f.p,f.target)
  root.wrap_legacy=true
  check(accepted==true,"legacy admission adapter rejected canonical queue")
  check(f.p.order_queue_0469.current.kind=="consecration","legacy toggle bypassed queue")
  check(f.supply.consumed==0 and f.supply.applied==0,"legacy toggle executed physical rite")
  check(Queue.cancel_current(f.p,"test-retire"),"legacy toggle cleanup failed")
end)

scenario("competing explicit consecration orders cannot both become active",function()
  local f=fresh();local other=f.pair(0)
  local first,first_status=Consecration.submit_or_assign_consecration_task(
    f.p,f.target,"explicit-first")
  check(first and first_status=="active","first explicit target not admitted")
  local second=Consecration.submit_or_assign_consecration_task(
    other,f.target,"explicit-competing")
  check(not second,"competing explicit rite admitted")
  check(other.order_queue_0469==nil,"competing priest received phantom order")
  check(Queue.cancel_current(f.p,"first-withdrawn"),"first explicit order not cancelled")
  local accepted=Consecration.submit_or_assign_consecration_task(
    other,f.target,"explicit-after-release")
  check(accepted,"second priest could not claim released target")
  check(Queue.cancel_current(other,"second-withdrawn"),"second order not retired")
end)

scenario("queued explicit consecration does not hold shared reservation",function()
  local f=fresh()
  check(Queue.submit(f.p,{kind="repair",target=f.target,priority=800,source="test"}),
        "repair did not begin")
  local accepted,status=Consecration.submit_or_assign_consecration_task(
    f.p,f.target,"explicit-pending")
  check(accepted and status=="queued","explicit consecration was not queued")
  check(not Reservations.is_claimed("sanctify",f.target),
        "pending explicit rite held target reservation")
  check(Queue.complete_current(f.p,"repair-done"),"repair completion failed")
  check(f.p.order_queue_0469.current.kind=="consecration","queued rite not promoted")
  check(service_until_ready(f.p),"queued explicit rite did not complete")
end)

scenario("dispatcher services preempted consecration refund before unrelated repair",function()
  local f=fresh();f.supply.apply=false;f.supply.deposit=false
  submit(f,f.p)
  check(Consecration.service_pair(f.p,"prepare"),"rite not prepared")
  game.tick=game.tick+Consecration.service_time_ticks+1
  local applied,reason=Consecration.service_pair(f.p,"apply")
  check(applied and reason=="refund-pending","failed rite did not retain capsule")
  check(Queue.submit(f.p,{kind="repair",priority=800,source="test"}),
        "repair failed to preempt pending restitution")
  local active=f.p.order_queue_0469.current
  check(active and active.kind=="repair","repair not current")
  check(Arbiter.action(f.p).kind=="consecration","classifier abandoned held capsule")
  local blocked=Dispatcher.service_pair(f.p,"refund-storage-blocked")
  check(blocked.blocked==1 and blocked.acted==0,"blocked refund incorrectly reported action")
  check(f.p.order_queue_0469.current==active,"refund finished unrelated repair")
  check(f.supply.consumed==1 and f.supply.refunded==0,
        "blocked refund altered supply accounting")
  check(Arbiter.action(f.p).kind=="repair",
        "blocked refund monopolized higher-priority work during retry backoff")
  f.supply.deposit=true
  game.tick=game.tick+Consecration.refund_retry_ticks+1
  check(Arbiter.action(f.p).kind=="consecration",
        "scheduled refund was not readmitted after backoff")
  local settled=Dispatcher.service_pair(f.p,"refund-storage-restored")
  check(settled.acted==1 and settled.failed==0,"dispatcher failed to refund capsule")
  check(f.supply.refunded==1 and f.supply.consumed==1,
        "dispatcher duplicated or lost consecration capsule")
  check(f.p.order_queue_0469.current==active,"refund retired repair order")
  check(Arbiter.action(f.p).kind=="repair","dispatcher did not resume interrupted repair")
  check(Queue.cancel_current(f.p,"clean-up"),"repair clean-up failed")
end)

scenario("stalled restitution yields to repair custody and resumes without a second rite",function()
  local f=fresh();f.supply.apply=false;f.supply.deposit=false
  submit(f,f.p)
  check(Consecration.service_pair(f.p,"prepare"),"rite not prepared")
  game.tick=game.tick+Consecration.service_time_ticks+1
  Consecration.service_pair(f.p,"apply")
  check(Queue.submit(f.p,{kind="repair",priority=800,source="test"}),"repair not started")
  local hold=f.p.consecration_refund_custody_0515
  check(hold~=nil,"lost consecration capsule")
  f.p.repair_pack_custody_0516={count=1}
  check(Arbiter.action(f.p).kind=="repair","consecration displaced live repair-pack custody")
  f.p.repair_pack_custody_0516=nil
  f.p.idle_conversation=true
  check(Arbiter.action(f.p).kind=="consecration",
        "idle conversation wrongly outranked due physical refund")
  f.p.idle_conversation=nil
  local blocked=Dispatcher.service_pair(f.p,"storage-full")
  check(blocked.blocked==1,"blocked restitution was not reported")
  check(Arbiter.action(f.p).kind=="repair","refund backoff failed to yield repair")
  check(f.p.consecration_refund_custody_0515==hold,"backoff discarded custody")
  game.tick=game.tick+Consecration.refund_retry_ticks+1
  f.supply.deposit=true
  local result=Dispatcher.service_pair(f.p,"after-retry")
  check(result.acted==1,"refund did not recover")
  check(f.supply.consumed==1 and f.supply.refunded==1,
        "refund retried consecration effect or lost capsule")
  check(f.p.order_queue_0469.current.kind=="repair",
        "refunding stole repair terminal ownership")
end)

scenario("combat retains priority over consecration refund custody",function()
  local f=fresh();f.supply.apply=false;f.supply.deposit=false
  submit(f,f.p)
  check(Consecration.service_pair(f.p,"prepare"),"rite not prepared")
  game.tick=game.tick+Consecration.service_time_ticks+1
  Consecration.service_pair(f.p,"apply")
  check(Queue.submit(f.p,{kind="combat",priority=900,source="test"}),
        "combat did not preempt rite")
  check(Arbiter.action(f.p).kind=="combat","refund incorrectly displaced combat")
  check(f.supply.refunded==0,"combat classification changed custody")
  check(Queue.cancel_current(f.p,"combat-ended"),"combat cleanup failed")
  check(Arbiter.action(f.p).kind=="consecration",
        "refund custody not restored to dispatcher after combat")
end)

scenario("disabled reservation claims fail closed without consuming queued work",function()
  local f=fresh()
  local root=Reservations.root()
  root.enabled=false
  local ok,why=Reservations.claim("sanctify",f.target,f.p)
  check(not ok and why=="disabled","disabled reservation claimed success")
  check(Reservations.count("sanctify")==0,"disabled authority created reservation")
  check(Work.submit("sanctify",f.target),"could not enqueue work for recovery")
  local selected,reason=Work.claim_nearest(f.p,"sanctify",{search_radius=16})
  check(not selected and reason=="reservation-authority-disabled",
        "queue bypassed disabled reservation authority")
  check(Work.count("sanctify")==1,"disabled authority consumed shared work")
  root.enabled=true
  local recovered,status=Work.claim_nearest(f.p,"sanctify",{search_radius=16})
  check(recovered and status=="claimed","re-enabled authority failed to claim pending work")
  check(Reservations.release_key("sanctify",recovered.reservation_key,f.p),
        "recovered shared claim not released")
end)

scenario("claim rejects missing reservation interface without discarding work",function()
  local f=fresh()
  check(Work.submit("sanctify",f.target),"shared work submit failed")
  local original=Reservations.claim
  Reservations.claim=nil
  local order,why=Work.claim_nearest(f.p,"sanctify",{search_radius=16})
  Reservations.claim=original
  check(not order and why=="reservation-authority-unavailable",
        "work claimed without required reservation interface")
  check(Work.count("sanctify")==1,"unavailable authority erased pending work")
  check(Reservations.count("sanctify")==0,"missing authority left a reservation")
end)

scenario("missing authority-issued claim key rolls back the exact provisional reservation",function()
  local f=fresh()
  check(Work.submit("sanctify",f.target),"shared work submit failed")
  local original=Reservations.claim
  Reservations.claim=function(...)
    local ok,why,res=original(...)
    if ok then return ok,why,{} end
    return ok,why,res
  end
  local claimed,why=Work.claim_nearest(f.p,"sanctify",{search_radius=16})
  Reservations.claim=original
  check(not claimed and why=="reservation-identity-unavailable",
        "claim without reservation identity was accepted")
  check(Reservations.count("sanctify")==0,"provisional claim leaked after missing identity")
  check(Work.count("sanctify")==1,"missing identity lost pending work")
  local retry,status=Work.claim_nearest(f.p,"sanctify",{search_radius=16})
  check(retry and status=="claimed" and retry.reservation_key,
        "failed provisional rollback prevented subsequent claim")
  check(Reservations.release_key("sanctify",retry.reservation_key,f.p),
        "retry reservation was not released")
end)

scenario("shared claim preserves stable release key after target destruction",function()
  local f=fresh()
  check(Work.submit("sanctify",f.target),"shared work submit failed")
  local selected,why=Work.claim_nearest(f.p,"sanctify",{search_radius=16})
  check(selected and why=="claimed" and type(selected.reservation_key)=="string",
        "shared work did not propagate a stable reservation key")
  local key=selected.reservation_key
  check(Reservations.is_claimed("sanctify",f.target),"shared claim not persisted")
  f.target.valid=false
  check(Reservations.release_key("sanctify",key,f.p),
        "destroyed target reservation could not be released by identity")
  check(Reservations.count("sanctify")==0,"destroyed target left a reservation")
end)

scenario("target invalidated during shared claim releases provisional identity",function()
  local f=fresh()
  local original=Reservations.claim
  Reservations.claim=function(...)
    local ok,why,res=original(...)
    if ok then
      f.target.valid=false
      f.target.unit_number=nil -- Cannot reconstruct the issued unit key afterward.
    end
    return ok,why,res
  end
  local accepted=Consecration.submit_or_assign_consecration_task(
    f.p,nil,"destroyed-mid-claim")
  Reservations.claim=original
  check(not accepted,"destroyed target admitted a consecration order")
  check(Reservations.count("sanctify")==0,
        "destroyed target leaked the already-acquired provisional claim")
  check(Work.count("sanctify")==0,
        "invalidated shared target remained in the discovery backlog")
  check(f.p.order_queue_0469==nil,"invalidated target entered canonical order queue")
  check(f.supply.consumed==0 and f.supply.applied==0,
        "invalidated target consumed or applied a consecration capsule")
end)

scenario("explicit admission releases destroyed midclaim target by issued key",function()
  local f=fresh()
  local original=Reservations.claim
  Reservations.claim=function(...)
    local ok,why,res=original(...)
    if ok then
      f.target.valid=false
      f.target.unit_number=nil
    end
    return ok,why,res
  end
  local accepted,why=Consecration.submit_or_assign_consecration_task(
    f.p,f.target,"explicit-midclaim-destruction")
  Reservations.claim=original
  check(not accepted and why=="target-invalid-after-claim",
        "explicit admission accepted a destroyed target")
  check(Reservations.count("sanctify")==0,
        "explicit admission leaked reservation after entity identity loss")
  check(f.p.order_queue_0469==nil,"destroyed explicit target reached the canonical queue")
  check(f.supply.consumed==0,"explicit midclaim destruction consumed a capsule")
end)

scenario("direct executor releases invalidated claim before physical rite",function()
  local f=fresh()
  submit(f,f.p)
  local original=Reservations.claim
  Reservations.claim=function(...)
    local ok,why,res=original(...)
    if ok then
      f.target.valid=false
      f.target.unit_number=nil
    end
    return ok,why,res
  end
  local ok=Consecration.service_pair(f.p,"destroy-inside-renewal")
  Reservations.claim=original
  check(not ok,"executor continued with target destroyed inside reservation renewal")
  check(Reservations.count("sanctify")==0,
        "executor left owner reservation after target destruction")
  check(f.supply.consumed==0 and f.supply.applied==0,
        "executor performed rite after target destruction")
  check(f.p.order_queue_0469.current==nil,
        "destroyed target order remained active")
end)

scenario("explicit queue failure releases captured key even after entity identity changes",function()
  local f=fresh()
  local original=Queue.submit
  Queue.submit=function()
    f.target.valid=false
    f.target.unit_number=nil
    return false,"mock-queue-rejection"
  end
  local ok=Consecration.submit_or_assign_consecration_task(
    f.p,f.target,"queue-rejection-after-invalidating-entity")
  Queue.submit=original
  check(not ok,"queue rejection was treated as consecration acceptance")
  check(Reservations.count("sanctify")==0,
        "queue rejection leaked reservation when entity identity vanished")
  check(f.p.order_queue_0469==nil,
        "rejected order entered canonical queue")
end)

scenario("shared queue requires ownership-safe release interface",function()
  local f=fresh()
  check(Work.submit("sanctify",f.target),"submit failed")
  local saved=Reservations.release_key
  Reservations.release_key=nil
  local order,why=Work.claim_nearest(f.p,"sanctify",{search_radius=16})
  Reservations.release_key=saved
  check(not order and why=="reservation-authority-unavailable",
        "queue admitted claim without a safe release interface")
  check(Work.count("sanctify")==1,"guard silently consumed pending work")
  check(Reservations.count("sanctify")==0,"guard acquired a claim without release support")
end)

scenario("generic shared work rejects a target destroyed inside acquisition",function()
  local f=fresh()
  check(Work.submit("repair",f.target),"repair discovery failed")
  local saved=Reservations.claim
  Reservations.claim=function(...)
    local ok,why,res=saved(...)
    if ok then
      f.target.valid=false
      f.target.unit_number=nil
    end
    return ok,why,res
  end
  local order,why=Work.claim_nearest(f.p,"repair",{search_radius=16})
  Reservations.claim=saved
  check(not order and why=="target-invalid-after-claim",
        "shared queue dispatched a destroyed repair target")
  check(Reservations.count("repair")==0,"generic repair claim was not released")
  check(Work.count("repair")==0,"destroyed repair target remained queued")
end)

print("[consecration-queue-regression] PASS scenarios="..total)
