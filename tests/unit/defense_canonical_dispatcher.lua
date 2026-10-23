-- Canonical per-pair dispatcher must reach the existing perimeter executor.
-- No independent tick owner, synthetic attack, or free defensive inventory.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
game={tick=108100}
local pair={
  station={valid=true,unit_number=104},
  priest={valid=true,unit_number=105},
  radius=28,
  defense_perimeter_0259={threats={{
    position={x=25,y=0},reason="persistent-hostile-incident"}}}
}
storage={tech_priests={pairs_by_station={[104]=pair}}}
local calls=0
local duty="start"
_G.TechPriestsDefensePerimeter0259={
  has_pending=function(p)
    return p.defense_task_0259~=nil
      or #(p.defense_perimeter_0259.threats or {})>0
  end,
  service_pair=function(p)
    calls=calls+1
    if p.machine_logistics_custody_0528 then
      return {processed=1,waiting=1,detail="defense-awaits-physical-custody"}
    end
    if duty=="start" then
      p.defense_task_0259={type="build-turret",position={x=25,y=0}}
      p.defense_perimeter_0259.threats={}
      return {processed=1,acted=1,detail="defense-perimeter-work-started"}
    end
    if duty=="waiting" then
      return {processed=1,waiting=1,detail="defense-task-repath"}
    end
    return {processed=1,acted=1,detail="defense-task-finished"}
  end,
}
local dispatcher=require("scripts.core.single_dispatcher_0510")
local result=dispatcher.service_pair(pair,"combat-test")
assert(result.acted==1 and calls==1
  and pair.defense_task_0259.type=="build-turret"
  and pair.canonical_action_0744.family=="defense"
  and pair.canonical_action_0744.owner=="single_dispatcher_0510",
  "canonical dispatcher did not take ownership of urgent physical defense")
game.tick=game.tick+5
duty="waiting"
result=dispatcher.service_pair(pair,"combat-test")
assert(result.waiting==1 and calls==2
  and pair.canonical_action_0744.family=="defense"
  and pair.canonical_action_0744.status=="waiting",
  "in-progress defense lost its canonical owner")
pair.defense_task_0259=nil
pair.defense_perimeter_0259.threats={{position={x=25,y=0}}}
pair.machine_logistics_custody_0528=true
game.tick=game.tick+5
result=dispatcher.service_pair(pair,"combat-test")
assert(calls==3 and (result.acted or 0)==0
  and pair.canonical_action_0744.family~="defense"
  and #(pair.defense_perimeter_0259.threats)==1,
  "defense preempted physical logistics ownership")
pair.machine_logistics_custody_0528=nil
duty="start"
game.tick=game.tick+5
result=dispatcher.service_pair(pair,"combat-test")
assert(result.acted==1 and calls==4
  and pair.defense_task_0259.type=="build-turret",
  "unblocked defense failed to resume at its retained waypoint")
-- A new industrial assignment must not seize the priest before the
-- already-pending defensive emergency gets to start. This is distinct from
-- protecting custody an existing industrial task has actually acquired.
pair.defense_task_0259=nil
pair.defense_perimeter_0259.threats={{position={x=25,y=0}}}
local orders_assigned=0
_G.TECH_PRIESTS_ORDER_QUEUE_0469={
  tick_pair=function(p)
    orders_assigned=orders_assigned+1
    p.machine_logistics_custody_0528={item="iron-plate",count=1}
    return true
  end,
}
game.tick=game.tick+5
local urgent=dispatcher.service_pair(pair,"enemy-incident")
assert(urgent.acted==1 and orders_assigned==0
  and pair.defense_task_0259.type=="build-turret"
  and pair.machine_logistics_custody_0528==nil,
  "routine order assigned fresh custody before hostile defense started")
_G.TECH_PRIESTS_ORDER_QUEUE_0469=nil
print("[defense-canonical-dispatcher] PASS owned emergency defense, custody yield and resumption")
