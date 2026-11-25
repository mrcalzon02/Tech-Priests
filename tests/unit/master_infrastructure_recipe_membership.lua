-- Exercise real 0644 planning through the real 0646 recipe membership owner.
-- Large recipe collections must be materialized once, not once per question.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=1000}
storage={tech_priests={pairs_by_station={}}}
defines={inventory={chest=1}}
local product_reads,recipe_walks=0,0
local order,recipes={},{}
setmetatable(recipes,{__pairs=function(t)
  recipe_walks=recipe_walks+1
  local i=0
  return function()
    i=i+1
    local key=order[i]
    if key then return key,t[key] end
  end
end})
local function recipe(name,product,enabled,ingredients)
  local value=setmetatable({valid=true,name=name,enabled=enabled,
    ingredients=ingredients or {}},{__index=function(_,key)
      if key=="products" then
        product_reads=product_reads+1
        return {{type="item",name=product,amount=1}}
      end
    end})
  recipes[name]=value;order[#order+1]=name
  return value
end
for i=1,1000 do recipe("unrelated-"..i,"unrelated-output-"..i,false) end
local standard=recipe("first-stone-furnace","stone-furnace",true,
  {{name="stone",amount=5}})
local alternative=recipe("second-stone-furnace","stone-furnace",true,
  {{name="stone",amount=1}})
local emergency=recipe("emergency-smelter","tech-priests-emergency-smelter",true,
  {{name="iron-plate",amount=1}})
local force={valid=true,index=1,name="player",recipes=recipes,technologies={}}
local stock={stone=1,["iron-plate"]=1}
local inventory={valid=true,get_item_count=function(name)return stock[name] or 0 end}
local surface={index=1,name="nauvis",find_entities_filtered=function()return {} end}
local pairs_to_plan={}
for i=1,4 do
  local station={valid=true,unit_number=i*10,position={x=i*50,y=0},
    force=force,surface=surface,get_inventory=function()return inventory end}
  local pair={station=station,station_unit=station.unit_number,radius=24,
    priest={valid=true,unit_number=i*10+1,position={x=i*50,y=0}}}
  pairs_to_plan[i]=pair;storage.tech_priests.pairs_by_station[station.unit_number]=pair
end
_G.TechPriestsPlanningConstraints0646=require("scripts.core.planning_constraints_0646")
local Plan=require("scripts.core.master_infrastructure_plan_0644")
local function plan(pair,item,reason)
  local result=assert(Plan.build_plan(pair,reason))
  assert(result.stage=="bootstrap-smelting" and result.target.preferred_item==item,
    reason..": unexpected target "..tostring(result.target.preferred_item))
  return result
end
plan(pairs_to_plan[1],"tech-priests-emergency-smelter","preserve-first-recipe-order")
assert(product_reads==1003 and recipe_walks==1,"initial recipe membership was not built once")
for tick=1,100 do
  game.tick=game.tick+97
  for _,pair in ipairs(pairs_to_plan) do
    plan(pair,"tech-priests-emergency-smelter","warm-four-priest-planning")
  end
end
assert(product_reads==1003 and recipe_walks==1,
  "warm infrastructure plans rediscovered recipe product membership")
-- Availability may change without advancing game.tick. No cached unlocked
-- boolean or ingredients count may conceal these native state changes.
standard.enabled=false
plan(pairs_to_plan[1],"stone-furnace","same-tick-alternative-enabled")
alternative.enabled=false
plan(pairs_to_plan[1],"tech-priests-emergency-smelter","same-tick-standard-locked")
standard.enabled=true;stock.stone=5
plan(pairs_to_plan[1],"stone-furnace","newly-stocked-standard-ingredients")
stock.stone=0
plan(pairs_to_plan[1],"tech-priests-emergency-smelter","standard-ingredients-consumed")
stock["iron-plate"]=0
local missing=plan(pairs_to_plan[1],"tech-priests-emergency-smelter","live-emergency-shortage")
assert(missing.target.feasibility:find("missing-ingredients:iron-plate",1,true),
  "retained recipe membership invented consumed physical ingredients")
emergency.enabled=false
local locked=plan(pairs_to_plan[1],"stone-furnace","same-tick-emergency-locked")
assert(locked.target.feasibility:find("emergency:technology-locked-or-no-recipe",1,true),
  "same-tick disabled emergency recipe remained available")
assert(product_reads==1003 and recipe_walks==1,
  "state changes caused another recipe product catalog walk")
print("[master-infrastructure-recipe-membership] PASS 400 warm plans; one recipe membership build; live unlocks and ingredients; first recipe order")
