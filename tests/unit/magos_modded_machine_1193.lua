-- 1193: a nonstandard modded crafting category requires its own
-- real item-placeable assembling machine; no free prefab or stock is added.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local recipes={
 ["automation-science-pack"]={
  name="automation-science-pack",category="crafting",energy=1,
  products={{name="automation-science-pack",amount=1}},
  ingredients={{name="sacred-binder",amount=1}}},
 ["sacred-binder"]={name="sacred-binder",
  category="sacred-crafting",energy=2,
  products={{name="sacred-binder",amount=1}},
  ingredients={{name="iron-plate",amount=1}}},
 ["iron-plate"]={name="iron-plate",category="smelting",energy=1,
  products={{name="iron-plate",amount=1}},
  ingredients={{name="iron-ore",amount=1}}}
}
local entities={
 ["assembling-machine-1"]={type="assembling-machine",
   crafting_speed=1,crafting_categories={crafting=true}},
 ["alchemical-loom"]={type="assembling-machine",
   crafting_speed=1,
   crafting_categories={["sacred-crafting"]=true},
   items_to_place_this={{name="alchemical-loom-kit"}}},
 ["false-loom"]={type="furnace",crafting_speed=1,
   crafting_categories={["sacred-crafting"]=true},
   items_to_place_this={{name="false-loom-kit"}}},
 ["stone-furnace"]={type="furnace",crafting_speed=1},
 ["electric-mining-drill"]={type="mining-drill",mining_speed=1},
 ["lab"]={type="lab"},["small-electric-pole"]={type="electric-pole"},
}
local items={
 ["automation-science-pack"]={name="automation-science-pack"},
 ["sacred-binder"]={name="sacred-binder"},
 ["iron-ore"]={name="iron-ore"},
 ["iron-plate"]={name="iron-plate"},
 ["assembling-machine-1"]={
  place_result={name="assembling-machine-1"}},
 ["alchemical-loom-kit"]={place_result={name="alchemical-loom"}},
 ["false-loom-kit"]={place_result={name="false-loom"}},
}
TECH_PRIESTS_MAGOS_STANDARD_ENTITY_GROUPS_0255={
 assemblers={"assembling-machine-1"},smelters={"stone-furnace"},
 miners={"electric-mining-drill"},power={"small-electric-pole"},
 labs={"lab"},chemical={},oil={}}
tech_priests_get_entity_prototype_0440=function(n)return entities[n]end
tech_priests_get_item_prototype_0440=function(n)return items[n]end
tech_priests_get_recipe_prototype_0440=function(n)return recipes[n]end
tech_priests_prototype_table_0440=function(kind)
 if kind=="entity" then return entities end
 if kind=="recipe" then return recipes end
 if kind=="item" then return items end
 return {}
end
tech_priests_0255_first_available_item=function(names)
 return names[1]
end
tech_priests_0255_current_planning_item=function()
 return "automation-science-pack"
end
local observed={["automation-science-pack"]=0,
 ["sacred-binder"]=0}
local force={recipes={},get_item_production_statistics=function()
 return {valid=true,get_flow_count=function(args)
  return observed[args.name] or 0
 end}
end}
for name in pairs(recipes)do force.recipes[name]={enabled=true}end
local surface={index=1}
local counts={["small-electric-pole"]=10,
 ["electric-mining-drill"]=10,["stone-furnace"]=10,
 ["assembling-machine-1"]=1}
local configured={["assembling-machine-1"]="automation-science-pack"}
surface.find_entities_filtered=function(args)
 local out={}
 for i=1,(counts[args.name] or 0)do
  out[#out+1]={valid=true,name=args.name,force=force,
    surface=surface,unit_number=10000+i+
      (args.name=="alchemical-loom" and 9000 or 0),
    get_recipe=function()
      local recipe_name=configured[args.name]
      return recipe_name and {name=recipe_name} or nil
    end}
 end
 return out
end
local pair={station={valid=true,force=force,surface=surface,
 unit_number=151,position={x=0,y=0}},priest={valid=true}}
game={tick=12000}
defines={flow_precision_index={one_minute=4}}
dofile("tech-priests_src/scripts/magos_ratio_planning.lua")
local op={}
local need,reason,plan=tech_priests_0257_pick_ratio_need(pair,op)
assert(need=="alchemical-loom-kit"
 and plan.factory_component_next_1150
 and plan.factory_component_next_1150.recipe=="sacred-binder"
 and plan.factory_component_next_1150.machine_entity=="alchemical-loom"
 and plan.factory_component_next_1150.machine_item==
 "alchemical-loom-kit"
 and plan.factory_component_next_1150.researched==true,
 "modded crafting category did not resolve to a legitimate placeable machine")
local issued,why=tech_priests_1150_issue_component_construction(
 pair,op,plan)
assert(issued and why=="queued-for-real-0338-construction"
 and pair.construction_requested_item.item_name=="alchemical-loom-kit"
 and pair.construction_requested_item.entity_name=="alchemical-loom"
 and pair.construction_requested_item.factory_component_recipe_1150==
   "sacred-binder",
 "custom machine recipe bypassed physical 0338 item-and-recipe authority")
pair.construction_requested_item=nil
-- After actual same-force, local, correctly configured machine appears,
-- recognize the modded assembler, not just the old vanilla group names.
counts["alchemical-loom"]=1
configured["alchemical-loom"]="sacred-binder"
local _,_,updated=tech_priests_0257_pick_ratio_need(pair,op)
assert(updated.factory_recipe_audit_1142.configured["sacred-binder"]==1
 and updated.factory_recipe_audit_1142.missing["sacred-binder"]==0
 and updated.factory_component_next_1150==nil,
 "installed custom loom was ignored and triggered duplicate construction")
counts["alchemical-loom"]=0
items["alchemical-loom-kit"].place_result=nil
local _,_,blocked=tech_priests_0257_pick_ratio_need(pair,op)
assert(blocked.factory_component_blocker_1150
 and blocked.factory_component_blocker_1150.recipe=="sacred-binder"
 and blocked.factory_component_blocker_1150.phase==
 "no-supported-machine-item",
 "unsupported custom machine was fabricated without a real placeable item")
print("[magos-modded-machine-1193] PASS exact custom-category LuaEntity capability, placeable item, 0338 request, live recipe readback and no unsafe fallback")
