-- 1150: production shortages must create dependency-ordered, genuine
-- construction requests for the original 0338 physical builder, and the
-- builder may configure only a new paid assembler with no held items.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local entities={
 ["assembling-machine-1"]={type="assembling-machine",
   crafting_speed=0.5,crafting_categories={crafting=true}},
 ["stone-furnace"]={type="furnace",crafting_speed=1},
 ["electric-mining-drill"]={type="mining-drill",mining_speed=1},
 ["small-electric-pole"]={type="electric-pole"},
 ["lab"]={type="lab"},
}
local items={}
for name,entity in pairs(entities) do
 items[name]={name=name,place_result={name=name,type=entity.type}}
end
items["automation-science-pack"]={name="automation-science-pack"}
items["iron-gear-wheel"]={name="iron-gear-wheel"}
items["iron-plate"]={name="iron-plate"}
items["copper-plate"]={name="copper-plate"}
items["iron-ore"]={name="iron-ore"}
items["copper-ore"]={name="copper-ore"}
local function recipe(name,category,energy,ingredients)
 return {name=name,category=category,energy=energy,
  products={{name=name,amount=1}},ingredients=ingredients}
end
local recipes={
 ["automation-science-pack"]=recipe("automation-science-pack","crafting",5,
   {{name="iron-gear-wheel",amount=1},{name="copper-plate",amount=1}}),
 ["iron-gear-wheel"]=recipe("iron-gear-wheel","crafting",0.5,
   {{name="iron-plate",amount=2}}),
 ["iron-plate"]=recipe("iron-plate","smelting",3.2,
   {{name="iron-ore",amount=1}}),
 ["copper-plate"]=recipe("copper-plate","smelting",3.2,
   {{name="copper-ore",amount=1}}),
}
TECH_PRIESTS_MAGOS_STANDARD_ENTITY_GROUPS_0255={
 assemblers={"assembling-machine-1"},smelters={"stone-furnace"},
 miners={"electric-mining-drill"},power={"small-electric-pole"},
 labs={"lab"},chemical={},oil={}}
tech_priests_get_entity_prototype_0440=function(n)return entities[n]end
tech_priests_get_item_prototype_0440=function(n)return items[n]end
tech_priests_get_recipe_prototype_0440=function(n)return recipes[n]end
tech_priests_prototype_table_0440=function(kind)
 if kind=="recipe" then return recipes end
 return {}
end
tech_priests_0255_first_available_item=function(names)return names[1]end
tech_priests_0255_pair_is_magos_planner=function()return true end
tech_priests_0255_current_planning_item=function()
 return "automation-science-pack"
end
local old_need_calls=0
tech_priests_0255_pick_standard_need=function()
 old_need_calls=old_need_calls+1
 return nil,"legacy-still-owned"
end
local surface={index=1}
local force={index=1,recipes={}}
for name in pairs(recipes) do force.recipes[name]={enabled=true} end
local production={["automation-science-pack"]=0,["iron-gear-wheel"]=0}
force.get_item_production_statistics=function(scoped_surface)
 assert(scoped_surface==surface,"local component stats crossed surfaces")
 return {valid=true,get_flow_count=function(args)
   assert(args.category=="input" and args.precision_index==4,
     "component output observation is not a real one-minute production rate")
   return production[args.name] or 0
 end}
end
local world_counts={
 ["small-electric-pole"]=5,["electric-mining-drill"]=5,
 ["stone-furnace"]=5,["lab"]=5,["assembling-machine-1"]=0}
local configured={}
surface.find_entities_filtered=function(args)
 assert(args.force==force and args.radius and args.position,
   "component scan escaped the original station/force")
 local name=args.name
 local arr={}
 for i=1,world_counts[name] or 0 do
  local recipe_name=configured[i]
  arr[i]={valid=true,name=name,unit_number=i+10000,
    force=force,surface=surface,
    get_recipe=function()
      return name=="assembling-machine-1" and recipe_name
        and {name=recipe_name} or nil
    end}
 end
 return arr
