-- Low-sanctity Chaos must improve survival without disabling genuine hazards.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local Doctrine=require("scripts.core.consecration.doctrine_effects")
local function near(actual, expected, label)
  assert(math.abs(actual-expected)<0.000001, label..": "..tostring(actual).." != "..tostring(expected))
end
local function record(modules, stored)
  return {
    entity={valid=true,get_module_inventory=function()
      return {get_contents=function() return modules or {} end}
    end},
    sanctification=stored,max_sanctification=100
  }
end
local baseline=record({},40)
local chaos=record({{name="tech-priests-chaos-module-2",count=1,quality="normal"}},40)
local order=record({{name="tech-priests-order-module-2",count=1,quality="normal"}},40)
local mixed=record({{name="tech-priests-order-module-1",count=1,quality="normal"},
                    {name="tech-priests-chaos-module-2",count=1,quality="normal"}},40)
local high_chaos=record({{name="tech-priests-chaos-module-2",count=4,quality="legendary"}},5)
game={tick=100}
-- Production remains driven by effective, not stored, sanctity.
near(Doctrine.effective_value(baseline),40,"baseline production sanctity")
near(Doctrine.effective_value(chaos),18,"Chaos extraction sanctity")
near(Doctrine.effective_value(order),60,"Order production sanctity")
near(Doctrine.effective_value(mixed),28,"mixed doctrine extraction sanctity")
near(Doctrine.detritus_quantity_multiplier(chaos,0.18),1.328,"Chaos production remains differentiated")
-- Physical hazards use stored condition (or stronger Order protection).
near(Doctrine.hazard_ratio(baseline,.05),.40,"normal hazard condition")
near(Doctrine.hazard_ratio(chaos,.05),.40,"Chaos must not invent equipment failure")
near(Doctrine.hazard_ratio(order,.05),.60,"Order can protect against wear")
near(Doctrine.hazard_ratio(mixed,.05),.40,"mixed doctrine hazard floor")
near(Doctrine.hazard_ratio(high_chaos,.05),.05,"Chaos at the real 5% floor")
near(Doctrine.hazard_ratio(nil,.05),.05,"missing record hazard floor")
near(Doctrine.hazard_ratio(baseline,2),1,"invalid floor clamps")
-- Chance protection is bounded and applies equally to fuel, control and eject.
near(Doctrine.hazard_chance(baseline,.40),.40,"ordinary fuel loss chance")
near(Doctrine.hazard_chance(chaos,.40),.30,"Chaos II fuel loss chance")
near(Doctrine.hazard_chance(chaos,.50),.375,"Chaos II control failure chance")
near(Doctrine.hazard_chance(chaos,.35),.2625,"Chaos II ejection chance")
near(Doctrine.hazard_chance(order,.40),.40,"Order no arbitrary resilience")
near(Doctrine.hazard_chance(high_chaos,1),.30,"Chaos protection capped not immune")
near(Doctrine.hazard_chance(chaos,-1),0,"negative chance clamp")
near(Doctrine.hazard_chance(chaos,2),.75,"overfull chance clamp")
-- Module removal returns both production and hazards to their original state.
chaos.entity.get_module_inventory=function() return {get_contents=function() return {} end} end
Doctrine.invalidate(chaos)
near(Doctrine.effective_value(chaos),40,"module removal restores production sanctity")
near(Doctrine.hazard_chance(chaos,.40),.40,"module removal restores baseline hazard")
assert(chaos.sanctification==40,"doctrine effects must not heal stored condition")
print("[machine-spirit-chaos-hazards] PASS physical hazard vs effective production split, capped resilience, module removal")
