package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=1000};storage={tech_priests={}}
local surface={find_entities_filtered=function()return {}end}
local burnt={valid=true,get_contents=function()return {}end,count_empty_stacks=function()return 0 end}
local fuel={valid=true,get_contents=function()return {}end}
local boiler={valid=true,name="boiler",type="boiler",unit_number=3,
 position={x=5,y=0},surface=surface,
 get_fuel_inventory=function()return fuel end,
 get_burnt_result_inventory=function()return burnt end}
local pair={station={valid=true,unit_number=1},priest={valid=true}}
local Readiness=require("scripts.core.energy_family_readiness_0705")
local report=Readiness.inspect_entity(pair,boiler,true)
assert(report.state=="fuel-service-eligible" and report.burnt_ready,
 "zero-slot residue inventory blocked a vanilla coal boiler")
burnt[1]=true
burnt.get_contents=function()return {ash=1}end
report=Readiness.inspect_entity(pair,boiler,true)
assert(report.state=="burnt-result-blocked" and not report.burnt_ready,
 "real full residue inventory lost its service requirement")
print("PASS zero-slot boiler residue inventory and actual full residue refusal")
