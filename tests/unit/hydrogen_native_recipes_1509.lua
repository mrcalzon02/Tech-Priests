package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
local C=require("hydrogen.native-contract");local cfg=require("hydrogen.config")
local recipes,machines={},{}
for i,m in ipairs(C.machines) do
 machines[m.name]={name=m.name,fixed_recipe="old",show_recipe_icon=false,crafting_categories={"unchanged"},energy_usage="50kW"}
 for _,id in ipairs(m.recipes) do if i~=5 and i~=7 then recipes[id]={name=id,hidden=true,ingredients={{name="water",amount=20}},results={{name="out",amount=20}}} end end
end
recipes["tp-mh7-review-forge-work"]={name="tp-mh7-review-forge-work",hidden=true,enabled=true}
recipes["tp-mh7-assembler-accept"]={name="tp-mh7-assembler-accept",hidden=true,enabled=true}
local effects={{type="unlock-recipe",recipe="tp-mh7-review-forge-work"}}
data={raw={recipe=recipes,["assembling-machine"]=machines,technology={[C.technology]={effects=effects}}}}
function data:extend(rows)for _,r in ipairs(rows)do self.raw[r.type][r.name]=r end end
require("hydrogen.native-recipes").register()
local unlocked={};for _,e in ipairs(effects)do unlocked[e.recipe]=true end
local count=0
for _,m in ipairs(C.machines) do
 local entity=machines[m.name]
 assert(entity.fixed_recipe==nil and entity.show_recipe_icon and entity.energy_usage=="50kW")
 for _,id in ipairs(m.recipes)do
  assert(not recipes[id].hidden and not recipes[id].enabled and unlocked[id])
  assert(not recipes[id].allow_productivity)
  count=count+1
 end
end
assert(count==13 and not unlocked["tp-mh7-review-forge-work"])
for i=1,4 do
 local f=recipes[C.machines[5].recipes[i]]
 assert(f.energy_required==24 and f.ingredients[1].name==cfg.stages[i].name and f.ingredients[1].amount==1)
 assert(f.results[1].name==cfg.formed_stages[i].name and f.results[1].amount==1 and not f.results[1].reset_freshness_on_craft and not f.results[1].always_fresh)
 local a=recipes[C.machines[7].recipes[i]]
 assert(a.energy_required==16/3 and a.ingredients[1].name==cfg.formed_stages[i].name and a.ingredients[1].amount==1)
 assert(a.ingredients[2].name==cfg.shell and a.ingredients[2].amount==1 and a.results[1].name==cfg.contained and a.results[1].amount==1)
end
assert(recipes["tp-mh7-assembler-accept"].hidden and not recipes["tp-mh7-assembler-accept"].enabled)
assert(C.private_item("tp-mh7-forge-cycle-token") and C.private_item("tp-mh7-assembler-accept-guard"))
for _,name in ipairs({cfg.stages[1].name,cfg.formed_stages[1].name,cfg.shell,cfg.contained,cfg.inert,"steel-plate"}) do
 assert(not C.private_item(name),"real stock must never be classified as an internal token: "..name)
end
print("hydrogen_native_recipes_1509 PASS: seven machines, thirteen real selectable processes, original ratios and retired clocks")