end
local pair={station={valid=true,unit_number=100,
  position={x=0,y=0},force=force,surface=surface},
 priest={valid=true,unit_number=101},
 master_infrastructure_plan_0644={stage="ready"}}
local op={}
_G.game={tick=7200}
_G.defines={flow_precision_index={one_minute=4}}
dofile("tech-priests_src/scripts/magos_ratio_planning.lua")
local need,reason=tech_priests_0255_pick_standard_need(pair,op)
local request=pair.construction_requested_item
local plan=op.magos_ratio_plan_0257
assert(need=="assembling-machine-1"
  and op.magos_ratio_phase_0257=="factory-component-construction-needed"
  and op.magos_ratio_component_job_1150=="iron-gear-wheel"
  and plan.factory_component_order_1150[1]=="iron-gear-wheel"
  and plan.factory_component_jobs_1150["iron-gear-wheel"].required_per_minute==5
  and request and request.factory_component_owner_1150==100
  and request.factory_component_recipe_1150=="iron-gear-wheel"
  and request.entity_name=="assembling-machine-1"
  and request.source=="magos-science-components-1150"
  and old_need_calls==0,
  "missing real gears production did not plan the first physical assembler")
local second=tech_priests_0255_pick_standard_need(pair,op)
assert(second=="assembling-machine-1"
  and pair.construction_requested_item==request
  and op.magos_ratio_component_dispatch_1150==
    "existing-exact-component-construction-request",
  "repeated planner ticks created a duplicate physical construction order")
-- 1164: Once 0644 has a real researchable lab it advances a physically
-- READY bootstrap plan to stage "science-ready". This is not permission to
-- stop the factory planner. Keep its exact 0338 request and never issue a
-- duplicate. An INCOMPLETE standard-drill bootstrap still owns the gate.
pair.master_infrastructure_plan_0644.stage="science-ready"
local science_need,science_reason=
  tech_priests_0255_pick_standard_need(pair,op)
assert(science_need=="assembling-machine-1"
  and op.magos_ratio_component_job_1150=="iron-gear-wheel"
  and op.magos_ratio_component_dispatch_1150==
    "existing-exact-component-construction-request"
  and pair.construction_requested_item==request
  and old_need_calls==0,
  "science-ready stopped dependency-first Magos construction")
pair.master_infrastructure_plan_0644.stage="bootstrap-normal-mining"
local blocked_need,blocked_reason=
  tech_priests_0255_pick_standard_need(pair,op)
assert(blocked_need==nil
  and blocked_reason=="central-martian-bootstrap:bootstrap-normal-mining"
  and pair.construction_requested_item==request
  and old_need_calls==0,
  "unfinished normal-drill infrastructure bypassed priority or lost custody")
-- 1168: the ACTUAL Factorio 123k runtime had red packs produced and a
-- physically built lab while 0644 still needed its normal drill. That must
-- not suppress subcomponent planning forever; preserve the drill stage and
-- original 0338 construction request rather than marking bootstrap done.
production["automation-science-pack"]=1
local overlap_need=tech_priests_0255_pick_standard_need(pair,op)
assert(overlap_need=="assembling-machine-1"
  and pair.master_infrastructure_plan_0644.stage=="bootstrap-normal-mining"
  and op.magos_ratio_bootstrap_overlap_1168==
    "real-local-lab-and-native-red-science"
  and op.magos_ratio_component_job_1150=="iron-gear-wheel"
  and op.magos_ratio_component_dispatch_1150==
    "existing-exact-component-construction-request"
  and pair.construction_requested_item==request and old_need_calls==0,
  "measured science progress did not reopen safe subcomponent construction")
