-- 1133: load the PRODUCTION Magos planning wrapper with engine-like
-- Factorio prototypes and real API-shaped production counters. This unit
-- test never credits recipe forecasts as actual mined/manufactured science.
local original_path=package.path
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local function item(name)return {name=name}end
local entities={
 ["assembling-machine-1"]={crafting_speed=0.5},
 ["stone-furnace"]={crafting_speed=1},
 ["electric-mining-drill"]={mining_speed=1},
 ["lab"]={},["small-electric-pole"]={}}
local function recipe(name,energy,ingredients)
 return {name=name,category=name=="iron-plate" or name=="copper-plate"
   and "smelting" or "crafting",energy=energy,
   products={{name=name,amount=1}},ingredients=ingredients}
end
local recipes={
 ["automation-science-pack"]=recipe("automation-science-pack",5,
   {{name="copper-plate",amount=1},{name="iron-gear-wheel",amount=1}}),
 ["iron-gear-wheel"]=recipe("iron-gear-wheel",0.5,
   {{name="iron-plate",amount=2}}),
 ["iron-plate"]=recipe("iron-plate",3.2,
   {{name="iron-ore",amount=1}}),
 ["copper-plate"]=recipe("copper-plate",3.2,
   {{name="copper-ore",amount=1}})
}
-- Correct recipe categories for mock objects (the production planner still
-- reads the real engine category).
recipes["iron-plate"].category="smelting"
recipes["copper-plate"].category="smelting"
for name,r in pairs(recipes)do assert(r.name==name)end
local items={
 ["automation-science-pack"]=item("automation-science-pack"),
 ["iron-plate"]=item("iron-plate"),["copper-plate"]=item("copper-plate"),
 ["iron-gear-wheel"]=item("iron-gear-wheel"),
 ["iron-ore"]=item("iron-ore"),["copper-ore"]=item("copper-ore"),
 ["transport-belt"]=item("transport-belt"),["inserter"]=item("inserter")}
TECH_PRIESTS_MAGOS_STANDARD_ENTITY_GROUPS_0255={
 assemblers={"assembling-machine-1"},smelters={"stone-furnace"},
 miners={"electric-mining-drill"},labs={"lab"},
 power={"small-electric-pole"},chemical={},oil={}}
tech_priests_get_entity_prototype_0440=function(n)return entities[n]end
tech_priests_get_item_prototype_0440=function(n)return items[n]end
tech_priests_get_recipe_prototype_0440=function(n)return recipes[n]end
tech_priests_prototype_table_0440=function(kind)
 if kind=="recipe" then return recipes end
 if kind=="entity" then return {} end
 return {}
end
tech_priests_0255_current_planning_item=function()
 return "automation-science-pack"
end
tech_priests_0255_pair_is_magos_planner=function()return true end
tech_priests_0255_first_available_item=function(names)return names[1]end
local original=function()return nil end
tech_priests_0255_pick_standard_need=original
local observed=0
local observed_map=nil
local calls=0
local force={index=1,get_item_production_statistics=function(surface)
 assert(surface.index==1)
 return {valid=true,get_flow_count=function(args)
  calls=calls+1
  assert(type(args.name)=="string" and args.category=="input"
    and args.precision_index==4,"wrong native production counter arguments")
  if observed_map then return observed_map[args.name] or 0 end
  assert(args.name=="automation-science-pack")
  return observed
 end}
end}
local surface={index=1}
local world_counts={}
surface.find_entities_filtered=function(args)
 local first=type(args.name)=="string" and args.name
 local n=world_counts[first] or 0
 local out={}
 for i=1,n do out[i]={valid=true,name=first} end
 return out
end
local pair={station={valid=true,surface=surface,force=force,
  position={x=0,y=0}},priest={valid=true}}
local op={}
game={tick=7200}
defines={flow_precision_index={one_minute=4}}
dofile("tech-priests_src/scripts/magos_ratio_planning.lua")
local plan=tech_priests_0257_build_ratio_plan(pair,op)
assert(plan.objective=="automation-science-pack"
  and plan.target_spm==5 and plan.target_rate==5/60
  and plan.observed_spm==0 and plan.observed_spm_scope=="force-surface-research-basket"
  and calls==1,"science target/measurement was not engine-grounded")
assert(plan.recipes["automation-science-pack"].rate==5/60
  and plan.recipes["iron-plate"].rate==10/60,
  "shared ingredient recipe rates were not propagated correctly")
assert(plan.groups.smelters==2,
  "different real smelting recipes were collapsed by maximum")
assert(plan.groups.assemblers==2,
  "science and gear machines were collapsed into a single assembler")
assert(plan.raw_items["iron-ore"]==10/60
  and plan.raw_items["copper-ore"]==5/60,
  "real science ingredients were replaced by arbitrary group totals")
assert(plan.groups.miners==2,
  "iron and copper mining demand did not add")
-- 1138: exact ingredient-to-recipe connections; no synthetic construction.
local first_link=plan.factory_links["iron-gear-wheel|item|iron-plate"]
assert(first_link and first_link.source_kind=="item"
  and first_link.consumer_recipe=="iron-gear-wheel"
  and first_link.rate_per_second==10/60
  and #plan.factory_link_order==5,
  "red science graph lost physical iron-plate-to-gear connection")
