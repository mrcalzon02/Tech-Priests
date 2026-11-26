-- Lua 5.2 regression: standard drills require real output receivers.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
local Async=dofile("tests/helpers/planning_continuation_1507.lua")
game={tick=1500}
storage={tech_priests={pairs_by_station={}}}
defines={inventory={chest=1},direction={north=0}}
local iron_chest={valid=true,name="iron-chest",type="container"}
prototypes={
 item={["iron-chest"]={place_result=iron_chest},
   ["wooden-chest"]={place_result={name="wooden-chest"}},
   ["iron-ore"]={}},
 entity={["iron-chest"]={name="iron-chest",type="container"},
   ["wooden-chest"]={name="wooden-chest",type="container"},
   ["burner-mining-drill"]={name="burner-mining-drill",type="mining-drill"}},
}
_G.TechPriestsPlanningConstraints0646={
  item_unlocked=function()return true end,
  entity_unlocked=function()return true end,
  interior_position_allowed=function()return true end,
}
local force={valid=true,index=1,name="player",
  recipes={["iron-chest"]={enabled=true,products={{name="iron-chest"}},
    ingredients={{name="iron-plate",amount=2}}}}}
local station_inventory={valid=true}
station_inventory.get_item_count=function(name)
  return name=="iron-chest" and 1 or 0
end
local surface={valid=true,index=1}
local station={valid=true,type="container",name="junior-cogitator-station",
  unit_number=11,position={x=0,y=0},surface=surface,force=force}
station.get_inventory=function(i)
  return i==defines.inventory.chest and station_inventory or nil
end
local drill={valid=true,type="mining-drill",name="burner-mining-drill",
  unit_number=14,position={x=10,y=1},drop_position={x=12.5,y=1.29},
  drop_target=nil,force=force,surface=surface}
local smelter={valid=true,type="furnace",name="stone-furnace",
  unit_number=15,position={x=3,y=1},force=force,surface=surface}
local storage_chest={valid=true,type="container",name="wooden-chest",
  unit_number=16,position={x=2,y=2},force=force,surface=surface}
local ore={valid=true,type="resource",name="iron-ore",amount=100,
  position={x=10.5,y=0.5}}
local valid_placement=true
local receiver_present=false
local ghost
surface.find_entities_filtered=function(filter)
  if filter.name=="entity-ghost" then return ghost and {ghost} or {} end
  if filter.name=="iron-chest" then
    return receiver_present and {{valid=true,type="container",
      name="iron-chest",position={x=12.5,y=1.5}}} or {}
  end
  if filter.type=="resource" then return {ore} end
  if filter.type=="mining-drill" then return {drill} end
  if type(filter.type)=="table" then
    if filter.radius and filter.radius<1 then
      return receiver_present and {{valid=true,type="container",
        name="iron-chest",position={x=12.5,y=1.5}}} or {}
    end
    if receiver_present then
      return {smelter,storage_chest,drill,{valid=true,type="container",
        name="iron-chest",position={x=12.5,y=1.5},force=force}}
    end
    return {smelter,storage_chest,drill}
  end
  return {}
end
Async.wrap_queries(surface,force)
surface.can_place_entity=function(o)
  return valid_placement and o.position.x==12.5 and o.position.y==1.5
end
surface.create_entity=function(o)
  ghost={valid=true,name="entity-ghost",ghost_name=o.inner_name,
    position=o.position,force=force,surface=surface,unit_number=90}
  return ghost
end
surface.find_entity=function()return ghost end
local pair={station=station,priest={valid=true,unit_number=12,
  position={x=0,y=0}},radius=24,station_unit=11,
  logistic_frustration_start_tick=0,logistic_frustration_due_tick=1500}
storage.tech_priests.pairs_by_station[11]=pair
local plan=require("scripts.core.master_infrastructure_plan_0644")
local ghosts=require("scripts.core.construction_bootstrap_ghost_planner_0645")
local function check(v,why)if not v then error("drill-output-regression: "..why,2)end end
local built=Async.plan(plan,pair,"test")
check(built and built.stage=="mining-output-buffer",
  "real uncovered drill did not become central infrastructure objective")
check(built.target.preferred_item=="iron-chest"
  and built.target.site_position.x==12.5
  and built.target.site_position.y==1.5,
  "physical drop position not used for chest planning")
local ok,why=Async.ghost(ghosts,pair,"test")
check(ok and pair.construction_bootstrap_ghost_0645
  and pair.construction_bootstrap_ghost_0645.position.x==12.5
  and pair.construction_bootstrap_ghost_0645.position.y==1.5,
  "construction ghost was not at the drill output: "..tostring(why))
ghost=nil;pair.construction_bootstrap_ghost_0645=nil
valid_placement=false
local deferred=Async.plan(plan,pair,"output-blocked-workshop-pending")
check(deferred.stage=="basic-crafting"
    and deferred.target.deferred_output
    and deferred.target.deferred_output.reason==
      "fixed-drill-output-position-blocked",
  "obstructed drill permanently blocked independent workshop construction")
local no_workshop,why=Async.ghost(ghosts,pair,"workshop-pending")
check(not no_workshop and why=="target-not-placeable",
  "missing workshop prototype was incorrectly constructed in the unit fixture")