-- A force-level production counter alone is insufficient: a Magos without
-- a REAL local laboratory cannot claim this limited cooperative exception.
world_counts["lab"]=0
local no_lab,no_lab_reason=tech_priests_0255_pick_standard_need(pair,op)
assert(no_lab==nil
  and no_lab_reason=="central-martian-bootstrap:bootstrap-normal-mining"
  and op.magos_ratio_bootstrap_overlap_1168==nil
  and pair.construction_requested_item==request,
  "remote science statistics bypassed missing local lab")
world_counts["lab"]=5
production["automation-science-pack"]=0
assert(tech_priests_0255_pick_standard_need(pair,op)==nil
  and op.magos_ratio_bootstrap_overlap_1168==nil,
  "unobserved science was treated as physical bootstrap completion")
-- 1172: the 0266 survival wrapper may not call the 0255 personal
-- planner at all. The existing strategic 0471 tick must independently queue
-- a missing dedicated component machine without hijacking survival work.
op.enabled=true
pair.independent_emergency_operation_0184=op
production["automation-science-pack"]=1
pair.construction_requested_item=nil
_G.storage={tech_priests={}}
local Queue=require("scripts.core.magos_planning_queue_0471")
game.tick=9000
Queue.tick_pair(pair)
local autonomous=pair.construction_requested_item
assert(autonomous
  and autonomous.factory_component_recipe_1150=="iron-gear-wheel"
  and autonomous.factory_component_owner_1150==100
  and op.magos_ratio_component_job_1150=="iron-gear-wheel"
  and pair.master_infrastructure_plan_0644.stage=="bootstrap-normal-mining"
  and pair.magos_science_last_result_1172.acted==true,
  "survival dispatcher blocked independent, real science shortage planning")
Queue.tick_pair(pair)
assert(pair.construction_requested_item==autonomous
  and pair.magos_science_next_tick_1172==9600,
  "repeated strategic tick duplicated the original 0338 construction")
op.enabled=false
pair.construction_requested_item=nil
game.tick=9700
Queue.tick_pair(pair)
assert(pair.construction_requested_item==nil
  and pair.magos_science_last_result_1172.reason==
    "emergency-operation-not-enabled",
  "disabled emergency operation caused autonomous construction")
op.enabled=true
pair.emergency_craft={item="firearm-magazine"}
game.tick=10400
Queue.tick_pair(pair)
assert(pair.construction_requested_item==nil
  and pair.magos_science_last_result_1172.reason==
    "incumbent-physical-duty-owned",
  "live emergency craft was interrupted by science planning")
pair.emergency_craft=nil
world_counts["lab"]=0
game.tick=11100
Queue.tick_pair(pair)
assert(pair.construction_requested_item==nil
  and pair.magos_science_last_result_1172.reason=="no-local-laboratory",
  "force-wide science count bypassed missing local lab")
world_counts["lab"]=5
production["automation-science-pack"]=0
game.tick=11800
Queue.tick_pair(pair)
assert(pair.construction_requested_item==nil
  and pair.magos_science_last_result_1172.reason==
    "no-native-red-science-production",
  "unobserved real science commissioned a factory")
production["automation-science-pack"]=1
pair.construction_requested_item={
  item_name="stone-furnace",entity_name="stone-furnace",
  source="foreign-existing-physical-builder"}
local foreign=pair.construction_requested_item
game.tick=12500
Queue.tick_pair(pair)
assert(pair.construction_requested_item==foreign
  and pair.magos_science_last_result_1172.reason==
    "existing-construction-request-preserved",
  "science pulse replaced existing physical construction custody")
pair.construction_requested_item=request
op.enabled=nil
pair.independent_emergency_operation_0184=nil
production["automation-science-pack"]=0
pair.master_infrastructure_plan_0644.stage="ready"
-- Another owner's request is never replaced, even if science is starving.
pair.construction_requested_item={
 item_name="stone-furnace",entity_name="stone-furnace",
 source="unrelated-existing-construction"}
