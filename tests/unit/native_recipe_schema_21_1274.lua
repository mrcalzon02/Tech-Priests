-- 1274 2.1 native recipe category + independent product probability.
local adapt=dofile("tech-priests_src/prototypes/compatibility/native_recipe_schema_1274.lua")
local function sample()
  return {
    ["speed-module"]={
      name="speed-module",category="crafting",additional_categories={"advanced-crafting","crafting"},
      results={{type="item",name="speed-module",amount=1},
               {type="item",name="mechanical-detritus",amount=1,probability=0,
                ignored_by_stats=1,ignored_by_productivity=1}},
      main_product="speed-module",always_show_products=true,show_amount_in_title=true
    },
    ["void-cargo"]={name="void-cargo",categories={"crafting-with-fluid"},
      results={{type="item",name="void-sealed-cargo",amount=1,probability=0.25}}},
    ["recycled-thing"]={name="recycled-thing",categories={"recycling"},
      results={{type="item",name="scrap",amount=1,independent_probability=0.4}}}
  }
end
local vanilla=sample()
assert(adapt(vanilla,"2.0.77")==0 and vanilla["speed-module"].category=="crafting"
  and vanilla["speed-module"].results[2].probability==0,
  "2.0 native recipe schema must not be mutated")
local migrated=sample()
local category_count,product_count=adapt(migrated,"2.1.24")
local speed=migrated["speed-module"]
assert(category_count==1 and product_count==2, "2.1 prototype migration count wrong")
assert(speed.categories[1]=="crafting" and speed.categories[2]=="advanced-crafting"
  and #speed.categories==2 and speed.category==nil
  and speed.additional_categories==nil, "2.1 category merge lost categories")
assert(speed.results[2].independent_probability==0
  and speed.results[2].probability==nil
  and speed.results[2].ignored_by_stats==1
  and speed.results[2].ignored_by_productivity==1
  and speed.main_product=="speed-module",
  "2.1 zero-probability Detritus slot or identity lost")
assert(migrated["void-cargo"].results[1].independent_probability==0.25
  and migrated["recycled-thing"].results[1].independent_probability==0.4,
  "2.1 stochastic recipe output changed")
assert(select(2,adapt(migrated,"2.1.24"))==0, "migration was not idempotent")
local conflict={bad={name="bad",results={{type="item",name="bad",
  probability=0.25,independent_probability=0.5}}}}
assert(not pcall(adapt,conflict,"2.1.24"),
  "conflicting product probabilities silently overwritten")
assert(not pcall(adapt,{},"invalid"), "unknown engine version accepted")
print("[recipe-schema-2.1-1274] PASS 2.0 preservation, 2.1 categories and zero-chance detritus outputs")
