package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=1000};storage={tech_priests={}}
local force={index=1};local target={valid=true,position={x=4,y=0},force=force}
local pair={station={valid=true,unit_number=1,position={x=0,y=0},force=force},
 priest={valid=true,unit_number=2,position={x=0,y=0},force=force},mode="idle"}
local machine_active=false
TECH_PRIESTS_MACHINE_LOGISTICS_FULFILLMENT_0528={recommend_action=function()
 return {kind="machine-logistics",target=target,item="iron-ore",active=machine_active}end}
TechPriestsEnergyFamilyLogistics0707={recommend_action=function()
 return {kind="energy-family-logistics",target=target,item="coal",active=false}end}
TechPriestsConstructionPlanner0338={recommend_action=function()return nil end}
local Arbiter=require("scripts.core.action_state_arbiter_0488")
local action=Arbiter.action(pair)
assert(action.kind=="energy-family-logistics" and action.item=="coal",
 "routine machine discovery starved canonical boiler fuel")
machine_active=true
assert(Arbiter.action(pair).kind=="machine-logistics","active machine duty displaced")
machine_active=false;pair.machine_logistics_custody_0528={count=1}
assert(Arbiter.action(pair).kind=="machine-logistics","held machine cargo displaced")
print("PASS energy prerequisites before routine discovery and incumbent machine protection")
