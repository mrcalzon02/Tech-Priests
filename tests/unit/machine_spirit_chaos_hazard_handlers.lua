-- Exercise actual consecration/effects.lua hazard entrypoints with deterministic
-- engine stubs. Source-level integration only; native Factorio proof is separate.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local Doctrine=require("scripts.core.consecration.doctrine_effects")
MINIMUM_SANCTIFICATION_EFFICIENCY=0.05
LOW_SANCTIFICATION_FUEL_LOSS_RATIO=0.45
LOW_SANCTIFICATION_FUEL_LOSS_MAX_CHANCE=0.40
LOW_SANCTIFICATION_CONTROL_MALFUNCTION_RATIO=0.45
LOW_SANCTIFICATION_CONTROL_FLOOR_RATIO=0.05
LOW_SANCTIFICATION_CONTROL_MALFUNCTION_MAX_CHANCE=0.50
LOW_SANCTIFICATION_CONTROL_MALFUNCTION_MIN_TICKS=30
LOW_SANCTIFICATION_CONTROL_MALFUNCTION_MAX_TICKS=60
LOW_SANCTIFICATION_OPERATOR_EJECT_RATIO=0.45
get_sanctification_ratio=function(rec)
  return math.max(.05,math.min(1,Doctrine.effective_value(rec)/rec.max_sanctification))
end
game={tick=250,connected_players={}}
dofile("tech-priests_src/scripts/core/consecration/effects.lua")
local saved_random=math.random
local trial=0
math.random=function(maximum)
  if maximum then return 1 end
  return trial
end
local function actor(modules)
  local stack={valid_for_read=true,name="coal",count=2}
  local fuel={stack}
  local entity={valid=true,unit_number=123,type="car",active=true,speed=1,
    get_module_inventory=function() return {get_contents=function() return modules or {} end} end,
    get_fuel_inventory=function() return fuel end}
  local player={valid=true,connected=true,vehicle=entity,driving=true}
  game.connected_players={player}
  return {entity=entity,sanctification=40,max_sanctification=100},stack,player
end
local chaos_mod={{name="tech-priests-chaos-module-2",count=1,quality="normal"}}
local baseline,baseline_fuel=actor()
local chaos,chaos_fuel=actor(chaos_mod)
-- At 40% stored sanctity, Chaos II deliberately lowers production sanctity to
-- 18%. That must not increase *physical* fuel-loss risk.
assert(Doctrine.effective_value(chaos)==18)
trial=.35
assert(maybe_delete_fuel_from_low_sanctification_burner(baseline,"physical-damage",1))
assert(baseline_fuel.count==1,"baseline fuel must debit physically")
assert(not maybe_delete_fuel_from_low_sanctification_burner(chaos,"physical-damage",1))
assert(chaos_fuel.count==2,"Chaos resilience did not protect paid fuel")
-- A fresh test actor is required: player.vehicle is identity-sensitive.
local baseline_control=actor()
local chaos_control=actor(chaos_mod)
trial=.40
game.connected_players={{valid=true,connected=true,vehicle=baseline_control.entity}}
assert(maybe_start_vehicle_control_malfunction(baseline_control,1))
assert(baseline_control.entity.active==false and baseline_control.control_malfunction_until_tick>game.tick,
  "baseline control failure did not occur")
game.connected_players={{valid=true,connected=true,vehicle=chaos_control.entity}}
assert(not maybe_start_vehicle_control_malfunction(chaos_control,1))
assert(chaos_control.entity.active==true and chaos_control.control_malfunction_until_tick==nil,
  "Chaos resilience failed on vehicle controls")
-- Operator ejection must also observe the same bounded resilience factor.
local baseline_eject,_,normal_player=actor()
local chaos_eject,_,chaos_player=actor(chaos_mod)
trial=.30
game.connected_players={normal_player}
assert(maybe_eject_player_from_low_sanctification_vehicle(baseline_eject,"physical-damage",1))
assert(normal_player.driving==false,"baseline driver was not ejected")
game.connected_players={chaos_player}
assert(not maybe_eject_player_from_low_sanctification_vehicle(chaos_eject,"physical-damage",1))
assert(chaos_player.driving==true,"Chaos resilience failed against ejection")
-- Order raises physical safety above the original hazard threshold.
local orderly,order_fuel,order_player=actor({{name="tech-priests-order-module-2",count=1}})
trial=0
game.connected_players={order_player}
assert(not maybe_delete_fuel_from_low_sanctification_burner(orderly,"physical-damage",1))
assert(not maybe_start_vehicle_control_malfunction(orderly,1))
assert(not maybe_eject_player_from_low_sanctification_vehicle(orderly,"physical-damage",1))
assert(order_fuel.count==2 and order_player.driving==true,"Order hazard threshold failed")
assert(chaos.sanctification==40,"hazard protection silently healed stored sanctity")
math.random=saved_random
print("[machine-spirit-chaos-hazard-handlers] PASS real effects entrypoints: fuel, control, operator, Order")
