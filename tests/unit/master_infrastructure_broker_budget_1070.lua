-- 1070: actual budgeted broker traversal, including a failing station,
-- preserves fair station selection across saved state and module reload.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=10700}
storage={tech_priests={pairs_by_station={}}}
local Plan=require("scripts.core.master_infrastructure_plan_0644")
local ids={10,20,30,40,50}
for _,id in ipairs(ids) do
  storage.tech_priests.pairs_by_station[id]={
    station={valid=true,unit_number=id},
    priest={valid=true,unit_number=id+1000}
  }
end
local visited={}
local function fake_service(pair)
  local id=pair.station.unit_number
  visited[#visited+1]=id
  if id==20 then error("station temporarily unavailable") end
  return true,"planned"
end
Plan.service_pair=fake_service
local function evaluate(budget,want,worked,errors)
  local before=#visited
  local acted,processed,exhausted,failed=Plan.service_all("broker",budget)
  assert(processed==#want and acted==worked and failed==errors
    and exhausted==(budget>0 and #ids>processed),
    "broker count/budget incorrectly reports attempted work")
  for i,id in ipairs(want) do
    assert(visited[before+i]==id,
      "round robin failed after error, save/reload, or station changes")
  end
end
evaluate(0,{},0,0)
evaluate(2,{10,20},1,1)
evaluate(2,{30,40},2,0)
evaluate(2,{50,10},2,0)
evaluate(2,{20,30},1,1)
-- Persistent cursor survives module reload, without saving transient Lua
-- profiler/module objects into storage.
local cursor=storage.tech_priests.master_infrastructure_plan_0644
  .last_serviced_station_1070
assert(cursor==30,"station traversal cursor not durable")
package.loaded["scripts.core.master_infrastructure_plan_0644"]=nil
Plan=require("scripts.core.master_infrastructure_plan_0644")
Plan.service_pair=fake_service
evaluate(2,{40,50},2,0)
assert(storage.tech_priests.master_infrastructure_plan_0644
  .last_serviced_station_1070==50,"reload resumed at wrong station")
storage.tech_priests.pairs_by_station[10]=nil
storage.tech_priests.pairs_by_station[60]={
  station={valid=true,unit_number=60},priest={valid=true,unit_number=1060}}
ids={20,30,40,50,60}
evaluate(2,{60,20},1,1)
-- An invalid pair cannot consume budget or block other valid stations.
storage.tech_priests.pairs_by_station[30].priest.valid=false
ids={20,40,50,60}
evaluate(2,{40,50},2,0)
-- The installed broker callback must actually *forward* the offered budget,
-- rather than ignoring it and traversing the whole population.
package.loaded["scripts.core.construction_bootstrap_ghost_planner_0645"]={
  install=function()return true end}
local captured
_G.TechPriestsRuntimeTickBroker0600={register_service=function(spec)
  if spec.name=="master_infrastructure_plan_0644" then
    captured=spec
  end
  return spec
end}
assert(Plan.install()==true and captured and captured.budget==8,
  "master survey did not install under the canonical runtime broker")
local before=#visited
local result=captured.fn({tick=10700},1)
assert(result.processed==1 and result.acted==1
  and result.exhausted==true and result.failed==0
  and #visited==before+1 and visited[#visited]==60,
  "broker callback ignored one-work-unit budget or cursor")
print("[master-infrastructure-budget-1070] PASS bounded visits, failure fairness, reload, broker budget")

-- Exercise the real broker and its admission/deadline owner, not a callback
-- loop that ignores scheduling. One visit per pulse must retain the former
-- up-to-eight visits per ~100-tick cycle, including reload and failed visits.
local Broker,Economy,attempts,polls,movement,throw_id
local function install_scheduler()
  package.loaded["scripts.core.runtime_tick_broker"]=nil
  package.loaded["scripts.core.efficiency_economy_0598"]=nil
  package.loaded["scripts.core.master_infrastructure_plan_0644"]=nil
  Broker=require("scripts.core.runtime_tick_broker")
  Economy=require("scripts.core.efficiency_economy_0598")
  Economy.install()
  _G.TechPriestsRuntimeTickBroker0600=Broker
  Plan=require("scripts.core.master_infrastructure_plan_0644")
  Plan.service_pair=function(pair)
    local id=pair.station.unit_number
    attempts[#attempts+1]={id=id,tick=game.tick}
    if id==throw_id then error("failed survey") end
    return true,"planned"
  end
  assert(Plan.install())
  for i=1,3 do
    local name="competing-poll-"..i
    assert(Broker.register_service{name=name,category="planning",interval=5,
      next_due_tick=5,budget=1,fn=function()
        polls[name]=(polls[name] or 0)+1;return {processed=1,acted=1}
      end})
  end
  assert(Broker.register_service{name="movement",category="movement",interval=5,
    budget=1,fn=function()movement=movement+1;return {processed=1,acted=1}end})
end
local function service()
  for _,entry in ipairs(Broker.services) do
    if entry.name=="master_infrastructure_plan_0644" then return entry end
  end
  error("missing real broker service")
end
local function pulse(tick)
  game.tick=tick
  local before=#attempts
  Broker.pulse{tick=tick}
  assert(#attempts-before<=1,"separate station surveys collapsed into one pulse")
end
local function world(population)
  storage={tech_priests={pairs_by_station={}}}
  game={tick=0}
  attempts,polls,movement={}, {}, 0
  throw_id=nil
  for i=1,population do
    local id=i*10
    storage.tech_priests.pairs_by_station[id]={
      station={valid=true,unit_number=id},priest={valid=true,unit_number=id+1000}}
  end
  install_scheduler()
  service().next_due_tick=5
end
world(4)
for tick=5,100,5 do pulse(tick) end
assert(#attempts==4,"four-station population lost or duplicated its first survey cycle")
for i=1,4 do
  assert(attempts[i].id==i*10 and attempts[i].tick==i*5,
    "four stations were not spread across separate broker pulses")
end
for tick=105,200,5 do pulse(tick) end
assert(#attempts==8,"budget smoothing reduced the former four-station refresh throughput")
for i=1,4 do
  assert(attempts[i+4].id==i*10 and attempts[i+4].tick-attempts[i].tick==100,
    "per-station refresh interval grew after spreading the batch")
end
assert(movement==40,"survey continuation slowed active movement")
for _,count in pairs(polls) do assert(count==40,"survey continuation starved a competing poll") end

world(12)
throw_id=20
pulse(5);pulse(10)
local cycle=storage.tech_priests.master_infrastructure_plan_0644.broker_cycle
local saved=storage.tech_priests.efficiency_economy_0598.broker_deadlines
  .master_infrastructure_plan_0644
assert(cycle.next_due_tick==15 and saved.next_due_tick==15,
  "the governor persisted the old long deadline instead of the continuation")
-- Remove a snapshotted station and add a new one while the batch is pending.
-- The removed slot consumes one bounded attempt; the newcomer enters the
-- next cycle through the existing station cursor.
storage.tech_priests.pairs_by_station[30]=nil
storage.tech_priests.pairs_by_station[130]={
  station={valid=true,unit_number=130},priest={valid=true,unit_number=1130}}
game.tick=12
install_scheduler()
assert(service().next_due_tick==15,"reload lost the saved continuation deadline")
for tick=15,100,5 do pulse(tick) end
local stats=Broker.root().service_stats.master_infrastructure_plan_0644
assert(stats.processed==8 and stats.failed==1 and stats.acted==6,
  "failure/removal lost the eight-attempt quota or falsely reported success")
assert(#attempts==7 and attempts[3].id==40 and attempts[7].id==80,
  "reload skipped/repeated a station or retried an invalid slot indefinitely")
assert(service().next_due_tick==102,
  "finishing a spread batch postponed the original cycle deadline")
for tick=105,200,5 do pulse(tick) end
assert(stats.processed==16,"spread visits cut the old eight-attempt cycle throughput")
local next_ids={90,100,110,120,130,10,20,40}
for index,id in ipairs(next_ids) do
  assert(attempts[7+index].id==id,"persistent cursor starved a tail/new station")
end
assert(stats.failed==2,"failed stations stopped receiving their fair later attempts")

world(4)
assert(Broker.register_service{name="competing-poll-4",category="planning",
  interval=5,next_due_tick=5,budget=1,fn=function()
    polls["competing-poll-4"]=(polls["competing-poll-4"] or 0)+1
    return {processed=1,acted=1}
  end})
for tick=5,300,5 do pulse(tick) end
assert(#attempts==12,"admission contention cut the four-station cycle quota")
local admission=storage.tech_priests.efficiency_economy_0598.stats
assert(admission.broker_background_deferred>0 and admission.broker_background_peak==4,
  "continuations bypassed the canonical shared admission cap")
for _,count in pairs(polls) do assert(count>=50,"continuations starved another due poll") end
assert(movement==60,"shared background contention deferred active movement")

world(0)
for tick=5,100,5 do pulse(tick) end
assert(#attempts==0 and Broker.root().service_stats.master_infrastructure_plan_0644.run==1,
  "an empty survey batch created a five-tick polling loop")
storage.tech_priests.pairs_by_station[10]={
  station={valid=true,unit_number=10},priest={valid=true,unit_number=1010}}
pulse(105)
assert(#attempts==1 and attempts[1].id==10,"empty cycle hid a newly added station")
print("[master-infrastructure-budget-1070] PASS real broker: one visit per pulse, unchanged cycle throughput, admission fairness, failure/removal accounting and saved continuation deadlines")
