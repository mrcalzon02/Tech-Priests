-- Lua 5.2 regression: execute the real emergency-assembler prototype
-- builder (not a copied list) against a minimal data-stage environment.
-- Factorio's genuine copper-cable and electronic-circuit recipes both use
-- the "electronics" category. A missing category makes set_recipe fail
-- to select either after the Electronics technology has been earned.
local f=assert(io.open("tech-priests_src/prototypes/entity.lua","rb"))
local full=f:read("*a");f:close()
local first=assert(full:find("local function make_emergency_assembler()",1,true))
local next=assert(full:find("\nlocal function make_emergency_smelter()",first,true))
local builder=full:sub(first,next-1)
local vanilla={name="assembling-machine-1",crafting_categories={"crafting"},
  energy_usage="75kW"}
local function clone(obj)
  if type(obj)~="table" then return obj end
  local result={}
  for k,v in pairs(obj) do result[k]=clone(v) end
  return result
end
local library={}
for k,v in pairs(table) do library[k]=v end
library.deepcopy=clone
local env={
  table=library,
  data={raw={["assembling-machine"]={["assembling-machine-1"]=vanilla}}},
  tech_priests_micro_icon_path=function()return "test-icon.png" end,
  tech_priests_apply_micro_icon=function()end,
  tech_priests_micro_crafting_art=function()return {} end,
  tech_priests_apply_micro_crafting_art=function()end,
  tech_priests_micro_boxes=function()end,
  tech_priests_apply_micro_visuals=function()end,
  tech_priests_apply_planetside_conditions=function()end,
  MICRO_ONE_TILE_SLIGHTLY_LARGE_SCALE_0541=1,
}
local factory,err=load(builder.."\nreturn make_emergency_assembler()",
  "emergency-assembler-prototype","t",env)
assert(factory,err)
local assembler=factory()
assert(assembler and assembler.name=="tech-priests-emergency-assembler",
  "data stage failed to construct the actual emergency assembler")
local categories={}
for _,category in ipairs(assembler.crafting_categories or {}) do
  categories[category]=true
end
assert(categories["electronics"],
  "real emergency assembler cannot manufacture copper cable/circuits")
assert(categories["crafting"] and categories["basic-crafting"]
    and categories["advanced-crafting"],
  "electronics repair displaced an existing workshop crafting family")
assert(not categories["smelting"]
    and not categories["tech-priests-emergency-smelting"],
  "electronics repair incorrectly moved plate smelting into the assembler")
assert(vanilla.crafting_categories[1]=="crafting"
    and vanilla.crafting_categories[2]==nil,
  "emergency assembler modification changed the vanilla prototype")
print("[emergency-assembler-electronics] PASS compatible categories and isolated smelting")

-- Execute the runtime capability preflight itself against both engine API
-- shapes. In Factorio 2.0 a LuaRecipePrototype supports `category` only:
-- asking for the 2.1-only `categories` property raises, not returns nil.
local file=assert(io.open("tech-priests_src/scripts/core/emergency_facility_doctrine.lua","rb"))
local doctrine=file:read("*a");file:close()
local fit_start=assert(doctrine:find("local function machine_recipe_fit(",1,true))
local fit_end=assert(doctrine:find("\nM.machine_recipe_fit=machine_recipe_fit",fit_start,true))
local fit_code=doctrine:sub(fit_start,fit_end-1)
local function strict_prototype(properties)
  return setmetatable(properties,{
    __index=function(_,key)
      error("invalid Factorio recipe prototype field: "..tostring(key))
    end,
  })
end
local legacy_recipe=strict_prototype({
  category="electronics",
  ingredients={{type="item",name="copper-plate",amount=1}},
  products={{type="item",name="copper-cable",amount=2}},
})
local runtime_env={
  valid=function(entity)return entity and entity.valid==true end,
  prototypes={recipe={["copper-cable"]=legacy_recipe}},
}
local loaded,load_error=load(fit_code.."\nreturn machine_recipe_fit",
  "real-assembler-capability-preflight","t",runtime_env)
assert(loaded,load_error)
local fit=loaded()
local force={recipes={["copper-cable"]={enabled=true}}}
local entity={valid=true,type="assembling-machine",force=force,
  prototype={crafting_categories={electronics=true}}}
local pair={station={force=force}}
local ok,accepted,why=pcall(fit,pair,entity,"copper-cable")
assert(ok and accepted==true,
  "Factorio 2.0 legacy recipe category threw or rejected: "..tostring(why))
runtime_env.prototypes.recipe["copper-cable"]=strict_prototype({
  categories={"electronics"},ingredients=legacy_recipe.ingredients,
  products=legacy_recipe.products,
})
ok,accepted,why=pcall(fit,pair,entity,"copper-cable")
assert(ok and accepted==true,
  "Factorio 2.1 multiple recipe categories threw or rejected: "..tostring(why))
entity.prototype.crafting_categories={crafting=true}
ok,accepted,why=pcall(fit,pair,entity,"copper-cable")
assert(ok and accepted==false and
    tostring(why):find("incompatible-crafting-category",1,true),
  "preflight accepted a physically incompatible workshop")
runtime_env.prototypes.recipe["copper-cable"]=strict_prototype({
  ingredients=legacy_recipe.ingredients,products=legacy_recipe.products,
})
ok,accepted,why=pcall(fit,pair,entity,"copper-cable")
assert(ok and accepted==false and why=="recipe-category-api-unavailable",
  "unknown engine recipe category must fail closed without a Lua exception")
print("[emergency-assembler-electronics] PASS engine 2.0/2.1 category API and fail-closed preflight")
