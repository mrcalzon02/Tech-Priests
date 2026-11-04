-- 1191: nonstandard fluid/item coproducts, physical source
-- prerequisites and catalyst startup inventory. No materials are created.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local function recipe(name,group,products,ingredients)
 return {name=name,category=group,energy=1,
  products=products,ingredients=ingredients or {}}
end
local recipes={
 ["automation-science-pack"]=recipe("automation-science-pack",
  "crafting",{{name="automation-science-pack",amount=1}},
  {{name="iron-plate",amount=1}}),
 ["etheric-science"]=recipe("etheric-science","crafting",
  {{name="etheric-science",amount=1}},
  {{name="mystic-binder",amount=1},
   {name="ether-fume",type="fluid",amount=2},
   {name="ritual-ink",amount=1}}),
 ["dual-reactor"]=recipe("dual-reactor","chemistry",
  {{name="mystic-binder",amount=2},
   {name="ether-fume",type="fluid",amount=5}},
  {{name="petroleum-gas",type="fluid",amount=6},
   {name="iron-plate",amount=2}}),
 ["ritual-ink"]=recipe("ritual-ink","crafting",
  {{name="ritual-ink",amount=1},{name="rare-stamp",amount=1}},
  {{name="rare-stamp",amount=1},
   {name="iron-plate",amount=1}}),
 ["gas-cracking"]=recipe("gas-cracking","chemistry",
  {{name="petroleum-gas",type="fluid",amount=5}},
  {{name="crude-oil",type="fluid",amount=2},
   {name="water",type="fluid",amount=3}}),
 ["iron-plate"]=recipe("iron-plate","smelting",
  {{name="iron-plate",amount=1}},
  {{name="iron-ore",amount=1}}),
}
local items={}
for _,name in ipairs({"automation-science-pack","etheric-science",
 "mystic-binder","ritual-ink","iron-plate","iron-ore","rare-stamp"})do
 items[name]={name=name}end
local entities={
 ["assembling-machine-1"]={crafting_speed=1,
  crafting_categories={crafting=true}},
 ["chemical-plant"]={crafting_speed=1,
  crafting_categories={chemistry=true}},
 ["stone-furnace"]={crafting_speed=1},
 ["electric-mining-drill"]={mining_speed=1},
 ["small-electric-pole"]={},["lab"]={},
 ["crude-well"]={type="resource",mineable_properties={
   products={{name="crude-oil",type="fluid",amount=10}}}},
}
TECH_PRIESTS_MAGOS_STANDARD_ENTITY_GROUPS_0255={
 assemblers={"assembling-machine-1"},chemical={"chemical-plant"},
 miners={"electric-mining-drill"},smelters={"stone-furnace"},
 labs={"lab"},power={"small-electric-pole"},oil={}}
tech_priests_get_entity_prototype_0440=function(n)return entities[n]end
tech_priests_get_item_prototype_0440=function(n)return items[n]end
tech_priests_get_recipe_prototype_0440=function(n)return recipes[n]end
tech_priests_prototype_table_0440=function(kind)
 if kind=="recipe" then return recipes end
 if kind=="entity" then return entities end
 return {}
end
tech_priests_0255_current_planning_item=function()
 return "automation-science-pack"
end
tech_priests_0255_first_available_item=function(names)return names[1]end
local surface={index=1}
surface.find_entities_filtered=function()return {}end
local force={recipes={},current_research={
 name="hybrid-arcanum",research_unit_ingredients={
  {name="etheric-science",amount=1}}},
 get_item_production_statistics=function(target)
  assert(target==surface)
  return {valid=true,get_flow_count=function(args)
   return args.name=="etheric-science" and 0 or 0 end}
 end}
for name in pairs(recipes)do force.recipes[name]={enabled=true}end
local pair={station={valid=true,position={x=0,y=0},
 force=force,surface=surface},priest={valid=true}}
game={tick=6000}
defines={flow_precision_index={one_minute=4}}
dofile("tech-priests_src/scripts/magos_ratio_planning.lua")
local function near(actual,expected)
 return type(actual)=="number" and math.abs(actual-expected)<1e-10
end
local plan=tech_priests_0257_build_ratio_plan(pair,{})
assert(plan.graph_complete_1189==true
 and near(plan.recipes["dual-reactor"].crafts_per_second_1191,2.5/60)
 and plan.recipes["dual-reactor"].machines==1
 and plan.recipes["dual-reactor"].output_demands_1191
  ["fluid|ether-fume"]==10/60
 and plan.recipes["gas-cracking"]~=nil,
 "shared gas/item reactor was double-counted or upstream fluid was omitted")
assert(near(plan.factory_links["dual-reactor|fluid|petroleum-gas"]
 .rate_per_second,15/60)
 and near(plan.factory_links["gas-cracking|fluid|crude-oil"]
 .rate_per_second,6/60)
 and near(plan.factory_links["gas-cracking|fluid|water"]
 .rate_per_second,9/60)
 and near(plan.raw_fluids_1191["crude-oil"],6/60)
 and near(plan.raw_fluids_1191.water,9/60)
 and plan.fluid_sources_1191.water=="offshore-pump-required"
 and plan.fluid_sources_1191["crude-oil"]==
 "resource-extraction-required",
 "typed water/crude fluid source demand was not recursively resolved")
assert(plan.catalyst_bootstrap_1191["item|rare-stamp"]
 and plan.catalyst_bootstrap_1191["item|rare-stamp"]
    .bootstrap_required==1
 and plan.unresolved["rare-stamp"]==nil,
 "returned catalyst created a fake manufacturing cycle or lost its seed")
local full,why,audit=tech_priests_0257_pick_ratio_need(pair,{})
assert(audit and audit.factory_component_blocker_1150
 and audit.factory_component_blocker_1150.phase==
 "fluid-transport-unverified-1191"
 and audit.factory_component_next_1150==nil,
 "unverified physical fluid transport was treated as an actionable builder")
-- Modded gas with no recognized raw fluid or unlocked upstream recipe
-- must be unresolved; never pretend an oil-pump is sufficient.
recipes["gas-cracking"].ingredients[1].name="unknown-exotic-liquid"
local missing=tech_priests_0257_build_ratio_plan(pair,{})
assert(not missing.graph_complete_1189
 and missing.unresolved["fluid|unknown-exotic-liquid"]
 and missing.unresolved_reasons_1189["fluid|unknown-exotic-liquid"]==
 "no-known-positive-yield-recipe",
 "unknown modded liquid was accepted without an extraction/recipe source")
print("[magos-modded-fluid-coproduct-1191] PASS shared outputs, fluid upstream graph, raw source requirements, one-time catalyst stock and physical fluid transport blocker")
