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
Energy.service_pair(pair)
assert(moves[#moves].x==2,"fuel pickup still targets the solid cargo center")
-- Pickup reach is greater than the movement completion radius. Arriving
-- within item reach must hand off the owned source route before delivery.
pair.priest.position={x=.5,y=0};Energy.service_pair(pair)
assert(stock==0 and pair.energy_family_custody_0707.count==2 and delivered==0,
 "physical edge pickup failed to retain exact fuel custody")
assert(moves[#moves].x==8.5,"boiler delivery did not use its actual footprint")
assert(pair.movement_request_0418.x==8.5,
 "native movement debounce sent counted coal back to its source")
pair.priest.position={x=8,y=0};Energy.service_pair(pair)
assert(delivered==2 and not pair.energy_family_custody_0707 and not pair.energy_family_logistics_0707,
 "counted coal never reached the physical boiler")
assert(not pair.movement_request_0418,"completed fuel duty retained its movement lease")
print("PASS canonical fuel storage, distinct inventory identity and physical footprint delivery")
station.bounding_box={left_top={x=-.7,y=-.7},right_bottom={x=.7,y=.7}}
local backing={valid=true,name="tech-priests-cogitator-return-cache",position={x=0,y=0},force=force,surface=surface,
 bounding_box={left_top={x=0,y=0},right_bottom={x=0,y=0}}}
local Fetch=require("scripts.core.logistics_fetch_executor_0527")
assert(Fetch.pickup_position(pair,backing).x==.7,"hidden station inventory still targets inaccessible solid host center")
backing.force={index=2}
assert(Fetch.pickup_position(pair,backing).x==0,"foreign backing inventory inherited station access geometry")
print("PASS same-force co-located backing inventory uses actual host footprint")
