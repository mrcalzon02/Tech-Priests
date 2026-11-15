package.path="tech-priests_src/?.lua;"..package.path
game={tick=10000};defines={inventory={chest=1,crafter_input=2,crafter_output=3},distraction={none=0}}
prototypes={item={["stone-brick"]={},["stone"]={},["automation-science-pack"]={}}}
local force,surface={index=1},{index=1}
local stored,output=48,2
local empty={valid=true,get_item_count=function()return 0 end,get_contents=function()return{}end}
local inventory={valid=true,get_item_count=function(item)return item=="stone-brick"and output or 0 end,
 get_contents=function()return{{name="stone-brick",count=output}}end,
 remove=function(s)local n=math.min(output,s.count);output=output-n;return n end}
local station={valid=true,name="planetary-magos-cogitator-station",unit_number=1,
 position={x=0,y=0},force=force,surface=surface,get_inventory=function()return empty end}
local furnace={valid=true,name="stone-furnace",type="furnace",unit_number=3,
 position={x=10,y=0},force=force,surface=surface,
 get_inventory=function(id)return id==3 and inventory or empty end,
 get_recipe=function()return{name="stone-brick",ingredients={{name="stone",amount=2,type="item"}}}end}
local science_output={valid=true,get_item_count=function()return 10 end,
 get_contents=function()return{{name="automation-science-pack",count=10}}end}
local science={valid=true,name="assembling-machine-1",type="assembling-machine",unit_number=4,
 position={x=2,y=0},force=force,surface=surface,
 get_inventory=function(id)return id==3 and science_output or empty end,
 get_recipe=function()return{name="automation-science-pack",ingredients={}}end}
surface.find_entities_filtered=function(spec)
 if spec.limit==64 then return{}end
 return{science,furnace}
end
surface.can_place_entity=function()return true end
local craft={output_item="stone-brick",strict_recipe_0647=true,facility_only_0647=true,
 target_stock_0647=50,strict_recipe_ingredients_0647={{name="stone",count=2}}}
local p={station=station,priest={valid=true,name="tech-priest",unit_number=2,
 position={x=0,y=0},force=force,surface=surface},radius=40,emergency_craft=craft,
 dispatcher_emergency_production_0514={phase="feed-machine",tick=game.tick},
 independent_emergency_operation_0184={enabled=true,started_tick=0,magos_ratio_plan_0257={
 factory_component_jobs_1150={["automation-science-pack"]={researched=true,output_deficient=true,
 output_item="automation-science-pack",required_per_minute=5}}}}}
storage={tech_priests={pairs_by_station={[1]=p},emergency_facility_doctrine_0343={
 by_station={[1]={["u:3"]=true}},facilities={["u:3"]={entity=furnace,station_unit=1,role="smelter"}}}}}
TechPriestsStorageRoleAuthority0686={generic_item_count=function(_,item)return item=="stone-brick"and stored or 0 end,
 deposit_exact=function(_,item,n)assert(item=="stone-brick");stored=stored+n;return true,"deposited",n end}
TechPriestsWorkReservations0601={claim=function()return true end,release=function()end}
local discover
TechPriestsRuntimeTickBroker0600={register_service=function(s)discover=s.fn;return true end}
local M=require("scripts.core.logistics_machine_fulfillment_0528");assert(M.install())
discover(nil,1)
local c=p.machine_logistics_candidate_0528
assert(c and c.machine==furnace and c.item=="stone-brick"and c.count==2,
 "aged science output hid the exact strict parent's completed bricks")
p.movement_request_0418={owner="move_priest_to",expires_tick=game.tick+300}
assert(M.strict_prerequisite_output_ready_1044(p),"strict parent could not collect its own native product")
assert(M.recommend_action(p).kind=="machine-logistics")
local A=require("scripts.core.action_state_arbiter_0488")
assert(A.action(p).kind=="machine-logistics","canonical classifier kept manufacturing instead of collecting its finished product")
p.inventory_transfer_custody_0687={count=1}
assert(not M.strict_prerequisite_output_ready_1044(p),"parent-output collection preempted another physical cargo owner")
p.inventory_transfer_custody_0687=nil
p.order_queue_0469={current={status="active",kind="crafting",item="iron-plate"}}
assert(not M.strict_prerequisite_output_ready_1044(p),"unrelated explicit crafting order was hijacked")
p.order_queue_0469=nil
p.movement_request_0418={owner="repair_executor_0516",expires_tick=game.tick+300}
assert(not M.strict_prerequisite_output_ready_1044(p),"parent-output exception stole a foreign movement lease")
p.movement_request_0418=nil
local goal
tech_priests_request_movement_0418=function(_,pos,_,options)goal=pos;return true end
M.service_pair(p,"strict-parent-output-start")
assert(goal and output==2 and stored==48,"parent output was collected before physical arrival")
p.priest.position={x=10,y=0};game.tick=10005
M.service_pair(p,"strict-parent-output-arrived")
assert(output==0 and stored==48 and p.machine_logistics_custody_0528.count==2,
 "finished bricks were not held under original physical output custody")
assert(A.action(p).kind=="machine-logistics","strict parent stole the counted output's return journey")
p.priest.position={x=0,y=0};game.tick=10010
M.service_pair(p,"strict-parent-output-returned")
assert(stored==50 and output==0 and not p.machine_logistics_custody_0528 and p.emergency_craft==craft,
 "collection changed parent ownership, lost cargo or credited bricks before the real deposit")
assert(not M.strict_prerequisite_output_ready_1044(p),"fulfilled parent kept a false output lease")
local iron_parent={output_item="iron-plate",facility_only_0647=true,infrastructure_first_0640=true,
 target_stock_0647=4,count=4,required_count=4}
p.emergency_craft=iron_parent;output=2
defines.entity_status={full_output=32};furnace.status=32
furnace.get_recipe=function()return{name="iron-plate",ingredients={{name="iron-ore",amount=1}}}end
game.tick=11000;discover(nil,1)
c=p.machine_logistics_candidate_0528
assert(c and c.machine==furnace and c.item=="stone-brick"
 and M.strict_prerequisite_output_ready_1044(p),
 "native full_output from a previous recipe still stranded the owned facility-only iron parent")
assert(A.action(p).kind=="machine-logistics")
p.priest.position={x=10,y=0};M.service_pair(p,"previous-recipe-blocker-pickup")
p.priest.position={x=0,y=0};game.tick=11005;M.service_pair(p,"previous-recipe-blocker-return")
assert(output==0 and stored==52 and p.emergency_craft==iron_parent,
 "clearing old bricks credited imaginary iron or retired the real iron parent")
print("PASS owned strict parent output outranks unrelated jobs, preserves movement and returns counted native product")
