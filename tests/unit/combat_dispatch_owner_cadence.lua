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
local deliveries,discoveries,repairs=0,0,0
local factory={station={valid=true,unit_number=123,position={x=0,y=0},force=force,surface=surface},
 priest={valid=true,unit_number=124,position={x=0,y=0},force=force,surface=surface},mode="idle"}
local machine={valid=true,unit_number=125,force=force,surface=surface,position={x=3,y=0},
 get_recipe=function()return{name="factory-test"}end}
factory.machine_logistics_candidate_0528={machine=machine,expires_tick=999999,action="supply-ingredient"}
factory.independent_emergency_operation_0184={enabled=true,magos_ratio_plan_0257={factory_component_jobs_1150={
 ["factory-test"]={configured=1,researched=true,output_deficient=true}}}}
TECH_PRIESTS_ACTION_STATE_ARBITER_0488={action=function(p)
 local order=p.order_queue_0469 and p.order_queue_0469.current
 return{kind=order and order.kind or"machine-logistics",target=machine,reason="fairness-test"}
end}
TECH_PRIESTS_ORDER_QUEUE_0469={tick_pair=function()end}
TECH_PRIESTS_MACHINE_LOGISTICS_FULFILLMENT_0528={service_pair=function()
 deliveries=deliveries+1;return{processed=1,acted=1,detail="actual-factory-delivery"}end}
TechPriestsRepairExecutor0516={discover_pair=function(p)
 discoveries=discoveries+1;p.order_queue_0469={current={kind="repair",status="active",source="repair_executor_0516"}};return true
end,service_pair=function(p)
 repairs=repairs+1;p.order_queue_0469.current=nil;return{processed=1,acted=1,detail="actual-maintenance"}
end}
game.tick=2000;M.service_pair(factory,"factory-admission")
assert(deliveries==1 and discoveries==0,"fresh repair discovery starved funded factory service")
game.tick=2100;M.service_pair(factory,"maintenance-turn")
assert(repairs==1 and discoveries==1,"factory delivery starved the next maintenance admission")
game.tick=2200;M.service_pair(factory,"next-factory-turn")
assert(deliveries==2 and discoveries==1,"completed maintenance failed to admit the waiting factory")
factory.independent_emergency_operation_0184.enabled=false
game.tick=2300;M.service_pair(factory,"default-maintenance")
assert(repairs==2 and deliveries==2,"maintenance mode inherited autonomous factory priority")
print("PASS independent factory and maintenance alternate admissions; default assistance retains maintenance")
