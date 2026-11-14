package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=1000};defines={inventory={chest=1,fuel=2,crafter_input=3,crafter_output=4}}
storage={tech_priests={pairs_by_station={}}}
local force={index=1,recipes={["iron-gear-wheel"]={enabled=true}}}
local surface={index=1,name="nauvis",valid=true};local stock,loaded=2,0;local selected
local source={valid=true,get_item_count=function(item)return item=="iron-plate"and stock or 0 end,
 remove=function(spec)local n=math.min(stock,spec.count);stock=stock-n;return n end}
local input={valid=true,get_item_count=function()return loaded end,
 can_insert=function()return true end,insert=function(spec)loaded=loaded+spec.count;return spec.count end}
local output={valid=true,get_item_count=function()return 0 end,get_contents=function()return {}end}
local assembler={valid=true,unit_number=3,name="assembling-machine-1",type="assembling-machine",
 position={x=3,y=0},force=force,surface=surface,prototype={crafting_categories={crafting=true}},
 get_inventory=function(id)if id==3 then return input elseif id==4 then return output end end,
 get_item_count=function()return loaded end,
 get_recipe=function()return selected and prototypes.recipe[selected]end,
 set_recipe=function(recipe)selected=recipe;return {}end}
surface.find_entities_filtered=function()return {assembler}end
local pair={station={valid=true,unit_number=1,position={x=0,y=0},force=force,surface=surface,
 get_inventory=function(id)if id==1 then return source end end},
 priest={valid=true,unit_number=2,position={x=0,y=0},force=force,surface=surface},radius=40,
 emergency_craft={output_item="iron-gear-wheel",strict_recipe_0647=true}}
storage.tech_priests.pairs_by_station[1]=pair
prototypes={item={["iron-plate"]={},["iron-gear-wheel"]={}},recipe={
 ["iron-gear-wheel"]={name="iron-gear-wheel",category="crafting",
 ingredients={{name="iron-plate",type="item",amount=2}},products={{name="iron-gear-wheel",type="item",amount=1}}}}}
force.recipes["iron-gear-wheel"].ingredients=prototypes.recipe["iron-gear-wheel"].ingredients
local F=require("scripts.core.emergency_facility_doctrine")
F.service_pair(pair)
assert(selected==nil,"unclaimed player assembler was repurposed")
assert(F.tag_built_entity(pair,assembler,"original-0338-bootstrap-workshop"))
local acted,reason=F.service_pair(pair)
assert(acted and reason=="used-owned-facilities" and selected=="iron-gear-wheel",
 "registered standard workshop was excluded from its production owner: "..tostring(reason))
assert(stock==0 and loaded==2,"registered workshop did not receive exact physical ingredients")
print("PASS registered standard workshop production and unclaimed player assembler isolation")
