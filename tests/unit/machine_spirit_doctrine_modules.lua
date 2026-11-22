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
-- Standard and custom module quality grades scale scripted effects.
near(M.quality_multiplier("normal"),1,"normal module quality")
near(M.quality_multiplier("uncommon"),1.1,"uncommon module quality")
near(M.quality_multiplier("legendary"),1.5,"legendary module quality")
near(M.quality_multiplier("unsupported"),1,"unknown module quality")
prototypes={quality={custom_sanctified={level=4},ridiculous={level=100}}}
near(M.quality_multiplier("custom_sanctified"),1.4,"custom quality level")
near(M.quality_multiplier("ridiculous"),1.5,"custom quality level cap")
prototypes=nil
local c=M.count_contents(stacks)
near(c.order,20,"two order modules")
near(c.chaos,24.2,"uncommon chaos sanctity")
near(c.resilience,0.275,"uncommon chaos resilience")
near(c.waste,0.154,"uncommon chaos waste")
near(c.extraction,0.44,"uncommon chaos extraction")
-- A legendary module strengthens only its own scripted effects.
local legendary=M.count_contents({
  {name="tech-priests-order-module-2",count=1,quality="legendary"},
  {name="tech-priests-chaos-module-1",count=1,quality="normal"}
})
near(legendary.order,30,"legendary Order II scales")
near(legendary.chaos,12,"normal Chaos I unchanged")
local reads=0
local entity={valid=true,get_module_inventory=function()return {get_contents=function()reads=reads+1;return stacks end}end}
game={tick=100}
local record={entity=entity,sanctification=50,max_sanctification=100}
near(M.effective_value(record),45.8,"effective sanctity")
assert(M.status_line(record)=="50.0 / 100.0 (eff 45.8)", "mixed doctrine effect not displayed")
near(M.performance_ratio(record,0.48),0.623,"low sanctity survival")
near(M.detritus_chance(record,0.1),0.2386,"detritus uplift")
near(M.detritus_quantity_multiplier(record,0.05),1.418,"floor yield increases despite capped chance")
near(M.detritus_quantity_multiplier(record,1),1,"no yield uplift at perfect sanctity")
near(M.damage_multiplier(record),0.725,"physical harm reduction")
near(M.damage_value(record),50,"chaos does not invent additional physical damage")
local fragile={entity=entity,sanctification=20,max_sanctification=100,
  machine_spirit_module_snapshot=record.machine_spirit_module_snapshot,
  machine_spirit_module_resample_tick=record.machine_spirit_module_resample_tick}
near(M.effective_value(fragile),15.8,"mixed modules change effective sanctity for waste")
near(M.damage_value(fragile),20,"chaos cannot worsen actual wear exposure")
near(M.damage_multiplier(fragile),0.725,"chaos reduces wear probability")
assert(reads==1,"module inventory was scanned more than once during same window")
stacks={{name="tech-priests-order-module-2",count=2}}
game.tick=159
near(M.effective_value(record),45.8,"within cache window")
assert(reads==1,"module cache refreshed early")
game.tick=160
near(M.effective_value(record),90,"module change refresh")
assert(M.status_line(record)=="50.0 / 100.0 (eff 90.0)", "doctrine label stale after module refresh")
assert(reads==2,"module cache did not refresh")
near(M.performance_ratio(record,0.9),0.9,"order does not gain chaos resilience")
near(M.detritus_chance(record,0.1),0.1,"order no extra detritus")
near(M.detritus_quantity_multiplier(record,0.05),1,"order alone has no extraction benefit")
near(M.damage_value(record),90,"order protects against physical wear")
local none={valid=true,get_module_inventory=function() return nil end}
near(M.effective_value({entity=none,sanctification=40,max_sanctification=100}),40,"no modules")
assert(M.status_line({entity=none,sanctification=40,max_sanctification=100})=="40.0 / 100.0", "unmodified label changed")
local caps=M.count_contents({{name="tech-priests-chaos-module-2",count=10}})
near(caps.resilience,0.7,"resilience limit")
near(caps.waste,0.45,"waste chance cap")
near(caps.extraction,1,"extraction amount cap")
near(M.detritus_quantity_multiplier({machine_spirit_module_snapshot=caps,machine_spirit_module_resample_tick=1000},0.05),1.95,"floor yield upper bound")
print("[machine-spirit-doctrine-modules] PASS caching, mixing, sanctity, resilience, waste")
