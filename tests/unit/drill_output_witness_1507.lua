-- Real 0644 -> 0645 callers reject an obsolete drill outlet before a ghost is
-- created, even when a script changes the drill without raising a build event.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
local Async=dofile("tests/helpers/planning_continuation_1507.lua")
game={tick=1000};storage={tech_priests={pairs_by_station={}}}
defines={inventory={chest=1},direction={north=0},events={on_player_rotated_entity=9001}}
local force={object_name="LuaForce",valid=true,index=1,name="player",technologies={},recipes={
  ["iron-chest"]={object_name="LuaRecipe",valid=true,enabled=true,products={{name="iron-chest"}},ingredients={}}}}
local surface={object_name="LuaSurface",valid=true,index=1}
local world,created={},{}
local function entity(kind,name,id,x,y)
  local e={object_name="LuaEntity",valid=true,type=kind,name=name,unit_number=id,
    position={x=x,y=y},force=force,surface=surface}
  world[#world+1]=e;return e
end
local station=entity("container","junior-cogitator-station",1,0,0)
local priest=entity("car","tech-priest",2,0,1)
local drill=entity("mining-drill","burner-mining-drill",3,10,1)
entity("furnace","stone-furnace",4,2,2)
entity("container","wooden-chest",5,3,3)
drill.drop_position={x=12.5,y=1.29}
local inventory={object_name="LuaInventory",valid=true,get_item_count=function(name)return name=="iron-chest"and 1 or 0 end}
station.get_inventory=function()return inventory end
prototypes={item={["iron-chest"]={place_result={name="iron-chest"}}},
  entity={["iron-chest"]={name="iron-chest",type="container",collision_box={{-.35,-.35},{.35,.35}}}}}
surface.find_entities_filtered=function(query)return Async.query(world,query,surface,force)end
surface.can_place_entity=function(args)
  return args.position.x==math.floor(drill.drop_position.x)+.5
    and args.position.y==math.floor(drill.drop_position.y)+.5
end
surface.create_entity=function(args)
  local ghost=entity("entity-ghost","entity-ghost",100+#created,args.position.x,args.position.y)
  ghost.ghost_name=args.inner_name;created[#created+1]=ghost;return ghost
end
local pair={station=station,priest=priest,station_unit=1,radius=24,
  self_construction_frustration_unlocked_1504=true}
storage.tech_priests.pairs_by_station[1]=pair
_G.TechPriestsPlanningConstraints0646={entity_unlocked=function()return true end,
  interior_position_allowed=function()return true end}
local P,Q,Site,Ghost,Area
local function load_modules()
  P=require("scripts.core.master_infrastructure_plan_0644")
  Q=require("scripts.core.force_planning_queue")
  Site=require("scripts.core.construction_site_planner")
  Ghost=require("scripts.core.construction_bootstrap_ghost_planner_0645")
  Area=require("scripts.core.bounded_planning_area_1507")
  _G.TechPriestsMasterInfrastructurePlan0644=P
end
load_modules()
local function wait_job(predicate)
  for _=1,20000 do
    local job=Q.peek(1,"infrastructure-survey","1")
    if job and predicate(job)then return job end
    Async.pulse(1)
  end
  error("infrastructure continuation did not reach the test boundary")
end
local function rotate(y)drill.drop_position={x=12.5,y=y}end

P.build_plan(pair,"rotate-during-drill-scan")
wait_job(function(job)return job.state.drill~=nil end)
rotate(3.29)
local rejected=wait_job(function(job)return job.status=="ready"end)
assert(rejected.result.stale and rejected.result.reason=="drill-output-changed",
  "resumed drill scan retained an obsolete outlet")
local plan=Async.plan(P,pair,"fresh-outlet")
assert(plan.output_witness and plan.output_witness.entity==drill
  and plan.target.site_position.y==3.5,"selected output lost its native witness")

-- Rotation after the world/final-stock checks must still refuse publication.
P.build_plan(pair,"rotate-before-publication")
wait_job(function(job)return job.state.phase=="publish"end)
rotate(5.29)
rejected=wait_job(function(job)return job.status=="ready"end)
assert(rejected.result.stale and rejected.result.reason=="drill-output-changed",
  "late output change published a stale fixed receiver")
plan=Async.plan(P,pair,"fresh-after-publication-refusal")
assert(plan.target.site_position.y==5.5)

-- Save-like serialization retains the native handle and plain witness data;
-- module reload restores all handlers without saving closures or iterators.
local function copy(value,seen)
  if type(value)~="table"then assert(type(value)~="function"and type(value)~="thread");return value end
  if value.object_name then return value end
  seen=seen or{};if seen[value]then return seen[value]end
  local result={};seen[value]=result
  for k,v in pairs(value)do result[copy(k,seen)]=copy(v,seen)end
  return result
end
storage=copy(storage);pair=storage.tech_priests.pairs_by_station[1]
for _,name in ipairs({"master_infrastructure_plan_0644","infrastructure_continuation_1507",
    "force_planning_queue","planning_metadata_1507","bounded_planning_area_1507",
    "construction_site_planner","construction_bootstrap_ghost_planner_0645"})do
  package.loaded["scripts.core."..name]=nil
end
load_modules();plan=pair.master_infrastructure_plan_0644
assert(P.plan_current(pair,plan),"saved live output witness lost authority after reload")

-- The old fixed-site job may already be ready when the drill changes. The
-- actual ghost consumer must reject its master plan before using that ticket.
local acted,why=Ghost.service_pair(pair,"queue-fixed-receiver")
assert(not acted and why=="placement-pending" and #created==0)
local position=plan.target.site_position
local key="1:iron-chest:storage:"..tostring(position.x)..":"..tostring(position.y)
for _=1,100 do
  local job=Q.peek(1,"fixed-output-placement-0359",key)
  if job and job.status=="ready"then break end
  Async.pulse(1)
end
local fixed=Q.peek(1,"fixed-output-placement-0359",key)
assert(fixed and fixed.status=="ready","fixed placement did not reach ready state")
rotate(7.29)
assert(not P.plan_current(pair,plan),"completed plan ignored the live drill witness")
acted=Ghost.service_pair(pair,"obsolete-ready-output-ticket")
assert(not acted and #created==0 and not pair.construction_bootstrap_ghost_0645,
  "actual ghost caller used an obsolete ready output ticket")
plan=Async.plan(P,pair,"rotated-output-replan")
assert(plan.target.site_position.y==7.5)
acted,why=Async.ghost(Ghost,pair,"fresh-output-ghost")
assert(acted and #created==1 and created[1].position.y==7.5,
  "rotation refusal prevented the fresh physical output proposal")

-- A newly connected native output also makes a completed receiver proposal
-- unnecessary, without depending on an external build event being raised.
drill.drop_target={object_name="LuaEntity",valid=true}
assert(not P.plan_current(pair,plan),"native output connection allowed a duplicate receiver")
drill.drop_target=nil
local handlers={}
_G.TechPriestsRuntimeEventRegistry={on_event=function(events,fn)
  for _,id in ipairs(events)do handlers[id]=fn end
  return true
end}
assert(Area.install() and handlers[9001],"player rotation does not invalidate planning areas")
assert(P.plan_current(pair,plan))
handlers[9001]({entity=drill})
assert(not P.plan_current(pair,plan),"rotation event retained the completed area witness")
assert(Q.root().stats.failures==0,"drill witness introduced a hidden handler failure")
print("[drill-output-witness-1507] PASS live scan/publication/consumption checks, actual 0644→0645, ready stale placement, native connection, reload and rotation events")
