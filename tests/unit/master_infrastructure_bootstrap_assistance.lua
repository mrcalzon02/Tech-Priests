-- Lua 5.2: emergency miner bootstraps resource income and supports normal drills.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=1200}
storage={tech_priests={pairs_by_station={}}}
defines={inventory={chest=1}}
_G.TechPriestsPlanningConstraints0646={
  item_unlocked=function()return true end
}
local Plan=require("scripts.core.master_infrastructure_plan_0644")
local stock={}
local inventory={valid=true,get_item_count=function(name)return stock[name] or 0 end}
local force={index=1,name="player",recipes={
  ["burner-mining-drill"]={enabled=true,
    products={{name="burner-mining-drill"}},
    ingredients={{name="iron-gear-wheel",amount=2},{name="iron-plate",amount=3}}},
  ["tech-priests-emergency-miner"]={enabled=true,
    products={{name="tech-priests-emergency-miner"}},
    ingredients={{name="iron-plate",amount=1},{name="stone",amount=1}}}
}}
local surface={index=1,name="nauvis"}
local machines={}
local smelter={valid=true,type="furnace",name="stone-furnace",unit_number=30,
  position={x=2,y=0}}
local chest={valid=true,type="container",name="wooden-chest",unit_number=31,
  position={x=4,y=0}}
local ore={valid=true,type="resource",name="iron-ore",amount=1000,
  position={x=7,y=0}}
machines={smelter,chest}
surface.find_entities_filtered=function(filters)
  if filters.type=="resource" then return {ore} end
  if type(filters.type)=="table" then return machines end
  return {}
end
local station={valid=true,name="junior-cogitator-station",unit_number=11,
  position={x=0,y=0},surface=surface,force=force}
station.get_inventory=function(id)
  return id==defines.inventory.chest and inventory or nil
end
local pair={station=station,priest={valid=true,unit_number=12,
  position={x=0,y=0}},radius=24,station_unit=11}
storage.tech_priests.pairs_by_station[11]=pair
local function check(ok,why)
  if not ok then error("bootstrap-assistance regression: "..why,2) end
end
local function scenario(name,expected_stage,expected_item)
  local plan=Plan.build_plan(pair,name)
  check(plan and plan.stage==expected_stage,
    name..": wrong stage "..tostring(plan and plan.stage))
  check(plan.target.preferred_item==expected_item,
    name..": wrong item "..tostring(plan.target.preferred_item))
  return plan
end
-- With no items stocked, both machine recipes are initially short of
-- ingredients. The one-plate, one-stone emergency miner remains the first
-- reachable machine; a burner drill must not steal the initial build target.
local empty=scenario("zero-stock-emergency-bootstrap",
  "bootstrap-mining","tech-priests-emergency-miner")
check(empty.target.feasibility:find("emergency-bootstrap:",1,true),
  "the cheap emergency recipe was not retained as the missing-material goal")
stock["tech-priests-emergency-miner"]=1
local first=scenario("bootstrap-with-missing-standard-ingredients",
  "bootstrap-mining","tech-priests-emergency-miner")
check(first.target.fallback_item=="burner-mining-drill",
  "normal mining objective was not retained after emergency bootstrap")
local emergency={valid=true,type="assembling-machine",
  name="tech-priests-emergency-miner",unit_number=33,position={x=5,y=1},
  force=force,surface=surface}
machines[#machines+1]=emergency
local upgrade=scenario("emergency-assists-standard-upgrade",
  "bootstrap-normal-mining","burner-mining-drill")
check(upgrade.target.delivery=="standard-drill-with-emergency-miner-assistance",
  "emergency source no longer contributes during normal-drill dependency chain")
check(emergency.valid and machines[#machines]==emergency,
  "standard planning retired the working emergency miner")
local drill={valid=true,type="mining-drill",name="burner-mining-drill",
  unit_number=34,position={x=8,y=1},force=force,surface=surface}
machines[#machines+1]=drill
local later=Plan.build_plan(pair,"standard-drill-built")
check(later.stage~="bootstrap-normal-mining"
  and later.stage~="bootstrap-mining",
  "planner remained stuck mining after both emergency and standard units exist")
machines[#machines]=nil
force.recipes["burner-mining-drill"].enabled=false
local locked=Plan.build_plan(pair,"normal-drill-recipe-locked")
check(locked.stage~="bootstrap-normal-mining",
  "locked standard drill was queued over working emergency income")
force.recipes["burner-mining-drill"].enabled=true
machines[#machines]=nil
stock["iron-gear-wheel"]=2;stock["iron-plate"]=3
scenario("normal-drill-with-ingredients-stocked",
  "bootstrap-mining","burner-mining-drill")
-- The inventory steward returns the station chest among its sources.
-- A second direct chest count would fake four plates and two gears from
-- just two plates and one gear, prematurely selecting the burner drill.
stock["tech-priests-emergency-miner"]=nil
stock["iron-gear-wheel"]=1;stock["iron-plate"]=2;stock.stone=1
_G.tech_priests_inventory_steward_sources_for_pair=function()
  return {{inv=inventory,entity=station,source="station-container"}}
end
scenario("station-inventory-counted-once",
  "bootstrap-mining","tech-priests-emergency-miner")
_G.tech_priests_inventory_steward_sources_for_pair=nil
stock["iron-gear-wheel"]=nil;stock["iron-plate"]=nil;stock.stone=nil
force.recipes["burner-mining-drill"].ingredients={
  {name="coolant",type="fluid",amount=10}}
scenario("unsupported-standard-fluid-keeps-emergency-assistance",
  "bootstrap-mining","tech-priests-emergency-miner")
print("[bootstrap-assistance-regression] PASS scenarios=8")
