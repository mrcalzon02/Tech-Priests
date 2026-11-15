package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=1000};defines={inventory={chest=1},command={stop=1,go_to_location=2},
 distraction={none=0}};storage={tech_priests={pairs_by_station={}}}
local force={index=1};local surface={index=1};local stock=2;local delivered=0
local same_text={__tostring=function()return "LuaInventory"end}
local empty=setmetatable({valid=true,get_item_count=function()return 0 end},same_text)
local cache_inv=setmetatable({valid=true,get_item_count=function(item)return item=="coal"and stock or 0 end,
 remove=function(spec)local n=math.min(stock,spec.count);stock=stock-n;return n end},same_text)
local station={valid=true,unit_number=1,position={x=0,y=0},force=force,surface=surface,
 get_inventory=function()return empty end}
local cache={valid=true,unit_number=4,position={x=5,y=0},force=force,surface=surface,
 bounding_box={left_top={x=2,y=-3},right_bottom={x=8,y=3}}}
local boiler={valid=true,unit_number=5,name="boiler",type="boiler",position={x=10,y=0},
 force=force,surface=surface,bounding_box={left_top={x=8.5,y=-1},right_bottom={x=11.5,y=1}}}
local pair={station=station,priest={valid=true,unit_number=2,position={x=0,y=0}},radius=40}
storage.tech_priests.pairs_by_station[1]=pair
prototypes={item={coal={fuel_value=4000000}}}
TechPriestsStorageRoleAuthority0686={generic_storage_sources=function(p)
 assert(p==pair);return {{entity=station,inv=empty},{entity=cache,inv=cache_inv}}end}
local report={entity=boiler,entity_name="boiler",entity_unit=5,state="fuel-service-eligible",
 fuel_count=0,fuel_inventory={valid=true,can_insert=function()return true end,
 insert=function(spec)delivered=delivered+spec.count;return spec.count end}}
TechPriestsEnergyFamilyReadiness0705={scan_pair=function(p)p.energy_family_reports_0705={report}end,
 inspect_entity=function()return report end}
TechPriestsWorkReservations0601={categories={},root=function()return {}end,
 claim=function()return true end,release=function()return true end}
