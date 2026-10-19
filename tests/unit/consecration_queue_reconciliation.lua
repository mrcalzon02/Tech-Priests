-- Canonical consecration ownership regression (plain Lua 5.2).
-- Shared work discovery -> reservations -> per-priest queue -> executor.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path

local Queue=require("scripts.core.order_queue_0469")
local Work=require("scripts.core.work_queue_authority")
local Reservations=require("scripts.core.work_reservations")
local Consecration=require("scripts.core.consecration_executor_0515")
_G.TECH_PRIESTS_ORDER_QUEUE_0469=Queue
_G.TechPriestsWorkQueueAuthority0601=Work
_G.TechPriestsWorkReservations0601=Reservations
_G.TechPriestsConsecrationExecutor0515=Consecration
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

print("[consecration-queue-regression] PASS scenarios="..total)