assert(plan.factory_links["automation-science-pack|item|copper-plate"]
  .rate_per_second==5/60,
  "red science copper input was not traced to its consumer")
-- A nominally complete machine list cannot claim science target achieved
-- while the live Factorio force/surface production counter says zero.
world_counts["small-electric-pole"]=48
world_counts["electric-mining-drill"]=48
world_counts["stone-furnace"]=48
world_counts["assembling-machine-1"]=48
world_counts["lab"]=48
world_counts["transport-belt"]=400
world_counts["inserter"]=400
local no_item,no_reason,verified=
  tech_priests_0257_pick_ratio_need(pair,op)
assert(no_item==nil and no_reason==nil
  and verified.observed_spm==0
  and op.magos_ratio_phase_0257=="real-science-throughput-below-target",
  "generic placed machines were falsely treated as 5 SPM production")
observed=5.25
local _,_,healthy=tech_priests_0257_pick_ratio_need(pair,op)
assert(healthy.observed_spm==5.25
  and op.magos_ratio_phase_0257=="ratio-satisfied",
  "physically measured SPM meeting objective was discarded")
-- User-controlled targets scale recipe throughput, cannot exceed bounded
-- upper limit, and do not invent production under a lower actual read.
pair.science_spm_target_1133=60
observed=2
local large=tech_priests_0257_build_ratio_plan(pair,op)
assert(large.target_spm==60 and large.observed_spm==2
  and large.recipes["automation-science-pack"].rate==1
  and large.groups.assemblers==11
  and large.groups.smelters==11
  and large.groups.miners==15,
  "higher SPM request did not expand physical factory demand")
pair.science_spm_target_1133=600
assert(tech_priests_0257_build_ratio_plan(pair,op).target_spm==60,
  "unbounded rate target bypassed factory planning limit")
-- A two-pack research cannot be "5 SPM satisfied" because red
-- science is producing while the physically required green science is zero.
recipes["logistic-science-pack"]=recipe("logistic-science-pack",6,
  {{name="copper-plate",amount=1},{name="iron-gear-wheel",amount=1}})
items["logistic-science-pack"]=item("logistic-science-pack")
pair.science_spm_target_1133=5
force.current_research={name="steel-processing",research_unit_ingredients={
  {name="automation-science-pack",amount=1},
  {name="logistic-science-pack",amount=1}}}
observed_map={
  ["automation-science-pack"]=5,
  ["logistic-science-pack"]=0}
local two=tech_priests_0257_build_ratio_plan(pair,op)
assert(two.science_technology=="steel-processing"
  and two.science_packs["automation-science-pack"]==1
  and two.science_packs["logistic-science-pack"]==1
  and two.recipes["iron-gear-wheel"].rate==10/60
  and two.groups.assemblers==3 and two.groups.smelters==3
  and two.groups.miners==3,
  "multiple research science packs did not add shared recipe/machine load")
assert(two.observed_spm==0
  and two.observed_spm_by_pack["automation-science-pack"]==5
  and two.observed_spm_by_pack["logistic-science-pack"]==0,
  "single healthy science family masked a stalled research requirement")
assert(#two.factory_link_order==7
  and two.factory_links["automation-science-pack|item|iron-gear-wheel"]
    .rate_per_second==5/60
  and two.factory_links["logistic-science-pack|item|iron-gear-wheel"]
    .rate_per_second==5/60
  and two.factory_links["iron-gear-wheel|item|iron-plate"]
    .rate_per_second==20/60,
  "shared gear production graph omitted either distinct science consumer")
for i=2,#two.factory_link_order do
  assert(two.factory_link_order[i-1]<two.factory_link_order[i],
    "factory input link ordering is not deterministic")
end
-- Factorio permits different counts for science packs in a research unit.
-- The *limiting completed research units per minute* is the minimum
-- observed pack production divided by its actual pack requirement.
force.current_research.research_unit_ingredients[2].amount=2
observed_map["logistic-science-pack"]=7
local uneven=tech_priests_0257_build_ratio_plan(pair,op)
assert(uneven.science_packs["logistic-science-pack"]==2
  and uneven.observed_spm==3.5
  and uneven.recipes["logistic-science-pack"].rate==10/60
  and uneven.factory_links["logistic-science-pack|item|iron-gear-wheel"]
    .rate_per_second==10/60
  and uneven.factory_links["iron-gear-wheel|item|iron-plate"]
    .rate_per_second==30/60,
  "uneven research basket did not scale both input connections and output")
-- Restore the single-pack source-only refusal fixture.
force.current_research=nil
observed_map=nil
-- Measurements fail CLOSED if the force API is missing. They must never
-- return estimated planned SPM in place of observed actual production.
force.get_item_production_statistics=nil
local missing=tech_priests_0257_build_ratio_plan(pair,op)
assert(missing.observed_spm==nil and missing.observed_spm_reason==
  "factorio-item-production-statistics-unavailable")
print("[magos-science-throughput-1133] PASS additive industry recipe sizing, 1138 input dependency graph, 5/60 SPM targets, engine-only measurement and no false throughput credit")
package.path=original_path