local services={}
TechPriestsRuntimeTickBroker0600={register_service=function(spec)services[spec.name]=spec;return spec end}
local moves={}
local Movement=require("scripts.core.movement_controller")
TECH_PRIESTS_MOVEMENT_CONTROLLER_0418=Movement
tech_priests_request_movement_0418=function(p,pos,reason,opts)
 assert(p==pair);moves[#moves+1]=pos;return Movement.request(p,pos,reason,opts)end
local Energy=require("scripts.core.energy_family_logistics_0707")
assert(Energy.install())
services.energy_family_discovery_0707.fn(nil,1)
assert(pair.energy_family_candidate_0707.source.entity==cache and stock==2,
 "canonical fuel storage disappeared behind an identical inventory display name")
local Arbiter=require("scripts.core.action_state_arbiter_0488")
local Dispatcher=require("scripts.core.single_dispatcher_0510")
TECH_PRIESTS_ACTION_STATE_ARBITER_0488=Arbiter
-- Independent strict batches can lack the facility-only compatibility flag.
-- The original dispatcher must send them to physical fuel service, preserving
-- their parent task through pickup, counted custody and delivery.
local parent={output_item="stone-wall",strict_recipe_0647=true,count=5}
pair.emergency_craft=parent
local crafts=0
TechPriestsEmergencyProductionExecutor0514={service_pair=function()
 crafts=crafts+1;return true,"parent-resumed"end}
Dispatcher.service_pair(pair,"strict-batch-fuel")
assert(moves[#moves].x==2,"fuel pickup still targets the solid cargo center")
-- Pickup reach is greater than the movement completion radius. Arriving
-- within item reach must hand off the owned source route before delivery.
pair.priest.position={x=.5,y=0};Dispatcher.service_pair(pair,"strict-batch-fuel")
assert(stock==0 and pair.energy_family_custody_0707.count==2 and delivered==0,
 "physical edge pickup failed to retain exact fuel custody")
assert(moves[#moves].x==8.5,"boiler delivery did not use its actual footprint")
assert(pair.movement_request_0418.x==8.5,
 "native movement debounce sent counted coal back to its source")
pair.priest.position={x=8,y=0};Dispatcher.service_pair(pair,"strict-batch-fuel")
assert(delivered==2 and not pair.energy_family_custody_0707 and not pair.energy_family_logistics_0707,
 "counted coal never reached the physical boiler")
assert(not pair.movement_request_0418,"completed fuel duty retained its movement lease")
assert(pair.emergency_craft==parent and crafts==0,
 "fuel service replaced the strict parent or manufactured while holding coal")
Dispatcher.service_pair(pair,"strict-batch-resume")
assert(crafts==1 and pair.emergency_craft==parent,
 "strict parent did not resume after its physical boiler delivery")
pair.emergency_craft=nil
print("PASS canonical fuel storage, distinct inventory identity and physical footprint delivery")
station.bounding_box={left_top={x=-.7,y=-.7},right_bottom={x=.7,y=.7}}
local backing={valid=true,name="tech-priests-cogitator-return-cache",position={x=0,y=0},force=force,surface=surface,
 bounding_box={left_top={x=0,y=0},right_bottom={x=0,y=0}}}
local Fetch=require("scripts.core.logistics_fetch_executor_0527")
assert(Fetch.pickup_position(pair,backing).x==.7,"hidden station inventory still targets inaccessible solid host center")
backing.force={index=2}
assert(Fetch.pickup_position(pair,backing).x==0,"foreign backing inventory inherited station access geometry")
print("PASS same-force co-located backing inventory uses actual host footprint")
-- The closest boiler corner can be enclosed by real plumbing. Navigation
-- must choose a clear exterior side while delivery still measures the real box.
pair.priest.name="test-priest";pair.priest.position={x=5,y=0}
surface.can_place_entity=function(spec)
 return spec.position.x>11.5 and spec.position.y==0
end
local contact=Fetch.approach_position(pair,boiler)
assert(contact and contact.x==12.05 and contact.y==0,
 "blocked boiler corner did not select the clear opposite service point")
local reach=Fetch.pickup_position({station=station,priest={position=contact}},boiler)
assert((contact.x-reach.x)^2+(contact.y-reach.y)^2<2.56,
 "walkable boiler contact enlarged physical delivery reach")
surface.can_place_entity=function()return false end
assert(Fetch.approach_position(pair,boiler)==nil,
 "completely blocked boiler fabricated a walkable destination")
print("PASS blocked boiler corner chooses a real clear side within original transfer reach")
surface.can_place_entity=function()return true end
stock=100;delivered=0;pair.priest.position={x=8,y=0}
game.tick=2000
services.energy_family_discovery_0707.fn(nil,1)
assert(pair.energy_family_candidate_0707.count==50,
 "native boiler still received a short eight-coal trip")
Energy.service_pair(pair);Energy.service_pair(pair);Energy.service_pair(pair)
assert(stock==50 and delivered==50 and not pair.energy_family_custody_0707,
 "full native boiler batch was not physically debited and delivered exactly")

local Readiness=require("scripts.core.energy_family_readiness_0705")
local fuel_count=8
local fuel={valid=true,get_contents=function()return{coal=fuel_count}end,
 get_item_count=function(name)return name=="coal"and fuel_count or 0 end}
boiler.get_fuel_inventory=function()return fuel end
boiler.burner={currently_burning={name="coal"},remaining_burning_fuel=1000000}
surface.find_entities_filtered=function()return{}end
local warm=Readiness.inspect_entity(pair,boiler,true)
assert(warm.state=="fuel-service-eligible"and warm.fuel_reserve_items==16
 and warm.burner.currently_burning=="coal",
 "burning a last coal hid the native boiler's depleted fuel reserve")
fuel_count=16
assert(Readiness.inspect_entity(pair,boiler,true).state=="fuel-sufficient",
 "native boiler reserve caused continuous unnecessary refueling")
fuel_count=0;boiler.burner.currently_burning={name="rocket-fuel"}
assert(Readiness.inspect_entity(pair,boiler,true).state=="fuel-sufficient",
 "coal reserve overrode another actually burning native fuel")
boiler.burner.currently_burning={name="coal"};fuel_count=1;boiler.name="modded-boiler"
assert(Readiness.inspect_entity(pair,boiler,true).state=="fuel-sufficient",
 "vanilla coal reserve changed an unverified modded burner")
boiler.name="boiler"
surface.find_entities_filtered=function()return{{type="inserter",pickup_target=boiler}}end
assert(Readiness.inspect_entity(pair,boiler,true).state=="external-item-automation-owned",
 "proactive fuel reserve seized an inserter-owned boiler")
print("PASS fifty paid coal, warm native boiler reserve, other fuels and external automation ownership")
