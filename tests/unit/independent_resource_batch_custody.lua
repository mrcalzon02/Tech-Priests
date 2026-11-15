package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=100};storage={tech_priests={}};prototypes={item={stone={}}}
local force,surface={index=1},{index=1}
local ore={valid=true,type="resource",name="stone",amount=20,position={x=8,y=0},force=force,surface=surface}
local task={kind="direct-mine-0336",bootstrap_resource_0637=true,required_count=4,
 output_item="stone",current={kind="direct-mine-0336",entity=ore,output_item="stone"}}
local pair={station={valid=true,unit_number=1,position={x=0,y=0},force=force,surface=surface},
 priest={valid=true,unit_number=2,position={x=8,y=0},force=force,surface=surface},
 radius=32,emergency_craft=task,independent_emergency_operation_0184={enabled=true}}
local trips,deposits=0,0
tech_priests_stop_movement_0418=function()return true end
tech_priests_request_movement_0418=function()trips=trips+1;return true end
tech_priests_safe_deposit_item=function(_,item,n)assert(item=="stone");deposits=deposits+n;return true end
local D=require("scripts.core.direct_acquisition_executor_0513")
D.service_pair(pair,"start")
game.tick=game.tick+D.laser_work_ticks(ore)+1;D.service_pair(pair,"first")
assert(ore.amount==19 and pair.direct_acquisition_custody_0513.count==1 and trips==0)
local Guard=require("scripts.core.direct_acquisition_physical_guard_0649")
for n=2,4 do
 D.service_pair(pair,"batch-work")
 game.tick=game.tick+D.laser_work_ticks(ore)+1
 D.service_pair(pair,"batch-extract")
 Guard.service_pair(pair,"guard-with-cargo")
 assert(ore.amount==20-n and pair.direct_acquisition_custody_0513.count==n and deposits==0,
  "material batch skipped resource cost, lost custody or deposited remotely")
end
D.service_pair(pair,"return")
assert(trips==1 and deposits==0,"material request still makes a return trip for every single unit")
pair.priest.position={x=1,y=0};game.tick=game.tick+5
D.service_pair(pair,"arrived")
assert(deposits==4 and not pair.direct_acquisition_custody_0513 and not pair.emergency_craft,
 "counted material batch failed exact physical return and completion")
print("PASS independent material mining retains exact timed resource debits and returns four units in one physical trip")
pair.priest.position={x=0,y=0};pair.priest.name="test-priest"
pair.emergency_craft={kind="direct-mine-0336",output_item="stone",required_count=4,
 bootstrap_resource_0637=true,current={kind="direct-mine-0336",entity=ore,output_item="stone"}}
surface.can_place_entity=function(spec)return spec.position.x==8 and spec.position.y>.8 end
local goal,options
tech_priests_request_movement_0418=function(_,position,_,opts)goal=position;options=opts;return true end
local before=ore.amount;game.tick=game.tick+1000
assert(D.service_pair(pair,"ore-under-solid-drill"))
assert(goal and goal.x==8 and goal.y==1.25 and options.radius==.15,
 "direct mining targeted the ore tile occupied by a working drill")
assert(ore.amount==before and not pair.direct_acquisition_custody_0513,
 "walkable mining contact credited ore before physical arrival")
surface.can_place_entity=function()return false end
assert(D.target_contact_position(pair,ore)==nil,
 "blocked ore target fabricated a traversable contact")
print("PASS direct mining uses a clear contact within original extraction reach")
