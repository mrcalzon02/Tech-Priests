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
pair.independent_emergency_operation_0184.enabled=true;game.tick=9000
force.is_chunk_charted=function()return false end
storage.tech_priests.pairs_by_station={
 [1]=pair,[2]={station={valid=true,unit_number=2,force=force,surface=surface,
 position={x=60,y=0}},priest={valid=true,force=force,surface=surface},radius=30}}
tech_priests_0259_resource_expansion_service(pair)
assert(started[2]=="stone","Magos ignored an actual same-force subordinate resource observation")
storage.tech_priests.pairs_by_station[2].station.force={index=2}
local explored=0
TECH_PRIESTS_STATION_EXPANSION_0256.request_station_expansion=function()
 explored=explored+1;return false end
game.tick=12000
tech_priests_0259_resource_expansion_service(pair)
assert(#started==2 and explored>0,"foreign station granted resource knowledge")
local child={station={valid=true,unit_number=3,force=force,surface=surface,position={x=0,y=0}},
 priest={valid=true,force=force,surface=surface},radius=20}
TECH_PRIESTS_COMMAND_HIERARCHY_0480={direct_subordinates=function(p)assert(p==pair);return {child}end}
local delegated=0
TECH_PRIESTS_STATION_EXPANSION_0256.request_station_expansion=function(p)
 if p==pair then p.station_expansion_admission_0256="command-capacity-full";return false end
 assert(p==child,"resource scout escaped authoritative subordinate list")
 delegated=delegated+1;return true
end
game.tick=15000
tech_priests_0259_resource_expansion_service(pair)
assert(delegated>0 and pair.resource_expansion_0259.delegated_station_unit==3,
 "full commander failed to delegate physical resource scouting")
assert(child.independent_emergency_operation_0184==nil,"delegation enabled unrelated independent factory mode")
TECH_PRIESTS_STATION_EXPANSION_0256.allowed_station_item_for_pair=function(p)
 return p==pair and "senior-cogitator-station"or "intermediate-cogitator-station"end
TechPriestsStorageRoleAuthority0686={generic_item_count=function(p,item)
 return p==child and item=="intermediate-cogitator-station"and 1 or 0 end}
TECH_PRIESTS_STATION_EXPANSION_0256.request_station_expansion=function(p)
 assert(p==child,"unfunded commander started another writ ahead of its actually stocked child")
 delegated=delegated+1;return true end
pair.station_expansion_admission_0256=nil;game.tick=18000
tech_priests_0259_resource_expansion_service(pair)
assert(pair.resource_expansion_0259.last_reason:find("stocked ranked child",1,true),
 "stocked child required its commander to exhaust command capacity before delegation")
print("PASS explicit autonomous expansion, blocking leaf priority and funded ranked child delegation")
