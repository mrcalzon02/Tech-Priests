package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=100};defines={inventory={crafter_input=2,crafter_output=3}}
prototypes={item={["iron-plate"]={},["logistic-science-pack"]={},["firearm-magazine"]={}}}
storage={tech_priests={}}
local force={index=1};local surface={index=1,find_entities_filtered=function()return{}end}
local pair={station={valid=true,unit_number=1,force=force,surface=surface,position={x=0,y=0}},
 priest={valid=true,unit_number=2,force=force,surface=surface,position={x=0,y=0}},
 independent_emergency_operation_0184={enabled=true,magos_ratio_plan_0257={factory_component_jobs_1150={}}}}
local stocks={["iron-plate"]=50}
TechPriestsStorageRoleAuthority0686={generic_item_count=function(_,n)return stocks[n]or 0 end}
local M=require("scripts.core.logistics_machine_fulfillment_0528")
local function offer(name,id)
 local recipe={name=name,ingredients={{name="iron-plate",amount=1,type="item"}}}
 local machine={valid=true,type="assembling-machine",name="assembling-machine-1",unit_number=id,
 force=force,surface=surface,position={x=5,y=0},get_recipe=function()return recipe end,
 get_inventory=function(n)if n==2 then return{valid=true,get_item_count=function()return 0 end}end end}
 pair.independent_emergency_operation_0184.magos_ratio_plan_0257.factory_component_jobs_1150[name]=
 {output_item=name,output_deficient=true,researched=true,required_per_minute=5}
 pair.factory_component_last_receipt_1150={configured=true,built_entity=machine,entity_unit=id,station_unit=1,recipe=name}
 pair.machine_logistics_candidate_0528=nil
 local accepted,why=M.offer_factory_component_feed_1153(pair,machine,name)
 if not accepted then return nil,why end
 return pair.machine_logistics_candidate_0528
end
local urgent=offer("logistic-science-pack",3)
assert(urgent.count==5,"genuinely missing science lost its counted batch")
stocks["logistic-science-pack"]=20
local buffered=offer("logistic-science-pack",3)
local ammunition=offer("firearm-magazine",4)
assert(ammunition.score>buffered.score and ammunition.count==5,
 "buffered green science still monopolizes trips over missing military intermediates")
assert(buffered.score>600 and buffered.count==5,
 "measured deficient science lost its priority over routine surplus once a small buffer existed")
stocks["firearm-magazine"]=20
local surplus,why=offer("firearm-magazine",4)
assert(surplus==nil and why=="no-physical-local-ingredient-stock",
 "already buffered intermediate monopolized repeated ingredient deliveries")
assert(stocks["iron-plate"]==50 and stocks["logistic-science-pack"]==20,
 "priority discovery changed physical stock")
print("PASS stocked science yields transport urgency to missing military intermediates without spending stock")

stocks["logistic-science-pack"]=0;stocks["firearm-magazine"]=0
pair.independent_emergency_operation_0184.started_tick=0
game.tick=1000
pair.factory_recipe_service_ticks_0528={["logistic-science-pack"]=1000,
 ["firearm-magazine"]=100}
local hungry=offer("logistic-science-pack",3)
local overdue=offer("firearm-magazine",4)
assert(overdue.score>hungry.score,
 "continuously consumed science still starved a funded military intermediate")
pair.factory_recipe_service_ticks_0528["firearm-magazine"]=1000
local serviced=offer("firearm-magazine",4)
assert(serviced.score<hungry.score,"completed intermediate did not surrender its aging priority")
print("PASS eligible factory trips age past continuously hungry science and reset after service")
game.tick=10000
pair.factory_recipe_service_ticks_0528={["logistic-science-pack"]=9000,
 ["firearm-magazine"]=1000}
assert(offer("firearm-magazine",4).score>offer("logistic-science-pack",3).score,
 "long physical rounds saturated waiting credit and restored permanent science starvation")
print("PASS overdue intermediates retain priority after a long native walking round")
