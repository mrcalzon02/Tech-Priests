package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=1000};storage={tech_priests={pairs_by_station={}}}
local enemy={name="enemy",index=2};local force={name="tp-arena-1",index=1,is_enemy=function(f)return f==enemy end}
local surface={index=1}
local target={valid=true,name="biter-spawner",type="unit-spawner",unit_number=3,force=enemy,surface=surface,position={x=2,y=0}}
local pair={station={valid=true,unit_number=1,position={x=0,y=0},force=force,surface=surface},
 priest={valid=true,unit_number=2,position={x=1,y=0},force=force,surface=surface},combat_target=target,mode="combat"}
storage.tech_priests.pairs_by_station[1]=pair
TECH_PRIESTS_ACTION_STATE_ARBITER_0488={action=function()return {kind="combat",target=target}end}
local calls=0
tech_priests_0293_prime_proxy_attack=function(p,t,reason)
 assert(p==pair and t==target and reason:find("dispatcher",1,true));calls=calls+1;return true
end
local M=require("scripts.core.single_dispatcher_0510")
for i=1,20 do game.tick=1000+i*5;M.service_pair(pair,"test")end
assert(calls==20 and pair.dispatcher_0510.result=="canonical-combat-owner-serviced",
 "combat remained a compatibility leaf waiting on slow heartbeat")
pair.combat_target=nil;game.tick=1101;M.service_pair(pair,"expired-routine-target")
assert(calls==21 and pair.combat_target==target,"routine target cleanup starved a live canonical combat target")
target.force=force;game.tick=1105;M.service_pair(pair,"friendly-test")
assert(calls==21,"canonical combat dispatch admitted friendly fire")
target.force=enemy
local cargo={item="coal",count=3}
pair.energy_family_custody_0707=cargo
TechPriestsEnergyFamilyLogistics0707={service_pair=function(p)
 assert(p.energy_family_custody_0707==cargo);return {processed=1,waiting=1,detail="returning-real-coal"}
end}
game.tick=1110;M.service_pair(pair,"cargo-test")
assert(calls==21 and cargo.count==3 and pair.dispatcher_0510.result=="returning-real-coal",
 "combat abandoned the incumbent physical fuel owner")
print("PASS canonical combat cadence, friendly refusal and original physical cargo owner")
