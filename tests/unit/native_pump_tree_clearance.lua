package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=1000};storage={tech_priests={pairs_by_station={}}}
prototypes={item={wood={},pipe={}}};defines={inventory={chest=1}}
local force={name="tp-arena-3",index=3};local surface={index=1}
local parent={output_item="lab",facility_only_0647=true,strict_recipe_0647=true,infrastructure_first_0640=true}
local pair={station={valid=true,unit_number=58,name="planetary-magos-cogitator-station",
 force=force,surface=surface,position={x=0,y=0}},priest={valid=true,unit_number=59,
 force=force,surface=surface,position={x=28,y=0}},radius=40,
 emergency_craft=parent,independent_emergency_operation_0184={enabled=true}}
storage.tech_priests.pairs_by_station[58]=pair
local tree={valid=true,unit_number=90,name="tree-05",type="tree",minable=true,
 position={x=29,y=0},force={name="neutral"},surface=surface,
 bounding_box={left_top={x=28.6,y=-.4},right_bottom={x=29.4,y=.4}},
 prototype={mineable_properties={products={{name="wood",type="item",amount=4}}}}}
local pump={valid=true,unit_number=91,name="offshore-pump",type="offshore-pump",
 position={x=30,y=0},force=force,surface=surface,
 fluidbox={valid=true,true,get_pipe_connections=function()return{{target_position={x=29,y=0}}}end}}
local load={valid=true,type="assembling-machine",force=force,surface=surface,energy=0,
 get_recipe=function()return{name="lab"}end}
surface.can_place_entity=function(spec)return spec.name~="pipe"or not tree.valid end
surface.find_entities_filtered=function(spec)assert(spec.type=="tree"and spec.force=="neutral");return{tree}end
TechPriestsStorageRoleAuthority0686={generic_item_count=function(_,name)return name=="wood"and 500 or 1 end}
local Clearance=require("scripts.core.native_pump_clearance_1252")
local Raw=require("scripts.core.bootstrap_resource_governor_0637")
local Direct=require("scripts.core.direct_acquisition_executor_0513")
TechPriestsDirectAcquisitionExecutor0513=Direct
local request=assert(Clearance.observe(pair,pump,load))
pair.machine_logistics_custody_0528={count=1}
assert(not Raw.admit_pump_clearance(pair),"tree clearance seized physical factory cargo")
pair.machine_logistics_custody_0528=nil
pair.order_queue_0469={current={kind="repair",status="active"}}
assert(not Raw.admit_pump_clearance(pair),"tree clearance seized explicit maintenance")
pair.order_queue_0469=nil
pair.independent_emergency_operation_0184.enabled=false
assert(not Raw.admit_pump_clearance(pair),"ordinary maintenance started autonomous site clearing")
pair.independent_emergency_operation_0184.enabled=true
local original_task={item="lab"}
pair.active_task=original_task;pair.active_task_0285=original_task
local original_order={kind="assignment",source="adopt-active",purpose="recipe-fanout",
 item="lab",task=original_task,status="active"}
pair.order_queue_0469={current=original_order}
TECH_PRIESTS_ORDER_QUEUE_0469={complete_current=function()error("native recipe order completed by tree mining")end}
assert(Raw.admit_pump_clearance(pair),"real obstructed intake did not admit its exact wood child")
local child=pair.direct_acquisition_task_0336
assert(child.pump_clearance_1252==request and child.current.entity==tree
 and pair.emergency_craft==parent and tree.valid,
 "clearance admission changed recipe, tree or physical stock")
assert(Direct.target_within_bounds(pair,tree.position),"exact owned inlet tree inherited the unrelated 24-tile ore cap")
assert(not Direct.target_within_bounds(pair,{x=41,y=0}),"site clearance authorized work beyond real station territory")
child.current=nil
assert(Raw.service_pair(pair)and pair.direct_acquisition_task_0336==child
 and child.current.entity==tree,"cleared canonical pointer retargeted clearance to an unrelated tree")
Raw.service_pair(pair)
assert(pair.direct_acquisition_task_0336==child,"existing wood stock retired an unmined physical obstruction")
local Arbiter=require("scripts.core.action_state_arbiter_0488")
assert(Arbiter.action(pair).kind=="acquisition","strict laboratory starved its exact physical clearance child")
local bag,wood= nil,0
game.create_inventory=function()
 local n=0;bag={valid=true}
 bag.get_item_count=function(name)return name=="wood"and n or 0 end
 bag.get_contents=function()return n>0 and{{name="wood",count=n}}or{}end
 bag.insert=function(s)n=n+s.count;return s.count end
 bag.remove=function(s)local k=math.min(n,s.count);n=n-k;return k end
 bag.is_empty=function()return n==0 end
 bag.destroy=function()assert(n==0);bag.valid=false end
 return bag
end
tree.mine=function(spec)assert(spec.inventory==bag);bag.insert{name="wood",count=4};tree.valid=false;return true end
tech_priests_stop_movement_0418=function()return true end
local refused=true
tech_priests_safe_deposit_item=function(_,name,count)
 assert(name=="wood");if refused then return false,"full",0 end
 wood=wood+count;return true,"deposited",count
end
Direct.service_pair(pair,"physical-tree-clearance")
game.tick=1100;Direct.service_pair(pair,"native-tree-mined")
assert(not tree.valid and bag.valid and bag.get_item_count("wood")==4
 and pair.direct_acquisition_custody_0513,"actual engine tree yield did not remain in physical custody")
assert(pair.emergency_craft==parent,"tree extraction discarded its native laboratory parent")
pair.priest.position={x=1,y=0};refused=false;game.tick=1110
Direct.service_pair(pair,"wood-physically-returned")
assert(wood==4 and not bag.valid and not pair.direct_acquisition_custody_0513
 and not pair.direct_acquisition_task_0336 and not pair.power_setup_tree_clearance_1252
 and pair.emergency_craft==parent and pair.order_queue_0469.current==original_order,
 "clearance failed exact native yield return and original recipe/order resumption")
assert(Direct.direct_radius(pair)==24,"completed clearance left a broader acquisition authority behind")
print("PASS exact native outlet tree, bounded original mining, real wood custody, refused deposit and strict-parent resumption")
