-- Exercise the actual planning authority with ordered, native-shaped recipe
-- collections. Metadata walks are counted separately from mutable state reads.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
game={tick=400}
local policy_file=os.getenv("TP_PLANNING_POLICY_FILE")
local function load_policy()
  package.loaded["scripts.core.planning_constraints_0646"]=nil
  return policy_file and assert(loadfile(policy_file))()
    or require("scripts.core.planning_constraints_0646")
end
local Policy=load_policy()
local walks,product_reads,main_reads,enabled_reads=0,0,0,0
local function recipe(name,products,enabled,main)
  local state={name=name,products=products,enabled=enabled,main=main}
  local object=setmetatable({}, {__index=function(_,key)
    if key=="object_name"then return main and "compatibility-recipe" or "LuaRecipe" end
    if key=="name"then return name end
    if key=="products"then product_reads=product_reads+1;return state.products end
    if key=="enabled"then enabled_reads=enabled_reads+1;return state.enabled end
    if key=="main_product"then
      main_reads=main_reads+1
      assert(main,"LuaRecipe does not expose main_product")
      return main
    end
  end})
  return object,state
end
local ordered,names={},{}
local function add(name,products,enabled,main)
  local object,state=recipe(name,products,enabled,main)
  ordered[name]=object;names[#names+1]=name
  return state
end
local first=add("z-first-native",{{name="plate"},{name="plate"},{name="byproduct"}},false)
local second=add("a-second-native",{{name="plate"}},false)
local legacy=add("compatibility-main-only",{{name="other-product"}},true,{name="main-only"})
for i=1,1000 do add("unrelated-"..i,{{name="product-"..i}},i%2==0)end
setmetatable(ordered,{__pairs=function()
  walks=walks+1
  local index=0
  return function()
    index=index+1;local name=names[index]
    if name then return name,ordered[name] end
  end
end})
local force_meta={__eq=function(a,b)return a.identity==b.identity end}
local force=setmetatable({valid=true,index=1,name="player",recipes=ordered,
  identity="first-force"},force_meta)
local allowed,reason=Policy.item_unlocked(force,"plate")
assert(not allowed and reason=="technology-locked-or-no-enabled-recipe")
first.enabled=true -- Mutates current enablement in the SAME game tick.
local live_recipe
allowed,reason,live_recipe=Policy.item_unlocked(force,"plate")
assert(allowed and reason=="enabled-recipe" and live_recipe==ordered["z-first-native"],
  "same-tick unlock change was hidden by a cached availability answer")
first.enabled=false
assert(not Policy.item_unlocked(force,"plate"),"same-tick recipe disabling stayed unlocked")
second.enabled=true
assert(Policy.item_unlocked(force,"plate"),"later enabled recipe was ignored")
local candidates=Policy.recipe_names_for_item(force,"plate",true)
assert(#candidates==2 and candidates[1]=="z-first-native" and candidates[2]=="a-second-native",
  "candidate order changed, skipped disabled recipes or repeated duplicate products")
assert(candidates==Policy.recipe_names_for_item(force,"plate",true),
  "repeated candidate access rebuilt the retained names")
local other_wrapper=setmetatable({valid=true,index=1,name="player",recipes=ordered,
  identity="first-force"},force_meta)
assert(not rawequal(force,other_wrapper) and force==other_wrapper
  and candidates==Policy.recipe_names_for_item(other_wrapper,"plate",true),
  "equal native force handles with different raw wrappers rebuilt the index")
assert(Policy.recipe_names_for_item(force,"byproduct",true)[1]=="z-first-native",
  "secondary product membership was lost")
assert(#Policy.recipe_names_for_item(force,"main-only",true)==0
  and Policy.recipe_names_for_item(force,"main-only")[1]=="compatibility-main-only"
  and Policy.item_unlocked(force,"main-only"),
  "main-product compatibility leaked into products-only crafting or disappeared from unlocks")
local initial_reads=product_reads
assert(walks==1 and product_reads==#names and main_reads==1,
  "initial metadata membership was read repeatedly or native main_product was queried")
for i=1,500 do
  Policy.item_unlocked(force,"plate")
  Policy.item_unlocked(force,"missing-"..i)
  Policy.recipe_names_for_item(force,"product-"..((i%1000)+1),true)
end
game.tick=100000
force.name="renamed-force"
assert(Policy.item_unlocked(force,"plate") and walks==1 and product_reads==initial_reads,
  "time, different missing items or force rename caused a new full recipe walk")
first.enabled=true
local selected
for _,name in ipairs(Policy.recipe_names_for_item(force,"plate",true))do
  if force.recipes[name].enabled then selected=name;break end
end
assert(selected=="z-first-native","first enabled candidate no longer matches native iteration order")
force.valid=false
assert(#Policy.recipe_names_for_item(force,"plate",true)==0)
allowed,reason=Policy.item_unlocked(force,"plate")
assert(not allowed and reason=="invalid-force-or-item","invalid force passed the unlock contract")
local fresh_recipe,fresh_state=recipe("replacement",{{name="replacement-item"}},true)
local recreated={valid=true,index=1,name="renamed-force",recipes={replacement=fresh_recipe}}
assert(#Policy.recipe_names_for_item(recreated,"plate",true)==0
  and Policy.recipe_names_for_item(recreated,"replacement-item",true)[1]=="replacement",
  "a recreated force reused the deleted force's indexed names")
assert(Policy.item_unlocked(recreated,"replacement-item"))
local before_reload=product_reads
Policy=load_policy()
assert(Policy.item_unlocked(recreated,"replacement-item") and product_reads==before_reload+1,
  "runtime reload reused stale recipe memberships or failed to rebuild")
fresh_state.enabled=false
assert(not Policy.item_unlocked(recreated,"replacement-item"),
  "post-reload enabled state was cached")
-- A transient product read may not become a permanent empty candidate set.
local fail_once=true
local intermittent=setmetatable({}, {__index=function(_,key)
  if key=="object_name"then return "LuaRecipe" end
  if key=="enabled"then return true end
  if key=="products"then
    if fail_once then fail_once=false;error("temporary metadata fault") end
    return {{name="recovered-product"}}
  end
end})
local recovering={valid=true,index=2,recipes={recover=intermittent}}
assert(not Policy.item_unlocked(recovering,"recovered-product"))
assert(Policy.item_unlocked(recovering,"recovered-product"),
  "failed metadata read permanently hid a valid recipe")
local entry_fails=true
local entry=setmetatable({}, {__index=function(_,key)
  if key=="name"then
    if entry_fails then entry_fails=false;error("temporary product entry fault") end
    return "recovered-entry"
  end
end})
local entry_recipe=recipe("entry-recipe",{entry},true)
local entry_force={valid=true,index=3,recipes={["entry-recipe"]=entry_recipe}}
assert(not Policy.item_unlocked(entry_force,"recovered-entry"))
assert(Policy.item_unlocked(entry_force,"recovered-entry"),
  "failed product entry read permanently certified partial membership")
print("[planning-recipe-membership-0646] PASS ordered names; one metadata walk;500different misses; live same-tick enablement; main-product separation; force identity; reload/error recovery")
