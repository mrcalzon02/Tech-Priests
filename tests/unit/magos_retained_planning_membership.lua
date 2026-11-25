-- Exercise the installed ratio graph and resource-expansion service, not a
-- replacement selector. Count immutable metadata walks separately from live
-- enablement/ingredient checks and real discovery/mission decisions.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
local walks={recipe=0,force=0,entity=0}
local function counted(values,kind)
  local names={}
  for name in pairs(values)do names[#names+1]=name end
  table.sort(names)
  return setmetatable(values,{__pairs=function()
    walks[kind]=walks[kind]+1
    local i=0
    return function()
      i=i+1;local name=names[i]
      if name then return name,values[name]end
    end
  end})
end
local function recipe(name,product,ingredients)
  return {name=name,object_name="LuaRecipe",enabled=true,
    category="crafting",energy=1,products={product},
    ingredients=ingredients or {}}
end
local recipes={}
recipes.widget=recipe("widget",{name="widget",amount=1},
  {{name="ore",amount=7}})
recipes.widget.enabled=false
for _,name in ipairs({"a-producer","z-producer"})do
  recipes[name]=recipe(name,{name="widget",amount=2,
    independent_probability=0.5},{{name="plate",amount=2},
    {name="crude-oil",type="fluid",amount=3}})
end
recipes.plate=recipe("plate",{name="plate",amount=1},
  {{name="ore",amount=1}})
recipes["zero-yield"]=recipe("zero-yield",{name="widget",
  amount=20,independent_probability=0},{{name="ore",amount=1}})
recipes["fluid-only"]=recipe("fluid-only",{name="widget",
  type="fluid",amount=20},{{name="ore",amount=1}})
recipes.hidden=recipe("hidden",{name="widget",amount=20})
recipes.hidden.hidden=true
for i=1,1000 do
  recipes["unrelated-"..i]=recipe("unrelated-"..i,
    {name="unrelated-product-"..i,amount=1})
end
local live={}
for name,value in pairs(recipes)do live[name]=value end
recipes=counted(recipes,"recipe")
live=counted(live,"force")
local entities={
  ["ore-node"]={type="resource",mineable_properties={products={
    {name="ore",type="item",amount=1},
    {name="ore",type="item",amount=1}}}},
  ["oil-well"]={type="resource",mineable_properties={products={
    {name="crude-oil",type="fluid",amount=10}}}},
  ["item-only-node"]={type="resource",mineable_properties={products={
    {name="same-name",type="item",amount=1}}}},
}
for i=1,1000 do entities["unrelated-entity-"..i]={type="simple-entity"}end
entities=counted(entities,"entity")
tech_priests_prototype_table_0440=function(kind)
  return kind=="recipe" and recipes or kind=="entity" and entities or {}
end
tech_priests_get_entity_prototype_0440=function(name)return entities[name]end
tech_priests_get_item_prototype_0440=function(name)return {name=name}end
tech_priests_0255_current_planning_item=function()return "widget"end
tech_priests_0255_pair_is_magos_planner=function()return true end
local force={valid=true,index=1,recipes=live}
local surface={index=1,find_entities_filtered=function()
  error("local sufficient supply must not start a world search")
end}
local pair={station={valid=true,unit_number=7,force=force,
  surface=surface,position={x=0,y=0}},priest={valid=true}}
game={tick=0}
local ratio_file=os.getenv("TP_RATIO_PLANNING_FILE")
assert(loadfile(ratio_file or "tech-priests_src/scripts/magos_ratio_planning.lua"))()
local plan=tech_priests_0257_build_ratio_plan(pair,{})
assert(plan.graph_complete_1189 and plan.recipes["a-producer"]
  and not plan.recipes["z-producer"] and not plan.recipes.widget
  and not plan.recipes["zero-yield"] and not plan.recipes["fluid-only"]
  and not plan.recipes.hidden and plan.raw_items.ore==0.5
  and plan.raw_fluids_1191["crude-oil"]==0.75,
  "typed yield, hidden/locked selection, deterministic tie or material graph changed")
for i=1,100 do tech_priests_0257_build_ratio_plan(pair,{})end
assert(walks.recipe==0 and walks.force==1 and walks.entity==1,
  "ratio questions repeatedly enumerated immutable recipe/resource membership")
local Policy=require("scripts.core.planning_constraints_0646")
local ores=Policy.resource_names_for_product("ore")
assert(#ores==1 and ores[1]=="ore-node"
  and ores==Policy.resource_names_for_product("ore")
  and #Policy.resource_names_for_product("same-name","fluid")==0
  and #Policy.resource_names_for_product("same-name","item")==1,
  "resource membership order, deduplication or product kind changed")
live["a-producer"].enabled=false
plan=tech_priests_0257_build_ratio_plan(pair,{})
assert(plan.recipes["z-producer"],"same-tick recipe disablement was cached")
live.widget.enabled=true
plan=tech_priests_0257_build_ratio_plan(pair,{})
assert(plan.recipes.widget and plan.raw_items.ore==1.75,
  "same-tick enablement or exact-name scoring was lost")
live.widget.ingredients[1].amount=9
assert(tech_priests_0257_build_ratio_plan(pair,{}).raw_items.ore==2.25,
  "recipe ingredients were replaced with a cached production plan")
live.widget.enabled=false;live["z-producer"].enabled=false
plan=tech_priests_0257_build_ratio_plan(pair,{})
assert(not plan.graph_complete_1189
  and plan.unresolved_reasons_1189.widget=="recipe-locked-for-force",
  "disabled, zero-yield, hidden or wrong-kind alternatives fabricated availability")
live["a-producer"].enabled=true
local supply_calls=0
local chain,chain_calls,courier_calls,drill_calls=nil,0,0,0
package.loaded["scripts.core.resource_station_chain_0820"]={
  status=function()return chain end,
  service_pair=function()chain_calls=chain_calls+1;return true,"progressed"end}
package.loaded["scripts.core.resource_return_courier_0837"]={
  service=function()courier_calls=courier_calls+1;return true,"delivered"end}
package.loaded["scripts.core.remote_machine_drill_1011"]={
  service_pair=function()drill_calls=drill_calls+1;return false,"waiting"end}
package.loaded["scripts.core.strategic_resource_campaign"]={interval=300,
  local_supply=function(_,resources,need)
    assert(resources==Policy.resource_names_for_product(need),
      "expansion rebuilt its own resource-product membership")
    supply_calls=supply_calls+1
    return {phase="sufficient-local-resource"}
  end}
TECH_PRIESTS_STATION_EXPANSION_0256={request_station_expansion=function()end}
local radius_reads=0
refresh_pair_radius=function()
  radius_reads=radius_reads+1;return 30
end
dofile("tech-priests_src/scripts/resource_expansion.lua")
for i=1,20 do
  game.tick=i*2000
  assert(tech_priests_0259_resource_expansion_service(pair)==false)
end
assert(supply_calls==40 and radius_reads==20
  and walks.recipe==0 and walks.force==1 and walks.entity==1,
  "resource-expansion passes repeated metadata walks or radius reads")
local before=supply_calls
chain={status="placing-station"}
assert(tech_priests_0259_resource_expansion_service(pair) and chain_calls==1,
  "active chain was blocked behind discovery cooldown")
chain={status="reached-resource",return_courier_0837={phase="first-hop-delivered"}}
assert(tech_priests_0259_resource_expansion_service(pair)
  and courier_calls==1 and drill_calls==1 and supply_calls==before,
  "counted active courier work was replaced by new discovery")
game.tick=1000000
for i=1,100 do Policy.resource_names_for_product("missing-"..i)end
assert(walks.entity==1,"missing products or elapsed time expired immutable membership")
-- Reloads rebuild deterministic metadata, without persisting cache warmth.
package.loaded["scripts.core.planning_constraints_0646"]=nil
local Reloaded=require("scripts.core.planning_constraints_0646")
assert(Reloaded.resource_names_for_product("ore")[1]=="ore-node"
  and walks.entity==2)
print("[magos-retained-planning-membership] PASS actual ratio graph and expansion; one shared recipe/resource walk; typed yield/live enablement/ingredients; active chain and custody ordering; reload")
