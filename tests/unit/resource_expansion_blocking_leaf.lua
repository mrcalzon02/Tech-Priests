package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=3000};storage={tech_priests={}}
local started={}
package.loaded["scripts.core.resource_station_chain_0820"]={
 status=function()return nil end,
 start=function(pair,item,pos,name)started[#started+1]=item;return true end}
package.loaded["scripts.core.resource_return_courier_0837"]={}
package.loaded["scripts.core.remote_machine_drill_1011"]={}
local surface={index=1};local force={index=1,is_chunk_charted=function()return true end}
local pair={station={valid=true,unit_number=1,name="planetary-magos-cogitator-station",
 position={x=0,y=0},surface=surface,force=force},priest={valid=true},radius=40,
 infrastructure_recipe_request_0647={missing="stone"}}
surface.find_entities_filtered=function(spec)
 if spec.radius then return {}end
 return {{valid=true,name=spec.name,type="resource",position={x=80,y=0},amount=1000}}
end
tech_priests_0255_pair_is_magos_planner=function(p)return p==pair end
tech_priests_prototype_table_0440=function()return {
 stone={type="resource",mineable_properties={products={{name="stone"}}}},
 iron={type="resource",mineable_properties={products={{name="iron-ore"}}}}}end
tech_priests_0257_build_ratio_plan=function()return {raw_items={["iron-ore"]=100}}end
TECH_PRIESTS_STATION_EXPANSION_0256={request_station_expansion=function()error("unnecessary blind exploration")end}
dofile("tech-priests_src/scripts/resource_expansion.lua")
tech_priests_0259_resource_expansion_service(pair)
assert(#started==0 and not pair.independent_emergency_operation_0184,
 "maintenance discovery enabled independent factory expansion")
pair.independent_emergency_operation_0184={enabled=true}
tech_priests_0259_resource_expansion_service(pair)
assert(started[1]=="stone","speculative iron expansion displaced blocking construction stone")
game.tick=6000;pair.independent_emergency_operation_0184.enabled=false
tech_priests_0259_resource_expansion_service(pair)
assert(#started==1,"disabled operation started another supply chain")
print("PASS explicit autonomous expansion and blocking raw leaf priority")
