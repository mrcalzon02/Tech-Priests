package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=1000};defines={inventory={chest=1,fuel=2,crafter_input=3,crafter_output=4}}
storage={tech_priests={pairs_by_station={}}}
local function inventory(items)
 local inv={valid=true,items=items}
 inv.get_item_count=function(name)
  if name then return items[name]or 0 end
  local n=0;for _,v in pairs(items)do n=n+v end;return n
 end
 inv.get_contents=function()return items end
 inv.remove=function(s)local n=math.min(items[s.name]or 0,s.count);items[s.name]=(items[s.name]or 0)-n;return n end
 inv.insert=function(s)items[s.name]=(items[s.name]or 0)+s.count;return s.count end
 inv.can_insert=function()return true end
 return inv
end
local stock=inventory({["automation-science-pack"]=1,["inserter"]=2,["transport-belt"]=2})
local input=inventory({["copper-plate"]=1,["iron-gear-wheel"]=1})
local output=inventory({})
local force={index=1,recipes={}}
local surface={index=1,valid=true,name="nauvis"}
local selected="automation-science-pack"
local recipes={
 ["automation-science-pack"]={name="automation-science-pack",category="crafting",ingredients={{name="copper-plate",amount=1},{name="iron-gear-wheel",amount=1}},products={{name="automation-science-pack",amount=1,independent_probability=1},{name="mechanical-detritus",amount=1,independent_probability=0}}},
 ["logistic-science-pack"]={name="logistic-science-pack",category="crafting",ingredients={{name="inserter",amount=1},{name="transport-belt",amount=1}},products={{name="logistic-science-pack",amount=1}}}}
prototypes={recipe=recipes,item={}}
for name,r in pairs(recipes)do force.recipes[name]={enabled=true,ingredients=r.ingredients};prototypes.item[name]={}end
for _,name in ipairs({"copper-plate","iron-gear-wheel","inserter","transport-belt","mechanical-detritus"})do prototypes.item[name]={}end
local machine={valid=true,unit_number=3,name="assembling-machine-1",type="assembling-machine",position={x=3,y=0},force=force,surface=surface,
 prototype={crafting_categories={crafting=true}},products_finished=1,crafting_progress=.5,
 get_inventory=function(id)if id==3 then return input elseif id==4 then return output end end,
 get_item_count=function()return input.get_item_count()+output.get_item_count()end,
 get_recipe=function()return recipes[selected]end,set_recipe=function(name)selected=name;return {}end}
surface.find_entities_filtered=function()return {machine}end
local pair={station={valid=true,unit_number=1,position={x=0,y=0},force=force,surface=surface,get_inventory=function(id)if id==1 then return stock end end},
 priest={valid=true,unit_number=2,position={x=0,y=0},force=force,surface=surface},radius=40,
 emergency_craft={output_item="logistic-science-pack",strict_recipe_0647=true,facility_only_0647=true}}
storage.tech_priests.pairs_by_station[1]=pair
tech_priests_safe_deposit_item=function(_,name,n)stock.insert{name=name,count=n};return true,"deposited",n end
local F=require("scripts.core.emergency_facility_doctrine")
assert(F.tag_built_entity(pair,machine,"original-0338-bootstrap-workshop"))
F.service_pair(pair)
assert(selected=="automation-science-pack"and machine.crafting_progress==.5,"active native cycle was interrupted")
assert(input.items["copper-plate"]==0 and stock.items["copper-plate"]==1,"unconsumed queue failed to drain exactly")
assert(pair.emergency_facility_workshop_service_phase_0357.phase=="incumbent-finishing-final-native-cycle","zero probability native byproduct blocked handoff")
machine.crafting_progress=0
F.service_pair(pair)
assert(input.items["copper-plate"]==0 and input.items["iron-gear-wheel"]==0,"idle incumbent inputs retained")
assert(stock.items["copper-plate"]==1 and stock.items["iron-gear-wheel"]==1,"real returned ingredients lost or duplicated")
F.service_pair(pair)
assert(selected=="logistic-science-pack","completed incumbent never released workshop")
assert(input.items.inserter==1 and input.items["transport-belt"]==1,"new recipe did not receive exact native inputs")
print("PASS completed native workshop batch hands off recipe without waiting for zero probability byproducts or deleting inputs")
