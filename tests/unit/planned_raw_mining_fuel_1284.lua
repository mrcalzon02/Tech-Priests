package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=1000};defines={inventory={chest=1,fuel=2,assembling_machine_input=3,
 assembling_machine_output=4},distraction={none=0}}
prototypes={item={coal={}}}
storage={tech_priests={pairs_by_station={}}}
local force={index=1};local surface={index=1};local stock,fuel=50,0
surface.find_entities_filtered=function()return{}end
surface.can_place_entity=function()return true end
local inventory={valid=true,get_contents=function()return{coal=fuel}end,
 get_item_count=function(name)return name=="coal"and fuel or 0 end,
 insert=function(s)assert(s.name=="coal");fuel=fuel+s.count;return s.count end}
local station={valid=true,unit_number=1,position={x=0,y=0},force=force,surface=surface}
local priest={valid=true,name="test-priest",unit_number=2,position={x=0,y=0},force=force,surface=surface}
local target={valid=true,name="stone",type="resource",position={x=8,y=0},surface=surface}
local drill={valid=true,unit_number=3,name="burner-mining-drill",type="mining-drill",
 position={x=6,y=0},force=force,surface=surface,mining_target=target,
 get_inventory=function(id)if id==2 then return inventory end end}
local raw={bootstrap_resource_0637=true,output_item="stone",required_count=98,
 current={kind="direct-mine-0336",entity=target,output_item="stone"}}
local pair={station=station,priest=priest,radius=40,emergency_craft=raw,
 direct_acquisition_task_0336=raw,mode="direct-acquisition",
 independent_emergency_operation_0184={enabled=true,magos_ratio_plan_0257={raw_items={stone=.5}}}}
storage.tech_priests.pairs_by_station[1]=pair
local record={station_unit=1,role="miner",entity=drill}
storage.tech_priests.emergency_facility_doctrine_0343={by_station={[1]={[3]=true}},facilities={[3]=record}}
TechPriestsStorageRoleAuthority0686={generic_item_count=function(_,item)return item=="coal"and stock or 0 end,
 remove_generic_item=function(_,item,n)assert(item=="coal");local take=math.min(stock,n);stock=stock-take;return take end}
local discovery
TechPriestsRuntimeTickBroker0600={register_service=function(spec)
 if spec.name=="machine_logistics_discovery_0528"then discovery=spec.fn end;return true end}
TechPriestsWorkReservations0601={categories={},root=function()return{reservations={}}end,
 claim=function()return true end,release=function()return true end}
local stops,extractions=0,0
TECH_PRIESTS_MOVEMENT_CONTROLLER_0418={request_status=function(p)
 local r=p.movement_request_0418;return{active=r~=nil,owner=r and r.owner}end,
 stop=function(p)stops=stops+1;p.movement_request_0418=nil;return true end}
tech_priests_request_movement_0418=function(p,pos,_,opts)
 p.movement_request_0418={x=pos.x,y=pos.y,owner=opts.owner,priority=opts.priority};return true end
TechPriestsDirectAcquisitionExecutor0513={current_direct_task=function(p)return raw,raw.current end,
 service_pair=function()extractions=extractions+1;return true,"raw-resumed"end}
local Machines=require("scripts.core.logistics_machine_fulfillment_0528")
assert(Machines.install())
local empty={valid=true,get_item_count=function()return 0 end,get_contents=function()return{}end,
 get_insertable_count=function()return 50 end}
local assembler={valid=true,unit_number=4,name="assembling-machine-1",type="assembling-machine",
 position={x=2,y=0},surface=surface,force=force,
 get_recipe=function()return{name="grenade",ingredients={{name="coal",amount=1}},
  products={{name="grenade",type="item",amount=1}}}end,
 get_inventory=function(id)if id==3 or id==4 then return empty end end}
surface.find_entities_filtered=function(spec)
 if type(spec.type)=="table"then
  for _,kind in ipairs(spec.type)do if kind=="mining-drill"then return{assembler,drill}end end
 end
 return{}
end
pair.independent_emergency_operation_0184.started_tick=0
pair.independent_emergency_operation_0184.magos_ratio_plan_0257.factory_component_jobs_1150={
 grenade={researched=true,output_deficient=true,output_item="grenade",required_per_minute=1}}
discovery(nil,2)
local candidate=pair.machine_logistics_candidate_0528
assert(candidate and candidate.machine==drill and candidate.item=="coal",
 "unrelated aged factory work hid the current planned mining fuel prerequisite")
assert(Machines.planned_raw_mining_fuel_ready_1282(pair),"planned native stone miner fuel not admitted")
assert(not Machines.yield_for_bootstrap(pair),"raw acquisition discarded its own mining fuel candidate")
assert(pair.machine_logistics_candidate_0528==candidate,"original fuel intent lost")
for _,field in ipairs{"direct_acquisition_custody_0513","item_family_custody_0702",
 "construction_custody_0338","emergency_facility_feed_custody_0357"}do
 pair[field]={count=1};assert(not Machines.planned_raw_mining_fuel_ready_1282(pair),field);pair[field]=nil
