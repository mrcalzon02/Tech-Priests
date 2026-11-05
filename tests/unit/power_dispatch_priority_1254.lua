-- 1254: new routine queue work cannot starve an already-funded steam
-- generator work item, but foreign orders/cargo/movement retain ownership.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=4800}
local force={index=1}
local surface={index=1}
local station={valid=true,unit_number=21,
 name="planetary-magos-cogitator-station",force=force,surface=surface,
 position={x=0,y=0}}
local priest={valid=true,unit_number=22,
 position={x=0,y=1},force=force,surface=surface}
local pair={station=station,priest=priest,mode="idle"}
storage={tech_priests={pairs_by_station={[21]=pair}}}
local power={owner="power-setup-1252",item_name="boiler",
 entity_name="boiler",position={x=-12,y=0}}
pair.structure_construction_requested_item=power
local orders,discover,construct=0,0,0
_G.TECH_PRIESTS_ORDER_QUEUE_0469={
 tick_pair=function()orders=orders+1;return true end}
_G.TECH_PRIESTS_ACTION_STATE_ARBITER_0488={
 action=function()return{kind="idle",reason="routine"}end}
_G.TechPriestsResourceReturnCourier0837=nil
_G.TechPriestsRailTrackFrontier0836=nil
_G.TechPriestsRemoteRailOutpost0835=nil
_G.TechPriestsDefensePerimeter0259=nil
_G.tech_priests_0259_resource_expansion_service=nil
_G.TechPriestsConstructionPlanner0338={
 discover_pair=function(p)
  assert(p==pair)
  discover=discover+1
  return {item_name="boiler",request_value=power}
 end,
 service_pair=function(p,reason)
  assert(p==pair and reason:find("funded-physical-power-1254",1,true))
  construct=construct+1
  return {processed=1,waiting=1,detail="moving-source"}
 end}
local Dispatcher=require("scripts.core.single_dispatcher_0510")
local out=Dispatcher.service_pair(pair,"power-priority-1254")
assert(out.waiting==1 and construct==1 and discover==1 and orders==0
 and pair.canonical_action_0744.family=="construction"
 and pair.canonical_action_0744.item=="boiler"
 and pair.structure_construction_requested_item==power,
 "funded power infrastructure failed to execute before new routine orders")
pair.active_order_0469={kind="logistics",status="active"}
local before=construct
Dispatcher.service_pair(pair,"foreign-order")
assert(construct==before and pair.active_order_0469.status=="active"
 and orders==1,
 "physical power planning seized a live 0469 foreign order")
pair.active_order_0469=nil
pair.direct_acquisition_custody_0513={item="iron-ore",count=1}
_G.TechPriestsDirectAcquisitionExecutor0513={
 service_pair=function(p)
  assert(p==pair and pair.direct_acquisition_custody_0513.count==1)
  return{processed=1,waiting=1,detail="physical-return"}
 end}
Dispatcher.service_pair(pair,"incumbent-cargo")
assert(construct==before and pair.direct_acquisition_custody_0513.count==1,
 "power priority seized one real 0513 ore from another owner")
pair.direct_acquisition_custody_0513=nil
pair.movement_request_0418={owner="direct-acquisition-0513",
 expires_tick=game.tick+120}
Dispatcher.service_pair(pair,"movement-reservation")
assert(construct==before and pair.movement_request_0418
 and pair.movement_request_0418.expires_tick>game.tick,
 "live 0418 movement was overwritten")
pair.movement_request_0418=nil
pair.construction_task_0338={phase="move-site",item_name="iron-chest"}
Dispatcher.service_pair(pair,"incumbent-builder")
assert(construct==before
 and pair.construction_task_0338.item_name=="iron-chest",
 "new boiler stole active 0338 construction")
pair.construction_task_0338=nil
pair.active_task={kind="repair"}
Dispatcher.service_pair(pair,"incumbent-task")
assert(construct==before and pair.active_task.kind=="repair",
 "new boiler seized foreign repair task")
print("[power-dispatch-priority-1254] PASS boiler dispatch before fresh orders, preserves foreign order, cargo, movement and active 0338 work")