local unrelated=pair.construction_requested_item
assert(tech_priests_0255_pick_standard_need(pair,op)=="assembling-machine-1"
  and pair.construction_requested_item==unrelated
  and op.magos_ratio_component_dispatch_1150==
    "existing-construction-request-preserved",
  "science planner seized an unrelated item construction request")
pair.construction_requested_item=nil
pair.construction_task_0338={phase="move-site"}
tech_priests_0255_pick_standard_need(pair,op)
assert(pair.construction_requested_item==nil
  and op.magos_ratio_component_dispatch_1150==
    "existing-physical-construction-owner",
  "live physical construction was preempted by a planned component")
pair.construction_task_0338=nil
-- A known physical build/recipe failure must not emit endless duplicate
-- machines into the factory.
pair.factory_component_blocked_1150={
 recipe="iron-gear-wheel",entity_unit=555,reason="set-recipe-refused"}
tech_priests_0255_pick_standard_need(pair,op)
assert(pair.construction_requested_item==nil
  and op.magos_ratio_component_dispatch_1150==
    "previous-physical-build-recipe-configuration-blocked",
  "failed recipe configuration triggered unbounded extra construction")
pair.factory_component_blocked_1150=nil
-- Real local gear throughput can satisfy its subcomponent requirement even
-- when none of this station's assemblers was configured for the recipe.
production["iron-gear-wheel"]=5.25
local next_need=tech_priests_0257_pick_ratio_need(pair,op)
assert(next_need=="assembling-machine-1"
  and op.magos_ratio_component_job_1150=="automation-science-pack",
  "measured upstream production was ignored in downstream science planning")
production["iron-gear-wheel"]=0
-- Actual configured gear and science recipes satisfy machine allocation,
-- while zero produced science still fails the engine throughput test.
world_counts["assembling-machine-1"]=2
configured[1]="iron-gear-wheel"
configured[2]="automation-science-pack"
local none=tech_priests_0257_pick_ratio_need(pair,op)
assert(none==nil and op.magos_ratio_phase_0257==
    "real-science-throughput-below-target",
  "recipe-configured factory was falsely credited with manufactured science")
-- An unresearched gear recipe blocks its downstream science build. This
-- must not create a pretend research unlock or remote/creative construction.
configured={}
world_counts["assembling-machine-1"]=0
force.recipes["iron-gear-wheel"].enabled=false
local locked=tech_priests_0257_build_ratio_plan(pair,op)
local audit=tech_priests_1142_observe_factory_recipe_slots(pair,locked)
assert(tech_priests_1150_plan_component_construction(pair,locked,audit)==nil
  and locked.factory_component_blocker_1150.recipe=="iron-gear-wheel"
  and locked.factory_component_jobs_1150["iron-gear-wheel"].phase==
    "recipe-locked-or-unknown",
  "science construction bypassed an unavailable intermediate recipe")
force.recipes["iron-gear-wheel"].enabled=true
-- A prototype without the required crafting category may not be ordered:
-- builders must never spend a machine that cannot make the deficit recipe.
entities["assembling-machine-1"].crafting_categories.crafting=nil
local impossible=tech_priests_0257_build_ratio_plan(pair,op)
local incompatible=tech_priests_1142_observe_factory_recipe_slots(
 pair,impossible)
assert(tech_priests_1150_plan_component_construction(
   pair,impossible,incompatible)==nil
  and impossible.factory_component_blocker_1150.recipe=="iron-gear-wheel"
  and impossible.factory_component_jobs_1150["iron-gear-wheel"].phase==
    "no-supported-machine-item",
  "science planner ordered a physically unsupported recipe-machine pair")
entities["assembling-machine-1"].crafting_categories.crafting=true
-- The existing 0338 construction owner configures ONLY an exact newly
-- constructed item-paid assembler, and never touches loaded/foreign machines.
local Builder=require("scripts.core.construction_planner")
pair.construction_requested_item=request
local task={request_field="construction_requested_item",
  request_value=request,item_name=request.item_name,
  entity_name=request.entity_name}
