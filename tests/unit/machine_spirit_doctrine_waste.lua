-- Source-level integration: real operation waste function plus deterministic fixtures.
-- Requires only the canonical core/consecration scripts; no native Factorio claim.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local Doctrine=require("scripts.core.consecration.doctrine_effects")
game={tick=400}
MINIMUM_SANCTIFICATION_EFFICIENCY=0.05
get_sanctification_ratio=function(record)
  return math.max(MINIMUM_SANCTIFICATION_EFFICIENCY,
    math.min(1,Doctrine.effective_value(record)/record.max_sanctification))
end
get_waste_chance_from_ratio=function(ratio)
  local base=0.015
  return math.min(1,base+(1-base)*(1-ratio)/(1-MINIMUM_SANCTIFICATION_EFFICIENCY))
end
get_recipe_item_output_units=function(recipe) return recipe.units end
roll_count_from_expected=function(n) return math.floor(n+0.5) end
recipe_accepts_machine_detritus_output=function(recipe) return recipe.has_detritus_slot end
add_mechanical_detritus=function(record,count,allow_spill)
  assert(allow_spill==false,"no spill by default")
  record.actual_delivered=count
end
dofile("tech-priests_src/scripts/core/consecration/effects.lua")
local function entity(modules)
  return {valid=true,get_module_inventory=function()
    return {get_contents=function() return modules or {} end}
  end}
end
local recipe={units=10,has_detritus_slot=true}
local clean={entity=entity(),max_sanctification=100,sanctification=5}
create_operation_waste(clean,recipe)
assert(clean.last_detritus_waste_chance_0417==1,"baseline chance not saturated at floor")
assert(clean.last_detritus_expected_0417==10,"baseline changed")
assert(clean.actual_delivered==10,"baseline physical output mismatch")
local profane={entity=entity({{name="tech-priests-chaos-module-2",count=1}}),max_sanctification=100,sanctification=5}
create_operation_waste(profane,recipe)
assert(profane.last_detritus_waste_chance_0417==1,"profane floor chance should saturate")
assert(math.abs(profane.last_detritus_expected_0417-13.8)<0.0001,"profane floor yield absent")
assert(profane.actual_delivered==14,"profane output did not reach custody")
local blocked={entity=entity({{name="tech-priests-chaos-module-2",count=1}}),max_sanctification=100,sanctification=5}
create_operation_waste(blocked,{units=10,has_detritus_slot=false})
assert(blocked.actual_delivered==nil,"unsupported recipe gained detritus")
assert(blocked.last_detritus_blocked_reason_0417=="recipe-lacks-mechanical-detritus-output-slot",
  "missing product slot not diagnosed")
print("[machine-spirit-doctrine-waste] PASS capped chance, yield, physical output custody")
