-- Lua 5.2 regression: standard drills require real output receivers.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
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
  position={x=0,y=0}},radius=24,station_unit=11}
storage.tech_priests.pairs_by_station[11]=pair
local plan=require("scripts.core.master_infrastructure_plan_0644")
local ghosts=require("scripts.core.construction_bootstrap_ghost_planner_0645")
local function check(v,why)if not v then error("drill-output-regression: "..why,2)end end
local built=plan.build_plan(pair,"test")
check(built and built.stage=="mining-output-buffer",
  "real uncovered drill did not become central infrastructure objective")
check(built.target.preferred_item=="iron-chest"
  and built.target.site_position.x==12.5
  and built.target.site_position.y==1.5,
  "physical drop position not used for chest planning")
local ok,why=ghosts.service_pair(pair,"test")
check(ok and pair.construction_bootstrap_ghost_0645
  and pair.construction_bootstrap_ghost_0645.position.x==12.5
  and pair.construction_bootstrap_ghost_0645.position.y==1.5,
  "construction ghost was not at the drill output: "..tostring(why))
ghost=nil;pair.construction_bootstrap_ghost_0645=nil
valid_placement=false
local deferred=plan.build_plan(pair,"output-blocked-workshop-pending")
check(deferred.stage=="basic-crafting"
    and deferred.target.deferred_output
    and deferred.target.deferred_output.reason==
      "fixed-drill-output-position-blocked",
  "obstructed drill permanently blocked independent workshop construction")
local no_workshop,why=ghosts.service_pair(pair,"workshop-pending")
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
local blocked_plan=plan.build_plan(pair,"all-independent-work-complete")
check(blocked_plan.status=="blocked"
    and blocked_plan.stage=="mining-output-buffer"
    and blocked_plan.target.site_position.x==12.5,
  "blocked output disappeared into false factory readiness")
local blocked,reason=ghosts.service_pair(pair,"blocked-final-test")
check(not blocked and reason=="fixed-drill-output-position-blocked",
  "fixed receiver bypassed real Factorio placement authority")
ghost=nil;pair.construction_bootstrap_ghost_0645=nil
valid_placement=true;receiver_present=true
local satisfied=plan.build_plan(pair,"receiver-present")
check(satisfied.stage~="mining-output-buffer",
  "completed physical receiver was ignored by infrastructure planning")
receiver_present=false
drill.drop_target={valid=true,name="iron-chest"}
local connected=plan.build_plan(pair,"engine-target-present")
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
surface.can_place_entity=function(o)
  return o.position.x==20.5 and o.position.y==1.5
end
local second=plan.build_plan(pair,"two-drill-alternate-output")
check(second.stage=="mining-output-buffer"
    and second.target.site_position.x==20.5
    and second.target.site_position.y==1.5
    and second.target.deferred_output
    and second.target.deferred_output.position.x==12.5,
  "blocked first drill prevented planning a legal second output")
print("[drill-output-regression] PASS scenarios=7")
