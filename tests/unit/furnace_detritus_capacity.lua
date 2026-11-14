local adapt=dofile("tech-priests_src/prototypes/compatibility/furnace_detritus_capacity.lua")
local function product(name,p)return{type="item",name=name,probability=p}end
local recipes={brick={category="smelting",results={product("stone-brick"),product("mechanical-detritus",0)}},
 cable={categories={"crafting"},results={product("copper-cable"),product("mechanical-detritus",0)}},
 reclaim={category="smelting",results={product("iron-ore",0.5),product("copper-ore",0.5),product("stone",0.2)}}}
local furnaces={stone={result_inventory_size=1,crafting_categories={"smelting"}},
 custom={result_inventory_size=4,crafting_categories={"smelting"}},
 other={result_inventory_size=1,crafting_categories={"other"}}}
adapt(furnaces,recipes)
assert(furnaces.stone.result_inventory_size==2,"zero-chance waste product prevents native smelting")
assert(furnaces.custom.result_inventory_size==4 and furnaces.other.result_inventory_size==1,
 "unrelated capacity changed or real multi-product reclamation granted extra capacity")
adapt(furnaces,recipes)
assert(furnaces.stone.result_inventory_size==2,"capacity adjustment is not idempotent")
print("PASS furnace output capacity preserves native smelting and the zero-chance consecration waste slot")
