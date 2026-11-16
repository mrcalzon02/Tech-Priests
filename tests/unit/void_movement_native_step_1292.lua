package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=100};storage={tech_priests={pairs_by_station={}}};defines={command={stop=1}}
local surface={index=1};local force={index=1};local calls=0
local priest={valid=true,name="void-tech-priest",unit_number=2,surface=surface,force=force,position={x=5.5,y=-.5}}
priest.teleport=function(pos,destination,raise,snap)
 calls=calls+1
 assert(destination==nil and raise==false and snap==false,"same-surface fractional Void move used native surface/grid defaults")
 priest.position={x=pos.x,y=pos.y};return true
end
local pair={station={valid=true,name="void-cogitator-station",unit_number=1,force=force,surface=surface},priest=priest}
storage.tech_priests.pairs_by_station[1]=pair
local M=require("scripts.core.void_movement_authority_0630")
assert(M.request(pair,{x=4.7,y=-.5},"physical-hub-contact",{owner="construction-planner-0338",priority=968,radius=.15}))
M.service(nil,1)
assert(calls==1 and priest.position.x<5.5 and priest.position.x>4.7,"native sub-tile step made no physical progress")
for _=1,8 do game.tick=game.tick+5;M.service(nil,1)end
assert(pair.void_movement_status_0630=="arrived"and not pair.void_movement_request_0630)
local before=calls
assert(M.request(pair,{x=3,y=-.5},"same-surface-only",{owner="construction-planner-0338",priority=968}))
priest.surface={index=2};M.service(nil,1)
assert(calls==before and pair.void_movement_status_0630=="surface-changed","Void backend crossed a surface boundary")
print("PASS native unsnapped current-surface Void steps, truthful arrival and surface-change refusal")
