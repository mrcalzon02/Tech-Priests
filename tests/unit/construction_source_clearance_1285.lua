-- Original construction chooses its own physical access dependency; canonical
-- acquisition must mine native wood, return it, and preserve the paid parent.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=1000};storage={tech_priests={pairs_by_station={}}}
defines={distraction={none=0}};prototypes={item={wood={},["assembling-machine-1"]={}}}
local bag
game.create_inventory=function()
 local items={};local inv={valid=true};bag=inv
 inv.get_item_count=function(n)return items[n]or 0 end
 inv.get_contents=function()local r={};for n,c in pairs(items)do if c>0 then r[#r+1]={name=n,count=c,quality="normal"}end end;return r end
 inv.insert=function(s)items[s.name]=(items[s.name]or 0)+s.count;return s.count end
 inv.remove=function(s)local n=math.min(items[s.name]or 0,s.count);items[s.name]=(items[s.name]or 0)-n;return n end
 inv.is_empty=function()return inv.get_item_count("wood")==0 end
 inv.destroy=function()assert(inv.is_empty());inv.valid=false end
 return inv
end
local force={name="player",index=1};local surface={index=1}
local stock,wood,mined=1,0,0
local inv={valid=true,get_item_count=function(n)return n=="assembling-machine-1"and stock or 0 end}
inv.remove=function(s)local n=math.min(stock,s.count);stock=stock-n;return n end
local station={valid=true,name="senior-cogitator-station",unit_number=1,position={x=0,y=0},force=force,surface=surface}
local priest={valid=true,name="test-priest",unit_number=2,position={x=0,y=0},force=force,surface=surface}
local source={valid=true,unit_number=3,position={x=6,y=0},force=force,surface=surface,
 selection_box={left_top={x=5.5,y=-.5},right_bottom={x=6.5,y=.5}}}
local tree={valid=true,name="tree-01",type="tree",unit_number=4,position={x=1.2,y=0},surface=surface,
 force={name="neutral",index=3},prototype={mineable_properties={products={{name="wood",type="item",amount=2}}}}}
tree.mine=function(spec)assert(spec.inventory==bag);mined=mined+1;bag.insert{name="wood",count=2};tree.valid=false;return true end
surface.find_entities_filtered=function(spec)return spec.type=="tree"and{tree}or{}end
surface.can_place_entity=function()return true end
local pair={station=station,priest=priest,radius=32,station_unit=1,independent_emergency_operation_0184={enabled=true}}
storage.tech_priests.pairs_by_station[1]=pair
local moves={}
tech_priests_request_movement_0418=function(_,pos,reason) moves[#moves+1]={pos=pos,reason=reason};return true end
tech_priests_stop_movement_0418=function()return true end
local full=false
tech_priests_safe_deposit_item=function(_,n,c)assert(n=="wood");if full then return false,"full",0 end;wood=wood+c;return true,"deposited",c end
local Queue=require("scripts.core.order_queue_0469");TECH_PRIESTS_ORDER_QUEUE_0469=Queue
local Direct=require("scripts.core.direct_acquisition_executor_0513");TechPriestsDirectAcquisitionExecutor0513=Direct
local Builder=require("scripts.core.construction_planner");TechPriestsConstructionPlanner0338=Builder
local Arbiter=require("scripts.core.action_state_arbiter_0488");TECH_PRIESTS_ACTION_STATE_ARBITER_0488=Arbiter
local Dispatcher=require("scripts.core.single_dispatcher_0510")
local parent={phase="move-source",started_tick=1000,reserved_0338=true,source_entity=source,source_inv=inv,
 item_name="assembling-machine-1",entity_name="assembling-machine-1",position={x=10,y=0},
 source_contact_entity_1285=source,source_contact_origin_1285={x=6,y=0},source_contact_tried_1285={true,true,true,true,true,true,true,true}}
pair.construction_task_0338=parent
local function attempt()game.tick=game.tick+121;return Builder.service_pair(pair,"autonomous-source-access")end
-- These refusals must not mint, extract or spend anything.
pair.independent_emergency_operation_0184.enabled=false
assert(attempt().detail=="source-contacts-unavailable"and not pair.direct_acquisition_task_0336)
pair.independent_emergency_operation_0184.enabled=true
pair.item_family_custody_0702={count=1}
assert(attempt().detail=="source-contacts-unavailable"and not pair.direct_acquisition_task_0336)
pair.item_family_custody_0702=nil
tree.force={name="enemy"};assert(attempt().detail=="source-contacts-unavailable")
tree.force={name="neutral"};tree.position={x=40,y=0}
assert(attempt().detail=="source-contacts-unavailable")
tree.position={x=1.2,y=0}
local incumbent={kind="logistics",status="active",source="existing",task={}}
pair.active_order_0469=incumbent
assert(attempt().detail=="source-contacts-unavailable"and pair.active_order_0469==incumbent)
pair.active_order_0469=nil
assert(attempt().detail=="source-access-clearance-requested")
local child=pair.direct_acquisition_task_0336
assert(child and Builder.source_clearance_active_1285(pair)and pair.order_queue_0469.current.task==child)
assert(stock==1 and wood==0 and mined==0 and not parent.carried)
assert(Arbiter.action(pair).kind=="acquisition","builder hid its own physical access dependency")
Dispatcher.service_pair(pair,"native-tree-start")
full=true;game.tick=game.tick+100
Dispatcher.service_pair(pair,"native-tree-finish")
assert(mined==1 and bag.valid and bag.get_item_count("wood")==2 and stock==1 and wood==0,
 "clearance failed native mining or lost refused wood cargo")
-- Parent revocation cannot delete already mined native cargo.
pair.construction_task_0338=nil;full=false;game.tick=game.tick+5
Dispatcher.service_pair(pair,"return-actual-wood")
assert(wood==2 and not bag.valid and not pair.direct_acquisition_task_0336 and not pair.direct_acquisition_custody_0513)
assert(not pair.order_queue_0469.current and stock==1 and mined==1)
pair.construction_task_0338=parent
assert(attempt().detail=="moving-source"and not pair.construction_source_clearance_1285 and stock==1)
priest.position={x=5,y=0}
local picked=attempt()
assert(picked.detail=="moving-site"and stock==0 and parent.carried.count==1
 and pair.construction_custody_0338.count==1 and pair.construction_task_0338==parent)
-- Both outbound and restitution travel can encounter forest. Measured stall
-- admits only the parent's tree dependency, retaining the exact paid kit.
for _,phase in ipairs{"move-site","return-custody"}do
 parent.phase=phase;priest.position={x=0,y=0};tree.position={x=1.2,y=0};tree.valid=true
 parent.access_route_best_1285=nil
 local before=mined
 attempt();game.tick=game.tick+181
 assert(Builder.service_pair(pair,"measured-construction-stall").detail=="source-access-clearance-requested")
 assert(Builder.source_clearance_active_1285(pair)and Arbiter.action(pair).kind=="acquisition"
  and stock==0 and parent.carried.count==1 and pair.construction_custody_0338.count==1)
 Dispatcher.service_pair(pair,"paid-kit-tree-start");game.tick=game.tick+100
 Dispatcher.service_pair(pair,"paid-kit-tree-mined");game.tick=game.tick+5
 Dispatcher.service_pair(pair,"paid-kit-wood-return")
 assert(mined==before+1 and not pair.direct_acquisition_custody_0513
  and not pair.direct_acquisition_task_0336 and stock==0
  and parent.carried.count==1 and pair.construction_custody_0338.count==1,
  "access dependency stole the paid construction kit or failed real wood custody")
end
assert(wood==6 and mined==3)
-- Revoked unladen access cannot mine, fail, or complete a foreign order.
priest.position={x=0,y=0};stock=1;tree.valid=true;parent.carried=nil;parent.phase="move-source"
pair.construction_custody_0338=nil;parent.source_contact_1285=nil
parent.source_contact_tried_1285={true,true,true,true,true,true,true,true}
assert(attempt().detail=="source-access-clearance-requested")
pair.construction_task_0338=nil
local foreign={kind="combat",status="active",source="foreign",task={}}
pair.order_queue_0469.current=foreign;pair.active_order_0469=foreign
local _,why=Direct.service_pair(pair,"revoked-access")
assert(why=="construction-source-clearance-context-changed"and mined==3 and stock==1
 and pair.order_queue_0469.current==foreign and foreign.status=="active")
print("PASS autonomous source clearance, native custody, parent resumption and foreign-order guards")
-- A strict lab cannot strand access to its own admitted native pipe route.
pair.order_queue_0469.current=nil;pair.active_order_0469=nil;pair.construction_task_0338=parent
pair.direct_acquisition_task_0336=nil;pair.construction_source_clearance_1285=nil
pair.item_family_custody_0702=nil;parent.source_clearance_count_1285=0
local strict={output_item="lab",strict_recipe_0647=true,facility_only_0647=true,infrastructure_first_0640=true}
pair.emergency_craft=strict;parent.item_name="pipe";parent.entity_name="pipe";prototypes.item.pipe={}
inv.get_item_count=function(n)return n=="pipe"and stock or 0 end
local request={source="standard-fluid-route-0691",route_plan_id="native-steam",item_name="pipe"}
parent.request_field="construction_request";parent.request_value=request;pair.construction_request=request
pair.standard_fluid_route_plan_0691={id="native-steam",machine={valid=true,force=force,surface=surface},
 remote={entity={valid=true,force=force,surface=surface}}}
request.route_plan_id="stale";attempt();assert(not pair.direct_acquisition_task_0336 and pair.emergency_craft==strict)
request.route_plan_id="native-steam";pair.order_queue_0469.current=foreign;pair.active_order_0469=foreign
attempt();assert(not pair.direct_acquisition_task_0336 and foreign.status=="active")
pair.order_queue_0469.current=nil;pair.active_order_0469=nil
pair.active_task={};local production={kind="assignment",status="active",source="adopt-active",purpose="recipe-fanout",
 item="lab",task=pair.active_task,priority=100}
assert(Queue.submit(pair,production))
local admitted=attempt()
assert(admitted.detail=="source-access-clearance-requested"and pair.emergency_craft==strict,tostring(admitted.detail))
assert(Builder.source_clearance_active_1285(pair)and Arbiter.action(pair).kind=="acquisition")
Dispatcher.service_pair(pair,"strict-native-route-tree-start");game.tick=game.tick+100
Dispatcher.service_pair(pair,"strict-native-route-tree-mined");game.tick=game.tick+5
Dispatcher.service_pair(pair,"strict-native-route-wood-return")
assert(mined==4 and wood==8 and stock==1 and pair.emergency_craft==strict
 and not pair.direct_acquisition_custody_0513 and pair.construction_task_0338==parent)
tree.valid=true;priest.position={x=0,y=0};parent.source_contact_1285=nil
parent.source_contact_tried_1285={true,true,true,true,true,true,true,true}
local again=attempt()
if again.detail=="moving-source"then game.tick=game.tick+181;again=Builder.service_pair(pair,"renewed-physical-stall")end
assert(again.detail=="source-access-clearance-requested",tostring(again.detail))
local replacement={output_item="lab",strict_recipe_0647=true,facility_only_0647=true,infrastructure_first_0640=true}
pair.emergency_craft=replacement
local _,revoked=Direct.service_pair(pair,"strict-parent-replaced")
assert(revoked=="construction-source-clearance-context-changed"and mined==4 and wood==8
 and stock==1 and pair.emergency_craft==replacement,"clearance outlived its exact strict parent")
print("PASS strict native fluid parent retains its recipe while original mining clears and returns actual source wood")




