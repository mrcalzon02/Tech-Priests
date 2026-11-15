package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=1000};storage={tech_priests={pairs_by_station={}}};prototypes={item={wood={}}}
local force={index=1};local surface={index=1,can_place_entity=function()return true end}
local priest={valid=true,name="test-priest",unit_number=2,position={x=8,y=0},force=force,surface=surface}
local station={valid=true,name="test-station",unit_number=1,position={x=0,y=0},force=force,surface=surface}
local quantity=4
local bag={valid=true,get_item_count=function()return quantity end,
 get_contents=function()return{{name="wood",count=quantity}}end,
 is_empty=function()return quantity==0 end}
bag.remove=function(s)local n=math.min(quantity,s.count);quantity=quantity-n;return n end
bag.destroy=function()assert(quantity==0);bag.valid=false end
local pair={station=station,priest=priest,direct_acquisition_custody_0513={item="wood",count=4,
 native_inventory=bag,parent_key="direct_acquisition_task_0336",required_units=1}}
local moves={};local deposited,stops=0,0
TECH_PRIESTS_MOVEMENT_CONTROLLER_0418={request_status=function(p)
 return{active=p.movement_request_0418~=nil,owner=p.movement_request_0418 and p.movement_request_0418.owner}end,
 stop=function(p)stops=stops+1;p.movement_request_0418=nil;return true end}
tech_priests_request_movement_0418=function(p,pos,_,opts)moves[#moves+1]=pos;p.movement_request_0418={owner=opts.owner};return true end
tech_priests_stop_movement_0418=function()return true end
tech_priests_safe_deposit_item=function(_,n,c)assert(n=="wood");deposited=deposited+c;return true,"deposited",c end
local Direct=require("scripts.core.direct_acquisition_executor_0513")
Direct.service_pair(pair);local first=moves[#moves]
priest.position={x=7,y=.5};game.tick=1061;Direct.service_pair(pair)
assert(moves[#moves]==first and deposited==0 and quantity==4,"real approach progress lost stable contact/cargo")
priest.position={x=7,y=-.5};game.tick=1242;Direct.service_pair(pair)
local alternate=moves[#moves]
assert(alternate~=first and(alternate.x~=first.x or alternate.y~=first.y)
 and alternate.x^2+alternate.y^2<=4 and deposited==0 and quantity==4 and bag.valid,
 "lateral stall failed to rotate a legal return contact or remotely deposited cargo")
priest.position=alternate;game.tick=1247;Direct.service_pair(pair)
assert(deposited==4 and quantity==0 and not bag.valid and not pair.direct_acquisition_custody_0513,
 "real arrival failed exact native cargo deposit")
assert(stops==1 and not pair.movement_request_0418,"completed custody retained a stale high-priority return lease")
-- A higher priority route may take ownership before actual deposit. Terminal
-- cleanup must leave that foreign controller request intact.
quantity=4;bag.valid=true;pair.direct_acquisition_custody_0513={item="wood",count=4,native_inventory=bag}
pair.movement_request_0418={owner="combat-safety"};Direct.service_pair(pair)
assert(stops==1 and pair.movement_request_0418.owner=="combat-safety"and deposited==8)
print("PASS directed return progress, stalled contact rotation and exact native wood custody")
