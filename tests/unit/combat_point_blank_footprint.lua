package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=1000};storage={tech_priests={}};defines={command={stop=1,go_to_location=2},distraction={none=0,by_enemy=1}}
TechPriestsPairBucketRegistry0600={force_bucket=function()end}
local Safety=require("scripts.core.combat_safety");Safety.install()
local force={index=1};local surface={index=1}
local priest={valid=true,unit_number=2,name="tech-priest",force=force,surface=surface,position={x=7,y=0},commandable={valid=true,set_command=function()end}}
local target={valid=true,name="medium-worm-turret",unit_number=3,position={x=10,y=0},bounding_box={left_top={x=8.5,y=-1.5},right_bottom={x=11.5,y=1.5}}}
local pair={station={valid=true,unit_number=1,position={x=0,y=0},force=force,surface=surface},priest=priest,radius=40}
tech_priests_0312_valid_pair=function()return true end
tech_priests_0423_point_blank_laser_range=function()return 1.5 end
TECH_PRIESTS_0312_FALLBACK_LASER_TICKS=30;TECH_PRIESTS_0312_MINING_LASER_DAMAGE=5
local shots,moves=0,0
tech_priests_0312_fire_laser=function()shots=shots+1 end
local Movement=require("scripts.core.movement_controller")
tech_priests_request_movement_0418=function(p,pos,reason,opts)
 moves=moves+1;assert(pos.x==8.5 and opts.owner=="fallback-combat-laser-0423")
 return Movement.request(p,pos,reason,opts)
end
-- Execute the actual canonical fallback leaf, with its native dependencies.
local f=assert(io.open("tech-priests_src/scripts/generated/control_legacy_part_021.lua","r"))
local source=f:read("*a");f:close()
local start=assert(source:find("function tech_priests_0312_fallback_combat_laser",1,true))
local finish=assert(source:find("TECH_PRIESTS_0312_PRE_PRIME_PROXY_ATTACK",start,true))
assert(load(source:sub(start,finish-1)))()
assert(tech_priests_0312_fallback_combat_laser(pair,target,"test"))
assert(shots==1 and moves==0,"solid worm center prevented a real point-blank beam")
priest.position={x=6,y=0};game.tick=1040
tech_priests_0312_fallback_combat_laser(pair,target,"test-walk")
assert(shots==1 and moves==1,"out-of-reach fallback fired remotely")
Movement.stop(pair,"test-handoff")
assert(Movement.combat_intent(pair,target,"test-wrapper",{owner="fallback-combat-laser-0423",fire_range=1.5,radius=.975,priority=92}))
assert(pair.movement_request_0418.x==8.5 and pair.movement_request_0418.owner=="fallback-combat-laser-0423",
 "combat wrapper replaced the authorized footprint goal with blocked center")
tech_priests_stop_movement_0418=Movement.stop
target.position={x=80,y=0};target.bounding_box={left_top={x=78.5,y=-1.5},right_bottom={x=81.5,y=1.5}}
pair.combat_target=target;pair.dispatcher_combat_target_0510=target;pair.target=target;pair.mode="moving-to-laser-fallback"
assert(not tech_priests_0312_fallback_combat_laser(pair,target,"unreachable-ambient-target")
 and not pair.combat_target and not pair.dispatcher_combat_target_0510 and not pair.movement_request_0418
 and pair.mode=="idle"and shots==1,
 "distant ambient target pinned the unarmed station outside its physical pursuit envelope")
pair.order_queue_0469={current={kind="combat",target=target,status="active"}}
tech_priests_request_movement_0418=function()moves=moves+1;return false end
assert(tech_priests_0312_fallback_combat_laser(pair,target,"explicit-order")and pair.combat_target==target,
 "ambient pursuit deferral silently cancelled an explicit combat order")
print("PASS point-blank footprint range, bounded ambient pursuit and explicit combat-order preservation")
