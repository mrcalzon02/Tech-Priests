-- 1070: an unbuildable ghost never permits an unbounded visit sweep.
-- The existing broker's budget is enforced independently of action success.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=10700}
storage={tech_priests={pairs_by_station={}}}
local Ghost=require("scripts.core.construction_bootstrap_ghost_planner_0645")
local ids={11,21,31,41,51,61}
for _,id in ipairs(ids) do
  storage.tech_priests.pairs_by_station[id]={
    station={valid=true,unit_number=id},
    priest={valid=true,unit_number=id+1000}}
end
local visited={}
local function blocked_ghost(pair)
  local id=pair.station.unit_number
  visited[#visited+1]=id
  if id==21 then error("temporary construction fixture exception") end
  return id==41,"ghost-created-or-pending"
end
Ghost.service_pair=blocked_ghost
local function eval(budget,expected,acted,failed)
  local first=#visited
  local actual,processed,exhausted,errors=Ghost.service_all("broker",budget)
  assert(processed==#expected and actual==acted and errors==failed
    and exhausted==(budget>0 and #ids>processed),
    "ghost planner did not report bounded attempted work")
  for i,id in ipairs(expected) do
    assert(visited[first+i]==id,"ghost planner starved later stations")
  end
end
eval(0,{},0,0)
eval(2,{11,21},0,1)
eval(2,{31,41},1,0)
eval(2,{51,61},0,0)
eval(2,{11,21},0,1)
-- The cursor remains in Factorio storage, not unsaved module scope.
package.loaded["scripts.core.construction_bootstrap_ghost_planner_0645"]=nil
Ghost=require("scripts.core.construction_bootstrap_ghost_planner_0645")
Ghost.service_pair=blocked_ghost
eval(2,{31,41},1,0)
storage.tech_priests.pairs_by_station[31].station.valid=false
ids={11,21,41,51,61}
eval(2,{51,61},0,0)
local hook
_G.TechPriestsRuntimeTickBroker0600={register_service=function(spec)
  if spec.name=="construction_bootstrap_ghost_planner_0645" then hook=spec end
  return spec
end}
assert(Ghost.install() and hook and hook.budget==6,
  "ghost planner did not register with canonical broker")
local first=#visited
local pulse=hook.fn({tick=game.tick},1)
assert(pulse.processed==1 and pulse.acted==0
  and pulse.exhausted==true and pulse.failed==0
  and #visited==first+1 and visited[#visited]==11,
  "ghost planning callback ignored broker offered budget")
assert(storage.tech_priests.construction_bootstrap_ghost_planner_0645
  .last_serviced_station_1070==11,
  "ghost planning cursor was not persisted")
print("[ghost-broker-budget-1070] PASS blocked/failed sites, round-robin persistence, broker cap")