local built
local selected=nil
local held=0
local changes=0
built={valid=true,name="assembling-machine-1",
 type="assembling-machine",unit_number=555,
 force=force,surface=surface,
 get_item_count=function()return held end,
 get_recipe=function()return selected and {name=selected} or nil end,
 set_recipe=function(name)
  changes=changes+1
  selected=name
  return {}
 end}
local configured_ok,why=Builder.configure_built_factory_recipe_1150(
 pair,task,built)
assert(configured_ok and why=="real-built-assembler-recipe-configured"
  and selected=="iron-gear-wheel" and changes==1,
  "paid new assembler did not receive its intended recipe")
selected=nil
held=1
local refused,cause=Builder.configure_built_factory_recipe_1150(
 pair,task,built)
assert(not refused and cause=="new-assembler-not-empty"
  and changes==1 and selected==nil,
  "recipe change ejected or overwrote an item inside a real machine")
held=0
selected="automation-science-pack"
refused,cause=Builder.configure_built_factory_recipe_1150(pair,task,built)
assert(not refused and cause=="built-machine-has-foreign-recipe"
  and changes==1 and selected=="automation-science-pack",
  "existing different recipe was overwritten by a new construction order")
selected=nil
built.type="furnace"
refused=Builder.configure_built_factory_recipe_1150(pair,task,built)
assert(not refused and changes==1,
  "furnace was wrongly configured through assembler-only set_recipe")
built.type="assembling-machine"
force.recipes["iron-gear-wheel"].enabled=false
refused,cause=Builder.configure_built_factory_recipe_1150(pair,task,built)
assert(not refused and cause=="factory-recipe-not-researched"
  and changes==1,
  "builder bypassed real force recipe technology")
force.recipes["iron-gear-wheel"].enabled=true
pair.construction_requested_item={}
refused=Builder.configure_built_factory_recipe_1150(pair,task,built)
assert(not refused and changes==1,
  "configuration ignored exact original builder request identity")
-- Verify the NEW request enters the ORIGINAL 0338 canonical discovery,
-- not an isolated planning ledger. Discovery alone must never spend an item.
local prior_prototypes=rawget(_G,"prototypes")
local prior_site=rawget(_G,"TECH_PRIESTS_CONSTRUCTION_SITE_PLANNER_0359")
local prior_storage=rawget(_G,"storage")
_G.prototypes={item=items,entity=entities}
_G.storage={tech_priests={pairs_by_station={[100]=pair}}}
_G.TECH_PRIESTS_CONSTRUCTION_SITE_PLANNER_0359={
 plan_site=function(p,placeable)
  assert(p==pair and placeable.item_name=="assembling-machine-1"
    and placeable.entity_name=="assembling-machine-1"
    and placeable.category=="assembler",
    "1150 attempted to bypass canonical 0338 site planning")
  return {x=8,y=8},"canonical-station-interior"
 end
}
pair.construction_requested_item=request
local discovered=Builder.discover_pair(pair,true)
assert(discovered and discovered.request_field=="construction_requested_item"
  and discovered.request_value==request
  and discovered.entity_name=="assembling-machine-1"
  and discovered.position.x==8 and discovered.position.y==8
  and discovered.category=="assembler"
  and discovered.item_name=="assembling-machine-1"
  and not pair.construction_task_0338
  and not pair.construction_custody_0338,
  "actual 0338 builder did not discover exact science component request")
_G.prototypes=prior_prototypes
_G.TECH_PRIESTS_CONSTRUCTION_SITE_PLANNER_0359=prior_site
_G.storage=prior_storage
print("[magos-component-construction-1150] PASS dependency-first subcomponent construction, 0338 exact request/custody, retry/lock guards and actual new assembler recipe configuration")
