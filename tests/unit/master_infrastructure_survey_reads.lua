-- 0644: repeated planner reads must stay inside one read-only survey.
-- This counts native-facing operations; it is not a native UPS benchmark.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=1200}
storage={tech_priests={pairs_by_station={}}}
defines={inventory={chest=1,lab_input=2}}
local calls={recipe_walks=0,recipe_visits=0,stock={},lab={}}
local ordered={}
local recipes={}
local function add_recipe(name,recipe)
  recipe.name=name
  recipes[name]=recipe
  ordered[#ordered+1]=name
end
for i=1,400 do
  add_recipe("unrelated-"..i,{enabled=true,
    products={{name="unrelated-product-"..i}},ingredients={}})
end
add_recipe("alternate-furnace",{enabled=false,
  products={{name="stone-furnace"}},
  ingredients={{name="iron-plate",amount=50}}})
add_recipe("stone-furnace",{enabled=true,
  products={{name="stone-furnace"}},
  ingredients={{name="stone",amount=5}}})
add_recipe("tech-priests-emergency-smelter",{enabled=true,
  products={{name="tech-priests-emergency-smelter"}},
  ingredients={{name="iron-plate",amount=1}}})
setmetatable(recipes,{__pairs=function()
  calls.recipe_walks=calls.recipe_walks+1
  local i=0
  return function()
    i=i+1
    local name=ordered[i]
    if name then
      calls.recipe_visits=calls.recipe_visits+1
      return name,recipes[name]
    end
  end
end})
local pack="automation-science-pack"
local technologies={}
for i=1,256 do
  local name=string.format("technology-%03d",i)
  technologies[name]={valid=true,name=name,enabled=true,researched=false,
    prerequisites={},research_unit_ingredients={{name=pack,amount=1}},
    research_unit_count=i}
end
technologies.locked={valid=true,name="locked",enabled=true,researched=false,
  prerequisites={{researched=false}},
  research_unit_ingredients={{name=pack,amount=1}},research_unit_count=0}
local force={valid=true,name="player",index=1,recipes=recipes,
  technologies=technologies}
local labs={}
local surface={index=1}
surface.find_entities_filtered=function(query)
  if query.type=="resource" then return {} end
  if query.type=="lab" or type(query.type)=="table" then
    return {labs[query.position.x]}
  end
  return {}
end
_G.TechPriestsStorageRoleAuthority0686={
  generic_item_count=function(pair,item)
    local key=pair.station.unit_number..":"..item
    calls.stock[key]=(calls.stock[key] or 0)+1
    return pair.stock[item] or 0
  end
}
_G.TechPriestsPlanningConstraints0646=require("scripts.core.planning_constraints_0646")
local Plan=require("scripts.core.master_infrastructure_plan_0644")
local pairs_list={}
for id=1,4 do
  local pair={stock={stone=5,[pack]=1},lab_stock={}}
  pair.station={valid=true,type="container",unit_number=id,
    position={x=id*100,y=0},force=force,surface=surface}
  pair.priest={valid=true,unit_number=1000+id}
  pair.radius=24
  local lab={valid=true,type="lab",name="lab",unit_number=2000+id,
    position={x=id*100+2,y=0},prototype={lab_inputs={pack}}}
  lab.get_inventory=function(inventory_id)
    assert(inventory_id==defines.inventory.lab_input)
    return {valid=true,get_item_count=function(item)
      local key=id..":"..item
      calls.lab[key]=(calls.lab[key] or 0)+1
      return pair.lab_stock[item] or 0
    end}
  end
  labs[id*100]=lab
  pairs_list[id]=pair
  storage.tech_priests.pairs_by_station[id]=pair
end
local function check(value,message)
  assert(value,"master-survey-reads: "..message)
end
for _,pair in ipairs(pairs_list) do
  local plan=Plan.build_plan(pair,"four-station-read-count")
  check(plan.target.preferred_item=="stone-furnace"
      and plan.target.feasibility=="ingredients-stocked",
    "real craftable furnace lost priority")
  check(plan.research_candidate=="technology-001",
    "cheapest prerequisite-complete research changed")
end
local stock_reads,lab_reads=0,0
for _,count in pairs(calls.stock) do stock_reads=stock_reads+count end
for _,count in pairs(calls.lab) do lab_reads=lab_reads+count end
print(string.format("[master-survey-reads] four-station calls recipe_walks=%d recipe_visits=%d stock_reads=%d lab_reads=%d",
  calls.recipe_walks,calls.recipe_visits,stock_reads,lab_reads))
check(calls.recipe_walks==4,
  "the first unlock lookup's recipe was rediscovered in a second force walk")
check(stock_reads==12 and lab_reads==4,
  "physical stock/lab science was recounted for every technology or repeated target")
for _,pair in ipairs(pairs_list) do
  check(pair.stock.stone==5 and pair.stock[pack]==1,
    "read-only planning consumed physical stock")
end

-- A second plan in the same tick must see stock transfers immediately.
local pair=pairs_list[1]
pair.stock.stone=0;pair.stock[pack]=0
local empty=Plan.build_plan(pair,"same-tick-stock-spent")
check(empty.target.preferred_item=="tech-priests-emergency-smelter"
    and empty.target.feasibility:find("missing-ingredients:",1,true)
    and empty.research_candidate==nil,
  "a previous plan's inventory count survived a real stock change")
pair.lab_stock[pack]=1
local lab_ready=Plan.build_plan(pair,"same-tick-science-moved-to-lab")
check(lab_ready.research_candidate=="technology-001",
  "fresh physical lab input was hidden by a prior zero count")
technologies["technology-001"].researched=true
check(Plan.build_plan(pair,"research-finished").research_candidate=="technology-002",
  "completed research remained eligible")

-- The existing one-tick Boolean cache must not freeze a selected recipe:
-- another callback can enable an earlier alternative before the next plan.
pair.stock.stone=5
recipes["alternate-furnace"].enabled=true
local alternate=Plan.build_plan(pair,"same-tick-new-earlier-recipe")
check(alternate.target.preferred_item=="tech-priests-emergency-smelter"
    and alternate.target.feasibility:find("standard:missing-ingredients:iron-plate",1,true),
  "cached recipe choice ignored the first currently enabled producer")
recipes["alternate-furnace"].enabled=false
recipes["stone-furnace"].enabled=false
local disabled=Plan.build_plan(pair,"same-tick-recipe-disabled")
check(disabled.target.feasibility:find("standard:recipe-unavailable",1,true),
  "a cached unlock bypassed a live disabled recipe")

-- Policy permits main_product as an unlock hint; this planner historically
-- requires a matching products entry, so preserve its fallback selection.
game.tick=game.tick+1
recipes["stone-furnace"].enabled=true
recipes["alternate-furnace"].enabled=true
recipes["alternate-furnace"].main_product="stone-furnace"
recipes["alternate-furnace"].products={{name="different-product"}}
check(Plan.build_plan(pair,"main-product-compatibility").target.preferred_item=="stone-furnace",
  "reuse changed the planner's product matching semantics")
print("[master-survey-reads] PASS bounded survey reads, live stock/research/recipe changes and legacy product selection")
