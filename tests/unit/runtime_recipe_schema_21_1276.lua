-- 1276: Exercise the REAL Magos yield/category logic and emergency
-- workshop's strict Factorio 2.0 versus 2.1 LuaRecipePrototype API.
local function extract(filename, from, through)
  local f=assert(io.open(filename,"rb"))
  local src=f:read("*a"); f:close()
  local begin=assert(src:find(from,1,true), "missing "..from)
  local finish=assert(src:find(through,begin+1,true), "missing "..through)
  return src:sub(begin,finish-1)
end
local magos="tech-priests_src/scripts/magos_ratio_planning.lua"
local categoryCode=extract(magos,
  "local function tech_priests_0257_recipe_category(recipe)",
  "local function tech_priests_0257_recipe_energy(recipe)")
local categoryFactory=assert(load(categoryCode.."\nreturn tech_priests_0257_recipe_category",
  "magos-category-schema","t",_G))
local category=categoryFactory()
local strict=function(fields)
  return setmetatable(fields,{__index=function(_,key)
    error("invalid native prototype property: "..tostring(key))
  end})
end
assert(category(strict({category="smelting"}))=="smelting",
  "2.0 strict singular category failed")
assert(category(strict({categories={"crafting","chemistry"}}))=="chemistry"
  and category(strict({categories={"crafting","smelting"}}))=="smelting",
  "2.1 multi-category specialist machine classification failed")
assert(category(strict({categories={"advanced-crafting","crafting"}}))=="advanced-crafting",
  "2.1 generic category selection lost")
assert(category(strict({}))==nil,"missing category fabricated")
local amountCode=extract(magos,
  "local function tech_priests_0257_recipe_products(recipe)",
  "local function tech_priests_0257_machine_speed_for_group(group)")
local amount=assert(load(amountCode.."\nreturn tech_priests_0257_product_amount",
  "magos-product-probability-schema","t",_G))()
local function recipe(products) return strict({products=products}) end
assert(amount(recipe({{type="item",name="a",amount=4,probability=0.25}}),"a")==1,
  "2.0 probabilistic output magnitude changed")
assert(amount(recipe({{type="item",name="a",amount=4,
  independent_probability=0.5,shared_probability={min=0,max=0.25}}}),"a")==0.5,
  "2.1 independent/shared probability factors not applied")
assert(amount(recipe({{type="item",name="a",amount=4,
  independent_probability=0}}),"a")==0,
  "zero-probability Detritus product was credited as actual yield")
assert(amount(recipe({{type="item",name="a",amount_min=2,amount_max=6,
  independent_probability=0.25}}),"a")==1,
  "variable-yield 2.1 product lost expected amount")
local em="tech-priests_src/scripts/core/emergency_facility_doctrine.lua"
local helperCode=extract(em,
  "local function emergency_recipe_categories_1276(proto)",
  "local function recipe_for(role, item)")
local categories=assert(load(helperCode.."\nreturn emergency_recipe_categories_1276",
  "emergency-native-categories","t",_G))()
assert(categories(strict({category="smelting"}))[1]=="smelting",
  "2.0 emergency recipe category unavailable")
assert(categories(strict({categories={"crafting","tech-priests-emergency-smelting"}}))[2]
    =="tech-priests-emergency-smelting",
  "2.1 emergency recipe discarded specialist smelting category")
assert(#categories(strict({}))==0,
  "unknown recipe API should not fabricate a category")
print("[runtime-recipe-schema-2.1-1276] PASS strict native 2.0/2.1 category and stochastic yield")
