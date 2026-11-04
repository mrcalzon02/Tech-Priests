-- 1189: Tech Priests must derive the science bill from Factorio's live
-- technology, even when pack names omit "science", and must never choose
-- unavailable recipes, assume 100% random yield or erase dependency cycles.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local function recipe(name,category,time,products,ingredients)
 return {name=name,category=category,energy=time,
  products=products,ingredients=ingredients or {}}
end
local recipes={
 ["automation-science-pack"]=recipe("automation-science-pack",
  "crafting",5,{{name="automation-science-pack",amount=1}},
  {{name="iron-gear-wheel",amount=1}}),
 ["arcane-knowledge"]=recipe("arcane-knowledge","crafting",2,
  {{name="arcane-knowledge",amount=2}},
  {{name="myetheric-resin",amount=3},{name="iron-plate",amount=1}}),
 ["myetheric-resin"]=recipe("myetheric-resin","crafting",1,
  {{name="myetheric-resin",amount=1}},
  {{name="iron-plate",amount=100}}),
 ["resin-distillation"]=recipe("resin-distillation","crafting",1,
  {{name="myetheric-resin",amount_min=4,amount_max=4,
    probability=0.5}},
  {{name="iron-plate",amount=2}}),
 ["resin-empty-chemical"]=recipe("resin-empty-chemical","crafting",1,
  {{name="myetheric-resin",amount=20,probability=0}},
  {{name="iron-plate",amount=1}}),
 ["iron-plate"]=recipe("iron-plate","smelting",3.2,
  {{name="iron-plate",amount=1}},
  {{name="iron-ore",amount=1}}),
 ["iron-gear-wheel"]=recipe("iron-gear-wheel","crafting",0.5,
  {{name="iron-gear-wheel",amount=1}},
  {{name="iron-plate",amount=2}}),
 ["cyclic-a"]=recipe("cyclic-a","crafting",1,
  {{name="cyclic-a",amount=1}},{{name="cyclic-b",amount=1}}),
 ["cyclic-b"]=recipe("cyclic-b","crafting",1,
  {{name="cyclic-b",amount=1}},{{name="cyclic-a",amount=1}}),
}
local items={}
for _,name in ipairs({"automation-science-pack","arcane-knowledge",
 "myetheric-resin","iron-ore","iron-plate","iron-gear-wheel",
 "cyclic-a","cyclic-b"}) do items[name]={name=name} end
local entity_protos={
 ["assembling-machine-1"]={crafting_speed=1},
 ["stone-furnace"]={crafting_speed=1},
 ["electric-mining-drill"]={mining_speed=1},
 ["small-electric-pole"]={},lab={},
}
TECH_PRIESTS_MAGOS_STANDARD_ENTITY_GROUPS_0255={
 assemblers={"assembling-machine-1"},smelters={"stone-furnace"},
 miners={"electric-mining-drill"},labs={"lab"},
 power={"small-electric-pole"},chemical={},oil={}}
tech_priests_get_recipe_prototype_0440=function(n)return recipes[n]end
tech_priests_get_item_prototype_0440=function(n)return items[n]end
tech_priests_get_entity_prototype_0440=function(n)return entity_protos[n]end
tech_priests_prototype_table_0440=function(kind)
 if kind=="recipe" then return recipes end
 if kind=="entity" then return {} end
 return {}
end
tech_priests_0255_current_planning_item=function()
 return "automation-science-pack"
end
local counts={}
local surface={index=1}
surface.find_entities_filtered=function(args)
 local n=counts[args.name] or 0
 local found={}
 for i=1,n do found[i]={valid=true,name=args.name,
  force=args.force,surface=surface,unit_number=i} end
 return found
end
local observed={["arcane-knowledge"]=7}
local force={recipes={},current_research={
 name="heresy-quantification",
 research_unit_ingredients={{name="arcane-knowledge",amount=2}}},
 get_item_production_statistics=function(scoped)
  assert(scoped==surface,"modded research measurement crossed surfaces")
  return {valid=true,get_flow_count=function(args)
   assert(args.category=="input" and args.precision_index==4,
    "modded science read a projected output instead of a native counter")
   return observed[args.name] or 0
  end}
 end}
for name in pairs(recipes) do force.recipes[name]={enabled=true} end
force.recipes["myetheric-resin"].enabled=false
local pair={station={valid=true,force=force,surface=surface,
  position={x=0,y=0}},priest={valid=true}}
local op={}
game={tick=12000}
defines={flow_precision_index={one_minute=4}}
dofile("tech-priests_src/scripts/magos_ratio_planning.lua")
local plan=tech_priests_0257_build_ratio_plan(pair,op)
assert(plan.science_technology=="heresy-quantification"
 and plan.science_packs["arcane-knowledge"]==2
 and not plan.science_packs["automation-science-pack"]
 and plan.recipes["arcane-knowledge"].rate==10/60
 and plan.recipes["resin-distillation"]
 and not plan.recipes["myetheric-resin"]
 and not plan.recipes["resin-empty-chemical"]
 and plan.recipes["resin-distillation"].rate==15/60
 and plan.raw_items["iron-ore"]==20/60
 and plan.observed_spm==3.5 and plan.graph_complete_1189,
 "modded research pack or recipe yield was computed incorrectly")
assert(plan.factory_links["arcane-knowledge|item|myetheric-resin"]
 .rate_per_second==15/60
 and plan.factory_links["resin-distillation|item|iron-plate"]
 .rate_per_second==15/60,
 "dependency links ignored the actual modded intermediate recipe yield")
force.recipes["resin-distillation"].enabled=false
local locked=tech_priests_0257_build_ratio_plan(pair,op)
assert(not locked.graph_complete_1189
 and locked.unresolved["myetheric-resin"]
 and locked.unresolved_reasons_1189["myetheric-resin"]==
   "recipe-locked-for-force"
 and not locked.recipes["resin-distillation"],
 "modded unavailable recipe was counted as a real buildable path")
force.recipes["resin-distillation"].enabled=true
force.current_research.research_unit_ingredients={
 {name="cyclic-a",amount=1}}
local cycle=tech_priests_0257_build_ratio_plan(pair,op)
assert(not cycle.graph_complete_1189
 and cycle.unresolved["cyclic-a"]
 and cycle.unresolved_reasons_1189["cyclic-a"]==
 "cyclic-recipe-dependency",
 "recursive modded recipes were silently dropped")
force.current_research.research_unit_ingredients={
 {name="arcane-knowledge",amount=2}}
force.recipes["resin-distillation"].enabled=true
local first=tech_priests_0257_build_ratio_plan(pair,op)
local second=tech_priests_0257_build_ratio_plan(pair,op)
assert(first.recipes["resin-distillation"].rate==
 second.recipes["resin-distillation"].rate
 and first.groups.assemblers==second.groups.assemblers,
 "recipe choice depended on unstable Lua table enumeration")
print("[magos-modded-research-graph-1189] PASS actual custom research pack, alternative unlocked recipe, probabilistic output, locked/cyclic refusal, stable machine demand")