-- Once the independent equipment is actually present, an unusable output
-- must NOT be counted as a completed bootstrap spine.
local completed={
 {valid=true,type="assembling-machine",name="assembling-machine-1",
   position={x=4,y=4},force=force},
 {valid=true,type="lab",name="lab",
   position={x=5,y=4},force=force},
 {valid=true,type="inserter",name="inserter",
   position={x=6,y=4},force=force},
 {valid=true,type="transport-belt",name="transport-belt",
   position={x=7,y=4},force=force},
}
local old_find=surface.find_entities_filtered
surface.find_entities_filtered=function(filter)
  if type(filter.type)=="table" then
    local found={smelter,storage_chest,drill}
    if receiver_present then
      found[#found+1]={valid=true,type="container",name="iron-chest",
        position={x=12.5,y=1.5},force=force}
    end
    for _,entity in ipairs(completed) do found[#found+1]=entity end
    return found
  end
  return old_find(filter)
end
Async.wrap_queries(surface,force)
local blocked_plan=Async.plan(plan,pair,"all-independent-work-complete")
check(blocked_plan.status=="blocked"
    and blocked_plan.stage=="mining-output-buffer"
    and blocked_plan.target.site_position.x==12.5,
  "blocked output disappeared into false factory readiness")
local blocked,reason=Async.ghost(ghosts,pair,"blocked-final-test")
check(not blocked and reason=="fixed-drill-output-position-blocked",
  "fixed receiver bypassed real Factorio placement authority")
ghost=nil;pair.construction_bootstrap_ghost_0645=nil
valid_placement=true;receiver_present=true
local satisfied=Async.plan(plan,pair,"receiver-present")
check(satisfied.stage~="mining-output-buffer",
  "completed physical receiver was ignored by infrastructure planning")
receiver_present=false
drill.drop_target={valid=true,name="iron-chest"}
local connected=Async.plan(plan,pair,"engine-target-present")
check(connected.stage~="mining-output-buffer",
  "connected drill falsely demanded a second receiver")
-- A separate usable drill must be selected rather than repeatedly
-- planning the blocked output of a closer drill.
drill.drop_target=nil
local second_drill={valid=true,type="mining-drill",name="burner-mining-drill",
  unit_number=17,position={x=16,y=1},
  drop_position={x=20.5,y=1.29},drop_target=nil,
  force=force,surface=surface}
surface.find_entities_filtered=function(filter)
  if type(filter.type)=="table" then
    local found={smelter,storage_chest,drill,second_drill}
    for _,entity in ipairs(completed) do found[#found+1]=entity end
    return found
  end
  return old_find(filter)
end
Async.wrap_queries(surface,force)
surface.can_place_entity=function(o)
  return o.position.x==20.5 and o.position.y==1.5
end
local second=Async.plan(plan,pair,"two-drill-alternate-output")
check(second.stage=="mining-output-buffer"
    and second.target.site_position.x==20.5
    and second.target.site_position.y==1.5
    and second.target.deferred_output
    and second.target.deferred_output.position.x==12.5,
  "blocked first drill prevented planning a legal second output")
-- Dense surveys must make the same physical choice after the third fallback,
-- including receiver positions across negative cell boundaries. The first two
-- outputs are blocked; the third is covered; the fourth is buildable.
local dense_drills={}
for i=1,12 do
  dense_drills[i]={valid=true,type="mining-drill",name="burner-mining-drill",
    unit_number=200+i,position={x=-4*i,y=-4},
    drop_position={x=-4*i-.01,y=-4.01},drop_target=nil,
    force=force,surface=surface}
end
local dense_receiver={valid=true,type="container",name="iron-chest",
  position={x=-11.51,y=-3.51},force=force,surface=surface}
surface.find_entities_filtered=function(filter)
  if type(filter.type)=="table" then
    local found={smelter,storage_chest,dense_receiver}
    for _,entity in ipairs(completed) do found[#found+1]=entity end
    for _,entity in ipairs(dense_drills) do found[#found+1]=entity end
    return found
  end
  return old_find(filter)
end
Async.wrap_queries(surface,force)
surface.can_place_entity=function(o)
  return (o.position.x==-12.5 or o.position.x==-16.5) and o.position.y==-4.5
end
local dense=Async.plan(plan,pair,"dense-negative-cell-receiver")
check(dense.stage=="mining-output-buffer"
    and dense.target.site_position.x==-16.5,
  "dense survey ignored a receiver across negative cell boundaries")

-- A receiver exactly one tile away does not cover the drop. Moving it between
-- plans must be visible immediately, even in the same game tick.
dense_receiver.position={x=dense_drills[3].drop_position.x+1,
  y=dense_drills[3].drop_position.y}
local boundary=Async.plan(plan,pair,"dense-strict-receiver-distance")
check(boundary.stage=="mining-output-buffer"
    and boundary.target.site_position.x==-12.5,
  "dense survey changed the strict receiver radius or retained old positions")
dense_receiver.position.x=dense_drills[3].drop_position.x+.99
local moved=Async.plan(plan,pair,"dense-live-receiver-position")
check(moved.stage=="mining-output-buffer"
    and moved.target.site_position.x==-16.5,
  "dense survey did not read the newly moved receiver")
dense_receiver.valid=false
local removed=Async.plan(plan,pair,"dense-invalid-receiver")
check(removed.stage=="mining-output-buffer"
    and removed.target.site_position.x==-12.5,
  "dense survey retained a removed receiver")
print("[drill-output-regression] PASS scenarios=11")
