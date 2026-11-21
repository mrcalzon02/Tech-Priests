-- Machine Spirit: two research branches with machine-installed doctrine modules.
-- Beacons must not transmit the native module effects without the sanctity rules.
local prefix = "__tech-priests__/graphics/icons/"
local specs = {
  {kind="order",tier=1,icon="machine-maintenance-litany.png",effect={consumption=-0.08},
   ingredients={{type="item",name="electronic-circuit",amount=5},{type="item",name="iron-gear-wheel",amount=5},{type="item",name="sacred-machine-oil",amount=2}}},
  {kind="order",tier=2,icon="machine-maintenance-litany.png",effect={consumption=-0.14},
   ingredients={{type="item",name="tech-priests-order-module-1",amount=1},{type="item",name="advanced-circuit",amount=8},{type="item",name="processing-unit",amount=2},{type="item",name="sacred-machine-oil",amount=4}}},
  {kind="chaos",tier=1,icon="mechanical-detritus.png",effect={speed=0.08,consumption=0.12},
   ingredients={{type="item",name="electronic-circuit",amount=5},{type="item",name="iron-gear-wheel",amount=5},{type="item",name="mechanical-detritus",amount=8}}},
  {kind="chaos",tier=2,icon="mechanical-detritus.png",effect={speed=0.14,consumption=0.24},
   ingredients={{type="item",name="tech-priests-chaos-module-1",amount=1},{type="item",name="advanced-circuit",amount=8},{type="item",name="processing-unit",amount=2},{type="item",name="mechanical-detritus",amount=20}}}
}
local function tint(kind,tier)
  if kind=="order" then
    if tier==1 then return {r=0.55,g=0.80,b=1.0,a=1} end
    return {r=0.80,g=0.95,b=1.0,a=1}
  end
  if tier==1 then return {r=1.0,g=0.52,b=0.35,a=1} end
  return {r=1.0,g=0.26,b=0.25,a=1}
end
local categories = {
  {type="module-category",name="tech-priests-machine-spirit-order"},
  {type="module-category",name="tech-priests-machine-spirit-chaos"}
}
data:extend(categories)
local modules, recipes, techs = {}, {}, {}
for _, spec in ipairs(specs) do
  local name="tech-priests-"..spec.kind.."-module-"..spec.tier
  local category="tech-priests-machine-spirit-"..spec.kind
  local icon={icon=prefix..spec.icon,icon_size=64,tint=tint(spec.kind,spec.tier)}
  modules[#modules+1] = {
    type="module",name=name,category=category,tier=spec.tier,
    icons={icon},subgroup="tech-priest-sanctification",
    order="f[doctrine]-"..spec.kind.."-"..spec.tier,
    stack_size=50,effect=spec.effect
  }
  recipes[#recipes+1] = {
    type="recipe",name=name,enabled=false,energy_required=spec.tier==1 and 8 or 18,
    ingredients=spec.ingredients,results={{type="item",name=name,amount=1}}
  }
  local tech_name="machine-spirit-"..(spec.kind=="order" and "law-order" or "chaos-anarchy").."-"..spec.tier
  local prerequisites
  if spec.tier==1 then
    prerequisites = spec.kind=="order"
      and {"modules","machine-spirit-initial-consecration-1"}
      or {"modules","efficient-sacred-oil-rendering"}
  else
    prerequisites = {
      "machine-spirit-"..(spec.kind=="order" and "law-order" or "chaos-anarchy").."-1",
      "advanced-electronics-2"
    }
  end
  techs[#techs+1] = {
    type="technology",name=tech_name,icons={icon},prerequisites=prerequisites,
    effects={{type="unlock-recipe",recipe=name}},
    unit={count=spec.tier==1 and 130 or 250,time=spec.tier==1 and 25 or 40,
      ingredients={{"automation-science-pack",1},{"logistic-science-pack",1},{"chemical-science-pack",1}}},
    order="c-l-m-"..spec.kind.."-"..spec.tier
  }
end
data:extend(modules)
data:extend(recipes)
data:extend(techs)
