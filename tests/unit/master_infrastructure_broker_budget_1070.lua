-- Actual 0644 admission and the shared force-planning broker. The former
-- "one complete station per callback" fixture hid the single-factory stall.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=10700};storage={tech_priests={pairs_by_station={}}};defines={events={}}
local captured={}
_G.TechPriestsRuntimeEventRegistry={on_event=function()return{}end,on_configuration_changed=function()return{}end}
_G.TechPriestsRuntimeTickBroker0600={base_interval=5,register_service=function(s)captured[s.name]=s;return s end}
package.loaded["scripts.core.construction_bootstrap_ghost_planner_0645"]={install=function()return true end}
local Q=require("scripts.core.force_planning_queue")
local Plan=require("scripts.core.master_infrastructure_plan_0644")
local force={valid=true,index=1,name="player",recipes={},technologies={}}
local surface={valid=true,index=1}
local function pair(id)
  return {station={valid=true,type="container",unit_number=id,position={x=id,y=0},force=force,surface=surface},
    priest={valid=true,unit_number=id+1000},radius=24}
end
local roster=storage.tech_priests.pairs_by_station
for _,id in ipairs({10,20,30,40,50})do roster[id]=pair(id)end
local visits={};local throw_id=20
local function no_action(p)
  local id=p.station.unit_number;visits[#visits+1]={id=id,tick=game.tick}
  if id==throw_id then error("station temporarily unavailable")end
  return false,"planning-pending"
end
Plan.service_pair=no_action
assert(Plan.install() and captured.master_infrastructure_plan_0644.budget==1,
  "0644 admission did not retain the canonical broker")
local function pulse(budget)
  game.tick=game.tick+1;local before=#visits;local r=Q.pulse({tick=game.tick},budget or 1)
  assert(r.processed<=(budget or 1) and #visits-before<=(budget or 1),"roster hid unbounded station admissions")
  return r
end
local function pending_roster()return Q.peek(0,"infrastructure-roster","active")end
local function finish(limit)
  for _=1,limit or 200 do
    pulse();local j,status=pending_roster()
    if j and status=="ready"then return j end
  end
  error("roster stalled")
end
for _=1,100 do
  local acted,processed=Plan.service_all("caller",1000)
  assert(acted==0 and processed==0,"ordinary caller advanced a survey")
end
assert(#visits==0 and Q.root().total==1,"repeated admission duplicated work or ran synchronously")
assert(pulse(0).processed==0 and #visits==0,"zero broker budget ran work")
-- A no-action or throwing station is charged without losing the other visits.
local finished=finish()
local seen={};for _,v in ipairs(visits)do seen[v.id]=(seen[v.id]or 0)+1 end
for _,id in ipairs({10,20,30,40,50})do assert(seen[id]==1,"failure/no-action starved or repeated station "..id)end
assert(finished.state.failures==1 and not finished.error,"one failed station terminated the roster job")
-- Start another roster; delete its saved key and reload the module with the
-- saved cursor/seen set intact. Every surviving station still gets a visit.
visits={};throw_id=nil;Plan.service_all("reload-cycle");pulse();pulse()
local saved=pending_roster().state.cursor
assert(type(saved)=="number","roster cursor is not save-safe")
roster[saved]=nil;roster[60]=pair(60)
package.loaded["scripts.core.master_infrastructure_plan_0644"]=nil
Plan=require("scripts.core.master_infrastructure_plan_0644");Plan.service_pair=no_action
finish()
seen={};for _,v in ipairs(visits)do seen[v.id]=(seen[v.id]or 0)+1 end
for id in pairs(roster)do assert(seen[id]==1,"save/reload or deletion lost station "..id)end
for _,count in pairs(seen)do assert(count==1,"saved roster repeated an admitted station")end
-- The installed periodic callback itself only admits, regardless of the
-- offered number. A different no-action force must not suppress this roster.
assert(Plan.install());local before=#visits
local admitted=captured.master_infrastructure_plan_0644.fn({tick=game.tick},1)
assert(admitted.processed==0 and #visits==before,"periodic admission ran a complete station")
local stalls=0
Q.register("no-action-fixture",function()stalls=stalls+1;return{processed=1,waiting=true}end)
Q.submit(2,"no-action-fixture","other-force",{})
finish(400)
assert(#visits>before and stalls>0,"shared no-action fairness failed")
Q.forget(2,"no-action-fixture","other-force")
print("[master-infrastructure-budget-1070] PASS admission-only callers; charged failing/no-action visits; deleted cursor and reload; force fairness")

-- Real runtime broker: movement receives every due tick while shared planner
-- continuations are admitted through the same background scheduling owner.
for _,name in ipairs({"runtime_tick_broker","efficiency_economy_0598","force_planning_queue", "planning_metadata_1507", "infrastructure_continuation_1507","master_infrastructure_plan_0644"})do package.loaded["scripts.core."..name]=nil end
storage={tech_priests={pairs_by_station={}}};game={tick=0};visits={};throw_id=nil
roster=storage.tech_priests.pairs_by_station
for id=1,100 do roster[id]=pair(id)end
local Broker=require("scripts.core.runtime_tick_broker")
_G.TechPriestsRuntimeTickBroker0600=Broker
require("scripts.core.efficiency_economy_0598").install()
Q=require("scripts.core.force_planning_queue")
Plan=require("scripts.core.master_infrastructure_plan_0644");Plan.service_pair=no_action;assert(Plan.install())
local movement,polls=0,{}
Broker.register_service{name="movement-fixture",category="movement",interval=5,budget=1,
  fn=function()movement=movement+1;return{processed=1,acted=1}end}
for i=1,3 do
  local key="other-planning-fixture-"..i
  Broker.register_service{name=key,category="planning",interval=5,budget=1,
    fn=function()polls[key]=(polls[key]or 0)+1;return{processed=1,acted=0}end}
end
for tick=5,1000,5 do
  game.tick=tick;Broker.pulse{tick=tick}
  assert((Q.root().last_work or 0)<=Q.budget,"real broker exceeded central planning allowance")
end
seen={};for _,v in ipairs(visits)do seen[v.id]=true end
for id=1,100 do assert(seen[id],"real broker starved station "..id)end
assert(movement==200,"planning admission reduced active movement service")
for _,count in pairs(polls)do assert(count>100,"continuations starved another eligible service")end
print("[master-infrastructure-budget-1070] PASS real broker: 100 no-action stations reached; movement receives all 200 due pulses; other services remain live")
