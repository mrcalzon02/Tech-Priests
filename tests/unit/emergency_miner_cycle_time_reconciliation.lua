-- Lua 5.2 data-final-fixes regression: an emergency miner is a slow
-- productive bridge, not a 480-second-per-ore stalled bootstrap device.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
local expected={
  wood=18,stone=18,["iron-ore"]=30,["copper-ore"]=30,
  coal=24,["uranium-ore"]=120
}
data={raw={["assembling-machine"]={
  ["tech-priests-emergency-miner"]={name="tech-priests-emergency-miner",
    crafting_speed=1,energy_source={type="burner"}}
},recipe={}}}
for item in pairs(expected) do
  data.raw.recipe["tech-priests-emergency-mine-"..item]={
    energy_required=480,allow_productivity=true,allow_decomposition=true}
end
data.raw.recipe["tech-priests-emergency-mine-modded-rare"]={
  energy_required=1200,allow_productivity=true}
require("prototypes.emergency_miner_no_fuel_0641")
local miner=data.raw["assembling-machine"]["tech-priests-emergency-miner"]
assert(miner.energy_source.type=="void" and miner.crafting_speed==1,
  "bootstrap micro-miner must operate as a real low-capacity recipe machine")
for item,duration in pairs(expected) do
  local recipe=data.raw.recipe["tech-priests-emergency-mine-"..item]
  assert(recipe.energy_required==duration,
    "incorrect physical emergency mining seconds for "..item..": "..tostring(recipe.energy_required))
  assert(recipe.allow_productivity==false and recipe.allow_decomposition==false,
    "emergency mining must not gain free productivity or decomposition")
end
assert(data.raw.recipe["tech-priests-emergency-mine-modded-rare"].energy_required==1200,
  "higher-tier modded resources lost their deliberately slow rate")
print("[emergency-miner-cycle-regression] PASS ore_seconds=30 coal_seconds=24 scenarios=7")
