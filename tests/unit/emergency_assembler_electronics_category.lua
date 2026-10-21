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
