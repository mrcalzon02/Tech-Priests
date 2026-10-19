-- Lua 5.2: normal unlocked industrial equipment outranks emergency substitutes.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=1200}
storage={tech_priests={pairs_by_station={}}}
defines={inventory={chest=1}}
_G.TechPriestsPlanningConstraints0646={
  item_unlocked=function()return true end
}
local Plan=require("scripts.core.master_infrastructure_plan_0644")
local stock={["tech-priests-emergency-miner"]=1}
local inventory={valid=true,get_item_count=function(name)return stock[name] or 0 end}
local force={index=1,name="player",recipes={
  ["burner-mining-drill"]={enabled=true,
    products={{name="burner-mining-drill"}},
    ingredients={{name="iron-gear-wheel",amount=2},{name="iron-plate",amount=3}}},
  ["tech-priests-emergency-miner"]={enabled=true,
    products={{name="tech-priests-emergency-miner"}},
    ingredients={{name="iron-plate",amount=1}}}
}}
local surface={index=1,name="nauvis"}
local smelter={valid=true,type="furnace",name="stone-furnace",unit_number=30,
  position={x=2,y=0}}
local chest={valid=true,type="container",name="wooden-chest",unit_number=31,
  position={x=4,y=0}}
local ore={valid=true,type="resource",name="iron-ore",amount=1000,
  position={x=7,y=0}}
surface.find_entities_filtered=function(filters)
  if filters.type=="resource" then return {ore} end
  if type(filters.type)=="table" then return {smelter,chest} end
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
  if not ok then error("standard-preference regression: "..why,2) end
end
local plan=Plan.build_plan(pair,"unlocked-but-missing-gears")
check(plan and plan.stage=="bootstrap-mining",
  "fixture did not request real mineral extraction")
check(plan.target.preferred_item=="burner-mining-drill",
  "stocked emergency miner displaced available normal drill")
check(plan.target.feasibility:find("missing-ingredients:",1,true),
  "missing standard ingredients were not retained as explicit prerequisites")
force.recipes["burner-mining-drill"].enabled=false
plan=Plan.build_plan(pair,"standard-disabled")
check(plan.target.preferred_item=="tech-priests-emergency-miner",
  "emergency alternative was not used when normal drill recipe disabled")
force.recipes["burner-mining-drill"].enabled=true
force.recipes["burner-mining-drill"].ingredients={
  {name="coolant",type="fluid",amount=10}}
plan=Plan.build_plan(pair,"unsupported-fluid")
check(plan.target.preferred_item=="tech-priests-emergency-miner",
  "unsupported fluid recipe bypassed physical machine requirements")
print("[standard-preference-regression] PASS scenarios=3")
