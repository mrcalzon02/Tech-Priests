-- Bounded machine-spirit doctrine tests, runs in plain Lua 5.2+ / texlua.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local M=require("scripts.core.consecration.doctrine_effects")
local function near(a,b,label)
  assert(math.abs(a-b)<0.00001,label.." got "..tostring(a).." expected "..tostring(b))
end
local stacks={
  {name="tech-priests-order-module-1",count=2,quality="normal"},
  {name="tech-priests-chaos-module-2",count=1,quality="uncommon"},
  {name="speed-module",count=1}
}
local c=M.count_contents(stacks)
near(c.order,20,"two order modules")
near(c.chaos,22,"chaos sanctity")
near(c.resilience,0.25,"chaos resilience")
near(c.waste,0.14,"chaos waste")
local reads=0
local entity={valid=true,get_module_inventory=function()return {get_contents=function()reads=reads+1;return stacks end}end}
game={tick=100}
local record={entity=entity,sanctification=50,max_sanctification=100}
near(M.effective_value(record),48,"effective sanctity")
near(M.performance_ratio(record,0.48),0.61,"low sanctity survival")
near(M.detritus_chance(record,0.1),0.226,"detritus uplift")
near(M.damage_multiplier(record),0.75,"physical harm reduction")
assert(reads==1,"module inventory was scanned more than once during same window")
stacks={{name="tech-priests-order-module-2",count=2}}
game.tick=159
near(M.effective_value(record),48,"within cache window")
assert(reads==1,"module cache refreshed early")
game.tick=160
near(M.effective_value(record),90,"module change refresh")
assert(reads==2,"module cache did not refresh")
near(M.performance_ratio(record,0.9),0.9,"order does not gain chaos resilience")
near(M.detritus_chance(record,0.1),0.1,"order no extra detritus")
local none={valid=true,get_module_inventory=function() return nil end}
near(M.effective_value({entity=none,sanctification=40,max_sanctification=100}),40,"no modules")
local caps=M.count_contents({{name="tech-priests-chaos-module-2",count=10}})
near(caps.resilience,0.7,"resilience limit")
near(caps.waste,0.45,"waste chance cap")
print("[machine-spirit-doctrine-modules] PASS caching, mixing, sanctity, resilience, waste")
