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