end
raw.direct_due_tick_0513=1100
assert(not Machines.planned_raw_mining_fuel_ready_1282(pair),"active extraction timer interrupted")
raw.direct_due_tick_0513=nil
record.station_unit=99;assert(not Machines.planned_raw_mining_fuel_ready_1282(pair),"foreign ownership accepted")
record.station_unit=1
target.name="iron-ore";assert(not Machines.planned_raw_mining_fuel_ready_1282(pair),"unrelated mining fuel preempted stone")
target.name="stone"
pair.order_queue_0469={current={status="active",kind="acquisition"}}
assert(not Machines.planned_raw_mining_fuel_ready_1282(pair),"explicit acquisition displaced")
pair.order_queue_0469=nil
pair.direct_acquisition_task_0336=nil
local smelting={output_item="stone-brick",strict_recipe_0647=true,facility_only_0647=true,
 infrastructure_first_0640=true,target_stock_0647=50,
 strict_recipe_ingredients_0647={{name="stone",count=2}}}
pair.emergency_craft=smelting
assert(Machines.planned_raw_mining_fuel_ready_1282(pair),
 "strict native smelting excluded fuel for its actually planned raw-material miner")
smelting.strict_recipe_ingredients_0647={{name="iron-ore",count=1}}
assert(not Machines.planned_raw_mining_fuel_ready_1282(pair),"unrelated strict recipe admitted stone fuel")
pair.emergency_craft=raw;pair.direct_acquisition_task_0336=raw
storage.tech_priests.emergency_facility_doctrine_0343.facilities[3]=nil
local receipt={station_unit=1,built_entity=drill,entity_unit=3,phase="complete",
 paid_original_0338=true,request_value={source="magos-stocked-ratio-capacity",
  raw_prerequisite_1282=true,resource_name="stone"}}
pair.factory_raw_mining_receipts_1282={[3]=receipt}
assert(Machines.planned_raw_mining_fuel_ready_1282(pair),"paid original normal-drill receipt was not recognized")
receipt.paid_original_0338=false
assert(not Machines.planned_raw_mining_fuel_ready_1282(pair),"unpaid drill intent became construction proof")
receipt.paid_original_0338=true;receipt.request_value.resource_name="iron-ore"
assert(not Machines.planned_raw_mining_fuel_ready_1282(pair),"unrelated paid drill receipt admitted this fuel")
receipt.request_value.resource_name="stone"
local Arbiter=require("scripts.core.action_state_arbiter_0488")
TECH_PRIESTS_ACTION_STATE_ARBITER_0488=Arbiter
local Dispatcher=require("scripts.core.single_dispatcher_0510")
pair.movement_request_0418={owner="direct-acquisition-0513",priority=650}
assert(Arbiter.action(pair).kind=="machine-logistics","planned fuel lost canonical dispatch")
Dispatcher.service_pair(pair,"planned-mining-fuel")
assert(stock==47 and fuel==0 and pair.machine_logistics_custody_0528.count==3
 and pair.emergency_craft==raw and stops==1 and extractions==0,
 "original dispatch failed exact coal pickup, parent retention or unladen route handoff")
Dispatcher.service_pair(pair,"planned-mining-fuel")
assert(fuel==0 and pair.movement_request_0418.owner=="logistics_machine_fulfillment_0528",
 "fuel was delivered remotely or without the original movement owner")
priest.position={x=6,y=0};Dispatcher.service_pair(pair,"planned-mining-fuel")
assert(fuel==3 and stock==47 and not pair.machine_logistics_custody_0528
 and pair.emergency_craft==raw,"counted coal did not reach the original owned native drill")
Dispatcher.service_pair(pair,"resume-raw-after-fuel")
assert(extractions==1 and pair.emergency_craft==raw,"preserved raw acquisition did not resume")
local produced=12
local output={valid=true,get_contents=function()return{stone=produced}end,
 get_item_count=function(item)return item=="stone"and produced or 0 end}
local receiver={valid=true,unit_number=5,name="wooden-chest",type="container",
 position={x=8,y=0},force=force,surface=surface,
 get_inventory=function(id)if id==1 then return output end end}
drill.drop_target=receiver
surface.find_entities_filtered=function(spec)
 if type(spec.type)=="table"then
  for _,kind in ipairs(spec.type)do if kind=="mining-drill"then return{assembler,drill,receiver}end end
 end
 return{}
end
game.tick=1400;discovery(nil,2)
candidate=pair.machine_logistics_candidate_0528
assert(candidate and candidate.machine==receiver and candidate.item=="stone"
 and candidate.action=="clear-output"and candidate.drill_source_0983==drill,
 "aged unrelated factory work hid the actual planned drill's completed output")
assert(Machines.planned_raw_mining_output_ready_1282(pair)
 and not Machines.yield_for_bootstrap(pair)
 and Arbiter.action(pair).kind=="machine-logistics"and produced==12,
 "physical raw output lost original collection dispatch or was remotely debited")
produced=0
assert(not Machines.planned_raw_mining_output_ready_1282(pair),"empty receiver treated as completed output")
produced=12;drill.drop_target=nil
assert(not Machines.planned_raw_mining_output_ready_1282(pair),"disconnected receiver accepted as native mining output")
print("PASS original planned raw miner receives exact paid fuel through canonical dispatch, custody and movement before raw work resumes")
print("PASS actual connected planned mining output outranks unrelated waiting work without remote pickup or phantom production")
