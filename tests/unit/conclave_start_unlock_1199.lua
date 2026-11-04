-- 1199: the player can handcraft a physical Conclave Center before science.
-- Verify actual data-stage prototype construction without any research grants.
local previous_data, previous_util = _G.data, package.loaded.util
_G.data = {
 raw = {
  explosion = {},
  technology = {
   ["planetary-magos-cogitator-stations"]={effects={}},
   ["processing-unit"]={effects={}},
   ["production-science-pack"]={effects={}},
   ["utility-science-pack"]={effects={}},
  }
 }
}
function data:extend(prototypes)
 for _,definition in ipairs(prototypes) do
  local family=self.raw[definition.type] or {}
  assert(family[definition.name]==nil,
   "duplicate Conclave prototype: "..definition.name)
  family[definition.name]=definition
  self.raw[definition.type]=family
 end
end
package.loaded.util={by_pixel=function(x,y)return {x/32,y/32} end}
dofile("tech-priests_src/prototypes/conclave_center_0558.lua")
local name="tech-priests-conclave-center"
local recipe=data.raw.recipe and data.raw.recipe[name]
local entity=data.raw.container and data.raw.container[name]
local item=data.raw.item and data.raw.item[name]
assert(recipe and recipe.enabled==true and recipe.category=="crafting",
 "Conclave recipe must be handcraftable without research")
assert(recipe.energy_required==5,
 "Conclave Center no longer has its early crafting time")
assert(item and item.place_result==name and entity and entity.minable.result==name,
 "Conclave craft must yield its real, recoverable physical center")
local actual={}
for _,v in ipairs(recipe.ingredients or {}) do
 assert(v.type=="item" and type(v.name)=="string"
   and type(v.amount)=="number" and not actual[v.name],
   "Conclave recipe has an invalid/duplicate ingredient")
 actual[v.name]=v.amount
end
local expected={
 ["copper-cable"]=20, ["iron-gear-wheel"]=10, ["iron-plate"]=20
}
for item_name,amount in pairs(expected) do
 assert(actual[item_name]==amount,
   "Conclave missing required early vanilla ingredient "..item_name)
 actual[item_name]=nil
end
assert(next(actual)==nil,
 "Conclave recipe still requires a technology-gated/foreign ingredient")
for tech_name,tech in pairs(data.raw.technology) do
 for _,effect in ipairs(tech.effects or {}) do
  assert(not(effect.type=="unlock-recipe" and effect.recipe==name),
   "Conclave is still gated by "..tech_name)
 end
end
-- The final prototype correction phase must not re-lock the new recipe.
local file=assert(io.open("tech-priests_src/data-final-fixes.lua","r"))
local final=file:read("*a")
file:close()
assert(not final:find("conclave_recipe.enabled = false",1,true)
 and not final:find('add_unlock_to_tech("processing-unit")',1,true),
 "final-fixes has retained a conflicting Conclave technology gate")
_G.data,package.loaded.util=previous_data,previous_util
print("[conclave-start-unlock-1199] PASS default crafting, real entity, three basic ingredients, no research gates")
