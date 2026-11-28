-- Real native recipes in dedicated categories. Keep old hidden prototypes
-- registered only so Factorio can deserialize old saves before migration.
local contract=require("hydrogen.native-contract")
local c=require("hydrogen.config")
local M={}
function M.register()
 local tech=assert(data.raw.technology[contract.technology])
 local recipes=data.raw.recipe
 local machines=data.raw["assembling-machine"]
 local created={}
 for i,suffix in ipairs(contract.suffixes) do
  local raw,formed=c.stages[i].name,c.formed_stages[i].name
  local forge_id=contract.machines[5].recipes[i]
  local seal_id=contract.machines[7].recipes[i]
  created[#created+1]={type="recipe",name=forge_id,categories={"tp-mh7-review-forging"},
   enabled=false,hidden=false,energy_required=24,allow_productivity=false,auto_recycle=false,
   allow_decomposition=false,main_product=formed,localised_name={"recipe-name."..forge_id},
   localised_description={"recipe-description."..forge_id},
   ingredients={{type="item",name=raw,amount=1}},
   results={{type="item",name=formed,amount=1,always_fresh=false,reset_freshness_on_craft=false}},
   raise_on_crafted=true,allow_inserter_overload=false}
  created[#created+1]={type="recipe",name=seal_id,categories={"tp-mh7-review-assembly"},
   enabled=false,hidden=false,energy_required=16/3,allow_productivity=false,auto_recycle=false,
   allow_decomposition=false,main_product=c.contained,localised_name={"recipe-name."..seal_id},
   localised_description={"recipe-description."..seal_id},
   ingredients={{type="item",name=formed,amount=1},{type="item",name=c.shell,amount=1,spoil_weight=0}},
   results={{type="item",name=c.contained,amount=1}},
   allow_inserter_overload=false}
 end
 data:extend(created)
 local unlock={}
 for _,effect in ipairs(tech.effects) do if effect.type=="unlock-recipe" then unlock[effect.recipe]=true end end
 for _,m in ipairs(contract.machines) do
  local machine=assert(machines[m.name])
  machine.fixed_recipe=nil
  machine.show_recipe_icon=true
  machine.show_recipe_icon_on_map=true
  machine.localised_name={"entity-name."..m.name}
  for _,id in ipairs(m.recipes) do
   local recipe=assert(recipes[id])
   recipe.hidden=false;recipe.hidden_in_factoriopedia=false;recipe.enabled=false
   recipe.localised_name={"recipe-name."..id}
   recipe.always_show_made_in=true
   recipe.allow_productivity=false
   if id=="tp-mh7-review-metallize" then recipe.raise_on_crafted=true end
   if not unlock[id] then tech.effects[#tech.effects+1]={type="unlock-recipe",recipe=id};unlock[id]=true end
  end
 end
 for id,recipe in pairs(recipes) do
  if contract.legacy_recipe(id) then
   recipe.hidden=true;recipe.hidden_in_factoriopedia=true;recipe.enabled=false
   recipe.auto_recycle=false
  end
 end
 -- No legacy control recipe is ever researched or selected by a new machine.
 for i=#tech.effects,1,-1 do
  local effect=tech.effects[i]
  if effect.type=="unlock-recipe" and contract.legacy_recipe(effect.recipe) then table.remove(tech.effects,i) end
 end
 machines[contract.machines[5].name].localised_description={"entity-description.tp-mh7-review-forge-native"}
 machines[contract.machines[7].name].localised_description={"entity-description.tp-mh7-canister-assembler-native"}
end
return M
