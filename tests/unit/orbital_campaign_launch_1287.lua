package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
storage={tech_priests={}};game={tick=1000};script={active_mods={["space-age"]="2.1.24"}}
defines={cargo_destination={space_platform=1},rocket_silo_status={building_rocket=0,rocket_ready=7}};prototypes={item={["space-platform-starter-pack"]={}}}
local force={index=1};local surface={index=1,planet={name="nauvis"}}
local pair={station={valid=true,unit_number=1,force=force,surface=surface},
 priest={valid=true,unit_number=2,force=force,surface=surface},independent_emergency_operation_0184={enabled=true}}
local payload,created,attempts,can_launch=0,0,0,false
local inventory={valid=true,get_item_count=function(n)assert(n=="space-platform-starter-pack");return payload end,
 can_insert=function()return true end}
local silo={valid=true,type="rocket-silo",force=force,surface=surface}
local report={silo=silo,rocket_silo_status=7,rocket_parts=0,rocket_parts_required=50,attached_cargo_inventory=inventory}
local platform
force.create_space_platform=function(spec)
 assert(spec.planet=="nauvis"and spec.starter_pack=="space-platform-starter-pack"and payload==1)
 created=created+1;platform={valid=true,force=force,space_location={name="nauvis"},surface={index=2}}
 return platform
end
silo.launch_rocket=function(destination)
 assert(destination.type==1 and destination.space_platform==platform)
 attempts=attempts+1
 if not can_launch then return false end
 assert(payload==1);payload=0;report.rocket_parts=0;return true
end
local Campaign=require("scripts.core.orbital_campaign_1287")
report.rocket_inventory=inventory
report.attached_cargo_inventory={valid=true,get_item_count=function()return 0 end,can_insert=function()return false end}
assert(Campaign.payload_inventory(report)==inventory,"reserved attached cargo hid the actual manual rocket inventory")
report.attached_cargo_inventory=inventory;report.rocket_inventory=nil
assert(not Campaign.requirement(pair,{})and created==0)
assert(Campaign.requirement(pair,report).loaded==false and created==0,
 "read-only planning created a free platform")
assert(not Campaign.request_launch(pair,report)and created==0 and attempts==0)
payload=1;pair.independent_emergency_operation_0184.enabled=false
assert(not Campaign.request_launch(pair,report)and created==0,"standard maintenance launched a player silo")
pair.independent_emergency_operation_0184.enabled=true;report.automation_owned=true
assert(not Campaign.request_launch(pair,report)and created==0,"external logistics ownership was ignored")
report.automation_owned=false;report.rocket_parts=49;report.rocket_silo_status=0
assert(not Campaign.request_launch(pair,report)and created==0)
report.rocket_parts=0;report.rocket_silo_status=7
pair.active_order_0469={kind="movement",status="active",source="player"}
assert(not Campaign.request_launch(pair,report)and created==0 and payload==1)
pair.active_order_0469=nil
assert(not Campaign.request_launch(pair,report)and created==1 and attempts==1 and payload==1 and not platform.hub)
assert(not Campaign.request_launch(pair,report)and created==1 and attempts==2 and payload==1,
 "native launch refusal duplicated a platform or removed real cargo")
can_launch=true;assert(Campaign.request_launch(pair,report)and created==1 and payload==0)
local observed=Campaign.observe(pair)
assert(not observed and storage.tech_priests.orbital_campaign_1287.by_force[1].phase=="launch-requested",
 "launch request was misreported as completed native delivery")
payload=1;assert(not Campaign.requirement(pair,report)and created==1,
 "another force-wide starter request duplicated an already paid flight")
payload=0
platform.hub={valid=true,force=force,surface=platform.surface};game.tick=1300
assert(Campaign.observe(pair)and storage.tech_priests.orbital_campaign_1287.by_force[1].phase=="starter-pack-delivered")
payload=1;report.rocket_parts=50
assert(not Campaign.requirement(pair,report)and created==1,"built platform caused duplicate starter launch")
local Void=require("scripts.core.void_orbital_construction_1292");local original_request=Void.material_request
Void.material_request=function()return{item="solar-panel",count=1,manager_station=8}end
local solar=0;local foreign_cargo=false
local cargo={valid=true,get_item_count=function(n)return n=="solar-panel"and solar or 0 end,can_insert=function()return true end,
 get_contents=function()return foreign_cargo and{{name="processing-unit",count=1}}or(solar>0 and{{name="solar-panel",count=solar}}or{})end}
report.rocket_inventory=cargo;report.attached_cargo_inventory=nil;defines.cargo_destination.station=2
assert(Campaign.requirement(pair,report).item=="solar-panel"and not Campaign.requirement(pair,report).loaded)
solar=1;local pod={valid=true}
silo.rocket={valid=true,attached_cargo_pod=pod}
silo.launch_rocket=function(destination)
 assert(destination.type==2 and destination.station==platform.hub and not destination.space_platform,
  "cargo used the starter-pack-only destination")
 solar=0;return true
end
assert(Campaign.request_launch(pair,report)and created==1)
Campaign.observe(pair)
assert(not Campaign.requirement(pair,report),"one local request duplicated an in-flight cargo launch")
pod.valid=false;Campaign.observe(pair)
assert(not Campaign.requirement(pair,report).loaded,"lost native flight falsely supplied the local Void demand")
foreign_cargo=true;assert(not Campaign.requirement(pair,report),"unrelated player cargo was launched")
Void.material_request=original_request
platform.force={index=2};assert(not Campaign.request_launch(pair,report)and created==1)
silo.position={x=20,y=0};silo.name="rocket-silo";silo.unit_number=4
silo.prototype={rocket_parts_required=50};silo.rocket_parts=0;silo.rocket_silo_status=7
silo.get_recipe=function()return{name="rocket-part",ingredients={},products={}}end
silo.get_inventory=function()return nil end
surface.find_entities_filtered=function()return{}end
local Readiness=require("scripts.core.rocket_silo_readiness_0709")
local native_ready=Readiness.inspect_silo(pair,silo,true)
assert(native_ready.state=="rocket-ready-monitor"and not native_ready.launch_sequence_active
 and native_ready.rocket_parts==0,"ready native rocket was confused with launch or new part manufacturing")
defines.inventory={crafter_input=1};prototypes.item["rocket-fuel"]={stack_size=10}
silo.get_recipe=function()return{name="rocket-part",ingredients={{name="rocket-fuel",type="item",amount=1}},products={}}end
silo.get_inventory=function(id)if id==1 then return{valid=true,get_item_count=function()return 0 end}end end
silo.rocket_silo_status=0
local buffered=Readiness.inspect_silo(pair,silo,true)
assert(buffered.item_ingredients_missing[1].target==10,"independent silo retained two-cycle transport churn")
pair.independent_emergency_operation_0184.enabled=false
assert(Readiness.inspect_silo(pair,silo,true).item_ingredients_missing[1].target==2,
 "independent batching changed standard player maintenance")
print("PASS independent native launch authority, paid payload, one platform order and truthful delivery observation")
