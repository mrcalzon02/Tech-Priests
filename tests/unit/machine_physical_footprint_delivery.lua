package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=1000};defines={inventory={crafter_input=3,crafter_output=4},command={stop=1,go_to_location=2},distraction={none=0}}
prototypes={item={["iron-plate"]={}}};TechPriestsPairBucketRegistry0600={force_bucket=function()end}
local force={index=1};local surface={valid=true,index=1}
local box={left_top={x=8.5,y=-1.5},right_bottom={x=11.5,y=1.5}}
surface.can_place_entity=function(spec)
 local p=spec.position
 return p.x<8.15 or p.x>11.85 or p.y< -1.85 or p.y>1.85
end
surface.find_entities_filtered=function()return {}end
local inserted=0
local input={valid=true,get_item_count=function()return inserted end,
 insert=function(s)assert(s.name=="iron-plate");inserted=inserted+s.count;return s.count end}
local machine={valid=true,name="assembling-machine-1",type="assembling-machine",unit_number=3,position={x=10,y=0},bounding_box=box,force=force,surface=surface,
 get_inventory=function(id)if id==3 then return input end end}
local pair={station={valid=true,unit_number=1,name="planetary-magos-cogitator-station",position={x=0,y=0},force=force,surface=surface},
 priest={valid=true,unit_number=2,name="tech-priest",position={x=0,y=0},force=force,surface=surface,commandable={valid=true,set_command=function()end}},radius=40}
storage={tech_priests={pairs_by_station={[1]=pair}}}
local custody={item="iron-plate",count=5,kind="supply"}
pair.machine_logistics_0528={phase="move-to-machine",action="supply-ingredient",machine=machine,item="iron-plate",custody=custody}
pair.machine_logistics_custody_0528=custody
local Movement=require("scripts.core.movement_controller")
TECH_PRIESTS_MOVEMENT_CONTROLLER_0418=Movement
local goal
tech_priests_request_movement_0418=function(p,pos,reason,options)
 goal=pos;return Movement.request(p,pos,reason,options)
end
local M=require("scripts.core.logistics_machine_fulfillment_0528")
local r=M.service_pair(pair,"physical-test")
assert(goal and inserted==0 and r.waiting==1,"machine contact was unreachable or inserted remotely")
assert(surface.can_place_entity{position=goal},"machine goal was inside its solid footprint")
assert((goal.x-10)^2+goal.y^2>2.56,"test did not exceed obsolete center-based reach")
pair.priest.position={x=goal.x,y=goal.y};game.tick=1005
M.service_pair(pair,"physical-arrival")
assert(inserted==5 and custody.count==0 and not pair.machine_logistics_custody_0528,
 "physical assembler edge contact did not deliver exact carried ingredients")
print("PASS real movement to large assembler footprint and exact physical recipe delivery")
