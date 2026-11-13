-- Deterministic Lua unit regression for first Cogitator cold-service spread.
-- Does NOT claim native Factorio wall-clock timing or global script UPS.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=100}
storage={tech_priests={pairs_by_station={}}}
local Broker=require("scripts.core.runtime_tick_broker")
local station={valid=true,unit_number=77}
local priest={valid=true,unit_number=78}
local pair={station=station,priest=priest}
storage.tech_priests.pairs_by_station[77]=pair
local immediate={
  "lifecycle","dispatcher","combat","movement",
  "recovery","safety","authority"}
local seen={}
for _,cat in ipairs(immediate)do
  local name="critical-"..cat
  assert(Broker.register_service{
    name=name,category=cat,interval=1000,budget=1,
    fn=function()
      seen[name]=(seen[name]or 0)+1
      return {processed=1,acted=0}
    end
  })
end
local n=40
for i=1,n do
  local name="planning-"..i
  assert(Broker.register_service{
    name=name,category=(i%2==0 and "construction" or "background"),
    interval=1000,budget=1,
    fn=function()
      seen[name]=(seen[name]or 0)+1
      return {processed=1,acted=0}
    end
  })
end
local ok,reason=Broker.stagger_first_station_wake_1407(pair)
assert(ok and reason=="nonessential-first-wake-work-staggered")
local state=Broker.root().first_station_wake_1407
assert(state and state.tick==100 and state.station_unit==77
  and state.deferred_services==n
  and state.immediate_services==#immediate
  and state.longest_delay_ticks>0
  and state.longest_delay_ticks<=120)
local distinct,targets={},{}
local minimum,maximum=math.huge,0
for _,service in ipairs(Broker.services)do
  assert(service.enabled~=false,"cold spread disabled an original service")
  if service.category=="construction" or service.category=="background"then
    assert(service.next_due_tick>100 and service.next_due_tick<=220)
    minimum=math.min(minimum,service.next_due_tick)
    maximum=math.max(maximum,service.next_due_tick)
    distinct[service.next_due_tick]=true
  else
    assert(service.next_due_tick==0,
      "critical movement/defense/lifecycle/dispatcher was delayed")
  end
end
local nslots=0
for _ in pairs(distinct)do nslots=nslots+1 end
assert(nslots>=20 and maximum-minimum>70,
  "forty cold planning services still collapsed onto one update tick")
-- The first scheduled pulse must run ONLY hard real-time services.
Broker.pulse({tick=100})
for _,cat in ipairs(immediate)do
  assert(seen["critical-"..cat]==1,"first tick lost critical service "..cat)
end
for i=1,n do
  assert(not seen["planning-"..i],
    "first placement pulse still ran every expensive planning service")
end
-- All other services eventually run, once, with their existing cadence.
for t=101,220 do
  game.tick=t
  Broker.pulse({tick=t})
end
for i=1,n do
  assert(seen["planning-"..i]==1,
    "delayed planning service never resumed or ran repeatedly: "..i)
end
for _,cat in ipairs(immediate)do
  assert(seen["critical-"..cat]==1,
    "critical service ran unexpectedly before original cadence")
end
local second,why=Broker.stagger_first_station_wake_1407(pair)
assert(not second and why=="already-spread-first-station")
local second_station={valid=true,unit_number=90}
storage.tech_priests.pairs_by_station[90]={
  station=second_station,priest={valid=true,unit_number=91}}
local refuse,reason=Broker.stagger_first_station_wake_1407(pair)
assert(not refuse and reason=="not-the-first-station")
print("[first-station-wake-1407] PASS 40 deferred real services spread <=120 ticks, seven critical immediate, no disabled duties")
